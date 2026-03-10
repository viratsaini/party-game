## Material factory for cel-shaded (toon) materials.
## Creates ShaderMaterial instances using the cel_shading.gdshader
## with presets optimized for different use cases.
## All materials are mobile-friendly and work with GL Compatibility renderer.
class_name CelShadedMaterials
extends Node

#region Shader Preloads
const CEL_SHADER_PATH := "res://shared/shaders/cel_shading.gdshader"
const OUTLINE_SHADER_PATH := "res://shared/shaders/outline_improved.gdshader"

static var _cel_shader: Shader = null
static var _outline_shader: Shader = null
#endregion

#region Configuration Presets
## Cel shading quality levels for performance tuning
enum CelQuality {
	LOW,      ## 3 cel levels, no rim light, no specular - best for low-end mobile
	MEDIUM,   ## 4 cel levels, rim light, no specular - balanced
	HIGH,     ## 5 cel levels, rim light, specular - full features
}

## Preset configurations for different object types
const PRESETS := {
	"character": {
		"cel_levels": 4,
		"cel_sharpness": 0.85,
		"shadow_intensity": 0.55,
		"shadow_color": Color(0.15, 0.1, 0.2),
		"enable_rim_light": true,
		"rim_intensity": 0.7,
		"rim_power": 3.0,
		"enable_specular": true,
		"specular_intensity": 0.5,
		"specular_size": 0.15,
	},
	"environment": {
		"cel_levels": 3,
		"cel_sharpness": 0.7,
		"shadow_intensity": 0.5,
		"shadow_color": Color(0.2, 0.15, 0.25),
		"enable_rim_light": false,
		"enable_specular": false,
	},
	"prop": {
		"cel_levels": 4,
		"cel_sharpness": 0.8,
		"shadow_intensity": 0.5,
		"shadow_color": Color(0.18, 0.12, 0.22),
		"enable_rim_light": true,
		"rim_intensity": 0.5,
		"rim_power": 4.0,
		"enable_specular": false,
	},
	"weapon": {
		"cel_levels": 4,
		"cel_sharpness": 0.9,
		"shadow_intensity": 0.4,
		"shadow_color": Color(0.1, 0.1, 0.15),
		"enable_rim_light": true,
		"rim_intensity": 0.8,
		"rim_power": 2.5,
		"enable_specular": true,
		"specular_intensity": 0.7,
		"specular_size": 0.2,
	},
	"pickup": {
		"cel_levels": 3,
		"cel_sharpness": 0.75,
		"shadow_intensity": 0.3,
		"shadow_color": Color(0.1, 0.1, 0.1),
		"enable_rim_light": true,
		"rim_intensity": 1.0,
		"rim_power": 2.0,
		"enable_specular": true,
		"specular_intensity": 0.8,
		"enable_emission": true,
		"emission_intensity": 0.5,
	},
	"projectile": {
		"cel_levels": 2,
		"cel_sharpness": 1.0,
		"shadow_intensity": 0.2,
		"enable_rim_light": true,
		"rim_intensity": 1.2,
		"rim_power": 2.0,
		"enable_emission": true,
		"emission_intensity": 1.5,
	},
}

## Outline presets
const OUTLINE_PRESETS := {
	"character": {
		"outline_width": 0.025,
		"min_outline_width": 0.012,
		"max_outline_width": 0.06,
		"reference_distance": 12.0,
		"distance_scale_factor": 0.7,
		"outline_color": Color(0.0, 0.0, 0.0, 1.0),
		"enhance_silhouette": true,
		"silhouette_boost": 1.4,
	},
	"prop": {
		"outline_width": 0.02,
		"min_outline_width": 0.008,
		"max_outline_width": 0.04,
		"reference_distance": 15.0,
		"distance_scale_factor": 0.6,
		"outline_color": Color(0.1, 0.05, 0.1, 1.0),
		"enhance_silhouette": false,
	},
	"weapon": {
		"outline_width": 0.015,
		"min_outline_width": 0.008,
		"max_outline_width": 0.035,
		"reference_distance": 10.0,
		"outline_color": Color(0.05, 0.05, 0.05, 1.0),
		"enhance_silhouette": true,
	},
}
#endregion

#region Shader Loading
## Loads and caches the cel shading shader
static func _get_cel_shader() -> Shader:
	if _cel_shader == null:
		_cel_shader = load(CEL_SHADER_PATH) as Shader
	return _cel_shader


## Loads and caches the outline shader
static func _get_outline_shader() -> Shader:
	if _outline_shader == null:
		_outline_shader = load(OUTLINE_SHADER_PATH) as Shader
	return _outline_shader
#endregion

#region Material Creation - Main API

## Creates a cel-shaded material with the given color and preset.
## [param color] Base albedo color
## [param preset_name] One of: "character", "environment", "prop", "weapon", "pickup", "projectile"
## Returns a configured ShaderMaterial
static func create_cel_material(color: Color, preset_name: String = "character") -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_cel_shader()

	# Apply base color
	mat.set_shader_parameter("albedo_color", color)

	# Apply preset if available
	if PRESETS.has(preset_name):
		_apply_preset(mat, PRESETS[preset_name])

	return mat


## Creates a cel-shaded material with team color support.
## [param base_color] Base material color
## [param team_color] Team tint color
## [param team_blend] How much team color affects the material (0.0-1.0)
static func create_team_cel_material(base_color: Color, team_color: Color, team_blend: float = 0.5) -> ShaderMaterial:
	var mat := create_cel_material(base_color, "character")
	mat.set_shader_parameter("use_team_color", true)
	mat.set_shader_parameter("team_color", team_color)
	mat.set_shader_parameter("team_color_blend", team_blend)
	return mat


## Creates an outline material with the given preset.
## [param preset_name] One of: "character", "prop", "weapon"
## [param color_override] Optional color to override preset
static func create_outline_material(preset_name: String = "character", color_override: Color = Color(-1, -1, -1)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_outline_shader()

	# Apply preset if available
	if OUTLINE_PRESETS.has(preset_name):
		for key in OUTLINE_PRESETS[preset_name]:
			mat.set_shader_parameter(key, OUTLINE_PRESETS[preset_name][key])

	# Apply color override if provided
	if color_override.r >= 0:
		mat.set_shader_parameter("outline_color", color_override)

	return mat


## Creates an outline material with team color tinting.
static func create_team_outline_material(team_color: Color, preset_name: String = "character") -> ShaderMaterial:
	var mat := create_outline_material(preset_name)
	mat.set_shader_parameter("use_team_tint", true)
	mat.set_shader_parameter("team_color", team_color)
	mat.set_shader_parameter("team_color_blend", 0.3)
	return mat


## Creates a complete character material set (cel material + outline material).
## Returns a dictionary with "main" and "outline" ShaderMaterial entries.
static func create_character_material_set(color: Color, team_color: Color = Color(-1, -1, -1)) -> Dictionary:
	var use_team := team_color.r >= 0

	var main_mat: ShaderMaterial
	var outline_mat: ShaderMaterial

	if use_team:
		main_mat = create_team_cel_material(color, team_color, 0.6)
		outline_mat = create_team_outline_material(team_color, "character")
	else:
		main_mat = create_cel_material(color, "character")
		outline_mat = create_outline_material("character")

	return {
		"main": main_mat,
		"outline": outline_mat,
	}
#endregion

#region Quality-Based Material Creation

## Creates a cel material adjusted for a specific quality level.
## Use this for performance scaling on different devices.
static func create_cel_material_for_quality(color: Color, quality: CelQuality, preset_name: String = "character") -> ShaderMaterial:
	var mat := create_cel_material(color, preset_name)

	match quality:
		CelQuality.LOW:
			mat.set_shader_parameter("cel_levels", 3)
			mat.set_shader_parameter("enable_rim_light", false)
			mat.set_shader_parameter("enable_specular", false)
			mat.set_shader_parameter("enable_fresnel", false)
		CelQuality.MEDIUM:
			mat.set_shader_parameter("cel_levels", 4)
			mat.set_shader_parameter("enable_rim_light", true)
			mat.set_shader_parameter("enable_specular", false)
			mat.set_shader_parameter("enable_fresnel", false)
		CelQuality.HIGH:
			# Use preset defaults (already high quality)
			pass

	return mat
#endregion

#region Specialized Materials

## Creates a glowing cel-shaded material (for pickups, projectiles, etc.)
static func create_glow_cel_material(color: Color, emission_strength: float = 1.5) -> ShaderMaterial:
	var mat := create_cel_material(color, "pickup")
	mat.set_shader_parameter("enable_emission", true)
	mat.set_shader_parameter("emission_color", color)
	mat.set_shader_parameter("emission_intensity", emission_strength)
	return mat


## Creates a cel-shaded material with fresnel edge glow.
## Great for energy shields, force fields, etc.
static func create_fresnel_cel_material(base_color: Color, fresnel_color: Color, fresnel_strength: float = 0.5) -> ShaderMaterial:
	var mat := create_cel_material(base_color, "character")
	mat.set_shader_parameter("enable_fresnel", true)
	mat.set_shader_parameter("fresnel_color", fresnel_color)
	mat.set_shader_parameter("fresnel_intensity", fresnel_strength)
	mat.set_shader_parameter("fresnel_power", 3.0)
	return mat


## Creates an environment/world cel-shaded material (optimized for static geometry)
static func create_environment_cel_material(color: Color) -> ShaderMaterial:
	return create_cel_material(color, "environment")


## Creates a weapon cel-shaded material with enhanced specular.
static func create_weapon_cel_material(color: Color) -> ShaderMaterial:
	return create_cel_material(color, "weapon")
#endregion

#region Material Modification

## Updates the team color on an existing cel-shaded material.
static func set_team_color(mat: ShaderMaterial, team_color: Color, blend: float = 0.5) -> void:
	mat.set_shader_parameter("use_team_color", true)
	mat.set_shader_parameter("team_color", team_color)
	mat.set_shader_parameter("team_color_blend", blend)


## Updates the base color on an existing cel-shaded material.
static func set_base_color(mat: ShaderMaterial, color: Color) -> void:
	mat.set_shader_parameter("albedo_color", color)


## Updates rim lighting parameters on an existing material.
static func set_rim_light(mat: ShaderMaterial, enabled: bool, color: Color = Color.WHITE, intensity: float = 0.8) -> void:
	mat.set_shader_parameter("enable_rim_light", enabled)
	if enabled:
		mat.set_shader_parameter("rim_color", color)
		mat.set_shader_parameter("rim_intensity", intensity)


## Updates outline color on an outline material.
static func set_outline_color(mat: ShaderMaterial, color: Color) -> void:
	mat.set_shader_parameter("outline_color", color)


## Updates outline width on an outline material.
static func set_outline_width(mat: ShaderMaterial, width: float) -> void:
	mat.set_shader_parameter("outline_width", width)


## Sets cel shading parameters for fine-tuning.
static func set_cel_parameters(mat: ShaderMaterial, levels: int, sharpness: float, shadow_intensity: float) -> void:
	mat.set_shader_parameter("cel_levels", levels)
	mat.set_shader_parameter("cel_sharpness", sharpness)
	mat.set_shader_parameter("shadow_intensity", shadow_intensity)
#endregion

#region Private Helpers

## Applies a preset dictionary to a shader material.
static func _apply_preset(mat: ShaderMaterial, preset: Dictionary) -> void:
	for key in preset:
		mat.set_shader_parameter(key, preset[key])
#endregion
