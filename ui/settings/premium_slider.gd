## PremiumSlider - AAA-quality slider with glow effects, value tooltip, and smooth animations.
##
## Features:
## - Glowing thumb that pulses on hover
## - Value tooltip that follows the thumb smoothly
## - Gradient fill color
## - Tick marks for key values
## - Smooth value interpolation
## - Sound feedback on value change
## - Spring physics for satisfying feel
class_name PremiumSlider
extends Control

# ============================================================================ #
#                                   SIGNALS                                     #
# ============================================================================ #

## Emitted when value changes.
signal value_changed_signal(new_value: float)

## Emitted when user starts dragging.
signal drag_started

## Emitted when user stops dragging.
signal drag_ended

# ============================================================================ #
#                                  CONSTANTS                                    #
# ============================================================================ #

const TRACK_HEIGHT: float = 6.0
const THUMB_RADIUS: float = 12.0
const THUMB_GLOW_RADIUS: float = 20.0
const TICK_HEIGHT: float = 12.0
const TICK_WIDTH: float = 2.0
const TOOLTIP_OFFSET: float = 35.0
const TOOLTIP_LERP_SPEED: float = 15.0
const VALUE_LERP_SPEED: float = 12.0
const SPRING_STIFFNESS: float = 200.0
const SPRING_DAMPING: float = 15.0

const COLORS := {
	"track_bg": Color(0.15, 0.15, 0.18, 1.0),
	"track_fill_start": Color(0.2, 0.6, 1.0, 1.0),
	"track_fill_end": Color(0.4, 0.8, 1.0, 1.0),
	"thumb": Color(1.0, 1.0, 1.0, 1.0),
	"thumb_glow": Color(0.3, 0.7, 1.0, 0.6),
	"thumb_hover_glow": Color(0.4, 0.8, 1.0, 0.8),
	"tick": Color(0.4, 0.4, 0.45, 1.0),
	"tick_active": Color(0.6, 0.8, 1.0, 1.0),
	"tooltip_bg": Color(0.1, 0.1, 0.12, 0.95),
	"tooltip_text": Color(1.0, 1.0, 1.0, 1.0),
}

# ============================================================================ #
#                                  EXPORTS                                      #
# ============================================================================ #

## Setting key for change tracking.
@export var setting_key: String = ""

## Minimum value.
@export var min_value: float = 0.0

## Maximum value.
@export var max_value: float = 1.0

## Current value.
@export var value: float = 0.5:
	set(v):
		var clamped := clampf(v, min_value, max_value)
		if value != clamped:
			value = clamped
			target_value = value
			_update_display()
			value_changed_signal.emit(value)

## Step for snapping (0 = continuous).
@export var step: float = 0.0

## Values to show tick marks at.
@export var tick_values: Array = []

## Format string for tooltip display.
@export var value_format: String = "%.2f"

## Show percentage instead of raw value.
@export var show_percentage: bool = false

## Enable sound effects.
@export var enable_sounds: bool = true

## Custom fill gradient.
@export var custom_gradient: Gradient = null

# ============================================================================ #
#                                   STATE                                       #
# ============================================================================ #

## Whether the slider is being dragged.
var is_dragging: bool = false

## Whether mouse is hovering.
var is_hovering: bool = false

## Smooth interpolated display value.
var display_value: float = 0.5

## Target value for smooth interpolation.
var target_value: float = 0.5

## Tooltip position (smoothly interpolated).
var tooltip_position: Vector2 = Vector2.ZERO

## Thumb glow intensity (animated).
var glow_intensity: float = 0.0

## Spring velocity for thumb.
var thumb_velocity: float = 0.0

## Previous value for change detection.
var previous_value: float = 0.0

## Time since last tick sound.
var tick_sound_cooldown: float = 0.0

# ============================================================================ #
#                                   NODES                                       #
# ============================================================================ #

var track_rect: Rect2
var thumb_position: Vector2

# ============================================================================ #
#                                 LIFECYCLE                                     #
# ============================================================================ #

func _ready() -> void:
	custom_minimum_size = Vector2(200, 50)
	display_value = value
	target_value = value
	previous_value = value
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Enable focus for keyboard control.
	focus_mode = Control.FOCUS_ALL


func _process(delta: float) -> void:
	# Smooth value interpolation.
	if not is_dragging:
		display_value = lerpf(display_value, target_value, VALUE_LERP_SPEED * delta)

	# Update glow intensity.
	var target_glow := 1.0 if (is_dragging or is_hovering) else 0.0
	glow_intensity = lerpf(glow_intensity, target_glow, 8.0 * delta)

	# Spring physics for thumb.
	var thumb_target := _value_to_position(display_value)
	var spring_force := SPRING_STIFFNESS * (thumb_target - thumb_position.x)
	var damping_force := SPRING_DAMPING * thumb_velocity
	thumb_velocity += (spring_force - damping_force) * delta
	thumb_position.x += thumb_velocity * delta

	# Smooth tooltip position.
	var target_tooltip := Vector2(thumb_position.x, track_rect.position.y - TOOLTIP_OFFSET)
	tooltip_position = tooltip_position.lerp(target_tooltip, TOOLTIP_LERP_SPEED * delta)

	# Tick sound cooldown.
	if tick_sound_cooldown > 0:
		tick_sound_cooldown -= delta

	queue_redraw()


func _draw() -> void:
	_calculate_layout()
	_draw_track()
	_draw_fill()
	_draw_ticks()
	_draw_thumb()
	if is_dragging or is_hovering:
		_draw_tooltip()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position)
			else:
				_end_drag()

	elif event is InputEventMouseMotion:
		if is_dragging:
			_update_drag(event.position)
		else:
			_update_hover(event.position)

	elif event is InputEventKey and event.pressed:
		if has_focus():
			match event.keycode:
				KEY_LEFT, KEY_DOWN:
					_adjust_value(-_get_step())
				KEY_RIGHT, KEY_UP:
					_adjust_value(_get_step())
				KEY_HOME:
					value = min_value
				KEY_END:
					value = max_value


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			is_hovering = true
			_play_sound("slider_hover")
		NOTIFICATION_MOUSE_EXIT:
			is_hovering = false
		NOTIFICATION_FOCUS_ENTER:
			is_hovering = true
		NOTIFICATION_FOCUS_EXIT:
			is_hovering = false

# ============================================================================ #
#                                  DRAWING                                      #
# ============================================================================ #

func _calculate_layout() -> void:
	var padding := THUMB_RADIUS + 5.0
	track_rect = Rect2(
		Vector2(padding, size.y / 2 - TRACK_HEIGHT / 2),
		Vector2(size.x - padding * 2, TRACK_HEIGHT)
	)

	# Initialize thumb position if needed.
	if thumb_position == Vector2.ZERO:
		thumb_position = Vector2(_value_to_position(display_value), track_rect.position.y + TRACK_HEIGHT / 2)
	else:
		thumb_position.y = track_rect.position.y + TRACK_HEIGHT / 2


func _draw_track() -> void:
	# Track background.
	var bg_rect := track_rect
	draw_rect(bg_rect, COLORS["track_bg"], true)

	# Rounded corners effect (draw circles at ends).
	var corner_radius := TRACK_HEIGHT / 2
	draw_circle(
		Vector2(track_rect.position.x, track_rect.position.y + corner_radius),
		corner_radius, COLORS["track_bg"]
	)
	draw_circle(
		Vector2(track_rect.end.x, track_rect.position.y + corner_radius),
		corner_radius, COLORS["track_bg"]
	)


func _draw_fill() -> void:
	var fill_width := (display_value - min_value) / (max_value - min_value) * track_rect.size.x
	if fill_width <= 0:
		return

	var fill_rect := Rect2(
		track_rect.position,
		Vector2(fill_width, TRACK_HEIGHT)
	)

	# Gradient fill.
	var gradient_texture := _create_gradient_texture()
	if gradient_texture:
		draw_texture_rect(gradient_texture, fill_rect, false)
	else:
		# Fallback solid color.
		draw_rect(fill_rect, COLORS["track_fill_start"], true)

	# Rounded left corner.
	var corner_radius := TRACK_HEIGHT / 2
	draw_circle(
		Vector2(track_rect.position.x, track_rect.position.y + corner_radius),
		corner_radius, COLORS["track_fill_start"]
	)

	# Rounded right edge (at fill end).
	if fill_width > corner_radius:
		draw_circle(
			Vector2(track_rect.position.x + fill_width, track_rect.position.y + corner_radius),
			corner_radius, _get_fill_color_at(display_value)
		)


func _draw_ticks() -> void:
	for tick_val: float in tick_values:
		if tick_val < min_value or tick_val > max_value:
			continue

		var tick_x := _value_to_position(tick_val)
		var tick_y := track_rect.position.y + TRACK_HEIGHT + 4

		var is_active := tick_val <= display_value
		var tick_color: Color = COLORS["tick_active"] if is_active else COLORS["tick"]

		# Draw tick mark.
		draw_line(
			Vector2(tick_x, tick_y),
			Vector2(tick_x, tick_y + TICK_HEIGHT),
			tick_color, TICK_WIDTH, true
		)

		# Draw tick value label.
		var label_text := _format_value(tick_val)
		var font := ThemeDB.fallback_font
		var font_size := 10
		var label_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

		draw_string(
			font, Vector2(tick_x - label_size.x / 2, tick_y + TICK_HEIGHT + 12),
			label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size,
			tick_color.darkened(0.2)
		)


func _draw_thumb() -> void:
	# Outer glow.
	if glow_intensity > 0:
		var glow_color: Color = COLORS["thumb_hover_glow"] if is_dragging else COLORS["thumb_glow"]
		glow_color.a *= glow_intensity

		# Draw multiple layers for soft glow.
		for i: int in range(4, 0, -1):
			var glow_radius := THUMB_RADIUS + THUMB_GLOW_RADIUS * (float(i) / 4.0) * glow_intensity
			var layer_alpha := glow_color.a * (1.0 - float(i) / 5.0)
			draw_circle(thumb_position, glow_radius, Color(glow_color, layer_alpha))

	# Main thumb circle.
	draw_circle(thumb_position, THUMB_RADIUS, COLORS["thumb"])

	# Inner highlight.
	var highlight_offset := Vector2(-2, -2)
	draw_circle(thumb_position + highlight_offset, THUMB_RADIUS * 0.3, Color(1, 1, 1, 0.4))

	# Border.
	draw_arc(thumb_position, THUMB_RADIUS, 0, TAU, 32, COLORS["track_fill_start"].lightened(0.2), 2.0, true)


func _draw_tooltip() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 12
	var text := _format_value(display_value)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

	var padding := Vector2(12, 8)
	var tooltip_size := text_size + padding * 2
	var tooltip_rect := Rect2(
		tooltip_position - Vector2(tooltip_size.x / 2, tooltip_size.y),
		tooltip_size
	)

	# Background with rounded corners.
	var bg_color: Color = COLORS["tooltip_bg"]
	bg_color.a *= (0.5 + glow_intensity * 0.5)

	# Draw tooltip background.
	_draw_rounded_rect(tooltip_rect, 6.0, bg_color)

	# Draw pointer triangle.
	var triangle_size := 8.0
	var triangle_points := PackedVector2Array([
		Vector2(tooltip_position.x - triangle_size / 2, tooltip_rect.end.y),
		Vector2(tooltip_position.x + triangle_size / 2, tooltip_rect.end.y),
		Vector2(tooltip_position.x, tooltip_rect.end.y + triangle_size / 2)
	])
	draw_colored_polygon(triangle_points, bg_color)

	# Draw text.
	var text_pos := Vector2(
		tooltip_rect.position.x + padding.x,
		tooltip_rect.position.y + padding.y + text_size.y * 0.8
	)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLORS["tooltip_text"])


func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	# Simple rounded rectangle using draw_rect and circles.
	draw_rect(
		Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2, rect.size.y),
		color
	)
	draw_rect(
		Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius * 2),
		color
	)

	# Corners.
	draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.end.y - radius), radius, color)

# ============================================================================ #
#                                INTERACTION                                    #
# ============================================================================ #

func _start_drag(pos: Vector2) -> void:
	is_dragging = true
	grab_focus()
	_update_value_from_position(pos.x)
	drag_started.emit()
	_play_sound("slider_grab")


func _end_drag() -> void:
	is_dragging = false
	drag_ended.emit()
	_play_sound("slider_release")


func _update_drag(pos: Vector2) -> void:
	_update_value_from_position(pos.x)


func _update_hover(pos: Vector2) -> void:
	var distance := pos.distance_to(thumb_position)
	is_hovering = distance < THUMB_RADIUS * 2


func _update_value_from_position(x: float) -> void:
	var normalized := (x - track_rect.position.x) / track_rect.size.x
	normalized = clampf(normalized, 0.0, 1.0)

	var new_value := min_value + normalized * (max_value - min_value)

	# Apply step snapping.
	if step > 0:
		new_value = roundf(new_value / step) * step

	# Snap to tick values if close.
	for tick_val: float in tick_values:
		var tick_norm := (tick_val - min_value) / (max_value - min_value)
		if abs(normalized - tick_norm) < 0.03:
			new_value = tick_val
			break

	if new_value != value:
		# Check if we crossed a tick mark for sound.
		_check_tick_crossing(value, new_value)

		value = new_value
		display_value = value
		_update_display()


func _check_tick_crossing(old_val: float, new_val: float) -> void:
	if tick_sound_cooldown > 0:
		return

	for tick_val: float in tick_values:
		if (old_val < tick_val and new_val >= tick_val) or (old_val > tick_val and new_val <= tick_val):
			_play_sound("slider_tick")
			tick_sound_cooldown = 0.05
			return

	# Play subtle tick for value changes.
	if abs(new_val - previous_value) > (max_value - min_value) * 0.05:
		_play_sound("slider_move")
		previous_value = new_val


func _adjust_value(amount: float) -> void:
	value = clampf(value + amount, min_value, max_value)
	_play_sound("slider_tick")

# ============================================================================ #
#                                  HELPERS                                      #
# ============================================================================ #

func _value_to_position(val: float) -> float:
	var normalized := (val - min_value) / (max_value - min_value)
	return track_rect.position.x + normalized * track_rect.size.x


func _get_step() -> float:
	if step > 0:
		return step
	return (max_value - min_value) * 0.05


func _format_value(val: float) -> String:
	if show_percentage:
		var percent := (val - min_value) / (max_value - min_value) * 100
		return "%d%%" % roundi(percent)
	return value_format % val


func _get_fill_color_at(val: float) -> Color:
	var t := (val - min_value) / (max_value - min_value)
	return COLORS["track_fill_start"].lerp(COLORS["track_fill_end"], t)


func _create_gradient_texture() -> GradientTexture2D:
	if custom_gradient:
		var tex := GradientTexture2D.new()
		tex.gradient = custom_gradient
		tex.width = int(track_rect.size.x)
		tex.height = int(TRACK_HEIGHT)
		return tex

	var gradient := Gradient.new()
	gradient.set_color(0, COLORS["track_fill_start"])
	gradient.add_point(1.0, COLORS["track_fill_end"])

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = int(track_rect.size.x)
	tex.height = int(TRACK_HEIGHT)
	return tex


func _update_display() -> void:
	# Force redraw.
	queue_redraw()


func _play_sound(sound_name: String) -> void:
	if not enable_sounds:
		return

	if Engine.has_singleton("AudioManager"):
		var audio_manager := Engine.get_singleton("AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx("ui_%s" % sound_name)

# ============================================================================ #
#                                PUBLIC API                                     #
# ============================================================================ #

## Set value with optional animation.
func set_value_animated(new_value: float, duration: float = 0.3) -> void:
	target_value = clampf(new_value, min_value, max_value)

	var tween := create_tween()
	tween.tween_property(self, "value", target_value, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Reset to default value.
func reset_to_default(default: float) -> void:
	set_value_animated(default)


## Set tick values.
func set_tick_values(ticks: Array) -> void:
	tick_values = ticks
	queue_redraw()


## Get normalized value (0-1).
func get_normalized_value() -> float:
	return (value - min_value) / (max_value - min_value)


## Set from normalized value (0-1).
func set_normalized_value(normalized: float) -> void:
	value = min_value + normalized * (max_value - min_value)
