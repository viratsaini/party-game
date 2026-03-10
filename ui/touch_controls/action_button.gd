## Circular touch action button for mobile input.
class_name ActionButton
extends Control

## Emitted when the button is pressed down.
signal button_pressed
## Emitted when the button is released.
signal button_released

## Text label drawn on the button.
@export var button_text: String = "A"
## Base colour of the button circle.
@export var button_color: Color = Color(1.0, 0.3, 0.3, 0.8)
## Radius of the button circle in pixels.
@export var button_radius: float = 50.0

## Whether the button is currently held.
var is_pressed: bool = false

# ── Internal ──────────────────────────────────────────────────────────────────
var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO

# Colours derived from base.
var _pressed_darken: float = 0.7  # Multiplier when held.
var _outline_color: Color = Color(1.0, 1.0, 1.0, 0.6)
var _text_color: Color = Color.WHITE


func _ready() -> void:
	_center = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_on_touch_pressed(touch_event)
		else:
			_on_touch_released(touch_event)


func _on_touch_pressed(event: InputEventScreenTouch) -> void:
	if is_pressed:
		return

	var local_pos: Vector2 = event.position - global_position
	if local_pos.distance_to(_center) > button_radius:
		return

	_touch_index = event.index
	is_pressed = true
	button_pressed.emit()
	queue_redraw()


func _on_touch_released(event: InputEventScreenTouch) -> void:
	if event.index != _touch_index:
		return

	_touch_index = -1
	is_pressed = false
	button_released.emit()
	queue_redraw()


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	_center = size * 0.5

	# Button circle.
	var col: Color = button_color
	if is_pressed:
		col = Color(col.r * _pressed_darken, col.g * _pressed_darken, col.b * _pressed_darken, col.a)

	draw_circle(_center, button_radius, col)
	draw_arc(_center, button_radius, 0.0, TAU, 48, _outline_color, 2.0)

	# Text label in the centre.
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 28
	var text_size: Vector2 = font.get_string_size(button_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = _center - Vector2(text_size.x * 0.5, -text_size.y * 0.25)
	draw_string(font, text_pos, button_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, _text_color)
