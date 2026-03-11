## ColorblindFilter - Advanced colorblind simulation and correction filters.
##
## Provides scientifically accurate colorblind simulation modes and daltonization
## (color correction) to help colorblind users distinguish colors better.
## Supports Deuteranopia, Protanopia, Tritanopia, and Achromatopsia.
extends CanvasLayer

# -- Signals --

## Emitted when the filter mode changes.
signal filter_changed(mode: int, is_simulation: bool)

# -- Constants --

## Filter modes available.
enum FilterMode {
	NONE,
	DEUTERANOPIA_SIM,    ## Simulate red-green colorblindness (green weakness)
	DEUTERANOPIA_CORRECT,## Correct for deuteranopia
	PROTANOPIA_SIM,      ## Simulate red-green colorblindness (red weakness)
	PROTANOPIA_CORRECT,  ## Correct for protanopia
	TRITANOPIA_SIM,      ## Simulate blue-yellow colorblindness
	TRITANOPIA_CORRECT,  ## Correct for tritanopia
	ACHROMATOPSIA_SIM,   ## Simulate complete color blindness
	HIGH_CONTRAST,       ## High contrast mode for low vision
	ENHANCED_COLORS      ## Enhance color differences
}

## Colorblind type enum (for API compatibility).
enum ColorblindType {
	DEUTERANOPIA,
	PROTANOPIA,
	TRITANOPIA,
	ACHROMATOPSIA
}

# -- Exported Properties --

## Current filter mode.
@export var filter_mode: FilterMode = FilterMode.NONE:
	set(value):
		filter_mode = value
		_apply_filter()

## Filter intensity (0.0 - 1.0).
@export_range(0.0, 1.0) var intensity: float = 1.0:
	set(value):
		intensity = clampf(value, 0.0, 1.0)
		_update_shader_intensity()

## Enable smooth transitions between filter modes.
@export var smooth_transitions: bool = true

## Transition duration in seconds.
@export var transition_duration: float = 0.3

# -- Internal State --

var _filter_rect: ColorRect = null
var _current_shader: ShaderMaterial = null
var _transition_tween: Tween = null
var _cached_shaders: Dictionary = {}  # FilterMode -> ShaderMaterial


# -- Lifecycle --

func _ready() -> void:
	layer = 100  # Above all game content
	_create_filter_rect()
	_cache_shaders()
	_apply_filter()


func _create_filter_rect() -> void:
	_filter_rect = ColorRect.new()
	_filter_rect.name = "FilterRect"
	_filter_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter_rect.visible = false
	add_child(_filter_rect)


func _cache_shaders() -> void:
	# Pre-create all shader materials for faster switching
	for mode: int in FilterMode.values():
		if mode != FilterMode.NONE:
			_cached_shaders[mode] = _create_shader_material(mode)


# -- Public API --

## Set the colorblind type with optional simulation/correction toggle.
func set_colorblind_type(cb_type: ColorblindType, simulate: bool = false) -> void:
	match cb_type:
		ColorblindType.DEUTERANOPIA:
			filter_mode = FilterMode.DEUTERANOPIA_SIM if simulate else FilterMode.DEUTERANOPIA_CORRECT
		ColorblindType.PROTANOPIA:
			filter_mode = FilterMode.PROTANOPIA_SIM if simulate else FilterMode.PROTANOPIA_CORRECT
		ColorblindType.TRITANOPIA:
			filter_mode = FilterMode.TRITANOPIA_SIM if simulate else FilterMode.TRITANOPIA_CORRECT
		ColorblindType.ACHROMATOPSIA:
			filter_mode = FilterMode.ACHROMATOPSIA_SIM


## Disable all filters.
func disable_filter() -> void:
	filter_mode = FilterMode.NONE


## Enable high contrast mode.
func enable_high_contrast() -> void:
	filter_mode = FilterMode.HIGH_CONTRAST


## Enable enhanced colors mode.
func enable_enhanced_colors() -> void:
	filter_mode = FilterMode.ENHANCED_COLORS


## Get the current filter as a descriptive string.
func get_filter_description() -> String:
	match filter_mode:
		FilterMode.NONE: return "None"
		FilterMode.DEUTERANOPIA_SIM: return "Deuteranopia Simulation"
		FilterMode.DEUTERANOPIA_CORRECT: return "Deuteranopia Correction"
		FilterMode.PROTANOPIA_SIM: return "Protanopia Simulation"
		FilterMode.PROTANOPIA_CORRECT: return "Protanopia Correction"
		FilterMode.TRITANOPIA_SIM: return "Tritanopia Simulation"
		FilterMode.TRITANOPIA_CORRECT: return "Tritanopia Correction"
		FilterMode.ACHROMATOPSIA_SIM: return "Achromatopsia Simulation"
		FilterMode.HIGH_CONTRAST: return "High Contrast"
		FilterMode.ENHANCED_COLORS: return "Enhanced Colors"
		_: return "Unknown"


## Check if current mode is a simulation (vs correction).
func is_simulation_mode() -> bool:
	return filter_mode in [
		FilterMode.DEUTERANOPIA_SIM,
		FilterMode.PROTANOPIA_SIM,
		FilterMode.TRITANOPIA_SIM,
		FilterMode.ACHROMATOPSIA_SIM
	]


## Convert a color for colorblind visibility.
## Useful for UI elements that need to be distinguishable.
func convert_color_for_visibility(original: Color) -> Color:
	match filter_mode:
		FilterMode.DEUTERANOPIA_CORRECT, FilterMode.PROTANOPIA_CORRECT:
			# Shift greens toward blue, reds toward orange
			return _shift_for_red_green_blindness(original)
		FilterMode.TRITANOPIA_CORRECT:
			# Shift blues toward cyan, yellows toward pink
			return _shift_for_blue_yellow_blindness(original)
		FilterMode.HIGH_CONTRAST:
			# Increase saturation and contrast
			return _increase_contrast(original)
		_:
			return original


## Get a colorblind-safe palette for the current mode.
func get_safe_palette() -> Array[Color]:
	match filter_mode:
		FilterMode.DEUTERANOPIA_CORRECT, FilterMode.PROTANOPIA_CORRECT:
			return _get_red_green_safe_palette()
		FilterMode.TRITANOPIA_CORRECT:
			return _get_blue_yellow_safe_palette()
		FilterMode.ACHROMATOPSIA_SIM:
			return _get_grayscale_palette()
		_:
			return _get_default_palette()


# -- Internal Methods --

func _apply_filter() -> void:
	if filter_mode == FilterMode.NONE:
		if smooth_transitions and _filter_rect.visible:
			_fade_out_filter()
		else:
			_filter_rect.visible = false
			_filter_rect.material = null
		filter_changed.emit(filter_mode, false)
		return

	var shader_mat: ShaderMaterial = _cached_shaders.get(filter_mode)
	if shader_mat == null:
		shader_mat = _create_shader_material(filter_mode)
		_cached_shaders[filter_mode] = shader_mat

	_current_shader = shader_mat
	_filter_rect.material = shader_mat
	_update_shader_intensity()

	if smooth_transitions and not _filter_rect.visible:
		_fade_in_filter()
	else:
		_filter_rect.visible = true
		_filter_rect.modulate.a = 1.0

	filter_changed.emit(filter_mode, is_simulation_mode())


func _fade_in_filter() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	_filter_rect.visible = true
	_filter_rect.modulate.a = 0.0

	_transition_tween = create_tween()
	_transition_tween.tween_property(_filter_rect, "modulate:a", 1.0, transition_duration)


func _fade_out_filter() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	_transition_tween = create_tween()
	_transition_tween.tween_property(_filter_rect, "modulate:a", 0.0, transition_duration)
	_transition_tween.tween_callback(func(): _filter_rect.visible = false)


func _update_shader_intensity() -> void:
	if _current_shader:
		_current_shader.set_shader_parameter("intensity", intensity)


func _create_shader_material(mode: FilterMode) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _create_shader(mode)
	material.set_shader_parameter("intensity", intensity)
	return material


func _create_shader(mode: FilterMode) -> Shader:
	var shader := Shader.new()

	match mode:
		FilterMode.DEUTERANOPIA_SIM:
			shader.code = _get_deuteranopia_sim_shader()
		FilterMode.DEUTERANOPIA_CORRECT:
			shader.code = _get_deuteranopia_correct_shader()
		FilterMode.PROTANOPIA_SIM:
			shader.code = _get_protanopia_sim_shader()
		FilterMode.PROTANOPIA_CORRECT:
			shader.code = _get_protanopia_correct_shader()
		FilterMode.TRITANOPIA_SIM:
			shader.code = _get_tritanopia_sim_shader()
		FilterMode.TRITANOPIA_CORRECT:
			shader.code = _get_tritanopia_correct_shader()
		FilterMode.ACHROMATOPSIA_SIM:
			shader.code = _get_achromatopsia_shader()
		FilterMode.HIGH_CONTRAST:
			shader.code = _get_high_contrast_shader()
		FilterMode.ENHANCED_COLORS:
			shader.code = _get_enhanced_colors_shader()
		_:
			shader.code = _get_passthrough_shader()

	return shader


# -- Shader Code Generation --

func _get_passthrough_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
"""


func _get_deuteranopia_sim_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

// Deuteranopia simulation matrix (Machado et al. 2009)
const mat3 deutan_sim = mat3(
	vec3(0.625, 0.375, 0.0),
	vec3(0.7, 0.3, 0.0),
	vec3(0.0, 0.3, 0.7)
);

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec3 simulated = deutan_sim * original.rgb;
	COLOR = vec4(mix(original.rgb, simulated, intensity), original.a);
}
"""


func _get_deuteranopia_correct_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

// Daltonization correction for deuteranopia
// Shifts red-green differences to red-blue differences
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec3 rgb = original.rgb;

	// Convert to LMS color space
	mat3 rgb_to_lms = mat3(
		vec3(0.31399022, 0.63951294, 0.04649755),
		vec3(0.15537241, 0.75789446, 0.08670142),
		vec3(0.01775239, 0.10944209, 0.87256922)
	);

	mat3 lms_to_rgb = mat3(
		vec3(5.47221206, -4.64196010, 0.16963708),
		vec3(-1.12524190, 2.29317094, -0.16789520),
		vec3(0.02980165, -0.19318073, 1.16364789)
	);

	vec3 lms = rgb_to_lms * rgb;

	// Simulate what a deuteranope sees
	mat3 deutan_sim = mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.494207, 0.0, 1.24827),
		vec3(0.0, 0.0, 1.0)
	);

	vec3 lms_deutan = deutan_sim * lms;
	vec3 sim_rgb = lms_to_rgb * lms_deutan;

	// Calculate error
	vec3 error = rgb - sim_rgb;

	// Shift error to visible spectrum (blue channel)
	vec3 correction = vec3(
		0.0,
		0.7 * error.r + 1.0 * error.g,
		0.7 * error.r + 1.0 * error.g
	);

	vec3 corrected = rgb + correction * intensity;
	corrected = clamp(corrected, 0.0, 1.0);

	COLOR = vec4(corrected, original.a);
}
"""


func _get_protanopia_sim_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

// Protanopia simulation matrix (Machado et al. 2009)
const mat3 protan_sim = mat3(
	vec3(0.567, 0.433, 0.0),
	vec3(0.558, 0.442, 0.0),
	vec3(0.0, 0.242, 0.758)
);

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec3 simulated = protan_sim * original.rgb;
	COLOR = vec4(mix(original.rgb, simulated, intensity), original.a);
}
"""


func _get_protanopia_correct_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

// Daltonization correction for protanopia
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec3 rgb = original.rgb;

	// Convert to LMS
	mat3 rgb_to_lms = mat3(
		vec3(0.31399022, 0.63951294, 0.04649755),
		vec3(0.15537241, 0.75789446, 0.08670142),
		vec3(0.01775239, 0.10944209, 0.87256922)
	);

	mat3 lms_to_rgb = mat3(
		vec3(5.47221206, -4.64196010, 0.16963708),
		vec3(-1.12524190, 2.29317094, -0.16789520),
		vec3(0.02980165, -0.19318073, 1.16364789)
	);

	vec3 lms = rgb_to_lms * rgb;

	// Simulate what a protanope sees
	mat3 protan_sim = mat3(
		vec3(0.0, 2.02344, -2.52581),
		vec3(0.0, 1.0, 0.0),
		vec3(0.0, 0.0, 1.0)
	);

	vec3 lms_protan = protan_sim * lms;
	vec3 sim_rgb = lms_to_rgb * lms_protan;

	// Calculate and shift error
	vec3 error = rgb - sim_rgb;
	vec3 correction = vec3(
		0.0,
		0.7 * error.r + 1.0 * error.g,
		0.7 * error.r + 1.0 * error.g
	);

	vec3 corrected = rgb + correction * intensity;
	corrected = clamp(corrected, 0.0, 1.0);

	COLOR = vec4(corrected, original.a);
}
"""


func _get_tritanopia_sim_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

// Tritanopia simulation matrix
const mat3 tritan_sim = mat3(
	vec3(0.95, 0.05, 0.0),
	vec3(0.0, 0.433, 0.567),
	vec3(0.0, 0.475, 0.525)
);

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec3 simulated = tritan_sim * original.rgb;
	COLOR = vec4(mix(original.rgb, simulated, intensity), original.a);
}
"""


func _get_tritanopia_correct_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

// Daltonization correction for tritanopia
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec3 rgb = original.rgb;

	// Shift blue-yellow differences to red-green
	vec3 error = vec3(0.0);
	error.r = (rgb.b - rgb.g) * 0.5;
	error.g = (rgb.b - rgb.g) * 0.5;

	vec3 corrected = rgb;
	corrected.r = clamp(rgb.r + error.r * intensity, 0.0, 1.0);
	corrected.g = clamp(rgb.g - error.g * intensity, 0.0, 1.0);

	COLOR = vec4(corrected, original.a);
}
"""


func _get_achromatopsia_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 original = texture(TEXTURE, UV);

	// Use luminance weights for perceptually accurate grayscale
	float gray = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 grayscale = vec3(gray);

	COLOR = vec4(mix(original.rgb, grayscale, intensity), original.a);
}
"""


func _get_high_contrast_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 original = texture(TEXTURE, UV);

	// Increase contrast
	float contrast = 1.0 + intensity * 0.5;
	vec3 contrasted = (original.rgb - 0.5) * contrast + 0.5;

	// Increase saturation
	float saturation = 1.0 + intensity * 0.3;
	float gray = dot(contrasted, vec3(0.2126, 0.7152, 0.0722));
	vec3 saturated = mix(vec3(gray), contrasted, saturation);

	// Darken dark colors, lighten light colors
	vec3 result = saturated;
	if (gray < 0.5) {
		result = result * (1.0 - intensity * 0.3);
	} else {
		result = result + (1.0 - result) * intensity * 0.3;
	}

	COLOR = vec4(clamp(result, 0.0, 1.0), original.a);
}
"""


func _get_enhanced_colors_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 original = texture(TEXTURE, UV);

	// Boost color differences
	vec3 rgb = original.rgb;

	// Find the dominant channel
	float max_channel = max(max(rgb.r, rgb.g), rgb.b);
	float min_channel = min(min(rgb.r, rgb.g), rgb.b);
	float diff = max_channel - min_channel;

	// Enhance the difference
	float boost = 1.0 + intensity * 0.5;
	vec3 enhanced = rgb;

	if (diff > 0.01) {
		// Boost the dominant color
		if (rgb.r == max_channel) {
			enhanced.r = clamp(rgb.r + diff * intensity * 0.3, 0.0, 1.0);
			enhanced.g = clamp(rgb.g - diff * intensity * 0.15, 0.0, 1.0);
			enhanced.b = clamp(rgb.b - diff * intensity * 0.15, 0.0, 1.0);
		} else if (rgb.g == max_channel) {
			enhanced.g = clamp(rgb.g + diff * intensity * 0.3, 0.0, 1.0);
			enhanced.r = clamp(rgb.r - diff * intensity * 0.15, 0.0, 1.0);
			enhanced.b = clamp(rgb.b - diff * intensity * 0.15, 0.0, 1.0);
		} else {
			enhanced.b = clamp(rgb.b + diff * intensity * 0.3, 0.0, 1.0);
			enhanced.r = clamp(rgb.r - diff * intensity * 0.15, 0.0, 1.0);
			enhanced.g = clamp(rgb.g - diff * intensity * 0.15, 0.0, 1.0);
		}
	}

	// Also boost saturation
	float gray = dot(enhanced, vec3(0.2126, 0.7152, 0.0722));
	vec3 saturated = mix(vec3(gray), enhanced, 1.0 + intensity * 0.3);

	COLOR = vec4(clamp(saturated, 0.0, 1.0), original.a);
}
"""


# -- Color Manipulation Helpers --

func _shift_for_red_green_blindness(color: Color) -> Color:
	# Shift problematic colors to be more distinguishable
	var h := color.h
	var s := color.s
	var v := color.v

	# Greens (120 degrees) shift toward cyan (180)
	# Reds (0/360 degrees) shift toward orange (30)
	if h > 60.0 / 360.0 and h < 180.0 / 360.0:  # Green range
		h = lerp(h, 180.0 / 360.0, 0.4)
	elif h < 60.0 / 360.0 or h > 300.0 / 360.0:  # Red range
		h = lerp(h, 30.0 / 360.0, 0.4) if h < 180.0 / 360.0 else lerp(h, 330.0 / 360.0, 0.4)

	return Color.from_hsv(h, s, v, color.a)


func _shift_for_blue_yellow_blindness(color: Color) -> Color:
	var h := color.h
	var s := color.s
	var v := color.v

	# Blues shift toward purple, yellows shift toward pink
	if h > 200.0 / 360.0 and h < 260.0 / 360.0:  # Blue range
		h = lerp(h, 280.0 / 360.0, 0.4)
	elif h > 40.0 / 360.0 and h < 80.0 / 360.0:  # Yellow range
		h = lerp(h, 340.0 / 360.0, 0.4)

	return Color.from_hsv(h, s, v, color.a)


func _increase_contrast(color: Color) -> Color:
	var v := color.v
	# Push toward extremes
	if v < 0.5:
		v = v * 0.7
	else:
		v = 1.0 - (1.0 - v) * 0.7

	return Color.from_hsv(color.h, min(color.s * 1.3, 1.0), v, color.a)


func _get_red_green_safe_palette() -> Array[Color]:
	# Colors distinguishable for red-green colorblind users
	return [
		Color(0.0, 0.45, 0.7),    # Blue
		Color(0.9, 0.6, 0.0),     # Orange
		Color(0.8, 0.4, 0.0),     # Vermillion
		Color(0.35, 0.7, 0.9),    # Sky Blue
		Color(0.0, 0.6, 0.5),     # Bluish Green
		Color(0.95, 0.9, 0.25),   # Yellow
		Color(0.8, 0.6, 0.7),     # Reddish Purple
		Color(0.2, 0.2, 0.2),     # Dark Gray
	]


func _get_blue_yellow_safe_palette() -> Array[Color]:
	# Colors distinguishable for blue-yellow colorblind users
	return [
		Color(0.8, 0.2, 0.2),     # Red
		Color(0.2, 0.8, 0.2),     # Green
		Color(0.9, 0.4, 0.6),     # Pink
		Color(0.4, 0.8, 0.6),     # Mint
		Color(0.5, 0.2, 0.5),     # Purple
		Color(0.2, 0.5, 0.2),     # Dark Green
		Color(0.8, 0.8, 0.8),     # Light Gray
		Color(0.3, 0.3, 0.3),     # Dark Gray
	]


func _get_grayscale_palette() -> Array[Color]:
	# High contrast grayscale palette
	return [
		Color(0.0, 0.0, 0.0),     # Black
		Color(0.2, 0.2, 0.2),     # Dark Gray
		Color(0.4, 0.4, 0.4),     # Medium Gray
		Color(0.6, 0.6, 0.6),     # Light Gray
		Color(0.8, 0.8, 0.8),     # Very Light Gray
		Color(1.0, 1.0, 1.0),     # White
	]


func _get_default_palette() -> Array[Color]:
	# Standard accessible color palette
	return [
		Color(0.122, 0.467, 0.706),  # Blue
		Color(1.0, 0.498, 0.055),    # Orange
		Color(0.173, 0.627, 0.173),  # Green
		Color(0.839, 0.153, 0.157),  # Red
		Color(0.58, 0.404, 0.741),   # Purple
		Color(0.549, 0.337, 0.294),  # Brown
		Color(0.89, 0.467, 0.761),   # Pink
		Color(0.498, 0.498, 0.498),  # Gray
		Color(0.737, 0.741, 0.133),  # Olive
		Color(0.09, 0.745, 0.812),   # Cyan
	]
