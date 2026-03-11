## Premium competitive-grade crosshair system.
## Features dynamic spread visualization, hit confirmation animations,
## per-weapon custom styles, color customization, and smooth transitions.
## Designed for PUBG/CoD/Apex Mobile quality standards.
class_name EnhancedCrosshair
extends Control

## Crosshair style presets.
enum Style {
	DOT,              ## Simple center dot.
	CROSS,            ## Classic cross lines.
	CIRCLE,           ## Circle with center dot.
	CIRCLE_DOT,       ## Circle with larger center dot.
	CHEVRON,          ## V-shaped indicators.
	DYNAMIC,          ## Lines that spread with accuracy.
	DYNAMIC_CIRCLE,   ## Dynamic lines with circle.
	T_SHAPE,          ## T-shaped crosshair.
	CUSTOM,           ## User-defined custom crosshair.
}

## Hit confirmation types.
enum HitType {
	NONE,
	NORMAL,
	HEADSHOT,
	CRITICAL,
	KILL,
}

## Current crosshair style.
var style: Style = Style.DYNAMIC

## Base size of the crosshair elements.
var base_size: float = 10.0

## Gap between crosshair elements and center.
var center_gap: float = 5.0

## Line thickness.
var line_thickness: float = 2.0

## Primary crosshair color.
var crosshair_color: Color = Color.WHITE

## Outline color for visibility.
var outline_color: Color = Color(0.0, 0.0, 0.0, 0.7)

## Outline thickness.
var outline_thickness: float = 1.0

## Whether to show the center dot.
var show_center_dot: bool = true

## Center dot size.
var dot_size: float = 2.5

## Whether to show the outer circle.
var show_circle: bool = false

## Circle radius.
var circle_radius: float = 20.0

## Dynamic spread (0.0 to 1.0).
var spread: float = 0.0

## Maximum spread distance.
var max_spread: float = 25.0

## Spread lerp speed.
var spread_lerp_speed: float = 12.0

## Target spread value.
var _target_spread: float = 0.0

# ── Hit Marker State ─────────────────────────────────────────────────────────

## Active hit markers.
var _hit_markers: Array[Dictionary] = []

## Hit confirmation animation settings.
const HIT_MARKER_DURATION: float = 0.2
const HEADSHOT_DURATION: float = 0.3
const KILL_DURATION: float = 0.4

# ── Animation State ──────────────────────────────────────────────────────────

## Current spread (animated).
var _current_spread: float = 0.0

## Crosshair pulse for firing.
var _fire_pulse: float = 0.0

## ADS (aim down sights) transition.
var _ads_transition: float = 0.0

## Movement spread multiplier.
var _movement_spread: float = 0.0

## Firing spread addition.
var _firing_spread: float = 0.0

## Custom crosshair configuration.
var _custom_config: Dictionary = {}

## Cached center position.
var _center: Vector2 = Vector2.ZERO

## Per-weapon style overrides.
var _weapon_configs: Dictionary = {}

# ── Color Palette ────────────────────────────────────────────────────────────

## Hit marker colors.
const HIT_COLOR_NORMAL: Color = Color(1.0, 1.0, 1.0, 1.0)
const HIT_COLOR_HEADSHOT: Color = Color(1.0, 0.85, 0.15, 1.0)
const HIT_COLOR_CRITICAL: Color = Color(1.0, 0.5, 0.15, 1.0)
const HIT_COLOR_KILL: Color = Color(1.0, 0.2, 0.15, 1.0)

## Spread indicator color.
const SPREAD_INDICATOR_COLOR: Color = Color(1.0, 1.0, 1.0, 0.3)

## ADS crosshair color (typically more subtle).
const ADS_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)

## Firing pulse color.
const FIRE_PULSE_COLOR: Color = Color(1.0, 0.8, 0.6, 0.4)

# ── Timing Constants ─────────────────────────────────────────────────────────

const FIRE_PULSE_DECAY: float = 10.0
const SPREAD_RECOVERY_SPEED: float = 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_setup_default_weapon_configs()


func _process(delta: float) -> void:
	var needs_redraw: bool = false

	# Smooth spread transitions.
	var target: float = _target_spread + _movement_spread + _firing_spread
	target = clampf(target, 0.0, 1.0)

	if absf(_current_spread - target) > 0.001:
		_current_spread = lerpf(_current_spread, target, spread_lerp_speed * delta)
		needs_redraw = true

	spread = _current_spread

	# Decay firing spread.
	if _firing_spread > 0.0:
		_firing_spread = maxf(_firing_spread - SPREAD_RECOVERY_SPEED * delta, 0.0)
		needs_redraw = true

	# Decay fire pulse.
	if _fire_pulse > 0.0:
		_fire_pulse = maxf(_fire_pulse - FIRE_PULSE_DECAY * delta, 0.0)
		needs_redraw = true

	# Update hit markers.
	var i: int = _hit_markers.size() - 1
	while i >= 0:
		var marker: Dictionary = _hit_markers[i]
		marker["time"] = (marker["time"] as float) - delta
		if marker["time"] <= 0.0:
			_hit_markers.remove_at(i)
		i -= 1
		needs_redraw = true

	if needs_redraw or not _hit_markers.is_empty():
		queue_redraw()


func _draw() -> void:
	_center = size * 0.5

	# Calculate effective sizes based on ADS transition.
	var effective_gap: float = lerpf(center_gap, center_gap * 0.5, _ads_transition)
	var effective_size: float = lerpf(base_size, base_size * 0.7, _ads_transition)
	var effective_thickness: float = lerpf(line_thickness, line_thickness * 0.8, _ads_transition)
	var effective_dot_size: float = lerpf(dot_size, dot_size * 0.8, _ads_transition)

	# Calculate spread offset.
	var spread_offset: float = _current_spread * max_spread

	# Draw spread indicator circle (background).
	if _current_spread > 0.1:
		_draw_spread_indicator(effective_gap + spread_offset + effective_size)

	# Draw crosshair based on style.
	match style:
		Style.DOT:
			_draw_dot_style(effective_dot_size)
		Style.CROSS:
			_draw_cross_style(effective_gap, effective_size, effective_thickness, spread_offset)
		Style.CIRCLE:
			_draw_circle_style(effective_gap, effective_size, effective_thickness)
		Style.CIRCLE_DOT:
			_draw_circle_dot_style(effective_gap, effective_dot_size, effective_thickness)
		Style.CHEVRON:
			_draw_chevron_style(effective_gap, effective_size, effective_thickness, spread_offset)
		Style.DYNAMIC:
			_draw_dynamic_style(effective_gap, effective_size, effective_thickness, spread_offset)
		Style.DYNAMIC_CIRCLE:
			_draw_dynamic_circle_style(effective_gap, effective_size, effective_thickness, spread_offset)
		Style.T_SHAPE:
			_draw_t_shape_style(effective_gap, effective_size, effective_thickness, spread_offset)
		Style.CUSTOM:
			_draw_custom_style(effective_gap, effective_size, effective_thickness, spread_offset)

	# Draw fire pulse effect.
	if _fire_pulse > 0.0:
		_draw_fire_pulse(effective_gap + spread_offset)

	# Draw hit markers on top.
	for marker: Dictionary in _hit_markers:
		_draw_hit_marker(marker)


## Draw simple dot crosshair.
func _draw_dot_style(dot_sz: float) -> void:
	var size_with_pulse: float = dot_sz + _fire_pulse * 2.0

	# Outline.
	draw_circle(_center, size_with_pulse + outline_thickness, outline_color)
	# Main dot.
	draw_circle(_center, size_with_pulse, crosshair_color)


## Draw classic cross crosshair.
func _draw_cross_style(gap: float, length: float, thickness: float, spread_offset: float) -> void:
	var effective_gap: float = gap + spread_offset

	# Four lines.
	_draw_line_with_outline(_center + Vector2(0, -effective_gap), _center + Vector2(0, -effective_gap - length), thickness)
	_draw_line_with_outline(_center + Vector2(0, effective_gap), _center + Vector2(0, effective_gap + length), thickness)
	_draw_line_with_outline(_center + Vector2(-effective_gap, 0), _center + Vector2(-effective_gap - length, 0), thickness)
	_draw_line_with_outline(_center + Vector2(effective_gap, 0), _center + Vector2(effective_gap + length, 0), thickness)

	# Center dot.
	if show_center_dot:
		draw_circle(_center, dot_size + outline_thickness, outline_color)
		draw_circle(_center, dot_size, crosshair_color)


## Draw circle crosshair.
func _draw_circle_style(gap: float, length: float, thickness: float) -> void:
	var radius: float = gap + length + _current_spread * max_spread * 0.5

	# Outline.
	draw_arc(_center, radius + outline_thickness, 0.0, TAU, 48, outline_color, thickness + outline_thickness * 2)
	# Main circle.
	draw_arc(_center, radius, 0.0, TAU, 48, crosshair_color, thickness)

	# Center dot.
	if show_center_dot:
		draw_circle(_center, dot_size + outline_thickness, outline_color)
		draw_circle(_center, dot_size, crosshair_color)


## Draw circle with larger center dot.
func _draw_circle_dot_style(gap: float, dot_sz: float, thickness: float) -> void:
	var radius: float = gap + _current_spread * max_spread * 0.3

	# Circle outline.
	draw_arc(_center, radius + outline_thickness, 0.0, TAU, 48, outline_color, thickness + outline_thickness * 2)
	# Circle.
	draw_arc(_center, radius, 0.0, TAU, 48, crosshair_color, thickness)

	# Larger center dot.
	draw_circle(_center, dot_sz * 1.5 + outline_thickness, outline_color)
	draw_circle(_center, dot_sz * 1.5, crosshair_color)


## Draw chevron crosshair.
func _draw_chevron_style(gap: float, length: float, thickness: float, spread_offset: float) -> void:
	var effective_gap: float = gap + spread_offset

	# Top chevron (V pointing down).
	var top_center: Vector2 = _center + Vector2(0, -effective_gap)
	_draw_line_with_outline(top_center, top_center + Vector2(-length * 0.7, -length * 0.7), thickness)
	_draw_line_with_outline(top_center, top_center + Vector2(length * 0.7, -length * 0.7), thickness)

	# Bottom chevron (V pointing up).
	var bottom_center: Vector2 = _center + Vector2(0, effective_gap)
	_draw_line_with_outline(bottom_center, bottom_center + Vector2(-length * 0.7, length * 0.7), thickness)
	_draw_line_with_outline(bottom_center, bottom_center + Vector2(length * 0.7, length * 0.7), thickness)

	# Center dot.
	if show_center_dot:
		draw_circle(_center, dot_size + outline_thickness, outline_color)
		draw_circle(_center, dot_size, crosshair_color)


## Draw dynamic crosshair with spread visualization.
func _draw_dynamic_style(gap: float, length: float, thickness: float, spread_offset: float) -> void:
	var effective_gap: float = gap + spread_offset

	# Four lines with dynamic gap.
	_draw_line_with_outline(_center + Vector2(0, -effective_gap), _center + Vector2(0, -effective_gap - length), thickness)
	_draw_line_with_outline(_center + Vector2(0, effective_gap), _center + Vector2(0, effective_gap + length), thickness)
	_draw_line_with_outline(_center + Vector2(-effective_gap, 0), _center + Vector2(-effective_gap - length, 0), thickness)
	_draw_line_with_outline(_center + Vector2(effective_gap, 0), _center + Vector2(effective_gap + length, 0), thickness)

	# Center dot.
	if show_center_dot:
		draw_circle(_center, dot_size + outline_thickness, outline_color)
		draw_circle(_center, dot_size, crosshair_color)


## Draw dynamic crosshair with circle.
func _draw_dynamic_circle_style(gap: float, length: float, thickness: float, spread_offset: float) -> void:
	var effective_gap: float = gap + spread_offset

	# Circle.
	var circle_rad: float = effective_gap + length * 0.3
	draw_arc(_center, circle_rad + outline_thickness * 0.5, 0.0, TAU, 48, outline_color, 1.5)
	draw_arc(_center, circle_rad, 0.0, TAU, 48, crosshair_color, 1.0)

	# Four lines outside circle.
	var line_start: float = circle_rad + 3
	_draw_line_with_outline(_center + Vector2(0, -line_start), _center + Vector2(0, -line_start - length * 0.6), thickness)
	_draw_line_with_outline(_center + Vector2(0, line_start), _center + Vector2(0, line_start + length * 0.6), thickness)
	_draw_line_with_outline(_center + Vector2(-line_start, 0), _center + Vector2(-line_start - length * 0.6, 0), thickness)
	_draw_line_with_outline(_center + Vector2(line_start, 0), _center + Vector2(line_start + length * 0.6, 0), thickness)

	# Center dot.
	if show_center_dot:
		draw_circle(_center, dot_size + outline_thickness, outline_color)
		draw_circle(_center, dot_size, crosshair_color)


## Draw T-shape crosshair.
func _draw_t_shape_style(gap: float, length: float, thickness: float, spread_offset: float) -> void:
	var effective_gap: float = gap + spread_offset

	# Top line (longer).
	_draw_line_with_outline(_center + Vector2(0, -effective_gap), _center + Vector2(0, -effective_gap - length * 1.5), thickness)

	# Left and right lines.
	_draw_line_with_outline(_center + Vector2(-effective_gap, 0), _center + Vector2(-effective_gap - length, 0), thickness)
	_draw_line_with_outline(_center + Vector2(effective_gap, 0), _center + Vector2(effective_gap + length, 0), thickness)

	# Center dot.
	if show_center_dot:
		draw_circle(_center, dot_size + outline_thickness, outline_color)
		draw_circle(_center, dot_size, crosshair_color)


## Draw custom configured crosshair.
func _draw_custom_style(gap: float, length: float, thickness: float, spread_offset: float) -> void:
	var effective_gap: float = gap + spread_offset

	# Draw configured elements.
	if _custom_config.get("show_top", true) as bool:
		_draw_line_with_outline(_center + Vector2(0, -effective_gap), _center + Vector2(0, -effective_gap - length), thickness)

	if _custom_config.get("show_bottom", true) as bool:
		_draw_line_with_outline(_center + Vector2(0, effective_gap), _center + Vector2(0, effective_gap + length), thickness)

	if _custom_config.get("show_left", true) as bool:
		_draw_line_with_outline(_center + Vector2(-effective_gap, 0), _center + Vector2(-effective_gap - length, 0), thickness)

	if _custom_config.get("show_right", true) as bool:
		_draw_line_with_outline(_center + Vector2(effective_gap, 0), _center + Vector2(effective_gap + length, 0), thickness)

	if _custom_config.get("show_circle", false) as bool:
		var circle_rad: float = _custom_config.get("circle_radius", 15.0) as float + spread_offset
		draw_arc(_center, circle_rad, 0.0, TAU, 48, crosshair_color, 1.0)

	if show_center_dot:
		draw_circle(_center, dot_size + outline_thickness, outline_color)
		draw_circle(_center, dot_size, crosshair_color)


## Draw spread indicator circle.
func _draw_spread_indicator(radius: float) -> void:
	var color: Color = SPREAD_INDICATOR_COLOR
	color.a *= _current_spread

	# Dashed circle effect.
	var segments: int = 16
	var segment_arc: float = TAU / float(segments) * 0.6

	for i: int in range(segments):
		var start_angle: float = float(i) * (TAU / float(segments))
		draw_arc(_center, radius, start_angle, start_angle + segment_arc, 8, color, 1.0)


## Draw fire pulse effect.
func _draw_fire_pulse(gap: float) -> void:
	var pulse_color: Color = FIRE_PULSE_COLOR
	pulse_color.a *= _fire_pulse

	var pulse_size: float = gap + 5.0 + (1.0 - _fire_pulse) * 8.0

	# Expanding ring.
	draw_arc(_center, pulse_size, 0.0, TAU, 32, pulse_color, 2.0)


## Draw line with outline.
func _draw_line_with_outline(from: Vector2, to: Vector2, thickness: float) -> void:
	# Outline.
	if outline_thickness > 0.0:
		draw_line(from, to, outline_color, thickness + outline_thickness * 2)
	# Main line.
	draw_line(from, to, crosshair_color, thickness)


## Draw hit marker.
func _draw_hit_marker(marker: Dictionary) -> void:
	var hit_type: HitType = marker.get("type", HitType.NORMAL) as HitType
	var time: float = marker["time"] as float
	var duration: float = marker.get("duration", HIT_MARKER_DURATION) as float
	var progress: float = 1.0 - (time / duration)

	# Animation values.
	var alpha: float = 1.0 - progress
	var scale: float = 1.0 + progress * 0.6
	var rotation: float = marker.get("rotation", 0.0) as float

	# Get color based on type.
	var color: Color = _get_hit_color(hit_type)
	color.a = alpha

	# Calculate marker dimensions.
	var marker_gap: float = center_gap * 0.8 * scale
	var marker_length: float = base_size * 0.8 * scale
	var marker_thickness: float = line_thickness * 1.2

	# Draw X-shaped marker.
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

		var start: Vector2 = _center + rotated_dir * marker_gap
		var end: Vector2 = _center + rotated_dir * (marker_gap + marker_length)

		# Outline.
		var outline_col: Color = Color(0, 0, 0, color.a * 0.6)
		draw_line(start, end, outline_col, marker_thickness + 2.0)
		# Main line.
		draw_line(start, end, color, marker_thickness)

	# Draw kill confirmation ring.
	if hit_type == HitType.KILL:
		var ring_radius: float = (marker_gap + marker_length) * 1.3
		var ring_color: Color = color
		ring_color.a *= 0.5
		draw_arc(_center, ring_radius, 0.0, TAU, 24, ring_color, 2.0)

	# Draw headshot crown effect.
	if hit_type == HitType.HEADSHOT:
		var crown_y: float = -marker_gap - marker_length - 5.0
		var crown_color: Color = color
		crown_color.a *= 0.8
		# Simple crown shape.
		var crown_points: PackedVector2Array = PackedVector2Array([
			_center + Vector2(-8, crown_y),
			_center + Vector2(-4, crown_y - 6),
			_center + Vector2(0, crown_y - 2),
			_center + Vector2(4, crown_y - 6),
			_center + Vector2(8, crown_y),
		])
		draw_polyline(crown_points, crown_color, 2.0)


## Get hit marker color.
func _get_hit_color(hit_type: HitType) -> Color:
	match hit_type:
		HitType.NORMAL:
			return HIT_COLOR_NORMAL
		HitType.HEADSHOT:
			return HIT_COLOR_HEADSHOT
		HitType.CRITICAL:
			return HIT_COLOR_CRITICAL
		HitType.KILL:
			return HIT_COLOR_KILL
		_:
			return HIT_COLOR_NORMAL


## Setup default weapon configurations.
func _setup_default_weapon_configs() -> void:
	_weapon_configs = {
		"pistol": {
			"style": Style.DYNAMIC,
			"base_size": 8.0,
			"center_gap": 4.0,
			"show_center_dot": true,
			"max_spread": 20.0,
		},
		"rifle": {
			"style": Style.DYNAMIC,
			"base_size": 10.0,
			"center_gap": 5.0,
			"show_center_dot": true,
			"max_spread": 25.0,
		},
		"smg": {
			"style": Style.DYNAMIC,
			"base_size": 10.0,
			"center_gap": 6.0,
			"show_center_dot": true,
			"max_spread": 30.0,
		},
		"sniper": {
			"style": Style.CROSS,
			"base_size": 14.0,
			"center_gap": 8.0,
			"show_center_dot": true,
			"max_spread": 10.0,
		},
		"shotgun": {
			"style": Style.CIRCLE,
			"base_size": 18.0,
			"center_gap": 12.0,
			"show_center_dot": false,
			"max_spread": 35.0,
		},
		"rocket": {
			"style": Style.CHEVRON,
			"base_size": 12.0,
			"center_gap": 10.0,
			"show_center_dot": true,
			"max_spread": 15.0,
		},
	}


# ── Public API ───────────────────────────────────────────────────────────────

## Show hit marker feedback.
func show_hit_marker(hit_type: HitType = HitType.NORMAL) -> void:
	var duration: float = HIT_MARKER_DURATION
	match hit_type:
		HitType.HEADSHOT:
			duration = HEADSHOT_DURATION
		HitType.KILL:
			duration = KILL_DURATION

	_hit_markers.append({
		"type": hit_type,
		"time": duration,
		"duration": duration,
		"rotation": randf() * 0.15 - 0.075,
	})

	queue_redraw()


## Trigger fire effect (increases spread and shows pulse).
func on_fire(spread_increase: float = 0.1) -> void:
	_firing_spread = minf(_firing_spread + spread_increase, 0.5)
	_fire_pulse = 0.8
	queue_redraw()


## Set the base spread amount (0.0 = accurate, 1.0 = maximum).
func set_spread(amount: float) -> void:
	_target_spread = clampf(amount, 0.0, 1.0)


## Set movement-based spread.
func set_movement_spread(amount: float) -> void:
	_movement_spread = clampf(amount, 0.0, 0.5)


## Instantly set spread without animation.
func set_spread_instant(amount: float) -> void:
	_target_spread = clampf(amount, 0.0, 1.0)
	_current_spread = _target_spread


## Set ADS (aim down sights) transition.
func set_ads_transition(amount: float) -> void:
	_ads_transition = clampf(amount, 0.0, 1.0)


## Set crosshair style.
func set_style(new_style: Style) -> void:
	style = new_style
	queue_redraw()


## Configure crosshair for a specific weapon type.
func configure_for_weapon(weapon_type: String) -> void:
	var config: Dictionary = _weapon_configs.get(weapon_type, {})

	if config.is_empty():
		# Default configuration.
		style = Style.DYNAMIC
		base_size = 10.0
		center_gap = 5.0
		show_center_dot = true
		max_spread = 25.0
	else:
		if config.has("style"):
			style = config["style"] as Style
		if config.has("base_size"):
			base_size = config["base_size"] as float
		if config.has("center_gap"):
			center_gap = config["center_gap"] as float
		if config.has("show_center_dot"):
			show_center_dot = config["show_center_dot"] as bool
		if config.has("max_spread"):
			max_spread = config["max_spread"] as float

	queue_redraw()


## Set custom crosshair configuration.
func set_custom_config(config: Dictionary) -> void:
	_custom_config = config
	style = Style.CUSTOM
	queue_redraw()


## Set crosshair color.
func set_color(color: Color) -> void:
	crosshair_color = color
	queue_redraw()


## Set crosshair visibility.
func set_crosshair_visible(is_visible: bool) -> void:
	visible = is_visible


## Reset to default state.
func reset() -> void:
	_target_spread = 0.0
	_current_spread = 0.0
	_movement_spread = 0.0
	_firing_spread = 0.0
	_fire_pulse = 0.0
	_ads_transition = 0.0
	_hit_markers.clear()
	queue_redraw()
