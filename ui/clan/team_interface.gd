## TeamInterface - Premium clan/team UI with roster and live status
##
## Features:
##   - Team roster with role badges (Leader/Officer/Member)
##   - Member status indicators (Online/Offline/In-Game)
##   - Team stats comparison vs other teams
##   - Clan wars interface with matchup display
##   - Recruitment board with application management
##   - Announcements with notification badges
##   - Animated transitions and hover effects
##
## Usage:
##   var team_ui = TeamInterface.new()
##   add_child(team_ui)
##   team_ui.load_team_data(team_dictionary)
extends Control


# region -- Signals

## Emitted when a member is clicked
signal member_clicked(member_id: int)

## Emitted when invite button is clicked
signal invite_member_requested()

## Emitted when application is accepted
signal application_accepted(player_id: int)

## Emitted when application is rejected
signal application_rejected(player_id: int)

## Emitted when team settings requested
signal settings_requested()

## Emitted when clan war action is taken
signal clan_war_action(action: String, war_id: String)

## Emitted when announcement is created
signal announcement_created(content: String)

# endregion


# region -- Enums

enum MemberStatus {
	OFFLINE,
	ONLINE,
	IN_GAME,
	AWAY,
}

enum MemberRole {
	MEMBER,
	OFFICER,
	LEADER,
}

enum Tab {
	ROSTER,
	WARS,
	RECRUITMENT,
	ANNOUNCEMENTS,
	STATS,
}

# endregion


# region -- Constants

## Status colors
const STATUS_COLORS: Dictionary = {
	MemberStatus.OFFLINE: Color(0.4, 0.4, 0.5),
	MemberStatus.ONLINE: Color(0.3, 0.9, 0.4),
	MemberStatus.IN_GAME: Color(0.3, 0.6, 1.0),
	MemberStatus.AWAY: Color(0.9, 0.7, 0.2),
}

## Status labels
const STATUS_LABELS: Dictionary = {
	MemberStatus.OFFLINE: "Offline",
	MemberStatus.ONLINE: "Online",
	MemberStatus.IN_GAME: "In Game",
	MemberStatus.AWAY: "Away",
}

## Role colors
const ROLE_COLORS: Dictionary = {
	MemberRole.MEMBER: Color(0.6, 0.6, 0.7),
	MemberRole.OFFICER: Color(0.5, 0.7, 1.0),
	MemberRole.LEADER: Color(1.0, 0.7, 0.2),
}

## Role labels
const ROLE_LABELS: Dictionary = {
	MemberRole.MEMBER: "Member",
	MemberRole.OFFICER: "Officer",
	MemberRole.LEADER: "Leader",
}

## Animation timings
const TAB_TRANSITION: float = 0.3
const MEMBER_STAGGER: float = 0.05
const HOVER_DURATION: float = 0.15
const NOTIFICATION_PULSE: float = 1.0

## Colors
const CARD_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const CARD_BORDER: Color = Color(0.25, 0.25, 0.35, 0.7)
const HEADER_BG: Color = Color(0.08, 0.08, 0.12)
const ACCENT_PRIMARY: Color = Color(0.3, 0.6, 1.0)
const ACCENT_SECONDARY: Color = Color(0.4, 0.8, 0.5)
const DANGER_COLOR: Color = Color(0.9, 0.3, 0.3)

# endregion


# region -- State

## Team data
var _team_data: Dictionary = {}

## Current tab
var _current_tab: Tab = Tab.ROSTER

## User's role in the team
var _user_role: MemberRole = MemberRole.MEMBER

## Notification counts per tab
var _notifications: Dictionary = {
	Tab.RECRUITMENT: 0,
	Tab.ANNOUNCEMENTS: 0,
}

## UI references
var _header: Control
var _tab_bar: HBoxContainer
var _content_container: Control
var _tab_contents: Dictionary = {}

# endregion


# region -- Lifecycle

func _ready() -> void:
	_setup_ui()

# endregion


# region -- UI Setup

func _setup_ui() -> void:
	name = "TeamInterface"
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
	main_vbox.offset_left = 20
	main_vbox.offset_right = -20
	main_vbox.offset_top = 15
	main_vbox.offset_bottom = -15
	main_vbox.add_theme_constant_override("separation", 0)

	# Team header
	_header = _create_header()
	main_vbox.add_child(_header)

	# Tab bar
	_tab_bar = _create_tab_bar()
	main_vbox.add_child(_tab_bar)

	# Content container
	_content_container = Control.new()
	_content_container.name = "ContentContainer"
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.clip_contents = true

	# Create all tab contents
	_tab_contents[Tab.ROSTER] = _create_roster_tab()
	_tab_contents[Tab.WARS] = _create_wars_tab()
	_tab_contents[Tab.RECRUITMENT] = _create_recruitment_tab()
	_tab_contents[Tab.ANNOUNCEMENTS] = _create_announcements_tab()
	_tab_contents[Tab.STATS] = _create_stats_tab()

	for tab: Tab in _tab_contents:
		var content: Control = _tab_contents[tab]
		content.visible = tab == _current_tab
		content.modulate.a = 1.0 if tab == _current_tab else 0.0
		_content_container.add_child(content)

	main_vbox.add_child(_content_container)
	add_child(main_vbox)


func _create_header() -> Control:
	var header := PanelContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 100)

	var header_style := StyleBoxFlat.new()
	header_style.bg_color = HEADER_BG
	header_style.set_corner_radius_all(12)
	header.add_theme_stylebox_override("panel", header_style)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)

	# Team emblem
	var emblem := _create_team_emblem()
	content.add_child(emblem)

	# Team info
	var info := _create_team_info()
	content.add_child(info)

	# Quick stats
	var stats := _create_header_stats()
	content.add_child(stats)

	# Action buttons
	var actions := _create_header_actions()
	content.add_child(actions)

	header.add_child(content)
	return header


func _create_team_emblem() -> Control:
	var container := Control.new()
	container.name = "Emblem"
	container.custom_minimum_size = Vector2(80, 80)

	# Border
	var border := ColorRect.new()
	border.color = ACCENT_PRIMARY.darkened(0.3)
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(border)

	# Background
	var bg := ColorRect.new()
	bg.name = "EmblemBG"
	bg.color = Color(0.15, 0.15, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 3
	bg.offset_right = -3
	bg.offset_top = 3
	bg.offset_bottom = -3
	container.add_child(bg)

	# Placeholder text
	var letter := Label.new()
	letter.name = "EmblemLetter"
	letter.text = "T"
	letter.add_theme_font_size_override("font_size", 40)
	letter.add_theme_color_override("font_color", ACCENT_PRIMARY)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(letter)

	return container


func _create_team_info() -> VBoxContainer:
	var info := VBoxContainer.new()
	info.name = "TeamInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)

	# Team name
	var name_label := Label.new()
	name_label.name = "TeamName"
	name_label.text = "Team Name"
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(name_label)

	# Team tag
	var tag_row := HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 10)

	var tag_label := Label.new()
	tag_label.name = "TeamTag"
	tag_label.text = "[TAG]"
	tag_label.add_theme_font_size_override("font_size", 16)
	tag_label.add_theme_color_override("font_color", ACCENT_PRIMARY)
	tag_row.add_child(tag_label)

	var level_label := Label.new()
	level_label.name = "TeamLevel"
	level_label.text = "Level 1"
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	tag_row.add_child(level_label)

	info.add_child(tag_row)

	# Member count
	var members_label := Label.new()
	members_label.name = "MemberCount"
	members_label.text = "0/50 Members"
	members_label.add_theme_font_size_override("font_size", 13)
	members_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	info.add_child(members_label)

	return info


func _create_header_stats() -> HBoxContainer:
	var stats := HBoxContainer.new()
	stats.name = "HeaderStats"
	stats.add_theme_constant_override("separation", 30)

	# Wins
	var wins := _create_stat_display("WINS", "0", ACCENT_SECONDARY)
	stats.add_child(wins)

	# War record
	var wars := _create_stat_display("WAR RECORD", "0-0", Color(0.7, 0.7, 0.8))
	stats.add_child(wars)

	# Rank
	var rank := _create_stat_display("RANK", "#999", ACCENT_PRIMARY)
	stats.add_child(rank)

	return stats


func _create_stat_display(label: String, value: String, color: Color) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.name = "Stat_%s" % label.replace(" ", "_")
	container.add_theme_constant_override("separation", 2)

	var value_label := Label.new()
	value_label.name = "Value"
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 22)
	value_label.add_theme_color_override("font_color", color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(value_label)

	var label_lbl := Label.new()
	label_lbl.text = label
	label_lbl.add_theme_font_size_override("font_size", 10)
	label_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	label_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(label_lbl)

	return container


func _create_header_actions() -> VBoxContainer:
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 8)

	# Settings button
	var settings_btn := Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(100, 35)
	settings_btn.visible = false  # Only for officers/leaders

	var settings_style := StyleBoxFlat.new()
	settings_style.bg_color = Color(0.2, 0.2, 0.28)
	settings_style.set_corner_radius_all(6)
	settings_btn.add_theme_stylebox_override("normal", settings_style)

	settings_btn.pressed.connect(func() -> void: settings_requested.emit())
	actions.add_child(settings_btn)

	# Invite button
	var invite_btn := Button.new()
	invite_btn.name = "InviteButton"
	invite_btn.text = "Invite"
	invite_btn.custom_minimum_size = Vector2(100, 35)

	var invite_style := StyleBoxFlat.new()
	invite_style.bg_color = ACCENT_PRIMARY.darkened(0.3)
	invite_style.set_corner_radius_all(6)
	invite_btn.add_theme_stylebox_override("normal", invite_style)

	invite_btn.pressed.connect(func() -> void: invite_member_requested.emit())
	actions.add_child(invite_btn)

	return actions


func _create_tab_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.name = "TabBar"
	bar.custom_minimum_size = Vector2(0, 50)
	bar.add_theme_constant_override("separation", 0)

	var tabs: Array[Dictionary] = [
		{"tab": Tab.ROSTER, "label": "Roster"},
		{"tab": Tab.WARS, "label": "Clan Wars"},
		{"tab": Tab.RECRUITMENT, "label": "Recruitment"},
		{"tab": Tab.ANNOUNCEMENTS, "label": "Announcements"},
		{"tab": Tab.STATS, "label": "Stats"},
	]

	for tab_info: Dictionary in tabs:
		var tab_btn := _create_tab_button(tab_info["tab"], tab_info["label"])
		bar.add_child(tab_btn)

	return bar


func _create_tab_button(tab: Tab, label: String) -> Button:
	var btn := Button.new()
	btn.name = "Tab_%d" % tab
	btn.text = label
	btn.toggle_mode = true
	btn.button_pressed = tab == _current_tab
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 45)
	btn.set_meta("tab", tab)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.1, 0.14)
	normal_style.border_width_bottom = 3
	normal_style.border_color = Color(0.15, 0.15, 0.2)
	btn.add_theme_stylebox_override("normal", normal_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.12, 0.12, 0.16)
	pressed_style.border_width_bottom = 3
	pressed_style.border_color = ACCENT_PRIMARY
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.pressed.connect(_on_tab_pressed.bind(tab))

	# Notification badge container
	var badge_container := Control.new()
	badge_container.name = "BadgeContainer"
	badge_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge_container.offset_left = -20
	badge_container.offset_right = 0
	badge_container.offset_top = 5
	badge_container.offset_bottom = 25

	var badge := Label.new()
	badge.name = "NotificationBadge"
	badge.text = ""
	badge.visible = false
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_container.add_child(badge)

	btn.add_child(badge_container)

	return btn


func _on_tab_pressed(tab: Tab) -> void:
	if tab == _current_tab:
		return

	_switch_tab(tab)


func _switch_tab(new_tab: Tab) -> void:
	var old_tab := _current_tab
	_current_tab = new_tab

	# Update button states
	for child: Node in _tab_bar.get_children():
		if child is Button:
			var btn: Button = child
			btn.button_pressed = btn.get_meta("tab", -1) == new_tab

	# Animate content transition
	var old_content: Control = _tab_contents[old_tab]
	var new_content: Control = _tab_contents[new_tab]

	new_content.visible = true

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(old_content, "modulate:a", 0.0, TAB_TRANSITION * 0.4)
	tween.tween_callback(func() -> void: old_content.visible = false)
	tween.tween_property(new_content, "modulate:a", 1.0, TAB_TRANSITION * 0.6)

# endregion


# region -- Tab Contents

func _create_roster_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "RosterTab"
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab.add_theme_constant_override("separation", 15)

	# Online filter
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 10)

	var show_label := Label.new()
	show_label.text = "Show:"
	show_label.add_theme_font_size_override("font_size", 14)
	show_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	filter_row.add_child(show_label)

	var filters := ["All", "Online", "In-Game"]
	for filter_text: String in filters:
		var filter_btn := Button.new()
		filter_btn.text = filter_text
		filter_btn.toggle_mode = true
		filter_btn.button_pressed = filter_text == "All"
		filter_btn.custom_minimum_size = Vector2(70, 30)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.2)
		style.set_corner_radius_all(4)
		filter_btn.add_theme_stylebox_override("normal", style)

		filter_row.add_child(filter_btn)

	tab.add_child(filter_row)

	# Member list scroll
	var scroll := ScrollContainer.new()
	scroll.name = "MemberScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var member_list := VBoxContainer.new()
	member_list.name = "MemberList"
	member_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	member_list.add_theme_constant_override("separation", 8)
	scroll.add_child(member_list)

	tab.add_child(scroll)

	return tab


func _create_wars_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "WarsTab"
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab.add_theme_constant_override("separation", 20)

	# Current war section
	var current_war := _create_current_war_section()
	tab.add_child(current_war)

	# War history
	var history := _create_war_history_section()
	tab.add_child(history)

	return tab


func _create_current_war_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "CurrentWar"
	section.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.text = "CURRENT WAR"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	section.add_child(header)

	# War card
	var war_card := PanelContainer.new()
	war_card.name = "WarCard"
	war_card.custom_minimum_size = Vector2(0, 150)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = CARD_BG
	card_style.set_corner_radius_all(12)
	card_style.set_border_width_all(2)
	card_style.border_color = DANGER_COLOR.darkened(0.5)
	war_card.add_theme_stylebox_override("panel", card_style)

	var war_content := HBoxContainer.new()
	war_content.alignment = BoxContainer.ALIGNMENT_CENTER
	war_content.add_theme_constant_override("separation", 40)

	# Our team
	var our_team := _create_war_team_display("Your Team", true)
	war_content.add_child(our_team)

	# VS
	var vs_label := Label.new()
	vs_label.text = "VS"
	vs_label.add_theme_font_size_override("font_size", 28)
	vs_label.add_theme_color_override("font_color", DANGER_COLOR)
	war_content.add_child(vs_label)

	# Enemy team
	var enemy_team := _create_war_team_display("Enemy Team", false)
	war_content.add_child(enemy_team)

	war_card.add_child(war_content)
	section.add_child(war_card)

	# No war placeholder
	var no_war := Label.new()
	no_war.name = "NoWarLabel"
	no_war.text = "No active war. Start a new war search!"
	no_war.add_theme_font_size_override("font_size", 16)
	no_war.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	no_war.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_war.visible = false
	section.add_child(no_war)

	return section


func _create_war_team_display(team_name: String, is_ours: bool) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.name = "WarTeam_%s" % ("Ours" if is_ours else "Enemy")
	container.add_theme_constant_override("separation", 8)
	container.custom_minimum_size = Vector2(200, 0)

	# Team emblem
	var emblem := ColorRect.new()
	emblem.custom_minimum_size = Vector2(60, 60)
	emblem.color = ACCENT_PRIMARY.darkened(0.5) if is_ours else DANGER_COLOR.darkened(0.5)
	container.add_child(emblem)

	# Team name
	var name_label := Label.new()
	name_label.name = "TeamName"
	name_label.text = team_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_label)

	# Score
	var score_label := Label.new()
	score_label.name = "Score"
	score_label.text = "0"
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_color", ACCENT_SECONDARY if is_ours else DANGER_COLOR)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(score_label)

	return container


func _create_war_history_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "WarHistory"
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.text = "WAR HISTORY"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	section.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var history_list := VBoxContainer.new()
	history_list.name = "HistoryList"
	history_list.add_theme_constant_override("separation", 8)
	scroll.add_child(history_list)

	section.add_child(scroll)

	return section


func _create_recruitment_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "RecruitmentTab"
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab.add_theme_constant_override("separation", 20)

	# Pending applications
	var pending := _create_applications_section()
	tab.add_child(pending)

	# Recruitment settings (for officers/leaders)
	var settings := _create_recruitment_settings()
	tab.add_child(settings)

	return tab


func _create_applications_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "Applications"
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.text = "PENDING APPLICATIONS"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	header_row.add_child(header)

	var count := Label.new()
	count.name = "ApplicationCount"
	count.text = "(0)"
	count.add_theme_font_size_override("font_size", 14)
	count.add_theme_color_override("font_color", ACCENT_PRIMARY)
	header_row.add_child(count)

	section.add_child(header_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var app_list := VBoxContainer.new()
	app_list.name = "ApplicationList"
	app_list.add_theme_constant_override("separation", 10)
	scroll.add_child(app_list)

	section.add_child(scroll)

	return section


func _create_recruitment_settings() -> Control:
	var section := PanelContainer.new()
	section.name = "RecruitmentSettings"
	section.custom_minimum_size = Vector2(0, 100)

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(10)
	section.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.text = "Recruitment Settings"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	content.add_child(header)

	var settings_row := HBoxContainer.new()
	settings_row.add_theme_constant_override("separation", 20)

	# Open recruitment toggle
	var open_label := Label.new()
	open_label.text = "Open Recruitment:"
	open_label.add_theme_font_size_override("font_size", 14)
	open_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	settings_row.add_child(open_label)

	var open_toggle := CheckButton.new()
	open_toggle.name = "OpenRecruitment"
	settings_row.add_child(open_toggle)

	# Min level
	var level_label := Label.new()
	level_label.text = "Min Level:"
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	settings_row.add_child(level_label)

	var level_spin := SpinBox.new()
	level_spin.name = "MinLevel"
	level_spin.min_value = 1
	level_spin.max_value = 100
	level_spin.value = 1
	settings_row.add_child(level_spin)

	content.add_child(settings_row)
	section.add_child(content)

	return section


func _create_announcements_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "AnnouncementsTab"
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab.add_theme_constant_override("separation", 15)

	# New announcement input (for officers/leaders)
	var new_announcement := _create_new_announcement_section()
	tab.add_child(new_announcement)

	# Announcements list
	var scroll := ScrollContainer.new()
	scroll.name = "AnnouncementScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var announcement_list := VBoxContainer.new()
	announcement_list.name = "AnnouncementList"
	announcement_list.add_theme_constant_override("separation", 12)
	scroll.add_child(announcement_list)

	tab.add_child(scroll)

	return tab


func _create_new_announcement_section() -> Control:
	var section := PanelContainer.new()
	section.name = "NewAnnouncement"
	section.custom_minimum_size = Vector2(0, 80)
	section.visible = false  # Only for officers/leaders

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = ACCENT_PRIMARY.darkened(0.5)
	section.add_theme_stylebox_override("panel", style)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	var input := TextEdit.new()
	input.name = "AnnouncementInput"
	input.placeholder_text = "Write an announcement..."
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size = Vector2(0, 60)
	content.add_child(input)

	var post_btn := Button.new()
	post_btn.text = "Post"
	post_btn.custom_minimum_size = Vector2(80, 40)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = ACCENT_PRIMARY.darkened(0.2)
	btn_style.set_corner_radius_all(6)
	post_btn.add_theme_stylebox_override("normal", btn_style)

	post_btn.pressed.connect(func() -> void:
		announcement_created.emit(input.text)
		input.text = ""
	)

	content.add_child(post_btn)
	section.add_child(content)

	return section


func _create_stats_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "StatsTab"
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab.add_theme_constant_override("separation", 20)

	# Team stats grid
	var stats_grid := GridContainer.new()
	stats_grid.name = "TeamStatsGrid"
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 15)

	var stats: Array[Dictionary] = [
		{"key": "total_kills", "label": "Total Kills", "color": DANGER_COLOR},
		{"key": "total_wins", "label": "Total Wins", "color": ACCENT_SECONDARY},
		{"key": "war_wins", "label": "War Victories", "color": ACCENT_PRIMARY},
		{"key": "avg_kd", "label": "Avg K/D", "color": Color(0.8, 0.8, 0.9)},
		{"key": "total_playtime", "label": "Total Playtime", "color": Color(0.7, 0.7, 0.8)},
		{"key": "active_members", "label": "Active Members", "color": ACCENT_SECONDARY},
	]

	for stat: Dictionary in stats:
		var card := _create_stat_card(stat)
		stats_grid.add_child(card)

	tab.add_child(stats_grid)

	# Top performers section
	var top_performers := _create_top_performers_section()
	tab.add_child(top_performers)

	return tab


func _create_stat_card(stat: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "StatCard_%s" % stat["key"]
	card.custom_minimum_size = Vector2(180, 90)

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)

	var label := Label.new()
	label.text = stat["label"]
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(label)

	var value := Label.new()
	value.name = "Value"
	value.text = "0"
	value.add_theme_font_size_override("font_size", 28)
	value.add_theme_color_override("font_color", stat["color"])
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(value)

	card.add_child(content)
	return card


func _create_top_performers_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "TopPerformers"
	section.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.text = "TOP PERFORMERS THIS WEEK"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	section.add_child(header)

	var performers_row := HBoxContainer.new()
	performers_row.name = "PerformersRow"
	performers_row.add_theme_constant_override("separation", 20)
	section.add_child(performers_row)

	return section

# endregion


# region -- Data Population

## Load team data
func load_team_data(data: Dictionary) -> void:
	_team_data = data.duplicate(true)
	_populate_team()


func _populate_team() -> void:
	_update_header()
	_populate_roster()
	_populate_wars()
	_populate_recruitment()
	_populate_announcements()
	_populate_stats()


func _update_header() -> void:
	# Team name
	var name_label: Label = _header.get_node_or_null("HBoxContainer/TeamInfo/TeamName")
	if name_label:
		name_label.text = _team_data.get("name", "Team")

	# Team tag
	var tag_label: Label = _header.get_node_or_null("HBoxContainer/TeamInfo/HBoxContainer/TeamTag")
	if tag_label:
		tag_label.text = "[%s]" % _team_data.get("tag", "TAG")

	# Team level
	var level_label: Label = _header.get_node_or_null("HBoxContainer/TeamInfo/HBoxContainer/TeamLevel")
	if level_label:
		level_label.text = "Level %d" % _team_data.get("level", 1)

	# Member count
	var count_label: Label = _header.get_node_or_null("HBoxContainer/TeamInfo/MemberCount")
	if count_label:
		var current: int = _team_data.get("member_count", 0)
		var max_members: int = _team_data.get("max_members", 50)
		count_label.text = "%d/%d Members" % [current, max_members]

	# Emblem letter
	var emblem_letter: Label = _header.get_node_or_null("HBoxContainer/Emblem/EmblemLetter")
	if emblem_letter:
		var team_name: String = _team_data.get("name", "T")
		if team_name.length() > 0:
			emblem_letter.text = team_name[0].to_upper()


func _populate_roster() -> void:
	var member_list: VBoxContainer = _tab_contents[Tab.ROSTER].get_node_or_null("MemberScroll/MemberList")
	if not member_list:
		return

	# Clear existing
	for child: Node in member_list.get_children():
		child.queue_free()

	# Add members
	var members: Array = _team_data.get("members", [])
	for i: int in members.size():
		var member: Dictionary = members[i]
		var entry := _create_member_entry(member)
		member_list.add_child(entry)

		# Stagger animation
		entry.modulate.a = 0.0
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(entry, "modulate:a", 1.0, 0.2).set_delay(i * MEMBER_STAGGER)


func _create_member_entry(data: Dictionary) -> PanelContainer:
	var entry := PanelContainer.new()
	entry.name = "Member_%d" % data.get("id", 0)
	entry.custom_minimum_size = Vector2(0, 60)

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(8)
	entry.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# Status indicator
	var status_val: int = data.get("status", MemberStatus.OFFLINE)
	var status_dot := ColorRect.new()
	status_dot.custom_minimum_size = Vector2(10, 10)
	status_dot.color = STATUS_COLORS.get(status_val, Color.GRAY)
	hbox.add_child(status_dot)

	# Avatar placeholder
	var avatar := ColorRect.new()
	avatar.custom_minimum_size = Vector2(40, 40)
	avatar.color = Color(0.2, 0.2, 0.25)
	hbox.add_child(avatar)

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = data.get("name", "Member")
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_row.add_child(name_label)

	# Role badge
	var role_val: int = data.get("role", MemberRole.MEMBER)
	if role_val != MemberRole.MEMBER:
		var role_badge := Label.new()
		role_badge.text = "[%s]" % ROLE_LABELS.get(role_val, "Member")
		role_badge.add_theme_font_size_override("font_size", 11)
		role_badge.add_theme_color_override("font_color", ROLE_COLORS.get(role_val, Color.GRAY))
		name_row.add_child(role_badge)

	info.add_child(name_row)

	var status_label := Label.new()
	status_label.text = STATUS_LABELS.get(status_val, "Offline")
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", STATUS_COLORS.get(status_val, Color.GRAY))
	info.add_child(status_label)

	hbox.add_child(info)

	# Level
	var level_label := Label.new()
	level_label.text = "Lv.%d" % data.get("level", 1)
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hbox.add_child(level_label)

	entry.add_child(hbox)

	# Click handler
	var member_id: int = data.get("id", 0)
	entry.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				member_clicked.emit(member_id)
	)

	return entry


func _populate_wars() -> void:
	var current_war: Dictionary = _team_data.get("current_war", {})

	var war_card: PanelContainer = _tab_contents[Tab.WARS].get_node_or_null("CurrentWar/WarCard")
	var no_war_label: Label = _tab_contents[Tab.WARS].get_node_or_null("CurrentWar/NoWarLabel")

	if current_war.is_empty():
		if war_card:
			war_card.visible = false
		if no_war_label:
			no_war_label.visible = true
	else:
		if war_card:
			war_card.visible = true
		if no_war_label:
			no_war_label.visible = false

		# Update war data
		_update_war_display(current_war)


func _update_war_display(war: Dictionary) -> void:
	var our_team: VBoxContainer = _tab_contents[Tab.WARS].get_node_or_null("CurrentWar/WarCard/HBoxContainer/WarTeam_Ours")
	var enemy_team: VBoxContainer = _tab_contents[Tab.WARS].get_node_or_null("CurrentWar/WarCard/HBoxContainer/WarTeam_Enemy")

	if our_team:
		var score: Label = our_team.get_node_or_null("Score")
		if score:
			score.text = str(war.get("our_score", 0))

	if enemy_team:
		var name_lbl: Label = enemy_team.get_node_or_null("TeamName")
		if name_lbl:
			name_lbl.text = war.get("enemy_name", "Enemy")

		var score: Label = enemy_team.get_node_or_null("Score")
		if score:
			score.text = str(war.get("enemy_score", 0))


func _populate_recruitment() -> void:
	var applications: Array = _team_data.get("applications", [])

	var count_label: Label = _tab_contents[Tab.RECRUITMENT].get_node_or_null("Applications/HBoxContainer/ApplicationCount")
	if count_label:
		count_label.text = "(%d)" % applications.size()

	_notifications[Tab.RECRUITMENT] = applications.size()
	_update_tab_notification(Tab.RECRUITMENT)


func _populate_announcements() -> void:
	var announcements: Array = _team_data.get("announcements", [])

	var announcement_list: VBoxContainer = _tab_contents[Tab.ANNOUNCEMENTS].get_node_or_null("AnnouncementScroll/AnnouncementList")
	if not announcement_list:
		return

	# Clear existing
	for child: Node in announcement_list.get_children():
		child.queue_free()

	for announcement: Dictionary in announcements:
		var card := _create_announcement_card(announcement)
		announcement_list.add_child(card)


func _create_announcement_card(data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(10)
	style.border_width_left = 4
	style.border_color = ACCENT_PRIMARY
	card.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)

	var author := Label.new()
	author.text = data.get("author", "Unknown")
	author.add_theme_font_size_override("font_size", 14)
	author.add_theme_color_override("font_color", ACCENT_PRIMARY)
	header.add_child(author)

	var time := Label.new()
	time.text = data.get("time_ago", "")
	time.add_theme_font_size_override("font_size", 12)
	time.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	header.add_child(time)

	content.add_child(header)

	var message := Label.new()
	message.text = data.get("content", "")
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(message)

	card.add_child(content)
	return card


func _populate_stats() -> void:
	var stats: Dictionary = _team_data.get("stats", {})

	_update_team_stat("total_kills", str(stats.get("total_kills", 0)))
	_update_team_stat("total_wins", str(stats.get("total_wins", 0)))
	_update_team_stat("war_wins", str(stats.get("war_wins", 0)))
	_update_team_stat("avg_kd", "%.2f" % stats.get("avg_kd", 0.0))
	_update_team_stat("total_playtime", "%dh" % stats.get("total_playtime_hours", 0))
	_update_team_stat("active_members", str(stats.get("active_members", 0)))


func _update_team_stat(key: String, value: String) -> void:
	var card: PanelContainer = _tab_contents[Tab.STATS].get_node_or_null("TeamStatsGrid/StatCard_%s" % key)
	if card:
		var value_label: Label = card.get_node_or_null("VBoxContainer/Value")
		if value_label:
			value_label.text = value


func _update_tab_notification(tab: Tab) -> void:
	var btn: Button = _tab_bar.get_node_or_null("Tab_%d" % tab)
	if btn:
		var badge: Label = btn.get_node_or_null("BadgeContainer/NotificationBadge")
		if badge:
			var count: int = _notifications.get(tab, 0)
			badge.text = str(count) if count <= 99 else "99+"
			badge.visible = count > 0

# endregion


# region -- Public API

## Set user's role
func set_user_role(role: MemberRole) -> void:
	_user_role = role

	# Update UI based on role
	var settings_btn: Button = _header.get_node_or_null("HBoxContainer/Actions/SettingsButton")
	if settings_btn:
		settings_btn.visible = role >= MemberRole.OFFICER

	var new_announcement: Control = _tab_contents[Tab.ANNOUNCEMENTS].get_node_or_null("NewAnnouncement")
	if new_announcement:
		new_announcement.visible = role >= MemberRole.OFFICER


## Get current tab
func get_current_tab() -> Tab:
	return _current_tab


## Switch to a specific tab
func switch_to_tab(tab: Tab) -> void:
	_switch_tab(tab)


## Refresh team data
func refresh() -> void:
	_populate_team()

# endregion
