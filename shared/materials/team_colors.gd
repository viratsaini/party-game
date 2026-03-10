## Static utility for team colors used across all party games.
class_name TeamColors
extends Node

const RED: Color = Color(0.9, 0.2, 0.2)
const BLUE: Color = Color(0.2, 0.4, 0.9)
const GREEN: Color = Color(0.2, 0.8, 0.3)
const YELLOW: Color = Color(0.9, 0.8, 0.2)

const COLORS: Array[Color] = [RED, BLUE, GREEN, YELLOW]

## Cached StandardMaterial3D instances keyed by team index.
static var _material_cache: Dictionary = {}


## Returns the team color for the given index, wrapping around if out of range.
static func get_color(index: int) -> Color:
	return COLORS[index % COLORS.size()]


## Returns a cached StandardMaterial3D tinted to the team color at [param index].
## Materials are created once and reused on subsequent calls.
static func get_material(index: int) -> StandardMaterial3D:
	var key: int = index % COLORS.size()
	if _material_cache.has(key):
		return _material_cache[key]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = get_color(key)
	mat.roughness = 0.6
	mat.metallic = 0.1
	_material_cache[key] = mat
	return mat
