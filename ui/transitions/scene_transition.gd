## SceneTransition - Premium scene transition system with multiple effects
## Provides fade, wipe, shatter, blur, and color inversion transitions
extends CanvasLayer

signal transition_started(effect_type: String)
signal transition_midpoint()
signal transition_completed()

enum TransitionType {
	FADE_BLACK,
	FADE_WHITE,
	FADE_VIGNETTE,
	WIPE_CIRCULAR,
	WIPE_LEFT,
	WIPE_RIGHT,
	WIPE_UP,
	WIPE_DOWN,
	WIPE_DIAGONAL,
	SHATTER,
	BLUR_ZOOM_IN,
	BLUR_ZOOM_OUT,
	COLOR_INVERSION,
	PIXELATE,
	DISSOLVE,
	CROSSFADE
}

# Configuration
@export var default_duration: float = 0.8
@export var default_type: TransitionType = TransitionType.FADE_VIGNETTE
@export var hold_at_midpoint: bool = false

# Transition layers
var _overlay: ColorRect
var _shader_overlay: ColorRect
var _vignette_overlay: ColorRect
var _shatter_container: Control
var _particle_container: Control

# State
var _is_transitioning: bool = false
var _current_tween: Tween
var _pending_callback: Callable
var _shatter_pieces: Array[Control] = []

# Shaders
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 2.0) = 0.0;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	float vignette = smoothstep(1.0 - softness, 1.0, dist * intensity);
	COLOR = vec4(color.rgb, vignette * color.a);
}
"""

const CIRCULAR_WIPE_SHADER := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float softness : hint_range(0.0, 0.2) = 0.02;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV - center;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	uv.x *= aspect;
	float dist = length(uv);
	float max_dist = length(vec2(0.5 * aspect, 0.5));
	float threshold = (1.0 - progress) * max_dist * 1.5;
	float alpha = smoothstep(threshold - softness, threshold + softness, dist);
	COLOR = vec4(color.rgb, alpha);
}
"""

const DIRECTIONAL_WIPE_SHADER := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float softness : hint_range(0.0, 0.3) = 0.1;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	float proj = dot(UV - 0.5, normalize(direction)) + 0.5;
	float threshold = progress * 1.2;
	float alpha = smoothstep(threshold - softness, threshold, proj);
	COLOR = vec4(color.rgb, 1.0 - alpha);
}
"""

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 0.0;
uniform float zoom : hint_range(0.5, 2.0) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = (UV - center) / zoom + center;

	vec4 col = vec4(0.0);
	float total = 0.0;

	for (float x = -2.0; x <= 2.0; x += 1.0) {
		for (float y = -2.0; y <= 2.0; y += 1.0) {
			vec2 offset = vec2(x, y) * blur_amount * 0.01;
			col += texture(SCREEN_TEXTURE, uv + offset);
			total += 1.0;
		}
	}

	col /= total;
	col.rgb *= brightness;
	COLOR = col;
}
"""

const PIXELATE_SHADER := """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(1.0, 100.0) = 1.0;

void fragment() {
	vec2 size = vec2(textureSize(SCREEN_TEXTURE, 0));
	vec2 factor = size / pixel_size;
	vec2 uv = floor(UV * factor) / factor;
	COLOR = texture(SCREEN_TEXTURE, uv);
}
"""

const DISSOLVE_SHADER := """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform vec4 target_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 screen_col = texture(SCREEN_TEXTURE, UV);
	float noise = rand(UV * 100.0);

	float dissolve = smoothstep(progress - edge_width, progress, noise);
	float edge = smoothstep(progress - edge_width, progress, noise) - smoothstep(progress, progress + edge_width, noise);

	vec4 final_color = mix(target_color, screen_col, dissolve);
	final_color = mix(final_color, edge_color, edge * 0.8);
	COLOR = final_color;
}
"""

const INVERSION_SHADER := """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = texture(SCREEN_TEXTURE, UV);
	vec3 inverted = vec3(1.0) - col.rgb;
	col.rgb = mix(col.rgb, inverted, intensity);
	col.rgb = mix(col.rgb, vec3(1.0), flash);
	COLOR = col;
}
"""


func _ready() -> void:
	layer = 100  # Ensure on top
	_setup_overlays()


func _setup_overlays() -> void:
	# Main color overlay for simple fades
	_overlay = ColorRect.new()
	_overlay.name = "TransitionOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Shader overlay for complex effects
	_shader_overlay = ColorRect.new()
	_shader_overlay.name = "ShaderOverlay"
	_shader_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shader_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_overlay.visible = false
	add_child(_shader_overlay)

	# Vignette overlay
	_vignette_overlay = ColorRect.new()
	_vignette_overlay.name = "VignetteOverlay"
	_vignette_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_mat := ShaderMaterial.new()
	vignette_mat.shader = _create_shader(VIGNETTE_SHADER)
	_vignette_overlay.material = vignette_mat
	_vignette_overlay.visible = false
	add_child(_vignette_overlay)

	# Shatter container
	_shatter_container = Control.new()
	_shatter_container.name = "ShatterContainer"
	_shatter_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shatter_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shatter_container.visible = false
	add_child(_shatter_container)

	# Particle container
	_particle_container = Control.new()
	_particle_container.name = "ParticleContainer"
	_particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particle_container)


func _create_shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader


## Main transition method with callback at midpoint
func transition_to_scene(scene_path: String, type: TransitionType = TransitionType.FADE_VIGNETTE, duration: float = -1.0) -> void:
	if _is_transitioning:
		return

	var actual_duration := duration if duration > 0 else default_duration

	await play_transition_out(type, actual_duration / 2.0)

	# Load and change scene at midpoint
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("Failed to load scene: %s" % scene_path)

	# Wait a frame for the new scene to initialize
	await get_tree().process_frame

	await play_transition_in(type, actual_duration / 2.0)


## Play just the out (fade to black/effect) portion
func play_transition_out(type: TransitionType = TransitionType.FADE_VIGNETTE, duration: float = 0.4) -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	transition_started.emit(TransitionType.keys()[type])

	match type:
		TransitionType.FADE_BLACK:
			await _fade_out(Color.BLACK, duration)
		TransitionType.FADE_WHITE:
			await _fade_out(Color.WHITE, duration)
		TransitionType.FADE_VIGNETTE:
			await _vignette_out(duration)
		TransitionType.WIPE_CIRCULAR:
			await _circular_wipe_out(duration)
		TransitionType.WIPE_LEFT:
			await _directional_wipe_out(Vector2(-1, 0), duration)
		TransitionType.WIPE_RIGHT:
			await _directional_wipe_out(Vector2(1, 0), duration)
		TransitionType.WIPE_UP:
			await _directional_wipe_out(Vector2(0, -1), duration)
		TransitionType.WIPE_DOWN:
			await _directional_wipe_out(Vector2(0, 1), duration)
		TransitionType.WIPE_DIAGONAL:
			await _directional_wipe_out(Vector2(1, 1).normalized(), duration)
		TransitionType.SHATTER:
			await _shatter_out(duration)
		TransitionType.BLUR_ZOOM_IN:
			await _blur_zoom_out(true, duration)
		TransitionType.BLUR_ZOOM_OUT:
			await _blur_zoom_out(false, duration)
		TransitionType.COLOR_INVERSION:
			await _inversion_out(duration)
		TransitionType.PIXELATE:
			await _pixelate_out(duration)
		TransitionType.DISSOLVE:
			await _dissolve_out(duration)
		_:
			await _fade_out(Color.BLACK, duration)

	transition_midpoint.emit()


## Play just the in (reveal) portion
func play_transition_in(type: TransitionType = TransitionType.FADE_VIGNETTE, duration: float = 0.4) -> void:
	match type:
		TransitionType.FADE_BLACK:
			await _fade_in(duration)
		TransitionType.FADE_WHITE:
			await _fade_in(duration)
		TransitionType.FADE_VIGNETTE:
			await _vignette_in(duration)
		TransitionType.WIPE_CIRCULAR:
			await _circular_wipe_in(duration)
		TransitionType.WIPE_LEFT, TransitionType.WIPE_RIGHT, TransitionType.WIPE_UP, TransitionType.WIPE_DOWN, TransitionType.WIPE_DIAGONAL:
			await _directional_wipe_in(duration)
		TransitionType.SHATTER:
			await _shatter_in(duration)
		TransitionType.BLUR_ZOOM_IN:
			await _blur_zoom_in(true, duration)
		TransitionType.BLUR_ZOOM_OUT:
			await _blur_zoom_in(false, duration)
		TransitionType.COLOR_INVERSION:
			await _inversion_in(duration)
		TransitionType.PIXELATE:
			await _pixelate_in(duration)
		TransitionType.DISSOLVE:
			await _dissolve_in(duration)
		_:
			await _fade_in(duration)

	_is_transitioning = false
	transition_completed.emit()


## Quick transition with custom callback at midpoint
func transition_with_callback(callback: Callable, type: TransitionType = TransitionType.FADE_VIGNETTE, duration: float = -1.0) -> void:
	if _is_transitioning:
		return

	var actual_duration := duration if duration > 0 else default_duration

	await play_transition_out(type, actual_duration / 2.0)

	if callback.is_valid():
		callback.call()

	await get_tree().process_frame
	await play_transition_in(type, actual_duration / 2.0)


# ============================================================================
# FADE TRANSITIONS
# ============================================================================

func _fade_out(color: Color, duration: float) -> void:
	_overlay.color = Color(color.r, color.g, color.b, 0)
	_overlay.visible = true

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.set_trans(Tween.TRANS_SINE)
	_current_tween.tween_property(_overlay, "color:a", 1.0, duration)

	await _current_tween.finished


func _fade_in(duration: float) -> void:
	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.set_trans(Tween.TRANS_SINE)
	_current_tween.tween_property(_overlay, "color:a", 0.0, duration)

	await _current_tween.finished
	_overlay.visible = false


# ============================================================================
# VIGNETTE TRANSITIONS
# ============================================================================

func _vignette_out(duration: float) -> void:
	_vignette_overlay.visible = true
	var mat := _vignette_overlay.material as ShaderMaterial
	mat.set_shader_parameter("intensity", 0.0)
	mat.set_shader_parameter("softness", 0.4)
	mat.set_shader_parameter("color", Color.BLACK)

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN)
	_current_tween.set_trans(Tween.TRANS_QUAD)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, 2.5, duration)

	await _current_tween.finished

	# Ensure fully black at end
	_overlay.color = Color.BLACK
	_overlay.visible = true


func _vignette_in(duration: float) -> void:
	_vignette_overlay.visible = true
	var mat := _vignette_overlay.material as ShaderMaterial
	mat.set_shader_parameter("intensity", 2.5)
	_overlay.visible = false

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_OUT)
	_current_tween.set_trans(Tween.TRANS_QUAD)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 2.5, 0.0, duration)

	await _current_tween.finished
	_vignette_overlay.visible = false


# ============================================================================
# CIRCULAR WIPE TRANSITIONS
# ============================================================================

func _circular_wipe_out(duration: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _create_shader(CIRCULAR_WIPE_SHADER)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("center", Vector2(0.5, 0.5))
	mat.set_shader_parameter("color", Color.BLACK)

	_shader_overlay.material = mat
	_shader_overlay.visible = true

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.set_trans(Tween.TRANS_SINE)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, duration)

	await _current_tween.finished

	_overlay.color = Color.BLACK
	_overlay.visible = true


func _circular_wipe_in(duration: float) -> void:
	_overlay.visible = false

	var mat := _shader_overlay.material as ShaderMaterial
	mat.set_shader_parameter("progress", 1.0)

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.set_trans(Tween.TRANS_SINE)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 1.0, 0.0, duration)

	await _current_tween.finished
	_shader_overlay.visible = false


# ============================================================================
# DIRECTIONAL WIPE TRANSITIONS
# ============================================================================

func _directional_wipe_out(direction: Vector2, duration: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _create_shader(DIRECTIONAL_WIPE_SHADER)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("direction", direction)
	mat.set_shader_parameter("color", Color.BLACK)

	_shader_overlay.material = mat
	_shader_overlay.visible = true

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.set_trans(Tween.TRANS_SINE)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, duration)

	await _current_tween.finished

	_overlay.color = Color.BLACK
	_overlay.visible = true


func _directional_wipe_in(duration: float) -> void:
	_overlay.visible = false

	var mat := _shader_overlay.material as ShaderMaterial
	mat.set_shader_parameter("progress", 1.0)

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.set_trans(Tween.TRANS_SINE)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 1.0, 0.0, duration)

	await _current_tween.finished
	_shader_overlay.visible = false


# ============================================================================
# SHATTER TRANSITIONS
# ============================================================================

func _shatter_out(duration: float) -> void:
	_capture_screen_for_shatter()
	_shatter_container.visible = true

	# Animate each piece flying away
	var piece_tweens: Array[Tween] = []
	for piece in _shatter_pieces:
		var tween := create_tween()
		tween.set_parallel(true)

		var center := Vector2(get_viewport().get_visible_rect().size) / 2.0
		var piece_center := piece.position + piece.size / 2.0
		var direction := (piece_center - center).normalized()
		var distance := randf_range(500, 1500)
		var rotation := randf_range(-720, 720)

		tween.tween_property(piece, "position", piece.position + direction * distance, duration)
		tween.tween_property(piece, "rotation", deg_to_rad(rotation), duration)
		tween.tween_property(piece, "modulate:a", 0.0, duration * 0.8).set_delay(duration * 0.2)
		tween.tween_property(piece, "scale", Vector2(0.3, 0.3), duration)

		piece_tweens.append(tween)

	_current_tween = create_tween()
	_current_tween.tween_interval(duration)
	await _current_tween.finished

	_overlay.color = Color.BLACK
	_overlay.visible = true
	_clear_shatter_pieces()


func _shatter_in(duration: float) -> void:
	_overlay.visible = false
	_shatter_container.visible = false
	_clear_shatter_pieces()

	# Simple fade in after shatter
	_overlay.color = Color(0, 0, 0, 1)
	_overlay.visible = true

	_current_tween = create_tween()
	_current_tween.tween_property(_overlay, "color:a", 0.0, duration)

	await _current_tween.finished
	_overlay.visible = false


func _capture_screen_for_shatter() -> void:
	_clear_shatter_pieces()

	var viewport := get_viewport()
	var screen_size := viewport.get_visible_rect().size

	# Create grid of pieces
	var cols := 8
	var rows := 6
	var piece_width := screen_size.x / cols
	var piece_height := screen_size.y / rows

	for row in range(rows):
		for col in range(cols):
			var piece := ColorRect.new()
			piece.position = Vector2(col * piece_width, row * piece_height)
			piece.size = Vector2(piece_width + 2, piece_height + 2)  # Slight overlap
			piece.color = Color(randf_range(0.1, 0.3), randf_range(0.1, 0.3), randf_range(0.1, 0.3))
			piece.pivot_offset = piece.size / 2.0

			_shatter_container.add_child(piece)
			_shatter_pieces.append(piece)


func _clear_shatter_pieces() -> void:
	for piece in _shatter_pieces:
		if is_instance_valid(piece):
			piece.queue_free()
	_shatter_pieces.clear()


# ============================================================================
# BLUR ZOOM TRANSITIONS
# ============================================================================

func _blur_zoom_out(zoom_in: bool, duration: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _create_shader(BLUR_SHADER)
	mat.set_shader_parameter("blur_amount", 0.0)
	mat.set_shader_parameter("zoom", 1.0)
	mat.set_shader_parameter("brightness", 1.0)

	_shader_overlay.material = mat
	_shader_overlay.visible = true

	var target_zoom := 1.5 if zoom_in else 0.7

	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("blur_amount", v), 0.0, 5.0, duration)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("zoom", v), 1.0, target_zoom, duration)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("brightness", v), 1.0, 0.0, duration)

	await _current_tween.finished

	_overlay.color = Color.BLACK
	_overlay.visible = true


func _blur_zoom_in(zoom_in: bool, duration: float) -> void:
	_overlay.visible = false

	var mat := _shader_overlay.material as ShaderMaterial
	var start_zoom := 1.5 if zoom_in else 0.7

	mat.set_shader_parameter("blur_amount", 5.0)
	mat.set_shader_parameter("zoom", start_zoom)
	mat.set_shader_parameter("brightness", 0.0)

	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("blur_amount", v), 5.0, 0.0, duration)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("zoom", v), start_zoom, 1.0, duration)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("brightness", v), 0.0, 1.0, duration)

	await _current_tween.finished
	_shader_overlay.visible = false


# ============================================================================
# COLOR INVERSION TRANSITIONS
# ============================================================================

func _inversion_out(duration: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _create_shader(INVERSION_SHADER)
	mat.set_shader_parameter("intensity", 0.0)
	mat.set_shader_parameter("flash", 0.0)

	_shader_overlay.material = mat
	_shader_overlay.visible = true

	_current_tween = create_tween()
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, 1.0, duration * 0.3)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("flash", v), 0.0, 1.0, duration * 0.7)

	await _current_tween.finished

	_overlay.color = Color.WHITE
	_overlay.visible = true


func _inversion_in(duration: float) -> void:
	_overlay.color = Color.WHITE

	_current_tween = create_tween()
	_current_tween.tween_property(_overlay, "color", Color.BLACK, duration * 0.2)
	_current_tween.tween_property(_overlay, "color:a", 0.0, duration * 0.8)

	await _current_tween.finished

	_overlay.visible = false
	_shader_overlay.visible = false


# ============================================================================
# PIXELATE TRANSITIONS
# ============================================================================

func _pixelate_out(duration: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _create_shader(PIXELATE_SHADER)
	mat.set_shader_parameter("pixel_size", 1.0)

	_shader_overlay.material = mat
	_shader_overlay.visible = true

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN)
	_current_tween.set_trans(Tween.TRANS_EXPO)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("pixel_size", v), 1.0, 80.0, duration)

	await _current_tween.finished

	_overlay.color = Color.BLACK
	_overlay.visible = true


func _pixelate_in(duration: float) -> void:
	_overlay.visible = false

	var mat := _shader_overlay.material as ShaderMaterial
	mat.set_shader_parameter("pixel_size", 80.0)

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_OUT)
	_current_tween.set_trans(Tween.TRANS_EXPO)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("pixel_size", v), 80.0, 1.0, duration)

	await _current_tween.finished
	_shader_overlay.visible = false


# ============================================================================
# DISSOLVE TRANSITIONS
# ============================================================================

func _dissolve_out(duration: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _create_shader(DISSOLVE_SHADER)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("edge_color", Color(1.0, 0.5, 0.2, 1.0))
	mat.set_shader_parameter("target_color", Color.BLACK)

	_shader_overlay.material = mat
	_shader_overlay.visible = true

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.2, duration)

	await _current_tween.finished

	_overlay.color = Color.BLACK
	_overlay.visible = true


func _dissolve_in(duration: float) -> void:
	_overlay.visible = false

	var mat := _shader_overlay.material as ShaderMaterial
	mat.set_shader_parameter("progress", 1.2)

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 1.2, 0.0, duration)

	await _current_tween.finished
	_shader_overlay.visible = false


# ============================================================================
# UTILITY
# ============================================================================

## Cancel current transition
func cancel_transition() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_overlay.visible = false
	_shader_overlay.visible = false
	_vignette_overlay.visible = false
	_shatter_container.visible = false
	_clear_shatter_pieces()

	_is_transitioning = false


## Check if transition is in progress
func is_transitioning() -> bool:
	return _is_transitioning


## Flash the screen (for impacts, etc.)
func flash_screen(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	_overlay.color = color
	_overlay.visible = true

	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, duration).from(1.0)
	await tween.finished
	_overlay.visible = false
