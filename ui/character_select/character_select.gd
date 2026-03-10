## Character selection screen for BattleZone Party.
## Displays a grid of available skins, connected player list, ready toggle, and
## (for the host) a start button that opens the mini-game picker.
## Enhanced with animations, chat, and modern UI.
extends Control

# ── Node References ───────────────────────────────────────────────────────────

@onready var character_grid: GridContainer = %CharacterGrid
@onready var player_list: VBoxContainer = %PlayerList
@onready var back_button: Button = %BackButton
@onready var ready_button: Button = %ReadyButton
@onready var start_button: Button = %StartButton
@onready var game_picker: PanelContainer = %GamePicker
@onready var game_list: VBoxContainer = %GameList
@onready var lobby_info_label: Label = %LobbyInfoLabel

# Chat panel
var chat_panel: Control = null

# ── Constants ─────────────────────────────────────────────────────────────────

const MAIN_MENU_SCENE: String = "res://ui/main_menu/main_menu.tscn"
const CARD_MIN_SIZE: Vector2 = Vector2(140, 160)

# ── State ─────────────────────────────────────────────────────────────────────

## All available character skins loaded from DefaultSkins.
var _skins: Array[CharacterSkin] = []

## Currently selected skin id for the local player.
var _selected_skin_id: int = 0

## Lookup from skin_id to the card Button node for highlight management.
var _card_buttons: Dictionary = {}


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_skins = DefaultSkins.get_all()
	_populate_character_grid()
	_connect_signals()
	_update_host_ui()
	_update_player_list()
	_update_lobby_info()
	game_picker.visible = false

	# Load and add chat panel
	_setup_chat_panel()

	# Play entrance animation
	_play_entrance_animation()

	# Show welcome notification
	if is_instance_valid(NotificationManager):
		var is_host: bool = multiplayer.is_server() if multiplayer.has_multiplayer_peer() else true
		if is_host:
			NotificationManager.show_info("Waiting for players to join...")
		else:
			NotificationManager.show_success("Connected to lobby!")


func _exit_tree() -> void:
	Lobby.player_joined.disconnect(_on_player_joined)
	Lobby.player_left.disconnect(_on_player_left)
	Lobby.player_updated.disconnect(_on_player_updated)
	Lobby.all_players_ready.disconnect(_on_all_players_ready)
	Lobby.game_starting.disconnect(_on_game_starting)


# ── Setup ─────────────────────────────────────────────────────────────────────

func _populate_character_grid() -> void:
	# Clear any placeholder children.
	for child: Node in character_grid.get_children():
		child.queue_free()

	_card_buttons.clear()

	for skin: CharacterSkin in _skins:
		var card := Button.new()
		card.custom_minimum_size = CARD_MIN_SIZE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.clip_text = true
		card.add_theme_font_size_override("font_size", 24)

		# Build a simple visual: colored rect + name label inside a VBox.
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var color_rect := ColorRect.new()
		color_rect.custom_minimum_size = Vector2(80, 80)
		color_rect.color = skin.mesh_color
		color_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(color_rect)

		var name_label := Label.new()
		name_label.text = skin.skin_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 24)
		vbox.add_child(name_label)

		card.add_child(vbox)

		var skin_id: int = skin.skin_id
		card.pressed.connect(_on_character_selected.bind(skin_id))
		character_grid.add_child(card)
		_card_buttons[skin_id] = card

	# Highlight first skin by default.
	_on_character_selected(0)


func _connect_signals() -> void:
	back_button.pressed.connect(_on_back_pressed)
	ready_button.toggled.connect(_on_ready_toggled)
	start_button.pressed.connect(_on_start_pressed)

	Lobby.player_joined.connect(_on_player_joined)
	Lobby.player_left.connect(_on_player_left)
	Lobby.player_updated.connect(_on_player_updated)
	Lobby.all_players_ready.connect(_on_all_players_ready)
	Lobby.game_starting.connect(_on_game_starting)

	# Button hover effects
	_setup_button_hover_effects()


# ── Character Selection ───────────────────────────────────────────────────────

func _on_character_selected(skin_id: int) -> void:
	_selected_skin_id = skin_id
	Lobby.set_local_character(skin_id)
	_highlight_selected_card(skin_id)

	# Play selection sound
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("character_select")

	# Animate the selected card
	if _card_buttons.has(skin_id):
		_animate_card_selection(_card_buttons[skin_id] as Button)


func _highlight_selected_card(skin_id: int) -> void:
	for id: int in _card_buttons:
		var btn: Button = _card_buttons[id] as Button
		if id == skin_id:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			btn.add_theme_stylebox_override("normal", _make_highlight_style())
		else:
			btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
			btn.remove_theme_stylebox_override("normal")


func _make_highlight_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.9, 0.3)
	style.border_color = Color(0.3, 0.6, 1.0, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	return style


# ── Ready / Start ─────────────────────────────────────────────────────────────

func _on_ready_toggled(toggled_on: bool) -> void:
	Lobby.toggle_ready()
	ready_button.text = "✓ UNREADY" if toggled_on else "READY"

	if is_instance_valid(NotificationManager):
		if toggled_on:
			NotificationManager.show_success("You are ready!")
		else:
			NotificationManager.show_info("Not ready")

	# Play sound
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("button_click")


func _on_start_pressed() -> void:
	# Check if all players are ready
	var all_ready: bool = true
	for peer_id: int in Lobby.players:
		if not Lobby.players[peer_id].get("ready", false):
			all_ready = false
			break

	if not all_ready:
		if is_instance_valid(NotificationManager):
			NotificationManager.show_warning("Not all players are ready!")
		return

	game_picker.visible = true
	_populate_game_picker()
	_animate_panel_entrance(game_picker)


func _populate_game_picker() -> void:
	for child: Node in game_list.get_children():
		child.queue_free()

	var games: Array[Dictionary] = GameManager.get_available_games()
	for game_info: Dictionary in games:
		var btn := Button.new()
		btn.text = game_info.get("name", "Unknown")
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 26)
		var game_id: String = game_info.get("id", "")
		btn.pressed.connect(_on_game_picked.bind(game_id))
		game_list.add_child(btn)

	# Add a cancel button.
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(0, 60)
	cancel.add_theme_font_size_override("font_size", 26)
	cancel.pressed.connect(func() -> void: game_picker.visible = false)
	game_list.add_child(cancel)


func _on_game_picked(game_id: String) -> void:
	game_picker.visible = false
	Lobby.select_game(game_id)

	# Use the first supported mode as default.
	var info: Dictionary = GameManager.get_game_info(game_id)
	var modes: Array = info.get("supported_modes", [])
	var mode: String = modes[0] if modes.size() > 0 else "ffa"
	GameManager.set_current_game(game_id, mode)

	Lobby.start_game()


# ── Player List ───────────────────────────────────────────────────────────────

func _update_player_list() -> void:
	for child: Node in player_list.get_children():
		# Skip the title label
		if child is Label and child.text == "Players":
			continue
		child.queue_free()

	for peer_id: int in Lobby.players:
		var info: Dictionary = Lobby.players[peer_id]
		var entry := HBoxContainer.new()
		entry.theme_override_constants["separation"] = 12

		# Color indicator
		var color_rect := ColorRect.new()
		color_rect.custom_minimum_size = Vector2(32, 32)
		color_rect.color = info.get("color", Color.WHITE)
		entry.add_child(color_rect)

		# Player name
		var name_label := Label.new()
		name_label.text = info.get("name", "Player")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 24)
		entry.add_child(name_label)

		# Skin name
		var skin_id: int = info.get("character_id", 0)
		var skin_label := Label.new()
		if skin_id >= 0 and skin_id < _skins.size():
			skin_label.text = _skins[skin_id].skin_name
		else:
			skin_label.text = "???"
		skin_label.add_theme_font_size_override("font_size", 20)
		skin_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		entry.add_child(skin_label)

		# Ready status
		var ready_label := Label.new()
		if info.get("ready", false):
			ready_label.text = " ✓"
			ready_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			ready_label.text = " ⏳"
			ready_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3, 1))
		ready_label.add_theme_font_size_override("font_size", 24)
		entry.add_child(ready_label)

		player_list.add_child(entry)

	_update_lobby_info()


func _update_host_ui() -> void:
	var is_host: bool = multiplayer.is_server() if multiplayer.has_multiplayer_peer() else true
	start_button.visible = is_host


# ── Lobby Signal Handlers ────────────────────────────────────────────────────

func _on_player_joined(_peer_id: int, _info: Dictionary) -> void:
	_update_player_list()
	if is_instance_valid(NotificationManager):
		var player_name: String = _info.get("name", "Player")
		NotificationManager.show_info("%s joined the lobby" % player_name)


func _on_player_left(_peer_id: int) -> void:
	_update_player_list()


func _on_player_updated(_peer_id: int, _info: Dictionary) -> void:
	_update_player_list()


func _on_all_players_ready() -> void:
	if is_instance_valid(NotificationManager):
		NotificationManager.show_success("All players are ready!")


func _on_game_starting(_game_id: String) -> void:
	if is_instance_valid(NotificationManager):
		NotificationManager.show_success("Game starting!")


# ── Navigation ────────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	ConnectionManager.shutdown()
	Lobby.reset_session()
	ChatManager.clear_history()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# ── Helper Functions ──────────────────────────────────────────────────────────

func _setup_chat_panel() -> void:
	var chat_scene: PackedScene = load("res://ui/chat/chat_panel.tscn")
	if chat_scene:
		chat_panel = chat_scene.instantiate() as Control
		add_child(chat_panel)


func _update_lobby_info() -> void:
	if not lobby_info_label:
		return

	var player_count: int = Lobby.players.size()
	var max_players: int = ConnectionManager.max_players
	var ready_count: int = 0

	for peer_id: int in Lobby.players:
		if Lobby.players[peer_id].get("ready", false):
			ready_count += 1

	lobby_info_label.text = "Players: %d/%d | Ready: %d/%d" % [
		player_count, max_players, ready_count, player_count
	]


func _play_entrance_animation() -> void:
	# Fade in animation
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func _animate_panel_entrance(panel: Control) -> void:
	if not panel:
		return

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_card_selection(button: Button) -> void:
	if not button:
		return

	var original_scale: Vector2 = button.scale
	button.scale = Vector2(1.1, 1.1)

	var tween := create_tween()
	tween.tween_property(button, "scale", original_scale, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _setup_button_hover_effects() -> void:
	var buttons: Array[Button] = [back_button, ready_button, start_button]

	for button: Button in buttons:
		if button:
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
