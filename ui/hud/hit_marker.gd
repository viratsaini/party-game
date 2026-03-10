## Hit marker visual feedback system.
## Shows confirmation when player successfully hits an enemy.
## Supports different styles for regular hits, headshots, and kills.
class_name HitMarker
extends Control

## Hit types for different visual feedback.
enum HitType {
	NORMAL,     ## Regular hit.
	HEADSHOT,   ## Headshot/critical hit.
	KILL,       ## Killing blow.
	ASSIST,     ## Assist (partial damage).
}

## Duration of hit marker animation.
const MARKER_DURATION: float = 0.2

## Colors for different hit types.
const NORMAL_COLOR: Color = Color.WHITE
const HEADSHOT_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)
const KILL_COLOR: Color = Color(1.0, 0.3, 0.2, 1.0)
const ASSIST_COLOR: Color = Color(0.6, 0.8, 1.0, 1.0)

## Size of the hit marker.
const MARKER_SIZE: float = 12.0

## Line thickness.
const LINE_THICKNESS: float = 2.5

## Gap from center.
const CENTER_GAP: float = 6.0

## Active hit markers with animation state.
var _active_markers: Array[Dictionary] = []

## Cached center position.
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	# Update active markers.
	var i: int = _active_markers.size() - 1
	while i >= 0:
		var marker: Dictionary = _active_markers[i]
		marker["time"] = (marker["time"] as float) - delta

		if marker["time"] <= 0.0:
			_active_markers.remove_at(i)

		i -= 1

	if not _active_markers.is_empty():
		queue_redraw()


func _draw() -> void:
	if _active_markers.is_empty():
		return

	_center = size * 0.5

	for marker: Dictionary in _active_markers:
		_draw_marker(marker)


## Draw a single hit marker.
func _draw_marker(marker: Dictionary) -> void:
	var hit_type: HitType = marker.get("type", HitType.NORMAL) as HitType
	var time: float = marker["time"] as float
	var duration: float = marker.get("duration", MARKER_DURATION) as float
	var progress: float = 1.0 - (time / duration)

	# Animation values.
	var alpha: float = 1.0 - progress
	var scale: float = 1.0 + progress * 0.5
	var rotation: float = marker.get("rotation", 0.0) as float

	# Get color based on hit type.
	var color: Color = _get_color_for_type(hit_type)
	color.a = alpha

	# Calculate marker dimensions.
	var gap: float = CENTER_GAP * scale
	var length: float = MARKER_SIZE * scale

	# Draw X-shaped marker.
	_draw_x_marker(_center, gap, length, rotation, color, hit_type == HitType.KILL)


## Draw X-shaped hit marker.
func _draw_x_marker(center: Vector2, gap: float, length: float, rotation: float, color: Color, is_kill: bool) -> void:
	# Four diagonal lines forming an X.
	var cos_r: float = cos(rotation)
	var sin_r: float = sin(rotation)

	var directions: Array[Vector2] = [
		Vector2(-1, -1).normalized(),
		Vector2(1, -1).normalized(),
		Vector2(1, 1).normalized(),
		Vector2(-1, 1).normalized(),
	]

	for dir: Vector2 in directions:
		# Rotate direction.
		var rotated_dir: Vector2 = Vector2(
			dir.x * cos_r - dir.y * sin_r,
			dir.x * sin_r + dir.y * cos_r
		)

		var start: Vector2 = center + rotated_dir * gap
		var end: Vector2 = center + rotated_dir * (gap + length)

		# Draw outline for better visibility.
		var outline_color: Color = Color(0, 0, 0, color.a * 0.6)
		draw_line(start, end, outline_color, LINE_THICKNESS + 2.0)

		# Draw main line.
		draw_line(start, end, color, LINE_THICKNESS)

	# For kills, draw additional effect.
	if is_kill:
		_draw_kill_effect(center, gap + length, color)


## Draw additional visual for kill confirmation.
func _draw_kill_effect(center: Vector2, radius: float, color: Color) -> void:
	# Draw expanding ring.
	var ring_color: Color = color
	ring_color.a *= 0.4
	draw_arc(center, radius * 1.2, 0.0, TAU, 16, ring_color, 1.5)


## Get color for hit type.
func _get_color_for_type(hit_type: HitType) -> Color:
	match hit_type:
		HitType.NORMAL:
			return NORMAL_COLOR
		HitType.HEADSHOT:
			return HEADSHOT_COLOR
		HitType.KILL:
			return KILL_COLOR
		HitType.ASSIST:
			return ASSIST_COLOR
		_:
			return NORMAL_COLOR


## Show a hit marker.
## [param hit_type] Type of hit for visual style.
## [param damage] Damage amount (affects size slightly).
func show_hit(hit_type: HitType = HitType.NORMAL, damage: float = 25.0) -> void:
	var duration: float = MARKER_DURATION
	if hit_type == HitType.KILL:
		duration *= 1.5  # Kill markers last longer.
	elif hit_type == HitType.HEADSHOT:
		duration *= 1.2

	# Scale based on damage.
	var size_scale: float = clampf(damage / 50.0, 0.8, 1.5)

	_active_markers.append({
		"type": hit_type,
		"time": duration,
		"duration": duration,
		"rotation": randf() * 0.2 - 0.1,  # Slight random rotation.
		"size_scale": size_scale,
	})

	queue_redraw()


## Convenience methods for specific hit types.
func show_normal_hit(damage: float = 25.0) -> void:
	show_hit(HitType.NORMAL, damage)


func show_headshot(damage: float = 50.0) -> void:
	show_hit(HitType.HEADSHOT, damage)


func show_kill(damage: float = 25.0) -> void:
	show_hit(HitType.KILL, damage)


func show_assist(damage: float = 25.0) -> void:
	show_hit(HitType.ASSIST, damage)


## Clear all active markers.
func clear() -> void:
	_active_markers.clear()
	queue_redraw()
