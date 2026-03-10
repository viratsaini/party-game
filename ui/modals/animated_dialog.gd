## AnimatedDialog - Premium modal dialog system with animations and effects
## Features background blur, elastic scale, glowing buttons, and particle confirmations
extends CanvasLayer

signal dialog_opened(dialog_id: String)
signal dialog_closed(dialog_id: String)
signal dialog_confirmed(dialog_id: String)
signal dialog_cancelled(dialog_id: String)

enum DialogType {
	INFO,
	CONFIRM,
	WARNING,
	ERROR,
	INPUT,
	CUSTOM
}

# Configuration
@export var blur_enabled: bool = true
@export var blur_amount: float = 3.0
@export var dim_amount: float = 0.7
@export var animation_duration: float = 0.3

# Node references
var _root: Control
var _blur_layer: ColorRect
var _dim_layer: ColorRect
var _dialog_container: Control
var _current_dialog: Control

# State
var _is_open: bool = false
var _current_dialog_id: String = ""
var _dialog_stack: Array[Dictionary] = []

# Colors
const ACCENT_COLOR := Color(0.3, 0.6, 1.0)
const SUCCESS_COLOR := Color(0.2, 0.8, 0.4)
const WARNING_COLOR := Color(0.9, 0.7, 0.2)
const ERROR_COLOR := Color(0.9, 0.3, 0.3)
const BUTTON_HOVER_GLOW := Color(0.4, 0.7, 1.0, 0.5)

# Shaders
const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 0.0;

void fragment() {
	vec4 col = vec4(0.0);
	float total = 0.0;

	for (float x = -2.0; x <= 2.0; x += 1.0) {
		for (float y = -2.0; y <= 2.0; y += 1.0) {
			vec2 offset = vec2(x, y) * blur_amount * 0.005;
			col += texture(SCREEN_TEXTURE, UV + offset);
			total += 1.0;
		}
	}

	COLOR = col / total;
}
"""

const BUTTON_GLOW_SHADER := """
shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 0.5);
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time : hint_range(0.0, 100.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float glow = smoothstep(0.0, 0.15, dist) * (1.0 - smoothstep(0.15, 0.2, dist));

	// Animated pulse
	glow *= glow_intensity * (0.7 + sin(time * 3.0) * 0.3);

	COLOR = vec4(glow_color.rgb, glow * glow_color.a);
}
"""


func _ready() -> void:
	layer = 120
	_build_ui()
	visible = false


func _process(_delta: float) -> void:
	_update_button_shaders()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "DialogRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Blur layer (using shader)
	if blur_enabled:
		_blur_layer = ColorRect.new()
		_blur_layer.name = "BlurLayer"
		_blur_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_blur_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var blur_mat := ShaderMaterial.new()
		var blur_shader := Shader.new()
		blur_shader.code = BLUR_SHADER
		blur_mat.shader = blur_shader
		blur_mat.set_shader_parameter("blur_amount", 0.0)
		_blur_layer.material = blur_mat

		_root.add_child(_blur_layer)

	# Dim layer
	_dim_layer = ColorRect.new()
	_dim_layer.name = "DimLayer"
	_dim_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_layer.color = Color(0, 0, 0, 0)
	_dim_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim_layer)

	# Dialog container
	_dialog_container = Control.new()
	_dialog_container.name = "DialogContainer"
	_dialog_container.set_anchors_preset(Control.PRESET_CENTER)
	_dialog_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dialog_container)


func _update_button_shaders() -> void:
	if not _current_dialog:
		return

	var time := Time.get_ticks_msec() / 1000.0

	# Update all button glow shaders
	for child in _current_dialog.get_children():
		if child is Button:
			var glow: ColorRect = child.get_node_or_null("GlowOverlay")
			if glow and glow.material:
				(glow.material as ShaderMaterial).set_shader_parameter("time", time)


# ============================================================================
# PUBLIC API
# ============================================================================

## Show an info dialog
func show_info(title: String, message: String, button_text: String = "OK") -> void:
	var id := _generate_id()
	_show_dialog(id, DialogType.INFO, title, message, [button_text], ACCENT_COLOR)


## Show a confirmation dialog
func show_confirm(title: String, message: String, confirm_text: String = "Confirm", cancel_text: String = "Cancel") -> void:
	var id := _generate_id()
	_show_dialog(id, DialogType.CONFIRM, title, message, [cancel_text, confirm_text], ACCENT_COLOR)


## Show a warning dialog
func show_warning(title: String, message: String, button_text: String = "OK") -> void:
	var id := _generate_id()
	_show_dialog(id, DialogType.WARNING, title, message, [button_text], WARNING_COLOR)


## Show an error dialog with shake effect
func show_error(title: String, message: String, button_text: String = "OK") -> void:
	var id := _generate_id()
	_show_dialog(id, DialogType.ERROR, title, message, [button_text], ERROR_COLOR)

	# Trigger shake after dialog appears
	await get_tree().create_timer(animation_duration + 0.1).timeout
	_shake_dialog()


## Show input dialog
func show_input(title: String, message: String, placeholder: String = "", confirm_text: String = "Submit", cancel_text: String = "Cancel") -> void:
	var id := _generate_id()
	_show_input_dialog(id, title, message, placeholder, confirm_text, cancel_text)


## Show custom dialog with arbitrary content
func show_custom(dialog_id: String, content: Control, buttons: Array[String] = ["OK"]) -> void:
	_show_custom_dialog(dialog_id, content, buttons)


## Close the current dialog
func close_dialog() -> void:
	if not _is_open:
		return

	await _animate_out()

	dialog_closed.emit(_current_dialog_id)

	_cleanup_dialog()

	# Check if there are stacked dialogs
	if not _dialog_stack.is_empty():
		var next := _dialog_stack.pop_back()
		_show_dialog(next.id, next.type, next.title, next.message, next.buttons, next.color)


## Force close all dialogs
func close_all() -> void:
	_dialog_stack.clear()
	if _is_open:
		close_dialog()


# ============================================================================
# DIALOG CREATION
# ============================================================================

func _show_dialog(id: String, type: DialogType, title: String, message: String, buttons: Array, accent: Color) -> void:
	if _is_open:
		# Stack current dialog
		_dialog_stack.append({
			"id": _current_dialog_id,
			"type": type,
			"title": title,
			"message": message,
			"buttons": buttons,
			"color": accent
		})
		_cleanup_dialog()

	_is_open = true
	_current_dialog_id = id
	visible = true

	# Create dialog panel
	_current_dialog = _create_dialog_panel(type, title, message, buttons, accent)
	_dialog_container.add_child(_current_dialog)

	# Position at center
	_current_dialog.position = -_current_dialog.size / 2

	# Animate in
	await _animate_in()

	dialog_opened.emit(id)


func _create_dialog_panel(type: DialogType, title: String, message: String, buttons: Array, accent: Color) -> Control:
	var panel := Control.new()
	panel.custom_minimum_size = Vector2(400, 200)

	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.size = Vector2(400, 200)
	bg.color = Color(0.12, 0.14, 0.18)
	panel.add_child(bg)

	# Border glow
	var border := ColorRect.new()
	border.name = "Border"
	border.size = Vector2(400, 200)
	border.color = Color(0, 0, 0, 0)  # Will be styled

	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_color = accent
	border_style.set_border_width_all(2)
	border_style.set_corner_radius_all(12)

	panel.add_child(border)

	# Title bar
	var title_bar := ColorRect.new()
	title_bar.size = Vector2(400, 50)
	title_bar.color = accent.darkened(0.6)
	panel.add_child(title_bar)

	# Title label
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 0)
	title_label.size = Vector2(400, 50)
	panel.add_child(title_label)

	# Type icon
	var icon := _create_type_icon(type, accent)
	icon.position = Vector2(20, 70)
	panel.add_child(icon)

	# Message
	var message_label := Label.new()
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	message_label.position = Vector2(70, 65)
	message_label.size = Vector2(310, 80)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(message_label)

	# Button container
	var button_container := HBoxContainer.new()
	button_container.position = Vector2(20, 155)
	button_container.size = Vector2(360, 40)
	button_container.alignment = BoxContainer.ALIGNMENT_END
	button_container.add_theme_constant_override("separation", 10)
	panel.add_child(button_container)

	# Create buttons
	for i in range(buttons.size()):
		var btn := _create_animated_button(buttons[i], i == buttons.size() - 1, accent)

		if i == buttons.size() - 1:  # Confirm button
			btn.pressed.connect(func():
				dialog_confirmed.emit(_current_dialog_id)
				_spawn_confirm_particles(accent)
				close_dialog()
			)
		else:  # Cancel button
			btn.pressed.connect(func():
				dialog_cancelled.emit(_current_dialog_id)
				close_dialog()
			)

		button_container.add_child(btn)

	panel.size = Vector2(400, 200)
	panel.pivot_offset = panel.size / 2

	return panel


func _create_type_icon(type: DialogType, color: Color) -> ColorRect:
	var icon := ColorRect.new()
	icon.size = Vector2(40, 40)
	icon.color = color

	# Different shapes for different types
	match type:
		DialogType.INFO:
			icon.color = ACCENT_COLOR
		DialogType.WARNING:
			icon.color = WARNING_COLOR
		DialogType.ERROR:
			icon.color = ERROR_COLOR
		_:
			icon.color = color

	return icon


func _create_animated_button(text: String, is_primary: bool, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 36)

	# Style
	var normal_style := StyleBoxFlat.new()
	normal_style.set_corner_radius_all(6)

	var hover_style := StyleBoxFlat.new()
	hover_style.set_corner_radius_all(6)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.set_corner_radius_all(6)

	if is_primary:
		normal_style.bg_color = accent
		hover_style.bg_color = accent.lightened(0.2)
		pressed_style.bg_color = accent.darkened(0.2)
	else:
		normal_style.bg_color = Color(0.25, 0.27, 0.32)
		hover_style.bg_color = Color(0.35, 0.37, 0.42)
		pressed_style.bg_color = Color(0.2, 0.22, 0.27)

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Glow overlay for hover effect
	var glow := ColorRect.new()
	glow.name = "GlowOverlay"
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var glow_mat := ShaderMaterial.new()
	var glow_shader := Shader.new()
	glow_shader.code = BUTTON_GLOW_SHADER
	glow_mat.shader = glow_shader
	glow_mat.set_shader_parameter("glow_color", BUTTON_HOVER_GLOW if is_primary else Color(0.5, 0.5, 0.5, 0.3))
	glow_mat.set_shader_parameter("glow_intensity", 0.0)
	glow.material = glow_mat

	btn.add_child(glow)

	# Connect hover signals
	btn.mouse_entered.connect(func():
		var tween := create_tween()
		tween.tween_method(
			func(v: float): glow_mat.set_shader_parameter("glow_intensity", v),
			0.0, 1.0, 0.2
		)
	)

	btn.mouse_exited.connect(func():
		var tween := create_tween()
		tween.tween_method(
			func(v: float): glow_mat.set_shader_parameter("glow_intensity", v),
			1.0, 0.0, 0.2
		)
	)

	return btn


func _show_input_dialog(id: String, title: String, message: String, placeholder: String, confirm_text: String, cancel_text: String) -> void:
	if _is_open:
		return

	_is_open = true
	_current_dialog_id = id
	visible = true

	# Create dialog with input field
	_current_dialog = Control.new()
	_current_dialog.custom_minimum_size = Vector2(450, 230)

	# Background
	var bg := ColorRect.new()
	bg.size = Vector2(450, 230)
	bg.color = Color(0.12, 0.14, 0.18)
	_current_dialog.add_child(bg)

	# Title bar
	var title_bar := ColorRect.new()
	title_bar.size = Vector2(450, 50)
	title_bar.color = ACCENT_COLOR.darkened(0.6)
	_current_dialog.add_child(title_bar)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size = Vector2(450, 50)
	_current_dialog.add_child(title_label)

	# Message
	var message_label := Label.new()
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	message_label.position = Vector2(20, 60)
	message_label.size = Vector2(410, 30)
	_current_dialog.add_child(message_label)

	# Input field
	var input := LineEdit.new()
	input.name = "InputField"
	input.placeholder_text = placeholder
	input.position = Vector2(20, 100)
	input.size = Vector2(410, 40)
	_current_dialog.add_child(input)

	# Buttons
	var button_container := HBoxContainer.new()
	button_container.position = Vector2(20, 180)
	button_container.size = Vector2(410, 40)
	button_container.alignment = BoxContainer.ALIGNMENT_END
	button_container.add_theme_constant_override("separation", 10)
	_current_dialog.add_child(button_container)

	var cancel_btn := _create_animated_button(cancel_text, false, ACCENT_COLOR)
	cancel_btn.pressed.connect(func():
		dialog_cancelled.emit(id)
		close_dialog()
	)
	button_container.add_child(cancel_btn)

	var confirm_btn := _create_animated_button(confirm_text, true, ACCENT_COLOR)
	confirm_btn.pressed.connect(func():
		dialog_confirmed.emit(id)
		# Input text can be retrieved via get_input_text()
		close_dialog()
	)
	button_container.add_child(confirm_btn)

	_current_dialog.size = Vector2(450, 230)
	_current_dialog.pivot_offset = _current_dialog.size / 2
	_current_dialog.position = -_current_dialog.size / 2

	_dialog_container.add_child(_current_dialog)

	await _animate_in()

	# Focus input field
	input.grab_focus()

	dialog_opened.emit(id)


func _show_custom_dialog(id: String, content: Control, buttons: Array[String]) -> void:
	if _is_open:
		return

	_is_open = true
	_current_dialog_id = id
	visible = true

	_current_dialog = Control.new()
	_current_dialog.add_child(content)

	# Add button container
	var button_container := HBoxContainer.new()
	button_container.position = Vector2(0, content.size.y + 10)
	button_container.size = Vector2(content.size.x, 40)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 10)
	_current_dialog.add_child(button_container)

	for i in range(buttons.size()):
		var btn := _create_animated_button(buttons[i], i == buttons.size() - 1, ACCENT_COLOR)
		btn.pressed.connect(func():
			if i == buttons.size() - 1:
				dialog_confirmed.emit(id)
			else:
				dialog_cancelled.emit(id)
			close_dialog()
		)
		button_container.add_child(btn)

	_current_dialog.size = Vector2(content.size.x, content.size.y + 60)
	_current_dialog.pivot_offset = _current_dialog.size / 2
	_current_dialog.position = -_current_dialog.size / 2

	_dialog_container.add_child(_current_dialog)

	await _animate_in()
	dialog_opened.emit(id)


# ============================================================================
# ANIMATIONS
# ============================================================================

func _animate_in() -> void:
	# Animate blur
	if blur_enabled and _blur_layer:
		var blur_mat := _blur_layer.material as ShaderMaterial
		var tween := create_tween()
		tween.tween_method(
			func(v: float): blur_mat.set_shader_parameter("blur_amount", v),
			0.0, blur_amount, animation_duration
		)

	# Animate dim
	var dim_tween := create_tween()
	dim_tween.tween_property(_dim_layer, "color:a", dim_amount, animation_duration)

	# Animate dialog with elastic scale
	_current_dialog.scale = Vector2(0.5, 0.5)
	_current_dialog.modulate.a = 0.0

	var dialog_tween := create_tween()
	dialog_tween.set_parallel(true)
	dialog_tween.set_ease(Tween.EASE_OUT)
	dialog_tween.set_trans(Tween.TRANS_ELASTIC)
	dialog_tween.tween_property(_current_dialog, "scale", Vector2(1.0, 1.0), animation_duration * 1.5)
	dialog_tween.tween_property(_current_dialog, "modulate:a", 1.0, animation_duration * 0.5)

	await dialog_tween.finished


func _animate_out() -> void:
	# Animate blur out
	if blur_enabled and _blur_layer:
		var blur_mat := _blur_layer.material as ShaderMaterial
		var tween := create_tween()
		tween.tween_method(
			func(v: float): blur_mat.set_shader_parameter("blur_amount", v),
			blur_amount, 0.0, animation_duration
		)

	# Animate dim out
	var dim_tween := create_tween()
	dim_tween.tween_property(_dim_layer, "color:a", 0.0, animation_duration)

	# Animate dialog out
	var dialog_tween := create_tween()
	dialog_tween.set_parallel(true)
	dialog_tween.set_ease(Tween.EASE_IN)
	dialog_tween.tween_property(_current_dialog, "scale", Vector2(0.8, 0.8), animation_duration)
	dialog_tween.tween_property(_current_dialog, "modulate:a", 0.0, animation_duration)

	await dialog_tween.finished


func _shake_dialog() -> void:
	if not _current_dialog:
		return

	var original_pos := _current_dialog.position
	var shake_intensity := 10.0

	# Flash red
	var bg: ColorRect = _current_dialog.get_node_or_null("Background")
	if bg:
		var original_color := bg.color
		bg.color = ERROR_COLOR.darkened(0.3)

		var color_tween := create_tween()
		color_tween.tween_property(bg, "color", original_color, 0.3)

	# Shake
	var tween := create_tween()
	for i in range(6):
		var offset := Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		tween.tween_property(_current_dialog, "position", original_pos + offset, 0.04)
		shake_intensity *= 0.8

	tween.tween_property(_current_dialog, "position", original_pos, 0.04)


func _spawn_confirm_particles(color: Color) -> void:
	if not _current_dialog:
		return

	var center := _current_dialog.global_position + _current_dialog.size / 2

	for i in range(20):
		var particle := ColorRect.new()
		var size := randf_range(5, 12)
		particle.size = Vector2(size, size)
		particle.position = center
		particle.color = color
		particle.pivot_offset = particle.size / 2.0

		_root.add_child(particle)

		var angle := randf() * TAU
		var distance := randf_range(50, 150)
		var target_pos := center + Vector2(cos(angle), sin(angle)) * distance

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_pos, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3).set_delay(0.1)
		tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.4)

		tween.chain().tween_callback(particle.queue_free)


func _cleanup_dialog() -> void:
	if _current_dialog:
		_current_dialog.queue_free()
		_current_dialog = null

	_is_open = false
	visible = false
	_current_dialog_id = ""


func _generate_id() -> String:
	return "dialog_%d" % Time.get_ticks_msec()


# ============================================================================
# UTILITY
# ============================================================================

## Get text from input dialog
func get_input_text() -> String:
	if not _current_dialog:
		return ""

	var input: LineEdit = _current_dialog.get_node_or_null("InputField")
	return input.text if input else ""


## Check if a dialog is open
func is_open() -> bool:
	return _is_open


## Get current dialog ID
func get_current_dialog_id() -> String:
	return _current_dialog_id
