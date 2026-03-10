## Premium Character Selection Screen - Valorant/Apex Legends Inspired
## Features dramatic animations, holographic effects, and smooth interactions.
## Complete overhaul with professional-grade UI/UX.
extends Control

# ---- Signals ----
signal character_locked_in(skin_id: int)

# ---- Preloaded Scripts ----
const CharacterCardScript: GDScript = preload("res://ui/character_select/character_card.gd")
const CharacterPreviewScript: GDScript = preload("res://ui/character_select/character_preview.gd")
const LobbyDisplayScript: GDScript = preload("res://ui/character_select/lobby_display.gd")

# ---- Node References ----
@onready var background: ColorRect = $Background
@onready var animated_bg: ColorRect = $AnimatedBackground
@onready var title_container: Control = $TitleContainer
@onready var character_grid: GridContainer = $CharacterGrid
@onready var character_preview: Control = $CharacterPreview
@onready var lobby_display: Control = $LobbyDisplay
@onready var bottom_bar: Control = $BottomBar
@onready var back_button: Button = $BottomBar/HBox/BackButton
@onready var ready_button: Button = $BottomBar/HBox/ReadyButton
@onready var start_button: Button = $BottomBar/HBox/StartButton
@onready var randomize_button: Button = $BottomBar/HBox/RandomizeButton
@onready var game_picker: PanelContainer = $GamePicker
@onready var game_list: VBoxContainer = $GamePicker/VBox/GameList
@onready var lock_in_overlay: Control = $LockInOverlay
@onready var transition_overlay: ColorRect = $TransitionOverlay

# Chat panel
var chat_panel: Control = null

# ---- Constants ----
const MAIN_MENU_SCENE: String = "res://ui/main_menu/main_menu.tscn"
const CARD_SIZE: Vector2 = Vector2(160, 200)
const GRID_COLUMNS: int = 3

# ---- Rarity Distribution ----
const RARITY_MAP: Dictionary = {
	0: 0,  # Robot - Common
	1: 2,  # Ninja - Epic
	2: 1,  # Astronaut - Rare
	3: 1,  # Pirate - Rare
	4: 2,  # Knight - Epic
	5: 3,  # Alien - Legendary
}

# ---- State ----
var _skins: Array[CharacterSkin] = []
var _selected_skin_id: int = 0
var _character_cards: Dictionary = {}  # skin_id -> CharacterCard
var _is_locked_in: bool = false
var _entrance_complete: bool = false


func _ready() -> void:
	_skins = DefaultSkins.get_all()
	_build_premium_ui()
	_connect_signals()
	_update_host_ui()
	_setup_chat_panel()

	# Start entrance sequence
	_play_entrance_sequence()

	# Show welcome notification
	_show_welcome_notification()


func _exit_tree() -> void:
	if Lobby.player_joined.is_connected(_on_player_joined):
		Lobby.player_joined.disconnect(_on_player_joined)
	if Lobby.player_left.is_connected(_on_player_left):
		Lobby.player_left.disconnect(_on_player_left)
	if Lobby.player_updated.is_connected(_on_player_updated):
		Lobby.player_updated.disconnect(_on_player_updated)
	if Lobby.all_players_ready.is_connected(_on_all_players_ready):
		Lobby.all_players_ready.disconnect(_on_all_players_ready)
	if Lobby.game_starting.is_connected(_on_game_starting):
		Lobby.game_starting.disconnect(_on_game_starting)


# ============================================================================
# UI CONSTRUCTION
# ============================================================================

func _build_premium_ui() -> void:
	# Main background with shader
	_setup_animated_background()

	# Title with dramatic styling
	_build_title_section()

	# Character grid with premium cards
	_build_character_grid()

	# Character preview panel
	_build_preview_panel()

	# Player lobby display
	_build_lobby_display()

	# Bottom action bar
	_build_bottom_bar()

	# Game picker overlay
	_build_game_picker()

	# Lock-in overlay for dramatic effect
	_build_lock_in_overlay()

	# Transition overlay
	_build_transition_overlay()


func _setup_animated_background() -> void:
	# Base background
	if not background:
		background = ColorRect.new()
		background.name = "Background"
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.color = Color(0.04, 0.04, 0.08, 1)
		add_child(background)

	# Animated shader background
	if not animated_bg:
		animated_bg = ColorRect.new()
		animated_bg.name = "AnimatedBackground"
		animated_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		animated_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(animated_bg)

	# Apply shader if available
	var shader: Shader = load("res://shared/shaders/select_background.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		animated_bg.material = mat


func _build_title_section() -> void:
	if not title_container:
		title_container = Control.new()
		title_container.name = "TitleContainer"
		title_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
		title_container.offset_bottom = 120
		add_child(title_container)

	# Clear existing children
	for child: Node in title_container.get_children():
		child.queue_free()

	# Main title
	var title := Label.new()
	title.name = "Title"
	title.text = "SELECT YOUR FIGHTER"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 30
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 4)
	title_container.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Choose wisely - your legend awaits"
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_top = 85
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	title_container.add_child(subtitle)

	# Animated underline
	var underline := ColorRect.new()
	underline.name = "Underline"
	underline.set_anchors_preset(Control.PRESET_CENTER_TOP)
	underline.offset_top = 78
	underline.offset_left = -150
	underline.offset_right = 150
	underline.offset_bottom = 80
	underline.color = Color(0.9, 0.7, 0.2, 0.8)
	title_container.add_child(underline)

	# Underline glow animation
	var tween := create_tween().set_loops()
	tween.tween_property(underline, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(underline, "modulate:a", 0.6, 1.0).set_trans(Tween.TRANS_SINE)


func _build_character_grid() -> void:
	if not character_grid:
		character_grid = GridContainer.new()
		character_grid.name = "CharacterGrid"
		character_grid.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		character_grid.offset_left = 40
		character_grid.offset_top = -200
		character_grid.offset_right = 560
		character_grid.offset_bottom = 200
		add_child(character_grid)

	character_grid.columns = GRID_COLUMNS
	character_grid.add_theme_constant_override("h_separation", 16)
	character_grid.add_theme_constant_override("v_separation", 16)

	# Clear existing
	for child: Node in character_grid.get_children():
		child.queue_free()
	_character_cards.clear()

	# Create premium cards for each skin
	for skin: CharacterSkin in _skins:
		var card: CharacterCard = CharacterCardScript.new() as CharacterCard
		card.custom_minimum_size = CARD_SIZE
		card.skin = skin
		card.rarity = RARITY_MAP.get(skin.skin_id, 0)

		card.card_selected.connect(_on_card_selected)
		card.card_hovered.connect(_on_card_hovered)
		card.card_info_requested.connect(_on_card_info_requested)

		character_grid.add_child(card)
		_character_cards[skin.skin_id] = card

	# Select first character by default
	if _skins.size() > 0:
		_select_character(0)


func _build_preview_panel() -> void:
	if not character_preview:
		character_preview = CharacterPreviewScript.new() as Control
		character_preview.name = "CharacterPreview"
		character_preview.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		character_preview.offset_left = -440
		character_preview.offset_top = -280
		character_preview.offset_right = -40
		character_preview.offset_bottom = 320
		add_child(character_preview)


func _build_lobby_display() -> void:
	if not lobby_display:
		lobby_display = LobbyDisplayScript.new() as Control
		lobby_display.name = "LobbyDisplay"
		lobby_display.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		lobby_display.offset_left = -360
		lobby_display.offset_top = 130
		lobby_display.offset_right = -20
		lobby_display.offset_bottom = 450
		add_child(lobby_display)

	# Initial player update
	_update_lobby_display()


func _build_bottom_bar() -> void:
	if not bottom_bar:
		bottom_bar = PanelContainer.new()
		bottom_bar.name = "BottomBar"
		bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bottom_bar.offset_top = -100
		add_child(bottom_bar)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.02, 0.04, 0.95)
		style.border_color = Color(0.15, 0.2, 0.3, 0.8)
		style.border_width_top = 2
		style.set_content_margin_all(15)
		bottom_bar.add_theme_stylebox_override("panel", style)

	# HBox for buttons
	var hbox: HBoxContainer = bottom_bar.get_node_or_null("HBox") as HBoxContainer
	if not hbox:
		hbox = HBoxContainer.new()
		hbox.name = "HBox"
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 20)
		bottom_bar.add_child(hbox)

	# Clear existing buttons
	for child: Node in hbox.get_children():
		child.queue_free()

	# Back button
	back_button = _create_action_button("BACK", Color(0.5, 0.5, 0.6, 1))
	back_button.name = "BackButton"
	hbox.add_child(back_button)

	# Randomize button
	randomize_button = _create_action_button("RANDOM", Color(0.6, 0.4, 0.8, 1))
	randomize_button.name = "RandomizeButton"
	hbox.add_child(randomize_button)

	# Ready button
	ready_button = _create_action_button("READY", Color(0.3, 0.7, 0.4, 1))
	ready_button.name = "ReadyButton"
	ready_button.toggle_mode = true
	ready_button.custom_minimum_size = Vector2(200, 60)
	hbox.add_child(ready_button)

	# Start button (host only)
	start_button = _create_action_button("START GAME", Color(0.9, 0.7, 0.2, 1))
	start_button.name = "StartButton"
	start_button.custom_minimum_size = Vector2(220, 60)
	hbox.add_child(start_button)


func _create_action_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 60)
	btn.add_theme_font_size_override("font_size", 22)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9)
	normal.border_color = color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.95)
	hover.border_color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 1)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 1)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.2, 1.2, 1.2, 1))

	return btn


func _build_game_picker() -> void:
	if not game_picker:
		game_picker = PanelContainer.new()
		game_picker.name = "GamePicker"
		game_picker.visible = false
		game_picker.set_anchors_preset(Control.PRESET_CENTER)
		game_picker.offset_left = -300
		game_picker.offset_top = -350
		game_picker.offset_right = 300
		game_picker.offset_bottom = 350
		add_child(game_picker)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.06, 0.98)
	style.border_color = Color(0.9, 0.7, 0.2, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 20
	game_picker.add_theme_stylebox_override("panel", style)

	var vbox := game_picker.get_node_or_null("VBox") as VBoxContainer
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		vbox.add_theme_constant_override("separation", 20)
		game_picker.add_child(vbox)

		# Title
		var title := Label.new()
		title.text = "CHOOSE GAME MODE"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 32)
		title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1))
		vbox.add_child(title)

		# Subtitle
		var subtitle := Label.new()
		subtitle.text = "Select a mini-game to play with your party"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 16)
		subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
		vbox.add_child(subtitle)

		# Game list
		game_list = VBoxContainer.new()
		game_list.name = "GameList"
		game_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		game_list.add_theme_constant_override("separation", 12)
		vbox.add_child(game_list)


func _build_lock_in_overlay() -> void:
	if not lock_in_overlay:
		lock_in_overlay = Control.new()
		lock_in_overlay.name = "LockInOverlay"
		lock_in_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_in_overlay.visible = false
		lock_in_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lock_in_overlay)


func _build_transition_overlay() -> void:
	if not transition_overlay:
		transition_overlay = ColorRect.new()
		transition_overlay.name = "TransitionOverlay"
		transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		transition_overlay.color = Color(0, 0, 0, 0)
		transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(transition_overlay)


# ============================================================================
# SIGNAL CONNECTIONS
# ============================================================================

func _connect_signals() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if ready_button:
		ready_button.toggled.connect(_on_ready_toggled)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if randomize_button:
		randomize_button.pressed.connect(_on_randomize_pressed)

	Lobby.player_joined.connect(_on_player_joined)
	Lobby.player_left.connect(_on_player_left)
	Lobby.player_updated.connect(_on_player_updated)
	Lobby.all_players_ready.connect(_on_all_players_ready)
	Lobby.game_starting.connect(_on_game_starting)

	_setup_button_animations()


func _setup_button_animations() -> void:
	var buttons: Array[Button] = [back_button, ready_button, start_button, randomize_button]

	for button: Button in buttons:
		if button:
			button.mouse_entered.connect(_on_button_hover.bind(button))
			button.mouse_exited.connect(_on_button_unhover.bind(button))


# ============================================================================
# CHARACTER SELECTION
# ============================================================================

func _on_card_selected(skin_id: int) -> void:
	if _is_locked_in:
		return

	_select_character(skin_id)
	_play_selection_sound()


func _on_card_hovered(skin_id: int) -> void:
	# Could show preview on hover
	pass


func _on_card_info_requested(skin_id: int) -> void:
	# Show detailed info panel
	if is_instance_valid(NotificationManager):
		if skin_id >= 0 and skin_id < _skins.size():
			var skin: CharacterSkin = _skins[skin_id]
			NotificationManager.show_info(skin.description)


func _select_character(skin_id: int) -> void:
	# Update selection state
	var previous_id: int = _selected_skin_id
	_selected_skin_id = skin_id

	# Deselect previous card
	if previous_id in _character_cards:
		var prev_card: CharacterCard = _character_cards[previous_id] as CharacterCard
		prev_card.set_selected(false)

	# Select new card
	if skin_id in _character_cards:
		var new_card: CharacterCard = _character_cards[skin_id] as CharacterCard
		new_card.set_selected(true)

	# Update preview
	if character_preview and skin_id >= 0 and skin_id < _skins.size():
		character_preview.set_character(_skins[skin_id])

	# Update background theme
	_update_background_theme(skin_id)

	# Update lobby
	Lobby.set_local_character(skin_id)


func _update_background_theme(skin_id: int) -> void:
	if not animated_bg or not animated_bg.material:
		return

	if skin_id < 0 or skin_id >= _skins.size():
		return

	var skin: CharacterSkin = _skins[skin_id]
	var mat: ShaderMaterial = animated_bg.material as ShaderMaterial

	if mat:
		mat.set_shader_parameter("accent_color", skin.accent_color)
		mat.set_shader_parameter("secondary_color", skin.mesh_color)


# ============================================================================
# READY / START
# ============================================================================

func _on_ready_toggled(toggled_on: bool) -> void:
	Lobby.toggle_ready()

	if toggled_on:
		ready_button.text = "UNREADY"
		_play_lock_in_effect()
		_is_locked_in = true

		if is_instance_valid(NotificationManager):
			NotificationManager.show_success("LOCKED IN!")
	else:
		ready_button.text = "READY"
		_is_locked_in = false

		if is_instance_valid(NotificationManager):
			NotificationManager.show_info("Selection unlocked")

	_play_button_sound()


func _play_lock_in_effect() -> void:
	# Flash overlay
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.6)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.4)
	tween.tween_callback(flash.queue_free)

	# Character preview lock-in
	if character_preview and character_preview.has_method("play_lock_in_animation"):
		character_preview.play_lock_in_animation()

	# Sound
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("lock_in")


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
		_shake_start_button()
		return

	# Show game picker with animation
	game_picker.visible = true
	_populate_game_picker()
	_animate_panel_entrance(game_picker)


func _shake_start_button() -> void:
	if not start_button:
		return

	var orig_x: float = start_button.position.x
	var tween := create_tween()
	tween.tween_property(start_button, "position:x", orig_x - 8, 0.05)
	tween.tween_property(start_button, "position:x", orig_x + 8, 0.05)
	tween.tween_property(start_button, "position:x", orig_x - 5, 0.05)
	tween.tween_property(start_button, "position:x", orig_x + 5, 0.05)
	tween.tween_property(start_button, "position:x", orig_x, 0.05)


func _populate_game_picker() -> void:
	for child: Node in game_list.get_children():
		child.queue_free()

	var games: Array[Dictionary] = GameManager.get_available_games()
	var index: int = 0

	for game_info: Dictionary in games:
		var btn := _create_game_button(game_info)
		game_list.add_child(btn)

		# Staggered entrance
		btn.modulate.a = 0.0
		btn.position.y += 20
		var tween := create_tween().set_parallel(true)
		tween.tween_interval(index * 0.05)
		tween.tween_property(btn, "modulate:a", 1.0, 0.2)
		tween.tween_property(btn, "position:y", btn.position.y - 20, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		index += 1

	# Cancel button
	var cancel := _create_action_button("CANCEL", Color(0.6, 0.3, 0.3, 1))
	cancel.pressed.connect(func() -> void:
		_animate_panel_exit(game_picker)
	)
	game_list.add_child(cancel)


func _create_game_button(game_info: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = game_info.get("name", "Unknown Game")
	btn.custom_minimum_size = Vector2(0, 70)
	btn.add_theme_font_size_override("font_size", 24)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.9)
	style.border_color = Color(0.3, 0.5, 0.8, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.15, 0.25, 0.95)
	hover.border_color = Color(0.4, 0.7, 1.0, 1)
	btn.add_theme_stylebox_override("hover", hover)

	var game_id: String = game_info.get("id", "")
	btn.pressed.connect(_on_game_picked.bind(game_id))

	return btn


func _on_game_picked(game_id: String) -> void:
	_animate_panel_exit(game_picker)

	Lobby.select_game(game_id)

	var info: Dictionary = GameManager.get_game_info(game_id)
	var modes: Array = info.get("supported_modes", [])
	var mode: String = modes[0] if modes.size() > 0 else "ffa"
	GameManager.set_current_game(game_id, mode)

	# Play transition effect
	_play_game_start_transition()

	await get_tree().create_timer(0.5).timeout
	Lobby.start_game()


func _play_game_start_transition() -> void:
	if not transition_overlay:
		return

	var tween := create_tween()
	tween.tween_property(transition_overlay, "color:a", 1.0, 0.5)


# ============================================================================
# RANDOMIZE
# ============================================================================

func _on_randomize_pressed() -> void:
	if _is_locked_in:
		if is_instance_valid(NotificationManager):
			NotificationManager.show_warning("Unready to change character")
		return

	# Spin animation on button
	_animate_randomize_button()

	# Random selection with dramatic reveal
	var random_id: int = randi() % _skins.size()

	# Quick flash through characters
	var flash_count: int = 8
	var current: int = _selected_skin_id

	for i: int in range(flash_count):
		current = (current + 1) % _skins.size()
		await get_tree().create_timer(0.05 + i * 0.02).timeout

		# Quick select without full animation
		if current in _character_cards:
			var card: CharacterCard = _character_cards[current] as CharacterCard
			card.modulate = Color(1.3, 1.3, 1.3, 1)
			var restore_tween := create_tween()
			restore_tween.tween_property(card, "modulate", Color.WHITE, 0.1)

	# Final selection
	_select_character(random_id)

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("character_select")


func _animate_randomize_button() -> void:
	if not randomize_button:
		return

	var tween := create_tween()
	tween.tween_property(randomize_button, "rotation", TAU, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(randomize_button, "rotation", 0.0, 0.0)


# ============================================================================
# LOBBY UPDATES
# ============================================================================

func _update_lobby_display() -> void:
	if lobby_display and lobby_display.has_method("update_players"):
		lobby_display.update_players(Lobby.players, _skins)


func _update_host_ui() -> void:
	var is_host: bool = multiplayer.is_server() if multiplayer.has_multiplayer_peer() else true
	if start_button:
		start_button.visible = is_host


func _on_player_joined(_peer_id: int, info: Dictionary) -> void:
	_update_lobby_display()
	if is_instance_valid(NotificationManager):
		var player_name: String = info.get("name", "Player")
		NotificationManager.show_info("%s joined the lobby" % player_name)


func _on_player_left(_peer_id: int) -> void:
	_update_lobby_display()


func _on_player_updated(_peer_id: int, _info: Dictionary) -> void:
	_update_lobby_display()


func _on_all_players_ready() -> void:
	if is_instance_valid(NotificationManager):
		NotificationManager.show_success("ALL PLAYERS READY!")

	if lobby_display and lobby_display.has_method("play_all_ready_animation"):
		lobby_display.play_all_ready_animation()


func _on_game_starting(_game_id: String) -> void:
	if is_instance_valid(NotificationManager):
		NotificationManager.show_success("GAME STARTING!")

	_play_game_start_transition()


# ============================================================================
# NAVIGATION
# ============================================================================

func _on_back_pressed() -> void:
	_play_exit_sequence()

	await get_tree().create_timer(0.4).timeout

	ConnectionManager.shutdown()
	Lobby.reset_session()
	ChatManager.clear_history()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# ============================================================================
# ANIMATIONS
# ============================================================================

func _play_entrance_sequence() -> void:
	# Start with screen black
	if transition_overlay:
		transition_overlay.color = Color(0, 0, 0, 1)

	# Fade in background
	var bg_tween := create_tween()
	bg_tween.tween_property(transition_overlay, "color:a", 0.0, 0.5)

	await get_tree().create_timer(0.2).timeout

	# Cascade in character cards
	var card_index: int = 0
	for skin_id: int in _character_cards:
		var card: CharacterCard = _character_cards[skin_id] as CharacterCard
		if card.has_method("animate_entrance"):
			card.animate_entrance(card_index * 0.08)
		card_index += 1

	# Title entrance
	if title_container:
		title_container.modulate.a = 0.0
		title_container.position.y -= 30

		var title_tween := create_tween().set_parallel(true)
		title_tween.tween_property(title_container, "modulate:a", 1.0, 0.4)
		title_tween.tween_property(title_container, "position:y", title_container.position.y + 30, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Bottom bar slide up
	if bottom_bar:
		bottom_bar.position.y += 100
		var bar_tween := create_tween()
		bar_tween.tween_interval(0.3)
		bar_tween.tween_property(bottom_bar, "position:y", bottom_bar.position.y - 100, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Preview panel
	if character_preview:
		character_preview.modulate.a = 0.0
		character_preview.position.x += 50

		var preview_tween := create_tween().set_parallel(true)
		preview_tween.tween_interval(0.2)
		preview_tween.tween_property(character_preview, "modulate:a", 1.0, 0.4)
		preview_tween.tween_property(character_preview, "position:x", character_preview.position.x - 50, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Lobby display
	if lobby_display:
		lobby_display.modulate.a = 0.0

		var lobby_tween := create_tween()
		lobby_tween.tween_interval(0.4)
		lobby_tween.tween_property(lobby_display, "modulate:a", 1.0, 0.3)

	_entrance_complete = true


func _play_exit_sequence() -> void:
	# Fade to black
	if transition_overlay:
		var tween := create_tween()
		tween.tween_property(transition_overlay, "color:a", 1.0, 0.4)


func _animate_panel_entrance(panel: Control) -> void:
	if not panel:
		return

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3)


func _animate_panel_exit(panel: Control) -> void:
	if not panel:
		return

	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.2)
	tween.chain().tween_callback(func() -> void: panel.visible = false)


func _on_button_hover(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("button_hover")


func _on_button_unhover(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.1)


# ============================================================================
# HELPERS
# ============================================================================

func _setup_chat_panel() -> void:
	var chat_scene: PackedScene = load("res://ui/chat/chat_panel.tscn")
	if chat_scene:
		chat_panel = chat_scene.instantiate() as Control
		add_child(chat_panel)


func _show_welcome_notification() -> void:
	if is_instance_valid(NotificationManager):
		var is_host: bool = multiplayer.is_server() if multiplayer.has_multiplayer_peer() else true
		if is_host:
			NotificationManager.show_info("Waiting for players to join...")
		else:
			NotificationManager.show_success("Connected to lobby!")


func _play_selection_sound() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("character_select")


func _play_button_sound() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("button_click")
