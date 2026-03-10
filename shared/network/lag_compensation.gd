## Lag Compensation System
##
## Implements server-side lag compensation through world state rewinding.
## Allows hit validation to be performed against historical world states
## based on shooter's latency, ensuring fair hit detection.
##
## Features:
##   - World state history buffer (1 second of snapshots)
##   - Time-based world rewinding
##   - Server-side hit validation against historical positions
##   - Interpolation between snapshots for precise timing
##   - Configurable maximum lag compensation window
class_name LagCompensation
extends RefCounted

# =============================================================================
# region - Constants
# =============================================================================

## Maximum time to rewind (prevents extreme lag abuse)
const MAX_REWIND_TIME_MS: int = 250

## Snapshot interval in milliseconds
const SNAPSHOT_INTERVAL_MS: int = 50

## Total history duration in milliseconds (1 second)
const HISTORY_DURATION_MS: int = 1000

## Maximum number of snapshots to store
const MAX_SNAPSHOTS: int = 20  # 1000ms / 50ms = 20 snapshots

## Hitbox radius for player collision detection
const PLAYER_HITBOX_RADIUS: float = 0.5

## Hitbox height for player collision detection
const PLAYER_HITBOX_HEIGHT: float = 1.8

# endregion

# =============================================================================
# region - Types
# =============================================================================

## Represents a single entity's state at a point in time
class EntitySnapshot:
	var entity_id: int = 0
	var position: Vector3 = Vector3.ZERO
	var rotation: float = 0.0
	var velocity: Vector3 = Vector3.ZERO
	var health: float = 100.0
	var is_alive: bool = true
	var hitbox_center: Vector3 = Vector3.ZERO
	var hitbox_size: Vector3 = Vector3.ONE

	func duplicate() -> EntitySnapshot:
		var copy := EntitySnapshot.new()
		copy.entity_id = entity_id
		copy.position = position
		copy.rotation = rotation
		copy.velocity = velocity
		copy.health = health
		copy.is_alive = is_alive
		copy.hitbox_center = hitbox_center
		copy.hitbox_size = hitbox_size
		return copy


## Represents the entire world state at a point in time
class WorldSnapshot:
	var timestamp_ms: int = 0
	var sequence: int = 0
	var entity_states: Dictionary = {}  # entity_id -> EntitySnapshot

	func duplicate() -> WorldSnapshot:
		var copy := WorldSnapshot.new()
		copy.timestamp_ms = timestamp_ms
		copy.sequence = sequence
		for entity_id: int in entity_states:
			copy.entity_states[entity_id] = entity_states[entity_id].duplicate()
		return copy


## Result of a lag-compensated hit check
class HitResult:
	var hit: bool = false
	var target_id: int = -1
	var hit_position: Vector3 = Vector3.ZERO
	var hit_normal: Vector3 = Vector3.UP
	var damage_multiplier: float = 1.0
	var body_part: String = "body"
	var rewind_time_ms: int = 0

# endregion

# =============================================================================
# region - State
# =============================================================================

## Circular buffer of world snapshots
var _snapshots: Array[WorldSnapshot] = []

## Current snapshot index (for circular buffer)
var _snapshot_index: int = 0

## Current snapshot sequence number
var _sequence: int = 0

## Time since last snapshot
var _time_since_snapshot: float = 0.0

## Whether the system is active
var _is_active: bool = false

## Reference to connection manager for ping data
var _connection_manager: Node = null

# endregion

# =============================================================================
# region - Initialization
# =============================================================================

func _init() -> void:
	# Pre-allocate snapshot buffer
	_snapshots.resize(MAX_SNAPSHOTS)
	for i in range(MAX_SNAPSHOTS):
		_snapshots[i] = WorldSnapshot.new()


func set_connection_manager(manager: Node) -> void:
	_connection_manager = manager


func start() -> void:
	_is_active = true
	_sequence = 0
	_snapshot_index = 0
	_time_since_snapshot = 0.0


func stop() -> void:
	_is_active = false
	# Clear all snapshots
	for snapshot: WorldSnapshot in _snapshots:
		snapshot.entity_states.clear()
		snapshot.timestamp_ms = 0
		snapshot.sequence = 0

# endregion

# =============================================================================
# region - Snapshot Recording
# =============================================================================

## Call this every physics frame to update time tracking
func process(delta: float) -> bool:
	if not _is_active:
		return false

	_time_since_snapshot += delta * 1000.0  # Convert to ms

	if _time_since_snapshot >= SNAPSHOT_INTERVAL_MS:
		_time_since_snapshot -= SNAPSHOT_INTERVAL_MS
		return true  # Signal that a snapshot should be recorded

	return false


## Records the current world state as a snapshot
func record_snapshot(entities: Dictionary) -> void:
	if not _is_active:
		return

	var snapshot: WorldSnapshot = _snapshots[_snapshot_index]
	snapshot.timestamp_ms = Time.get_ticks_msec()
	snapshot.sequence = _sequence
	snapshot.entity_states.clear()

	for entity_id: int in entities:
		var entity_data: Dictionary = entities[entity_id]
		var entity_snap := EntitySnapshot.new()

		entity_snap.entity_id = entity_id
		entity_snap.position = entity_data.get("position", Vector3.ZERO) as Vector3
		entity_snap.rotation = entity_data.get("rotation", 0.0) as float
		entity_snap.velocity = entity_data.get("velocity", Vector3.ZERO) as Vector3
		entity_snap.health = entity_data.get("health", 100.0) as float
		entity_snap.is_alive = entity_data.get("is_alive", true) as bool

		# Calculate hitbox
		entity_snap.hitbox_center = entity_snap.position + Vector3(0, PLAYER_HITBOX_HEIGHT * 0.5, 0)
		entity_snap.hitbox_size = Vector3(
			PLAYER_HITBOX_RADIUS * 2,
			PLAYER_HITBOX_HEIGHT,
			PLAYER_HITBOX_RADIUS * 2
		)

		snapshot.entity_states[entity_id] = entity_snap

	# Advance circular buffer
	_snapshot_index = (_snapshot_index + 1) % MAX_SNAPSHOTS
	_sequence += 1


## Creates entity data dictionary from a CharacterBody3D node
static func create_entity_data(character: CharacterBody3D) -> Dictionary:
	var data: Dictionary = {}
	data["position"] = character.global_position
	data["rotation"] = character.rotation.y
	data["velocity"] = character.velocity

	# Get health from PlayerCharacter if available
	if character.has_method("get") and character.get("health") != null:
		data["health"] = character.health
		data["is_alive"] = character.is_alive
	else:
		data["health"] = 100.0
		data["is_alive"] = true

	return data

# endregion

# =============================================================================
# region - World Rewinding
# =============================================================================

## Rewinds the world state to a specific timestamp
## Returns the interpolated world snapshot at that time
func rewind_to_time(target_time_ms: int) -> WorldSnapshot:
	var current_time_ms: int = Time.get_ticks_msec()
	var rewind_delta: int = current_time_ms - target_time_ms

	# Clamp rewind to maximum allowed
	if rewind_delta > MAX_REWIND_TIME_MS:
		target_time_ms = current_time_ms - MAX_REWIND_TIME_MS

	# Find the two snapshots that bracket the target time
	var before_snapshot: WorldSnapshot = null
	var after_snapshot: WorldSnapshot = null

	for snapshot: WorldSnapshot in _snapshots:
		if snapshot.timestamp_ms == 0:
			continue

		if snapshot.timestamp_ms <= target_time_ms:
			if before_snapshot == null or snapshot.timestamp_ms > before_snapshot.timestamp_ms:
				before_snapshot = snapshot

		if snapshot.timestamp_ms >= target_time_ms:
			if after_snapshot == null or snapshot.timestamp_ms < after_snapshot.timestamp_ms:
				after_snapshot = snapshot

	# If we only have one snapshot, use it directly
	if before_snapshot == null and after_snapshot == null:
		return WorldSnapshot.new()

	if before_snapshot == null:
		return after_snapshot.duplicate()

	if after_snapshot == null:
		return before_snapshot.duplicate()

	if before_snapshot == after_snapshot:
		return before_snapshot.duplicate()

	# Interpolate between the two snapshots
	return _interpolate_snapshots(before_snapshot, after_snapshot, target_time_ms)


## Interpolates between two world snapshots
func _interpolate_snapshots(
	before: WorldSnapshot,
	after: WorldSnapshot,
	target_time_ms: int
) -> WorldSnapshot:
	var result := WorldSnapshot.new()
	result.timestamp_ms = target_time_ms

	# Calculate interpolation factor
	var time_range: float = float(after.timestamp_ms - before.timestamp_ms)
	var t: float = 0.0
	if time_range > 0:
		t = float(target_time_ms - before.timestamp_ms) / time_range
	t = clampf(t, 0.0, 1.0)

	# Collect all entity IDs from both snapshots
	var all_entity_ids: Array[int] = []
	for entity_id: int in before.entity_states:
		if entity_id not in all_entity_ids:
			all_entity_ids.append(entity_id)
	for entity_id: int in after.entity_states:
		if entity_id not in all_entity_ids:
			all_entity_ids.append(entity_id)

	# Interpolate each entity
	for entity_id: int in all_entity_ids:
		var before_entity: EntitySnapshot = before.entity_states.get(entity_id) as EntitySnapshot
		var after_entity: EntitySnapshot = after.entity_states.get(entity_id) as EntitySnapshot

		var result_entity := EntitySnapshot.new()
		result_entity.entity_id = entity_id

		if before_entity != null and after_entity != null:
			# Interpolate between both states
			result_entity.position = before_entity.position.lerp(after_entity.position, t)
			result_entity.rotation = lerpf(before_entity.rotation, after_entity.rotation, t)
			result_entity.velocity = before_entity.velocity.lerp(after_entity.velocity, t)
			result_entity.health = lerpf(before_entity.health, after_entity.health, t)
			result_entity.is_alive = before_entity.is_alive and after_entity.is_alive
			result_entity.hitbox_center = before_entity.hitbox_center.lerp(after_entity.hitbox_center, t)
			result_entity.hitbox_size = before_entity.hitbox_size.lerp(after_entity.hitbox_size, t)
		elif before_entity != null:
			result_entity = before_entity.duplicate()
		elif after_entity != null:
			result_entity = after_entity.duplicate()

		result.entity_states[entity_id] = result_entity

	return result


## Gets the ping for a specific peer
func get_peer_ping_ms(peer_id: int) -> int:
	if _connection_manager == null:
		return 0
	if _connection_manager.has_method("get_ping"):
		return _connection_manager.get_ping(peer_id)
	return 0

# endregion

# =============================================================================
# region - Hit Validation
# =============================================================================

## Performs lag-compensated hit detection for a hitscan weapon
func validate_hitscan_hit(
	shooter_id: int,
	shot_origin: Vector3,
	shot_direction: Vector3,
	max_range: float,
	shooter_ping_ms: int = 0
) -> HitResult:
	var result := HitResult.new()

	# Calculate the time when the shot was fired on the shooter's screen
	# Account for one-way delay (ping/2) plus some processing time
	var one_way_delay_ms: int = (shooter_ping_ms / 2) + 10
	var shot_time_ms: int = Time.get_ticks_msec() - one_way_delay_ms

	result.rewind_time_ms = one_way_delay_ms

	# Get the world state at shot time
	var rewound_world: WorldSnapshot = rewind_to_time(shot_time_ms)

	if rewound_world.entity_states.is_empty():
		return result

	# Normalize direction
	shot_direction = shot_direction.normalized()

	# Check ray against all entity hitboxes in the rewound state
	var closest_hit_distance: float = max_range
	var hit_entity_id: int = -1
	var hit_pos: Vector3 = Vector3.ZERO

	for entity_id: int in rewound_world.entity_states:
		# Don't hit yourself
		if entity_id == shooter_id:
			continue

		var entity: EntitySnapshot = rewound_world.entity_states[entity_id] as EntitySnapshot

		# Skip dead entities
		if not entity.is_alive:
			continue

		# Ray-capsule intersection for more accurate human hitbox
		var hit_info: Dictionary = _ray_capsule_intersection(
			shot_origin,
			shot_direction,
			entity.position,
			PLAYER_HITBOX_RADIUS,
			PLAYER_HITBOX_HEIGHT
		)

		if hit_info["hit"] and hit_info["distance"] < closest_hit_distance:
			closest_hit_distance = hit_info["distance"]
			hit_entity_id = entity_id
			hit_pos = hit_info["position"]

			# Determine body part for damage multiplier
			var local_hit_height: float = hit_pos.y - entity.position.y
			if local_hit_height > PLAYER_HITBOX_HEIGHT * 0.75:
				result.body_part = "head"
				result.damage_multiplier = 1.5
			elif local_hit_height < PLAYER_HITBOX_HEIGHT * 0.3:
				result.body_part = "legs"
				result.damage_multiplier = 0.75
			else:
				result.body_part = "body"
				result.damage_multiplier = 1.0

	if hit_entity_id >= 0:
		result.hit = true
		result.target_id = hit_entity_id
		result.hit_position = hit_pos
		result.hit_normal = (shot_origin - hit_pos).normalized()

	return result


## Performs lag-compensated hit detection for a projectile
func validate_projectile_hit(
	shooter_id: int,
	projectile_position: Vector3,
	projectile_radius: float,
	shooter_ping_ms: int = 0
) -> HitResult:
	var result := HitResult.new()

	# For projectiles, we use the current ping since the projectile
	# traveled through the network-simulated world
	var rewind_ms: int = shooter_ping_ms / 2
	var hit_time_ms: int = Time.get_ticks_msec() - rewind_ms

	result.rewind_time_ms = rewind_ms

	# Get the world state at impact time
	var rewound_world: WorldSnapshot = rewind_to_time(hit_time_ms)

	if rewound_world.entity_states.is_empty():
		return result

	# Check sphere against all entity hitboxes
	for entity_id: int in rewound_world.entity_states:
		if entity_id == shooter_id:
			continue

		var entity: EntitySnapshot = rewound_world.entity_states[entity_id] as EntitySnapshot

		if not entity.is_alive:
			continue

		# Sphere-capsule intersection
		if _sphere_capsule_intersection(
			projectile_position,
			projectile_radius,
			entity.position,
			PLAYER_HITBOX_RADIUS,
			PLAYER_HITBOX_HEIGHT
		):
			result.hit = true
			result.target_id = entity_id
			result.hit_position = projectile_position
			result.hit_normal = (projectile_position - entity.hitbox_center).normalized()
			result.damage_multiplier = 1.0
			result.body_part = "body"
			break

	return result

# endregion

# =============================================================================
# region - Geometry Helpers
# =============================================================================

## Ray-capsule intersection test
## Returns {"hit": bool, "distance": float, "position": Vector3}
func _ray_capsule_intersection(
	ray_origin: Vector3,
	ray_direction: Vector3,
	capsule_base: Vector3,
	capsule_radius: float,
	capsule_height: float
) -> Dictionary:
	var result: Dictionary = {"hit": false, "distance": INF, "position": Vector3.ZERO}

	# Capsule is defined as a cylinder with hemispherical caps
	var capsule_top: Vector3 = capsule_base + Vector3(0, capsule_height, 0)
	var capsule_axis: Vector3 = Vector3.UP

	# Project ray onto the plane perpendicular to capsule axis
	var ray_dir_2d: Vector2 = Vector2(ray_direction.x, ray_direction.z)
	var origin_2d: Vector2 = Vector2(ray_origin.x - capsule_base.x, ray_origin.z - capsule_base.z)

	# 2D circle intersection
	var a: float = ray_dir_2d.dot(ray_dir_2d)
	var b: float = 2.0 * origin_2d.dot(ray_dir_2d)
	var c: float = origin_2d.dot(origin_2d) - capsule_radius * capsule_radius

	var discriminant: float = b * b - 4.0 * a * c

	if discriminant < 0:
		return result

	var sqrt_disc: float = sqrt(discriminant)
	var t1: float = (-b - sqrt_disc) / (2.0 * a)
	var t2: float = (-b + sqrt_disc) / (2.0 * a)

	# Check both intersection points
	for t: float in [t1, t2]:
		if t < 0:
			continue

		var hit_point: Vector3 = ray_origin + ray_direction * t
		var hit_height: float = hit_point.y - capsule_base.y

		# Check if hit is within cylinder height (including caps)
		if hit_height >= -capsule_radius and hit_height <= capsule_height + capsule_radius:
			# Adjust for hemispherical caps
			if hit_height < 0:
				# Bottom cap - check sphere
				var cap_center: Vector3 = capsule_base
				if ray_origin.distance_to(cap_center) <= capsule_radius:
					result.hit = true
					result.distance = t
					result.position = hit_point
					return result
			elif hit_height > capsule_height:
				# Top cap - check sphere
				var cap_center: Vector3 = capsule_top
				var to_cap: Vector3 = hit_point - cap_center
				if to_cap.length() <= capsule_radius:
					result.hit = true
					result.distance = t
					result.position = hit_point
					return result
			else:
				# Cylinder body
				result.hit = true
				result.distance = t
				result.position = hit_point
				return result

	return result


## Sphere-capsule intersection test
func _sphere_capsule_intersection(
	sphere_center: Vector3,
	sphere_radius: float,
	capsule_base: Vector3,
	capsule_radius: float,
	capsule_height: float
) -> bool:
	# Find closest point on capsule axis to sphere center
	var capsule_top: Vector3 = capsule_base + Vector3(0, capsule_height, 0)

	var t: float = clampf(
		(sphere_center.y - capsule_base.y) / capsule_height,
		0.0,
		1.0
	)

	var closest_point: Vector3 = capsule_base.lerp(capsule_top, t)

	# Check distance to closest point
	var distance: float = sphere_center.distance_to(closest_point)
	return distance <= (sphere_radius + capsule_radius)

# endregion

# =============================================================================
# region - Debug
# =============================================================================

## Returns debug information about the current state
func get_debug_info() -> Dictionary:
	var valid_snapshots: int = 0
	var oldest_time: int = Time.get_ticks_msec()
	var newest_time: int = 0

	for snapshot: WorldSnapshot in _snapshots:
		if snapshot.timestamp_ms > 0:
			valid_snapshots += 1
			oldest_time = mini(oldest_time, snapshot.timestamp_ms)
			newest_time = maxi(newest_time, snapshot.timestamp_ms)

	return {
		"is_active": _is_active,
		"snapshot_count": valid_snapshots,
		"sequence": _sequence,
		"history_span_ms": newest_time - oldest_time if valid_snapshots > 0 else 0,
		"max_rewind_ms": MAX_REWIND_TIME_MS,
	}

# endregion
