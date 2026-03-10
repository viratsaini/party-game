## Real-time minimap system showing a 2D overhead view of the game world.
## Displays player positions, objectives, and map boundaries.
class_name Minimap
extends Control

## Size of the minimap in pixels.
const MINIMAP_SIZE: float = 180.0
## World units visible in the minimap (diameter).
const VIEW_RANGE: float = 60.0
## Player blip size.
const PLAYER_BLIP_SIZE: float = 8.0
## Local player blip size (larger for visibility).
const LOCAL_PLAYER_BLIP_SIZE: float = 10.0
## Objective marker size.
const OBJECTIVE_SIZE: float = 12.0
## Border width.
const BORDER_WIDTH: float = 2.0

## Colors.
const BACKGROUND_COLOR: Color = Color(0.1, 0.1, 0.1, 0.7)
const BORDER_COLOR: Color = Color(0.4, 0.4, 0.4, 0.9)
const LOCAL_PLAYER_COLOR: Color = Color(0.2, 0.8, 1.0, 1.0)
const ENEMY_COLOR: Color = Color(1.0, 0.3, 0.2, 0.9)
const ALLY_COLOR: Color = Color(0.3, 1.0, 0.3, 0.9)
const OBJECTIVE_COLOR: Color = Color(1.0, 0.85, 0.2, 0.9)
const NORTH_INDICATOR_COLOR: Color = Color(1.0, 0.3, 0.3, 0.8)

## Reference to the local player for centering the map.
var _local_player: Node3D = null

## List of tracked entities: {node: Node3D, type: String, color: Color}
var _tracked_entities: Array[Dictionary] = []

## Objective markers: {position: Vector3, type: String, color: Color}
var _objective_markers: Array[Dictionary] = []

## Whether to rotate the minimap with the player.
var rotate_with_player: bool = true

## Current zoom level (1.0 = default).
var zoom_level: float = 1.0

## Cached center point.
var _center: Vector2 = Vector2.ZERO

## Cached scale factor.
var _scale_factor: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	_center = Vector2(MINIMAP_SIZE, MINIMAP_SIZE) * 0.5
	_update_scale_factor()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_center = size * 0.5
	_update_scale_factor()

	# Draw background circle.
	draw_circle(_center, MINIMAP_SIZE * 0.5, BACKGROUND_COLOR)

	# Draw border.
	draw_arc(_center, MINIMAP_SIZE * 0.5 - BORDER_WIDTH * 0.5, 0.0, TAU, 64, BORDER_COLOR, BORDER_WIDTH)

	# Get player rotation for map rotation.
	var rotation_offset: float = 0.0
	if rotate_with_player and _local_player:
		rotation_offset = _local_player.rotation.y

	# Draw grid lines (optional visual aid).
	_draw_grid(rotation_offset)

	# Draw objective markers.
	for objective: Dictionary in _objective_markers:
		_draw_objective(objective, rotation_offset)

	# Draw tracked entities.
	for entity: Dictionary in _tracked_entities:
		_draw_entity(entity, rotation_offset)

	# Draw local player (always on top, at center).
	if _local_player:
		_draw_local_player(rotation_offset)

	# Draw north indicator.
	_draw_north_indicator(rotation_offset)

	# Draw compass directions.
	_draw_compass(rotation_offset)


## Draw subtle grid lines for spatial reference.
func _draw_grid(rotation: float) -> void:
	var grid_color: Color = Color(0.3, 0.3, 0.3, 0.2)
	var grid_spacing: float = 15.0 * _scale_factor

	# Draw concentric circles.
	var num_circles: int = 3
	for i: int in range(1, num_circles + 1):
		var radius: float = (MINIMAP_SIZE * 0.5 - BORDER_WIDTH) * (float(i) / float(num_circles))
		draw_arc(_center, radius, 0.0, TAU, 32, grid_color, 1.0)


## Draw the local player indicator at the center.
func _draw_local_player(rotation: float) -> void:
	# Draw a triangle pointing in the player's facing direction.
	var size: float = LOCAL_PLAYER_BLIP_SIZE

	# Player faces forward (negative Z in Godot).
	var angle: float = 0.0
	if not rotate_with_player:
		angle = -_local_player.rotation.y

	var tip: Vector2 = _center + Vector2(0, -size).rotated(angle)
	var left: Vector2 = _center + Vector2(-size * 0.6, size * 0.5).rotated(angle)
	var right: Vector2 = _center + Vector2(size * 0.6, size * 0.5).rotated(angle)

	var points: PackedVector2Array = PackedVector2Array([tip, left, right])
	var colors: PackedColorArray = PackedColorArray([LOCAL_PLAYER_COLOR, LOCAL_PLAYER_COLOR, LOCAL_PLAYER_COLOR])
	draw_polygon(points, colors)

	# Draw outline.
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color.WHITE, 1.5)


## Draw an entity on the minimap.
func _draw_entity(entity: Dictionary, rotation: float) -> void:
	var node: Node3D = entity.get("node") as Node3D
	if not node or not is_instance_valid(node):
		return

	if not _local_player:
		return

	# Calculate relative position.
	var relative_pos: Vector3 = node.global_position - _local_player.global_position
	var pos_2d: Vector2 = Vector2(relative_pos.x, relative_pos.z)

	# Apply rotation if map rotates with player.
	if rotate_with_player:
		pos_2d = pos_2d.rotated(-_local_player.rotation.y)

	# Scale and offset to minimap coordinates.
	pos_2d *= _scale_factor
	var screen_pos: Vector2 = _center + Vector2(pos_2d.x, -pos_2d.y)

	# Clamp to minimap bounds.
	var radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH - PLAYER_BLIP_SIZE
	var offset: Vector2 = screen_pos - _center
	if offset.length() > radius:
		offset = offset.normalized() * radius
		screen_pos = _center + offset

	# Draw the blip.
	var color: Color = entity.get("color", ENEMY_COLOR) as Color
	var blip_size: float = PLAYER_BLIP_SIZE

	var entity_type: String = entity.get("type", "enemy") as String
	match entity_type:
		"player":
			draw_circle(screen_pos, blip_size, color)
			draw_arc(screen_pos, blip_size, 0.0, TAU, 16, Color.WHITE, 1.0)
		"objective":
			_draw_diamond(screen_pos, blip_size, color)
		"pickup":
			_draw_square(screen_pos, blip_size * 0.8, color)
		_:
			draw_circle(screen_pos, blip_size, color)


## Draw an objective marker.
func _draw_objective(objective: Dictionary, rotation: float) -> void:
	var world_pos: Vector3 = objective.get("position", Vector3.ZERO) as Vector3

	if not _local_player:
		return

	# Calculate relative position.
	var relative_pos: Vector3 = world_pos - _local_player.global_position
	var pos_2d: Vector2 = Vector2(relative_pos.x, relative_pos.z)

	# Apply rotation if map rotates with player.
	if rotate_with_player:
		pos_2d = pos_2d.rotated(-_local_player.rotation.y)

	# Scale and offset to minimap coordinates.
	pos_2d *= _scale_factor
	var screen_pos: Vector2 = _center + Vector2(pos_2d.x, -pos_2d.y)

	# Check if within bounds.
	var radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH - OBJECTIVE_SIZE
	var offset: Vector2 = screen_pos - _center
	var is_outside: bool = offset.length() > radius

	if is_outside:
		# Draw at edge pointing toward objective.
		offset = offset.normalized() * radius
		screen_pos = _center + offset

	var color: Color = objective.get("color", OBJECTIVE_COLOR) as Color
	_draw_diamond(screen_pos, OBJECTIVE_SIZE, color)

	# Draw pulse effect for nearby objectives.
	if not is_outside:
		var pulse: float = (sin(Time.get_ticks_msec() / 300.0) + 1.0) * 0.5
		var pulse_color: Color = color
		pulse_color.a *= 0.3 + pulse * 0.3
		_draw_diamond(screen_pos, OBJECTIVE_SIZE * (1.2 + pulse * 0.3), pulse_color)


## Draw the north indicator.
func _draw_north_indicator(rotation: float) -> void:
	var north_dir: Vector2 = Vector2.UP

	if rotate_with_player and _local_player:
		north_dir = north_dir.rotated(-_local_player.rotation.y)

	var edge_pos: Vector2 = _center + north_dir * (MINIMAP_SIZE * 0.5 - BORDER_WIDTH - 8)

	# Draw N label.
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size("N", HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_string(font, edge_pos - text_size * 0.5, "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, NORTH_INDICATOR_COLOR)


## Draw compass directions.
func _draw_compass(rotation: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var compass_color: Color = Color(0.6, 0.6, 0.6, 0.5)
	var compass_radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH - 8

	var directions: Array[Dictionary] = [
		{"label": "N", "angle": 0.0},
		{"label": "E", "angle": PI * 0.5},
		{"label": "S", "angle": PI},
		{"label": "W", "angle": PI * 1.5},
	]

	for dir: Dictionary in directions:
		var angle: float = dir["angle"] as float
		if rotate_with_player and _local_player:
			angle -= _local_player.rotation.y

		var pos: Vector2 = _center + Vector2(sin(angle), -cos(angle)) * compass_radius
		var label: String = dir["label"] as String

		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		var col: Color = NORTH_INDICATOR_COLOR if label == "N" else compass_color
		draw_string(font, pos - text_size * 0.5, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, col)


## Draw a diamond shape.
func _draw_diamond(pos: Vector2, half_size: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		pos + Vector2(0, -half_size),
		pos + Vector2(half_size, 0),
		pos + Vector2(0, half_size),
		pos + Vector2(-half_size, 0),
	])
	var colors: PackedColorArray = PackedColorArray([color, color, color, color])
	draw_polygon(points, colors)


## Draw a square shape.
func _draw_square(pos: Vector2, half_size: float, color: Color) -> void:
	var rect: Rect2 = Rect2(pos - Vector2(half_size, half_size), Vector2(half_size * 2, half_size * 2))
	draw_rect(rect, color)


## Update the scale factor based on view range and zoom.
func _update_scale_factor() -> void:
	var effective_range: float = VIEW_RANGE / zoom_level
	_scale_factor = (MINIMAP_SIZE * 0.5 - BORDER_WIDTH) / (effective_range * 0.5)


## Set the local player reference.
func set_local_player(player: Node3D) -> void:
	_local_player = player


## Track an entity on the minimap.
## [param node] The Node3D to track.
## [param type] Entity type: "player", "enemy", "objective", "pickup".
## [param color] Color for the entity blip.
func track_entity(node: Node3D, type: String = "player", color: Color = ENEMY_COLOR) -> void:
	# Check if already tracked.
	for entity: Dictionary in _tracked_entities:
		if entity.get("node") == node:
			entity["type"] = type
			entity["color"] = color
			return

	_tracked_entities.append({
		"node": node,
		"type": type,
		"color": color,
	})


## Stop tracking an entity.
func untrack_entity(node: Node3D) -> void:
	for i: int in range(_tracked_entities.size() - 1, -1, -1):
		if _tracked_entities[i].get("node") == node:
			_tracked_entities.remove_at(i)
			return


## Clear all tracked entities.
func clear_tracked_entities() -> void:
	_tracked_entities.clear()


## Add an objective marker at a world position.
func add_objective(position: Vector3, type: String = "objective", color: Color = OBJECTIVE_COLOR) -> void:
	_objective_markers.append({
		"position": position,
		"type": type,
		"color": color,
	})


## Remove an objective marker.
func remove_objective(position: Vector3) -> void:
	for i: int in range(_objective_markers.size() - 1, -1, -1):
		var obj_pos: Vector3 = _objective_markers[i].get("position", Vector3.ZERO) as Vector3
		if obj_pos.distance_to(position) < 0.5:
			_objective_markers.remove_at(i)
			return


## Clear all objective markers.
func clear_objectives() -> void:
	_objective_markers.clear()


## Set the zoom level (1.0 = default, higher = more zoomed in).
func set_zoom(level: float) -> void:
	zoom_level = clampf(level, 0.5, 3.0)
	_update_scale_factor()


## Toggle map rotation mode.
func set_rotate_with_player(enabled: bool) -> void:
	rotate_with_player = enabled
