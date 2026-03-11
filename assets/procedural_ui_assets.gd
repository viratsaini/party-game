@tool
class_name ProceduralUIAssets
extends Node
## Main Asset Generation Manager for BattleZone Party
## Combines all texture generators into a unified system
## Handles caching, preloading, and runtime texture generation

signal assets_generated
signal generation_progress(current: int, total: int)

# Asset cache
var _button_cache: Dictionary = {}
var _background_cache: Dictionary = {}
var _icon_cache: Dictionary = {}

# Configuration
var _default_button_size := Vector2(400, 150)
var _default_icon_size := 64
var _use_caching := true


func _ready() -> void:
	# Pregenerate common assets on ready if running in game
	if not Engine.is_editor_hint():
		call_deferred("_pregenerate_assets")


## Pregenerate commonly used assets
func _pregenerate_assets() -> void:
	var total := 8 + 8  # buttons + icons
	var current := 0

	# Generate button sets
	for style in UITextureGenerator.ButtonStyle.values():
		_get_or_create_button_set(style)
		current += 1
		generation_progress.emit(current, total)

	# Generate common icons
	var common_icons := [
		IconGenerator.IconType.PLAY,
		IconGenerator.IconType.SETTINGS_GEAR,
		IconGenerator.IconType.BACK_ARROW,
		IconGenerator.IconType.CLOSE_X,
		IconGenerator.IconType.CHECK,
		IconGenerator.IconType.USER,
		IconGenerator.IconType.WIFI,
		IconGenerator.IconType.CONTROLLER
	]

	for icon_type in common_icons:
		get_icon(icon_type)
		current += 1
		generation_progress.emit(current, total)

	assets_generated.emit()


# ============ BUTTON TEXTURE ACCESS ============

## Get a complete button StyleBox set for a given style
func get_button_stylebox_set(
	style: UITextureGenerator.ButtonStyle = UITextureGenerator.ButtonStyle.PRIMARY,
	size: Vector2 = Vector2.ZERO
) -> Dictionary:
	if size == Vector2.ZERO:
		size = _default_button_size

	var textures := _get_or_create_button_set(style, int(size.x), int(size.y))

	return {
		"normal": _create_texture_stylebox(textures["normal"]),
		"hover": _create_texture_stylebox(textures["hover"]),
		"pressed": _create_texture_stylebox(textures["pressed"]),
		"disabled": _create_texture_stylebox(textures["disabled"])
	}


## Apply button style to a Button node
func apply_button_style(
	button: Button,
	style: UITextureGenerator.ButtonStyle = UITextureGenerator.ButtonStyle.PRIMARY,
	size: Vector2 = Vector2.ZERO
) -> void:
	var styles := get_button_stylebox_set(style, size)

	button.add_theme_stylebox_override("normal", styles["normal"])
	button.add_theme_stylebox_override("hover", styles["hover"])
	button.add_theme_stylebox_override("pressed", styles["pressed"])
	button.add_theme_stylebox_override("disabled", styles["disabled"])


## Get button textures directly
func get_button_textures(
	style: UITextureGenerator.ButtonStyle = UITextureGenerator.ButtonStyle.PRIMARY,
	width: int = 400,
	height: int = 150
) -> Dictionary:
	return _get_or_create_button_set(style, width, height)


func _get_or_create_button_set(
	style: UITextureGenerator.ButtonStyle,
	width: int = 400,
	height: int = 150
) -> Dictionary:
	var cache_key := "%d_%d_%d" % [style, width, height]

	if _use_caching and _button_cache.has(cache_key):
		return _button_cache[cache_key]

	var textures := UITextureGenerator.generate_button_texture_set(width, height, style)

	if _use_caching:
		_button_cache[cache_key] = textures

	return textures


func _create_texture_stylebox(texture: ImageTexture) -> StyleBoxTexture:
	var stylebox := StyleBoxTexture.new()
	stylebox.texture = texture

	# Set margins for nine-patch scaling
	var margin := 20
	stylebox.texture_margin_left = margin
	stylebox.texture_margin_right = margin
	stylebox.texture_margin_top = margin
	stylebox.texture_margin_bottom = margin

	return stylebox


# ============ BACKGROUND TEXTURE ACCESS ============

## Generate a radial gradient background
func get_radial_background(
	width: int = 1080,
	height: int = 1920,
	center_color: Color = Color(0.15, 0.15, 0.25, 1.0),
	edge_color: Color = Color(0.05, 0.05, 0.1, 1.0)
) -> ImageTexture:
	var cache_key := "radial_%d_%d_%s_%s" % [width, height, center_color.to_html(), edge_color.to_html()]

	if _use_caching and _background_cache.has(cache_key):
		return _background_cache[cache_key]

	var texture := BackgroundGenerator.generate_radial_gradient(width, height, center_color, edge_color)

	if _use_caching:
		_background_cache[cache_key] = texture

	return texture


## Generate a cyber grid background
func get_cyber_grid_background(
	width: int = 1080,
	height: int = 1920,
	scheme: String = "battlezone"
) -> ImageTexture:
	var cache_key := "cyber_%d_%d_%s" % [width, height, scheme]

	if _use_caching and _background_cache.has(cache_key):
		return _background_cache[cache_key]

	var texture := BackgroundGenerator.generate_cyber_grid(width, height, scheme)

	if _use_caching:
		_background_cache[cache_key] = texture

	return texture


## Generate a particle field background
func get_particle_field_background(
	width: int = 1080,
	height: int = 1920,
	scheme: String = "battlezone",
	seed_value: int = 12345
) -> ImageTexture:
	var cache_key := "particles_%d_%d_%s_%d" % [width, height, scheme, seed_value]

	if _use_caching and _background_cache.has(cache_key):
		return _background_cache[cache_key]

	var texture := BackgroundGenerator.generate_particle_field(width, height, scheme, 200, seed_value)

	if _use_caching:
		_background_cache[cache_key] = texture

	return texture


## Generate a hexagon pattern background
func get_hexagon_background(
	width: int = 1080,
	height: int = 1920,
	scheme: String = "battlezone"
) -> ImageTexture:
	var cache_key := "hexagon_%d_%d_%s" % [width, height, scheme]

	if _use_caching and _background_cache.has(cache_key):
		return _background_cache[cache_key]

	var texture := BackgroundGenerator.generate_hexagon_pattern(width, height, scheme)

	if _use_caching:
		_background_cache[cache_key] = texture

	return texture


## Generate a circuit board background
func get_circuit_background(
	width: int = 1080,
	height: int = 1920,
	scheme: String = "neon"
) -> ImageTexture:
	var cache_key := "circuit_%d_%d_%s" % [width, height, scheme]

	if _use_caching and _background_cache.has(cache_key):
		return _background_cache[cache_key]

	var texture := BackgroundGenerator.generate_circuit_board(width, height, scheme)

	if _use_caching:
		_background_cache[cache_key] = texture

	return texture


## Generate a layered background with multiple effects
func get_layered_background(
	width: int = 1080,
	height: int = 1920,
	scheme: String = "battlezone"
) -> ImageTexture:
	var cache_key := "layered_%d_%d_%s" % [width, height, scheme]

	if _use_caching and _background_cache.has(cache_key):
		return _background_cache[cache_key]

	var texture := BackgroundGenerator.generate_layered_background(width, height, scheme)

	if _use_caching:
		_background_cache[cache_key] = texture

	return texture


## Apply background to a TextureRect
func apply_background(
	texture_rect: TextureRect,
	style: BackgroundGenerator.BackgroundStyle = BackgroundGenerator.BackgroundStyle.GRADIENT_RADIAL,
	scheme: String = "battlezone"
) -> void:
	var viewport_size := texture_rect.get_viewport_rect().size
	var width := int(viewport_size.x) if viewport_size.x > 0 else 1080
	var height := int(viewport_size.y) if viewport_size.y > 0 else 1920

	var texture: ImageTexture

	match style:
		BackgroundGenerator.BackgroundStyle.GRADIENT_RADIAL:
			texture = get_radial_background(width, height)
		BackgroundGenerator.BackgroundStyle.CYBER_GRID:
			texture = get_cyber_grid_background(width, height, scheme)
		BackgroundGenerator.BackgroundStyle.PARTICLE_FIELD:
			texture = get_particle_field_background(width, height, scheme)
		BackgroundGenerator.BackgroundStyle.HEXAGON_PATTERN:
			texture = get_hexagon_background(width, height, scheme)
		BackgroundGenerator.BackgroundStyle.CIRCUIT_BOARD:
			texture = get_circuit_background(width, height, scheme)
		_:
			texture = get_layered_background(width, height, scheme)

	texture_rect.texture = texture


# ============ ICON ACCESS ============

## Get an icon texture
func get_icon(
	icon_type: IconGenerator.IconType,
	size: int = 0,
	color: Color = Color(0.95, 0.95, 0.95, 1.0),
	with_glow: bool = false
) -> ImageTexture:
	if size == 0:
		size = _default_icon_size

	var cache_key := "%d_%d_%s_%s" % [icon_type, size, color.to_html(), str(with_glow)]

	if _use_caching and _icon_cache.has(cache_key):
		return _icon_cache[cache_key]

	var texture := IconGenerator.generate_icon(icon_type, size, color, with_glow)

	if _use_caching:
		_icon_cache[cache_key] = texture

	return texture


## Get an icon with a specific style
func get_styled_icon(
	icon_type: IconGenerator.IconType,
	style: String = "default",
	size: int = 0,
	with_glow: bool = false
) -> ImageTexture:
	var color: Color = IconGenerator.ICON_COLORS.get(style, IconGenerator.ICON_COLORS["default"])
	return get_icon(icon_type, size, color, with_glow)


## Apply icon to a TextureRect
func apply_icon(
	texture_rect: TextureRect,
	icon_type: IconGenerator.IconType,
	size: int = 0,
	color: Color = Color(0.95, 0.95, 0.95, 1.0)
) -> void:
	texture_rect.texture = get_icon(icon_type, size, color)


## Apply icon to a Button
func apply_button_icon(
	button: Button,
	icon_type: IconGenerator.IconType,
	size: int = 32,
	color: Color = Color(0.95, 0.95, 0.95, 1.0)
) -> void:
	button.icon = get_icon(icon_type, size, color)


# ============ CACHE MANAGEMENT ============

## Clear all cached textures
func clear_cache() -> void:
	_button_cache.clear()
	_background_cache.clear()
	_icon_cache.clear()


## Clear specific cache type
func clear_button_cache() -> void:
	_button_cache.clear()


func clear_background_cache() -> void:
	_background_cache.clear()


func clear_icon_cache() -> void:
	_icon_cache.clear()


## Enable/disable caching
func set_caching_enabled(enabled: bool) -> void:
	_use_caching = enabled
	if not enabled:
		clear_cache()


## Get cache statistics
func get_cache_stats() -> Dictionary:
	return {
		"button_entries": _button_cache.size(),
		"background_entries": _background_cache.size(),
		"icon_entries": _icon_cache.size(),
		"total_entries": _button_cache.size() + _background_cache.size() + _icon_cache.size()
	}
