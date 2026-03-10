## Grenade Projectile - Bouncing explosive that detonates after fuse or on direct player hit.
##
## Uses RigidBody3D for realistic physics including bouncing off walls.
class_name GrenadeProjectile
extends RigidBody3D


# region -- Properties

## Initial velocity direction.
var direction: Vector3 = Vector3.FORWARD

## Initial speed.
var speed: float = 20.0

## Explosion damage.
var damage: float = 80.0

## Owner peer ID.
var owner_peer_id: int = 0

## Explosion radius.
var explosion_radius: float = 4.0

## Damage falloff at edge.
var explosion_falloff: float = 0.5

## Time until auto-detonate.
var fuse_time: float = 2.5

## Has this grenade already exploded?
var _has_exploded: bool = false

## Time since spawn.
var _time_alive: float = 0.0

## Has initial velocity been applied?
var _velocity_applied: bool = false

# endregion


func _ready() -> void:
	# Get metadata if set
	if has_meta("direction"):
		direction = get_meta("direction")
	if has_meta("speed"):
		speed = get_meta("speed")
	if has_meta("damage"):
		damage = get_meta("damage")
	if has_meta("owner_peer_id"):
		owner_peer_id = get_meta("owner_peer_id")
	if has_meta("explosion_radius"):
		explosion_radius = get_meta("explosion_radius")
	if has_meta("explosion_falloff"):
		explosion_falloff = get_meta("explosion_falloff")
	if has_meta("fuse_time"):
		fuse_time = get_meta("fuse_time")
	if has_meta("gravity_scale"):
		gravity_scale = get_meta("gravity_scale")

	# Connect collision signal
	body_entered.connect(_on_body_entered)

	# Apply initial velocity on next physics frame
	call_deferred("_apply_initial_velocity")


func _apply_initial_velocity() -> void:
	if _velocity_applied:
		return
	_velocity_applied = true

	linear_velocity = direction * speed


func _physics_process(delta: float) -> void:
	if _has_exploded:
		return

	_time_alive += delta

	# Check fuse timer
	if _time_alive >= fuse_time:
		_explode()


func _on_body_entered(body: Node) -> void:
	if _has_exploded:
		return

	# Explode on direct player hit (except owner briefly after launch)
	if body is CharacterBody3D:
		var char := body as CharacterBody3D
		var char_peer_id: int = char.get("peer_id") if char.get("peer_id") != null else -1

		# Allow owner hit after first bounce / short delay
		if char_peer_id == owner_peer_id and _time_alive < 0.2:
			return

		_explode()


## Detonate the grenade.
func _explode() -> void:
	if _has_exploded:
		return

	_has_exploded = true

	# Only server processes damage
	if _is_server():
		_deal_explosion_damage()

	# Spawn explosion effect
	_spawn_explosion_effect()

	# Play explosion sound
	if AudioManager:
		AudioManager.play_sfx_3d("explosion", global_position)

	# Destroy grenade
	queue_free()


## Deal damage to all entities in explosion radius.
func _deal_explosion_damage() -> void:
	var explosion_pos := global_position

	# Find all bodies in radius
	var space_state := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = explosion_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, explosion_pos)
	query.collision_mask = 0b10  # Players layer

	var results := space_state.intersect_shape(query, 32)

	for result: Dictionary in results:
		var collider: Node3D = result.get("collider")
		if not collider or not collider is CharacterBody3D:
			continue

		var character := collider as CharacterBody3D

		# Calculate distance-based damage
		var distance := explosion_pos.distance_to(character.global_position)
		var damage_mult := _calculate_falloff(distance)

		# Reduced self-damage
		if character.get("peer_id") == owner_peer_id:
			damage_mult *= 0.5

		var final_damage := damage * damage_mult

		if final_damage > 0.0 and character.has_method("take_damage"):
			character.take_damage(final_damage, owner_peer_id)


## Calculate damage falloff based on distance.
func _calculate_falloff(distance: float) -> float:
	if distance <= 0.0:
		return 1.0
	if distance >= explosion_radius:
		return 0.0

	var falloff_range := 1.0 - explosion_falloff
	var distance_ratio := distance / explosion_radius
	return 1.0 - (distance_ratio * falloff_range)


## Spawn visual explosion effect.
func _spawn_explosion_effect() -> void:
	if ParticleEffectsManager and ParticleEffectsManager.has_method("spawn_explosion"):
		ParticleEffectsManager.spawn_explosion(global_position, explosion_radius * 0.8)


func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()
