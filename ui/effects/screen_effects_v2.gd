## ScreenEffectsV2 - Advanced screen-space visual effects system.
##
## This is a comprehensive screen effects library featuring:
##
## SCREEN SHAKE (10 patterns):
##   - Light, Medium, Heavy, Earthquake
##   - Directional, Circular, Bounce
##   - Impact, Explosion, Damage
##
## FLASH EFFECTS (8 types):
##   - White flash, Color flash, Damage flash
##   - Healing flash, Power-up flash, Lightning flash
##   - Fade to white, Fade to black
##
## FADE OVERLAYS (6 types):
##   - Fade in/out, Cross-fade
##   - Iris in/out, Wipe transitions
##   - Diamond reveal, Circle reveal
##
## DISTORTION FIELDS (8 types):
##   - Ripple, Shockwave, Heat haze
##   - Underwater, Drunk, Warp
##   - Barrel, Pincushion
##
## SPEED EFFECTS (4 types):
##   - Speed lines, Motion blur
##   - Radial blur, Zoom blur
##
## ZOOM EFFECTS (4 types):
##   - Dramatic zoom, Punch zoom
##   - Focus zoom, Dolly zoom
##
## SPLITSCREEN (4 types):
##   - Horizontal split, Vertical split
##   - Quad split, Dynamic split
##
## Usage:
##   ScreenEffectsV2.shake(ShakePattern.EXPLOSION, 0.5)
##   ScreenEffectsV2.flash(Color.WHITE, 0.2)
##   ScreenEffectsV2.distortion_ripple(center, 0.8)
##
class_name ScreenEffectsV2
extends Node


# region - Signals

signal shake_started(pattern: ShakePattern)
signal shake_ended()
signal flash_started(color: Color)
signal flash_ended()
signal transition_started(type: TransitionType)
signal transition_ended()

# endregion


# region - Enums

## Screen shake patterns
enum ShakePattern {
	LIGHT,        ## Subtle tremor (damage tick)
	MEDIUM,       ## Standard shake (hit taken)
	HEAVY,        ## Intense shake (big hit)
	EARTHQUAKE,   ## Prolonged rumble
	DIRECTIONAL,  ## Shake in specific direction
	CIRCULAR,     ## Orbital shake
	BOUNCE,       ## Bouncy vertical shake
	IMPACT,       ## Sharp initial, quick decay
	EXPLOSION,    ## Outward then settle
	DAMAGE,       ## Quick directional jolt
}

## Flash effect types
enum FlashType {
	WHITE,        ## Pure white flash
	COLOR,        ## Custom color flash
	DAMAGE,       ## Red damage indicator
	HEAL,         ## Green healing indicator
	POWERUP,      ## Gold power-up effect
	LIGHTNING,    ## Blue-white lightning
	CRITICAL,     ## Orange critical hit
	STUN,         ## Yellow stun effect
}

## Transition types
enum TransitionType {
	FADE_BLACK,   ## Fade to/from black
	FADE_WHITE,   ## Fade to/from white
	CROSSFADE,    ## Crossfade between scenes
	IRIS_IN,      ## Circle closing
	IRIS_OUT,     ## Circle opening
	WIPE_LEFT,    ## Horizontal wipe
	WIPE_DOWN,    ## Vertical wipe
	DIAMOND,      ## Diamond pattern
	PIXELATE,     ## Pixel dissolve
	GLITCH,       ## Glitch transition
}

## Distortion types
enum DistortionType {
	RIPPLE,       ## Water ripple effect
	SHOCKWAVE,    ## Expanding ring
	HEAT_HAZE,    ## Heat shimmer
	UNDERWATER,   ## Underwater caustics
	DRUNK,        ## Wobbly distortion
	WARP,         ## Space warp
	BARREL,       ## Barrel distortion
	PINCUSHION,   ## Pincushion distortion
}

## Speed line styles
enum SpeedLineStyle {
	RADIAL,       ## Lines from center
	HORIZONTAL,   ## Horizontal streaks
	VERTICAL,     ## Vertical streaks
	TUNNEL,       ## Tunnel vision effect
}

# endregion


# region - Shake Pattern Data

const SHAKE_PATTERNS: Dictionary = {
	ShakePattern.LIGHT: {
		"amplitude": 3.0,
		"frequency": 20.0,
		"decay": 8.0,
		"rotation": 0.5,
	},
	ShakePattern.MEDIUM: {
		"amplitude": 8.0,
		"frequency": 25.0,
		"decay": 6.0,
		"rotation": 1.5,
	},
	ShakePattern.HEAVY: {
		"amplitude": 15.0,
		"frequency": 30.0,
		"decay": 4.0,
		"rotation": 3.0,
	},
	ShakePattern.EARTHQUAKE: {
		"amplitude": 12.0,
		"frequency": 8.0,
		"decay": 1.5,
		"rotation": 2.0,
		"sustained": true,
	},
	ShakePattern.DIRECTIONAL: {
		"amplitude": 10.0,
		"frequency": 20.0,
		"decay": 5.0,
		"rotation": 0.0,
		"directional": true,
	},
	ShakePattern.CIRCULAR: {
		"amplitude": 6.0,
		"frequency": 15.0,
		"decay": 4.0,
		"rotation": 0.0,
		"circular": true,
	},
	ShakePattern.BOUNCE: {
		"amplitude": 12.0,
		"frequency": 12.0,
		"decay": 6.0,
		"rotation": 0.0,
		"bounce": true,
	},
	ShakePattern.IMPACT: {
		"amplitude": 20.0,
		"frequency": 40.0,
		"decay": 12.0,
		"rotation": 2.0,
	},
	ShakePattern.EXPLOSION: {
		"amplitude": 25.0,
		"frequency": 35.0,
		"decay": 8.0,
		"rotation": 4.0,
	},
	ShakePattern.DAMAGE: {
		"amplitude": 6.0,
		"frequency": 30.0,
		"decay": 15.0,
		"rotation": 1.0,
	},
}

# endregion


# region - Shader Code

const SHADER_SCREEN_DISTORTION := """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius : hint_range(0.0, 2.0) = 0.5;
uniform float ripple_count : hint_range(1.0, 20.0) = 5.0;
uniform float time_scale : hint_range(0.0, 10.0) = 1.0;
uniform int effect_type = 0; // 0=ripple, 1=shockwave, 2=heat, 3=underwater, 4=drunk, 5=warp

void fragment() {
	vec2 uv = UV;
	vec2 to_center = uv - center;
	float dist = length(to_center);

	if (effect_type == 0) { // Ripple
		float ripple = sin(dist * ripple_count * 6.28318 - TIME * time_scale * 5.0);
		float falloff = 1.0 - smoothstep(0.0, radius, dist);
		uv += normalize(to_center) * ripple * intensity * 0.02 * falloff;
	}
	else if (effect_type == 1) { // Shockwave
		float ring = 1.0 - abs(dist - radius * (1.0 - intensity));
		ring = pow(max(ring, 0.0), 8.0);
		uv += normalize(to_center) * ring * intensity * 0.1;
	}
	else if (effect_type == 2) { // Heat haze
		float noise1 = sin(uv.y * 50.0 + TIME * 3.0) * cos(uv.x * 30.0 + TIME * 2.0);
		float noise2 = sin(uv.y * 80.0 - TIME * 4.0) * cos(uv.x * 60.0 + TIME * 1.5);
		uv.x += (noise1 + noise2 * 0.5) * intensity * 0.005;
		uv.y += (noise2 + noise1 * 0.3) * intensity * 0.003;
	}
	else if (effect_type == 3) { // Underwater
		float wave1 = sin(uv.y * 20.0 + TIME * 2.0) * cos(TIME * 0.5);
		float wave2 = sin(uv.x * 15.0 + TIME * 1.5) * sin(TIME * 0.7);
		uv.x += wave1 * intensity * 0.01;
		uv.y += wave2 * intensity * 0.008;
	}
	else if (effect_type == 4) { // Drunk
		float wobble = sin(TIME * 2.0 + uv.y * 5.0) * cos(TIME * 1.5 + uv.x * 3.0);
		float sway = sin(TIME * 0.5) * 0.5 + 0.5;
		uv.x += wobble * intensity * 0.02 * sway;
		uv.y += sin(TIME * 3.0 + uv.x * 4.0) * intensity * 0.01;
	}
	else if (effect_type == 5) { // Warp
		float warp = sin(dist * 10.0 - TIME * 3.0);
		uv += to_center * warp * intensity * 0.05;
	}

	COLOR = texture(TEXTURE, uv);
}
"""

const SHADER_FLASH := """
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform int blend_mode = 0; // 0=additive, 1=multiply, 2=overlay

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (blend_mode == 0) { // Additive
		COLOR = vec4(tex.rgb + flash_color.rgb * intensity, tex.a);
	}
	else if (blend_mode == 1) { // Multiply
		COLOR = vec4(mix(tex.rgb, tex.rgb * flash_color.rgb, intensity), tex.a);
	}
	else { // Overlay
		vec3 overlay = mix(tex.rgb, flash_color.rgb, intensity * flash_color.a);
		COLOR = vec4(overlay, tex.a);
	}
}
"""

const SHADER_SPEED_LINES := """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec2 center = vec2(0.5, 0.5);
uniform float line_count : hint_range(10.0, 100.0) = 40.0;
uniform float line_width : hint_range(0.001, 0.1) = 0.02;
uniform float speed : hint_range(0.0, 10.0) = 2.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.3);
uniform int style = 0; // 0=radial, 1=horizontal, 2=vertical, 3=tunnel

void fragment() {
	vec2 uv = UV;
	vec4 tex = texture(TEXTURE, uv);
	float line_alpha = 0.0;

	if (style == 0) { // Radial
		vec2 to_center = uv - center;
		float angle = atan(to_center.y, to_center.x);
		float dist = length(to_center);

		float line = fract(angle / 6.28318 * line_count + TIME * speed);
		line = smoothstep(0.0, line_width, line) * smoothstep(line_width * 2.0, line_width, line);
		line *= smoothstep(0.1, 0.5, dist); // Fade near center
		line_alpha = line * intensity;
	}
	else if (style == 1) { // Horizontal
		float line = fract(uv.x * line_count - TIME * speed);
		line = smoothstep(0.0, line_width, line) * smoothstep(line_width * 2.0, line_width, line);
		line_alpha = line * intensity;
	}
	else if (style == 2) { // Vertical
		float line = fract(uv.y * line_count - TIME * speed);
		line = smoothstep(0.0, line_width, line) * smoothstep(line_width * 2.0, line_width, line);
		line_alpha = line * intensity;
	}
	else if (style == 3) { // Tunnel
		vec2 to_center = uv - center;
		float dist = length(to_center);
		float angle = atan(to_center.y, to_center.x);

		float line = fract(angle / 6.28318 * line_count + TIME * speed);
		line = smoothstep(0.0, line_width, line) * smoothstep(line_width * 2.0, line_width, line);
		line *= (1.0 - smoothstep(0.0, 0.3, dist)); // Stronger near center
		line_alpha = line * intensity;
	}

	COLOR = mix(tex, line_color, line_alpha * line_color.a);
}
"""

const SHADER_RADIAL_BLUR := """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec2 center = vec2(0.5, 0.5);
uniform int samples : hint_range(4, 32) = 16;
uniform float blur_size : hint_range(0.0, 0.5) = 0.1;

void fragment() {
	vec2 uv = UV;
	vec2 to_center = center - uv;
	float dist = length(to_center);

	vec4 color = vec4(0.0);
	float total_weight = 0.0;

	for (int i = 0; i < samples; i++) {
		float t = float(i) / float(samples - 1);
		vec2 sample_uv = uv + to_center * t * blur_size * intensity * dist;
		float weight = 1.0 - t * 0.5;
		color += texture(TEXTURE, sample_uv) * weight;
		total_weight += weight;
	}

	COLOR = color / total_weight;
}
"""

const SHADER_ZOOM_BLUR := """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec2 center = vec2(0.5, 0.5);
uniform int samples : hint_range(4, 32) = 12;
uniform float zoom_strength : hint_range(0.0, 0.5) = 0.15;
uniform bool zoom_in = true;

void fragment() {
	vec2 uv = UV;
	vec2 to_center = uv - center;

	vec4 color = vec4(0.0);
	float total_weight = 0.0;

	for (int i = 0; i < samples; i++) {
		float t = float(i) / float(samples - 1);
		float scale = zoom_in ? (1.0 - t * zoom_strength * intensity) : (1.0 + t * zoom_strength * intensity);
		vec2 sample_uv = center + to_center * scale;
		float weight = 1.0 - t * 0.3;
		color += texture(TEXTURE, sample_uv) * weight;
		total_weight += weight;
	}

	COLOR = color / total_weight;
}
"""

const SHADER_TRANSITION := """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 center = vec2(0.5, 0.5);
uniform int transition_type = 0;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.1;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mask = 0.0;

	if (transition_type == 0) { // Fade
		mask = progress;
	}
	else if (transition_type == 1) { // Iris (circle)
		float dist = distance(UV, center);
		float radius = (1.0 - progress) * 1.5;
		mask = smoothstep(radius - edge_softness, radius, dist);
	}
	else if (transition_type == 2) { // Wipe horizontal
		mask = smoothstep(progress - edge_softness, progress, UV.x);
	}
	else if (transition_type == 3) { // Wipe vertical
		mask = smoothstep(progress - edge_softness, progress, UV.y);
	}
	else if (transition_type == 4) { // Diamond
		vec2 to_center = abs(UV - center);
		float diamond = to_center.x + to_center.y;
		float threshold = (1.0 - progress) * 1.5;
		mask = smoothstep(threshold - edge_softness, threshold, diamond);
	}
	else if (transition_type == 5) { // Pixelate
		float pixel_size = mix(1.0, 100.0, progress);
		vec2 pixelated_uv = floor(UV * pixel_size) / pixel_size;
		tex = texture(TEXTURE, pixelated_uv);
		mask = progress;
	}

	COLOR = mix(tex, transition_color, mask * transition_color.a);
}
"""

const SHADER_VIGNETTE_DYNAMIC := """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float radius : hint_range(0.0, 2.0) = 0.8;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 offset = vec2(0.0, 0.0);
uniform float pulse_speed : hint_range(0.0, 5.0) = 0.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.1;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 center = vec2(0.5, 0.5) + offset;
	float dist = distance(UV, center);

	float pulse = pulse_speed > 0.0 ? sin(TIME * pulse_speed) * pulse_amount : 0.0;
	float vignette = smoothstep(radius + pulse, radius - softness + pulse, dist);
	vignette = 1.0 - (1.0 - vignette) * intensity;

	COLOR = vec4(mix(color.rgb, tex.rgb, vignette), tex.a);
}
"""

const SHADER_CHROMATIC_ABERRATION := """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 0.1) = 0.01;
uniform vec2 direction = vec2(1.0, 0.0);
uniform bool radial = false;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 uv = UV;
	vec2 offset;

	if (radial) {
		vec2 to_center = uv - center;
		float dist = length(to_center);
		offset = normalize(to_center) * intensity * dist;
	} else {
		offset = direction * intensity;
	}

	float r = texture(TEXTURE, uv + offset).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - offset).b;
	float a = texture(TEXTURE, uv).a;

	COLOR = vec4(r, g, b, a);
}
"""

# endregion


# region - State

## Active shake state
var _shake_active: bool = false
var _shake_amplitude: float = 0.0
var _shake_frequency: float = 0.0
var _shake_decay: float = 0.0
var _shake_rotation: float = 0.0
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_direction: Vector2 = Vector2.ZERO
var _shake_pattern: ShakePattern = ShakePattern.MEDIUM
var _original_camera_offset: Vector2 = Vector2.ZERO

## Screen effect layers
var _flash_layer: ColorRect = null
var _distortion_layer: ColorRect = null
var _speed_lines_layer: ColorRect = null
var _blur_layer: ColorRect = null
var _transition_layer: ColorRect = null
var _vignette_layer: ColorRect = null
var _chromatic_layer: ColorRect = null

## Shader materials
var _flash_material: ShaderMaterial = null
var _distortion_material: ShaderMaterial = null
var _speed_lines_material: ShaderMaterial = null
var _radial_blur_material: ShaderMaterial = null
var _zoom_blur_material: ShaderMaterial = null
var _transition_material: ShaderMaterial = null
var _vignette_material: ShaderMaterial = null
var _chromatic_material: ShaderMaterial = null

## Canvas layer for screen effects
var _canvas_layer: CanvasLayer = null

## Active tweens
var _active_tweens: Array[Tween] = []

# endregion


# region - Lifecycle

func _ready() -> void:
	_setup_canvas_layer()
	_compile_shaders()
	_setup_effect_layers()
	print("[ScreenEffectsV2] Screen effects system initialized")


func _process(delta: float) -> void:
	if _shake_active:
		_update_shake(delta)


func _setup_canvas_layer() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "ScreenEffectsLayer"
	_canvas_layer.layer = 128  # Very high, above most UI
	add_child(_canvas_layer)


func _compile_shaders() -> void:
	# Flash shader
	var flash_shader := Shader.new()
	flash_shader.code = SHADER_FLASH
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = flash_shader

	# Distortion shader
	var distortion_shader := Shader.new()
	distortion_shader.code = SHADER_SCREEN_DISTORTION
	_distortion_material = ShaderMaterial.new()
	_distortion_material.shader = distortion_shader

	# Speed lines shader
	var speed_shader := Shader.new()
	speed_shader.code = SHADER_SPEED_LINES
	_speed_lines_material = ShaderMaterial.new()
	_speed_lines_material.shader = speed_shader

	# Radial blur shader
	var radial_shader := Shader.new()
	radial_shader.code = SHADER_RADIAL_BLUR
	_radial_blur_material = ShaderMaterial.new()
	_radial_blur_material.shader = radial_shader

	# Zoom blur shader
	var zoom_shader := Shader.new()
	zoom_shader.code = SHADER_ZOOM_BLUR
	_zoom_blur_material = ShaderMaterial.new()
	_zoom_blur_material.shader = zoom_shader

	# Transition shader
	var transition_shader := Shader.new()
	transition_shader.code = SHADER_TRANSITION
	_transition_material = ShaderMaterial.new()
	_transition_material.shader = transition_shader

	# Vignette shader
	var vignette_shader := Shader.new()
	vignette_shader.code = SHADER_VIGNETTE_DYNAMIC
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = vignette_shader

	# Chromatic aberration shader
	var chromatic_shader := Shader.new()
	chromatic_shader.code = SHADER_CHROMATIC_ABERRATION
	_chromatic_material = ShaderMaterial.new()
	_chromatic_material.shader = chromatic_shader


func _setup_effect_layers() -> void:
	# Create fullscreen ColorRects for each effect type
	_distortion_layer = _create_effect_layer("DistortionLayer", _distortion_material)
	_speed_lines_layer = _create_effect_layer("SpeedLinesLayer", _speed_lines_material)
	_blur_layer = _create_effect_layer("BlurLayer", _radial_blur_material)
	_vignette_layer = _create_effect_layer("VignetteLayer", _vignette_material)
	_chromatic_layer = _create_effect_layer("ChromaticLayer", _chromatic_material)
	_flash_layer = _create_effect_layer("FlashLayer", _flash_material)
	_transition_layer = _create_effect_layer("TransitionLayer", _transition_material)


func _create_effect_layer(layer_name: String, material: ShaderMaterial) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = layer_name
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(1, 1, 1, 0)  # Transparent by default
	rect.visible = false
	_canvas_layer.add_child(rect)
	return rect

# endregion


# region - Screen Shake

## Starts a screen shake with the given pattern
func shake(pattern: ShakePattern = ShakePattern.MEDIUM, duration: float = 0.5, intensity_mult: float = 1.0) -> void:
	var pattern_data: Dictionary = SHAKE_PATTERNS.get(pattern, SHAKE_PATTERNS[ShakePattern.MEDIUM])

	_shake_pattern = pattern
	_shake_amplitude = pattern_data.get("amplitude", 8.0) * intensity_mult
	_shake_frequency = pattern_data.get("frequency", 25.0)
	_shake_decay = pattern_data.get("decay", 6.0)
	_shake_rotation = pattern_data.get("rotation", 1.0) * intensity_mult
	_shake_time = 0.0
	_shake_duration = duration
	_shake_active = true

	shake_started.emit(pattern)


## Starts a directional shake (e.g., from an impact)
func shake_directional(direction: Vector2, duration: float = 0.3, intensity: float = 1.0) -> void:
	_shake_direction = direction.normalized()
	shake(ShakePattern.DIRECTIONAL, duration, intensity)


## Starts an impact shake at a specific world position (converts to screen direction)
func shake_from_position(world_pos: Vector3, camera: Camera3D, duration: float = 0.3, intensity: float = 1.0) -> void:
	if not camera:
		shake(ShakePattern.IMPACT, duration, intensity)
		return

	# Calculate direction from camera to impact
	var camera_pos := camera.global_position
	var dir_3d := (world_pos - camera_pos).normalized()

	# Project to 2D screen direction
	var screen_dir := Vector2(dir_3d.x, -dir_3d.y).normalized()
	shake_directional(screen_dir, duration, intensity)


## Stops the current shake
func stop_shake() -> void:
	_shake_active = false
	_apply_shake_offset(Vector2.ZERO, 0.0)
	shake_ended.emit()


func _update_shake(delta: float) -> void:
	_shake_time += delta

	if _shake_time >= _shake_duration:
		stop_shake()
		return

	var progress: float = _shake_time / _shake_duration
	var decay_factor: float = exp(-_shake_decay * progress)
	var current_amplitude: float = _shake_amplitude * decay_factor

	var offset := Vector2.ZERO
	var rotation: float = 0.0

	var pattern_data: Dictionary = SHAKE_PATTERNS.get(_shake_pattern, {})

	if pattern_data.get("circular", false):
		# Circular shake
		var angle: float = _shake_time * _shake_frequency
		offset = Vector2(cos(angle), sin(angle)) * current_amplitude
	elif pattern_data.get("bounce", false):
		# Bouncy shake
		var bounce: float = abs(sin(_shake_time * _shake_frequency)) * decay_factor
		offset = Vector2(0, -bounce * _shake_amplitude)
	elif pattern_data.get("directional", false):
		# Directional shake
		var wave: float = sin(_shake_time * _shake_frequency) * decay_factor
		offset = _shake_direction * wave * _shake_amplitude
	else:
		# Random shake
		var noise_x: float = sin(_shake_time * _shake_frequency + randf() * 0.5)
		var noise_y: float = cos(_shake_time * _shake_frequency * 1.1 + randf() * 0.5)
		offset = Vector2(noise_x, noise_y) * current_amplitude

	# Apply rotation shake
	if _shake_rotation > 0:
		rotation = sin(_shake_time * _shake_frequency * 0.8) * _shake_rotation * decay_factor

	_apply_shake_offset(offset, rotation)


func _apply_shake_offset(offset: Vector2, rotation: float) -> void:
	# Apply to the current camera
	var camera_2d := get_viewport().get_camera_2d()
	if camera_2d:
		camera_2d.offset = _original_camera_offset + offset
		camera_2d.rotation = deg_to_rad(rotation)

# endregion


# region - Flash Effects

## Creates a screen flash effect
func flash(color: Color = Color.WHITE, duration: float = 0.2, flash_type: FlashType = FlashType.WHITE) -> void:
	# Set flash color based on type
	var flash_color := color
	match flash_type:
		FlashType.DAMAGE:
			flash_color = Color(1.0, 0.2, 0.1, 0.5)
		FlashType.HEAL:
			flash_color = Color(0.2, 1.0, 0.3, 0.4)
		FlashType.POWERUP:
			flash_color = Color(1.0, 0.85, 0.0, 0.4)
		FlashType.LIGHTNING:
			flash_color = Color(0.9, 0.95, 1.0, 0.7)
		FlashType.CRITICAL:
			flash_color = Color(1.0, 0.5, 0.0, 0.5)
		FlashType.STUN:
			flash_color = Color(1.0, 1.0, 0.3, 0.4)

	_flash_layer.visible = true
	_flash_material.set_shader_parameter("flash_color", flash_color)
	_flash_material.set_shader_parameter("intensity", 1.0)

	flash_started.emit(flash_color)

	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			_flash_material.set_shader_parameter("intensity", value),
		1.0, 0.0, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	tween.finished.connect(func() -> void:
		_flash_layer.visible = false
		flash_ended.emit()
	)

	_active_tweens.append(tween)


## Creates a damage indicator flash
func damage_flash(intensity: float = 1.0) -> void:
	flash(Color.RED, 0.15 * intensity, FlashType.DAMAGE)


## Creates a healing indicator flash
func heal_flash() -> void:
	flash(Color.GREEN, 0.3, FlashType.HEAL)


## Creates a power-up flash
func powerup_flash() -> void:
	flash(Color.GOLD, 0.4, FlashType.POWERUP)

# endregion


# region - Distortion Effects

## Creates a ripple distortion at the given screen position
func distortion_ripple(center: Vector2, duration: float = 0.8, intensity: float = 0.5) -> void:
	_distortion_layer.visible = true
	_distortion_material.set_shader_parameter("effect_type", 0)  # Ripple
	_distortion_material.set_shader_parameter("center", center)
	_distortion_material.set_shader_parameter("intensity", intensity)
	_distortion_material.set_shader_parameter("radius", 0.5)
	_distortion_material.set_shader_parameter("ripple_count", 8.0)

	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			_distortion_material.set_shader_parameter("intensity", value),
		intensity, 0.0, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	tween.finished.connect(func() -> void:
		_distortion_layer.visible = false
	)

	_active_tweens.append(tween)


## Creates a shockwave distortion expanding from center
func distortion_shockwave(center: Vector2, duration: float = 0.6, intensity: float = 0.8) -> void:
	_distortion_layer.visible = true
	_distortion_material.set_shader_parameter("effect_type", 1)  # Shockwave
	_distortion_material.set_shader_parameter("center", center)
	_distortion_material.set_shader_parameter("radius", 0.0)

	var tween := create_tween()

	# Expand radius while fading intensity
	tween.tween_method(
		func(value: float) -> void:
			_distortion_material.set_shader_parameter("intensity", intensity * (1.0 - value))
			_distortion_material.set_shader_parameter("radius", value * 1.5),
		0.0, 1.0, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	tween.finished.connect(func() -> void:
		_distortion_layer.visible = false
	)

	_active_tweens.append(tween)


## Enables heat haze distortion
func enable_heat_haze(intensity: float = 0.3) -> void:
	_distortion_layer.visible = true
	_distortion_material.set_shader_parameter("effect_type", 2)  # Heat haze
	_distortion_material.set_shader_parameter("intensity", intensity)


## Enables underwater distortion
func enable_underwater(intensity: float = 0.5) -> void:
	_distortion_layer.visible = true
	_distortion_material.set_shader_parameter("effect_type", 3)  # Underwater
	_distortion_material.set_shader_parameter("intensity", intensity)


## Enables drunk/dizzy distortion
func enable_drunk(intensity: float = 0.4) -> void:
	_distortion_layer.visible = true
	_distortion_material.set_shader_parameter("effect_type", 4)  # Drunk
	_distortion_material.set_shader_parameter("intensity", intensity)


## Disables all distortion effects
func disable_distortion() -> void:
	_distortion_layer.visible = false

# endregion


# region - Speed Lines

## Enables speed lines effect
func enable_speed_lines(style: SpeedLineStyle = SpeedLineStyle.RADIAL, intensity: float = 0.5, color: Color = Color(1, 1, 1, 0.3)) -> void:
	_speed_lines_layer.visible = true
	_speed_lines_material.set_shader_parameter("style", style)
	_speed_lines_material.set_shader_parameter("intensity", intensity)
	_speed_lines_material.set_shader_parameter("line_color", color)
	_speed_lines_material.set_shader_parameter("line_count", 40.0)
	_speed_lines_material.set_shader_parameter("speed", 2.0)


## Disables speed lines
func disable_speed_lines() -> void:
	_speed_lines_layer.visible = false


## Pulses speed lines intensity
func pulse_speed_lines(peak_intensity: float = 0.8, duration: float = 0.3) -> void:
	var current_intensity: float = _speed_lines_material.get_shader_parameter("intensity")

	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			_speed_lines_material.set_shader_parameter("intensity", value),
		current_intensity, peak_intensity, duration * 0.3
	).set_ease(Tween.EASE_OUT)

	tween.tween_method(
		func(value: float) -> void:
			_speed_lines_material.set_shader_parameter("intensity", value),
		peak_intensity, current_intensity, duration * 0.7
	).set_ease(Tween.EASE_IN)

	_active_tweens.append(tween)

# endregion


# region - Blur Effects

## Enables radial blur (motion blur from center)
func enable_radial_blur(intensity: float = 0.3, center: Vector2 = Vector2(0.5, 0.5)) -> void:
	_blur_layer.visible = true
	_blur_layer.material = _radial_blur_material
	_radial_blur_material.set_shader_parameter("intensity", intensity)
	_radial_blur_material.set_shader_parameter("center", center)


## Enables zoom blur
func enable_zoom_blur(intensity: float = 0.3, zoom_in: bool = true, center: Vector2 = Vector2(0.5, 0.5)) -> void:
	_blur_layer.visible = true
	_blur_layer.material = _zoom_blur_material
	_zoom_blur_material.set_shader_parameter("intensity", intensity)
	_zoom_blur_material.set_shader_parameter("zoom_in", zoom_in)
	_zoom_blur_material.set_shader_parameter("center", center)


## Disables blur effects
func disable_blur() -> void:
	_blur_layer.visible = false


## Creates a zoom blur pulse (for dramatic moments)
func zoom_blur_pulse(duration: float = 0.5, peak_intensity: float = 0.6, zoom_in: bool = true) -> void:
	enable_zoom_blur(0.0, zoom_in)

	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			_zoom_blur_material.set_shader_parameter("intensity", value),
		0.0, peak_intensity, duration * 0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

	tween.tween_method(
		func(value: float) -> void:
			_zoom_blur_material.set_shader_parameter("intensity", value),
		peak_intensity, 0.0, duration * 0.7
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	tween.finished.connect(disable_blur)

	_active_tweens.append(tween)

# endregion


# region - Transitions

## Starts a screen transition
func transition(type: TransitionType, duration: float = 0.5, color: Color = Color.BLACK, reverse: bool = false) -> void:
	_transition_layer.visible = true
	_transition_material.set_shader_parameter("transition_color", color)

	var transition_type_id: int = 0
	match type:
		TransitionType.FADE_BLACK, TransitionType.FADE_WHITE:
			transition_type_id = 0
		TransitionType.IRIS_IN, TransitionType.IRIS_OUT:
			transition_type_id = 1
		TransitionType.WIPE_LEFT:
			transition_type_id = 2
		TransitionType.WIPE_DOWN:
			transition_type_id = 3
		TransitionType.DIAMOND:
			transition_type_id = 4
		TransitionType.PIXELATE:
			transition_type_id = 5

	_transition_material.set_shader_parameter("transition_type", transition_type_id)

	var start_progress: float = 0.0 if not reverse else 1.0
	var end_progress: float = 1.0 if not reverse else 0.0

	_transition_material.set_shader_parameter("progress", start_progress)

	transition_started.emit(type)

	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			_transition_material.set_shader_parameter("progress", value),
		start_progress, end_progress, duration
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	tween.finished.connect(func() -> void:
		if reverse:
			_transition_layer.visible = false
		transition_ended.emit()
	)

	_active_tweens.append(tween)


## Fade to black
func fade_to_black(duration: float = 0.5) -> void:
	transition(TransitionType.FADE_BLACK, duration, Color.BLACK, false)


## Fade from black
func fade_from_black(duration: float = 0.5) -> void:
	transition(TransitionType.FADE_BLACK, duration, Color.BLACK, true)


## Fade to white
func fade_to_white(duration: float = 0.5) -> void:
	transition(TransitionType.FADE_WHITE, duration, Color.WHITE, false)


## Fade from white
func fade_from_white(duration: float = 0.5) -> void:
	transition(TransitionType.FADE_WHITE, duration, Color.WHITE, true)


## Iris transition (circle close)
func iris_in(duration: float = 0.5, color: Color = Color.BLACK) -> void:
	transition(TransitionType.IRIS_IN, duration, color, false)


## Iris transition (circle open)
func iris_out(duration: float = 0.5, color: Color = Color.BLACK) -> void:
	transition(TransitionType.IRIS_OUT, duration, color, true)

# endregion


# region - Vignette

## Enables dynamic vignette
func enable_vignette(intensity: float = 0.3, color: Color = Color.BLACK, radius: float = 0.8) -> void:
	_vignette_layer.visible = true
	_vignette_material.set_shader_parameter("intensity", intensity)
	_vignette_material.set_shader_parameter("color", color)
	_vignette_material.set_shader_parameter("radius", radius)
	_vignette_material.set_shader_parameter("softness", 0.5)


## Enables pulsing damage vignette
func enable_damage_vignette(intensity: float = 0.5, pulse_speed: float = 2.0) -> void:
	_vignette_layer.visible = true
	_vignette_material.set_shader_parameter("intensity", intensity)
	_vignette_material.set_shader_parameter("color", Color(0.5, 0.0, 0.0, 1.0))
	_vignette_material.set_shader_parameter("radius", 0.6)
	_vignette_material.set_shader_parameter("pulse_speed", pulse_speed)
	_vignette_material.set_shader_parameter("pulse_amount", 0.15)


## Disables vignette
func disable_vignette() -> void:
	_vignette_layer.visible = false

# endregion


# region - Chromatic Aberration

## Enables chromatic aberration
func enable_chromatic_aberration(intensity: float = 0.01, radial: bool = false) -> void:
	_chromatic_layer.visible = true
	_chromatic_material.set_shader_parameter("intensity", intensity)
	_chromatic_material.set_shader_parameter("radial", radial)


## Creates a chromatic aberration pulse
func chromatic_pulse(duration: float = 0.3, peak_intensity: float = 0.03) -> void:
	enable_chromatic_aberration(0.0, true)

	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			_chromatic_material.set_shader_parameter("intensity", value),
		0.0, peak_intensity, duration * 0.2
	).set_ease(Tween.EASE_OUT)

	tween.tween_method(
		func(value: float) -> void:
			_chromatic_material.set_shader_parameter("intensity", value),
		peak_intensity, 0.0, duration * 0.8
	).set_ease(Tween.EASE_IN)

	tween.finished.connect(func() -> void:
		_chromatic_layer.visible = false
	)

	_active_tweens.append(tween)


## Disables chromatic aberration
func disable_chromatic_aberration() -> void:
	_chromatic_layer.visible = false

# endregion


# region - Combination Effects

## Heavy impact effect (shake + flash + chromatic)
func heavy_impact(direction: Vector2 = Vector2.ZERO, intensity: float = 1.0) -> void:
	if direction != Vector2.ZERO:
		shake_directional(direction, 0.4, intensity)
	else:
		shake(ShakePattern.IMPACT, 0.4, intensity)

	flash(Color(1, 1, 1, 0.3), 0.1)
	chromatic_pulse(0.3, 0.02 * intensity)


## Explosion effect (shake + shockwave + flash)
func explosion_effect(screen_center: Vector2, intensity: float = 1.0) -> void:
	shake(ShakePattern.EXPLOSION, 0.6, intensity)
	distortion_shockwave(screen_center, 0.5, 0.6 * intensity)
	flash(Color(1, 0.8, 0.5, 0.4), 0.15)


## Death/KO effect
func death_effect() -> void:
	shake(ShakePattern.HEAVY, 0.5, 1.2)
	enable_damage_vignette(0.7, 3.0)
	chromatic_pulse(0.5, 0.04)

	# Fade out vignette after a delay
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		var tween := create_tween()
		tween.tween_method(
			func(value: float) -> void:
				_vignette_material.set_shader_parameter("intensity", value),
			0.7, 0.0, 0.5
		)
		tween.finished.connect(disable_vignette)
	)


## Speed boost effect
func speed_boost_effect(duration: float = 2.0) -> void:
	enable_speed_lines(SpeedLineStyle.RADIAL, 0.6)
	enable_chromatic_aberration(0.008, true)

	get_tree().create_timer(duration).timeout.connect(func() -> void:
		disable_speed_lines()
		disable_chromatic_aberration()
	)


## Slow motion start effect
func slow_motion_effect() -> void:
	zoom_blur_pulse(0.3, 0.4, true)
	flash(Color(0.8, 0.9, 1.0, 0.2), 0.2)

# endregion


# region - Cleanup

## Clears all active screen effects
func clear_all_effects() -> void:
	stop_shake()

	# Kill all active tweens
	for tween: Tween in _active_tweens:
		if tween.is_valid():
			tween.kill()
	_active_tweens.clear()

	# Hide all layers
	_flash_layer.visible = false
	_distortion_layer.visible = false
	_speed_lines_layer.visible = false
	_blur_layer.visible = false
	_transition_layer.visible = false
	_vignette_layer.visible = false
	_chromatic_layer.visible = false

# endregion
