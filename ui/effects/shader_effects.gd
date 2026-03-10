## UIShaderEffects - Collection of shader-based visual effects for UI.
##
## Provides runtime shader effects that can be applied to any Control:
## - Wave distortion
## - Ripple effect
## - Glitch effect
## - Hologram shader
## - Outline glow
## - Color grading
## - Screen transitions
##
## Usage:
##   UIShaderEffects.apply_glow(control, Color.CYAN)
##   UIShaderEffects.ripple_at(control, click_position)
##   UIShaderEffects.glitch_burst(control, 0.5)
extends Node


# region - Enums

## Effect types
enum EffectType {
	WAVE,
	RIPPLE,
	GLITCH,
	HOLOGRAM,
	OUTLINE_GLOW,
	COLOR_GRADE,
	CHROMATIC_ABERRATION,
	PIXELATE,
	BLUR,
	VIGNETTE,
	SCANLINES,
	CRT,
}

# endregion


# region - Shader Code

## Wave distortion shader
const SHADER_WAVE := """
shader_type canvas_item;

uniform float amplitude : hint_range(0.0, 50.0) = 10.0;
uniform float frequency : hint_range(0.0, 10.0) = 2.0;
uniform float speed : hint_range(0.0, 10.0) = 3.0;
uniform vec2 direction = vec2(1.0, 0.0);

void fragment() {
	vec2 uv = UV;
	float wave = sin(dot(uv, direction) * frequency * 6.28318 + TIME * speed) * amplitude * 0.001;
	uv += direction * wave;
	COLOR = texture(TEXTURE, uv);
}
"""

## Ripple effect shader
const SHADER_RIPPLE := """
shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float ripple_radius : hint_range(0.0, 2.0) = 0.0;
uniform float ripple_width : hint_range(0.01, 0.5) = 0.1;
uniform float amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float decay : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	vec2 uv = UV;
	float dist = distance(uv, center);
	float ring = smoothstep(ripple_radius - ripple_width, ripple_radius, dist) *
				 smoothstep(ripple_radius + ripple_width, ripple_radius, dist);
	float wave = sin(dist * 30.0 - ripple_radius * 50.0) * amplitude * ring;
	wave *= exp(-decay * ripple_radius);
	uv += normalize(uv - center) * wave;
	COLOR = texture(TEXTURE, uv);
}
"""

## Glitch effect shader
const SHADER_GLITCH := """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float block_size : hint_range(1.0, 100.0) = 20.0;
uniform float color_offset : hint_range(0.0, 0.1) = 0.02;
uniform float time_scale : hint_range(0.0, 10.0) = 5.0;

float random(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float time = TIME * time_scale;

	// Block offset
	float block_y = floor(uv.y * block_size) / block_size;
	float noise = random(vec2(block_y, floor(time * 10.0)));

	if (noise < intensity * 0.3) {
		uv.x += (random(vec2(time, block_y)) - 0.5) * intensity * 0.2;
	}

	// Color channel separation
	float r = texture(TEXTURE, uv + vec2(color_offset * intensity, 0.0)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - vec2(color_offset * intensity, 0.0)).b;
	float a = texture(TEXTURE, uv).a;

	// Scanline noise
	float scanline = sin(uv.y * 800.0 + time * 10.0) * 0.04 * intensity;

	COLOR = vec4(r + scanline, g + scanline, b + scanline, a);
}
"""

## Hologram effect shader
const SHADER_HOLOGRAM := """
shader_type canvas_item;

uniform vec4 hologram_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float scanline_count : hint_range(10.0, 500.0) = 100.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float flicker_speed : hint_range(0.0, 20.0) = 8.0;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.1;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Convert to grayscale and apply hologram color
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 holo = hologram_color.rgb * gray;

	// Scanlines
	float scanline = sin(UV.y * scanline_count * 3.14159) * 0.5 + 0.5;
	scanline = mix(1.0, scanline, scanline_intensity);

	// Flicker
	float flicker = sin(TIME * flicker_speed) * 0.5 + 0.5;
	flicker = 1.0 - flicker_intensity + flicker * flicker_intensity;

	// Combine
	vec3 final_color = holo * scanline * flicker;
	final_color += hologram_color.rgb * glow_intensity * gray;

	COLOR = vec4(final_color, tex.a * hologram_color.a);
}
"""

## Outline glow shader
const SHADER_OUTLINE_GLOW := """
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_width : hint_range(0.0, 20.0) = 3.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform bool pulse_enabled = false;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 pixel_size = 1.0 / vec2(textureSize(TEXTURE, 0));

	float outline = 0.0;
	for (float x = -glow_width; x <= glow_width; x += 1.0) {
		for (float y = -glow_width; y <= glow_width; y += 1.0) {
			float dist = length(vec2(x, y));
			if (dist <= glow_width) {
				vec2 offset = vec2(x, y) * pixel_size;
				float sample_alpha = texture(TEXTURE, UV + offset).a;
				outline = max(outline, sample_alpha * (1.0 - dist / glow_width));
			}
		}
	}

	float pulse = pulse_enabled ? (sin(TIME * pulse_speed) * 0.3 + 0.7) : 1.0;
	vec4 glow = glow_color * outline * glow_intensity * pulse;

	// Blend glow behind the texture
	COLOR = mix(glow, tex, tex.a);
	COLOR.a = max(glow.a, tex.a);
}
"""

## Color grading shader
const SHADER_COLOR_GRADE := """
shader_type canvas_item;

uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform float saturation : hint_range(0.0, 3.0) = 1.0;
uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 color = tex.rgb;

	// Brightness
	color += brightness;

	// Contrast
	color = (color - 0.5) * contrast + 0.5;

	// Saturation and hue shift
	vec3 hsv = rgb_to_hsv(color);
	hsv.x = fract(hsv.x + hue_shift);
	hsv.y *= saturation;
	color = hsv_to_rgb(hsv);

	// Tint
	color = mix(color, color * tint_color.rgb, tint_strength);

	COLOR = vec4(clamp(color, 0.0, 1.0), tex.a);
}
"""

## Chromatic aberration shader
const SHADER_CHROMATIC := """
shader_type canvas_item;

uniform float offset : hint_range(0.0, 0.05) = 0.005;
uniform vec2 direction = vec2(1.0, 0.0);

void fragment() {
	vec2 dir = normalize(UV - vec2(0.5)) * offset;
	if (length(direction) > 0.0) {
		dir = direction * offset;
	}

	float r = texture(TEXTURE, UV + dir).r;
	float g = texture(TEXTURE, UV).g;
	float b = texture(TEXTURE, UV - dir).b;
	float a = texture(TEXTURE, UV).a;

	COLOR = vec4(r, g, b, a);
}
"""

## Pixelate shader
const SHADER_PIXELATE := """
shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 100.0) = 8.0;

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 uv = floor(UV * tex_size / pixel_size) * pixel_size / tex_size;
	COLOR = texture(TEXTURE, uv);
}
"""

## Blur shader
const SHADER_BLUR := """
shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 10.0) = 2.0;
uniform int samples : hint_range(3, 15) = 9;

void fragment() {
	vec2 pixel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
	vec4 color = vec4(0.0);
	float total = 0.0;

	for (int x = -samples / 2; x <= samples / 2; x++) {
		for (int y = -samples / 2; y <= samples / 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * pixel_size * blur_amount;
			float weight = 1.0 / (1.0 + length(vec2(x, y)));
			color += texture(TEXTURE, UV + offset) * weight;
			total += weight;
		}
	}

	COLOR = color / total;
}
"""

## Vignette shader
const SHADER_VIGNETTE := """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.4;
uniform float smoothness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 center = UV - vec2(0.5);
	float dist = length(center);
	float vignette = smoothstep(0.5 - smoothness * 0.5, 0.5 + smoothness * 0.5, dist * (1.0 + intensity));
	COLOR = mix(tex, vignette_color, vignette * intensity);
	COLOR.a = tex.a;
}
"""

## Scanlines shader
const SHADER_SCANLINES := """
shader_type canvas_item;

uniform float line_count : hint_range(10.0, 1000.0) = 200.0;
uniform float line_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float scroll_speed : hint_range(0.0, 10.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float scanline = sin((UV.y + TIME * scroll_speed * 0.1) * line_count * 3.14159);
	scanline = scanline * 0.5 + 0.5;
	scanline = 1.0 - scanline * line_intensity;
	COLOR = vec4(tex.rgb * scanline, tex.a);
}
"""

## CRT effect shader
const SHADER_CRT := """
shader_type canvas_item;

uniform float curvature : hint_range(0.0, 0.1) = 0.02;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float chromatic_offset : hint_range(0.0, 0.01) = 0.002;
uniform float noise_intensity : hint_range(0.0, 0.5) = 0.05;

float random(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Barrel distortion
	vec2 uv = UV - vec2(0.5);
	float dist = dot(uv, uv);
	uv *= 1.0 + dist * curvature;
	uv += vec2(0.5);

	// Check bounds
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
		return;
	}

	// Chromatic aberration
	float r = texture(TEXTURE, uv + vec2(chromatic_offset, 0.0)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - vec2(chromatic_offset, 0.0)).b;
	float a = texture(TEXTURE, uv).a;

	vec3 color = vec3(r, g, b);

	// Scanlines
	float scanline = sin(uv.y * 800.0) * 0.5 + 0.5;
	color *= 1.0 - scanline_intensity * (1.0 - scanline);

	// Vignette
	vec2 center = uv - vec2(0.5);
	float vignette = 1.0 - dot(center, center) * vignette_intensity * 4.0;
	color *= vignette;

	// Noise
	float noise = random(uv + TIME) * noise_intensity;
	color += noise;

	COLOR = vec4(color, a);
}
"""

# endregion


# region - State

## Cached shader resources
var _shaders: Dictionary = {}  ## EffectType -> Shader

## Active effects on controls
var _active_effects: Dictionary = {}  ## Control -> Dictionary{type, material, tween}

# endregion


# region - Lifecycle

func _ready() -> void:
	_compile_shaders()
	print("[UIShaderEffects] Shader effects system ready with %d effects" % _shaders.size())


func _compile_shaders() -> void:
	_shaders[EffectType.WAVE] = _create_shader(SHADER_WAVE)
	_shaders[EffectType.RIPPLE] = _create_shader(SHADER_RIPPLE)
	_shaders[EffectType.GLITCH] = _create_shader(SHADER_GLITCH)
	_shaders[EffectType.HOLOGRAM] = _create_shader(SHADER_HOLOGRAM)
	_shaders[EffectType.OUTLINE_GLOW] = _create_shader(SHADER_OUTLINE_GLOW)
	_shaders[EffectType.COLOR_GRADE] = _create_shader(SHADER_COLOR_GRADE)
	_shaders[EffectType.CHROMATIC_ABERRATION] = _create_shader(SHADER_CHROMATIC)
	_shaders[EffectType.PIXELATE] = _create_shader(SHADER_PIXELATE)
	_shaders[EffectType.BLUR] = _create_shader(SHADER_BLUR)
	_shaders[EffectType.VIGNETTE] = _create_shader(SHADER_VIGNETTE)
	_shaders[EffectType.SCANLINES] = _create_shader(SHADER_SCANLINES)
	_shaders[EffectType.CRT] = _create_shader(SHADER_CRT)


func _create_shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader

# endregion


# region - Wave Effect

## Applies a wave distortion effect
func apply_wave(
	control: Control,
	amplitude: float = 10.0,
	frequency: float = 2.0,
	speed: float = 3.0,
	direction: Vector2 = Vector2(1, 0)
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.WAVE)
	material.set_shader_parameter("amplitude", amplitude)
	material.set_shader_parameter("frequency", frequency)
	material.set_shader_parameter("speed", speed)
	material.set_shader_parameter("direction", direction)
	return material

# endregion


# region - Ripple Effect

## Creates a ripple effect at the specified position
func ripple_at(
	control: Control,
	position: Vector2,
	duration: float = 0.8,
	amplitude: float = 0.03
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.RIPPLE)

	# Convert position to UV coordinates
	var uv_pos := position / control.size
	material.set_shader_parameter("center", uv_pos)
	material.set_shader_parameter("amplitude", amplitude)
	material.set_shader_parameter("ripple_width", 0.15)
	material.set_shader_parameter("decay", 2.0)
	material.set_shader_parameter("ripple_radius", 0.0)

	# Animate the ripple
	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			material.set_shader_parameter("ripple_radius", value),
		0.0, 2.0, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	tween.finished.connect(func() -> void:
		remove_effect(control)
	)

	_store_effect(control, EffectType.RIPPLE, material, tween)

	return material

# endregion


# region - Glitch Effect

## Applies a glitch effect
func apply_glitch(
	control: Control,
	intensity: float = 0.5,
	block_size: float = 20.0
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.GLITCH)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("block_size", block_size)
	material.set_shader_parameter("color_offset", 0.02)
	material.set_shader_parameter("time_scale", 5.0)
	return material


## Creates a temporary glitch burst
func glitch_burst(
	control: Control,
	duration: float = 0.5,
	peak_intensity: float = 0.8
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.GLITCH)
	material.set_shader_parameter("block_size", 15.0)
	material.set_shader_parameter("time_scale", 8.0)

	# Animate intensity
	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			material.set_shader_parameter("intensity", value)
			material.set_shader_parameter("color_offset", value * 0.05),
		0.0, peak_intensity, duration * 0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

	tween.tween_method(
		func(value: float) -> void:
			material.set_shader_parameter("intensity", value)
			material.set_shader_parameter("color_offset", value * 0.05),
		peak_intensity, 0.0, duration * 0.7
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	tween.finished.connect(func() -> void:
		remove_effect(control)
	)

	_store_effect(control, EffectType.GLITCH, material, tween)

	return material

# endregion


# region - Hologram Effect

## Applies a hologram effect
func apply_hologram(
	control: Control,
	color: Color = Color.CYAN,
	scanline_count: float = 100.0,
	flicker_intensity: float = 0.1
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.HOLOGRAM)
	material.set_shader_parameter("hologram_color", color)
	material.set_shader_parameter("scanline_count", scanline_count)
	material.set_shader_parameter("scanline_intensity", 0.3)
	material.set_shader_parameter("flicker_speed", 8.0)
	material.set_shader_parameter("flicker_intensity", flicker_intensity)
	material.set_shader_parameter("glow_intensity", 0.5)
	return material

# endregion


# region - Outline Glow Effect

## Applies an outline glow effect
func apply_glow(
	control: Control,
	color: Color = Color.WHITE,
	width: float = 3.0,
	intensity: float = 2.0,
	pulse: bool = false
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.OUTLINE_GLOW)
	material.set_shader_parameter("glow_color", color)
	material.set_shader_parameter("glow_width", width)
	material.set_shader_parameter("glow_intensity", intensity)
	material.set_shader_parameter("pulse_enabled", pulse)
	material.set_shader_parameter("pulse_speed", 2.0)
	return material


## Animates glow intensity
func pulse_glow(
	control: Control,
	color: Color = Color.WHITE,
	duration: float = 0.5
) -> ShaderMaterial:
	var material := apply_glow(control, color, 5.0, 0.0, false)

	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			material.set_shader_parameter("glow_intensity", value),
		0.0, 3.0, duration * 0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	tween.tween_method(
		func(value: float) -> void:
			material.set_shader_parameter("glow_intensity", value),
		3.0, 0.0, duration * 0.7
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	tween.finished.connect(func() -> void:
		remove_effect(control)
	)

	_store_effect(control, EffectType.OUTLINE_GLOW, material, tween)

	return material

# endregion


# region - Color Grading

## Applies color grading
func apply_color_grade(
	control: Control,
	brightness: float = 0.0,
	contrast: float = 1.0,
	saturation: float = 1.0,
	hue_shift: float = 0.0,
	tint: Color = Color.WHITE,
	tint_strength: float = 0.0
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.COLOR_GRADE)
	material.set_shader_parameter("brightness", brightness)
	material.set_shader_parameter("contrast", contrast)
	material.set_shader_parameter("saturation", saturation)
	material.set_shader_parameter("hue_shift", hue_shift)
	material.set_shader_parameter("tint_color", tint)
	material.set_shader_parameter("tint_strength", tint_strength)
	return material


## Applies a desaturation effect (grayscale)
func desaturate(control: Control, amount: float = 1.0) -> ShaderMaterial:
	return apply_color_grade(control, 0.0, 1.0, 1.0 - amount)


## Applies sepia tone
func apply_sepia(control: Control, strength: float = 0.8) -> ShaderMaterial:
	return apply_color_grade(control, 0.0, 1.0, 0.5, 0.05, Color(1.0, 0.9, 0.7), strength)

# endregion


# region - Chromatic Aberration

## Applies chromatic aberration
func apply_chromatic_aberration(
	control: Control,
	offset: float = 0.005,
	direction: Vector2 = Vector2.ZERO
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.CHROMATIC_ABERRATION)
	material.set_shader_parameter("offset", offset)
	material.set_shader_parameter("direction", direction)
	return material

# endregion


# region - Pixelate Effect

## Applies pixelation effect
func apply_pixelate(control: Control, pixel_size: float = 8.0) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.PIXELATE)
	material.set_shader_parameter("pixel_size", pixel_size)
	return material


## Animates pixelation (for transitions)
func pixelate_transition(
	control: Control,
	duration: float = 0.5,
	max_pixel_size: float = 32.0,
	fade_out: bool = true
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.PIXELATE)

	var tween := create_tween()

	if fade_out:
		# Pixelate out
		tween.tween_method(
			func(value: float) -> void:
				material.set_shader_parameter("pixel_size", value),
			1.0, max_pixel_size, duration
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	else:
		# Pixelate in
		tween.tween_method(
			func(value: float) -> void:
				material.set_shader_parameter("pixel_size", value),
			max_pixel_size, 1.0, duration
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		tween.finished.connect(func() -> void:
			remove_effect(control)
		)

	_store_effect(control, EffectType.PIXELATE, material, tween)

	return material

# endregion


# region - Blur Effect

## Applies blur effect
func apply_blur(control: Control, amount: float = 2.0) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.BLUR)
	material.set_shader_parameter("blur_amount", amount)
	material.set_shader_parameter("samples", 9)
	return material


## Animates blur (focus effect)
func blur_transition(
	control: Control,
	duration: float = 0.3,
	target_blur: float = 5.0,
	blur_in: bool = true
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.BLUR)

	var start_blur: float = 0.0 if blur_in else target_blur
	var end_blur: float = target_blur if blur_in else 0.0

	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			material.set_shader_parameter("blur_amount", value),
		start_blur, end_blur, duration
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	if not blur_in:
		tween.finished.connect(func() -> void:
			remove_effect(control)
		)

	_store_effect(control, EffectType.BLUR, material, tween)

	return material

# endregion


# region - Vignette Effect

## Applies vignette effect
func apply_vignette(
	control: Control,
	intensity: float = 0.4,
	smoothness: float = 0.5,
	color: Color = Color.BLACK
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.VIGNETTE)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("smoothness", smoothness)
	material.set_shader_parameter("vignette_color", color)
	return material

# endregion


# region - Scanlines Effect

## Applies scanlines effect
func apply_scanlines(
	control: Control,
	line_count: float = 200.0,
	intensity: float = 0.2,
	scroll_speed: float = 0.0
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.SCANLINES)
	material.set_shader_parameter("line_count", line_count)
	material.set_shader_parameter("line_intensity", intensity)
	material.set_shader_parameter("scroll_speed", scroll_speed)
	return material

# endregion


# region - CRT Effect

## Applies full CRT effect
func apply_crt(
	control: Control,
	curvature: float = 0.02,
	scanline_intensity: float = 0.2,
	noise: float = 0.05
) -> ShaderMaterial:
	var material := _apply_effect(control, EffectType.CRT)
	material.set_shader_parameter("curvature", curvature)
	material.set_shader_parameter("scanline_intensity", scanline_intensity)
	material.set_shader_parameter("vignette_intensity", 0.3)
	material.set_shader_parameter("chromatic_offset", 0.002)
	material.set_shader_parameter("noise_intensity", noise)
	return material

# endregion


# region - Effect Management

## Removes any shader effect from a control
func remove_effect(control: Control) -> void:
	if not is_instance_valid(control):
		return

	control.material = null

	if _active_effects.has(control):
		var effect_data: Dictionary = _active_effects[control]
		if effect_data.has("tween") and effect_data["tween"] is Tween:
			var tween: Tween = effect_data["tween"]
			if tween.is_valid():
				tween.kill()
		_active_effects.erase(control)


## Checks if a control has an active effect
func has_effect(control: Control) -> bool:
	return _active_effects.has(control)


## Gets the current effect type on a control
func get_effect_type(control: Control) -> int:
	if _active_effects.has(control):
		return _active_effects[control].get("type", -1)
	return -1


## Removes all active effects
func remove_all_effects() -> void:
	for control: Control in _active_effects.keys():
		remove_effect(control)


func _apply_effect(control: Control, effect_type: int) -> ShaderMaterial:
	# Remove existing effect if any
	remove_effect(control)

	if not _shaders.has(effect_type):
		push_warning("UIShaderEffects: Unknown effect type %d" % effect_type)
		return null

	var material := ShaderMaterial.new()
	material.shader = _shaders[effect_type]
	control.material = material

	return material


func _store_effect(control: Control, effect_type: int, material: ShaderMaterial, tween: Tween = null) -> void:
	_active_effects[control] = {
		"type": effect_type,
		"material": material,
		"tween": tween,
	}

# endregion
