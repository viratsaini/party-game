## MovingPlatform - Versatile moving platform for maps.
##
## Supports multiple movement patterns:
##   - LINEAR: Moves between two points
##   - CIRCULAR: Rotates around a center point
##   - WAYPOINTS: Follows a path of multiple points
##   - ELEVATOR: Vertical movement with stop delays
##
## Players standing on the platform move with it via velocity inheritance.
class_name MovingPlatform
extends AnimatableBody3D


# region -- Enums

enum MovementType {
	LINEAR,
	CIRCULAR,
	WAYPOINTS,
	ELEVATOR,
}

enum EaseType {
	LINEAR,
	SMOOTH,
	BOUNCE,
	ELASTIC,
}

# endregion


# region -- Exports

## The type of movement pattern
@export var movement_type: MovementType = MovementType.LINEAR

## Movement speed (units per second or degrees per second for circular)
@export var speed: float = 3.0

## Easing type for movement
@export var ease_type: EaseType = EaseType.SMOOTH

## For LINEAR: end position relative to start
@export var end_offset: Vector3 = Vector3(0, 5, 0)

## For CIRCULAR: radius of rotation
@export var circular_radius: float = 5.0

## For CIRCULAR: axis of rotation (normalized)
@export var circular_axis: Vector3 = Vector3.UP

## For ELEVATOR: stop duration at each end
@export var stop_duration: float = 1.5

## For WAYPOINTS: list of position offsets relative to start
@export var waypoints: Array[Vector3] = []

## Should the platform wait at each point?
@export var pause_at_points: bool = false

## Duration to pause at each point
@export var pause_duration: float = 0.5

## Should the platform loop back to start or ping-pong?
@export var loop_mode: bool = true  # true = loop, false = ping-pong

## Optional: link to a trigger that activates this platform
@export var trigger_activated: bool = false

## Visual mesh for animation effects
@export var platform_mesh: NodePath = ""

# endregion


# region -- State

var _origin: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _direction: int = 1  # 1 = forward, -1 = backward (for ping-pong)
var _current_waypoint_index: int = 0
var _target_waypoint_index: int = 1
var _is_paused: bool = false
var _pause_timer: float = 0.0
var _is_active: bool = true
var _previous_position: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO

var _mesh_node: MeshInstance3D = null

# endregion


# region -- Lifecycle

func _ready() -> void:
	_origin = global_position
	_previous_position = global_position

	# Cache mesh reference
	if platform_mesh:
		_mesh_node = get_node_or_null(platform_mesh) as MeshInstance3D

	# Set up waypoints if empty
	if movement_type == MovementType.WAYPOINTS and waypoints.is_empty():
		waypoints = [Vector3.ZERO, end_offset]

	# For LINEAR, add implicit waypoints
	if movement_type == MovementType.LINEAR:
		waypoints = [Vector3.ZERO, end_offset]

	_is_active = not trigger_activated


func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	if not _is_server():
		return

	_previous_position = global_position

	# Handle pause state
	if _is_paused:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_is_paused = false
		return

	match movement_type:
		MovementType.LINEAR:
			_process_linear(delta)
		MovementType.CIRCULAR:
			_process_circular(delta)
		MovementType.WAYPOINTS:
			_process_waypoints(delta)
		MovementType.ELEVATOR:
			_process_elevator(delta)

	# Calculate velocity for player movement inheritance
	_velocity = (global_position - _previous_position) / delta

# endregion


# region -- Movement Processors

func _process_linear(delta: float) -> void:
	_time += delta * speed * _direction

	var duration := end_offset.length() / speed
	var progress := clampf(_time / duration, 0.0, 1.0)
	progress = _apply_easing(progress)

	global_position = _origin + end_offset * progress

	# Check for direction change (ping-pong)
	if not loop_mode:
		if progress >= 1.0:
			_direction = -1
			if pause_at_points:
				_start_pause()
		elif progress <= 0.0:
			_direction = 1
			if pause_at_points:
				_start_pause()
	else:
		if progress >= 1.0:
			_time = 0.0
			if pause_at_points:
				_start_pause()


func _process_circular(delta: float) -> void:
	_time += delta

	var angle := _time * speed
	var offset := Vector3.ZERO

	# Calculate position on circle based on axis
	if circular_axis.is_equal_approx(Vector3.UP):
		offset = Vector3(cos(angle), 0, sin(angle)) * circular_radius
	elif circular_axis.is_equal_approx(Vector3.RIGHT):
		offset = Vector3(0, cos(angle), sin(angle)) * circular_radius
	else:
		offset = Vector3(cos(angle), sin(angle), 0) * circular_radius

	global_position = _origin + offset


func _process_waypoints(delta: float) -> void:
	if waypoints.size() < 2:
		return

	var start_pos := _origin + waypoints[_current_waypoint_index]
	var end_pos := _origin + waypoints[_target_waypoint_index]
	var segment_distance := start_pos.distance_to(end_pos)

	if segment_distance < 0.01:
		_advance_waypoint()
		return

	_time += delta * speed

	var progress := clampf(_time / segment_distance, 0.0, 1.0)
	progress = _apply_easing(progress)

	global_position = start_pos.lerp(end_pos, progress)

	if progress >= 1.0:
		_advance_waypoint()


func _process_elevator(delta: float) -> void:
	# Elevator is similar to linear but with proper stops
	_process_linear(delta)

# endregion


# region -- Waypoint Navigation

func _advance_waypoint() -> void:
	_time = 0.0

	if pause_at_points:
		_start_pause()

	_current_waypoint_index = _target_waypoint_index

	if loop_mode:
		# Loop mode: go to next waypoint, wrap around
		_target_waypoint_index = (_target_waypoint_index + 1) % waypoints.size()
	else:
		# Ping-pong mode
		_target_waypoint_index += _direction

		if _target_waypoint_index >= waypoints.size():
			_direction = -1
			_target_waypoint_index = waypoints.size() - 2
		elif _target_waypoint_index < 0:
			_direction = 1
			_target_waypoint_index = 1


func _start_pause() -> void:
	_is_paused = true
	_pause_timer = pause_duration if pause_at_points else stop_duration

# endregion


# region -- Easing

func _apply_easing(t: float) -> float:
	match ease_type:
		EaseType.LINEAR:
			return t
		EaseType.SMOOTH:
			# Smoothstep
			return t * t * (3.0 - 2.0 * t)
		EaseType.BOUNCE:
			# Bounce out
			if t < 1.0 / 2.75:
				return 7.5625 * t * t
			elif t < 2.0 / 2.75:
				var t2 := t - 1.5 / 2.75
				return 7.5625 * t2 * t2 + 0.75
			elif t < 2.5 / 2.75:
				var t2 := t - 2.25 / 2.75
				return 7.5625 * t2 * t2 + 0.9375
			else:
				var t2 := t - 2.625 / 2.75
				return 7.5625 * t2 * t2 + 0.984375
		EaseType.ELASTIC:
			# Elastic out
			if t == 0.0 or t == 1.0:
				return t
			return pow(2.0, -10.0 * t) * sin((t - 0.075) * (2.0 * PI) / 0.3) + 1.0

	return t

# endregion


# region -- Public API

## Get the platform's current velocity (for player movement inheritance)
func get_platform_velocity() -> Vector3:
	return _velocity


## Activate the platform (for trigger-based platforms)
func activate() -> void:
	_is_active = true
	_rpc_set_active.rpc(true)


## Deactivate the platform
func deactivate() -> void:
	_is_active = false
	_rpc_set_active.rpc(false)


## Set platform to a specific position along its path (0.0 - 1.0)
func set_position_along_path(t: float) -> void:
	match movement_type:
		MovementType.LINEAR, MovementType.ELEVATOR:
			global_position = _origin + end_offset * clampf(t, 0.0, 1.0)
		MovementType.CIRCULAR:
			var angle := t * TAU
			var offset := Vector3(cos(angle), 0, sin(angle)) * circular_radius
			global_position = _origin + offset
		MovementType.WAYPOINTS:
			var total_points := waypoints.size()
			var float_index := t * (total_points - 1)
			var index := int(float_index)
			var frac := float_index - index
			if index >= total_points - 1:
				global_position = _origin + waypoints[total_points - 1]
			else:
				var start_p := _origin + waypoints[index]
				var end_p := _origin + waypoints[index + 1]
				global_position = start_p.lerp(end_p, frac)


@rpc("authority", "call_local", "reliable")
func _rpc_set_active(active: bool) -> void:
	_is_active = active

# endregion


# region -- Helpers

func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
