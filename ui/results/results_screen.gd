## Results / leaderboard screen for BattleZone Party.
## Displays final standings with placement, player name, and score.
## The round winner is highlighted with a gold label.
## Host has a "Play Again" button; all players can return to lobby or quit.
extends Control

# ── Node References ───────────────────────────────────────────────────────────

@onready var results_list: VBoxContainer = %ResultsList
@onready var winner_label: Label = %WinnerLabel
@onready var play_again_button: Button = %PlayAgainButton
@onready var lobby_button: Button = %LobbyButton
@onready var quit_button: Button = %QuitButton

# ── Constants ─────────────────────────────────────────────────────────────────

const MAIN_MENU_SCENE: String = "res://ui/main_menu/main_menu.tscn"
const CHARACTER_SELECT_SCENE: String = "res://ui/character_select/character_select.tscn"

## Placement colours — gold, silver, bronze, then default.
const PLACEMENT_COLORS: Array[Color] = [
	Color(1.0, 0.84, 0.0),   # 1st — Gold
	Color(0.75, 0.75, 0.75),  # 2nd — Silver
	Color(0.8, 0.5, 0.2),     # 3rd — Bronze
]

# ── State ─────────────────────────────────────────────────────────────────────

## Cached leaderboard entries populated on _ready.
var _leaderboard: Array = []


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_signals()
	_update_host_ui()
	_populate_results()


# ── Setup ─────────────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)
	lobby_button.pressed.connect(_on_lobby_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _update_host_ui() -> void:
	var is_host: bool = multiplayer.is_server() if multiplayer.has_multiplayer_peer() else false
	play_again_button.visible = is_host


# ── Results Population ────────────────────────────────────────────────────────

func _populate_results() -> void:
	# Clear previous entries.
	for child: Node in results_list.get_children():
		child.queue_free()

	_leaderboard = Lobby.get_leaderboard()

	if _leaderboard.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No results yet."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 28)
		results_list.add_child(empty_label)
		winner_label.text = ""
		return

	# Set winner label.
	var winner_name: String = _leaderboard[0].get("name", "Player")
	winner_label.text = "🏆 WINNER: %s" % winner_name

	# Build a card for each player.
	for i: int in _leaderboard.size():
		var entry: Dictionary = _leaderboard[i]
		var placement: int = i + 1
		var card := _create_placement_card(placement, entry)
		results_list.add_child(card)

	# Animate the winner label with a scale pop.
	_animate_winner_label()


func _create_placement_card(placement: int, entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)

	# Colour based on placement.
	if placement <= PLACEMENT_COLORS.size():
		style.bg_color = PLACEMENT_COLORS[placement - 1].darkened(0.6)
		style.border_color = PLACEMENT_COLORS[placement - 1]
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.15, 0.15, 0.2, 1.0)

	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)

	# Rank label
	var rank_label := Label.new()
	rank_label.text = "#%d" % placement
	rank_label.custom_minimum_size = Vector2(60, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 32)
	if placement <= PLACEMENT_COLORS.size():
		rank_label.add_theme_color_override("font_color", PLACEMENT_COLORS[placement - 1])
	hbox.add_child(rank_label)

	# Player name
	var name_label := Label.new()
	name_label.text = entry.get("name", "Player")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 28)
	hbox.add_child(name_label)

	# Score
	var score_label := Label.new()
	score_label.text = str(entry.get("score", 0))
	score_label.custom_minimum_size = Vector2(80, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", 28)
	hbox.add_child(score_label)

	panel.add_child(hbox)
	return panel


func _animate_winner_label() -> void:
	winner_label.pivot_offset = winner_label.size * 0.5
	winner_label.scale = Vector2(0.5, 0.5)
	winner_label.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(winner_label, "scale", Vector2.ONE, 0.5)
	tween.parallel().tween_property(winner_label, "modulate:a", 1.0, 0.3)


# ── Button Handlers ───────────────────────────────────────────────────────────

func _on_play_again_pressed() -> void:
	Lobby.reset_ready_states()
	GameManager.transition_to(GameManager.GameState.LOBBY)
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_lobby_pressed() -> void:
	Lobby.reset_ready_states()
	GameManager.transition_to(GameManager.GameState.LOBBY)
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_quit_pressed() -> void:
	ConnectionManager.shutdown()
	Lobby.reset_session()
	GameManager.transition_to(GameManager.GameState.MENU)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
