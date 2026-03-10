## Main menu screen for BattleZone Party.
## First scene loaded — provides room creation, joining, settings, and quit.
## Enhanced with modern UI, animations, and improved UX.
extends Control

# ── Node References ───────────────────────────────────────────────────────────

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

@onready var version_label: Label = %VersionLabel

# Tutorial
var tutorial_overlay: CanvasLayer = null

# ── Constants ─────────────────────────────────────────────────────────────────

const PROFILE_PATH: String = "user://player_profile.cfg"
const CHARACTER_SELECT_SCENE: String = "res://ui/character_select/character_select.tscn"

# ── State ─────────────────────────────────────────────────────────────────────

## Discovered LAN games stored as an array of host_info dictionaries.
var _discovered: Array[Dictionary] = []

## Player display name persisted across sessions.
var _player_name: String = "Player"


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_player_profile()
	_setup_ui()
	_connect_signals()

	# Start LAN discovery so we can list available games.
	ConnectionManager.start_lan_discovery()

	# Play menu background music.
	AudioManager.play_music("menu")

	# Show tutorial for first-time users
	if is_instance_valid(TutorialManager) and TutorialManager.should_show_tutorial():
		_show_tutorial()

	# Add entrance animation
	_play_entrance_animation()

	# Show welcome notification
	if is_instance_valid(NotificationManager):
		NotificationManager.show_info("Welcome to BattleZone Party!")


func _exit_tree() -> void:
	ConnectionManager.lan_game_discovered.disconnect(_on_discovered_game)
	if tutorial_overlay != null:
		tutorial_overlay.queue_free()


# ── Profile Persistence ───────────────────────────────────────────────────────

func _load_player_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) == OK:
		_player_name = cfg.get_value("profile", "name", "Player")
	Lobby.set_local_player_name(_player_name)


func _save_player_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "name", _player_name)
	cfg.save(PROFILE_PATH)


# ── UI Setup ──────────────────────────────────────────────────────────────────

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

	# Button hover effects
	_setup_button_hover_effects()


# ── Button Handlers ───────────────────────────────────────────────────────────

func _on_create_pressed() -> void:
	# Validate player name
	if _player_name.strip_edges().is_empty():
		if is_instance_valid(NotificationManager):
			NotificationManager.show_warning("Please enter a player name in Settings first!")
		_show_panel(settings_panel)
		return

	var err: Error = ConnectionManager.host_game(_player_name)
	if err != OK:
		push_warning("MainMenu: Failed to host game — %s" % error_string(err))
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

	if is_instance_valid(NotificationManager):
		NotificationManager.show_info("Refreshing game list...")


func _on_manual_ip_pressed() -> void:
	_show_panel(manual_ip_panel)


func _on_connect_button_pressed() -> void:
	var ip: String = ip_input.text.strip_edges()
	if ip.is_empty():
		if is_instance_valid(NotificationManager):
			NotificationManager.show_warning("Please enter an IP address!")
		return

	# Validate IP format (basic check)
	if not _is_valid_ip(ip):
		if is_instance_valid(NotificationManager):
			NotificationManager.show_warning("Invalid IP address format!")
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
		push_warning("MainMenu: Failed to join game at %s — %s" % [ip, error_string(err)])
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
	var label: String = "%s — %d/%d players" % [
		info.get("host_name", "Unknown"),
		info.get("player_count", 0),
		info.get("max_players", 8),
	]
	discovered_games.add_item(label)

	# Hide searching label when games are found
	if searching_label and _discovered.size() > 0:
		searching_label.visible = false

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
	get_tree().quit()


func _on_back_pressed() -> void:
	_hide_all_panels()
	if searching_label:
		searching_label.visible = false


func _on_manual_back_pressed() -> void:
	_show_panel(join_panel)


func _on_settings_back_pressed() -> void:
	_save_player_profile()
	_hide_all_panels()


func _on_connection_failed() -> void:
	if is_instance_valid(NotificationManager):
		NotificationManager.show_error("Connection failed! Please try again.")


func _on_connected_to_host() -> void:
	if is_instance_valid(NotificationManager):
		NotificationManager.show_success("Connected successfully!")

	# Play transition animation
	_play_transition_animation()
	await get_tree().create_timer(0.5).timeout

	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


# ── Settings Handlers ─────────────────────────────────────────────────────────

func _on_name_changed(new_text: String) -> void:
	_player_name = new_text.strip_edges() if not new_text.strip_edges().is_empty() else "Player"
	Lobby.set_local_player_name(_player_name)


func _on_master_volume_changed(value: float) -> void:
	AudioManager.master_volume = value


func _on_music_volume_changed(value: float) -> void:
	AudioManager.music_volume = value


func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.sfx_volume = value


# ── Helpers ───────────────────────────────────────────────────────────────────

func _show_panel(panel: PanelContainer) -> void:
	_hide_all_panels()
	panel.visible = true
	button_container.visible = false
	_animate_panel_entrance(panel)


func _hide_all_panels() -> void:
	join_panel.visible = false
	manual_ip_panel.visible = false
	settings_panel.visible = false
	button_container.visible = true


# ── Animation Functions ───────────────────────────────────────────────────────

func _play_entrance_animation() -> void:
	# Fade in and slide up animation for main menu
	title_container.modulate.a = 0.0
	button_container.modulate.a = 0.0
	title_container.position.y += 50
	button_container.position.y += 50

	var tween := create_tween().set_parallel(true)
	tween.tween_property(title_container, "modulate:a", 1.0, 0.6)
	tween.tween_property(title_container, "position:y", title_container.position.y - 50, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.2).timeout

	var tween2 := create_tween().set_parallel(true)
	tween2.tween_property(button_container, "modulate:a", 1.0, 0.6)
	tween2.tween_property(button_container, "position:y", button_container.position.y - 50, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _play_transition_animation() -> void:
	# Fade out animation
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)


func _animate_panel_entrance(panel: PanelContainer) -> void:
	# Slide and fade in animation for panels
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_searching_text() -> void:
	if not searching_label:
		return

	var base_text: String = "Searching for games"
	var dots: int = 0

	while searching_label.visible and join_panel.visible:
		dots = (dots + 1) % 4
		searching_label.text = base_text + ".".repeat(dots)
		await get_tree().create_timer(0.5).timeout


func _setup_button_hover_effects() -> void:
	# Add hover effects to all main buttons
	var buttons: Array[Button] = [
		create_button, join_button, settings_button, quit_button
	]

	for button: Button in buttons:
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.mouse_exited.connect(_on_button_unhover.bind(button))


func _on_button_hover(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("button_hover")


func _on_button_unhover(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)


# ── Tutorial Functions ────────────────────────────────────────────────────────

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


# ── Validation Functions ──────────────────────────────────────────────────────

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
