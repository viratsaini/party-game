## TransitionEffects - Additional visual effects for transitions and screen effects
## Includes screen shake, chromatic aberration, slow motion, and more
extends Node

signal effect_started(effect_name: String)
signal effect_completed(effect_name: String)

# Screen shake state
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _shake_frequency: float = 30.0
var _original_camera_offset: Vector2 = Vector2.ZERO
var _target_camera: Camera2D

# Slow motion state
var _slow_mo_tween: Tween
var _original_time_scale: float = 1.0

# Chromatic aberration shader
const CHROMATIC_ABERRATION_SHADER := """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 20.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float radial_blur : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	vec2 direction = (uv - center) * intensity * 0.001;

	float r = texture(SCREEN_TEXTURE, uv + direction).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - direction).b;

	// Apply radial blur
	if (radial_blur > 0.0) {
		vec4 blur = vec4(0.0);
		float total = 0.0;
		for (float i = 0.0; i < 10.0; i += 1.0) {
			float t = i / 10.0;
			vec2 offset = direction * t * radial_blur * 5.0;
			blur += texture(SCREEN_TEXTURE, uv - offset);
			total += 1.0;
		}
		blur /= total;
		g = mix(g, blur.g, radial_blur);
	}

	COLOR = vec4(r, g, b, 1.0);
}
"""

# Scanlines shader
const SCANLINES_SHADER := """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float line_count : hint_range(100.0, 1000.0) = 400.0;
uniform float scroll_speed : hint_range(0.0, 5.0) = 0.0;

void fragment() {
	vec4 col = texture(SCREEN_TEXTURE, UV);
	float scanline = sin((UV.y + TIME * scroll_speed * 0.01) * line_count * 3.14159) * 0.5 + 0.5;
	scanline = pow(scanline, 2.0);
	col.rgb *= 1.0 - (scanline * intensity);
	COLOR = col;
}
"""

# Vignette + grain shader
const FILM_GRAIN_SHADER := """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform float grain_intensity : hint_range(0.0, 0.5) = 0.1;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.5;

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 col = texture(SCREEN_TEXTURE, UV);

	// Film grain
	float grain = rand(UV + vec2(TIME * 0.01, TIME * 0.01)) * 2.0 - 1.0;
	col.rgb += grain * grain_intensity;

	// Vignette
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	float vignette = smoothstep(1.0 - vignette_softness, 1.0, dist * 2.0 * vignette_intensity);
	col.rgb *= 1.0 - vignette;

	COLOR = col;
}
"""

# Heat distortion shader
const HEAT_DISTORTION_SHADER := """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 0.1) = 0.01;
uniform float speed : hint_range(0.0, 10.0) = 2.0;
uniform float scale : hint_range(1.0, 50.0) = 10.0;

void fragment() {
	vec2 uv = UV;
	float distortion = sin(uv.y * scale + TIME * speed) * intensity;
	distortion += sin(uv.x * scale * 0.7 + TIME * speed * 1.3) * intensity * 0.5;
	uv.x += distortion;
	COLOR = texture(SCREEN_TEXTURE, uv);
}
"""

# Effect overlays
var _chromatic_overlay: ColorRect
var _scanlines_overlay: ColorRect
var _film_grain_overlay: ColorRect
var _heat_overlay: ColorRect

# Active effects tracking
var _active_effects: Dictionary = {}


func _ready() -> void:
	_setup_effect_overlays()


func _process(delta: float) -> void:
	_process_screen_shake(delta)


func _setup_effect_overlays() -> void:
	# Create canvas layer for effects
	var canvas := CanvasLayer.new()
	canvas.name = "TransitionEffectsLayer"
	canvas.layer = 99
	add_child(canvas)

	# Chromatic aberration overlay
	_chromatic_overlay = _create_effect_overlay(CHROMATIC_ABERRATION_SHADER, "ChromaticAberration")
	canvas.add_child(_chromatic_overlay)

	# Scanlines overlay
	_scanlines_overlay = _create_effect_overlay(SCANLINES_SHADER, "Scanlines")
	canvas.add_child(_scanlines_overlay)

	# Film grain overlay
	_film_grain_overlay = _create_effect_overlay(FILM_GRAIN_SHADER, "FilmGrain")
	canvas.add_child(_film_grain_overlay)

	# Heat distortion overlay
	_heat_overlay = _create_effect_overlay(HEAT_DISTORTION_SHADER, "HeatDistortion")
	canvas.add_child(_heat_overlay)


func _create_effect_overlay(shader_code: String, overlay_name: String) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = overlay_name
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = shader_code

	var mat := ShaderMaterial.new()
	mat.shader = shader

	overlay.material = mat
	overlay.visible = false

	return overlay


# ============================================================================
# SCREEN SHAKE
# ============================================================================

## Start screen shake effect
func shake_screen(intensity: float = 10.0, duration: float = 0.3, frequency: float = 30.0) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration
	_shake_frequency = frequency

	# Find camera if not set
	if not _target_camera:
		_target_camera = get_viewport().get_camera_2d()
		if _target_camera:
			_original_camera_offset = _target_camera.offset

	effect_started.emit("screen_shake")


## Heavy impact shake
func impact_shake() -> void:
	shake_screen(20.0, 0.2, 40.0)


## Light rumble shake
func rumble_shake() -> void:
	shake_screen(5.0, 0.5, 20.0)


## Explosion shake
func explosion_shake() -> void:
	shake_screen(30.0, 0.4, 50.0)


func _process_screen_shake(delta: float) -> void:
	if _shake_timer <= 0:
		return

	_shake_timer -= delta

	if _shake_timer <= 0:
		# Reset camera
		if _target_camera:
			_target_camera.offset = _original_camera_offset
		effect_completed.emit("screen_shake")
		return

	# Calculate shake offset
	var progress := _shake_timer / _shake_duration
	var decay := progress * progress  # Quadratic decay

	var offset := Vector2(
		sin(Time.get_ticks_msec() * _shake_frequency * 0.001) * _shake_intensity * decay,
		cos(Time.get_ticks_msec() * _shake_frequency * 0.001 * 1.3) * _shake_intensity * decay
	)

	if _target_camera:
		_target_camera.offset = _original_camera_offset + offset


## Set target camera for shake effects
func set_shake_camera(camera: Camera2D) -> void:
	_target_camera = camera
	if camera:
		_original_camera_offset = camera.offset


# ============================================================================
# SLOW MOTION
# ============================================================================

## Enter slow motion
func enter_slow_motion(time_scale: float = 0.3, transition_duration: float = 0.1) -> void:
	_original_time_scale = Engine.time_scale

	if _slow_mo_tween and _slow_mo_tween.is_valid():
		_slow_mo_tween.kill()

	_slow_mo_tween = create_tween()
	_slow_mo_tween.set_ease(Tween.EASE_OUT)
	_slow_mo_tween.set_trans(Tween.TRANS_EXPO)
	_slow_mo_tween.tween_method(_set_time_scale, Engine.time_scale, time_scale, transition_duration)

	effect_started.emit("slow_motion")


## Exit slow motion
func exit_slow_motion(transition_duration: float = 0.2) -> void:
	if _slow_mo_tween and _slow_mo_tween.is_valid():
		_slow_mo_tween.kill()

	_slow_mo_tween = create_tween()
	_slow_mo_tween.set_ease(Tween.EASE_IN)
	_slow_mo_tween.set_trans(Tween.TRANS_QUAD)
	_slow_mo_tween.tween_method(_set_time_scale, Engine.time_scale, 1.0, transition_duration)

	await _slow_mo_tween.finished
	effect_completed.emit("slow_motion")


## Pulse slow motion (slow then return)
func pulse_slow_motion(time_scale: float = 0.2, hold_duration: float = 0.3) -> void:
	await enter_slow_motion(time_scale, 0.05)
	await get_tree().create_timer(hold_duration * time_scale).timeout  # Account for time scale
	await exit_slow_motion(0.3)


func _set_time_scale(scale: float) -> void:
	Engine.time_scale = scale
	# Adjust audio pitch to match (optional)
	# AudioServer.playback_speed_scale = scale


# ============================================================================
# CHROMATIC ABERRATION
# ============================================================================

## Enable chromatic aberration effect
func enable_chromatic_aberration(intensity: float = 5.0, radial_blur: float = 0.0) -> void:
	var mat := _chromatic_overlay.material as ShaderMaterial
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("radial_blur", radial_blur)
	_chromatic_overlay.visible = true
	_active_effects["chromatic"] = true
	effect_started.emit("chromatic_aberration")


## Disable chromatic aberration
func disable_chromatic_aberration() -> void:
	_chromatic_overlay.visible = false
	_active_effects.erase("chromatic")
	effect_completed.emit("chromatic_aberration")


## Pulse chromatic aberration
func pulse_chromatic_aberration(max_intensity: float = 15.0, duration: float = 0.3) -> void:
	_chromatic_overlay.visible = true
	var mat := _chromatic_overlay.material as ShaderMaterial

	var tween := create_tween()
	tween.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, max_intensity, duration * 0.3)
	tween.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), max_intensity, 0.0, duration * 0.7)

	await tween.finished
	_chromatic_overlay.visible = false


## Impact effect combining shake and chromatic
func impact_effect() -> void:
	impact_shake()
	pulse_chromatic_aberration(20.0, 0.2)


# ============================================================================
# SCANLINES
# ============================================================================

## Enable scanlines effect
func enable_scanlines(intensity: float = 0.3, line_count: float = 400.0, scroll_speed: float = 0.0) -> void:
	var mat := _scanlines_overlay.material as ShaderMaterial
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("line_count", line_count)
	mat.set_shader_parameter("scroll_speed", scroll_speed)
	_scanlines_overlay.visible = true
	_active_effects["scanlines"] = true


## Disable scanlines
func disable_scanlines() -> void:
	_scanlines_overlay.visible = false
	_active_effects.erase("scanlines")


# ============================================================================
# FILM GRAIN
# ============================================================================

## Enable film grain + vignette
func enable_film_grain(grain_intensity: float = 0.1, vignette_intensity: float = 0.3) -> void:
	var mat := _film_grain_overlay.material as ShaderMaterial
	mat.set_shader_parameter("grain_intensity", grain_intensity)
	mat.set_shader_parameter("vignette_intensity", vignette_intensity)
	_film_grain_overlay.visible = true
	_active_effects["film_grain"] = true


## Disable film grain
func disable_film_grain() -> void:
	_film_grain_overlay.visible = false
	_active_effects.erase("film_grain")


# ============================================================================
# HEAT DISTORTION
# ============================================================================

## Enable heat distortion
func enable_heat_distortion(intensity: float = 0.01, speed: float = 2.0, scale: float = 10.0) -> void:
	var mat := _heat_overlay.material as ShaderMaterial
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("scale", scale)
	_heat_overlay.visible = true
	_active_effects["heat"] = true


## Disable heat distortion
func disable_heat_distortion() -> void:
	_heat_overlay.visible = false
	_active_effects.erase("heat")


# ============================================================================
# COMBINED EFFECTS
# ============================================================================

## Death effect: slow mo + desaturation
func death_effect() -> void:
	pulse_slow_motion(0.15, 0.5)
	pulse_chromatic_aberration(25.0, 0.4)


## Victory effect: quick time scale pulse
func victory_effect() -> void:
	pulse_slow_motion(0.5, 0.2)


## Damage taken effect
func damage_effect() -> void:
	shake_screen(8.0, 0.15, 35.0)
	pulse_chromatic_aberration(10.0, 0.15)


## Critical hit effect
func critical_hit_effect() -> void:
	shake_screen(15.0, 0.25, 45.0)
	pulse_slow_motion(0.3, 0.15)
	pulse_chromatic_aberration(15.0, 0.2)


## Enable cinematic mode (film grain + vignette)
func enable_cinematic_mode() -> void:
	enable_film_grain(0.08, 0.4)
	enable_scanlines(0.15, 500.0, 0.0)


## Disable cinematic mode
func disable_cinematic_mode() -> void:
	disable_film_grain()
	disable_scanlines()


# ============================================================================
# UTILITY
# ============================================================================

## Clear all active effects
func clear_all_effects() -> void:
	_chromatic_overlay.visible = false
	_scanlines_overlay.visible = false
	_film_grain_overlay.visible = false
	_heat_overlay.visible = false
	_active_effects.clear()

	# Reset time scale
	Engine.time_scale = 1.0

	# Reset camera shake
	_shake_timer = 0
	if _target_camera:
		_target_camera.offset = _original_camera_offset


## Check if effect is active
func is_effect_active(effect_name: String) -> bool:
	return _active_effects.has(effect_name)


## Get all active effects
func get_active_effects() -> Array:
	return _active_effects.keys()
