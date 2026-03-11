## Rocket Projectile - Explosive projectile that detonates on impact.
##
## Deals area damage with falloff. Can damage the shooter if too close.
class_name RocketProjectile
extends Area3D


# region -- Properties

## Travel direction.
var direction: Vector3 = Vector3.FORWARD

## Movement speed.
var speed: float = 25.0

## Direct hit damage.
var damage: float = 100.0

## Owner peer ID (to avoid immediate self-collision).
var owner_peer_id: int = 0

## Explosion radius.
var explosion_radius: float = 5.0

## Damage falloff at edge (0.0 = no damage, 1.0 = full damage).
var explosion_falloff: float = 0.4

## Self-damage multiplier.
var self_damage_mult: float = 0.5

## Lifetime before auto-destruct.
var lifetime: float = 5.0

## Has this rocket already exploded?
var _has_exploded: bool = false

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
	if has_meta("self_damage_mult"):
		self_damage_mult = get_meta("self_damage_mult")

	# Connect collision signal
	body_entered.connect(_on_body_entered)

	# Look in travel direction
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

	# Auto-destruct timer
	var timer := Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_expired)
	add_child(timer)
	timer.start()


func _physics_process(delta: float) -> void:
	if _has_exploded:
		return

	global_position += direction * speed * delta


func _on_body_entered(body: Node3D) -> void:
	if _has_exploded:
		return

	# Ignore owner briefly (prevent immediate self-hit)
	if body is CharacterBody3D:
		var char := body as CharacterBody3D
		if char.get("peer_id") == owner_peer_id:
			# Only ignore if very close to spawn point
			return

	_explode()


func _on_lifetime_expired() -> void:
	if not _has_exploded:
		_explode()


## Detonate the rocket.
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

	# Destroy rocket
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

		# Apply self-damage reduction
		if character.get("peer_id") == owner_peer_id:
			damage_mult *= self_damage_mult

		var final_damage := damage * damage_mult

		if final_damage > 0.0 and character.has_method("take_damage"):
			character.take_damage(final_damage, owner_peer_id)


## Calculate damage falloff based on distance.
func _calculate_falloff(distance: float) -> float:
	if distance <= 0.0:
		return 1.0
	if distance >= explosion_radius:
		return 0.0

	# Linear falloff from center to edge
	var falloff_range := 1.0 - explosion_falloff
	var distance_ratio := distance / explosion_radius
	return 1.0 - (distance_ratio * falloff_range)


## Spawn visual explosion effect.
func _spawn_explosion_effect() -> void:
	# Use particle effects manager if available
	if ParticleEffectsManager and ParticleEffectsManager.has_method("spawn_explosion"):
		ParticleEffectsManager.spawn_explosion(global_position, explosion_radius)


func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()
