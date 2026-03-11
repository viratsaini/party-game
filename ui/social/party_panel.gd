## PartyPanel - Premium party/squad management system
##
## Features:
##   - Party panel with member avatars and status
##   - Ready check visualization with countdown
##   - Voice activity indicators with waveforms
##   - Role icons (leader crown, member)
##   - Party invite flow with animations
##   - Kick/leave with confirmation modals
##   - Party chat integration
##   - Party settings (privacy, game mode)
##   - Member limit display
##   - Join requests queue
##
## Usage:
##   var party = PartyPanel.new()
##   add_child(party)
##   party.set_party_data(party_info)
extends Control


# region -- Signals

## Emitted when party is created
signal party_created(party_id: String)

## Emitted when player leaves party
signal party_left()

## Emitted when a member is invited
signal member_invited(player_id: String)

## Emitted when a member is kicked
signal member_kicked(player_id: String)

## Emitted when ready status changes
signal ready_changed(is_ready: bool)

## Emitted when all members are ready
signal all_ready()

## Emitted when party chat message is sent
signal chat_message_sent(message: String)

## Emitted when party settings change
signal settings_changed(settings: Dictionary)

## Emitted when start game is requested
signal start_game_requested()

# endregion


# region -- Constants

## Party roles
enum PartyRole {
	LEADER,
	MEMBER,
}

## Member status
enum MemberStatus {
	NOT_READY,
	READY,
	IN_GAME,
	LOADING,
	DISCONNECTED,
}

## Status colors
const STATUS_COLORS: Dictionary = {
	MemberStatus.NOT_READY: Color(0.5, 0.5, 0.55),
	MemberStatus.READY: Color(0.3, 0.9, 0.4),
	MemberStatus.IN_GAME: Color(0.4, 0.6, 1.0),
	MemberStatus.LOADING: Color(1.0, 0.7, 0.2),
	MemberStatus.DISCONNECTED: Color(0.9, 0.3, 0.3),
}

## Animation timings
const MEMBER_SLIDE_DURATION: float = 0.35
const READY_PULSE_SPEED: float = 2.0
const VOICE_WAVEFORM_SPEED: float = 8.0
const COUNTDOWN_TICK_SCALE: float = 1.3
const INVITE_POPUP_DURATION: float = 0.3

## Card dimensions
const MEMBER_CARD_HEIGHT: float = 70.0
const AVATAR_SIZE: float = 50.0
const PANEL_WIDTH: float = 320.0

## UI Colors
const PANEL_BG: Color = Color(0.08, 0.08, 0.12, 0.98)
const CARD_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const CARD_HOVER_BG: Color = Color(0.14, 0.14, 0.2, 0.98)
const LEADER_COLOR: Color = Color(1.0, 0.8, 0.2)
const TEXT_PRIMARY: Color = Color(0.95, 0.95, 0.98)
const TEXT_SECONDARY: Color = Color(0.6, 0.62, 0.7)

# endregion


# region -- State

## Party data
var _party_data: Dictionary = {}

## Party members
var _members: Array[Dictionary] = []

## Local player ID
var _local_player_id: String = ""

## Is local player the leader
var _is_leader: bool = false

## Ready check active
var _ready_check_active: bool = false
var _ready_check_countdown: float = 0.0

## Voice state
var _speaking_members: Dictionary = {}  # member_id -> bool

## Animation phases
var _ready_pulse_phase: float = 0.0
var _waveform_phase: float = 0.0

## UI References
var _header: Control
var _members_container: VBoxContainer
var _ready_check_panel: Control
var _party_chat: Control
var _invite_panel: Control
var _settings_panel: Control

## Member nodes
var _member_nodes: Dictionary = {}

# endregion


# region -- Lifecycle

func _ready() -> void:
	_setup_ui()


func _process(delta: float) -> void:
	_ready_pulse_phase += delta * READY_PULSE_SPEED
	_waveform_phase += delta * VOICE_WAVEFORM_SPEED

	_update_ready_visuals()
	_update_voice_indicators()

	if _ready_check_active and _ready_check_countdown > 0:
		_ready_check_countdown -= delta
		_update_countdown_display()

# endregion


# region -- UI Setup

func _setup_ui() -> void:
	name = "PartyPanel"
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Main panel
	var panel := PanelContainer.new()
	panel.name = "MainPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.set_corner_radius_all(16)
	panel_style.shadow_color = Color(0, 0, 0, 0.3)
	panel_style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)

	# Header
	_header = _create_header()
	main_vbox.add_child(_header)

	# Members section
	var members_section := _create_members_section()
	main_vbox.add_child(members_section)

	# Ready check panel
	_ready_check_panel = _create_ready_check_panel()
	main_vbox.add_child(_ready_check_panel)

	# Action buttons
	var actions := _create_action_buttons()
	main_vbox.add_child(actions)

	# Party chat (collapsed by default)
	_party_chat = _create_party_chat()
	main_vbox.add_child(_party_chat)

	panel.add_child(main_vbox)
	add_child(panel)

	# Invite panel (overlay)
	_invite_panel = _create_invite_panel()
	_invite_panel.visible = false
	add_child(_invite_panel)


func _create_header() -> Control:
	var header := VBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "PARTY"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title_row.add_child(title)

	# Member count
	var count := Label.new()
	count.name = "MemberCount"
	count.text = "0/4"
	count.add_theme_font_size_override("font_size", 16)
	count.add_theme_color_override("font_color", TEXT_SECONDARY)
	title_row.add_child(count)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)

	# Settings button
	var settings_btn := Button.new()
	settings_btn.text = "..."
	settings_btn.custom_minimum_size = Vector2(35, 30)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.2)
	btn_style.set_corner_radius_all(6)
	settings_btn.add_theme_stylebox_override("normal", btn_style)

	settings_btn.pressed.connect(_show_settings)
	title_row.add_child(settings_btn)

	header.add_child(title_row)

	# Party code
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)

	var code_label := Label.new()
	code_label.text = "Code:"
	code_label.add_theme_font_size_override("font_size", 13)
	code_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	code_row.add_child(code_label)

	var code_value := Label.new()
	code_value.name = "PartyCode"
	code_value.text = "------"
	code_value.add_theme_font_size_override("font_size", 14)
	code_value.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	code_row.add_child(code_value)

	var copy_btn := Button.new()
	copy_btn.text = "Copy"
	copy_btn.custom_minimum_size = Vector2(50, 24)

	var copy_style := StyleBoxFlat.new()
	copy_style.bg_color = Color(0.2, 0.3, 0.5)
	copy_style.set_corner_radius_all(5)
	copy_btn.add_theme_stylebox_override("normal", copy_style)
	copy_btn.add_theme_font_size_override("font_size", 11)

	copy_btn.pressed.connect(_copy_party_code)
	code_row.add_child(copy_btn)

	header.add_child(code_row)

	return header


func _create_members_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "MembersSection"
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)

	# Section header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "Members"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", TEXT_SECONDARY)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var invite_btn := Button.new()
	invite_btn.name = "InviteButton"
	invite_btn.text = "+ Invite"
	invite_btn.custom_minimum_size = Vector2(70, 26)

	var invite_style := StyleBoxFlat.new()
	invite_style.bg_color = Color(0.2, 0.5, 0.3)
	invite_style.set_corner_radius_all(6)
	invite_btn.add_theme_stylebox_override("normal", invite_style)
	invite_btn.add_theme_font_size_override("font_size", 12)

	invite_btn.pressed.connect(_show_invite_panel)
	header.add_child(invite_btn)

	section.add_child(header)

	# Members container
	_members_container = VBoxContainer.new()
	_members_container.name = "Members"
	_members_container.add_theme_constant_override("separation", 6)

	section.add_child(_members_container)

	return section


func _create_ready_check_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ReadyCheckPanel"
	panel.visible = false
	panel.custom_minimum_size = Vector2(0, 80)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.3, 0.8)
	panel.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)

	# Title
	var title := Label.new()
	title.name = "ReadyTitle"
	title.text = "Ready Check"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	# Countdown
	var countdown := Label.new()
	countdown.name = "Countdown"
	countdown.text = "10"
	countdown.add_theme_font_size_override("font_size", 32)
	countdown.add_theme_color_override("font_color", TEXT_PRIMARY)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(countdown)

	# Ready status icons row
	var status_row := HBoxContainer.new()
	status_row.name = "StatusRow"
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 15)
	content.add_child(status_row)

	panel.add_child(content)
	return panel


func _create_action_buttons() -> Control:
	var container := VBoxContainer.new()
	container.name = "ActionButtons"
	container.add_theme_constant_override("separation", 8)

	# Ready button
	var ready_btn := Button.new()
	ready_btn.name = "ReadyButton"
	ready_btn.text = "Ready Up"
	ready_btn.custom_minimum_size = Vector2(0, 45)
	ready_btn.toggle_mode = true

	var ready_style := StyleBoxFlat.new()
	ready_style.bg_color = Color(0.2, 0.5, 0.3)
	ready_style.set_corner_radius_all(10)
	ready_btn.add_theme_stylebox_override("normal", ready_style)

	var ready_pressed := StyleBoxFlat.new()
	ready_pressed.bg_color = Color(0.3, 0.7, 0.4)
	ready_pressed.set_corner_radius_all(10)
	ready_btn.add_theme_stylebox_override("pressed", ready_pressed)

	ready_btn.add_theme_font_size_override("font_size", 16)
	ready_btn.toggled.connect(_on_ready_toggled)
	container.add_child(ready_btn)

	# Start game button (leader only)
	var start_btn := Button.new()
	start_btn.name = "StartButton"
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size = Vector2(0, 45)
	start_btn.visible = false  # Only visible for leader when all ready

	var start_style := StyleBoxFlat.new()
	start_style.bg_color = Color(0.3, 0.5, 0.8)
	start_style.set_corner_radius_all(10)
	start_btn.add_theme_stylebox_override("normal", start_style)

	var start_hover := StyleBoxFlat.new()
	start_hover.bg_color = Color(0.35, 0.55, 0.9)
	start_hover.set_corner_radius_all(10)
	start_btn.add_theme_stylebox_override("hover", start_hover)

	start_btn.add_theme_font_size_override("font_size", 16)
	start_btn.pressed.connect(func() -> void: start_game_requested.emit())
	container.add_child(start_btn)

	# Leave button
	var leave_btn := Button.new()
	leave_btn.name = "LeaveButton"
	leave_btn.text = "Leave Party"
	leave_btn.custom_minimum_size = Vector2(0, 35)

	var leave_style := StyleBoxFlat.new()
	leave_style.bg_color = Color(0.4, 0.2, 0.2)
	leave_style.set_corner_radius_all(8)
	leave_btn.add_theme_stylebox_override("normal", leave_style)

	leave_btn.add_theme_font_size_override("font_size", 14)
	leave_btn.pressed.connect(_confirm_leave_party)
	container.add_child(leave_btn)

	return container


func _create_party_chat() -> Control:
	var container := VBoxContainer.new()
	container.name = "PartyChat"
	container.add_theme_constant_override("separation", 8)

	# Toggle header
	var header := Button.new()
	header.name = "ChatToggle"
	header.text = "Party Chat [+]"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size = Vector2(0, 30)

	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.12, 0.12, 0.16)
	header_style.set_corner_radius_all(6)
	header.add_theme_stylebox_override("normal", header_style)
	header.add_theme_font_size_override("font_size", 13)

	header.pressed.connect(_toggle_party_chat)
	container.add_child(header)

	# Chat content (hidden by default)
	var chat_content := VBoxContainer.new()
	chat_content.name = "ChatContent"
	chat_content.visible = false
	chat_content.add_theme_constant_override("separation", 6)

	# Messages scroll
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var messages := VBoxContainer.new()
	messages.name = "Messages"
	messages.add_theme_constant_override("separation", 4)
	scroll.add_child(messages)

	chat_content.add_child(scroll)

	# Input
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)

	var input := LineEdit.new()
	input.name = "ChatInput"
	input.placeholder_text = "Message party..."
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(_send_party_chat)
	input_row.add_child(input)

	var send_btn := Button.new()
	send_btn.text = ">"
	send_btn.custom_minimum_size = Vector2(35, 30)

	var send_style := StyleBoxFlat.new()
	send_style.bg_color = Color(0.2, 0.4, 0.6)
	send_style.set_corner_radius_all(6)
	send_btn.add_theme_stylebox_override("normal", send_style)

	send_btn.pressed.connect(func() -> void:
		var chat_input: LineEdit = chat_content.get_node_or_null("HBoxContainer/ChatInput")
		if chat_input:
			_send_party_chat(chat_input.text)
	)
	input_row.add_child(send_btn)

	chat_content.add_child(input_row)
	container.add_child(chat_content)

	return container


func _create_invite_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "InvitePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -150
	panel.offset_bottom = 150

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.4, 0.6)
	panel.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)

	# Title
	var title := Label.new()
	title.text = "Invite to Party"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	# Search input
	var search := LineEdit.new()
	search.name = "SearchInput"
	search.placeholder_text = "Search friends..."
	search.custom_minimum_size = Vector2(0, 40)
	content.add_child(search)

	# Friends list
	var friends_scroll := ScrollContainer.new()
	friends_scroll.custom_minimum_size = Vector2(0, 150)
	friends_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var friends_list := VBoxContainer.new()
	friends_list.name = "FriendsList"
	friends_list.add_theme_constant_override("separation", 6)
	friends_scroll.add_child(friends_list)

	content.add_child(friends_scroll)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 38)

	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.25, 0.25, 0.3)
	close_style.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", close_style)

	close_btn.pressed.connect(func() -> void: _invite_panel.visible = false)
	content.add_child(close_btn)

	panel.add_child(content)
	return panel

# endregion


# region -- Member Cards

func _create_member_card(member: Dictionary) -> PanelContainer:
	var member_id: String = member.get("id", "")
	var role: int = member.get("role", PartyRole.MEMBER)
	var status: int = member.get("status", MemberStatus.NOT_READY)
	var is_speaking: bool = _speaking_members.get(member_id, false)
	var is_self: bool = member_id == _local_player_id

	var card := PanelContainer.new()
	card.name = "Member_%s" % member_id
	card.custom_minimum_size = Vector2(0, MEMBER_CARD_HEIGHT)
	card.set_meta("member_id", member_id)
	card.set_meta("member_data", member)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", style)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)

	# Avatar with role indicator
	var avatar := _create_member_avatar(member, role)
	content.add_child(avatar)

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)

	# Name row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = member.get("name", "Player")
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	name_row.add_child(name_label)

	if is_self:
		var self_tag := Label.new()
		self_tag.text = "(You)"
		self_tag.add_theme_font_size_override("font_size", 12)
		self_tag.add_theme_color_override("font_color", TEXT_SECONDARY)
		name_row.add_child(self_tag)

	if role == PartyRole.LEADER:
		var leader_tag := Label.new()
		leader_tag.text = "[Leader]"
		leader_tag.add_theme_font_size_override("font_size", 12)
		leader_tag.add_theme_color_override("font_color", LEADER_COLOR)
		name_row.add_child(leader_tag)

	info.add_child(name_row)

	# Status
	var status_label := Label.new()
	status_label.name = "Status"
	status_label.text = _get_status_text(status)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", STATUS_COLORS.get(status, TEXT_SECONDARY))
	info.add_child(status_label)

	content.add_child(info)

	# Voice indicator
	if is_speaking:
		var voice := _create_voice_indicator()
		content.add_child(voice)

	# Ready indicator
	var ready_dot := ColorRect.new()
	ready_dot.name = "ReadyDot"
	ready_dot.custom_minimum_size = Vector2(12, 12)
	ready_dot.color = STATUS_COLORS.get(status, TEXT_SECONDARY)
	content.add_child(ready_dot)

	# Kick button (leader only, for non-self)
	if _is_leader and not is_self:
		var kick_btn := Button.new()
		kick_btn.text = "X"
		kick_btn.custom_minimum_size = Vector2(28, 28)
		kick_btn.modulate.a = 0.0  # Hidden until hover

		var kick_style := StyleBoxFlat.new()
		kick_style.bg_color = Color(0.5, 0.2, 0.2)
		kick_style.set_corner_radius_all(5)
		kick_btn.add_theme_stylebox_override("normal", kick_style)

		kick_btn.pressed.connect(_confirm_kick_member.bind(member_id, member.get("name", "Player")))
		content.add_child(kick_btn)

	card.add_child(content)

	# Hover effects
	card.mouse_entered.connect(_on_member_hovered.bind(card, true))
	card.mouse_exited.connect(_on_member_hovered.bind(card, false))

	_member_nodes[member_id] = card
	return card


func _create_member_avatar(member: Dictionary, role: int) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(AVATAR_SIZE + 6, AVATAR_SIZE + 6)

	# Avatar background
	var avatar_bg := ColorRect.new()
	avatar_bg.color = Color(0.2, 0.2, 0.25)
	avatar_bg.set_anchors_preset(Control.PRESET_CENTER)
	avatar_bg.offset_left = -AVATAR_SIZE / 2
	avatar_bg.offset_right = AVATAR_SIZE / 2
	avatar_bg.offset_top = -AVATAR_SIZE / 2
	avatar_bg.offset_bottom = AVATAR_SIZE / 2
	container.add_child(avatar_bg)

	# Initials
	var initials := Label.new()
	var name_str: String = member.get("name", "?")
	initials.text = name_str[0].to_upper() if name_str.length() > 0 else "?"
	initials.add_theme_font_size_override("font_size", 22)
	initials.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.set_anchors_preset(Control.PRESET_CENTER)
	initials.offset_left = -AVATAR_SIZE / 2
	initials.offset_right = AVATAR_SIZE / 2
	initials.offset_top = -AVATAR_SIZE / 2
	initials.offset_bottom = AVATAR_SIZE / 2
	container.add_child(initials)

	# Leader crown
	if role == PartyRole.LEADER:
		var crown := Label.new()
		crown.text = "[*]"
		crown.add_theme_font_size_override("font_size", 14)
		crown.add_theme_color_override("font_color", LEADER_COLOR)
		crown.set_anchors_preset(Control.PRESET_CENTER_TOP)
		crown.offset_top = -AVATAR_SIZE / 2 - 8
		container.add_child(crown)

	return container


func _create_voice_indicator() -> Control:
	var container := Control.new()
	container.name = "VoiceIndicator"
	container.custom_minimum_size = Vector2(35, 25)
	container.draw.connect(_draw_voice_waveform.bind(container))
	return container


func _draw_voice_waveform(container: Control) -> void:
	var bar_count: int = 3
	var bar_width: float = 4.0
	var bar_spacing: float = 3.0
	var max_height: float = 18.0
	var min_height: float = 4.0
	var center_y: float = container.size.y / 2
	var start_x: float = (container.size.x - (bar_count * bar_width + (bar_count - 1) * bar_spacing)) / 2

	for i: int in bar_count:
		var phase_offset: float = i * 0.7
		var height: float = min_height + (max_height - min_height) * (0.5 + 0.5 * sin(_waveform_phase + phase_offset))
		var x: float = start_x + i * (bar_width + bar_spacing)
		var y: float = center_y - height / 2

		var rect := Rect2(x, y, bar_width, height)
		container.draw_rect(rect, Color(0.3, 0.9, 0.5))


func _get_status_text(status: int) -> String:
	match status:
		MemberStatus.NOT_READY: return "Not Ready"
		MemberStatus.READY: return "Ready"
		MemberStatus.IN_GAME: return "In Game"
		MemberStatus.LOADING: return "Loading..."
		MemberStatus.DISCONNECTED: return "Disconnected"
		_: return "Unknown"

# endregion


# region -- Interactions

func _on_member_hovered(card: PanelContainer, hovered: bool) -> void:
	var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	style.bg_color = CARD_HOVER_BG if hovered else CARD_BG
	card.add_theme_stylebox_override("panel", style)

	# Show/hide kick button
	var kick_btn: Button = card.get_node_or_null("HBoxContainer/Button")
	if kick_btn:
		var tween := create_tween()
		tween.tween_property(kick_btn, "modulate:a", 1.0 if hovered else 0.0, 0.15)


func _on_ready_toggled(is_ready: bool) -> void:
	ready_changed.emit(is_ready)

	var ready_btn: Button = get_node_or_null("MainPanel/VBoxContainer/ActionButtons/ReadyButton")
	if ready_btn:
		ready_btn.text = "Ready!" if is_ready else "Ready Up"


func _toggle_party_chat() -> void:
	var chat_content: Control = _party_chat.get_node_or_null("ChatContent")
	var toggle: Button = _party_chat.get_node_or_null("ChatToggle")

	if chat_content:
		chat_content.visible = not chat_content.visible

	if toggle:
		toggle.text = "Party Chat [-]" if chat_content.visible else "Party Chat [+]"


func _send_party_chat(text: String) -> void:
	if text.strip_edges().is_empty():
		return

	chat_message_sent.emit(text)

	var input: LineEdit = _party_chat.get_node_or_null("ChatContent/HBoxContainer/ChatInput")
	if input:
		input.text = ""


func _show_invite_panel() -> void:
	_invite_panel.visible = true

	# Animate
	_invite_panel.modulate.a = 0.0
	_invite_panel.scale = Vector2(0.9, 0.9)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_invite_panel, "modulate:a", 1.0, INVITE_POPUP_DURATION)
	tween.parallel().tween_property(_invite_panel, "scale", Vector2.ONE, INVITE_POPUP_DURATION)


func _copy_party_code() -> void:
	var code: String = _party_data.get("code", "")
	if code.length() > 0:
		DisplayServer.clipboard_set(code)
		# Show feedback
		var code_label: Label = _header.get_node_or_null("VBoxContainer/HBoxContainer/PartyCode")
		if code_label:
			var original_text: String = code_label.text
			code_label.text = "Copied!"
			code_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
			await get_tree().create_timer(1.5).timeout
			code_label.text = original_text
			code_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))


func _show_settings() -> void:
	# Create settings popup
	var popup := PanelContainer.new()
	popup.name = "SettingsPopup"
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.offset_left = -150
	popup.offset_right = 150
	popup.offset_top = -120
	popup.offset_bottom = 120

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.35, 0.45)
	popup.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)

	var title := Label.new()
	title.text = "Party Settings"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	# Privacy setting
	var privacy_row := HBoxContainer.new()
	privacy_row.add_theme_constant_override("separation", 10)

	var privacy_label := Label.new()
	privacy_label.text = "Privacy:"
	privacy_label.add_theme_font_size_override("font_size", 14)
	privacy_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	privacy_row.add_child(privacy_label)

	var privacy_btn := Button.new()
	privacy_btn.text = "Friends Only"
	privacy_btn.toggle_mode = true
	privacy_btn.custom_minimum_size = Vector2(100, 30)

	var pvt_style := StyleBoxFlat.new()
	pvt_style.bg_color = Color(0.2, 0.2, 0.28)
	pvt_style.set_corner_radius_all(6)
	privacy_btn.add_theme_stylebox_override("normal", pvt_style)

	privacy_row.add_child(privacy_btn)
	content.add_child(privacy_row)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 35)

	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.25, 0.25, 0.3)
	close_style.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", close_style)

	close_btn.pressed.connect(func() -> void: popup.queue_free())
	content.add_child(close_btn)

	popup.add_child(content)
	add_child(popup)


func _confirm_leave_party() -> void:
	var dialog := _create_confirm_dialog(
		"Leave Party",
		"Are you sure you want to leave the party?",
		func() -> void: party_left.emit()
	)
	add_child(dialog)


func _confirm_kick_member(member_id: String, member_name: String) -> void:
	var dialog := _create_confirm_dialog(
		"Kick Member",
		"Kick %s from the party?" % member_name,
		func() -> void: member_kicked.emit(member_id)
	)
	add_child(dialog)


func _create_confirm_dialog(title_text: String, message: String, on_confirm: Callable) -> Control:
	var backdrop := ColorRect.new()
	backdrop.name = "DialogBackdrop"
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dialog := PanelContainer.new()
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.offset_left = -140
	dialog.offset_right = 140
	dialog.offset_top = -80
	dialog.offset_bottom = 80

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.3, 0.3)
	dialog.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var msg := Label.new()
	msg.text = message
	msg.add_theme_font_size_override("font_size", 14)
	msg.add_theme_color_override("font_color", TEXT_SECONDARY)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(msg)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 15)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(90, 35)

	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.6, 0.25, 0.25)
	confirm_style.set_corner_radius_all(8)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)

	confirm_btn.pressed.connect(func() -> void:
		on_confirm.call()
		backdrop.queue_free()
	)
	buttons.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 35)

	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.25, 0.25, 0.3)
	cancel_style.set_corner_radius_all(8)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)

	cancel_btn.pressed.connect(func() -> void: backdrop.queue_free())
	buttons.add_child(cancel_btn)

	content.add_child(buttons)
	dialog.add_child(content)
	backdrop.add_child(dialog)

	return backdrop

# endregion


# region -- Visual Updates

func _update_ready_visuals() -> void:
	for member_id: String in _member_nodes:
		var card: PanelContainer = _member_nodes[member_id]
		var ready_dot: ColorRect = card.get_node_or_null("HBoxContainer/ReadyDot")
		var member_data: Dictionary = card.get_meta("member_data", {})
		var status: int = member_data.get("status", MemberStatus.NOT_READY)

		if ready_dot and status == MemberStatus.READY:
			# Pulse effect
			var pulse: float = 0.7 + 0.3 * sin(_ready_pulse_phase)
			ready_dot.color = STATUS_COLORS[MemberStatus.READY] * pulse


func _update_voice_indicators() -> void:
	for member_id: String in _member_nodes:
		if _speaking_members.get(member_id, false):
			var card: PanelContainer = _member_nodes[member_id]
			var voice: Control = card.get_node_or_null("HBoxContainer/VoiceIndicator")
			if voice:
				voice.queue_redraw()


func _update_countdown_display() -> void:
	var countdown_label: Label = _ready_check_panel.get_node_or_null("VBoxContainer/Countdown")
	if countdown_label:
		countdown_label.text = str(int(ceil(_ready_check_countdown)))

		# Tick animation
		if int(_ready_check_countdown) != int(_ready_check_countdown + 0.1):
			var tween := create_tween()
			tween.tween_property(countdown_label, "scale", Vector2.ONE * COUNTDOWN_TICK_SCALE, 0.1)
			tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.15)

# endregion


# region -- Data Loading

## Set party data
func set_party_data(data: Dictionary) -> void:
	_party_data = data.duplicate(true)
	_members = []

	var members_array: Array = data.get("members", [])
	for m: Dictionary in members_array:
		_members.append(m)

	_local_player_id = data.get("local_player_id", "")

	# Check if local player is leader
	for member: Dictionary in _members:
		if member.get("id", "") == _local_player_id:
			_is_leader = member.get("role", PartyRole.MEMBER) == PartyRole.LEADER
			break

	_rebuild_members()
	_update_header()


## Add a member to the party
func add_member(member: Dictionary) -> void:
	_members.append(member)
	var card := _create_member_card(member)
	_members_container.add_child(card)
	_animate_member_entrance(card)
	_update_header()


## Remove a member from the party
func remove_member(member_id: String) -> void:
	for i: int in range(_members.size() - 1, -1, -1):
		if _members[i].get("id", "") == member_id:
			_members.remove_at(i)
			break

	if _member_nodes.has(member_id):
		var card: PanelContainer = _member_nodes[member_id]
		_animate_member_exit(card)
		_member_nodes.erase(member_id)

	_update_header()


## Update member status
func update_member_status(member_id: String, status: int) -> void:
	for member: Dictionary in _members:
		if member.get("id", "") == member_id:
			member["status"] = status
			break

	if _member_nodes.has(member_id):
		var card: PanelContainer = _member_nodes[member_id]
		var status_label: Label = card.get_node_or_null("HBoxContainer/VBoxContainer/Status")
		if status_label:
			status_label.text = _get_status_text(status)
			status_label.add_theme_color_override("font_color", STATUS_COLORS.get(status, TEXT_SECONDARY))

		var ready_dot: ColorRect = card.get_node_or_null("HBoxContainer/ReadyDot")
		if ready_dot:
			ready_dot.color = STATUS_COLORS.get(status, TEXT_SECONDARY)

	_check_all_ready()


## Update voice status
func set_member_speaking(member_id: String, is_speaking: bool) -> void:
	_speaking_members[member_id] = is_speaking


## Start ready check
func start_ready_check(duration: float = 10.0) -> void:
	_ready_check_active = true
	_ready_check_countdown = duration
	_ready_check_panel.visible = true

	# Animate entrance
	_ready_check_panel.modulate.a = 0.0
	_ready_check_panel.scale = Vector2(0.9, 0.9)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_ready_check_panel, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(_ready_check_panel, "scale", Vector2.ONE, 0.3)


## End ready check
func end_ready_check() -> void:
	_ready_check_active = false

	var tween := create_tween()
	tween.tween_property(_ready_check_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void: _ready_check_panel.visible = false)


func _rebuild_members() -> void:
	for child: Node in _members_container.get_children():
		child.queue_free()
	_member_nodes.clear()

	for i: int in _members.size():
		var member: Dictionary = _members[i]
		var card := _create_member_card(member)
		_members_container.add_child(card)
		_animate_member_entrance(card, i)


func _update_header() -> void:
	var max_members: int = _party_data.get("max_members", 4)
	var count_label: Label = _header.get_node_or_null("VBoxContainer/HBoxContainer/MemberCount")
	if count_label:
		count_label.text = "%d/%d" % [_members.size(), max_members]

	var code_label: Label = _header.get_node_or_null("VBoxContainer/HBoxContainer/PartyCode")
	if code_label:
		code_label.text = _party_data.get("code", "------")

	# Show/hide start button based on leader status and ready state
	_check_all_ready()


func _check_all_ready() -> void:
	if not _is_leader:
		return

	var all_ready: bool = true
	for member: Dictionary in _members:
		if member.get("status", MemberStatus.NOT_READY) != MemberStatus.READY:
			all_ready = false
			break

	var start_btn: Button = get_node_or_null("MainPanel/VBoxContainer/ActionButtons/StartButton")
	if start_btn:
		start_btn.visible = all_ready and _members.size() >= 2

	if all_ready and _members.size() >= 2:
		all_ready.emit()


func _animate_member_entrance(card: Control, index: int = 0) -> void:
	card.modulate.a = 0.0
	card.position.x = -50

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "modulate:a", 1.0, MEMBER_SLIDE_DURATION).set_delay(index * 0.08)
	tween.parallel().tween_property(card, "position:x", 0, MEMBER_SLIDE_DURATION).set_delay(index * 0.08)


func _animate_member_exit(card: Control) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(card, "position:x", 50, 0.2)
	tween.tween_callback(func() -> void: card.queue_free())

# endregion


# region -- Public API

## Get party code
func get_party_code() -> String:
	return _party_data.get("code", "")


## Check if local player is leader
func is_leader() -> bool:
	return _is_leader


## Get member count
func get_member_count() -> int:
	return _members.size()


## Get max members
func get_max_members() -> int:
	return _party_data.get("max_members", 4)


## Add chat message to party chat
func add_chat_message(sender: String, message: String) -> void:
	var messages: VBoxContainer = _party_chat.get_node_or_null("ChatContent/ScrollContainer/Messages")
	if not messages:
		return

	var entry := Label.new()
	entry.text = "%s: %s" % [sender, message]
	entry.add_theme_font_size_override("font_size", 13)
	entry.add_theme_color_override("font_color", TEXT_PRIMARY)
	entry.autowrap_mode = TextServer.AUTOWRAP_WORD

	messages.add_child(entry)

	# Limit messages
	while messages.get_child_count() > 50:
		messages.get_child(0).queue_free()

# endregion
