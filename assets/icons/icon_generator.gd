@tool
class_name IconGenerator
extends RefCounted
## Procedural Icon Generator for BattleZone Party
## Creates game icons using Godot primitives and procedural techniques
## Perfect for UI elements, HUD indicators, and action buttons

enum IconType {
	PLAY,
	PAUSE,
	SETTINGS_GEAR,
	HOME,
	BACK_ARROW,
	FORWARD_ARROW,
	REFRESH,
	CLOSE_X,
	CHECK,
	PLUS,
	MINUS,
	STAR,
	HEART,
	SHIELD,
	SWORD,
	TROPHY,
	CROWN,
	LIGHTNING,
	FIRE,
	CROSSHAIR,
	CONTROLLER,
	WIFI,
	VOLUME_HIGH,
	VOLUME_MUTE,
	EXPAND,
	COLLAPSE,
	USER,
	USERS,
	CHAT,
	FLAG,
	TIMER,
	COIN
}

# Default icon colors
const ICON_COLORS := {
	"default": Color(0.95, 0.95, 0.95, 1.0),
	"accent": Color(0.3, 0.6, 1.0, 1.0),
	"success": Color(0.3, 0.85, 0.4, 1.0),
	"danger": Color(0.95, 0.3, 0.25, 1.0),
	"warning": Color(0.95, 0.75, 0.2, 1.0),
	"gold": Color(1.0, 0.85, 0.2, 1.0)
}


## Generate an icon of the specified type
static func generate_icon(
	icon_type: IconType,
	size: int = 64,
	color: Color = Color(0.95, 0.95, 0.95, 1.0),
	with_glow: bool = false,
	glow_color: Color = Color(1.0, 1.0, 1.0, 0.3)
) -> ImageTexture:

	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var padding := int(size * 0.15)
	var inner_size := size - padding * 2

	match icon_type:
		IconType.PLAY:
			_draw_play_icon(image, padding, inner_size, color)
		IconType.PAUSE:
			_draw_pause_icon(image, padding, inner_size, color)
		IconType.SETTINGS_GEAR:
			_draw_gear_icon(image, padding, inner_size, color)
		IconType.HOME:
			_draw_home_icon(image, padding, inner_size, color)
		IconType.BACK_ARROW:
			_draw_arrow_icon(image, padding, inner_size, color, true)
		IconType.FORWARD_ARROW:
			_draw_arrow_icon(image, padding, inner_size, color, false)
		IconType.REFRESH:
			_draw_refresh_icon(image, padding, inner_size, color)
		IconType.CLOSE_X:
			_draw_close_icon(image, padding, inner_size, color)
		IconType.CHECK:
			_draw_check_icon(image, padding, inner_size, color)
		IconType.PLUS:
			_draw_plus_icon(image, padding, inner_size, color)
		IconType.MINUS:
			_draw_minus_icon(image, padding, inner_size, color)
		IconType.STAR:
			_draw_star_icon(image, padding, inner_size, color)
		IconType.HEART:
			_draw_heart_icon(image, padding, inner_size, color)
		IconType.SHIELD:
			_draw_shield_icon(image, padding, inner_size, color)
		IconType.SWORD:
			_draw_sword_icon(image, padding, inner_size, color)
		IconType.TROPHY:
			_draw_trophy_icon(image, padding, inner_size, color)
		IconType.CROWN:
			_draw_crown_icon(image, padding, inner_size, color)
		IconType.LIGHTNING:
			_draw_lightning_icon(image, padding, inner_size, color)
		IconType.FIRE:
			_draw_fire_icon(image, padding, inner_size, color)
		IconType.CROSSHAIR:
			_draw_crosshair_icon(image, padding, inner_size, color)
		IconType.CONTROLLER:
			_draw_controller_icon(image, padding, inner_size, color)
		IconType.WIFI:
			_draw_wifi_icon(image, padding, inner_size, color)
		IconType.VOLUME_HIGH:
			_draw_volume_icon(image, padding, inner_size, color, true)
		IconType.VOLUME_MUTE:
			_draw_volume_icon(image, padding, inner_size, color, false)
		IconType.USER:
			_draw_user_icon(image, padding, inner_size, color)
		IconType.USERS:
			_draw_users_icon(image, padding, inner_size, color)
		IconType.CHAT:
			_draw_chat_icon(image, padding, inner_size, color)
		IconType.FLAG:
			_draw_flag_icon(image, padding, inner_size, color)
		IconType.TIMER:
			_draw_timer_icon(image, padding, inner_size, color)
		IconType.COIN:
			_draw_coin_icon(image, padding, inner_size, color)

	if with_glow:
		_apply_icon_glow(image, glow_color)

	return ImageTexture.create_from_image(image)


## Generate a complete icon set for common actions
static func generate_icon_set(
	size: int = 64,
	color: Color = Color(0.95, 0.95, 0.95, 1.0)
) -> Dictionary:
	var icons := {}
	for icon_type in IconType.values():
		var type_name: String = IconType.keys()[icon_type].to_lower()
		icons[type_name] = generate_icon(icon_type, size, color)
	return icons


# ============ ICON DRAWING FUNCTIONS ============

static func _draw_play_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2
	var half_size := size / 2

	# Draw triangle pointing right
	var points := [
		Vector2(cx - half_size * 0.4, cy - half_size * 0.7),
		Vector2(cx + half_size * 0.6, cy),
		Vector2(cx - half_size * 0.4, cy + half_size * 0.7)
	]

	_fill_polygon(image, points, color)


static func _draw_pause_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var bar_width := int(size * 0.25)
	var bar_height := int(size * 0.7)
	var gap := int(size * 0.15)

	var left_x := padding + (size - bar_width * 2 - gap) / 2
	var top_y := padding + (size - bar_height) / 2

	# Left bar
	_fill_rect(image, left_x, top_y, bar_width, bar_height, color)
	# Right bar
	_fill_rect(image, left_x + bar_width + gap, top_y, bar_width, bar_height, color)


static func _draw_gear_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2
	var outer_radius := size / 2 - 2
	var inner_radius := outer_radius * 0.55
	var tooth_count := 8
	var tooth_depth := outer_radius * 0.25

	# Draw gear teeth
	for i in range(tooth_count * 2):
		var angle := TAU * i / (tooth_count * 2)
		var radius: float = outer_radius if i % 2 == 0 else outer_radius - tooth_depth

		var x := cx + int(radius * cos(angle))
		var y := cy + int(radius * sin(angle))

		_draw_thick_line(image, cx, cy, x, y, color, 3)

	# Draw outer ring
	_draw_circle_outline(image, cx, cy, outer_radius - tooth_depth / 2, color, 4)

	# Draw inner hole
	_draw_filled_circle(image, cx, cy, int(inner_radius * 0.4), Color(0, 0, 0, 0))


static func _draw_home_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var base_y := padding + size - 4

	# Roof triangle
	var roof_points := [
		Vector2(cx, padding + 4),
		Vector2(padding + 4, padding + size * 0.45),
		Vector2(padding + size - 4, padding + size * 0.45)
	]
	_fill_polygon(image, roof_points, color)

	# House body
	var body_top := int(padding + size * 0.4)
	var body_left := padding + int(size * 0.15)
	var body_width := int(size * 0.7)
	var body_height := int(size * 0.5)
	_fill_rect(image, body_left, body_top, body_width, body_height, color)

	# Door (cut out)
	var door_width := int(size * 0.25)
	var door_height := int(size * 0.35)
	var door_left := cx - door_width / 2
	var door_top := base_y - door_height - 2
	_fill_rect(image, door_left, door_top, door_width, door_height, Color(0, 0, 0, 0))


static func _draw_arrow_icon(image: Image, padding: int, size: int, color: Color, is_back: bool) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2
	var arrow_size := int(size * 0.35)
	var shaft_width := int(size * 0.15)

	if is_back:
		# Arrow pointing left
		var points := [
			Vector2(cx - arrow_size, cy),
			Vector2(cx, cy - arrow_size),
			Vector2(cx, cy - shaft_width),
			Vector2(cx + arrow_size, cy - shaft_width),
			Vector2(cx + arrow_size, cy + shaft_width),
			Vector2(cx, cy + shaft_width),
			Vector2(cx, cy + arrow_size)
		]
		_fill_polygon(image, points, color)
	else:
		# Arrow pointing right
		var points := [
			Vector2(cx + arrow_size, cy),
			Vector2(cx, cy - arrow_size),
			Vector2(cx, cy - shaft_width),
			Vector2(cx - arrow_size, cy - shaft_width),
			Vector2(cx - arrow_size, cy + shaft_width),
			Vector2(cx, cy + shaft_width),
			Vector2(cx, cy + arrow_size)
		]
		_fill_polygon(image, points, color)


static func _draw_refresh_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2
	var radius := size / 2 - 6

	# Draw circular arrow (arc)
	_draw_arc(image, cx, cy, radius, 0.3, 2.5, color, 4)

	# Draw arrowhead
	var arrow_angle := 0.3
	var ax := cx + int(radius * cos(arrow_angle))
	var ay := cy + int(radius * sin(arrow_angle))

	var arrow_points := [
		Vector2(ax, ay),
		Vector2(ax - 10, ay - 5),
		Vector2(ax - 5, ay + 10)
	]
	_fill_polygon(image, arrow_points, color)


static func _draw_close_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var margin := int(size * 0.2)
	var x1 := padding + margin
	var y1 := padding + margin
	var x2 := padding + size - margin
	var y2 := padding + size - margin

	_draw_thick_line(image, x1, y1, x2, y2, color, 4)
	_draw_thick_line(image, x2, y1, x1, y2, color, 4)


static func _draw_check_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var x1 := padding + int(size * 0.15)
	var y1 := padding + int(size * 0.5)
	var x2 := padding + int(size * 0.4)
	var y2 := padding + int(size * 0.75)
	var x3 := padding + int(size * 0.85)
	var y3 := padding + int(size * 0.25)

	_draw_thick_line(image, x1, y1, x2, y2, color, 5)
	_draw_thick_line(image, x2, y2, x3, y3, color, 5)


static func _draw_plus_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2
	var arm_length := int(size * 0.35)
	var thickness := int(size * 0.15)

	# Horizontal bar
	_fill_rect(image, cx - arm_length, cy - thickness / 2, arm_length * 2, thickness, color)
	# Vertical bar
	_fill_rect(image, cx - thickness / 2, cy - arm_length, thickness, arm_length * 2, color)


static func _draw_minus_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2
	var arm_length := int(size * 0.35)
	var thickness := int(size * 0.15)

	# Horizontal bar only
	_fill_rect(image, cx - arm_length, cy - thickness / 2, arm_length * 2, thickness, color)


static func _draw_star_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2
	var outer_radius := size / 2 - 4
	var inner_radius := outer_radius * 0.4
	var points: Array[Vector2] = []

	for i in range(10):
		var angle := TAU * i / 10 - PI / 2
		var radius: float = outer_radius if i % 2 == 0 else inner_radius
		points.append(Vector2(cx + radius * cos(angle), cy + radius * sin(angle)))

	_fill_polygon(image, points, color)


static func _draw_heart_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var top_y := padding + int(size * 0.3)
	var bottom_y := padding + size - 4
	var left_cx := cx - int(size * 0.22)
	var right_cx := cx + int(size * 0.22)
	var lobe_radius := int(size * 0.22)

	# Draw two circles for top lobes
	_draw_filled_circle(image, left_cx, top_y, lobe_radius, color)
	_draw_filled_circle(image, right_cx, top_y, lobe_radius, color)

	# Draw triangle for bottom
	var triangle_points := [
		Vector2(padding + 4, top_y),
		Vector2(padding + size - 4, top_y),
		Vector2(cx, bottom_y)
	]
	_fill_polygon(image, triangle_points, color)


static func _draw_shield_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var top_y := padding + 4
	var bottom_y := padding + size - 4
	var half_width := size / 2 - 4

	var points := [
		Vector2(cx - half_width, top_y),
		Vector2(cx + half_width, top_y),
		Vector2(cx + half_width, top_y + size * 0.4),
		Vector2(cx, bottom_y),
		Vector2(cx - half_width, top_y + size * 0.4)
	]

	_fill_polygon(image, points, color)


static func _draw_sword_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2

	# Blade
	var blade_points := [
		Vector2(cx, padding + 4),
		Vector2(cx + 6, padding + size * 0.65),
		Vector2(cx - 6, padding + size * 0.65)
	]
	_fill_polygon(image, blade_points, color)

	# Guard
	_fill_rect(image, padding + int(size * 0.2), int(padding + size * 0.6), int(size * 0.6), 6, color)

	# Handle
	_fill_rect(image, cx - 4, int(padding + size * 0.65), 8, int(size * 0.25), color)

	# Pommel
	_draw_filled_circle(image, cx, padding + size - 6, 5, color)


static func _draw_trophy_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cup_width := int(size * 0.5)
	var cup_height := int(size * 0.5)
	var top_y := padding + 6

	# Cup body
	var cup_points := [
		Vector2(cx - cup_width / 2, top_y),
		Vector2(cx + cup_width / 2, top_y),
		Vector2(cx + cup_width / 3, top_y + cup_height),
		Vector2(cx - cup_width / 3, top_y + cup_height)
	]
	_fill_polygon(image, cup_points, color)

	# Handles
	_draw_arc(image, padding + int(size * 0.2), top_y + cup_height / 3, int(size * 0.15), PI * 0.5, PI * 1.5, color, 3)
	_draw_arc(image, padding + size - int(size * 0.2), top_y + cup_height / 3, int(size * 0.15), -PI * 0.5, PI * 0.5, color, 3)

	# Stem
	_fill_rect(image, cx - 4, top_y + cup_height, 8, int(size * 0.15), color)

	# Base
	_fill_rect(image, cx - int(size * 0.25), padding + size - 10, int(size * 0.5), 6, color)


static func _draw_crown_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var top_y := padding + int(size * 0.2)
	var bottom_y := padding + size - int(size * 0.25)
	var half_width := int(size * 0.4)

	var points := [
		Vector2(cx - half_width, bottom_y),
		Vector2(cx - half_width, top_y + size * 0.2),
		Vector2(cx - half_width * 0.5, top_y + size * 0.35),
		Vector2(cx - half_width * 0.25, top_y),
		Vector2(cx, top_y + size * 0.25),
		Vector2(cx + half_width * 0.25, top_y),
		Vector2(cx + half_width * 0.5, top_y + size * 0.35),
		Vector2(cx + half_width, top_y + size * 0.2),
		Vector2(cx + half_width, bottom_y)
	]

	_fill_polygon(image, points, color)

	# Base band
	_fill_rect(image, cx - half_width, bottom_y, half_width * 2, 6, color)


static func _draw_lightning_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2

	var points := [
		Vector2(cx + size * 0.1, padding + 4),
		Vector2(cx - size * 0.25, padding + size * 0.5),
		Vector2(cx, padding + size * 0.5),
		Vector2(cx - size * 0.1, padding + size - 4),
		Vector2(cx + size * 0.25, padding + size * 0.4),
		Vector2(cx, padding + size * 0.4)
	]

	_fill_polygon(image, points, color)


static func _draw_fire_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var bottom_y := padding + size - 4

	# Main flame
	var points := [
		Vector2(cx, padding + 4),
		Vector2(cx + size * 0.3, padding + size * 0.4),
		Vector2(cx + size * 0.25, bottom_y),
		Vector2(cx, bottom_y - size * 0.15),
		Vector2(cx - size * 0.25, bottom_y),
		Vector2(cx - size * 0.3, padding + size * 0.4)
	]

	_fill_polygon(image, points, color)


static func _draw_crosshair_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2
	var radius := size / 2 - 6
	var gap := 6

	# Circle
	_draw_circle_outline(image, cx, cy, radius, color, 2)

	# Cross lines with gap
	_draw_thick_line(image, padding + 4, cy, cx - gap, cy, color, 2)
	_draw_thick_line(image, cx + gap, cy, padding + size - 4, cy, color, 2)
	_draw_thick_line(image, cx, padding + 4, cx, cy - gap, color, 2)
	_draw_thick_line(image, cx, cy + gap, cx, padding + size - 4, color, 2)

	# Center dot
	_draw_filled_circle(image, cx, cy, 2, color)


static func _draw_controller_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2

	# Controller body (rounded rectangle)
	var body_width := int(size * 0.8)
	var body_height := int(size * 0.5)

	_draw_rounded_rect(image, cx - body_width / 2, cy - body_height / 2, body_width, body_height, 8, color)

	# D-pad (left side)
	var dpad_x := cx - int(size * 0.22)
	_fill_rect(image, dpad_x - 6, cy - 2, 12, 4, Color(0, 0, 0, 0))
	_fill_rect(image, dpad_x - 2, cy - 6, 4, 12, Color(0, 0, 0, 0))

	# Buttons (right side)
	var btn_x := cx + int(size * 0.22)
	_draw_filled_circle(image, btn_x, cy - 4, 3, Color(0, 0, 0, 0))
	_draw_filled_circle(image, btn_x, cy + 4, 3, Color(0, 0, 0, 0))


static func _draw_wifi_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var bottom_y := padding + size - 8

	# Draw arcs from bottom to top
	_draw_arc(image, cx, bottom_y, int(size * 0.15), -PI * 0.8, -PI * 0.2, color, 3)
	_draw_arc(image, cx, bottom_y, int(size * 0.3), -PI * 0.8, -PI * 0.2, color, 3)
	_draw_arc(image, cx, bottom_y, int(size * 0.45), -PI * 0.8, -PI * 0.2, color, 3)

	# Center dot
	_draw_filled_circle(image, cx, bottom_y, 4, color)


static func _draw_volume_icon(image: Image, padding: int, size: int, color: Color, is_high: bool) -> void:
	var speaker_width := int(size * 0.25)
	var speaker_height := int(size * 0.35)
	var cx := padding + int(size * 0.3)
	var cy := padding + size / 2

	# Speaker cone
	var cone_points := [
		Vector2(cx - speaker_width / 2, cy - speaker_height / 3),
		Vector2(cx, cy - speaker_height / 3),
		Vector2(cx + speaker_width / 2, cy - speaker_height / 2),
		Vector2(cx + speaker_width / 2, cy + speaker_height / 2),
		Vector2(cx, cy + speaker_height / 3),
		Vector2(cx - speaker_width / 2, cy + speaker_height / 3)
	]
	_fill_polygon(image, cone_points, color)

	if is_high:
		# Sound waves
		var wave_x := cx + speaker_width / 2 + 8
		_draw_arc(image, wave_x, cy, 8, -PI * 0.4, PI * 0.4, color, 2)
		_draw_arc(image, wave_x, cy, 16, -PI * 0.4, PI * 0.4, color, 2)
	else:
		# X for mute
		var x_offset := cx + speaker_width / 2 + 12
		_draw_thick_line(image, x_offset, cy - 8, x_offset + 12, cy + 8, color, 3)
		_draw_thick_line(image, x_offset + 12, cy - 8, x_offset, cy + 8, color, 3)


static func _draw_user_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var head_radius := int(size * 0.2)
	var head_y := padding + int(size * 0.3)

	# Head
	_draw_filled_circle(image, cx, head_y, head_radius, color)

	# Body (shoulders)
	var body_top := head_y + head_radius + 4
	var body_width := int(size * 0.5)

	var body_points := [
		Vector2(cx - body_width / 2, padding + size - 4),
		Vector2(cx - body_width / 4, body_top),
		Vector2(cx + body_width / 4, body_top),
		Vector2(cx + body_width / 2, padding + size - 4)
	]
	_fill_polygon(image, body_points, color)


static func _draw_users_icon(image: Image, padding: int, size: int, color: Color) -> void:
	# Draw two overlapping user icons
	var offset := int(size * 0.15)

	# Back user (slightly dimmer)
	var dim_color := Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, color.a)
	_draw_user_icon_at(image, padding - offset, padding, size, dim_color)

	# Front user
	_draw_user_icon_at(image, padding + offset, padding, size, color)


static func _draw_user_icon_at(image: Image, padding_x: int, padding_y: int, size: int, color: Color) -> void:
	var cx := padding_x + size / 2
	var head_radius := int(size * 0.18)
	var head_y := padding_y + int(size * 0.32)

	_draw_filled_circle(image, cx, head_y, head_radius, color)

	var body_top := head_y + head_radius + 3
	var body_width := int(size * 0.4)

	var body_points := [
		Vector2(cx - body_width / 2, padding_y + size - 6),
		Vector2(cx - body_width / 4, body_top),
		Vector2(cx + body_width / 4, body_top),
		Vector2(cx + body_width / 2, padding_y + size - 6)
	]
	_fill_polygon(image, body_points, color)


static func _draw_chat_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var bubble_width := int(size * 0.75)
	var bubble_height := int(size * 0.55)
	var left := padding + (size - bubble_width) / 2
	var top := padding + 4

	# Chat bubble
	_draw_rounded_rect(image, left, top, bubble_width, bubble_height, 8, color)

	# Tail
	var tail_points := [
		Vector2(left + bubble_width * 0.25, top + bubble_height - 2),
		Vector2(left + 8, top + bubble_height + 12),
		Vector2(left + bubble_width * 0.4, top + bubble_height - 2)
	]
	_fill_polygon(image, tail_points, color)


static func _draw_flag_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var pole_x := padding + int(size * 0.25)
	var pole_top := padding + 4
	var pole_bottom := padding + size - 4

	# Pole
	_fill_rect(image, pole_x - 2, pole_top, 4, pole_bottom - pole_top, color)

	# Flag
	var flag_points := [
		Vector2(pole_x + 2, pole_top),
		Vector2(padding + size - 8, pole_top + int(size * 0.2)),
		Vector2(pole_x + 2, pole_top + int(size * 0.4))
	]
	_fill_polygon(image, flag_points, color)


static func _draw_timer_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2 + 4
	var radius := int(size * 0.38)

	# Clock face
	_draw_circle_outline(image, cx, cy, radius, color, 3)

	# Top knob
	_fill_rect(image, cx - 4, padding + 4, 8, 8, color)

	# Clock hands
	_draw_thick_line(image, cx, cy, cx, cy - radius + 6, color, 2)
	_draw_thick_line(image, cx, cy, cx + radius - 8, cy + 4, color, 2)

	# Center dot
	_draw_filled_circle(image, cx, cy, 3, color)


static func _draw_coin_icon(image: Image, padding: int, size: int, color: Color) -> void:
	var cx := padding + size / 2
	var cy := padding + size / 2
	var radius := size / 2 - 4

	# Outer circle
	_draw_filled_circle(image, cx, cy, radius, color)

	# Inner ring
	var ring_color := Color(color.r * 0.8, color.g * 0.7, color.b * 0.4, color.a)
	_draw_circle_outline(image, cx, cy, radius - 4, ring_color, 2)

	# Dollar sign or symbol
	_fill_rect(image, cx - 2, cy - radius + 10, 4, radius * 2 - 20, ring_color)


# ============ PRIMITIVE DRAWING HELPERS ============

static func _fill_rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(h):
		for px in range(w):
			var abs_x := x + px
			var abs_y := y + py
			if abs_x >= 0 and abs_x < image.get_width() and abs_y >= 0 and abs_y < image.get_height():
				var existing := image.get_pixel(abs_x, abs_y)
				image.set_pixel(abs_x, abs_y, _alpha_blend(existing, color))


static func _draw_rounded_rect(image: Image, x: int, y: int, w: int, h: int, radius: int, color: Color) -> void:
	for py in range(h):
		for px in range(w):
			if _is_inside_rounded_rect(px, py, w, h, radius):
				var abs_x := x + px
				var abs_y := y + py
				if abs_x >= 0 and abs_x < image.get_width() and abs_y >= 0 and abs_y < image.get_height():
					var existing := image.get_pixel(abs_x, abs_y)
					image.set_pixel(abs_x, abs_y, _alpha_blend(existing, color))


static func _is_inside_rounded_rect(px: int, py: int, w: int, h: int, radius: int) -> bool:
	if px < 0 or px >= w or py < 0 or py >= h:
		return false

	if px < radius and py < radius:
		return _point_in_circle(px, py, radius, radius, radius)
	elif px >= w - radius and py < radius:
		return _point_in_circle(px, py, w - radius - 1, radius, radius)
	elif px < radius and py >= h - radius:
		return _point_in_circle(px, py, radius, h - radius - 1, radius)
	elif px >= w - radius and py >= h - radius:
		return _point_in_circle(px, py, w - radius - 1, h - radius - 1, radius)

	return true


static func _point_in_circle(px: int, py: int, cx: int, cy: int, r: int) -> bool:
	var dx := px - cx
	var dy := py - cy
	return (dx * dx + dy * dy) <= (r * r)


static func _draw_filled_circle(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var x := cx + dx
				var y := cy + dy
				if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
					var existing := image.get_pixel(x, y)
					image.set_pixel(x, y, _alpha_blend(existing, color))


static func _draw_circle_outline(image: Image, cx: int, cy: int, radius: int, color: Color, thickness: int) -> void:
	for dy in range(-radius - thickness, radius + thickness + 1):
		for dx in range(-radius - thickness, radius + thickness + 1):
			var dist := sqrt(float(dx * dx + dy * dy))
			if abs(dist - radius) <= thickness / 2.0:
				var x := cx + dx
				var y := cy + dy
				if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
					var existing := image.get_pixel(x, y)
					image.set_pixel(x, y, _alpha_blend(existing, color))


static func _draw_thick_line(image: Image, x1: int, y1: int, x2: int, y2: int, color: Color, thickness: int) -> void:
	var dx: int = abs(x2 - x1)
	var dy: int = abs(y2 - y1)
	var sx: int = 1 if x1 < x2 else -1
	var sy: int = 1 if y1 < y2 else -1
	var err: int = dx - dy

	var x: int = x1
	var y: int = y1

	while true:
		for ty in range(-thickness / 2, thickness / 2 + 1):
			for tx in range(-thickness / 2, thickness / 2 + 1):
				var px: int = x + tx
				var py: int = y + ty
				if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
					var existing: Color = image.get_pixel(px, py)
					image.set_pixel(px, py, _alpha_blend(existing, color))

		if x == x2 and y == y2:
			break

		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy


static func _draw_arc(image: Image, cx: int, cy: int, radius: int, start_angle: float, end_angle: float, color: Color, thickness: int) -> void:
	var steps := int(abs(end_angle - start_angle) * radius * 0.5)
	steps = maxi(steps, 20)

	for i in range(steps):
		var t: float = float(i) / float(steps - 1)
		var angle := lerpf(start_angle, end_angle, t)
		var x := cx + int(radius * cos(angle))
		var y := cy + int(radius * sin(angle))

		for ty in range(-thickness / 2, thickness / 2 + 1):
			for tx in range(-thickness / 2, thickness / 2 + 1):
				var px := x + tx
				var py := y + ty
				if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
					var existing := image.get_pixel(px, py)
					image.set_pixel(px, py, _alpha_blend(existing, color))


static func _fill_polygon(image: Image, points: Array, color: Color) -> void:
	if points.size() < 3:
		return

	# Find bounding box
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF

	for point in points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)

	# Scanline fill
	for y in range(int(min_y), int(max_y) + 1):
		var intersections: Array[float] = []

		for i in range(points.size()):
			var p1: Vector2 = points[i]
			var p2: Vector2 = points[(i + 1) % points.size()]

			if (p1.y <= y and p2.y > y) or (p2.y <= y and p1.y > y):
				var t: float = (y - p1.y) / (p2.y - p1.y)
				intersections.append(p1.x + t * (p2.x - p1.x))

		intersections.sort()

		for i in range(0, intersections.size() - 1, 2):
			var x_start := int(intersections[i])
			var x_end := int(intersections[i + 1])

			for x in range(x_start, x_end + 1):
				if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
					var existing := image.get_pixel(x, y)
					image.set_pixel(x, y, _alpha_blend(existing, color))


static func _apply_icon_glow(image: Image, glow_color: Color) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var glow_radius := 4

	# Create a copy for the glow
	var glow_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	glow_image.fill(Color(0, 0, 0, 0))

	# Blur the original image for glow
	for y in range(height):
		for x in range(width):
			var original := image.get_pixel(x, y)
			if original.a > 0.1:
				# Add glow around this pixel
				for dy in range(-glow_radius, glow_radius + 1):
					for dx in range(-glow_radius, glow_radius + 1):
						var dist := sqrt(float(dx * dx + dy * dy))
						if dist <= glow_radius:
							var gx := x + dx
							var gy := y + dy
							if gx >= 0 and gx < width and gy >= 0 and gy < height:
								var intensity: float = (1.0 - dist / glow_radius) * original.a * glow_color.a
								var pixel_glow := Color(glow_color.r, glow_color.g, glow_color.b, intensity)
								var existing := glow_image.get_pixel(gx, gy)
								glow_image.set_pixel(gx, gy, _alpha_blend(existing, pixel_glow))

	# Composite glow under original
	for y in range(height):
		for x in range(width):
			var glow := glow_image.get_pixel(x, y)
			var original := image.get_pixel(x, y)
			image.set_pixel(x, y, _alpha_blend(glow, original))


static func _alpha_blend(base: Color, top: Color) -> Color:
	var out_a := top.a + base.a * (1.0 - top.a)
	if out_a < 0.001:
		return Color(0, 0, 0, 0)

	var out_r := (top.r * top.a + base.r * base.a * (1.0 - top.a)) / out_a
	var out_g := (top.g * top.a + base.g * base.a * (1.0 - top.a)) / out_a
	var out_b := (top.b * top.a + base.b * base.a * (1.0 - top.a)) / out_a

	return Color(out_r, out_g, out_b, out_a)
