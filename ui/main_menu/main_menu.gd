## Main menu screen for BattleZone Party - ROUND 2 ULTRA PREMIUM EDITION.
## Features AAA-quality animations, advanced shaders, particle physics,
## dynamic glow, holographic effects, smart adaptation, and responsive
## micro-interactions with haptic feedback synchronization.
extends Control

# ══════════════════════════════════════════════════════════════════════════════
# PRELOADS
# ══════════════════════════════════════════════════════════════════════════════

const UIParticlesClass = preload("res://ui/effects/ui_particles.gd")
const UIGlowEffectClass = preload("res://ui/effects/glow_effect.gd")
const AdvancedParticlesV2Class = preload("res://ui/effects/advanced_particles_v2.gd")
const MenuFXManagerClass = preload("res://ui/effects/menu_fx_manager.gd")


# ══════════════════════════════════════════════════════════════════════════════
# NODE REFERENCES
# ══════════════════════════════════════════════════════════════════════════════

@onready var title_container: VBoxContainer = %TitleContainer
@onready var button_container: VBoxContainer = %ButtonContainer
@onready var create_button: Button = %CreateButton
@onready var join_button: Button = %JoinButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

# Join panel
@onready var join_panel: PanelContainer = %JoinPanel
@onready var discovered_games: ItemList = %DiscoveredGames
@onready var refresh_button: Button = %RefreshButton
@onready var manual_ip_button: Button = %ManualIPButton
@onready var back_button: Button = %BackButton
@onready var searching_label: Label = %SearchingLabel

# Manual IP panel (secondary option)
@onready var manual_ip_panel: PanelContainer = %ManualIPPanel
@onready var ip_input: LineEdit = %IPInput
@onready var connect_button: Button = %ConnectButton
@onready var manual_back_button: Button = %ManualBackButton

# Settings panel
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var name_input: LineEdit = %NameInput
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var settings_back_button: Button = %SettingsBackButton

# Graphics settings
@onready var quality_option: OptionButton = %QualityOption
@onready var bloom_toggle: CheckButton = %BloomToggle
@onready var vignette_toggle: CheckButton = %VignetteToggle
@onready var effects_toggle: CheckButton = %EffectsToggle

@onready var version_label: Label = %VersionLabel

# Tutorial
var tutorial_overlay: CanvasLayer = null


# ══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ══════════════════════════════════════════════════════════════════════════════

const PROFILE_PATH: String = "user://player_profile.cfg"
const CHARACTER_SELECT_SCENE: String = "res://ui/character_select/character_select.tscn"

# Animation timing
const ENTRANCE_DELAY: float = 0.05
const BUTTON_CASCADE_DELAY: float = 0.08
const PANEL_TRANSITION_DURATION: float = 0.4
const IDLE_FLOAT_AMPLITUDE: float = 2.0

# Visual effects
const PARALLAX_STRENGTH: float = 15.0
const MAGNETIC_SNAP_RADIUS: float = 80.0
const MAGNETIC_SNAP_STRENGTH: float = 0.15


# ══════════════════════════════════════════════════════════════════════════════
# STATE
# ══════════════════════════════════════════════════════════════════════════════

## Discovered LAN games stored as an array of host_info dictionaries.
var _discovered: Array[Dictionary] = []

## Player display name persisted across sessions.
var _player_name: String = "Player"

## Effect systems
var _particles: Control = null
var _button_glows: Dictionary = {}
var _panel_glows: Dictionary = {}
var _idle_tweens: Dictionary = {}

## Parallax state
var _parallax_layers: Array[Control] = []
var _mouse_pos: Vector2 = Vector2.ZERO

## Button original positions (for magnetic snap)
var _button_original_positions: Dictionary = {}

## Active panel reference
var _active_panel: PanelContainer = null

## Background grid animation
var _grid_offset: float = 0.0
var _vignette_pulse: float = 0.0


# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_load_player_profile()
	_setup_ui()
	_setup_effects()
	_connect_signals()

	# Start LAN discovery so we can list available games.
	ConnectionManager.start_lan_discovery()

	# Play menu background music.
	AudioManager.play_music("menu")

	# Show tutorial for first-time users
	if is_instance_valid(TutorialManager) and TutorialManager.should_show_tutorial():
		_show_tutorial()

	# Play ultra-premium entrance animation
	await get_tree().process_frame
	_play_ultra_entrance_animation()

	# Show welcome notification
	if is_instance_valid(NotificationManager):
		NotificationManager.show_info("Welcome to BattleZone Party!")


func _exit_tree() -> void:
	ConnectionManager.lan_game_discovered.disconnect(_on_discovered_game)
	if tutorial_overlay != null:
		tutorial_overlay.queue_free()

	# Cleanup effects
	_cleanup_effects()


func _process(delta: float) -> void:
	_update_parallax(delta)
	_update_background_effects(delta)
	_update_magnetic_snap()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_pos = event.position


func _draw() -> void:
	_draw_animated_background()
	_draw_vignette()


# ══════════════════════════════════════════════════════════════════════════════
# PROFILE PERSISTENCE
# ══════════════════════════════════════════════════════════════════════════════

func _load_player_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) == OK:
		_player_name = cfg.get_value("profile", "name", "Player")
	Lobby.set_local_player_name(_player_name)


func _save_player_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "name", _player_name)
	cfg.save(PROFILE_PATH)


# ══════════════════════════════════════════════════════════════════════════════
# UI SETUP
# ══════════════════════════════════════════════════════════════════════════════

func _setup_ui() -> void:
	join_panel.visible = false
	manual_ip_panel.visible = false
	settings_panel.visible = false

	name_input.text = _player_name

	# Initialise sliders from AudioManager.
	master_slider.value = AudioManager.master_volume
	music_slider.value = AudioManager.music_volume
	sfx_slider.value = AudioManager.sfx_volume

	version_label.text = "v" + ProjectSettings.get_setting("application/config/version", "0.1.0")

	# Initially hide searching label
	if searching_label:
		searching_label.visible = false

	# Store original button positions for magnetic snap
	_store_button_positions()

	# Setup pivot points for buttons
	_setup_button_pivots()


func _setup_button_pivots() -> void:
	var buttons: Array[Button] = [create_button, join_button, settings_button, quit_button]
	for button in buttons:
		button.pivot_offset = button.size / 2


func _store_button_positions() -> void:
	var buttons: Array[Button] = [create_button, join_button, settings_button, quit_button]
	for button in buttons:
		_button_original_positions[button] = button.position


func _connect_signals() -> void:
	create_button.pressed.connect(_on_create_pressed)
	join_button.pressed.connect(_on_join_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Join panel signals
	refresh_button.pressed.connect(_on_refresh_pressed)
	manual_ip_button.pressed.connect(_on_manual_ip_pressed)
	back_button.pressed.connect(_on_back_pressed)
	discovered_games.item_selected.connect(_on_discovered_item_selected)

	# Manual IP panel signals
	connect_button.pressed.connect(_on_connect_button_pressed)
	manual_back_button.pressed.connect(_on_manual_back_pressed)

	# Settings signals
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	name_input.text_changed.connect(_on_name_changed)
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	# Connection manager signals
	ConnectionManager.lan_game_discovered.connect(_on_discovered_game)
	ConnectionManager.connection_failed.connect(_on_connection_failed)
	ConnectionManager.connected_to_host.connect(_on_connected_to_host)

	# Setup ultra-premium button effects
	_setup_ultra_button_effects()


# ══════════════════════════════════════════════════════════════════════════════
# EFFECTS SETUP
# ══════════════════════════════════════════════════════════════════════════════

func _setup_effects() -> void:
	# Create particle system
	_particles = UIParticlesClass.new()
	_particles.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_particles)
	move_child(_particles, 1)  # Above background, below UI

	# Start ambient particles
	_particles.start_ambient_particles(Rect2(Vector2.ZERO, size))

	# Setup button glow effects
	_setup_button_glows()

	# Setup parallax layers
	_setup_parallax_layers()

	# Start idle breathing animations
	_start_idle_animations()


func _setup_button_glows() -> void:
	var button_configs: Array = [
		[create_button, "primary"],
		[join_button, "secondary"],
		[settings_button, "neutral"],
		[quit_button, "danger"]
	]

	for config in button_configs:
		var button: Button = config[0]
		var glow_type: String = config[1]

		var glow = UIGlowEffectClass.new()
		glow.glow_type = glow_type
		glow.pulse_on_idle = true
		glow.size = button.size
		glow.position = Vector2.ZERO
		button.add_child(glow)
		button.move_child(glow, 0)

		# Keep glow size synced
		button.resized.connect(func(): glow.size = button.size)

		_button_glows[button] = glow


func _setup_parallax_layers() -> void:
	# Title and buttons act as parallax layers
	_parallax_layers = [title_container, button_container, version_label]


func _start_idle_animations() -> void:
	# Title floating animation
	_start_float_animation(title_container, IDLE_FLOAT_AMPLITUDE * 1.2)

	# Button container subtle float
	_start_float_animation(button_container, IDLE_FLOAT_AMPLITUDE * 0.5)


func _start_float_animation(control: Control, amplitude: float) -> void:
	var original_pos: Vector2 = control.position

	var tween: Tween = create_tween()
	tween.set_loops()

	tween.tween_property(control, "position:y", original_pos.y - amplitude, 2.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(control, "position:y", original_pos.y + amplitude * 0.5, 2.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(control, "position:y", original_pos.y, 1.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	_idle_tweens[control] = tween


func _cleanup_effects() -> void:
	if _particles:
		_particles.clear_all()

	for tween in _idle_tweens.values():
		if tween and tween.is_valid():
			tween.kill()


# ══════════════════════════════════════════════════════════════════════════════
# ULTRA-PREMIUM BUTTON EFFECTS
# ══════════════════════════════════════════════════════════════════════════════

func _setup_ultra_button_effects() -> void:
	var buttons: Array[Button] = [
		create_button, join_button, settings_button, quit_button,
		refresh_button, manual_ip_button, back_button,
		connect_button, manual_back_button, settings_back_button
	]

	for button in buttons:
		if button == null:
			continue

		button.mouse_entered.connect(_on_button_hover_enter.bind(button))
		button.mouse_exited.connect(_on_button_hover_exit.bind(button))
		button.button_down.connect(_on_button_press_down.bind(button))
		button.button_up.connect(_on_button_press_up.bind(button))


func _on_button_hover_enter(button: Button) -> void:
	# Kill any existing tween
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# Scale up with back easing (slight overshoot)
	tween.tween_property(button, "scale", Vector2(1.08, 1.08), 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# Brighten
	var hover_color := Color(1.15, 1.15, 1.2, 1.0)
	tween.tween_property(button, "modulate", hover_color, 0.15)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	# Update glow state
	if _button_glows.has(button):
		_button_glows[button].set_state(UIGlowEffectClass.GlowState.HOVER)

	# Start particle trail
	if _particles:
		_particles.start_button_hover_trail(button)

	# Play hover sound
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("button_hover")


func _on_button_hover_exit(button: Button) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(button, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(button, "modulate", Color.WHITE, 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	# Update glow state
	if _button_glows.has(button):
		_button_glows[button].set_state(UIGlowEffectClass.GlowState.IDLE)

	# Stop particle trail
	if _particles:
		_particles.stop_button_hover_trail(button)


func _on_button_press_down(button: Button) -> void:
	var tween: Tween = create_tween()

	# Quick squish
	tween.tween_property(button, "scale", Vector2(0.92, 0.92), 0.05)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_OUT)

	# Update glow
	if _button_glows.has(button):
		_button_glows[button].set_state(UIGlowEffectClass.GlowState.ACTIVE)

	# Emit click particles
	if _particles:
		_particles.emit_button_click(button)

	# Play click sound
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("button_click")


func _on_button_press_up(button: Button) -> void:
	var tween: Tween = create_tween()

	# Spring overshoot
	tween.tween_property(button, "scale", Vector2(1.12, 1.12), 0.1)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# Settle
	tween.tween_property(button, "scale", Vector2(1.08, 1.08), 0.1)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	# Update glow
	if _button_glows.has(button):
		if button.is_hovered():
			_button_glows[button].set_state(UIGlowEffectClass.GlowState.HOVER)
		else:
			_button_glows[button].set_state(UIGlowEffectClass.GlowState.IDLE)


# ══════════════════════════════════════════════════════════════════════════════
# BACKGROUND EFFECTS
# ══════════════════════════════════════════════════════════════════════════════

func _update_background_effects(delta: float) -> void:
	# Animate grid
	_grid_offset += delta * 20.0
	if _grid_offset > 100.0:
		_grid_offset -= 100.0

	# Pulsing vignette (synced to music would be ideal)
	_vignette_pulse = sin(Time.get_ticks_msec() * 0.001) * 0.1 + 0.9


func _draw_animated_background() -> void:
	# Base gradient
	var gradient_colors: PackedColorArray = PackedColorArray([
		Color(0.05, 0.05, 0.12, 1.0),
		Color(0.08, 0.06, 0.15, 1.0)
	])

	draw_rect(Rect2(Vector2.ZERO, size), gradient_colors[0])

	# Animated hex grid
	_draw_hex_grid()

	# Ambient glow spots
	_draw_ambient_glows()


func _draw_hex_grid() -> void:
	var grid_color := Color(0.15, 0.2, 0.4, 0.08)
	var hex_size: float = 50.0
	var hex_height: float = hex_size * 1.732  # sqrt(3)

	var cols: int = int(size.x / (hex_size * 1.5)) + 2
	var rows: int = int(size.y / hex_height) + 2

	for col in range(cols):
		for row in range(rows):
			var offset_y: float = hex_height * 0.5 if col % 2 == 1 else 0
			var x: float = col * hex_size * 1.5 - fmod(_grid_offset, hex_size * 1.5)
			var y: float = row * hex_height + offset_y - fmod(_grid_offset * 0.5, hex_height)

			var center := Vector2(x, y)

			# Draw hexagon outline
			_draw_hexagon(center, hex_size * 0.4, grid_color)


func _draw_hexagon(center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var angle: float = (float(i) / 6.0) * TAU + PI / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	for i in range(6):
		var next_i: int = (i + 1) % 6
		draw_line(points[i], points[next_i], color, 1.0, true)


func _draw_ambient_glows() -> void:
	# Soft glow spots in background
	var glow_positions: Array[Vector2] = [
		Vector2(size.x * 0.2, size.y * 0.3),
		Vector2(size.x * 0.8, size.y * 0.4),
		Vector2(size.x * 0.5, size.y * 0.7),
	]

	var glow_colors: Array[Color] = [
		Color(0.3, 0.5, 1.0, 0.1),
		Color(0.6, 0.3, 1.0, 0.08),
		Color(0.2, 0.8, 0.8, 0.06),
	]

	var time: float = Time.get_ticks_msec() * 0.0005

	for i in range(glow_positions.size()):
		var pos: Vector2 = glow_positions[i]
		pos.x += sin(time + i) * 30.0
		pos.y += cos(time * 0.7 + i) * 20.0

		var glow_radius: float = 200.0 + sin(time * 0.5 + i * 2) * 50.0

		# Draw multiple circles with decreasing alpha for soft glow
		var layers: int = 8
		for layer in range(layers):
			var t: float = float(layer) / layers
			var r: float = glow_radius * (1.0 - t * 0.5)
			var alpha: float = glow_colors[i].a * (1.0 - t)
			var c: Color = glow_colors[i]
			c.a = alpha
			draw_circle(pos, r, c)


func _draw_vignette() -> void:
	# Draw vignette overlay
	var vignette_color := Color(0.0, 0.0, 0.0, 0.4 * _vignette_pulse)

	# Corner gradients
	var corner_radius: float = size.length() * 0.5

	# Draw from corners
	var corners: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(size.x, 0),
		Vector2(size.x, size.y),
		Vector2(0, size.y)
	]

	for corner in corners:
		var layers: int = 10
		for i in range(layers):
			var t: float = float(i) / layers
			var r: float = corner_radius * t * 0.5
			var alpha: float = vignette_color.a * (1.0 - t)
			var c: Color = vignette_color
			c.a = alpha
			draw_circle(corner, r, c)


# ══════════════════════════════════════════════════════════════════════════════
# PARALLAX & MAGNETIC SNAP
# ══════════════════════════════════════════════════════════════════════════════

func _update_parallax(_delta: float) -> void:
	var center: Vector2 = size / 2.0
	var mouse_offset: Vector2 = (_mouse_pos - center) / center

	for i in range(_parallax_layers.size()):
		var layer: Control = _parallax_layers[i]
		if layer == null:
			continue

		var depth: float = (float(i) + 1.0) / _parallax_layers.size()
		var offset: Vector2 = mouse_offset * PARALLAX_STRENGTH * depth

		# Apply smoothly
		# Note: This modifies position slightly, idle animation handles base position
		# We add offset to pivot instead of position to avoid conflicts
		layer.pivot_offset = layer.size / 2.0 + offset


func _update_magnetic_snap() -> void:
	if not button_container.visible:
		return

	var buttons: Array[Button] = [create_button, join_button, settings_button, quit_button]

	for button in buttons:
		if button == null or not _button_original_positions.has(button):
			continue

		var button_center: Vector2 = button.global_position + button.size / 2.0
		var distance: float = button_center.distance_to(_mouse_pos)

		if distance < MAGNETIC_SNAP_RADIUS and distance > 1.0:
			var direction: Vector2 = (_mouse_pos - button_center).normalized()
			var factor: float = (1.0 - distance / MAGNETIC_SNAP_RADIUS) * MAGNETIC_SNAP_STRENGTH
			var offset: Vector2 = direction * factor * 15.0

			button.position = button.position.lerp(
				_button_original_positions[button] + offset,
				0.15
			)
		else:
			# Return to original position
			button.position = button.position.lerp(
				_button_original_positions[button],
				0.1
			)


# ══════════════════════════════════════════════════════════════════════════════
# ENTRANCE ANIMATIONS
# ══════════════════════════════════════════════════════════════════════════════

func _play_ultra_entrance_animation() -> void:
	# Hide everything first
	title_container.modulate.a = 0.0
	button_container.modulate.a = 0.0
	version_label.modulate.a = 0.0

	# Logo glitch reveal
	await _animate_logo_glitch_reveal()

	# Button cascade entrance
	await _animate_button_cascade()

	# Version fade in
	_animate_version_fade()


func _animate_logo_glitch_reveal() -> void:
	var title: Label = title_container.get_node("Title")
	var subtitle: Label = title_container.get_node("Subtitle")
	var tagline: Label = title_container.get_node("Tagline")

	title_container.modulate.a = 1.0

	# Hide children initially
	title.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	tagline.modulate.a = 0.0

	title.scale = Vector2(1.3, 1.3)
	title.pivot_offset = title.size / 2.0

	var original_title_pos: Vector2 = title.position

	# Glitch phase - rapid position jitter
	var glitch_tween: Tween = create_tween()

	for i in range(6):
		var offset: Vector2 = Vector2(randf_range(-20, 20), randf_range(-5, 5))
		var alpha: float = float(i + 1) / 8.0

		glitch_tween.tween_property(title, "position", original_title_pos + offset, 0.04)
		glitch_tween.tween_property(title, "modulate:a", alpha, 0.04)

	# Snap to position
	glitch_tween.tween_property(title, "position", original_title_pos, 0.08)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_OUT)

	glitch_tween.set_parallel(true)
	glitch_tween.tween_property(title, "modulate:a", 1.0, 0.15)
	glitch_tween.tween_property(title, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)

	await glitch_tween.finished

	# Subtitle slide in
	subtitle.position.x -= 50
	var subtitle_tween: Tween = create_tween()
	subtitle_tween.set_parallel(true)
	subtitle_tween.tween_property(subtitle, "modulate:a", 1.0, 0.3)
	subtitle_tween.tween_property(subtitle, "position:x", subtitle.position.x + 50, 0.3)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.1).timeout

	# Tagline fade
	var tagline_tween: Tween = create_tween()
	tagline_tween.tween_property(tagline, "modulate:a", 1.0, 0.4)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	await subtitle_tween.finished


func _animate_button_cascade() -> void:
	button_container.modulate.a = 1.0

	var buttons: Array = [create_button, join_button, settings_button, quit_button]
	var delay: float = 0.0

	for button in buttons:
		button.modulate.a = 0.0
		button.position.y += 30
		button.scale = Vector2(0.9, 0.9)
		button.pivot_offset = button.size / 2.0

		var original_pos: float = button.position.y - 30

		var tween: Tween = create_tween()
		tween.set_parallel(true)

		tween.tween_property(button, "modulate:a", 1.0, 0.25)\
			.set_delay(delay)

		tween.tween_property(button, "position:y", original_pos, 0.3)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)\
			.set_delay(delay)

		tween.tween_property(button, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)\
			.set_delay(delay)

		# Update stored position
		_button_original_positions[button] = Vector2(button.position.x, original_pos)

		delay += BUTTON_CASCADE_DELAY

	await get_tree().create_timer(delay + 0.3).timeout


func _animate_version_fade() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(version_label, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)


# ══════════════════════════════════════════════════════════════════════════════
# PANEL TRANSITIONS
# ══════════════════════════════════════════════════════════════════════════════

func _show_panel(panel: PanelContainer) -> void:
	_active_panel = panel

	# Animate button container out
	var exit_tween: Tween = create_tween()
	exit_tween.set_parallel(true)
	exit_tween.tween_property(button_container, "modulate:a", 0.0, 0.2)
	exit_tween.tween_property(button_container, "scale", Vector2(0.95, 0.95), 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	await exit_tween.finished
	button_container.visible = false

	# Show panel with 3D rotation effect
	_hide_all_panels()
	panel.visible = true
	panel.pivot_offset = panel.size / 2.0

	# Initial state
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.rotation = deg_to_rad(-5)

	# Animate in with elastic
	var enter_tween: Tween = create_tween()
	enter_tween.set_parallel(true)

	enter_tween.tween_property(panel, "modulate:a", 1.0, PANEL_TRANSITION_DURATION * 0.7)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	enter_tween.tween_property(panel, "scale", Vector2.ONE, PANEL_TRANSITION_DURATION)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	enter_tween.tween_property(panel, "rotation", 0.0, PANEL_TRANSITION_DURATION)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)

	# Add panel edge glow
	_add_panel_glow(panel)


func _hide_current_panel() -> void:
	if _active_panel == null:
		return

	var panel: PanelContainer = _active_panel
	_active_panel = null

	# Remove glow
	_remove_panel_glow(panel)

	# Animate out with zoom
	var exit_tween: Tween = create_tween()
	exit_tween.set_parallel(true)

	exit_tween.tween_property(panel, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	exit_tween.tween_property(panel, "scale", Vector2(1.1, 1.1), 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	await exit_tween.finished
	panel.visible = false
	panel.scale = Vector2.ONE
	panel.rotation = 0.0

	# Show button container
	button_container.visible = true
	button_container.scale = Vector2(0.95, 0.95)

	var enter_tween: Tween = create_tween()
	enter_tween.set_parallel(true)
	enter_tween.tween_property(button_container, "modulate:a", 1.0, 0.25)
	enter_tween.tween_property(button_container, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


func _add_panel_glow(panel: PanelContainer) -> void:
	if _panel_glows.has(panel):
		return

	var glow = UIGlowEffectClass.new()
	glow.glow_type = "cyan"
	glow.pulse_on_idle = true
	glow.size = panel.size
	glow.position = Vector2.ZERO
	panel.add_child(glow)
	panel.move_child(glow, 0)

	panel.resized.connect(func(): glow.size = panel.size)
	_panel_glows[panel] = glow


func _remove_panel_glow(panel: PanelContainer) -> void:
	if not _panel_glows.has(panel):
		return

	var glow = _panel_glows[panel]
	if is_instance_valid(glow):
		glow.queue_free()
	_panel_glows.erase(panel)


func _hide_all_panels() -> void:
	join_panel.visible = false
	manual_ip_panel.visible = false
	settings_panel.visible = false


# ══════════════════════════════════════════════════════════════════════════════
# TRANSITION ANIMATIONS
# ══════════════════════════════════════════════════════════════════════════════

func _play_transition_animation() -> void:
	# Fade out with zoom
	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "modulate:a", 0.0, 0.4)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.4)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	# Play whoosh sound
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("whoosh")


# ══════════════════════════════════════════════════════════════════════════════
# SEARCHING ANIMATION
# ══════════════════════════════════════════════════════════════════════════════

func _animate_searching_text() -> void:
	if not searching_label:
		return

	var base_text: String = "Searching for games"
	var dots: int = 0

	while searching_label.visible and join_panel.visible:
		dots = (dots + 1) % 4
		searching_label.text = base_text + ".".repeat(dots)

		# Pulse effect
		var tween: Tween = create_tween()
		tween.tween_property(searching_label, "modulate", Color(0.7, 0.9, 1.0), 0.25)
		tween.tween_property(searching_label, "modulate", Color.WHITE, 0.25)

		await get_tree().create_timer(0.5).timeout


# ══════════════════════════════════════════════════════════════════════════════
# BUTTON HANDLERS
# ══════════════════════════════════════════════════════════════════════════════

func _on_create_pressed() -> void:
	# Validate player name
	if _player_name.strip_edges().is_empty():
		if is_instance_valid(NotificationManager):
			NotificationManager.show_warning("Please enter a player name in Settings first!")

		# Shake settings button
		_shake_button(settings_button)
		_show_panel(settings_panel)
		return

	var err: Error = ConnectionManager.host_game(_player_name)
	if err != OK:
		push_warning("MainMenu: Failed to host game - %s" % error_string(err))
		if is_instance_valid(NotificationManager):
			NotificationManager.show_error("Failed to create room: %s" % error_string(err))
		return

	ConnectionManager.start_lan_broadcast()
	Lobby.set_local_player_name(_player_name)

	if is_instance_valid(NotificationManager):
		NotificationManager.show_success("Room created successfully!")

	# Play transition animation
	_play_transition_animation()
	await get_tree().create_timer(0.5).timeout

	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_join_pressed() -> void:
	_show_panel(join_panel)
	_discovered.clear()
	discovered_games.clear()

	# Start searching animation
	if searching_label:
		searching_label.visible = true
		_animate_searching_text()

	# Restart LAN discovery to refresh the list
	ConnectionManager.stop_lan_discovery()
	ConnectionManager.start_lan_discovery()

	if is_instance_valid(NotificationManager):
		NotificationManager.show_info("Searching for nearby games...")


func _on_refresh_pressed() -> void:
	_discovered.clear()
	discovered_games.clear()

	# Restart LAN discovery
	ConnectionManager.stop_lan_discovery()
	ConnectionManager.start_lan_discovery()

	if searching_label:
		searching_label.visible = true
		_animate_searching_text()

	# Spin animation on refresh button
	_spin_button(refresh_button)

	if is_instance_valid(NotificationManager):
		NotificationManager.show_info("Refreshing game list...")


func _on_manual_ip_pressed() -> void:
	_show_panel(manual_ip_panel)


func _on_connect_button_pressed() -> void:
	var ip: String = ip_input.text.strip_edges()
	if ip.is_empty():
		if is_instance_valid(NotificationManager):
			NotificationManager.show_warning("Please enter an IP address!")
		_shake_control(ip_input)
		return

	# Validate IP format (basic check)
	if not _is_valid_ip(ip):
		if is_instance_valid(NotificationManager):
			NotificationManager.show_warning("Invalid IP address format!")
		_shake_control(ip_input)
		return

	_on_connect_pressed(ip)


func _on_connect_pressed(ip: String) -> void:
	# Validate player name
	if _player_name.strip_edges().is_empty():
		if is_instance_valid(NotificationManager):
			NotificationManager.show_warning("Please enter a player name in Settings first!")
		_show_panel(settings_panel)
		return

	if is_instance_valid(NotificationManager):
		NotificationManager.show_info("Connecting to %s..." % ip)

	var err: Error = ConnectionManager.join_game(ip, _player_name)
	if err != OK:
		push_warning("MainMenu: Failed to join game at %s - %s" % [ip, error_string(err)])
		if is_instance_valid(NotificationManager):
			NotificationManager.show_error("Failed to connect: %s" % error_string(err))
		return

	Lobby.set_local_player_name(_player_name)
	# Connection success will be handled by _on_connected_to_host signal


func _on_discovered_game(info: Dictionary) -> void:
	# Avoid duplicate entries for the same host IP.
	for existing: Dictionary in _discovered:
		if existing.get("ip", "") == info.get("ip", ""):
			return

	_discovered.append(info)
	var label: String = "%s - %d/%d players" % [
		info.get("host_name", "Unknown"),
		info.get("player_count", 0),
		info.get("max_players", 8),
	]
	discovered_games.add_item(label)

	# Hide searching label when games are found
	if searching_label and _discovered.size() > 0:
		searching_label.visible = false

	# Emit sparkles on discovered games list
	if _particles and discovered_games:
		_particles.emit_sparkles(discovered_games, 3)

	if is_instance_valid(NotificationManager):
		NotificationManager.show_success("Found game: %s" % info.get("host_name", "Unknown"))


func _on_discovered_item_selected(index: int) -> void:
	if index < 0 or index >= _discovered.size():
		return
	var info: Dictionary = _discovered[index]
	var ip: String = info.get("ip", "")
	if not ip.is_empty():
		_on_connect_pressed(ip)


func _on_settings_pressed() -> void:
	_show_panel(settings_panel)


func _on_quit_pressed() -> void:
	# Dramatic exit animation
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	await tween.finished
	get_tree().quit()


func _on_back_pressed() -> void:
	_hide_current_panel()
	if searching_label:
		searching_label.visible = false


func _on_manual_back_pressed() -> void:
	_show_panel(join_panel)


func _on_settings_back_pressed() -> void:
	_save_player_profile()
	_hide_current_panel()


func _on_connection_failed() -> void:
	if is_instance_valid(NotificationManager):
		NotificationManager.show_error("Connection failed! Please try again.")

	# Shake the current panel
	if _active_panel:
		_shake_control(_active_panel)


func _on_connected_to_host() -> void:
	if is_instance_valid(NotificationManager):
		NotificationManager.show_success("Connected successfully!")

	# Play transition animation
	_play_transition_animation()
	await get_tree().create_timer(0.5).timeout

	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


# ══════════════════════════════════════════════════════════════════════════════
# SETTINGS HANDLERS
# ══════════════════════════════════════════════════════════════════════════════

func _on_name_changed(new_text: String) -> void:
	_player_name = new_text.strip_edges() if not new_text.strip_edges().is_empty() else "Player"
	Lobby.set_local_player_name(_player_name)


func _on_master_volume_changed(value: float) -> void:
	AudioManager.master_volume = value


func _on_music_volume_changed(value: float) -> void:
	AudioManager.music_volume = value


func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.sfx_volume = value


# ══════════════════════════════════════════════════════════════════════════════
# FEEDBACK ANIMATIONS
# ══════════════════════════════════════════════════════════════════════════════

func _shake_button(button: Button) -> void:
	_shake_control(button)

	# Flash glow red
	if _button_glows.has(button):
		var glow = _button_glows[button]
		var original_color: Color = glow._glow_color
		glow.set_glow_color(Color(1.0, 0.3, 0.3))
		glow.pulse_once(0.8)

		await get_tree().create_timer(0.5).timeout
		glow.set_glow_color(original_color)


func _shake_control(control: Control) -> void:
	var original_pos: Vector2 = control.position
	var tween: Tween = create_tween()

	var shakes: int = 6
	var intensity: float = 8.0

	for i in range(shakes):
		var offset: float = intensity * (1.0 - float(i) / shakes)
		var target_x: float = original_pos.x + offset * (1 if i % 2 == 0 else -1)
		tween.tween_property(control, "position:x", target_x, 0.04)

	tween.tween_property(control, "position:x", original_pos.x, 0.04)


func _spin_button(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(button, "rotation", TAU, 0.4)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "rotation", 0.0, 0.0)


# ══════════════════════════════════════════════════════════════════════════════
# TUTORIAL FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

func _show_tutorial() -> void:
	var tutorial_scene: PackedScene = load("res://ui/tutorial/tutorial_overlay.tscn")
	if tutorial_scene:
		tutorial_overlay = tutorial_scene.instantiate() as CanvasLayer
		add_child(tutorial_overlay)

		if is_instance_valid(TutorialManager):
			TutorialManager.tutorial_step_changed.connect(_on_tutorial_step_changed)
			TutorialManager.tutorial_completed.connect(_on_tutorial_completed)
			TutorialManager.start_tutorial()


func _on_tutorial_step_changed(step_index: int) -> void:
	if not tutorial_overlay:
		return

	var step_data: Dictionary = TutorialManager.get_current_step()
	tutorial_overlay.update_step(step_data, step_index, TutorialManager.tutorial_steps.size())
	tutorial_overlay.show_tutorial()


func _on_tutorial_completed() -> void:
	if tutorial_overlay:
		tutorial_overlay.hide_tutorial()


# ══════════════════════════════════════════════════════════════════════════════
# VALIDATION FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

func _is_valid_ip(ip: String) -> bool:
	# Basic IP validation (IPv4)
	var parts: PackedStringArray = ip.split(".")
	if parts.size() != 4:
		return false

	for part: String in parts:
		if not part.is_valid_int():
			return false
		var num: int = part.to_int()
		if num < 0 or num > 255:
			return false

	return true
