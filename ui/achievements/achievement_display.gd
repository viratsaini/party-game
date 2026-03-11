## AchievementDisplay - Premium achievement system with flip animations
##
## Features:
##   - Achievement cards flip on unlock with 3D effect
##   - Progress bars with milestone markers
##   - Rarity indicators with glow effects
##   - Completion percentage ring
##   - Secret achievements stay hidden until unlocked
##   - Share achievement animation
##   - Trophy case with 3D-like display
##
## Usage:
##   var display = AchievementDisplay.new()
##   add_child(display)
##   display.load_achievements(achievements_array)
extends Control


# region -- Signals

## Emitted when achievement card is clicked
signal achievement_clicked(achievement_id: String)

## Emitted when achievement is shared
signal achievement_shared(achievement_id: String)

## Emitted when category is changed
signal category_changed(category: String)

## Emitted when flip animation completes
signal flip_completed(achievement_id: String)

# endregion


# region -- Constants

## Rarity colors
const RARITY_COLORS: Dictionary = {
	"common": Color(0.6, 0.6, 0.65),
	"uncommon": Color(0.3, 0.8, 0.4),
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.7, 0.3, 0.9),
	"legendary": Color(1.0, 0.6, 0.1),
}

## Rarity glow intensity
const RARITY_GLOW: Dictionary = {
	"common": 0.0,
	"uncommon": 0.2,
	"rare": 0.4,
	"epic": 0.6,
	"legendary": 0.8,
}

## Animation timings
const FLIP_DURATION: float = 0.6
const PROGRESS_FILL_DURATION: float = 0.8
const RING_FILL_DURATION: float = 1.2
const CARD_HOVER_DURATION: float = 0.15
const SHARE_ANIMATION_DURATION: float = 1.0
const STAGGER_DELAY: float = 0.05

## Card dimensions
const CARD_WIDTH: float = 280.0
const CARD_HEIGHT: float = 140.0
const CARD_SPACING: float = 15.0
const TROPHY_SIZE: float = 100.0

## Colors
const CARD_BG: Color = Color(0.1, 0.1, 0.14, 0.98)
const CARD_BG_LOCKED: Color = Color(0.08, 0.08, 0.1, 0.95)
const CARD_BORDER: Color = Color(0.2, 0.2, 0.28, 0.8)
const TEXT_PRIMARY: Color = Color(0.95, 0.95, 0.98)
const TEXT_SECONDARY: Color = Color(0.6, 0.6, 0.7)
const TEXT_LOCKED: Color = Color(0.35, 0.35, 0.4)
const SECRET_COLOR: Color = Color(0.4, 0.3, 0.5)

# endregion


# region -- State

## All achievements data
var _achievements: Array[Dictionary] = []

## Unlocked achievement IDs
var _unlocked_ids: Array[String] = []

## Current category filter
var _current_category: String = "all"

## Achievement cards by ID
var _card_nodes: Dictionary = {}

## Trophy case nodes
var _trophy_nodes: Array[Control] = []

## Flip animation queue
var _flip_queue: Array[String] = []
var _is_flipping: bool = false

## Completion percentage
var _completion_percentage: float = 0.0

## UI references
var _header: Control
var _category_tabs: HBoxContainer
var _completion_ring: Control
var _content_scroll: ScrollContainer
var _cards_grid: GridContainer
var _trophy_case: Control

# endregion


# region -- Lifecycle

func _ready() -> void:
	_setup_ui()


func _process(delta: float) -> void:
	_update_glow_effects(delta)
	_process_flip_queue()

# endregion


# region -- UI Setup

func _setup_ui() -> void:
	name = "AchievementDisplay"
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main layout
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainLayout"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 25
	main_vbox.offset_right = -25
	main_vbox.offset_top = 20
	main_vbox.offset_bottom = -20
	main_vbox.add_theme_constant_override("separation", 20)

	# Header with completion ring
	_header = _create_header()
	main_vbox.add_child(_header)

	# Category tabs
	_category_tabs = _create_category_tabs()
	main_vbox.add_child(_category_tabs)

	# Content area
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 25)

	# Achievement cards grid
	var cards_section := _create_cards_section()
	content.add_child(cards_section)

	# Trophy case
	_trophy_case = _create_trophy_case()
	content.add_child(_trophy_case)

	main_vbox.add_child(content)
	add_child(main_vbox)


func _create_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 120)
	header.add_theme_constant_override("separation", 30)

	# Title and subtitle
	var title_section := VBoxContainer.new()
	title_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_section.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "ACHIEVEMENTS"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.WHITE)
	title_section.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "0/0 Unlocked"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", TEXT_SECONDARY)
	title_section.add_child(subtitle)

	# XP earned from achievements
	var xp_label := Label.new()
	xp_label.name = "XPEarned"
	xp_label.text = "0 XP Earned"
	xp_label.add_theme_font_size_override("font_size", 14)
	xp_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	title_section.add_child(xp_label)

	header.add_child(title_section)

	# Completion ring
	_completion_ring = _create_completion_ring()
	header.add_child(_completion_ring)

	return header


func _create_completion_ring() -> Control:
	var container := Control.new()
	container.name = "CompletionRing"
	container.custom_minimum_size = Vector2(120, 120)
	container.set_meta("progress", 0.0)
	container.set_meta("target_progress", 0.0)
	container.draw.connect(_draw_completion_ring.bind(container))

	# Percentage label in center
	var percent_label := Label.new()
	percent_label.name = "PercentLabel"
	percent_label.text = "0%"
	percent_label.add_theme_font_size_override("font_size", 28)
	percent_label.add_theme_color_override("font_color", Color.WHITE)
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent_label.set_anchors_preset(Control.PRESET_CENTER)
	percent_label.offset_left = -40
	percent_label.offset_right = 40
	percent_label.offset_top = -15
	percent_label.offset_bottom = 15
	container.add_child(percent_label)

	var complete_label := Label.new()
	complete_label.text = "Complete"
	complete_label.add_theme_font_size_override("font_size", 11)
	complete_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	complete_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	complete_label.offset_top = -35
	container.add_child(complete_label)

	return container


func _draw_completion_ring(container: Control) -> void:
	var center := container.size / 2
	var radius: float = 50.0
	var ring_width: float = 8.0
	var progress: float = container.get_meta("progress", 0.0)

	# Background ring
	_draw_ring_arc(container, center, radius, ring_width, 0.0, TAU, Color(0.15, 0.15, 0.2))

	# Progress ring with gradient
	if progress > 0.0:
		var end_angle: float = TAU * progress - PI / 2
		var gradient_color := Color(0.3, 0.6, 1.0).lerp(Color(0.5, 1.0, 0.5), progress)
		_draw_ring_arc(container, center, radius, ring_width, -PI / 2, end_angle, gradient_color)


func _draw_ring_arc(container: Control, center: Vector2, radius: float, width: float, start: float, end: float, color: Color) -> void:
	var segments: int = 48
	var angle_step: float = (end - start) / segments

	for i: int in segments:
		var angle1: float = start + angle_step * i
		var angle2: float = start + angle_step * (i + 1)

		var inner1 := center + Vector2(cos(angle1), sin(angle1)) * (radius - width / 2)
		var outer1 := center + Vector2(cos(angle1), sin(angle1)) * (radius + width / 2)
		var inner2 := center + Vector2(cos(angle2), sin(angle2)) * (radius - width / 2)
		var outer2 := center + Vector2(cos(angle2), sin(angle2)) * (radius + width / 2)

		var points := PackedVector2Array([inner1, outer1, outer2, inner2])
		var colors := PackedColorArray([color, color, color, color])
		container.draw_polygon(points, colors)


func _create_category_tabs() -> HBoxContainer:
	var tabs := HBoxContainer.new()
	tabs.name = "CategoryTabs"
	tabs.add_theme_constant_override("separation", 10)

	var categories: Array[Dictionary] = [
		{"id": "all", "label": "All"},
		{"id": "combat", "label": "Combat"},
		{"id": "progression", "label": "Progression"},
		{"id": "social", "label": "Social"},
		{"id": "mastery", "label": "Mastery"},
	]

	for cat: Dictionary in categories:
		var btn := Button.new()
		btn.name = "Category_%s" % cat["id"]
		btn.text = cat["label"]
		btn.toggle_mode = true
		btn.button_pressed = cat["id"] == _current_category
		btn.custom_minimum_size = Vector2(100, 38)
		btn.set_meta("category", cat["id"])

		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.12, 0.12, 0.16)
		normal_style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", normal_style)

		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = Color(0.2, 0.3, 0.5)
		pressed_style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		btn.pressed.connect(_on_category_pressed.bind(cat["id"]))
		tabs.add_child(btn)

	return tabs


func _on_category_pressed(category: String) -> void:
	if category == _current_category:
		return

	_current_category = category

	# Update button states
	for child: Node in _category_tabs.get_children():
		if child is Button:
			var btn: Button = child
			btn.button_pressed = btn.get_meta("category", "") == category

	# Filter and animate
	_filter_achievements()
	category_changed.emit(category)


func _create_cards_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "CardsSection"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)

	# Filter info
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 15)

	var filter_label := Label.new()
	filter_label.name = "FilterLabel"
	filter_label.text = "Showing: All (0)"
	filter_label.add_theme_font_size_override("font_size", 14)
	filter_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	filter_row.add_child(filter_label)

	var sort_btn := Button.new()
	sort_btn.name = "SortButton"
	sort_btn.text = "Sort: Newest"
	sort_btn.custom_minimum_size = Vector2(100, 30)

	var sort_style := StyleBoxFlat.new()
	sort_style.bg_color = Color(0.15, 0.15, 0.2)
	sort_style.set_corner_radius_all(6)
	sort_btn.add_theme_stylebox_override("normal", sort_style)

	filter_row.add_child(sort_btn)
	section.add_child(filter_row)

	# Scroll container
	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "ContentScroll"
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	# Cards grid
	_cards_grid = GridContainer.new()
	_cards_grid.name = "CardsGrid"
	_cards_grid.columns = 2
	_cards_grid.add_theme_constant_override("h_separation", int(CARD_SPACING))
	_cards_grid.add_theme_constant_override("v_separation", int(CARD_SPACING))
	_content_scroll.add_child(_cards_grid)

	section.add_child(_content_scroll)
	return section


func _create_trophy_case() -> Control:
	var section := VBoxContainer.new()
	section.name = "TrophyCase"
	section.custom_minimum_size = Vector2(280, 0)
	section.add_theme_constant_override("separation", 15)

	# Header
	var header := Label.new()
	header.text = "TROPHY CASE"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(header)

	# Trophy display (3D-like)
	var trophy_panel := PanelContainer.new()
	trophy_panel.name = "TrophyPanel"
	trophy_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1)
	panel_style.set_corner_radius_all(12)
	panel_style.shadow_color = Color(0, 0, 0, 0.4)
	panel_style.shadow_size = 8
	trophy_panel.add_theme_stylebox_override("panel", panel_style)

	var trophy_grid := GridContainer.new()
	trophy_grid.name = "TrophyGrid"
	trophy_grid.columns = 2
	trophy_grid.add_theme_constant_override("h_separation", 15)
	trophy_grid.add_theme_constant_override("v_separation", 15)
	trophy_panel.add_child(trophy_grid)

	section.add_child(trophy_panel)

	# Recent unlocks
	var recent := _create_recent_unlocks()
	section.add_child(recent)

	return section


func _create_recent_unlocks() -> Control:
	var section := VBoxContainer.new()
	section.name = "RecentUnlocks"
	section.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.text = "RECENT UNLOCKS"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", TEXT_SECONDARY)
	section.add_child(header)

	var list := VBoxContainer.new()
	list.name = "RecentList"
	list.add_theme_constant_override("separation", 8)
	section.add_child(list)

	return section

# endregion


# region -- Achievement Cards

func _create_achievement_card(achievement: Dictionary) -> Control:
	var is_unlocked: bool = achievement.get("unlocked", false)
	var is_hidden: bool = achievement.get("hidden", false) and not is_unlocked
	var rarity: String = achievement.get("rarity", "common")

	# Card container for flip animation
	var card_container := Control.new()
	card_container.name = "AchievementCard_%s" % achievement.get("id", "unknown")
	card_container.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_container.set_meta("achievement", achievement)
	card_container.set_meta("is_flipped", false)
	card_container.set_meta("glow_phase", randf() * TAU)

	# Front face (locked/hidden state)
	var front := _create_card_face(achievement, false, is_hidden)
	front.name = "Front"
	card_container.add_child(front)

	# Back face (unlocked state)
	var back := _create_card_face(achievement, true, false)
	back.name = "Back"
	back.visible = is_unlocked
	back.modulate.a = 1.0 if is_unlocked else 0.0
	card_container.add_child(back)

	# Set initial state
	if is_unlocked:
		front.visible = false
		back.visible = true
		card_container.set_meta("is_flipped", true)

	# Click handler
	card_container.gui_input.connect(_on_card_input.bind(card_container))
	card_container.mouse_entered.connect(_on_card_hover.bind(card_container, true))
	card_container.mouse_exited.connect(_on_card_hover.bind(card_container, false))

	_card_nodes[achievement.get("id", "")] = card_container
	return card_container


func _create_card_face(achievement: Dictionary, is_back: bool, is_hidden: bool) -> PanelContainer:
	var is_unlocked: bool = is_back
	var rarity: String = achievement.get("rarity", "common")

	var face := PanelContainer.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style := StyleBoxFlat.new()
	if is_hidden:
		style.bg_color = SECRET_COLOR.darkened(0.7)
		style.set_border_width_all(2)
		style.border_color = SECRET_COLOR.darkened(0.3)
	elif is_unlocked:
		style.bg_color = CARD_BG
		style.set_border_width_all(2)
		style.border_color = RARITY_COLORS.get(rarity, Color.GRAY)
	else:
		style.bg_color = CARD_BG_LOCKED
		style.set_border_width_all(2)
		style.border_color = CARD_BORDER
	style.set_corner_radius_all(12)
	face.add_theme_stylebox_override("panel", style)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 15)

	# Icon
	var icon := _create_achievement_icon(achievement, is_unlocked, is_hidden)
	content.add_child(icon)

	# Info
	var info := _create_achievement_info(achievement, is_unlocked, is_hidden)
	content.add_child(info)

	# Rarity indicator
	var rarity_indicator := _create_rarity_indicator(rarity, is_unlocked)
	content.add_child(rarity_indicator)

	face.add_child(content)
	return face


func _create_achievement_icon(achievement: Dictionary, is_unlocked: bool, is_hidden: bool) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(70, 70)

	# Icon background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_CENTER)
	bg.offset_left = -30
	bg.offset_right = 30
	bg.offset_top = -30
	bg.offset_bottom = 30

	if is_hidden:
		bg.color = SECRET_COLOR.darkened(0.5)
	elif is_unlocked:
		var rarity: String = achievement.get("rarity", "common")
		bg.color = RARITY_COLORS.get(rarity, Color.GRAY).darkened(0.6)
	else:
		bg.color = Color(0.15, 0.15, 0.2)

	container.add_child(bg)

	# Icon symbol
	var symbol := Label.new()
	symbol.set_anchors_preset(Control.PRESET_CENTER)
	symbol.offset_left = -30
	symbol.offset_right = 30
	symbol.offset_top = -20
	symbol.offset_bottom = 20
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol.add_theme_font_size_override("font_size", 28)

	if is_hidden:
		symbol.text = "?"
		symbol.add_theme_color_override("font_color", SECRET_COLOR)
	else:
		var icon_type: String = achievement.get("icon", "star")
		symbol.text = _get_icon_symbol(icon_type)
		symbol.add_theme_color_override("font_color", Color.WHITE if is_unlocked else TEXT_LOCKED)

	container.add_child(symbol)

	return container


func _get_icon_symbol(icon_type: String) -> String:
	match icon_type:
		"kill": return "X"
		"headshot": return "+"
		"streak": return "*"
		"level": return "^"
		"prestige": return "P"
		"games": return "#"
		"friend": return "F"
		"party": return "P"
		"team": return "T"
		"weapon": return "W"
		"game_mode": return "M"
		"perfect": return "!"
		"win": return "W"
		"secret": return "?"
		"time": return "T"
		_: return "*"


func _create_achievement_info(achievement: Dictionary, is_unlocked: bool, is_hidden: bool) -> VBoxContainer:
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)

	# Name
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.add_theme_font_size_override("font_size", 16)

	if is_hidden:
		name_label.text = "Secret Achievement"
		name_label.add_theme_color_override("font_color", SECRET_COLOR)
	else:
		name_label.text = achievement.get("name", "Achievement")
		name_label.add_theme_color_override("font_color", TEXT_PRIMARY if is_unlocked else TEXT_SECONDARY)

	info.add_child(name_label)

	# Description
	var desc_label := Label.new()
	desc_label.name = "Description"
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD

	if is_hidden:
		desc_label.text = "Unlock to reveal"
		desc_label.add_theme_color_override("font_color", SECRET_COLOR.darkened(0.2))
	else:
		desc_label.text = achievement.get("description", "")
		desc_label.add_theme_color_override("font_color", TEXT_SECONDARY if is_unlocked else TEXT_LOCKED)

	info.add_child(desc_label)

	# Progress bar (for locked achievements)
	if not is_unlocked and not is_hidden:
		var progress_bar := _create_progress_bar(achievement)
		info.add_child(progress_bar)

	# Unlock date (for unlocked achievements)
	if is_unlocked:
		var date_label := Label.new()
		date_label.name = "UnlockDate"
		date_label.text = "Unlocked: %s" % achievement.get("unlock_date", "Unknown")
		date_label.add_theme_font_size_override("font_size", 11)
		date_label.add_theme_color_override("font_color", TEXT_SECONDARY)
		info.add_child(date_label)

	return info


func _create_progress_bar(achievement: Dictionary) -> Control:
	var container := HBoxContainer.new()
	container.name = "ProgressContainer"
	container.add_theme_constant_override("separation", 10)

	# Bar
	var bar_bg := Panel.new()
	bar_bg.custom_minimum_size = Vector2(120, 12)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.16)
	bg_style.set_corner_radius_all(4)
	bar_bg.add_theme_stylebox_override("panel", bg_style)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = RARITY_COLORS.get(achievement.get("rarity", "common"), Color.GRAY).darkened(0.3)
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.offset_left = 2
	fill.offset_top = 2
	fill.offset_bottom = -2

	var progress: float = achievement.get("progress", 0.0)
	var target: int = achievement.get("target", 1)
	var percentage: float = clampf(float(progress) / target, 0.0, 1.0)
	fill.size.x = (bar_bg.custom_minimum_size.x - 4) * percentage
	fill.set_meta("target_percentage", percentage)

	bar_bg.add_child(fill)
	container.add_child(bar_bg)

	# Progress text
	var progress_label := Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.text = "%d/%d" % [int(progress), target]
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	progress_label.custom_minimum_size = Vector2(60, 0)
	container.add_child(progress_label)

	return container


func _create_rarity_indicator(rarity: String, is_unlocked: bool) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(60, 0)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 6)

	# Rarity gem
	var gem := ColorRect.new()
	gem.name = "RarityGem"
	gem.custom_minimum_size = Vector2(16, 16)
	gem.color = RARITY_COLORS.get(rarity, Color.GRAY) if is_unlocked else Color(0.25, 0.25, 0.3)
	container.add_child(gem)

	# Rarity label
	var label := Label.new()
	label.text = rarity.to_upper()
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, Color.GRAY) if is_unlocked else TEXT_LOCKED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(label)

	# XP reward
	var xp_label := Label.new()
	var xp_rewards: Dictionary = {
		"common": 50,
		"uncommon": 100,
		"rare": 200,
		"epic": 500,
		"legendary": 1000,
	}
	xp_label.text = "+%d XP" % xp_rewards.get(rarity, 50)
	xp_label.add_theme_font_size_override("font_size", 10)
	xp_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0) if is_unlocked else TEXT_LOCKED)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(xp_label)

	return container

# endregion


# region -- Card Interactions

func _on_card_input(event: InputEvent, card: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var achievement: Dictionary = card.get_meta("achievement", {})
			achievement_clicked.emit(achievement.get("id", ""))


func _on_card_hover(card: Control, hovered: bool) -> void:
	var front: PanelContainer = card.get_node_or_null("Front")
	var back: PanelContainer = card.get_node_or_null("Back")

	var visible_face: PanelContainer = back if card.get_meta("is_flipped", false) else front
	if not visible_face:
		return

	var style: StyleBoxFlat = visible_face.get_theme_stylebox("panel").duplicate()

	if hovered:
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 10
	else:
		style.shadow_color = Color(0, 0, 0, 0.2)
		style.shadow_size = 4

	visible_face.add_theme_stylebox_override("panel", style)

	# Scale animation
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "scale", Vector2(1.03, 1.03) if hovered else Vector2.ONE, CARD_HOVER_DURATION)

# endregion


# region -- Flip Animation

## Queue an achievement for flip animation (unlock effect)
func queue_flip(achievement_id: String) -> void:
	if not _card_nodes.has(achievement_id):
		return

	_flip_queue.append(achievement_id)


func _process_flip_queue() -> void:
	if _is_flipping or _flip_queue.is_empty():
		return

	var achievement_id: String = _flip_queue.pop_front()
	_play_flip_animation(achievement_id)


func _play_flip_animation(achievement_id: String) -> void:
	if not _card_nodes.has(achievement_id):
		return

	var card: Control = _card_nodes[achievement_id]
	var front: Control = card.get_node_or_null("Front")
	var back: Control = card.get_node_or_null("Back")

	if not front or not back:
		return

	_is_flipping = true

	# Update achievement data
	var achievement: Dictionary = card.get_meta("achievement", {})
	achievement["unlocked"] = true
	card.set_meta("achievement", achievement)

	# Flip animation using scale
	back.visible = true
	back.modulate.a = 0.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# First half: scale X to 0 (flip)
	tween.tween_property(card, "scale:x", 0.0, FLIP_DURATION * 0.5)

	# Switch faces at midpoint
	tween.tween_callback(func() -> void:
		front.visible = false
		back.modulate.a = 1.0
		card.set_meta("is_flipped", true)
	)

	# Second half: scale X back to 1
	tween.tween_property(card, "scale:x", 1.0, FLIP_DURATION * 0.5)

	# Completion
	tween.tween_callback(func() -> void:
		_is_flipping = false
		flip_completed.emit(achievement_id)
	)

	# Add glow burst effect
	_play_unlock_burst(card, achievement.get("rarity", "common"))


func _play_unlock_burst(card: Control, rarity: String) -> void:
	var burst := ColorRect.new()
	burst.name = "UnlockBurst"
	burst.color = RARITY_COLORS.get(rarity, Color.GRAY)
	burst.color.a = 0.8
	burst.set_anchors_preset(Control.PRESET_FULL_RECT)
	burst.offset_left = -10
	burst.offset_right = 10
	burst.offset_top = -10
	burst.offset_bottom = 10
	burst.z_index = -1
	card.add_child(burst)

	var tween := create_tween()
	tween.tween_property(burst, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: burst.queue_free())

# endregion


# region -- Glow Effects

func _update_glow_effects(delta: float) -> void:
	for achievement_id: String in _card_nodes:
		var card: Control = _card_nodes[achievement_id]
		var achievement: Dictionary = card.get_meta("achievement", {})

		if not achievement.get("unlocked", false):
			continue

		var rarity: String = achievement.get("rarity", "common")
		var glow_intensity: float = RARITY_GLOW.get(rarity, 0.0)

		if glow_intensity <= 0.0:
			continue

		var phase: float = card.get_meta("glow_phase", 0.0)
		phase += delta * 2.0
		card.set_meta("glow_phase", phase)

		# Update border glow
		var back: PanelContainer = card.get_node_or_null("Back")
		if back:
			var style: StyleBoxFlat = back.get_theme_stylebox("panel").duplicate()
			var pulse: float = 0.5 + 0.5 * sin(phase)
			style.border_color = RARITY_COLORS.get(rarity, Color.GRAY).lerp(Color.WHITE, pulse * glow_intensity * 0.3)
			back.add_theme_stylebox_override("panel", style)

# endregion


# region -- Data Loading

## Load achievements data
func load_achievements(achievements: Array[Dictionary]) -> void:
	_achievements = achievements.duplicate(true)
	_rebuild_cards()
	_update_completion()
	_populate_trophy_case()
	_populate_recent()


func _rebuild_cards() -> void:
	# Clear existing
	for child: Node in _cards_grid.get_children():
		child.queue_free()
	_card_nodes.clear()

	# Filter by category
	var filtered := _get_filtered_achievements()

	# Create cards with stagger
	for i: int in filtered.size():
		var achievement: Dictionary = filtered[i]
		var card := _create_achievement_card(achievement)
		_cards_grid.add_child(card)

		# Stagger animation
		card.modulate.a = 0.0
		card.position.y += 20

		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(i * STAGGER_DELAY)
		tween.parallel().tween_property(card, "position:y", card.position.y - 20, 0.3).set_delay(i * STAGGER_DELAY)

	# Update filter label
	var filter_label: Label = get_node_or_null("MainLayout/CardsSection/HBoxContainer/FilterLabel")
	if filter_label:
		filter_label.text = "Showing: %s (%d)" % [_current_category.capitalize(), filtered.size()]


func _get_filtered_achievements() -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []

	for achievement: Dictionary in _achievements:
		if _current_category == "all" or achievement.get("category", "") == _current_category:
			filtered.append(achievement)

	return filtered


func _filter_achievements() -> void:
	_rebuild_cards()


func _update_completion() -> void:
	var total: int = _achievements.size()
	var unlocked: int = 0
	var total_xp: int = 0

	var xp_rewards: Dictionary = {
		"common": 50,
		"uncommon": 100,
		"rare": 200,
		"epic": 500,
		"legendary": 1000,
	}

	for achievement: Dictionary in _achievements:
		if achievement.get("unlocked", false):
			unlocked += 1
			total_xp += xp_rewards.get(achievement.get("rarity", "common"), 50)

	_completion_percentage = float(unlocked) / max(total, 1)

	# Update header
	var subtitle: Label = _header.get_node_or_null("VBoxContainer/Subtitle")
	if subtitle:
		subtitle.text = "%d/%d Unlocked" % [unlocked, total]

	var xp_label: Label = _header.get_node_or_null("VBoxContainer/XPEarned")
	if xp_label:
		xp_label.text = "%d XP Earned" % total_xp

	# Animate completion ring
	_animate_completion_ring()


func _animate_completion_ring() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(
		func(v: float) -> void:
			_completion_ring.set_meta("progress", v)
			_completion_ring.queue_redraw()

			var percent_label: Label = _completion_ring.get_node_or_null("PercentLabel")
			if percent_label:
				percent_label.text = "%d%%" % int(v * 100),
		_completion_ring.get_meta("progress", 0.0),
		_completion_percentage,
		RING_FILL_DURATION
	)


func _populate_trophy_case() -> void:
	var trophy_grid: GridContainer = _trophy_case.get_node_or_null("TrophyPanel/TrophyGrid")
	if not trophy_grid:
		return

	# Clear existing
	for child: Node in trophy_grid.get_children():
		child.queue_free()
	_trophy_nodes.clear()

	# Get legendary and epic achievements (unlocked)
	var trophies: Array[Dictionary] = []
	for achievement: Dictionary in _achievements:
		var rarity: String = achievement.get("rarity", "common")
		if achievement.get("unlocked", false) and (rarity == "legendary" or rarity == "epic"):
			trophies.append(achievement)

	# Limit to 4 trophies
	for i: int in mini(trophies.size(), 4):
		var trophy := _create_trophy_display(trophies[i])
		trophy_grid.add_child(trophy)
		_trophy_nodes.append(trophy)


func _create_trophy_display(achievement: Dictionary) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(TROPHY_SIZE, TROPHY_SIZE)

	var rarity: String = achievement.get("rarity", "common")
	var color: Color = RARITY_COLORS.get(rarity, Color.GRAY)

	# 3D-like base
	var base := ColorRect.new()
	base.color = color.darkened(0.7)
	base.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	base.offset_top = -15
	container.add_child(base)

	# Trophy body
	var body := ColorRect.new()
	body.color = color.darkened(0.4)
	body.set_anchors_preset(Control.PRESET_CENTER)
	body.offset_left = -30
	body.offset_right = 30
	body.offset_top = -35
	body.offset_bottom = 10
	container.add_child(body)

	# Trophy top
	var top := ColorRect.new()
	top.color = color
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_left = -25
	top.offset_right = 25
	top.offset_top = 10
	top.offset_bottom = 35
	container.add_child(top)

	# Icon
	var icon := Label.new()
	icon.text = _get_icon_symbol(achievement.get("icon", "star"))
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", Color.WHITE)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_top = -20
	container.add_child(icon)

	return container


func _populate_recent() -> void:
	var recent_list: VBoxContainer = _trophy_case.get_node_or_null("RecentUnlocks/RecentList")
	if not recent_list:
		return

	# Clear existing
	for child: Node in recent_list.get_children():
		child.queue_free()

	# Get recent unlocked achievements (last 5)
	var recent: Array[Dictionary] = []
	for achievement: Dictionary in _achievements:
		if achievement.get("unlocked", false):
			recent.append(achievement)

	recent.reverse()

	for i: int in mini(recent.size(), 5):
		var entry := _create_recent_entry(recent[i])
		recent_list.add_child(entry)


func _create_recent_entry(achievement: Dictionary) -> HBoxContainer:
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override("separation", 8)

	var rarity: String = achievement.get("rarity", "common")

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.color = RARITY_COLORS.get(rarity, Color.GRAY)
	entry.add_child(dot)

	var name_label := Label.new()
	name_label.text = achievement.get("name", "Achievement")
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(name_label)

	return entry

# endregion


# region -- Public API

## Trigger unlock animation for an achievement
func unlock_achievement(achievement_id: String) -> void:
	# Update data
	for achievement: Dictionary in _achievements:
		if achievement.get("id", "") == achievement_id:
			achievement["unlocked"] = true
			break

	# Queue flip animation
	queue_flip(achievement_id)

	# Update UI
	_update_completion()
	_populate_trophy_case()
	_populate_recent()


## Get completion percentage
func get_completion_percentage() -> float:
	return _completion_percentage


## Get unlocked achievement count
func get_unlocked_count() -> int:
	var count: int = 0
	for achievement: Dictionary in _achievements:
		if achievement.get("unlocked", false):
			count += 1
	return count


## Get total achievement count
func get_total_count() -> int:
	return _achievements.size()


## Share an achievement (triggers animation)
func share_achievement(achievement_id: String) -> void:
	if not _card_nodes.has(achievement_id):
		return

	var card: Control = _card_nodes[achievement_id]

	# Share animation: scale up, flash, scale down
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(card, "scale", Vector2(1.15, 1.15), 0.2)
	tween.tween_property(card, "scale", Vector2.ONE, 0.4)

	achievement_shared.emit(achievement_id)

# endregion
