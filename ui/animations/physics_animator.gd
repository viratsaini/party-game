## PhysicsAnimator - Advanced physics-based animation system for UI elements.
##
## Features:
## - Spring physics for all movements (damping, stiffness, mass)
## - Chain dynamics for linked elements
## - Collision detection between animated elements
## - Gravity effects on UI elements
## - Wind simulation for particles and cloth-like effects
## - Constraint systems (distance, angle, area)
##
## Usage:
##   var animator := PhysicsAnimator.new()
##   animator.add_body(my_control, PhysicsBody.new())
##   animator.apply_force(my_control, Vector2(100, 0))
##   animator.add_spring(control1, control2, 100.0, 0.5)
class_name PhysicsAnimator
extends RefCounted


# region - Signals

## Emitted when a collision occurs between two bodies
signal collision_detected(body_a: PhysicsBody, body_b: PhysicsBody, contact_point: Vector2)

## Emitted when a body reaches rest (velocity near zero)
signal body_at_rest(body: PhysicsBody)

## Emitted when a body exceeds bounds
signal body_out_of_bounds(body: PhysicsBody)

## Emitted each physics step with delta
signal step_completed(delta: float)

# endregion


# region - Constants

## Default physics values
const DEFAULT_GRAVITY: Vector2 = Vector2(0, 980)
const DEFAULT_DAMPING: float = 0.98
const DEFAULT_STIFFNESS: float = 200.0
const DEFAULT_MASS: float = 1.0
const REST_THRESHOLD: float = 0.1
const MAX_VELOCITY: float = 2000.0
const SUBSTEPS: int = 4

# endregion


# region - Inner Classes

## Physics properties for a single body
class PhysicsBody extends RefCounted:
	## Node being animated
	var node: Node

	## Current position
	var position: Vector2 = Vector2.ZERO

	## Previous position (for Verlet integration)
	var prev_position: Vector2 = Vector2.ZERO

	## Current velocity
	var velocity: Vector2 = Vector2.ZERO

	## Accumulated forces
	var force: Vector2 = Vector2.ZERO

	## Mass of the body
	var mass: float = 1.0

	## Inverse mass (0 for static bodies)
	var inv_mass: float = 1.0

	## Linear damping (air resistance)
	var damping: float = 0.98

	## Angular properties
	var rotation: float = 0.0
	var angular_velocity: float = 0.0
	var angular_damping: float = 0.95

	## Collision properties
	var collision_radius: float = 20.0
	var collision_enabled: bool = true
	var collision_layer: int = 1
	var collision_mask: int = 1
	var bounciness: float = 0.5
	var friction: float = 0.3

	## Constraints
	var pinned: bool = false
	var pin_position: Vector2 = Vector2.ZERO
	var bounds: Rect2 = Rect2()
	var use_bounds: bool = false

	## State
	var is_sleeping: bool = false
	var sleep_counter: int = 0
	var active: bool = true

	## Custom data
	var user_data: Dictionary = {}


	func _init(p_node: Node = null) -> void:
		node = p_node
		if node:
			position = _get_node_position(node)
			prev_position = position


	func set_mass(value: float) -> void:
		mass = maxf(value, 0.001)
		inv_mass = 1.0 / mass if mass > 0.0 else 0.0


	func set_static(is_static: bool) -> void:
		if is_static:
			inv_mass = 0.0
			pinned = true
		else:
			inv_mass = 1.0 / mass


	func apply_force(f: Vector2) -> void:
		if inv_mass > 0.0:
			force += f


	func apply_impulse(impulse: Vector2) -> void:
		if inv_mass > 0.0:
			velocity += impulse * inv_mass


	func get_kinetic_energy() -> float:
		return 0.5 * mass * velocity.length_squared()


	func _get_node_position(n: Node) -> Vector2:
		if n is Control:
			return (n as Control).position + (n as Control).size / 2.0
		elif n is Node2D:
			return (n as Node2D).position
		return Vector2.ZERO


## Spring constraint between two bodies
class Spring extends RefCounted:
	var body_a: PhysicsBody
	var body_b: PhysicsBody
	var rest_length: float = 100.0
	var stiffness: float = 200.0
	var damping: float = 10.0
	var min_length: float = 0.0
	var max_length: float = INF
	var enabled: bool = true

	func _init(
		a: PhysicsBody = null,
		b: PhysicsBody = null,
		p_rest_length: float = 100.0,
		p_stiffness: float = 200.0,
		p_damping: float = 10.0
	) -> void:
		body_a = a
		body_b = b
		rest_length = p_rest_length
		stiffness = p_stiffness
		damping = p_damping


## Distance constraint
class DistanceConstraint extends RefCounted:
	var body_a: PhysicsBody
	var body_b: PhysicsBody
	var distance: float = 100.0
	var stiffness: float = 1.0
	var enabled: bool = true

	func _init(a: PhysicsBody = null, b: PhysicsBody = null, dist: float = 100.0) -> void:
		body_a = a
		body_b = b
		distance = dist


## Chain of linked bodies
class Chain extends RefCounted:
	var bodies: Array[PhysicsBody] = []
	var springs: Array[Spring] = []
	var anchor_start: bool = true
	var anchor_end: bool = false
	var segment_length: float = 20.0
	var stiffness: float = 500.0
	var damping: float = 15.0

	func _init(
		num_segments: int = 5,
		p_segment_length: float = 20.0,
		start_pos: Vector2 = Vector2.ZERO
	) -> void:
		segment_length = p_segment_length

		for i in range(num_segments):
			var body := PhysicsBody.new()
			body.position = start_pos + Vector2(0, i * segment_length)
			body.prev_position = body.position
			body.mass = 0.5
			body.inv_mass = 2.0
			bodies.append(body)

		# Create springs between segments
		for i in range(num_segments - 1):
			var spring := Spring.new(bodies[i], bodies[i + 1], segment_length, stiffness, damping)
			springs.append(spring)

		# Anchor first body
		if anchor_start and not bodies.is_empty():
			bodies[0].pinned = true
			bodies[0].pin_position = bodies[0].position


	func set_anchor_position(pos: Vector2) -> void:
		if not bodies.is_empty():
			bodies[0].pin_position = pos


## Wind zone affecting physics bodies
class WindZone extends RefCounted:
	var bounds: Rect2 = Rect2(0, 0, 1000, 1000)
	var direction: Vector2 = Vector2(1, 0)
	var strength: float = 50.0
	var turbulence: float = 0.3
	var frequency: float = 2.0
	var enabled: bool = true
	var _time: float = 0.0

	func get_force_at(pos: Vector2, time: float) -> Vector2:
		if not enabled or not bounds.has_point(pos):
			return Vector2.ZERO

		_time = time

		# Base wind force
		var force := direction.normalized() * strength

		# Add turbulence (Perlin-like noise approximation)
		var noise_x := sin(pos.x * 0.01 + time * frequency) * cos(pos.y * 0.01)
		var noise_y := cos(pos.x * 0.01) * sin(pos.y * 0.01 + time * frequency)

		force += Vector2(noise_x, noise_y) * strength * turbulence

		return force


## Gravity zone
class GravityZone extends RefCounted:
	var position: Vector2 = Vector2.ZERO
	var radius: float = 200.0
	var strength: float = 500.0
	var falloff: float = 2.0  ## Falloff exponent
	var is_attractor: bool = true  ## False for repulsor
	var enabled: bool = true

	func get_force_at(body_pos: Vector2) -> Vector2:
		if not enabled:
			return Vector2.ZERO

		var diff := position - body_pos
		var dist := diff.length()

		if dist < 1.0 or dist > radius:
			return Vector2.ZERO

		var normalized_dist := dist / radius
		var force_magnitude := strength * pow(1.0 - normalized_dist, falloff)

		var force := diff.normalized() * force_magnitude

		if not is_attractor:
			force = -force

		return force

# endregion


# region - State

## All physics bodies
var bodies: Dictionary = {}  ## Node -> PhysicsBody

## All springs
var springs: Array[Spring] = []

## All distance constraints
var constraints: Array[DistanceConstraint] = []

## All chains
var chains: Array[Chain] = []

## Wind zones
var wind_zones: Array[WindZone] = []

## Gravity zones
var gravity_zones: Array[GravityZone] = []

## Global settings
var gravity: Vector2 = DEFAULT_GRAVITY
var global_damping: float = DEFAULT_DAMPING
var time_scale: float = 1.0
var paused: bool = false
var collision_enabled: bool = true

## Bounds for all bodies
var global_bounds: Rect2 = Rect2(0, 0, 1920, 1080)
var use_global_bounds: bool = false

## Performance
var max_bodies: int = 100
var sleep_enabled: bool = true

## Internal
var _accumulated_time: float = 0.0
var _fixed_timestep: float = 1.0 / 60.0

# endregion


# region - Body Management

## Adds a physics body for a node
func add_body(node: Node, config: Dictionary = {}) -> PhysicsBody:
	if bodies.size() >= max_bodies:
		push_warning("PhysicsAnimator: Maximum body count reached")
		return null

	var body := PhysicsBody.new(node)

	# Apply configuration
	if config.has("mass"):
		body.set_mass(config.mass)
	if config.has("damping"):
		body.damping = config.damping
	if config.has("collision_radius"):
		body.collision_radius = config.collision_radius
	if config.has("bounciness"):
		body.bounciness = config.bounciness
	if config.has("friction"):
		body.friction = config.friction
	if config.has("static"):
		body.set_static(config.static)
	if config.has("bounds"):
		body.bounds = config.bounds
		body.use_bounds = true

	bodies[node] = body
	return body


## Gets a body by node
func get_body(node: Node) -> PhysicsBody:
	return bodies.get(node)


## Removes a body
func remove_body(node: Node) -> void:
	if bodies.has(node):
		var body: PhysicsBody = bodies[node]

		# Remove any springs connected to this body
		for i in range(springs.size() - 1, -1, -1):
			if springs[i].body_a == body or springs[i].body_b == body:
				springs.remove_at(i)

		# Remove any constraints
		for i in range(constraints.size() - 1, -1, -1):
			if constraints[i].body_a == body or constraints[i].body_b == body:
				constraints.remove_at(i)

		bodies.erase(node)


## Clears all bodies
func clear_bodies() -> void:
	bodies.clear()
	springs.clear()
	constraints.clear()
	chains.clear()


## Gets body count
func get_body_count() -> int:
	return bodies.size()

# endregion


# region - Force Application

## Applies a force to a body
func apply_force(node: Node, force: Vector2) -> void:
	var body := get_body(node)
	if body:
		body.apply_force(force)


## Applies an impulse to a body
func apply_impulse(node: Node, impulse: Vector2) -> void:
	var body := get_body(node)
	if body:
		body.apply_impulse(impulse)


## Applies a force to all bodies
func apply_force_all(force: Vector2) -> void:
	for body: PhysicsBody in bodies.values():
		body.apply_force(force)


## Applies an explosion force from a point
func apply_explosion(center: Vector2, force: float, radius: float) -> void:
	for body: PhysicsBody in bodies.values():
		var diff := body.position - center
		var dist := diff.length()

		if dist < radius and dist > 0.1:
			var falloff := 1.0 - (dist / radius)
			var explosion_force := diff.normalized() * force * falloff
			body.apply_impulse(explosion_force)


## Applies an implosion force toward a point
func apply_implosion(center: Vector2, force: float, radius: float) -> void:
	apply_explosion(center, -force, radius)


## Sets velocity directly
func set_velocity(node: Node, velocity: Vector2) -> void:
	var body := get_body(node)
	if body:
		body.velocity = velocity

# endregion


# region - Spring Management

## Adds a spring between two nodes
func add_spring(
	node_a: Node,
	node_b: Node,
	rest_length: float = -1.0,
	stiffness: float = DEFAULT_STIFFNESS,
	damping: float = 10.0
) -> Spring:
	var body_a := get_body(node_a)
	var body_b := get_body(node_b)

	if not body_a or not body_b:
		push_warning("PhysicsAnimator: Both nodes must have bodies")
		return null

	# Auto-calculate rest length if not specified
	if rest_length < 0.0:
		rest_length = body_a.position.distance_to(body_b.position)

	var spring := Spring.new(body_a, body_b, rest_length, stiffness, damping)
	springs.append(spring)

	return spring


## Removes a spring
func remove_spring(spring: Spring) -> void:
	springs.erase(spring)


## Removes all springs between two nodes
func remove_springs_between(node_a: Node, node_b: Node) -> void:
	var body_a := get_body(node_a)
	var body_b := get_body(node_b)

	if not body_a or not body_b:
		return

	for i in range(springs.size() - 1, -1, -1):
		var s := springs[i]
		if (s.body_a == body_a and s.body_b == body_b) or \
		   (s.body_a == body_b and s.body_b == body_a):
			springs.remove_at(i)

# endregion


# region - Constraint Management

## Adds a distance constraint
func add_distance_constraint(
	node_a: Node,
	node_b: Node,
	distance: float = -1.0,
	stiffness: float = 1.0
) -> DistanceConstraint:
	var body_a := get_body(node_a)
	var body_b := get_body(node_b)

	if not body_a or not body_b:
		return null

	if distance < 0.0:
		distance = body_a.position.distance_to(body_b.position)

	var constraint := DistanceConstraint.new(body_a, body_b, distance)
	constraint.stiffness = stiffness
	constraints.append(constraint)

	return constraint


## Pins a body to a position
func pin_body(node: Node, position: Vector2 = Vector2.INF) -> void:
	var body := get_body(node)
	if body:
		body.pinned = true
		if position != Vector2.INF:
			body.pin_position = position
		else:
			body.pin_position = body.position


## Unpins a body
func unpin_body(node: Node) -> void:
	var body := get_body(node)
	if body:
		body.pinned = false

# endregion


# region - Chain Management

## Creates a chain of linked bodies
func create_chain(
	start_pos: Vector2,
	num_segments: int,
	segment_length: float = 20.0,
	stiffness: float = 500.0,
	damping: float = 15.0
) -> Chain:
	var chain := Chain.new(num_segments, segment_length, start_pos)
	chain.stiffness = stiffness
	chain.damping = damping

	# Update spring properties
	for spring in chain.springs:
		spring.stiffness = stiffness
		spring.damping = damping

	chains.append(chain)
	return chain


## Removes a chain
func remove_chain(chain: Chain) -> void:
	chains.erase(chain)


## Updates chain anchor position
func set_chain_anchor(chain: Chain, position: Vector2) -> void:
	chain.set_anchor_position(position)

# endregion


# region - Wind and Gravity Zones

## Adds a wind zone
func add_wind_zone(
	bounds: Rect2,
	direction: Vector2 = Vector2(1, 0),
	strength: float = 50.0,
	turbulence: float = 0.3
) -> WindZone:
	var zone := WindZone.new()
	zone.bounds = bounds
	zone.direction = direction
	zone.strength = strength
	zone.turbulence = turbulence
	wind_zones.append(zone)
	return zone


## Adds a gravity zone (attractor or repulsor)
func add_gravity_zone(
	position: Vector2,
	radius: float = 200.0,
	strength: float = 500.0,
	is_attractor: bool = true
) -> GravityZone:
	var zone := GravityZone.new()
	zone.position = position
	zone.radius = radius
	zone.strength = strength
	zone.is_attractor = is_attractor
	gravity_zones.append(zone)
	return zone


## Removes a wind zone
func remove_wind_zone(zone: WindZone) -> void:
	wind_zones.erase(zone)


## Removes a gravity zone
func remove_gravity_zone(zone: GravityZone) -> void:
	gravity_zones.erase(zone)

# endregion


# region - Simulation

## Main update function - call each frame
func update(delta: float) -> void:
	if paused:
		return

	delta *= time_scale

	# Use fixed timestep with accumulator for stability
	_accumulated_time += delta

	while _accumulated_time >= _fixed_timestep:
		_physics_step(_fixed_timestep)
		_accumulated_time -= _fixed_timestep

	# Interpolate remaining time
	var alpha: float = _accumulated_time / _fixed_timestep
	_interpolate_positions(alpha)

	# Apply to nodes
	_apply_to_nodes()

	step_completed.emit(delta)


func _physics_step(dt: float) -> void:
	# Apply forces
	_apply_forces(dt)

	# Integrate
	_integrate(dt)

	# Solve constraints
	for _i in range(SUBSTEPS):
		_solve_springs(dt)
		_solve_constraints()
		_solve_chains(dt)

	# Handle collisions
	if collision_enabled:
		_solve_collisions()

	# Apply bounds
	_apply_bounds()

	# Check sleeping
	if sleep_enabled:
		_check_sleeping()


func _apply_forces(dt: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0

	for body: PhysicsBody in bodies.values():
		if not body.active or body.pinned or body.is_sleeping:
			continue

		# Apply gravity
		body.apply_force(gravity * body.mass)

		# Apply wind zones
		for zone: WindZone in wind_zones:
			var wind_force := zone.get_force_at(body.position, time)
			body.apply_force(wind_force)

		# Apply gravity zones
		for zone: GravityZone in gravity_zones:
			var grav_force := zone.get_force_at(body.position)
			body.apply_force(grav_force)


func _integrate(dt: float) -> void:
	for body: PhysicsBody in bodies.values():
		if not body.active or body.pinned:
			if body.pinned:
				body.position = body.pin_position
				body.velocity = Vector2.ZERO
			continue

		if body.is_sleeping:
			continue

		# Verlet integration
		var acceleration := body.force * body.inv_mass

		# Store previous position
		var temp := body.position

		# Update position
		body.position = body.position * 2.0 - body.prev_position + acceleration * dt * dt
		body.prev_position = temp

		# Calculate velocity from position change
		body.velocity = (body.position - body.prev_position) / dt

		# Apply damping
		body.velocity *= body.damping * global_damping

		# Clamp velocity
		if body.velocity.length() > MAX_VELOCITY:
			body.velocity = body.velocity.normalized() * MAX_VELOCITY

		# Clear forces
		body.force = Vector2.ZERO

		# Angular integration
		body.rotation += body.angular_velocity * dt
		body.angular_velocity *= body.angular_damping


func _solve_springs(dt: float) -> void:
	for spring: Spring in springs:
		if not spring.enabled:
			continue

		var body_a := spring.body_a
		var body_b := spring.body_b

		if not body_a or not body_b:
			continue

		var diff := body_b.position - body_a.position
		var dist := diff.length()

		if dist < 0.0001:
			continue

		var direction := diff / dist

		# Clamp length
		var target_dist := clampf(dist, spring.min_length, spring.max_length)

		# Spring force (Hooke's law)
		var displacement := target_dist - spring.rest_length
		var spring_force := direction * spring.stiffness * displacement

		# Damping force
		var relative_velocity := body_b.velocity - body_a.velocity
		var damping_force := direction * relative_velocity.dot(direction) * spring.damping

		var total_force := spring_force + damping_force

		# Apply forces
		if body_a.inv_mass > 0.0:
			body_a.velocity += total_force * body_a.inv_mass * dt
		if body_b.inv_mass > 0.0:
			body_b.velocity -= total_force * body_b.inv_mass * dt


func _solve_constraints() -> void:
	for constraint: DistanceConstraint in constraints:
		if not constraint.enabled:
			continue

		var body_a := constraint.body_a
		var body_b := constraint.body_b

		if not body_a or not body_b:
			continue

		var diff := body_b.position - body_a.position
		var dist := diff.length()

		if dist < 0.0001:
			continue

		var direction := diff / dist
		var error := dist - constraint.distance

		# Calculate correction
		var correction := direction * error * constraint.stiffness * 0.5

		# Apply based on mass ratio
		var total_mass := body_a.inv_mass + body_b.inv_mass
		if total_mass > 0.0:
			var ratio_a := body_a.inv_mass / total_mass
			var ratio_b := body_b.inv_mass / total_mass

			if body_a.inv_mass > 0.0 and not body_a.pinned:
				body_a.position += correction * ratio_a
			if body_b.inv_mass > 0.0 and not body_b.pinned:
				body_b.position -= correction * ratio_b


func _solve_chains(dt: float) -> void:
	for chain: Chain in chains:
		# Update anchored bodies
		if chain.anchor_start and not chain.bodies.is_empty():
			chain.bodies[0].position = chain.bodies[0].pin_position

		if chain.anchor_end and not chain.bodies.is_empty():
			var last := chain.bodies[chain.bodies.size() - 1]
			last.position = last.pin_position

		# Solve chain springs
		for spring: Spring in chain.springs:
			var body_a := spring.body_a
			var body_b := spring.body_b

			var diff := body_b.position - body_a.position
			var dist := diff.length()

			if dist < 0.0001:
				continue

			var direction := diff / dist
			var error := dist - spring.rest_length

			# Position correction
			var correction := direction * error * 0.5

			if not body_a.pinned:
				body_a.position += correction
			if not body_b.pinned:
				body_b.position -= correction


func _solve_collisions() -> void:
	var body_array: Array = bodies.values()

	for i in range(body_array.size()):
		var body_a: PhysicsBody = body_array[i]

		if not body_a.collision_enabled:
			continue

		for j in range(i + 1, body_array.size()):
			var body_b: PhysicsBody = body_array[j]

			if not body_b.collision_enabled:
				continue

			# Layer check
			if not (body_a.collision_layer & body_b.collision_mask) and \
			   not (body_b.collision_layer & body_a.collision_mask):
				continue

			var diff := body_b.position - body_a.position
			var dist := diff.length()
			var min_dist := body_a.collision_radius + body_b.collision_radius

			if dist < min_dist and dist > 0.001:
				var direction := diff / dist
				var overlap := min_dist - dist

				# Calculate collision response
				var total_mass := body_a.inv_mass + body_b.inv_mass
				if total_mass > 0.0:
					var ratio_a := body_a.inv_mass / total_mass
					var ratio_b := body_b.inv_mass / total_mass

					# Separate bodies
					if not body_a.pinned and body_a.inv_mass > 0.0:
						body_a.position -= direction * overlap * ratio_a
					if not body_b.pinned and body_b.inv_mass > 0.0:
						body_b.position += direction * overlap * ratio_b

					# Calculate impulse
					var relative_velocity := body_a.velocity - body_b.velocity
					var velocity_along_normal := relative_velocity.dot(direction)

					if velocity_along_normal > 0.0:
						continue  # Moving apart

					var restitution := minf(body_a.bounciness, body_b.bounciness)
					var impulse_magnitude := -(1.0 + restitution) * velocity_along_normal / total_mass
					var impulse := direction * impulse_magnitude

					if not body_a.pinned and body_a.inv_mass > 0.0:
						body_a.velocity += impulse * body_a.inv_mass
					if not body_b.pinned and body_b.inv_mass > 0.0:
						body_b.velocity -= impulse * body_b.inv_mass

					# Apply friction
					var tangent := (relative_velocity - direction * velocity_along_normal).normalized()
					var friction_impulse := -tangent * velocity_along_normal * \
						(body_a.friction + body_b.friction) * 0.5

					if not body_a.pinned and body_a.inv_mass > 0.0:
						body_a.velocity += friction_impulse * body_a.inv_mass * 0.5
					if not body_b.pinned and body_b.inv_mass > 0.0:
						body_b.velocity -= friction_impulse * body_b.inv_mass * 0.5

				# Emit collision signal
				var contact := body_a.position + direction * body_a.collision_radius
				collision_detected.emit(body_a, body_b, contact)


func _apply_bounds() -> void:
	for body: PhysicsBody in bodies.values():
		if not body.active or body.pinned:
			continue

		var bounds := body.bounds if body.use_bounds else global_bounds
		if not body.use_bounds and not use_global_bounds:
			continue

		var bounced := false

		# Left bound
		if body.position.x - body.collision_radius < bounds.position.x:
			body.position.x = bounds.position.x + body.collision_radius
			body.velocity.x = -body.velocity.x * body.bounciness
			bounced = true

		# Right bound
		if body.position.x + body.collision_radius > bounds.end.x:
			body.position.x = bounds.end.x - body.collision_radius
			body.velocity.x = -body.velocity.x * body.bounciness
			bounced = true

		# Top bound
		if body.position.y - body.collision_radius < bounds.position.y:
			body.position.y = bounds.position.y + body.collision_radius
			body.velocity.y = -body.velocity.y * body.bounciness
			bounced = true

		# Bottom bound
		if body.position.y + body.collision_radius > bounds.end.y:
			body.position.y = bounds.end.y - body.collision_radius
			body.velocity.y = -body.velocity.y * body.bounciness
			bounced = true

		if bounced:
			body_out_of_bounds.emit(body)


func _check_sleeping() -> void:
	for body: PhysicsBody in bodies.values():
		if body.pinned:
			continue

		var speed := body.velocity.length()

		if speed < REST_THRESHOLD:
			body.sleep_counter += 1
			if body.sleep_counter > 60:  # ~1 second at 60fps
				body.is_sleeping = true
				body.velocity = Vector2.ZERO
				body_at_rest.emit(body)
		else:
			body.sleep_counter = 0
			body.is_sleeping = false


func _interpolate_positions(alpha: float) -> void:
	# Interpolation for smoother rendering
	# In this implementation, we apply directly
	pass


func _apply_to_nodes() -> void:
	for node: Node in bodies:
		var body: PhysicsBody = bodies[node]

		if not is_instance_valid(node):
			continue

		if node is Control:
			var ctrl := node as Control
			# Position is center, so offset by half size
			ctrl.position = body.position - ctrl.size / 2.0
			ctrl.rotation = body.rotation
		elif node is Node2D:
			var n2d := node as Node2D
			n2d.position = body.position
			n2d.rotation = body.rotation

# endregion


# region - Utility

## Wakes up a sleeping body
func wake_body(node: Node) -> void:
	var body := get_body(node)
	if body:
		body.is_sleeping = false
		body.sleep_counter = 0


## Wakes all bodies
func wake_all() -> void:
	for body: PhysicsBody in bodies.values():
		body.is_sleeping = false
		body.sleep_counter = 0


## Resets all bodies to their initial positions
func reset() -> void:
	for body: PhysicsBody in bodies.values():
		if body.node:
			body.position = body._get_node_position(body.node)
			body.prev_position = body.position
		body.velocity = Vector2.ZERO
		body.force = Vector2.ZERO
		body.is_sleeping = false
		body.sleep_counter = 0


## Gets total kinetic energy in the system
func get_total_energy() -> float:
	var energy: float = 0.0
	for body: PhysicsBody in bodies.values():
		energy += body.get_kinetic_energy()
	return energy


## Checks if system is at rest
func is_at_rest() -> bool:
	for body: PhysicsBody in bodies.values():
		if not body.is_sleeping and body.velocity.length() > REST_THRESHOLD:
			return false
	return true

# endregion


# region - Spring Presets

## Creates a soft spring (low stiffness, high damping)
func add_soft_spring(node_a: Node, node_b: Node, rest_length: float = -1.0) -> Spring:
	return add_spring(node_a, node_b, rest_length, 50.0, 20.0)


## Creates a stiff spring (high stiffness, low damping)
func add_stiff_spring(node_a: Node, node_b: Node, rest_length: float = -1.0) -> Spring:
	return add_spring(node_a, node_b, rest_length, 800.0, 5.0)


## Creates a bouncy spring
func add_bouncy_spring(node_a: Node, node_b: Node, rest_length: float = -1.0) -> Spring:
	return add_spring(node_a, node_b, rest_length, 300.0, 2.0)


## Creates a critically damped spring (no oscillation)
func add_critical_spring(node_a: Node, node_b: Node, rest_length: float = -1.0, stiffness: float = 200.0) -> Spring:
	# Critical damping = 2 * sqrt(stiffness * mass)
	var critical_damping := 2.0 * sqrt(stiffness)
	return add_spring(node_a, node_b, rest_length, stiffness, critical_damping)

# endregion
