## Character selection screen for BattleZone Party.
## Displays a grid of available skins, connected player list, ready toggle, and
## (for the host) a start button that opens the mini-game picker.
extends Control

# ── Node References ───────────────────────────────────────────────────────────

@onready var character_grid: GridContainer = %CharacterGrid
@onready var player_list: VBoxContainer = %PlayerList
@onready var back_button: Button = %BackButton
@onready var ready_button: Button = %ReadyButton
@onready var start_button: Button = %StartButton
@onready var game_picker: PanelContainer = %GamePicker
@onready var game_list: VBoxContainer = %GameList

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
	game_picker.visible = false


func _exit_tree() -> void:
	Lobby.player_joined.disconnect(_on_player_joined)
	Lobby.player_left.disconnect(_on_player_left)
	Lobby.player_updated.disconnect(_on_player_updated)


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


# ── Character Selection ───────────────────────────────────────────────────────

func _on_character_selected(skin_id: int) -> void:
	_selected_skin_id = skin_id
	Lobby.set_local_character(skin_id)
	_highlight_selected_card(skin_id)


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
	ready_button.text = "UNREADY" if toggled_on else "READY"


func _on_start_pressed() -> void:
	game_picker.visible = true
	_populate_game_picker()


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
		child.queue_free()

	for peer_id: int in Lobby.players:
		var info: Dictionary = Lobby.players[peer_id]
		var entry := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = info.get("name", "Player")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 24)
		entry.add_child(name_label)

		var skin_id: int = info.get("character_id", 0)
		var skin_label := Label.new()
		if skin_id >= 0 and skin_id < _skins.size():
			skin_label.text = _skins[skin_id].skin_name
		else:
			skin_label.text = "???"
		skin_label.add_theme_font_size_override("font_size", 24)
		entry.add_child(skin_label)

		var ready_label := Label.new()
		ready_label.text = " ✓" if info.get("ready", false) else ""
		ready_label.add_theme_font_size_override("font_size", 24)
		ready_label.add_theme_color_override("font_color", Color.GREEN)
		entry.add_child(ready_label)

		player_list.add_child(entry)


func _update_host_ui() -> void:
	var is_host: bool = multiplayer.is_server() if multiplayer.has_multiplayer_peer() else true
	start_button.visible = is_host


# ── Lobby Signal Handlers ────────────────────────────────────────────────────

func _on_player_joined(_peer_id: int, _info: Dictionary) -> void:
	_update_player_list()


func _on_player_left(_peer_id: int) -> void:
	_update_player_list()


func _on_player_updated(_peer_id: int, _info: Dictionary) -> void:
	_update_player_list()


# ── Navigation ────────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	ConnectionManager.shutdown()
	Lobby.reset_session()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
