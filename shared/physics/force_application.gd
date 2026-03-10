## Force Application System for Ragdoll Physics
##
## Provides utilities for applying various types of forces to ragdolls
## in satisfying, exaggerated ways. Includes explosion forces, directional
## knockback, environmental interactions, and combo multipliers.
##
## Usage:
##   ForceApplication.apply_damage_force(ragdoll, damage, direction, hit_point)
##   ForceApplication.apply_explosion(center, radius, force, ragdolls)
##   ForceApplication.apply_environmental_force(ragdoll, env_type, contact_point)
class_name ForceApplication
extends RefCounted


#region Constants

## Force type multipliers for different damage sources
const FORCE_MULTIPLIERS: Dictionary = {
	"bullet": 1.0,
	"rocket": 3.0,
	"melee": 1.5,
	"explosion": 4.0,
	"environmental": 2.0,
	"fall": 0.5,
	"vehicle": 5.0,
}

## Base force magnitude per damage point
const FORCE_PER_DAMAGE: float = 0.5

## Upward bias for dramatic launches (0.0 - 1.0)
const UPWARD_BIAS: float = 0.4

## Spin factor for angular momentum
const SPIN_FACTOR: float = 2.0

## Maximum velocity any ragdoll body can have
const MAX_VELOCITY: float = 50.0

## Minimum force to apply (prevents micro-pushes)
const MIN_FORCE_THRESHOLD: float = 5.0

## Environmental force magnitudes
const ENV_FORCES: Dictionary = {
	"wind": 15.0,
	"water_current": 8.0,
	"conveyor": 12.0,
	"fan": 25.0,
	"geyser": 40.0,
	"bounce_pad": 35.0,
	"lava": 20.0,
}

## Combo multiplier settings
const COMBO_DECAY_TIME: float = 2.0
const COMBO_FORCE_BONUS: float = 0.2  ## 20% more force per combo level
const MAX_COMBO_MULTIPLIER: float = 3.0

#endregion


#region Static Methods - Primary Force Application

## Apply damage-based force to a ragdoll
## @param ragdoll: RagdollSystem to apply force to
## @param damage: Amount of damage dealt (determines force magnitude)
## @param direction: Direction of the attack (normalized)
## @param hit_point: World position where damage was applied
## @param damage_type: Type of damage (affects multiplier)
## @return: Actual force vector applied
static func apply_damage_force(
	ragdoll: RagdollSystem,
	damage: float,
	direction: Vector3,
	hit_point: Vector3 = Vector3.ZERO,
	damage_type: String = "bullet"
) -> Vector3:
	if not ragdoll:
		return Vector3.ZERO

	# Calculate base force
	var multiplier: float = FORCE_MULTIPLIERS.get(damage_type, 1.0) as float
	var force_magnitude: float = damage * FORCE_PER_DAMAGE * multiplier

	# Ensure minimum force
	if force_magnitude < MIN_FORCE_THRESHOLD:
		force_magnitude = MIN_FORCE_THRESHOLD

	# Build force vector with upward bias for dramatic effect
	var force_direction: Vector3 = direction.normalized()
	force_direction += Vector3.UP * UPWARD_BIAS
	force_direction = force_direction.normalized()

	var force: Vector3 = force_direction * force_magnitude

	# Add randomness for natural look
	force += _random_spread() * force_magnitude * 0.1

	# Determine hit bone from hit point
	var hit_bone: String = _determine_hit_bone(ragdoll, hit_point)

	# Apply to ragdoll
	ragdoll.apply_force(force, hit_point, hit_bone)

	return force


## Apply explosion force to multiple ragdolls
## @param center: World position of explosion
## @param radius: Explosion effect radius
## @param base_force: Force at explosion center
## @param ragdolls: Array of RagdollSystem nodes to affect
## @param apply_upward_bias: Whether to add upward force (spectacular launches)
static func apply_explosion(
	center: Vector3,
	radius: float,
	base_force: float,
	ragdolls: Array,
	apply_upward_bias: bool = true
) -> void:
	var explosion_mult: float = FORCE_MULTIPLIERS.get("explosion", 4.0) as float

	for ragdoll_node in ragdolls:
		var ragdoll: RagdollSystem = ragdoll_node as RagdollSystem
		if not ragdoll:
			continue

		var ragdoll_pos: Vector3 = ragdoll.get_ragdoll_position()
		var to_ragdoll: Vector3 = ragdoll_pos - center
		var distance: float = to_ragdoll.length()

		# Skip if outside radius
		if distance > radius:
			continue

		# Calculate falloff (quadratic for realistic feel, but exaggerated)
		var falloff: float = 1.0 - (distance / radius)
		falloff = falloff * falloff  # Square for sharper falloff

		# Calculate force
		var force_magnitude: float = base_force * falloff * explosion_mult

		# Direction away from center
		var force_direction: Vector3 = to_ragdoll.normalized()

		# Add upward bias for spectacular launches
		if apply_upward_bias:
			force_direction += Vector3.UP * 0.6
			force_direction = force_direction.normalized()

		var force: Vector3 = force_direction * force_magnitude

		# Apply with some spin
		ragdoll.apply_explosion_force(center, force_magnitude, radius)


## Apply directional knockback (e.g., from melee hit, vehicle collision)
## @param ragdoll: Target ragdoll
## @param direction: Knockback direction
## @param magnitude: Force strength
## @param add_spin: Whether to add rotational force
static func apply_knockback(
	ragdoll: RagdollSystem,
	direction: Vector3,
	magnitude: float,
	add_spin: bool = true
) -> void:
	if not ragdoll:
		return

	ragdoll.apply_knockback(direction, magnitude)

	# Add angular momentum for dramatic spinning
	if add_spin:
		var spin_axis: Vector3 = direction.cross(Vector3.UP).normalized()
		if spin_axis.length_squared() < 0.01:
			spin_axis = Vector3.RIGHT

		_apply_spin(ragdoll, spin_axis, magnitude * SPIN_FACTOR)


## Apply environmental force (wind, water, etc.)
## @param ragdoll: Target ragdoll
## @param env_type: Type of environmental force
## @param contact_point: Where the environment touches the ragdoll
## @param custom_direction: Override direction (optional)
static func apply_environmental_force(
	ragdoll: RagdollSystem,
	env_type: String,
	contact_point: Vector3 = Vector3.ZERO,
	custom_direction: Vector3 = Vector3.ZERO
) -> void:
	if not ragdoll:
		return

	var force_magnitude: float = ENV_FORCES.get(env_type, 10.0) as float
	var force_direction: Vector3 = custom_direction

	# Default directions for environment types
	if force_direction.length_squared() < 0.01:
		match env_type:
			"wind":
				force_direction = Vector3(1, 0.1, 0)  # Horizontal with slight lift
			"water_current":
				force_direction = Vector3(1, -0.2, 0)  # Horizontal with sink
			"conveyor":
				force_direction = Vector3(1, 0, 0)  # Pure horizontal
			"fan":
				force_direction = Vector3.UP  # Straight up
			"geyser":
				force_direction = Vector3(0, 1, 0.1)  # Up with slight angle
			"bounce_pad":
				force_direction = Vector3.UP
			"lava":
				force_direction = Vector3(0, 1, 0)  # Pop up from lava
			_:
				force_direction = Vector3.UP

	force_direction = force_direction.normalized()
	var force: Vector3 = force_direction * force_magnitude

	ragdoll.apply_force(force, contact_point, "root")


## Apply combo-enhanced force (increases with consecutive hits)
## @param ragdoll: Target ragdoll
## @param base_force: Base force vector
## @param combo_count: Current combo hit count
## @param hit_point: Impact location
static func apply_combo_force(
	ragdoll: RagdollSystem,
	base_force: Vector3,
	combo_count: int,
	hit_point: Vector3 = Vector3.ZERO
) -> void:
	if not ragdoll:
		return

	# Calculate combo multiplier
	var combo_bonus: float = 1.0 + (combo_count * COMBO_FORCE_BONUS)
	combo_bonus = minf(combo_bonus, MAX_COMBO_MULTIPLIER)

	var enhanced_force: Vector3 = base_force * combo_bonus

	# Higher combos get more upward bias (juggle physics)
	if combo_count > 2:
		enhanced_force += Vector3.UP * base_force.length() * 0.2 * combo_count

	ragdoll.apply_force(enhanced_force, hit_point, "")


## Apply impact force when ragdoll hits a surface
## @param ragdoll: Target ragdoll
## @param collision_normal: Surface normal at collision point
## @param collision_velocity: Velocity at moment of collision
## @param surface_type: Type of surface (affects bounce/absorption)
static func apply_impact_force(
	ragdoll: RagdollSystem,
	collision_normal: Vector3,
	collision_velocity: Vector3,
	surface_type: String = "default"
) -> void:
	if not ragdoll:
		return

	var speed: float = collision_velocity.length()
	if speed < 2.0:
		return  # Ignore minor impacts

	# Reflect velocity for bounce
	var bounce_factor: float = _get_surface_bounce(surface_type)
	var reflected: Vector3 = collision_velocity.bounce(collision_normal)
	var bounce_force: Vector3 = reflected * bounce_factor

	# Absorb some energy
	var absorption: float = _get_surface_absorption(surface_type)
	bounce_force *= (1.0 - absorption)

	ragdoll.apply_force(bounce_force, Vector3.ZERO, "root")

#endregion


#region Static Methods - Utility

## Calculate force needed to launch ragdoll to target position
## @param ragdoll: Source ragdoll
## @param target: Target world position
## @param flight_time: Desired time to reach target (affects arc)
## @return: Required launch force
static func calculate_launch_force(
	ragdoll: RagdollSystem,
	target: Vector3,
	flight_time: float = 1.0
) -> Vector3:
	if not ragdoll:
		return Vector3.ZERO

	var start_pos: Vector3 = ragdoll.get_ragdoll_position()
	var displacement: Vector3 = target - start_pos

	# Basic projectile motion calculation
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

	# Horizontal velocity needed
	var horizontal_vel: Vector3 = Vector3(displacement.x, 0, displacement.z) / flight_time

	# Vertical velocity needed (accounting for gravity)
	var vertical_vel: float = (displacement.y + 0.5 * gravity * flight_time * flight_time) / flight_time

	var launch_velocity: Vector3 = horizontal_vel + Vector3.UP * vertical_vel

	# Convert to force (assuming unit mass)
	return launch_velocity * 10.0  # Impulse factor


## Get random spread vector for natural-looking forces
static func _random_spread() -> Vector3:
	return Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-0.5, 0.5),
		randf_range(-1.0, 1.0)
	).normalized()


## Determine which bone was hit based on hit point
static func _determine_hit_bone(ragdoll: RagdollSystem, hit_point: Vector3) -> String:
	if hit_point == Vector3.ZERO:
		return "root"

	# Find closest bone to hit point
	var closest_bone: String = "root"
	var closest_distance: float = INF

	for bone_name: String in ragdoll.physics_bones:
		var bone: RigidBody3D = ragdoll.physics_bones[bone_name] as RigidBody3D
		if not bone:
			continue

		var distance: float = bone.global_position.distance_to(hit_point)
		if distance < closest_distance:
			closest_distance = distance
			closest_bone = bone_name

	return closest_bone


## Apply spin to ragdoll
static func _apply_spin(ragdoll: RagdollSystem, axis: Vector3, magnitude: float) -> void:
	# Apply angular velocity to all bones
	for bone_name: String in ragdoll.physics_bones:
		var bone: RigidBody3D = ragdoll.physics_bones[bone_name] as RigidBody3D
		if bone:
			bone.angular_velocity += axis * magnitude * randf_range(0.8, 1.2)


## Get bounce factor for surface type
static func _get_surface_bounce(surface_type: String) -> float:
	match surface_type:
		"rubber", "bouncy":
			return 0.9
		"metal":
			return 0.5
		"wood":
			return 0.4
		"dirt", "grass":
			return 0.2
		"water":
			return 0.1
		"soft", "cushion":
			return 0.05
		_:
			return 0.3


## Get absorption factor for surface type
static func _get_surface_absorption(surface_type: String) -> float:
	match surface_type:
		"rubber", "bouncy":
			return 0.1
		"metal":
			return 0.3
		"wood":
			return 0.4
		"dirt", "grass":
			return 0.6
		"water":
			return 0.7
		"soft", "cushion":
			return 0.9
		_:
			return 0.5

#endregion


#region Static Methods - Special Effects

## Apply "home run" force (dramatic baseball-bat style hit)
## @param ragdoll: Target ragdoll
## @param swing_direction: Direction of the swing
## @param power: Hit power (0.0 - 1.0)
static func apply_home_run_hit(
	ragdoll: RagdollSystem,
	swing_direction: Vector3,
	power: float = 1.0
) -> void:
	if not ragdoll:
		return

	var base_force: float = 80.0 * power
	var direction: Vector3 = swing_direction.normalized()

	# Strong upward component for arc
	direction += Vector3.UP * 0.7
	direction = direction.normalized()

	var force: Vector3 = direction * base_force

	ragdoll.apply_force(force, Vector3.ZERO, "torso")

	# Add dramatic spin
	var spin_axis: Vector3 = swing_direction.cross(Vector3.UP)
	_apply_spin(ragdoll, spin_axis, 15.0)


## Apply "ragdoll toss" (grab and throw)
## @param ragdoll: Target ragdoll
## @param throw_direction: Direction to throw
## @param throw_power: Force magnitude
static func apply_throw(
	ragdoll: RagdollSystem,
	throw_direction: Vector3,
	throw_power: float
) -> void:
	if not ragdoll:
		return

	var direction: Vector3 = throw_direction.normalized()
	direction += Vector3.UP * 0.3  # Slight upward arc
	direction = direction.normalized()

	var force: Vector3 = direction * throw_power

	ragdoll.apply_force(force, Vector3.ZERO, "pelvis")


## Apply "ground pound" force (downward slam that bounces)
## @param ragdoll: Target ragdoll
## @param impact_point: Where the slam hits
## @param radius: Effect radius
static func apply_ground_pound(
	ragdoll: RagdollSystem,
	impact_point: Vector3,
	radius: float = 5.0
) -> void:
	if not ragdoll:
		return

	var ragdoll_pos: Vector3 = ragdoll.get_ragdoll_position()
	var distance: float = ragdoll_pos.distance_to(impact_point)

	if distance > radius:
		return

	var falloff: float = 1.0 - (distance / radius)
	var force_magnitude: float = 60.0 * falloff * falloff

	# Direction is up and away from impact
	var horizontal_dir: Vector3 = (ragdoll_pos - impact_point)
	horizontal_dir.y = 0
	horizontal_dir = horizontal_dir.normalized()

	var force_direction: Vector3 = (horizontal_dir + Vector3.UP * 1.5).normalized()
	var force: Vector3 = force_direction * force_magnitude

	ragdoll.apply_force(force, impact_point, "root")


## Apply suction force (pull towards point)
## @param ragdoll: Target ragdoll
## @param suction_point: Center of suction
## @param suction_power: Pull strength
## @param max_distance: Maximum effect range
static func apply_suction(
	ragdoll: RagdollSystem,
	suction_point: Vector3,
	suction_power: float,
	max_distance: float = 10.0
) -> void:
	if not ragdoll:
		return

	var ragdoll_pos: Vector3 = ragdoll.get_ragdoll_position()
	var to_point: Vector3 = suction_point - ragdoll_pos
	var distance: float = to_point.length()

	if distance > max_distance:
		return

	var falloff: float = 1.0 - (distance / max_distance)
	var force_magnitude: float = suction_power * falloff

	var force: Vector3 = to_point.normalized() * force_magnitude

	ragdoll.apply_force(force, Vector3.ZERO, "pelvis")

#endregion


#region Static Methods - Particle Effects Integration

## Get recommended particle spawn point for impact
## @param ragdoll: Target ragdoll
## @param hit_bone: Bone that was hit
## @return: World position for particle spawn
static func get_impact_particle_position(ragdoll: RagdollSystem, hit_bone: String) -> Vector3:
	if not ragdoll:
		return Vector3.ZERO

	var bone: RigidBody3D = ragdoll.physics_bones.get(hit_bone) as RigidBody3D
	if bone:
		return bone.global_position

	return ragdoll.get_ragdoll_position()


## Get recommended particle velocity based on force
## @param force: Applied force
## @return: Velocity vector for particles
static func get_impact_particle_velocity(force: Vector3) -> Vector3:
	return force.normalized() * minf(force.length() * 0.5, 20.0)

#endregion
