## Hit marker visual feedback system with premium features.
## Shows confirmation when player successfully hits an enemy.
## Supports different styles for regular hits, headshots, and kills.
## Features: combo tracking, damage numbers, expanding animations, screen effects.
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

## Damage number settings.
const DAMAGE_NUMBER_RISE_SPEED: float = 100.0
const DAMAGE_NUMBER_FADE_TIME: float = 0.8
const DAMAGE_NUMBER_COLOR: Color = Color(1.0, 0.9, 0.3, 1.0)

## Combo settings.
const COMBO_WINDOW: float = 3.0  ## Time window to maintain combo.
const COMBO_COLOR: Color = Color(0.3, 0.8, 1.0, 1.0)

## Active hit markers with animation state.
var _active_markers: Array[Dictionary] = []

## Floating damage numbers.
## Each entry: {damage: float, position: Vector2, velocity: Vector2, alpha: float}
var _damage_numbers: Array[Dictionary] = []

## Current combo count.
var _combo_count: int = 0

## Time since last hit (for combo tracking).
var _time_since_last_hit: float = 0.0

## Combo display alpha (fades in/out).
var _combo_alpha: float = 0.0

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

	# Update damage numbers.
	i = _damage_numbers.size() - 1
	while i >= 0:
		var dmg_num: Dictionary = _damage_numbers[i]
		dmg_num["position"] = (dmg_num["position"] as Vector2) + (dmg_num["velocity"] as Vector2) * delta
		dmg_num["alpha"] = (dmg_num["alpha"] as float) - delta / DAMAGE_NUMBER_FADE_TIME

		if dmg_num["alpha"] <= 0.0:
			_damage_numbers.remove_at(i)
		i -= 1

	# Update combo timer.
	_time_since_last_hit += delta
	if _time_since_last_hit > COMBO_WINDOW:
		_combo_count = 0
		_combo_alpha = maxf(_combo_alpha - delta * 2.0, 0.0)
	else:
		_combo_alpha = minf(_combo_alpha + delta * 4.0, 1.0)

	if not _active_markers.is_empty() or not _damage_numbers.is_empty() or _combo_alpha > 0.01:
		queue_redraw()


func _draw() -> void:
	_center = size * 0.5

	# Draw active hit markers.
	for marker: Dictionary in _active_markers:
		_draw_marker(marker)

	# Draw damage numbers.
	for dmg_num: Dictionary in _damage_numbers:
		_draw_damage_number(dmg_num)

	# Draw combo counter if active.
	if _combo_count > 1 and _combo_alpha > 0.01:
		_draw_combo_counter()


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


## Draw a floating damage number.
func _draw_damage_number(dmg_num: Dictionary) -> void:
	var damage: float = dmg_num["damage"] as float
	var pos: Vector2 = dmg_num["position"] as Vector2
	var alpha: float = dmg_num["alpha"] as float

	var color: Color = DAMAGE_NUMBER_COLOR
	color.a *= alpha

	var text: String = str(int(damage))
	var font_size: int = 24

	# Draw outline for visibility.
	var outline_color: Color = Color.BLACK
	outline_color.a = alpha * 0.8

	for offset: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		draw_string(ThemeDB.fallback_font, pos + offset, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, outline_color)

	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


## Draw the combo counter.
func _draw_combo_counter() -> void:
	var combo_text: String = "x%d COMBO" % _combo_count
	var combo_pos: Vector2 = _center + Vector2(0, 60)

	var color: Color = COMBO_COLOR
	color.a *= _combo_alpha

	var font_size: int = 28

	# Outline for visibility.
	var outline_color: Color = Color.BLACK
	outline_color.a = _combo_alpha * 0.9

	for offset: Vector2 in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
		draw_string(ThemeDB.fallback_font, combo_pos + offset, combo_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, outline_color)

	draw_string(ThemeDB.fallback_font, combo_pos, combo_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


## Show a hit marker.
## [param hit_type] Type of hit for visual style.
## [param damage] Damage amount (affects size and shows damage number).
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

	# Add floating damage number.
	if damage > 0.0:
		_add_damage_number(damage)

	# Update combo tracking.
	_increment_combo()

	queue_redraw()


## Internal: Add a floating damage number.
func _add_damage_number(damage: float) -> void:
	# Randomize position slightly for variety.
	var offset: Vector2 = Vector2(randf_range(-20, 20), randf_range(-10, 10))

	_damage_numbers.append({
		"damage": damage,
		"position": _center + offset,
		"velocity": Vector2(0, -DAMAGE_NUMBER_RISE_SPEED),
		"alpha": 1.0,
	})


## Internal: Increment combo counter.
func _increment_combo() -> void:
	_combo_count += 1
	_time_since_last_hit = 0.0


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
	_damage_numbers.clear()
	_combo_count = 0
	_combo_alpha = 0.0
	_time_since_last_hit = 0.0
	queue_redraw()


## Reset combo counter (e.g., when round ends).
func reset_combo() -> void:
	_combo_count = 0
	_combo_alpha = 0.0
	_time_since_last_hit = 0.0


## Get current combo count.
func get_combo_count() -> int:
	return _combo_count

