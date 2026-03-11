## AnimatedLeaderboard - Premium leaderboard with beautiful animations
##
## Features:
##   - Smooth rank position transitions when rankings change
##   - Crown/medals for top 3 with golden shine effect
##   - Player cards expand on hover with detailed stats
##   - Stats bars fill smoothly with easing
##   - Rank up/down arrows with color coding (green/red)
##   - Personal rank highlight with pulsing glow
##   - Smooth momentum-based scrolling
##   - Real-time leaderboard updates
##
## Usage:
##   var leaderboard = AnimatedLeaderboard.new()
##   add_child(leaderboard)
##   leaderboard.set_entries(player_data_array)
extends Control


# region -- Signals

## Emitted when a player entry is clicked
signal entry_clicked(player_id: int, player_data: Dictionary)

## Emitted when the leaderboard finishes animating
signal animation_completed()

## Emitted when player scrolls the leaderboard
signal scroll_changed(scroll_position: float)

# endregion


# region -- Constants

## Medal colors for top 3 positions
const MEDAL_COLORS: Dictionary = {
	1: Color(1.0, 0.843, 0.0),    # Gold
	2: Color(0.753, 0.753, 0.753), # Silver
	3: Color(0.804, 0.498, 0.196), # Bronze
}

## Medal icons (emoji fallback)
const MEDAL_ICONS: Dictionary = {
	1: "crown",
	2: "silver_medal",
	3: "bronze_medal",
}

## Animation durations
const RANK_TRANSITION_DURATION: float = 0.6
const CARD_EXPAND_DURATION: float = 0.25
const STAT_BAR_FILL_DURATION: float = 0.8
const GLOW_PULSE_DURATION: float = 1.5
const SHINE_DURATION: float = 2.0

## Card dimensions
const CARD_HEIGHT: float = 80.0
const CARD_EXPANDED_HEIGHT: float = 180.0
const CARD_SPACING: float = 8.0
const CARD_CORNER_RADIUS: float = 12.0

## Scroll physics
const SCROLL_DECELERATION: float = 5.0
const SCROLL_SENSITIVITY: float = 40.0
const SCROLL_BOUNCE_STRENGTH: float = 0.3

## Colors
const RANK_UP_COLOR: Color = Color(0.2, 0.9, 0.3)
const RANK_DOWN_COLOR: Color = Color(0.9, 0.2, 0.2)
const PERSONAL_GLOW_COLOR: Color = Color(0.3, 0.6, 1.0, 0.6)
const CARD_BG_COLOR: Color = Color(0.12, 0.12, 0.18, 0.95)
const CARD_HOVER_COLOR: Color = Color(0.18, 0.18, 0.26, 0.98)
const CARD_BORDER_COLOR: Color = Color(0.3, 0.3, 0.4, 0.8)

# endregion


# region -- State

## Current leaderboard entries
var _entries: Array[Dictionary] = []

## Previous rank positions for transition animations
var _previous_ranks: Dictionary = {}  # player_id -> previous_rank

## Currently expanded card player_id (-1 if none)
var _expanded_player_id: int = -1

## Local player's ID for highlighting
var _local_player_id: int = -1

## Card nodes by player_id
var _card_nodes: Dictionary = {}  # player_id -> LeaderboardCard

## Scroll state
var _scroll_position: float = 0.0
var _scroll_velocity: float = 0.0
var _scroll_target: float = 0.0
var _is_scrolling: bool = false
var _scroll_bounds: Vector2 = Vector2.ZERO  # min, max

## UI components
var _scroll_container: Control
var _cards_container: VBoxContainer
var _header: Control
var _footer: Control

## Animation state
var _is_animating: bool = false
var _animation_queue: Array[Dictionary] = []

# endregion


# region -- Lifecycle

func _ready() -> void:
	_setup_ui()
	_setup_header()
	_setup_scroll_container()
	_setup_footer()
	_start_ambient_animations()


func _process(delta: float) -> void:
	_update_scroll(delta)
	_update_glow_effects(delta)

# endregion


# region -- UI Setup

func _setup_ui() -> void:
	name = "AnimatedLeaderboard"
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Main background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.06, 0.06, 0.1, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _setup_header() -> void:
	_header = PanelContainer.new()
	_header.name = "Header"
	_header.custom_minimum_size = Vector2(0, 80)
	_header.set_anchors_preset(Control.PRESET_TOP_WIDE)

	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	header_style.set_corner_radius_all(0)
	header_style.border_width_bottom = 2
	header_style.border_color = Color(0.3, 0.4, 0.6, 0.8)
	_header.add_theme_stylebox_override("panel", header_style)

	var header_content := HBoxContainer.new()
	header_content.alignment = BoxContainer.ALIGNMENT_CENTER
	header_content.add_theme_constant_override("separation", 20)

	# Trophy icon
	var trophy_label := Label.new()
	trophy_label.text = "LEADERBOARD"
	trophy_label.add_theme_font_size_override("font_size", 32)
	trophy_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))
	header_content.add_child(trophy_label)

	_header.add_child(header_content)
	add_child(_header)


func _setup_scroll_container() -> void:
	_scroll_container = Control.new()
	_scroll_container.name = "ScrollContainer"
	_scroll_container.clip_contents = true
	_scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll_container.offset_top = 90
	_scroll_container.offset_bottom = -60

	_cards_container = VBoxContainer.new()
	_cards_container.name = "CardsContainer"
	_cards_container.add_theme_constant_override("separation", int(CARD_SPACING))
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_scroll_container.add_child(_cards_container)
	add_child(_scroll_container)

	# Connect input for scrolling
	_scroll_container.gui_input.connect(_on_scroll_input)


func _setup_footer() -> void:
	_footer = PanelContainer.new()
	_footer.name = "Footer"
	_footer.custom_minimum_size = Vector2(0, 50)
	_footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.offset_top = -50

	var footer_style := StyleBoxFlat.new()
	footer_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	footer_style.border_width_top = 1
	footer_style.border_color = Color(0.3, 0.4, 0.6, 0.5)
	_footer.add_theme_stylebox_override("panel", footer_style)

	var footer_content := HBoxContainer.new()
	footer_content.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_content.add_theme_constant_override("separation", 30)

	# Player count
	var players_label := Label.new()
	players_label.name = "PlayersLabel"
	players_label.text = "0 Players"
	players_label.add_theme_font_size_override("font_size", 16)
	players_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	footer_content.add_child(players_label)

	# Refresh hint
	var refresh_label := Label.new()
	refresh_label.text = "Updates in real-time"
	refresh_label.add_theme_font_size_override("font_size", 14)
	refresh_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	footer_content.add_child(refresh_label)

	_footer.add_child(footer_content)
	add_child(_footer)

# endregion


# region -- Leaderboard Data

## Set all leaderboard entries with animated transitions
func set_entries(entries: Array[Dictionary], animate: bool = true) -> void:
	# Store previous ranks for transition
	for entry: Dictionary in _entries:
		var player_id: int = entry.get("player_id", 0)
		var rank: int = entry.get("rank", 0)
		_previous_ranks[player_id] = rank

	_entries = entries.duplicate(true)

	# Sort by score/rank
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("score", 0) > b.get("score", 0)
	)

	# Assign ranks
	for i: int in _entries.size():
		_entries[i]["rank"] = i + 1

	if animate:
		_animate_rank_transitions()
	else:
		_rebuild_cards()

	_update_player_count()


## Set the local player ID for highlighting
func set_local_player(player_id: int) -> void:
	_local_player_id = player_id
	_refresh_highlights()


## Add or update a single entry
func update_entry(entry: Dictionary, animate: bool = true) -> void:
	var player_id: int = entry.get("player_id", 0)
	var found: bool = false

	for i: int in _entries.size():
		if _entries[i].get("player_id", 0) == player_id:
			_previous_ranks[player_id] = _entries[i].get("rank", i + 1)
			_entries[i] = entry.duplicate(true)
			found = true
			break

	if not found:
		_entries.append(entry.duplicate(true))

	# Re-sort and rebuild
	set_entries(_entries, animate)


## Remove an entry
func remove_entry(player_id: int) -> void:
	for i: int in range(_entries.size() - 1, -1, -1):
		if _entries[i].get("player_id", 0) == player_id:
			_entries.remove_at(i)
			break

	if _card_nodes.has(player_id):
		_card_nodes[player_id].queue_free()
		_card_nodes.erase(player_id)

	_rebuild_cards()

# endregion


# region -- Card Building

func _rebuild_cards() -> void:
	# Clear existing cards
	for child: Node in _cards_container.get_children():
		child.queue_free()
	_card_nodes.clear()

	# Build new cards
	for entry: Dictionary in _entries:
		var card := _create_leaderboard_card(entry)
		_cards_container.add_child(card)
		_card_nodes[entry.get("player_id", 0)] = card

	_update_scroll_bounds()


func _create_leaderboard_card(entry: Dictionary) -> PanelContainer:
	var player_id: int = entry.get("player_id", 0)
	var rank: int = entry.get("rank", 0)
	var player_name: String = entry.get("name", "Player")
	var score: int = entry.get("score", 0)
	var kills: int = entry.get("kills", 0)
	var deaths: int = entry.get("deaths", 0)
	var rank_change: int = entry.get("rank_change", 0)
	var is_local: bool = player_id == _local_player_id

	var card := PanelContainer.new()
	card.name = "Card_%d" % player_id
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.set_meta("player_id", player_id)
	card.set_meta("entry", entry)
	card.set_meta("expanded", false)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Card style
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = CARD_BG_COLOR
	card_style.set_corner_radius_all(int(CARD_CORNER_RADIUS))
	card_style.set_border_width_all(2)
	card_style.border_color = CARD_BORDER_COLOR

	# Top 3 special border
	if rank <= 3 and MEDAL_COLORS.has(rank):
		card_style.border_color = MEDAL_COLORS[rank]
		card_style.border_width_left = 4

	card.add_theme_stylebox_override("panel", card_style)

	# Main horizontal layout
	var main_hbox := HBoxContainer.new()
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 16)
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Rank display
	var rank_container := _create_rank_display(rank)
	main_hbox.add_child(rank_container)

	# Player info
	var info_container := _create_player_info(player_name, score, rank_change)
	main_hbox.add_child(info_container)

	# Stats preview
	var stats_preview := _create_stats_preview(kills, deaths)
	main_hbox.add_child(stats_preview)

	# Expandable details (hidden initially)
	var details := _create_expanded_details(entry)
	details.name = "Details"
	details.visible = false

	# VBox to hold main content and details
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(main_hbox)
	vbox.add_child(details)

	card.add_child(vbox)

	# Local player glow
	if is_local:
		_add_glow_effect(card, PERSONAL_GLOW_COLOR)

	# Connect hover events
	card.mouse_entered.connect(_on_card_hovered.bind(card))
	card.mouse_exited.connect(_on_card_unhovered.bind(card))
	card.gui_input.connect(_on_card_input.bind(card))

	return card


func _create_rank_display(rank: int) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(70, 60)

	# Medal/rank background
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(bg)

	# Rank label
	var rank_label := Label.new()
	rank_label.name = "RankLabel"

	if rank <= 3 and MEDAL_COLORS.has(rank):
		# Medal icon for top 3
		match rank:
			1: rank_label.text = "[1st]"
			2: rank_label.text = "[2nd]"
			3: rank_label.text = "[3rd]"
		rank_label.add_theme_color_override("font_color", MEDAL_COLORS[rank])
		rank_label.add_theme_font_size_override("font_size", 24)

		# Add shine effect for gold
		if rank == 1:
			_add_shine_effect(container)
	else:
		rank_label.text = "#%d" % rank
		rank_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		rank_label.add_theme_font_size_override("font_size", 22)

	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(rank_label)

	return container


func _create_player_info(player_name: String, score: int, rank_change: int) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 4)

	# Name row with rank change indicator
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.text = player_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_row.add_child(name_label)

	# Rank change arrow
	if rank_change != 0:
		var arrow := Label.new()
		arrow.name = "RankChangeArrow"
		if rank_change > 0:
			arrow.text = " +%d" % rank_change
			arrow.add_theme_color_override("font_color", RANK_UP_COLOR)
		else:
			arrow.text = " %d" % rank_change
			arrow.add_theme_color_override("font_color", RANK_DOWN_COLOR)
		arrow.add_theme_font_size_override("font_size", 16)
		name_row.add_child(arrow)

	container.add_child(name_row)

	# Score with animated counter effect
	var score_label := Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "%d pts" % score
	score_label.add_theme_font_size_override("font_size", 16)
	score_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	container.add_child(score_label)

	return container


func _create_stats_preview(kills: int, deaths: int) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.custom_minimum_size = Vector2(120, 0)
	container.add_theme_constant_override("separation", 16)

	# K/D display
	var kd_label := Label.new()
	var kd_ratio: float = float(kills) / max(deaths, 1)
	kd_label.text = "%d/%d" % [kills, deaths]
	kd_label.add_theme_font_size_override("font_size", 18)

	if kd_ratio >= 2.0:
		kd_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	elif kd_ratio >= 1.0:
		kd_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
	else:
		kd_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))

	container.add_child(kd_label)

	# KD ratio
	var ratio_label := Label.new()
	ratio_label.text = "(%.2f)" % kd_ratio
	ratio_label.add_theme_font_size_override("font_size", 14)
	ratio_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	container.add_child(ratio_label)

	return container


func _create_expanded_details(entry: Dictionary) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 12)

	# Separator line
	var separator := HSeparator.new()
	separator.add_theme_color_override("separation", Color(0.3, 0.3, 0.4, 0.5))
	container.add_child(separator)

	# Stats bars row
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 30)
	stats_grid.add_theme_constant_override("v_separation", 10)

	# Add various stat bars
	var stats: Array[Dictionary] = [
		{"name": "Accuracy", "value": entry.get("accuracy", 0.0), "max": 100.0, "color": Color(0.3, 0.8, 1.0)},
		{"name": "Damage", "value": entry.get("damage_dealt", 0), "max": entry.get("max_damage", 10000), "color": Color(1.0, 0.4, 0.3)},
		{"name": "Headshots", "value": entry.get("headshots", 0), "max": entry.get("kills", 1), "color": Color(1.0, 0.8, 0.2)},
		{"name": "Assists", "value": entry.get("assists", 0), "max": max(entry.get("kills", 1), 1), "color": Color(0.5, 1.0, 0.5)},
	]

	for stat: Dictionary in stats:
		var stat_bar := _create_stat_bar(stat["name"], stat["value"], stat["max"], stat["color"])
		stats_grid.add_child(stat_bar)

	container.add_child(stats_grid)

	# Achievements preview
	var achievements_row := HBoxContainer.new()
	achievements_row.add_theme_constant_override("separation", 8)

	var achievements_label := Label.new()
	achievements_label.text = "Badges:"
	achievements_label.add_theme_font_size_override("font_size", 14)
	achievements_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	achievements_row.add_child(achievements_label)

	# Sample badges
	var badges: Array = entry.get("badges", ["MVP", "Streak"])
	for badge: String in badges:
		var badge_label := Label.new()
		badge_label.text = "[%s]" % badge
		badge_label.add_theme_font_size_override("font_size", 12)
		badge_label.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
		achievements_row.add_child(badge_label)

	container.add_child(achievements_row)

	return container


func _create_stat_bar(stat_name: String, value: float, max_value: float, color: Color) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.custom_minimum_size = Vector2(200, 30)
	container.add_theme_constant_override("separation", 10)

	# Label
	var label := Label.new()
	label.text = stat_name
	label.custom_minimum_size = Vector2(80, 0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	container.add_child(label)

	# Progress bar background
	var bar_bg := Panel.new()
	bar_bg.custom_minimum_size = Vector2(100, 16)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2)
	bg_style.set_corner_radius_all(4)
	bar_bg.add_theme_stylebox_override("panel", bg_style)

	# Fill bar
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = color
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.size.x = 0  # Start empty for animation
	fill.set_meta("target_fill", clampf(value / max_value, 0.0, 1.0))
	bar_bg.add_child(fill)

	container.add_child(bar_bg)

	# Value label
	var value_label := Label.new()
	if value == int(value):
		value_label.text = str(int(value))
	else:
		value_label.text = "%.1f%%" % value
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", color)
	container.add_child(value_label)

	return container

# endregion


# region -- Effects

func _add_glow_effect(node: Control, color: Color) -> void:
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.color = color
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -6
	glow.offset_right = 6
	glow.offset_top = -6
	glow.offset_bottom = 6
	glow.z_index = -1
	glow.set_meta("glow_phase", 0.0)
	node.add_child(glow)
	glow.move_to_front()


func _add_shine_effect(node: Control) -> void:
	var shine := ColorRect.new()
	shine.name = "Shine"
	shine.color = Color(1.0, 1.0, 1.0, 0.0)
	shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	shine.set_meta("shine_phase", 0.0)
	node.add_child(shine)


func _start_ambient_animations() -> void:
	# Continuous glow pulse timer
	var glow_timer := Timer.new()
	glow_timer.wait_time = 0.05
	glow_timer.timeout.connect(_pulse_glows)
	add_child(glow_timer)
	glow_timer.start()

	# Medal shine animation
	var shine_timer := Timer.new()
	shine_timer.wait_time = 0.05
	shine_timer.timeout.connect(_animate_shines)
	add_child(shine_timer)
	shine_timer.start()


func _pulse_glows() -> void:
	for player_id: int in _card_nodes:
		var card: PanelContainer = _card_nodes[player_id]
		var glow: ColorRect = card.get_node_or_null("Glow")
		if glow:
			var phase: float = glow.get_meta("glow_phase", 0.0)
			phase += 0.05
			glow.set_meta("glow_phase", phase)
			var alpha: float = 0.3 + 0.3 * sin(phase * TAU / GLOW_PULSE_DURATION)
			glow.color.a = alpha


func _animate_shines() -> void:
	for player_id: int in _card_nodes:
		var card: PanelContainer = _card_nodes[player_id]
		var rank_container: Control = card.get_node_or_null("VBoxContainer/HBoxContainer/Control")
		if rank_container:
			var shine: ColorRect = rank_container.get_node_or_null("Shine")
			if shine:
				var phase: float = shine.get_meta("shine_phase", 0.0)
				phase += 0.02
				if phase > 1.0:
					phase = 0.0
				shine.set_meta("shine_phase", phase)

				# Sweep effect
				var alpha: float = 0.0
				if phase < 0.2:
					alpha = phase / 0.2 * 0.4
				elif phase < 0.3:
					alpha = 0.4 - (phase - 0.2) / 0.1 * 0.4
				shine.color.a = alpha


func _update_glow_effects(_delta: float) -> void:
	pass  # Handled by timer

# endregion


# region -- Animations

func _animate_rank_transitions() -> void:
	_is_animating = true

	# First, calculate position changes
	var position_changes: Array[Dictionary] = []

	for entry: Dictionary in _entries:
		var player_id: int = entry.get("player_id", 0)
		var new_rank: int = entry.get("rank", 0)
		var old_rank: int = _previous_ranks.get(player_id, new_rank)

		if old_rank != new_rank:
			entry["rank_change"] = old_rank - new_rank  # Positive = moved up
			position_changes.append({
				"player_id": player_id,
				"from_rank": old_rank,
				"to_rank": new_rank,
			})

	# Rebuild cards with new data
	_rebuild_cards()

	# Animate position transitions
	for change: Dictionary in position_changes:
		var player_id: int = change["player_id"]
		var from_rank: int = change["from_rank"]
		var to_rank: int = change["to_rank"]

		if _card_nodes.has(player_id):
			var card: PanelContainer = _card_nodes[player_id]
			var rank_diff: int = from_rank - to_rank
			var start_offset: float = rank_diff * (CARD_HEIGHT + CARD_SPACING)

			# Start from old position
			card.position.y += start_offset
			card.modulate.a = 0.7

			# Animate to new position
			var tween := create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_BACK)
			tween.tween_property(card, "position:y", card.position.y - start_offset, RANK_TRANSITION_DURATION)
			tween.parallel().tween_property(card, "modulate:a", 1.0, RANK_TRANSITION_DURATION * 0.5)

	# Complete animation after delay
	await get_tree().create_timer(RANK_TRANSITION_DURATION).timeout
	_is_animating = false
	animation_completed.emit()


func _animate_stat_bars(card: PanelContainer) -> void:
	var details: VBoxContainer = card.get_node_or_null("VBoxContainer/Details")
	if not details:
		return

	# Find all stat bar fills and animate them
	for child: Node in details.get_children():
		if child is GridContainer:
			for stat_container: Node in child.get_children():
				if stat_container is HBoxContainer:
					var bar_bg: Panel = stat_container.get_node_or_null("Panel")
					if bar_bg:
						var fill: ColorRect = bar_bg.get_node_or_null("Fill")
						if fill:
							var target: float = fill.get_meta("target_fill", 0.5)
							fill.size.x = 0

							var tween := create_tween()
							tween.set_ease(Tween.EASE_OUT)
							tween.set_trans(Tween.TRANS_CUBIC)
							tween.tween_property(fill, "size:x", bar_bg.size.x * target, STAT_BAR_FILL_DURATION)

# endregion


# region -- Scroll System

func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_velocity -= SCROLL_SENSITIVITY
			_is_scrolling = true
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_velocity += SCROLL_SENSITIVITY
			_is_scrolling = true


func _update_scroll(delta: float) -> void:
	if not _is_scrolling and abs(_scroll_velocity) < 0.1:
		return

	# Apply velocity
	_scroll_position += _scroll_velocity * delta * 60.0

	# Decelerate
	_scroll_velocity *= pow(0.9, delta * 60.0)

	if abs(_scroll_velocity) < 0.1:
		_scroll_velocity = 0.0
		_is_scrolling = false

	# Clamp with bounce
	if _scroll_position < _scroll_bounds.x:
		_scroll_position = lerpf(_scroll_position, _scroll_bounds.x, SCROLL_BOUNCE_STRENGTH)
		_scroll_velocity *= -0.3
	elif _scroll_position > _scroll_bounds.y:
		_scroll_position = lerpf(_scroll_position, _scroll_bounds.y, SCROLL_BOUNCE_STRENGTH)
		_scroll_velocity *= -0.3

	# Apply position
	_cards_container.position.y = -_scroll_position

	scroll_changed.emit(_scroll_position)


func _update_scroll_bounds() -> void:
	var content_height: float = _cards_container.get_minimum_size().y
	var container_height: float = _scroll_container.size.y

	_scroll_bounds.x = 0.0
	_scroll_bounds.y = maxf(0.0, content_height - container_height)


## Scroll to show a specific player
func scroll_to_player(player_id: int, animate: bool = true) -> void:
	if not _card_nodes.has(player_id):
		return

	var card: PanelContainer = _card_nodes[player_id]
	var target_y: float = card.position.y - _scroll_container.size.y / 2 + CARD_HEIGHT / 2
	target_y = clampf(target_y, _scroll_bounds.x, _scroll_bounds.y)

	if animate:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "_scroll_position", target_y, 0.4)
	else:
		_scroll_position = target_y
		_cards_container.position.y = -_scroll_position

# endregion


# region -- Card Interactions

func _on_card_hovered(card: PanelContainer) -> void:
	var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	style.bg_color = CARD_HOVER_COLOR
	card.add_theme_stylebox_override("panel", style)

	# Scale up slightly
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "scale", Vector2(1.02, 1.02), 0.15)


func _on_card_unhovered(card: PanelContainer) -> void:
	var is_expanded: bool = card.get_meta("expanded", false)
	if is_expanded:
		return

	var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	style.bg_color = CARD_BG_COLOR
	card.add_theme_stylebox_override("panel", style)

	# Scale back
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "scale", Vector2.ONE, 0.15)


func _on_card_input(event: InputEvent, card: PanelContainer) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var player_id: int = card.get_meta("player_id", -1)
			var entry: Dictionary = card.get_meta("entry", {})

			# Toggle expansion
			_toggle_card_expansion(card)

			entry_clicked.emit(player_id, entry)


func _toggle_card_expansion(card: PanelContainer) -> void:
	var is_expanded: bool = card.get_meta("expanded", false)
	var details: VBoxContainer = card.get_node_or_null("VBoxContainer/Details")

	if not details:
		return

	# Collapse previously expanded card
	if _expanded_player_id != -1 and _expanded_player_id != card.get_meta("player_id", -1):
		if _card_nodes.has(_expanded_player_id):
			var prev_card: PanelContainer = _card_nodes[_expanded_player_id]
			_collapse_card(prev_card)

	if is_expanded:
		_collapse_card(card)
		_expanded_player_id = -1
	else:
		_expand_card(card)
		_expanded_player_id = card.get_meta("player_id", -1)


func _expand_card(card: PanelContainer) -> void:
	card.set_meta("expanded", true)

	var details: VBoxContainer = card.get_node_or_null("VBoxContainer/Details")
	if details:
		details.visible = true
		details.modulate.a = 0.0

		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "custom_minimum_size:y", CARD_EXPANDED_HEIGHT, CARD_EXPAND_DURATION)
		tween.parallel().tween_property(details, "modulate:a", 1.0, CARD_EXPAND_DURATION)

		# Animate stat bars after expansion starts
		await get_tree().create_timer(CARD_EXPAND_DURATION * 0.3).timeout
		_animate_stat_bars(card)


func _collapse_card(card: PanelContainer) -> void:
	card.set_meta("expanded", false)

	var details: VBoxContainer = card.get_node_or_null("VBoxContainer/Details")
	if details:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "custom_minimum_size:y", CARD_HEIGHT, CARD_EXPAND_DURATION)
		tween.parallel().tween_property(details, "modulate:a", 0.0, CARD_EXPAND_DURATION * 0.5)

		await tween.finished
		details.visible = false

# endregion


# region -- Helpers

func _update_player_count() -> void:
	var players_label: Label = _footer.get_node_or_null("HBoxContainer/PlayersLabel")
	if players_label:
		players_label.text = "%d Players" % _entries.size()


func _refresh_highlights() -> void:
	for player_id: int in _card_nodes:
		var card: PanelContainer = _card_nodes[player_id]
		var existing_glow: ColorRect = card.get_node_or_null("Glow")

		if player_id == _local_player_id and not existing_glow:
			_add_glow_effect(card, PERSONAL_GLOW_COLOR)
		elif player_id != _local_player_id and existing_glow:
			existing_glow.queue_free()


## Get the current rank of a player
func get_player_rank(player_id: int) -> int:
	for entry: Dictionary in _entries:
		if entry.get("player_id", 0) == player_id:
			return entry.get("rank", 0)
	return -1


## Get all entries
func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


## Check if currently animating
func is_animating() -> bool:
	return _is_animating

# endregion
