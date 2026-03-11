## Dynamic crosshair system with weapon-specific styles.
## Supports spread indicators, hit feedback, and smooth animations.
class_name Crosshair
extends Control

## Crosshair style types.
enum Style {
	DOT,           ## Simple center dot.
	CROSS,         ## Classic cross lines.
	CIRCLE,        ## Circle with center dot.
	CHEVRON,       ## V-shaped indicators.
	DYNAMIC,       ## Lines that spread with accuracy.
}

## Current crosshair style.
var style: Style = Style.DYNAMIC

## Base size of the crosshair.
var base_size: float = 8.0

## Gap between crosshair elements and center.
var center_gap: float = 4.0

## Line thickness.
var line_thickness: float = 2.0

## Crosshair color.
var crosshair_color: Color = Color.WHITE

## Outline color for better visibility.
var outline_color: Color = Color(0.0, 0.0, 0.0, 0.6)

## Whether to show the center dot.
var show_center_dot: bool = true

## Center dot size.
var dot_size: float = 2.0

## Dynamic spread (0.0 to 1.0, affects line separation).
var spread: float = 0.0

## Maximum spread distance.
var max_spread: float = 20.0

## Spread lerp speed.
var spread_lerp_speed: float = 10.0

## Target spread value (for smooth transitions).
var _target_spread: float = 0.0

## Hit marker state.
var _hit_marker_active: bool = false
var _hit_marker_time: float = 0.0
const HIT_MARKER_DURATION: float = 0.15
const HIT_MARKER_COLOR: Color = Color(1.0, 0.3, 0.3, 1.0)
const HEADSHOT_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)

## Whether the last hit was a headshot/critical.
var _is_critical_hit: bool = false

## Cached center position.
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	# Smooth spread transitions.
	spread = lerpf(spread, _target_spread, spread_lerp_speed * delta)

	# Update hit marker.
	if _hit_marker_active:
		_hit_marker_time -= delta
		if _hit_marker_time <= 0.0:
			_hit_marker_active = false

	queue_redraw()


func _draw() -> void:
	_center = size * 0.5

	# Draw based on current style.
	match style:
		Style.DOT:
			_draw_dot_style()
		Style.CROSS:
			_draw_cross_style()
		Style.CIRCLE:
			_draw_circle_style()
		Style.CHEVRON:
			_draw_chevron_style()
		Style.DYNAMIC:
			_draw_dynamic_style()

	# Draw hit marker on top.
	if _hit_marker_active:
		_draw_hit_marker()


## Draw simple dot crosshair.
func _draw_dot_style() -> void:
	var size_with_spread: float = dot_size + spread * 2.0

	# Outline.
	draw_circle(_center, size_with_spread + 1.0, outline_color)
	# Main dot.
	draw_circle(_center, size_with_spread, crosshair_color)


## Draw classic cross crosshair.
func _draw_cross_style() -> void:
	var gap: float = center_gap + spread * max_spread
	var length: float = base_size

	# Draw four lines.
	_draw_crosshair_line(_center + Vector2(0, -gap), _center + Vector2(0, -gap - length), true)
	_draw_crosshair_line(_center + Vector2(0, gap), _center + Vector2(0, gap + length), true)
	_draw_crosshair_line(_center + Vector2(-gap, 0), _center + Vector2(-gap - length, 0), true)
	_draw_crosshair_line(_center + Vector2(gap, 0), _center + Vector2(gap + length, 0), true)

	# Center dot.
	if show_center_dot:
		draw_circle(_center, dot_size + 0.5, outline_color)
		draw_circle(_center, dot_size, crosshair_color)


## Draw circle crosshair.
func _draw_circle_style() -> void:
	var radius: float = center_gap + base_size + spread * max_spread * 0.5

	# Outline.
	draw_arc(_center, radius + 1.0, 0.0, TAU, 32, outline_color, line_thickness + 2.0)
	# Main circle.
	draw_arc(_center, radius, 0.0, TAU, 32, crosshair_color, line_thickness)

	# Center dot.
	if show_center_dot:
		draw_circle(_center, dot_size + 0.5, outline_color)
		draw_circle(_center, dot_size, crosshair_color)


## Draw chevron crosshair.
func _draw_chevron_style() -> void:
	var gap: float = center_gap + spread * max_spread
	var length: float = base_size

	# Top chevron (V shape pointing down).
	var top_center: Vector2 = _center + Vector2(0, -gap)
	_draw_crosshair_line(top_center, top_center + Vector2(-length * 0.7, -length * 0.7), true)
	_draw_crosshair_line(top_center, top_center + Vector2(length * 0.7, -length * 0.7), true)

	# Bottom chevron (V shape pointing up).
	var bottom_center: Vector2 = _center + Vector2(0, gap)
	_draw_crosshair_line(bottom_center, bottom_center + Vector2(-length * 0.7, length * 0.7), true)
	_draw_crosshair_line(bottom_center, bottom_center + Vector2(length * 0.7, length * 0.7), true)

	# Center dot.
	if show_center_dot:
		draw_circle(_center, dot_size + 0.5, outline_color)
		draw_circle(_center, dot_size, crosshair_color)


## Draw dynamic crosshair with spread visualization.
func _draw_dynamic_style() -> void:
	var gap: float = center_gap + spread * max_spread
	var length: float = base_size

	# Four lines with gap.
	_draw_crosshair_line(_center + Vector2(0, -gap), _center + Vector2(0, -gap - length), true)
	_draw_crosshair_line(_center + Vector2(0, gap), _center + Vector2(0, gap + length), true)
	_draw_crosshair_line(_center + Vector2(-gap, 0), _center + Vector2(-gap - length, 0), true)
	_draw_crosshair_line(_center + Vector2(gap, 0), _center + Vector2(gap + length, 0), true)

	# Center dot.
	if show_center_dot:
		draw_circle(_center, dot_size + 0.5, outline_color)
		draw_circle(_center, dot_size, crosshair_color)


## Draw a crosshair line with optional outline.
func _draw_crosshair_line(from: Vector2, to: Vector2, with_outline: bool) -> void:
	if with_outline:
		draw_line(from, to, outline_color, line_thickness + 2.0)
	draw_line(from, to, crosshair_color, line_thickness)


## Draw the hit marker overlay.
func _draw_hit_marker() -> void:
	var progress: float = _hit_marker_time / HIT_MARKER_DURATION
	var alpha: float = progress
	var scale: float = 1.0 + (1.0 - progress) * 0.3

	var color: Color = HEADSHOT_COLOR if _is_critical_hit else HIT_MARKER_COLOR
	color.a = alpha

	var marker_size: float = base_size * 1.5 * scale
	var gap: float = center_gap * 0.5

	# Draw X-shaped hit marker.
	var offset: float = gap + marker_size * 0.3
	var length: float = marker_size * 0.5

	# Top-left to bottom-right.
	draw_line(
		_center + Vector2(-offset, -offset),
		_center + Vector2(-offset - length, -offset - length),
		color, line_thickness + 1.0
	)
	draw_line(
		_center + Vector2(offset, offset),
		_center + Vector2(offset + length, offset + length),
		color, line_thickness + 1.0
	)

	# Top-right to bottom-left.
	draw_line(
		_center + Vector2(offset, -offset),
		_center + Vector2(offset + length, -offset - length),
		color, line_thickness + 1.0
	)
	draw_line(
		_center + Vector2(-offset, offset),
		_center + Vector2(-offset - length, offset + length),
		color, line_thickness + 1.0
	)


## Show hit marker feedback.
## [param is_critical] Whether the hit was a headshot/critical hit.
func show_hit_marker(is_critical: bool = false) -> void:
	_hit_marker_active = true
	_hit_marker_time = HIT_MARKER_DURATION
	_is_critical_hit = is_critical


## Set the spread amount (0.0 = accurate, 1.0 = maximum spread).
func set_spread(amount: float) -> void:
	_target_spread = clampf(amount, 0.0, 1.0)


## Instantly set spread without animation.
func set_spread_instant(amount: float) -> void:
	_target_spread = clampf(amount, 0.0, 1.0)
	spread = _target_spread


## Set crosshair style.
func set_style(new_style: Style) -> void:
	style = new_style


## Configure crosshair for a specific weapon type.
func configure_for_weapon(weapon_type: String) -> void:
	match weapon_type:
		"blaster", "pistol":
			style = Style.DYNAMIC
			base_size = 8.0
			center_gap = 4.0
			show_center_dot = true
		"rapid_fire", "smg":
			style = Style.DYNAMIC
			base_size = 10.0
			center_gap = 6.0
			show_center_dot = true
		"power_shot", "sniper":
			style = Style.CROSS
			base_size = 12.0
			center_gap = 8.0
			show_center_dot = true
		"shotgun":
			style = Style.CIRCLE
			base_size = 15.0
			center_gap = 10.0
			show_center_dot = false
		"rocket":
			style = Style.CHEVRON
			base_size = 10.0
			center_gap = 8.0
			show_center_dot = true
		_:
			style = Style.DYNAMIC
			base_size = 8.0
			center_gap = 4.0
			show_center_dot = true


## Set crosshair color.
func set_color(color: Color) -> void:
	crosshair_color = color


## Set visibility.
func set_crosshair_visible(visible: bool) -> void:
	self.visible = visible
