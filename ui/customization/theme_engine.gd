## ThemeEngine - Comprehensive UI theming and customization system.
##
## Provides theme presets, custom color schemes, font selection, animation control,
## and full UI appearance customization. Supports saving/loading custom themes
## and exporting/importing theme configurations.
extends Node

# -- Signals --

## Emitted when the active theme changes.
signal theme_changed(theme_name: String)
## Emitted when any theme property changes.
signal theme_property_changed(property: String, value: Variant)
## Emitted when a custom theme is saved.
signal custom_theme_saved(theme_name: String)
## Emitted when a custom theme is deleted.
signal custom_theme_deleted(theme_name: String)

# -- Constants --

const THEMES_PATH: String = "user://themes/"
const ACTIVE_THEME_PATH: String = "user://active_theme.cfg"
const DEFAULT_THEME_NAME: String = "Default"

# Built-in theme presets
const PRESET_THEMES: Dictionary = {
	"Default": {
		"primary_color": Color(0.2, 0.6, 1.0),
		"secondary_color": Color(0.15, 0.45, 0.75),
		"accent_color": Color(1.0, 0.7, 0.2),
		"background_color": Color(0.1, 0.1, 0.15),
		"surface_color": Color(0.15, 0.15, 0.2),
		"text_color": Color(1.0, 1.0, 1.0),
		"text_secondary_color": Color(0.7, 0.7, 0.7),
		"success_color": Color(0.3, 0.85, 0.4),
		"warning_color": Color(1.0, 0.8, 0.2),
		"error_color": Color(0.9, 0.3, 0.3),
		"border_radius": 8,
		"border_width": 2,
		"animation_speed": 1.0,
		"particle_density": 1.0,
	},
	"Dark Mode": {
		"primary_color": Color(0.3, 0.5, 0.9),
		"secondary_color": Color(0.2, 0.35, 0.65),
		"accent_color": Color(0.95, 0.6, 0.1),
		"background_color": Color(0.05, 0.05, 0.08),
		"surface_color": Color(0.1, 0.1, 0.13),
		"text_color": Color(0.95, 0.95, 0.95),
		"text_secondary_color": Color(0.6, 0.6, 0.65),
		"success_color": Color(0.25, 0.8, 0.35),
		"warning_color": Color(0.95, 0.75, 0.15),
		"error_color": Color(0.85, 0.25, 0.25),
		"border_radius": 6,
		"border_width": 1,
		"animation_speed": 1.0,
		"particle_density": 1.0,
	},
	"Light Mode": {
		"primary_color": Color(0.1, 0.4, 0.8),
		"secondary_color": Color(0.15, 0.5, 0.9),
		"accent_color": Color(0.9, 0.5, 0.1),
		"background_color": Color(0.95, 0.95, 0.97),
		"surface_color": Color(1.0, 1.0, 1.0),
		"text_color": Color(0.1, 0.1, 0.15),
		"text_secondary_color": Color(0.4, 0.4, 0.45),
		"success_color": Color(0.2, 0.7, 0.3),
		"warning_color": Color(0.85, 0.65, 0.1),
		"error_color": Color(0.8, 0.2, 0.2),
		"border_radius": 8,
		"border_width": 1,
		"animation_speed": 1.0,
		"particle_density": 1.0,
	},
	"High Contrast": {
		"primary_color": Color(0.0, 0.8, 1.0),
		"secondary_color": Color(0.0, 0.6, 0.8),
		"accent_color": Color(1.0, 1.0, 0.0),
		"background_color": Color(0.0, 0.0, 0.0),
		"surface_color": Color(0.05, 0.05, 0.05),
		"text_color": Color(1.0, 1.0, 1.0),
		"text_secondary_color": Color(0.9, 0.9, 0.9),
		"success_color": Color(0.0, 1.0, 0.0),
		"warning_color": Color(1.0, 1.0, 0.0),
		"error_color": Color(1.0, 0.0, 0.0),
		"border_radius": 0,
		"border_width": 3,
		"animation_speed": 0.5,
		"particle_density": 0.5,
	},
	"Neon Cyberpunk": {
		"primary_color": Color(1.0, 0.0, 0.5),
		"secondary_color": Color(0.0, 1.0, 0.8),
		"accent_color": Color(1.0, 0.9, 0.0),
		"background_color": Color(0.05, 0.0, 0.1),
		"surface_color": Color(0.1, 0.05, 0.15),
		"text_color": Color(0.9, 0.95, 1.0),
		"text_secondary_color": Color(0.6, 0.7, 0.8),
		"success_color": Color(0.0, 1.0, 0.5),
		"warning_color": Color(1.0, 0.5, 0.0),
		"error_color": Color(1.0, 0.0, 0.3),
		"border_radius": 4,
		"border_width": 2,
		"animation_speed": 1.2,
		"particle_density": 1.5,
	},
	"Military": {
		"primary_color": Color(0.4, 0.5, 0.35),
		"secondary_color": Color(0.3, 0.4, 0.25),
		"accent_color": Color(0.9, 0.7, 0.4),
		"background_color": Color(0.15, 0.15, 0.12),
		"surface_color": Color(0.2, 0.2, 0.17),
		"text_color": Color(0.9, 0.9, 0.85),
		"text_secondary_color": Color(0.7, 0.7, 0.65),
		"success_color": Color(0.4, 0.7, 0.3),
		"warning_color": Color(0.9, 0.7, 0.2),
		"error_color": Color(0.8, 0.3, 0.2),
		"border_radius": 2,
		"border_width": 2,
		"animation_speed": 0.8,
		"particle_density": 0.7,
	},
	"Minimal": {
		"primary_color": Color(0.2, 0.2, 0.2),
		"secondary_color": Color(0.3, 0.3, 0.3),
		"accent_color": Color(0.4, 0.4, 0.4),
		"background_color": Color(0.98, 0.98, 0.98),
		"surface_color": Color(1.0, 1.0, 1.0),
		"text_color": Color(0.1, 0.1, 0.1),
		"text_secondary_color": Color(0.5, 0.5, 0.5),
		"success_color": Color(0.3, 0.6, 0.3),
		"warning_color": Color(0.7, 0.6, 0.3),
		"error_color": Color(0.7, 0.3, 0.3),
		"border_radius": 4,
		"border_width": 1,
		"animation_speed": 0.5,
		"particle_density": 0.3,
	},
	"Retro Arcade": {
		"primary_color": Color(0.0, 0.8, 0.2),
		"secondary_color": Color(0.8, 0.0, 0.8),
		"accent_color": Color(1.0, 0.8, 0.0),
		"background_color": Color(0.0, 0.0, 0.1),
		"surface_color": Color(0.0, 0.05, 0.15),
		"text_color": Color(0.0, 1.0, 0.3),
		"text_secondary_color": Color(0.0, 0.7, 0.2),
		"success_color": Color(0.0, 1.0, 0.0),
		"warning_color": Color(1.0, 1.0, 0.0),
		"error_color": Color(1.0, 0.0, 0.0),
		"border_radius": 0,
		"border_width": 2,
		"animation_speed": 1.5,
		"particle_density": 1.2,
	},
}

# -- Enums --

## Font weight options.
enum FontWeight {
	LIGHT,
	REGULAR,
	MEDIUM,
	BOLD,
	EXTRA_BOLD
}

## Border style options.
enum BorderStyle {
	NONE,
	SOLID,
	DASHED,
	DOUBLE,
	GLOW
}

# -- Current Theme Properties --

## Active theme name.
var active_theme_name: String = DEFAULT_THEME_NAME:
	set(value):
		active_theme_name = value
		_apply_theme()
		theme_changed.emit(value)

## Primary color (main brand color).
var primary_color: Color = Color(0.2, 0.6, 1.0):
	set(value):
		primary_color = value
		theme_property_changed.emit("primary_color", value)

## Secondary color (supporting color).
var secondary_color: Color = Color(0.15, 0.45, 0.75):
	set(value):
		secondary_color = value
		theme_property_changed.emit("secondary_color", value)

## Accent color (highlights, CTAs).
var accent_color: Color = Color(1.0, 0.7, 0.2):
	set(value):
		accent_color = value
		theme_property_changed.emit("accent_color", value)

## Background color.
var background_color: Color = Color(0.1, 0.1, 0.15):
	set(value):
		background_color = value
		theme_property_changed.emit("background_color", value)

## Surface/panel color.
var surface_color: Color = Color(0.15, 0.15, 0.2):
	set(value):
		surface_color = value
		theme_property_changed.emit("surface_color", value)

## Primary text color.
var text_color: Color = Color(1.0, 1.0, 1.0):
	set(value):
		text_color = value
		theme_property_changed.emit("text_color", value)

## Secondary text color.
var text_secondary_color: Color = Color(0.7, 0.7, 0.7):
	set(value):
		text_secondary_color = value
		theme_property_changed.emit("text_secondary_color", value)

## Success state color.
var success_color: Color = Color(0.3, 0.85, 0.4):
	set(value):
		success_color = value
		theme_property_changed.emit("success_color", value)

## Warning state color.
var warning_color: Color = Color(1.0, 0.8, 0.2):
	set(value):
		warning_color = value
		theme_property_changed.emit("warning_color", value)

## Error state color.
var error_color: Color = Color(0.9, 0.3, 0.3):
	set(value):
		error_color = value
		theme_property_changed.emit("error_color", value)

## Border radius for UI elements.
var border_radius: int = 8:
	set(value):
		border_radius = clampi(value, 0, 32)
		theme_property_changed.emit("border_radius", value)

## Border width.
var border_width: int = 2:
	set(value):
		border_width = clampi(value, 0, 8)
		theme_property_changed.emit("border_width", value)

## Border style.
var border_style: BorderStyle = BorderStyle.SOLID:
	set(value):
		border_style = value
		theme_property_changed.emit("border_style", value)

## Animation speed multiplier.
var animation_speed: float = 1.0:
	set(value):
		animation_speed = clampf(value, 0.0, 2.0)
		theme_property_changed.emit("animation_speed", value)

## Particle effect density.
var particle_density: float = 1.0:
	set(value):
		particle_density = clampf(value, 0.0, 2.0)
		theme_property_changed.emit("particle_density", value)

## Font family name.
var font_family: String = "":
	set(value):
		font_family = value
		theme_property_changed.emit("font_family", value)

## Font weight.
var font_weight: FontWeight = FontWeight.REGULAR:
	set(value):
		font_weight = value
		theme_property_changed.emit("font_weight", value)

## Base font size.
var base_font_size: int = 16:
	set(value):
		base_font_size = clampi(value, 10, 32)
		theme_property_changed.emit("base_font_size", value)

## Background image path.
var background_image_path: String = "":
	set(value):
		background_image_path = value
		theme_property_changed.emit("background_image_path", value)

## Background image opacity.
var background_image_opacity: float = 0.3:
	set(value):
		background_image_opacity = clampf(value, 0.0, 1.0)
		theme_property_changed.emit("background_image_opacity", value)

## Button opacity.
var button_opacity: float = 1.0:
	set(value):
		button_opacity = clampf(value, 0.3, 1.0)
		theme_property_changed.emit("button_opacity", value)

## Panel opacity.
var panel_opacity: float = 0.95:
	set(value):
		panel_opacity = clampf(value, 0.3, 1.0)
		theme_property_changed.emit("panel_opacity", value)

## HUD element opacity.
var hud_opacity: float = 0.9:
	set(value):
		hud_opacity = clampf(value, 0.2, 1.0)
		theme_property_changed.emit("hud_opacity", value)

## Enable glow effects.
var glow_enabled: bool = true:
	set(value):
		glow_enabled = value
		theme_property_changed.emit("glow_enabled", value)

## Glow intensity.
var glow_intensity: float = 0.5:
	set(value):
		glow_intensity = clampf(value, 0.0, 1.0)
		theme_property_changed.emit("glow_intensity", value)

## Shadow enabled.
var shadow_enabled: bool = true:
	set(value):
		shadow_enabled = value
		theme_property_changed.emit("shadow_enabled", value)

## Shadow offset.
var shadow_offset: Vector2 = Vector2(2, 2):
	set(value):
		shadow_offset = value
		theme_property_changed.emit("shadow_offset", value)

## Shadow color.
var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.5):
	set(value):
		shadow_color = value
		theme_property_changed.emit("shadow_color", value)

# -- Internal State --

var _custom_themes: Dictionary = {}  # theme_name -> theme_data
var _generated_theme: Theme = null


# -- Lifecycle --

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_themes_directory()
	_load_custom_themes()
	_load_active_theme()


func _ensure_themes_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("themes"):
		dir.make_dir("themes")


# -- Public API: Theme Management --

## Get list of all available theme names.
func get_available_themes() -> Array[String]:
	var themes: Array[String] = []

	# Add preset themes
	for theme_name: String in PRESET_THEMES.keys():
		themes.append(theme_name)

	# Add custom themes
	for theme_name: String in _custom_themes.keys():
		if theme_name not in themes:
			themes.append(theme_name)

	return themes


## Get list of preset theme names.
func get_preset_themes() -> Array[String]:
	var themes: Array[String] = []
	for theme_name: String in PRESET_THEMES.keys():
		themes.append(theme_name)
	return themes


## Get list of custom theme names.
func get_custom_themes() -> Array[String]:
	var themes: Array[String] = []
	for theme_name: String in _custom_themes.keys():
		themes.append(theme_name)
	return themes


## Apply a theme by name.
func apply_theme(theme_name: String) -> bool:
	if theme_name in PRESET_THEMES:
		_apply_theme_data(PRESET_THEMES[theme_name])
		active_theme_name = theme_name
		_save_active_theme()
		return true
	elif theme_name in _custom_themes:
		_apply_theme_data(_custom_themes[theme_name])
		active_theme_name = theme_name
		_save_active_theme()
		return true

	push_warning("ThemeEngine: Theme '%s' not found" % theme_name)
	return false


## Save current settings as a custom theme.
func save_custom_theme(theme_name: String) -> bool:
	if theme_name in PRESET_THEMES:
		push_warning("ThemeEngine: Cannot overwrite preset theme '%s'" % theme_name)
		return false

	var theme_data := _get_current_theme_data()
	_custom_themes[theme_name] = theme_data

	# Save to file
	var path := THEMES_PATH + theme_name.to_lower().replace(" ", "_") + ".theme"
	var cfg := ConfigFile.new()

	for key: String in theme_data.keys():
		cfg.set_value("theme", key, theme_data[key])

	var err := cfg.save(path)
	if err != OK:
		push_warning("ThemeEngine: Failed to save theme '%s' - error %d" % [theme_name, err])
		return false

	custom_theme_saved.emit(theme_name)
	return true


## Delete a custom theme.
func delete_custom_theme(theme_name: String) -> bool:
	if theme_name not in _custom_themes:
		return false

	_custom_themes.erase(theme_name)

	# Delete file
	var path := THEMES_PATH + theme_name.to_lower().replace(" ", "_") + ".theme"
	var dir := DirAccess.open(THEMES_PATH)
	if dir:
		dir.remove(path)

	custom_theme_deleted.emit(theme_name)

	# If this was the active theme, switch to default
	if active_theme_name == theme_name:
		apply_theme(DEFAULT_THEME_NAME)

	return true


## Duplicate a theme.
func duplicate_theme(source_name: String, new_name: String) -> bool:
	var source_data: Dictionary

	if source_name in PRESET_THEMES:
		source_data = PRESET_THEMES[source_name].duplicate()
	elif source_name in _custom_themes:
		source_data = _custom_themes[source_name].duplicate()
	else:
		return false

	_custom_themes[new_name] = source_data
	return save_custom_theme(new_name)


## Reset to default theme.
func reset_to_default() -> void:
	apply_theme(DEFAULT_THEME_NAME)


## Check if a theme is a preset (non-editable).
func is_preset_theme(theme_name: String) -> bool:
	return theme_name in PRESET_THEMES


# -- Public API: Export/Import --

## Export theme to JSON string.
func export_theme_json(theme_name: String = "") -> String:
	var theme_data: Dictionary

	if theme_name.is_empty():
		theme_data = _get_current_theme_data()
	elif theme_name in _custom_themes:
		theme_data = _custom_themes[theme_name]
	elif theme_name in PRESET_THEMES:
		theme_data = PRESET_THEMES[theme_name]
	else:
		return ""

	# Convert colors to hex strings for JSON compatibility
	var export_data := {}
	for key: String in theme_data.keys():
		var value: Variant = theme_data[key]
		if value is Color:
			export_data[key] = "#" + (value as Color).to_html(true)
		elif value is Vector2:
			export_data[key] = {"x": (value as Vector2).x, "y": (value as Vector2).y}
		else:
			export_data[key] = value

	return JSON.stringify(export_data, "  ")


## Import theme from JSON string.
func import_theme_json(json_string: String, theme_name: String) -> bool:
	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		push_warning("ThemeEngine: Failed to parse theme JSON - %s" % json.get_error_message())
		return false

	var data: Variant = json.data
	if not data is Dictionary:
		push_warning("ThemeEngine: Invalid theme data format")
		return false

	# Convert hex strings back to colors
	var theme_data := {}
	for key: String in (data as Dictionary).keys():
		var value: Variant = (data as Dictionary)[key]
		if value is String and (value as String).begins_with("#"):
			theme_data[key] = Color((value as String))
		elif value is Dictionary and (value as Dictionary).has("x") and (value as Dictionary).has("y"):
			theme_data[key] = Vector2((value as Dictionary)["x"], (value as Dictionary)["y"])
		else:
			theme_data[key] = value

	_custom_themes[theme_name] = theme_data
	return save_custom_theme(theme_name)


## Export theme to clipboard.
func export_to_clipboard(theme_name: String = "") -> void:
	var json := export_theme_json(theme_name)
	if not json.is_empty():
		DisplayServer.clipboard_set(json)


## Import theme from clipboard.
func import_from_clipboard(theme_name: String) -> bool:
	var json := DisplayServer.clipboard_get()
	return import_theme_json(json, theme_name)


# -- Public API: Theme Generation --

## Generate a Godot Theme resource from current settings.
func generate_godot_theme() -> Theme:
	_generated_theme = Theme.new()

	# Button styles
	_add_button_styles()

	# Panel styles
	_add_panel_styles()

	# Label styles
	_add_label_styles()

	# Line edit styles
	_add_line_edit_styles()

	# Slider styles
	_add_slider_styles()

	# Progress bar styles
	_add_progress_bar_styles()

	# Check box/button styles
	_add_check_styles()

	# Tab styles
	_add_tab_styles()

	return _generated_theme


## Apply generated theme to the project.
func apply_to_project() -> void:
	var theme := generate_godot_theme()
	# This would set the project default theme
	# In Godot 4, this is typically done through project settings or directly on the root control


# -- Public API: Color Utilities --

## Get a lighter version of a color.
func get_lighter(color: Color, amount: float = 0.2) -> Color:
	return color.lightened(amount)


## Get a darker version of a color.
func get_darker(color: Color, amount: float = 0.2) -> Color:
	return color.darkened(amount)


## Get hover color for a base color.
func get_hover_color(base: Color) -> Color:
	return base.lightened(0.15)


## Get pressed color for a base color.
func get_pressed_color(base: Color) -> Color:
	return base.darkened(0.15)


## Get disabled color for a base color.
func get_disabled_color(base: Color) -> Color:
	var gray := base.lightened(0.2)
	gray.s *= 0.3  # Reduce saturation
	return gray


## Generate complementary color.
func get_complementary(color: Color) -> Color:
	var h := color.h + 0.5
	if h > 1.0:
		h -= 1.0
	return Color.from_hsv(h, color.s, color.v, color.a)


## Generate triadic colors.
func get_triadic(color: Color) -> Array[Color]:
	var colors: Array[Color] = []
	colors.append(Color.from_hsv(fmod(color.h + 0.333, 1.0), color.s, color.v, color.a))
	colors.append(Color.from_hsv(fmod(color.h + 0.666, 1.0), color.s, color.v, color.a))
	return colors


# -- Internal Methods --

func _apply_theme_data(theme_data: Dictionary) -> void:
	if theme_data.has("primary_color"):
		primary_color = theme_data["primary_color"]
	if theme_data.has("secondary_color"):
		secondary_color = theme_data["secondary_color"]
	if theme_data.has("accent_color"):
		accent_color = theme_data["accent_color"]
	if theme_data.has("background_color"):
		background_color = theme_data["background_color"]
	if theme_data.has("surface_color"):
		surface_color = theme_data["surface_color"]
	if theme_data.has("text_color"):
		text_color = theme_data["text_color"]
	if theme_data.has("text_secondary_color"):
		text_secondary_color = theme_data["text_secondary_color"]
	if theme_data.has("success_color"):
		success_color = theme_data["success_color"]
	if theme_data.has("warning_color"):
		warning_color = theme_data["warning_color"]
	if theme_data.has("error_color"):
		error_color = theme_data["error_color"]
	if theme_data.has("border_radius"):
		border_radius = theme_data["border_radius"]
	if theme_data.has("border_width"):
		border_width = theme_data["border_width"]
	if theme_data.has("animation_speed"):
		animation_speed = theme_data["animation_speed"]
	if theme_data.has("particle_density"):
		particle_density = theme_data["particle_density"]


func _get_current_theme_data() -> Dictionary:
	return {
		"primary_color": primary_color,
		"secondary_color": secondary_color,
		"accent_color": accent_color,
		"background_color": background_color,
		"surface_color": surface_color,
		"text_color": text_color,
		"text_secondary_color": text_secondary_color,
		"success_color": success_color,
		"warning_color": warning_color,
		"error_color": error_color,
		"border_radius": border_radius,
		"border_width": border_width,
		"border_style": border_style,
		"animation_speed": animation_speed,
		"particle_density": particle_density,
		"font_family": font_family,
		"font_weight": font_weight,
		"base_font_size": base_font_size,
		"background_image_path": background_image_path,
		"background_image_opacity": background_image_opacity,
		"button_opacity": button_opacity,
		"panel_opacity": panel_opacity,
		"hud_opacity": hud_opacity,
		"glow_enabled": glow_enabled,
		"glow_intensity": glow_intensity,
		"shadow_enabled": shadow_enabled,
		"shadow_offset": shadow_offset,
		"shadow_color": shadow_color,
	}


func _apply_theme() -> void:
	# Apply theme changes to all existing UI
	theme_changed.emit(active_theme_name)


func _load_custom_themes() -> void:
	var dir := DirAccess.open(THEMES_PATH)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".theme"):
			_load_theme_file(THEMES_PATH + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()


func _load_theme_file(path: String) -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return

	var theme_data := {}
	for key: String in cfg.get_section_keys("theme"):
		theme_data[key] = cfg.get_value("theme", key)

	# Extract theme name from file path
	var file_name := path.get_file().get_basename()
	var theme_name := file_name.replace("_", " ").capitalize()

	_custom_themes[theme_name] = theme_data


func _save_active_theme() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("active", "theme_name", active_theme_name)

	# Also save current state in case it's a modified preset
	var theme_data := _get_current_theme_data()
	for key: String in theme_data.keys():
		cfg.set_value("current", key, theme_data[key])

	cfg.save(ACTIVE_THEME_PATH)


func _load_active_theme() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(ACTIVE_THEME_PATH)
	if err != OK:
		apply_theme(DEFAULT_THEME_NAME)
		return

	var theme_name: String = cfg.get_value("active", "theme_name", DEFAULT_THEME_NAME)
	apply_theme(theme_name)


# -- Theme Generation Helpers --

func _add_button_styles() -> void:
	if not _generated_theme:
		return

	# Normal state
	var normal := StyleBoxFlat.new()
	normal.bg_color = primary_color
	normal.bg_color.a = button_opacity
	normal.set_corner_radius_all(border_radius)
	normal.border_width_bottom = border_width
	normal.border_width_left = border_width
	normal.border_width_right = border_width
	normal.border_width_top = border_width
	normal.border_color = get_darker(primary_color, 0.2)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	_generated_theme.set_stylebox("normal", "Button", normal)

	# Hover state
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = get_hover_color(primary_color)
	_generated_theme.set_stylebox("hover", "Button", hover)

	# Pressed state
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = get_pressed_color(primary_color)
	_generated_theme.set_stylebox("pressed", "Button", pressed)

	# Disabled state
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = get_disabled_color(primary_color)
	_generated_theme.set_stylebox("disabled", "Button", disabled)

	# Focus state
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(border_radius + 2)
	focus.border_width_bottom = 2
	focus.border_width_left = 2
	focus.border_width_right = 2
	focus.border_width_top = 2
	focus.border_color = accent_color
	_generated_theme.set_stylebox("focus", "Button", focus)

	# Colors
	_generated_theme.set_color("font_color", "Button", text_color)
	_generated_theme.set_color("font_hover_color", "Button", text_color)
	_generated_theme.set_color("font_pressed_color", "Button", text_color)
	_generated_theme.set_color("font_disabled_color", "Button", text_secondary_color)

	# Font size
	_generated_theme.set_font_size("font_size", "Button", base_font_size)


func _add_panel_styles() -> void:
	if not _generated_theme:
		return

	var panel := StyleBoxFlat.new()
	panel.bg_color = surface_color
	panel.bg_color.a = panel_opacity
	panel.set_corner_radius_all(border_radius)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 16
	panel.content_margin_bottom = 16

	if shadow_enabled:
		panel.shadow_color = shadow_color
		panel.shadow_offset = shadow_offset
		panel.shadow_size = 4

	_generated_theme.set_stylebox("panel", "PanelContainer", panel)
	_generated_theme.set_stylebox("panel", "Panel", panel)


func _add_label_styles() -> void:
	if not _generated_theme:
		return

	_generated_theme.set_color("font_color", "Label", text_color)
	_generated_theme.set_font_size("font_size", "Label", base_font_size)

	if shadow_enabled:
		_generated_theme.set_color("font_shadow_color", "Label", shadow_color)
		_generated_theme.set_constant("shadow_offset_x", "Label", int(shadow_offset.x))
		_generated_theme.set_constant("shadow_offset_y", "Label", int(shadow_offset.y))


func _add_line_edit_styles() -> void:
	if not _generated_theme:
		return

	var normal := StyleBoxFlat.new()
	normal.bg_color = get_darker(surface_color, 0.1)
	normal.set_corner_radius_all(border_radius / 2)
	normal.border_width_bottom = border_width
	normal.border_width_left = border_width
	normal.border_width_right = border_width
	normal.border_width_top = border_width
	normal.border_color = get_darker(surface_color, 0.3)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	_generated_theme.set_stylebox("normal", "LineEdit", normal)

	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = primary_color
	_generated_theme.set_stylebox("focus", "LineEdit", focus)

	_generated_theme.set_color("font_color", "LineEdit", text_color)
	_generated_theme.set_color("font_placeholder_color", "LineEdit", text_secondary_color)
	_generated_theme.set_color("caret_color", "LineEdit", accent_color)
	_generated_theme.set_color("selection_color", "LineEdit", Color(primary_color.r, primary_color.g, primary_color.b, 0.4))


func _add_slider_styles() -> void:
	if not _generated_theme:
		return

	# Slider track
	var slider := StyleBoxFlat.new()
	slider.bg_color = get_darker(surface_color, 0.2)
	slider.set_corner_radius_all(4)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	_generated_theme.set_stylebox("slider", "HSlider", slider)
	_generated_theme.set_stylebox("slider", "VSlider", slider)

	# Grabber area (filled portion)
	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = primary_color
	grabber_area.set_corner_radius_all(4)
	_generated_theme.set_stylebox("grabber_area", "HSlider", grabber_area)
	_generated_theme.set_stylebox("grabber_area", "VSlider", grabber_area)

	var grabber_area_highlight := grabber_area.duplicate() as StyleBoxFlat
	grabber_area_highlight.bg_color = get_hover_color(primary_color)
	_generated_theme.set_stylebox("grabber_area_highlight", "HSlider", grabber_area_highlight)
	_generated_theme.set_stylebox("grabber_area_highlight", "VSlider", grabber_area_highlight)


func _add_progress_bar_styles() -> void:
	if not _generated_theme:
		return

	# Background
	var bg := StyleBoxFlat.new()
	bg.bg_color = get_darker(surface_color, 0.2)
	bg.set_corner_radius_all(border_radius / 2)
	_generated_theme.set_stylebox("background", "ProgressBar", bg)

	# Fill
	var fill := StyleBoxFlat.new()
	fill.bg_color = primary_color
	fill.set_corner_radius_all(border_radius / 2)
	_generated_theme.set_stylebox("fill", "ProgressBar", fill)

	_generated_theme.set_color("font_color", "ProgressBar", text_color)


func _add_check_styles() -> void:
	if not _generated_theme:
		return

	# CheckBox/CheckButton colors
	_generated_theme.set_color("font_color", "CheckBox", text_color)
	_generated_theme.set_color("font_hover_color", "CheckBox", get_hover_color(text_color))
	_generated_theme.set_color("font_pressed_color", "CheckBox", text_color)

	_generated_theme.set_color("font_color", "CheckButton", text_color)
	_generated_theme.set_color("font_hover_color", "CheckButton", get_hover_color(text_color))
	_generated_theme.set_color("font_pressed_color", "CheckButton", text_color)


func _add_tab_styles() -> void:
	if not _generated_theme:
		return

	# TabBar unselected
	var unselected := StyleBoxFlat.new()
	unselected.bg_color = surface_color
	unselected.set_corner_radius_all(border_radius)
	unselected.corner_radius_bottom_left = 0
	unselected.corner_radius_bottom_right = 0
	_generated_theme.set_stylebox("tab_unselected", "TabBar", unselected)

	# TabBar selected
	var selected := StyleBoxFlat.new()
	selected.bg_color = primary_color
	selected.set_corner_radius_all(border_radius)
	selected.corner_radius_bottom_left = 0
	selected.corner_radius_bottom_right = 0
	_generated_theme.set_stylebox("tab_selected", "TabBar", selected)

	# TabBar hovered
	var hovered := unselected.duplicate() as StyleBoxFlat
	hovered.bg_color = get_hover_color(surface_color)
	_generated_theme.set_stylebox("tab_hovered", "TabBar", hovered)

	_generated_theme.set_color("font_selected_color", "TabBar", text_color)
	_generated_theme.set_color("font_unselected_color", "TabBar", text_secondary_color)
	_generated_theme.set_color("font_hovered_color", "TabBar", text_color)
