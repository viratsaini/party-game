## AccessibilityManager - Comprehensive accessibility system for BattleZone Party.
##
## Provides visual, audio, input, and cognitive accessibility features to ensure
## the game is playable by everyone regardless of ability. This autoload singleton
## manages all accessibility settings and coordinates with other systems.
extends Node

# -- Signals --

## Emitted when any accessibility setting changes.
signal settings_changed
## Emitted when colorblind mode changes.
signal colorblind_mode_changed(mode: ColorblindMode)
## Emitted when UI scale changes.
signal ui_scale_changed(scale: float)
## Emitted when reduce motion setting changes.
signal reduce_motion_changed(enabled: bool)
## Emitted when high contrast mode changes.
signal high_contrast_changed(enabled: bool)
## Emitted when screen reader speaks.
signal screen_reader_spoke(text: String)
## Emitted when focus changes (for screen reader).
signal focus_changed(element: Control)
## Emitted when a setting needs audio feedback.
signal audio_feedback_requested(feedback_type: String)

# -- Constants --

const SETTINGS_PATH: String = "user://accessibility_settings.cfg"
const MIN_UI_SCALE: float = 0.8
const MAX_UI_SCALE: float = 1.5
const DEFAULT_UI_SCALE: float = 1.0

# -- Enums --

## Colorblind filter modes.
enum ColorblindMode {
	NONE,
	DEUTERANOPIA,  ## Red-green (most common)
	PROTANOPIA,    ## Red-green (red weakness)
	TRITANOPIA,    ## Blue-yellow
	ACHROMATOPSIA  ## Complete color blindness (grayscale)
}

## Text size presets.
enum TextSizePreset {
	SMALL,
	NORMAL,
	LARGE,
	EXTRA_LARGE
}

## Animation speed presets.
enum AnimationSpeed {
	OFF,      ## No animations
	SLOW,     ## 50% speed
	NORMAL,   ## 100% speed
	FAST      ## 150% speed
}

## Input mode types.
enum InputMode {
	STANDARD,
	ONE_HANDED_LEFT,
	ONE_HANDED_RIGHT,
	CONTROLLER_ONLY,
	KEYBOARD_ONLY,
	TOUCH_ONLY
}

## UI complexity levels.
enum UIComplexity {
	FULL,       ## All elements shown
	SIMPLIFIED, ## Essential elements only
	MINIMAL     ## Bare minimum for gameplay
}

## Focus indicator styles.
enum FocusIndicatorStyle {
	OUTLINE,
	BACKGROUND,
	BOTH,
	HIGH_VISIBILITY
}

# -- Visual Accessibility Settings --

## Current colorblind mode.
var colorblind_mode: ColorblindMode = ColorblindMode.NONE:
	set(value):
		colorblind_mode = value
		colorblind_mode_changed.emit(value)
		settings_changed.emit()

## High contrast mode enabled.
var high_contrast_enabled: bool = false:
	set(value):
		high_contrast_enabled = value
		high_contrast_changed.emit(value)
		settings_changed.emit()

## Large text mode enabled.
var large_text_enabled: bool = false:
	set(value):
		large_text_enabled = value
		_apply_text_size()
		settings_changed.emit()

## Text size preset.
var text_size_preset: TextSizePreset = TextSizePreset.NORMAL:
	set(value):
		text_size_preset = value
		_apply_text_size()
		settings_changed.emit()

## UI scale factor (0.8 - 1.5).
var ui_scale: float = DEFAULT_UI_SCALE:
	set(value):
		ui_scale = clampf(value, MIN_UI_SCALE, MAX_UI_SCALE)
		ui_scale_changed.emit(ui_scale)
		settings_changed.emit()

## Reduce motion (disables non-essential animations).
var reduce_motion: bool = false:
	set(value):
		reduce_motion = value
		reduce_motion_changed.emit(value)
		settings_changed.emit()

## Screen flash reduction.
var reduce_screen_flash: bool = false:
	set(value):
		reduce_screen_flash = value
		settings_changed.emit()

## Flash intensity multiplier (0.0 - 1.0, lower = less intense).
var flash_intensity: float = 1.0:
	set(value):
		flash_intensity = clampf(value, 0.0, 1.0)
		settings_changed.emit()

## Simplified UI mode.
var simplified_ui: bool = false:
	set(value):
		simplified_ui = value
		settings_changed.emit()

## UI complexity level.
var ui_complexity: UIComplexity = UIComplexity.FULL:
	set(value):
		ui_complexity = value
		settings_changed.emit()

## Show outlines around important UI elements.
var show_ui_outlines: bool = false:
	set(value):
		show_ui_outlines = value
		settings_changed.emit()

## Increase contrast of text against backgrounds.
var enhanced_text_contrast: bool = false:
	set(value):
		enhanced_text_contrast = value
		settings_changed.emit()

## Cursor size multiplier.
var cursor_scale: float = 1.0:
	set(value):
		cursor_scale = clampf(value, 0.5, 3.0)
		settings_changed.emit()

## Custom cursor color (for visibility).
var cursor_color: Color = Color.WHITE:
	set(value):
		cursor_color = value
		settings_changed.emit()

# -- Audio Accessibility Settings --

## Subtitles enabled for all audio.
var subtitles_enabled: bool = false:
	set(value):
		subtitles_enabled = value
		settings_changed.emit()

## Subtitle text size multiplier.
var subtitle_size: float = 1.0:
	set(value):
		subtitle_size = clampf(value, 0.5, 2.0)
		settings_changed.emit()

## Subtitle background opacity.
var subtitle_background_opacity: float = 0.7:
	set(value):
		subtitle_background_opacity = clampf(value, 0.0, 1.0)
		settings_changed.emit()

## Speaker identification in subtitles.
var subtitle_speaker_labels: bool = true:
	set(value):
		subtitle_speaker_labels = value
		settings_changed.emit()

## Visual sound indicators enabled (show icons for sounds).
var visual_sound_indicators: bool = false:
	set(value):
		visual_sound_indicators = value
		settings_changed.emit()

## Mono audio mode (combines L/R channels).
var mono_audio: bool = false:
	set(value):
		mono_audio = value
		_apply_mono_audio()
		settings_changed.emit()

## Audio balance (-1.0 = left, 0.0 = center, 1.0 = right).
var audio_balance: float = 0.0:
	set(value):
		audio_balance = clampf(value, -1.0, 1.0)
		_apply_audio_balance()
		settings_changed.emit()

## Enhanced audio (boost important gameplay sounds).
var enhanced_audio: bool = false:
	set(value):
		enhanced_audio = value
		settings_changed.emit()

## Screen reader support enabled.
var screen_reader_enabled: bool = false:
	set(value):
		screen_reader_enabled = value
		settings_changed.emit()

## Text-to-speech for menus.
var text_to_speech_enabled: bool = false:
	set(value):
		text_to_speech_enabled = value
		settings_changed.emit()

## TTS speech rate.
var tts_speech_rate: float = 1.0:
	set(value):
		tts_speech_rate = clampf(value, 0.5, 2.0)
		settings_changed.emit()

## TTS voice pitch.
var tts_pitch: float = 1.0:
	set(value):
		tts_pitch = clampf(value, 0.5, 2.0)
		settings_changed.emit()

# -- Input Accessibility Settings --

## Keyboard navigation enabled.
var keyboard_navigation: bool = true:
	set(value):
		keyboard_navigation = value
		settings_changed.emit()

## Controller support enabled.
var controller_support: bool = true:
	set(value):
		controller_support = value
		settings_changed.emit()

## One-handed mode enabled.
var one_handed_mode: bool = false:
	set(value):
		one_handed_mode = value
		settings_changed.emit()

## Input mode selection.
var input_mode: InputMode = InputMode.STANDARD:
	set(value):
		input_mode = value
		settings_changed.emit()

## Touch hold duration in seconds before action triggers.
var touch_hold_duration: float = 0.4:
	set(value):
		touch_hold_duration = clampf(value, 0.1, 2.0)
		settings_changed.emit()

## Double-tap prevention window in seconds.
var double_tap_prevention_time: float = 0.3:
	set(value):
		double_tap_prevention_time = clampf(value, 0.0, 1.0)
		settings_changed.emit()

## Enable double-tap prevention.
var double_tap_prevention: bool = false:
	set(value):
		double_tap_prevention = value
		settings_changed.emit()

## Auto-pause when window loses focus.
var auto_pause_on_focus_loss: bool = true:
	set(value):
		auto_pause_on_focus_loss = value
		settings_changed.emit()

## Sticky keys enabled (for modifier keys).
var sticky_keys: bool = false:
	set(value):
		sticky_keys = value
		settings_changed.emit()

## Key repeat delay in seconds.
var key_repeat_delay: float = 0.5:
	set(value):
		key_repeat_delay = clampf(value, 0.1, 2.0)
		settings_changed.emit()

## Key repeat rate (repeats per second).
var key_repeat_rate: float = 10.0:
	set(value):
		key_repeat_rate = clampf(value, 1.0, 30.0)
		settings_changed.emit()

## Controller vibration enabled.
var controller_vibration: bool = true:
	set(value):
		controller_vibration = value
		settings_changed.emit()

## Controller vibration intensity.
var vibration_intensity: float = 1.0:
	set(value):
		vibration_intensity = clampf(value, 0.0, 1.0)
		settings_changed.emit()

# -- Cognitive Accessibility Settings --

## Simplified language mode.
var simplified_language: bool = false:
	set(value):
		simplified_language = value
		settings_changed.emit()

## Icon-only mode (replace text with icons where possible).
var icon_only_mode: bool = false:
	set(value):
		icon_only_mode = value
		settings_changed.emit()

## Tutorial can be skipped but re-watched.
var allow_tutorial_skip: bool = true:
	set(value):
		allow_tutorial_skip = value
		settings_changed.emit()

## Tutorial progress tracking.
var tutorials_completed: Array[String] = []

## Animation speed multiplier.
var animation_speed: AnimationSpeed = AnimationSpeed.NORMAL:
	set(value):
		animation_speed = value
		settings_changed.emit()

## Animation speed multiplier value.
var animation_speed_multiplier: float = 1.0:
	get:
		match animation_speed:
			AnimationSpeed.OFF: return 0.0
			AnimationSpeed.SLOW: return 0.5
			AnimationSpeed.NORMAL: return 1.0
			AnimationSpeed.FAST: return 1.5
			_: return 1.0

## Reduce visual clutter (hide non-essential effects).
var reduce_visual_clutter: bool = false:
	set(value):
		reduce_visual_clutter = value
		settings_changed.emit()

## Focus indicator style.
var focus_indicator_style: FocusIndicatorStyle = FocusIndicatorStyle.OUTLINE:
	set(value):
		focus_indicator_style = value
		settings_changed.emit()

## Focus indicator color.
var focus_indicator_color: Color = Color(1.0, 0.8, 0.0, 1.0):  # Yellow
	set(value):
		focus_indicator_color = value
		settings_changed.emit()

## Confirmation dialogs for important actions.
var confirm_important_actions: bool = true:
	set(value):
		confirm_important_actions = value
		settings_changed.emit()

## Reading time multiplier for timed text.
var reading_time_multiplier: float = 1.0:
	set(value):
		reading_time_multiplier = clampf(value, 0.5, 5.0)
		settings_changed.emit()

## Auto-advance dialogs/tutorials.
var auto_advance_dialogs: bool = false:
	set(value):
		auto_advance_dialogs = value
		settings_changed.emit()

## Show timer warnings earlier.
var extended_timer_warnings: bool = false:
	set(value):
		extended_timer_warnings = value
		settings_changed.emit()

## Dyslexia-friendly font enabled.
var dyslexia_friendly_font: bool = false:
	set(value):
		dyslexia_friendly_font = value
		settings_changed.emit()

## Extra line spacing for readability.
var increased_line_spacing: bool = false:
	set(value):
		increased_line_spacing = value
		settings_changed.emit()

# -- Internal State --

var _colorblind_filter: CanvasLayer = null
var _current_focus: Control = null
var _focus_history: Array[Control] = []
var _last_input_time: Dictionary = {}  # For double-tap prevention
var _sticky_modifiers: Dictionary = {
	"shift": false,
	"ctrl": false,
	"alt": false
}

# -- Lifecycle --

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_colorblind_filter()
	load_settings()
	_connect_signals()

	# Apply initial settings
	call_deferred("_apply_all_settings")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if auto_pause_on_focus_loss and is_inside_tree():
			get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if auto_pause_on_focus_loss and is_inside_tree():
			# Don't auto-unpause - let the user do it
			pass


func _input(event: InputEvent) -> void:
	if keyboard_navigation:
		_handle_keyboard_navigation(event)

	if double_tap_prevention:
		_handle_double_tap_prevention(event)

	if sticky_keys:
		_handle_sticky_keys(event)


func _connect_signals() -> void:
	# Connect to viewport focus changes
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)


# -- Colorblind Filter Management --

func _setup_colorblind_filter() -> void:
	# Create a CanvasLayer for the colorblind filter
	_colorblind_filter = CanvasLayer.new()
	_colorblind_filter.name = "ColorblindFilter"
	_colorblind_filter.layer = 100  # Above everything
	add_child(_colorblind_filter)

	# The actual filter shader will be applied when needed
	colorblind_mode_changed.connect(_apply_colorblind_filter)


func _apply_colorblind_filter(_mode: ColorblindMode) -> void:
	# Clear existing filter
	for child in _colorblind_filter.get_children():
		child.queue_free()

	if colorblind_mode == ColorblindMode.NONE:
		return

	# Create a ColorRect with the appropriate shader
	var filter_rect := ColorRect.new()
	filter_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Apply the shader based on mode
	var shader_material := ShaderMaterial.new()
	shader_material.shader = _create_colorblind_shader(colorblind_mode)
	filter_rect.material = shader_material

	_colorblind_filter.add_child(filter_rect)


func _create_colorblind_shader(mode: ColorblindMode) -> Shader:
	var shader := Shader.new()
	var shader_code: String

	match mode:
		ColorblindMode.DEUTERANOPIA:
			shader_code = _get_deuteranopia_shader()
		ColorblindMode.PROTANOPIA:
			shader_code = _get_protanopia_shader()
		ColorblindMode.TRITANOPIA:
			shader_code = _get_tritanopia_shader()
		ColorblindMode.ACHROMATOPSIA:
			shader_code = _get_achromatopsia_shader()
		_:
			shader_code = "shader_type canvas_item;\nvoid fragment() { COLOR = texture(TEXTURE, UV); }"

	shader.code = shader_code
	return shader


func _get_deuteranopia_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Deuteranopia simulation matrix
	float r = color.r * 0.625 + color.g * 0.375;
	float g = color.r * 0.7 + color.g * 0.3;
	float b = color.b * 0.3 + color.g * 0.7;

	COLOR = vec4(r, g, b, color.a);
}
"""


func _get_protanopia_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Protanopia simulation matrix
	float r = color.r * 0.567 + color.g * 0.433;
	float g = color.r * 0.558 + color.g * 0.442;
	float b = color.b * 0.242 + color.g * 0.758;

	COLOR = vec4(r, g, b, color.a);
}
"""


func _get_tritanopia_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Tritanopia simulation matrix
	float r = color.r * 0.95 + color.g * 0.05;
	float g = color.g * 0.433 + color.b * 0.567;
	float b = color.r * 0.475 + color.b * 0.525;

	COLOR = vec4(r, g, b, color.a);
}
"""


func _get_achromatopsia_shader() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Grayscale conversion using luminance
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));

	COLOR = vec4(vec3(gray), color.a);
}
"""


# -- Audio Accessibility --

func _apply_mono_audio() -> void:
	# Godot doesn't have built-in mono audio, but we can work around it
	# by adjusting the audio bus panning
	if mono_audio:
		# Set all audio to center (mono)
		_set_global_panning(0.0)
	else:
		_set_global_panning(audio_balance)


func _apply_audio_balance() -> void:
	if not mono_audio:
		_set_global_panning(audio_balance)


func _set_global_panning(pan: float) -> void:
	# This would adjust the master bus panning
	# In practice, you'd need to modify individual audio players or use bus effects
	pass


# -- Input Accessibility --

func _handle_keyboard_navigation(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed:
		return

	match key_event.keycode:
		KEY_TAB:
			if key_event.shift_pressed:
				_focus_previous()
			else:
				_focus_next()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_SPACE:
			if _current_focus and _current_focus.has_method("_pressed"):
				_current_focus._pressed()
			elif _current_focus is BaseButton:
				(_current_focus as BaseButton).emit_signal("pressed")
		KEY_ESCAPE:
			_focus_back()


func _focus_next() -> void:
	var focusables := _get_focusable_controls()
	if focusables.is_empty():
		return

	var current_idx := focusables.find(_current_focus)
	var next_idx := (current_idx + 1) % focusables.size()
	focusables[next_idx].grab_focus()


func _focus_previous() -> void:
	var focusables := _get_focusable_controls()
	if focusables.is_empty():
		return

	var current_idx := focusables.find(_current_focus)
	var prev_idx := current_idx - 1
	if prev_idx < 0:
		prev_idx = focusables.size() - 1
	focusables[prev_idx].grab_focus()


func _focus_back() -> void:
	if _focus_history.size() > 1:
		_focus_history.pop_back()
		var previous := _focus_history.pop_back()
		if is_instance_valid(previous):
			previous.grab_focus()


func _get_focusable_controls() -> Array[Control]:
	var result: Array[Control] = []
	_collect_focusable_controls(get_tree().root, result)
	return result


func _collect_focusable_controls(node: Node, result: Array[Control]) -> void:
	if node is Control:
		var ctrl := node as Control
		if ctrl.visible and ctrl.focus_mode != Control.FOCUS_NONE:
			result.append(ctrl)

	for child in node.get_children():
		_collect_focusable_controls(child, result)


func _handle_double_tap_prevention(event: InputEvent) -> void:
	if not event is InputEventMouseButton and not event is InputEventScreenTouch:
		return

	var event_id: String = ""
	var pressed := false

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		event_id = "mouse_%d" % mb.button_index
		pressed = mb.pressed
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		event_id = "touch_%d" % st.index
		pressed = st.pressed

	if not pressed:
		return

	var current_time := Time.get_ticks_msec() / 1000.0

	if _last_input_time.has(event_id):
		var last_time: float = _last_input_time[event_id]
		if current_time - last_time < double_tap_prevention_time:
			# Block this input - it's a double tap
			get_viewport().set_input_as_handled()
			return

	_last_input_time[event_id] = current_time


func _handle_sticky_keys(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	# Check for modifier key releases to toggle sticky state
	if not key_event.pressed:
		match key_event.keycode:
			KEY_SHIFT:
				_sticky_modifiers["shift"] = not _sticky_modifiers["shift"]
			KEY_CTRL:
				_sticky_modifiers["ctrl"] = not _sticky_modifiers["ctrl"]
			KEY_ALT:
				_sticky_modifiers["alt"] = not _sticky_modifiers["alt"]


## Check if a sticky modifier is active.
func is_sticky_modifier_active(modifier: String) -> bool:
	return _sticky_modifiers.get(modifier, false)


## Clear all sticky modifiers.
func clear_sticky_modifiers() -> void:
	_sticky_modifiers = {
		"shift": false,
		"ctrl": false,
		"alt": false
	}


# -- Focus Management --

func _on_gui_focus_changed(control: Control) -> void:
	_current_focus = control

	if control != null:
		_focus_history.append(control)
		# Limit history size
		if _focus_history.size() > 20:
			_focus_history.remove_at(0)

		focus_changed.emit(control)

		# Announce to screen reader if enabled
		if screen_reader_enabled or text_to_speech_enabled:
			_announce_focus(control)


func _announce_focus(control: Control) -> void:
	var announcement := ""

	if control is Button:
		var btn := control as Button
		announcement = "%s button" % btn.text
	elif control is Label:
		var lbl := control as Label
		announcement = lbl.text
	elif control is LineEdit:
		var le := control as LineEdit
		announcement = "%s text field" % le.placeholder_text if le.placeholder_text else "Text field"
	elif control is CheckBox:
		var cb := control as CheckBox
		var state := "checked" if cb.button_pressed else "unchecked"
		announcement = "%s checkbox, %s" % [cb.text, state]
	elif control is Slider:
		var slider := control as Slider
		announcement = "Slider, value %d percent" % int((slider.value - slider.min_value) / (slider.max_value - slider.min_value) * 100)
	else:
		# Generic fallback
		if control.has_meta("accessibility_label"):
			announcement = control.get_meta("accessibility_label")
		else:
			announcement = control.name

	if not announcement.is_empty():
		speak(announcement)


## Speak text using text-to-speech.
func speak(text: String, interrupt: bool = true) -> void:
	if not text_to_speech_enabled and not screen_reader_enabled:
		return

	screen_reader_spoke.emit(text)

	# Use Godot's built-in TTS if available
	if DisplayServer.tts_is_speaking() and interrupt:
		DisplayServer.tts_stop()

	DisplayServer.tts_speak(text, "", int(tts_speech_rate * 100), tts_pitch)


## Stop any currently speaking TTS.
func stop_speaking() -> void:
	DisplayServer.tts_stop()


# -- Text Size Management --

func _apply_text_size() -> void:
	var scale_factor := 1.0

	match text_size_preset:
		TextSizePreset.SMALL:
			scale_factor = 0.85
		TextSizePreset.NORMAL:
			scale_factor = 1.0
		TextSizePreset.LARGE:
			scale_factor = 1.25
		TextSizePreset.EXTRA_LARGE:
			scale_factor = 1.5

	if large_text_enabled:
		scale_factor *= 1.25

	# Apply to theme or project settings
	# This would need to be implemented based on your theme system


func _apply_all_settings() -> void:
	_apply_colorblind_filter(colorblind_mode)
	_apply_text_size()
	_apply_mono_audio()
	_apply_audio_balance()


# -- Tutorial Management --

## Mark a tutorial as completed.
func complete_tutorial(tutorial_id: String) -> void:
	if tutorial_id not in tutorials_completed:
		tutorials_completed.append(tutorial_id)
		save_settings()


## Check if a tutorial has been completed.
func is_tutorial_completed(tutorial_id: String) -> bool:
	return tutorial_id in tutorials_completed


## Reset tutorial progress (allow re-watching).
func reset_tutorial(tutorial_id: String) -> void:
	tutorials_completed.erase(tutorial_id)
	save_settings()


## Reset all tutorials.
func reset_all_tutorials() -> void:
	tutorials_completed.clear()
	save_settings()


# -- Utility Functions --

## Get the current text scale factor based on settings.
func get_text_scale_factor() -> float:
	var scale := 1.0

	match text_size_preset:
		TextSizePreset.SMALL: scale = 0.85
		TextSizePreset.NORMAL: scale = 1.0
		TextSizePreset.LARGE: scale = 1.25
		TextSizePreset.EXTRA_LARGE: scale = 1.5

	if large_text_enabled:
		scale *= 1.25

	return scale * ui_scale


## Check if animations should be played.
func should_play_animation() -> bool:
	return animation_speed != AnimationSpeed.OFF and not reduce_motion


## Get the duration multiplier for animations.
func get_animation_duration_multiplier() -> float:
	if reduce_motion or animation_speed == AnimationSpeed.OFF:
		return 0.0

	return 1.0 / animation_speed_multiplier


## Check if an effect should be shown (respects reduce visual clutter).
func should_show_effect(effect_type: String) -> bool:
	if reduce_visual_clutter:
		# Only show essential effects
		var essential_effects := ["damage", "heal", "death", "respawn", "pickup"]
		return effect_type in essential_effects
	return true


## Get modified flash intensity.
func get_flash_intensity() -> float:
	if reduce_screen_flash:
		return flash_intensity * 0.3
	return flash_intensity


## Check if confirmation dialog should be shown for an action.
func should_confirm_action(action_type: String) -> bool:
	if not confirm_important_actions:
		return false

	var important_actions := [
		"quit_game",
		"leave_match",
		"delete_save",
		"reset_settings",
		"purchase",
		"spend_currency"
	]

	return action_type in important_actions


## Get reading time for text (accounting for user multiplier).
func get_reading_time(text: String) -> float:
	# Average reading speed is about 200 words per minute
	var word_count := text.split(" ").size()
	var base_time := float(word_count) / 200.0 * 60.0  # Convert to seconds
	return base_time * reading_time_multiplier


## Apply focus indicator to a control.
func apply_focus_indicator(control: Control) -> void:
	match focus_indicator_style:
		FocusIndicatorStyle.OUTLINE:
			# Apply outline stylebox
			var stylebox := StyleBoxFlat.new()
			stylebox.draw_center = false
			stylebox.border_width_left = 3
			stylebox.border_width_right = 3
			stylebox.border_width_top = 3
			stylebox.border_width_bottom = 3
			stylebox.border_color = focus_indicator_color
			control.add_theme_stylebox_override("focus", stylebox)

		FocusIndicatorStyle.BACKGROUND:
			var stylebox := StyleBoxFlat.new()
			stylebox.bg_color = Color(focus_indicator_color.r, focus_indicator_color.g, focus_indicator_color.b, 0.3)
			control.add_theme_stylebox_override("focus", stylebox)

		FocusIndicatorStyle.BOTH, FocusIndicatorStyle.HIGH_VISIBILITY:
			var stylebox := StyleBoxFlat.new()
			stylebox.bg_color = Color(focus_indicator_color.r, focus_indicator_color.g, focus_indicator_color.b, 0.3)
			stylebox.border_width_left = 4 if focus_indicator_style == FocusIndicatorStyle.HIGH_VISIBILITY else 3
			stylebox.border_width_right = 4 if focus_indicator_style == FocusIndicatorStyle.HIGH_VISIBILITY else 3
			stylebox.border_width_top = 4 if focus_indicator_style == FocusIndicatorStyle.HIGH_VISIBILITY else 3
			stylebox.border_width_bottom = 4 if focus_indicator_style == FocusIndicatorStyle.HIGH_VISIBILITY else 3
			stylebox.border_color = focus_indicator_color
			control.add_theme_stylebox_override("focus", stylebox)


## Get controller vibration intensity (0 if disabled).
func get_vibration_intensity() -> float:
	if not controller_vibration:
		return 0.0
	return vibration_intensity


## Vibrate controller with accessibility scaling.
func vibrate_controller(duration: float = 0.2, strong: float = 0.5, weak: float = 0.3) -> void:
	if not controller_vibration:
		return

	var intensity := get_vibration_intensity()
	Input.start_joy_vibration(0, strong * intensity, weak * intensity, duration)


# -- Persistence --

## Save all accessibility settings to disk.
func save_settings() -> void:
	var cfg := ConfigFile.new()

	# Visual
	cfg.set_value("visual", "colorblind_mode", colorblind_mode)
	cfg.set_value("visual", "high_contrast_enabled", high_contrast_enabled)
	cfg.set_value("visual", "large_text_enabled", large_text_enabled)
	cfg.set_value("visual", "text_size_preset", text_size_preset)
	cfg.set_value("visual", "ui_scale", ui_scale)
	cfg.set_value("visual", "reduce_motion", reduce_motion)
	cfg.set_value("visual", "reduce_screen_flash", reduce_screen_flash)
	cfg.set_value("visual", "flash_intensity", flash_intensity)
	cfg.set_value("visual", "simplified_ui", simplified_ui)
	cfg.set_value("visual", "ui_complexity", ui_complexity)
	cfg.set_value("visual", "show_ui_outlines", show_ui_outlines)
	cfg.set_value("visual", "enhanced_text_contrast", enhanced_text_contrast)
	cfg.set_value("visual", "cursor_scale", cursor_scale)
	cfg.set_value("visual", "cursor_color", cursor_color)

	# Audio
	cfg.set_value("audio", "subtitles_enabled", subtitles_enabled)
	cfg.set_value("audio", "subtitle_size", subtitle_size)
	cfg.set_value("audio", "subtitle_background_opacity", subtitle_background_opacity)
	cfg.set_value("audio", "subtitle_speaker_labels", subtitle_speaker_labels)
	cfg.set_value("audio", "visual_sound_indicators", visual_sound_indicators)
	cfg.set_value("audio", "mono_audio", mono_audio)
	cfg.set_value("audio", "audio_balance", audio_balance)
	cfg.set_value("audio", "enhanced_audio", enhanced_audio)
	cfg.set_value("audio", "screen_reader_enabled", screen_reader_enabled)
	cfg.set_value("audio", "text_to_speech_enabled", text_to_speech_enabled)
	cfg.set_value("audio", "tts_speech_rate", tts_speech_rate)
	cfg.set_value("audio", "tts_pitch", tts_pitch)

	# Input
	cfg.set_value("input", "keyboard_navigation", keyboard_navigation)
	cfg.set_value("input", "controller_support", controller_support)
	cfg.set_value("input", "one_handed_mode", one_handed_mode)
	cfg.set_value("input", "input_mode", input_mode)
	cfg.set_value("input", "touch_hold_duration", touch_hold_duration)
	cfg.set_value("input", "double_tap_prevention", double_tap_prevention)
	cfg.set_value("input", "double_tap_prevention_time", double_tap_prevention_time)
	cfg.set_value("input", "auto_pause_on_focus_loss", auto_pause_on_focus_loss)
	cfg.set_value("input", "sticky_keys", sticky_keys)
	cfg.set_value("input", "key_repeat_delay", key_repeat_delay)
	cfg.set_value("input", "key_repeat_rate", key_repeat_rate)
	cfg.set_value("input", "controller_vibration", controller_vibration)
	cfg.set_value("input", "vibration_intensity", vibration_intensity)

	# Cognitive
	cfg.set_value("cognitive", "simplified_language", simplified_language)
	cfg.set_value("cognitive", "icon_only_mode", icon_only_mode)
	cfg.set_value("cognitive", "allow_tutorial_skip", allow_tutorial_skip)
	cfg.set_value("cognitive", "tutorials_completed", tutorials_completed)
	cfg.set_value("cognitive", "animation_speed", animation_speed)
	cfg.set_value("cognitive", "reduce_visual_clutter", reduce_visual_clutter)
	cfg.set_value("cognitive", "focus_indicator_style", focus_indicator_style)
	cfg.set_value("cognitive", "focus_indicator_color", focus_indicator_color)
	cfg.set_value("cognitive", "confirm_important_actions", confirm_important_actions)
	cfg.set_value("cognitive", "reading_time_multiplier", reading_time_multiplier)
	cfg.set_value("cognitive", "auto_advance_dialogs", auto_advance_dialogs)
	cfg.set_value("cognitive", "extended_timer_warnings", extended_timer_warnings)
	cfg.set_value("cognitive", "dyslexia_friendly_font", dyslexia_friendly_font)
	cfg.set_value("cognitive", "increased_line_spacing", increased_line_spacing)

	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("AccessibilityManager: Failed to save settings - error %d" % err)


## Load accessibility settings from disk.
func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)

	if err != OK:
		# File doesn't exist yet, use defaults
		return

	# Visual
	colorblind_mode = cfg.get_value("visual", "colorblind_mode", colorblind_mode)
	high_contrast_enabled = cfg.get_value("visual", "high_contrast_enabled", high_contrast_enabled)
	large_text_enabled = cfg.get_value("visual", "large_text_enabled", large_text_enabled)
	text_size_preset = cfg.get_value("visual", "text_size_preset", text_size_preset)
	ui_scale = cfg.get_value("visual", "ui_scale", ui_scale)
	reduce_motion = cfg.get_value("visual", "reduce_motion", reduce_motion)
	reduce_screen_flash = cfg.get_value("visual", "reduce_screen_flash", reduce_screen_flash)
	flash_intensity = cfg.get_value("visual", "flash_intensity", flash_intensity)
	simplified_ui = cfg.get_value("visual", "simplified_ui", simplified_ui)
	ui_complexity = cfg.get_value("visual", "ui_complexity", ui_complexity)
	show_ui_outlines = cfg.get_value("visual", "show_ui_outlines", show_ui_outlines)
	enhanced_text_contrast = cfg.get_value("visual", "enhanced_text_contrast", enhanced_text_contrast)
	cursor_scale = cfg.get_value("visual", "cursor_scale", cursor_scale)
	cursor_color = cfg.get_value("visual", "cursor_color", cursor_color)

	# Audio
	subtitles_enabled = cfg.get_value("audio", "subtitles_enabled", subtitles_enabled)
	subtitle_size = cfg.get_value("audio", "subtitle_size", subtitle_size)
	subtitle_background_opacity = cfg.get_value("audio", "subtitle_background_opacity", subtitle_background_opacity)
	subtitle_speaker_labels = cfg.get_value("audio", "subtitle_speaker_labels", subtitle_speaker_labels)
	visual_sound_indicators = cfg.get_value("audio", "visual_sound_indicators", visual_sound_indicators)
	mono_audio = cfg.get_value("audio", "mono_audio", mono_audio)
	audio_balance = cfg.get_value("audio", "audio_balance", audio_balance)
	enhanced_audio = cfg.get_value("audio", "enhanced_audio", enhanced_audio)
	screen_reader_enabled = cfg.get_value("audio", "screen_reader_enabled", screen_reader_enabled)
	text_to_speech_enabled = cfg.get_value("audio", "text_to_speech_enabled", text_to_speech_enabled)
	tts_speech_rate = cfg.get_value("audio", "tts_speech_rate", tts_speech_rate)
	tts_pitch = cfg.get_value("audio", "tts_pitch", tts_pitch)

	# Input
	keyboard_navigation = cfg.get_value("input", "keyboard_navigation", keyboard_navigation)
	controller_support = cfg.get_value("input", "controller_support", controller_support)
	one_handed_mode = cfg.get_value("input", "one_handed_mode", one_handed_mode)
	input_mode = cfg.get_value("input", "input_mode", input_mode)
	touch_hold_duration = cfg.get_value("input", "touch_hold_duration", touch_hold_duration)
	double_tap_prevention = cfg.get_value("input", "double_tap_prevention", double_tap_prevention)
	double_tap_prevention_time = cfg.get_value("input", "double_tap_prevention_time", double_tap_prevention_time)
	auto_pause_on_focus_loss = cfg.get_value("input", "auto_pause_on_focus_loss", auto_pause_on_focus_loss)
	sticky_keys = cfg.get_value("input", "sticky_keys", sticky_keys)
	key_repeat_delay = cfg.get_value("input", "key_repeat_delay", key_repeat_delay)
	key_repeat_rate = cfg.get_value("input", "key_repeat_rate", key_repeat_rate)
	controller_vibration = cfg.get_value("input", "controller_vibration", controller_vibration)
	vibration_intensity = cfg.get_value("input", "vibration_intensity", vibration_intensity)

	# Cognitive
	simplified_language = cfg.get_value("cognitive", "simplified_language", simplified_language)
	icon_only_mode = cfg.get_value("cognitive", "icon_only_mode", icon_only_mode)
	allow_tutorial_skip = cfg.get_value("cognitive", "allow_tutorial_skip", allow_tutorial_skip)
	tutorials_completed = cfg.get_value("cognitive", "tutorials_completed", tutorials_completed)
	animation_speed = cfg.get_value("cognitive", "animation_speed", animation_speed)
	reduce_visual_clutter = cfg.get_value("cognitive", "reduce_visual_clutter", reduce_visual_clutter)
	focus_indicator_style = cfg.get_value("cognitive", "focus_indicator_style", focus_indicator_style)
	focus_indicator_color = cfg.get_value("cognitive", "focus_indicator_color", focus_indicator_color)
	confirm_important_actions = cfg.get_value("cognitive", "confirm_important_actions", confirm_important_actions)
	reading_time_multiplier = cfg.get_value("cognitive", "reading_time_multiplier", reading_time_multiplier)
	auto_advance_dialogs = cfg.get_value("cognitive", "auto_advance_dialogs", auto_advance_dialogs)
	extended_timer_warnings = cfg.get_value("cognitive", "extended_timer_warnings", extended_timer_warnings)
	dyslexia_friendly_font = cfg.get_value("cognitive", "dyslexia_friendly_font", dyslexia_friendly_font)
	increased_line_spacing = cfg.get_value("cognitive", "increased_line_spacing", increased_line_spacing)


## Reset all settings to defaults.
func reset_to_defaults() -> void:
	# Visual
	colorblind_mode = ColorblindMode.NONE
	high_contrast_enabled = false
	large_text_enabled = false
	text_size_preset = TextSizePreset.NORMAL
	ui_scale = DEFAULT_UI_SCALE
	reduce_motion = false
	reduce_screen_flash = false
	flash_intensity = 1.0
	simplified_ui = false
	ui_complexity = UIComplexity.FULL
	show_ui_outlines = false
	enhanced_text_contrast = false
	cursor_scale = 1.0
	cursor_color = Color.WHITE

	# Audio
	subtitles_enabled = false
	subtitle_size = 1.0
	subtitle_background_opacity = 0.7
	subtitle_speaker_labels = true
	visual_sound_indicators = false
	mono_audio = false
	audio_balance = 0.0
	enhanced_audio = false
	screen_reader_enabled = false
	text_to_speech_enabled = false
	tts_speech_rate = 1.0
	tts_pitch = 1.0

	# Input
	keyboard_navigation = true
	controller_support = true
	one_handed_mode = false
	input_mode = InputMode.STANDARD
	touch_hold_duration = 0.4
	double_tap_prevention = false
	double_tap_prevention_time = 0.3
	auto_pause_on_focus_loss = true
	sticky_keys = false
	key_repeat_delay = 0.5
	key_repeat_rate = 10.0
	controller_vibration = true
	vibration_intensity = 1.0

	# Cognitive
	simplified_language = false
	icon_only_mode = false
	allow_tutorial_skip = true
	animation_speed = AnimationSpeed.NORMAL
	reduce_visual_clutter = false
	focus_indicator_style = FocusIndicatorStyle.OUTLINE
	focus_indicator_color = Color(1.0, 0.8, 0.0, 1.0)
	confirm_important_actions = true
	reading_time_multiplier = 1.0
	auto_advance_dialogs = false
	extended_timer_warnings = false
	dyslexia_friendly_font = false
	increased_line_spacing = false

	save_settings()
