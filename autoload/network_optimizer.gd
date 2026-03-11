## NetworkOptimizer Autoload Singleton
##
## Handles bandwidth optimization through delta compression, packet batching,
## and priority-based state replication for BattleZone Party.
##
## Features:
##   - Delta compression for position/state updates
##   - Input buffering and batching
##   - Priority-based entity updates
##   - Bandwidth throttling (<50 KB/s per player target)
##   - Packet scheduling and rate limiting
extends Node

# =============================================================================
# region - Constants
# =============================================================================

## Maximum bandwidth per player in bytes per second (50 KB/s target)
const MAX_BANDWIDTH_PER_PLAYER: int = 51200

## State update rate in Hz (20 updates per second for mobile optimization)
const STATE_UPDATE_RATE: float = 20.0

## Input send rate in Hz (60 inputs per second for responsive feel)
const INPUT_SEND_RATE: float = 60.0

## Maximum inputs to buffer before forcing send
const MAX_INPUT_BUFFER_SIZE: int = 10

## Delta compression threshold - positions within this distance use delta encoding
const DELTA_THRESHOLD: float = 32.0

## Quantization precision for positions (1/1000 unit precision)
const POSITION_QUANTIZE_SCALE: float = 1000.0

## Maximum packet size in bytes
const MAX_PACKET_SIZE: int = 1200

# endregion

# =============================================================================
# region - Signals
# =============================================================================

## Emitted when bandwidth usage changes significantly
signal bandwidth_updated(bytes_per_second: int)

## Emitted when packet is ready to send
signal packet_ready(packet_data: PackedByteArray, channel: int)

## Emitted when entity states are received
signal states_received(states: Dictionary)

## Emitted when inputs are received from a peer
signal inputs_received(peer_id: int, inputs: Array)

# endregion

# =============================================================================
# region - Enums
# =============================================================================

## Packet types for the optimized protocol
enum PacketType {
	STATE_FULL = 0,        ## Full state snapshot
	STATE_DELTA = 1,       ## Delta-compressed state
	INPUT_BATCH = 2,       ## Batched player inputs
	ACK = 3,               ## Acknowledgment
	PING = 4,              ## Latency measurement
	ENTITY_SPAWN = 5,      ## New entity created
	ENTITY_DESTROY = 6,    ## Entity removed
	EVENT = 7,             ## Game event (hit, pickup, etc.)
}

## Entity priority levels for bandwidth allocation
enum EntityPriority {
	CRITICAL = 0,    ## Local player, always send
	HIGH = 1,        ## Nearby players, frequent updates
	MEDIUM = 2,      ## Distant players, reduced updates
	LOW = 3,         ## Non-essential entities
}

# endregion

# =============================================================================
# region - State
# =============================================================================

## Whether optimization is enabled
var enabled: bool = true

## Current bandwidth usage in bytes per second
var current_bandwidth: int = 0

## Accumulated bytes sent this second
var _bytes_this_second: int = 0

## Time accumulator for bandwidth measurement
var _bandwidth_timer: float = 0.0

## Input buffer for batching
var _input_buffer: Array[Dictionary] = []

## Last input sequence number sent
var _input_sequence: int = 0

## Acknowledged input sequence per peer (server-side)
var _peer_ack_sequences: Dictionary = {}  # peer_id -> last_ack_sequence

## Previous entity states for delta compression
var _previous_states: Dictionary = {}  # entity_id -> EntityState

## Pending state updates to send
var _pending_updates: Array[Dictionary] = []

## Time accumulator for state updates
var _state_timer: float = 0.0

## Time accumulator for input sends
var _input_timer: float = 0.0

## Snapshot history for reconciliation (indexed by sequence)
var _snapshot_history: Dictionary = {}  # sequence -> snapshot_data

## Current snapshot sequence number
var _snapshot_sequence: int = 0

## Maximum snapshots to keep in history
const MAX_SNAPSHOT_HISTORY: int = 128

# endregion

# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if not enabled:
		return

	_update_bandwidth_tracking(delta)
	_process_input_buffer(delta)
	_process_state_updates(delta)

# endregion

# =============================================================================
# region - Bandwidth Tracking
# =============================================================================

func _update_bandwidth_tracking(delta: float) -> void:
	_bandwidth_timer += delta
	if _bandwidth_timer >= 1.0:
		_bandwidth_timer -= 1.0
		current_bandwidth = _bytes_this_second
		_bytes_this_second = 0
		bandwidth_updated.emit(current_bandwidth)


## Records bytes sent for bandwidth tracking
func record_bytes_sent(byte_count: int) -> void:
	_bytes_this_second += byte_count


## Check if we can send more data within bandwidth limits
func can_send_bytes(byte_count: int, player_count: int = 1) -> bool:
	var budget: int = MAX_BANDWIDTH_PER_PLAYER * player_count
	return _bytes_this_second + byte_count <= budget

# endregion

# =============================================================================
# region - Input Buffering and Batching
# =============================================================================

## Queues an input for batched sending
func queue_input(input_data: Dictionary) -> void:
	_input_sequence += 1
	input_data["sequence"] = _input_sequence
	input_data["timestamp"] = Time.get_ticks_msec()
	_input_buffer.append(input_data)

	# Force send if buffer is full
	if _input_buffer.size() >= MAX_INPUT_BUFFER_SIZE:
		_send_input_batch()


func _process_input_buffer(delta: float) -> void:
	_input_timer += delta
	var interval: float = 1.0 / INPUT_SEND_RATE

	if _input_timer >= interval and _input_buffer.size() > 0:
		_input_timer -= interval
		_send_input_batch()


func _send_input_batch() -> void:
	if _input_buffer.is_empty():
		return

	var packet: PackedByteArray = encode_input_batch(_input_buffer)
	packet_ready.emit(packet, 1)  # Channel 1 for inputs (unreliable)
	record_bytes_sent(packet.size())

	# Keep inputs in buffer until acknowledged (for reconciliation)
	# We'll trim old inputs when we receive ACKs


## Encodes a batch of inputs into a compact packet
func encode_input_batch(inputs: Array) -> PackedByteArray:
	var buffer := PackedByteArray()

	# Header: packet type (1 byte) + input count (1 byte)
	buffer.append(PacketType.INPUT_BATCH)
	buffer.append(mini(inputs.size(), 255))

	for input: Dictionary in inputs:
		# Encode each input compactly (6 bytes per input)
		# Sequence (2 bytes) + movement_x (1 byte) + movement_y (1 byte) + buttons (1 byte) + aim_angle (1 byte)
		var seq: int = input.get("sequence", 0) as int
		buffer.append(seq & 0xFF)
		buffer.append((seq >> 8) & 0xFF)

		# Quantize movement to -127 to 127
		var move: Vector2 = input.get("movement", Vector2.ZERO) as Vector2
		buffer.append(clampi(int(move.x * 127), -127, 127) + 128)  # Shift to 0-255
		buffer.append(clampi(int(move.y * 127), -127, 127) + 128)

		# Button flags
		var buttons: int = input.get("buttons", 0) as int
		buffer.append(buttons & 0xFF)

		# Aim angle (0-255 maps to 0-360 degrees)
		var aim: float = input.get("aim_angle", 0.0) as float
		buffer.append(int(fmod(aim + 360.0, 360.0) / 360.0 * 255.0) & 0xFF)

	return buffer


## Decodes a batch of inputs from a packet
func decode_input_batch(buffer: PackedByteArray) -> Array[Dictionary]:
	var inputs: Array[Dictionary] = []

	if buffer.size() < 2:
		return inputs

	var packet_type: int = buffer[0]
	if packet_type != PacketType.INPUT_BATCH:
		return inputs

	var count: int = buffer[1]
	var offset: int = 2

	for i in range(count):
		if offset + 6 > buffer.size():
			break

		var input: Dictionary = {}
		input["sequence"] = buffer[offset] | (buffer[offset + 1] << 8)
		input["movement"] = Vector2(
			(buffer[offset + 2] - 128) / 127.0,
			(buffer[offset + 3] - 128) / 127.0
		)
		input["buttons"] = buffer[offset + 4]
		input["aim_angle"] = buffer[offset + 5] / 255.0 * 360.0

		inputs.append(input)
		offset += 6

	return inputs


## Processes acknowledgment from server, removing confirmed inputs
func process_input_ack(ack_sequence: int) -> void:
	# Remove all inputs up to and including the acknowledged sequence
	while _input_buffer.size() > 0:
		var input: Dictionary = _input_buffer[0]
		if input.get("sequence", 0) as int <= ack_sequence:
			_input_buffer.remove_at(0)
		else:
			break

# endregion

# =============================================================================
# region - Delta Compression
# =============================================================================

## Compresses entity state using delta encoding against previous state
func compress_state_delta(entity_id: int, current_state: Dictionary) -> PackedByteArray:
	var buffer := PackedByteArray()

	var previous: Dictionary = _previous_states.get(entity_id, {}) as Dictionary
	var has_previous: bool = not previous.is_empty()

	# Entity ID (4 bytes)
	buffer.append_array(_encode_int32(entity_id))

	# Flags byte: bit 0 = has position delta, bit 1 = has rotation delta, etc.
	var flags: int = 0

	var position: Vector3 = current_state.get("position", Vector3.ZERO) as Vector3
	var rotation: float = current_state.get("rotation", 0.0) as float
	var velocity: Vector3 = current_state.get("velocity", Vector3.ZERO) as Vector3
	var health: float = current_state.get("health", 100.0) as float

	var prev_pos: Vector3 = previous.get("position", Vector3.ZERO) as Vector3
	var prev_rot: float = previous.get("rotation", 0.0) as float
	var prev_vel: Vector3 = previous.get("velocity", Vector3.ZERO) as Vector3
	var prev_health: float = previous.get("health", 100.0) as float

	var pos_delta: Vector3 = position - prev_pos
	var can_use_delta: bool = has_previous and pos_delta.length() < DELTA_THRESHOLD

	if can_use_delta:
		flags |= 0x01  # Using delta position
	if absf(rotation - prev_rot) > 0.01:
		flags |= 0x02  # Rotation changed
	if velocity.length() > 0.01:
		flags |= 0x04  # Has velocity
	if absf(health - prev_health) > 0.1:
		flags |= 0x08  # Health changed

	buffer.append(flags)

	# Position (delta or full)
	if can_use_delta:
		# 6 bytes for delta (int16 per axis, scaled by 1000)
		buffer.append_array(_encode_int16(int(pos_delta.x * POSITION_QUANTIZE_SCALE)))
		buffer.append_array(_encode_int16(int(pos_delta.y * POSITION_QUANTIZE_SCALE)))
		buffer.append_array(_encode_int16(int(pos_delta.z * POSITION_QUANTIZE_SCALE)))
	else:
		# 12 bytes for full position
		buffer.append_array(_encode_float(position.x))
		buffer.append_array(_encode_float(position.y))
		buffer.append_array(_encode_float(position.z))

	# Rotation (2 bytes, scaled 0-65535 for 0-360 degrees)
	if flags & 0x02:
		var rot_encoded: int = int(fmod(rotation + 360.0, 360.0) / 360.0 * 65535.0)
		buffer.append_array(_encode_int16(rot_encoded))

	# Velocity (6 bytes if present)
	if flags & 0x04:
		buffer.append_array(_encode_int16(int(velocity.x * 100.0)))
		buffer.append_array(_encode_int16(int(velocity.y * 100.0)))
		buffer.append_array(_encode_int16(int(velocity.z * 100.0)))

	# Health (1 byte, 0-255)
	if flags & 0x08:
		buffer.append(clampi(int(health), 0, 255))

	# Store current state for next delta
	_previous_states[entity_id] = current_state.duplicate()

	return buffer


## Decompresses delta-encoded entity state
func decompress_state_delta(buffer: PackedByteArray, offset: int, previous: Dictionary) -> Dictionary:
	var state: Dictionary = {}
	var read_offset: int = offset

	if buffer.size() < read_offset + 5:
		return state

	# Entity ID
	var entity_id: int = _decode_int32(buffer, read_offset)
	read_offset += 4
	state["entity_id"] = entity_id

	# Flags
	var flags: int = buffer[read_offset]
	read_offset += 1

	# Position
	if flags & 0x01:
		# Delta position
		var prev_pos: Vector3 = previous.get("position", Vector3.ZERO) as Vector3
		var dx: float = _decode_int16(buffer, read_offset) / POSITION_QUANTIZE_SCALE
		var dy: float = _decode_int16(buffer, read_offset + 2) / POSITION_QUANTIZE_SCALE
		var dz: float = _decode_int16(buffer, read_offset + 4) / POSITION_QUANTIZE_SCALE
		state["position"] = prev_pos + Vector3(dx, dy, dz)
		read_offset += 6
	else:
		# Full position
		state["position"] = Vector3(
			_decode_float(buffer, read_offset),
			_decode_float(buffer, read_offset + 4),
			_decode_float(buffer, read_offset + 8)
		)
		read_offset += 12

	# Rotation
	if flags & 0x02:
		var rot_raw: int = _decode_int16(buffer, read_offset)
		state["rotation"] = (rot_raw / 65535.0) * 360.0
		read_offset += 2
	else:
		state["rotation"] = previous.get("rotation", 0.0)

	# Velocity
	if flags & 0x04:
		state["velocity"] = Vector3(
			_decode_int16(buffer, read_offset) / 100.0,
			_decode_int16(buffer, read_offset + 2) / 100.0,
			_decode_int16(buffer, read_offset + 4) / 100.0
		)
		read_offset += 6
	else:
		state["velocity"] = previous.get("velocity", Vector3.ZERO)

	# Health
	if flags & 0x08:
		state["health"] = buffer[read_offset]
		read_offset += 1
	else:
		state["health"] = previous.get("health", 100.0)

	state["_read_size"] = read_offset - offset
	return state

# endregion

# =============================================================================
# region - State Updates
# =============================================================================

func _process_state_updates(delta: float) -> void:
	_state_timer += delta
	var interval: float = 1.0 / STATE_UPDATE_RATE

	if _state_timer >= interval:
		_state_timer -= interval
		_flush_state_updates()


## Queues an entity state update for sending
func queue_state_update(entity_id: int, state: Dictionary, priority: EntityPriority = EntityPriority.MEDIUM) -> void:
	_pending_updates.append({
		"entity_id": entity_id,
		"state": state,
		"priority": priority,
	})


func _flush_state_updates() -> void:
	if _pending_updates.is_empty():
		return

	# Sort by priority
	_pending_updates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["priority"] < b["priority"]
	)

	# Build packet respecting max size
	var packet := PackedByteArray()
	packet.append(PacketType.STATE_DELTA)
	packet.append_array(_encode_int32(_snapshot_sequence))

	var entity_count: int = 0
	var count_offset: int = packet.size()
	packet.append(0)  # Placeholder for entity count

	for update: Dictionary in _pending_updates:
		var entity_data: PackedByteArray = compress_state_delta(
			update["entity_id"],
			update["state"]
		)

		if packet.size() + entity_data.size() > MAX_PACKET_SIZE:
			break

		packet.append_array(entity_data)
		entity_count += 1

	packet[count_offset] = entity_count

	if entity_count > 0:
		# Store snapshot for reconciliation
		_store_snapshot(_snapshot_sequence, _pending_updates.slice(0, entity_count))
		_snapshot_sequence += 1

		packet_ready.emit(packet, 0)  # Channel 0 for state (unreliable ordered)
		record_bytes_sent(packet.size())

	_pending_updates.clear()


func _store_snapshot(sequence: int, updates: Array) -> void:
	_snapshot_history[sequence] = {
		"timestamp": Time.get_ticks_msec(),
		"updates": updates,
	}

	# Trim old snapshots
	var keys: Array = _snapshot_history.keys()
	while keys.size() > MAX_SNAPSHOT_HISTORY:
		var oldest_key: int = keys[0] as int
		_snapshot_history.erase(oldest_key)
		keys.remove_at(0)


## Gets a snapshot by sequence number for reconciliation
func get_snapshot(sequence: int) -> Dictionary:
	return _snapshot_history.get(sequence, {}) as Dictionary

# endregion

# =============================================================================
# region - Encoding Helpers
# =============================================================================

func _encode_int16(value: int) -> PackedByteArray:
	var buffer := PackedByteArray()
	buffer.resize(2)
	buffer.encode_s16(0, value)
	return buffer


func _decode_int16(buffer: PackedByteArray, offset: int) -> int:
	if buffer.size() < offset + 2:
		return 0
	return buffer.decode_s16(offset)


func _encode_int32(value: int) -> PackedByteArray:
	var buffer := PackedByteArray()
	buffer.resize(4)
	buffer.encode_s32(0, value)
	return buffer


func _decode_int32(buffer: PackedByteArray, offset: int) -> int:
	if buffer.size() < offset + 4:
		return 0
	return buffer.decode_s32(offset)


func _encode_float(value: float) -> PackedByteArray:
	var buffer := PackedByteArray()
	buffer.resize(4)
	buffer.encode_float(0, value)
	return buffer


func _decode_float(buffer: PackedByteArray, offset: int) -> float:
	if buffer.size() < offset + 4:
		return 0.0
	return buffer.decode_float(offset)

# endregion

# =============================================================================
# region - Priority Calculation
# =============================================================================

## Calculates entity priority based on distance from local player
func calculate_entity_priority(
	entity_position: Vector3,
	local_player_position: Vector3,
	is_local_player: bool
) -> EntityPriority:
	if is_local_player:
		return EntityPriority.CRITICAL

	var distance: float = entity_position.distance_to(local_player_position)

	if distance < 15.0:
		return EntityPriority.HIGH
	elif distance < 40.0:
		return EntityPriority.MEDIUM
	else:
		return EntityPriority.LOW


## Gets the update interval multiplier based on priority
func get_priority_update_multiplier(priority: EntityPriority) -> float:
	match priority:
		EntityPriority.CRITICAL:
			return 1.0
		EntityPriority.HIGH:
			return 1.0
		EntityPriority.MEDIUM:
			return 0.5
		EntityPriority.LOW:
			return 0.25
		_:
			return 0.25

# endregion

# =============================================================================
# region - RPC Handlers
# =============================================================================

## Sends state packet to all clients (server-side)
@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_state_update(packet: PackedByteArray) -> void:
	_handle_state_packet(packet)


## Sends input packet to server (client-side)
@rpc("any_peer", "call_remote", "unreliable")
func _rpc_input_update(packet: PackedByteArray) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var inputs: Array[Dictionary] = decode_input_batch(packet)
	inputs_received.emit(sender_id, inputs)


## Sends input acknowledgment to client (server-side)
@rpc("authority", "call_remote", "unreliable")
func _rpc_input_ack(ack_sequence: int) -> void:
	process_input_ack(ack_sequence)


func _handle_state_packet(packet: PackedByteArray) -> void:
	if packet.size() < 6:
		return

	var packet_type: int = packet[0]
	if packet_type != PacketType.STATE_DELTA:
		return

	var snapshot_seq: int = _decode_int32(packet, 1)
	var entity_count: int = packet[5]

	var states: Dictionary = {}
	var offset: int = 6

	for i in range(entity_count):
		if offset >= packet.size():
			break

		var entity_id: int = _decode_int32(packet, offset)
		var previous: Dictionary = _previous_states.get(entity_id, {}) as Dictionary
		var state: Dictionary = decompress_state_delta(packet, offset, previous)

		if state.has("_read_size"):
			offset += state["_read_size"] as int
			state.erase("_read_size")

		states[entity_id] = state
		_previous_states[entity_id] = state

	states["_snapshot_sequence"] = snapshot_seq
	states_received.emit(states)

# endregion

# =============================================================================
# region - Utility
# =============================================================================

## Clears all cached state (call on disconnect)
func clear_state() -> void:
	_input_buffer.clear()
	_input_sequence = 0
	_peer_ack_sequences.clear()
	_previous_states.clear()
	_pending_updates.clear()
	_snapshot_history.clear()
	_snapshot_sequence = 0
	_bytes_this_second = 0
	current_bandwidth = 0


## Returns estimated packet size for given entity count
func estimate_packet_size(entity_count: int, use_delta: bool) -> int:
	var base_size: int = 6  # Header
	var per_entity: int = 13 if use_delta else 21  # Approximate
	return base_size + (per_entity * entity_count)

# endregion
