## FriendsList - Premium social friends list with rich animations
##
## Features:
##   - Animated friend cards with slide-in entrance
##   - Online status with glowing indicator
##   - Activity feed showing what friends are playing
##   - Presence system (In Game, Online, Away, Offline)
##   - Voice chat indicator with animated waveform
##   - Profile pictures with animated frames
##   - Quick actions (invite, message, spectate)
##   - Search and filter functionality
##   - Friend request system with animations
##
## Usage:
##   var friends_list = FriendsList.new()
##   add_child(friends_list)
##   friends_list.load_friends(friends_array)
extends Control


# region -- Signals

## Emitted when a friend card is clicked
signal friend_selected(friend_id: String, friend_data: Dictionary)

## Emitted when invite button is pressed
signal friend_invite_requested(friend_id: String)

## Emitted when message button is pressed
signal friend_message_requested(friend_id: String)

## Emitted when spectate button is pressed
signal friend_spectate_requested(friend_id: String)

## Emitted when friend request is sent
signal friend_request_sent(username: String)

## Emitted when friend request is accepted
signal friend_request_accepted(request_id: String)

## Emitted when friend request is declined
signal friend_request_declined(request_id: String)

## Emitted when friend is removed
signal friend_removed(friend_id: String)

# endregion


# region -- Constants

## Presence status types
enum PresenceStatus {
	OFFLINE,
	ONLINE,
	AWAY,
	IN_GAME,
	DO_NOT_DISTURB,
}

## Presence colors
const PRESENCE_COLORS: Dictionary = {
	PresenceStatus.OFFLINE: Color(0.4, 0.4, 0.45),
	PresenceStatus.ONLINE: Color(0.2, 0.9, 0.4),
	PresenceStatus.AWAY: Color(1.0, 0.7, 0.2),
	PresenceStatus.IN_GAME: Color(0.4, 0.6, 1.0),
	PresenceStatus.DO_NOT_DISTURB: Color(0.9, 0.2, 0.2),
}

## Presence labels
const PRESENCE_LABELS: Dictionary = {
	PresenceStatus.OFFLINE: "Offline",
	PresenceStatus.ONLINE: "Online",
	PresenceStatus.AWAY: "Away",
	PresenceStatus.IN_GAME: "In Game",
	PresenceStatus.DO_NOT_DISTURB: "Do Not Disturb",
}

## Animation timings
const CARD_SLIDE_DURATION: float = 0.4
const CARD_STAGGER_DELAY: float = 0.06
const GLOW_PULSE_SPEED: float = 2.5
const WAVEFORM_SPEED: float = 8.0
const HOVER_SCALE_DURATION: float = 0.15
const ACTION_BUTTON_SLIDE: float = 0.2

## Card dimensions
const CARD_HEIGHT: float = 85.0
const CARD_SPACING: float = 8.0
const AVATAR_SIZE: float = 55.0
const FRAME_WIDTH: float = 3.0

## UI Colors
const CARD_BG: Color = Color(0.1, 0.1, 0.14, 0.95)
const CARD_HOVER_BG: Color = Color(0.14, 0.14, 0.2, 0.98)
const CARD_BORDER: Color = Color(0.2, 0.22, 0.3, 0.7)
const TEXT_PRIMARY: Color = Color(0.95, 0.95, 0.98)
const TEXT_SECONDARY: Color = Color(0.6, 0.62, 0.7)
const TEXT_ACTIVITY: Color = Color(0.5, 0.7, 1.0)

# endregion


# region -- State

## All friends data
var _friends: Array[Dictionary] = []

## Friend requests
var _friend_requests: Array[Dictionary] = []

## Current filter
var _current_filter: String = "all"

## Search query
var _search_query: String = ""

## Friend card nodes by ID
var _card_nodes: Dictionary = {}

## Currently hovered card
var _hovered_card_id: String = ""

## Animation phase for glow effects
var _glow_phase: float = 0.0

## Waveform animation phase
var _waveform_phase: float = 0.0

## UI References
var _header: Control
var _search_input: LineEdit
var _filter_tabs: HBoxContainer
var _scroll_container: ScrollContainer
var _friends_container: VBoxContainer
var _requests_panel: PanelContainer
var _add_friend_panel: Control

# endregion


# region -- Lifecycle

func _ready() -> void:
	_setup_ui()


func _process(delta: float) -> void:
	_glow_phase += delta * GLOW_PULSE_SPEED
	_waveform_phase += delta * WAVEFORM_SPEED
	_update_presence_glows()
	_update_voice_waveforms()

# endregion


# region -- UI Setup

func _setup_ui() -> void:
	name = "FriendsList"
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
	main_vbox.offset_left = 20
	main_vbox.offset_right = -20
	main_vbox.offset_top = 15
	main_vbox.offset_bottom = -15
	main_vbox.add_theme_constant_override("separation", 15)

	# Header
	_header = _create_header()
	main_vbox.add_child(_header)

	# Search bar
	var search_row := _create_search_bar()
	main_vbox.add_child(search_row)

	# Filter tabs
	_filter_tabs = _create_filter_tabs()
	main_vbox.add_child(_filter_tabs)

	# Friend requests panel (collapsible)
	_requests_panel = _create_requests_panel()
	main_vbox.add_child(_requests_panel)

	# Friends scroll container
	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "FriendsScroll"
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_friends_container = VBoxContainer.new()
	_friends_container.name = "FriendsContainer"
	_friends_container.add_theme_constant_override("separation", int(CARD_SPACING))
	_friends_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_scroll_container.add_child(_friends_container)
	main_vbox.add_child(_scroll_container)

	# Add friend button
	var add_friend_btn := _create_add_friend_button()
	main_vbox.add_child(add_friend_btn)

	add_child(main_vbox)


func _create_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 15)

	# Title
	var title := Label.new()
	title.text = "FRIENDS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title)

	# Online count
	var online_count := Label.new()
	online_count.name = "OnlineCount"
	online_count.text = "0 Online"
	online_count.add_theme_font_size_override("font_size", 16)
	online_count.add_theme_color_override("font_color", PRESENCE_COLORS[PresenceStatus.ONLINE])
	header.add_child(online_count)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# Total friends count
	var total_label := Label.new()
	total_label.name = "TotalCount"
	total_label.text = "0 Friends"
	total_label.add_theme_font_size_override("font_size", 14)
	total_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	header.add_child(total_label)

	return header


func _create_search_bar() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Search input
	var search_container := PanelContainer.new()
	search_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color(0.12, 0.12, 0.16)
	search_style.set_corner_radius_all(8)
	search_style.set_border_width_all(1)
	search_style.border_color = CARD_BORDER
	search_container.add_theme_stylebox_override("panel", search_style)

	var search_hbox := HBoxContainer.new()
	search_hbox.add_theme_constant_override("separation", 10)

	# Search icon
	var search_icon := Label.new()
	search_icon.text = "[Search]"
	search_icon.add_theme_font_size_override("font_size", 14)
	search_icon.add_theme_color_override("font_color", TEXT_SECONDARY)
	search_hbox.add_child(search_icon)

	# Input
	_search_input = LineEdit.new()
	_search_input.name = "SearchInput"
	_search_input.placeholder_text = "Search friends..."
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.add_theme_color_override("font_color", TEXT_PRIMARY)
	_search_input.add_theme_color_override("font_placeholder_color", TEXT_SECONDARY)
	_search_input.text_changed.connect(_on_search_changed)
	search_hbox.add_child(_search_input)

	search_container.add_child(search_hbox)
	row.add_child(search_container)

	return row


func _create_filter_tabs() -> HBoxContainer:
	var tabs := HBoxContainer.new()
	tabs.name = "FilterTabs"
	tabs.add_theme_constant_override("separation", 8)

	var filters: Array[Dictionary] = [
		{"id": "all", "label": "All"},
		{"id": "online", "label": "Online"},
		{"id": "in_game", "label": "In Game"},
		{"id": "offline", "label": "Offline"},
	]

	for filter: Dictionary in filters:
		var btn := Button.new()
		btn.name = "Filter_%s" % filter["id"]
		btn.text = filter["label"]
		btn.toggle_mode = true
		btn.button_pressed = filter["id"] == _current_filter
		btn.custom_minimum_size = Vector2(80, 32)
		btn.set_meta("filter_id", filter["id"])

		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.1, 0.1, 0.14)
		normal_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", normal_style)

		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = Color(0.2, 0.3, 0.5)
		pressed_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		btn.pressed.connect(_on_filter_pressed.bind(filter["id"]))
		tabs.add_child(btn)

	return tabs


func _create_requests_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "RequestsPanel"
	panel.visible = false  # Hidden by default

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.18)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.3, 0.6, 0.5)
	panel.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "Friend Requests"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	header.add_child(title)

	var count := Label.new()
	count.name = "RequestCount"
	count.text = "(0)"
	count.add_theme_font_size_override("font_size", 14)
	count.add_theme_color_override("font_color", TEXT_SECONDARY)
	header.add_child(count)

	content.add_child(header)

	var requests_list := VBoxContainer.new()
	requests_list.name = "RequestsList"
	requests_list.add_theme_constant_override("separation", 6)
	content.add_child(requests_list)

	panel.add_child(content)
	return panel


func _create_add_friend_button() -> Button:
	var btn := Button.new()
	btn.name = "AddFriendButton"
	btn.text = "+ Add Friend"
	btn.custom_minimum_size = Vector2(0, 45)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.7)
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.25, 0.5, 0.8)
	hover_style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.pressed.connect(_show_add_friend_dialog)
	return btn

# endregion


# region -- Friend Cards

func _create_friend_card(friend: Dictionary) -> PanelContainer:
	var friend_id: String = friend.get("id", "")
	var presence: int = friend.get("presence", PresenceStatus.OFFLINE)
	var is_speaking: bool = friend.get("is_speaking", false)

	var card := PanelContainer.new()
	card.name = "FriendCard_%s" % friend_id
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.set_meta("friend_id", friend_id)
	card.set_meta("friend_data", friend)
	card.set_meta("presence", presence)
	card.set_meta("is_speaking", is_speaking)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Card style
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = CARD_BORDER
	card.add_theme_stylebox_override("panel", style)

	# Main content
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 15)

	# Avatar with frame and presence indicator
	var avatar_container := _create_avatar_with_frame(friend)
	main_hbox.add_child(avatar_container)

	# Friend info
	var info := _create_friend_info(friend)
	main_hbox.add_child(info)

	# Voice indicator (if speaking)
	if is_speaking:
		var voice_indicator := _create_voice_indicator()
		main_hbox.add_child(voice_indicator)

	# Quick actions
	var actions := _create_quick_actions(friend_id, presence)
	main_hbox.add_child(actions)

	card.add_child(main_hbox)

	# Connect events
	card.mouse_entered.connect(_on_card_hovered.bind(card, true))
	card.mouse_exited.connect(_on_card_hovered.bind(card, false))
	card.gui_input.connect(_on_card_input.bind(card))

	_card_nodes[friend_id] = card
	return card


func _create_avatar_with_frame(friend: Dictionary) -> Control:
	var container := Control.new()
	container.name = "AvatarContainer"
	container.custom_minimum_size = Vector2(AVATAR_SIZE + 10, AVATAR_SIZE + 10)

	var presence: int = friend.get("presence", PresenceStatus.OFFLINE)
	var frame_color: Color = PRESENCE_COLORS.get(presence, PRESENCE_COLORS[PresenceStatus.OFFLINE])

	# Animated frame (drawn with glow)
	var frame := Control.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -(AVATAR_SIZE / 2 + FRAME_WIDTH)
	frame.offset_right = AVATAR_SIZE / 2 + FRAME_WIDTH
	frame.offset_top = -(AVATAR_SIZE / 2 + FRAME_WIDTH)
	frame.offset_bottom = AVATAR_SIZE / 2 + FRAME_WIDTH
	frame.set_meta("frame_color", frame_color)
	frame.set_meta("presence", presence)
	frame.draw.connect(_draw_avatar_frame.bind(frame))
	container.add_child(frame)

	# Avatar background
	var avatar_bg := ColorRect.new()
	avatar_bg.name = "AvatarBG"
	avatar_bg.color = Color(0.2, 0.2, 0.25)
	avatar_bg.set_anchors_preset(Control.PRESET_CENTER)
	avatar_bg.offset_left = -AVATAR_SIZE / 2
	avatar_bg.offset_right = AVATAR_SIZE / 2
	avatar_bg.offset_top = -AVATAR_SIZE / 2
	avatar_bg.offset_bottom = AVATAR_SIZE / 2
	container.add_child(avatar_bg)

	# Avatar initials
	var initials := Label.new()
	initials.name = "Initials"
	var name_str: String = friend.get("name", "?")
	initials.text = name_str[0].to_upper() if name_str.length() > 0 else "?"
	initials.add_theme_font_size_override("font_size", 24)
	initials.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.set_anchors_preset(Control.PRESET_CENTER)
	initials.offset_left = -AVATAR_SIZE / 2
	initials.offset_right = AVATAR_SIZE / 2
	initials.offset_top = -AVATAR_SIZE / 2
	initials.offset_bottom = AVATAR_SIZE / 2
	container.add_child(initials)

	# Presence dot
	var presence_dot := ColorRect.new()
	presence_dot.name = "PresenceDot"
	presence_dot.custom_minimum_size = Vector2(14, 14)
	presence_dot.color = frame_color
	presence_dot.set_anchors_preset(Control.PRESET_CENTER)
	presence_dot.offset_left = AVATAR_SIZE / 2 - 12
	presence_dot.offset_right = AVATAR_SIZE / 2 + 2
	presence_dot.offset_top = AVATAR_SIZE / 2 - 12
	presence_dot.offset_bottom = AVATAR_SIZE / 2 + 2
	container.add_child(presence_dot)

	return container


func _draw_avatar_frame(frame: Control) -> void:
	var center := frame.size / 2
	var radius: float = AVATAR_SIZE / 2 + FRAME_WIDTH / 2
	var frame_color: Color = frame.get_meta("frame_color", Color.WHITE)
	var presence: int = frame.get_meta("presence", PresenceStatus.OFFLINE)

	# Base frame
	frame.draw_arc(center, radius, 0, TAU, 32, frame_color, FRAME_WIDTH)

	# Glow for online statuses
	if presence != PresenceStatus.OFFLINE:
		var glow_alpha: float = 0.2 + 0.15 * sin(_glow_phase)
		var glow_color := frame_color
		glow_color.a = glow_alpha
		frame.draw_arc(center, radius + 2, 0, TAU, 32, glow_color, FRAME_WIDTH + 4)


func _create_friend_info(friend: Dictionary) -> VBoxContainer:
	var info := VBoxContainer.new()
	info.name = "FriendInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)

	# Name row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = friend.get("name", "Friend")
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	name_row.add_child(name_label)

	# Badges/tags
	var badges: Array = friend.get("badges", [])
	for badge: String in badges:
		var badge_label := Label.new()
		badge_label.text = "[%s]" % badge
		badge_label.add_theme_font_size_override("font_size", 11)
		badge_label.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
		name_row.add_child(badge_label)

	info.add_child(name_row)

	# Presence/status
	var presence: int = friend.get("presence", PresenceStatus.OFFLINE)
	var status_label := Label.new()
	status_label.name = "Status"
	status_label.text = PRESENCE_LABELS.get(presence, "Offline")
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", PRESENCE_COLORS.get(presence, TEXT_SECONDARY))
	info.add_child(status_label)

	# Activity (what they're playing)
	var activity: String = friend.get("activity", "")
	if activity.length() > 0:
		var activity_label := Label.new()
		activity_label.name = "Activity"
		activity_label.text = activity
		activity_label.add_theme_font_size_override("font_size", 12)
		activity_label.add_theme_color_override("font_color", TEXT_ACTIVITY)
		info.add_child(activity_label)

	return info


func _create_voice_indicator() -> Control:
	var container := Control.new()
	container.name = "VoiceIndicator"
	container.custom_minimum_size = Vector2(40, 30)
	container.set_meta("waveform_bars", [])
	container.draw.connect(_draw_voice_waveform.bind(container))
	return container


func _draw_voice_waveform(container: Control) -> void:
	var bar_count: int = 4
	var bar_width: float = 4.0
	var bar_spacing: float = 3.0
	var max_height: float = 20.0
	var min_height: float = 4.0
	var center_y: float = container.size.y / 2
	var start_x: float = (container.size.x - (bar_count * bar_width + (bar_count - 1) * bar_spacing)) / 2

	for i: int in bar_count:
		var phase_offset: float = i * 0.8
		var height: float = min_height + (max_height - min_height) * (0.5 + 0.5 * sin(_waveform_phase + phase_offset))
		var x: float = start_x + i * (bar_width + bar_spacing)
		var y: float = center_y - height / 2

		var rect := Rect2(x, y, bar_width, height)
		container.draw_rect(rect, Color(0.3, 0.8, 0.5))


func _create_quick_actions(friend_id: String, presence: int) -> HBoxContainer:
	var actions := HBoxContainer.new()
	actions.name = "QuickActions"
	actions.add_theme_constant_override("separation", 8)
	actions.modulate.a = 0.0  # Hidden by default, show on hover

	# Invite button
	if presence == PresenceStatus.ONLINE or presence == PresenceStatus.AWAY:
		var invite_btn := _create_action_button("Invite", Color(0.2, 0.6, 0.9))
		invite_btn.pressed.connect(func() -> void: friend_invite_requested.emit(friend_id))
		actions.add_child(invite_btn)

	# Message button
	var message_btn := _create_action_button("Msg", Color(0.5, 0.5, 0.6))
	message_btn.pressed.connect(func() -> void: friend_message_requested.emit(friend_id))
	actions.add_child(message_btn)

	# Spectate button (if in game)
	if presence == PresenceStatus.IN_GAME:
		var spectate_btn := _create_action_button("Watch", Color(0.7, 0.4, 0.9))
		spectate_btn.pressed.connect(func() -> void: friend_spectate_requested.emit(friend_id))
		actions.add_child(spectate_btn)

	return actions


func _create_action_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(55, 30)

	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.5)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = color
	btn.add_theme_stylebox_override("normal", style)

	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", color.lightened(0.3))

	return btn

# endregion


# region -- Card Interactions

func _on_card_hovered(card: PanelContainer, hovered: bool) -> void:
	var friend_id: String = card.get_meta("friend_id", "")

	# Update style
	var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	style.bg_color = CARD_HOVER_BG if hovered else CARD_BG
	card.add_theme_stylebox_override("panel", style)

	# Show/hide quick actions
	var actions: HBoxContainer = card.get_node_or_null("HBoxContainer/QuickActions")
	if actions:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(actions, "modulate:a", 1.0 if hovered else 0.0, ACTION_BUTTON_SLIDE)

	# Scale animation
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "scale", Vector2(1.02, 1.02) if hovered else Vector2.ONE, HOVER_SCALE_DURATION)

	_hovered_card_id = friend_id if hovered else ""


func _on_card_input(event: InputEvent, card: PanelContainer) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var friend_id: String = card.get_meta("friend_id", "")
			var friend_data: Dictionary = card.get_meta("friend_data", {})
			friend_selected.emit(friend_id, friend_data)

# endregion


# region -- Filter & Search

func _on_filter_pressed(filter_id: String) -> void:
	if filter_id == _current_filter:
		return

	_current_filter = filter_id

	# Update button states
	for child: Node in _filter_tabs.get_children():
		if child is Button:
			var btn: Button = child
			btn.button_pressed = btn.get_meta("filter_id", "") == filter_id

	_rebuild_friends_list()


func _on_search_changed(text: String) -> void:
	_search_query = text.to_lower()
	_rebuild_friends_list()


func _filter_friends() -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []

	for friend: Dictionary in _friends:
		var presence: int = friend.get("presence", PresenceStatus.OFFLINE)
		var name_str: String = friend.get("name", "").to_lower()

		# Apply search filter
		if _search_query.length() > 0 and not name_str.contains(_search_query):
			continue

		# Apply presence filter
		match _current_filter:
			"all":
				filtered.append(friend)
			"online":
				if presence == PresenceStatus.ONLINE or presence == PresenceStatus.IN_GAME:
					filtered.append(friend)
			"in_game":
				if presence == PresenceStatus.IN_GAME:
					filtered.append(friend)
			"offline":
				if presence == PresenceStatus.OFFLINE:
					filtered.append(friend)

	# Sort: online first, then by name
	filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_online: bool = a.get("presence", PresenceStatus.OFFLINE) != PresenceStatus.OFFLINE
		var b_online: bool = b.get("presence", PresenceStatus.OFFLINE) != PresenceStatus.OFFLINE
		if a_online != b_online:
			return a_online
		return a.get("name", "") < b.get("name", "")
	)

	return filtered

# endregion


# region -- Animations

func _update_presence_glows() -> void:
	for friend_id: String in _card_nodes:
		var card: PanelContainer = _card_nodes[friend_id]
		var avatar_container: Control = card.get_node_or_null("HBoxContainer/AvatarContainer")
		if avatar_container:
			var frame: Control = avatar_container.get_node_or_null("Frame")
			if frame:
				frame.queue_redraw()


func _update_voice_waveforms() -> void:
	for friend_id: String in _card_nodes:
		var card: PanelContainer = _card_nodes[friend_id]
		var is_speaking: bool = card.get_meta("is_speaking", false)
		if is_speaking:
			var voice_indicator: Control = card.get_node_or_null("HBoxContainer/VoiceIndicator")
			if voice_indicator:
				voice_indicator.queue_redraw()


func _animate_card_entrance(card: Control, index: int) -> void:
	# Start off-screen
	card.modulate.a = 0.0
	card.position.x = -100

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "modulate:a", 1.0, CARD_SLIDE_DURATION).set_delay(index * CARD_STAGGER_DELAY)
	tween.parallel().tween_property(card, "position:x", 0, CARD_SLIDE_DURATION).set_delay(index * CARD_STAGGER_DELAY)

# endregion


# region -- Data Loading

## Load friends data
func load_friends(friends: Array[Dictionary]) -> void:
	_friends = friends.duplicate(true)
	_rebuild_friends_list()
	_update_header_counts()


## Load friend requests
func load_friend_requests(requests: Array[Dictionary]) -> void:
	_friend_requests = requests.duplicate(true)
	_update_requests_panel()


func _rebuild_friends_list() -> void:
	# Clear existing
	for child: Node in _friends_container.get_children():
		child.queue_free()
	_card_nodes.clear()

	# Filter and rebuild
	var filtered := _filter_friends()

	for i: int in filtered.size():
		var friend: Dictionary = filtered[i]
		var card := _create_friend_card(friend)
		_friends_container.add_child(card)
		_animate_card_entrance(card, i)


func _update_header_counts() -> void:
	var online_count: int = 0
	for friend: Dictionary in _friends:
		var presence: int = friend.get("presence", PresenceStatus.OFFLINE)
		if presence != PresenceStatus.OFFLINE:
			online_count += 1

	var online_label: Label = _header.get_node_or_null("OnlineCount")
	if online_label:
		online_label.text = "%d Online" % online_count

	var total_label: Label = _header.get_node_or_null("TotalCount")
	if total_label:
		total_label.text = "%d Friends" % _friends.size()


func _update_requests_panel() -> void:
	_requests_panel.visible = _friend_requests.size() > 0

	var count_label: Label = _requests_panel.get_node_or_null("VBoxContainer/HBoxContainer/RequestCount")
	if count_label:
		count_label.text = "(%d)" % _friend_requests.size()

	var requests_list: VBoxContainer = _requests_panel.get_node_or_null("VBoxContainer/RequestsList")
	if not requests_list:
		return

	# Clear existing
	for child: Node in requests_list.get_children():
		child.queue_free()

	# Add request entries
	for request: Dictionary in _friend_requests:
		var entry := _create_request_entry(request)
		requests_list.add_child(entry)


func _create_request_entry(request: Dictionary) -> HBoxContainer:
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override("separation", 10)

	var request_id: String = request.get("id", "")

	# Name
	var name_label := Label.new()
	name_label.text = request.get("from_name", "Unknown")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	entry.add_child(name_label)

	# Accept button
	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size = Vector2(60, 28)

	var accept_style := StyleBoxFlat.new()
	accept_style.bg_color = Color(0.2, 0.6, 0.3)
	accept_style.set_corner_radius_all(5)
	accept_btn.add_theme_stylebox_override("normal", accept_style)
	accept_btn.add_theme_font_size_override("font_size", 12)

	accept_btn.pressed.connect(func() -> void: friend_request_accepted.emit(request_id))
	entry.add_child(accept_btn)

	# Decline button
	var decline_btn := Button.new()
	decline_btn.text = "X"
	decline_btn.custom_minimum_size = Vector2(28, 28)

	var decline_style := StyleBoxFlat.new()
	decline_style.bg_color = Color(0.4, 0.2, 0.2)
	decline_style.set_corner_radius_all(5)
	decline_btn.add_theme_stylebox_override("normal", decline_style)

	decline_btn.pressed.connect(func() -> void: friend_request_declined.emit(request_id))
	entry.add_child(decline_btn)

	return entry


func _show_add_friend_dialog() -> void:
	# Simple modal for adding friend
	var dialog := PanelContainer.new()
	dialog.name = "AddFriendDialog"
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.offset_left = -200
	dialog.offset_right = 200
	dialog.offset_top = -100
	dialog.offset_bottom = 100

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.4, 0.6)
	dialog.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)

	var title := Label.new()
	title.text = "Add Friend"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var input := LineEdit.new()
	input.name = "UsernameInput"
	input.placeholder_text = "Enter username..."
	input.custom_minimum_size = Vector2(0, 40)
	content.add_child(input)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 15)

	var send_btn := Button.new()
	send_btn.text = "Send Request"
	send_btn.custom_minimum_size = Vector2(120, 38)

	var send_style := StyleBoxFlat.new()
	send_style.bg_color = Color(0.2, 0.5, 0.8)
	send_style.set_corner_radius_all(8)
	send_btn.add_theme_stylebox_override("normal", send_style)

	send_btn.pressed.connect(func() -> void:
		var username: String = input.text.strip_edges()
		if username.length() > 0:
			friend_request_sent.emit(username)
		dialog.queue_free()
	)
	buttons.add_child(send_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 38)

	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.3, 0.3, 0.35)
	cancel_style.set_corner_radius_all(8)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)

	cancel_btn.pressed.connect(func() -> void: dialog.queue_free())
	buttons.add_child(cancel_btn)

	content.add_child(buttons)
	dialog.add_child(content)

	# Add backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed:
				dialog.queue_free()
				backdrop.queue_free()
	)
	add_child(backdrop)
	add_child(dialog)

	# Animate entrance
	dialog.modulate.a = 0.0
	dialog.scale = Vector2(0.8, 0.8)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(dialog, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(dialog, "scale", Vector2.ONE, 0.25)

# endregion


# region -- Public API

## Update a friend's presence
func update_friend_presence(friend_id: String, presence: int, activity: String = "") -> void:
	for friend: Dictionary in _friends:
		if friend.get("id", "") == friend_id:
			friend["presence"] = presence
			friend["activity"] = activity
			break

	# Update card if visible
	if _card_nodes.has(friend_id):
		_rebuild_friends_list()

	_update_header_counts()


## Update friend's voice status
func update_friend_voice(friend_id: String, is_speaking: bool) -> void:
	for friend: Dictionary in _friends:
		if friend.get("id", "") == friend_id:
			friend["is_speaking"] = is_speaking
			break

	if _card_nodes.has(friend_id):
		var card: PanelContainer = _card_nodes[friend_id]
		card.set_meta("is_speaking", is_speaking)


## Remove a friend
func remove_friend(friend_id: String) -> void:
	for i: int in range(_friends.size() - 1, -1, -1):
		if _friends[i].get("id", "") == friend_id:
			_friends.remove_at(i)
			break

	_rebuild_friends_list()
	_update_header_counts()
	friend_removed.emit(friend_id)


## Get online friend count
func get_online_count() -> int:
	var count: int = 0
	for friend: Dictionary in _friends:
		if friend.get("presence", PresenceStatus.OFFLINE) != PresenceStatus.OFFLINE:
			count += 1
	return count


## Get total friend count
func get_friend_count() -> int:
	return _friends.size()

# endregion
