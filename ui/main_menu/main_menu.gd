## Main menu screen for BattleZone Party.
## First scene loaded — provides room creation, joining, settings, and quit.
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
@onready var ip_input: LineEdit = %IPInput
@onready var connect_button: Button = %ConnectButton
@onready var discovered_games: ItemList = %DiscoveredGames
@onready var back_button: Button = %BackButton

# Settings panel
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var name_input: LineEdit = %NameInput
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var settings_back_button: Button = %SettingsBackButton

@onready var version_label: Label = %VersionLabel

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


func _exit_tree() -> void:
	ConnectionManager.lan_game_discovered.disconnect(_on_discovered_game)


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
	settings_panel.visible = false

	name_input.text = _player_name

	# Initialise sliders from AudioManager.
	master_slider.value = AudioManager.master_volume
	music_slider.value = AudioManager.music_volume
	sfx_slider.value = AudioManager.sfx_volume

	version_label.text = "v" + ProjectSettings.get_setting("application/config/version", "0.1.0")


func _connect_signals() -> void:
	create_button.pressed.connect(_on_create_pressed)
	join_button.pressed.connect(_on_join_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	connect_button.pressed.connect(_on_connect_button_pressed)
	back_button.pressed.connect(_on_back_pressed)
	discovered_games.item_selected.connect(_on_discovered_item_selected)

	settings_back_button.pressed.connect(_on_settings_back_pressed)
	name_input.text_changed.connect(_on_name_changed)
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	ConnectionManager.lan_game_discovered.connect(_on_discovered_game)


# ── Button Handlers ───────────────────────────────────────────────────────────

func _on_create_pressed() -> void:
	var err: Error = ConnectionManager.host_game(_player_name)
	if err != OK:
		push_warning("MainMenu: Failed to host game — %s" % error_string(err))
		return
	ConnectionManager.start_lan_broadcast()
	Lobby.set_local_player_name(_player_name)
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_join_pressed() -> void:
	_show_panel(join_panel)
	_discovered.clear()
	discovered_games.clear()


func _on_connect_button_pressed() -> void:
	var ip: String = ip_input.text.strip_edges()
	if ip.is_empty():
		return
	_on_connect_pressed(ip)


func _on_connect_pressed(ip: String) -> void:
	var err: Error = ConnectionManager.join_game(ip, _player_name)
	if err != OK:
		push_warning("MainMenu: Failed to join game at %s — %s" % [ip, error_string(err)])
		return
	Lobby.set_local_player_name(_player_name)
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_discovered_game(info: Dictionary) -> void:
	# Avoid duplicate entries for the same host IP.
	for existing: Dictionary in _discovered:
		if existing.get("ip", "") == info.get("ip", ""):
			return

	_discovered.append(info)
	var label: String = "%s (%s) — %d/%d" % [
		info.get("host_name", "Unknown"),
		info.get("ip", "?"),
		info.get("player_count", 0),
		info.get("max_players", 8),
	]
	discovered_games.add_item(label)


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


func _on_settings_back_pressed() -> void:
	_save_player_profile()
	_hide_all_panels()


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


func _hide_all_panels() -> void:
	join_panel.visible = false
	settings_panel.visible = false
	button_container.visible = true
