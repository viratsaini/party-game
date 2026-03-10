## ObstacleHazard — Generic server-authoritative obstacle hazard for Obstacle Royale.
##
## Supports four hazard types driven by an exported enum:
##   PENDULUM  — swings back and forth on the X axis via a sine wave.
##   SPINNER   — rotates continuously around the Y axis.
##   PUSHER    — slides back and forth along a configurable axis, pushing players.
##   FALLING_TILE — shakes then falls when a player steps on it; respawns after a delay.
##
## The server controls all obstacle state and replicates transforms to clients
## via the built-in MultiplayerSynchronizer (or manual RPCs as needed).
class_name ObstacleHazard
extends AnimatableBody3D


# region — Enums

## The type of obstacle behaviour this node exhibits.
enum HazardType {
	PENDULUM,
	SPINNER,
	PUSHER,
	FALLING_TILE,
}

# endregion


# region — Exports

## Which behaviour pattern this hazard follows.
@export var hazard_type: HazardType = HazardType.PENDULUM

## Maximum swing angle in degrees (PENDULUM only).
@export var swing_angle: float = 45.0

## Movement / rotation speed (units depend on hazard type).
@export var speed: float = 2.0

## Force applied to players on contact (PUSHER / PENDULUM knockback).
@export var push_force: float = 12.0

## Distance the PUSHER travels from its origin (half-extent).
@export var push_distance: float = 5.0

## Axis along which the PUSHER moves.  Normalized on ready.
@export var push_axis: Vector3 = Vector3.RIGHT

## Duration in seconds before a FALLING_TILE drops after being triggered.
@export var tile_shake_duration: float = 0.8

## Time the tile stays gone before re-appearing.
@export var tile_respawn_delay: float = 5.0

## Time the tile is falling / disabled.
@export var tile_fall_duration: float = 3.0

# endregion


# region — State

## Accumulated time used for oscillation functions.
var _time: float = 0.0

## Original transform, cached on ready so oscillations are relative.
var _origin_position: Vector3 = Vector3.ZERO
var _origin_rotation: Vector3 = Vector3.ZERO

## FALLING_TILE state flags.
var _tile_triggered: bool = false
var _tile_fallen: bool = false
var _tile_timer: float = 0.0

## Reference to the MeshInstance3D child (for shake effect).
var _mesh: MeshInstance3D = null

## Reference to the CollisionShape3D child.
var _collision: CollisionShape3D = null

# endregion


# region — Lifecycle

func _ready() -> void:
	_origin_position = position
	_origin_rotation = rotation

	push_axis = push_axis.normalized() if push_axis.length() > 0.01 else Vector3.RIGHT

	# Cache child references.
	for child: Node in get_children():
		if child is MeshInstance3D and not _mesh:
			_mesh = child as MeshInstance3D
		if child is CollisionShape3D and not _collision:
			_collision = child as CollisionShape3D

	# FALLING_TILE: connect body-entered so we know when a player steps on it.
	if hazard_type == HazardType.FALLING_TILE:
		# We use contact monitoring via an Area3D child if present, or body signals.
		_connect_tile_detection()


func _physics_process(delta: float) -> void:
	# Only the server drives obstacle logic.
	if not _is_server():
		return

	match hazard_type:
		HazardType.PENDULUM:
			_process_pendulum(delta)
		HazardType.SPINNER:
			_process_spinner(delta)
		HazardType.PUSHER:
			_process_pusher(delta)
		HazardType.FALLING_TILE:
			_process_falling_tile(delta)

# endregion


# region — PENDULUM

func _process_pendulum(delta: float) -> void:
	_time += delta * speed
	var angle_rad: float = deg_to_rad(swing_angle) * sin(_time)
	rotation = Vector3(_origin_rotation.x + angle_rad, _origin_rotation.y, _origin_rotation.z)

# endregion


# region — SPINNER

func _process_spinner(delta: float) -> void:
	rotation.y += speed * delta

# endregion


# region — PUSHER

func _process_pusher(delta: float) -> void:
	_time += delta * speed
	var offset: float = sin(_time) * push_distance
	position = _origin_position + push_axis * offset

# endregion


# region — FALLING_TILE

func _process_falling_tile(delta: float) -> void:
	if not _tile_triggered:
		return

	_tile_timer -= delta

	if not _tile_fallen:
		# Shake phase.
		if _tile_timer > 0.0:
			_apply_shake()
		else:
			# Time to fall.
			_tile_fallen = true
			_tile_timer = tile_fall_duration
			_drop_tile()
	else:
		# Fallen phase — wait for fall duration to expire, then start respawn.
		if _tile_timer <= 0.0:
			_tile_timer = tile_respawn_delay
			_start_respawn_wait()


func _connect_tile_detection() -> void:
	# Look for an Area3D child named "TileDetector" (the tscn provides one).
	var detector: Area3D = get_node_or_null("TileDetector") as Area3D
	if detector:
		detector.body_entered.connect(_on_tile_body_entered)
	else:
		# Fallback: create a small Area3D on top of this body for detection.
		var area := Area3D.new()
		area.name = "TileDetector"
		area.collision_layer = 0
		area.collision_mask = 1  # Players on layer 1.
		area.monitoring = true
		area.monitorable = false

		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		# Slightly larger than the tile to catch players stepping on top.
		box.size = Vector3(2.0, 1.0, 2.0)
		shape_node.shape = box
		shape_node.position = Vector3(0.0, 0.75, 0.0)
		area.add_child(shape_node)
		add_child(area)
		area.body_entered.connect(_on_tile_body_entered)


func _on_tile_body_entered(body: Node3D) -> void:
	if not _is_server():
		return
	if _tile_triggered:
		return
	# Only react to player characters.
	if not body is CharacterBody3D:
		return

	_tile_triggered = true
	_tile_timer = tile_shake_duration
	_rpc_tile_state.rpc("shake")


func _apply_shake() -> void:
	if _mesh:
		_mesh.position = Vector3(
			randf_range(-0.05, 0.05),
			_mesh.position.y,
			randf_range(-0.05, 0.05)
		)


func _drop_tile() -> void:
	# Disable collision and hide mesh.
	if _collision:
		_collision.disabled = true
	visible = false
	_rpc_tile_state.rpc("fall")


func _start_respawn_wait() -> void:
	# After respawn delay, reset the tile.
	var timer := Timer.new()
	timer.wait_time = tile_respawn_delay
	timer.one_shot = true
	timer.timeout.connect(_respawn_tile.bind(timer))
	add_child(timer)
	timer.start()


func _respawn_tile(timer: Timer) -> void:
	timer.queue_free()
	_tile_triggered = false
	_tile_fallen = false
	_tile_timer = 0.0
	position = _origin_position
	if _collision:
		_collision.disabled = false
	if _mesh:
		_mesh.position = Vector3.ZERO
	visible = true
	_rpc_tile_state.rpc("respawn")


## Replicates tile visual state to all clients.
@rpc("authority", "call_remote", "reliable")
func _rpc_tile_state(state: String) -> void:
	match state:
		"shake":
			# Client-side shake effect via a short tween.
			if _mesh:
				var tw: Tween = create_tween().set_loops(int(tile_shake_duration / 0.05))
				tw.tween_property(_mesh, "position:x", randf_range(-0.05, 0.05), 0.025)
				tw.tween_property(_mesh, "position:x", 0.0, 0.025)
		"fall":
			if _collision:
				_collision.disabled = true
			visible = false
		"respawn":
			if _collision:
				_collision.disabled = false
			if _mesh:
				_mesh.position = Vector3.ZERO
			visible = true

# endregion


# region — Helpers

func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
