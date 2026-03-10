## Static helper functions that produce pre-built StandardMaterial3D resources
## tailored for the low-poly art style used across all party games.
class_name GameMaterials
extends Node


## Creates a flat, unlit-looking material with the given [param color].
## [param metallic] and [param roughness] default to values suited for a
## cartoony low-poly look.
static func create_flat_material(color: Color, metallic: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


## Creates a glowing material with emission enabled.
## Useful for power-ups, projectiles, and UI highlights.
static func create_glow_material(color: Color, emission_energy: float = 2.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission_energy
	mat.roughness = 0.4
	return mat


## Creates a semi-transparent material using alpha blending.
## [param alpha] controls base opacity (0.0 fully transparent, 1.0 fully opaque).
static func create_transparent_material(color: Color, alpha: float = 0.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.roughness = 0.8
	return mat


## Returns a neutral gray floor material with high roughness.
static func floor_material() -> StandardMaterial3D:
	return create_flat_material(Color(0.55, 0.55, 0.55), 0.0, 1.0)


## Returns a darker gray wall material with a slight metallic sheen.
static func wall_material() -> StandardMaterial3D:
	return create_flat_material(Color(0.35, 0.35, 0.38), 0.15, 0.85)


## Returns a red-orange hazard material with subtle emission to draw attention.
static func hazard_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.3, 0.1)
	mat.metallic = 0.0
	mat.roughness = 0.7
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.4, 0.1)
	mat.emission_energy_multiplier = 0.8
	return mat


## Returns a shiny gold pickup material.
static func pickup_material() -> StandardMaterial3D:
	return create_flat_material(Color(1.0, 0.85, 0.3), 0.8, 0.3)
