## MatchCard - Premium match history card with expandable details
##
## Features:
##   - Card-based layout with elegant shadows
##   - Smooth expand/collapse animation for details
##   - Victory/defeat color coding with gradients
##   - MVP and achievement indicators
##   - Map preview images with blur effect
##   - Stats appear on hover with transitions
##   - Filter and sort with smooth animations
##
## Usage:
##   var card = MatchCard.new()
##   card.set_match_data(match_dictionary)
##   add_child(card)
extends PanelContainer


# region -- Signals

## Emitted when card is clicked
signal card_clicked(match_id: String)

## Emitted when card is expanded
signal card_expanded(match_id: String)

## Emitted when card is collapsed
signal card_collapsed(match_id: String)

## Emitted when a player in the match is clicked
signal player_clicked(player_id: int)

## Emitted when replay button is clicked
signal replay_requested(match_id: String)

# endregion


# region -- Constants

## Card sizes
const CARD_HEIGHT_COLLAPSED: float = 90.0
const CARD_HEIGHT_EXPANDED: float = 320.0
const CARD_CORNER_RADIUS: float = 14.0

## Animation timings
const EXPAND_DURATION: float = 0.35
const HOVER_DURATION: float = 0.15
const FADE_DURATION: float = 0.2
const SHADOW_TRANSITION: float = 0.2

## Victory/Defeat colors
const VICTORY_COLOR: Color = Color(0.15, 0.35, 0.2, 0.95)
const VICTORY_ACCENT: Color = Color(0.3, 0.85, 0.4)
const DEFEAT_COLOR: Color = Color(0.35, 0.15, 0.15, 0.95)
const DEFEAT_ACCENT: Color = Color(0.9, 0.3, 0.3)
const DRAW_COLOR: Color = Color(0.25, 0.25, 0.3, 0.95)
const DRAW_ACCENT: Color = Color(0.7, 0.7, 0.4)

## UI colors
const CARD_BG: Color = Color(0.1, 0.1, 0.14, 0.98)
const CARD_BORDER: Color = Color(0.25, 0.25, 0.35, 0.6)
const TEXT_PRIMARY: Color = Color(0.95, 0.95, 0.98)
const TEXT_SECONDARY: Color = Color(0.6, 0.6, 0.7)
const TEXT_MUTED: Color = Color(0.4, 0.4, 0.5)

# endregion


# region -- State

## Match data
var _match_data: Dictionary = {}

## Expansion state
var _is_expanded: bool = false
var _is_animating: bool = false

## Hover state
var _is_hovered: bool = false

## UI references
var _header: Control
var _details: Control
var _map_preview: Control
var _stats_overlay: Control

# endregion


# region -- Lifecycle

func _ready() -> void:
	_setup_card()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_on_mouse_enter()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_on_mouse_exit()

# endregion


# region -- UI Setup

func _setup_card() -> void:
	name = "MatchCard"
	custom_minimum_size = Vector2(0, CARD_HEIGHT_COLLAPSED)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	# Base style
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(int(CARD_CORNER_RADIUS))
	style.set_border_width_all(2)
	style.border_color = CARD_BORDER
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", style)

	# Main layout
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainLayout"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)

	# Header (always visible)
	_header = _create_header()
	main_vbox.add_child(_header)

	# Expandable details
	_details = _create_details()
	_details.visible = false
	_details.modulate.a = 0.0
	main_vbox.add_child(_details)

	add_child(main_vbox)

	# Connect input
	gui_input.connect(_on_gui_input)


func _create_header() -> Control:
	var header := Control.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, CARD_HEIGHT_COLLAPSED)

	var hbox := HBoxContainer.new()
	hbox.name = "HeaderContent"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 15
	hbox.offset_right = -15
	hbox.offset_top = 12
	hbox.offset_bottom = -12
	hbox.add_theme_constant_override("separation", 15)

	# Result indicator (left accent bar is handled by stylebox)
	var result_container := _create_result_indicator()
	hbox.add_child(result_container)

	# Match info
	var info_container := _create_match_info()
	hbox.add_child(info_container)

	# Quick stats
	var stats_container := _create_quick_stats()
	hbox.add_child(stats_container)

	# MVP badge (if applicable)
	var mvp_badge := _create_mvp_badge()
	hbox.add_child(mvp_badge)

	# Time ago
	var time_label := Label.new()
	time_label.name = "TimeLabel"
	time_label.text = ""
	time_label.add_theme_font_size_override("font_size", 13)
	time_label.add_theme_color_override("font_color", TEXT_MUTED)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(time_label)

	# Expand indicator
	var expand_icon := Label.new()
	expand_icon.name = "ExpandIcon"
	expand_icon.text = "v"
	expand_icon.add_theme_font_size_override("font_size", 16)
	expand_icon.add_theme_color_override("font_color", TEXT_MUTED)
	hbox.add_child(expand_icon)

	header.add_child(hbox)
	return header


func _create_result_indicator() -> Control:
	var container := Control.new()
	container.name = "ResultIndicator"
	container.custom_minimum_size = Vector2(70, 60)

	# Result text
	var result_label := Label.new()
	result_label.name = "ResultLabel"
	result_label.text = "WIN"
	result_label.add_theme_font_size_override("font_size", 20)
	result_label.add_theme_color_override("font_color", VICTORY_ACCENT)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.set_anchors_preset(Control.PRESET_CENTER)
	result_label.offset_left = -35
	result_label.offset_right = 35
	result_label.offset_top = -15
	result_label.offset_bottom = 15
	container.add_child(result_label)

	# Score
	var score_label := Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = ""
	score_label.add_theme_font_size_override("font_size", 12)
	score_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	score_label.offset_top = -5
	container.add_child(score_label)

	return container


func _create_match_info() -> VBoxContainer:
	var container := VBoxContainer.new()
	container.name = "MatchInfo"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 4)

	# Game mode
	var mode_label := Label.new()
	mode_label.name = "ModeLabel"
	mode_label.text = "Game Mode"
	mode_label.add_theme_font_size_override("font_size", 18)
	mode_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	container.add_child(mode_label)

	# Map name
	var map_label := Label.new()
	map_label.name = "MapLabel"
	map_label.text = "Map Name"
	map_label.add_theme_font_size_override("font_size", 14)
	map_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	container.add_child(map_label)

	# Duration
	var duration_label := Label.new()
	duration_label.name = "DurationLabel"
	duration_label.text = ""
	duration_label.add_theme_font_size_override("font_size", 12)
	duration_label.add_theme_color_override("font_color", TEXT_MUTED)
	container.add_child(duration_label)

	return container


func _create_quick_stats() -> HBoxContainer:
	var container := HBoxContainer.new()
	container.name = "QuickStats"
	container.custom_minimum_size = Vector2(180, 0)
	container.add_theme_constant_override("separation", 20)

	# K/D/A
	var kda_box := _create_stat_box("K/D/A", "0/0/0", Color(0.8, 0.8, 0.9))
	container.add_child(kda_box)

	# Damage
	var dmg_box := _create_stat_box("DMG", "0", Color(0.9, 0.5, 0.3))
	container.add_child(dmg_box)

	return container


func _create_stat_box(label: String, value: String, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Stat_%s" % label.replace("/", "")
	box.add_theme_constant_override("separation", 2)

	var value_lbl := Label.new()
	value_lbl.name = "Value"
	value_lbl.text = value
	value_lbl.add_theme_font_size_override("font_size", 18)
	value_lbl.add_theme_color_override("font_color", color)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value_lbl)

	var label_lbl := Label.new()
	label_lbl.text = label
	label_lbl.add_theme_font_size_override("font_size", 11)
	label_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	label_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label_lbl)

	return box


func _create_mvp_badge() -> Control:
	var container := Control.new()
	container.name = "MVPBadge"
	container.custom_minimum_size = Vector2(50, 50)
	container.visible = false

	var badge := PanelContainer.new()
	badge.set_anchors_preset(Control.PRESET_CENTER)
	badge.offset_left = -22
	badge.offset_right = 22
	badge.offset_top = -15
	badge.offset_bottom = 15

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(1.0, 0.7, 0.1, 0.9)
	badge_style.set_corner_radius_all(6)
	badge.add_theme_stylebox_override("panel", badge_style)

	var mvp_label := Label.new()
	mvp_label.text = "MVP"
	mvp_label.add_theme_font_size_override("font_size", 12)
	mvp_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.0))
	mvp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mvp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(mvp_label)

	container.add_child(badge)
	return container


func _create_details() -> Control:
	var details := VBoxContainer.new()
	details.name = "Details"
	details.add_theme_constant_override("separation", 15)

	# Separator
	var separator := HSeparator.new()
	separator.add_theme_color_override("separation", CARD_BORDER)
	details.add_child(separator)

	# Content row
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)

	# Map preview (left side)
	_map_preview = _create_map_preview()
	content.add_child(_map_preview)

	# Detailed stats (middle)
	var stats := _create_detailed_stats()
	content.add_child(stats)

	# Team/Players (right side)
	var players := _create_players_list()
	content.add_child(players)

	details.add_child(content)

	# Action buttons
	var actions := _create_action_buttons()
	details.add_child(actions)

	return details


func _create_map_preview() -> Control:
	var container := Control.new()
	container.name = "MapPreview"
	container.custom_minimum_size = Vector2(200, 130)

	# Background (would be map image)
	var bg := ColorRect.new()
	bg.name = "MapImage"
	bg.color = Color(0.15, 0.15, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(bg)

	# Blur overlay
	var blur := ColorRect.new()
	blur.name = "BlurOverlay"
	blur.color = Color(0.0, 0.0, 0.0, 0.3)
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(blur)

	# Map name overlay
	var name_panel := PanelContainer.new()
	name_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_panel.offset_top = -30

	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	name_panel.add_theme_stylebox_override("panel", overlay_style)

	var map_name := Label.new()
	map_name.name = "MapNameOverlay"
	map_name.text = "Map Name"
	map_name.add_theme_font_size_override("font_size", 14)
	map_name.add_theme_color_override("font_color", TEXT_PRIMARY)
	map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_panel.add_child(map_name)

	container.add_child(name_panel)

	return container


func _create_detailed_stats() -> VBoxContainer:
	var container := VBoxContainer.new()
	container.name = "DetailedStats"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 10)

	# Stats grid
	var grid := GridContainer.new()
	grid.name = "StatsGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)

	# Add stat rows
	var stats: Array[Dictionary] = [
		{"key": "kills", "label": "Kills"},
		{"key": "deaths", "label": "Deaths"},
		{"key": "assists", "label": "Assists"},
		{"key": "headshots", "label": "Headshots"},
		{"key": "damage_dealt", "label": "Damage Dealt"},
		{"key": "damage_taken", "label": "Damage Taken"},
		{"key": "accuracy", "label": "Accuracy"},
		{"key": "longest_streak", "label": "Best Streak"},
	]

	for stat: Dictionary in stats:
		var row := _create_detail_stat_row(stat["key"], stat["label"])
		grid.add_child(row)

	container.add_child(grid)

	return container


func _create_detail_stat_row(key: String, label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Stat_%s" % key
	row.add_theme_constant_override("separation", 10)

	var label_lbl := Label.new()
	label_lbl.text = label
	label_lbl.custom_minimum_size = Vector2(100, 0)
	label_lbl.add_theme_font_size_override("font_size", 13)
	label_lbl.add_theme_color_override("font_color", TEXT_SECONDARY)
	row.add_child(label_lbl)

	var value_lbl := Label.new()
	value_lbl.name = "Value"
	value_lbl.text = "0"
	value_lbl.add_theme_font_size_override("font_size", 13)
	value_lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
	row.add_child(value_lbl)

	return row


func _create_players_list() -> VBoxContainer:
	var container := VBoxContainer.new()
	container.name = "PlayersList"
	container.custom_minimum_size = Vector2(180, 0)
	container.add_theme_constant_override("separation", 6)

	# Header
	var header := Label.new()
	header.text = "PLAYERS"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", TEXT_MUTED)
	container.add_child(header)

	# Scroll for players
	var scroll := ScrollContainer.new()
	scroll.name = "PlayersScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var players_vbox := VBoxContainer.new()
	players_vbox.name = "Players"
	players_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(players_vbox)

	container.add_child(scroll)

	return container


func _create_action_buttons() -> HBoxContainer:
	var container := HBoxContainer.new()
	container.name = "Actions"
	container.alignment = BoxContainer.ALIGNMENT_END
	container.add_theme_constant_override("separation", 10)

	# Share button
	var share_btn := Button.new()
	share_btn.name = "ShareButton"
	share_btn.text = "Share"
	share_btn.custom_minimum_size = Vector2(80, 32)

	var share_style := StyleBoxFlat.new()
	share_style.bg_color = Color(0.2, 0.2, 0.28)
	share_style.set_corner_radius_all(6)
	share_btn.add_theme_stylebox_override("normal", share_style)

	container.add_child(share_btn)

	# Watch replay button
	var replay_btn := Button.new()
	replay_btn.name = "ReplayButton"
	replay_btn.text = "Watch Replay"
	replay_btn.custom_minimum_size = Vector2(110, 32)

	var replay_style := StyleBoxFlat.new()
	replay_style.bg_color = Color(0.2, 0.4, 0.6)
	replay_style.set_corner_radius_all(6)
	replay_btn.add_theme_stylebox_override("normal", replay_style)

	replay_btn.pressed.connect(func() -> void:
		replay_requested.emit(_match_data.get("id", ""))
	)

	container.add_child(replay_btn)

	return container

# endregion


# region -- Data Population

## Set match data and populate the card
func set_match_data(data: Dictionary) -> void:
	_match_data = data.duplicate(true)
	_populate_card()


func _populate_card() -> void:
	var result: String = _match_data.get("result", "loss")
	var is_victory: bool = result == "win"
	var is_draw: bool = result == "draw"

	# Update style based on result
	_update_result_style(is_victory, is_draw)

	# Header data
	_update_header(is_victory, is_draw)

	# Details data
	_update_details()


func _update_result_style(is_victory: bool, is_draw: bool) -> void:
	var style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()

	if is_victory:
		style.border_color = VICTORY_ACCENT.darkened(0.3)
		style.border_width_left = 5
	elif is_draw:
		style.border_color = DRAW_ACCENT.darkened(0.3)
		style.border_width_left = 5
	else:
		style.border_color = DEFEAT_ACCENT.darkened(0.3)
		style.border_width_left = 5

	add_theme_stylebox_override("panel", style)


func _update_header(is_victory: bool, is_draw: bool) -> void:
	# Result label
	var result_label: Label = _header.get_node_or_null("HeaderContent/ResultIndicator/ResultLabel")
	if result_label:
		if is_draw:
			result_label.text = "DRAW"
			result_label.add_theme_color_override("font_color", DRAW_ACCENT)
		elif is_victory:
			result_label.text = "WIN"
			result_label.add_theme_color_override("font_color", VICTORY_ACCENT)
		else:
			result_label.text = "LOSS"
			result_label.add_theme_color_override("font_color", DEFEAT_ACCENT)

	# Score
	var score_label: Label = _header.get_node_or_null("HeaderContent/ResultIndicator/ScoreLabel")
	if score_label:
		var my_score: int = _match_data.get("my_score", 0)
		var enemy_score: int = _match_data.get("enemy_score", 0)
		score_label.text = "%d - %d" % [my_score, enemy_score]

	# Mode and map
	var mode_label: Label = _header.get_node_or_null("HeaderContent/MatchInfo/ModeLabel")
	if mode_label:
		mode_label.text = _match_data.get("mode", "Unknown Mode")

	var map_label: Label = _header.get_node_or_null("HeaderContent/MatchInfo/MapLabel")
	if map_label:
		map_label.text = _match_data.get("map", "Unknown Map")

	var duration_label: Label = _header.get_node_or_null("HeaderContent/MatchInfo/DurationLabel")
	if duration_label:
		var duration: int = _match_data.get("duration_seconds", 0)
		duration_label.text = "%d:%02d" % [duration / 60, duration % 60]

	# KDA
	var kda_box: VBoxContainer = _header.get_node_or_null("HeaderContent/QuickStats/Stat_KDA")
	if kda_box:
		var value_label: Label = kda_box.get_node_or_null("Value")
		if value_label:
			var k: int = _match_data.get("kills", 0)
			var d: int = _match_data.get("deaths", 0)
			var a: int = _match_data.get("assists", 0)
			value_label.text = "%d/%d/%d" % [k, d, a]

	# Damage
	var dmg_box: VBoxContainer = _header.get_node_or_null("HeaderContent/QuickStats/Stat_DMG")
	if dmg_box:
		var value_label: Label = dmg_box.get_node_or_null("Value")
		if value_label:
			var dmg: int = _match_data.get("damage_dealt", 0)
			if dmg >= 1000:
				value_label.text = "%.1fk" % (dmg / 1000.0)
			else:
				value_label.text = str(dmg)

	# MVP badge
	var mvp_badge: Control = _header.get_node_or_null("HeaderContent/MVPBadge")
	if mvp_badge:
		mvp_badge.visible = _match_data.get("is_mvp", false)

	# Time
	var time_label: Label = _header.get_node_or_null("HeaderContent/TimeLabel")
	if time_label:
		time_label.text = _match_data.get("time_ago", "")


func _update_details() -> void:
	# Map name in preview
	var map_name: Label = _details.get_node_or_null("VBoxContainer/HBoxContainer/MapPreview/PanelContainer/MapNameOverlay")
	if map_name:
		map_name.text = _match_data.get("map", "Unknown")

	# Detailed stats
	var stats_grid: GridContainer = _details.get_node_or_null("VBoxContainer/HBoxContainer/DetailedStats/StatsGrid")
	if stats_grid:
		_update_stat_row(stats_grid, "kills", str(_match_data.get("kills", 0)))
		_update_stat_row(stats_grid, "deaths", str(_match_data.get("deaths", 0)))
		_update_stat_row(stats_grid, "assists", str(_match_data.get("assists", 0)))
		_update_stat_row(stats_grid, "headshots", str(_match_data.get("headshots", 0)))
		_update_stat_row(stats_grid, "damage_dealt", str(_match_data.get("damage_dealt", 0)))
		_update_stat_row(stats_grid, "damage_taken", str(_match_data.get("damage_taken", 0)))
		_update_stat_row(stats_grid, "accuracy", "%.1f%%" % _match_data.get("accuracy", 0.0))
		_update_stat_row(stats_grid, "longest_streak", str(_match_data.get("longest_streak", 0)))

	# Players list
	var players: Array = _match_data.get("players", [])
	_populate_players_list(players)


func _update_stat_row(grid: GridContainer, key: String, value: String) -> void:
	var row: HBoxContainer = grid.get_node_or_null("Stat_%s" % key)
	if row:
		var value_label: Label = row.get_node_or_null("Value")
		if value_label:
			value_label.text = value


func _populate_players_list(players: Array) -> void:
	var players_container: VBoxContainer = _details.get_node_or_null("VBoxContainer/HBoxContainer/PlayersList/PlayersScroll/Players")
	if not players_container:
		return

	# Clear existing
	for child: Node in players_container.get_children():
		child.queue_free()

	# Add players
	for player_data: Dictionary in players:
		var player_entry := _create_player_entry(player_data)
		players_container.add_child(player_entry)


func _create_player_entry(data: Dictionary) -> HBoxContainer:
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override("separation", 8)

	var is_self: bool = data.get("is_self", false)
	var is_same_team: bool = data.get("same_team", true)

	# Team indicator
	var team_dot := ColorRect.new()
	team_dot.custom_minimum_size = Vector2(4, 20)
	team_dot.color = VICTORY_ACCENT if is_same_team else DEFEAT_ACCENT
	entry.add_child(team_dot)

	# Player name
	var name_label := Label.new()
	name_label.text = data.get("name", "Player")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)

	if is_self:
		name_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		name_label.add_theme_color_override("font_color", TEXT_SECONDARY)

	entry.add_child(name_label)

	# K/D
	var kd_label := Label.new()
	kd_label.text = "%d/%d" % [data.get("kills", 0), data.get("deaths", 0)]
	kd_label.add_theme_font_size_override("font_size", 12)
	kd_label.add_theme_color_override("font_color", TEXT_MUTED)
	entry.add_child(kd_label)

	# Click handler
	var player_id: int = data.get("id", 0)
	entry.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				player_clicked.emit(player_id)
	)

	return entry

# endregion


# region -- Interactions

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_toggle_expansion()
			card_clicked.emit(_match_data.get("id", ""))


func _on_mouse_enter() -> void:
	_is_hovered = true
	_animate_hover(true)


func _on_mouse_exit() -> void:
	_is_hovered = false
	_animate_hover(false)


func _animate_hover(hovered: bool) -> void:
	var style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()

	if hovered:
		style.shadow_size = 8
		style.shadow_color = Color(0, 0, 0, 0.4)
	else:
		style.shadow_size = 4
		style.shadow_color = Color(0, 0, 0, 0.3)

	add_theme_stylebox_override("panel", style)

	# Scale animation
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2(1.01, 1.01) if hovered else Vector2.ONE, HOVER_DURATION)

# endregion


# region -- Expansion

func _toggle_expansion() -> void:
	if _is_animating:
		return

	if _is_expanded:
		_collapse()
	else:
		_expand()


func _expand() -> void:
	_is_animating = true
	_is_expanded = true

	_details.visible = true

	# Update expand icon
	var expand_icon: Label = _header.get_node_or_null("HeaderContent/ExpandIcon")
	if expand_icon:
		expand_icon.text = "^"

	# Animate
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "custom_minimum_size:y", CARD_HEIGHT_EXPANDED, EXPAND_DURATION)
	tween.parallel().tween_property(_details, "modulate:a", 1.0, FADE_DURATION)

	await tween.finished
	_is_animating = false
	card_expanded.emit(_match_data.get("id", ""))


func _collapse() -> void:
	_is_animating = true
	_is_expanded = false

	# Update expand icon
	var expand_icon: Label = _header.get_node_or_null("HeaderContent/ExpandIcon")
	if expand_icon:
		expand_icon.text = "v"

	# Animate
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_details, "modulate:a", 0.0, FADE_DURATION * 0.5)
	tween.tween_property(self, "custom_minimum_size:y", CARD_HEIGHT_COLLAPSED, EXPAND_DURATION)

	await tween.finished
	_details.visible = false
	_is_animating = false
	card_collapsed.emit(_match_data.get("id", ""))


## Force expand the card
func expand() -> void:
	if not _is_expanded:
		_expand()


## Force collapse the card
func collapse() -> void:
	if _is_expanded:
		_collapse()


## Check if card is expanded
func is_expanded() -> bool:
	return _is_expanded

# endregion


# region -- Public API

## Get match data
func get_match_data() -> Dictionary:
	return _match_data.duplicate(true)


## Get match ID
func get_match_id() -> String:
	return _match_data.get("id", "")


## Check if this match was a victory
func is_victory() -> bool:
	return _match_data.get("result", "") == "win"


## Check if player was MVP
func is_mvp() -> bool:
	return _match_data.get("is_mvp", false)

# endregion
