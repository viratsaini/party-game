## SurfaceSounds - Surface-specific sound management for BattleZone Party.
##
## Handles footstep sounds, impact sounds, and other surface-dependent audio.
## Detects surface types via physics layers, materials, or groups.
## Integrates with AudioManager for 3D spatial playback.
class_name SurfaceSounds
extends Node


# -- Signals --

## Emitted when a footstep sound is played.
signal footstep_played(surface: AudioManager.SurfaceType, position: Vector3)

## Emitted when an impact sound is played.
signal impact_played(surface: AudioManager.SurfaceType, position: Vector3, intensity: float)


# -- Constants --

## Default footstep interval while walking (seconds between steps).
const DEFAULT_FOOTSTEP_INTERVAL: float = 0.4

## Footstep interval while running.
const RUNNING_FOOTSTEP_INTERVAL: float = 0.25

## Minimum velocity to trigger footsteps.
const MIN_FOOTSTEP_VELOCITY: float = 0.5

## Physics layer bits for surface detection.
const SURFACE_DETECTION_MASK: int = 1


# -- Exports --

@export_group("Footsteps")

## Enable footstep sounds.
@export var footsteps_enabled: bool = true

## Base volume for footstep sounds (dB).
@export_range(-20.0, 6.0, 1.0) var footstep_volume_db: float = -6.0

## Pitch variation for footsteps.
@export_range(0.0, 0.3, 0.01) var footstep_pitch_variance: float = 0.1

## Distance at which footsteps can be heard.
@export_range(5.0, 50.0, 1.0) var footstep_max_distance: float = 20.0

@export_group("Impacts")

## Enable impact sounds.
@export var impacts_enabled: bool = true

## Base volume for impact sounds (dB).
@export_range(-10.0, 10.0, 1.0) var impact_volume_db: float = 0.0

## Distance at which impacts can be heard.
@export_range(10.0, 100.0, 1.0) var impact_max_distance: float = 40.0

@export_group("Surface Detection")

## Physics layers to raycast for surface detection.
@export_flags_3d_physics var surface_detection_mask: int = 1

## Fallback surface type when detection fails.
@export_enum("Default:0", "Concrete:1", "Metal:2", "Wood:3", "Grass:4", "Sand:5", "Water:6", "Gravel:7", "Carpet:8")
var default_surface: int = 0


# -- State --

## Mapping from physics layer to surface type.
var _layer_to_surface: Dictionary = {
	# Example mappings - configure based on your project's physics layers
	# Layer 1: Default (world geometry)
	1: AudioManager.SurfaceType.CONCRETE,
	# Layer 2: Metal surfaces
	2: AudioManager.SurfaceType.METAL,
	# Layer 3: Wood surfaces
	4: AudioManager.SurfaceType.WOOD,
	# Layer 4: Grass/nature
	8: AudioManager.SurfaceType.GRASS,
}

## Mapping from group names to surface types.
var _group_to_surface: Dictionary = {
	"surface_concrete": AudioManager.SurfaceType.CONCRETE,
	"surface_metal": AudioManager.SurfaceType.METAL,
	"surface_wood": AudioManager.SurfaceType.WOOD,
	"surface_grass": AudioManager.SurfaceType.GRASS,
	"surface_sand": AudioManager.SurfaceType.SAND,
	"surface_water": AudioManager.SurfaceType.WATER,
	"surface_gravel": AudioManager.SurfaceType.GRAVEL,
	"surface_carpet": AudioManager.SurfaceType.CARPET,
}

## Registered footstep sound variations per surface.
var _footstep_sounds: Dictionary = {}  # SurfaceType -> Array[String] (sfx keys)

## Registered impact sound variations per surface.
var _impact_sounds: Dictionary = {}  # SurfaceType -> Array[String] (sfx keys)

## Last footstep sound index per surface (for round-robin variation).
var _footstep_index: Dictionary = {}

## Physics space state for raycasts.
var _space_state: PhysicsDirectSpaceState3D = null


# -- Lifecycle --

func _ready() -> void:
	_register_default_sounds()


func _physics_process(_delta: float) -> void:
	# Update space state reference
	if not _space_state:
		var world := get_tree().root.get_world_3d()
		if world:
			_space_state = world.direct_space_state


# -- Public API: Footsteps --

## Play a footstep sound at the given position.
## Automatically detects surface type via raycast downward.
func play_footstep(position: Vector3, velocity: float = 1.0, is_running: bool = false) -> void:
	if not footsteps_enabled:
		return

	if velocity < MIN_FOOTSTEP_VELOCITY:
		return

	# Detect surface below the position
	var surface := detect_surface_below(position)

	# Get the appropriate sound
	var sfx_key := _get_footstep_sound(surface)
	if sfx_key.is_empty():
		return

	# Calculate volume based on velocity
	var velocity_factor := clampf(velocity / 8.0, 0.5, 1.5)
	var final_volume := footstep_volume_db + (velocity_factor - 1.0) * 6.0

	# Running footsteps are slightly louder
	if is_running:
		final_volume += 2.0

	# Play the sound
	AudioManager.play_sfx_3d_advanced(sfx_key, position, {
		"priority": AudioManager.AudioPriority.LOW,
		"volume_db": final_volume,
		"pitch_variance": footstep_pitch_variance,
		"max_distance": footstep_max_distance,
	})

	footstep_played.emit(surface, position)


## Play a footstep with explicit surface type (no detection).
func play_footstep_on_surface(position: Vector3, surface: AudioManager.SurfaceType, velocity: float = 1.0) -> void:
	if not footsteps_enabled:
		return

	var sfx_key := _get_footstep_sound(surface)
	if sfx_key.is_empty():
		return

	var velocity_factor := clampf(velocity / 8.0, 0.5, 1.5)
	var final_volume := footstep_volume_db + (velocity_factor - 1.0) * 6.0

	AudioManager.play_sfx_3d_advanced(sfx_key, position, {
		"priority": AudioManager.AudioPriority.LOW,
		"volume_db": final_volume,
		"pitch_variance": footstep_pitch_variance,
		"max_distance": footstep_max_distance,
	})

	footstep_played.emit(surface, position)


# -- Public API: Impacts --

## Play an impact sound at the given position.
## Automatically detects surface type from collision normal/position.
func play_impact(position: Vector3, normal: Vector3 = Vector3.UP, intensity: float = 1.0) -> void:
	if not impacts_enabled:
		return

	# Detect surface at impact point
	var surface := detect_surface_at(position, normal)

	play_impact_on_surface(position, surface, intensity)


## Play an impact with explicit surface type.
func play_impact_on_surface(position: Vector3, surface: AudioManager.SurfaceType, intensity: float = 1.0) -> void:
	if not impacts_enabled:
		return

	var sfx_key := _get_impact_sound(surface)
	if sfx_key.is_empty():
		# Fallback to generic impact
		sfx_key = "impact_default"

	var final_volume := impact_volume_db + clampf(log(intensity + 0.5) * 6.0, -6.0, 12.0)

	AudioManager.play_sfx_3d_advanced(sfx_key, position, {
		"priority": AudioManager.AudioPriority.HIGH,
		"volume_db": final_volume,
		"pitch_variance": 0.1,
		"pitch_scale": 1.0 / clampf(intensity, 0.5, 2.0),  # Higher intensity = lower pitch
		"max_distance": impact_max_distance,
	})

	impact_played.emit(surface, position, intensity)


## Play a bullet impact sound (specialized for projectile hits).
func play_bullet_impact(position: Vector3, surface: AudioManager.SurfaceType, caliber: float = 1.0) -> void:
	var sfx_key := "impact_bullet_%s" % _get_surface_name(surface)

	if not AudioManager._sfx_registry.has(sfx_key):
		sfx_key = "impact_bullet_default"
		if not AudioManager._sfx_registry.has(sfx_key):
			sfx_key = "impact_%s" % _get_surface_name(surface)

	var final_volume := impact_volume_db + clampf(caliber * 3.0, 0.0, 9.0)

	AudioManager.play_sfx_3d_advanced(sfx_key, position, {
		"priority": AudioManager.AudioPriority.HIGH,
		"volume_db": final_volume,
		"pitch_variance": 0.15,
		"max_distance": impact_max_distance * 0.75,
	})


# -- Public API: Surface Detection --

## Detect the surface type below a position using a downward raycast.
func detect_surface_below(position: Vector3, max_distance: float = 2.0) -> AudioManager.SurfaceType:
	if not _space_state:
		return default_surface as AudioManager.SurfaceType

	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 0.1,
		position + Vector3.DOWN * max_distance,
		surface_detection_mask
	)

	var result := _space_state.intersect_ray(query)
	if result.is_empty():
		return default_surface as AudioManager.SurfaceType

	return _determine_surface_from_collision(result)


## Detect surface type at a specific position using the collision normal.
func detect_surface_at(position: Vector3, normal: Vector3) -> AudioManager.SurfaceType:
	if not _space_state:
		return default_surface as AudioManager.SurfaceType

	# Raycast slightly into the surface
	var query := PhysicsRayQueryParameters3D.create(
		position + normal * 0.1,
		position - normal * 0.2,
		surface_detection_mask
	)

	var result := _space_state.intersect_ray(query)
	if result.is_empty():
		return default_surface as AudioManager.SurfaceType

	return _determine_surface_from_collision(result)


## Detect surface from a collision body directly.
func detect_surface_from_body(body: Node3D) -> AudioManager.SurfaceType:
	if not body:
		return default_surface as AudioManager.SurfaceType

	# Check groups first (most explicit)
	for group_name: String in _group_to_surface:
		if body.is_in_group(group_name):
			return _group_to_surface[group_name]

	# Check physics layers
	if body is CollisionObject3D:
		var collision_obj := body as CollisionObject3D
		var layer := collision_obj.collision_layer

		for layer_bit: int in _layer_to_surface:
			if layer & layer_bit:
				return _layer_to_surface[layer_bit]

	return default_surface as AudioManager.SurfaceType


# -- Registration --

## Register a footstep sound for a surface type.
func register_footstep_sound(surface: AudioManager.SurfaceType, sfx_key: String) -> void:
	if not _footstep_sounds.has(surface):
		_footstep_sounds[surface] = []
	(_footstep_sounds[surface] as Array).append(sfx_key)


## Register multiple footstep sound variations for a surface.
func register_footstep_sounds(surface: AudioManager.SurfaceType, sfx_keys: Array[String]) -> void:
	_footstep_sounds[surface] = sfx_keys


## Register an impact sound for a surface type.
func register_impact_sound(surface: AudioManager.SurfaceType, sfx_key: String) -> void:
	if not _impact_sounds.has(surface):
		_impact_sounds[surface] = []
	(_impact_sounds[surface] as Array).append(sfx_key)


## Register multiple impact sound variations for a surface.
func register_impact_sounds(surface: AudioManager.SurfaceType, sfx_keys: Array[String]) -> void:
	_impact_sounds[surface] = sfx_keys


## Map a physics layer to a surface type.
func set_layer_surface(layer_bit: int, surface: AudioManager.SurfaceType) -> void:
	_layer_to_surface[layer_bit] = surface


## Map a group name to a surface type.
func set_group_surface(group_name: String, surface: AudioManager.SurfaceType) -> void:
	_group_to_surface[group_name] = surface


# -- Internal --

func _register_default_sounds() -> void:
	# Register placeholder footstep sounds
	# In production, these would reference actual audio files
	var surfaces := [
		AudioManager.SurfaceType.DEFAULT,
		AudioManager.SurfaceType.CONCRETE,
		AudioManager.SurfaceType.METAL,
		AudioManager.SurfaceType.WOOD,
		AudioManager.SurfaceType.GRASS,
		AudioManager.SurfaceType.SAND,
		AudioManager.SurfaceType.WATER,
		AudioManager.SurfaceType.GRAVEL,
		AudioManager.SurfaceType.CARPET,
	]

	for surface in surfaces:
		var surface_name := _get_surface_name(surface)

		# Register footstep variations (typically 3-5 variations per surface)
		_footstep_sounds[surface] = [
			"footstep_%s_1" % surface_name,
			"footstep_%s_2" % surface_name,
			"footstep_%s_3" % surface_name,
		]

		# Register impact variations
		_impact_sounds[surface] = [
			"impact_%s_1" % surface_name,
			"impact_%s_2" % surface_name,
		]

		_footstep_index[surface] = 0


func _determine_surface_from_collision(result: Dictionary) -> AudioManager.SurfaceType:
	var collider: Object = result.get("collider")
	if not collider or not collider is Node3D:
		return default_surface as AudioManager.SurfaceType

	return detect_surface_from_body(collider as Node3D)


func _get_footstep_sound(surface: AudioManager.SurfaceType) -> String:
	if not _footstep_sounds.has(surface):
		surface = AudioManager.SurfaceType.DEFAULT

	if not _footstep_sounds.has(surface):
		return ""

	var sounds: Array = _footstep_sounds[surface]
	if sounds.is_empty():
		return ""

	# Round-robin through variations
	var index: int = _footstep_index.get(surface, 0)
	var sfx_key: String = sounds[index]
	_footstep_index[surface] = (index + 1) % sounds.size()

	return sfx_key


func _get_impact_sound(surface: AudioManager.SurfaceType) -> String:
	if not _impact_sounds.has(surface):
		surface = AudioManager.SurfaceType.DEFAULT

	if not _impact_sounds.has(surface):
		return ""

	var sounds: Array = _impact_sounds[surface]
	if sounds.is_empty():
		return ""

	# Random selection for impacts (more variation desired)
	return sounds[randi() % sounds.size()]


func _get_surface_name(surface: AudioManager.SurfaceType) -> String:
	match surface:
		AudioManager.SurfaceType.CONCRETE: return "concrete"
		AudioManager.SurfaceType.METAL: return "metal"
		AudioManager.SurfaceType.WOOD: return "wood"
		AudioManager.SurfaceType.GRASS: return "grass"
		AudioManager.SurfaceType.SAND: return "sand"
		AudioManager.SurfaceType.WATER: return "water"
		AudioManager.SurfaceType.GRAVEL: return "gravel"
		AudioManager.SurfaceType.CARPET: return "carpet"
		_: return "default"


# -- Footstep Controller Helper --

## Helper class to manage footstep timing for a character.
class FootstepController extends RefCounted:
	var surface_sounds: SurfaceSounds
	var character: CharacterBody3D
	var step_interval: float = DEFAULT_FOOTSTEP_INTERVAL
	var running_interval: float = RUNNING_FOOTSTEP_INTERVAL
	var _time_since_step: float = 0.0
	var _is_grounded: bool = false

	func _init(p_surface_sounds: SurfaceSounds, p_character: CharacterBody3D) -> void:
		surface_sounds = p_surface_sounds
		character = p_character

	## Call this every physics frame to update footstep timing.
	func update(delta: float) -> void:
		if not character:
			return

		_is_grounded = character.is_on_floor()
		if not _is_grounded:
			_time_since_step = 0.0
			return

		var velocity := character.velocity
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()

		if horizontal_speed < MIN_FOOTSTEP_VELOCITY:
			_time_since_step = 0.0
			return

		# Determine if running
		var is_running := horizontal_speed > 6.0
		var current_interval := running_interval if is_running else step_interval

		# Adjust interval based on speed
		current_interval /= clampf(horizontal_speed / 4.0, 0.5, 2.0)

		_time_since_step += delta
		if _time_since_step >= current_interval:
			_time_since_step = 0.0
			surface_sounds.play_footstep(
				character.global_position,
				horizontal_speed,
				is_running
			)


## Create a footstep controller for a character.
func create_footstep_controller(character: CharacterBody3D) -> FootstepController:
	return FootstepController.new(self, character)
