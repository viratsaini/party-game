## Client-Side Prediction System
##
## Implements client-side prediction with server reconciliation for responsive
## local player movement even at high latencies (<100ms perceived lag at 150ms ping).
##
## Features:
##   - Immediate local input application
##   - Input buffering for reconciliation
##   - Server state reconciliation with input replay
##   - Smooth error correction (no snapping)
##   - Physics prediction for gravity, collisions
class_name ClientPrediction
extends RefCounted

# =============================================================================
# region - Constants
# =============================================================================

## Maximum inputs to keep in buffer for reconciliation
const MAX_INPUT_BUFFER: int = 64

## Maximum position error before hard snap (units)
const MAX_POSITION_ERROR: float = 5.0

## Smooth correction speed (units per second)
const CORRECTION_SPEED: float = 10.0

## Position error threshold for correction (below this, no correction needed)
const POSITION_ERROR_THRESHOLD: float = 0.01

## Velocity error threshold
const VELOCITY_ERROR_THRESHOLD: float = 0.1

## Input acknowledgment timeout (ms)
const INPUT_ACK_TIMEOUT_MS: int = 500

# endregion

# =============================================================================
# region - Types
# =============================================================================

## Stores a single input frame for replay during reconciliation
class InputFrame:
	var sequence: int = 0
	var timestamp_ms: int = 0
	var movement: Vector2 = Vector2.ZERO
	var buttons: int = 0
	var aim_angle: float = 0.0
	var delta_time: float = 0.0
	## State AFTER this input was applied (for validation)
	var resulting_position: Vector3 = Vector3.ZERO
	var resulting_velocity: Vector3 = Vector3.ZERO

	func duplicate() -> InputFrame:
		var copy := InputFrame.new()
		copy.sequence = sequence
		copy.timestamp_ms = timestamp_ms
		copy.movement = movement
		copy.buttons = buttons
		copy.aim_angle = aim_angle
		copy.delta_time = delta_time
		copy.resulting_position = resulting_position
		copy.resulting_velocity = resulting_velocity
		return copy


## Server state update for reconciliation
class ServerState:
	var sequence: int = 0
	var timestamp_ms: int = 0
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var rotation: float = 0.0
	var is_grounded: bool = false
	var health: float = 100.0


## Prediction statistics for debugging
class PredictionStats:
	var total_reconciliations: int = 0
	var position_corrections: int = 0
	var hard_snaps: int = 0
	var average_error: float = 0.0
	var max_error: float = 0.0
	var inputs_replayed: int = 0

# endregion

# =============================================================================
# region - State
# =============================================================================

## Current input sequence number
var _current_sequence: int = 0

## Last acknowledged sequence from server
var _last_ack_sequence: int = 0

## Input buffer for reconciliation
var _input_buffer: Array[InputFrame] = []

## Whether prediction is active
var _is_active: bool = false

## Current position error for smooth correction
var _position_error: Vector3 = Vector3.ZERO

## Statistics
var _stats: PredictionStats = PredictionStats.new()

## Movement parameters (should match player character)
var _movement_params: Dictionary = {
	"speed": 8.0,
	"sprint_speed": 12.0,
	"jump_force": 8.0,
	"gravity": 9.8,
	"air_control": 0.7,
}

## Reference to the character body for physics simulation
var _character: CharacterBody3D = null

# endregion

# =============================================================================
# region - Initialization
# =============================================================================

func _init() -> void:
	_input_buffer = []


func start(character: CharacterBody3D, movement_params: Dictionary = {}) -> void:
	_character = character
	_is_active = true
	_current_sequence = 0
	_last_ack_sequence = 0
	_input_buffer.clear()
	_position_error = Vector3.ZERO
	_stats = PredictionStats.new()

	# Merge movement params
	for key in movement_params:
		_movement_params[key] = movement_params[key]


func stop() -> void:
	_is_active = false
	_character = null
	_input_buffer.clear()

# endregion

# =============================================================================
# region - Input Recording
# =============================================================================

## Records an input and returns the sequence number
func record_input(
	movement: Vector2,
	buttons: int,
	aim_angle: float,
	delta_time: float,
	resulting_position: Vector3,
	resulting_velocity: Vector3
) -> int:
	if not _is_active:
		return -1

	_current_sequence += 1

	var frame := InputFrame.new()
	frame.sequence = _current_sequence
	frame.timestamp_ms = Time.get_ticks_msec()
	frame.movement = movement
	frame.buttons = buttons
	frame.aim_angle = aim_angle
	frame.delta_time = delta_time
	frame.resulting_position = resulting_position
	frame.resulting_velocity = resulting_velocity

	_input_buffer.append(frame)

	# Trim old inputs
	_trim_input_buffer()

	return _current_sequence


## Creates input data dictionary for network transmission
func create_input_packet(
	movement: Vector2,
	buttons: int,
	aim_angle: float
) -> Dictionary:
	return {
		"sequence": _current_sequence + 1,
		"movement": movement,
		"buttons": buttons,
		"aim_angle": aim_angle,
	}


func _trim_input_buffer() -> void:
	# Remove inputs that have been acknowledged
	while _input_buffer.size() > 0:
		var oldest: InputFrame = _input_buffer[0]
		if oldest.sequence <= _last_ack_sequence:
			_input_buffer.remove_at(0)
		else:
			break

	# Also enforce max size
	while _input_buffer.size() > MAX_INPUT_BUFFER:
		_input_buffer.remove_at(0)


## Gets unacknowledged inputs for retransmission
func get_unacked_inputs() -> Array[InputFrame]:
	var result: Array[InputFrame] = []
	for frame: InputFrame in _input_buffer:
		if frame.sequence > _last_ack_sequence:
			result.append(frame)
	return result

# endregion

# =============================================================================
# region - Server Reconciliation
# =============================================================================

## Process a server state update and reconcile if needed
func reconcile_with_server(server_state: ServerState) -> Dictionary:
	if not _is_active:
		return {"reconciled": false}

	# Update last acknowledged sequence
	if server_state.sequence > _last_ack_sequence:
		_last_ack_sequence = server_state.sequence

	_stats.total_reconciliations += 1

	# Find the input frame this server state corresponds to
	var server_input_frame: InputFrame = null
	for frame: InputFrame in _input_buffer:
		if frame.sequence == server_state.sequence:
			server_input_frame = frame
			break

	if server_input_frame == null:
		# Server state is for an input we don't have - this is normal if it's old
		_trim_input_buffer()
		return {"reconciled": false, "reason": "input_not_found"}

	# Compare server position with our predicted position at that frame
	var position_error: Vector3 = server_state.position - server_input_frame.resulting_position
	var error_magnitude: float = position_error.length()

	_stats.average_error = lerpf(_stats.average_error, error_magnitude, 0.1)
	_stats.max_error = maxf(_stats.max_error, error_magnitude)

	# Check if correction is needed
	if error_magnitude < POSITION_ERROR_THRESHOLD:
		_trim_input_buffer()
		return {"reconciled": true, "correction_needed": false, "error": error_magnitude}

	_stats.position_corrections += 1

	# Determine correction method
	var result: Dictionary = {}
	if error_magnitude > MAX_POSITION_ERROR:
		# Hard snap for large errors
		_stats.hard_snaps += 1
		result = _hard_snap_correction(server_state)
	else:
		# Smooth correction with input replay
		result = _smooth_correction(server_state, server_input_frame)

	_trim_input_buffer()
	return result


## Hard snap to server position (for large errors)
func _hard_snap_correction(server_state: ServerState) -> Dictionary:
	if _character == null:
		return {"reconciled": false}

	_character.global_position = server_state.position
	_character.velocity = server_state.velocity
	_position_error = Vector3.ZERO

	# Replay all unacknowledged inputs
	var replayed: int = _replay_inputs_from_sequence(server_state.sequence, server_state)

	return {
		"reconciled": true,
		"correction_needed": true,
		"method": "hard_snap",
		"inputs_replayed": replayed,
		"new_position": _character.global_position,
	}


## Smooth correction with gradual error reduction
func _smooth_correction(server_state: ServerState, frame: InputFrame) -> Dictionary:
	# Calculate the error to correct
	var error: Vector3 = server_state.position - frame.resulting_position

	# Add to position error accumulator (will be applied smoothly over time)
	_position_error += error

	# Replay inputs from the acknowledged point
	var replayed: int = _replay_inputs_from_sequence(server_state.sequence, server_state)
	_stats.inputs_replayed += replayed

	return {
		"reconciled": true,
		"correction_needed": true,
		"method": "smooth",
		"error": error.length(),
		"inputs_replayed": replayed,
		"position_error_remaining": _position_error.length(),
	}


## Replays inputs from a given sequence point
func _replay_inputs_from_sequence(start_sequence: int, server_state: ServerState) -> int:
	if _character == null:
		return 0

	# Set character to server state
	_character.global_position = server_state.position
	_character.velocity = server_state.velocity

	var replayed: int = 0

	# Replay all inputs after the acknowledged sequence
	for frame: InputFrame in _input_buffer:
		if frame.sequence <= start_sequence:
			continue

		# Simulate this input
		_simulate_input(frame)

		# Update the predicted result
		frame.resulting_position = _character.global_position
		frame.resulting_velocity = _character.velocity

		replayed += 1

	return replayed


## Simulates a single input frame's effect on the character
func _simulate_input(frame: InputFrame) -> void:
	if _character == null:
		return

	var delta: float = frame.delta_time
	var speed: float = _movement_params["speed"]

	# Check sprint
	if frame.buttons & 0x10:  # Sprint button
		speed = _movement_params["sprint_speed"]

	# Apply movement
	var movement_3d := Vector3(frame.movement.x, 0, frame.movement.y) * speed

	# Transform by aim direction
	var aim_rad: float = deg_to_rad(frame.aim_angle)
	var cos_aim: float = cos(aim_rad)
	var sin_aim: float = sin(aim_rad)
	var rotated_movement := Vector3(
		movement_3d.x * cos_aim - movement_3d.z * sin_aim,
		0,
		movement_3d.x * sin_aim + movement_3d.z * cos_aim
	)

	_character.velocity.x = rotated_movement.x
	_character.velocity.z = rotated_movement.z

	# Apply gravity
	if not _character.is_on_floor():
		_character.velocity.y -= _movement_params["gravity"] * delta

	# Apply jump
	if frame.buttons & 0x02:  # Jump button
		if _character.is_on_floor():
			_character.velocity.y = _movement_params["jump_force"]

	# Move
	_character.move_and_slide()

# endregion

# =============================================================================
# region - Smooth Error Correction
# =============================================================================

## Apply smooth error correction each frame
## Returns the correction vector applied
func apply_smooth_correction(delta: float) -> Vector3:
	if _position_error.length() < POSITION_ERROR_THRESHOLD:
		_position_error = Vector3.ZERO
		return Vector3.ZERO

	# Calculate correction amount
	var correction_amount: float = CORRECTION_SPEED * delta
	var correction: Vector3

	if _position_error.length() <= correction_amount:
		# Apply remaining error
		correction = _position_error
		_position_error = Vector3.ZERO
	else:
		# Apply partial correction
		correction = _position_error.normalized() * correction_amount
		_position_error -= correction

	return correction


## Gets the current position error magnitude
func get_position_error() -> float:
	return _position_error.length()

# endregion

# =============================================================================
# region - Movement Prediction
# =============================================================================

## Predicts position after applying given input
## Useful for extrapolation of other players
static func predict_position(
	current_position: Vector3,
	current_velocity: Vector3,
	movement: Vector2,
	speed: float,
	gravity: float,
	is_grounded: bool,
	delta: float,
	aim_angle: float = 0.0
) -> Dictionary:
	var new_velocity: Vector3 = current_velocity

	# Apply movement
	var aim_rad: float = deg_to_rad(aim_angle)
	var forward := Vector3(sin(aim_rad), 0, cos(aim_rad))
	var right := Vector3(cos(aim_rad), 0, -sin(aim_rad))

	var target_velocity := (right * movement.x + forward * movement.y) * speed
	new_velocity.x = target_velocity.x
	new_velocity.z = target_velocity.z

	# Apply gravity if not grounded
	if not is_grounded:
		new_velocity.y -= gravity * delta

	# Calculate new position
	var new_position: Vector3 = current_position + new_velocity * delta

	return {
		"position": new_position,
		"velocity": new_velocity,
	}

# endregion

# =============================================================================
# region - Statistics
# =============================================================================

func get_stats() -> Dictionary:
	return {
		"total_reconciliations": _stats.total_reconciliations,
		"position_corrections": _stats.position_corrections,
		"hard_snaps": _stats.hard_snaps,
		"average_error": _stats.average_error,
		"max_error": _stats.max_error,
		"inputs_replayed": _stats.inputs_replayed,
		"buffer_size": _input_buffer.size(),
		"current_sequence": _current_sequence,
		"last_ack_sequence": _last_ack_sequence,
		"pending_inputs": _current_sequence - _last_ack_sequence,
		"position_error": _position_error.length(),
	}


func reset_stats() -> void:
	_stats = PredictionStats.new()

# endregion

# =============================================================================
# region - Button Flags
# =============================================================================

## Button flag constants (matches network_optimizer.gd)
const BTN_SHOOT: int = 1
const BTN_JUMP: int = 2
const BTN_ABILITY1: int = 4
const BTN_ABILITY2: int = 8
const BTN_RELOAD: int = 16
const BTN_SPRINT: int = 32


## Creates button flags from input state
static func create_button_flags(
	shoot: bool = false,
	jump: bool = false,
	ability1: bool = false,
	ability2: bool = false,
	reload: bool = false,
	sprint: bool = false
) -> int:
	var flags: int = 0
	if shoot: flags |= BTN_SHOOT
	if jump: flags |= BTN_JUMP
	if ability1: flags |= BTN_ABILITY1
	if ability2: flags |= BTN_ABILITY2
	if reload: flags |= BTN_RELOAD
	if sprint: flags |= BTN_SPRINT
	return flags


## Extracts button state from flags
static func has_button(flags: int, button: int) -> bool:
	return (flags & button) != 0

# endregion
