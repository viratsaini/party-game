## Advanced Color Picker - Smooth gradient selector with hue wheel and color harmony
## Features: hue wheel with drag, RGB sliders, hex input, saved colors, eyedropper, harmony
extends Control
class_name ColorPickerAdvanced

## Emitted when color changes
signal color_changed(color: Color)
## Emitted when color is confirmed
signal color_confirmed(color: Color)
## Emitted when eyedropper is activated
signal eyedropper_activated

# Current color
@export var selected_color: Color = Color.WHITE:
	set(value):
		selected_color = value
		if is_inside_tree():
			_update_all_from_color(value)
			color_changed.emit(value)

# Configuration
@export var show_alpha: bool = true
@export var show_hex_input: bool = true
@export var show_rgb_sliders: bool = true
@export var show_harmony: bool = true
@export var max_saved_colors: int = 12

# Colors
@export_group("Theme")
@export var panel_color: Color = Color(0.12, 0.12, 0.16, 1.0)
@export var accent_color: Color = Color(0.3, 0.5, 1.0, 1.0)
@export var text_color: Color = Color.WHITE

# Animation
@export var animation_duration: float = 0.2

# Saved colors palette
var saved_colors: Array[Color] = []

# Internal nodes
var _container: VBoxContainer
var _wheel_container: Control
var _hue_wheel: Control
var _satval_square: Control
var _wheel_indicator: Control
var _square_indicator: Control
var _preview_panel: Panel
var _preview_current: ColorRect
var _preview_new: ColorRect
var _rgb_container: VBoxContainer
var _red_slider: HSlider
var _green_slider: HSlider
var _blue_slider: HSlider
var _alpha_slider: HSlider
var _rgb_labels: Array[Label] = []
var _hex_input: LineEdit
var _harmony_container: HBoxContainer
var _saved_colors_container: GridContainer
var _eyedropper_btn: Button
var _confirm_btn: Button

# State
var _dragging_wheel: bool = false
var _dragging_square: bool = false
var _hue: float = 0.0
var _saturation: float = 1.0
var _value: float = 1.0
var _alpha: float = 1.0
var _original_color: Color = Color.WHITE
var _updating_internally: bool = false

# Harmony types
enum HarmonyType { COMPLEMENTARY, TRIADIC, ANALOGOUS, SPLIT_COMPLEMENTARY, TETRADIC }
var _current_harmony: HarmonyType = HarmonyType.COMPLEMENTARY


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_all_from_color(selected_color)
	_original_color = selected_color


func _setup_ui() -> void:
	custom_minimum_size = Vector2(320, 480)

	# Main container
	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.add_theme_constant_override("separation", 10)
	add_child(_container)

	# Background
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = panel_color
	bg_style.corner_radius_top_left = 12
	bg_style.corner_radius_top_right = 12
	bg_style.corner_radius_bottom_left = 12
	bg_style.corner_radius_bottom_right = 12
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	# Padding
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	margin.add_child(inner)

	# Hue wheel and saturation/value square
	_setup_wheel_section(inner)

	# Color preview
	_setup_preview_section(inner)

	# RGB sliders
	if show_rgb_sliders:
		_setup_rgb_sliders(inner)

	# Hex input
	if show_hex_input:
		_setup_hex_input(inner)

	# Color harmony
	if show_harmony:
		_setup_harmony_section(inner)

	# Saved colors
	_setup_saved_colors(inner)

	# Action buttons
	_setup_action_buttons(inner)


func _setup_wheel_section(parent: Control) -> void:
	_wheel_container = Control.new()
	_wheel_container.custom_minimum_size = Vector2(200, 200)
	parent.add_child(_wheel_container)

	# Hue wheel (ring)
	_hue_wheel = Control.new()
	_hue_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hue_wheel.mouse_filter = Control.MOUSE_FILTER_STOP
	_wheel_container.add_child(_hue_wheel)
	_hue_wheel.draw.connect(_draw_hue_wheel)

	# Saturation/Value square (inside the wheel)
	_satval_square = Control.new()
	_satval_square.anchor_left = 0.2
	_satval_square.anchor_right = 0.8
	_satval_square.anchor_top = 0.2
	_satval_square.anchor_bottom = 0.8
	_satval_square.mouse_filter = Control.MOUSE_FILTER_STOP
	_wheel_container.add_child(_satval_square)
	_satval_square.draw.connect(_draw_satval_square)

	# Wheel indicator (shows current hue on the ring)
	_wheel_indicator = Control.new()
	_wheel_indicator.custom_minimum_size = Vector2(16, 16)
	_wheel_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel_container.add_child(_wheel_indicator)
	_wheel_indicator.draw.connect(_draw_wheel_indicator)

	# Square indicator (shows current sat/val)
	_square_indicator = Control.new()
	_square_indicator.custom_minimum_size = Vector2(14, 14)
	_square_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_satval_square.add_child(_square_indicator)
	_square_indicator.draw.connect(_draw_square_indicator)


func _setup_preview_section(parent: Control) -> void:
	var preview_container := HBoxContainer.new()
	preview_container.custom_minimum_size = Vector2(0, 50)
	preview_container.add_theme_constant_override("separation", 5)
	parent.add_child(preview_container)

	# Original color
	var orig_container := VBoxContainer.new()
	orig_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var orig_label := Label.new()
	orig_label.text = "Original"
	orig_label.add_theme_font_size_override("font_size", 10)
	orig_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.7))
	orig_container.add_child(orig_label)

	_preview_current = ColorRect.new()
	_preview_current.custom_minimum_size = Vector2(0, 35)
	_preview_current.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orig_container.add_child(_preview_current)

	preview_container.add_child(orig_container)

	# Arrow
	var arrow := Label.new()
	arrow.text = ">"
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.add_theme_color_override("font_color", text_color)
	preview_container.add_child(arrow)

	# New color
	var new_container := VBoxContainer.new()
	new_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var new_label := Label.new()
	new_label.text = "New"
	new_label.add_theme_font_size_override("font_size", 10)
	new_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.7))
	new_container.add_child(new_label)

	_preview_new = ColorRect.new()
	_preview_new.custom_minimum_size = Vector2(0, 35)
	_preview_new.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_container.add_child(_preview_new)

	preview_container.add_child(new_container)


func _setup_rgb_sliders(parent: Control) -> void:
	_rgb_container = VBoxContainer.new()
	_rgb_container.add_theme_constant_override("separation", 8)
	parent.add_child(_rgb_container)

	_red_slider = _create_color_slider("R", Color.RED)
	_green_slider = _create_color_slider("G", Color.GREEN)
	_blue_slider = _create_color_slider("B", Color.BLUE)

	if show_alpha:
		_alpha_slider = _create_color_slider("A", Color.WHITE)


func _create_color_slider(label_text: String, color: Color) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_rgb_container.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(20, 0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.001
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var slider_style := StyleBoxFlat.new()
	slider_style.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.5)
	slider_style.corner_radius_top_left = 4
	slider_style.corner_radius_top_right = 4
	slider_style.corner_radius_bottom_left = 4
	slider_style.corner_radius_bottom_right = 4
	slider.add_theme_stylebox_override("slider", slider_style)

	var grabber_style := StyleBoxFlat.new()
	grabber_style.bg_color = color
	grabber_style.corner_radius_top_left = 6
	grabber_style.corner_radius_top_right = 6
	grabber_style.corner_radius_bottom_left = 6
	grabber_style.corner_radius_bottom_right = 6
	slider.add_theme_stylebox_override("grabber_area", grabber_style)

	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = "255"
	value_label.custom_minimum_size = Vector2(35, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", text_color)
	row.add_child(value_label)
	_rgb_labels.append(value_label)

	return slider


func _setup_hex_input(parent: Control) -> void:
	var hex_row := HBoxContainer.new()
	hex_row.add_theme_constant_override("separation", 8)
	parent.add_child(hex_row)

	var hex_label := Label.new()
	hex_label.text = "Hex:"
	hex_label.add_theme_font_size_override("font_size", 14)
	hex_label.add_theme_color_override("font_color", text_color)
	hex_row.add_child(hex_label)

	_hex_input = LineEdit.new()
	_hex_input.placeholder_text = "#FFFFFF"
	_hex_input.max_length = 9  # #RRGGBBAA
	_hex_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hex_style := StyleBoxFlat.new()
	hex_style.bg_color = Color(0.1, 0.1, 0.14, 1.0)
	hex_style.corner_radius_top_left = 6
	hex_style.corner_radius_top_right = 6
	hex_style.corner_radius_bottom_left = 6
	hex_style.corner_radius_bottom_right = 6
	_hex_input.add_theme_stylebox_override("normal", hex_style)
	_hex_input.add_theme_stylebox_override("focus", hex_style)
	_hex_input.add_theme_color_override("font_color", text_color)
	_hex_input.add_theme_font_size_override("font_size", 14)

	hex_row.add_child(_hex_input)

	# Eyedropper button
	_eyedropper_btn = Button.new()
	_eyedropper_btn.text = "[*]"
	_eyedropper_btn.tooltip_text = "Pick color from screen"
	_eyedropper_btn.custom_minimum_size = Vector2(35, 0)

	var eyedrop_style := StyleBoxFlat.new()
	eyedrop_style.bg_color = Color(0.2, 0.2, 0.25, 1.0)
	eyedrop_style.corner_radius_top_left = 6
	eyedrop_style.corner_radius_top_right = 6
	eyedrop_style.corner_radius_bottom_left = 6
	eyedrop_style.corner_radius_bottom_right = 6
	_eyedropper_btn.add_theme_stylebox_override("normal", eyedrop_style)

	hex_row.add_child(_eyedropper_btn)


func _setup_harmony_section(parent: Control) -> void:
	var harmony_section := VBoxContainer.new()
	harmony_section.add_theme_constant_override("separation", 5)
	parent.add_child(harmony_section)

	var harmony_label := Label.new()
	harmony_label.text = "Color Harmony"
	harmony_label.add_theme_font_size_override("font_size", 12)
	harmony_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.7))
	harmony_section.add_child(harmony_label)

	_harmony_container = HBoxContainer.new()
	_harmony_container.add_theme_constant_override("separation", 6)
	harmony_section.add_child(_harmony_container)

	# Add harmony color swatches (will be filled dynamically)
	for i in range(5):
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(40, 30)
		swatch.flat = true

		var swatch_style := StyleBoxFlat.new()
		swatch_style.corner_radius_top_left = 6
		swatch_style.corner_radius_top_right = 6
		swatch_style.corner_radius_bottom_left = 6
		swatch_style.corner_radius_bottom_right = 6
		swatch.add_theme_stylebox_override("normal", swatch_style)

		_harmony_container.add_child(swatch)


func _setup_saved_colors(parent: Control) -> void:
	var saved_section := VBoxContainer.new()
	saved_section.add_theme_constant_override("separation", 5)
	parent.add_child(saved_section)

	var header := HBoxContainer.new()
	saved_section.add_child(header)

	var saved_label := Label.new()
	saved_label.text = "Saved Colors"
	saved_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saved_label.add_theme_font_size_override("font_size", 12)
	saved_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.7))
	header.add_child(saved_label)

	var save_btn := Button.new()
	save_btn.text = "+ Save"
	save_btn.flat = true
	save_btn.add_theme_font_size_override("font_size", 11)
	save_btn.add_theme_color_override("font_color", accent_color)
	save_btn.pressed.connect(_save_current_color)
	header.add_child(save_btn)

	_saved_colors_container = GridContainer.new()
	_saved_colors_container.columns = 6
	_saved_colors_container.add_theme_constant_override("h_separation", 5)
	_saved_colors_container.add_theme_constant_override("v_separation", 5)
	saved_section.add_child(_saved_colors_container)


func _setup_action_buttons(parent: Control) -> void:
	var btn_container := HBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 10)
	parent.add_child(btn_container)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, 40)

	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.25, 0.25, 0.3, 1.0)
	cancel_style.corner_radius_top_left = 8
	cancel_style.corner_radius_top_right = 8
	cancel_style.corner_radius_bottom_left = 8
	cancel_style.corner_radius_bottom_right = 8
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.add_theme_color_override("font_color", text_color)
	cancel_btn.pressed.connect(_on_cancel)
	btn_container.add_child(cancel_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm"
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.custom_minimum_size = Vector2(0, 40)

	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = accent_color
	confirm_style.corner_radius_top_left = 8
	confirm_style.corner_radius_top_right = 8
	confirm_style.corner_radius_bottom_left = 8
	confirm_style.corner_radius_bottom_right = 8
	_confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	_confirm_btn.add_theme_color_override("font_color", Color.WHITE)
	_confirm_btn.pressed.connect(_on_confirm)
	btn_container.add_child(_confirm_btn)


func _connect_signals() -> void:
	_hue_wheel.gui_input.connect(_on_wheel_input)
	_satval_square.gui_input.connect(_on_square_input)

	if _red_slider:
		_red_slider.value_changed.connect(func(v: float) -> void: _on_rgb_changed())
	if _green_slider:
		_green_slider.value_changed.connect(func(v: float) -> void: _on_rgb_changed())
	if _blue_slider:
		_blue_slider.value_changed.connect(func(v: float) -> void: _on_rgb_changed())
	if _alpha_slider:
		_alpha_slider.value_changed.connect(func(v: float) -> void: _on_rgb_changed())

	if _hex_input:
		_hex_input.text_submitted.connect(_on_hex_submitted)

	if _eyedropper_btn:
		_eyedropper_btn.pressed.connect(func() -> void: eyedropper_activated.emit())


# Drawing functions
func _draw_hue_wheel() -> void:
	var center: Vector2 = _hue_wheel.size * 0.5
	var outer_radius: float = minf(center.x, center.y) - 5
	var inner_radius: float = outer_radius * 0.75
	var segments: int = 64

	for i in range(segments):
		var angle1: float = (float(i) / segments) * TAU
		var angle2: float = (float(i + 1) / segments) * TAU
		var hue1: float = float(i) / segments
		var hue2: float = float(i + 1) / segments

		var color1 := Color.from_hsv(hue1, 1.0, 1.0)
		var color2 := Color.from_hsv(hue2, 1.0, 1.0)

		var points: PackedVector2Array = PackedVector2Array([
			center + Vector2(cos(angle1), sin(angle1)) * inner_radius,
			center + Vector2(cos(angle1), sin(angle1)) * outer_radius,
			center + Vector2(cos(angle2), sin(angle2)) * outer_radius,
			center + Vector2(cos(angle2), sin(angle2)) * inner_radius
		])

		var colors: PackedColorArray = PackedColorArray([color1, color1, color2, color2])
		_hue_wheel.draw_polygon(points, colors)


func _draw_satval_square() -> void:
	var size: Vector2 = _satval_square.size
	var base_color := Color.from_hsv(_hue, 1.0, 1.0)

	# Draw white-to-color gradient (horizontal)
	for x in range(int(size.x)):
		var sat: float = float(x) / size.x
		var top_color := Color.WHITE.lerp(base_color, sat)

		for y in range(int(size.y)):
			var val: float = 1.0 - float(y) / size.y
			var final_color := top_color * val
			final_color.a = 1.0
			_satval_square.draw_rect(Rect2(x, y, 1, 1), final_color)


func _draw_wheel_indicator() -> void:
	var radius: float = 8
	_wheel_indicator.draw_circle(Vector2(radius, radius), radius, Color.WHITE)
	_wheel_indicator.draw_circle(Vector2(radius, radius), radius - 2, Color.from_hsv(_hue, 1.0, 1.0))
	_wheel_indicator.draw_arc(Vector2(radius, radius), radius, 0, TAU, 32, Color.BLACK, 1.5)


func _draw_square_indicator() -> void:
	var radius: float = 7
	_square_indicator.draw_circle(Vector2(radius, radius), radius, Color.WHITE)
	_square_indicator.draw_circle(Vector2(radius, radius), radius - 2, selected_color)
	_square_indicator.draw_arc(Vector2(radius, radius), radius, 0, TAU, 32, Color.BLACK, 1.5)


# Input handling
func _on_wheel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging_wheel = mb.pressed
			if mb.pressed:
				_update_hue_from_position(mb.position)
	elif event is InputEventMouseMotion and _dragging_wheel:
		_update_hue_from_position(event.position)


func _on_square_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging_square = mb.pressed
			if mb.pressed:
				_update_satval_from_position(mb.position)
	elif event is InputEventMouseMotion and _dragging_square:
		_update_satval_from_position(event.position)


func _update_hue_from_position(pos: Vector2) -> void:
	var center: Vector2 = _hue_wheel.size * 0.5
	var angle: float = atan2(pos.y - center.y, pos.x - center.x)
	if angle < 0:
		angle += TAU

	_hue = angle / TAU
	_update_color_from_hsv()
	_update_wheel_indicator_position()
	_satval_square.queue_redraw()


func _update_satval_from_position(pos: Vector2) -> void:
	var size: Vector2 = _satval_square.size
	_saturation = clampf(pos.x / size.x, 0.0, 1.0)
	_value = clampf(1.0 - pos.y / size.y, 0.0, 1.0)
	_update_color_from_hsv()
	_update_square_indicator_position()


func _update_color_from_hsv() -> void:
	if _updating_internally:
		return

	_updating_internally = true
	selected_color = Color.from_hsv(_hue, _saturation, _value, _alpha)
	_update_preview()
	_update_rgb_sliders()
	_update_hex_input()
	_update_harmony_colors()
	_wheel_indicator.queue_redraw()
	_square_indicator.queue_redraw()
	color_changed.emit(selected_color)
	_updating_internally = false


func _update_all_from_color(color: Color) -> void:
	if _updating_internally:
		return

	_updating_internally = true
	_hue = color.h
	_saturation = color.s
	_value = color.v
	_alpha = color.a

	_update_wheel_indicator_position()
	_update_square_indicator_position()
	_update_preview()
	_update_rgb_sliders()
	_update_hex_input()
	_update_harmony_colors()
	_hue_wheel.queue_redraw()
	_satval_square.queue_redraw()
	_wheel_indicator.queue_redraw()
	_square_indicator.queue_redraw()
	_updating_internally = false


func _update_wheel_indicator_position() -> void:
	var center: Vector2 = _hue_wheel.size * 0.5
	var radius: float = minf(center.x, center.y) * 0.875
	var angle: float = _hue * TAU

	_wheel_indicator.position = center + Vector2(cos(angle), sin(angle)) * radius - Vector2(8, 8)


func _update_square_indicator_position() -> void:
	var size: Vector2 = _satval_square.size
	_square_indicator.position = Vector2(_saturation * size.x, (1.0 - _value) * size.y) - Vector2(7, 7)


func _update_preview() -> void:
	if _preview_current:
		_preview_current.color = _original_color
	if _preview_new:
		_preview_new.color = selected_color


func _update_rgb_sliders() -> void:
	if _red_slider:
		_red_slider.set_value_no_signal(selected_color.r)
	if _green_slider:
		_green_slider.set_value_no_signal(selected_color.g)
	if _blue_slider:
		_blue_slider.set_value_no_signal(selected_color.b)
	if _alpha_slider:
		_alpha_slider.set_value_no_signal(selected_color.a)

	if _rgb_labels.size() >= 3:
		_rgb_labels[0].text = str(int(selected_color.r * 255))
		_rgb_labels[1].text = str(int(selected_color.g * 255))
		_rgb_labels[2].text = str(int(selected_color.b * 255))
		if _rgb_labels.size() >= 4:
			_rgb_labels[3].text = str(int(selected_color.a * 255))


func _update_hex_input() -> void:
	if _hex_input:
		var hex: String = "#" + selected_color.to_html(show_alpha)
		_hex_input.text = hex.to_upper()


func _update_harmony_colors() -> void:
	if not _harmony_container:
		return

	var harmonies: Array[Color] = _calculate_harmony_colors()

	for i in range(mini(harmonies.size(), _harmony_container.get_child_count())):
		var btn: Button = _harmony_container.get_child(i) as Button
		if btn:
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
			if style:
				style.bg_color = harmonies[i]
				btn.add_theme_stylebox_override("normal", style)

			# Connect click to select harmony color
			if not btn.pressed.is_connected(_select_harmony_color):
				btn.pressed.connect(_select_harmony_color.bind(i))


func _calculate_harmony_colors() -> Array[Color]:
	var colors: Array[Color] = []

	match _current_harmony:
		HarmonyType.COMPLEMENTARY:
			colors.append(selected_color)
			colors.append(Color.from_hsv(fmod(_hue + 0.5, 1.0), _saturation, _value, _alpha))

		HarmonyType.TRIADIC:
			colors.append(selected_color)
			colors.append(Color.from_hsv(fmod(_hue + 0.333, 1.0), _saturation, _value, _alpha))
			colors.append(Color.from_hsv(fmod(_hue + 0.666, 1.0), _saturation, _value, _alpha))

		HarmonyType.ANALOGOUS:
			colors.append(Color.from_hsv(fmod(_hue - 0.083 + 1.0, 1.0), _saturation, _value, _alpha))
			colors.append(selected_color)
			colors.append(Color.from_hsv(fmod(_hue + 0.083, 1.0), _saturation, _value, _alpha))

		HarmonyType.SPLIT_COMPLEMENTARY:
			colors.append(selected_color)
			colors.append(Color.from_hsv(fmod(_hue + 0.416, 1.0), _saturation, _value, _alpha))
			colors.append(Color.from_hsv(fmod(_hue + 0.583, 1.0), _saturation, _value, _alpha))

		HarmonyType.TETRADIC:
			colors.append(selected_color)
			colors.append(Color.from_hsv(fmod(_hue + 0.25, 1.0), _saturation, _value, _alpha))
			colors.append(Color.from_hsv(fmod(_hue + 0.5, 1.0), _saturation, _value, _alpha))
			colors.append(Color.from_hsv(fmod(_hue + 0.75, 1.0), _saturation, _value, _alpha))

	# Pad to 5 colors if needed
	while colors.size() < 5:
		var last := colors[-1] if colors.size() > 0 else selected_color
		colors.append(Color.from_hsv(last.h, last.s * 0.7, last.v, last.a))

	return colors


func _select_harmony_color(index: int) -> void:
	var harmonies := _calculate_harmony_colors()
	if index < harmonies.size():
		selected_color = harmonies[index]


func _on_rgb_changed() -> void:
	if _updating_internally:
		return

	_updating_internally = true
	var r: float = _red_slider.value if _red_slider else 0.0
	var g: float = _green_slider.value if _green_slider else 0.0
	var b: float = _blue_slider.value if _blue_slider else 0.0
	var a: float = _alpha_slider.value if _alpha_slider else 1.0

	selected_color = Color(r, g, b, a)
	_hue = selected_color.h
	_saturation = selected_color.s
	_value = selected_color.v
	_alpha = a

	_update_wheel_indicator_position()
	_update_square_indicator_position()
	_update_preview()
	_update_hex_input()
	_update_harmony_colors()
	_satval_square.queue_redraw()
	_wheel_indicator.queue_redraw()
	_square_indicator.queue_redraw()

	if _rgb_labels.size() >= 3:
		_rgb_labels[0].text = str(int(r * 255))
		_rgb_labels[1].text = str(int(g * 255))
		_rgb_labels[2].text = str(int(b * 255))
		if _rgb_labels.size() >= 4:
			_rgb_labels[3].text = str(int(a * 255))

	color_changed.emit(selected_color)
	_updating_internally = false


func _on_hex_submitted(hex: String) -> void:
	if hex.begins_with("#"):
		hex = hex.substr(1)

	if hex.is_valid_hex_number() and (hex.length() == 6 or hex.length() == 8):
		var color := Color.html(hex)
		selected_color = color


func _save_current_color() -> void:
	if saved_colors.size() >= max_saved_colors:
		saved_colors.pop_front()

	saved_colors.append(selected_color)
	_update_saved_colors_display()


func _update_saved_colors_display() -> void:
	# Clear existing
	for child in _saved_colors_container.get_children():
		child.queue_free()

	# Add saved colors
	for color in saved_colors:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(30, 30)
		swatch.flat = true

		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		swatch.add_theme_stylebox_override("normal", style)

		swatch.pressed.connect(func() -> void: selected_color = color)
		_saved_colors_container.add_child(swatch)


func _on_cancel() -> void:
	selected_color = _original_color


func _on_confirm() -> void:
	color_confirmed.emit(selected_color)


# Public API
func get_color() -> Color:
	return selected_color


func set_color(color: Color) -> void:
	_original_color = color
	selected_color = color


func set_harmony_type(harmony: HarmonyType) -> void:
	_current_harmony = harmony
	_update_harmony_colors()


func add_saved_color(color: Color) -> void:
	saved_colors.append(color)
	_update_saved_colors_display()


func clear_saved_colors() -> void:
	saved_colors.clear()
	_update_saved_colors_display()
