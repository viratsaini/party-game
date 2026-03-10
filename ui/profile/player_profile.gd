## PlayerProfile - Premium player profile display with rich visual elements
##
## Features:
##   - Level badge with animated XP progress bar
##   - Avatar frame with animated gradient border
##   - Title and badge showcase with hover effects
##   - Recent matches timeline with scroll
##   - Win/loss graph with smooth animations
##   - Best plays carousel with auto-scroll
##   - Social links with icons
##
## Usage:
##   var profile = PlayerProfile.new()
##   add_child(profile)
##   profile.load_profile(player_data)
extends Control


# region -- Signals

## Emitted when avatar is clicked
signal avatar_clicked()

## Emitted when a badge is clicked
signal badge_clicked(badge_id: String)

## Emitted when a match in timeline is clicked
signal match_clicked(match_id: String)

## Emitted when a social link is clicked
signal social_link_clicked(platform: String, url: String)

## Emitted when edit profile is clicked
signal edit_profile_requested()

# endregion


# region -- Constants

## XP bar animation
const XP_BAR_FILL_DURATION: float = 1.2
const XP_COUNT_DURATION: float = 1.5

## Border animation
const BORDER_ROTATION_SPEED: float = 2.0
const BORDER_GRADIENT_COLORS: Array[Color] = [
	Color(0.3, 0.6, 1.0),
	Color(0.5, 0.3, 1.0),
	Color(1.0, 0.3, 0.6),
	Color(1.0, 0.6, 0.3),
	Color(0.3, 1.0, 0.6),
]

## Carousel
const CAROUSEL_AUTO_SCROLL_DELAY: float = 4.0
const CAROUSEL_TRANSITION_DURATION: float = 0.5

## Colors
const LEVEL_COLORS: Dictionary = {
	"bronze": Color(0.804, 0.498, 0.196),
	"silver": Color(0.753, 0.753, 0.753),
	"gold": Color(1.0, 0.843, 0.0),
	"platinum": Color(0.9, 0.95, 1.0),
	"diamond": Color(0.6, 0.85, 1.0),
	"master": Color(0.7, 0.3, 0.9),
	"legend": Color(1.0, 0.4, 0.4),
}

const CARD_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const CARD_BORDER: Color = Color(0.2, 0.25, 0.35, 0.8)

# endregion


# region -- State

## Player data
var _profile_data: Dictionary = {}

## UI references
var _avatar_container: Control
var _info_section: VBoxContainer
var _badges_container: HBoxContainer
var _timeline_container: VBoxContainer
var _graph_container: Control
var _carousel: Control
var _social_container: HBoxContainer

## Animation state
var _border_phase: float = 0.0
var _carousel_index: int = 0
var _carousel_timer: Timer

# endregion


# region -- Lifecycle

func _ready() -> void:
	_setup_ui()


func _process(delta: float) -> void:
	_update_border_animation(delta)

# endregion


# region -- UI Setup

func _setup_ui() -> void:
	name = "PlayerProfile"
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.05, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main layout
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainLayout"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 30
	main_vbox.offset_right = -30
	main_vbox.offset_top = 20
	main_vbox.offset_bottom = -20
	main_vbox.add_theme_constant_override("separation", 25)

	# Header with avatar and basic info
	var header := _create_header_section()
	main_vbox.add_child(header)

	# Badges section
	var badges := _create_badges_section()
	main_vbox.add_child(badges)

	# Stats and timeline row
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 25)
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var timeline := _create_timeline_section()
	content_row.add_child(timeline)

	var graph := _create_graph_section()
	content_row.add_child(graph)

	main_vbox.add_child(content_row)

	# Best plays carousel
	var carousel := _create_carousel_section()
	main_vbox.add_child(carousel)

	# Social links footer
	var social := _create_social_section()
	main_vbox.add_child(social)

	add_child(main_vbox)


func _create_header_section() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 25)
	header.custom_minimum_size = Vector2(0, 160)

	# Avatar with animated border
	_avatar_container = _create_avatar_container()
	header.add_child(_avatar_container)

	# Player info
	_info_section = _create_info_section()
	header.add_child(_info_section)

	# Edit button (for own profile)
	var edit_btn := Button.new()
	edit_btn.name = "EditButton"
	edit_btn.text = "Edit Profile"
	edit_btn.custom_minimum_size = Vector2(120, 40)
	edit_btn.visible = false  # Show only for own profile

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.3)
	btn_style.set_corner_radius_all(8)
	edit_btn.add_theme_stylebox_override("normal", btn_style)

	edit_btn.pressed.connect(func() -> void: edit_profile_requested.emit())
	header.add_child(edit_btn)

	return header


func _create_avatar_container() -> Control:
	var container := Control.new()
	container.name = "AvatarContainer"
	container.custom_minimum_size = Vector2(150, 150)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# Animated border (custom drawn)
	var border := Control.new()
	border.name = "AnimatedBorder"
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.draw.connect(_draw_animated_border.bind(border))
	container.add_child(border)

	# Avatar background
	var avatar_bg := ColorRect.new()
	avatar_bg.name = "AvatarBG"
	avatar_bg.color = Color(0.15, 0.15, 0.2)
	avatar_bg.set_anchors_preset(Control.PRESET_CENTER)
	avatar_bg.offset_left = -60
	avatar_bg.offset_right = 60
	avatar_bg.offset_top = -60
	avatar_bg.offset_bottom = 60
	container.add_child(avatar_bg)

	# Avatar placeholder
	var avatar := ColorRect.new()
	avatar.name = "Avatar"
	avatar.color = Color(0.3, 0.3, 0.4)
	avatar.set_anchors_preset(Control.PRESET_CENTER)
	avatar.offset_left = -55
	avatar.offset_right = 55
	avatar.offset_top = -55
	avatar.offset_bottom = 55
	container.add_child(avatar)

	# Avatar label (initials)
	var initials := Label.new()
	initials.name = "Initials"
	initials.text = "?"
	initials.add_theme_font_size_override("font_size", 48)
	initials.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.set_anchors_preset(Control.PRESET_CENTER)
	initials.offset_left = -55
	initials.offset_right = 55
	initials.offset_top = -55
	initials.offset_bottom = 55
	container.add_child(initials)

	# Click handler
	container.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				avatar_clicked.emit()
	)

	return container


func _create_info_section() -> VBoxContainer:
	var info := VBoxContainer.new()
	info.name = "InfoSection"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 12)

	# Player name with title
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 15)

	var player_name := Label.new()
	player_name.name = "PlayerName"
	player_name.text = "Player Name"
	player_name.add_theme_font_size_override("font_size", 32)
	player_name.add_theme_color_override("font_color", Color.WHITE)
	name_row.add_child(player_name)

	var title := Label.new()
	title.name = "Title"
	title.text = ""
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
	name_row.add_child(title)

	info.add_child(name_row)

	# Level badge with XP bar
	var level_container := _create_level_badge()
	info.add_child(level_container)

	# Quick stats row
	var stats_row := _create_quick_stats_row()
	info.add_child(stats_row)

	return info


func _create_level_badge() -> Control:
	var container := HBoxContainer.new()
	container.name = "LevelContainer"
	container.add_theme_constant_override("separation", 15)

	# Level badge
	var badge := PanelContainer.new()
	badge.name = "LevelBadge"
	badge.custom_minimum_size = Vector2(80, 40)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = LEVEL_COLORS["gold"].darkened(0.6)
	badge_style.set_corner_radius_all(8)
	badge_style.set_border_width_all(2)
	badge_style.border_color = LEVEL_COLORS["gold"]
	badge.add_theme_stylebox_override("panel", badge_style)

	var badge_label := Label.new()
	badge_label.name = "LevelLabel"
	badge_label.text = "LVL 1"
	badge_label.add_theme_font_size_override("font_size", 18)
	badge_label.add_theme_color_override("font_color", LEVEL_COLORS["gold"])
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)

	container.add_child(badge)

	# XP bar
	var xp_container := VBoxContainer.new()
	xp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_container.add_theme_constant_override("separation", 4)

	var xp_label := Label.new()
	xp_label.name = "XPLabel"
	xp_label.text = "0 / 100 XP"
	xp_label.add_theme_font_size_override("font_size", 14)
	xp_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	xp_container.add_child(xp_label)

	var xp_bar_bg := Panel.new()
	xp_bar_bg.name = "XPBarBG"
	xp_bar_bg.custom_minimum_size = Vector2(300, 16)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2)
	bg_style.set_corner_radius_all(4)
	xp_bar_bg.add_theme_stylebox_override("panel", bg_style)

	var xp_fill := ColorRect.new()
	xp_fill.name = "XPFill"
	xp_fill.color = Color(0.3, 0.7, 1.0)
	xp_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	xp_fill.offset_left = 2
	xp_fill.offset_top = 2
	xp_fill.offset_bottom = -2
	xp_fill.size.x = 0
	xp_bar_bg.add_child(xp_fill)

	xp_container.add_child(xp_bar_bg)
	container.add_child(xp_container)

	# Prestige indicator
	var prestige := Label.new()
	prestige.name = "Prestige"
	prestige.text = ""
	prestige.add_theme_font_size_override("font_size", 16)
	prestige.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	container.add_child(prestige)

	return container


func _create_quick_stats_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "QuickStats"
	row.add_theme_constant_override("separation", 30)

	var stats: Array[Dictionary] = [
		{"key": "matches", "label": "Matches", "value": "0"},
		{"key": "wins", "label": "Wins", "value": "0"},
		{"key": "kd", "label": "K/D", "value": "0.00"},
		{"key": "playtime", "label": "Playtime", "value": "0h"},
	]

	for stat: Dictionary in stats:
		var stat_box := VBoxContainer.new()
		stat_box.name = "Stat_%s" % stat["key"]
		stat_box.add_theme_constant_override("separation", 2)

		var value_label := Label.new()
		value_label.name = "Value"
		value_label.text = stat["value"]
		value_label.add_theme_font_size_override("font_size", 22)
		value_label.add_theme_color_override("font_color", Color.WHITE)
		stat_box.add_child(value_label)

		var label := Label.new()
		label.text = stat["label"]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		stat_box.add_child(label)

		row.add_child(stat_box)

	return row


func _create_badges_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "BadgesSection"
	section.add_theme_constant_override("separation", 10)

	# Section header
	var header := Label.new()
	header.text = "BADGES & TITLES"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	section.add_child(header)

	# Badges container
	_badges_container = HBoxContainer.new()
	_badges_container.name = "Badges"
	_badges_container.add_theme_constant_override("separation", 12)
	section.add_child(_badges_container)

	return section


func _create_timeline_section() -> Control:
	var section := PanelContainer.new()
	section.name = "TimelineSection"
	section.custom_minimum_size = Vector2(350, 0)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = CARD_BORDER
	section.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)

	# Header
	var header := Label.new()
	header.text = "RECENT MATCHES"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	content.add_child(header)

	# Timeline scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_timeline_container = VBoxContainer.new()
	_timeline_container.name = "Timeline"
	_timeline_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_timeline_container)

	content.add_child(scroll)
	section.add_child(content)

	return section


func _create_graph_section() -> Control:
	var section := PanelContainer.new()
	section.name = "GraphSection"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = CARD_BORDER
	section.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)

	# Header
	var header := Label.new()
	header.text = "WIN/LOSS HISTORY"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	content.add_child(header)

	# Graph area
	_graph_container = Control.new()
	_graph_container.name = "Graph"
	_graph_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_container.custom_minimum_size = Vector2(0, 150)
	_graph_container.set_meta("data", [])
	_graph_container.set_meta("animation_progress", 0.0)
	_graph_container.draw.connect(_draw_winloss_graph)
	content.add_child(_graph_container)

	# Legend
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 25)

	var win_legend := _create_legend_item("Wins", Color(0.3, 0.8, 0.4))
	var loss_legend := _create_legend_item("Losses", Color(1.0, 0.3, 0.3))
	legend.add_child(win_legend)
	legend.add_child(loss_legend)

	content.add_child(legend)
	section.add_child(content)

	return section


func _create_legend_item(text: String, color: Color) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.color = color
	item.add_child(dot)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	item.add_child(label)

	return item


func _create_carousel_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "CarouselSection"
	section.add_theme_constant_override("separation", 10)
	section.custom_minimum_size = Vector2(0, 150)

	# Header
	var header := Label.new()
	header.text = "BEST PLAYS"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	section.add_child(header)

	# Carousel container
	_carousel = Control.new()
	_carousel.name = "Carousel"
	_carousel.custom_minimum_size = Vector2(0, 120)
	_carousel.clip_contents = true
	_carousel.set_meta("items", [])
	_carousel.set_meta("current_index", 0)
	section.add_child(_carousel)

	# Navigation dots
	var dots := HBoxContainer.new()
	dots.name = "Dots"
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 8)
	section.add_child(dots)

	# Auto-scroll timer
	_carousel_timer = Timer.new()
	_carousel_timer.wait_time = CAROUSEL_AUTO_SCROLL_DELAY
	_carousel_timer.timeout.connect(_carousel_next)
	add_child(_carousel_timer)

	return section


func _create_social_section() -> Control:
	var section := HBoxContainer.new()
	section.name = "SocialSection"
	section.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_theme_constant_override("separation", 20)
	section.custom_minimum_size = Vector2(0, 50)

	_social_container = HBoxContainer.new()
	_social_container.name = "SocialLinks"
	_social_container.add_theme_constant_override("separation", 15)
	section.add_child(_social_container)

	return section

# endregion


# region -- Animated Border

func _update_border_animation(delta: float) -> void:
	_border_phase += delta * BORDER_ROTATION_SPEED
	if _border_phase > TAU:
		_border_phase -= TAU

	if _avatar_container:
		var border: Control = _avatar_container.get_node_or_null("AnimatedBorder")
		if border:
			border.queue_redraw()


func _draw_animated_border(border: Control) -> void:
	var center := border.size / 2
	var radius: float = 72.0
	var border_width: float = 4.0
	var segments: int = 64

	for i: int in segments:
		var angle1: float = TAU * i / segments
		var angle2: float = TAU * (i + 1) / segments

		# Calculate gradient color based on angle and phase
		var color_phase: float = fmod(angle1 + _border_phase, TAU) / TAU
		var color_idx: int = int(color_phase * BORDER_GRADIENT_COLORS.size())
		var next_idx: int = (color_idx + 1) % BORDER_GRADIENT_COLORS.size()
		var blend: float = fmod(color_phase * BORDER_GRADIENT_COLORS.size(), 1.0)

		var color: Color = BORDER_GRADIENT_COLORS[color_idx].lerp(
			BORDER_GRADIENT_COLORS[next_idx],
			blend
		)

		var inner1 := center + Vector2(cos(angle1), sin(angle1)) * (radius - border_width / 2)
		var outer1 := center + Vector2(cos(angle1), sin(angle1)) * (radius + border_width / 2)
		var inner2 := center + Vector2(cos(angle2), sin(angle2)) * (radius - border_width / 2)
		var outer2 := center + Vector2(cos(angle2), sin(angle2)) * (radius + border_width / 2)

		var points := PackedVector2Array([inner1, outer1, outer2, inner2])
		var colors := PackedColorArray([color, color, color, color])
		border.draw_polygon(points, colors)

# endregion


# region -- Win/Loss Graph

func _draw_winloss_graph() -> void:
	if not _graph_container:
		return

	var data: Array = _graph_container.get_meta("data", [])
	var progress: float = _graph_container.get_meta("animation_progress", 0.0)

	if data.is_empty():
		# Draw placeholder text
		_graph_container.draw_string(
			ThemeDB.fallback_font,
			_graph_container.size / 2 - Vector2(50, 0),
			"No data yet",
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			16,
			Color(0.5, 0.5, 0.6)
		)
		return

	var padding := Vector2(40, 20)
	var chart_size := _graph_container.size - padding * 2

	# Draw grid
	var grid_color := Color(0.2, 0.2, 0.25, 0.5)
	for i: int in 5:
		var y: float = padding.y + chart_size.y * (i / 4.0)
		_graph_container.draw_line(
			Vector2(padding.x, y),
			Vector2(padding.x + chart_size.x, y),
			grid_color,
			1.0
		)

	# Draw data
	var points_to_draw: int = int(data.size() * progress)
	if points_to_draw < 1:
		return

	var win_points: PackedVector2Array = []
	var loss_points: PackedVector2Array = []

	# Find max values
	var max_wins: int = 1
	var max_losses: int = 1
	for entry: Dictionary in data:
		max_wins = maxi(max_wins, entry.get("wins", 0))
		max_losses = maxi(max_losses, entry.get("losses", 0))
	var max_val: int = maxi(max_wins, max_losses)

	for i: int in points_to_draw:
		var entry: Dictionary = data[i]
		var x: float = padding.x + chart_size.x * (float(i) / max(data.size() - 1, 1))

		var win_y: float = padding.y + chart_size.y * (1.0 - float(entry.get("wins", 0)) / max_val)
		var loss_y: float = padding.y + chart_size.y * (1.0 - float(entry.get("losses", 0)) / max_val)

		win_points.append(Vector2(x, win_y))
		loss_points.append(Vector2(x, loss_y))

	# Draw lines
	var win_color := Color(0.3, 0.8, 0.4)
	var loss_color := Color(1.0, 0.3, 0.3)

	if win_points.size() >= 2:
		_graph_container.draw_polyline(win_points, win_color, 2.0, true)
	if loss_points.size() >= 2:
		_graph_container.draw_polyline(loss_points, loss_color, 2.0, true)

	# Draw points
	for point: Vector2 in win_points:
		_graph_container.draw_circle(point, 4, win_color)
	for point: Vector2 in loss_points:
		_graph_container.draw_circle(point, 4, loss_color)


func _animate_graph(data: Array) -> void:
	_graph_container.set_meta("data", data)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(
		func(v: float) -> void:
			_graph_container.set_meta("animation_progress", v)
			_graph_container.queue_redraw(),
		0.0,
		1.0,
		1.0
	)

# endregion


# region -- Carousel

func _add_carousel_item(play: Dictionary) -> void:
	var item := PanelContainer.new()
	item.custom_minimum_size = Vector2(_carousel.size.x - 20, 100)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.set_corner_radius_all(10)
	item.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)

	# Play type icon
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.color = Color(0.3, 0.5, 0.8)
	hbox.add_child(icon)

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = play.get("title", "Best Play")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(title)

	var desc := Label.new()
	desc.text = play.get("description", "")
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	info.add_child(desc)

	var date := Label.new()
	date.text = play.get("date", "")
	date.add_theme_font_size_override("font_size", 12)
	date.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	info.add_child(date)

	hbox.add_child(info)
	item.add_child(hbox)

	_carousel.add_child(item)


func _carousel_next() -> void:
	var items: Array = _carousel.get_meta("items", [])
	if items.is_empty():
		return

	_carousel_index = (_carousel_index + 1) % items.size()
	_animate_carousel_to(_carousel_index)


func _animate_carousel_to(index: int) -> void:
	var offset: float = -index * (_carousel.size.x)

	for i: int in _carousel.get_child_count():
		var child: Control = _carousel.get_child(i)
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(child, "position:x", i * _carousel.size.x + offset, CAROUSEL_TRANSITION_DURATION)

# endregion


# region -- Data Loading

## Load profile data and animate elements
func load_profile(data: Dictionary) -> void:
	_profile_data = data.duplicate(true)
	_populate_profile()
	_animate_elements()


func _populate_profile() -> void:
	# Player name
	var name_label: Label = _info_section.get_node_or_null("HBoxContainer/PlayerName")
	if name_label:
		name_label.text = _profile_data.get("name", "Player")

	# Title
	var title_label: Label = _info_section.get_node_or_null("HBoxContainer/Title")
	if title_label:
		var title: String = _profile_data.get("title", "")
		title_label.text = title
		title_label.visible = not title.is_empty()

	# Avatar initials
	var initials: Label = _avatar_container.get_node_or_null("Initials")
	if initials:
		var name_str: String = _profile_data.get("name", "?")
		if name_str.length() > 0:
			initials.text = name_str[0].to_upper()

	# Level
	var level: int = _profile_data.get("level", 1)
	var level_label: Label = _info_section.get_node_or_null("LevelContainer/LevelBadge/LevelLabel")
	if level_label:
		level_label.text = "LVL %d" % level

	# Prestige
	var prestige: int = _profile_data.get("prestige", 0)
	var prestige_label: Label = _info_section.get_node_or_null("LevelContainer/Prestige")
	if prestige_label:
		if prestige > 0:
			prestige_label.text = "[P%d]" % prestige
			prestige_label.visible = true
		else:
			prestige_label.visible = false

	# Quick stats
	_update_quick_stat("matches", str(_profile_data.get("matches_played", 0)))
	_update_quick_stat("wins", str(_profile_data.get("wins", 0)))
	_update_quick_stat("kd", "%.2f" % _profile_data.get("kd_ratio", 0.0))
	_update_quick_stat("playtime", "%dh" % _profile_data.get("playtime_hours", 0))

	# Badges
	var badges: Array = _profile_data.get("badges", [])
	_populate_badges(badges)

	# Recent matches
	var matches: Array = _profile_data.get("recent_matches", [])
	_populate_timeline(matches)

	# Graph data
	var graph_data: Array = _profile_data.get("winloss_history", [])
	_animate_graph(graph_data)

	# Best plays
	var plays: Array = _profile_data.get("best_plays", [])
	_populate_carousel(plays)

	# Social links
	var social: Array = _profile_data.get("social_links", [])
	_populate_social_links(social)


func _update_quick_stat(key: String, value: String) -> void:
	var stat_box: VBoxContainer = _info_section.get_node_or_null("QuickStats/Stat_%s" % key)
	if stat_box:
		var value_label: Label = stat_box.get_node_or_null("Value")
		if value_label:
			value_label.text = value


func _populate_badges(badges: Array) -> void:
	# Clear existing
	for child: Node in _badges_container.get_children():
		child.queue_free()

	for badge_data: Dictionary in badges:
		var badge := _create_badge(badge_data)
		_badges_container.add_child(badge)


func _create_badge(data: Dictionary) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "Badge_%s" % data.get("id", "unknown")
	badge.custom_minimum_size = Vector2(80, 35)
	badge.set_meta("badge_data", data)

	var rarity: String = data.get("rarity", "common")
	var rarity_colors: Dictionary = {
		"common": Color(0.6, 0.6, 0.6),
		"rare": Color(0.3, 0.5, 1.0),
		"epic": Color(0.7, 0.3, 0.9),
		"legendary": Color(1.0, 0.6, 0.1),
	}

	var style := StyleBoxFlat.new()
	style.bg_color = rarity_colors.get(rarity, Color.GRAY).darkened(0.7)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = rarity_colors.get(rarity, Color.GRAY)
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = data.get("name", "Badge")
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", rarity_colors.get(rarity, Color.WHITE))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(label)

	# Click handler
	badge.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				badge_clicked.emit(data.get("id", ""))
	)

	return badge


func _populate_timeline(matches: Array) -> void:
	# Clear existing
	for child: Node in _timeline_container.get_children():
		child.queue_free()

	for match_data: Dictionary in matches:
		var entry := _create_timeline_entry(match_data)
		_timeline_container.add_child(entry)


func _create_timeline_entry(data: Dictionary) -> PanelContainer:
	var entry := PanelContainer.new()
	entry.custom_minimum_size = Vector2(0, 50)
	entry.set_meta("match_data", data)

	var is_win: bool = data.get("result", "loss") == "win"

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.set_corner_radius_all(6)
	style.border_width_left = 4
	style.border_color = Color(0.3, 0.8, 0.4) if is_win else Color(1.0, 0.3, 0.3)
	entry.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	# Result indicator
	var result := Label.new()
	result.text = "W" if is_win else "L"
	result.custom_minimum_size = Vector2(25, 0)
	result.add_theme_font_size_override("font_size", 16)
	result.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4) if is_win else Color(1.0, 0.3, 0.3))
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(result)

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var mode := Label.new()
	mode.text = data.get("mode", "Match")
	mode.add_theme_font_size_override("font_size", 14)
	mode.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(mode)

	var stats := Label.new()
	stats.text = "%d/%d" % [data.get("kills", 0), data.get("deaths", 0)]
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	info.add_child(stats)

	hbox.add_child(info)

	# Time
	var time := Label.new()
	time.text = data.get("time_ago", "")
	time.add_theme_font_size_override("font_size", 11)
	time.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	hbox.add_child(time)

	entry.add_child(hbox)

	# Click handler
	entry.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				match_clicked.emit(data.get("id", ""))
	)

	return entry


func _populate_carousel(plays: Array) -> void:
	# Clear existing
	for child: Node in _carousel.get_children():
		child.queue_free()

	_carousel.set_meta("items", plays)

	for i: int in plays.size():
		var play: Dictionary = plays[i]
		_add_carousel_item(play)

		# Position items
		var item: Control = _carousel.get_child(i)
		item.position.x = i * _carousel.size.x

	if plays.size() > 1:
		_carousel_timer.start()


func _populate_social_links(links: Array) -> void:
	# Clear existing
	for child: Node in _social_container.get_children():
		child.queue_free()

	for link: Dictionary in links:
		var btn := Button.new()
		btn.text = link.get("platform", "Link")
		btn.custom_minimum_size = Vector2(100, 35)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.3)
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)

		btn.pressed.connect(func() -> void:
			social_link_clicked.emit(link.get("platform", ""), link.get("url", ""))
		)

		_social_container.add_child(btn)


func _animate_elements() -> void:
	# Animate XP bar
	var xp_fill: ColorRect = _info_section.get_node_or_null("LevelContainer/VBoxContainer/XPBarBG/XPFill")
	var xp_bar_bg: Panel = _info_section.get_node_or_null("LevelContainer/VBoxContainer/XPBarBG")
	var xp_label: Label = _info_section.get_node_or_null("LevelContainer/VBoxContainer/XPLabel")

	if xp_fill and xp_bar_bg:
		var current_xp: int = _profile_data.get("current_xp", 0)
		var xp_for_level: int = _profile_data.get("xp_for_level", 100)
		var progress: float = float(current_xp) / max(xp_for_level, 1)
		var target_width: float = (xp_bar_bg.size.x - 4) * progress

		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(xp_fill, "size:x", target_width, XP_BAR_FILL_DURATION)

		# Animate XP count
		if xp_label:
			var count_tween := create_tween()
			count_tween.set_ease(Tween.EASE_OUT)
			count_tween.set_trans(Tween.TRANS_CUBIC)
			count_tween.tween_method(
				func(v: float) -> void:
					xp_label.text = "%d / %d XP" % [int(v), xp_for_level],
				0.0,
				float(current_xp),
				XP_COUNT_DURATION
			)

# endregion


# region -- Public API

## Check if this is the local player's profile
func is_own_profile() -> bool:
	return _profile_data.get("is_self", false)


## Get current profile data
func get_profile_data() -> Dictionary:
	return _profile_data.duplicate(true)


## Refresh the profile display
func refresh() -> void:
	_populate_profile()
	_animate_elements()

# endregion
