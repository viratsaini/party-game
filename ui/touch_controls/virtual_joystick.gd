## Virtual joystick Control for mobile touch input.
## Tracks a single finger inside the outer ring and emits normalised direction.
class_name VirtualJoystick
extends Control

## Emitted every frame the output changes, including on release (Vector2.ZERO).
signal joystick_changed(output: Vector2)

## Outer ring radius in pixels.
@export var joystick_radius: float = 100.0
## Inner knob radius in pixels.
@export var knob_radius: float = 40.0
## Dead-zone as a fraction of joystick_radius (0-1).
@export var dead_zone: float = 0.15
## Clamp zone as a fraction of joystick_radius – output reaches 1.0 at this distance.
@export var clamp_zone: float = 0.9

## Normalised output in the range (-1, -1) to (1, 1). Read this each physics frame.
var output: Vector2 = Vector2.ZERO
## Whether the joystick is currently being held.
var is_pressed: bool = false

# ── Internal ──────────────────────────────────────────────────────────────────
var _touch_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO  # Pixel offset of knob from center.
var _center: Vector2 = Vector2.ZERO

# ── Colors ────────────────────────────────────────────────────────────────────
var _ring_color: Color = Color(1.0, 1.0, 1.0, 0.25)
var _ring_pressed_color: Color = Color(1.0, 1.0, 1.0, 0.4)
var _knob_color: Color = Color(1.0, 1.0, 1.0, 0.6)
var _knob_pressed_color: Color = Color(1.0, 1.0, 1.0, 0.85)


func _ready() -> void:
	_center = size * 0.5
	# Ensure the Control can receive input.
	mouse_filter = Control.MOUSE_FILTER_STOP


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_on_touch_pressed(touch_event)
		else:
			_on_touch_released(touch_event)
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		_on_touch_dragged(drag_event)


# ── Touch handling ────────────────────────────────────────────────────────────

func _on_touch_pressed(event: InputEventScreenTouch) -> void:
	if is_pressed:
		return  # Already tracking a finger.

	var local_pos: Vector2 = _to_local_pos(event.position)
	if local_pos.distance_to(_center) > joystick_radius:
		return  # Touch is outside the outer ring.

	_touch_index = event.index
	is_pressed = true
	_update_knob(local_pos)


func _on_touch_released(event: InputEventScreenTouch) -> void:
	if event.index != _touch_index:
		return

	_reset()


func _on_touch_dragged(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return

	var local_pos: Vector2 = _to_local_pos(event.position)
	_update_knob(local_pos)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _to_local_pos(screen_pos: Vector2) -> Vector2:
	return screen_pos - global_position


func _update_knob(local_pos: Vector2) -> void:
	var diff: Vector2 = local_pos - _center
	var dist: float = diff.length()

	# Clamp the knob to the outer ring.
	if dist > joystick_radius:
		diff = diff.normalized() * joystick_radius
		dist = joystick_radius

	_knob_offset = diff

	# Calculate normalised output.
	var max_reach: float = joystick_radius * clamp_zone
	var dead_reach: float = joystick_radius * dead_zone

	if dist < dead_reach:
		output = Vector2.ZERO
	else:
		var clamped: float = clampf((dist - dead_reach) / (max_reach - dead_reach), 0.0, 1.0)
		output = diff.normalized() * clamped

	joystick_changed.emit(output)
	queue_redraw()


func _reset() -> void:
	_touch_index = -1
	is_pressed = false
	_knob_offset = Vector2.ZERO
	output = Vector2.ZERO
	joystick_changed.emit(output)
	queue_redraw()


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	_center = size * 0.5

	# Outer ring.
	var ring_col: Color = _ring_pressed_color if is_pressed else _ring_color
	draw_circle(_center, joystick_radius, ring_col)
	draw_arc(_center, joystick_radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.5), 2.0)

	# Inner knob.
	var knob_pos: Vector2 = _center + _knob_offset
	var knob_col: Color = _knob_pressed_color if is_pressed else _knob_color
	draw_circle(knob_pos, knob_radius, knob_col)
	draw_arc(knob_pos, knob_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.7), 2.0)
