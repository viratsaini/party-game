## Graphics Manager Autoload Singleton
##
## Manages all post-processing effects, quality presets, and visual settings
## for BattleZone Party. Provides a unified API for applying effects and
## transitioning between visual profiles.
##
## Features:
## - Quality presets (Low, Medium, High, Ultra)
## - Per-effect toggles
## - Game mode-specific profiles
## - Temporary effects (hit, low health, speed boost)
## - Mobile-optimized with GL Compatibility support
## - Performance monitoring
##
## Usage:
##   GraphicsManager.set_quality_preset(GraphicsManager.QualityPreset.HIGH)
##   GraphicsManager.apply_game_profile("arena_blaster")
##   GraphicsManager.apply_hit_effect()
extends Node


# region -- Enums

## Quality preset levels
enum QualityPreset {
	LOW = 0,       ## Minimal effects, maximum performance
	MEDIUM = 1,    ## Balanced effects
	HIGH = 2,      ## Most effects enabled
	ULTRA = 3,     ## All effects at full quality
}


## Individual effect toggles
enum Effect {
	BLOOM,
	SSAO,
	COLOR_GRADING,
	VIGNETTE,
	MOTION_BLUR,
	CHROMATIC_ABERRATION,
	DOF,
	LENS_DISTORTION,
	FOG,
}

# endregion


# region -- Signals

## Emitted when quality preset changes
signal quality_changed(preset: QualityPreset)

## Emitted when an effect is toggled
signal effect_toggled(effect: Effect, enabled: bool)

## Emitted when a game profile is applied
signal profile_applied(profile_name: String)

## Emitted when a temporary effect starts
signal effect_started(effect_name: String)

## Emitted when a temporary effect ends
signal effect_ended(effect_name: String)

# endregion


# region -- Constants

## Path to the post-processing environment resource
const POST_PROCESSING_ENV_PATH: String = "res://shared/environment/post_processing.tres"

## Settings file path
const SETTINGS_PATH: String = "user://graphics_settings.cfg"

## Default transition duration for profile changes
const DEFAULT_TRANSITION_DURATION: float = 0.5

## Performance monitoring window (frames)
const PERF_SAMPLE_COUNT: int = 60

## Target frame budget for post-processing (ms)
const TARGET_PP_BUDGET_MS: float = 5.0

# endregion


# region -- State

## Current quality preset
var quality_preset: QualityPreset = QualityPreset.MEDIUM:
	set(value):
		quality_preset = value
		_apply_quality_preset(value)
		quality_changed.emit(value)

## Individual effect states
var effect_states: Dictionary = {
	Effect.BLOOM: true,
	Effect.SSAO: false,
	Effect.COLOR_GRADING: true,
	Effect.VIGNETTE: true,
	Effect.MOTION_BLUR: false,
	Effect.CHROMATIC_ABERRATION: false,
	Effect.DOF: false,
	Effect.LENS_DISTORTION: false,
	Effect.FOG: false,
}

## Current game profile name
var current_profile_name: String = "default"

## Reference to the WorldEnvironment node
var _world_environment: WorldEnvironment = null

## Reference to the Environment resource
var _environment: Environment = null

## Current profile values (for blending)
var _current_profile: Dictionary = {}

## Target profile values (for blending)
var _target_profile: Dictionary = {}

## Profile transition progress (0-1)
var _transition_progress: float = 1.0

## Profile transition duration
var _transition_duration: float = 0.0

## Active temporary effects
var _active_effects: Dictionary = {}

## Post-processing canvas layer for shader effects
var _pp_canvas: CanvasLayer = null

## Shader effect nodes
var _vignette_rect: ColorRect = null
var _chromatic_rect: ColorRect = null
var _motion_blur_rect: ColorRect = null
var _lens_distortion_rect: ColorRect = null

## Performance monitoring
var _frame_times: Array[float] = []
var _auto_quality_enabled: bool = false

# endregion


# region -- Lifecycle

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_create_pp_canvas()
	_create_shader_effects()

	# Wait for scene tree to be ready before setting up environment
	await get_tree().process_frame
	_setup_environment()


func _process(delta: float) -> void:
	# Update profile transition
	if _transition_progress < 1.0:
		_transition_progress = minf(_transition_progress + delta / _transition_duration, 1.0)
		_apply_blended_profile()

	# Update temporary effects
	_update_temporary_effects(delta)

	# Performance monitoring
	if _auto_quality_enabled:
		_monitor_performance(delta)

# endregion


# region -- Setup

## Creates or gets the WorldEnvironment node
func _setup_environment() -> void:
	# Look for existing WorldEnvironment in current scene
	_world_environment = _find_world_environment()

	if not _world_environment:
		# Create a new WorldEnvironment
		_world_environment = WorldEnvironment.new()
		_world_environment.name = "PPWorldEnvironment"
		get_tree().root.add_child.call_deferred(_world_environment)

	# Load or create the environment resource
	if ResourceLoader.exists(POST_PROCESSING_ENV_PATH):
		_environment = load(POST_PROCESSING_ENV_PATH) as Environment
		if _environment:
			_environment = _environment.duplicate() as Environment  # Work with a copy
	else:
		_environment = Environment.new()
		_setup_default_environment()

	if _world_environment:
		_world_environment.environment = _environment

	# Apply initial quality preset
	_apply_quality_preset(quality_preset)

	# Load default profile
	_current_profile = PPProfiles.get_profile("default")
	_apply_profile_to_environment(_current_profile)


## Finds an existing WorldEnvironment in the scene tree
func _find_world_environment() -> WorldEnvironment:
	var root: Node = get_tree().root
	return _find_node_by_type(root, "WorldEnvironment") as WorldEnvironment


## Recursively finds a node of a specific type
func _find_node_by_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_node_by_type(child, type_name)
		if found:
			return found
	return null


## Sets up default environment values if no resource exists
func _setup_default_environment() -> void:
	if not _environment:
		return

	_environment.background_mode = Environment.BG_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment.glow_enabled = true
	_environment.adjustment_enabled = true


## Creates the canvas layer for shader-based post-processing effects
func _create_pp_canvas() -> void:
	_pp_canvas = CanvasLayer.new()
	_pp_canvas.name = "PPEffectsCanvas"
	_pp_canvas.layer = 100  # Above everything
	add_child(_pp_canvas)


## Creates shader effect nodes
func _create_shader_effects() -> void:
	# Vignette effect
	_vignette_rect = _create_fullscreen_rect("VignetteEffect")
	_vignette_rect.material = _create_vignette_material()
	_pp_canvas.add_child(_vignette_rect)

	# Chromatic aberration effect
	_chromatic_rect = _create_fullscreen_rect("ChromaticEffect")
	_chromatic_rect.material = _create_chromatic_material()
	_pp_canvas.add_child(_chromatic_rect)

	# Motion blur effect
	_motion_blur_rect = _create_fullscreen_rect("MotionBlurEffect")
	_motion_blur_rect.material = _create_motion_blur_material()
	_pp_canvas.add_child(_motion_blur_rect)

	# Lens distortion effect
	_lens_distortion_rect = _create_fullscreen_rect("LensDistortionEffect")
	_lens_distortion_rect.material = _create_lens_distortion_material()
	_pp_canvas.add_child(_lens_distortion_rect)

	# Initially hide all effects
	_update_shader_effects({})


## Creates a fullscreen ColorRect for shader effects
func _create_fullscreen_rect(rect_name: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = rect_name
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	return rect

# endregion


# region -- Shader Materials

## Creates vignette shader material
func _create_vignette_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform float roundness : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	float dist = length(uv) * 2.0;
	float vignette = smoothstep(1.0 - softness, 1.0 + softness * 0.5, dist * (1.0 + roundness));

	COLOR = vec4(color.rgb, vignette * intensity * color.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


## Creates chromatic aberration shader material
func _create_chromatic_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 0.05) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 offset = (uv - 0.5) * intensity;

	float r = texture(screen_texture, uv + offset).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - offset).b;

	COLOR = vec4(r, g, b, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


## Creates motion blur shader material
func _create_motion_blur_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 velocity = vec2(0.0, 0.0);
uniform int samples : hint_range(2, 16) = 8;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 color = vec4(0.0);
	vec2 blur_offset = velocity * intensity * 0.02;

	for (int i = 0; i < samples; i++) {
		float t = float(i) / float(samples - 1) - 0.5;
		color += texture(screen_texture, uv + blur_offset * t);
	}

	COLOR = color / float(samples);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


## Creates lens distortion shader material
func _create_lens_distortion_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(-0.1, 0.1) = 0.0;
uniform float cubic_intensity : hint_range(-0.1, 0.1) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	float r2 = dot(uv, uv);
	float r4 = r2 * r2;

	vec2 distorted = uv * (1.0 + intensity * r2 + cubic_intensity * r4) + 0.5;

	if (distorted.x < 0.0 || distorted.x > 1.0 || distorted.y < 0.0 || distorted.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		COLOR = texture(screen_texture, distorted);
	}
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

# endregion


# region -- Quality Presets

## Sets the quality preset
func set_quality_preset(preset: QualityPreset) -> void:
	quality_preset = preset
	_save_settings()


## Gets the current quality preset
func get_quality_preset() -> QualityPreset:
	return quality_preset


## Returns human-readable name for a quality preset
func get_quality_preset_name(preset: QualityPreset) -> String:
	match preset:
		QualityPreset.LOW:
			return "Low"
		QualityPreset.MEDIUM:
			return "Medium"
		QualityPreset.HIGH:
			return "High"
		QualityPreset.ULTRA:
			return "Ultra"
		_:
			return "Unknown"


## Applies quality preset settings
func _apply_quality_preset(preset: QualityPreset) -> void:
	match preset:
		QualityPreset.LOW:
			effect_states[Effect.BLOOM] = false
			effect_states[Effect.SSAO] = false
			effect_states[Effect.COLOR_GRADING] = true
			effect_states[Effect.VIGNETTE] = false
			effect_states[Effect.MOTION_BLUR] = false
			effect_states[Effect.CHROMATIC_ABERRATION] = false
			effect_states[Effect.DOF] = false
			effect_states[Effect.LENS_DISTORTION] = false
			effect_states[Effect.FOG] = false

		QualityPreset.MEDIUM:
			effect_states[Effect.BLOOM] = true
			effect_states[Effect.SSAO] = false
			effect_states[Effect.COLOR_GRADING] = true
			effect_states[Effect.VIGNETTE] = true
			effect_states[Effect.MOTION_BLUR] = false
			effect_states[Effect.CHROMATIC_ABERRATION] = false
			effect_states[Effect.DOF] = false
			effect_states[Effect.LENS_DISTORTION] = false
			effect_states[Effect.FOG] = false

		QualityPreset.HIGH:
			effect_states[Effect.BLOOM] = true
			effect_states[Effect.SSAO] = true
			effect_states[Effect.COLOR_GRADING] = true
			effect_states[Effect.VIGNETTE] = true
			effect_states[Effect.MOTION_BLUR] = false
			effect_states[Effect.CHROMATIC_ABERRATION] = true
			effect_states[Effect.DOF] = false
			effect_states[Effect.LENS_DISTORTION] = false
			effect_states[Effect.FOG] = false

		QualityPreset.ULTRA:
			effect_states[Effect.BLOOM] = true
			effect_states[Effect.SSAO] = true
			effect_states[Effect.COLOR_GRADING] = true
			effect_states[Effect.VIGNETTE] = true
			effect_states[Effect.MOTION_BLUR] = true
			effect_states[Effect.CHROMATIC_ABERRATION] = true
			effect_states[Effect.DOF] = true
			effect_states[Effect.LENS_DISTORTION] = true
			effect_states[Effect.FOG] = true

	# Re-apply current profile with new quality settings
	if _current_profile.size() > 0:
		var scaled: Dictionary = PPProfiles.get_quality_scaled_profile(_current_profile, preset)
		_apply_profile_to_environment(scaled)

# endregion


# region -- Effect Toggles

## Toggles an individual effect
func set_effect_enabled(effect: Effect, enabled: bool) -> void:
	effect_states[effect] = enabled
	_apply_effect_state(effect, enabled)
	effect_toggled.emit(effect, enabled)
	_save_settings()


## Gets the current state of an effect
func is_effect_enabled(effect: Effect) -> bool:
	return effect_states.get(effect, false) as bool


## Applies the current state of an effect to the environment
func _apply_effect_state(effect: Effect, enabled: bool) -> void:
	if not _environment:
		return

	match effect:
		Effect.BLOOM:
			_environment.glow_enabled = enabled
		Effect.SSAO:
			_environment.ssao_enabled = enabled
		Effect.COLOR_GRADING:
			_environment.adjustment_enabled = enabled
		Effect.FOG:
			_environment.fog_enabled = enabled
		Effect.VIGNETTE:
			if _vignette_rect:
				_vignette_rect.visible = enabled
		Effect.MOTION_BLUR:
			if _motion_blur_rect:
				_motion_blur_rect.visible = enabled
		Effect.CHROMATIC_ABERRATION:
			if _chromatic_rect:
				_chromatic_rect.visible = enabled
		Effect.LENS_DISTORTION:
			if _lens_distortion_rect:
				_lens_distortion_rect.visible = enabled
		Effect.DOF:
			_environment.dof_blur_far_enabled = enabled
			_environment.dof_blur_near_enabled = enabled

# endregion


# region -- Profile Application

## Applies a game-specific profile
func apply_game_profile(game_id: String, transition_duration: float = DEFAULT_TRANSITION_DURATION) -> void:
	var profile: Dictionary = PPProfiles.get_profile(game_id)
	var scaled_profile: Dictionary = PPProfiles.get_quality_scaled_profile(profile, quality_preset)

	current_profile_name = game_id
	_target_profile = scaled_profile

	if transition_duration > 0.0:
		_transition_duration = transition_duration
		_transition_progress = 0.0
	else:
		_current_profile = scaled_profile
		_apply_profile_to_environment(scaled_profile)

	profile_applied.emit(game_id)


## Applies profile values to the environment resource
func _apply_profile_to_environment(profile: Dictionary) -> void:
	if not _environment:
		return

	# Apply environment properties
	if profile.has("glow_enabled") and effect_states[Effect.BLOOM]:
		_environment.glow_enabled = profile["glow_enabled"] as bool
	if profile.has("glow_intensity"):
		_environment.glow_intensity = profile["glow_intensity"] as float
	if profile.has("glow_strength"):
		_environment.glow_strength = profile["glow_strength"] as float
	if profile.has("glow_bloom"):
		_environment.glow_bloom = profile["glow_bloom"] as float
	if profile.has("glow_hdr_threshold"):
		_environment.glow_hdr_threshold = profile["glow_hdr_threshold"] as float
	if profile.has("glow_mix"):
		_environment.glow_mix = profile["glow_mix"] as float

	if profile.has("adjustment_enabled") and effect_states[Effect.COLOR_GRADING]:
		_environment.adjustment_enabled = profile["adjustment_enabled"] as bool
	if profile.has("adjustment_brightness"):
		_environment.adjustment_brightness = profile["adjustment_brightness"] as float
	if profile.has("adjustment_contrast"):
		_environment.adjustment_contrast = profile["adjustment_contrast"] as float
	if profile.has("adjustment_saturation"):
		_environment.adjustment_saturation = profile["adjustment_saturation"] as float

	if profile.has("tonemap_mode"):
		_environment.tonemap_mode = profile["tonemap_mode"] as int
	if profile.has("tonemap_exposure"):
		_environment.tonemap_exposure = profile["tonemap_exposure"] as float

	if profile.has("ssao_enabled") and effect_states[Effect.SSAO]:
		_environment.ssao_enabled = profile["ssao_enabled"] as bool
	if profile.has("ssao_radius"):
		_environment.ssao_radius = profile["ssao_radius"] as float
	if profile.has("ssao_intensity"):
		_environment.ssao_intensity = profile["ssao_intensity"] as float

	if profile.has("fog_enabled") and effect_states[Effect.FOG]:
		_environment.fog_enabled = profile["fog_enabled"] as bool
	if profile.has("fog_density"):
		_environment.fog_density = profile["fog_density"] as float

	if profile.has("dof_blur_far_enabled") and effect_states[Effect.DOF]:
		_environment.dof_blur_far_enabled = profile["dof_blur_far_enabled"] as bool
	if profile.has("dof_blur_far_distance"):
		_environment.dof_blur_far_distance = profile["dof_blur_far_distance"] as float
	if profile.has("dof_blur_far_transition"):
		_environment.dof_blur_far_transition = profile["dof_blur_far_transition"] as float

	# Apply shader effects
	_update_shader_effects(profile)


## Updates shader-based effects from profile
func _update_shader_effects(profile: Dictionary) -> void:
	# Vignette
	if _vignette_rect and _vignette_rect.material:
		var vignette_mat: ShaderMaterial = _vignette_rect.material as ShaderMaterial
		var vignette_intensity: float = profile.get("vignette_intensity", 0.0) as float
		var vignette_color: Color = profile.get("vignette_color", Color.BLACK) as Color

		vignette_mat.set_shader_parameter("intensity", vignette_intensity)
		vignette_mat.set_shader_parameter("color", vignette_color)
		_vignette_rect.visible = vignette_intensity > 0.01 and effect_states[Effect.VIGNETTE]

	# Chromatic aberration
	if _chromatic_rect and _chromatic_rect.material:
		var chromatic_mat: ShaderMaterial = _chromatic_rect.material as ShaderMaterial
		var chromatic_enabled: bool = profile.get("chromatic_aberration_enabled", false) as bool
		var chromatic_intensity: float = profile.get("chromatic_aberration_intensity", 0.0) as float

		chromatic_mat.set_shader_parameter("intensity", chromatic_intensity)
		_chromatic_rect.visible = chromatic_enabled and chromatic_intensity > 0.001 and effect_states[Effect.CHROMATIC_ABERRATION]

	# Motion blur
	if _motion_blur_rect and _motion_blur_rect.material:
		var motion_mat: ShaderMaterial = _motion_blur_rect.material as ShaderMaterial
		var motion_enabled: bool = profile.get("motion_blur_enabled", false) as bool
		var motion_intensity: float = profile.get("motion_blur_intensity", 0.0) as float

		motion_mat.set_shader_parameter("intensity", motion_intensity)
		_motion_blur_rect.visible = motion_enabled and motion_intensity > 0.01 and effect_states[Effect.MOTION_BLUR]

	# Lens distortion
	if _lens_distortion_rect and _lens_distortion_rect.material:
		var lens_mat: ShaderMaterial = _lens_distortion_rect.material as ShaderMaterial
		var lens_enabled: bool = profile.get("lens_distortion_enabled", false) as bool
		var lens_intensity: float = profile.get("lens_distortion_intensity", 0.0) as float

		lens_mat.set_shader_parameter("intensity", lens_intensity)
		_lens_distortion_rect.visible = lens_enabled and absf(lens_intensity) > 0.001 and effect_states[Effect.LENS_DISTORTION]


## Applies blended profile during transition
func _apply_blended_profile() -> void:
	var blended: Dictionary = PPProfiles.blend_profiles(_current_profile, _target_profile, _transition_progress)
	_apply_profile_to_environment(blended)

	if _transition_progress >= 1.0:
		_current_profile = _target_profile.duplicate()

# endregion


# region -- Temporary Effects

## Applies a hit effect (red flash)
func apply_hit_effect(intensity: float = 1.0, duration: float = 0.2) -> void:
	var modifier: Dictionary = PPProfiles.get_hit_effect_modifier(intensity)
	_start_temporary_effect("hit", modifier, duration)


## Applies low health effect (pulsing red vignette)
func apply_low_health_effect(health_percent: float) -> void:
	if health_percent > 0.3:
		_stop_temporary_effect("low_health")
		return

	var modifier: Dictionary = PPProfiles.get_low_health_modifier(health_percent)
	_active_effects["low_health"] = {
		"modifier": modifier,
		"duration": -1.0,  # Continuous
		"elapsed": 0.0,
		"health_percent": health_percent,
	}


## Applies speed boost effect
func apply_speed_boost_effect(intensity: float = 1.0, duration: float = 5.0) -> void:
	var modifier: Dictionary = PPProfiles.get_speed_boost_modifier(intensity)
	_start_temporary_effect("speed_boost", modifier, duration)


## Applies victory effect
func apply_victory_effect(duration: float = 3.0) -> void:
	var modifier: Dictionary = PPProfiles.get_victory_modifier()
	_start_temporary_effect("victory", modifier, duration)


## Applies death effect
func apply_death_effect(duration: float = 2.0) -> void:
	var modifier: Dictionary = PPProfiles.get_death_modifier()
	_start_temporary_effect("death", modifier, duration)


## Applies slow motion effect
func apply_slow_motion_effect(duration: float = 1.0) -> void:
	var modifier: Dictionary = PPProfiles.get_slow_motion_modifier()
	_start_temporary_effect("slow_motion", modifier, duration)


## Starts a temporary effect
func _start_temporary_effect(effect_name: String, modifier: Dictionary, duration: float) -> void:
	_active_effects[effect_name] = {
		"modifier": modifier,
		"duration": duration,
		"elapsed": 0.0,
	}
	effect_started.emit(effect_name)


## Stops a temporary effect
func _stop_temporary_effect(effect_name: String) -> void:
	if _active_effects.has(effect_name):
		_active_effects.erase(effect_name)
		effect_ended.emit(effect_name)


## Clears all temporary effects
func clear_all_effects() -> void:
	var effect_names: Array = _active_effects.keys().duplicate()
	for effect_name: String in effect_names:
		effect_ended.emit(effect_name)
	_active_effects.clear()
	_apply_profile_to_environment(_current_profile)


## Updates temporary effects
func _update_temporary_effects(delta: float) -> void:
	if _active_effects.is_empty():
		return

	var effects_to_remove: Array[String] = []
	var combined_modifier: Dictionary = {}

	for effect_name: String in _active_effects:
		var effect_data: Dictionary = _active_effects[effect_name]
		var duration: float = effect_data["duration"] as float

		if duration > 0.0:
			effect_data["elapsed"] = (effect_data["elapsed"] as float) + delta
			if (effect_data["elapsed"] as float) >= duration:
				effects_to_remove.append(effect_name)
				continue

			# Calculate fade out
			var remaining: float = duration - (effect_data["elapsed"] as float)
			var fade: float = minf(remaining / 0.2, 1.0)  # Fade out over last 0.2s
			var modifier: Dictionary = effect_data["modifier"] as Dictionary

			for key: String in modifier:
				if modifier[key] is float:
					combined_modifier[key] = (modifier[key] as float) * fade
				else:
					combined_modifier[key] = modifier[key]
		else:
			# Continuous effect (like low health)
			if effect_name == "low_health":
				var health_pct: float = effect_data.get("health_percent", 0.3) as float
				effect_data["modifier"] = PPProfiles.get_low_health_modifier(health_pct)

			for key: String in effect_data["modifier"]:
				combined_modifier[key] = effect_data["modifier"][key]

	# Remove expired effects
	for effect_name: String in effects_to_remove:
		_active_effects.erase(effect_name)
		effect_ended.emit(effect_name)

	# Apply combined modifier
	if combined_modifier.size() > 0:
		var modified_profile: Dictionary = PPProfiles.apply_modifier(_current_profile, combined_modifier)
		_apply_profile_to_environment(modified_profile)
	elif effects_to_remove.size() > 0 and _active_effects.is_empty():
		_apply_profile_to_environment(_current_profile)

# endregion


# region -- Motion Blur Velocity

## Updates motion blur velocity (call from player controller)
func set_motion_blur_velocity(velocity: Vector2) -> void:
	if _motion_blur_rect and _motion_blur_rect.material and effect_states[Effect.MOTION_BLUR]:
		var mat: ShaderMaterial = _motion_blur_rect.material as ShaderMaterial
		mat.set_shader_parameter("velocity", velocity)

# endregion


# region -- Performance Monitoring

## Enables/disables automatic quality adjustment
func set_auto_quality(enabled: bool) -> void:
	_auto_quality_enabled = enabled
	_frame_times.clear()


## Monitors performance and adjusts quality if needed
func _monitor_performance(delta: float) -> void:
	_frame_times.append(delta)

	if _frame_times.size() > PERF_SAMPLE_COUNT:
		_frame_times.remove_at(0)

	if _frame_times.size() == PERF_SAMPLE_COUNT:
		var avg_frame_time: float = 0.0
		for ft: float in _frame_times:
			avg_frame_time += ft
		avg_frame_time /= PERF_SAMPLE_COUNT

		var fps: float = 1.0 / avg_frame_time

		# If FPS drops below 30, reduce quality
		if fps < 30.0 and quality_preset > QualityPreset.LOW:
			quality_preset = (quality_preset - 1) as QualityPreset
			push_warning("GraphicsManager: Auto-reducing quality to %s due to low FPS (%.1f)" % [
				get_quality_preset_name(quality_preset), fps
			])
			_frame_times.clear()

# endregion


# region -- Settings Persistence

## Loads graphics settings from disk
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return

	quality_preset = cfg.get_value("graphics", "quality_preset", QualityPreset.MEDIUM) as QualityPreset

	for effect: Effect in effect_states:
		var key: String = "effect_%d" % effect
		if cfg.has_section_key("effects", key):
			effect_states[effect] = cfg.get_value("effects", key, effect_states[effect])


## Saves graphics settings to disk
func _save_settings() -> void:
	var cfg := ConfigFile.new()

	cfg.set_value("graphics", "quality_preset", quality_preset)

	for effect: Effect in effect_states:
		var key: String = "effect_%d" % effect
		cfg.set_value("effects", key, effect_states[effect])

	cfg.save(SETTINGS_PATH)

# endregion


# region -- Utility Functions

## Gets the current environment resource (for external modification)
func get_environment() -> Environment:
	return _environment


## Gets the WorldEnvironment node
func get_world_environment() -> WorldEnvironment:
	return _world_environment


## Resets all effects to default
func reset_to_defaults() -> void:
	quality_preset = QualityPreset.MEDIUM
	clear_all_effects()
	apply_game_profile("default")
	_save_settings()


## Gets all available quality preset values
func get_all_quality_presets() -> Array[QualityPreset]:
	return [
		QualityPreset.LOW,
		QualityPreset.MEDIUM,
		QualityPreset.HIGH,
		QualityPreset.ULTRA,
	]

# endregion
