## DestructibleCover - Destructible cover that can be damaged and destroyed.
##
## Features:
##   - Health-based destruction
##   - Visual damage states (cracking)
##   - Debris spawning on destruction
##   - Optional respawning
##   - Server-authoritative
class_name DestructibleCover
extends StaticBody3D


# region -- Signals

signal destroyed()
signal respawned()
signal damage_taken(remaining_health: float)

# endregion


# region -- Exports

## Maximum health before destruction
@export var max_health: float = 100.0

## Current health
@export var health: float = 100.0

## Should this cover respawn after destruction?
@export var can_respawn: bool = true

## Time until respawn (seconds)
@export var respawn_time: float = 15.0

## Number of damage visual states (meshes to swap)
@export var damage_states: int = 3

## Array of mesh instances for damage states (healthy -> damaged -> destroyed)
@export var state_meshes: Array[NodePath] = []

## Debris scene to spawn on destruction
@export var debris_scene: PackedScene = null

## Number of debris pieces to spawn
@export var debris_count: int = 5

## Force applied to debris
@export var debris_force: float = 8.0

## Particle effect on destruction
@export var destruction_particles: NodePath = ""

## Sound effect name for destruction
@export var destruction_sound: String = "cover_destroy"

## Sound effect name for damage
@export var damage_sound: String = "cover_hit"

# endregion


# region -- State

var _is_destroyed: bool = false
var _current_state: int = 0
var _mesh_nodes: Array[MeshInstance3D] = []
var _collision_shape: CollisionShape3D = null
var _particles: GPUParticles3D = null

# endregion


# region -- Lifecycle

func _ready() -> void:
	health = max_health
	_current_state = 0

	# Cache mesh references
	for path in state_meshes:
		var node := get_node_or_null(path) as MeshInstance3D
		if node:
			_mesh_nodes.append(node)

	# Cache collision shape
	for child in get_children():
		if child is CollisionShape3D:
			_collision_shape = child
			break

	# Cache particle reference
	if destruction_particles:
		_particles = get_node_or_null(destruction_particles) as GPUParticles3D

	_update_visual_state()

# endregion


# region -- Damage System

## Apply damage to this cover (server-authoritative)
func take_damage(amount: float, _source_peer_id: int = -1) -> void:
	if not _is_server():
		return

	if _is_destroyed:
		return

	health = maxf(health - amount, 0.0)
	damage_taken.emit(health)

	# Play damage sound
	AudioManager.play_sfx(damage_sound)

	# Update visual state
	_update_damage_state()

	# Replicate to clients
	_rpc_update_health.rpc(health)

	# Check for destruction
	if health <= 0.0:
		_destroy()


func _update_damage_state() -> void:
	if damage_states <= 1 or _mesh_nodes.is_empty():
		return

	var health_per_state := max_health / damage_states
	var new_state := damage_states - 1 - int(health / health_per_state)
	new_state = clampi(new_state, 0, damage_states - 1)

	if new_state != _current_state:
		_current_state = new_state
		_update_visual_state()
		_rpc_set_visual_state.rpc(_current_state)


func _update_visual_state() -> void:
	for i in _mesh_nodes.size():
		if _mesh_nodes[i]:
			_mesh_nodes[i].visible = (i == _current_state)


@rpc("authority", "call_remote", "reliable")
func _rpc_update_health(new_health: float) -> void:
	health = new_health
	_update_damage_state()


@rpc("authority", "call_remote", "reliable")
func _rpc_set_visual_state(state: int) -> void:
	_current_state = state
	_update_visual_state()

# endregion


# region -- Destruction

func _destroy() -> void:
	if _is_destroyed:
		return

	_is_destroyed = true
	destroyed.emit()

	# Play destruction sound
	AudioManager.play_sfx(destruction_sound)

	# Spawn debris
	_spawn_debris()

	# Trigger particles
	if _particles:
		_particles.emitting = true

	# Disable collision
	if _collision_shape:
		_collision_shape.disabled = true

	# Hide meshes
	for mesh in _mesh_nodes:
		if mesh:
			mesh.visible = false

	# Notify clients
	_rpc_on_destroyed.rpc()

	# Start respawn timer if applicable
	if can_respawn:
		_start_respawn_timer()


func _spawn_debris() -> void:
	if not debris_scene:
		return

	for i in debris_count:
		var debris := debris_scene.instantiate() as RigidBody3D
		if not debris:
			continue

		debris.global_position = global_position + Vector3(
			randf_range(-0.5, 0.5),
			randf_range(0.0, 0.5),
			randf_range(-0.5, 0.5)
		)

		# Apply random force
		var force := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.5, 1.0),
			randf_range(-1.0, 1.0)
		).normalized() * debris_force

		get_parent().add_child(debris)
		debris.apply_impulse(force)

		# Auto-cleanup debris after a delay
		var cleanup_timer := Timer.new()
		cleanup_timer.wait_time = 5.0
		cleanup_timer.one_shot = true
		cleanup_timer.timeout.connect(debris.queue_free)
		debris.add_child(cleanup_timer)
		cleanup_timer.start()


@rpc("authority", "call_remote", "reliable")
func _rpc_on_destroyed() -> void:
	_is_destroyed = true

	# Disable collision
	if _collision_shape:
		_collision_shape.disabled = true

	# Hide meshes
	for mesh in _mesh_nodes:
		if mesh:
			mesh.visible = false

	# Trigger particles
	if _particles:
		_particles.emitting = true

# endregion


# region -- Respawn

func _start_respawn_timer() -> void:
	var timer := Timer.new()
	timer.wait_time = respawn_time
	timer.one_shot = true
	timer.timeout.connect(_respawn.bind(timer))
	add_child(timer)
	timer.start()


func _respawn(timer: Timer) -> void:
	timer.queue_free()

	if not _is_server():
		return

	_is_destroyed = false
	health = max_health
	_current_state = 0

	# Enable collision
	if _collision_shape:
		_collision_shape.disabled = false

	_update_visual_state()
	respawned.emit()

	# Notify clients
	_rpc_on_respawned.rpc()


@rpc("authority", "call_remote", "reliable")
func _rpc_on_respawned() -> void:
	_is_destroyed = false
	health = max_health
	_current_state = 0

	# Enable collision
	if _collision_shape:
		_collision_shape.disabled = false

	_update_visual_state()

# endregion


# region -- Public API

## Check if this cover is destroyed
func is_destroyed() -> bool:
	return _is_destroyed


## Force respawn immediately (server only)
func force_respawn() -> void:
	if _is_server() and _is_destroyed:
		_respawn(null)


## Get current health percentage (0.0 - 1.0)
func get_health_percentage() -> float:
	return health / max_health

# endregion


# region -- Helpers

func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
