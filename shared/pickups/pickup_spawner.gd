## Pickup Spawner System for BattleZone Party.
##
## Manages spawn points, pickup selection based on rarity weights,
## respawn timing, and network synchronization. Place this node in your
## game scene and configure spawn points as child Marker3D nodes.
class_name PickupSpawner
extends Node3D


# region -- Signals

## Emitted when a pickup is spawned at a spawn point.
signal pickup_spawned(pickup: PickupBase, spawn_point_index: int)

## Emitted when a pickup is collected.
signal pickup_collected(pickup_id: String, peer_id: int, spawn_point_index: int)

## Emitted when all initial pickups have been spawned.
signal initial_spawn_complete()

# endregion


# region -- Enums

## Spawn mode determines how pickups are distributed.
enum SpawnMode {
	RANDOM,            ## Random pickup at random spawn point
	WEIGHTED_RANDOM,   ## Pickups based on rarity weights
	FIXED,             ## Fixed pickup types at specific points
	SEQUENTIAL,        ## Cycle through pickup types in order
}

# endregion


# region -- Exports

## Pickup scenes that can be spawned (must extend PickupBase).
@export var pickup_scenes: Array[PackedScene] = []

## How pickups are selected for spawning.
@export var spawn_mode: SpawnMode = SpawnMode.WEIGHTED_RANDOM

## Delay before spawning initial pickups after _ready.
@export var initial_spawn_delay: float = 2.0

## Whether to spawn initial pickups when the scene loads.
@export var auto_spawn_initial: bool = true

## Maximum number of active pickups at once (0 = unlimited).
@export var max_active_pickups: int = 0

## Minimum time between spawns at the same point.
@export var min_respawn_interval: float = 5.0

## Whether spawn points are visible in the editor.
@export var show_spawn_points_in_editor: bool = true

## Color for spawn point gizmos in editor.
@export var spawn_point_gizmo_color: Color = Color(0.2, 0.8, 0.4, 0.5)

# endregion


# region -- Constants

## Node group for spawn points.
const SPAWN_POINT_GROUP: StringName = &"pickup_spawn_points"

## Default respawn time if pickup doesn't specify one.
const DEFAULT_RESPAWN_TIME: float = 15.0

# endregion


# region -- State

## Currently active pickups mapped by spawn point index.
var _active_pickups: Dictionary = {}  # int -> PickupBase

## Spawn points collected from child Marker3D nodes.
var _spawn_points: Array[Vector3] = []

## Spawn point timers for respawning.
var _spawn_timers: Dictionary = {}  # int -> Timer

## Sequential spawn index (for SEQUENTIAL mode).
var _sequential_index: int = 0

## Whether initial spawning is complete.
var _initial_spawn_done: bool = false

## Preloaded pickup instances for performance.
var _pickup_pool: Dictionary = {}  # String -> Array[PickupBase]

# endregion


# region -- Lifecycle

func _ready() -> void:
	# Collect spawn points from child Marker3D nodes.
	_collect_spawn_points()

	# Spawn initial pickups if configured.
	if auto_spawn_initial and _is_server():
		var timer := Timer.new()
		timer.name = "InitialSpawnTimer"
		timer.wait_time = initial_spawn_delay
		timer.one_shot = true
		timer.timeout.connect(_spawn_initial_pickups)
		add_child(timer)
		timer.start()


func _collect_spawn_points() -> void:
	_spawn_points.clear()

	for child in get_children():
		if child is Marker3D:
			_spawn_points.append(child.global_position)

	if _spawn_points.is_empty():
		push_warning("PickupSpawner: No spawn points found. Add Marker3D children to define spawn locations.")

# endregion


# region -- Initial Spawning

## Spawn pickups at all spawn points.
func _spawn_initial_pickups() -> void:
	if not _is_server():
		return

	for i in range(_spawn_points.size()):
		if max_active_pickups > 0 and _active_pickups.size() >= max_active_pickups:
			break

		_spawn_pickup_at_point(i)

	_initial_spawn_done = true
	initial_spawn_complete.emit()


## Spawn a pickup at a specific spawn point index.
func _spawn_pickup_at_point(point_index: int) -> void:
	if not _is_server():
		return

	if point_index < 0 or point_index >= _spawn_points.size():
		push_warning("PickupSpawner: Invalid spawn point index %d" % point_index)
		return

	# Check if there's already a pickup at this point.
	if _active_pickups.has(point_index):
		return

	# Select pickup type based on spawn mode.
	var pickup_scene: PackedScene = _select_pickup_scene()
	if not pickup_scene:
		push_warning("PickupSpawner: No pickup scenes configured")
		return

	# Instantiate and position the pickup.
	var pickup: PickupBase = pickup_scene.instantiate() as PickupBase
	if not pickup:
		push_warning("PickupSpawner: Failed to instantiate pickup scene")
		return

	pickup.name = "Pickup_%d_%d" % [point_index, Time.get_ticks_msec()]
	pickup.global_position = _spawn_points[point_index]

	# Connect signals.
	pickup.collected.connect(_on_pickup_collected.bind(point_index))
	pickup.respawned.connect(_on_pickup_respawned.bind(point_index))

	# Add to scene and track.
	add_child(pickup, true)
	_active_pickups[point_index] = pickup

	# Notify clients.
	_rpc_spawn_pickup.rpc(point_index, pickup_scene.resource_path)

	pickup_spawned.emit(pickup, point_index)


## Select a pickup scene based on the current spawn mode.
func _select_pickup_scene() -> PackedScene:
	if pickup_scenes.is_empty():
		return null

	match spawn_mode:
		SpawnMode.RANDOM:
			return pickup_scenes[randi() % pickup_scenes.size()]

		SpawnMode.WEIGHTED_RANDOM:
			return _select_weighted_random()

		SpawnMode.FIXED:
			# In FIXED mode, use the first available scene.
			return pickup_scenes[0] if pickup_scenes.size() > 0 else null

		SpawnMode.SEQUENTIAL:
			var scene: PackedScene = pickup_scenes[_sequential_index]
			_sequential_index = (_sequential_index + 1) % pickup_scenes.size()
			return scene

	return pickup_scenes[0]


## Select a pickup based on rarity weights.
func _select_weighted_random() -> PackedScene:
	var total_weight: int = 0
	var weights: Array[int] = []

	for scene in pickup_scenes:
		# Instantiate temporarily to get the weight.
		var temp_pickup: PickupBase = scene.instantiate() as PickupBase
		if temp_pickup:
			var weight: int = temp_pickup.get_spawn_weight()
			weights.append(weight)
			total_weight += weight
			temp_pickup.queue_free()
		else:
			weights.append(50)  # Default weight
			total_weight += 50

	if total_weight <= 0:
		return pickup_scenes[0]

	var roll: int = randi() % total_weight
	var cumulative: int = 0

	for i in range(weights.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return pickup_scenes[i]

	return pickup_scenes[pickup_scenes.size() - 1]

# endregion


# region -- Pickup Events

## Called when a pickup is collected.
func _on_pickup_collected(peer_id: int, pickup_id: String, point_index: int) -> void:
	if not _is_server():
		return

	# Remove from active pickups.
	if _active_pickups.has(point_index):
		_active_pickups.erase(point_index)

	pickup_collected.emit(pickup_id, peer_id, point_index)


## Called when a pickup respawns.
func _on_pickup_respawned(point_index: int) -> void:
	# Re-add to active pickups if still in scene.
	var pickup: PickupBase = _find_pickup_at_point(point_index)
	if pickup:
		_active_pickups[point_index] = pickup


func _find_pickup_at_point(point_index: int) -> PickupBase:
	for child in get_children():
		if child is PickupBase:
			var pickup: PickupBase = child
			if pickup.global_position.distance_to(_spawn_points[point_index]) < 0.5:
				return pickup
	return null

# endregion


# region -- Public API

## Force spawn a specific pickup type at a given spawn point.
func spawn_specific_pickup(pickup_scene: PackedScene, point_index: int) -> PickupBase:
	if not _is_server():
		return null

	if point_index < 0 or point_index >= _spawn_points.size():
		return null

	# Remove existing pickup at this point.
	if _active_pickups.has(point_index):
		var existing: PickupBase = _active_pickups[point_index]
		existing.queue_free()
		_active_pickups.erase(point_index)

	# Spawn the new pickup.
	var pickup: PickupBase = pickup_scene.instantiate() as PickupBase
	if not pickup:
		return null

	pickup.name = "Pickup_%d_%d" % [point_index, Time.get_ticks_msec()]
	pickup.global_position = _spawn_points[point_index]

	pickup.collected.connect(_on_pickup_collected.bind(point_index))
	pickup.respawned.connect(_on_pickup_respawned.bind(point_index))

	add_child(pickup, true)
	_active_pickups[point_index] = pickup

	_rpc_spawn_pickup.rpc(point_index, pickup_scene.resource_path)

	return pickup


## Get the number of currently active pickups.
func get_active_pickup_count() -> int:
	return _active_pickups.size()


## Get all currently active pickups.
func get_active_pickups() -> Array[PickupBase]:
	var result: Array[PickupBase] = []
	for pickup in _active_pickups.values():
		if is_instance_valid(pickup):
			result.append(pickup)
	return result


## Clear all active pickups.
func clear_all_pickups() -> void:
	for pickup in _active_pickups.values():
		if is_instance_valid(pickup):
			pickup.queue_free()
	_active_pickups.clear()

	if _is_server():
		_rpc_clear_all.rpc()


## Add a new spawn point at runtime.
func add_spawn_point(position: Vector3) -> int:
	_spawn_points.append(position)
	return _spawn_points.size() - 1


## Get all spawn point positions.
func get_spawn_points() -> Array[Vector3]:
	return _spawn_points.duplicate()

# endregion


# region -- Network RPCs

## Sync pickup spawn to clients.
@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_pickup(point_index: int, scene_path: String) -> void:
	if point_index < 0 or point_index >= _spawn_points.size():
		return

	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return

	var pickup: PickupBase = scene.instantiate() as PickupBase
	if not pickup:
		return

	pickup.name = "Pickup_%d_%d" % [point_index, Time.get_ticks_msec()]
	pickup.global_position = _spawn_points[point_index]

	add_child(pickup)
	_active_pickups[point_index] = pickup


## Sync clearing all pickups to clients.
@rpc("authority", "call_remote", "reliable")
func _rpc_clear_all() -> void:
	for pickup in _active_pickups.values():
		if is_instance_valid(pickup):
			pickup.queue_free()
	_active_pickups.clear()

# endregion


# region -- Helpers

## Check if we're the server.
func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
