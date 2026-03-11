## MovementParticles - Movement-related VFX library for BattleZone Party.
##
## Provides effects for:
## - Dust clouds (running, sliding)
## - Jetpack flames (continuous thrust)
## - Landing dust (ground impact)
## - Dash trails (dodge/sprint effects)
## - Speed lines (fast movement feedback)
## - Footstep dust
## - Jump/double jump effects
##
## Usage:
##   MovementParticles.dust_cloud(position, intensity)
##   MovementParticles.start_jetpack(character_node) -> JetpackController
##   MovementParticles.landing_dust(position, fall_speed)
class_name MovementParticles
extends Node


# region - Signals

## Emitted when a movement effect triggers (for audio sync)
signal movement_effect_triggered(effect_type: String, position: Vector3)

# endregion


# region - Constants

## Ground surface types for dust effects
enum GroundType {
	DIRT,
	SAND,
	CONCRETE,
	GRASS,
	METAL,
	WATER,
	SNOW,
	DEFAULT,
}

## Dust colors by ground type
const GROUND_COLORS: Dictionary = {
	GroundType.DIRT: Color(0.55, 0.45, 0.35, 0.7),
	GroundType.SAND: Color(0.85, 0.75, 0.55, 0.6),
	GroundType.CONCRETE: Color(0.5, 0.5, 0.5, 0.5),
	GroundType.GRASS: Color(0.4, 0.55, 0.3, 0.4),
	GroundType.METAL: Color(0.6, 0.6, 0.65, 0.3),
	GroundType.WATER: Color(0.6, 0.8, 1.0, 0.5),
	GroundType.SNOW: Color(0.95, 0.95, 1.0, 0.7),
	GroundType.DEFAULT: Color(0.6, 0.55, 0.45, 0.6),
}

## Jetpack flame presets
const JETPACK_PRESETS: Dictionary = {
	"standard": {
		"color_inner": Color(1.0, 0.9, 0.3, 1.0),
		"color_outer": Color(1.0, 0.3, 0.0, 0.0),
		"intensity": 1.0,
	},
	"plasma": {
		"color_inner": Color(0.3, 0.8, 1.0, 1.0),
		"color_outer": Color(0.1, 0.3, 1.0, 0.0),
		"intensity": 1.2,
	},
	"rocket": {
		"color_inner": Color(1.0, 1.0, 0.5, 1.0),
		"color_outer": Color(1.0, 0.4, 0.0, 0.0),
		"intensity": 1.5,
	},
}

# endregion


# region - Instance

static var _instance: MovementParticles = null


static func get_instance() -> MovementParticles:
	if not is_instance_valid(_instance):
		_instance = MovementParticles.new()
		_instance.name = "MovementParticles"
	return _instance


func _enter_tree() -> void:
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null

# endregion


# region - Dust Effects

## Spawns a dust cloud effect (for running, sliding, etc.).
## [param position] World position at feet level
## [param options] Optional: ground_type, intensity, velocity
static func dust_cloud(position: Vector3, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var ground_type: GroundType = options.get("ground_type", GroundType.DEFAULT)
	var color: Color = options.get("color", GROUND_COLORS.get(ground_type, GROUND_COLORS[GroundType.DEFAULT]))
	var intensity: float = options.get("intensity", 1.0)

	var spawn_options: Dictionary = {
		"color": color,
		"scale": intensity,
	}

	# Add directional velocity if provided (for running dust)
	if options.has("velocity"):
		var vel: Vector3 = options["velocity"]
		if vel.length_squared() > 0.01:
			spawn_options["direction"] = -vel.normalized()

	var effect: Node = particle_manager.spawn_movement_effect("dust_cloud", position, spawn_options)

	# Emit signal for audio
	var instance: MovementParticles = get_instance()
	if is_instance_valid(instance):
		instance.movement_effect_triggered.emit("dust", position)

	return effect


## Spawns footstep dust (smaller, periodic effect).
## [param position] Foot position
## [param ground_type] Surface type for color
static func footstep_dust(position: Vector3, ground_type: GroundType = GroundType.DEFAULT) -> Node:
	return dust_cloud(position, {
		"ground_type": ground_type,
		"intensity": 0.4,
	})


## Spawns sliding dust (larger, directional).
## [param position] Character position
## [param velocity] Slide velocity (for direction)
## [param ground_type] Surface type
static func slide_dust(position: Vector3, velocity: Vector3, ground_type: GroundType = GroundType.DEFAULT) -> Node:
	return dust_cloud(position, {
		"ground_type": ground_type,
		"intensity": 1.2,
		"velocity": velocity,
	})

# endregion


# region - Landing Effects

## Spawns landing dust based on fall speed.
## [param position] Landing position
## [param fall_speed] Vertical velocity at impact (positive = faster fall)
## [param options] Optional: ground_type
static func landing_dust(position: Vector3, fall_speed: float = 5.0, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	# Scale effect based on fall speed
	var intensity: float = clampf(fall_speed / 15.0, 0.3, 2.0)

	var ground_type: GroundType = options.get("ground_type", GroundType.DEFAULT)
	var color: Color = options.get("color", GROUND_COLORS.get(ground_type, GROUND_COLORS[GroundType.DEFAULT]))

	var spawn_options: Dictionary = {
		"color": color,
		"scale": intensity,
	}

	var effect: Node = particle_manager.spawn_movement_effect("landing_dust", position, spawn_options)

	# Emit signal with intensity for audio/haptics
	var instance: MovementParticles = get_instance()
	if is_instance_valid(instance):
		instance.movement_effect_triggered.emit("landing", position)

	return effect


## Spawns a heavy landing effect (superhero landing style).
## [param position] Impact center
## [param options] Optional: color, crack_effect
static func heavy_landing(position: Vector3, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	# Spawn main dust ring
	var effect: Node = particle_manager.spawn_movement_effect("landing_dust", position, {
		"scale": 2.0,
		"color": options.get("color", GROUND_COLORS[GroundType.CONCRETE]),
	})

	# Spawn debris particles
	if particle_manager.has_method("spawn_effect"):
		particle_manager.spawn_effect(24, position, {"scale": 1.5})  ## SPARKS

	# Spawn impact light
	_spawn_landing_light(position)

	return effect


static func _spawn_landing_light(position: Vector3) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 2.0
	light.omni_range = 3.0
	light.omni_attenuation = 2.0
	light.position = position

	tree.root.add_child(light)

	var tween: Tween = tree.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.15)
	tween.tween_callback(light.queue_free)

# endregion


# region - Jetpack Effects

## Starts a jetpack flame effect attached to a character.
## Returns a JetpackController that manages the continuous effect.
## [param attach_node] Node to attach the effect to (usually character feet)
## [param options] Optional: preset, offset
static func start_jetpack(attach_node: Node3D, options: Dictionary = {}) -> JetpackController:
	var controller: JetpackController = JetpackController.new()
	controller.start(attach_node, options)

	var instance: MovementParticles = get_instance()
	if is_instance_valid(instance):
		instance.movement_effect_triggered.emit("jetpack_start", attach_node.global_position)

	return controller


## Spawns a single jetpack burst (for jump boost).
## [param position] Position to spawn at
## [param direction] Direction of thrust (usually down)
static func jetpack_burst(position: Vector3, direction: Vector3 = Vector3.DOWN, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var preset_name: String = options.get("preset", "standard")
	var preset: Dictionary = JETPACK_PRESETS.get(preset_name, JETPACK_PRESETS["standard"])

	var spawn_options: Dictionary = {
		"direction": direction,
		"color": options.get("color", preset["color_inner"]),
		"scale": options.get("scale", 1.0) * preset["intensity"],
	}

	return particle_manager.spawn_movement_effect("jetpack_flame", position, spawn_options)

# endregion


# region - Dash/Speed Effects

## Spawns a dash trail effect.
## [param position] Character position
## [param direction] Dash direction
## [param options] Optional: color, length
static func dash_trail(position: Vector3, direction: Vector3, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var spawn_options: Dictionary = {
		"direction": -direction.normalized() if direction.length_squared() > 0.01 else Vector3.BACK,
		"color": options.get("color", Color(0.5, 0.8, 1.0, 0.6)),
		"scale": options.get("scale", 1.0),
	}

	var effect: Node = particle_manager.spawn_movement_effect("dash_trail", position, spawn_options)

	var instance: MovementParticles = get_instance()
	if is_instance_valid(instance):
		instance.movement_effect_triggered.emit("dash", position)

	return effect


## Spawns speed lines effect (for very fast movement).
## [param position] Character position
## [param velocity] Movement velocity
static func speed_lines(position: Vector3, velocity: Vector3, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var speed: float = velocity.length()
	if speed < 10.0:  # Don't show speed lines for slow movement
		return null

	var spawn_options: Dictionary = {
		"direction": -velocity.normalized(),
		"color": options.get("color", Color(1.0, 1.0, 1.0, 0.5)),
		"scale": clampf(speed / 20.0, 0.5, 2.0),
	}

	return particle_manager.spawn_movement_effect("speed_lines", position, spawn_options)


## Starts continuous speed line generation for fast movement.
## Returns a controller that should be updated each frame.
static func start_speed_effect(character_node: Node3D) -> SpeedEffectController:
	var controller: SpeedEffectController = SpeedEffectController.new()
	controller.start(character_node)
	return controller

# endregion


# region - Jump Effects

## Spawns a jump launch effect.
## [param position] Position at feet
## [param ground_type] Surface type for color
static func jump_launch(position: Vector3, ground_type: GroundType = GroundType.DEFAULT) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var color: Color = GROUND_COLORS.get(ground_type, GROUND_COLORS[GroundType.DEFAULT])

	var spawn_options: Dictionary = {
		"direction": Vector3.DOWN,
		"color": color,
		"scale": 0.7,
	}

	return particle_manager.spawn_movement_effect("dust_cloud", position, spawn_options)


## Spawns a double jump effect (air burst).
## [param position] Position in air
## [param options] Optional: color
static func double_jump(position: Vector3, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var spawn_options: Dictionary = {
		"direction": Vector3.DOWN,
		"color": options.get("color", Color(0.7, 0.9, 1.0, 0.6)),
		"scale": 0.8,
	}

	# Spawn a ring-like dust effect
	var effect: Node = particle_manager.spawn_movement_effect("landing_dust", position, spawn_options)

	# Also spawn a small burst
	particle_manager.spawn_movement_effect("dash_trail", position, {
		"direction": Vector3.DOWN,
		"color": Color(0.8, 0.9, 1.0, 0.4),
		"scale": 0.5,
	})

	return effect


## Spawns wall jump particles.
## [param position] Position on wall
## [param wall_normal] Wall surface normal
static func wall_jump(position: Vector3, wall_normal: Vector3) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var spawn_options: Dictionary = {
		"direction": wall_normal,
		"color": GROUND_COLORS[GroundType.CONCRETE],
		"scale": 0.6,
	}

	return particle_manager.spawn_movement_effect("dust_cloud", position, spawn_options)

# endregion


# region - Water Effects

## Spawns water splash effect.
## [param position] Water surface position
## [param intensity] Splash size (0.0-2.0)
static func water_splash(position: Vector3, intensity: float = 1.0) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var spawn_options: Dictionary = {
		"direction": Vector3.UP,
		"color": Color(0.6, 0.8, 1.0, 0.7),
		"scale": intensity,
	}

	return particle_manager.spawn_movement_effect("landing_dust", position, spawn_options)


## Spawns water ripple effect (for swimming).
## [param position] Water surface position
static func water_ripple(position: Vector3) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var spawn_options: Dictionary = {
		"color": Color(0.7, 0.85, 1.0, 0.4),
		"scale": 0.5,
	}

	return particle_manager.spawn_movement_effect("dust_cloud", position, spawn_options)

# endregion


# region - Helpers

static func _get_particle_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("AdvancedParticleManager"):
		return tree.root.get_node("AdvancedParticleManager")
	return null

# endregion


# region - Jetpack Controller

## Controller for continuous jetpack flame effects.
class JetpackController extends RefCounted:
	var _active: bool = false
	var _attach_node: Node3D
	var _offset: Vector3 = Vector3(0, -0.5, 0)
	var _particles: CPUParticles3D
	var _light: OmniLight3D
	var _preset: Dictionary
	var _thrust_level: float = 1.0

	func start(attach_node: Node3D, options: Dictionary = {}) -> void:
		_attach_node = attach_node
		_offset = options.get("offset", Vector3(0, -0.5, 0))
		_active = true

		var preset_name: String = options.get("preset", "standard")
		_preset = JETPACK_PRESETS.get(preset_name, JETPACK_PRESETS["standard"])

		# Create persistent particle emitter
		_create_particles()

		# Create glow light
		_create_light()

	func _create_particles() -> void:
		_particles = CPUParticles3D.new()
		_particles.amount = 15
		_particles.lifetime = 0.2
		_particles.explosiveness = 0.0
		_particles.one_shot = false
		_particles.emitting = true

		_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_particles.emission_sphere_radius = 0.15

		_particles.direction = Vector3(0, -1, 0)
		_particles.spread = 25.0
		_particles.initial_velocity_min = 3.0
		_particles.initial_velocity_max = 8.0

		_particles.gravity = Vector3(0, 2, 0)

		_particles.scale_amount_min = 0.05
		_particles.scale_amount_max = 0.15

		_particles.color = _preset["color_inner"]

		if is_instance_valid(_attach_node):
			_attach_node.add_child(_particles)
			_particles.position = _offset

	func _create_light() -> void:
		_light = OmniLight3D.new()
		_light.light_color = _preset["color_inner"]
		_light.light_energy = 2.0 * _preset["intensity"]
		_light.omni_range = 2.0
		_light.omni_attenuation = 2.0

		if is_instance_valid(_attach_node):
			_attach_node.add_child(_light)
			_light.position = _offset

	func set_thrust(level: float) -> void:
		_thrust_level = clampf(level, 0.0, 2.0)

		if is_instance_valid(_particles):
			_particles.amount = int(15 * _thrust_level)
			_particles.initial_velocity_max = 8.0 * _thrust_level

		if is_instance_valid(_light):
			_light.light_energy = 2.0 * _preset["intensity"] * _thrust_level

	func update(_delta: float) -> void:
		if not _active:
			return

		# Particles follow the attach node automatically since they're children
		# Just update intensity flicker
		if is_instance_valid(_light):
			_light.light_energy = (2.0 + randf_range(-0.2, 0.2)) * _preset["intensity"] * _thrust_level

	func stop() -> void:
		_active = false

		if is_instance_valid(_particles):
			_particles.emitting = false
			# Queue free after particles fade
			var tree: SceneTree = Engine.get_main_loop() as SceneTree
			if tree:
				var timer: SceneTreeTimer = tree.create_timer(_particles.lifetime * 2.0)
				timer.timeout.connect(func() -> void:
					if is_instance_valid(_particles):
						_particles.queue_free()
				)

		if is_instance_valid(_light):
			var tree: SceneTree = Engine.get_main_loop() as SceneTree
			if tree:
				var tween: Tween = tree.create_tween()
				tween.tween_property(_light, "light_energy", 0.0, 0.1)
				tween.tween_callback(_light.queue_free)

	func is_active() -> bool:
		return _active

# endregion


# region - Speed Effect Controller

## Controller for continuous speed line effects during fast movement.
class SpeedEffectController extends RefCounted:
	var _active: bool = false
	var _character: Node3D
	var _spawn_timer: float = 0.0
	var _min_speed: float = 12.0
	var _spawn_interval: float = 0.08
	var _last_velocity: Vector3 = Vector3.ZERO

	func start(character: Node3D) -> void:
		_active = true
		_character = character

	func update(delta: float, velocity: Vector3) -> void:
		if not _active or not is_instance_valid(_character):
			return

		_last_velocity = velocity
		var speed: float = velocity.length()

		if speed < _min_speed:
			return

		_spawn_timer += delta
		var adjusted_interval: float = _spawn_interval / (speed / _min_speed)

		if _spawn_timer >= adjusted_interval:
			_spawn_timer = 0.0
			MovementParticles.speed_lines(_character.global_position, velocity)

	func stop() -> void:
		_active = false

	func is_active() -> bool:
		return _active

# endregion
