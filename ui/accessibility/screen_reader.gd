## ScreenReader - Comprehensive screen reader and text-to-speech support.
##
## Provides full screen reader functionality including element announcements,
## navigation feedback, visual sound indicators, and subtitle display.
## Works with Godot's built-in TTS and provides fallback options.
extends CanvasLayer

# -- Signals --

## Emitted when speech starts.
signal speech_started(text: String)
## Emitted when speech ends.
signal speech_ended
## Emitted when a sound indicator is shown.
signal sound_indicator_shown(sound_type: String, direction: float)
## Emitted when subtitles are updated.
signal subtitles_updated(text: String, speaker: String)

# -- Constants --

const SUBTITLE_DISPLAY_TIME: float = 4.0
const SOUND_INDICATOR_DURATION: float = 1.5
const MAX_SPEECH_QUEUE_SIZE: int = 10
const ANNOUNCEMENT_PRIORITIES: Dictionary = {
	"critical": 0,
	"high": 1,
	"normal": 2,
	"low": 3
}

# -- Enums --

## Sound types for visual indicators.
enum SoundType {
	GUNSHOT,
	EXPLOSION,
	FOOTSTEP,
	VOICE,
	PICKUP,
	ALERT,
	UI,
	AMBIENT,
	DAMAGE,
	HEAL,
	ENEMY,
	TEAMMATE
}

## Subtitle positioning options.
enum SubtitlePosition {
	BOTTOM,
	TOP,
	CUSTOM
}

# -- Exported Properties --

## Enable screen reader functionality.
@export var enabled: bool = true:
	set(value):
		enabled = value
		_update_visibility()

## Enable text-to-speech.
@export var tts_enabled: bool = true

## TTS speech rate (0.5 - 2.0).
@export_range(0.5, 2.0) var speech_rate: float = 1.0

## TTS pitch (0.5 - 2.0).
@export_range(0.5, 2.0) var pitch: float = 1.0

## TTS volume (0.0 - 1.0).
@export_range(0.0, 1.0) var volume: float = 1.0

## Enable subtitles.
@export var subtitles_enabled: bool = true

## Subtitle text size multiplier.
@export_range(0.5, 2.0) var subtitle_size: float = 1.0

## Subtitle background opacity.
@export_range(0.0, 1.0) var subtitle_background_opacity: float = 0.7

## Show speaker names in subtitles.
@export var show_speaker_labels: bool = true

## Subtitle position.
@export var subtitle_position: SubtitlePosition = SubtitlePosition.BOTTOM

## Enable visual sound indicators.
@export var sound_indicators_enabled: bool = true

## Sound indicator size.
@export_range(0.5, 2.0) var indicator_size: float = 1.0

## Announce all focus changes.
@export var announce_focus_changes: bool = true

## Announce UI state changes (checkboxes, sliders, etc.).
@export var announce_state_changes: bool = true

## Read button hints.
@export var read_button_hints: bool = true

# -- Internal State --

var _subtitle_container: PanelContainer = null
var _subtitle_label: RichTextLabel = null
var _sound_indicator_container: Control = null
var _active_indicators: Array[Control] = []

var _speech_queue: Array[Dictionary] = []
var _is_speaking: bool = false
var _current_speech: String = ""

var _subtitle_timer: Timer = null
var _current_subtitle_speaker: String = ""

var _focused_element: Control = null
var _last_announced_text: String = ""

# Sound indicator textures/shapes
var _indicator_icons: Dictionary = {}


# -- Lifecycle --

func _ready() -> void:
	layer = 99  # High layer for accessibility UI
	_setup_subtitle_display()
	_setup_sound_indicators()
	_setup_timers()
	_load_indicator_icons()
	_connect_signals()
	_update_visibility()


func _process(_delta: float) -> void:
	if not enabled:
		return

	# Process speech queue
	if not _is_speaking and not _speech_queue.is_empty():
		_process_next_speech()

	# Update speaking status
	if _is_speaking and not DisplayServer.tts_is_speaking():
		_on_speech_finished()


func _connect_signals() -> void:
	# Connect to viewport focus changes
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


# -- Setup Methods --

func _setup_subtitle_display() -> void:
	# Create subtitle container
	_subtitle_container = PanelContainer.new()
	_subtitle_container.name = "SubtitleContainer"
	_subtitle_container.visible = false

	# Style the container
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, subtitle_background_opacity)
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_subtitle_container.add_theme_stylebox_override("panel", style)

	# Create subtitle label
	_subtitle_label = RichTextLabel.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.bbcode_enabled = true
	_subtitle_label.fit_content = true
	_subtitle_label.scroll_active = false
	_subtitle_label.custom_minimum_size = Vector2(400, 0)
	_subtitle_label.add_theme_font_size_override("normal_font_size", int(24 * subtitle_size))
	_subtitle_label.add_theme_color_override("default_color", Color.WHITE)
	_subtitle_container.add_child(_subtitle_label)

	add_child(_subtitle_container)
	_update_subtitle_position()


func _setup_sound_indicators() -> void:
	_sound_indicator_container = Control.new()
	_sound_indicator_container.name = "SoundIndicators"
	_sound_indicator_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sound_indicator_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sound_indicator_container)


func _setup_timers() -> void:
	_subtitle_timer = Timer.new()
	_subtitle_timer.name = "SubtitleTimer"
	_subtitle_timer.one_shot = true
	_subtitle_timer.timeout.connect(_on_subtitle_timeout)
	add_child(_subtitle_timer)


func _load_indicator_icons() -> void:
	# In production, load actual icon textures
	# For now, we'll use procedurally generated shapes
	pass


func _update_visibility() -> void:
	if _subtitle_container:
		_subtitle_container.visible = enabled and subtitles_enabled and _subtitle_label.text != ""
	if _sound_indicator_container:
		_sound_indicator_container.visible = enabled and sound_indicators_enabled


func _update_subtitle_position() -> void:
	if not _subtitle_container:
		return

	var viewport_size := get_viewport().get_visible_rect().size

	match subtitle_position:
		SubtitlePosition.BOTTOM:
			_subtitle_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			_subtitle_container.position.y = -100
		SubtitlePosition.TOP:
			_subtitle_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
			_subtitle_container.position.y = 50
		SubtitlePosition.CUSTOM:
			# Allow manual positioning
			pass


# -- Public API: Text-to-Speech --

## Speak text with TTS.
func speak(text: String, priority: String = "normal", interrupt: bool = false) -> void:
	if not enabled or not tts_enabled:
		return

	if text.is_empty():
		return

	if interrupt:
		stop_speaking()
		_speech_queue.clear()

	# Add to queue with priority
	var priority_value: int = ANNOUNCEMENT_PRIORITIES.get(priority, 2)
	var speech_data := {
		"text": text,
		"priority": priority_value,
		"timestamp": Time.get_ticks_msec()
	}

	# Insert based on priority
	var insert_index := _speech_queue.size()
	for i: int in _speech_queue.size():
		if priority_value < (_speech_queue[i]["priority"] as int):
			insert_index = i
			break

	_speech_queue.insert(insert_index, speech_data)

	# Limit queue size
	while _speech_queue.size() > MAX_SPEECH_QUEUE_SIZE:
		_speech_queue.pop_back()


## Stop current speech.
func stop_speaking() -> void:
	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	_is_speaking = false
	_current_speech = ""
	speech_ended.emit()


## Check if currently speaking.
func is_speaking() -> bool:
	return _is_speaking or DisplayServer.tts_is_speaking()


## Announce a UI element.
func announce_element(element: Control, include_hints: bool = true) -> void:
	if not enabled:
		return

	var announcement := _build_element_announcement(element, include_hints)
	if announcement != _last_announced_text:
		_last_announced_text = announcement
		speak(announcement)


## Announce a custom message.
func announce(text: String, priority: String = "normal") -> void:
	speak(text, priority)


## Announce a critical message (interrupts current speech).
func announce_critical(text: String) -> void:
	speak(text, "critical", true)


# -- Public API: Subtitles --

## Show a subtitle.
func show_subtitle(text: String, speaker: String = "", duration: float = -1.0) -> void:
	if not enabled or not subtitles_enabled:
		return

	if duration < 0:
		duration = SUBTITLE_DISPLAY_TIME

	_current_subtitle_speaker = speaker

	var display_text := ""
	if show_speaker_labels and not speaker.is_empty():
		display_text = "[b][color=#FFD700]%s:[/color][/b] %s" % [speaker, text]
	else:
		display_text = text

	_subtitle_label.text = display_text
	_subtitle_label.add_theme_font_size_override("normal_font_size", int(24 * subtitle_size))
	_subtitle_container.visible = true

	_subtitle_timer.stop()
	_subtitle_timer.start(duration)

	subtitles_updated.emit(text, speaker)


## Hide current subtitle.
func hide_subtitle() -> void:
	_subtitle_container.visible = false
	_subtitle_label.text = ""
	_current_subtitle_speaker = ""


## Update subtitle settings.
func update_subtitle_settings(size: float, bg_opacity: float, show_speakers: bool) -> void:
	subtitle_size = size
	subtitle_background_opacity = bg_opacity
	show_speaker_labels = show_speakers

	if _subtitle_container:
		var style := _subtitle_container.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.bg_color.a = bg_opacity

	if _subtitle_label:
		_subtitle_label.add_theme_font_size_override("normal_font_size", int(24 * size))


# -- Public API: Sound Indicators --

## Show a visual sound indicator.
func show_sound_indicator(sound_type: SoundType, world_position: Vector3, intensity: float = 1.0) -> void:
	if not enabled or not sound_indicators_enabled:
		return

	# Calculate direction from player/camera to sound
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var camera_pos := camera.global_position
	var direction := (world_position - camera_pos).normalized()

	# Project to 2D screen space (as a direction indicator)
	var angle := atan2(direction.x, direction.z)
	var screen_center := get_viewport().get_visible_rect().size / 2.0

	# Create indicator
	var indicator := _create_sound_indicator(sound_type, angle, intensity)
	_sound_indicator_container.add_child(indicator)
	_active_indicators.append(indicator)

	# Animate and remove
	var tween := create_tween()
	tween.tween_property(indicator, "modulate:a", 0.0, SOUND_INDICATOR_DURATION)
	tween.tween_callback(func():
		_active_indicators.erase(indicator)
		indicator.queue_free()
	)

	sound_indicator_shown.emit(_get_sound_type_name(sound_type), angle)


## Show a directional sound indicator (2D angle).
func show_directional_indicator(sound_type: SoundType, angle: float, intensity: float = 1.0) -> void:
	if not enabled or not sound_indicators_enabled:
		return

	var indicator := _create_sound_indicator(sound_type, angle, intensity)
	_sound_indicator_container.add_child(indicator)
	_active_indicators.append(indicator)

	var tween := create_tween()
	tween.tween_property(indicator, "modulate:a", 0.0, SOUND_INDICATOR_DURATION)
	tween.tween_callback(func():
		_active_indicators.erase(indicator)
		indicator.queue_free()
	)


## Clear all sound indicators.
func clear_sound_indicators() -> void:
	for indicator: Control in _active_indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	_active_indicators.clear()


# -- Internal Methods --

func _process_next_speech() -> void:
	if _speech_queue.is_empty():
		return

	var speech_data: Dictionary = _speech_queue.pop_front()
	_current_speech = speech_data["text"]
	_is_speaking = true

	speech_started.emit(_current_speech)

	# Use Godot's built-in TTS
	DisplayServer.tts_speak(_current_speech, "", int(speech_rate * 100), pitch, volume)


func _on_speech_finished() -> void:
	_is_speaking = false
	_current_speech = ""
	speech_ended.emit()


func _on_subtitle_timeout() -> void:
	hide_subtitle()


func _on_focus_changed(control: Control) -> void:
	if not enabled or not announce_focus_changes:
		return

	if control == null or control == _focused_element:
		return

	_focused_element = control
	announce_element(control, read_button_hints)


func _build_element_announcement(element: Control, include_hints: bool) -> String:
	var parts: Array[String] = []

	# Element type and name/text
	if element is Button:
		var btn := element as Button
		parts.append(btn.text if not btn.text.is_empty() else btn.name)
		parts.append("button")

		if btn.disabled:
			parts.append("disabled")

		if include_hints and not btn.shortcut_in_tooltip:
			# Check for keyboard shortcut
			var shortcut := _get_button_shortcut(btn)
			if not shortcut.is_empty():
				parts.append("press %s" % shortcut)

	elif element is CheckBox or element is CheckButton:
		var cb := element as BaseButton
		var text: String = ""
		if element is CheckBox:
			text = (element as CheckBox).text
		elif element is CheckButton:
			text = (element as CheckButton).text

		parts.append(text if not text.is_empty() else element.name)
		parts.append("checkbox")
		parts.append("checked" if cb.button_pressed else "unchecked")

		if include_hints:
			parts.append("press space to toggle")

	elif element is Slider:
		var slider := element as Slider
		var percent := int((slider.value - slider.min_value) / (slider.max_value - slider.min_value) * 100)
		parts.append(element.name)
		parts.append("slider")
		parts.append("%d percent" % percent)

		if include_hints:
			parts.append("use arrow keys to adjust")

	elif element is SpinBox:
		var spinbox := element as SpinBox
		parts.append(element.name)
		parts.append("spin box")
		parts.append("value %d" % int(spinbox.value))

	elif element is LineEdit:
		var line := element as LineEdit
		if not line.placeholder_text.is_empty():
			parts.append(line.placeholder_text)
		else:
			parts.append(element.name)
		parts.append("text field")

		if not line.text.is_empty():
			parts.append("contains %s" % line.text)

	elif element is TextEdit:
		parts.append(element.name)
		parts.append("text area")

	elif element is OptionButton:
		var opt := element as OptionButton
		parts.append(element.name)
		parts.append("dropdown")
		if opt.selected >= 0:
			parts.append("selected %s" % opt.get_item_text(opt.selected))

		if include_hints:
			parts.append("press space to open")

	elif element is TabBar:
		var tabs := element as TabBar
		parts.append(element.name)
		parts.append("tab bar")
		parts.append("tab %d of %d" % [tabs.current_tab + 1, tabs.tab_count])

		if include_hints:
			parts.append("use arrow keys to switch tabs")

	elif element is ProgressBar:
		var progress := element as ProgressBar
		var percent := int((progress.value - progress.min_value) / (progress.max_value - progress.min_value) * 100)
		parts.append(element.name)
		parts.append("progress bar")
		parts.append("%d percent" % percent)

	elif element is Label:
		var label := element as Label
		if not label.text.is_empty():
			parts.append(label.text)

	elif element is RichTextLabel:
		var rtl := element as RichTextLabel
		var plain_text := rtl.get_parsed_text()
		if not plain_text.is_empty():
			# Truncate long text
			if plain_text.length() > 200:
				parts.append(plain_text.substr(0, 200) + "...")
			else:
				parts.append(plain_text)

	else:
		# Generic fallback
		if element.has_meta("accessibility_label"):
			parts.append(element.get_meta("accessibility_label") as String)
		elif element.has_meta("aria_label"):
			parts.append(element.get_meta("aria_label") as String)
		else:
			parts.append(element.name)

	# Check for custom accessibility description
	if element.has_meta("accessibility_description"):
		parts.append(element.get_meta("accessibility_description") as String)

	# Check for additional hints
	if include_hints and element.has_meta("accessibility_hint"):
		parts.append(element.get_meta("accessibility_hint") as String)

	return ", ".join(parts)


func _get_button_shortcut(button: Button) -> String:
	if button.shortcut:
		var shortcut := button.shortcut
		for event: InputEvent in shortcut.events:
			if event is InputEventKey:
				var key := event as InputEventKey
				var key_string := OS.get_keycode_string(key.keycode)
				var modifiers: Array[String] = []

				if key.ctrl_pressed:
					modifiers.append("Ctrl")
				if key.shift_pressed:
					modifiers.append("Shift")
				if key.alt_pressed:
					modifiers.append("Alt")

				if modifiers.is_empty():
					return key_string
				else:
					return "+".join(modifiers) + "+" + key_string

	return ""


func _create_sound_indicator(sound_type: SoundType, angle: float, intensity: float) -> Control:
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size / 2.0

	# Create indicator control
	var indicator := Control.new()
	indicator.custom_minimum_size = Vector2(64, 64) * indicator_size
	indicator.size = indicator.custom_minimum_size
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Position around screen edge based on angle
	var radius := min(viewport_size.x, viewport_size.y) * 0.4
	var x := center.x + cos(angle) * radius
	var y := center.y + sin(angle) * radius
	indicator.position = Vector2(x, y) - indicator.size / 2.0

	# Create visual representation
	var icon := _create_indicator_visual(sound_type, intensity)
	icon.rotation = angle + PI / 2.0  # Point toward center
	indicator.add_child(icon)

	# Add pulsing animation
	var tween := create_tween().set_loops(3)
	tween.tween_property(indicator, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(indicator, "scale", Vector2(1.0, 1.0), 0.15)

	return indicator


func _create_indicator_visual(sound_type: SoundType, intensity: float) -> Control:
	var visual := ColorRect.new()
	visual.size = Vector2(48, 48) * indicator_size
	visual.pivot_offset = visual.size / 2.0
	visual.position = -visual.size / 2.0

	# Color based on sound type
	var color := _get_sound_indicator_color(sound_type)
	color.a = clampf(intensity * 0.8, 0.4, 1.0)
	visual.color = color

	# Add direction arrow shape (simple triangle)
	var arrow := Polygon2D.new()
	var arrow_size := 24.0 * indicator_size
	arrow.polygon = PackedVector2Array([
		Vector2(0, -arrow_size),
		Vector2(-arrow_size * 0.6, arrow_size * 0.5),
		Vector2(arrow_size * 0.6, arrow_size * 0.5)
	])
	arrow.color = Color.WHITE
	arrow.position = visual.size / 2.0

	visual.add_child(arrow)
	visual.visible = false  # Hide the rect, just show arrow

	# Actually, let's create a proper indicator
	var container := Control.new()
	container.custom_minimum_size = Vector2(48, 48) * indicator_size

	# Background circle
	var bg := ColorRect.new()
	bg.size = container.custom_minimum_size
	bg.color = color
	bg.pivot_offset = bg.size / 2.0

	# Create rounded corners using a shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	if (dist > 0.5) {
		discard;
	}
	COLOR = COLOR;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	bg.material = mat

	container.add_child(bg)

	# Add icon/symbol based on sound type
	var symbol := Label.new()
	symbol.text = _get_sound_type_symbol(sound_type)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol.add_theme_font_size_override("font_size", int(20 * indicator_size))
	symbol.add_theme_color_override("font_color", Color.WHITE)
	symbol.size = container.custom_minimum_size
	container.add_child(symbol)

	return container


func _get_sound_indicator_color(sound_type: SoundType) -> Color:
	match sound_type:
		SoundType.GUNSHOT, SoundType.DAMAGE:
			return Color(0.9, 0.2, 0.2)  # Red
		SoundType.EXPLOSION:
			return Color(1.0, 0.5, 0.0)  # Orange
		SoundType.ENEMY:
			return Color(0.8, 0.1, 0.1)  # Dark red
		SoundType.TEAMMATE:
			return Color(0.2, 0.6, 1.0)  # Blue
		SoundType.HEAL, SoundType.PICKUP:
			return Color(0.2, 0.9, 0.3)  # Green
		SoundType.ALERT:
			return Color(1.0, 0.8, 0.0)  # Yellow
		SoundType.FOOTSTEP:
			return Color(0.6, 0.6, 0.6)  # Gray
		SoundType.VOICE:
			return Color(0.8, 0.6, 1.0)  # Purple
		SoundType.UI:
			return Color(0.4, 0.8, 1.0)  # Cyan
		SoundType.AMBIENT:
			return Color(0.5, 0.7, 0.5)  # Muted green
		_:
			return Color(0.7, 0.7, 0.7)  # Default gray


func _get_sound_type_symbol(sound_type: SoundType) -> String:
	match sound_type:
		SoundType.GUNSHOT:
			return "!"
		SoundType.EXPLOSION:
			return "*"
		SoundType.FOOTSTEP:
			return "^"
		SoundType.VOICE:
			return "\""
		SoundType.PICKUP:
			return "+"
		SoundType.ALERT:
			return "!"
		SoundType.UI:
			return ">"
		SoundType.DAMAGE:
			return "X"
		SoundType.HEAL:
			return "+"
		SoundType.ENEMY:
			return "!"
		SoundType.TEAMMATE:
			return "@"
		SoundType.AMBIENT:
			return "~"
		_:
			return "?"


func _get_sound_type_name(sound_type: SoundType) -> String:
	match sound_type:
		SoundType.GUNSHOT: return "gunshot"
		SoundType.EXPLOSION: return "explosion"
		SoundType.FOOTSTEP: return "footstep"
		SoundType.VOICE: return "voice"
		SoundType.PICKUP: return "pickup"
		SoundType.ALERT: return "alert"
		SoundType.UI: return "ui"
		SoundType.AMBIENT: return "ambient"
		SoundType.DAMAGE: return "damage"
		SoundType.HEAL: return "heal"
		SoundType.ENEMY: return "enemy"
		SoundType.TEAMMATE: return "teammate"
		_: return "unknown"


# -- Accessibility Label Helpers --

## Set accessibility label on a control.
static func set_label(control: Control, label: String) -> void:
	control.set_meta("accessibility_label", label)


## Set accessibility description on a control.
static func set_description(control: Control, description: String) -> void:
	control.set_meta("accessibility_description", description)


## Set accessibility hint on a control.
static func set_hint(control: Control, hint: String) -> void:
	control.set_meta("accessibility_hint", hint)


## Set all accessibility metadata on a control.
static func configure_control(control: Control, label: String, description: String = "", hint: String = "") -> void:
	set_label(control, label)
	if not description.is_empty():
		set_description(control, description)
	if not hint.is_empty():
		set_hint(control, hint)
