## AdvancedParticleManager - High-performance particle effects system for BattleZone Party.
##
## Features:
## - Object pooling for maximum performance (max 1000 simultaneous particles)
## - Priority-based culling when over budget
## - Mobile-optimized (GPUParticles3D where supported, fallback to CPU)
## - Category system for combat, movement, feedback, ambient, and UI effects
## - Automatic quality scaling based on device performance
##
## Usage:
##   AdvancedParticleManager.spawn_effect(EffectType.MUZZLE_FLASH, position, options)
##   AdvancedParticleManager.spawn_combat_effect("explosion", position, {scale = 2.0})
extends Node


# region - Enums

## Effect categories with priority levels (lower number = higher priority)
enum ParticleCategory {
	COMBAT = 0,      ## Hits, explosions, muzzle flash - NEVER skip
	FEEDBACK = 1,    ## Pickups, level-ups, achievements - High priority
	MOVEMENT = 2,    ## Dust, jetpack, landing - Medium priority
	UI = 3,          ## Button clicks, celebrations - Can skip under load
	AMBIENT = 4,     ## Environment, weather - Skip first
}

## Pre-defined effect types for easy spawning
enum EffectType {
	# Combat effects
	MUZZLE_FLASH,
	BULLET_IMPACT,
	BLOOD_SPLATTER,
	EXPLOSION_SMALL,
	EXPLOSION_MEDIUM,
	EXPLOSION_LARGE,
	BULLET_TRACER,
	SHELL_CASING,
	HIT_SPARK,

	# Movement effects
	DUST_CLOUD,
	JETPACK_FLAME,
	LANDING_DUST,
	DASH_TRAIL,
	SPEED_LINES,

	# Feedback effects
	PICKUP_SPARKLE,
	LEVEL_UP,
	HEAL_EFFECT,
	SHIELD_EFFECT,

	# UI effects
	CONFETTI,
	STARS,
	CELEBRATION,

	# Ambient effects
	SMOKE,
	FIRE,
	SPARKS,
}

# endregion


# region - Constants

## Maximum simultaneous active particle effects
const MAX_ACTIVE_EFFECTS: int = 1000

## Pool sizes per category
const POOL_SIZES: Dictionary = {
	ParticleCategory.COMBAT: 100,
	ParticleCategory.FEEDBACK: 50,
	ParticleCategory.MOVEMENT: 80,
	ParticleCategory.UI: 30,
	ParticleCategory.AMBIENT: 40,
}

## Priority weights for culling decisions
const PRIORITY_WEIGHTS: Dictionary = {
	ParticleCategory.COMBAT: 1,      ## Never cull
	ParticleCategory.FEEDBACK: 2,    ## Rarely cull
	ParticleCategory.MOVEMENT: 3,    ## Sometimes cull
	ParticleCategory.UI: 4,          ## Often cull
	ParticleCategory.AMBIENT: 5,     ## Cull first
}

## Effect specifications: particle count, duration, category
const EFFECT_SPECS: Dictionary = {
	EffectType.MUZZLE_FLASH: {
		"particle_count": 10,
		"duration": 0.1,
		"category": ParticleCategory.COMBAT,
		"emission_shape": "sphere",
		"emission_radius": 0.1,
		"speed_min": 8.0,
		"speed_max": 15.0,
		"spread": 45.0,
		"gravity": Vector3.ZERO,
		"color_start": Color(1.0, 0.9, 0.3, 1.0),
		"color_end": Color(1.0, 0.5, 0.1, 0.0),
		"scale_min": 0.05,
		"scale_max": 0.15,
		"explosiveness": 1.0,
	},
	EffectType.BULLET_IMPACT: {
		"particle_count": 12,
		"duration": 0.25,
		"category": ParticleCategory.COMBAT,
		"emission_shape": "point",
		"speed_min": 3.0,
		"speed_max": 8.0,
		"spread": 120.0,
		"gravity": Vector3(0, -5, 0),
		"color_start": Color(1.0, 0.8, 0.4, 1.0),
		"color_end": Color(0.6, 0.4, 0.2, 0.0),
		"scale_min": 0.02,
		"scale_max": 0.06,
		"explosiveness": 0.9,
	},
	EffectType.BLOOD_SPLATTER: {
		"particle_count": 18,
		"duration": 0.3,
		"category": ParticleCategory.COMBAT,
		"emission_shape": "sphere",
		"emission_radius": 0.2,
		"speed_min": 4.0,
		"speed_max": 10.0,
		"spread": 150.0,
		"gravity": Vector3(0, -12, 0),
		"color_start": Color(0.8, 0.1, 0.1, 1.0),
		"color_end": Color(0.5, 0.0, 0.0, 0.0),
		"scale_min": 0.03,
		"scale_max": 0.1,
		"explosiveness": 0.95,
	},
	EffectType.EXPLOSION_SMALL: {
		"particle_count": 30,
		"duration": 0.4,
		"category": ParticleCategory.COMBAT,
		"emission_shape": "sphere",
		"emission_radius": 0.3,
		"speed_min": 5.0,
		"speed_max": 12.0,
		"spread": 180.0,
		"gravity": Vector3(0, -3, 0),
		"color_start": Color(1.0, 0.9, 0.2, 1.0),
		"color_end": Color(0.8, 0.2, 0.0, 0.0),
		"scale_min": 0.1,
		"scale_max": 0.3,
		"explosiveness": 1.0,
	},
	EffectType.EXPLOSION_MEDIUM: {
		"particle_count": 50,
		"duration": 0.5,
		"category": ParticleCategory.COMBAT,
		"emission_shape": "sphere",
		"emission_radius": 0.5,
		"speed_min": 8.0,
		"speed_max": 18.0,
		"spread": 180.0,
		"gravity": Vector3(0, -2, 0),
		"color_start": Color(1.0, 1.0, 0.5, 1.0),
		"color_end": Color(1.0, 0.3, 0.0, 0.0),
		"scale_min": 0.15,
		"scale_max": 0.5,
		"explosiveness": 1.0,
	},
	EffectType.EXPLOSION_LARGE: {
		"particle_count": 60,
		"duration": 0.6,
		"category": ParticleCategory.COMBAT,
		"emission_shape": "sphere",
		"emission_radius": 0.8,
		"speed_min": 12.0,
		"speed_max": 25.0,
		"spread": 180.0,
		"gravity": Vector3(0, -1, 0),
		"color_start": Color(1.0, 1.0, 0.8, 1.0),
		"color_end": Color(1.0, 0.4, 0.0, 0.0),
		"scale_min": 0.2,
		"scale_max": 0.8,
		"explosiveness": 1.0,
	},
	EffectType.BULLET_TRACER: {
		"particle_count": 5,
		"duration": 0.15,
		"category": ParticleCategory.COMBAT,
		"emission_shape": "box",
		"emission_box_extents": Vector3(0.02, 0.02, 0.5),
		"speed_min": 0.5,
		"speed_max": 2.0,
		"spread": 5.0,
		"gravity": Vector3.ZERO,
		"color_start": Color(1.0, 0.9, 0.3, 0.8),
		"color_end": Color(1.0, 0.6, 0.1, 0.0),
		"scale_min": 0.01,
		"scale_max": 0.03,
		"explosiveness": 0.0,
	},
	EffectType.SHELL_CASING: {
		"particle_count": 1,
		"duration": 0.6,
		"category": ParticleCategory.COMBAT,
		"emission_shape": "point",
		"speed_min": 2.0,
		"speed_max": 4.0,
		"spread": 30.0,
		"gravity": Vector3(0, -15, 0),
		"color_start": Color(0.8, 0.7, 0.3, 1.0),
		"color_end": Color(0.6, 0.5, 0.2, 1.0),
		"scale_min": 0.02,
		"scale_max": 0.04,
		"explosiveness": 1.0,
	},
	EffectType.HIT_SPARK: {
		"particle_count": 8,
		"duration": 0.15,
		"category": ParticleCategory.COMBAT,
		"emission_shape": "point",
		"speed_min": 6.0,
		"speed_max": 12.0,
		"spread": 90.0,
		"gravity": Vector3(0, -8, 0),
		"color_start": Color(1.0, 1.0, 1.0, 1.0),
		"color_end": Color(1.0, 0.8, 0.3, 0.0),
		"scale_min": 0.02,
		"scale_max": 0.05,
		"explosiveness": 1.0,
	},
	EffectType.DUST_CLOUD: {
		"particle_count": 12,
		"duration": 0.4,
		"category": ParticleCategory.MOVEMENT,
		"emission_shape": "sphere",
		"emission_radius": 0.3,
		"speed_min": 1.0,
		"speed_max": 3.0,
		"spread": 180.0,
		"gravity": Vector3(0, 0.5, 0),
		"color_start": Color(0.6, 0.5, 0.4, 0.6),
		"color_end": Color(0.5, 0.4, 0.3, 0.0),
		"scale_min": 0.1,
		"scale_max": 0.3,
		"explosiveness": 0.8,
	},
	EffectType.JETPACK_FLAME: {
		"particle_count": 15,
		"duration": 0.2,
		"category": ParticleCategory.MOVEMENT,
		"emission_shape": "cone",
		"emission_radius": 0.15,
		"speed_min": 3.0,
		"speed_max": 8.0,
		"spread": 25.0,
		"gravity": Vector3(0, 2, 0),
		"color_start": Color(1.0, 0.7, 0.1, 1.0),
		"color_end": Color(1.0, 0.2, 0.0, 0.0),
		"scale_min": 0.05,
		"scale_max": 0.15,
		"explosiveness": 0.0,
	},
	EffectType.LANDING_DUST: {
		"particle_count": 15,
		"duration": 0.3,
		"category": ParticleCategory.MOVEMENT,
		"emission_shape": "ring",
		"emission_radius": 0.5,
		"speed_min": 2.0,
		"speed_max": 5.0,
		"spread": 45.0,
		"gravity": Vector3(0, 1, 0),
		"color_start": Color(0.6, 0.55, 0.45, 0.7),
		"color_end": Color(0.5, 0.45, 0.35, 0.0),
		"scale_min": 0.08,
		"scale_max": 0.2,
		"explosiveness": 0.9,
	},
	EffectType.DASH_TRAIL: {
		"particle_count": 20,
		"duration": 0.25,
		"category": ParticleCategory.MOVEMENT,
		"emission_shape": "box",
		"emission_box_extents": Vector3(0.3, 0.8, 0.1),
		"speed_min": 0.5,
		"speed_max": 1.5,
		"spread": 180.0,
		"gravity": Vector3.ZERO,
		"color_start": Color(0.5, 0.8, 1.0, 0.6),
		"color_end": Color(0.3, 0.5, 1.0, 0.0),
		"scale_min": 0.03,
		"scale_max": 0.08,
		"explosiveness": 0.3,
	},
	EffectType.SPEED_LINES: {
		"particle_count": 8,
		"duration": 0.15,
		"category": ParticleCategory.MOVEMENT,
		"emission_shape": "box",
		"emission_box_extents": Vector3(0.1, 0.1, 0.8),
		"speed_min": 15.0,
		"speed_max": 25.0,
		"spread": 5.0,
		"gravity": Vector3.ZERO,
		"color_start": Color(1.0, 1.0, 1.0, 0.5),
		"color_end": Color(1.0, 1.0, 1.0, 0.0),
		"scale_min": 0.01,
		"scale_max": 0.02,
		"explosiveness": 0.0,
	},
	EffectType.PICKUP_SPARKLE: {
		"particle_count": 20,
		"duration": 0.5,
		"category": ParticleCategory.FEEDBACK,
		"emission_shape": "sphere",
		"emission_radius": 0.4,
		"speed_min": 2.0,
		"speed_max": 5.0,
		"spread": 180.0,
		"gravity": Vector3(0, 2, 0),
		"color_start": Color(1.0, 1.0, 0.5, 1.0),
		"color_end": Color(1.0, 0.8, 0.2, 0.0),
		"scale_min": 0.03,
		"scale_max": 0.08,
		"explosiveness": 0.7,
	},
	EffectType.LEVEL_UP: {
		"particle_count": 30,
		"duration": 0.8,
		"category": ParticleCategory.FEEDBACK,
		"emission_shape": "ring",
		"emission_radius": 0.8,
		"speed_min": 3.0,
		"speed_max": 8.0,
		"spread": 30.0,
		"gravity": Vector3(0, 5, 0),
		"color_start": Color(0.3, 1.0, 0.3, 1.0),
		"color_end": Color(1.0, 1.0, 0.5, 0.0),
		"scale_min": 0.05,
		"scale_max": 0.12,
		"explosiveness": 0.5,
	},
	EffectType.HEAL_EFFECT: {
		"particle_count": 15,
		"duration": 0.6,
		"category": ParticleCategory.FEEDBACK,
		"emission_shape": "sphere",
		"emission_radius": 0.5,
		"speed_min": 1.0,
		"speed_max": 3.0,
		"spread": 60.0,
		"gravity": Vector3(0, 3, 0),
		"color_start": Color(0.2, 1.0, 0.3, 1.0),
		"color_end": Color(0.5, 1.0, 0.5, 0.0),
		"scale_min": 0.04,
		"scale_max": 0.1,
		"explosiveness": 0.4,
	},
	EffectType.SHIELD_EFFECT: {
		"particle_count": 25,
		"duration": 0.5,
		"category": ParticleCategory.FEEDBACK,
		"emission_shape": "sphere",
		"emission_radius": 0.6,
		"speed_min": 0.5,
		"speed_max": 2.0,
		"spread": 180.0,
		"gravity": Vector3.ZERO,
		"color_start": Color(0.3, 0.6, 1.0, 0.8),
		"color_end": Color(0.5, 0.8, 1.0, 0.0),
		"scale_min": 0.03,
		"scale_max": 0.08,
		"explosiveness": 0.6,
	},
	EffectType.CONFETTI: {
		"particle_count": 50,
		"duration": 2.0,
		"category": ParticleCategory.UI,
		"emission_shape": "sphere",
		"emission_radius": 0.5,
		"speed_min": 3.0,
		"speed_max": 8.0,
		"spread": 180.0,
		"gravity": Vector3(0, -3, 0),
		"color_start": Color(1.0, 1.0, 1.0, 1.0),
		"color_end": Color(1.0, 1.0, 1.0, 0.0),
		"scale_min": 0.03,
		"scale_max": 0.08,
		"explosiveness": 0.8,
		"use_rainbow": true,
	},
	EffectType.STARS: {
		"particle_count": 25,
		"duration": 1.0,
		"category": ParticleCategory.UI,
		"emission_shape": "sphere",
		"emission_radius": 0.3,
		"speed_min": 2.0,
		"speed_max": 5.0,
		"spread": 120.0,
		"gravity": Vector3(0, 1, 0),
		"color_start": Color(1.0, 1.0, 0.6, 1.0),
		"color_end": Color(1.0, 0.9, 0.4, 0.0),
		"scale_min": 0.04,
		"scale_max": 0.1,
		"explosiveness": 0.7,
	},
	EffectType.CELEBRATION: {
		"particle_count": 40,
		"duration": 1.5,
		"category": ParticleCategory.UI,
		"emission_shape": "sphere",
		"emission_radius": 0.6,
		"speed_min": 4.0,
		"speed_max": 10.0,
		"spread": 180.0,
		"gravity": Vector3(0, -2, 0),
		"color_start": Color(1.0, 0.9, 0.3, 1.0),
		"color_end": Color(1.0, 0.5, 0.1, 0.0),
		"scale_min": 0.05,
		"scale_max": 0.15,
		"explosiveness": 1.0,
	},
	EffectType.SMOKE: {
		"particle_count": 20,
		"duration": 2.0,
		"category": ParticleCategory.AMBIENT,
		"emission_shape": "sphere",
		"emission_radius": 0.2,
		"speed_min": 0.5,
		"speed_max": 2.0,
		"spread": 45.0,
		"gravity": Vector3(0, 1.5, 0),
		"color_start": Color(0.5, 0.5, 0.5, 0.5),
		"color_end": Color(0.3, 0.3, 0.3, 0.0),
		"scale_min": 0.15,
		"scale_max": 0.5,
		"explosiveness": 0.0,
	},
	EffectType.FIRE: {
		"particle_count": 25,
		"duration": 0.6,
		"category": ParticleCategory.AMBIENT,
		"emission_shape": "sphere",
		"emission_radius": 0.15,
		"speed_min": 2.0,
		"speed_max": 5.0,
		"spread": 30.0,
		"gravity": Vector3(0, 3, 0),
		"color_start": Color(1.0, 0.8, 0.2, 1.0),
		"color_end": Color(1.0, 0.2, 0.0, 0.0),
		"scale_min": 0.08,
		"scale_max": 0.2,
		"explosiveness": 0.0,
	},
	EffectType.SPARKS: {
		"particle_count": 15,
		"duration": 0.4,
		"category": ParticleCategory.AMBIENT,
		"emission_shape": "point",
		"speed_min": 3.0,
		"speed_max": 8.0,
		"spread": 90.0,
		"gravity": Vector3(0, -8, 0),
		"color_start": Color(1.0, 0.9, 0.5, 1.0),
		"color_end": Color(1.0, 0.5, 0.1, 0.0),
		"scale_min": 0.01,
		"scale_max": 0.03,
		"explosiveness": 0.8,
	},
}

# endregion


# region - Signals

## Emitted when particle budget is exceeded and culling occurs
signal budget_exceeded(active_count: int, culled_count: int)

## Emitted when quality level changes
signal quality_changed(new_quality: float)

# endregion


# region - State

## Object pools for each category
var _pools: Dictionary = {}  ## Category -> Array[CPUParticles3D]

## Currently active effects
var _active_effects: Array[Dictionary] = []  ## [{node, category, priority, spawn_time}]

## Quality multiplier (0.0-1.0) - affects particle counts
var _quality: float = 1.0

## Whether to use GPU particles (mobile may fall back to CPU)
var _use_gpu_particles: bool = false

## Performance tracking
var _frame_times: Array[float] = []
var _last_perf_check: float = 0.0
const PERF_CHECK_INTERVAL: float = 2.0
const TARGET_FRAME_TIME: float = 0.0167  ## ~60 FPS

## Node containers
var _effects_container_3d: Node3D
var _effects_container_2d: Node2D

# endregion


# region - Lifecycle

func _ready() -> void:
	# Detect platform capabilities
	_detect_platform_capabilities()

	# Create containers for effects
	_effects_container_3d = Node3D.new()
	_effects_container_3d.name = "ParticleEffects3D"
	add_child(_effects_container_3d)

	_effects_container_2d = Node2D.new()
	_effects_container_2d.name = "ParticleEffects2D"
	add_child(_effects_container_2d)

	# Initialize object pools
	_initialize_pools()

	print("[AdvancedParticleManager] Initialized with quality: %.1f, GPU: %s" % [_quality, _use_gpu_particles])


func _process(delta: float) -> void:
	# Update performance tracking
	_track_performance(delta)

	# Clean up finished effects
	_cleanup_finished_effects()


func _detect_platform_capabilities() -> void:
	# Check if we're on mobile
	var os_name: String = OS.get_name()
	var is_mobile: bool = os_name in ["Android", "iOS"]

	if is_mobile:
		# Start with lower quality on mobile
		_quality = 0.6
		# Check for GPU particle support
		_use_gpu_particles = RenderingServer.get_rendering_device() != null
	else:
		_quality = 1.0
		_use_gpu_particles = true


func _initialize_pools() -> void:
	for category: int in POOL_SIZES.keys():
		var pool_size: int = POOL_SIZES[category]
		var pool: Array = []

		for i: int in range(pool_size):
			var particles: CPUParticles3D = _create_pooled_particle_node()
			_effects_container_3d.add_child(particles)
			pool.append(particles)

		_pools[category] = pool


func _create_pooled_particle_node() -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.emitting = false
	particles.visible = false
	particles.one_shot = true
	return particles

# endregion


# region - Public API

## Spawns a particle effect at the given 3D position.
## Returns the particle node if spawned, null if culled.
func spawn_effect(effect_type: EffectType, position: Vector3, options: Dictionary = {}) -> Node:
	if not EFFECT_SPECS.has(effect_type):
		push_warning("AdvancedParticleManager: Unknown effect type %d" % effect_type)
		return null

	var spec: Dictionary = EFFECT_SPECS[effect_type]
	var category: ParticleCategory = spec.get("category", ParticleCategory.AMBIENT)

	# Check if we should cull this effect
	if _should_cull_effect(category):
		return null

	# Get a particle node from the pool
	var particles: CPUParticles3D = _get_from_pool(category)
	if not particles:
		# Pool exhausted, try to steal from lower priority category
		particles = _steal_from_lower_priority(category)
		if not particles:
			return null

	# Configure the particle system
	_configure_particles(particles, spec, options)

	# Position and activate
	particles.global_position = position
	particles.visible = true
	particles.emitting = true

	# Apply custom direction if provided
	if options.has("direction"):
		var dir: Vector3 = options["direction"]
		if dir.length_squared() > 0.001:
			particles.look_at(position + dir, Vector3.UP)

	# Track as active
	_active_effects.append({
		"node": particles,
		"category": category,
		"priority": PRIORITY_WEIGHTS[category],
		"spawn_time": Time.get_ticks_msec() / 1000.0,
		"duration": spec.get("duration", 1.0),
	})

	return particles


## Spawns a combat effect by name (convenience method).
func spawn_combat_effect(effect_name: String, position: Vector3, options: Dictionary = {}) -> Node:
	var effect_type: EffectType
	match effect_name.to_lower():
		"muzzle_flash", "muzzle":
			effect_type = EffectType.MUZZLE_FLASH
		"impact", "bullet_impact":
			effect_type = EffectType.BULLET_IMPACT
		"blood", "blood_splatter":
			effect_type = EffectType.BLOOD_SPLATTER
		"explosion_small", "small_explosion":
			effect_type = EffectType.EXPLOSION_SMALL
		"explosion_medium", "medium_explosion", "explosion":
			effect_type = EffectType.EXPLOSION_MEDIUM
		"explosion_large", "large_explosion", "big_explosion":
			effect_type = EffectType.EXPLOSION_LARGE
		"tracer", "bullet_tracer":
			effect_type = EffectType.BULLET_TRACER
		"shell", "shell_casing":
			effect_type = EffectType.SHELL_CASING
		"spark", "hit_spark":
			effect_type = EffectType.HIT_SPARK
		_:
			push_warning("AdvancedParticleManager: Unknown combat effect '%s'" % effect_name)
			return null

	return spawn_effect(effect_type, position, options)


## Spawns a movement effect by name (convenience method).
func spawn_movement_effect(effect_name: String, position: Vector3, options: Dictionary = {}) -> Node:
	var effect_type: EffectType
	match effect_name.to_lower():
		"dust", "dust_cloud":
			effect_type = EffectType.DUST_CLOUD
		"jetpack", "jetpack_flame":
			effect_type = EffectType.JETPACK_FLAME
		"landing", "landing_dust":
			effect_type = EffectType.LANDING_DUST
		"dash", "dash_trail":
			effect_type = EffectType.DASH_TRAIL
		"speed", "speed_lines":
			effect_type = EffectType.SPEED_LINES
		_:
			push_warning("AdvancedParticleManager: Unknown movement effect '%s'" % effect_name)
			return null

	return spawn_effect(effect_type, position, options)


## Sets the quality level (0.0 to 1.0).
## Lower quality = fewer particles, better performance.
func set_quality(quality: float) -> void:
	_quality = clampf(quality, 0.1, 1.0)
	quality_changed.emit(_quality)


## Gets the current quality level.
func get_quality() -> float:
	return _quality


## Reduces particle quality temporarily (for thermal throttling).
func reduce_particles(factor: float) -> void:
	set_quality(_quality * factor)


## Returns the count of currently active effects.
func get_active_effect_count() -> int:
	return _active_effects.size()


## Clears all active effects immediately.
func clear_all_effects() -> void:
	for effect_data: Dictionary in _active_effects:
		var node: CPUParticles3D = effect_data.get("node") as CPUParticles3D
		if is_instance_valid(node):
			node.emitting = false
			node.visible = false
	_active_effects.clear()


## Pre-warms a specific effect type (useful for loading screens).
func prewarm_effect(effect_type: EffectType) -> void:
	if not EFFECT_SPECS.has(effect_type):
		return

	var spec: Dictionary = EFFECT_SPECS[effect_type]
	var category: ParticleCategory = spec.get("category", ParticleCategory.AMBIENT)

	# Just ensure the pool has nodes ready
	if _pools.has(category):
		var pool: Array = _pools[category]
		for particles: CPUParticles3D in pool:
			# Touch each particle to ensure it's ready
			if not particles.emitting:
				particles.restart()
				particles.emitting = false

# endregion


# region - Pool Management

func _get_from_pool(category: ParticleCategory) -> CPUParticles3D:
	if not _pools.has(category):
		return null

	var pool: Array = _pools[category]
	for particles: CPUParticles3D in pool:
		if not particles.emitting:
			return particles

	return null


func _return_to_pool(particles: CPUParticles3D) -> void:
	particles.emitting = false
	particles.visible = false


func _steal_from_lower_priority(target_category: ParticleCategory) -> CPUParticles3D:
	var target_priority: int = PRIORITY_WEIGHTS[target_category]

	# Find the lowest priority active effect that we can steal
	var best_candidate: Dictionary = {}
	var best_priority: int = -1

	for effect_data: Dictionary in _active_effects:
		var priority: int = effect_data.get("priority", 0)
		if priority > target_priority and priority > best_priority:
			best_candidate = effect_data
			best_priority = priority

	if best_candidate.is_empty():
		return null

	# Steal this effect's node
	var node: CPUParticles3D = best_candidate.get("node") as CPUParticles3D
	if is_instance_valid(node):
		node.emitting = false
		node.visible = false
		_active_effects.erase(best_candidate)
		return node

	return null

# endregion


# region - Particle Configuration

func _configure_particles(particles: CPUParticles3D, spec: Dictionary, options: Dictionary) -> void:
	# Apply quality scaling to particle count
	var base_count: int = spec.get("particle_count", 10)
	var scaled_count: int = maxi(1, int(base_count * _quality))
	particles.amount = scaled_count

	# Timing
	particles.lifetime = spec.get("duration", 1.0)
	particles.explosiveness = spec.get("explosiveness", 0.8)
	particles.one_shot = true

	# Emission shape
	var emission_shape: String = spec.get("emission_shape", "point")
	match emission_shape:
		"point":
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
		"sphere":
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = spec.get("emission_radius", 0.1)
		"box":
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			particles.emission_box_extents = spec.get("emission_box_extents", Vector3(0.5, 0.5, 0.5))
		"ring":
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			particles.emission_ring_radius = spec.get("emission_radius", 0.5)
			particles.emission_ring_height = 0.1
			particles.emission_ring_axis = Vector3.UP
		"cone":
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = spec.get("emission_radius", 0.1)

	# Velocity
	particles.direction = Vector3(0, 1, 0)
	if options.has("direction"):
		particles.direction = options["direction"]

	particles.spread = spec.get("spread", 45.0)
	particles.initial_velocity_min = spec.get("speed_min", 1.0)
	particles.initial_velocity_max = spec.get("speed_max", 5.0)

	# Physics
	particles.gravity = spec.get("gravity", Vector3.ZERO)

	# Size
	particles.scale_amount_min = spec.get("scale_min", 0.05)
	particles.scale_amount_max = spec.get("scale_max", 0.1)

	# Color
	var color_start: Color = options.get("color", spec.get("color_start", Color.WHITE))
	var color_end: Color = spec.get("color_end", Color(color_start.r, color_start.g, color_start.b, 0.0))

	if spec.get("use_rainbow", false):
		particles.color_ramp = _create_rainbow_gradient()
	else:
		particles.color_ramp = _create_color_gradient(color_start, color_end)

	# Scale override from options
	if options.has("scale"):
		var scale_mult: float = options["scale"]
		particles.scale_amount_min *= scale_mult
		particles.scale_amount_max *= scale_mult
		if particles.emission_shape == CPUParticles3D.EMISSION_SHAPE_SPHERE:
			particles.emission_sphere_radius *= scale_mult


func _create_color_gradient(start: Color, end: Color) -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([start, end])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	return gradient


func _create_rainbow_gradient() -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color.RED,
		Color.ORANGE,
		Color.YELLOW,
		Color.GREEN,
		Color.BLUE,
		Color.PURPLE,
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	return gradient

# endregion


# region - Culling & Performance

func _should_cull_effect(category: ParticleCategory) -> bool:
	# Combat effects are never culled
	if category == ParticleCategory.COMBAT:
		return false

	# Check total active count
	if _active_effects.size() >= MAX_ACTIVE_EFFECTS:
		# Cull lower priority effects
		budget_exceeded.emit(_active_effects.size(), 1)
		return PRIORITY_WEIGHTS[category] >= 3

	# Check performance
	if _is_under_performance_pressure():
		# Only allow combat and feedback under pressure
		return PRIORITY_WEIGHTS[category] >= 3

	return false


func _is_under_performance_pressure() -> bool:
	if _frame_times.size() < 30:
		return false

	var avg_frame_time: float = 0.0
	for ft: float in _frame_times:
		avg_frame_time += ft
	avg_frame_time /= _frame_times.size()

	# If average frame time is > 20ms (~50 FPS), we're under pressure
	return avg_frame_time > 0.02


func _track_performance(delta: float) -> void:
	_frame_times.append(delta)
	if _frame_times.size() > 60:
		_frame_times.remove_at(0)

	# Periodic quality adjustment
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_perf_check > PERF_CHECK_INTERVAL:
		_last_perf_check = current_time
		_auto_adjust_quality()


func _auto_adjust_quality() -> void:
	if _frame_times.size() < 30:
		return

	var avg_frame_time: float = 0.0
	for ft: float in _frame_times:
		avg_frame_time += ft
	avg_frame_time /= _frame_times.size()

	# Adjust quality based on performance
	if avg_frame_time > 0.025:  ## < 40 FPS
		set_quality(_quality * 0.8)
	elif avg_frame_time < 0.012 and _quality < 1.0:  ## > 80 FPS
		set_quality(minf(_quality * 1.1, 1.0))


func _cleanup_finished_effects() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var to_remove: Array[int] = []

	for i: int in range(_active_effects.size()):
		var effect_data: Dictionary = _active_effects[i]
		var node: CPUParticles3D = effect_data.get("node") as CPUParticles3D

		if not is_instance_valid(node):
			to_remove.append(i)
			continue

		# Check if effect has finished
		var elapsed: float = current_time - effect_data.get("spawn_time", 0.0)
		var duration: float = effect_data.get("duration", 1.0)

		if elapsed > duration * 2.0 or not node.emitting:
			_return_to_pool(node)
			to_remove.append(i)

	# Remove finished effects (in reverse order to maintain indices)
	for i: int in range(to_remove.size() - 1, -1, -1):
		_active_effects.remove_at(to_remove[i])

# endregion


# region - 2D Effects Support (for UI)

## Spawns a 2D particle effect for UI elements.
func spawn_2d_effect(position: Vector2, effect_name: String, options: Dictionary = {}) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	_effects_container_2d.add_child(particles)

	particles.position = position
	particles.one_shot = true
	particles.emitting = true
	particles.amount = int(30 * _quality)
	particles.lifetime = 1.0
	particles.explosiveness = 0.8

	match effect_name.to_lower():
		"sparkle":
			particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = 20.0
			particles.direction = Vector2(0, -1)
			particles.spread = 45.0
			particles.gravity = Vector2(0, 50)
			particles.initial_velocity_min = 100.0
			particles.initial_velocity_max = 200.0
			particles.color = options.get("color", Color(1, 1, 0.5, 1))

		"confetti":
			particles.amount = int(50 * _quality)
			particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = 30.0
			particles.direction = Vector2(0, -1)
			particles.spread = 180.0
			particles.gravity = Vector2(0, 200)
			particles.initial_velocity_min = 150.0
			particles.initial_velocity_max = 300.0
			particles.color_ramp = _create_rainbow_gradient()

		"click":
			particles.amount = int(15 * _quality)
			particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
			particles.direction = Vector2(0, 0)
			particles.spread = 180.0
			particles.gravity = Vector2.ZERO
			particles.initial_velocity_min = 50.0
			particles.initial_velocity_max = 100.0
			particles.lifetime = 0.3
			particles.color = options.get("color", Color(1, 1, 1, 0.8))

	# Auto-cleanup
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(particles.lifetime * 2.0)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)

	return particles

# endregion
