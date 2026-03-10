## Premium Text Input - The most satisfying text input experience
## Features: floating labels, smooth cursor, character counter, validation, auto-complete
extends Control
class_name PremiumTextInput

## Emitted when text changes
signal text_changed(new_text: String)
## Emitted when text is submitted (Enter pressed)
signal text_submitted(text: String)
## Emitted when validation state changes
signal validation_changed(is_valid: bool)
## Emitted when auto-complete suggestion selected
signal suggestion_selected(suggestion: String)

# Visual configuration
@export var label_text: String = "Input Label":
	set(value):
		label_text = value
		if is_inside_tree():
			_floating_label.text = value

@export var placeholder_text: String = "Enter text...":
	set(value):
		placeholder_text = value
		if is_inside_tree():
			_placeholder_label.text = value

@export var max_characters: int = 100
@export var show_character_counter: bool = true
@export var enable_validation: bool = true
@export var validation_pattern: String = ""  # Regex pattern
@export var required: bool = false
@export var error_message: String = "Invalid input"
@export var success_message: String = "Looks good!"
@export var enable_autocomplete: bool = true

# Color scheme
@export_group("Colors")
@export var base_color: Color = Color(0.15, 0.15, 0.2, 1.0)
@export var focus_color: Color = Color(0.3, 0.5, 1.0, 1.0)
@export var success_color: Color = Color(0.2, 0.8, 0.4, 1.0)
@export var error_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var warning_color: Color = Color(1.0, 0.7, 0.2, 1.0)
@export var text_color: Color = Color.WHITE
@export var label_color: Color = Color(0.7, 0.7, 0.8, 1.0)

# Animation settings
@export_group("Animation")
@export var animation_duration: float = 0.25
@export var cursor_fade_duration: float = 0.4
@export var error_slide_duration: float = 0.3

# Auto-complete suggestions
var suggestions: Array[String] = []

# Internal nodes
var _container: Control
var _background: Panel
var _line_edit: LineEdit
var _floating_label: Label
var _placeholder_label: Label
var _character_counter: Label
var _validation_icon: Label
var _error_container: Control
var _error_label: Label
var _success_glow: Panel
var _autocomplete_popup: Control
var _autocomplete_list: VBoxContainer
var _cursor_blink_tween: Tween
var _underline: ColorRect

# State
var _is_focused: bool = false
var _is_valid: bool = true
var _has_content: bool = false
var _label_raised: bool = false
var _current_validation_state: int = 0  # 0: none, 1: valid, 2: invalid
var _showing_autocomplete: bool = false
var _selected_suggestion_index: int = -1

# Animation tweens
var _label_tween: Tween
var _placeholder_tween: Tween
var _border_tween: Tween
var _icon_tween: Tween
var _error_tween: Tween
var _glow_tween: Tween
var _autocomplete_tween: Tween


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_start_cursor_animation()


func _setup_ui() -> void:
	custom_minimum_size = Vector2(300, 70)

	# Main container
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_container)

	# Background panel
	_background = Panel.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.anchor_bottom = 0.85
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = base_color
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 0
	bg_style.corner_radius_bottom_right = 0
	_background.add_theme_stylebox_override("panel", bg_style)
	_container.add_child(_background)

	# Underline (animated border)
	_underline = ColorRect.new()
	_underline.anchor_top = 0.85
	_underline.anchor_bottom = 0.88
	_underline.anchor_left = 0.0
	_underline.anchor_right = 1.0
	_underline.offset_top = 0
	_underline.offset_bottom = 0
	_underline.color = label_color
	_container.add_child(_underline)

	# Success glow effect
	_success_glow = Panel.new()
	_success_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_success_glow.anchor_bottom = 0.85
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(0, 0, 0, 0)
	glow_style.border_width_left = 2
	glow_style.border_width_right = 2
	glow_style.border_width_top = 2
	glow_style.border_width_bottom = 2
	glow_style.border_color = success_color
	glow_style.corner_radius_top_left = 8
	glow_style.corner_radius_top_right = 8
	glow_style.shadow_color = Color(success_color.r, success_color.g, success_color.b, 0.0)
	glow_style.shadow_size = 10
	_success_glow.add_theme_stylebox_override("panel", glow_style)
	_success_glow.modulate.a = 0.0
	_container.add_child(_success_glow)

	# Floating label
	_floating_label = Label.new()
	_floating_label.text = label_text
	_floating_label.position = Vector2(12, 20)
	_floating_label.add_theme_color_override("font_color", label_color)
	_floating_label.add_theme_font_size_override("font_size", 16)
	_container.add_child(_floating_label)

	# Placeholder (fades when typing)
	_placeholder_label = Label.new()
	_placeholder_label.text = placeholder_text
	_placeholder_label.position = Vector2(12, 20)
	_placeholder_label.add_theme_color_override("font_color", Color(label_color.r, label_color.g, label_color.b, 0.5))
	_placeholder_label.add_theme_font_size_override("font_size", 16)
	_placeholder_label.visible = false
	_container.add_child(_placeholder_label)

	# Line edit (the actual input)
	_line_edit = LineEdit.new()
	_line_edit.anchor_left = 0.0
	_line_edit.anchor_right = 1.0
	_line_edit.anchor_top = 0.3
	_line_edit.anchor_bottom = 0.85
	_line_edit.offset_left = 10
	_line_edit.offset_right = -40
	_line_edit.max_length = max_characters
	_line_edit.placeholder_text = ""  # We use our own placeholder
	var line_style := StyleBoxEmpty.new()
	_line_edit.add_theme_stylebox_override("normal", line_style)
	_line_edit.add_theme_stylebox_override("focus", line_style)
	_line_edit.add_theme_color_override("font_color", text_color)
	_line_edit.add_theme_font_size_override("font_size", 16)
	_container.add_child(_line_edit)

	# Character counter
	_character_counter = Label.new()
	_character_counter.anchor_left = 1.0
	_character_counter.anchor_right = 1.0
	_character_counter.anchor_top = 0.88
	_character_counter.anchor_bottom = 1.0
	_character_counter.offset_left = -60
	_character_counter.offset_right = -5
	_character_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_character_counter.add_theme_color_override("font_color", label_color)
	_character_counter.add_theme_font_size_override("font_size", 12)
	_character_counter.text = "0/%d" % max_characters
	_character_counter.visible = show_character_counter
	_container.add_child(_character_counter)

	# Validation icon
	_validation_icon = Label.new()
	_validation_icon.anchor_left = 1.0
	_validation_icon.anchor_right = 1.0
	_validation_icon.anchor_top = 0.3
	_validation_icon.anchor_bottom = 0.85
	_validation_icon.offset_left = -35
	_validation_icon.offset_right = -5
	_validation_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_validation_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_validation_icon.add_theme_font_size_override("font_size", 20)
	_validation_icon.modulate.a = 0.0
	_container.add_child(_validation_icon)

	# Error container (slides in from bottom)
	_error_container = Control.new()
	_error_container.anchor_top = 1.0
	_error_container.anchor_bottom = 1.0
	_error_container.anchor_left = 0.0
	_error_container.anchor_right = 1.0
	_error_container.offset_top = 0
	_error_container.offset_bottom = 25
	_error_container.clip_contents = true
	_container.add_child(_error_container)

	_error_label = Label.new()
	_error_label.text = error_message
	_error_label.position = Vector2(5, 20)  # Starts below, slides up
	_error_label.add_theme_color_override("font_color", error_color)
	_error_label.add_theme_font_size_override("font_size", 12)
	_error_container.add_child(_error_label)

	# Auto-complete popup
	_setup_autocomplete_popup()


func _setup_autocomplete_popup() -> void:
	_autocomplete_popup = Control.new()
	_autocomplete_popup.anchor_top = 1.0
	_autocomplete_popup.anchor_left = 0.0
	_autocomplete_popup.anchor_right = 1.0
	_autocomplete_popup.offset_top = -10
	_autocomplete_popup.custom_minimum_size = Vector2(0, 150)
	_autocomplete_popup.visible = false
	_autocomplete_popup.z_index = 100
	add_child(_autocomplete_popup)

	var popup_bg := Panel.new()
	popup_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.12, 0.12, 0.16, 0.98)
	popup_style.corner_radius_bottom_left = 8
	popup_style.corner_radius_bottom_right = 8
	popup_style.shadow_color = Color(0, 0, 0, 0.3)
	popup_style.shadow_size = 5
	popup_bg.add_theme_stylebox_override("panel", popup_style)
	_autocomplete_popup.add_child(popup_bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 5
	scroll.offset_right = -5
	scroll.offset_top = 5
	scroll.offset_bottom = -5
	_autocomplete_popup.add_child(scroll)

	_autocomplete_list = VBoxContainer.new()
	_autocomplete_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_autocomplete_list)


func _connect_signals() -> void:
	_line_edit.focus_entered.connect(_on_focus_entered)
	_line_edit.focus_exited.connect(_on_focus_exited)
	_line_edit.text_changed.connect(_on_text_changed)
	_line_edit.text_submitted.connect(_on_text_submitted)


func _start_cursor_animation() -> void:
	# Custom cursor blink with fade effect
	_animate_cursor_fade()


func _animate_cursor_fade() -> void:
	if _cursor_blink_tween and _cursor_blink_tween.is_valid():
		_cursor_blink_tween.kill()

	_cursor_blink_tween = create_tween()
	_cursor_blink_tween.set_loops()

	# Fade out
	_cursor_blink_tween.tween_method(func(alpha: float) -> void:
		_line_edit.add_theme_color_override("caret_color", Color(text_color.r, text_color.g, text_color.b, alpha))
	, 1.0, 0.0, cursor_fade_duration)

	# Fade in
	_cursor_blink_tween.tween_method(func(alpha: float) -> void:
		_line_edit.add_theme_color_override("caret_color", Color(text_color.r, text_color.g, text_color.b, alpha))
	, 0.0, 1.0, cursor_fade_duration)


func _on_focus_entered() -> void:
	_is_focused = true
	_animate_label_up()
	_animate_border_focus(true)
	_show_placeholder(false)

	# Show autocomplete if we have suggestions
	if enable_autocomplete and suggestions.size() > 0:
		_update_autocomplete_suggestions(_line_edit.text)


func _on_focus_exited() -> void:
	_is_focused = false

	if not _has_content:
		_animate_label_down()

	_animate_border_focus(false)
	_hide_autocomplete()

	# Validate on blur
	if enable_validation:
		_validate_input()


func _on_text_changed(new_text: String) -> void:
	_has_content = new_text.length() > 0

	# Update character counter with color feedback
	_update_character_counter(new_text.length())

	# Fade placeholder
	if _has_content and _placeholder_label.visible:
		_fade_placeholder(false)

	# Real-time validation (soft)
	if enable_validation and new_text.length() > 0:
		_soft_validate(new_text)
	else:
		_clear_validation()

	# Update autocomplete
	if enable_autocomplete and _is_focused:
		_update_autocomplete_suggestions(new_text)

	text_changed.emit(new_text)


func _on_text_submitted(text: String) -> void:
	if enable_validation:
		_validate_input()

	if _is_valid:
		text_submitted.emit(text)


func _animate_label_up() -> void:
	if _label_raised:
		return

	_label_raised = true

	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()

	_label_tween = create_tween()
	_label_tween.set_parallel(true)
	_label_tween.set_ease(Tween.EASE_OUT)
	_label_tween.set_trans(Tween.TRANS_BACK)

	# Move up and scale down
	_label_tween.tween_property(_floating_label, "position", Vector2(8, 2), animation_duration)
	_label_tween.tween_property(_floating_label, "scale", Vector2(0.75, 0.75), animation_duration)

	# Change color to focus color
	_label_tween.tween_property(_floating_label, "modulate", focus_color, animation_duration)


func _animate_label_down() -> void:
	if not _label_raised:
		return

	_label_raised = false

	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()

	_label_tween = create_tween()
	_label_tween.set_parallel(true)
	_label_tween.set_ease(Tween.EASE_OUT)
	_label_tween.set_trans(Tween.TRANS_CUBIC)

	# Move down and scale up
	_label_tween.tween_property(_floating_label, "position", Vector2(12, 20), animation_duration)
	_label_tween.tween_property(_floating_label, "scale", Vector2.ONE, animation_duration)

	# Reset color
	_label_tween.tween_property(_floating_label, "modulate", Color.WHITE, animation_duration)


func _animate_border_focus(focused: bool) -> void:
	if _border_tween and _border_tween.is_valid():
		_border_tween.kill()

	_border_tween = create_tween()
	_border_tween.set_ease(Tween.EASE_OUT)
	_border_tween.set_trans(Tween.TRANS_CUBIC)

	var target_color: Color = focus_color if focused else label_color
	var target_height: float = 3.0 if focused else 2.0

	_border_tween.tween_property(_underline, "color", target_color, animation_duration)


func _show_placeholder(show: bool) -> void:
	_placeholder_label.visible = show
	_placeholder_label.modulate.a = 1.0 if show else 0.0


func _fade_placeholder(fade_in: bool) -> void:
	if _placeholder_tween and _placeholder_tween.is_valid():
		_placeholder_tween.kill()

	_placeholder_tween = create_tween()

	if fade_in:
		_placeholder_label.visible = true
		_placeholder_tween.tween_property(_placeholder_label, "modulate:a", 1.0, animation_duration * 0.5)
	else:
		_placeholder_tween.tween_property(_placeholder_label, "modulate:a", 0.0, animation_duration * 0.5)
		_placeholder_tween.tween_callback(func() -> void: _placeholder_label.visible = false)


func _update_character_counter(count: int) -> void:
	if not show_character_counter:
		return

	_character_counter.text = "%d/%d" % [count, max_characters]

	var ratio: float = float(count) / float(max_characters)
	var counter_color: Color

	if ratio >= 1.0:
		counter_color = error_color
	elif ratio >= 0.9:
		counter_color = warning_color
	elif ratio >= 0.75:
		counter_color = Color.YELLOW.lerp(warning_color, (ratio - 0.75) / 0.15)
	else:
		counter_color = label_color

	_character_counter.add_theme_color_override("font_color", counter_color)


func _soft_validate(text: String) -> void:
	# Soft validation while typing (just icon, no error message)
	var is_valid: bool = _check_validity(text)

	if is_valid and text.length() > 0:
		_show_validation_icon(true)
	elif not is_valid and text.length() > 2:  # Only show X after some typing
		_show_validation_icon(false)
	else:
		_clear_validation()


func _validate_input() -> void:
	var text: String = _line_edit.text
	_is_valid = _check_validity(text)

	if _is_valid:
		_show_success()
	else:
		_show_error()

	validation_changed.emit(_is_valid)


func _check_validity(text: String) -> bool:
	# Required check
	if required and text.strip_edges().is_empty():
		return false

	# Regex pattern check
	if validation_pattern.length() > 0:
		var regex := RegEx.new()
		if regex.compile(validation_pattern) == OK:
			return regex.search(text) != null

	return true


func _show_validation_icon(valid: bool) -> void:
	if _icon_tween and _icon_tween.is_valid():
		_icon_tween.kill()

	_validation_icon.text = "OK" if valid else "X"
	_validation_icon.add_theme_color_override("font_color", success_color if valid else error_color)

	_icon_tween = create_tween()
	_icon_tween.set_ease(Tween.EASE_OUT)
	_icon_tween.set_trans(Tween.TRANS_BACK)

	# Scale pop animation
	_validation_icon.scale = Vector2(0.5, 0.5)
	_validation_icon.pivot_offset = _validation_icon.size * 0.5

	_icon_tween.tween_property(_validation_icon, "modulate:a", 1.0, animation_duration * 0.5)
	_icon_tween.parallel().tween_property(_validation_icon, "scale", Vector2.ONE, animation_duration)


func _clear_validation() -> void:
	if _icon_tween and _icon_tween.is_valid():
		_icon_tween.kill()

	_icon_tween = create_tween()
	_icon_tween.tween_property(_validation_icon, "modulate:a", 0.0, animation_duration * 0.3)


func _show_error() -> void:
	_current_validation_state = 2

	# Update underline color
	_underline.color = error_color

	# Slide error message in from bottom
	if _error_tween and _error_tween.is_valid():
		_error_tween.kill()

	_error_label.text = error_message

	_error_tween = create_tween()
	_error_tween.set_ease(Tween.EASE_OUT)
	_error_tween.set_trans(Tween.TRANS_BACK)
	_error_tween.tween_property(_error_label, "position:y", 3.0, error_slide_duration)

	# Shake animation
	_shake_input()


func _show_success() -> void:
	_current_validation_state = 1

	# Update underline color
	_underline.color = success_color

	# Hide error if showing
	if _error_tween and _error_tween.is_valid():
		_error_tween.kill()
	_error_tween = create_tween()
	_error_tween.tween_property(_error_label, "position:y", 20.0, error_slide_duration * 0.5)

	# Show success glow
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()

	_glow_tween = create_tween()
	_glow_tween.tween_property(_success_glow, "modulate:a", 1.0, animation_duration)
	_glow_tween.tween_interval(0.5)
	_glow_tween.tween_property(_success_glow, "modulate:a", 0.3, animation_duration)


func _shake_input() -> void:
	var original_pos: Vector2 = _container.position
	var shake_tween: Tween = create_tween()

	shake_tween.tween_property(_container, "position:x", original_pos.x + 8, 0.05)
	shake_tween.tween_property(_container, "position:x", original_pos.x - 8, 0.05)
	shake_tween.tween_property(_container, "position:x", original_pos.x + 5, 0.05)
	shake_tween.tween_property(_container, "position:x", original_pos.x - 5, 0.05)
	shake_tween.tween_property(_container, "position:x", original_pos.x, 0.05)


func _update_autocomplete_suggestions(filter_text: String) -> void:
	# Clear existing suggestions
	for child in _autocomplete_list.get_children():
		child.queue_free()

	# Filter suggestions
	var filtered: Array[String] = []
	for suggestion in suggestions:
		if filter_text.is_empty() or suggestion.to_lower().begins_with(filter_text.to_lower()):
			filtered.append(suggestion)

	if filtered.is_empty():
		_hide_autocomplete()
		return

	# Add suggestion items
	for i in range(mini(filtered.size(), 5)):
		var suggestion: String = filtered[i]
		var item := _create_suggestion_item(suggestion, i)
		_autocomplete_list.add_child(item)

	_show_autocomplete()
	_selected_suggestion_index = -1


func _create_suggestion_item(text: String, index: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 35)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", focus_color)
	btn.add_theme_font_size_override("font_size", 14)

	# Hover style
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(focus_color.r, focus_color.g, focus_color.b, 0.2)
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.pressed.connect(func() -> void: _select_suggestion(text))
	btn.mouse_entered.connect(func() -> void: _selected_suggestion_index = index)

	return btn


func _select_suggestion(suggestion: String) -> void:
	_line_edit.text = suggestion
	_line_edit.caret_column = suggestion.length()
	_hide_autocomplete()
	_on_text_changed(suggestion)
	suggestion_selected.emit(suggestion)


func _show_autocomplete() -> void:
	if _showing_autocomplete:
		return

	_showing_autocomplete = true
	_autocomplete_popup.visible = true
	_autocomplete_popup.modulate.a = 0.0
	_autocomplete_popup.position.y = 0

	if _autocomplete_tween and _autocomplete_tween.is_valid():
		_autocomplete_tween.kill()

	_autocomplete_tween = create_tween()
	_autocomplete_tween.set_parallel(true)
	_autocomplete_tween.set_ease(Tween.EASE_OUT)
	_autocomplete_tween.set_trans(Tween.TRANS_BACK)
	_autocomplete_tween.tween_property(_autocomplete_popup, "modulate:a", 1.0, animation_duration)
	_autocomplete_tween.tween_property(_autocomplete_popup, "position:y", 10, animation_duration)


func _hide_autocomplete() -> void:
	if not _showing_autocomplete:
		return

	_showing_autocomplete = false

	if _autocomplete_tween and _autocomplete_tween.is_valid():
		_autocomplete_tween.kill()

	_autocomplete_tween = create_tween()
	_autocomplete_tween.tween_property(_autocomplete_popup, "modulate:a", 0.0, animation_duration * 0.5)
	_autocomplete_tween.tween_callback(func() -> void: _autocomplete_popup.visible = false)


# Public API
func get_text() -> String:
	return _line_edit.text


func set_text(text: String) -> void:
	_line_edit.text = text
	_on_text_changed(text)

	if text.length() > 0:
		_animate_label_up()


func clear() -> void:
	_line_edit.text = ""
	_has_content = false
	_clear_validation()
	_animate_label_down()
	_update_character_counter(0)


func set_suggestions(new_suggestions: Array[String]) -> void:
	suggestions = new_suggestions


func is_valid() -> bool:
	return _is_valid


func focus() -> void:
	_line_edit.grab_focus()


func set_error(message: String) -> void:
	error_message = message
	_is_valid = false
	_show_error()


func clear_error() -> void:
	_is_valid = true
	_current_validation_state = 0
	_underline.color = label_color

	if _error_tween and _error_tween.is_valid():
		_error_tween.kill()
	_error_tween = create_tween()
	_error_tween.tween_property(_error_label, "position:y", 20.0, error_slide_duration * 0.5)
