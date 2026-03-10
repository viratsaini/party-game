## InteractiveDoor - Interactive door/gate system for maps.
##
## Features:
##   - Manual activation (trigger zones)
##   - Timer-based cycling
##   - Multiple door types (sliding, rotating, double)
##   - Sound effects
##   - Server-authoritative
class_name InteractiveDoor
extends Node3D


# region -- Enums

enum DoorType {
	SLIDE_HORIZONTAL,
	SLIDE_VERTICAL,
	ROTATE,
	DOUBLE_SLIDE,
}

enum ActivationType {
	TRIGGER_ZONE,
	SWITCH,
	TIMED_CYCLE,
	REMOTE,  # Controlled by another script
}

# endregion


# region -- Signals

signal door_opened()
signal door_closed()
signal door_state_changed(is_open: bool)

# endregion


# region -- Exports

## The type of door movement
@export var door_type: DoorType = DoorType.SLIDE_HORIZONTAL

## How the door is activated
@export var activation_type: ActivationType = ActivationType.TRIGGER_ZONE

## Duration to fully open/close
@export var open_duration: float = 1.0

## For SLIDE types: distance to move
@export var slide_distance: float = 3.0

## For ROTATE type: angle to rotate (degrees)
@export var rotate_angle: float = 90.0

## For TIMED_CYCLE: time door stays open
@export var open_time: float = 3.0

## For TIMED_CYCLE: time door stays closed
@export var closed_time: float = 5.0

## Should door auto-close after opening?
@export var auto_close: bool = true

## Delay before auto-close
@export var auto_close_delay: float = 2.0

## Door mesh node path
@export var door_mesh_a: NodePath = ""

## Second door mesh path (for double doors)
@export var door_mesh_b: NodePath = ""

## Collision body path
@export var door_body_a: NodePath = ""

## Second collision body path (for double doors)
@export var door_body_b: NodePath = ""

## Trigger zone path (for TRIGGER_ZONE activation)
@export var trigger_zone: NodePath = ""

## Sound effects
@export var open_sound: String = "door_open"
@export var close_sound: String = "door_close"

# endregion


# region -- State

var _is_open: bool = false
var _is_moving: bool = false
var _progress: float = 0.0  # 0.0 = closed, 1.0 = open
var _target_progress: float = 0.0
var _cycle_timer: float = 0.0
var _auto_close_timer: float = 0.0

var _mesh_a: Node3D = null
var _mesh_b: Node3D = null
var _body_a: StaticBody3D = null
var _body_b: StaticBody3D = null
var _trigger: Area3D = null

var _origin_a: Transform3D
var _origin_b: Transform3D

var _players_in_trigger: int = 0

# endregion


# region -- Lifecycle

func _ready() -> void:
	# Cache references
	if door_mesh_a:
		_mesh_a = get_node_or_null(door_mesh_a) as Node3D
	if door_mesh_b:
		_mesh_b = get_node_or_null(door_mesh_b) as Node3D
	if door_body_a:
		_body_a = get_node_or_null(door_body_a) as StaticBody3D
	if door_body_b:
		_body_b = get_node_or_null(door_body_b) as StaticBody3D
	if trigger_zone:
		_trigger = get_node_or_null(trigger_zone) as Area3D
		if _trigger:
			_trigger.body_entered.connect(_on_trigger_body_entered)
			_trigger.body_exited.connect(_on_trigger_body_exited)

	# Store origins
	if _mesh_a:
		_origin_a = _mesh_a.transform
	if _mesh_b:
		_origin_b = _mesh_b.transform


func _physics_process(delta: float) -> void:
	if not _is_server():
		return

	# Handle timed cycle
	if activation_type == ActivationType.TIMED_CYCLE:
		_process_timed_cycle(delta)

	# Handle auto-close
	if auto_close and _is_open and not _is_moving:
		if activation_type != ActivationType.TRIGGER_ZONE or _players_in_trigger == 0:
			_auto_close_timer += delta
			if _auto_close_timer >= auto_close_delay:
				close_door()

	# Process door movement
	if _is_moving:
		_process_movement(delta)

# endregion


# region -- Movement

func _process_movement(delta: float) -> void:
	var direction := 1.0 if _target_progress > _progress else -1.0
	var speed := 1.0 / open_duration

	_progress += direction * speed * delta
	_progress = clampf(_progress, 0.0, 1.0)

	_update_door_positions()

	# Check if movement complete
	if absf(_progress - _target_progress) < 0.01:
		_progress = _target_progress
		_is_moving = false
		_update_door_positions()

		if _progress >= 1.0:
			_is_open = true
			door_opened.emit()
			door_state_changed.emit(true)
		else:
			_is_open = false
			door_closed.emit()
			door_state_changed.emit(false)

		_rpc_door_state.rpc(_is_open, _progress)


func _update_door_positions() -> void:
	match door_type:
		DoorType.SLIDE_HORIZONTAL:
			if _mesh_a:
				_mesh_a.transform = _origin_a
				_mesh_a.position.x += slide_distance * _progress
			if _body_a:
				_body_a.position.x = _mesh_a.position.x if _mesh_a else slide_distance * _progress

		DoorType.SLIDE_VERTICAL:
			if _mesh_a:
				_mesh_a.transform = _origin_a
				_mesh_a.position.y += slide_distance * _progress
			if _body_a:
				_body_a.position.y = _mesh_a.position.y if _mesh_a else slide_distance * _progress

		DoorType.ROTATE:
			if _mesh_a:
				_mesh_a.transform = _origin_a
				_mesh_a.rotation_degrees.y += rotate_angle * _progress
			if _body_a:
				_body_a.rotation_degrees.y = _mesh_a.rotation_degrees.y if _mesh_a else rotate_angle * _progress

		DoorType.DOUBLE_SLIDE:
			if _mesh_a:
				_mesh_a.transform = _origin_a
				_mesh_a.position.x -= slide_distance * 0.5 * _progress
			if _mesh_b:
				_mesh_b.transform = _origin_b
				_mesh_b.position.x += slide_distance * 0.5 * _progress
			if _body_a:
				_body_a.position.x = _mesh_a.position.x if _mesh_a else -slide_distance * 0.5 * _progress
			if _body_b:
				_body_b.position.x = _mesh_b.position.x if _mesh_b else slide_distance * 0.5 * _progress


func _process_timed_cycle(delta: float) -> void:
	_cycle_timer += delta

	if _is_open:
		if _cycle_timer >= open_time:
			close_door()
	else:
		if _cycle_timer >= closed_time:
			open_door()

# endregion


# region -- Trigger Zone

func _on_trigger_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	_players_in_trigger += 1

	if activation_type == ActivationType.TRIGGER_ZONE and not _is_open:
		open_door()


func _on_trigger_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	_players_in_trigger = maxi(_players_in_trigger - 1, 0)

# endregion


# region -- Public API

## Open the door
func open_door() -> void:
	if not _is_server():
		return

	if _is_open and not _is_moving:
		return

	_target_progress = 1.0
	_is_moving = true
	_auto_close_timer = 0.0
	_cycle_timer = 0.0

	AudioManager.play_sfx(open_sound)
	_rpc_play_sound.rpc(open_sound)


## Close the door
func close_door() -> void:
	if not _is_server():
		return

	if not _is_open and not _is_moving:
		return

	_target_progress = 0.0
	_is_moving = true
	_cycle_timer = 0.0

	AudioManager.play_sfx(close_sound)
	_rpc_play_sound.rpc(close_sound)


## Toggle door state
func toggle_door() -> void:
	if _is_open or _target_progress > 0.5:
		close_door()
	else:
		open_door()


## Check if door is currently open
func is_open() -> bool:
	return _is_open


## Check if door is currently moving
func is_moving() -> bool:
	return _is_moving

# endregion


# region -- RPC

@rpc("authority", "call_remote", "reliable")
func _rpc_door_state(is_open: bool, progress: float) -> void:
	_is_open = is_open
	_progress = progress
	_is_moving = false
	_update_door_positions()


@rpc("authority", "call_remote", "unreliable")
func _rpc_play_sound(sound_name: String) -> void:
	AudioManager.play_sfx(sound_name)

# endregion


# region -- Helpers

func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
