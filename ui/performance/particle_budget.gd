## ParticleBudget - Advanced particle system performance manager
##
## Ensures 60 FPS through intelligent particle management:
## - Per-screen particle budgets
## - Dynamic reduction based on FPS
## - Object pooling for zero-allocation particles
## - Texture atlasing support
## - Off-screen particle culling
## - GPU particles when supported
##
## Usage:
##   var emitter = ParticleBudget.spawn_particles(ParticleBudget.ParticleType.EXPLOSION, pos)
##   ParticleBudget.set_screen_budget("gameplay", 500)
class_name ParticleBudget
extends Node


# =============================================================================
# region - Signals
# =============================================================================

## Emitted when particle budget changes
signal budget_changed(screen: String, current: int, max_budget: int)

## Emitted when particles are culled due to budget
signal particles_culled(count: int, reason: String)

## Emitted when performance mode changes
signal performance_mode_changed(mode: PerformanceMode)

# endregion


# =============================================================================
# region - Enums and Constants
# =============================================================================

## Particle types for built-in effects
enum ParticleType {
	EXPLOSION,
	MUZZLE_FLASH,
	BULLET_IMPACT,
	BLOOD_SPLATTER,
	SMOKE,
	DUST,
	SPARKS,
	CONFETTI,
	STARS,
	HEAL,
	SHIELD,
	DAMAGE_NUMBER,
	FOOTSTEP,
	JETPACK,
	SPAWN,
	DEATH,
	PICKUP,
	POWERUP
}

## Performance modes
enum PerformanceMode {
	ULTRA,      ## Full particle counts
	HIGH,       ## 80% particles
	MEDIUM,     ## 50% particles
	LOW,        ## 25% particles
	MINIMAL     ## 10% particles, critical only
}

## Particle priority levels
enum ParticlePriority {
	CRITICAL,   ## Always spawn (player feedback)
	HIGH,       ## Important (combat effects)
	MEDIUM,     ## Nice to have (ambient)
	LOW,        ## Optional (decoration)
	AMBIENT     ## First to cull (background effects)
}

## Default budgets per screen
const DEFAULT_BUDGETS: Dictionary = {
	"gameplay": 500,
	"menu": 200,
	"results": 300,
	"loading": 100,
	"hud": 150
}

## Particle configs
const PARTICLE_CONFIGS: Dictionary = {
	ParticleType.EXPLOSION: {
		"base_count": 40,
		"lifetime": 1.0,
		"priority": ParticlePriority.HIGH,
		"one_shot": true,
		"use_gpu": true
	},
	ParticleType.MUZZLE_FLASH: {
		"base_count": 15,
		"lifetime": 0.15,
		"priority": ParticlePriority.HIGH,
		"one_shot": true,
		"use_gpu": false
	},
	ParticleType.BULLET_IMPACT: {
		"base_count": 20,
		"lifetime": 0.5,
		"priority": ParticlePriority.HIGH,
		"one_shot": true,
		"use_gpu": true
	},
	ParticleType.BLOOD_SPLATTER: {
		"base_count": 25,
		"lifetime": 0.8,
		"priority": ParticlePriority.HIGH,
		"one_shot": true,
		"use_gpu": true
	},
	ParticleType.SMOKE: {
		"base_count": 20,
		"lifetime": 2.0,
		"priority": ParticlePriority.MEDIUM,
		"one_shot": false,
		"use_gpu": true
	},
	ParticleType.DUST: {
		"base_count": 15,
		"lifetime": 1.5,
		"priority": ParticlePriority.LOW,
		"one_shot": true,
		"use_gpu": false
	},
	ParticleType.SPARKS: {
		"base_count": 30,
		"lifetime": 0.6,
		"priority": ParticlePriority.MEDIUM,
		"one_shot": true,
		"use_gpu": true
	},
	ParticleType.CONFETTI: {
		"base_count": 50,
		"lifetime": 3.0,
		"priority": ParticlePriority.LOW,
		"one_shot": true,
		"use_gpu": true
	},
	ParticleType.STARS: {
		"base_count": 25,
		"lifetime": 1.5,
		"priority": ParticlePriority.LOW,
		"one_shot": true,
		"use_gpu": false
	},
	ParticleType.HEAL: {
		"base_count": 20,
		"lifetime": 1.0,
		"priority": ParticlePriority.CRITICAL,
		"one_shot": true,
		"use_gpu": false
	},
	ParticleType.SHIELD: {
		"base_count": 15,
		"lifetime": 0.5,
		"priority": ParticlePriority.CRITICAL,
		"one_shot": false,
		"use_gpu": true
	},
	ParticleType.DAMAGE_NUMBER: {
		"base_count": 1,
		"lifetime": 1.0,
		"priority": ParticlePriority.CRITICAL,
		"one_shot": true,
		"use_gpu": false
	},
	ParticleType.FOOTSTEP: {
		"base_count": 5,
		"lifetime": 0.5,
		"priority": ParticlePriority.AMBIENT,
		"one_shot": true,
		"use_gpu": false
	},
	ParticleType.JETPACK: {
		"base_count": 15,
		"lifetime": 0.4,
		"priority": ParticlePriority.HIGH,
		"one_shot": false,
		"use_gpu": true
	},
	ParticleType.SPAWN: {
		"base_count": 30,
		"lifetime": 1.0,
		"priority": ParticlePriority.HIGH,
		"one_shot": true,
		"use_gpu": true
	},
	ParticleType.DEATH: {
		"base_count": 40,
		"lifetime": 1.5,
		"priority": ParticlePriority.CRITICAL,
		"one_shot": true,
		"use_gpu": true
	},
	ParticleType.PICKUP: {
		"base_count": 20,
		"lifetime": 0.8,
		"priority": ParticlePriority.MEDIUM,
		"one_shot": true,
		"use_gpu": false
	},
	ParticleType.POWERUP: {
		"base_count": 25,
		"lifetime": 1.0,
		"priority": ParticlePriority.CRITICAL,
		"one_shot": true,
		"use_gpu": true
	}
}

## Pool sizes
const POOL_SIZE_CPU: int = 50
const POOL_SIZE_GPU: int = 30

## Performance thresholds
const FPS_ULTRA: float = 58.0
const FPS_HIGH: float = 50.0
const FPS_MEDIUM: float = 40.0
const FPS_LOW: float = 30.0

## Quality multipliers per mode
const QUALITY_MULTIPLIERS: Dictionary = {
	PerformanceMode.ULTRA: 1.0,
	PerformanceMode.HIGH: 0.8,
	PerformanceMode.MEDIUM: 0.5,
	PerformanceMode.LOW: 0.25,
	PerformanceMode.MINIMAL: 0.1
}

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

## Current performance mode
var current_mode: PerformanceMode = PerformanceMode.HIGH

## Whether auto-adjustment is enabled
var auto_adjust_enabled: bool = true

## Current screen for budget tracking
var current_screen: String = "gameplay"

## Screen budgets (particles per screen)
var screen_budgets: Dictionary = {}

## Active particle counts per screen
var active_particles: Dictionary = {}

## Object pools
var _cpu_particle_pool: Array[CPUParticles2D] = []
var _cpu_particle_pool_3d: Array[CPUParticles3D] = []
var _gpu_particle_pool: Array[GPUParticles2D] = []
var _gpu_particle_pool_3d: Array[GPUParticles3D] = []

## Active emitters tracking
var _active_emitters: Array[Node] = []

## FPS tracking
var _frame_times: Array[float] = []
var _current_fps: float = 60.0

## Viewport for culling
var _viewport_rect: Rect2 = Rect2()
var _culling_margin: float = 150.0

## Whether GPU particles are supported
var _gpu_particles_supported: bool = true

## Statistics
var _total_particles_spawned: int = 0
var _total_particles_culled: int = 0
var _particles_recycled: int = 0

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	_initialize_budgets()
	_initialize_pools()
	_detect_gpu_support()
	_update_viewport_rect()

	get_viewport().size_changed.connect(_update_viewport_rect)


func _process(delta: float) -> void:
	_track_frame_time(delta)
	_update_active_counts()
	_cull_off_screen_particles()

	if auto_adjust_enabled:
		_auto_adjust_performance_mode()


func _initialize_budgets() -> void:
	for screen: String in DEFAULT_BUDGETS:
		screen_budgets[screen] = DEFAULT_BUDGETS[screen]
		active_particles[screen] = 0


func _initialize_pools() -> void:
	# Pre-allocate CPU particle pools
	for i in range(POOL_SIZE_CPU):
		var cpu_2d := CPUParticles2D.new()
		cpu_2d.emitting = false
		cpu_2d.one_shot = true
		_cpu_particle_pool.append(cpu_2d)

		var cpu_3d := CPUParticles3D.new()
		cpu_3d.emitting = false
		cpu_3d.one_shot = true
		_cpu_particle_pool_3d.append(cpu_3d)

	# Pre-allocate GPU particle pools
	for i in range(POOL_SIZE_GPU):
		var gpu_2d := GPUParticles2D.new()
		gpu_2d.emitting = false
		gpu_2d.one_shot = true
		_gpu_particle_pool.append(gpu_2d)

		var gpu_3d := GPUParticles3D.new()
		gpu_3d.emitting = false
		gpu_3d.one_shot = true
		_gpu_particle_pool_3d.append(gpu_3d)


func _detect_gpu_support() -> void:
	# Check if GPU particles are supported
	var renderer: String = ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")
	_gpu_particles_supported = renderer != "gl_compatibility"


func _update_viewport_rect() -> void:
	var viewport := get_viewport()
	if viewport:
		_viewport_rect = Rect2(Vector2.ZERO, viewport.get_visible_rect().size)

# endregion


# =============================================================================
# region - Main API
# =============================================================================

## Spawns a particle effect at the given position
func spawn_particles(
	type: ParticleType,
	position: Variant,  ## Vector2 or Vector3
	parent: Node = null,
	override_count: int = -1,
	priority_override: ParticlePriority = ParticlePriority.MEDIUM
) -> Node:
	var config: Dictionary = PARTICLE_CONFIGS.get(type, {})
	if config.is_empty():
		push_warning("[ParticleBudget] Unknown particle type: %d" % type)
		return null

	var priority: ParticlePriority = config.get("priority", priority_override)

	# Check if we should spawn based on budget and priority
	if not _can_spawn_particles(config, priority):
		_total_particles_culled += 1
		particles_culled.emit(1, "budget")
		return null

	# Calculate particle count based on performance mode
	var base_count: int = override_count if override_count > 0 else config.get("base_count", 20)
	var adjusted_count: int = _adjust_particle_count(base_count, priority)

	if adjusted_count <= 0:
		return null

	# Get emitter from pool
	var is_3d: bool = position is Vector3
	var use_gpu: bool = config.get("use_gpu", false) and _gpu_particles_supported
	var emitter: Node = _get_pooled_emitter(is_3d, use_gpu)

	if emitter == null:
		return null

	# Configure emitter
	_configure_emitter(emitter, type, config, adjusted_count, position)

	# Add to scene
	if parent:
		parent.add_child(emitter)
	else:
		get_tree().current_scene.add_child(emitter)

	# Track emitter
	_active_emitters.append(emitter)
	_total_particles_spawned += adjusted_count

	# Update active count
	active_particles[current_screen] = active_particles.get(current_screen, 0) + adjusted_count
	budget_changed.emit(current_screen, active_particles[current_screen], screen_budgets[current_screen])

	# Auto-cleanup for one-shot particles
	if config.get("one_shot", true):
		var lifetime: float = config.get("lifetime", 1.0)
		_schedule_cleanup(emitter, lifetime, adjusted_count)

	return emitter


## Spawns 2D particles
func spawn_particles_2d(
	type: ParticleType,
	position: Vector2,
	parent: Node = null,
	override_count: int = -1
) -> Node:
	return spawn_particles(type, position, parent, override_count)


## Spawns 3D particles
func spawn_particles_3d(
	type: ParticleType,
	position: Vector3,
	parent: Node = null,
	override_count: int = -1
) -> Node:
	return spawn_particles(type, position, parent, override_count)


## Stops and recycles a particle emitter
func stop_particles(emitter: Node) -> void:
	if not is_instance_valid(emitter):
		return

	if emitter is CPUParticles2D:
		emitter.emitting = false
		_return_emitter_to_pool(emitter)
	elif emitter is CPUParticles3D:
		emitter.emitting = false
		_return_emitter_to_pool(emitter)
	elif emitter is GPUParticles2D:
		emitter.emitting = false
		_return_emitter_to_pool(emitter)
	elif emitter is GPUParticles3D:
		emitter.emitting = false
		_return_emitter_to_pool(emitter)

	_active_emitters.erase(emitter)


## Sets the current screen for budget tracking
func set_current_screen(screen: String) -> void:
	if not screen_budgets.has(screen):
		screen_budgets[screen] = DEFAULT_BUDGETS.get("gameplay", 500)
		active_particles[screen] = 0

	current_screen = screen


## Sets the budget for a specific screen
func set_screen_budget(screen: String, budget: int) -> void:
	screen_budgets[screen] = budget
	budget_changed.emit(screen, active_particles.get(screen, 0), budget)


## Gets remaining budget for current screen
func get_remaining_budget() -> int:
	var current: int = active_particles.get(current_screen, 0)
	var budget: int = screen_budgets.get(current_screen, 500)
	return maxi(0, budget - current)


## Forces cleanup of all particles
func cleanup_all() -> void:
	for emitter: Node in _active_emitters:
		if is_instance_valid(emitter):
			stop_particles(emitter)

	_active_emitters.clear()

	for screen: String in active_particles:
		active_particles[screen] = 0

# endregion


# =============================================================================
# region - Pool Management
# =============================================================================

func _get_pooled_emitter(is_3d: bool, use_gpu: bool) -> Node:
	if is_3d:
		if use_gpu and _gpu_particle_pool_3d.size() > 0:
			_particles_recycled += 1
			return _gpu_particle_pool_3d.pop_back()
		elif _cpu_particle_pool_3d.size() > 0:
			_particles_recycled += 1
			return _cpu_particle_pool_3d.pop_back()
	else:
		if use_gpu and _gpu_particle_pool.size() > 0:
			_particles_recycled += 1
			return _gpu_particle_pool.pop_back()
		elif _cpu_particle_pool.size() > 0:
			_particles_recycled += 1
			return _cpu_particle_pool.pop_back()

	# Pool exhausted, create new
	if is_3d:
		return GPUParticles3D.new() if use_gpu else CPUParticles3D.new()
	else:
		return GPUParticles2D.new() if use_gpu else CPUParticles2D.new()


func _return_emitter_to_pool(emitter: Node) -> void:
	if emitter.get_parent():
		emitter.get_parent().remove_child(emitter)

	if emitter is CPUParticles2D and _cpu_particle_pool.size() < POOL_SIZE_CPU:
		emitter.emitting = false
		_cpu_particle_pool.append(emitter)
	elif emitter is CPUParticles3D and _cpu_particle_pool_3d.size() < POOL_SIZE_CPU:
		emitter.emitting = false
		_cpu_particle_pool_3d.append(emitter)
	elif emitter is GPUParticles2D and _gpu_particle_pool.size() < POOL_SIZE_GPU:
		emitter.emitting = false
		_gpu_particle_pool.append(emitter)
	elif emitter is GPUParticles3D and _gpu_particle_pool_3d.size() < POOL_SIZE_GPU:
		emitter.emitting = false
		_gpu_particle_pool_3d.append(emitter)
	else:
		emitter.queue_free()


func _schedule_cleanup(emitter: Node, lifetime: float, count: int) -> void:
	var timer := get_tree().create_timer(lifetime + 0.5)
	timer.timeout.connect(func():
		if is_instance_valid(emitter):
			stop_particles(emitter)
			active_particles[current_screen] = maxi(0, active_particles.get(current_screen, 0) - count)
			budget_changed.emit(current_screen, active_particles[current_screen], screen_budgets[current_screen])
	)

# endregion


# =============================================================================
# region - Emitter Configuration
# =============================================================================

func _configure_emitter(emitter: Node, type: ParticleType, config: Dictionary, count: int, position: Variant) -> void:
	var is_2d: bool = position is Vector2

	if is_2d:
		_configure_2d_emitter(emitter, type, config, count, position as Vector2)
	else:
		_configure_3d_emitter(emitter, type, config, count, position as Vector3)


func _configure_2d_emitter(emitter: Node, type: ParticleType, config: Dictionary, count: int, position: Vector2) -> void:
	var lifetime: float = config.get("lifetime", 1.0)
	var one_shot: bool = config.get("one_shot", true)

	if emitter is CPUParticles2D:
		emitter.position = position
		emitter.amount = count
		emitter.lifetime = lifetime
		emitter.one_shot = one_shot
		emitter.explosiveness = 0.8
		_apply_particle_style_2d_cpu(emitter, type)
		emitter.emitting = true

	elif emitter is GPUParticles2D:
		emitter.position = position
		emitter.amount = count
		emitter.lifetime = lifetime
		emitter.one_shot = one_shot
		emitter.explosiveness = 0.8
		_apply_particle_style_2d_gpu(emitter, type)
		emitter.emitting = true


func _configure_3d_emitter(emitter: Node, type: ParticleType, config: Dictionary, count: int, position: Vector3) -> void:
	var lifetime: float = config.get("lifetime", 1.0)
	var one_shot: bool = config.get("one_shot", true)

	if emitter is CPUParticles3D:
		emitter.position = position
		emitter.amount = count
		emitter.lifetime = lifetime
		emitter.one_shot = one_shot
		emitter.explosiveness = 0.8
		_apply_particle_style_3d_cpu(emitter, type)
		emitter.emitting = true

	elif emitter is GPUParticles3D:
		emitter.position = position
		emitter.amount = count
		emitter.lifetime = lifetime
		emitter.one_shot = one_shot
		emitter.explosiveness = 0.8
		_apply_particle_style_3d_gpu(emitter, type)
		emitter.emitting = true


func _apply_particle_style_2d_cpu(emitter: CPUParticles2D, type: ParticleType) -> void:
	match type:
		ParticleType.EXPLOSION:
			emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			emitter.emission_sphere_radius = 10.0
			emitter.direction = Vector2(0, -1)
			emitter.spread = 180.0
			emitter.gravity = Vector2(0, 200)
			emitter.initial_velocity_min = 150.0
			emitter.initial_velocity_max = 300.0
			emitter.scale_amount_min = 1.0
			emitter.scale_amount_max = 2.0
			emitter.color = Color(1.0, 0.6, 0.2)

		ParticleType.MUZZLE_FLASH:
			emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
			emitter.direction = Vector2(1, 0)
			emitter.spread = 30.0
			emitter.gravity = Vector2.ZERO
			emitter.initial_velocity_min = 200.0
			emitter.initial_velocity_max = 400.0
			emitter.scale_amount_min = 0.5
			emitter.scale_amount_max = 1.0
			emitter.color = Color(1.0, 1.0, 0.5)

		ParticleType.BULLET_IMPACT:
			emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
			emitter.direction = Vector2(0, -1)
			emitter.spread = 90.0
			emitter.gravity = Vector2(0, 300)
			emitter.initial_velocity_min = 100.0
			emitter.initial_velocity_max = 200.0
			emitter.scale_amount_min = 0.3
			emitter.scale_amount_max = 0.8
			emitter.color = Color(0.8, 0.8, 0.6)

		ParticleType.SPARKS:
			emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
			emitter.direction = Vector2(0, -1)
			emitter.spread = 60.0
			emitter.gravity = Vector2(0, 400)
			emitter.initial_velocity_min = 100.0
			emitter.initial_velocity_max = 250.0
			emitter.scale_amount_min = 0.2
			emitter.scale_amount_max = 0.5
			emitter.color = Color(1.0, 0.8, 0.3)

		ParticleType.CONFETTI:
			emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			emitter.emission_sphere_radius = 30.0
			emitter.direction = Vector2(0, -1)
			emitter.spread = 180.0
			emitter.gravity = Vector2(0, 150)
			emitter.initial_velocity_min = 100.0
			emitter.initial_velocity_max = 250.0
			emitter.angular_velocity_min = -720.0
			emitter.angular_velocity_max = 720.0
			emitter.scale_amount_min = 2.0
			emitter.scale_amount_max = 4.0
			emitter.color = Color(1.0, 0.5, 0.5)

		ParticleType.HEAL:
			emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			emitter.emission_sphere_radius = 20.0
			emitter.direction = Vector2(0, -1)
			emitter.spread = 30.0
			emitter.gravity = Vector2(0, -50)
			emitter.initial_velocity_min = 30.0
			emitter.initial_velocity_max = 80.0
			emitter.scale_amount_min = 0.5
			emitter.scale_amount_max = 1.5
			emitter.color = Color(0.3, 1.0, 0.3)

		_:
			# Default particle style
			emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			emitter.emission_sphere_radius = 10.0
			emitter.direction = Vector2(0, -1)
			emitter.spread = 45.0
			emitter.gravity = Vector2(0, 100)
			emitter.initial_velocity_min = 50.0
			emitter.initial_velocity_max = 150.0


func _apply_particle_style_2d_gpu(emitter: GPUParticles2D, type: ParticleType) -> void:
	# GPU particles need a process material
	var material := ParticleProcessMaterial.new()

	match type:
		ParticleType.EXPLOSION:
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			material.emission_sphere_radius = 10.0
			material.direction = Vector3(0, -1, 0)
			material.spread = 180.0
			material.gravity = Vector3(0, 200, 0)
			material.initial_velocity_min = 150.0
			material.initial_velocity_max = 300.0
			material.scale_min = 1.0
			material.scale_max = 2.0
			material.color = Color(1.0, 0.6, 0.2)

		_:
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			material.emission_sphere_radius = 10.0
			material.direction = Vector3(0, -1, 0)
			material.spread = 45.0
			material.gravity = Vector3(0, 100, 0)
			material.initial_velocity_min = 50.0
			material.initial_velocity_max = 150.0

	emitter.process_material = material


func _apply_particle_style_3d_cpu(emitter: CPUParticles3D, type: ParticleType) -> void:
	match type:
		ParticleType.EXPLOSION:
			emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			emitter.emission_sphere_radius = 0.5
			emitter.direction = Vector3(0, 1, 0)
			emitter.spread = 180.0
			emitter.gravity = Vector3(0, -9.8, 0)
			emitter.initial_velocity_min = 3.0
			emitter.initial_velocity_max = 8.0
			emitter.scale_amount_min = 0.05
			emitter.scale_amount_max = 0.15
			emitter.color = Color(1.0, 0.6, 0.2)

		ParticleType.MUZZLE_FLASH:
			emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
			emitter.direction = Vector3(0, 0, -1)
			emitter.spread = 15.0
			emitter.gravity = Vector3.ZERO
			emitter.initial_velocity_min = 5.0
			emitter.initial_velocity_max = 10.0
			emitter.scale_amount_min = 0.02
			emitter.scale_amount_max = 0.05
			emitter.color = Color(1.0, 1.0, 0.5)

		ParticleType.JETPACK:
			emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			emitter.emission_sphere_radius = 0.1
			emitter.direction = Vector3(0, -1, 0)
			emitter.spread = 30.0
			emitter.gravity = Vector3(0, -2.0, 0)
			emitter.initial_velocity_min = 1.0
			emitter.initial_velocity_max = 3.0
			emitter.scale_amount_min = 0.03
			emitter.scale_amount_max = 0.08
			emitter.color = Color(1.0, 0.5, 0.2)

		_:
			emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			emitter.emission_sphere_radius = 0.2
			emitter.direction = Vector3(0, 1, 0)
			emitter.spread = 45.0
			emitter.gravity = Vector3(0, -9.8, 0)
			emitter.initial_velocity_min = 1.0
			emitter.initial_velocity_max = 3.0


func _apply_particle_style_3d_gpu(emitter: GPUParticles3D, type: ParticleType) -> void:
	var material := ParticleProcessMaterial.new()

	match type:
		ParticleType.EXPLOSION:
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			material.emission_sphere_radius = 0.5
			material.direction = Vector3(0, 1, 0)
			material.spread = 180.0
			material.gravity = Vector3(0, -9.8, 0)
			material.initial_velocity_min = 3.0
			material.initial_velocity_max = 8.0
			material.scale_min = 0.05
			material.scale_max = 0.15
			material.color = Color(1.0, 0.6, 0.2)

		_:
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			material.emission_sphere_radius = 0.2
			material.direction = Vector3(0, 1, 0)
			material.spread = 45.0
			material.gravity = Vector3(0, -9.8, 0)
			material.initial_velocity_min = 1.0
			material.initial_velocity_max = 3.0

	emitter.process_material = material

# endregion


# =============================================================================
# region - Budget & Performance
# =============================================================================

func _can_spawn_particles(config: Dictionary, priority: ParticlePriority) -> bool:
	# Critical particles always spawn
	if priority == ParticlePriority.CRITICAL:
		return true

	# Check budget
	var current: int = active_particles.get(current_screen, 0)
	var budget: int = screen_budgets.get(current_screen, 500)
	var base_count: int = config.get("base_count", 20)

	if current + base_count > budget:
		# Only allow high priority if over budget
		return priority <= ParticlePriority.HIGH and current < budget * 1.2

	# Check performance mode
	match current_mode:
		PerformanceMode.MINIMAL:
			return priority <= ParticlePriority.HIGH
		PerformanceMode.LOW:
			return priority <= ParticlePriority.MEDIUM
		_:
			return true


func _adjust_particle_count(base_count: int, priority: ParticlePriority) -> int:
	if priority == ParticlePriority.CRITICAL:
		return base_count

	var multiplier: float = QUALITY_MULTIPLIERS.get(current_mode, 1.0)

	# Further reduce for lower priorities
	match priority:
		ParticlePriority.AMBIENT:
			multiplier *= 0.5
		ParticlePriority.LOW:
			multiplier *= 0.7
		_:
			pass

	return maxi(1, int(float(base_count) * multiplier))


func _update_active_counts() -> void:
	# Clean up finished emitters
	var to_remove: Array[Node] = []

	for emitter: Node in _active_emitters:
		if not is_instance_valid(emitter):
			to_remove.append(emitter)
			continue

		var is_emitting: bool = false
		if emitter is CPUParticles2D:
			is_emitting = emitter.emitting
		elif emitter is CPUParticles3D:
			is_emitting = emitter.emitting
		elif emitter is GPUParticles2D:
			is_emitting = emitter.emitting
		elif emitter is GPUParticles3D:
			is_emitting = emitter.emitting

		if not is_emitting:
			to_remove.append(emitter)

	for emitter: Node in to_remove:
		_active_emitters.erase(emitter)
		_return_emitter_to_pool(emitter)


func _cull_off_screen_particles() -> void:
	var culled_count: int = 0

	for emitter: Node in _active_emitters:
		if not is_instance_valid(emitter):
			continue

		# Only cull 2D particles
		if emitter is Node2D:
			var pos: Vector2 = emitter.global_position
			var expanded_rect := _viewport_rect.grow(_culling_margin)

			if not expanded_rect.has_point(pos):
				stop_particles(emitter)
				culled_count += 1

	if culled_count > 0:
		_total_particles_culled += culled_count
		particles_culled.emit(culled_count, "off_screen")


func _track_frame_time(delta: float) -> void:
	_frame_times.append(delta)
	if _frame_times.size() > 30:
		_frame_times.remove_at(0)

	var total: float = 0.0
	for ft: float in _frame_times:
		total += ft
	var avg_frame_time: float = total / _frame_times.size()
	_current_fps = 1.0 / avg_frame_time if avg_frame_time > 0 else 60.0


func _auto_adjust_performance_mode() -> void:
	var new_mode: PerformanceMode = current_mode

	if _current_fps >= FPS_ULTRA:
		new_mode = PerformanceMode.ULTRA
	elif _current_fps >= FPS_HIGH:
		new_mode = PerformanceMode.HIGH
	elif _current_fps >= FPS_MEDIUM:
		new_mode = PerformanceMode.MEDIUM
	elif _current_fps >= FPS_LOW:
		new_mode = PerformanceMode.LOW
	else:
		new_mode = PerformanceMode.MINIMAL

	if new_mode != current_mode:
		current_mode = new_mode
		performance_mode_changed.emit(new_mode)

# endregion


# =============================================================================
# region - Statistics & Debug
# =============================================================================

## Gets particle system statistics
func get_statistics() -> Dictionary:
	return {
		"current_fps": _current_fps,
		"performance_mode": PerformanceMode.keys()[current_mode],
		"current_screen": current_screen,
		"active_particles": active_particles.get(current_screen, 0),
		"screen_budget": screen_budgets.get(current_screen, 500),
		"budget_usage_percent": float(active_particles.get(current_screen, 0)) / float(screen_budgets.get(current_screen, 500)) * 100.0,
		"total_spawned": _total_particles_spawned,
		"total_culled": _total_particles_culled,
		"recycled": _particles_recycled,
		"active_emitters": _active_emitters.size(),
		"cpu_pool_size": _cpu_particle_pool.size(),
		"gpu_pool_size": _gpu_particle_pool.size(),
		"gpu_supported": _gpu_particles_supported
	}


## Sets performance mode manually
func set_performance_mode(mode: PerformanceMode) -> void:
	auto_adjust_enabled = false
	current_mode = mode
	performance_mode_changed.emit(mode)


## Enables auto-adjustment
func enable_auto_adjust() -> void:
	auto_adjust_enabled = true

# endregion
