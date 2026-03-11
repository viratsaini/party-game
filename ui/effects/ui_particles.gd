## UI Particle Effects System for ultra-premium menu visuals.
## Creates GPU-efficient particle effects for button trails, ambient effects,
## floating particles, and dynamic visual feedback.
class_name UIParticles
extends Control

# ══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ══════════════════════════════════════════════════════════════════════════════

signal particle_burst_completed
signal effect_finished(effect_name: String)


# ══════════════════════════════════════════════════════════════════════════════
# PARTICLE CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

## Particle data structure
class Particle:
	var position: Vector2
	var velocity: Vector2
	var acceleration: Vector2
	var color: Color
	var size: float
	var life: float
	var max_life: float
	var rotation: float
	var rotation_speed: float
	var scale_start: float
	var scale_end: float
	var alpha_start: float
	var alpha_end: float
	var shape: int  # 0 = circle, 1 = square, 2 = diamond, 3 = star


## Particle pool for performance
var _particle_pool: Array[Particle] = []
var _active_particles: Array[Particle] = []
var _max_particles: int = 500


## Emitter configurations
var _emitters: Dictionary = {}
var _active_emitters: Array[String] = []


# ══════════════════════════════════════════════════════════════════════════════
# PRESET CONFIGURATIONS
# ══════════════════════════════════════════════════════════════════════════════

## Hover trail particles (follow cursor near buttons)
const HOVER_TRAIL_CONFIG: Dictionary = {
	"emit_rate": 30.0,
	"life_min": 0.3,
	"life_max": 0.6,
	"size_min": 2.0,
	"size_max": 6.0,
	"speed_min": 20.0,
	"speed_max": 50.0,
	"color_start": Color(1.0, 0.9, 0.5, 0.8),
	"color_end": Color(1.0, 0.6, 0.2, 0.0),
	"gravity": Vector2(0, -30),
	"spread_angle": 45.0,
	"shape": 0
}


## Ambient floating particles
const AMBIENT_CONFIG: Dictionary = {
	"emit_rate": 5.0,
	"life_min": 3.0,
	"life_max": 6.0,
	"size_min": 1.0,
	"size_max": 3.0,
	"speed_min": 5.0,
	"speed_max": 15.0,
	"color_start": Color(0.5, 0.7, 1.0, 0.3),
	"color_end": Color(0.7, 0.5, 1.0, 0.0),
	"gravity": Vector2(0, -5),
	"spread_angle": 360.0,
	"shape": 0
}


## Button click burst
const CLICK_BURST_CONFIG: Dictionary = {
	"count": 12,
	"life_min": 0.2,
	"life_max": 0.5,
	"size_min": 3.0,
	"size_max": 8.0,
	"speed_min": 100.0,
	"speed_max": 200.0,
	"color_start": Color(1.0, 1.0, 1.0, 1.0),
	"color_end": Color(1.0, 0.8, 0.4, 0.0),
	"gravity": Vector2(0, 100),
	"spread_angle": 360.0,
	"shape": 2
}


## Energy glow particles
const ENERGY_GLOW_CONFIG: Dictionary = {
	"emit_rate": 15.0,
	"life_min": 0.5,
	"life_max": 1.0,
	"size_min": 4.0,
	"size_max": 12.0,
	"speed_min": 10.0,
	"speed_max": 30.0,
	"color_start": Color(0.3, 0.8, 1.0, 0.6),
	"color_end": Color(0.6, 0.3, 1.0, 0.0),
	"gravity": Vector2.ZERO,
	"spread_angle": 360.0,
	"shape": 0
}


## Sparkle particles
const SPARKLE_CONFIG: Dictionary = {
	"emit_rate": 8.0,
	"life_min": 0.2,
	"life_max": 0.4,
	"size_min": 2.0,
	"size_max": 5.0,
	"speed_min": 0.0,
	"speed_max": 10.0,
	"color_start": Color(1.0, 1.0, 1.0, 1.0),
	"color_end": Color(1.0, 1.0, 0.8, 0.0),
	"gravity": Vector2.ZERO,
	"spread_angle": 360.0,
	"shape": 3
}


## Hex grid particles
const HEX_GRID_CONFIG: Dictionary = {
	"emit_rate": 2.0,
	"life_min": 2.0,
	"life_max": 4.0,
	"size_min": 8.0,
	"size_max": 15.0,
	"speed_min": 0.0,
	"speed_max": 5.0,
	"color_start": Color(0.3, 0.5, 0.8, 0.15),
	"color_end": Color(0.5, 0.3, 0.8, 0.0),
	"gravity": Vector2.ZERO,
	"spread_angle": 360.0,
	"shape": 1
}


# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_initialize_pool()
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_update_particles(delta)
	_update_emitters(delta)
	queue_redraw()


func _draw() -> void:
	_render_particles()


# ══════════════════════════════════════════════════════════════════════════════
# PARTICLE POOL MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

func _initialize_pool() -> void:
	for i in range(_max_particles):
		var particle := Particle.new()
		_particle_pool.append(particle)


func _get_particle() -> Particle:
	if _particle_pool.is_empty():
		# Pool exhausted, reuse oldest active particle
		if _active_particles.is_empty():
			return Particle.new()
		var oldest: Particle = _active_particles.pop_front()
		return oldest

	return _particle_pool.pop_back()


func _return_particle(particle: Particle) -> void:
	if _particle_pool.size() < _max_particles:
		_particle_pool.append(particle)


# ══════════════════════════════════════════════════════════════════════════════
# PARTICLE UPDATE
# ══════════════════════════════════════════════════════════════════════════════

func _update_particles(delta: float) -> void:
	var particles_to_remove: Array[Particle] = []

	for particle in _active_particles:
		particle.life -= delta

		if particle.life <= 0:
			particles_to_remove.append(particle)
			continue

		# Physics update
		particle.velocity += particle.acceleration * delta
		particle.position += particle.velocity * delta
		particle.rotation += particle.rotation_speed * delta

	# Remove dead particles
	for particle in particles_to_remove:
		_active_particles.erase(particle)
		_return_particle(particle)


func _update_emitters(delta: float) -> void:
	for emitter_name in _active_emitters:
		if not _emitters.has(emitter_name):
			continue

		var emitter: Dictionary = _emitters[emitter_name]
		emitter["accumulator"] = emitter.get("accumulator", 0.0) + delta

		var emit_rate: float = emitter["config"]["emit_rate"]
		var emit_interval: float = 1.0 / emit_rate

		while emitter["accumulator"] >= emit_interval:
			emitter["accumulator"] -= emit_interval
			_emit_particle(emitter["position"], emitter["config"])


# ══════════════════════════════════════════════════════════════════════════════
# PARTICLE EMISSION
# ══════════════════════════════════════════════════════════════════════════════

func _emit_particle(pos: Vector2, config: Dictionary) -> void:
	var particle: Particle = _get_particle()

	particle.position = pos
	particle.life = randf_range(config["life_min"], config["life_max"])
	particle.max_life = particle.life
	particle.size = randf_range(config["size_min"], config["size_max"])
	particle.scale_start = 1.0
	particle.scale_end = 0.0
	particle.alpha_start = config["color_start"].a
	particle.alpha_end = config["color_end"].a
	particle.color = config["color_start"]
	particle.shape = config.get("shape", 0)
	particle.rotation = randf() * TAU
	particle.rotation_speed = randf_range(-3.0, 3.0)

	# Calculate velocity based on spread angle
	var spread: float = deg_to_rad(config["spread_angle"])
	var angle: float = randf_range(-spread / 2, spread / 2) - PI / 2  # Default upward
	var speed: float = randf_range(config["speed_min"], config["speed_max"])
	particle.velocity = Vector2(cos(angle), sin(angle)) * speed

	particle.acceleration = config.get("gravity", Vector2.ZERO)

	_active_particles.append(particle)


## Emit a burst of particles at position
func emit_burst(pos: Vector2, config: Dictionary = CLICK_BURST_CONFIG, count: int = -1) -> void:
	var particle_count: int = count if count > 0 else config.get("count", 10)

	for i in range(particle_count):
		_emit_particle(pos, config)

	particle_burst_completed.emit()


## Emit particles in a ring pattern
func emit_ring(center: Vector2, radius: float, config: Dictionary, count: int = 12) -> void:
	for i in range(count):
		var angle: float = (float(i) / count) * TAU
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		_emit_particle(pos, config)


## Emit trail particles (call continuously while hovering)
func emit_trail(pos: Vector2, config: Dictionary = HOVER_TRAIL_CONFIG) -> void:
	if randf() < config["emit_rate"] * get_process_delta_time():
		_emit_particle(pos, config)


# ══════════════════════════════════════════════════════════════════════════════
# EMITTER MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

## Start a continuous emitter at position
func start_emitter(name: String, pos: Vector2, config: Dictionary) -> void:
	_emitters[name] = {
		"position": pos,
		"config": config,
		"accumulator": 0.0
	}
	if not _active_emitters.has(name):
		_active_emitters.append(name)


## Stop an emitter
func stop_emitter(name: String) -> void:
	_active_emitters.erase(name)
	_emitters.erase(name)


## Update emitter position (for following elements)
func update_emitter_position(name: String, pos: Vector2) -> void:
	if _emitters.has(name):
		_emitters[name]["position"] = pos


## Check if emitter is active
func is_emitter_active(name: String) -> bool:
	return _active_emitters.has(name)


# ══════════════════════════════════════════════════════════════════════════════
# PARTICLE RENDERING
# ══════════════════════════════════════════════════════════════════════════════

func _render_particles() -> void:
	for particle in _active_particles:
		var t: float = 1.0 - (particle.life / particle.max_life)

		# Calculate current size with easing
		var current_scale: float = lerpf(particle.scale_start, particle.scale_end, t * t)
		var current_size: float = particle.size * current_scale

		# Calculate current color with alpha fade
		var current_alpha: float = lerpf(particle.alpha_start, particle.alpha_end, t)
		var current_color: Color = particle.color
		current_color.a = current_alpha

		# Draw based on shape
		match particle.shape:
			0:  # Circle
				draw_circle(particle.position, current_size, current_color)
			1:  # Square
				_draw_rotated_rect(particle.position, current_size, particle.rotation, current_color)
			2:  # Diamond
				_draw_diamond(particle.position, current_size, particle.rotation, current_color)
			3:  # Star
				_draw_star(particle.position, current_size, particle.rotation, current_color)


func _draw_rotated_rect(pos: Vector2, size: float, rotation: float, color: Color) -> void:
	var half_size: float = size / 2
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-half_size, -half_size),
		Vector2(half_size, -half_size),
		Vector2(half_size, half_size),
		Vector2(-half_size, half_size)
	])

	# Rotate points
	for i in range(points.size()):
		points[i] = points[i].rotated(rotation) + pos

	draw_colored_polygon(points, color)


func _draw_diamond(pos: Vector2, size: float, rotation: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -size),
		Vector2(size, 0),
		Vector2(0, size),
		Vector2(-size, 0)
	])

	for i in range(points.size()):
		points[i] = points[i].rotated(rotation) + pos

	draw_colored_polygon(points, color)


func _draw_star(pos: Vector2, size: float, rotation: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var inner_size: float = size * 0.4
	var point_count: int = 4

	for i in range(point_count * 2):
		var angle: float = (float(i) / (point_count * 2)) * TAU + rotation
		var r: float = size if i % 2 == 0 else inner_size
		points.append(Vector2(cos(angle), sin(angle)) * r + pos)

	draw_colored_polygon(points, color)


# ══════════════════════════════════════════════════════════════════════════════
# PRESET EFFECTS
# ══════════════════════════════════════════════════════════════════════════════

## Button hover trail effect
func start_button_hover_trail(button: Control) -> void:
	var name: String = "hover_" + str(button.get_instance_id())
	var pos: Vector2 = button.global_position + button.size / 2
	start_emitter(name, pos, HOVER_TRAIL_CONFIG)


func stop_button_hover_trail(button: Control) -> void:
	var name: String = "hover_" + str(button.get_instance_id())
	stop_emitter(name)


## Button click burst
func emit_button_click(button: Control) -> void:
	var pos: Vector2 = button.global_position + button.size / 2
	emit_burst(pos, CLICK_BURST_CONFIG)


## Ambient background particles
func start_ambient_particles(area: Rect2) -> void:
	# Create multiple emitters across the area
	var cols: int = 4
	var rows: int = 3

	for x in range(cols):
		for y in range(rows):
			var pos: Vector2 = Vector2(
				area.position.x + area.size.x * (float(x) + 0.5) / cols,
				area.position.y + area.size.y * (float(y) + 0.5) / rows
			)
			start_emitter("ambient_%d_%d" % [x, y], pos, AMBIENT_CONFIG)


func stop_ambient_particles() -> void:
	for name in _active_emitters.duplicate():
		if name.begins_with("ambient_"):
			stop_emitter(name)


## Energy glow around element
func start_energy_glow(control: Control) -> void:
	var name: String = "energy_" + str(control.get_instance_id())
	var pos: Vector2 = control.global_position + control.size / 2
	start_emitter(name, pos, ENERGY_GLOW_CONFIG)


func stop_energy_glow(control: Control) -> void:
	var name: String = "energy_" + str(control.get_instance_id())
	stop_emitter(name)


## Sparkle effect on element
func emit_sparkles(control: Control, count: int = 5) -> void:
	for i in range(count):
		var pos: Vector2 = control.global_position + Vector2(
			randf() * control.size.x,
			randf() * control.size.y
		)
		_emit_particle(pos, SPARKLE_CONFIG)


## Hex grid background effect
func start_hex_grid(area: Rect2) -> void:
	var spacing: float = 80.0
	var cols: int = int(area.size.x / spacing) + 1
	var rows: int = int(area.size.y / spacing) + 1

	for x in range(cols):
		for y in range(rows):
			var offset: float = spacing / 2 if y % 2 == 1 else 0
			var pos: Vector2 = Vector2(
				area.position.x + x * spacing + offset,
				area.position.y + y * spacing
			)
			if randf() < 0.3:  # Only some positions emit
				start_emitter("hex_%d_%d" % [x, y], pos, HEX_GRID_CONFIG)


func stop_hex_grid() -> void:
	for name in _active_emitters.duplicate():
		if name.begins_with("hex_"):
			stop_emitter(name)


# ══════════════════════════════════════════════════════════════════════════════
# UTILITY
# ══════════════════════════════════════════════════════════════════════════════

## Get current particle count
func get_particle_count() -> int:
	return _active_particles.size()


## Clear all particles
func clear_all() -> void:
	for particle in _active_particles:
		_return_particle(particle)
	_active_particles.clear()
	_emitters.clear()
	_active_emitters.clear()


## Set maximum particles (for performance tuning)
func set_max_particles(count: int) -> void:
	_max_particles = count
	while _particle_pool.size() < count:
		_particle_pool.append(Particle.new())
