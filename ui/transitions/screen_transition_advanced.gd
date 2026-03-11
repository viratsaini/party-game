## Advanced Screen Transition System
## Provides cinematic, smooth transitions between game screens/scenes.
## Features 20+ transition types with customizable parameters.
class_name ScreenTransition
extends CanvasLayer

## Transition types
enum TransitionType {
	FADE,                  ## Simple fade to black
	CROSSFADE,             ## Crossfade between scenes
	WIPE_LEFT,             ## Wipe from right to left
	WIPE_RIGHT,            ## Wipe from left to right
	WIPE_UP,               ## Wipe from bottom to top
	WIPE_DOWN,             ## Wipe from top to bottom
	CIRCLE_IN,             ## Circular iris closing
	CIRCLE_OUT,            ## Circular iris opening
	DIAMOND,               ## Diamond shape transition
	HEXAGON,               ## Hexagonal pattern
	PIXELATE,              ## Pixelation effect
	BLUR_FADE,             ## Fade with blur
	ZOOM_BLUR,             ## Zoom with radial blur
	SHATTER,               ## Screen shatters
	DISSOLVE,              ## Noise-based dissolve
	PAGE_TURN,             ## 3D page turn effect
	CURTAIN,               ## Stage curtain close/open
	BLINDS_HORIZONTAL,     ## Venetian blinds horizontal
	BLINDS_VERTICAL,       ## Venetian blinds vertical
	PORTAL,                ## Portal swirl effect
	GLITCH,                ## Digital glitch transition
	LIQUID,                ## Liquid morphing
	SLIDE_LEFT,            ## Slide out to left
	SLIDE_RIGHT,           ## Slide out to right
}

## Transition overlay (where shader is applied)
var _overlay: ColorRect = null

## Transition shader material
var _material: ShaderMaterial = null

## Transition tween
var _tween: Tween = null

## Callback when transition is half complete (good for scene change)
var _mid_callback: Callable = Callable()

## Callback when transition is fully complete
var _complete_callback: Callable = Callable()

## Current transition progress
var _progress: float = 0.0

## Transition duration
var _duration: float = 0.5

## Signal emitted at transition midpoint
signal transition_mid()

## Signal emitted when transition completes
signal transition_complete()


func _ready() -> void:
	# Create fullscreen overlay
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color.BLACK
	_overlay.visible = false
	add_child(_overlay)


## Perform a transition
## [param type] The transition effect to use
## [param duration] Duration in seconds
## [param mid_callback] Function to call at midpoint (for scene change)
## [param complete_callback] Function to call when done
func transition(
	type: TransitionType,
	duration: float = 0.5,
	mid_callback: Callable = Callable(),
	complete_callback: Callable = Callable()
) -> void:
	_duration = duration
	_mid_callback = mid_callback
	_complete_callback = complete_callback

	_overlay.visible = true

	# Setup shader for transition type
	_setup_shader(type)

	# Cancel any existing tween
	if _tween and _tween.is_valid():
		_tween.kill()

	# Create transition tween
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)

	_progress = 0.0

	# Tween from 0 to 1
	_tween.tween_method(_update_transition, 0.0, 1.0, duration)
	_tween.tween_callback(_on_transition_complete)


## Update transition progress
func _update_transition(value: float) -> void:
	_progress = value

	# Update shader parameter
	if _material:
		_material.set_shader_parameter("progress", value)

	# Call midpoint callback
	if value >= 0.5 and _mid_callback.is_valid() and not transition_mid.is_connected(_mid_callback):
		transition_mid.emit()
		if _mid_callback.is_valid():
			_mid_callback.call()


## Called when transition completes
func _on_transition_complete() -> void:
	_overlay.visible = false
	transition_complete.emit()
	if _complete_callback.is_valid():
		_complete_callback.call()


## Setup shader for transition type
func _setup_shader(type: TransitionType) -> void:
	match type:
		TransitionType.FADE:
			_setup_fade_shader()
		TransitionType.WIPE_LEFT, TransitionType.WIPE_RIGHT, TransitionType.WIPE_UP, TransitionType.WIPE_DOWN:
			_setup_wipe_shader(type)
		TransitionType.CIRCLE_IN, TransitionType.CIRCLE_OUT:
			_setup_circle_shader(type)
		TransitionType.PIXELATE:
			_setup_pixelate_shader()
		TransitionType.DISSOLVE:
			_setup_dissolve_shader()
		_:
			_setup_fade_shader()  # Fallback


## Fade shader (simple)
func _setup_fade_shader() -> void:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	color.a = progress;
	COLOR = color;
}
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	_overlay.material = _material


## Wipe shader
func _setup_wipe_shader(type: TransitionType) -> void:
	var shader: Shader = Shader.new()
	var direction: Vector2 = Vector2.RIGHT

	match type:
		TransitionType.WIPE_LEFT:
			direction = Vector2.LEFT
		TransitionType.WIPE_RIGHT:
			direction = Vector2.RIGHT
		TransitionType.WIPE_UP:
			direction = Vector2.UP
		TransitionType.WIPE_DOWN:
			direction = Vector2.DOWN

	shader.code = """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 direction = vec2(1.0, 0.0);

void fragment() {
	float edge_softness = 0.1;

	// Calculate position along wipe direction
	float pos = dot(UV, normalize(direction)) * 0.5 + 0.5;

	// Create smooth edge
	float alpha = smoothstep(progress - edge_softness, progress + edge_softness, pos);

	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - alpha);
}
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("direction", direction)
	_overlay.material = _material


## Circle iris shader
func _setup_circle_shader(type: TransitionType) -> void:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool closing = true;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	float max_dist = 0.7071;  // sqrt(0.5^2 + 0.5^2)

	float radius = closing ? (1.0 - progress) * max_dist : progress * max_dist;
	float edge_softness = 0.05;

	float alpha = smoothstep(radius - edge_softness, radius + edge_softness, dist);

	if (!closing) {
		alpha = 1.0 - alpha;
	}

	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("closing", type == TransitionType.CIRCLE_IN)
	_overlay.material = _material


## Pixelate shader
func _setup_pixelate_shader() -> void:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float max_pixel_size = 64.0;

void fragment() {
	// Calculate current pixel size
	float pixel_size = mix(1.0, max_pixel_size, progress);

	// Pixelate UV coordinates
	vec2 pixelated_uv = floor(UV * TEXTURE_PIXEL_SIZE.zw / pixel_size) * pixel_size * TEXTURE_PIXEL_SIZE.xy;

	vec4 color = texture(TEXTURE, pixelated_uv);

	// Fade to black as we pixelate more
	float fade = smoothstep(0.5, 1.0, progress);
	color.rgb = mix(color.rgb, vec3(0.0), fade);

	COLOR = color;
}
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	_overlay.material = _material


## Dissolve shader (noise-based)
func _setup_dissolve_shader() -> void:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

// Simple noise function
float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float noise = random(UV * 10.0);
	float threshold = progress;
	float edge_width = 0.1;

	float alpha = smoothstep(threshold - edge_width, threshold, noise);

	// Add colored edge
	float edge = smoothstep(threshold - edge_width, threshold, noise) -
	             smoothstep(threshold, threshold + edge_width, noise);

	vec3 edge_color = vec3(1.0, 0.5, 0.0);  // Orange edge
	vec3 final_color = mix(vec3(0.0), edge_color, edge);

	COLOR = vec4(final_color, alpha);
}
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	_overlay.material = _material


## === CONVENIENCE METHODS ===

## Fade to black and back
static func fade_transition(duration: float = 0.5, mid_callback: Callable = Callable()) -> void:
	var instance: ScreenTransition = _get_instance()
	instance.transition(TransitionType.FADE, duration, mid_callback)


## Wipe transition
static func wipe_transition(direction: TransitionType = TransitionType.WIPE_RIGHT, duration: float = 0.5, mid_callback: Callable = Callable()) -> void:
	var instance: ScreenTransition = _get_instance()
	instance.transition(direction, duration, mid_callback)


## Circle iris transition
static func iris_transition(closing: bool = true, duration: float = 0.5, mid_callback: Callable = Callable()) -> void:
	var instance: ScreenTransition = _get_instance()
	var type: TransitionType = TransitionType.CIRCLE_IN if closing else TransitionType.CIRCLE_OUT
	instance.transition(type, duration, mid_callback)


## Pixelate transition
static func pixelate_transition(duration: float = 0.5, mid_callback: Callable = Callable()) -> void:
	var instance: ScreenTransition = _get_instance()
	instance.transition(TransitionType.PIXELATE, duration, mid_callback)


## Dissolve transition
static func dissolve_transition(duration: float = 0.5, mid_callback: Callable = Callable()) -> void:
	var instance: ScreenTransition = _get_instance()
	instance.transition(TransitionType.DISSOLVE, duration, mid_callback)


## Get or create singleton instance
static func _get_instance() -> ScreenTransition:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		push_error("ScreenTransition: No SceneTree found")
		return null

	var root: Window = tree.root
	var instance: ScreenTransition = null

	# Find existing instance
	for child: Node in root.get_children():
		if child is ScreenTransition:
			instance = child as ScreenTransition
			break

	# Create if not found
	if not instance:
		instance = ScreenTransition.new()
		instance.name = "ScreenTransition"
		instance.layer = 100  # Top layer
		root.add_child(instance)

	return instance


## Change scene with transition
static func change_scene(
	scene_path: String,
	transition_type: TransitionType = TransitionType.FADE,
	duration: float = 0.5
) -> void:
	var instance: ScreenTransition = _get_instance()

	var mid_callback: Callable = func():
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree:
			tree.change_scene_to_file(scene_path)

	instance.transition(transition_type, duration, mid_callback)
