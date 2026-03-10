## JetpackEffects -- Visual and audio effects for the jetpack system.
##
## Manages flame particles, glow effects, sound loops, and visual feedback
## for the jetpack. Automatically syncs with JetpackController state.
##
## Attach as a child of the player character, sibling to JetpackController.
class_name JetpackEffects
extends Node3D

# =============================================================================
# region -- Signals
# =============================================================================

## Emitted when effects fully start.
signal effects_started()

## Emitted when effects fully stop.
signal effects_stopped()

# endregion

# =============================================================================
# region -- Constants
# =============================================================================

## Particle colors for flame effect.
const FLAME_COLOR_INNER: Color = Color(1.0, 0.9, 0.3, 1.0)  # Bright yellow core
const FLAME_COLOR_OUTER: Color = Color(1.0, 0.4, 0.1, 0.8)  # Orange edge
const FLAME_COLOR_TIP: Color = Color(1.0, 0.2, 0.05, 0.4)   # Red tip

## Boost flame color (more intense).
const BOOST_COLOR_INNER: Color = Color(0.8, 0.9, 1.0, 1.0)  # White-blue core
const BOOST_COLOR_OUTER: Color = Color(0.4, 0.6, 1.0, 0.9)  # Blue edge

## Glow colors.
const GLOW_COLOR_NORMAL: Color = Color(1.0, 0.6, 0.2, 0.7)
const GLOW_COLOR_BOOST: Color = Color(0.5, 0.7, 1.0, 0.9)
const GLOW_COLOR_LOW_FUEL: Color = Color(1.0, 0.3, 0.1, 0.5)

## Particle counts for different quality levels.
const PARTICLE_COUNT_HIGH: int = 20
const PARTICLE_COUNT_MEDIUM: int = 12
const PARTICLE_COUNT_LOW: int = 6

## Flame offset from player center (behind and slightly down).
const FLAME_OFFSET: Vector3 = Vector3(0.0, -0.3, 0.5)

## Audio fade times.
const AUDIO_FADE_IN: float = 0.15
const AUDIO_FADE_OUT: float = 0.25

# endregion

# =============================================================================
# region -- Exports
# =============================================================================

## Quality level for particles (0 = low, 1 = medium, 2 = high).
@export_range(0, 2) var quality_level: int = 1

## Whether to show glow effect.
@export var show_glow: bool = true

## Whether to play audio.
@export var play_audio: bool = true

## Volume offset for audio (dB).
@export var audio_volume_db: float = 0.0

# endregion

# =============================================================================
# region -- State
# =============================================================================

## Reference to jetpack controller.
var _jetpack: JetpackController = null

## Particle systems for flames.
var _flame_particles_left: GPUParticles3D = null
var _flame_particles_right: GPUParticles3D = null

## Glow sprite/light.
var _glow_light: OmniLight3D = null

## Audio player for thruster loop.
var _thruster_audio: AudioStreamPlayer3D = null

## Audio player for boost sound (one-shot).
var _boost_audio: AudioStreamPlayer3D = null

## Current effect state.
var _is_active: bool = false
var _is_boosting: bool = false
var _target_audio_volume: float = -80.0
var _current_audio_volume: float = -80.0

# endregion

# =============================================================================
# region -- Lifecycle
# =============================================================================

func _ready() -> void:
	_find_jetpack_controller()
	_create_effects()
	_connect_signals()


func _process(delta: float) -> void:
	_update_audio_volume(delta)
	_update_effects_intensity()


func _exit_tree() -> void:
	_cleanup_effects()

# endregion

# =============================================================================
# region -- Setup
# =============================================================================

func _find_jetpack_controller() -> void:
	# Look for sibling JetpackController
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child is JetpackController:
				_jetpack = child as JetpackController
				break

	# Also check if parent has a jetpack property
	if not _jetpack and parent and parent.has_method("get_jetpack_controller"):
		_jetpack = parent.get_jetpack_controller()

	if not _jetpack:
		push_warning("JetpackEffects: Could not find JetpackController. Effects may not sync.")


func _connect_signals() -> void:
	if _jetpack:
		_jetpack.thrust_state_changed.connect(_on_thrust_state_changed)
		_jetpack.boost_triggered.connect(_on_boost_triggered)
		_jetpack.fuel_changed.connect(_on_fuel_changed)
		_jetpack.fuel_depleted.connect(_on_fuel_depleted)
		_jetpack.unlimited_fuel_changed.connect(_on_unlimited_fuel_changed)


func _create_effects() -> void:
	_create_flame_particles()
	_create_glow_light()
	_create_audio_players()

# endregion

# =============================================================================
# region -- Particle Effects
# =============================================================================

func _create_flame_particles() -> void:
	# Create left flame
	_flame_particles_left = _create_single_flame_particle()
	_flame_particles_left.position = FLAME_OFFSET + Vector3(-0.2, 0.0, 0.0)
	add_child(_flame_particles_left)

	# Create right flame
	_flame_particles_right = _create_single_flame_particle()
	_flame_particles_right.position = FLAME_OFFSET + Vector3(0.2, 0.0, 0.0)
	add_child(_flame_particles_right)


func _create_single_flame_particle() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "FlameParticle"
	particles.emitting = false
	particles.amount = _get_particle_count()
	particles.lifetime = 0.4
	particles.explosiveness = 0.1
	particles.randomness = 0.3
	particles.visibility_aabb = AABB(Vector3(-1, -2, -1), Vector3(2, 4, 2))

	# Create particle material
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)  # Flames go down/back
	material.spread = 15.0
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 6.0
	material.gravity = Vector3(0, -2, 0)
	material.scale_min = 0.1
	material.scale_max = 0.25

	# Color gradient (yellow -> orange -> red, fading out)
	var color_ramp := Gradient.new()
	color_ramp.add_point(0.0, FLAME_COLOR_INNER)
	color_ramp.add_point(0.4, FLAME_COLOR_OUTER)
	color_ramp.add_point(1.0, FLAME_COLOR_TIP)

	var color_curve := GradientTexture1D.new()
	color_curve.gradient = color_ramp
	material.color_ramp = color_curve

	# Scale over lifetime (grows then shrinks)
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.2))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	material.scale_curve = scale_texture

	particles.process_material = material

	# Create mesh for particles (simple quad)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.15, 0.3)
	particles.draw_pass_1 = mesh

	# Create unshaded material for the mesh
	var mesh_material := StandardMaterial3D.new()
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_material.albedo_color = Color.WHITE
	mesh_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mesh_material

	return particles


func _get_particle_count() -> int:
	match quality_level:
		0: return PARTICLE_COUNT_LOW
		1: return PARTICLE_COUNT_MEDIUM
		2: return PARTICLE_COUNT_HIGH
		_: return PARTICLE_COUNT_MEDIUM

# endregion

# =============================================================================
# region -- Glow Effect
# =============================================================================

func _create_glow_light() -> void:
	if not show_glow:
		return

	_glow_light = OmniLight3D.new()
	_glow_light.name = "JetpackGlow"
	_glow_light.position = FLAME_OFFSET
	_glow_light.light_color = GLOW_COLOR_NORMAL
	_glow_light.light_energy = 0.0  # Start off
	_glow_light.omni_range = 2.0
	_glow_light.omni_attenuation = 1.5
	_glow_light.shadow_enabled = false  # Performance
	add_child(_glow_light)


func _set_glow_color(color: Color) -> void:
	if _glow_light:
		_glow_light.light_color = color


func _set_glow_intensity(intensity: float) -> void:
	if _glow_light:
		_glow_light.light_energy = intensity

# endregion

# =============================================================================
# region -- Audio
# =============================================================================

func _create_audio_players() -> void:
	if not play_audio:
		return

	# Main thruster loop
	_thruster_audio = AudioStreamPlayer3D.new()
	_thruster_audio.name = "ThrusterAudio"
	_thruster_audio.bus = &"SFX"
	_thruster_audio.max_distance = 20.0
	_thruster_audio.unit_size = 5.0
	_thruster_audio.volume_db = -80.0  # Start silent
	add_child(_thruster_audio)

	# Boost one-shot
	_boost_audio = AudioStreamPlayer3D.new()
	_boost_audio.name = "BoostAudio"
	_boost_audio.bus = &"SFX"
	_boost_audio.max_distance = 25.0
	_boost_audio.unit_size = 5.0
	add_child(_boost_audio)

	# Register and load audio streams
	_register_audio_streams()


func _register_audio_streams() -> void:
	# These streams should be registered with AudioManager on game startup
	# For now, create placeholder streams that can be replaced
	# The actual sounds should be loaded from res://audio/sfx/

	# Check if AudioManager has these sounds registered
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		# Sounds will be played through AudioManager
		pass


func _update_audio_volume(delta: float) -> void:
	if not _thruster_audio:
		return

	# Smoothly interpolate volume
	var speed := 1.0 / AUDIO_FADE_IN if _target_audio_volume > _current_audio_volume else 1.0 / AUDIO_FADE_OUT
	_current_audio_volume = move_toward(_current_audio_volume, _target_audio_volume, 60.0 * delta * speed)
	_thruster_audio.volume_db = _current_audio_volume + audio_volume_db

	# Start/stop the stream based on volume
	if _current_audio_volume > -60.0 and not _thruster_audio.playing:
		if _thruster_audio.stream:
			_thruster_audio.play()
	elif _current_audio_volume <= -79.0 and _thruster_audio.playing:
		_thruster_audio.stop()


func _play_boost_sound() -> void:
	if not _boost_audio:
		return

	# Play through AudioManager if available
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx_3d("jetpack_boost", global_position, audio_volume_db)
	elif _boost_audio.stream:
		_boost_audio.play()

# endregion

# =============================================================================
# region -- Effect Updates
# =============================================================================

func _update_effects_intensity() -> void:
	if not _jetpack:
		return

	var fuel := _jetpack.fuel
	var is_boosting := _jetpack.is_boosting
	var has_unlimited := _jetpack.has_unlimited_fuel

	# Update glow based on state
	if _glow_light:
		if _is_active:
			var base_intensity := 1.5 if is_boosting else 0.8
			if has_unlimited:
				base_intensity *= 1.3
			elif fuel < 0.25:
				base_intensity *= 0.5
			_glow_light.light_energy = base_intensity

			# Update glow color
			if is_boosting:
				_glow_light.light_color = GLOW_COLOR_BOOST
			elif fuel < 0.25 and not has_unlimited:
				_glow_light.light_color = GLOW_COLOR_LOW_FUEL
			else:
				_glow_light.light_color = GLOW_COLOR_NORMAL
		else:
			_glow_light.light_energy = 0.0

	# Update particle intensity based on fuel/boost state
	_update_particle_intensity(is_boosting, fuel, has_unlimited)


func _update_particle_intensity(is_boosting: bool, fuel: float, has_unlimited: bool) -> void:
	if not _flame_particles_left or not _flame_particles_right:
		return

	if not _is_active:
		return

	# Adjust particle speed/scale based on boost
	var speed_mult := 2.0 if is_boosting else 1.0
	var scale_mult := 1.5 if is_boosting else 1.0

	# Reduce particles when low on fuel
	if fuel < 0.25 and not has_unlimited:
		speed_mult *= 0.7
		scale_mult *= 0.8

	# Update particle material properties
	for particles in [_flame_particles_left, _flame_particles_right]:
		var mat := particles.process_material as ParticleProcessMaterial
		if mat:
			mat.initial_velocity_min = 3.0 * speed_mult
			mat.initial_velocity_max = 6.0 * speed_mult
			mat.scale_min = 0.1 * scale_mult
			mat.scale_max = 0.25 * scale_mult

			# Change colors for boost
			if is_boosting:
				var color_ramp := Gradient.new()
				color_ramp.add_point(0.0, BOOST_COLOR_INNER)
				color_ramp.add_point(0.5, BOOST_COLOR_OUTER)
				color_ramp.add_point(1.0, Color(0.2, 0.3, 0.8, 0.0))
				var color_curve := GradientTexture1D.new()
				color_curve.gradient = color_ramp
				mat.color_ramp = color_curve


func _start_effects() -> void:
	if _is_active:
		return

	_is_active = true

	# Start particles
	if _flame_particles_left:
		_flame_particles_left.emitting = true
	if _flame_particles_right:
		_flame_particles_right.emitting = true

	# Fade in audio
	_target_audio_volume = 0.0

	effects_started.emit()


func _stop_effects() -> void:
	if not _is_active:
		return

	_is_active = false

	# Stop particles
	if _flame_particles_left:
		_flame_particles_left.emitting = false
	if _flame_particles_right:
		_flame_particles_right.emitting = false

	# Fade out audio
	_target_audio_volume = -80.0

	# Reset glow
	if _glow_light:
		_glow_light.light_energy = 0.0

	effects_stopped.emit()


func _cleanup_effects() -> void:
	_stop_effects()

# endregion

# =============================================================================
# region -- Signal Handlers
# =============================================================================

func _on_thrust_state_changed(is_thrusting: bool) -> void:
	if is_thrusting:
		_start_effects()
	else:
		_stop_effects()


func _on_boost_triggered() -> void:
	_is_boosting = true
	_play_boost_sound()

	# Reset boost visual after duration
	var timer := get_tree().create_timer(JetpackController.BOOST_DURATION)
	timer.timeout.connect(func(): _is_boosting = false)


func _on_fuel_changed(fuel_normalized: float) -> void:
	# Visual feedback handled in _update_effects_intensity
	pass


func _on_fuel_depleted() -> void:
	_stop_effects()

	# Play sputter sound
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx_3d("jetpack_empty", global_position, audio_volume_db - 3.0)


func _on_unlimited_fuel_changed(is_unlimited: bool) -> void:
	# Visual feedback - could add special effects for power-up
	if is_unlimited and _is_active:
		# Flash the glow brighter briefly
		if _glow_light:
			var original_energy := _glow_light.light_energy
			_glow_light.light_energy = 3.0
			var tween := create_tween()
			tween.tween_property(_glow_light, "light_energy", original_energy, 0.5)

# endregion

# =============================================================================
# region -- Public API
# =============================================================================

## Force start effects (for preview/testing).
func force_start() -> void:
	_start_effects()


## Force stop effects.
func force_stop() -> void:
	_stop_effects()


## Set quality level at runtime.
func set_quality(level: int) -> void:
	quality_level = clampi(level, 0, 2)

	# Update particle counts
	var count := _get_particle_count()
	if _flame_particles_left:
		_flame_particles_left.amount = count
	if _flame_particles_right:
		_flame_particles_right.amount = count


## Get whether effects are currently active.
func is_active() -> bool:
	return _is_active

# endregion
