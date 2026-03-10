## Advanced Particle System V2 - Round 2 Ultra-Premium Effects
## Features:
## - Particle-to-particle physics interactions
## - Cursor proximity reactions
## - Section-specific behaviors
## - Letter emission from text
## - Constellation pattern formation
## - Energy field visualization
## - LOD (Level of Detail) system for performance
## - Memory pooling with budget management
## - Frame time monitoring with auto-adjustment
class_name AdvancedParticlesV2
extends Control


# ==============================================================================
# SIGNALS
# ==============================================================================

signal performance_adjusted(new_budget: int)
signal constellation_formed
signal energy_pulse_completed


# ==============================================================================
# ENUMS
# ==============================================================================

enum ParticleBehavior {
	AMBIENT,           ## Floating background particles
	REACTIVE,          ## React to cursor proximity
	CONSTELLATION,     ## Form constellation patterns
	ENERGY_FIELD,      ## Energy visualization
	TRAIL,             ## Follow cursor/elements
	BURST,             ## Explosion patterns
	LETTER_EMIT,       ## Emit from text letters
	SHOCKWAVE,         ## Expanding ring
	VORTEX,            ## Spiral toward point
	MAGNETIC,          ## Attract/repel physics
}

enum LODLevel {
	ULTRA,    ## Full quality - 500+ particles
	HIGH,     ## High quality - 300 particles
	MEDIUM,   ## Medium quality - 150 particles
	LOW,      ## Low quality - 75 particles
	MINIMAL,  ## Minimal - 30 particles
}


# ==============================================================================
# PARTICLE DATA STRUCTURE
# ==============================================================================

class AdvancedParticle:
	var position: Vector2
	var velocity: Vector2
	var acceleration: Vector2
	var color: Color
	var target_color: Color
	var size: float
	var target_size: float
	var life: float
	var max_life: float
	var rotation: float
	var rotation_speed: float
	var behavior: int
	var behavior_data: Dictionary
	var connections: Array[AdvancedParticle]
	var is_anchor: bool
	var mass: float
	var charge: float  # For magnetic interactions

	func _init() -> void:
		connections = []
		behavior_data = {}
		is_anchor = false
		mass = 1.0
		charge = 0.0


# ==============================================================================
# CONFIGURATION CONSTANTS
# ==============================================================================

## Performance budgets per LOD level
const LOD_BUDGETS: Dictionary = {
	LODLevel.ULTRA: 500,
	LODLevel.HIGH: 300,
	LODLevel.MEDIUM: 150,
	LODLevel.LOW: 75,
	LODLevel.MINIMAL: 30,
}

## Target frame time thresholds (milliseconds)
const FRAME_TIME_EXCELLENT: float = 8.0   # 120+ FPS
const FRAME_TIME_GOOD: float = 12.0       # 80+ FPS
const FRAME_TIME_OK: float = 16.0         # 60+ FPS
const FRAME_TIME_POOR: float = 25.0       # 40+ FPS

## Physics constants
const PARTICLE_INTERACTION_RADIUS: float = 100.0
const MAGNETIC_STRENGTH: float = 500.0
const CURSOR_INFLUENCE_RADIUS: float = 150.0
const CONSTELLATION_LINK_DISTANCE: float = 120.0
const VORTEX_STRENGTH: float = 200.0

## Visual constants
const CONNECTION_LINE_ALPHA: float = 0.3
const ENERGY_FIELD_GLOW_RADIUS: float = 50.0


# ==============================================================================
# STATE VARIABLES
# ==============================================================================

## Particle management
var _particle_pool: Array[AdvancedParticle] = []
var _active_particles: Array[AdvancedParticle] = []
var _max_particles: int = 500
var _current_budget: int = 500

## LOD system
var _current_lod: LODLevel = LODLevel.ULTRA
var _frame_times: Array[float] = []
var _frame_time_sample_count: int = 30
var _auto_adjust_enabled: bool = true

## Cursor tracking
var _cursor_position: Vector2 = Vector2.ZERO
var _cursor_velocity: Vector2 = Vector2.ZERO
var _last_cursor_position: Vector2 = Vector2.ZERO
var _cursor_speed: float = 0.0

## Section configurations
var _section_configs: Dictionary = {}
var _active_sections: Array[String] = []

## Constellation state
var _constellation_anchors: Array[Vector2] = []
var _constellation_active: bool = false

## Energy field state
var _energy_field_center: Vector2 = Vector2.ZERO
var _energy_field_radius: float = 200.0
var _energy_pulse_time: float = 0.0

## Emitters
var _emitters: Dictionary = {}
var _text_emitters: Dictionary = {}

## Performance monitoring
var _last_frame_start: int = 0
var _particles_processed_this_frame: int = 0


# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_initialize_pool()
	_setup_default_sections()
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_last_frame_start = Time.get_ticks_usec()

	_update_cursor_state(delta)
	_update_particles(delta)
	_update_particle_interactions(delta)
	_update_emitters(delta)
	_update_energy_field(delta)

	_monitor_performance()

	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cursor_position = event.position


func _draw() -> void:
	_render_connections()
	_render_energy_field()
	_render_particles()


# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _initialize_pool() -> void:
	_particle_pool.clear()
	_active_particles.clear()

	for i in range(_max_particles):
		var particle := AdvancedParticle.new()
		_particle_pool.append(particle)


func _setup_default_sections() -> void:
	# Main menu button area
	_section_configs["buttons"] = {
		"behavior": ParticleBehavior.REACTIVE,
		"emit_rate": 8.0,
		"color_start": Color(0.4, 0.7, 1.0, 0.6),
		"color_end": Color(0.7, 0.4, 1.0, 0.0),
		"size_range": Vector2(2.0, 5.0),
		"life_range": Vector2(1.0, 2.5),
		"speed_range": Vector2(10.0, 30.0),
	}

	# Title area
	_section_configs["title"] = {
		"behavior": ParticleBehavior.LETTER_EMIT,
		"emit_rate": 5.0,
		"color_start": Color(1.0, 0.9, 0.4, 0.8),
		"color_end": Color(1.0, 0.6, 0.2, 0.0),
		"size_range": Vector2(1.5, 4.0),
		"life_range": Vector2(0.8, 1.5),
		"speed_range": Vector2(20.0, 50.0),
	}

	# Background
	_section_configs["background"] = {
		"behavior": ParticleBehavior.CONSTELLATION,
		"emit_rate": 2.0,
		"color_start": Color(0.5, 0.6, 0.9, 0.4),
		"color_end": Color(0.3, 0.5, 0.8, 0.0),
		"size_range": Vector2(1.0, 3.0),
		"life_range": Vector2(4.0, 8.0),
		"speed_range": Vector2(2.0, 8.0),
	}

	# Energy field area
	_section_configs["energy"] = {
		"behavior": ParticleBehavior.ENERGY_FIELD,
		"emit_rate": 12.0,
		"color_start": Color(0.2, 0.8, 1.0, 0.7),
		"color_end": Color(0.6, 0.2, 1.0, 0.0),
		"size_range": Vector2(3.0, 8.0),
		"life_range": Vector2(1.5, 3.0),
		"speed_range": Vector2(30.0, 80.0),
	}


# ==============================================================================
# CURSOR STATE
# ==============================================================================

func _update_cursor_state(delta: float) -> void:
	_cursor_velocity = (_cursor_position - _last_cursor_position) / delta
	_cursor_speed = _cursor_velocity.length()
	_last_cursor_position = _cursor_position


# ==============================================================================
# PARTICLE POOL MANAGEMENT
# ==============================================================================

func _get_particle() -> AdvancedParticle:
	# Check budget
	if _active_particles.size() >= _current_budget:
		# LOD: Remove oldest particle when over budget
		if not _active_particles.is_empty():
			var oldest: AdvancedParticle = _active_particles.pop_front()
			_reset_particle(oldest)
			return oldest
		return null

	if _particle_pool.is_empty():
		return null

	return _particle_pool.pop_back()


func _return_particle(particle: AdvancedParticle) -> void:
	_reset_particle(particle)
	if _particle_pool.size() < _max_particles:
		_particle_pool.append(particle)


func _reset_particle(particle: AdvancedParticle) -> void:
	particle.connections.clear()
	particle.behavior_data.clear()
	particle.is_anchor = false
	particle.mass = 1.0
	particle.charge = 0.0


# ==============================================================================
# PARTICLE UPDATE
# ==============================================================================

func _update_particles(delta: float) -> void:
	var particles_to_remove: Array[AdvancedParticle] = []
	_particles_processed_this_frame = 0

	for particle in _active_particles:
		_particles_processed_this_frame += 1

		# LOD skip: Process fewer particles at lower LOD
		if _current_lod >= LODLevel.MEDIUM:
			if _particles_processed_this_frame % 2 == 0:
				continue

		particle.life -= delta

		if particle.life <= 0:
			particles_to_remove.append(particle)
			continue

		# Apply behavior-specific update
		_update_particle_behavior(particle, delta)

		# Physics integration
		particle.velocity += particle.acceleration * delta
		particle.position += particle.velocity * delta
		particle.rotation += particle.rotation_speed * delta

		# Smooth color/size transitions
		particle.color = particle.color.lerp(particle.target_color, delta * 3.0)
		particle.size = lerpf(particle.size, particle.target_size, delta * 5.0)

	# Remove dead particles
	for particle in particles_to_remove:
		_active_particles.erase(particle)
		_return_particle(particle)


func _update_particle_behavior(particle: AdvancedParticle, delta: float) -> void:
	match particle.behavior:
		ParticleBehavior.REACTIVE:
			_behavior_reactive(particle, delta)
		ParticleBehavior.CONSTELLATION:
			_behavior_constellation(particle, delta)
		ParticleBehavior.ENERGY_FIELD:
			_behavior_energy_field(particle, delta)
		ParticleBehavior.VORTEX:
			_behavior_vortex(particle, delta)
		ParticleBehavior.MAGNETIC:
			_behavior_magnetic(particle, delta)
		ParticleBehavior.SHOCKWAVE:
			_behavior_shockwave(particle, delta)


# ==============================================================================
# PARTICLE BEHAVIORS
# ==============================================================================

func _behavior_reactive(particle: AdvancedParticle, delta: float) -> void:
	var to_cursor: Vector2 = _cursor_position - particle.position
	var dist: float = to_cursor.length()

	if dist < CURSOR_INFLUENCE_RADIUS and dist > 1.0:
		var influence: float = 1.0 - (dist / CURSOR_INFLUENCE_RADIUS)
		influence = influence * influence  # Quadratic falloff

		# Flee from fast cursor, attracted to slow cursor
		if _cursor_speed > 200.0:
			# Flee
			var flee_dir: Vector2 = -to_cursor.normalized()
			particle.velocity += flee_dir * influence * 100.0 * delta
			particle.target_color = Color(1.0, 0.5, 0.3, particle.color.a)
		else:
			# Gentle attraction
			var attract_dir: Vector2 = to_cursor.normalized()
			particle.velocity += attract_dir * influence * 30.0 * delta
			particle.target_color = Color(0.5, 0.8, 1.0, particle.color.a)

		# Size pulse based on proximity
		particle.target_size = particle.behavior_data.get("base_size", 3.0) * (1.0 + influence * 0.5)


func _behavior_constellation(particle: AdvancedParticle, _delta: float) -> void:
	# Slow drift with slight attraction to nearest anchor
	var nearest_dist: float = INF
	var nearest_anchor: Vector2 = Vector2.ZERO

	for anchor in _constellation_anchors:
		var dist: float = particle.position.distance_to(anchor)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_anchor = anchor

	if nearest_dist < 200.0 and nearest_dist > 30.0:
		var to_anchor: Vector2 = (nearest_anchor - particle.position).normalized()
		particle.acceleration = to_anchor * 5.0
	else:
		particle.acceleration = Vector2.ZERO

	# Twinkle effect
	var t: float = 1.0 - (particle.life / particle.max_life)
	var twinkle: float = sin(Time.get_ticks_msec() * 0.01 + particle.behavior_data.get("twinkle_offset", 0.0))
	particle.target_size = particle.behavior_data.get("base_size", 2.0) * (0.7 + twinkle * 0.3)


func _behavior_energy_field(particle: AdvancedParticle, delta: float) -> void:
	var to_center: Vector2 = _energy_field_center - particle.position
	var dist: float = to_center.length()

	# Orbit around center
	var orbit_speed: float = particle.behavior_data.get("orbit_speed", 2.0)
	var tangent: Vector2 = Vector2(-to_center.y, to_center.x).normalized()

	particle.acceleration = tangent * orbit_speed * 50.0

	# Pulse outward during energy pulse
	if _energy_pulse_time > 0.0:
		var pulse_force: Vector2 = -to_center.normalized() * 100.0 * _energy_pulse_time
		particle.velocity += pulse_force * delta


func _behavior_vortex(particle: AdvancedParticle, delta: float) -> void:
	var target: Vector2 = particle.behavior_data.get("target", Vector2.ZERO)
	var to_target: Vector2 = target - particle.position
	var dist: float = to_target.length()

	if dist > 10.0:
		# Spiral inward
		var inward: Vector2 = to_target.normalized()
		var tangent: Vector2 = Vector2(-inward.y, inward.x)

		var spiral_ratio: float = particle.behavior_data.get("spiral_ratio", 0.3)
		var force: Vector2 = (inward * spiral_ratio + tangent * (1.0 - spiral_ratio)) * VORTEX_STRENGTH

		particle.velocity = particle.velocity.lerp(force, delta * 2.0)
	else:
		# Reached center - destroy or reset
		particle.life = 0.0


func _behavior_magnetic(particle: AdvancedParticle, delta: float) -> void:
	# Apply forces from other charged particles
	for other in _active_particles:
		if other == particle or other.behavior != ParticleBehavior.MAGNETIC:
			continue

		var to_other: Vector2 = other.position - particle.position
		var dist: float = to_other.length()

		if dist < 10.0 or dist > PARTICLE_INTERACTION_RADIUS:
			continue

		# Coulomb-like force
		var force_mag: float = (particle.charge * other.charge * MAGNETIC_STRENGTH) / (dist * dist)
		var force_dir: Vector2 = to_other.normalized()

		# Opposite charges attract, same charges repel
		particle.velocity -= force_dir * force_mag * delta


func _behavior_shockwave(particle: AdvancedParticle, delta: float) -> void:
	var origin: Vector2 = particle.behavior_data.get("origin", Vector2.ZERO)
	var to_origin: Vector2 = particle.position - origin
	var target_radius: float = particle.behavior_data.get("target_radius", 200.0)
	var current_radius: float = to_origin.length()

	# Expand outward
	var expand_speed: float = particle.behavior_data.get("expand_speed", 400.0)
	particle.velocity = to_origin.normalized() * expand_speed

	# Fade as it expands
	var progress: float = current_radius / target_radius
	particle.target_color.a = (1.0 - progress) * particle.behavior_data.get("base_alpha", 0.8)

	# Kill when reached target radius
	if current_radius >= target_radius:
		particle.life = 0.0


# ==============================================================================
# PARTICLE INTERACTIONS
# ==============================================================================

func _update_particle_interactions(delta: float) -> void:
	# Skip at lower LOD levels
	if _current_lod >= LODLevel.MEDIUM:
		return

	# Update constellation connections
	if _constellation_active:
		_update_constellation_connections()


func _update_constellation_connections() -> void:
	# Clear old connections
	for particle in _active_particles:
		particle.connections.clear()

	# Build new connections
	for i in range(_active_particles.size()):
		var particle: AdvancedParticle = _active_particles[i]

		if particle.behavior != ParticleBehavior.CONSTELLATION:
			continue

		for j in range(i + 1, _active_particles.size()):
			var other: AdvancedParticle = _active_particles[j]

			if other.behavior != ParticleBehavior.CONSTELLATION:
				continue

			var dist: float = particle.position.distance_to(other.position)
			if dist < CONSTELLATION_LINK_DISTANCE:
				particle.connections.append(other)


# ==============================================================================
# ENERGY FIELD
# ==============================================================================

func _update_energy_field(delta: float) -> void:
	if _energy_pulse_time > 0.0:
		_energy_pulse_time -= delta * 2.0
		if _energy_pulse_time <= 0.0:
			_energy_pulse_time = 0.0
			energy_pulse_completed.emit()


func trigger_energy_pulse(center: Vector2, radius: float = 200.0) -> void:
	_energy_field_center = center
	_energy_field_radius = radius
	_energy_pulse_time = 1.0


# ==============================================================================
# EMITTER MANAGEMENT
# ==============================================================================

func _update_emitters(delta: float) -> void:
	for emitter_name in _emitters.keys():
		var emitter: Dictionary = _emitters[emitter_name]

		if not emitter.get("active", true):
			continue

		emitter["accumulator"] = emitter.get("accumulator", 0.0) + delta

		var emit_rate: float = emitter["config"]["emit_rate"]

		# LOD: Reduce emit rate at lower quality
		emit_rate *= _get_lod_emit_multiplier()

		var emit_interval: float = 1.0 / emit_rate

		while emitter["accumulator"] >= emit_interval:
			emitter["accumulator"] -= emit_interval
			_emit_from_config(emitter["position"], emitter["config"])


func _get_lod_emit_multiplier() -> float:
	match _current_lod:
		LODLevel.ULTRA:
			return 1.0
		LODLevel.HIGH:
			return 0.8
		LODLevel.MEDIUM:
			return 0.5
		LODLevel.LOW:
			return 0.3
		LODLevel.MINIMAL:
			return 0.1
	return 1.0


func _emit_from_config(pos: Vector2, config: Dictionary) -> void:
	var particle: AdvancedParticle = _get_particle()
	if particle == null:
		return

	particle.position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	particle.life = randf_range(config["life_range"].x, config["life_range"].y)
	particle.max_life = particle.life

	var size_range: Vector2 = config["size_range"]
	particle.size = randf_range(size_range.x, size_range.y)
	particle.target_size = particle.size
	particle.behavior_data["base_size"] = particle.size

	particle.color = config["color_start"]
	particle.target_color = config["color_end"]

	particle.rotation = randf() * TAU
	particle.rotation_speed = randf_range(-2.0, 2.0)

	var speed_range: Vector2 = config["speed_range"]
	var speed: float = randf_range(speed_range.x, speed_range.y)
	var angle: float = randf() * TAU
	particle.velocity = Vector2(cos(angle), sin(angle)) * speed

	particle.acceleration = Vector2(0, -10)  # Slight upward drift

	particle.behavior = config.get("behavior", ParticleBehavior.AMBIENT)
	particle.behavior_data["twinkle_offset"] = randf() * 100.0
	particle.behavior_data["orbit_speed"] = randf_range(1.0, 3.0)

	_active_particles.append(particle)


# ==============================================================================
# EMISSION METHODS
# ==============================================================================

## Start a section emitter
func start_section(section_name: String, area: Rect2) -> void:
	if not _section_configs.has(section_name):
		return

	var config: Dictionary = _section_configs[section_name]
	var center: Vector2 = area.position + area.size / 2.0

	_emitters[section_name] = {
		"position": center,
		"area": area,
		"config": config,
		"accumulator": 0.0,
		"active": true,
	}

	if not _active_sections.has(section_name):
		_active_sections.append(section_name)


## Stop a section emitter
func stop_section(section_name: String) -> void:
	if _emitters.has(section_name):
		_emitters[section_name]["active"] = false
	_active_sections.erase(section_name)


## Emit particles from text letters
func emit_from_text(text: String, font: Font, position: Vector2, font_size: int = 32) -> void:
	var x_offset: float = 0.0

	for i in range(text.length()):
		var char: String = text[i]
		if char == " ":
			x_offset += font_size * 0.3
			continue

		var char_width: float = font.get_string_size(char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var char_pos: Vector2 = position + Vector2(x_offset + char_width / 2.0, font_size / 2.0)

		# Emit 2-4 particles per letter
		var count: int = randi_range(2, 4)
		for j in range(count):
			_emit_letter_particle(char_pos, char)

		x_offset += char_width


func _emit_letter_particle(pos: Vector2, _letter: String) -> void:
	var config: Dictionary = _section_configs.get("title", {})
	if config.is_empty():
		return

	var particle: AdvancedParticle = _get_particle()
	if particle == null:
		return

	particle.position = pos + Vector2(randf_range(-5, 5), randf_range(-5, 5))
	particle.life = randf_range(0.5, 1.2)
	particle.max_life = particle.life
	particle.size = randf_range(1.5, 3.5)
	particle.target_size = 0.0

	particle.color = config.get("color_start", Color.GOLD)
	particle.target_color = config.get("color_end", Color(1, 0.8, 0, 0))

	particle.velocity = Vector2(randf_range(-30, 30), randf_range(-50, -20))
	particle.acceleration = Vector2(0, 30)

	particle.behavior = ParticleBehavior.LETTER_EMIT
	particle.rotation = randf() * TAU
	particle.rotation_speed = randf_range(-5.0, 5.0)

	_active_particles.append(particle)


## Emit shockwave ripple
func emit_shockwave(origin: Vector2, color: Color = Color(1.0, 1.0, 1.0, 0.8), radius: float = 200.0, particle_count: int = 24) -> void:
	for i in range(particle_count):
		var particle: AdvancedParticle = _get_particle()
		if particle == null:
			break

		var angle: float = (float(i) / particle_count) * TAU
		particle.position = origin + Vector2(cos(angle), sin(angle)) * 5.0
		particle.velocity = Vector2.ZERO
		particle.acceleration = Vector2.ZERO

		particle.life = 0.6
		particle.max_life = 0.6
		particle.size = 4.0
		particle.target_size = 2.0

		particle.color = color
		particle.target_color = Color(color.r, color.g, color.b, 0.0)

		particle.behavior = ParticleBehavior.SHOCKWAVE
		particle.behavior_data = {
			"origin": origin,
			"target_radius": radius,
			"expand_speed": radius / 0.5,
			"base_alpha": color.a,
		}

		_active_particles.append(particle)


## Emit vortex effect
func emit_vortex(target: Vector2, source_area: Rect2, color: Color = Color.CYAN, particle_count: int = 20) -> void:
	for i in range(particle_count):
		var particle: AdvancedParticle = _get_particle()
		if particle == null:
			break

		particle.position = source_area.position + Vector2(
			randf() * source_area.size.x,
			randf() * source_area.size.y
		)
		particle.velocity = Vector2.ZERO
		particle.acceleration = Vector2.ZERO

		particle.life = 1.5
		particle.max_life = 1.5
		particle.size = randf_range(3.0, 6.0)
		particle.target_size = 1.0

		particle.color = color
		particle.target_color = Color(color.r, color.g, color.b, 0.0)

		particle.behavior = ParticleBehavior.VORTEX
		particle.behavior_data = {
			"target": target,
			"spiral_ratio": randf_range(0.2, 0.5),
		}

		_active_particles.append(particle)


## Start constellation mode
func start_constellation(anchor_positions: Array[Vector2]) -> void:
	_constellation_anchors = anchor_positions
	_constellation_active = true

	# Emit constellation particles
	for anchor in anchor_positions:
		for i in range(3):
			_emit_constellation_particle(anchor)


func _emit_constellation_particle(near_pos: Vector2) -> void:
	var config: Dictionary = _section_configs.get("background", {})

	var particle: AdvancedParticle = _get_particle()
	if particle == null:
		return

	particle.position = near_pos + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	particle.life = randf_range(5.0, 10.0)
	particle.max_life = particle.life
	particle.size = randf_range(1.5, 3.0)
	particle.target_size = particle.size
	particle.behavior_data["base_size"] = particle.size

	particle.color = config.get("color_start", Color(0.8, 0.9, 1.0, 0.5))
	particle.target_color = config.get("color_end", Color(0.8, 0.9, 1.0, 0.0))

	particle.velocity = Vector2(randf_range(-5, 5), randf_range(-5, 5))
	particle.acceleration = Vector2.ZERO

	particle.behavior = ParticleBehavior.CONSTELLATION
	particle.behavior_data["twinkle_offset"] = randf() * 100.0

	_active_particles.append(particle)


func stop_constellation() -> void:
	_constellation_active = false
	_constellation_anchors.clear()


## Emit magnetic particles
func emit_magnetic(pos: Vector2, charge: float, color: Color, count: int = 5) -> void:
	for i in range(count):
		var particle: AdvancedParticle = _get_particle()
		if particle == null:
			break

		particle.position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		particle.life = randf_range(2.0, 4.0)
		particle.max_life = particle.life
		particle.size = randf_range(3.0, 6.0)
		particle.target_size = particle.size

		particle.color = color
		particle.target_color = Color(color.r, color.g, color.b, 0.0)

		particle.velocity = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		particle.acceleration = Vector2.ZERO

		particle.behavior = ParticleBehavior.MAGNETIC
		particle.charge = charge * (1.0 if randf() > 0.5 else -1.0)
		particle.mass = randf_range(0.5, 2.0)

		_active_particles.append(particle)


## Create cursor trail
func emit_cursor_trail(color: Color = Color(1.0, 0.8, 0.3, 0.6)) -> void:
	if _cursor_speed < 50.0:
		return

	var particle: AdvancedParticle = _get_particle()
	if particle == null:
		return

	particle.position = _cursor_position
	particle.life = randf_range(0.2, 0.4)
	particle.max_life = particle.life

	# Size and color based on cursor speed
	var speed_factor: float = clampf(_cursor_speed / 500.0, 0.0, 1.0)
	particle.size = lerpf(2.0, 6.0, speed_factor)
	particle.target_size = 0.0

	# Color shifts with speed
	var fast_color: Color = Color(1.0, 0.4, 0.2, 0.8)
	particle.color = color.lerp(fast_color, speed_factor)
	particle.target_color = Color(particle.color.r, particle.color.g, particle.color.b, 0.0)

	particle.velocity = -_cursor_velocity.normalized() * 20.0
	particle.acceleration = Vector2.ZERO

	particle.behavior = ParticleBehavior.TRAIL
	particle.rotation = _cursor_velocity.angle()

	_active_particles.append(particle)


# ==============================================================================
# RENDERING
# ==============================================================================

func _render_particles() -> void:
	for particle in _active_particles:
		var t: float = 1.0 - (particle.life / particle.max_life)
		var alpha: float = particle.color.a * (1.0 - t * t)

		var draw_color: Color = particle.color
		draw_color.a = alpha

		# Draw based on behavior
		match particle.behavior:
			ParticleBehavior.CONSTELLATION:
				_draw_star(particle.position, particle.size, particle.rotation, draw_color)
			ParticleBehavior.ENERGY_FIELD:
				_draw_energy_particle(particle.position, particle.size, draw_color)
			ParticleBehavior.SHOCKWAVE:
				_draw_shockwave_particle(particle, draw_color)
			_:
				draw_circle(particle.position, particle.size, draw_color)


func _render_connections() -> void:
	if not _constellation_active:
		return

	for particle in _active_particles:
		if particle.behavior != ParticleBehavior.CONSTELLATION:
			continue

		for connected in particle.connections:
			var dist: float = particle.position.distance_to(connected.position)
			var alpha: float = (1.0 - dist / CONSTELLATION_LINK_DISTANCE) * CONNECTION_LINE_ALPHA
			alpha *= minf(particle.color.a, connected.color.a)

			var line_color := Color(0.8, 0.9, 1.0, alpha)
			draw_line(particle.position, connected.position, line_color, 1.0, true)


func _render_energy_field() -> void:
	if _energy_pulse_time <= 0.0:
		return

	var pulse_radius: float = _energy_field_radius * (1.0 - _energy_pulse_time)

	# Draw expanding ring
	var ring_color := Color(0.2, 0.8, 1.0, _energy_pulse_time * 0.5)
	var point_count: int = 32
	var points: PackedVector2Array = PackedVector2Array()

	for i in range(point_count + 1):
		var angle: float = (float(i) / point_count) * TAU
		points.append(_energy_field_center + Vector2(cos(angle), sin(angle)) * pulse_radius)

	for i in range(point_count):
		draw_line(points[i], points[i + 1], ring_color, 2.0 * _energy_pulse_time, true)


func _draw_star(pos: Vector2, size: float, rotation: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var inner_size: float = size * 0.4
	var point_count: int = 4

	for i in range(point_count * 2):
		var angle: float = (float(i) / (point_count * 2)) * TAU + rotation
		var r: float = size if i % 2 == 0 else inner_size
		points.append(Vector2(cos(angle), sin(angle)) * r + pos)

	draw_colored_polygon(points, color)


func _draw_energy_particle(pos: Vector2, size: float, color: Color) -> void:
	# Glowing energy orb
	var layers: int = 4
	for i in range(layers):
		var t: float = float(i) / layers
		var r: float = size * (1.0 + t * 0.5)
		var a: float = color.a * (1.0 - t * 0.7)
		draw_circle(pos, r, Color(color.r, color.g, color.b, a))


func _draw_shockwave_particle(particle: AdvancedParticle, color: Color) -> void:
	var origin: Vector2 = particle.behavior_data.get("origin", Vector2.ZERO)
	var direction: Vector2 = (particle.position - origin).normalized()

	# Draw elongated shape
	var perp: Vector2 = Vector2(-direction.y, direction.x) * particle.size * 0.5
	var points: PackedVector2Array = PackedVector2Array([
		particle.position + direction * particle.size * 2.0,
		particle.position + perp,
		particle.position - direction * particle.size,
		particle.position - perp,
	])

	draw_colored_polygon(points, color)


# ==============================================================================
# PERFORMANCE MONITORING
# ==============================================================================

func _monitor_performance() -> void:
	var frame_time: float = (Time.get_ticks_usec() - _last_frame_start) / 1000.0

	_frame_times.append(frame_time)
	if _frame_times.size() > _frame_time_sample_count:
		_frame_times.pop_front()

	if not _auto_adjust_enabled:
		return

	# Adjust LOD based on average frame time
	if _frame_times.size() >= _frame_time_sample_count:
		var avg_frame_time: float = 0.0
		for t in _frame_times:
			avg_frame_time += t
		avg_frame_time /= _frame_times.size()

		_adjust_lod_for_performance(avg_frame_time)


func _adjust_lod_for_performance(avg_frame_time: float) -> void:
	var new_lod: LODLevel = _current_lod

	if avg_frame_time < FRAME_TIME_EXCELLENT:
		# Excellent performance - can increase quality
		if _current_lod > LODLevel.ULTRA:
			new_lod = LODLevel(_current_lod - 1)
	elif avg_frame_time > FRAME_TIME_POOR:
		# Poor performance - must decrease quality
		if _current_lod < LODLevel.MINIMAL:
			new_lod = LODLevel(_current_lod + 1)
	elif avg_frame_time > FRAME_TIME_OK:
		# OK performance - slightly decrease if not already low
		if _current_lod < LODLevel.LOW:
			new_lod = LODLevel(_current_lod + 1)

	if new_lod != _current_lod:
		_set_lod(new_lod)


func _set_lod(lod: LODLevel) -> void:
	_current_lod = lod
	_current_budget = LOD_BUDGETS[lod]
	performance_adjusted.emit(_current_budget)

	print("[AdvancedParticlesV2] LOD adjusted to %d, budget: %d particles" % [lod, _current_budget])


# ==============================================================================
# PUBLIC API
# ==============================================================================

## Get current particle count
func get_particle_count() -> int:
	return _active_particles.size()


## Get current LOD level
func get_current_lod() -> LODLevel:
	return _current_lod


## Set LOD level manually
func set_lod(lod: LODLevel) -> void:
	_auto_adjust_enabled = false
	_set_lod(lod)


## Enable/disable auto LOD adjustment
func set_auto_adjust(enabled: bool) -> void:
	_auto_adjust_enabled = enabled


## Clear all particles
func clear_all() -> void:
	for particle in _active_particles:
		_return_particle(particle)
	_active_particles.clear()
	_emitters.clear()
	_active_sections.clear()


## Set cursor position manually (for non-mouse input)
func set_cursor_position(pos: Vector2) -> void:
	_cursor_position = pos


## Get average frame time
func get_average_frame_time() -> float:
	if _frame_times.is_empty():
		return 0.0

	var total: float = 0.0
	for t in _frame_times:
		total += t
	return total / _frame_times.size()
