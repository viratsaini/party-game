## Premium hit marker visual feedback system.
## Features expanding circles, different colors for hit types, kill confirmation X,
## damage numbers with bounce animation, combo system for rapid hits, and smooth effects.
## Designed for competitive mobile game quality (PUBG/CoD/Apex style).
class_name HitMarker
extends Control

## Hit types for different visual feedback.
enum HitType {
	NORMAL,        ## Regular hit.
	HEADSHOT,      ## Headshot/critical hit.
	KILL,          ## Killing blow.
	ASSIST,        ## Assist (partial damage).
	ARMOR_BREAK,   ## Broke enemy armor/shield.
}

## Signal emitted when a combo milestone is reached.
signal combo_milestone(combo_count: int)

## Duration of hit marker animation.
const MARKER_DURATION: float = 0.25

## Duration for kill markers (longer).
const KILL_MARKER_DURATION: float = 0.4

## Combo time window.
const COMBO_WINDOW: float = 1.5

## Colors for different hit types.
const NORMAL_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const HEADSHOT_COLOR: Color = Color(1.0, 0.85, 0.15, 1.0)
const KILL_COLOR: Color = Color(1.0, 0.25, 0.2, 1.0)
const ASSIST_COLOR: Color = Color(0.5, 0.8, 1.0, 1.0)
const ARMOR_BREAK_COLOR: Color = Color(0.3, 0.7, 1.0, 1.0)

## Damage number colors.
const DAMAGE_COLOR_LOW: Color = Color(1.0, 1.0, 1.0, 1.0)
const DAMAGE_COLOR_MED: Color = Color(1.0, 0.85, 0.3, 1.0)
const DAMAGE_COLOR_HIGH: Color = Color(1.0, 0.5, 0.2, 1.0)
const DAMAGE_COLOR_CRITICAL: Color = Color(1.0, 0.2, 0.15, 1.0)

## Size constants.
const BASE_MARKER_SIZE: float = 14.0
const LINE_THICKNESS: float = 2.5
const CENTER_GAP: float = 7.0
const EXPANDING_CIRCLE_MAX_RADIUS: float = 35.0

## Active hit markers with animation state.
var _active_markers: Array[Dictionary] = []

## Active damage numbers.
var _damage_numbers: Array[Dictionary] = []

## Combo tracking.
var _combo_count: int = 0
var _last_hit_time: float = 0.0
var _combo_display_time: float = 0.0

## Cached center position.
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var needs_redraw: bool = false

	# Update active markers.
	var i: int = _active_markers.size() - 1
	while i >= 0:
		var marker: Dictionary = _active_markers[i]
		marker["time"] = (marker["time"] as float) - delta

		if marker["time"] <= 0.0:
			_active_markers.remove_at(i)
		else:
			needs_redraw = true

		i -= 1

	# Update damage numbers.
	i = _damage_numbers.size() - 1
	while i >= 0:
		var dmg_num: Dictionary = _damage_numbers[i]
		dmg_num["time"] = (dmg_num["time"] as float) - delta

		# Update position (float up).
		dmg_num["offset_y"] = (dmg_num["offset_y"] as float) - delta * 60.0

		if dmg_num["time"] <= 0.0:
			_damage_numbers.remove_at(i)
		else:
			needs_redraw = true

		i -= 1

	# Update combo timer.
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if _combo_count > 0 and current_time - _last_hit_time > COMBO_WINDOW:
		_combo_count = 0

	if _combo_display_time > 0.0:
		_combo_display_time -= delta
		needs_redraw = true

	if needs_redraw or not _active_markers.is_empty() or not _damage_numbers.is_empty():
		queue_redraw()


func _draw() -> void:
	_center = size * 0.5

	# Draw active markers.
	for marker: Dictionary in _active_markers:
		_draw_marker(marker)

	# Draw damage numbers.
	for dmg_num: Dictionary in _damage_numbers:
		_draw_damage_number(dmg_num)

	# Draw combo counter.
	if _combo_count >= 2 and _combo_display_time > 0.0:
		_draw_combo_counter()


## Draw a single hit marker.
func _draw_marker(marker: Dictionary) -> void:
	var hit_type: HitType = marker.get("type", HitType.NORMAL) as HitType
	var time: float = marker["time"] as float
	var duration: float = marker.get("duration", MARKER_DURATION) as float
	var progress: float = 1.0 - (time / duration)

	# Animation values.
	var alpha: float = 1.0 - progress * progress  # Quadratic fade.
	var scale: float = 1.0 + progress * 0.4
	var rotation: float = marker.get("rotation", 0.0) as float

	# Get color based on hit type.
	var color: Color = _get_color_for_type(hit_type)
	color.a = alpha

	# Calculate marker dimensions.
	var gap: float = CENTER_GAP * scale
	var length: float = BASE_MARKER_SIZE * scale

	# Draw based on hit type.
	match hit_type:
		HitType.KILL:
			_draw_kill_marker(_center, gap, length, rotation, color, progress)
		HitType.HEADSHOT:
			_draw_headshot_marker(_center, gap, length, rotation, color, progress)
		HitType.ARMOR_BREAK:
			_draw_armor_break_marker(_center, gap, length, color, progress)
		_:
			_draw_standard_marker(_center, gap, length, rotation, color)

	# Draw expanding circle for all hit types.
	if marker.get("show_circle", false) as bool:
		_draw_expanding_circle(_center, progress, color)


## Draw standard X-shaped hit marker.
func _draw_standard_marker(center: Vector2, gap: float, length: float, rotation: float, color: Color) -> void:
	var cos_r: float = cos(rotation)
	var sin_r: float = sin(rotation)

	var directions: Array[Vector2] = [
		Vector2(-1, -1).normalized(),
		Vector2(1, -1).normalized(),
		Vector2(1, 1).normalized(),
		Vector2(-1, 1).normalized(),
	]

	for dir: Vector2 in directions:
		var rotated_dir: Vector2 = Vector2(
			dir.x * cos_r - dir.y * sin_r,
			dir.x * sin_r + dir.y * cos_r
		)

		var start: Vector2 = center + rotated_dir * gap
		var end: Vector2 = center + rotated_dir * (gap + length)

		# Outline.
		var outline_color: Color = Color(0, 0, 0, color.a * 0.6)
		draw_line(start, end, outline_color, LINE_THICKNESS + 2.0)

		# Main line.
		draw_line(start, end, color, LINE_THICKNESS)


## Draw kill confirmation marker (X with additional effects).
func _draw_kill_marker(center: Vector2, gap: float, length: float, rotation: float, color: Color, progress: float) -> void:
	# Draw standard X.
	_draw_standard_marker(center, gap, length, rotation, color)

	# Draw additional expanding ring.
	var ring_radius: float = (gap + length) * (1.0 + progress * 0.5)
	var ring_color: Color = color
	ring_color.a *= 0.5 * (1.0 - progress)
	draw_arc(center, ring_radius, 0.0, TAU, 32, ring_color, 2.0)

	# Draw inner confirmation dot.
	if progress < 0.3:
		var dot_alpha: float = (0.3 - progress) / 0.3
		var dot_color: Color = color
		dot_color.a = dot_alpha
		draw_circle(center, 3.0, dot_color)


## Draw headshot marker (crown effect).
func _draw_headshot_marker(center: Vector2, gap: float, length: float, rotation: float, color: Color, progress: float) -> void:
	# Draw standard X with headshot color.
	_draw_standard_marker(center, gap, length, rotation, color)

	# Draw crown/star effect above.
	var crown_y: float = center.y - gap - length - 8.0
	var crown_scale: float = 1.0 + progress * 0.3
	var crown_color: Color = color
	crown_color.a *= 1.0 - progress * 0.5

	# Simple crown shape.
	var crown_width: float = 12.0 * crown_scale
	var crown_height: float = 8.0 * crown_scale

	var crown_points: PackedVector2Array = PackedVector2Array([
		Vector2(center.x - crown_width, crown_y),
		Vector2(center.x - crown_width * 0.5, crown_y - crown_height),
		Vector2(center.x, crown_y - crown_height * 0.4),
		Vector2(center.x + crown_width * 0.5, crown_y - crown_height),
		Vector2(center.x + crown_width, crown_y),
	])

	# Draw crown outline.
	var outline_color: Color = Color(0, 0, 0, crown_color.a * 0.6)
	draw_polyline(crown_points, outline_color, 3.0)
	draw_polyline(crown_points, crown_color, 2.0)

	# Draw sparkle effect.
	if progress < 0.5:
		var sparkle_alpha: float = (0.5 - progress) / 0.5
		var sparkle_color: Color = HEADSHOT_COLOR
		sparkle_color.a = sparkle_alpha * 0.8

		# Small sparkles around crown.
		for j: int in range(3):
			var sparkle_angle: float = -PI * 0.5 + (float(j) - 1.0) * 0.4
			var sparkle_dist: float = crown_height + 5.0 + progress * 15.0
			var sparkle_pos: Vector2 = Vector2(center.x, crown_y) + Vector2(cos(sparkle_angle), sin(sparkle_angle)) * sparkle_dist
			draw_circle(sparkle_pos, 2.0, sparkle_color)


## Draw armor break marker (shield crack effect).
func _draw_armor_break_marker(center: Vector2, gap: float, length: float, color: Color, progress: float) -> void:
	# Draw shield shape breaking.
	var shield_size: float = gap + length
	var crack_offset: float = progress * 8.0

	# Left half.
	var left_center: Vector2 = center + Vector2(-crack_offset, 0)
	_draw_shield_half(left_center, shield_size, color, true, progress)

	# Right half.
	var right_center: Vector2 = center + Vector2(crack_offset, 0)
	_draw_shield_half(right_center, shield_size, color, false, progress)

	# Draw break particles.
	if progress < 0.6:
		var particle_alpha: float = (0.6 - progress) / 0.6
		var particle_color: Color = ARMOR_BREAK_COLOR
		particle_color.a = particle_alpha * 0.7

		for j: int in range(4):
			var angle: float = float(j) * PI * 0.5 + progress * 2.0
			var dist: float = shield_size * 0.5 + progress * 20.0
			var particle_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
			draw_circle(particle_pos, 2.5 * (1.0 - progress), particle_color)


## Draw half of a shield shape.
func _draw_shield_half(center: Vector2, sz: float, color: Color, is_left: bool, _progress: float) -> void:
	var half_width: float = sz * 0.4
	var height: float = sz * 0.8

	var x_mult: float = -1.0 if is_left else 1.0

	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -height * 0.5),
		center + Vector2(half_width * x_mult, -height * 0.3),
		center + Vector2(half_width * x_mult, height * 0.3),
		center + Vector2(0, height * 0.5),
	])

	draw_polyline(points, color, 2.0)


## Draw expanding circle effect.
func _draw_expanding_circle(center: Vector2, progress: float, color: Color) -> void:
	var radius: float = CENTER_GAP + progress * EXPANDING_CIRCLE_MAX_RADIUS
	var circle_color: Color = color
	circle_color.a *= (1.0 - progress) * 0.6

	# Multiple rings for effect.
	draw_arc(center, radius, 0.0, TAU, 32, circle_color, 2.0)

	if progress < 0.5:
		var inner_radius: float = CENTER_GAP + progress * EXPANDING_CIRCLE_MAX_RADIUS * 0.6
		var inner_color: Color = color
		inner_color.a *= (0.5 - progress) * 0.4
		draw_arc(center, inner_radius, 0.0, TAU, 32, inner_color, 1.5)


## Draw damage number.
func _draw_damage_number(dmg_num: Dictionary) -> void:
	var damage: int = dmg_num["damage"] as int
	var time: float = dmg_num["time"] as float
	var duration: float = dmg_num["duration"] as float
	var offset_x: float = dmg_num["offset_x"] as float
	var offset_y: float = dmg_num["offset_y"] as float
	var is_critical: bool = dmg_num.get("is_critical", false) as bool

	var progress: float = 1.0 - (time / duration)

	# Calculate position with bounce.
	var bounce: float = 0.0
	if progress < 0.2:
		bounce = sin(progress / 0.2 * PI) * 15.0
	var pos: Vector2 = _center + Vector2(offset_x, offset_y - bounce)

	# Calculate alpha with fade.
	var alpha: float = 1.0
	if progress > 0.7:
		alpha = (1.0 - progress) / 0.3

	# Calculate scale with pop.
	var scale: float = 1.0
	if progress < 0.15:
		scale = 1.0 + (0.15 - progress) / 0.15 * 0.4

	# Get color based on damage.
	var color: Color = _get_damage_color(damage, is_critical)
	color.a = alpha

	# Draw damage text.
	var font: Font = ThemeDB.fallback_font
	var damage_text: String = str(damage)
	var font_size: int = int(18 * scale)

	if is_critical:
		damage_text = damage_text + "!"
		font_size = int(22 * scale)

	var text_size: Vector2 = font.get_string_size(damage_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = Vector2(pos.x - text_size.x * 0.5, pos.y + text_size.y * 0.35)

	# Shadow.
	var shadow_color: Color = Color(0, 0, 0, alpha * 0.8)
	draw_string(font, text_pos + Vector2(1, 1), damage_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)
	draw_string(font, text_pos + Vector2(-1, 1), damage_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)

	# Main text.
	draw_string(font, text_pos, damage_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


## Draw combo counter.
func _draw_combo_counter() -> void:
	var font: Font = ThemeDB.fallback_font
	var combo_text: String = "x%d" % _combo_count

	var alpha: float = minf(_combo_display_time / 0.5, 1.0)
	var scale: float = 1.0 + (1.0 - alpha) * 0.2 if _combo_display_time > 0.8 else 1.0

	var font_size: int = int(16 * scale)
	var color: Color = _get_combo_color(_combo_count)
	color.a = alpha

	var text_size: Vector2 = font.get_string_size(combo_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos: Vector2 = Vector2(_center.x + 40, _center.y - 20)
	var text_pos: Vector2 = Vector2(pos.x - text_size.x * 0.5, pos.y + text_size.y * 0.35)

	# Shadow.
	draw_string(font, text_pos + Vector2(1, 1), combo_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, alpha * 0.7))
	# Main.
	draw_string(font, text_pos, combo_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


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
		HitType.ARMOR_BREAK:
			return ARMOR_BREAK_COLOR
		_:
			return NORMAL_COLOR


## Get color for damage number.
func _get_damage_color(damage: int, is_critical: bool) -> Color:
	if is_critical:
		return HEADSHOT_COLOR

	if damage >= 50:
		return DAMAGE_COLOR_CRITICAL
	elif damage >= 30:
		return DAMAGE_COLOR_HIGH
	elif damage >= 15:
		return DAMAGE_COLOR_MED
	else:
		return DAMAGE_COLOR_LOW


## Get color for combo counter.
func _get_combo_color(combo: int) -> Color:
	if combo >= 10:
		return KILL_COLOR
	elif combo >= 5:
		return HEADSHOT_COLOR
	else:
		return NORMAL_COLOR


## Update combo tracking.
func _update_combo() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	if current_time - _last_hit_time <= COMBO_WINDOW:
		_combo_count += 1
		if _combo_count in [5, 10, 15, 20]:
			combo_milestone.emit(_combo_count)
	else:
		_combo_count = 1

	_last_hit_time = current_time
	_combo_display_time = 1.0


# ── Public API ───────────────────────────────────────────────────────────────

## Show a hit marker.
func show_hit(hit_type: HitType = HitType.NORMAL, damage: float = 25.0, show_damage_number: bool = true) -> void:
	var duration: float = MARKER_DURATION
	if hit_type == HitType.KILL:
		duration = KILL_MARKER_DURATION
	elif hit_type == HitType.HEADSHOT:
		duration *= 1.3

	var show_circle: bool = hit_type == HitType.KILL or hit_type == HitType.HEADSHOT

	_active_markers.append({
		"type": hit_type,
		"time": duration,
		"duration": duration,
		"rotation": randf() * 0.15 - 0.075,
		"show_circle": show_circle,
	})

	# Add damage number if requested.
	if show_damage_number and damage > 0.0:
		_add_damage_number(int(damage), hit_type == HitType.HEADSHOT)

	# Update combo.
	_update_combo()

	queue_redraw()


## Add a damage number display.
func _add_damage_number(damage: int, is_critical: bool) -> void:
	var offset_x: float = randf_range(-30.0, 30.0)
	var offset_y: float = randf_range(-10.0, 10.0) - 40.0

	_damage_numbers.append({
		"damage": damage,
		"time": 1.0,
		"duration": 1.0,
		"offset_x": offset_x,
		"offset_y": offset_y,
		"is_critical": is_critical,
	})


## Convenience methods for specific hit types.
func show_normal_hit(damage: float = 25.0) -> void:
	show_hit(HitType.NORMAL, damage)


func show_headshot(damage: float = 50.0) -> void:
	show_hit(HitType.HEADSHOT, damage)


func show_kill(damage: float = 25.0) -> void:
	show_hit(HitType.KILL, damage)


func show_assist(damage: float = 25.0) -> void:
	show_hit(HitType.ASSIST, damage)


func show_armor_break(damage: float = 0.0) -> void:
	show_hit(HitType.ARMOR_BREAK, damage, false)


## Get current combo count.
func get_combo_count() -> int:
	return _combo_count


## Reset combo.
func reset_combo() -> void:
	_combo_count = 0
	_combo_display_time = 0.0


## Clear all active markers.
func clear() -> void:
	_active_markers.clear()
	_damage_numbers.clear()
	queue_redraw()
