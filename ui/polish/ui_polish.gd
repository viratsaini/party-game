## UIPolish - Comprehensive UI polish and feedback system for BattleZone Party
##
## Ensures flawless UI through:
## - Consistent hover states for all buttons
## - Entrance/exit animations for all panels
## - Smooth transitions everywhere
## - No instant snaps
## - Consistent animation timing and easing
## - Interactive element feedback
## - Loading states everywhere
## - Friendly error states
## - Celebratory success states
##
## Usage:
##   UIPolish.apply_button_polish(button)
##   UIPolish.apply_panel_polish(panel)
##   UIPolish.show_loading_state(container)
##   UIPolish.show_success_state(container, "Achievement unlocked!")
class_name UIPolish
extends RefCounted


# =============================================================================
# region - Constants
# =============================================================================

## Standard animation timings
const TIMING_INSTANT: float = 0.0
const TIMING_FAST: float = 0.1
const TIMING_NORMAL: float = 0.2
const TIMING_SMOOTH: float = 0.3
const TIMING_SLOW: float = 0.5

## Hover scale
const HOVER_SCALE: float = 1.05
const PRESS_SCALE: float = 0.95

## Panel animation offsets
const PANEL_SLIDE_OFFSET: float = 50.0
const PANEL_SCALE_START: float = 0.9

## Feedback colors
const COLOR_SUCCESS: Color = Color(0.3, 0.9, 0.3)
const COLOR_ERROR: Color = Color(0.9, 0.3, 0.3)
const COLOR_WARNING: Color = Color(0.9, 0.7, 0.2)
const COLOR_INFO: Color = Color(0.3, 0.7, 0.9)

## Loading spinner
const LOADING_ROTATION_SPEED: float = 360.0  # degrees per second

# endregion


# =============================================================================
# region - Button Polish
# =============================================================================

## Applies comprehensive polish to a button
static func apply_button_polish(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return

	# Store original scale
	button.set_meta("original_scale", button.scale)
	button.set_meta("original_pivot", button.pivot_offset)

	# Set pivot to center
	button.pivot_offset = button.size / 2

	# Connect hover signals
	if not button.mouse_entered.is_connected(_on_button_hover_enter.bind(button)):
		button.mouse_entered.connect(_on_button_hover_enter.bind(button))
	if not button.mouse_exited.is_connected(_on_button_hover_exit.bind(button)):
		button.mouse_exited.connect(_on_button_hover_exit.bind(button))

	# Connect press signals
	if not button.button_down.is_connected(_on_button_press.bind(button)):
		button.button_down.connect(_on_button_press.bind(button))
	if not button.button_up.is_connected(_on_button_release.bind(button)):
		button.button_up.connect(_on_button_release.bind(button))

	# Connect focus signals for accessibility
	if not button.focus_entered.is_connected(_on_button_focus.bind(button)):
		button.focus_entered.connect(_on_button_focus.bind(button))
	if not button.focus_exited.is_connected(_on_button_unfocus.bind(button)):
		button.focus_exited.connect(_on_button_unfocus.bind(button))


static func _on_button_hover_enter(button: BaseButton) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), TIMING_FAST)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)

	# Play hover sound
	_play_ui_sound("hover")


static func _on_button_hover_exit(button: BaseButton) -> void:
	var original_scale: Vector2 = button.get_meta("original_scale", Vector2.ONE)
	var tween := button.create_tween()
	tween.tween_property(button, "scale", original_scale, TIMING_FAST)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)


static func _on_button_press(button: BaseButton) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), TIMING_FAST * 0.5)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_QUAD)

	# Play click sound
	_play_ui_sound("click")


static func _on_button_release(button: BaseButton) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), TIMING_NORMAL)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)


static func _on_button_focus(button: BaseButton) -> void:
	# Add focus glow effect
	var tween := button.create_tween()
	tween.tween_property(button, "modulate", Color(1.1, 1.1, 1.2), TIMING_FAST)


static func _on_button_unfocus(button: BaseButton) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "modulate", Color.WHITE, TIMING_FAST)


## Applies polish to all buttons in a container
static func apply_button_polish_recursive(container: Node) -> void:
	for child: Node in container.get_children():
		if child is BaseButton:
			apply_button_polish(child)
		if child.get_child_count() > 0:
			apply_button_polish_recursive(child)

# endregion


# =============================================================================
# region - Panel Polish
# =============================================================================

## Applies polish to a panel container
static func apply_panel_polish(panel: Control, entrance_direction: Vector2 = Vector2.DOWN) -> void:
	if not is_instance_valid(panel):
		return

	# Store original values
	panel.set_meta("original_position", panel.position)
	panel.set_meta("entrance_direction", entrance_direction)

	# Connect visibility changed
	if not panel.visibility_changed.is_connected(_on_panel_visibility_changed.bind(panel)):
		panel.visibility_changed.connect(_on_panel_visibility_changed.bind(panel))


static func _on_panel_visibility_changed(panel: Control) -> void:
	if panel.visible:
		animate_panel_entrance(panel)


## Animates a panel entrance
static func animate_panel_entrance(panel: Control, from_direction: Vector2 = Vector2.ZERO) -> Tween:
	if not is_instance_valid(panel):
		return null

	var direction: Vector2 = from_direction if from_direction != Vector2.ZERO else panel.get_meta("entrance_direction", Vector2.DOWN)
	var original_pos: Vector2 = panel.get_meta("original_position", panel.position)

	# Set initial state
	panel.position = original_pos + direction * PANEL_SLIDE_OFFSET
	panel.scale = Vector2(PANEL_SCALE_START, PANEL_SCALE_START)
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2

	# Animate entrance
	var tween := panel.create_tween()
	tween.set_parallel(true)

	tween.tween_property(panel, "position", original_pos, TIMING_SMOOTH)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)

	tween.tween_property(panel, "scale", Vector2.ONE, TIMING_SMOOTH)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)

	tween.tween_property(panel, "modulate:a", 1.0, TIMING_NORMAL)\
		.set_ease(Tween.EASE_OUT)

	_play_ui_sound("panel_open")

	return tween


## Animates a panel exit
static func animate_panel_exit(panel: Control, to_direction: Vector2 = Vector2.ZERO, hide_after: bool = true) -> Tween:
	if not is_instance_valid(panel):
		return null

	var direction: Vector2 = to_direction if to_direction != Vector2.ZERO else panel.get_meta("entrance_direction", Vector2.DOWN)
	var target_pos: Vector2 = panel.position + direction * PANEL_SLIDE_OFFSET

	panel.pivot_offset = panel.size / 2

	var tween := panel.create_tween()
	tween.set_parallel(true)

	tween.tween_property(panel, "position", target_pos, TIMING_NORMAL)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_CUBIC)

	tween.tween_property(panel, "scale", Vector2(PANEL_SCALE_START, PANEL_SCALE_START), TIMING_NORMAL)\
		.set_ease(Tween.EASE_IN)

	tween.tween_property(panel, "modulate:a", 0.0, TIMING_FAST)

	if hide_after:
		tween.chain().tween_callback(func(): panel.visible = false)

	_play_ui_sound("panel_close")

	return tween

# endregion


# =============================================================================
# region - Loading States
# =============================================================================

## Shows a loading state in a container
static func show_loading_state(container: Control, message: String = "Loading...") -> Control:
	if not is_instance_valid(container):
		return null

	# Create loading overlay
	var overlay := ColorRect.new()
	overlay.name = "LoadingOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.1, 0.1, 0.15, 0.9)
	overlay.modulate.a = 0.0

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	overlay.add_child(vbox)

	# Spinner
	var spinner := _create_loading_spinner()
	vbox.add_child(spinner)

	# Message
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(label)

	container.add_child(overlay)

	# Fade in
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, TIMING_NORMAL)

	return overlay


## Hides a loading state
static func hide_loading_state(container: Control) -> void:
	var overlay := container.get_node_or_null("LoadingOverlay")
	if overlay:
		var tween := overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 0.0, TIMING_FAST)
		tween.tween_callback(overlay.queue_free)


static func _create_loading_spinner() -> Control:
	var spinner := Control.new()
	spinner.custom_minimum_size = Vector2(48, 48)

	var circle := ColorRect.new()
	circle.name = "SpinnerCircle"
	circle.custom_minimum_size = Vector2(48, 48)
	circle.size = Vector2(48, 48)
	circle.pivot_offset = Vector2(24, 24)
	spinner.add_child(circle)

	# Start spinning animation
	spinner.ready.connect(func():
		var tween := circle.create_tween()
		tween.set_loops()
		tween.tween_property(circle, "rotation_degrees", 360.0, 1.0)\
			.from(0.0)\
			.set_ease(Tween.EASE_IN_OUT)\
			.set_trans(Tween.TRANS_LINEAR)
	)

	return spinner

# endregion


# =============================================================================
# region - Success States
# =============================================================================

## Shows a success celebration state
static func show_success_state(container: Control, message: String = "Success!", duration: float = 2.0) -> Control:
	if not is_instance_valid(container):
		return null

	var overlay := ColorRect.new()
	overlay.name = "SuccessOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(COLOR_SUCCESS.r, COLOR_SUCCESS.g, COLOR_SUCCESS.b, 0.1)
	overlay.modulate.a = 0.0

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	overlay.add_child(vbox)

	# Checkmark icon (using text as placeholder)
	var icon := Label.new()
	icon.text = "!"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 48)
	icon.add_theme_color_override("font_color", COLOR_SUCCESS)
	icon.scale = Vector2.ZERO
	vbox.add_child(icon)

	# Message
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", COLOR_SUCCESS)
	label.modulate.a = 0.0
	vbox.add_child(label)

	container.add_child(overlay)

	# Animate entrance
	var tween := container.create_tween()
	tween.set_parallel(true)

	tween.tween_property(overlay, "modulate:a", 1.0, TIMING_FAST)
	tween.tween_property(icon, "scale", Vector2.ONE, TIMING_SMOOTH)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_ELASTIC)

	tween.chain().tween_property(label, "modulate:a", 1.0, TIMING_NORMAL)

	# Auto-hide after duration
	tween.chain().tween_interval(duration)
	tween.chain().tween_property(overlay, "modulate:a", 0.0, TIMING_NORMAL)
	tween.chain().tween_callback(overlay.queue_free)

	_play_ui_sound("success")

	return overlay


## Shows a celebratory victory state
static func show_victory_celebration(container: Control, title: String = "Victory!", subtitle: String = "") -> Control:
	if not is_instance_valid(container):
		return null

	var overlay := ColorRect.new()
	overlay.name = "VictoryOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.05, 0.1, 0.95)
	overlay.modulate.a = 0.0

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 20)
	overlay.add_child(vbox)

	# Title
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_label.scale = Vector2.ZERO
	vbox.add_child(title_label)

	# Subtitle
	if not subtitle.is_empty():
		var sub_label := Label.new()
		sub_label.text = subtitle
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", 24)
		sub_label.add_theme_color_override("font_color", Color.WHITE)
		sub_label.modulate.a = 0.0
		vbox.add_child(sub_label)

	container.add_child(overlay)

	# Epic entrance animation
	var tween := container.create_tween()

	tween.tween_property(overlay, "modulate:a", 1.0, TIMING_NORMAL)
	tween.tween_property(title_label, "scale", Vector2(1.2, 1.2), TIMING_SLOW)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(title_label, "scale", Vector2.ONE, TIMING_NORMAL)\
		.set_ease(Tween.EASE_IN_OUT)

	if vbox.get_child_count() > 1:
		var sub_label: Label = vbox.get_child(1) as Label
		tween.tween_property(sub_label, "modulate:a", 1.0, TIMING_SMOOTH)

	_play_ui_sound("victory")

	return overlay

# endregion


# =============================================================================
# region - Error States
# =============================================================================

## Shows an error state
static func show_error_state(container: Control, message: String = "An error occurred", retry_callback: Callable = Callable()) -> Control:
	if not is_instance_valid(container):
		return null

	var overlay := ColorRect.new()
	overlay.name = "ErrorOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.15, 0.1, 0.1, 0.95)
	overlay.modulate.a = 0.0

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 16)
	overlay.add_child(vbox)

	# Error icon
	var icon := Label.new()
	icon.text = "X"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 48)
	icon.add_theme_color_override("font_color", COLOR_ERROR)
	vbox.add_child(icon)

	# Message
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 300
	vbox.add_child(label)

	# Retry button if callback provided
	if retry_callback.is_valid():
		var retry_btn := Button.new()
		retry_btn.text = "Try Again"
		retry_btn.custom_minimum_size = Vector2(120, 44)
		retry_btn.pressed.connect(func():
			hide_error_state(container)
			retry_callback.call()
		)
		vbox.add_child(retry_btn)
		apply_button_polish(retry_btn)

	container.add_child(overlay)

	# Shake animation for error emphasis
	var tween := container.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, TIMING_FAST)

	# Shake the icon
	tween.chain()
	for i in range(3):
		tween.tween_property(icon, "position:x", icon.position.x + 10, 0.05)
		tween.tween_property(icon, "position:x", icon.position.x - 10, 0.05)
	tween.tween_property(icon, "position:x", icon.position.x, 0.05)

	_play_ui_sound("error")

	return overlay


## Hides an error state
static func hide_error_state(container: Control) -> void:
	var overlay := container.get_node_or_null("ErrorOverlay")
	if overlay:
		var tween := overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 0.0, TIMING_FAST)
		tween.tween_callback(overlay.queue_free)

# endregion


# =============================================================================
# region - Transition Helpers
# =============================================================================

## Fades a control in
static func fade_in(control: CanvasItem, duration: float = TIMING_NORMAL) -> Tween:
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, duration)\
		.set_ease(Tween.EASE_OUT)
	return tween


## Fades a control out
static func fade_out(control: CanvasItem, duration: float = TIMING_NORMAL, hide_after: bool = false) -> Tween:
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 0.0, duration)\
		.set_ease(Tween.EASE_IN)
	if hide_after:
		tween.tween_callback(func(): control.visible = false)
	return tween


## Slides a control in from a direction
static func slide_in(control: Control, from_direction: Vector2, duration: float = TIMING_SMOOTH) -> Tween:
	var target_pos: Vector2 = control.position
	control.position = target_pos + from_direction * 100
	control.modulate.a = 0.0

	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "position", target_pos, duration)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.5)
	return tween


## Slides a control out to a direction
static func slide_out(control: Control, to_direction: Vector2, duration: float = TIMING_NORMAL, hide_after: bool = false) -> Tween:
	var target_pos: Vector2 = control.position + to_direction * 100

	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "position", target_pos, duration)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)

	if hide_after:
		tween.chain().tween_callback(func(): control.visible = false)
	return tween


## Scales a control in with bounce
static func scale_in(control: Control, duration: float = TIMING_SMOOTH) -> Tween:
	control.pivot_offset = control.size / 2
	control.scale = Vector2.ZERO
	control.modulate.a = 0.0

	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, duration)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.5)
	return tween


## Scales a control out
static func scale_out(control: Control, duration: float = TIMING_NORMAL, hide_after: bool = false) -> Tween:
	control.pivot_offset = control.size / 2

	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ZERO, duration)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_BACK)
	tween.tween_property(control, "modulate:a", 0.0, duration)

	if hide_after:
		tween.chain().tween_callback(func(): control.visible = false)
	return tween

# endregion


# =============================================================================
# region - Sound Helpers
# =============================================================================

static func _play_ui_sound(sound_name: String) -> void:
	# Try to play via AudioManager if available
	var audio_manager := Engine.get_singleton("AudioManager") if Engine.has_singleton("AudioManager") else null

	if audio_manager and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("ui_" + sound_name)
	else:
		# Fallback: try to find AudioManager autoload
		var root := Engine.get_main_loop()
		if root is SceneTree:
			var manager := root.root.get_node_or_null("AudioManager")
			if manager and manager.has_method("play_sfx"):
				manager.play_sfx("ui_" + sound_name)

# endregion


# =============================================================================
# region - Utility Functions
# =============================================================================

## Applies all polish to a container and its children
static func apply_full_polish(container: Node) -> void:
	for child: Node in container.get_children():
		if child is BaseButton:
			apply_button_polish(child)
		elif child is PanelContainer:
			apply_panel_polish(child)

		if child.get_child_count() > 0:
			apply_full_polish(child)


## Creates a pulsing glow effect
static func add_pulse_effect(control: Control, color: Color = COLOR_INFO, intensity: float = 0.3) -> Tween:
	var tween := control.create_tween()
	tween.set_loops()

	var original_modulate: Color = control.modulate
	var pulse_modulate := Color(
		original_modulate.r + color.r * intensity,
		original_modulate.g + color.g * intensity,
		original_modulate.b + color.b * intensity,
		original_modulate.a
	)

	tween.tween_property(control, "modulate", pulse_modulate, 0.5)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate", original_modulate, 0.5)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)

	return tween


## Removes pulse effect
static func remove_pulse_effect(control: Control) -> void:
	# Kill any running tweens and reset modulate
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", Color.WHITE, TIMING_FAST)

# endregion
