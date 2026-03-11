## AnimatedToggle - Premium toggle switch with physical animation and satisfying feedback.
##
## Features:
## - Physical switch animation with slide + flip
## - Green glow on state
## - Gray with subtle pulse off state
## - Satisfying click sound
## - Spring animation on toggle
## - Smooth state transitions
class_name AnimatedToggle
extends Control

# ============================================================================ #
#                                   SIGNALS                                     #
# ============================================================================ #

## Emitted when toggle state changes.
signal toggled_signal(enabled: bool)

## Emitted when animation completes.
signal animation_completed

# ============================================================================ #
#                                  CONSTANTS                                    #
# ============================================================================ #

const TRACK_WIDTH: float = 52.0
const TRACK_HEIGHT: float = 28.0
const THUMB_SIZE: float = 22.0
const THUMB_MARGIN: float = 3.0
const SPRING_STIFFNESS: float = 300.0
const SPRING_DAMPING: float = 20.0
const GLOW_PULSE_SPEED: float = 2.0
const FLIP_DURATION: float = 0.15

const COLORS := {
	# Off state.
	"track_off": Color(0.25, 0.25, 0.28, 1.0),
	"track_off_border": Color(0.35, 0.35, 0.38, 1.0),
	"thumb_off": Color(0.6, 0.6, 0.65, 1.0),
	"thumb_off_shadow": Color(0.2, 0.2, 0.22, 0.5),

	# On state.
	"track_on": Color(0.15, 0.55, 0.3, 1.0),
	"track_on_border": Color(0.2, 0.7, 0.4, 1.0),
	"thumb_on": Color(1.0, 1.0, 1.0, 1.0),
	"thumb_on_glow": Color(0.3, 0.9, 0.5, 0.6),

	# Hover state.
	"hover_glow": Color(0.5, 0.8, 1.0, 0.3),

	# Disabled state.
	"disabled": Color(0.3, 0.3, 0.32, 1.0),
	"disabled_thumb": Color(0.4, 0.4, 0.42, 1.0),
}

# ============================================================================ #
#                                  EXPORTS                                      #
# ============================================================================ #

## Setting key for change tracking.
@export var setting_key: String = ""

## Whether the toggle is on.
@export var toggled_on: bool = false:
	set(v):
		if toggled_on != v:
			toggled_on = v
			_start_toggle_animation()
			toggled_signal.emit(toggled_on)

## Whether the toggle is disabled.
@export var disabled: bool = false

## Enable sound effects.
@export var enable_sounds: bool = true

## Enable haptic feedback.
@export var enable_haptics: bool = true

# ============================================================================ #
#                                   STATE                                       #
# ============================================================================ #

## Current thumb position (0 = left/off, 1 = right/on).
var thumb_progress: float = 0.0

## Target thumb position.
var thumb_target: float = 0.0

## Spring velocity for thumb.
var thumb_velocity: float = 0.0

## Whether mouse is hovering.
var is_hovering: bool = false

## Whether mouse is pressed.
var is_pressed: bool = false

## Glow pulse phase.
var glow_phase: float = 0.0

## Flip animation progress (0 = normal, 1 = flipped).
var flip_progress: float = 0.0

## Track color transition.
var track_color_progress: float = 0.0

## Off-state pulse animation.
var off_pulse_phase: float = 0.0

# ============================================================================ #
#                                 LIFECYCLE                                     #
# ============================================================================ #

func _ready() -> void:
	custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

	# Initialize state.
	thumb_progress = 1.0 if toggled_on else 0.0
	thumb_target = thumb_progress
	track_color_progress = thumb_progress


func _process(delta: float) -> void:
	# Spring physics for thumb.
	var spring_force := SPRING_STIFFNESS * (thumb_target - thumb_progress)
	var damping_force := SPRING_DAMPING * thumb_velocity
	thumb_velocity += (spring_force - damping_force) * delta
	thumb_progress += thumb_velocity * delta

	# Clamp and detect animation completion.
	thumb_progress = clampf(thumb_progress, 0.0, 1.0)
	if abs(thumb_progress - thumb_target) < 0.001 and abs(thumb_velocity) < 0.1:
		thumb_progress = thumb_target
		thumb_velocity = 0.0

	# Track color transition.
	track_color_progress = lerpf(track_color_progress, thumb_target, 10.0 * delta)

	# Glow pulse animation.
	glow_phase += delta * GLOW_PULSE_SPEED
	if glow_phase > TAU:
		glow_phase -= TAU

	# Off-state subtle pulse.
	off_pulse_phase += delta * 1.5
	if off_pulse_phase > TAU:
		off_pulse_phase -= TAU

	# Flip animation decay.
	flip_progress = lerpf(flip_progress, 0.0, 8.0 * delta)

	queue_redraw()


func _draw() -> void:
	_draw_track()
	_draw_thumb()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_pressed = true
				_play_sound("toggle_press")
			else:
				if is_pressed:
					is_pressed = false
					_toggle()
					get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed:
		if has_focus():
			match event.keycode:
				KEY_SPACE, KEY_ENTER:
					_toggle()
					get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			is_hovering = true
		NOTIFICATION_MOUSE_EXIT:
			is_hovering = false
			is_pressed = false
		NOTIFICATION_FOCUS_ENTER:
			is_hovering = true
		NOTIFICATION_FOCUS_EXIT:
			is_hovering = false

# ============================================================================ #
#                                  DRAWING                                      #
# ============================================================================ #

func _draw_track() -> void:
	var track_rect := Rect2(Vector2.ZERO, Vector2(TRACK_WIDTH, TRACK_HEIGHT))
	var corner_radius := TRACK_HEIGHT / 2

	# Determine colors based on state.
	var track_color: Color
	var border_color: Color

	if disabled:
		track_color = COLORS["disabled"]
		border_color = COLORS["disabled"]
	else:
		track_color = COLORS["track_off"].lerp(COLORS["track_on"], track_color_progress)
		border_color = COLORS["track_off_border"].lerp(COLORS["track_on_border"], track_color_progress)

		# Off-state subtle pulse.
		if track_color_progress < 0.5:
			var pulse := (sin(off_pulse_phase) + 1.0) * 0.5 * 0.1
			track_color = track_color.lightened(pulse)

	# Draw track background.
	_draw_rounded_rect(track_rect, corner_radius, track_color)

	# Draw border.
	_draw_rounded_rect_outline(track_rect, corner_radius, border_color, 1.5)

	# Hover glow.
	if is_hovering and not disabled:
		var glow_color: Color = COLORS["hover_glow"]
		glow_color.a *= 0.3 + 0.2 * sin(glow_phase)
		for i: int in range(3, 0, -1):
			var glow_rect := track_rect.grow(float(i) * 2)
			_draw_rounded_rect(glow_rect, corner_radius + float(i) * 2, Color(glow_color, glow_color.a * (1.0 - float(i) / 4.0)))


func _draw_thumb() -> void:
	# Calculate thumb position.
	var travel_distance := TRACK_WIDTH - THUMB_SIZE - THUMB_MARGIN * 2
	var thumb_x := THUMB_MARGIN + thumb_progress * travel_distance + THUMB_SIZE / 2
	var thumb_y := TRACK_HEIGHT / 2
	var thumb_pos := Vector2(thumb_x, thumb_y)

	# Apply flip effect (scale).
	var flip_scale := 1.0 - flip_progress * 0.3
	var effective_radius := THUMB_SIZE / 2 * flip_scale

	# Determine thumb color.
	var thumb_color: Color
	if disabled:
		thumb_color = COLORS["disabled_thumb"]
	else:
		thumb_color = COLORS["thumb_off"].lerp(COLORS["thumb_on"], track_color_progress)

	# Draw shadow.
	if not disabled:
		var shadow_offset := Vector2(1, 2)
		var shadow_color := COLORS["thumb_off_shadow"]
		shadow_color.a *= 1.0 - track_color_progress * 0.5
		draw_circle(thumb_pos + shadow_offset, effective_radius + 1, shadow_color)

	# Draw glow for on state.
	if track_color_progress > 0.1 and not disabled:
		var glow_intensity := track_color_progress * (0.8 + 0.2 * sin(glow_phase))
		var glow_color: Color = COLORS["thumb_on_glow"]
		glow_color.a *= glow_intensity

		# Multiple glow layers.
		for i: int in range(4, 0, -1):
			var glow_radius := effective_radius + float(i) * 4 * glow_intensity
			draw_circle(thumb_pos, glow_radius, Color(glow_color, glow_color.a * (1.0 - float(i) / 5.0)))

	# Draw main thumb.
	draw_circle(thumb_pos, effective_radius, thumb_color)

	# Draw highlight.
	var highlight_offset := Vector2(-2, -2) * flip_scale
	var highlight_radius := effective_radius * 0.3
	draw_circle(thumb_pos + highlight_offset, highlight_radius, Color(1, 1, 1, 0.4))

	# Draw border.
	var border_color := COLORS["track_on_border"] if track_color_progress > 0.5 else COLORS["track_off_border"]
	if disabled:
		border_color = COLORS["disabled"]
	draw_arc(thumb_pos, effective_radius, 0, TAU, 24, border_color, 1.0, true)

	# Draw icon inside thumb.
	_draw_thumb_icon(thumb_pos, effective_radius)


func _draw_thumb_icon(center: Vector2, radius: float) -> void:
	var icon_color := Color(0.3, 0.3, 0.35, 0.8).lerp(Color(0.2, 0.6, 0.3, 0.9), track_color_progress)
	if disabled:
		icon_color = COLORS["disabled"]

	var icon_scale := radius * 0.5

	if track_color_progress > 0.5:
		# Checkmark icon for on state.
		var check_points: PackedVector2Array = [
			center + Vector2(-icon_scale * 0.5, 0),
			center + Vector2(-icon_scale * 0.1, icon_scale * 0.4),
			center + Vector2(icon_scale * 0.5, -icon_scale * 0.3)
		]
		draw_polyline(check_points, icon_color, 2.0, true)
	else:
		# Line icon for off state.
		draw_line(
			center + Vector2(-icon_scale * 0.4, 0),
			center + Vector2(icon_scale * 0.4, 0),
			icon_color, 2.0, true
		)


func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	# Draw rounded rectangle using rect and circles.
	var inner_rect := Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2, rect.size.y)
	draw_rect(inner_rect, color)

	draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius * 2), color)

	# Corners.
	draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.end.y - radius), radius, color)


func _draw_rounded_rect_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
	# Top and bottom lines.
	draw_line(
		Vector2(rect.position.x + radius, rect.position.y),
		Vector2(rect.end.x - radius, rect.position.y),
		color, width, true
	)
	draw_line(
		Vector2(rect.position.x + radius, rect.end.y),
		Vector2(rect.end.x - radius, rect.end.y),
		color, width, true
	)

	# Left and right lines.
	draw_line(
		Vector2(rect.position.x, rect.position.y + radius),
		Vector2(rect.position.x, rect.end.y - radius),
		color, width, true
	)
	draw_line(
		Vector2(rect.end.x, rect.position.y + radius),
		Vector2(rect.end.x, rect.end.y - radius),
		color, width, true
	)

	# Corner arcs.
	draw_arc(Vector2(rect.position.x + radius, rect.position.y + radius), radius, PI, PI * 1.5, 16, color, width, true)
	draw_arc(Vector2(rect.end.x - radius, rect.position.y + radius), radius, PI * 1.5, TAU, 16, color, width, true)
	draw_arc(Vector2(rect.position.x + radius, rect.end.y - radius), radius, PI * 0.5, PI, 16, color, width, true)
	draw_arc(Vector2(rect.end.x - radius, rect.end.y - radius), radius, 0, PI * 0.5, 16, color, width, true)

# ============================================================================ #
#                                  ACTIONS                                      #
# ============================================================================ #

func _toggle() -> void:
	toggled_on = not toggled_on


func _start_toggle_animation() -> void:
	thumb_target = 1.0 if toggled_on else 0.0

	# Add spring impulse.
	var direction := 1.0 if toggled_on else -1.0
	thumb_velocity += direction * 5.0

	# Trigger flip effect.
	flip_progress = 0.5

	# Play sound.
	_play_sound("toggle_click")

	# Haptic feedback.
	if enable_haptics:
		_trigger_haptic()


func _play_sound(sound_name: String) -> void:
	if not enable_sounds:
		return

	if Engine.has_singleton("AudioManager"):
		var audio_manager := Engine.get_singleton("AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx("ui_%s" % sound_name)


func _trigger_haptic() -> void:
	# Haptic feedback for gamepads.
	if Input.get_connected_joypads().size() > 0:
		Input.start_joy_vibration(0, 0.2, 0.1, 0.05)

# ============================================================================ #
#                                PUBLIC API                                     #
# ============================================================================ #

## Set toggle state without emitting signal.
func set_state_silent(enabled: bool) -> void:
	if toggled_on != enabled:
		toggled_on = enabled
		thumb_target = 1.0 if enabled else 0.0
		thumb_progress = thumb_target
		track_color_progress = thumb_target


## Set toggle state with animation.
func set_state(enabled: bool) -> void:
	toggled_on = enabled


## Get current state.
func get_state() -> bool:
	return toggled_on


## Enable/disable the toggle.
func set_disabled(is_disabled: bool) -> void:
	disabled = is_disabled
	queue_redraw()
