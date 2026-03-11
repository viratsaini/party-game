## NetworkUIOptimizer - UI state synchronization optimization for BattleZone Party
##
## Optimizes network UI updates through:
## - UI state sync only when changed (dirty flag system)
## - Delta compression for UI updates
## - Batch UI updates
## - Predictive UI updates
## - Rollback on server mismatch
##
## Usage:
##   NetworkUIOptimizer.sync_ui_state("health", player_id, health_value)
##   NetworkUIOptimizer.predict_ui_change("ammo", -1)
##   NetworkUIOptimizer.rollback_prediction("ammo")
class_name NetworkUIOptimizer
extends Node


# =============================================================================
# region - Signals
# =============================================================================

## Emitted when UI state is synchronized
signal ui_state_synced(state_type: String, player_id: int, value: Variant)

## Emitted when prediction is confirmed
signal prediction_confirmed(state_type: String)

## Emitted when prediction needs rollback
signal prediction_rolled_back(state_type: String, predicted: Variant, actual: Variant)

## Emitted when batch update is sent
signal batch_sent(state_count: int, byte_size: int)

## Emitted on bandwidth update
signal bandwidth_changed(bytes_per_second: int)

# endregion


# =============================================================================
# region - Enums and Constants
# =============================================================================

## UI state types for synchronization
enum UIStateType {
	HEALTH,
	AMMO,
	SCORE,
	KILLS,
	DEATHS,
	POWERUP,
	STATUS,
	OBJECTIVE,
	TIMER,
	CUSTOM
}

## Priority levels for UI updates
enum UpdatePriority {
	CRITICAL,   ## Must sync immediately (health, death)
	HIGH,       ## Sync soon (score, kills)
	MEDIUM,     ## Can batch (ammo, powerups)
	LOW         ## Batch heavily (cosmetic, non-gameplay)
}

## Sync intervals per priority (in frames)
const SYNC_INTERVALS: Dictionary = {
	UpdatePriority.CRITICAL: 1,    ## Every frame
	UpdatePriority.HIGH: 3,        ## Every 3 frames (~50ms)
	UpdatePriority.MEDIUM: 6,      ## Every 6 frames (~100ms)
	UpdatePriority.LOW: 15         ## Every 15 frames (~250ms)
}

## Maximum batch size in bytes
const MAX_BATCH_SIZE: int = 512

## Maximum pending predictions before forcing sync
const MAX_PENDING_PREDICTIONS: int = 16

## Prediction timeout in seconds
const PREDICTION_TIMEOUT: float = 1.0

## Compression threshold (don't compress smaller than this)
const COMPRESSION_THRESHOLD: int = 32

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

## Whether optimization is enabled
var enabled: bool = true

## Current UI states per player
var _ui_states: Dictionary = {}  # player_id -> { state_type -> { value, dirty, priority, last_sync } }

## Previous states for delta compression
var _previous_states: Dictionary = {}  # player_id -> { state_type -> value }

## Pending updates to batch
var _pending_updates: Array[Dictionary] = []

## Predictions awaiting confirmation
var _pending_predictions: Dictionary = {}  # state_type -> { predicted_value, timestamp, original_value }

## Frame counter for sync timing
var _frame_counter: int = 0

## Bandwidth tracking
var _bytes_sent_this_second: int = 0
var _bandwidth_timer: float = 0.0
var _current_bandwidth: int = 0

## Local player ID
var _local_player_id: int = 0

## Statistics
var _updates_sent: int = 0
var _updates_batched: int = 0
var _predictions_made: int = 0
var _predictions_confirmed: int = 0
var _predictions_rolled_back: int = 0
var _bytes_saved_compression: int = 0

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	# Get local player ID from multiplayer
	if multiplayer.has_multiplayer_peer():
		_local_player_id = multiplayer.get_unique_id()


func _process(delta: float) -> void:
	if not enabled:
		return

	_frame_counter += 1
	_update_bandwidth_tracking(delta)
	_process_sync_queue()
	_check_prediction_timeouts(delta)


func _update_bandwidth_tracking(delta: float) -> void:
	_bandwidth_timer += delta
	if _bandwidth_timer >= 1.0:
		_bandwidth_timer -= 1.0
		_current_bandwidth = _bytes_sent_this_second
		_bytes_sent_this_second = 0
		bandwidth_changed.emit(_current_bandwidth)

# endregion


# =============================================================================
# region - State Registration
# =============================================================================

## Registers a UI state for a player
func register_ui_state(
	player_id: int,
	state_type: UIStateType,
	initial_value: Variant,
	priority: UpdatePriority = UpdatePriority.MEDIUM
) -> void:
	if not _ui_states.has(player_id):
		_ui_states[player_id] = {}
		_previous_states[player_id] = {}

	_ui_states[player_id][state_type] = {
		"value": initial_value,
		"dirty": false,
		"priority": priority,
		"last_sync": 0
	}

	_previous_states[player_id][state_type] = initial_value


## Registers all standard UI states for a player
func register_player(player_id: int) -> void:
	register_ui_state(player_id, UIStateType.HEALTH, 100, UpdatePriority.CRITICAL)
	register_ui_state(player_id, UIStateType.AMMO, 30, UpdatePriority.HIGH)
	register_ui_state(player_id, UIStateType.SCORE, 0, UpdatePriority.MEDIUM)
	register_ui_state(player_id, UIStateType.KILLS, 0, UpdatePriority.MEDIUM)
	register_ui_state(player_id, UIStateType.DEATHS, 0, UpdatePriority.MEDIUM)
	register_ui_state(player_id, UIStateType.POWERUP, "", UpdatePriority.HIGH)
	register_ui_state(player_id, UIStateType.STATUS, "", UpdatePriority.LOW)


## Unregisters a player's UI states
func unregister_player(player_id: int) -> void:
	_ui_states.erase(player_id)
	_previous_states.erase(player_id)

# endregion


# =============================================================================
# region - State Updates
# =============================================================================

## Updates a UI state (marks as dirty for sync)
func set_ui_state(player_id: int, state_type: UIStateType, value: Variant) -> void:
	if not _ui_states.has(player_id):
		push_warning("[NetworkUIOptimizer] Player %d not registered" % player_id)
		return

	if not _ui_states[player_id].has(state_type):
		push_warning("[NetworkUIOptimizer] State type %d not registered for player %d" % [state_type, player_id])
		return

	var state: Dictionary = _ui_states[player_id][state_type]
	var old_value: Variant = state["value"]

	# Only mark dirty if value actually changed
	if old_value != value:
		state["value"] = value
		state["dirty"] = true

		# Apply locally immediately
		ui_state_synced.emit(UIStateType.keys()[state_type], player_id, value)


## Gets current UI state value
func get_ui_state(player_id: int, state_type: UIStateType) -> Variant:
	if not _ui_states.has(player_id):
		return null
	if not _ui_states[player_id].has(state_type):
		return null

	return _ui_states[player_id][state_type]["value"]


## Syncs a UI state immediately (bypasses batching)
func sync_ui_state_immediate(player_id: int, state_type: UIStateType, value: Variant) -> void:
	set_ui_state(player_id, state_type, value)

	if multiplayer.is_server():
		_send_state_update(player_id, state_type, value, true)
	else:
		_rpc_request_state_update.rpc_id(1, player_id, state_type, value)

# endregion


# =============================================================================
# region - Prediction System
# =============================================================================

## Creates a prediction for a UI state (client-side)
func predict_ui_change(state_type: UIStateType, delta_value: Variant) -> void:
	if not _ui_states.has(_local_player_id):
		return

	if not _ui_states[_local_player_id].has(state_type):
		return

	var current_value: Variant = _ui_states[_local_player_id][state_type]["value"]
	var predicted_value: Variant

	# Apply delta based on type
	if current_value is int and delta_value is int:
		predicted_value = current_value + delta_value
	elif current_value is float and (delta_value is float or delta_value is int):
		predicted_value = current_value + delta_value
	else:
		predicted_value = delta_value

	# Store prediction
	_pending_predictions[state_type] = {
		"predicted_value": predicted_value,
		"original_value": current_value,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}

	# Apply prediction locally
	_ui_states[_local_player_id][state_type]["value"] = predicted_value
	ui_state_synced.emit(UIStateType.keys()[state_type], _local_player_id, predicted_value)

	_predictions_made += 1


## Confirms a prediction matches server state
func confirm_prediction(state_type: UIStateType, server_value: Variant) -> void:
	if not _pending_predictions.has(state_type):
		return

	var prediction: Dictionary = _pending_predictions[state_type]
	var predicted_value: Variant = prediction["predicted_value"]

	if _values_match(predicted_value, server_value):
		# Prediction was correct
		_pending_predictions.erase(state_type)
		prediction_confirmed.emit(UIStateType.keys()[state_type])
		_predictions_confirmed += 1
	else:
		# Prediction was wrong - rollback
		rollback_prediction(state_type, server_value)


## Rolls back a prediction to server state
func rollback_prediction(state_type: UIStateType, server_value: Variant = null) -> void:
	if not _pending_predictions.has(state_type):
		return

	var prediction: Dictionary = _pending_predictions[state_type]
	var rollback_value: Variant = server_value if server_value != null else prediction["original_value"]

	# Apply rollback
	if _ui_states.has(_local_player_id) and _ui_states[_local_player_id].has(state_type):
		_ui_states[_local_player_id][state_type]["value"] = rollback_value

	prediction_rolled_back.emit(
		UIStateType.keys()[state_type],
		prediction["predicted_value"],
		rollback_value
	)

	_pending_predictions.erase(state_type)
	_predictions_rolled_back += 1

	# Emit corrected state
	ui_state_synced.emit(UIStateType.keys()[state_type], _local_player_id, rollback_value)


func _check_prediction_timeouts(delta: float) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var to_rollback: Array[int] = []  # UIStateType values

	for state_type: int in _pending_predictions:
		var prediction: Dictionary = _pending_predictions[state_type]
		if current_time - prediction["timestamp"] > PREDICTION_TIMEOUT:
			to_rollback.append(state_type)

	for state_type: int in to_rollback:
		rollback_prediction(state_type as UIStateType)
		push_warning("[NetworkUIOptimizer] Prediction timeout for state %s" % UIStateType.keys()[state_type])

# endregion


# =============================================================================
# region - Batching & Sync
# =============================================================================

func _process_sync_queue() -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	var updates_to_send: Array[Dictionary] = []
	var total_size: int = 0

	# Collect dirty states that are due for sync
	for player_id: int in _ui_states:
		var player_states: Dictionary = _ui_states[player_id]

		for state_type: int in player_states:
			var state: Dictionary = player_states[state_type]

			if not state["dirty"]:
				continue

			var priority: int = state["priority"]
			var sync_interval: int = SYNC_INTERVALS[priority]

			# Check if it's time to sync this priority level
			if _frame_counter % sync_interval != 0 and priority != UpdatePriority.CRITICAL:
				continue

			# Create update packet
			var update := _create_update_packet(player_id, state_type, state["value"])
			var update_size: int = update["data"].size()

			# Check batch size limit
			if total_size + update_size > MAX_BATCH_SIZE:
				# Send current batch
				if not updates_to_send.is_empty():
					_send_batch(updates_to_send)
					updates_to_send.clear()
					total_size = 0

			updates_to_send.append(update)
			total_size += update_size
			state["dirty"] = false
			state["last_sync"] = _frame_counter
			_updates_batched += 1

	# Send remaining updates
	if not updates_to_send.is_empty():
		_send_batch(updates_to_send)


func _create_update_packet(player_id: int, state_type: int, value: Variant) -> Dictionary:
	var data := PackedByteArray()

	# Header: player_id (2 bytes) + state_type (1 byte)
	data.append(player_id & 0xFF)
	data.append((player_id >> 8) & 0xFF)
	data.append(state_type)

	# Encode value based on type
	var value_bytes := _encode_value(value)

	# Use delta compression if possible
	var previous: Variant = null
	if _previous_states.has(player_id) and _previous_states[player_id].has(state_type):
		previous = _previous_states[player_id][state_type]

	if previous != null and value_bytes.size() >= COMPRESSION_THRESHOLD:
		var delta_bytes := _encode_delta(previous, value)
		if delta_bytes.size() < value_bytes.size():
			# Use delta encoding
			data.append(1)  # Delta flag
			data.append_array(delta_bytes)
			_bytes_saved_compression += value_bytes.size() - delta_bytes.size()
		else:
			# Use full value
			data.append(0)  # Full flag
			data.append_array(value_bytes)
	else:
		data.append(0)  # Full flag
		data.append_array(value_bytes)

	# Update previous state
	if _previous_states.has(player_id):
		_previous_states[player_id][state_type] = value

	return {
		"player_id": player_id,
		"state_type": state_type,
		"value": value,
		"data": data
	}


func _send_batch(updates: Array[Dictionary]) -> void:
	var batch_data := PackedByteArray()

	# Header: update count (1 byte)
	batch_data.append(updates.size())

	# Append all updates
	for update: Dictionary in updates:
		var data: PackedByteArray = update["data"]
		batch_data.append(data.size())  # Length prefix
		batch_data.append_array(data)

	# Send via RPC
	if multiplayer.is_server():
		_rpc_batch_update.rpc(batch_data)
	else:
		_rpc_batch_update.rpc_id(1, batch_data)

	_bytes_sent_this_second += batch_data.size()
	_updates_sent += updates.size()

	batch_sent.emit(updates.size(), batch_data.size())


func _send_state_update(player_id: int, state_type: UIStateType, value: Variant, immediate: bool) -> void:
	var update := _create_update_packet(player_id, state_type, value)

	if immediate:
		_send_batch([update])
	else:
		_pending_updates.append(update)

# endregion


# =============================================================================
# region - Value Encoding
# =============================================================================

func _encode_value(value: Variant) -> PackedByteArray:
	var data := PackedByteArray()

	match typeof(value):
		TYPE_INT:
			data.append(TYPE_INT)
			data.append_array(_encode_int32(value as int))
		TYPE_FLOAT:
			data.append(TYPE_FLOAT)
			data.append_array(_encode_float(value as float))
		TYPE_STRING:
			data.append(TYPE_STRING)
			var str_bytes := (value as String).to_utf8_buffer()
			data.append(str_bytes.size())
			data.append_array(str_bytes)
		TYPE_BOOL:
			data.append(TYPE_BOOL)
			data.append(1 if value else 0)
		TYPE_VECTOR2:
			data.append(TYPE_VECTOR2)
			var v: Vector2 = value as Vector2
			data.append_array(_encode_float(v.x))
			data.append_array(_encode_float(v.y))
		_:
			# Fallback to JSON
			data.append(255)  # Custom type marker
			var json_str := JSON.stringify(value)
			var json_bytes := json_str.to_utf8_buffer()
			data.append_array(_encode_int32(json_bytes.size()))
			data.append_array(json_bytes)

	return data


func _decode_value(data: PackedByteArray, offset: int) -> Dictionary:
	if offset >= data.size():
		return {"value": null, "size": 0}

	var type_id: int = data[offset]
	var read_size: int = 1

	match type_id:
		TYPE_INT:
			var value: int = _decode_int32(data, offset + 1)
			return {"value": value, "size": 5}
		TYPE_FLOAT:
			var value: float = _decode_float(data, offset + 1)
			return {"value": value, "size": 5}
		TYPE_STRING:
			var str_len: int = data[offset + 1]
			var str_bytes := data.slice(offset + 2, offset + 2 + str_len)
			return {"value": str_bytes.get_string_from_utf8(), "size": 2 + str_len}
		TYPE_BOOL:
			return {"value": data[offset + 1] != 0, "size": 2}
		TYPE_VECTOR2:
			var x: float = _decode_float(data, offset + 1)
			var y: float = _decode_float(data, offset + 5)
			return {"value": Vector2(x, y), "size": 9}
		255:  # Custom JSON
			var json_len: int = _decode_int32(data, offset + 1)
			var json_bytes := data.slice(offset + 5, offset + 5 + json_len)
			var json := JSON.new()
			var err := json.parse(json_bytes.get_string_from_utf8())
			return {"value": json.data if err == OK else null, "size": 5 + json_len}
		_:
			return {"value": null, "size": 0}


func _encode_delta(previous: Variant, current: Variant) -> PackedByteArray:
	var data := PackedByteArray()

	if previous is int and current is int:
		var delta: int = (current as int) - (previous as int)
		# Use variable-length encoding for small deltas
		if delta >= -128 and delta <= 127:
			data.append(1)  # 1 byte delta
			data.append(delta + 128)  # Shift to unsigned
		else:
			data.append(4)  # 4 byte delta
			data.append_array(_encode_int32(delta))
	elif previous is float and current is float:
		var delta: float = (current as float) - (previous as float)
		data.append(4)
		data.append_array(_encode_float(delta))
	else:
		# Fallback to full encoding
		return _encode_value(current)

	return data


func _encode_int32(value: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(4)
	data.encode_s32(0, value)
	return data


func _decode_int32(data: PackedByteArray, offset: int) -> int:
	if data.size() < offset + 4:
		return 0
	return data.decode_s32(offset)


func _encode_float(value: float) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(4)
	data.encode_float(0, value)
	return data


func _decode_float(data: PackedByteArray, offset: int) -> float:
	if data.size() < offset + 4:
		return 0.0
	return data.decode_float(offset)


func _values_match(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false

	if a is float and b is float:
		return absf((a as float) - (b as float)) < 0.001
	else:
		return a == b

# endregion


# =============================================================================
# region - RPC Handlers
# =============================================================================

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_batch_update(batch_data: PackedByteArray) -> void:
	if batch_data.size() < 1:
		return

	var update_count: int = batch_data[0]
	var offset: int = 1

	for i in range(update_count):
		if offset >= batch_data.size():
			break

		var packet_len: int = batch_data[offset]
		offset += 1

		if offset + packet_len > batch_data.size():
			break

		var packet := batch_data.slice(offset, offset + packet_len)
		_process_update_packet(packet)
		offset += packet_len


func _process_update_packet(packet: PackedByteArray) -> void:
	if packet.size() < 4:
		return

	var player_id: int = packet[0] | (packet[1] << 8)
	var state_type: int = packet[2]
	var is_delta: bool = packet[3] == 1

	var value_offset: int = 4
	var decoded: Dictionary

	if is_delta:
		# Apply delta to previous value
		var previous: Variant = null
		if _previous_states.has(player_id) and _previous_states[player_id].has(state_type):
			previous = _previous_states[player_id][state_type]

		if previous != null:
			decoded = _decode_delta(packet, value_offset, previous)
		else:
			return  # Can't apply delta without previous
	else:
		decoded = _decode_value(packet, value_offset)

	var value: Variant = decoded["value"]
	if value == null:
		return

	# Update state
	if not _ui_states.has(player_id):
		_ui_states[player_id] = {}
		_previous_states[player_id] = {}

	if not _ui_states[player_id].has(state_type):
		_ui_states[player_id][state_type] = {
			"value": value,
			"dirty": false,
			"priority": UpdatePriority.MEDIUM,
			"last_sync": _frame_counter
		}
	else:
		_ui_states[player_id][state_type]["value"] = value

	_previous_states[player_id][state_type] = value

	# Confirm prediction if this is for local player
	if player_id == _local_player_id and _pending_predictions.has(state_type):
		confirm_prediction(state_type as UIStateType, value)
	else:
		ui_state_synced.emit(UIStateType.keys()[state_type], player_id, value)


func _decode_delta(packet: PackedByteArray, offset: int, previous: Variant) -> Dictionary:
	if offset >= packet.size():
		return {"value": null, "size": 0}

	var delta_size: int = packet[offset]
	offset += 1

	if previous is int:
		if delta_size == 1:
			var delta: int = packet[offset] - 128
			return {"value": (previous as int) + delta, "size": 2}
		else:
			var delta: int = _decode_int32(packet, offset)
			return {"value": (previous as int) + delta, "size": 5}
	elif previous is float:
		var delta: float = _decode_float(packet, offset)
		return {"value": (previous as float) + delta, "size": 5}

	return {"value": null, "size": 0}


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_state_update(player_id: int, state_type: int, value: Variant) -> void:
	if not multiplayer.is_server():
		return

	# Validate and apply state change
	set_ui_state(player_id, state_type as UIStateType, value)

	# Broadcast to all clients
	var update := _create_update_packet(player_id, state_type, value)
	_send_batch([update])

# endregion


# =============================================================================
# region - Statistics
# =============================================================================

## Gets network UI optimization statistics
func get_statistics() -> Dictionary:
	return {
		"updates_sent": _updates_sent,
		"updates_batched": _updates_batched,
		"predictions_made": _predictions_made,
		"predictions_confirmed": _predictions_confirmed,
		"predictions_rolled_back": _predictions_rolled_back,
		"prediction_accuracy": float(_predictions_confirmed) / float(_predictions_made) if _predictions_made > 0 else 1.0,
		"bytes_saved_compression": _bytes_saved_compression,
		"current_bandwidth_bps": _current_bandwidth,
		"pending_predictions": _pending_predictions.size(),
		"registered_players": _ui_states.size()
	}


## Resets statistics
func reset_statistics() -> void:
	_updates_sent = 0
	_updates_batched = 0
	_predictions_made = 0
	_predictions_confirmed = 0
	_predictions_rolled_back = 0
	_bytes_saved_compression = 0

# endregion
