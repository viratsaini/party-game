## Ultra-premium 3D minimap system with competitive FPS features.
## Features 3D terrain height visualization, real-time player cone of vision,
## sound wave visualization for enemy footsteps, objective path drawing with Bezier curves,
## ML-style danger zone prediction, time-since-seen indicators, and scan pulse effects.
## Designed for esports-ready tactical shooter HUDs.
class_name Minimap3D
extends Control

## Signal emitted when danger zone is detected.
signal danger_zone_detected(position: Vector3, threat_level: float)
## Signal emitted when enemy footsteps are detected.
signal footsteps_detected(position: Vector3, intensity: float)

# ── Map Configuration ─────────────────────────────────────────────────────────

## Size of the minimap in pixels.
const MINIMAP_SIZE: float = 220.0
## World units visible in the minimap (diameter).
var view_range: float = 80.0
## Player blip size.
const PLAYER_BLIP_SIZE: float = 10.0
## Local player blip size.
const LOCAL_PLAYER_BLIP_SIZE: float = 12.0
## Objective marker size.
const OBJECTIVE_SIZE: float = 14.0
## Border width.
const BORDER_WIDTH: float = 3.0
## Terrain grid resolution.
const TERRAIN_GRID_SIZE: int = 16
## Maximum tracked sounds.
const MAX_SOUND_WAVES: int = 8
## Cone of vision angle (degrees).
const FOV_ANGLE: float = 75.0
## Cone of vision range.
const FOV_RANGE: float = 0.7  ## As fraction of minimap radius.

# ── References ────────────────────────────────────────────────────────────────

## Reference to the local player for centering the map.
var _local_player: Node3D = null

## List of tracked entities.
var _tracked_entities: Array[Dictionary] = []

## Objective markers.
var _objective_markers: Array[Dictionary] = []

## Terrain height data (grid of heights for 3D visualization).
var _terrain_heights: Array[Array] = []

## Sound wave events (enemy footsteps, gunshots, etc.).
var _sound_waves: Array[Dictionary] = []

## Danger zones (ML-predicted areas of threat).
var _danger_zones: Array[Dictionary] = []

## Entity time-since-seen tracking.
var _entity_last_seen: Dictionary = {}  ## entity_id -> last_seen_time

## Path waypoints for objective navigation.
var _path_waypoints: Array[Vector3] = []

# ── Animation State ───────────────────────────────────────────────────────────

## Scan pulse effect.
var _scan_pulse_active: bool = false
var _scan_pulse_progress: float = 0.0
var _scan_pulse_tween: Tween = null

## Rotation animation.
var _map_rotation: float = 0.0
var _target_rotation: float = 0.0

## Zoom animation.
var zoom_level: float = 1.0
var _display_zoom: float = 1.0

## Whether to rotate the minimap with the player.
var rotate_with_player: bool = true

## FOV cone pulse.
var _fov_pulse: float = 0.0

## Danger zone pulse.
var _danger_pulse: float = 0.0

## Cached values.
var _center: Vector2 = Vector2.ZERO
var _scale_factor: float = 1.0

# ── Color Palette ─────────────────────────────────────────────────────────────

## Background colors.
const BG_COLOR: Color = Color(0.08, 0.08, 0.12, 0.85)
const BG_INNER_COLOR: Color = Color(0.05, 0.05, 0.08, 0.9)
const BORDER_COLOR: Color = Color(0.35, 0.35, 0.42, 0.95)
const BORDER_GLOW_COLOR: Color = Color(0.4, 0.8, 1.0, 0.3)

## Grid colors.
const GRID_COLOR: Color = Color(0.25, 0.25, 0.32, 0.3)
const GRID_MAJOR_COLOR: Color = Color(0.3, 0.3, 0.38, 0.45)

## Terrain height colors (low to high).
const TERRAIN_COLOR_LOW: Color = Color(0.15, 0.2, 0.15, 0.4)
const TERRAIN_COLOR_MID: Color = Color(0.25, 0.3, 0.25, 0.5)
const TERRAIN_COLOR_HIGH: Color = Color(0.4, 0.45, 0.35, 0.6)
const TERRAIN_SHADOW_COLOR: Color = Color(0.1, 0.1, 0.12, 0.5)

## Player colors.
const LOCAL_PLAYER_COLOR: Color = Color(0.2, 0.85, 1.0, 1.0)
const LOCAL_PLAYER_GLOW: Color = Color(0.3, 0.9, 1.0, 0.5)
const ENEMY_COLOR: Color = Color(1.0, 0.3, 0.2, 0.95)
const ENEMY_GLOW: Color = Color(1.0, 0.4, 0.25, 0.5)
const ALLY_COLOR: Color = Color(0.3, 1.0, 0.35, 0.95)
const ALLY_GLOW: Color = Color(0.35, 1.0, 0.4, 0.5)

## FOV cone colors.
const FOV_CONE_COLOR: Color = Color(0.3, 0.8, 1.0, 0.15)
const FOV_EDGE_COLOR: Color = Color(0.4, 0.9, 1.0, 0.35)

## Objective colors.
const OBJECTIVE_COLOR: Color = Color(1.0, 0.88, 0.2, 0.95)
const OBJECTIVE_GLOW: Color = Color(1.0, 0.9, 0.3, 0.5)
const PATH_COLOR: Color = Color(1.0, 0.85, 0.25, 0.7)
const PATH_GLOW_COLOR: Color = Color(1.0, 0.9, 0.4, 0.3)

## Sound wave colors.
const SOUND_FOOTSTEP_COLOR: Color = Color(1.0, 0.7, 0.3, 0.7)
const SOUND_GUNSHOT_COLOR: Color = Color(1.0, 0.4, 0.25, 0.85)
const SOUND_WAVE_COLOR: Color = Color(1.0, 0.8, 0.4, 0.5)

## Danger zone colors.
const DANGER_ZONE_COLOR: Color = Color(1.0, 0.25, 0.15, 0.35)
const DANGER_ZONE_EDGE: Color = Color(1.0, 0.3, 0.2, 0.65)
const DANGER_ZONE_HIGH: Color = Color(1.0, 0.15, 0.1, 0.5)

## Scan pulse colors.
const SCAN_PULSE_COLOR: Color = Color(0.3, 0.9, 1.0, 0.6)
const SCAN_LINE_COLOR: Color = Color(0.4, 0.95, 1.0, 0.8)

## Time-since-seen indicator colors.
const SEEN_RECENT_COLOR: Color = Color(1.0, 0.3, 0.2, 0.9)
const SEEN_OLD_COLOR: Color = Color(0.7, 0.4, 0.35, 0.5)
const SEEN_ANCIENT_COLOR: Color = Color(0.5, 0.4, 0.4, 0.25)

## North indicator.
const NORTH_INDICATOR_COLOR: Color = Color(1.0, 0.35, 0.3, 0.9)

# ── Timing Constants ──────────────────────────────────────────────────────────

const ROTATION_LERP_SPEED: float = 12.0
const ZOOM_LERP_SPEED: float = 8.0
const SOUND_WAVE_DURATION: float = 2.5
const SOUND_WAVE_EXPANSION_SPEED: float = 1.2
const DANGER_PULSE_SPEED: float = 4.0
const FOV_PULSE_SPEED: float = 2.0
const SCAN_PULSE_DURATION: float = 1.5
const TIME_RECENT: float = 5.0  ## Seconds.
const TIME_OLD: float = 15.0
const TIME_ANCIENT: float = 30.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(MINIMAP_SIZE + 20, MINIMAP_SIZE + 20)
	_center = Vector2(MINIMAP_SIZE + 20, MINIMAP_SIZE + 20) * 0.5
	_update_scale_factor()
	_initialize_terrain_grid()


func _process(delta: float) -> void:
	var needs_redraw: bool = true  # Minimap always redraws for real-time updates.

	# Update rotation interpolation.
	if rotate_with_player and _local_player:
		_target_rotation = _local_player.rotation.y
	else:
		_target_rotation = 0.0

	if absf(_map_rotation - _target_rotation) > 0.01:
		_map_rotation = lerpf(_map_rotation, _target_rotation, ROTATION_LERP_SPEED * delta)

	# Update zoom interpolation.
	if absf(_display_zoom - zoom_level) > 0.01:
		_display_zoom = lerpf(_display_zoom, zoom_level, ZOOM_LERP_SPEED * delta)
		_update_scale_factor()

	# Update FOV pulse.
	_fov_pulse = fmod(_fov_pulse + FOV_PULSE_SPEED * delta, TAU)

	# Update danger zone pulse.
	if _danger_zones.size() > 0:
		_danger_pulse = fmod(_danger_pulse + DANGER_PULSE_SPEED * delta, TAU)

	# Update sound waves.
	_update_sound_waves(delta)

	# Update danger zones.
	_update_danger_zones(delta)

	# Update scan pulse.
	if _scan_pulse_active:
		needs_redraw = true

	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	_center = size * 0.5
	_update_scale_factor()

	# Draw background with clipping circle.
	_draw_background()

	# Get rotation for all elements.
	var rotation_offset: float = 0.0
	if rotate_with_player:
		rotation_offset = _map_rotation

	# Draw terrain height visualization.
	_draw_terrain_3d(rotation_offset)

	# Draw grid.
	_draw_grid(rotation_offset)

	# Draw danger zones.
	for zone: Dictionary in _danger_zones:
		_draw_danger_zone(zone, rotation_offset)

	# Draw objective path with Bezier curves.
	if _path_waypoints.size() > 0:
		_draw_objective_path(rotation_offset)

	# Draw sound wave visualizations.
	for wave: Dictionary in _sound_waves:
		_draw_sound_wave(wave, rotation_offset)

	# Draw objective markers.
	for objective: Dictionary in _objective_markers:
		_draw_objective_v2(objective, rotation_offset)

	# Draw tracked entities.
	for entity: Dictionary in _tracked_entities:
		_draw_entity_v2(entity, rotation_offset)

	# Draw local player with FOV cone.
	if _local_player:
		_draw_local_player_v2(rotation_offset)

	# Draw scan pulse effect.
	if _scan_pulse_active:
		_draw_scan_pulse()

	# Draw border with glow.
	_draw_border()

	# Draw compass.
	_draw_compass_v2(rotation_offset)


## Draw background with circular gradient.
func _draw_background() -> void:
	var radius: float = MINIMAP_SIZE * 0.5

	# Main background circle.
	draw_circle(_center, radius, BG_COLOR)

	# Inner darker circle.
	draw_circle(_center, radius - 5, BG_INNER_COLOR)


## Draw 3D terrain visualization using height data.
func _draw_terrain_3d(rotation: float) -> void:
	if _terrain_heights.size() == 0:
		return

	var cell_size: float = (MINIMAP_SIZE - BORDER_WIDTH * 2) / float(TERRAIN_GRID_SIZE)
	var radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH

	for y: int in range(TERRAIN_GRID_SIZE):
		for x: int in range(TERRAIN_GRID_SIZE):
			# Calculate cell position relative to center.
			var cell_offset: Vector2 = Vector2(
				(float(x) - float(TERRAIN_GRID_SIZE) * 0.5 + 0.5) * cell_size,
				(float(y) - float(TERRAIN_GRID_SIZE) * 0.5 + 0.5) * cell_size
			)

			# Apply rotation.
			cell_offset = cell_offset.rotated(-rotation)

			var screen_pos: Vector2 = _center + cell_offset

			# Skip if outside minimap circle.
			if screen_pos.distance_to(_center) > radius:
				continue

			# Get height value (0.0 to 1.0).
			var height: float = _terrain_heights[y][x] as float

			# Calculate color based on height.
			var terrain_color: Color
			if height < 0.33:
				terrain_color = TERRAIN_COLOR_LOW.lerp(TERRAIN_COLOR_MID, height / 0.33)
			elif height < 0.66:
				terrain_color = TERRAIN_COLOR_MID.lerp(TERRAIN_COLOR_HIGH, (height - 0.33) / 0.33)
			else:
				terrain_color = TERRAIN_COLOR_HIGH

			# Draw cell with pseudo-3D effect (offset shadow).
			var shadow_offset: Vector2 = Vector2(2, 2) * height
			var cell_rect: Rect2 = Rect2(screen_pos - Vector2(cell_size * 0.5, cell_size * 0.5), Vector2(cell_size, cell_size))

			# Shadow.
			if height > 0.2:
				var shadow_rect: Rect2 = cell_rect
				shadow_rect.position += shadow_offset
				draw_rect(shadow_rect, TERRAIN_SHADOW_COLOR)

			# Main cell.
			draw_rect(cell_rect, terrain_color)


## Draw grid with major and minor lines.
func _draw_grid(rotation: float) -> void:
	var radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH

	# Draw concentric range circles.
	var num_circles: int = 4
	for i: int in range(1, num_circles + 1):
		var circle_radius: float = radius * (float(i) / float(num_circles))
		var color: Color = GRID_MAJOR_COLOR if i == num_circles else GRID_COLOR
		draw_arc(_center, circle_radius, 0.0, TAU, 48, color, 1.0)

	# Draw radial lines.
	var num_lines: int = 8
	for i: int in range(num_lines):
		var angle: float = (TAU / float(num_lines)) * float(i) - rotation
		var inner_pos: Vector2 = _center + Vector2(cos(angle), sin(angle)) * 10
		var outer_pos: Vector2 = _center + Vector2(cos(angle), sin(angle)) * radius

		var color: Color = GRID_MAJOR_COLOR if i % 2 == 0 else GRID_COLOR
		draw_line(inner_pos, outer_pos, color, 1.0)


## Draw local player with cone of vision.
func _draw_local_player_v2(rotation: float) -> void:
	# Draw FOV cone first (behind player blip).
	_draw_fov_cone(rotation)

	# Draw player blip.
	var blip_size: float = LOCAL_PLAYER_BLIP_SIZE

	# Player faces forward (triangle pointing up in non-rotated mode).
	var angle: float = 0.0
	if not rotate_with_player:
		angle = -_local_player.rotation.y

	# Draw glow.
	draw_circle(_center, blip_size * 1.5, LOCAL_PLAYER_GLOW)

	# Draw triangle.
	var tip: Vector2 = _center + Vector2(0, -blip_size).rotated(angle)
	var left: Vector2 = _center + Vector2(-blip_size * 0.65, blip_size * 0.55).rotated(angle)
	var right: Vector2 = _center + Vector2(blip_size * 0.65, blip_size * 0.55).rotated(angle)

	var points: PackedVector2Array = PackedVector2Array([tip, left, right])
	var colors: PackedColorArray = PackedColorArray([LOCAL_PLAYER_COLOR, LOCAL_PLAYER_COLOR, LOCAL_PLAYER_COLOR])
	draw_polygon(points, colors)

	# Draw outline.
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color.WHITE, 2.0)


## Draw field of view cone.
func _draw_fov_cone(rotation: float) -> void:
	var radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH
	var fov_radius: float = radius * FOV_RANGE

	# Calculate cone angles.
	var half_fov: float = deg_to_rad(FOV_ANGLE * 0.5)
	var forward_angle: float = -PI * 0.5  # Up in screen space.

	if not rotate_with_player:
		forward_angle -= _local_player.rotation.y

	var left_angle: float = forward_angle - half_fov
	var right_angle: float = forward_angle + half_fov

	# Draw filled cone.
	var cone_points: PackedVector2Array = PackedVector2Array()
	cone_points.append(_center)

	var segments: int = 24
	for i: int in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = lerpf(left_angle, right_angle, t)
		cone_points.append(_center + Vector2(cos(angle), sin(angle)) * fov_radius)

	var cone_colors: PackedColorArray = PackedColorArray()
	for i: int in range(cone_points.size()):
		var pulse: float = (sin(_fov_pulse + float(i) * 0.2) + 1.0) * 0.5
		var color: Color = FOV_CONE_COLOR
		color.a *= 0.8 + pulse * 0.2
		cone_colors.append(color)

	draw_polygon(cone_points, cone_colors)

	# Draw cone edges.
	draw_line(_center, _center + Vector2(cos(left_angle), sin(left_angle)) * fov_radius, FOV_EDGE_COLOR, 2.0)
	draw_line(_center, _center + Vector2(cos(right_angle), sin(right_angle)) * fov_radius, FOV_EDGE_COLOR, 2.0)

	# Draw arc at cone edge.
	draw_arc(_center, fov_radius, left_angle, right_angle, 24, FOV_EDGE_COLOR, 1.5)


## Draw an entity on the minimap with time-since-seen indicator.
func _draw_entity_v2(entity: Dictionary, rotation: float) -> void:
	var node: Node3D = entity.get("node") as Node3D
	if not node or not is_instance_valid(node):
		return

	if not _local_player:
		return

	var entity_id: int = node.get_instance_id()

	# Update last seen time.
	_entity_last_seen[entity_id] = Time.get_ticks_msec() / 1000.0

	# Calculate relative position.
	var relative_pos: Vector3 = node.global_position - _local_player.global_position
	var pos_2d: Vector2 = Vector2(relative_pos.x, relative_pos.z)

	# Apply rotation.
	if rotate_with_player:
		pos_2d = pos_2d.rotated(-_map_rotation)

	# Scale and offset.
	pos_2d *= _scale_factor
	var screen_pos: Vector2 = _center + Vector2(pos_2d.x, -pos_2d.y)

	# Clamp to minimap bounds.
	var radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH - PLAYER_BLIP_SIZE
	var offset: Vector2 = screen_pos - _center
	var is_clamped: bool = false

	if offset.length() > radius:
		offset = offset.normalized() * radius
		screen_pos = _center + offset
		is_clamped = true

	# Get entity type and color.
	var entity_type: String = entity.get("type", "enemy") as String
	var color: Color = entity.get("color", ENEMY_COLOR) as Color
	var glow_color: Color = ENEMY_GLOW if entity_type == "enemy" else ALLY_GLOW
	var blip_size: float = PLAYER_BLIP_SIZE

	# Draw glow.
	draw_circle(screen_pos, blip_size * 1.4, glow_color)

	# Draw blip.
	match entity_type:
		"enemy":
			# Draw enemy as diamond.
			_draw_enemy_blip(screen_pos, blip_size, color, is_clamped)
		"ally":
			# Draw ally as circle.
			draw_circle(screen_pos, blip_size, color)
			draw_arc(screen_pos, blip_size, 0.0, TAU, 16, Color.WHITE, 1.5)
		_:
			draw_circle(screen_pos, blip_size, color)

	# Draw time-since-seen indicator for enemies.
	if entity_type == "enemy":
		_draw_time_since_seen_indicator(screen_pos, blip_size, entity_id)


## Draw enemy blip with directional indicator.
func _draw_enemy_blip(pos: Vector2, blip_size: float, color: Color, is_clamped: bool) -> void:
	if is_clamped:
		# Draw arrow pointing toward enemy when clamped.
		var direction: Vector2 = (pos - _center).normalized()
		var arrow_tip: Vector2 = pos + direction * 5
		var arrow_left: Vector2 = pos + direction.rotated(2.5) * blip_size * 0.7
		var arrow_right: Vector2 = pos + direction.rotated(-2.5) * blip_size * 0.7

		var points: PackedVector2Array = PackedVector2Array([arrow_tip, arrow_left, pos, arrow_right])
		var colors: PackedColorArray = PackedColorArray([color, color, color, color])
		draw_polygon(points, colors)
	else:
		# Draw diamond shape.
		var points: PackedVector2Array = PackedVector2Array([
			pos + Vector2(0, -blip_size),
			pos + Vector2(blip_size, 0),
			pos + Vector2(0, blip_size),
			pos + Vector2(-blip_size, 0),
		])
		var colors: PackedColorArray = PackedColorArray([color, color, color, color])
		draw_polygon(points, colors)

		# Outline.
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color.WHITE, 1.5)


## Draw time-since-seen indicator.
func _draw_time_since_seen_indicator(pos: Vector2, blip_size: float, entity_id: int) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var last_seen: float = _entity_last_seen.get(entity_id, current_time) as float
	var time_since: float = current_time - last_seen

	if time_since < 0.5:
		return  # Just seen, no indicator needed.

	var indicator_color: Color
	var indicator_alpha: float

	if time_since < TIME_RECENT:
		indicator_color = SEEN_RECENT_COLOR
		indicator_alpha = 1.0 - (time_since / TIME_RECENT) * 0.3
	elif time_since < TIME_OLD:
		indicator_color = SEEN_OLD_COLOR
		indicator_alpha = 0.7 - ((time_since - TIME_RECENT) / (TIME_OLD - TIME_RECENT)) * 0.3
	else:
		indicator_color = SEEN_ANCIENT_COLOR
		indicator_alpha = 0.4

	indicator_color.a = indicator_alpha

	# Draw clock-style indicator.
	var indicator_radius: float = blip_size * 1.8
	var fill_angle: float = TAU * minf(time_since / TIME_ANCIENT, 1.0)

	draw_arc(pos, indicator_radius, -PI * 0.5, -PI * 0.5 + fill_angle, 16, indicator_color, 2.0)


## Draw sound wave visualization.
func _draw_sound_wave(wave: Dictionary, rotation: float) -> void:
	var world_pos: Vector3 = wave.get("position", Vector3.ZERO) as Vector3
	var progress: float = wave.get("progress", 0.0) as float
	var intensity: float = wave.get("intensity", 1.0) as float
	var sound_type: String = wave.get("type", "footstep") as String

	if not _local_player:
		return

	# Calculate relative position.
	var relative_pos: Vector3 = world_pos - _local_player.global_position
	var pos_2d: Vector2 = Vector2(relative_pos.x, relative_pos.z)

	if rotate_with_player:
		pos_2d = pos_2d.rotated(-_map_rotation)

	pos_2d *= _scale_factor
	var screen_pos: Vector2 = _center + Vector2(pos_2d.x, -pos_2d.y)

	# Check if within bounds.
	var radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH
	if screen_pos.distance_to(_center) > radius:
		return

	# Wave properties.
	var max_wave_radius: float = 25.0 * intensity
	var wave_radius: float = max_wave_radius * progress
	var wave_alpha: float = (1.0 - progress) * intensity

	# Choose color based on sound type.
	var wave_color: Color = SOUND_FOOTSTEP_COLOR if sound_type == "footstep" else SOUND_GUNSHOT_COLOR
	wave_color.a = wave_alpha * 0.7

	# Draw expanding ring.
	draw_arc(screen_pos, wave_radius, 0.0, TAU, 24, wave_color, 2.5)

	# Draw inner pulse.
	if progress < 0.5:
		var inner_color: Color = wave_color
		inner_color.a = wave_alpha
		draw_circle(screen_pos, 4.0 * (1.0 - progress * 2.0), inner_color)


## Draw danger zone visualization.
func _draw_danger_zone(zone: Dictionary, rotation: float) -> void:
	var world_pos: Vector3 = zone.get("position", Vector3.ZERO) as Vector3
	var zone_radius: float = zone.get("radius", 10.0) as float
	var threat_level: float = zone.get("threat_level", 0.5) as float

	if not _local_player:
		return

	# Calculate relative position.
	var relative_pos: Vector3 = world_pos - _local_player.global_position
	var pos_2d: Vector2 = Vector2(relative_pos.x, relative_pos.z)

	if rotate_with_player:
		pos_2d = pos_2d.rotated(-_map_rotation)

	pos_2d *= _scale_factor
	var screen_pos: Vector2 = _center + Vector2(pos_2d.x, -pos_2d.y)
	var screen_radius: float = zone_radius * _scale_factor

	# Check if any part is visible.
	var minimap_radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH
	if screen_pos.distance_to(_center) > minimap_radius + screen_radius:
		return

	# Calculate color based on threat level.
	var zone_color: Color = DANGER_ZONE_COLOR.lerp(DANGER_ZONE_HIGH, threat_level)
	var pulse: float = (sin(_danger_pulse) + 1.0) * 0.5
	zone_color.a *= 0.7 + pulse * 0.3

	# Draw filled zone.
	draw_circle(screen_pos, screen_radius, zone_color)

	# Draw pulsing edge.
	var edge_color: Color = DANGER_ZONE_EDGE
	edge_color.a *= 0.6 + pulse * 0.4
	draw_arc(screen_pos, screen_radius, 0.0, TAU, 32, edge_color, 2.0)

	# Draw threat level indicator.
	var font: Font = ThemeDB.fallback_font
	var threat_text: String = "%d%%" % int(threat_level * 100)
	var text_size: Vector2 = font.get_string_size(threat_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	draw_string(font, screen_pos - text_size * 0.5 + Vector2(0, text_size.y * 0.35), threat_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, edge_color)


## Draw objective with Bezier path.
func _draw_objective_v2(objective: Dictionary, rotation: float) -> void:
	var world_pos: Vector3 = objective.get("position", Vector3.ZERO) as Vector3

	if not _local_player:
		return

	# Calculate relative position.
	var relative_pos: Vector3 = world_pos - _local_player.global_position
	var pos_2d: Vector2 = Vector2(relative_pos.x, relative_pos.z)

	if rotate_with_player:
		pos_2d = pos_2d.rotated(-_map_rotation)

	pos_2d *= _scale_factor
	var screen_pos: Vector2 = _center + Vector2(pos_2d.x, -pos_2d.y)

	# Check bounds.
	var radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH - OBJECTIVE_SIZE
	var offset_vec: Vector2 = screen_pos - _center
	var is_outside: bool = offset_vec.length() > radius

	if is_outside:
		offset_vec = offset_vec.normalized() * radius
		screen_pos = _center + offset_vec

	var color: Color = objective.get("color", OBJECTIVE_COLOR) as Color

	# Draw glow.
	draw_circle(screen_pos, OBJECTIVE_SIZE * 1.5, OBJECTIVE_GLOW)

	# Draw diamond marker.
	_draw_diamond_marker(screen_pos, OBJECTIVE_SIZE, color)

	# Draw pulse for nearby objectives.
	if not is_outside:
		var pulse: float = (sin(Time.get_ticks_msec() / 300.0) + 1.0) * 0.5
		var pulse_color: Color = color
		pulse_color.a *= 0.25 + pulse * 0.25
		_draw_diamond_marker(screen_pos, OBJECTIVE_SIZE * (1.3 + pulse * 0.3), pulse_color)


## Draw diamond marker shape.
func _draw_diamond_marker(pos: Vector2, half_size: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		pos + Vector2(0, -half_size),
		pos + Vector2(half_size, 0),
		pos + Vector2(0, half_size),
		pos + Vector2(-half_size, 0),
	])
	var colors: PackedColorArray = PackedColorArray([color, color, color, color])
	draw_polygon(points, colors)


## Draw objective path with Bezier curves.
func _draw_objective_path(rotation: float) -> void:
	if _path_waypoints.size() < 2 or not _local_player:
		return

	var path_points: PackedVector2Array = PackedVector2Array()

	# Start from player position.
	path_points.append(_center)

	# Convert all waypoints to screen space.
	for waypoint: Vector3 in _path_waypoints:
		var relative_pos: Vector3 = waypoint - _local_player.global_position
		var pos_2d: Vector2 = Vector2(relative_pos.x, relative_pos.z)

		if rotate_with_player:
			pos_2d = pos_2d.rotated(-_map_rotation)

		pos_2d *= _scale_factor
		var screen_pos: Vector2 = _center + Vector2(pos_2d.x, -pos_2d.y)

		# Clamp to minimap bounds.
		var minimap_radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH
		var offset_vec: Vector2 = screen_pos - _center
		if offset_vec.length() > minimap_radius:
			offset_vec = offset_vec.normalized() * minimap_radius
			screen_pos = _center + offset_vec

		path_points.append(screen_pos)

	# Draw Bezier curve path.
	if path_points.size() >= 2:
		_draw_bezier_path(path_points)


## Draw smooth Bezier curve between points.
func _draw_bezier_path(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return

	# Draw glow.
	for i: int in range(points.size() - 1):
		var start: Vector2 = points[i]
		var end: Vector2 = points[i + 1]

		# Calculate control points for smooth curve.
		var direction: Vector2 = (end - start).normalized()
		var dist: float = start.distance_to(end)
		var control1: Vector2 = start + direction.orthogonal() * dist * 0.2
		var control2: Vector2 = end - direction.orthogonal() * dist * 0.2

		# Draw cubic bezier approximation.
		var prev_point: Vector2 = start
		var segments: int = 12

		for j: int in range(1, segments + 1):
			var t: float = float(j) / float(segments)

			# Cubic bezier formula.
			var point: Vector2 = (1.0 - t) * (1.0 - t) * (1.0 - t) * start
			point += 3.0 * (1.0 - t) * (1.0 - t) * t * control1
			point += 3.0 * (1.0 - t) * t * t * control2
			point += t * t * t * end

			# Draw glow line.
			draw_line(prev_point, point, PATH_GLOW_COLOR, 6.0)
			# Draw main line.
			draw_line(prev_point, point, PATH_COLOR, 2.5)

			prev_point = point

	# Draw animated dots along path.
	var anim_phase: float = fmod(Time.get_ticks_msec() / 500.0, 1.0)
	for i: int in range(points.size() - 1):
		var dot_pos: Vector2 = points[i].lerp(points[i + 1], anim_phase)
		draw_circle(dot_pos, 4.0, PATH_COLOR)


## Draw scan pulse effect.
func _draw_scan_pulse() -> void:
	var max_radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH
	var pulse_radius: float = max_radius * _scan_pulse_progress

	# Draw expanding ring.
	var ring_alpha: float = 1.0 - _scan_pulse_progress
	var ring_color: Color = SCAN_PULSE_COLOR
	ring_color.a = ring_alpha * 0.7

	draw_arc(_center, pulse_radius, 0.0, TAU, 48, ring_color, 3.0)

	# Draw scan line.
	var line_color: Color = SCAN_LINE_COLOR
	line_color.a = ring_alpha
	draw_arc(_center, pulse_radius, 0.0, TAU, 48, line_color, 1.5)

	# Draw inner glow.
	if _scan_pulse_progress < 0.3:
		var inner_alpha: float = (0.3 - _scan_pulse_progress) / 0.3
		var inner_color: Color = SCAN_PULSE_COLOR
		inner_color.a = inner_alpha * 0.5
		draw_circle(_center, pulse_radius * 0.3, inner_color)


## Draw border with glow effect.
func _draw_border() -> void:
	var radius: float = MINIMAP_SIZE * 0.5

	# Outer glow.
	draw_arc(_center, radius + 2, 0.0, TAU, 48, BORDER_GLOW_COLOR, 4.0)

	# Main border.
	draw_arc(_center, radius - BORDER_WIDTH * 0.5, 0.0, TAU, 48, BORDER_COLOR, BORDER_WIDTH)


## Draw compass with cardinal directions.
func _draw_compass_v2(rotation: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var compass_radius: float = MINIMAP_SIZE * 0.5 - BORDER_WIDTH - 12

	var directions: Array[Dictionary] = [
		{"label": "N", "angle": 0.0, "color": NORTH_INDICATOR_COLOR},
		{"label": "E", "angle": PI * 0.5, "color": Color(0.65, 0.65, 0.7, 0.85)},
		{"label": "S", "angle": PI, "color": Color(0.65, 0.65, 0.7, 0.85)},
		{"label": "W", "angle": PI * 1.5, "color": Color(0.65, 0.65, 0.7, 0.85)},
	]

	for dir: Dictionary in directions:
		var angle: float = dir["angle"] as float
		if rotate_with_player:
			angle -= _map_rotation

		var pos: Vector2 = _center + Vector2(sin(angle), -cos(angle)) * compass_radius
		var label: String = dir["label"] as String
		var color: Color = dir["color"] as Color

		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)

		# Draw background.
		if label == "N":
			draw_circle(pos, 10, Color(0.15, 0.1, 0.1, 0.7))

		# Draw text.
		draw_string(font, pos - text_size * 0.5 + Vector2(0, text_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, color)


## Initialize terrain grid with sample data.
func _initialize_terrain_grid() -> void:
	_terrain_heights.clear()

	for y: int in range(TERRAIN_GRID_SIZE):
		var row: Array = []
		for x: int in range(TERRAIN_GRID_SIZE):
			# Generate sample terrain (replace with actual terrain sampling).
			var noise_val: float = sin(float(x) * 0.5) * cos(float(y) * 0.5) * 0.5 + 0.5
			row.append(noise_val)
		_terrain_heights.append(row)


## Update scale factor based on view range and zoom.
func _update_scale_factor() -> void:
	var effective_range: float = view_range / _display_zoom
	_scale_factor = (MINIMAP_SIZE * 0.5 - BORDER_WIDTH) / (effective_range * 0.5)


## Update sound waves animation.
func _update_sound_waves(delta: float) -> void:
	for i: int in range(_sound_waves.size() - 1, -1, -1):
		var wave: Dictionary = _sound_waves[i]
		wave["progress"] = (wave["progress"] as float) + delta * SOUND_WAVE_EXPANSION_SPEED / SOUND_WAVE_DURATION

		if (wave["progress"] as float) >= 1.0:
			_sound_waves.remove_at(i)


## Update danger zones.
func _update_danger_zones(delta: float) -> void:
	for i: int in range(_danger_zones.size() - 1, -1, -1):
		var zone: Dictionary = _danger_zones[i]
		zone["lifetime"] = (zone["lifetime"] as float) - delta

		if (zone["lifetime"] as float) <= 0.0:
			_danger_zones.remove_at(i)


# ── Public API ────────────────────────────────────────────────────────────────

## Set the local player reference.
func set_local_player(player: Node3D) -> void:
	_local_player = player


## Track an entity on the minimap.
func track_entity(node: Node3D, type: String = "enemy", color: Color = ENEMY_COLOR) -> void:
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
	_entity_last_seen.clear()


## Add an objective marker.
func add_objective(position: Vector3, obj_type: String = "objective", color: Color = OBJECTIVE_COLOR) -> void:
	_objective_markers.append({
		"position": position,
		"type": obj_type,
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


## Add a sound wave event (enemy footsteps, gunshot, etc.).
func add_sound_event(position: Vector3, sound_type: String = "footstep", intensity: float = 1.0) -> void:
	if _sound_waves.size() >= MAX_SOUND_WAVES:
		_sound_waves.remove_at(0)

	_sound_waves.append({
		"position": position,
		"type": sound_type,
		"intensity": intensity,
		"progress": 0.0,
	})

	footsteps_detected.emit(position, intensity)


## Add a danger zone (ML-predicted threat area).
func add_danger_zone(position: Vector3, zone_radius: float, threat_level: float, duration: float = 10.0) -> void:
	_danger_zones.append({
		"position": position,
		"radius": zone_radius,
		"threat_level": threat_level,
		"lifetime": duration,
	})

	danger_zone_detected.emit(position, threat_level)


## Clear all danger zones.
func clear_danger_zones() -> void:
	_danger_zones.clear()


## Set objective path waypoints for Bezier curve drawing.
func set_objective_path(waypoints: Array[Vector3]) -> void:
	_path_waypoints = waypoints


## Clear objective path.
func clear_objective_path() -> void:
	_path_waypoints.clear()


## Update terrain height data.
func update_terrain_heights(heights: Array[Array]) -> void:
	_terrain_heights = heights


## Trigger scan pulse effect.
func trigger_scan_pulse() -> void:
	if _scan_pulse_active:
		return

	_scan_pulse_active = true
	_scan_pulse_progress = 0.0

	if _scan_pulse_tween and _scan_pulse_tween.is_valid():
		_scan_pulse_tween.kill()

	_scan_pulse_tween = create_tween()
	_scan_pulse_tween.tween_property(self, "_scan_pulse_progress", 1.0, SCAN_PULSE_DURATION)
	_scan_pulse_tween.tween_callback(func() -> void: _scan_pulse_active = false)


## Set zoom level (1.0 = default, higher = more zoomed in).
func set_zoom(level: float) -> void:
	zoom_level = clampf(level, 0.5, 3.0)


## Toggle map rotation mode.
func set_rotate_with_player(enabled: bool) -> void:
	rotate_with_player = enabled


## Set view range in world units.
func set_view_range(world_range: float) -> void:
	view_range = maxf(world_range, 20.0)
	_update_scale_factor()
