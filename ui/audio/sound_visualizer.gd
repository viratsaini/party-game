## SoundVisualizer - Accessibility sound visualization system for BattleZone Party.
##
## Provides visual representations of audio events for deaf/hard-of-hearing players,
## including directional indicators, caption overlays, spectrum analysis visualization,
## and integration with screen readers. Essential for audio accessibility.
class_name SoundVisualizer
extends CanvasLayer


# -- Signals --

## Emitted when a visual indicator is displayed.
signal indicator_shown(sound_type: String, direction: Vector2)

## Emitted when a caption is displayed.
signal caption_shown(caption_text: String)

## Emitted when visualization mode changes.
signal mode_changed(new_mode: VisualizationMode)


# -- Enums --

## Visualization display modes.
enum VisualizationMode {
	DISABLED,       ## No visualization
	MINIMAL,        ## Only important sounds
	STANDARD,       ## Common sounds
	FULL,           ## All sounds including ambient
	CAPTIONS_ONLY,  ## Text captions without visual indicators
}

## Sound importance levels for filtering.
enum SoundImportance {
	AMBIENT,        ## Background sounds
	LOW,            ## Footsteps, minor effects
	MEDIUM,         ## Gunfire, abilities
	HIGH,           ## Explosions, impacts
	CRITICAL,       ## Voice lines, alerts
	ESSENTIAL,      ## Game-critical cues
}

## Visual indicator styles.
enum IndicatorStyle {
	ARROW,          ## Simple directional arrow
	ICON,           ## Category-specific icon
	WAVE,           ## Audio wave visualization
	PULSE,          ## Radial pulse effect
	ARC,            ## Arc around screen edge
}


# -- Constants --

const MAX_INDICATORS: int = 12
const MAX_CAPTIONS: int = 5
const INDICATOR_DURATION: float = 2.0
const CAPTION_DURATION: float = 3.0
const INDICATOR_FADE_TIME: float = 0.3


# -- Exports --

@export_group("Visualization Settings")

## Current visualization mode.
@export var visualization_mode: VisualizationMode = VisualizationMode.STANDARD:
	set(v):
		visualization_mode = v
		mode_changed.emit(v)

## Visual indicator style.
@export var indicator_style: IndicatorStyle = IndicatorStyle.ARROW

## Show sound captions.
@export var show_captions: bool = true

## Caption font size.
@export_range(12, 32, 1) var caption_font_size: int = 18

## Caption background opacity.
@export_range(0.0, 1.0, 0.05) var caption_background_opacity: float = 0.7

@export_group("Indicator Appearance")

## Indicator size in pixels.
@export_range(20, 100, 5) var indicator_size: float = 40.0

## Distance from screen edge for indicators.
@export_range(20, 150, 5) var edge_padding: float = 50.0

## Indicator color (auto-tints based on sound type).
@export var indicator_base_color: Color = Color.WHITE

## High importance color.
@export var indicator_critical_color: Color = Color.RED

## Enable pulsing animation.
@export var pulse_animation: bool = true

@export_group("Spectrum Analyzer")

## Show audio spectrum visualization.
@export var show_spectrum: bool = false

## Spectrum bar count.
@export_range(8, 64, 4) var spectrum_bars: int = 16

## Spectrum position on screen.
@export var spectrum_position: Vector2 = Vector2(20, 500)

## Spectrum size.
@export var spectrum_size: Vector2 = Vector2(200, 60)


# -- State --

## Active visual indicators.
var _active_indicators: Array[IndicatorData] = []

## Active captions.
var _active_captions: Array[CaptionData] = []

## Indicator pool for reuse.
var _indicator_pool: Array[Control] = []

## Caption container.
var _caption_container: VBoxContainer = null

## Spectrum analyzer.
var _spectrum_analyzer: Control = null

## Sound type to icon mapping.
var _sound_icons: Dictionary = {}

## Sound type to caption text mapping.
var _sound_captions: Dictionary = {}

## Last indicator positions to prevent overlap.
var _indicator_positions: Array[Vector2] = []

## Screen reader integration.
var _screen_reader_enabled: bool = false


# -- Data Classes --

class IndicatorData extends RefCounted:
	var control: Control = null
	var direction: Vector2 = Vector2.ZERO
	var importance: int = SoundImportance.MEDIUM
	var sound_type: String = ""
	var lifetime: float = 0.0
	var max_lifetime: float = INDICATOR_DURATION


class CaptionData extends RefCounted:
	var label: Label = null
	var text: String = ""
	var lifetime: float = 0.0
	var max_lifetime: float = CAPTION_DURATION


# -- Lifecycle --

func _ready() -> void:
	layer = 100  # Above most UI
	process_mode = Node.PROCESS_MODE_ALWAYS

	_create_ui_elements()
	_register_sound_mappings()
	_connect_audio_signals()


func _process(delta: float) -> void:
	_update_indicators(delta)
	_update_captions(delta)

	if show_spectrum:
		_update_spectrum()


# -- UI Creation --

func _create_ui_elements() -> void:
	# Create caption container
	_caption_container = VBoxContainer.new()
	_caption_container.name = "CaptionContainer"
	_caption_container.anchor_left = 0.5
	_caption_container.anchor_right = 0.5
	_caption_container.anchor_top = 0.85
	_caption_container.anchor_bottom = 1.0
	_caption_container.offset_left = -300
	_caption_container.offset_right = 300
	_caption_container.offset_bottom = -20
	_caption_container.add_theme_constant_override("separation", 8)
	add_child(_caption_container)

	# Create indicator pool
	for i in MAX_INDICATORS:
		var indicator := _create_indicator_control()
		indicator.visible = false
		add_child(indicator)
		_indicator_pool.append(indicator)

	# Create spectrum analyzer if enabled
	if show_spectrum:
		_create_spectrum_analyzer()


func _create_indicator_control() -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(indicator_size, indicator_size)

	match indicator_style:
		IndicatorStyle.ARROW:
			var arrow := _create_arrow_indicator()
			container.add_child(arrow)
		IndicatorStyle.ICON:
			var icon := TextureRect.new()
			icon.name = "Icon"
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(indicator_size, indicator_size)
			container.add_child(icon)
		IndicatorStyle.WAVE:
			var wave := _create_wave_indicator()
			container.add_child(wave)
		IndicatorStyle.PULSE:
			var pulse := _create_pulse_indicator()
			container.add_child(pulse)
		IndicatorStyle.ARC:
			var arc := _create_arc_indicator()
			container.add_child(arc)

	return container


func _create_arrow_indicator() -> Control:
	var arrow := Control.new()
	arrow.name = "Arrow"
	arrow.custom_minimum_size = Vector2(indicator_size, indicator_size)

	# Arrow is drawn via _draw override in a custom script
	# For simplicity, using a ColorRect as placeholder
	var rect := ColorRect.new()
	rect.color = indicator_base_color
	rect.custom_minimum_size = Vector2(indicator_size * 0.3, indicator_size * 0.8)
	rect.position = Vector2(indicator_size * 0.35, indicator_size * 0.1)
	arrow.add_child(rect)

	# Triangle tip
	var tip := ColorRect.new()
	tip.color = indicator_base_color
	tip.custom_minimum_size = Vector2(indicator_size * 0.6, indicator_size * 0.3)
	tip.position = Vector2(indicator_size * 0.2, 0)
	arrow.add_child(tip)

	return arrow


func _create_wave_indicator() -> Control:
	var wave := Control.new()
	wave.name = "Wave"
	wave.custom_minimum_size = Vector2(indicator_size, indicator_size)

	# Create multiple wave bars
	for i in 5:
		var bar := ColorRect.new()
		bar.color = indicator_base_color
		bar.custom_minimum_size = Vector2(4, indicator_size * 0.3)
		bar.position = Vector2(i * 8 + 4, indicator_size * 0.35)
		bar.name = "Bar%d" % i
		wave.add_child(bar)

	return wave


func _create_pulse_indicator() -> Control:
	var pulse := Control.new()
	pulse.name = "Pulse"
	pulse.custom_minimum_size = Vector2(indicator_size, indicator_size)

	# Create concentric circles
	for i in 3:
		var circle := ColorRect.new()
		var size := indicator_size * (0.3 + i * 0.2)
		circle.color = indicator_base_color
		circle.color.a = 1.0 - i * 0.3
		circle.custom_minimum_size = Vector2(size, size)
		circle.position = Vector2((indicator_size - size) / 2, (indicator_size - size) / 2)
		circle.name = "Circle%d" % i
		pulse.add_child(circle)

	return pulse


func _create_arc_indicator() -> Control:
	var arc := Control.new()
	arc.name = "Arc"
	arc.custom_minimum_size = Vector2(indicator_size * 2, indicator_size)

	var bar := ColorRect.new()
	bar.color = indicator_base_color
	bar.custom_minimum_size = Vector2(indicator_size * 1.5, 6)
	bar.position = Vector2(indicator_size * 0.25, indicator_size * 0.5 - 3)
	arc.add_child(bar)

	return arc


func _create_spectrum_analyzer() -> void:
	_spectrum_analyzer = Control.new()
	_spectrum_analyzer.name = "SpectrumAnalyzer"
	_spectrum_analyzer.position = spectrum_position
	_spectrum_analyzer.custom_minimum_size = spectrum_size

	# Create background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.custom_minimum_size = spectrum_size
	_spectrum_analyzer.add_child(bg)

	# Create bars
	var bar_width := spectrum_size.x / spectrum_bars - 2
	for i in spectrum_bars:
		var bar := ColorRect.new()
		bar.name = "SpectrumBar%d" % i
		bar.color = Color.GREEN
		bar.custom_minimum_size = Vector2(bar_width, spectrum_size.y)
		bar.position = Vector2(i * (bar_width + 2), spectrum_size.y)
		bar.pivot_offset = Vector2(bar_width / 2, spectrum_size.y)
		_spectrum_analyzer.add_child(bar)

	add_child(_spectrum_analyzer)


# -- Sound Mappings --

func _register_sound_mappings() -> void:
	# Map sound types to captions and importance
	_sound_captions = {
		# Weapons
		"weapon_fire": "[Gunfire]",
		"weapon_reload": "[Reloading]",
		"explosion": "[EXPLOSION]",
		"grenade_bounce": "[Grenade]",
		"rocket_launch": "[Rocket]",

		# Movement
		"footstep": "[Footsteps]",
		"footstep_run": "[Running]",
		"jetpack": "[Jetpack]",
		"jump": "[Jump]",
		"land": "[Landing]",

		# Combat
		"hit_marker": "[Hit!]",
		"damage_taken": "[Damage received]",
		"shield_break": "[Shield broken]",
		"kill": "[Kill!]",
		"death": "[Player eliminated]",

		# Pickups
		"pickup_health": "[Health pickup]",
		"pickup_ammo": "[Ammo pickup]",
		"pickup_powerup": "[Power-up!]",
		"pickup_weapon": "[Weapon pickup]",

		# Alerts
		"countdown": "[Countdown]",
		"match_start": "[Match started!]",
		"match_end": "[Match over]",
		"overtime": "[OVERTIME]",
		"warning": "[Warning!]",

		# Voice
		"voice_taunt": "[Player taunt]",
		"voice_callout": "[Callout]",
		"voice_ping": "[Ping!]",

		# UI
		"notification": "[Notification]",
		"achievement": "[Achievement!]",
		"level_up": "[Level Up!]",
	}

	# Importance levels
	var importance_map := {
		"weapon_fire": SoundImportance.MEDIUM,
		"explosion": SoundImportance.HIGH,
		"footstep": SoundImportance.LOW,
		"damage_taken": SoundImportance.HIGH,
		"kill": SoundImportance.CRITICAL,
		"pickup_powerup": SoundImportance.MEDIUM,
		"countdown": SoundImportance.CRITICAL,
		"match_start": SoundImportance.ESSENTIAL,
		"overtime": SoundImportance.ESSENTIAL,
		"voice_ping": SoundImportance.HIGH,
		"achievement": SoundImportance.CRITICAL,
	}


# -- Audio Signal Connections --

func _connect_audio_signals() -> void:
	# Connect to AudioManager signals if available
	if AudioManager:
		AudioManager.spatial_sound_spawned.connect(_on_spatial_sound)


func _on_spatial_sound(_player: AudioStreamPlayer3D, key: String, position: Vector3) -> void:
	# Convert 3D position to screen direction
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var camera_pos := camera.global_position
	var direction_3d := (position - camera_pos).normalized()

	# Project to 2D screen direction
	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y

	var dot_right := direction_3d.dot(right)
	var dot_up := direction_3d.dot(up)
	var dot_forward := direction_3d.dot(forward)

	# Only show indicator if sound is not directly in front
	if dot_forward > 0.8:
		return

	var screen_direction := Vector2(dot_right, -dot_up).normalized()

	# Determine importance from sound key
	var importance := _get_sound_importance(key)

	# Filter based on mode
	if not _should_show_sound(importance):
		return

	show_indicator(key, screen_direction, importance)


# -- Public API: Show Indicators --

## Show a directional sound indicator.
func show_indicator(sound_type: String, direction: Vector2, importance: int = SoundImportance.MEDIUM) -> void:
	if visualization_mode == VisualizationMode.DISABLED:
		return

	if not _should_show_sound(importance):
		return

	# Get available indicator from pool
	var indicator_control := _get_available_indicator()
	if not indicator_control:
		return

	# Configure indicator
	var data := IndicatorData.new()
	data.control = indicator_control
	data.direction = direction
	data.importance = importance
	data.sound_type = sound_type
	data.lifetime = 0.0
	data.max_lifetime = INDICATOR_DURATION

	# Position indicator at screen edge
	var screen_size := get_viewport().get_visible_rect().size
	var center := screen_size / 2

	var angle := direction.angle()
	var edge_pos := _calculate_edge_position(direction, screen_size, center)

	indicator_control.position = edge_pos - Vector2(indicator_size / 2, indicator_size / 2)
	indicator_control.rotation = angle + PI / 2  # Point toward center

	# Color based on importance
	_set_indicator_color(indicator_control, importance)

	indicator_control.visible = true
	indicator_control.modulate.a = 1.0

	_active_indicators.append(data)
	indicator_shown.emit(sound_type, direction)

	# Show caption if enabled
	if show_captions:
		_show_caption_for_sound(sound_type, importance)


## Show a sound caption without directional indicator.
func show_caption(text: String, importance: int = SoundImportance.MEDIUM) -> void:
	if not show_captions or visualization_mode == VisualizationMode.DISABLED:
		return

	if not _should_show_sound(importance):
		return

	# Create caption label
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, caption_background_opacity)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", caption_font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Color based on importance
	match importance:
		SoundImportance.CRITICAL, SoundImportance.ESSENTIAL:
			label.add_theme_color_override("font_color", indicator_critical_color)
		SoundImportance.HIGH:
			label.add_theme_color_override("font_color", Color.YELLOW)
		_:
			label.add_theme_color_override("font_color", Color.WHITE)

	panel.add_child(label)
	_caption_container.add_child(panel)

	# Limit caption count
	while _caption_container.get_child_count() > MAX_CAPTIONS:
		var old_child := _caption_container.get_child(0)
		_caption_container.remove_child(old_child)
		old_child.queue_free()

	# Track caption data
	var data := CaptionData.new()
	data.label = label
	data.text = text
	data.lifetime = 0.0
	_active_captions.append(data)

	caption_shown.emit(text)

	# Screen reader announcement
	if _screen_reader_enabled:
		_announce_to_screen_reader(text)


## Show directional damage indicator.
func show_damage_indicator(direction: Vector2, damage_amount: float) -> void:
	var importance := SoundImportance.MEDIUM
	if damage_amount > 50:
		importance = SoundImportance.HIGH
	if damage_amount > 100:
		importance = SoundImportance.CRITICAL

	show_indicator("damage_taken", direction, importance)

	var caption := "[Damage: %d]" % int(damage_amount)
	show_caption(caption, importance)


## Show enemy spotted indicator.
func show_enemy_indicator(direction: Vector2) -> void:
	show_indicator("enemy_spotted", direction, SoundImportance.HIGH)
	show_caption("[Enemy spotted]", SoundImportance.HIGH)


# -- Update Functions --

func _update_indicators(delta: float) -> void:
	var to_remove: Array[int] = []

	for i in range(_active_indicators.size()):
		var data: IndicatorData = _active_indicators[i]
		data.lifetime += delta

		# Calculate fade
		var fade_start := data.max_lifetime - INDICATOR_FADE_TIME
		if data.lifetime > fade_start:
			var fade_progress := (data.lifetime - fade_start) / INDICATOR_FADE_TIME
			data.control.modulate.a = 1.0 - fade_progress

		# Pulse animation
		if pulse_animation and data.lifetime < fade_start:
			var pulse := 1.0 + sin(data.lifetime * 8.0) * 0.1
			data.control.scale = Vector2(pulse, pulse)

		# Check expiration
		if data.lifetime >= data.max_lifetime:
			data.control.visible = false
			data.control.scale = Vector2.ONE
			to_remove.append(i)

	# Remove expired indicators
	for i in range(to_remove.size() - 1, -1, -1):
		_active_indicators.remove_at(to_remove[i])


func _update_captions(delta: float) -> void:
	var to_remove: Array[int] = []

	for i in range(_active_captions.size()):
		var data: CaptionData = _active_captions[i]
		data.lifetime += delta

		# Fade out
		var fade_start := data.max_lifetime - INDICATOR_FADE_TIME
		if data.lifetime > fade_start:
			var fade_progress := (data.lifetime - fade_start) / INDICATOR_FADE_TIME
			if data.label and data.label.get_parent():
				data.label.get_parent().modulate.a = 1.0 - fade_progress

		# Check expiration
		if data.lifetime >= data.max_lifetime:
			if data.label and data.label.get_parent():
				data.label.get_parent().queue_free()
			to_remove.append(i)

	# Remove expired captions
	for i in range(to_remove.size() - 1, -1, -1):
		_active_captions.remove_at(to_remove[i])


func _update_spectrum() -> void:
	if not _spectrum_analyzer or not _spectrum_analyzer.visible:
		return

	# Get audio spectrum data from AudioServer
	# This requires an AudioEffectSpectrumAnalyzer on the bus
	var effect_idx := AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Master"))

	# Simulate spectrum for visual effect
	for i in spectrum_bars:
		var bar := _spectrum_analyzer.get_node_or_null("SpectrumBar%d" % i)
		if bar:
			# Simulated value - in production, use actual spectrum data
			var value := randf() * 0.5 + 0.3
			bar.scale.y = value

			# Color gradient based on value
			bar.color = Color.GREEN.lerp(Color.RED, value)


# -- Helper Functions --

func _get_available_indicator() -> Control:
	for indicator in _indicator_pool:
		if not indicator.visible:
			return indicator
	return null


func _calculate_edge_position(direction: Vector2, screen_size: Vector2, center: Vector2) -> Vector2:
	# Find intersection with screen edge
	var padding := edge_padding + indicator_size / 2

	var max_x := screen_size.x - padding
	var min_x := padding
	var max_y := screen_size.y - padding
	var min_y := padding

	# Calculate intersection with each edge
	var pos := center

	if abs(direction.x) > abs(direction.y):
		# Horizontal edge intersection
		if direction.x > 0:
			pos = center + direction * ((max_x - center.x) / direction.x)
		else:
			pos = center + direction * ((min_x - center.x) / direction.x)
	else:
		# Vertical edge intersection
		if direction.y > 0:
			pos = center + direction * ((max_y - center.y) / direction.y)
		else:
			pos = center + direction * ((min_y - center.y) / direction.y)

	# Clamp to screen bounds
	pos.x = clampf(pos.x, min_x, max_x)
	pos.y = clampf(pos.y, min_y, max_y)

	return pos


func _set_indicator_color(indicator: Control, importance: int) -> void:
	var color := indicator_base_color

	match importance:
		SoundImportance.CRITICAL, SoundImportance.ESSENTIAL:
			color = indicator_critical_color
		SoundImportance.HIGH:
			color = Color.ORANGE
		SoundImportance.MEDIUM:
			color = Color.YELLOW
		SoundImportance.LOW:
			color = Color.WHITE.darkened(0.2)
		SoundImportance.AMBIENT:
			color = Color.WHITE.darkened(0.5)

	# Apply color to all ColorRects in indicator
	for child in indicator.get_children():
		_colorize_recursive(child, color)


func _colorize_recursive(node: Node, color: Color) -> void:
	if node is ColorRect:
		var original_alpha := node.color.a
		node.color = color
		node.color.a = original_alpha
	for child in node.get_children():
		_colorize_recursive(child, color)


func _should_show_sound(importance: int) -> bool:
	match visualization_mode:
		VisualizationMode.DISABLED:
			return false
		VisualizationMode.MINIMAL:
			return importance >= SoundImportance.HIGH
		VisualizationMode.STANDARD:
			return importance >= SoundImportance.MEDIUM
		VisualizationMode.FULL:
			return true
		VisualizationMode.CAPTIONS_ONLY:
			return importance >= SoundImportance.MEDIUM
	return true


func _get_sound_importance(sound_key: String) -> int:
	# Extract base sound type from key
	var base_key := sound_key.split("_")[0] if "_" in sound_key else sound_key

	# Check known important sounds
	if "explosion" in sound_key or "grenade" in sound_key:
		return SoundImportance.HIGH
	if "weapon" in sound_key or "fire" in sound_key:
		return SoundImportance.MEDIUM
	if "footstep" in sound_key:
		return SoundImportance.LOW
	if "voice" in sound_key or "callout" in sound_key:
		return SoundImportance.HIGH
	if "pickup" in sound_key:
		return SoundImportance.MEDIUM
	if "kill" in sound_key or "death" in sound_key:
		return SoundImportance.CRITICAL
	if "countdown" in sound_key or "match" in sound_key:
		return SoundImportance.ESSENTIAL

	return SoundImportance.MEDIUM


func _show_caption_for_sound(sound_type: String, importance: int) -> void:
	var caption_text := _sound_captions.get(sound_type, "[%s]" % sound_type)
	show_caption(caption_text, importance)


func _announce_to_screen_reader(text: String) -> void:
	# Use platform TTS if available
	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	DisplayServer.tts_speak(text)


# -- Settings API --

## Set visualization mode.
func set_mode(mode: VisualizationMode) -> void:
	visualization_mode = mode


## Get current mode.
func get_mode() -> VisualizationMode:
	return visualization_mode


## Enable/disable captions.
func set_captions_enabled(enabled: bool) -> void:
	show_captions = enabled


## Enable/disable screen reader integration.
func set_screen_reader_enabled(enabled: bool) -> void:
	_screen_reader_enabled = enabled


## Set indicator style.
func set_indicator_style(style: IndicatorStyle) -> void:
	indicator_style = style
	# Recreate indicator pool with new style
	for indicator in _indicator_pool:
		indicator.queue_free()
	_indicator_pool.clear()

	for i in MAX_INDICATORS:
		var indicator := _create_indicator_control()
		indicator.visible = false
		add_child(indicator)
		_indicator_pool.append(indicator)


## Enable/disable spectrum analyzer.
func set_spectrum_enabled(enabled: bool) -> void:
	show_spectrum = enabled
	if _spectrum_analyzer:
		_spectrum_analyzer.visible = enabled
	elif enabled:
		_create_spectrum_analyzer()


# -- Debug --

## Get current state information.
func get_debug_info() -> Dictionary:
	return {
		"mode": visualization_mode,
		"active_indicators": _active_indicators.size(),
		"active_captions": _active_captions.size(),
		"show_captions": show_captions,
		"show_spectrum": show_spectrum,
		"screen_reader_enabled": _screen_reader_enabled,
	}


## Clear all active visualizations.
func clear_all() -> void:
	for data: IndicatorData in _active_indicators:
		if data.control:
			data.control.visible = false
	_active_indicators.clear()

	for child in _caption_container.get_children():
		child.queue_free()
	_active_captions.clear()
