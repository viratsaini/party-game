## CombatParticles - Comprehensive combat VFX library for BattleZone Party.
##
## Provides high-level API for spawning combat-related particle effects including:
## - Muzzle flashes (8-12 particles, 0.1s)
## - Blood/impact effects (15-20 particles, 0.3s)
## - Explosions (40-60 particles, 0.5s)
## - Bullet tracers
## - Shell casings
## - Hit sparks and impact effects
##
## Usage:
##   CombatParticles.muzzle_flash(position, direction, color)
##   CombatParticles.explosion(position, size, damage_source)
##   CombatParticles.bullet_impact(position, normal, surface_type)
class_name CombatParticles
extends Node


# region - Signals

## Emitted when a major combat effect spawns (for audio/haptic sync)
signal combat_effect_spawned(effect_type: String, position: Vector3, intensity: float)

# endregion


# region - Constants

## Surface material types for impact effects
enum SurfaceType {
	METAL,
	CONCRETE,
	WOOD,
	FLESH,
	ENERGY,
	DEFAULT,
}

## Explosion sizes
enum ExplosionSize {
	SMALL,   ## Grenade, small blast
	MEDIUM,  ## Standard rocket
	LARGE,   ## Big explosion, vehicle destruction
}

## Impact effect colors by surface type
const SURFACE_COLORS: Dictionary = {
	SurfaceType.METAL: Color(1.0, 0.9, 0.5, 1.0),      ## Bright sparks
	SurfaceType.CONCRETE: Color(0.6, 0.55, 0.5, 1.0), ## Dust/debris
	SurfaceType.WOOD: Color(0.6, 0.4, 0.2, 1.0),      ## Brown splinters
	SurfaceType.FLESH: Color(0.8, 0.1, 0.1, 1.0),     ## Red blood
	SurfaceType.ENERGY: Color(0.3, 0.6, 1.0, 1.0),    ## Blue energy
	SurfaceType.DEFAULT: Color(1.0, 0.8, 0.4, 1.0),   ## Generic sparks
}

## Muzzle flash color presets
const MUZZLE_COLORS: Dictionary = {
	"standard": Color(1.0, 0.9, 0.3, 1.0),
	"plasma": Color(0.3, 0.8, 1.0, 1.0),
	"laser": Color(1.0, 0.2, 0.2, 1.0),
	"shotgun": Color(1.0, 0.7, 0.2, 1.0),
	"energy": Color(0.5, 1.0, 0.5, 1.0),
}

# endregion


# region - Instance

## Singleton instance reference
static var _instance: CombatParticles = null


## Get or create the singleton instance
static func get_instance() -> CombatParticles:
	if not is_instance_valid(_instance):
		_instance = CombatParticles.new()
		_instance.name = "CombatParticles"
	return _instance


func _enter_tree() -> void:
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null

# endregion


# region - Muzzle Flash Effects

## Spawns a muzzle flash effect at the weapon's muzzle position.
## [param position] World position of the muzzle
## [param direction] Firing direction (for flash orientation)
## [param options] Optional overrides: color, weapon_type, scale
static func muzzle_flash(position: Vector3, direction: Vector3 = Vector3.FORWARD, options: Dictionary = {}) -> Node:
	var particle_manager: Node = Engine.get_singleton("AdvancedParticleManager") if Engine.has_singleton("AdvancedParticleManager") else null

	# Try autoload if singleton not available
	if not particle_manager:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree and tree.root.has_node("AdvancedParticleManager"):
			particle_manager = tree.root.get_node("AdvancedParticleManager")

	if not particle_manager:
		push_warning("CombatParticles: AdvancedParticleManager not found")
		return null

	# Determine color based on weapon type
	var weapon_type: String = options.get("weapon_type", "standard")
	var color: Color = options.get("color", MUZZLE_COLORS.get(weapon_type, MUZZLE_COLORS["standard"]))

	var spawn_options: Dictionary = {
		"direction": direction,
		"color": color,
		"scale": options.get("scale", 1.0),
	}

	var effect: Node = particle_manager.spawn_combat_effect("muzzle_flash", position, spawn_options)

	# Also spawn a brief light flash
	if effect and options.get("spawn_light", true):
		_spawn_muzzle_light(position, color)

	# Emit signal for audio sync
	var instance: CombatParticles = get_instance()
	if is_instance_valid(instance):
		instance.combat_effect_spawned.emit("muzzle_flash", position, options.get("scale", 1.0))

	return effect


## Spawns the brief point light for muzzle flash
static func _spawn_muzzle_light(position: Vector3, color: Color) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 3.0
	light.omni_attenuation = 2.0
	light.position = position

	tree.root.add_child(light)

	# Fade out and remove
	var tween: Tween = tree.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.08)
	tween.tween_callback(light.queue_free)

# endregion


# region - Impact Effects

## Spawns a bullet impact effect based on the surface type.
## [param position] World position of impact
## [param normal] Surface normal at impact point
## [param surface] Type of surface hit
## [param options] Optional overrides: scale, color
static func bullet_impact(position: Vector3, normal: Vector3 = Vector3.UP, surface: SurfaceType = SurfaceType.DEFAULT, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var color: Color = options.get("color", SURFACE_COLORS.get(surface, SURFACE_COLORS[SurfaceType.DEFAULT]))

	# Choose effect based on surface type
	var effect_name: String = "bullet_impact"
	if surface == SurfaceType.FLESH:
		effect_name = "blood_splatter"
	elif surface == SurfaceType.METAL:
		effect_name = "hit_spark"

	var spawn_options: Dictionary = {
		"direction": normal,
		"color": color,
		"scale": options.get("scale", 1.0),
	}

	var effect: Node = particle_manager.spawn_combat_effect(effect_name, position, spawn_options)

	# Emit signal
	var instance: CombatParticles = get_instance()
	if is_instance_valid(instance):
		instance.combat_effect_spawned.emit("impact", position, 0.5)

	return effect


## Spawns a blood splatter effect (for player hits).
## [param position] World position
## [param direction] Direction of the hit (for splatter direction)
## [param options] Optional: scale, intensity
static func blood_splatter(position: Vector3, direction: Vector3 = Vector3.ZERO, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var spawn_options: Dictionary = {
		"direction": -direction if direction.length_squared() > 0.001 else Vector3.UP,
		"color": Color(0.8, 0.1, 0.1, 1.0),
		"scale": options.get("scale", 1.0) * options.get("intensity", 1.0),
	}

	var effect: Node = particle_manager.spawn_combat_effect("blood_splatter", position, spawn_options)

	# Emit signal with intensity for haptic feedback
	var instance: CombatParticles = get_instance()
	if is_instance_valid(instance):
		instance.combat_effect_spawned.emit("blood", position, options.get("intensity", 1.0))

	return effect


## Spawns a hit spark effect (for armor/shield hits).
static func hit_spark(position: Vector3, direction: Vector3 = Vector3.UP, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var spawn_options: Dictionary = {
		"direction": direction,
		"color": options.get("color", Color(1.0, 1.0, 1.0, 1.0)),
		"scale": options.get("scale", 1.0),
	}

	return particle_manager.spawn_combat_effect("hit_spark", position, spawn_options)

# endregion


# region - Explosion Effects

## Spawns an explosion effect.
## [param position] World position of explosion center
## [param size] Explosion size (SMALL, MEDIUM, LARGE)
## [param options] Optional: color, damage_radius
static func explosion(position: Vector3, size: ExplosionSize = ExplosionSize.MEDIUM, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var effect_name: String
	var scale: float = 1.0
	var intensity: float = 1.0

	match size:
		ExplosionSize.SMALL:
			effect_name = "explosion_small"
			scale = 0.7
			intensity = 0.5
		ExplosionSize.MEDIUM:
			effect_name = "explosion"
			scale = 1.0
			intensity = 1.0
		ExplosionSize.LARGE:
			effect_name = "big_explosion"
			scale = 1.5
			intensity = 1.5

	var spawn_options: Dictionary = {
		"scale": scale * options.get("scale", 1.0),
		"color": options.get("color", Color(1.0, 0.8, 0.3, 1.0)),
	}

	var effect: Node = particle_manager.spawn_combat_effect(effect_name, position, spawn_options)

	# Spawn secondary smoke effect
	if options.get("spawn_smoke", true):
		_spawn_explosion_smoke(position, size)

	# Spawn flash light
	if options.get("spawn_light", true):
		_spawn_explosion_light(position, size, spawn_options.get("color", Color.ORANGE))

	# Emit signal for screen shake and audio
	var instance: CombatParticles = get_instance()
	if is_instance_valid(instance):
		instance.combat_effect_spawned.emit("explosion", position, intensity)

	return effect


## Spawns secondary smoke from explosion
static func _spawn_explosion_smoke(position: Vector3, size: ExplosionSize) -> void:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return

	var scale: float = 1.0
	match size:
		ExplosionSize.SMALL:
			scale = 0.5
		ExplosionSize.MEDIUM:
			scale = 1.0
		ExplosionSize.LARGE:
			scale = 1.8

	# Slight delay for smoke to follow fire
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		await tree.create_timer(0.05).timeout
		if particle_manager.has_method("spawn_effect"):
			particle_manager.spawn_effect(22, position + Vector3(0, 0.3, 0), {"scale": scale})  ## SMOKE = 22


## Spawns explosion flash light
static func _spawn_explosion_light(position: Vector3, size: ExplosionSize, color: Color) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.position = position

	match size:
		ExplosionSize.SMALL:
			light.light_energy = 5.0
			light.omni_range = 5.0
		ExplosionSize.MEDIUM:
			light.light_energy = 8.0
			light.omni_range = 8.0
		ExplosionSize.LARGE:
			light.light_energy = 12.0
			light.omni_range = 12.0

	light.omni_attenuation = 2.0

	tree.root.add_child(light)

	# Fade out
	var tween: Tween = tree.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.tween_callback(light.queue_free)

# endregion


# region - Tracer and Shell Effects

## Spawns a bullet tracer effect.
## [param start] Start position (muzzle)
## [param end] End position (impact point)
## [param options] Optional: color, speed, width
static func bullet_tracer(start: Vector3, end: Vector3, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var direction: Vector3 = (end - start).normalized()
	var distance: float = start.distance_to(end)

	# Position tracer at midpoint
	var midpoint: Vector3 = start + direction * (distance * 0.5)

	var spawn_options: Dictionary = {
		"direction": direction,
		"color": options.get("color", Color(1.0, 0.9, 0.3, 0.8)),
		"scale": options.get("width", 1.0),
	}

	return particle_manager.spawn_combat_effect("tracer", midpoint, spawn_options)


## Spawns a shell casing ejection effect.
## [param position] Position of the weapon's ejection port
## [param eject_direction] Direction to eject the shell
## [param options] Optional: casing_type (pistol, rifle, shotgun)
static func shell_casing(position: Vector3, eject_direction: Vector3 = Vector3.RIGHT, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var spawn_options: Dictionary = {
		"direction": eject_direction,
		"color": Color(0.8, 0.7, 0.3, 1.0),
		"scale": options.get("scale", 1.0),
	}

	return particle_manager.spawn_combat_effect("shell_casing", position, spawn_options)

# endregion


# region - Special Combat Effects

## Spawns a death/elimination burst effect.
## [param position] Position of the eliminated player
## [param color] Player's team/personal color
## [param options] Optional: intensity
static func elimination_burst(position: Vector3, color: Color = Color.RED, options: Dictionary = {}) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	# Spawn large explosion
	var effect: Node = explosion(position, ExplosionSize.MEDIUM, {
		"color": color,
		"spawn_smoke": true,
		"spawn_light": true,
		"scale": options.get("scale", 1.2),
	})

	# Also spawn a secondary particle burst
	if particle_manager.has_method("spawn_combat_effect"):
		particle_manager.spawn_combat_effect("blood_splatter", position, {
			"color": color,
			"scale": 1.5,
		})

	return effect


## Spawns a shield hit effect (energy deflection).
## [param position] Impact position on shield
## [param normal] Shield surface normal
## [param shield_color] Color of the shield
static func shield_hit(position: Vector3, normal: Vector3 = Vector3.FORWARD, shield_color: Color = Color(0.3, 0.6, 1.0)) -> Node:
	var particle_manager: Node = _get_particle_manager()
	if not particle_manager:
		return null

	var spawn_options: Dictionary = {
		"direction": normal,
		"color": shield_color,
		"scale": 0.8,
	}

	# Spawn energy-style hit spark
	var effect: Node = particle_manager.spawn_combat_effect("hit_spark", position, spawn_options)

	# Spawn ripple effect light
	_spawn_shield_ripple(position, shield_color)

	return effect


## Spawns a brief shield ripple light effect
static func _spawn_shield_ripple(position: Vector3, color: Color) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 2.0
	light.omni_attenuation = 1.0
	light.position = position

	tree.root.add_child(light)

	var tween: Tween = tree.create_tween()
	tween.tween_property(light, "omni_range", 4.0, 0.15)
	tween.parallel().tween_property(light, "light_energy", 0.0, 0.15)
	tween.tween_callback(light.queue_free)


## Spawns a continuous stream effect (for flamethrowers, etc.).
## Returns a controller that must be stopped manually.
## [param start_position] Starting position of the stream
## [param direction] Direction of the stream
## [param options] Optional: color, length, intensity
static func start_stream_effect(start_position: Vector3, direction: Vector3, options: Dictionary = {}) -> StreamEffectController:
	var controller: StreamEffectController = StreamEffectController.new()
	controller.start(start_position, direction, options)
	return controller

# endregion


# region - Helpers

static func _get_particle_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("AdvancedParticleManager"):
		return tree.root.get_node("AdvancedParticleManager")
	return null

# endregion


# region - Stream Effect Controller

## Controller for continuous stream effects like flamethrowers
class StreamEffectController extends RefCounted:
	var _active: bool = false
	var _position: Vector3
	var _direction: Vector3
	var _options: Dictionary
	var _spawn_timer: float = 0.0
	var _spawn_interval: float = 0.05

	func start(pos: Vector3, dir: Vector3, opts: Dictionary = {}) -> void:
		_active = true
		_position = pos
		_direction = dir
		_options = opts
		_spawn_interval = opts.get("spawn_interval", 0.05)

	func update(delta: float, new_position: Vector3, new_direction: Vector3) -> void:
		if not _active:
			return

		_position = new_position
		_direction = new_direction

		_spawn_timer += delta
		if _spawn_timer >= _spawn_interval:
			_spawn_timer = 0.0
			_spawn_stream_particle()

	func _spawn_stream_particle() -> void:
		var particle_manager: Node = CombatParticles._get_particle_manager()
		if particle_manager and particle_manager.has_method("spawn_effect"):
			particle_manager.spawn_effect(23, _position, {  ## FIRE = 23
				"direction": _direction,
				"color": _options.get("color", Color(1.0, 0.5, 0.1)),
				"scale": _options.get("scale", 1.0),
			})

	func stop() -> void:
		_active = false

	func is_active() -> bool:
		return _active

# endregion
