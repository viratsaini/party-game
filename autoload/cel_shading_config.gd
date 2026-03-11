## Global cel-shading configuration singleton.
## Provides centralized control over all cel-shading parameters.
## Access via CelShadingConfig autoload.
class_name CelShadingConfigClass
extends Node

#region Signals
signal quality_changed(new_quality: CelShadedMaterials.CelQuality)
signal settings_changed()
signal outlines_toggled(enabled: bool)
#endregion

#region Configuration Export
@export_group("Quality Settings")
## Current quality level - affects all cel-shaded materials
@export var quality: CelShadedMaterials.CelQuality = CelShadedMaterials.CelQuality.MEDIUM:
	set(value):
		quality = value
		_apply_quality_settings()
		quality_changed.emit(quality)

## Enable/disable outlines globally
@export var outlines_enabled: bool = true:
	set(value):
		outlines_enabled = value
		outlines_toggled.emit(outlines_enabled)

@export_group("Cel Shading Parameters")
## Number of shading steps (2-8)
@export_range(2, 8, 1) var cel_levels: int = 4

## Sharpness of cel transitions (0 = smooth, 1 = hard)
@export_range(0.0, 1.0) var cel_sharpness: float = 0.85

## Shadow darkness (0 = no shadow, 1 = full shadow)
@export_range(0.0, 1.0) var shadow_intensity: float = 0.55

## Shadow tint color
@export var shadow_color: Color = Color(0.15, 0.1, 0.2)

@export_group("Rim Lighting")
## Enable rim lighting effect
@export var rim_enabled: bool = true

## Rim light color
@export var rim_color: Color = Color(1.0, 1.0, 1.0)

## Rim light intensity
@export_range(0.0, 2.0) var rim_intensity: float = 0.7

## Rim light power (affects falloff)
@export_range(0.5, 8.0) var rim_power: float = 3.0

## Rim threshold for cel-style rim
@export_range(0.0, 1.0) var rim_threshold: float = 0.5

@export_group("Specular Highlights")
## Enable specular highlights
@export var specular_enabled: bool = true

## Specular highlight color
@export var specular_color: Color = Color(1.0, 1.0, 1.0)

## Specular intensity
@export_range(0.0, 2.0) var specular_intensity: float = 0.6

## Specular highlight size
@export_range(0.0, 1.0) var specular_size: float = 0.2

@export_group("Outline Settings")
## Base outline width
@export_range(0.0, 0.1) var outline_width: float = 0.025

## Minimum outline width
@export_range(0.0, 0.05) var min_outline_width: float = 0.012

## Maximum outline width
@export_range(0.0, 0.15) var max_outline_width: float = 0.06

## Reference distance for outline scaling
@export_range(1.0, 50.0) var reference_distance: float = 12.0

## Outline color
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 1.0)

## Enable silhouette enhancement
@export var enhance_silhouette: bool = true
#endregion

#region Quality Presets
const QUALITY_PRESETS := {
	CelShadedMaterials.CelQuality.LOW: {
		"cel_levels": 3,
		"cel_sharpness": 0.7,
		"rim_enabled": false,
		"specular_enabled": false,
		"outline_width": 0.02,
		"enhance_silhouette": false,
	},
	CelShadedMaterials.CelQuality.MEDIUM: {
		"cel_levels": 4,
		"cel_sharpness": 0.85,
		"rim_enabled": true,
		"specular_enabled": false,
		"outline_width": 0.025,
		"enhance_silhouette": true,
	},
	CelShadedMaterials.CelQuality.HIGH: {
		"cel_levels": 5,
		"cel_sharpness": 0.9,
		"rim_enabled": true,
		"specular_enabled": true,
		"outline_width": 0.03,
		"enhance_silhouette": true,
	},
}
#endregion

#region Lifecycle
func _ready() -> void:
	_apply_quality_settings()
#endregion

#region Quality Management
## Apply settings based on current quality level
func _apply_quality_settings() -> void:
	if QUALITY_PRESETS.has(quality):
		var preset: Dictionary = QUALITY_PRESETS[quality]
		cel_levels = preset.get("cel_levels", cel_levels)
		cel_sharpness = preset.get("cel_sharpness", cel_sharpness)
		rim_enabled = preset.get("rim_enabled", rim_enabled)
		specular_enabled = preset.get("specular_enabled", specular_enabled)
		outline_width = preset.get("outline_width", outline_width)
		enhance_silhouette = preset.get("enhance_silhouette", enhance_silhouette)
		settings_changed.emit()


## Set quality and optionally save to settings
func set_quality(new_quality: CelShadedMaterials.CelQuality, save: bool = false) -> void:
	quality = new_quality
	if save:
		save_settings()


## Auto-detect appropriate quality based on device
func auto_detect_quality() -> CelShadedMaterials.CelQuality:
	# Check if running on mobile
	var os_name := OS.get_name()
	var is_mobile := os_name in ["Android", "iOS"]

	if is_mobile:
		# Check device performance (simple heuristic based on screen size)
		var screen_size := DisplayServer.screen_get_size()
		var total_pixels := screen_size.x * screen_size.y

		if total_pixels < 1920 * 1080:
			return CelShadedMaterials.CelQuality.LOW
		elif total_pixels < 2560 * 1440:
			return CelShadedMaterials.CelQuality.MEDIUM
		else:
			return CelShadedMaterials.CelQuality.MEDIUM  # Cap at medium for mobile
	else:
		# Desktop - use high quality
		return CelShadedMaterials.CelQuality.HIGH
#endregion

#region Material Application
## Apply current settings to a cel-shaded material
func apply_to_material(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("cel_levels", cel_levels)
	mat.set_shader_parameter("cel_sharpness", cel_sharpness)
	mat.set_shader_parameter("shadow_intensity", shadow_intensity)
	mat.set_shader_parameter("shadow_color", shadow_color)

	mat.set_shader_parameter("enable_rim_light", rim_enabled)
	mat.set_shader_parameter("rim_color", rim_color)
	mat.set_shader_parameter("rim_intensity", rim_intensity)
	mat.set_shader_parameter("rim_power", rim_power)
	mat.set_shader_parameter("rim_threshold", rim_threshold)

	mat.set_shader_parameter("enable_specular", specular_enabled)
	mat.set_shader_parameter("specular_color", specular_color)
	mat.set_shader_parameter("specular_intensity", specular_intensity)
	mat.set_shader_parameter("specular_size", specular_size)


## Apply current settings to an outline material
func apply_to_outline(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("outline_width", outline_width)
	mat.set_shader_parameter("min_outline_width", min_outline_width)
	mat.set_shader_parameter("max_outline_width", max_outline_width)
	mat.set_shader_parameter("reference_distance", reference_distance)
	mat.set_shader_parameter("outline_color", outline_color)
	mat.set_shader_parameter("enhance_silhouette", enhance_silhouette)


## Create a cel material with current global settings
func create_configured_material(color: Color, preset_name: String = "character") -> ShaderMaterial:
	var mat := CelShadedMaterials.create_cel_material(color, preset_name)
	apply_to_material(mat)
	return mat


## Create an outline material with current global settings
func create_configured_outline(preset_name: String = "character") -> ShaderMaterial:
	var mat := CelShadedMaterials.create_outline_material(preset_name)
	apply_to_outline(mat)
	return mat
#endregion

#region Settings Persistence
const SETTINGS_FILE := "user://cel_shading_settings.cfg"

## Save current settings to file
func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("quality", "level", quality)
	config.set_value("quality", "outlines_enabled", outlines_enabled)

	config.set_value("cel_shading", "cel_levels", cel_levels)
	config.set_value("cel_shading", "cel_sharpness", cel_sharpness)
	config.set_value("cel_shading", "shadow_intensity", shadow_intensity)
	config.set_value("cel_shading", "shadow_color", shadow_color)

	config.set_value("rim", "enabled", rim_enabled)
	config.set_value("rim", "color", rim_color)
	config.set_value("rim", "intensity", rim_intensity)
	config.set_value("rim", "power", rim_power)
	config.set_value("rim", "threshold", rim_threshold)

	config.set_value("specular", "enabled", specular_enabled)
	config.set_value("specular", "color", specular_color)
	config.set_value("specular", "intensity", specular_intensity)
	config.set_value("specular", "size", specular_size)

	config.set_value("outline", "width", outline_width)
	config.set_value("outline", "min_width", min_outline_width)
	config.set_value("outline", "max_width", max_outline_width)
	config.set_value("outline", "reference_distance", reference_distance)
	config.set_value("outline", "color", outline_color)
	config.set_value("outline", "enhance_silhouette", enhance_silhouette)

	var err := config.save(SETTINGS_FILE)
	if err != OK:
		push_error("Failed to save cel-shading settings: %s" % error_string(err))


## Load settings from file
func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE)

	if err != OK:
		# No saved settings, use auto-detected quality
		quality = auto_detect_quality()
		return

	quality = config.get_value("quality", "level", quality)
	outlines_enabled = config.get_value("quality", "outlines_enabled", outlines_enabled)

	cel_levels = config.get_value("cel_shading", "cel_levels", cel_levels)
	cel_sharpness = config.get_value("cel_shading", "cel_sharpness", cel_sharpness)
	shadow_intensity = config.get_value("cel_shading", "shadow_intensity", shadow_intensity)
	shadow_color = config.get_value("cel_shading", "shadow_color", shadow_color)

	rim_enabled = config.get_value("rim", "enabled", rim_enabled)
	rim_color = config.get_value("rim", "color", rim_color)
	rim_intensity = config.get_value("rim", "intensity", rim_intensity)
	rim_power = config.get_value("rim", "power", rim_power)
	rim_threshold = config.get_value("rim", "threshold", rim_threshold)

	specular_enabled = config.get_value("specular", "enabled", specular_enabled)
	specular_color = config.get_value("specular", "color", specular_color)
	specular_intensity = config.get_value("specular", "intensity", specular_intensity)
	specular_size = config.get_value("specular", "size", specular_size)

	outline_width = config.get_value("outline", "width", outline_width)
	min_outline_width = config.get_value("outline", "min_width", min_outline_width)
	max_outline_width = config.get_value("outline", "max_width", max_outline_width)
	reference_distance = config.get_value("outline", "reference_distance", reference_distance)
	outline_color = config.get_value("outline", "color", outline_color)
	enhance_silhouette = config.get_value("outline", "enhance_silhouette", enhance_silhouette)

	settings_changed.emit()


## Reset to default settings
func reset_to_defaults() -> void:
	quality = auto_detect_quality()

	cel_levels = 4
	cel_sharpness = 0.85
	shadow_intensity = 0.55
	shadow_color = Color(0.15, 0.1, 0.2)

	rim_enabled = true
	rim_color = Color(1.0, 1.0, 1.0)
	rim_intensity = 0.7
	rim_power = 3.0
	rim_threshold = 0.5

	specular_enabled = true
	specular_color = Color(1.0, 1.0, 1.0)
	specular_intensity = 0.6
	specular_size = 0.2

	outline_width = 0.025
	min_outline_width = 0.012
	max_outline_width = 0.06
	reference_distance = 12.0
	outline_color = Color(0.0, 0.0, 0.0, 1.0)
	enhance_silhouette = true
	outlines_enabled = true

	settings_changed.emit()
#endregion

#region Debug / Performance
## Get estimated shader cost (relative units for comparison)
func get_estimated_shader_cost() -> float:
	var cost := 1.0  # Base cost

	# Cel levels add complexity
	cost += cel_levels * 0.1

	# Rim lighting
	if rim_enabled:
		cost += 0.3

	# Specular
	if specular_enabled:
		cost += 0.4

	# Outline (separate pass)
	if outlines_enabled:
		cost += 0.5
		if enhance_silhouette:
			cost += 0.1

	return cost


## Get a description of current quality settings
func get_quality_description() -> String:
	var features := []

	features.append("%d cel levels" % cel_levels)

	if rim_enabled:
		features.append("rim lighting")

	if specular_enabled:
		features.append("specular")

	if outlines_enabled:
		features.append("outlines")
		if enhance_silhouette:
			features.append("silhouette enhancement")

	return "Quality: %s (%s)" % [
		CelShadedMaterials.CelQuality.keys()[quality],
		", ".join(features)
	]
#endregion
