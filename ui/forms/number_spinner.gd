## Number Spinner - Satisfying number input with drag, acceleration, and flip animation
## Features: increment/decrement with repeat, long press accelerates, wheel support, digit flip
extends Control
class_name NumberSpinner

## Emitted when value changes
signal value_changed(new_value: float)
## Emitted when value reaches min/max
signal limit_reached(is_max: bool)

# Value configuration
@export var value: float = 0.0:
	set(v):
		var old_value := value
		value = clampf(v, min_value, max_value)
		if old_value != value and is_inside_tree():
			_animate_value_change(old_value, value)
			value_changed.emit(value)

@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var step: float = 1.0
@export var decimals: int = 0
@export var wrap_around: bool = false

# Display
@export var prefix: String = ""
@export var suffix: String = ""
@export var show_step_indicators: bool = true
@export var label_text: String = "Value"

# Visual
@export_group("Colors")
@export var base_color: Color = Color(0.15, 0.15, 0.2, 1.0)
@export var accent_color: Color = Color(0.3, 0.5, 1.0, 1.0)
@export var text_color: Color = Color.WHITE
@export var button_color: Color = Color(0.25, 0.25, 0.35, 1.0)
@export var warning_color: Color = Color(1.0, 0.5, 0.2, 1.0)

# Timing
@export_group("Timing")
@export var repeat_delay: float = 0.4
@export var repeat_rate_start: float = 0.15
@export var repeat_rate_fast: float = 0.03
@export var acceleration_time: float = 2.0
@export var flip_duration: float = 0.2

# Internal nodes
var _container: Control
var _background: Panel
var _label: Label
var _value_container: Control
var _digit_displays: Array[Control] = []
var _decrement_btn: Button
var _increment_btn: Button
var _step_indicator: Control
var _drag_area: Control

# State
var _is_dragging: bool = false
var _drag_start_y: float = 0.0
var _drag_start_value: float = 0.0
var _is_incrementing: bool = false
var _is_decrementing: bool = false
var _repeat_timer: float = 0.0
var _hold_time: float = 0.0
var _current_repeat_rate: float = 0.15

# Animation
var _flip_tweens: Dictionary = {}
var _shake_tween: Tween


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_display(value, false)


func _setup_ui() -> void:
	custom_minimum_size = Vector2(200, 80)

	# Main container
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_container)

	# Background
	_background = Panel.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = base_color
	bg_style.corner_radius_top_left = 12
	bg_style.corner_radius_top_right = 12
	bg_style.corner_radius_bottom_left = 12
	bg_style.corner_radius_bottom_right = 12
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(button_color.r, button_color.g, button_color.b, 0.5)
	_background.add_theme_stylebox_override("panel", bg_style)
	_container.add_child(_background)

	# Label
	_label = Label.new()
	_label.text = label_text
	_label.position = Vector2(10, 5)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.7))
	_container.add_child(_label)

	# Decrement button
	_decrement_btn = _create_spinner_button("-", false)
	_decrement_btn.anchor_left = 0.0
	_decrement_btn.anchor_right = 0.2
	_decrement_btn.anchor_top = 0.25
	_decrement_btn.anchor_bottom = 0.95
	_decrement_btn.offset_left = 5
	_decrement_btn.offset_right = 0
	_decrement_btn.offset_top = 5
	_decrement_btn.offset_bottom = -5
	_container.add_child(_decrement_btn)

	# Increment button
	_increment_btn = _create_spinner_button("+", true)
	_increment_btn.anchor_left = 0.8
	_increment_btn.anchor_right = 1.0
	_increment_btn.anchor_top = 0.25
	_increment_btn.anchor_bottom = 0.95
	_increment_btn.offset_left = 0
	_increment_btn.offset_right = -5
	_increment_btn.offset_top = 5
	_increment_btn.offset_bottom = -5
	_container.add_child(_increment_btn)

	# Value display area (draggable)
	_value_container = Control.new()
	_value_container.anchor_left = 0.2
	_value_container.anchor_right = 0.8
	_value_container.anchor_top = 0.25
	_value_container.anchor_bottom = 0.95
	_value_container.offset_top = 5
	_value_container.offset_bottom = -5
	_value_container.clip_contents = true
	_container.add_child(_value_container)

	# Drag overlay
	_drag_area = Control.new()
	_drag_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_value_container.add_child(_drag_area)

	# Create digit displays
	_setup_digit_displays()

	# Step indicators
	if show_step_indicators:
		_setup_step_indicators()


func _create_spinner_button(text: String, is_increment: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = false

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = button_color
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(button_color.r + 0.1, button_color.g + 0.1, button_color.b + 0.1, 1.0)
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = accent_color
	pressed_style.corner_radius_top_left = 8
	pressed_style.corner_radius_top_right = 8
	pressed_style.corner_radius_bottom_left = 8
	pressed_style.corner_radius_bottom_right = 8

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", text_color)

	return btn


func _setup_digit_displays() -> void:
	# Clear existing
	for digit in _digit_displays:
		digit.queue_free()
	_digit_displays.clear()

	# Create a centered label for the value
	var display := Control.new()
	display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_value_container.add_child(display)

	var current_label := Label.new()
	current_label.name = "CurrentValue"
	current_label.set_anchors_preset(Control.PRESET_CENTER)
	current_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	current_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_label.add_theme_font_size_override("font_size", 28)
	current_label.add_theme_color_override("font_color", text_color)
	display.add_child(current_label)

	# Create "next" value label for flip animation
	var next_label := Label.new()
	next_label.name = "NextValue"
	next_label.set_anchors_preset(Control.PRESET_CENTER)
	next_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	next_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_label.add_theme_font_size_override("font_size", 28)
	next_label.add_theme_color_override("font_color", text_color)
	next_label.modulate.a = 0.0
	display.add_child(next_label)

	_digit_displays.append(display)


func _setup_step_indicators() -> void:
	_step_indicator = Control.new()
	_step_indicator.anchor_left = 0.2
	_step_indicator.anchor_right = 0.8
	_step_indicator.anchor_top = 0.9
	_step_indicator.anchor_bottom = 1.0
	_step_indicator.offset_top = -3
	_container.add_child(_step_indicator)

	# Create step dots
	var step_count: int = int((max_value - min_value) / step) + 1
	var max_dots: int = mini(step_count, 20)
	var dot_size: float = 4.0
	var total_width: float = _step_indicator.size.x if _step_indicator.size.x > 0 else 120
	var spacing: float = total_width / float(max_dots)

	for i in range(max_dots):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(dot_size, dot_size)
		dot.size = Vector2(dot_size, dot_size)
		dot.position = Vector2(i * spacing + spacing * 0.5 - dot_size * 0.5, 0)
		dot.color = Color(text_color.r, text_color.g, text_color.b, 0.3)
		_step_indicator.add_child(dot)


func _connect_signals() -> void:
	# Button press/release for hold detection
	_decrement_btn.button_down.connect(func() -> void: _start_decrement())
	_decrement_btn.button_up.connect(func() -> void: _stop_decrement())
	_increment_btn.button_down.connect(func() -> void: _start_increment())
	_increment_btn.button_up.connect(func() -> void: _stop_increment())

	# Drag handling
	_drag_area.gui_input.connect(_on_drag_input)


func _start_increment() -> void:
	_is_incrementing = true
	_hold_time = 0.0
	_repeat_timer = repeat_delay
	_current_repeat_rate = repeat_rate_start
	_change_value(step)
	_animate_button_press(_increment_btn, true)


func _stop_increment() -> void:
	_is_incrementing = false
	_animate_button_press(_increment_btn, false)


func _start_decrement() -> void:
	_is_decrementing = true
	_hold_time = 0.0
	_repeat_timer = repeat_delay
	_current_repeat_rate = repeat_rate_start
	_change_value(-step)
	_animate_button_press(_decrement_btn, true)


func _stop_decrement() -> void:
	_is_decrementing = false
	_animate_button_press(_decrement_btn, false)


func _animate_button_press(btn: Button, pressed: bool) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	if pressed:
		tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1)
	else:
		tween.tween_property(btn, "scale", Vector2.ONE, 0.15)


func _process(delta: float) -> void:
	if _is_incrementing or _is_decrementing:
		_hold_time += delta
		_repeat_timer -= delta

		# Accelerate repeat rate over time
		var accel_progress: float = clampf(_hold_time / acceleration_time, 0.0, 1.0)
		_current_repeat_rate = lerpf(repeat_rate_start, repeat_rate_fast, accel_progress)

		if _repeat_timer <= 0.0:
			_repeat_timer = _current_repeat_rate

			# Increase step for faster acceleration
			var accel_step: float = step
			if accel_progress > 0.5:
				accel_step = step * (1.0 + accel_progress * 4.0)

			if _is_incrementing:
				_change_value(accel_step)
			elif _is_decrementing:
				_change_value(-accel_step)


func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_start_drag(mb.position.y)
			else:
				_end_drag()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_value(step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_value(-step)

	elif event is InputEventMouseMotion and _is_dragging:
		_update_drag(event.position.y)


func _start_drag(y: float) -> void:
	_is_dragging = true
	_drag_start_y = y
	_drag_start_value = value
	Input.set_default_cursor_shape(Input.CURSOR_VSIZE)


func _update_drag(y: float) -> void:
	var delta_y: float = _drag_start_y - y
	var value_change: float = delta_y * step * 0.1  # Sensitivity

	# Snap to step
	var new_value: float = _drag_start_value + snapped(value_change, step)
	value = new_value


func _end_drag() -> void:
	_is_dragging = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _change_value(delta: float) -> void:
	var new_value: float = value + delta

	if wrap_around:
		if new_value > max_value:
			new_value = min_value
		elif new_value < min_value:
			new_value = max_value
	else:
		new_value = clampf(new_value, min_value, max_value)

		# Check limits
		if new_value == max_value and delta > 0:
			_shake_at_limit()
			limit_reached.emit(true)
		elif new_value == min_value and delta < 0:
			_shake_at_limit()
			limit_reached.emit(false)

	value = new_value


func _animate_value_change(old_val: float, new_val: float) -> void:
	if _digit_displays.is_empty():
		return

	var display: Control = _digit_displays[0]
	var current_label: Label = display.get_node("CurrentValue")
	var next_label: Label = display.get_node("NextValue")

	# Determine direction
	var going_up: bool = new_val > old_val

	# Set next value
	next_label.text = _format_value(new_val)
	next_label.position.y = 30 if going_up else -30
	next_label.modulate.a = 0.0

	# Animate flip
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Current value slides out
	var current_target_y: float = -30 if going_up else 30
	tween.tween_property(current_label, "position:y", current_target_y, flip_duration)
	tween.tween_property(current_label, "modulate:a", 0.0, flip_duration * 0.7)

	# Next value slides in
	tween.tween_property(next_label, "position:y", 0.0, flip_duration)
	tween.tween_property(next_label, "modulate:a", 1.0, flip_duration * 0.7)

	# Swap labels after animation
	tween.chain().tween_callback(func() -> void:
		current_label.text = next_label.text
		current_label.position.y = 0
		current_label.modulate.a = 1.0
		next_label.modulate.a = 0.0
	)

	# Update step indicator
	_update_step_indicator()


func _update_step_indicator() -> void:
	if not show_step_indicators or not is_instance_valid(_step_indicator):
		return

	var progress: float = (value - min_value) / (max_value - min_value)
	var dot_count: int = _step_indicator.get_child_count()

	for i in range(dot_count):
		var dot: ColorRect = _step_indicator.get_child(i) as ColorRect
		if not dot:
			continue

		var dot_progress: float = float(i) / float(dot_count - 1) if dot_count > 1 else 0.0
		var is_active: bool = dot_progress <= progress

		var target_color := Color(accent_color if is_active else Color(text_color.r, text_color.g, text_color.b, 0.3))
		var target_scale := Vector2(1.3, 1.3) if is_active else Vector2.ONE

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(dot, "color", target_color, 0.15)
		tween.tween_property(dot, "scale", target_scale, 0.15)


func _shake_at_limit() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	var original_x: float = _value_container.position.x

	_shake_tween = create_tween()
	_shake_tween.tween_property(_value_container, "position:x", original_x + 6, 0.04)
	_shake_tween.tween_property(_value_container, "position:x", original_x - 6, 0.04)
	_shake_tween.tween_property(_value_container, "position:x", original_x + 4, 0.04)
	_shake_tween.tween_property(_value_container, "position:x", original_x - 4, 0.04)
	_shake_tween.tween_property(_value_container, "position:x", original_x, 0.04)

	# Flash warning color
	var display: Control = _digit_displays[0] if _digit_displays.size() > 0 else null
	if display:
		var label: Label = display.get_node_or_null("CurrentValue")
		if label:
			var color_tween := create_tween()
			color_tween.tween_property(label, "modulate", warning_color, 0.1)
			color_tween.tween_property(label, "modulate", Color.WHITE, 0.2)


func _format_value(val: float) -> String:
	var formatted: String

	if decimals == 0:
		formatted = str(int(val))
	else:
		formatted = ("%%0.%df" % decimals) % val

	return prefix + formatted + suffix


func _update_display(val: float, animate: bool = true) -> void:
	if _digit_displays.is_empty():
		return

	var display: Control = _digit_displays[0]
	var current_label: Label = display.get_node("CurrentValue")

	if animate:
		_animate_value_change(value, val)
	else:
		current_label.text = _format_value(val)


# Public API
func get_value() -> float:
	return value


func set_value_silent(new_value: float) -> void:
	var clamped := clampf(new_value, min_value, max_value)
	value = clamped
	_update_display(clamped, false)


func set_range(new_min: float, new_max: float) -> void:
	min_value = new_min
	max_value = new_max
	value = clampf(value, min_value, max_value)
	_update_display(value, false)


func set_step(new_step: float) -> void:
	step = new_step


func increment() -> void:
	_change_value(step)


func decrement() -> void:
	_change_value(-step)
