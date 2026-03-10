## UIParticleLibrary - Reusable particle effect system for UI elements.
##
## Provides pooled particle effects for common UI interactions:
## - Button click particles
## - Sparkle effects
## - Confetti system
## - Trail effects
## - Energy bursts
## - Smoke/mist effects
##
## Usage:
##   UIParticleLibrary.click_burst(global_position)
##   UIParticleLibrary.spawn_confetti(area_rect)
##   UIParticleLibrary.sparkle_trail(start_pos, end_pos)
extends Node


# region - Signals

## Emitted when a particle effect starts
signal effect_started(effect_name: String, position: Vector2)

## Emitted when a particle effect completes
signal effect_completed(effect_name: String)

# endregion


# region - Enums

## Particle effect types
enum EffectType {
	CLICK_BURST,
	SPARKLE,
	CONFETTI,
	TRAIL,
	ENERGY_BURST,
	SMOKE,
	MIST,
	STARS,
	HEARTS,
	COINS,
}

## Confetti shape types
enum ConfettiShape {
	SQUARE,
	CIRCLE,
	STAR,
	RIBBON,
}

# endregion


# region - Constants

## Pool sizes for each effect type
const POOL_SIZES: Dictionary = {
	EffectType.CLICK_BURST: 10,
	EffectType.SPARKLE: 20,
	EffectType.CONFETTI: 5,
	EffectType.TRAIL: 8,
	EffectType.ENERGY_BURST: 6,
	EffectType.SMOKE: 8,
	EffectType.MIST: 4,
	EffectType.STARS: 10,
	EffectType.HEARTS: 10,
	EffectType.COINS: 8,
}

## Default colors for various effects
const COLOR_SCHEMES: Dictionary = {
	"default": [Color.WHITE, Color(0.9, 0.9, 1.0)],
	"success": [Color(0.3, 1.0, 0.3), Color(0.5, 1.0, 0.5), Color(0.2, 0.8, 0.2)],
	"error": [Color(1.0, 0.3, 0.3), Color(1.0, 0.5, 0.3), Color(0.8, 0.2, 0.2)],
	"warning": [Color(1.0, 0.8, 0.2), Color(1.0, 0.6, 0.1), Color(0.9, 0.7, 0.1)],
	"gold": [Color(1.0, 0.84, 0.0), Color(1.0, 0.9, 0.4), Color(0.85, 0.65, 0.12)],
	"rainbow": [Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.BLUE, Color.PURPLE],
	"celebration": [Color(1.0, 0.4, 0.7), Color(0.4, 0.8, 1.0), Color(1.0, 0.9, 0.3), Color(0.5, 1.0, 0.5)],
	"magic": [Color(0.7, 0.3, 1.0), Color(0.5, 0.5, 1.0), Color(1.0, 0.5, 0.8)],
	"fire": [Color(1.0, 0.3, 0.0), Color(1.0, 0.6, 0.0), Color(1.0, 0.9, 0.3)],
	"ice": [Color(0.7, 0.9, 1.0), Color(0.5, 0.7, 1.0), Color(0.9, 0.95, 1.0)],
}

## Maximum active particles for performance
const MAX_ACTIVE_PARTICLES: int = 200

# endregion


# region - State

## Object pools for each effect type
var _pools: Dictionary = {}  ## EffectType -> Array[GPUParticles2D]

## Currently active effects
var _active_effects: Array[GPUParticles2D] = []

## Total active particle count
var _active_particle_count: int = 0

## Canvas layer for particles
var _canvas_layer: CanvasLayer = null

## Container for particle effects
var _particle_container: Control = null

## Quality level (0.0 - 1.0) for performance scaling
var _quality_level: float = 1.0

# endregion


# region - Lifecycle

func _ready() -> void:
	_setup_canvas_layer()
	_initialize_pools()
	print("[UIParticleLibrary] Particle system initialized with %d effect types" % POOL_SIZES.size())


func _process(_delta: float) -> void:
	_cleanup_finished_effects()
	_update_particle_count()


func _setup_canvas_layer() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "UIParticleLayer"
	_canvas_layer.layer = 100  # Above most UI
	add_child(_canvas_layer)

	_particle_container = Control.new()
	_particle_container.name = "ParticleContainer"
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_particle_container)


func _initialize_pools() -> void:
	for effect_type: int in POOL_SIZES.keys():
		_pools[effect_type] = []
		var pool_size: int = POOL_SIZES[effect_type]
		for i in range(pool_size):
			var particles := _create_particles_for_type(effect_type)
			particles.emitting = false
			particles.visible = false
			_particle_container.add_child(particles)
			_pools[effect_type].append(particles)

# endregion


# region - Public API

## Creates a burst of particles at the given position (for button clicks, etc.)
func click_burst(
	position: Vector2,
	color_scheme: String = "default",
	scale: float = 1.0
) -> GPUParticles2D:
	var particles := _get_from_pool(EffectType.CLICK_BURST)
	if not particles:
		return null

	_configure_click_burst(particles, color_scheme, scale)
	particles.position = position
	particles.emitting = true
	particles.visible = true

	_active_effects.append(particles)
	effect_started.emit("click_burst", position)

	return particles


## Spawns sparkle particles at the given position
func sparkle(
	position: Vector2,
	color_scheme: String = "gold",
	duration: float = 1.0,
	count: int = 20
) -> GPUParticles2D:
	var particles := _get_from_pool(EffectType.SPARKLE)
	if not particles:
		return null

	_configure_sparkle(particles, color_scheme, duration, count)
	particles.position = position
	particles.emitting = true
	particles.visible = true

	_active_effects.append(particles)
	effect_started.emit("sparkle", position)

	return particles


## Spawns confetti within the given area
func confetti(
	area: Rect2,
	color_scheme: String = "celebration",
	duration: float = 3.0,
	intensity: float = 1.0
) -> GPUParticles2D:
	var particles := _get_from_pool(EffectType.CONFETTI)
	if not particles:
		return null

	_configure_confetti(particles, area, color_scheme, duration, intensity)
	particles.position = area.position + area.size / 2
	particles.emitting = true
	particles.visible = true

	_active_effects.append(particles)
	effect_started.emit("confetti", particles.position)

	return particles


## Creates a trail effect between two positions
func trail(
	start_pos: Vector2,
	end_pos: Vector2,
	color_scheme: String = "magic",
	duration: float = 0.5
) -> GPUParticles2D:
	var particles := _get_from_pool(EffectType.TRAIL)
	if not particles:
		return null

	_configure_trail(particles, start_pos, end_pos, color_scheme, duration)
	particles.position = start_pos
	particles.emitting = true
	particles.visible = true

	_active_effects.append(particles)
	effect_started.emit("trail", start_pos)

	# Animate the trail
	var tween := create_tween()
	tween.tween_property(particles, "position", end_pos, duration) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)

	return particles


## Creates an energy burst effect
func energy_burst(
	position: Vector2,
	color_scheme: String = "magic",
	radius: float = 100.0,
	duration: float = 0.5
) -> GPUParticles2D:
	var particles := _get_from_pool(EffectType.ENERGY_BURST)
	if not particles:
		return null

	_configure_energy_burst(particles, color_scheme, radius, duration)
	particles.position = position
	particles.emitting = true
	particles.visible = true

	_active_effects.append(particles)
	effect_started.emit("energy_burst", position)

	return particles


## Creates a smoke/mist effect
func smoke(
	position: Vector2,
	color: Color = Color(0.5, 0.5, 0.5, 0.5),
	duration: float = 2.0,
	spread: float = 50.0
) -> GPUParticles2D:
	var particles := _get_from_pool(EffectType.SMOKE)
	if not particles:
		return null

	_configure_smoke(particles, color, duration, spread)
	particles.position = position
	particles.emitting = true
	particles.visible = true

	_active_effects.append(particles)
	effect_started.emit("smoke", position)

	return particles


## Creates floating star particles
func stars(
	position: Vector2,
	color_scheme: String = "gold",
	count: int = 10,
	spread: float = 100.0
) -> GPUParticles2D:
	var particles := _get_from_pool(EffectType.STARS)
	if not particles:
		return null

	_configure_stars(particles, color_scheme, count, spread)
	particles.position = position
	particles.emitting = true
	particles.visible = true

	_active_effects.append(particles)
	effect_started.emit("stars", position)

	return particles


## Creates floating heart particles (for likes, love reactions, etc.)
func hearts(
	position: Vector2,
	color: Color = Color(1.0, 0.3, 0.5),
	count: int = 5
) -> GPUParticles2D:
	var particles := _get_from_pool(EffectType.HEARTS)
	if not particles:
		return null

	_configure_hearts(particles, color, count)
	particles.position = position
	particles.emitting = true
	particles.visible = true

	_active_effects.append(particles)
	effect_started.emit("hearts", position)

	return particles


## Creates coin/reward particles
func coins(
	position: Vector2,
	count: int = 10,
	spread: float = 100.0
) -> GPUParticles2D:
	var particles := _get_from_pool(EffectType.COINS)
	if not particles:
		return null

	_configure_coins(particles, count, spread)
	particles.position = position
	particles.emitting = true
	particles.visible = true

	_active_effects.append(particles)
	effect_started.emit("coins", position)

	return particles


## Stops all active particle effects
func stop_all_effects() -> void:
	for particles: GPUParticles2D in _active_effects:
		if is_instance_valid(particles):
			particles.emitting = false
	_active_effects.clear()


## Sets the quality level for particle effects (0.0 - 1.0)
func set_quality_level(quality: float) -> void:
	_quality_level = clampf(quality, 0.1, 1.0)


## Gets the current active particle count
func get_active_particle_count() -> int:
	return _active_particle_count

# endregion


# region - Particle Configuration

func _create_particles_for_type(effect_type: int) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = 32
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.randomness = 0.5

	# Create a simple particle material
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 45.0
	material.gravity = Vector3(0, 98, 0)
	material.initial_velocity_min = 100.0
	material.initial_velocity_max = 200.0
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.color = Color.WHITE

	particles.process_material = material

	# Create draw pass (simple quad)
	var quad := QuadMesh.new()
	quad.size = Vector2(8, 8)
	particles.draw_pass_1 = quad

	return particles


func _configure_click_burst(particles: GPUParticles2D, color_scheme: String, scale: float) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	if not material:
		return

	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.gravity = Vector3(0, 200, 0)
	material.initial_velocity_min = 150.0 * scale
	material.initial_velocity_max = 300.0 * scale
	material.scale_min = 0.3 * scale
	material.scale_max = 0.8 * scale

	var colors := _get_colors(color_scheme)
	material.color = colors[0] if not colors.is_empty() else Color.WHITE

	particles.amount = int(24 * _quality_level)
	particles.lifetime = 0.6
	particles.explosiveness = 0.95


func _configure_sparkle(particles: GPUParticles2D, color_scheme: String, duration: float, count: int) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	if not material:
		return

	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.gravity = Vector3(0, -50, 0)  # Float up
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 80.0
	material.scale_min = 0.2
	material.scale_max = 0.6

	var colors := _get_colors(color_scheme)
	material.color = colors[0] if not colors.is_empty() else Color.WHITE

	particles.amount = int(count * _quality_level)
	particles.lifetime = duration
	particles.explosiveness = 0.3
	particles.randomness = 0.8


func _configure_confetti(particles: GPUParticles2D, area: Rect2, color_scheme: String, duration: float, intensity: float) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	if not material:
		return

	material.direction = Vector3(0, 1, 0)
	material.spread = 30.0
	material.gravity = Vector3(0, 200, 0)
	material.initial_velocity_min = 50.0 * intensity
	material.initial_velocity_max = 150.0 * intensity
	material.scale_min = 0.4
	material.scale_max = 1.0
	material.angular_velocity_min = -360
	material.angular_velocity_max = 360

	var colors := _get_colors(color_scheme)
	material.color = colors[0] if not colors.is_empty() else Color.WHITE

	# Set emission shape to rectangle
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(area.size.x / 2, 10, 0)

	particles.amount = int(50 * intensity * _quality_level)
	particles.lifetime = duration
	particles.explosiveness = 0.1
	particles.randomness = 0.7


func _configure_trail(particles: GPUParticles2D, _start_pos: Vector2, _end_pos: Vector2, color_scheme: String, duration: float) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	if not material:
		return

	material.direction = Vector3(0, 0, 0)
	material.spread = 15.0
	material.gravity = Vector3(0, 0, 0)
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 20.0
	material.scale_min = 0.3
	material.scale_max = 0.6

	var colors := _get_colors(color_scheme)
	material.color = colors[0] if not colors.is_empty() else Color.WHITE

	particles.amount = int(30 * _quality_level)
	particles.lifetime = duration * 0.8
	particles.explosiveness = 0.0
	particles.one_shot = false

	# Re-enable one_shot after duration
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		particles.one_shot = true
		particles.emitting = false
	)


func _configure_energy_burst(particles: GPUParticles2D, color_scheme: String, radius: float, duration: float) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	if not material:
		return

	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.gravity = Vector3(0, 0, 0)
	material.initial_velocity_min = radius * 2
	material.initial_velocity_max = radius * 4
	material.scale_min = 0.5
	material.scale_max = 1.5
	material.damping_min = 2.0
	material.damping_max = 4.0

	var colors := _get_colors(color_scheme)
	material.color = colors[0] if not colors.is_empty() else Color.WHITE

	particles.amount = int(40 * _quality_level)
	particles.lifetime = duration
	particles.explosiveness = 1.0


func _configure_smoke(particles: GPUParticles2D, color: Color, duration: float, spread: float) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	if not material:
		return

	material.direction = Vector3(0, -1, 0)
	material.spread = 30.0
	material.gravity = Vector3(0, -30, 0)  # Float up
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 30.0
	material.scale_min = 1.0
	material.scale_max = 3.0
	material.color = color

	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = spread

	particles.amount = int(20 * _quality_level)
	particles.lifetime = duration
	particles.explosiveness = 0.1
	particles.randomness = 0.6


func _configure_stars(particles: GPUParticles2D, color_scheme: String, count: int, spread: float) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	if not material:
		return

	material.direction = Vector3(0, -1, 0)
	material.spread = 45.0
	material.gravity = Vector3(0, -20, 0)
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 80.0
	material.scale_min = 0.3
	material.scale_max = 0.8
	material.angular_velocity_min = -180
	material.angular_velocity_max = 180

	var colors := _get_colors(color_scheme)
	material.color = colors[0] if not colors.is_empty() else Color.WHITE

	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = spread

	particles.amount = int(count * _quality_level)
	particles.lifetime = 1.5
	particles.explosiveness = 0.8


func _configure_hearts(particles: GPUParticles2D, color: Color, count: int) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	if not material:
		return

	material.direction = Vector3(0, -1, 0)
	material.spread = 60.0
	material.gravity = Vector3(0, -50, 0)  # Float up
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.scale_min = 0.5
	material.scale_max = 1.2
	material.color = color

	particles.amount = int(count * _quality_level)
	particles.lifetime = 1.5
	particles.explosiveness = 0.5


func _configure_coins(particles: GPUParticles2D, count: int, spread: float) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	if not material:
		return

	material.direction = Vector3(0, -1, 0)
	material.spread = 45.0
	material.gravity = Vector3(0, 300, 0)
	material.initial_velocity_min = 200.0
	material.initial_velocity_max = 400.0
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.angular_velocity_min = -720
	material.angular_velocity_max = 720
	material.color = Color(1.0, 0.84, 0.0)  # Gold

	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = spread * 0.3

	particles.amount = int(count * _quality_level)
	particles.lifetime = 1.2
	particles.explosiveness = 0.9

# endregion


# region - Pool Management

func _get_from_pool(effect_type: int) -> GPUParticles2D:
	if not _pools.has(effect_type):
		return null

	# Check particle limit
	if _active_particle_count >= MAX_ACTIVE_PARTICLES:
		_recycle_oldest_effect()

	var pool: Array = _pools[effect_type]
	for particles: GPUParticles2D in pool:
		if not particles.emitting and particles not in _active_effects:
			return particles

	# Pool exhausted - try to recycle an old effect
	_recycle_oldest_effect()

	# Try again
	for particles: GPUParticles2D in pool:
		if not particles.emitting and particles not in _active_effects:
			return particles

	return null


func _return_to_pool(particles: GPUParticles2D) -> void:
	particles.emitting = false
	particles.visible = false
	_active_effects.erase(particles)


func _recycle_oldest_effect() -> void:
	if _active_effects.is_empty():
		return

	var oldest := _active_effects[0]
	if is_instance_valid(oldest):
		oldest.emitting = false
		oldest.visible = false
	_active_effects.remove_at(0)


func _cleanup_finished_effects() -> void:
	var to_remove: Array[GPUParticles2D] = []

	for particles: GPUParticles2D in _active_effects:
		if not is_instance_valid(particles):
			to_remove.append(particles)
			continue

		if not particles.emitting and particles.one_shot:
			to_remove.append(particles)
			particles.visible = false
			effect_completed.emit(_get_effect_name(particles))

	for particles: GPUParticles2D in to_remove:
		_active_effects.erase(particles)


func _update_particle_count() -> void:
	_active_particle_count = 0
	for particles: GPUParticles2D in _active_effects:
		if is_instance_valid(particles) and particles.emitting:
			_active_particle_count += particles.amount

# endregion


# region - Utilities

func _get_colors(scheme_name: String) -> Array:
	if COLOR_SCHEMES.has(scheme_name):
		return COLOR_SCHEMES[scheme_name]
	return COLOR_SCHEMES["default"]


func _get_effect_name(_particles: GPUParticles2D) -> String:
	# Could store this on the particles node if needed
	return "unknown"

# endregion
