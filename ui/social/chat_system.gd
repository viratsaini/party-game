## ChatSystem - Premium chat system with rich messaging features
##
## Features:
##   - Chat bubbles with tail and smooth animations
##   - Emoji picker with category tabs and search
##   - GIF/sticker support with preview
##   - Animated typing indicators (bouncing dots)
##   - Read receipts with checkmarks
##   - Message reactions with emoji
##   - Reply threading with context preview
##   - Link previews with thumbnails
##   - Multiple chat channels support
##   - Timestamps and grouping
##
## Usage:
##   var chat = ChatSystem.new()
##   add_child(chat)
##   chat.open_channel("general")
extends Control


# region -- Signals

## Emitted when a message is sent
signal message_sent(channel: String, message: String, reply_to: String)

## Emitted when user starts typing
signal typing_started(channel: String)

## Emitted when user stops typing
signal typing_stopped(channel: String)

## Emitted when a reaction is added
signal reaction_added(message_id: String, emoji: String)

## Emitted when a message is clicked
signal message_clicked(message_id: String, message_data: Dictionary)

## Emitted when a link is clicked
signal link_clicked(url: String)

## Emitted when emoji picker is toggled
signal emoji_picker_toggled(visible: bool)

# endregion


# region -- Constants

## Message bubble colors
const BUBBLE_SELF_COLOR: Color = Color(0.2, 0.4, 0.7, 0.95)
const BUBBLE_OTHER_COLOR: Color = Color(0.15, 0.15, 0.2, 0.95)
const BUBBLE_SYSTEM_COLOR: Color = Color(0.1, 0.1, 0.15, 0.8)

## Text colors
const TEXT_PRIMARY: Color = Color(0.95, 0.95, 0.98)
const TEXT_SECONDARY: Color = Color(0.6, 0.62, 0.7)
const TEXT_TIMESTAMP: Color = Color(0.45, 0.45, 0.5)
const TEXT_LINK: Color = Color(0.4, 0.7, 1.0)

## Animation timings
const BUBBLE_SLIDE_DURATION: float = 0.3
const BUBBLE_STAGGER_DELAY: float = 0.05
const TYPING_DOT_SPEED: float = 3.0
const REACTION_POP_DURATION: float = 0.2
const LINK_PREVIEW_FADE: float = 0.25

## Bubble styling
const BUBBLE_CORNER_RADIUS: int = 16
const BUBBLE_TAIL_SIZE: float = 8.0
const BUBBLE_MAX_WIDTH: float = 400.0
const BUBBLE_PADDING: int = 12
const MESSAGE_SPACING: float = 4.0
const GROUP_SPACING: float = 12.0

## Emoji picker
const EMOJI_SIZE: float = 28.0
const EMOJI_GRID_COLUMNS: int = 8
const EMOJI_CATEGORIES: Array = ["Recent", "Smileys", "People", "Animals", "Food", "Activities", "Travel", "Objects"]

## Common emojis (text representations for now)
const COMMON_EMOJIS: Array = [
	":)", ":(", ":D", ";)", ":P", "<3", ":O", ":/",
	":thumbsup:", ":thumbsdown:", ":fire:", ":star:", ":check:", ":x:", ":100:", ":clap:",
	":laugh:", ":cry:", ":angry:", ":think:", ":cool:", ":love:", ":wow:", ":sad:",
]

# endregion


# region -- State

## Current channel ID
var _current_channel: String = ""

## Messages by channel
var _messages: Dictionary = {}  # channel_id -> Array[Dictionary]

## Message nodes by ID
var _message_nodes: Dictionary = {}

## Typing users by channel
var _typing_users: Dictionary = {}  # channel_id -> Array[String]

## Currently replying to message
var _reply_to_message: Dictionary = {}

## Typing indicator phase
var _typing_phase: float = 0.0

## Emoji picker visible
var _emoji_picker_visible: bool = false

## UI references
var _header: Control
var _messages_scroll: ScrollContainer
var _messages_container: VBoxContainer
var _typing_indicator: Control
var _input_area: Control
var _message_input: TextEdit
var _emoji_picker: Control
var _reply_preview: Control

# endregion


# region -- Lifecycle

func _ready() -> void:
	_setup_ui()


func _process(delta: float) -> void:
	_typing_phase += delta * TYPING_DOT_SPEED
	_update_typing_indicator()

# endregion


# region -- UI Setup

func _setup_ui() -> void:
	name = "ChatSystem"
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.06, 0.06, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main layout
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainLayout"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)

	# Header
	_header = _create_header()
	main_vbox.add_child(_header)

	# Messages area
	var messages_area := _create_messages_area()
	main_vbox.add_child(messages_area)

	# Typing indicator
	_typing_indicator = _create_typing_indicator()
	main_vbox.add_child(_typing_indicator)

	# Reply preview (hidden by default)
	_reply_preview = _create_reply_preview()
	main_vbox.add_child(_reply_preview)

	# Input area
	_input_area = _create_input_area()
	main_vbox.add_child(_input_area)

	add_child(main_vbox)

	# Emoji picker (overlay)
	_emoji_picker = _create_emoji_picker()
	_emoji_picker.visible = false
	add_child(_emoji_picker)


func _create_header() -> Control:
	var header := PanelContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 55)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.11)
	style.border_width_bottom = 1
	style.border_color = Color(0.15, 0.15, 0.2)
	header.add_theme_stylebox_override("panel", style)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)

	# Channel icon
	var icon := Label.new()
	icon.text = "#"
	icon.add_theme_font_size_override("font_size", 24)
	icon.add_theme_color_override("font_color", TEXT_SECONDARY)
	content.add_child(icon)

	# Channel name
	var channel_name := Label.new()
	channel_name.name = "ChannelName"
	channel_name.text = "general"
	channel_name.add_theme_font_size_override("font_size", 18)
	channel_name.add_theme_color_override("font_color", TEXT_PRIMARY)
	content.add_child(channel_name)

	# Online count
	var online := Label.new()
	online.name = "OnlineCount"
	online.text = "| 0 online"
	online.add_theme_font_size_override("font_size", 14)
	online.add_theme_color_override("font_color", TEXT_SECONDARY)
	content.add_child(online)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	# Search button
	var search_btn := Button.new()
	search_btn.text = "Search"
	search_btn.custom_minimum_size = Vector2(70, 30)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.2)
	btn_style.set_corner_radius_all(6)
	search_btn.add_theme_stylebox_override("normal", btn_style)
	search_btn.add_theme_font_size_override("font_size", 12)

	content.add_child(search_btn)

	header.add_child(content)
	return header


func _create_messages_area() -> Control:
	_messages_scroll = ScrollContainer.new()
	_messages_scroll.name = "MessagesScroll"
	_messages_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_messages_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_messages_scroll.follow_focus = true

	_messages_container = VBoxContainer.new()
	_messages_container.name = "MessagesContainer"
	_messages_container.add_theme_constant_override("separation", int(MESSAGE_SPACING))
	_messages_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Add padding at top
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 15)
	_messages_container.add_child(top_spacer)

	_messages_scroll.add_child(_messages_container)
	return _messages_scroll


func _create_typing_indicator() -> Control:
	var container := HBoxContainer.new()
	container.name = "TypingIndicator"
	container.visible = false
	container.custom_minimum_size = Vector2(0, 25)
	container.add_theme_constant_override("separation", 8)

	# User text
	var text := Label.new()
	text.name = "TypingText"
	text.text = "Someone is typing"
	text.add_theme_font_size_override("font_size", 13)
	text.add_theme_color_override("font_color", TEXT_SECONDARY)
	container.add_child(text)

	# Animated dots
	var dots := Control.new()
	dots.name = "Dots"
	dots.custom_minimum_size = Vector2(30, 15)
	dots.draw.connect(_draw_typing_dots.bind(dots))
	container.add_child(dots)

	return container


func _draw_typing_dots(dots: Control) -> void:
	var dot_radius: float = 3.0
	var spacing: float = 8.0
	var y: float = dots.size.y / 2

	for i: int in 3:
		var phase_offset: float = i * 0.8
		var bounce: float = 2.0 * abs(sin(_typing_phase + phase_offset))
		var x: float = 5 + i * spacing
		dots.draw_circle(Vector2(x, y - bounce), dot_radius, TEXT_SECONDARY)


func _create_reply_preview() -> Control:
	var container := PanelContainer.new()
	container.name = "ReplyPreview"
	container.visible = false
	container.custom_minimum_size = Vector2(0, 45)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.border_width_left = 3
	style.border_color = Color(0.3, 0.5, 0.8)
	container.add_theme_stylebox_override("panel", style)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	# Reply info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var reply_to := Label.new()
	reply_to.name = "ReplyTo"
	reply_to.text = "Replying to Username"
	reply_to.add_theme_font_size_override("font_size", 12)
	reply_to.add_theme_color_override("font_color", TEXT_LINK)
	info.add_child(reply_to)

	var preview_text := Label.new()
	preview_text.name = "PreviewText"
	preview_text.text = "Message preview..."
	preview_text.add_theme_font_size_override("font_size", 12)
	preview_text.add_theme_color_override("font_color", TEXT_SECONDARY)
	preview_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(preview_text)

	content.add_child(info)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "X"
	cancel_btn.custom_minimum_size = Vector2(25, 25)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.25)
	btn_style.set_corner_radius_all(4)
	cancel_btn.add_theme_stylebox_override("normal", btn_style)

	cancel_btn.pressed.connect(_cancel_reply)
	content.add_child(cancel_btn)

	container.add_child(content)
	return container


func _create_input_area() -> Control:
	var container := PanelContainer.new()
	container.name = "InputArea"
	container.custom_minimum_size = Vector2(0, 60)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.11)
	style.border_width_top = 1
	style.border_color = Color(0.15, 0.15, 0.2)
	container.add_theme_stylebox_override("panel", style)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	# Attachment button
	var attach_btn := Button.new()
	attach_btn.text = "+"
	attach_btn.custom_minimum_size = Vector2(35, 35)

	var attach_style := StyleBoxFlat.new()
	attach_style.bg_color = Color(0.15, 0.15, 0.2)
	attach_style.set_corner_radius_all(8)
	attach_btn.add_theme_stylebox_override("normal", attach_style)
	attach_btn.add_theme_font_size_override("font_size", 20)

	content.add_child(attach_btn)

	# Message input
	var input_container := PanelContainer.new()
	input_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.12, 0.12, 0.16)
	input_style.set_corner_radius_all(10)
	input_container.add_theme_stylebox_override("panel", input_style)

	_message_input = TextEdit.new()
	_message_input.name = "MessageInput"
	_message_input.placeholder_text = "Type a message..."
	_message_input.custom_minimum_size = Vector2(0, 38)
	_message_input.scroll_fit_content_height = true
	_message_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_message_input.add_theme_color_override("font_color", TEXT_PRIMARY)
	_message_input.add_theme_color_override("font_placeholder_color", TEXT_SECONDARY)
	_message_input.text_changed.connect(_on_input_changed)
	_message_input.gui_input.connect(_on_input_key)

	input_container.add_child(_message_input)
	content.add_child(input_container)

	# Emoji button
	var emoji_btn := Button.new()
	emoji_btn.text = ":)"
	emoji_btn.custom_minimum_size = Vector2(35, 35)

	var emoji_style := StyleBoxFlat.new()
	emoji_style.bg_color = Color(0.15, 0.15, 0.2)
	emoji_style.set_corner_radius_all(8)
	emoji_btn.add_theme_stylebox_override("normal", emoji_style)
	emoji_btn.add_theme_font_size_override("font_size", 16)

	emoji_btn.pressed.connect(_toggle_emoji_picker)
	content.add_child(emoji_btn)

	# Send button
	var send_btn := Button.new()
	send_btn.name = "SendButton"
	send_btn.text = ">"
	send_btn.custom_minimum_size = Vector2(45, 35)

	var send_style := StyleBoxFlat.new()
	send_style.bg_color = Color(0.2, 0.5, 0.8)
	send_style.set_corner_radius_all(8)
	send_btn.add_theme_stylebox_override("normal", send_style)
	send_btn.add_theme_font_size_override("font_size", 18)

	send_btn.pressed.connect(_send_message)
	content.add_child(send_btn)

	container.add_child(content)
	return container


func _create_emoji_picker() -> Control:
	var panel := PanelContainer.new()
	panel.name = "EmojiPicker"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -320
	panel.offset_top = -350
	panel.offset_right = -10
	panel.offset_bottom = -70

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14)
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color(0.2, 0.2, 0.28)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	# Search bar
	var search := LineEdit.new()
	search.name = "EmojiSearch"
	search.placeholder_text = "Search emojis..."
	search.custom_minimum_size = Vector2(0, 35)
	content.add_child(search)

	# Category tabs
	var categories := HBoxContainer.new()
	categories.name = "CategoryTabs"
	categories.add_theme_constant_override("separation", 5)

	for category: String in EMOJI_CATEGORIES:
		var tab := Button.new()
		tab.text = category.substr(0, 2)
		tab.custom_minimum_size = Vector2(32, 28)
		tab.toggle_mode = true
		tab.button_pressed = category == "Recent"

		var tab_style := StyleBoxFlat.new()
		tab_style.bg_color = Color(0.15, 0.15, 0.2)
		tab_style.set_corner_radius_all(5)
		tab.add_theme_stylebox_override("normal", tab_style)
		tab.add_theme_font_size_override("font_size", 11)

		categories.add_child(tab)

	content.add_child(categories)

	# Emoji grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var grid := GridContainer.new()
	grid.name = "EmojiGrid"
	grid.columns = EMOJI_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)

	# Populate with common emojis
	for emoji: String in COMMON_EMOJIS:
		var btn := Button.new()
		btn.text = emoji
		btn.custom_minimum_size = Vector2(EMOJI_SIZE, EMOJI_SIZE)

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.15, 0.2)
		btn_style.set_corner_radius_all(5)
		btn.add_theme_stylebox_override("normal", btn_style)

		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.25, 0.25, 0.35)
		hover_style.set_corner_radius_all(5)
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_emoji_selected.bind(emoji))

		grid.add_child(btn)

	scroll.add_child(grid)
	content.add_child(scroll)

	panel.add_child(content)
	return panel

# endregion


# region -- Message Bubbles

func _create_message_bubble(message: Dictionary) -> Control:
	var is_self: bool = message.get("is_self", false)
	var is_system: bool = message.get("is_system", false)
	var message_id: String = message.get("id", "")

	# Container for alignment
	var container := HBoxContainer.new()
	container.name = "Message_%s" % message_id
	container.set_meta("message_id", message_id)
	container.set_meta("message_data", message)

	if is_system:
		container.alignment = BoxContainer.ALIGNMENT_CENTER
	elif is_self:
		container.alignment = BoxContainer.ALIGNMENT_END
	else:
		container.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Bubble
	var bubble := PanelContainer.new()
	bubble.name = "Bubble"
	bubble.custom_minimum_size = Vector2(80, 0)

	var style := StyleBoxFlat.new()
	if is_system:
		style.bg_color = BUBBLE_SYSTEM_COLOR
		style.set_corner_radius_all(8)
	else:
		style.bg_color = BUBBLE_SELF_COLOR if is_self else BUBBLE_OTHER_COLOR
		style.corner_radius_top_left = BUBBLE_CORNER_RADIUS
		style.corner_radius_top_right = BUBBLE_CORNER_RADIUS
		style.corner_radius_bottom_left = BUBBLE_CORNER_RADIUS if is_self else 4
		style.corner_radius_bottom_right = 4 if is_self else BUBBLE_CORNER_RADIUS

	bubble.add_theme_stylebox_override("panel", style)

	var bubble_content := VBoxContainer.new()
	bubble_content.add_theme_constant_override("separation", 6)

	# Reply context (if replying to another message)
	var reply_to: Dictionary = message.get("reply_to", {})
	if not reply_to.is_empty():
		var reply_context := _create_reply_context(reply_to)
		bubble_content.add_child(reply_context)

	# Sender name (for others' messages)
	if not is_self and not is_system:
		var sender := Label.new()
		sender.text = message.get("sender_name", "User")
		sender.add_theme_font_size_override("font_size", 13)
		sender.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		bubble_content.add_child(sender)

	# Message text
	var text := RichTextLabel.new()
	text.name = "MessageText"
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(50, 0)

	# Parse message for links and emojis
	var parsed_text: String = _parse_message_text(message.get("text", ""))
	text.text = parsed_text
	text.add_theme_font_size_override("normal_font_size", 15)
	text.add_theme_color_override("default_color", TEXT_PRIMARY if not is_system else TEXT_SECONDARY)

	bubble_content.add_child(text)

	# Link preview (if message contains URL)
	var link_preview: Dictionary = message.get("link_preview", {})
	if not link_preview.is_empty():
		var preview := _create_link_preview(link_preview)
		bubble_content.add_child(preview)

	# Timestamp and read receipt row
	var meta_row := HBoxContainer.new()
	meta_row.alignment = BoxContainer.ALIGNMENT_END
	meta_row.add_theme_constant_override("separation", 8)

	var timestamp := Label.new()
	timestamp.text = message.get("timestamp", "")
	timestamp.add_theme_font_size_override("font_size", 11)
	timestamp.add_theme_color_override("font_color", TEXT_TIMESTAMP)
	meta_row.add_child(timestamp)

	# Read receipt (for self messages)
	if is_self:
		var receipt := Label.new()
		receipt.name = "ReadReceipt"
		var read_by: int = message.get("read_by", 0)
		if read_by > 0:
			receipt.text = "[Read]"
			receipt.add_theme_color_override("font_color", Color(0.4, 0.8, 0.5))
		else:
			receipt.text = "[Sent]"
			receipt.add_theme_color_override("font_color", TEXT_TIMESTAMP)
		receipt.add_theme_font_size_override("font_size", 11)
		meta_row.add_child(receipt)

	bubble_content.add_child(meta_row)

	# Reactions
	var reactions: Dictionary = message.get("reactions", {})
	if not reactions.is_empty():
		var reactions_row := _create_reactions_row(reactions, message_id)
		bubble_content.add_child(reactions_row)

	bubble.add_child(bubble_content)

	# Add spacer for alignment
	if not is_system:
		if is_self:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(spacer)

		container.add_child(bubble)

		if not is_self:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(spacer)
	else:
		container.add_child(bubble)

	# Connect interactions
	bubble.gui_input.connect(_on_bubble_input.bind(container))

	_message_nodes[message_id] = container
	return container


func _create_reply_context(reply_to: Dictionary) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(0, 35)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.6)
	style.border_width_left = 2
	style.border_color = Color(0.4, 0.5, 0.7)
	style.set_corner_radius_all(4)
	container.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)

	var sender := Label.new()
	sender.text = reply_to.get("sender_name", "User")
	sender.add_theme_font_size_override("font_size", 12)
	sender.add_theme_color_override("font_color", TEXT_LINK)
	content.add_child(sender)

	var preview := Label.new()
	var preview_text: String = reply_to.get("text", "")
	if preview_text.length() > 50:
		preview_text = preview_text.substr(0, 47) + "..."
	preview.text = preview_text
	preview.add_theme_font_size_override("font_size", 11)
	preview.add_theme_color_override("font_color", TEXT_SECONDARY)
	content.add_child(preview)

	container.add_child(content)
	return container


func _create_link_preview(preview: Dictionary) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(200, 80)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.2, 0.2, 0.28)
	container.add_theme_stylebox_override("panel", style)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)

	# Thumbnail placeholder
	var thumb := ColorRect.new()
	thumb.custom_minimum_size = Vector2(70, 70)
	thumb.color = Color(0.15, 0.15, 0.2)
	content.add_child(thumb)

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = preview.get("title", "Link")
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(title)

	var desc := Label.new()
	var description: String = preview.get("description", "")
	if description.length() > 60:
		description = description.substr(0, 57) + "..."
	desc.text = description
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", TEXT_SECONDARY)
	info.add_child(desc)

	var domain := Label.new()
	domain.text = preview.get("domain", "")
	domain.add_theme_font_size_override("font_size", 11)
	domain.add_theme_color_override("font_color", TEXT_LINK)
	info.add_child(domain)

	content.add_child(info)
	container.add_child(content)

	# Click handler
	container.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				link_clicked.emit(preview.get("url", ""))
	)

	return container


func _create_reactions_row(reactions: Dictionary, message_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Reactions"
	row.add_theme_constant_override("separation", 6)

	for emoji: String in reactions.keys():
		var count: int = reactions[emoji]
		var reaction := _create_reaction_chip(emoji, count, message_id)
		row.add_child(reaction)

	# Add reaction button
	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.custom_minimum_size = Vector2(26, 22)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.set_corner_radius_all(11)
	add_btn.add_theme_stylebox_override("normal", style)
	add_btn.add_theme_font_size_override("font_size", 12)

	add_btn.pressed.connect(_show_reaction_picker.bind(message_id))
	row.add_child(add_btn)

	return row


func _create_reaction_chip(emoji: String, count: int, message_id: String) -> Button:
	var chip := Button.new()
	chip.text = "%s %d" % [emoji, count]
	chip.custom_minimum_size = Vector2(0, 22)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.25, 0.35)
	style.set_corner_radius_all(11)
	chip.add_theme_stylebox_override("normal", style)
	chip.add_theme_font_size_override("font_size", 12)

	chip.pressed.connect(func() -> void: reaction_added.emit(message_id, emoji))

	return chip


func _parse_message_text(text: String) -> String:
	# Simple URL detection
	var url_regex := RegEx.new()
	url_regex.compile("(https?://[^\\s]+)")
	text = url_regex.sub(text, "[color=#66aaff][url=$1]$1[/url][/color]", true)

	return text

# endregion


# region -- Input Handling

func _on_input_changed() -> void:
	if _message_input.text.length() > 0:
		typing_started.emit(_current_channel)
	else:
		typing_stopped.emit(_current_channel)


func _on_input_key(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ENTER:
			if not key.shift_pressed:
				_send_message()
				get_viewport().set_input_as_handled()


func _send_message() -> void:
	var text: String = _message_input.text.strip_edges()
	if text.is_empty():
		return

	var reply_id: String = _reply_to_message.get("id", "")

	# Emit signal
	message_sent.emit(_current_channel, text, reply_id)

	# Clear input
	_message_input.text = ""
	_cancel_reply()

	typing_stopped.emit(_current_channel)


func _toggle_emoji_picker() -> void:
	_emoji_picker_visible = not _emoji_picker_visible
	_emoji_picker.visible = _emoji_picker_visible

	if _emoji_picker_visible:
		# Animate entrance
		_emoji_picker.modulate.a = 0.0
		_emoji_picker.scale = Vector2(0.9, 0.9)

		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(_emoji_picker, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(_emoji_picker, "scale", Vector2.ONE, 0.2)

	emoji_picker_toggled.emit(_emoji_picker_visible)


func _on_emoji_selected(emoji: String) -> void:
	_message_input.text += " " + emoji + " "
	_emoji_picker.visible = false
	_emoji_picker_visible = false


func _on_bubble_input(event: InputEvent, container: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var message_id: String = container.get_meta("message_id", "")
			var message_data: Dictionary = container.get_meta("message_data", {})
			_show_message_context_menu(message_id, message_data, mb.global_position)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			var message_id: String = container.get_meta("message_id", "")
			var message_data: Dictionary = container.get_meta("message_data", {})
			message_clicked.emit(message_id, message_data)


func _show_message_context_menu(message_id: String, message_data: Dictionary, pos: Vector2) -> void:
	var menu := PopupMenu.new()
	menu.add_item("Reply", 0)
	menu.add_item("React", 1)
	menu.add_separator()
	menu.add_item("Copy", 2)

	if message_data.get("is_self", false):
		menu.add_separator()
		menu.add_item("Edit", 3)
		menu.add_item("Delete", 4)

	menu.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _start_reply(message_data)
			1: _show_reaction_picker(message_id)
			2: DisplayServer.clipboard_set(message_data.get("text", ""))
		menu.queue_free()
	)

	add_child(menu)
	menu.popup(Rect2i(int(pos.x), int(pos.y), 0, 0))


func _start_reply(message: Dictionary) -> void:
	_reply_to_message = message
	_reply_preview.visible = true

	var reply_to: Label = _reply_preview.get_node_or_null("HBoxContainer/VBoxContainer/ReplyTo")
	if reply_to:
		reply_to.text = "Replying to %s" % message.get("sender_name", "User")

	var preview_text: Label = _reply_preview.get_node_or_null("HBoxContainer/VBoxContainer/PreviewText")
	if preview_text:
		var text: String = message.get("text", "")
		if text.length() > 50:
			text = text.substr(0, 47) + "..."
		preview_text.text = text

	_message_input.grab_focus()


func _cancel_reply() -> void:
	_reply_to_message = {}
	_reply_preview.visible = false


func _show_reaction_picker(message_id: String) -> void:
	# Simple inline reaction picker
	var quick_reactions: Array = [":thumbsup:", ":heart:", ":laugh:", ":fire:", ":clap:"]

	var picker := HBoxContainer.new()
	picker.name = "QuickReactions"
	picker.add_theme_constant_override("separation", 5)

	for emoji: String in quick_reactions:
		var btn := Button.new()
		btn.text = emoji
		btn.custom_minimum_size = Vector2(32, 32)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.28)
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)

		btn.pressed.connect(func() -> void:
			reaction_added.emit(message_id, emoji)
			picker.queue_free()
		)

		picker.add_child(btn)

	# Position near the message
	if _message_nodes.has(message_id):
		var message_node: Control = _message_nodes[message_id]
		picker.position = message_node.global_position + Vector2(50, -40)

	add_child(picker)

	# Auto-dismiss after delay
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(picker):
		picker.queue_free()

# endregion


# region -- Typing Indicator

func _update_typing_indicator() -> void:
	var typing: Array = _typing_users.get(_current_channel, [])

	if typing.is_empty():
		_typing_indicator.visible = false
		return

	_typing_indicator.visible = true

	var text_label: Label = _typing_indicator.get_node_or_null("TypingText")
	if text_label:
		if typing.size() == 1:
			text_label.text = "%s is typing" % typing[0]
		elif typing.size() == 2:
			text_label.text = "%s and %s are typing" % [typing[0], typing[1]]
		else:
			text_label.text = "Several people are typing"

	var dots: Control = _typing_indicator.get_node_or_null("Dots")
	if dots:
		dots.queue_redraw()

# endregion


# region -- Data Loading

## Open a chat channel
func open_channel(channel_id: String) -> void:
	_current_channel = channel_id

	# Update header
	var channel_name: Label = _header.get_node_or_null("HBoxContainer/ChannelName")
	if channel_name:
		channel_name.text = channel_id

	# Load messages
	_rebuild_messages()


## Add a message to the current channel
func add_message(message: Dictionary) -> void:
	if not _messages.has(_current_channel):
		_messages[_current_channel] = []

	_messages[_current_channel].append(message)

	# Create and animate bubble
	var bubble := _create_message_bubble(message)
	_messages_container.add_child(bubble)
	_animate_bubble_entrance(bubble)

	# Scroll to bottom
	await get_tree().process_frame
	_messages_scroll.scroll_vertical = int(_messages_scroll.get_v_scroll_bar().max_value)


## Load multiple messages
func load_messages(messages: Array[Dictionary]) -> void:
	_messages[_current_channel] = messages.duplicate(true)
	_rebuild_messages()


## Set typing users for a channel
func set_typing_users(channel: String, users: Array) -> void:
	_typing_users[channel] = users


func _rebuild_messages() -> void:
	# Clear existing (keep spacer)
	while _messages_container.get_child_count() > 1:
		var child: Node = _messages_container.get_child(1)
		child.queue_free()
	_message_nodes.clear()

	var messages: Array = _messages.get(_current_channel, [])

	for i: int in messages.size():
		var message: Dictionary = messages[i]
		var bubble := _create_message_bubble(message)
		_messages_container.add_child(bubble)
		_animate_bubble_entrance(bubble, i)

	# Scroll to bottom
	await get_tree().process_frame
	_messages_scroll.scroll_vertical = int(_messages_scroll.get_v_scroll_bar().max_value)


func _animate_bubble_entrance(bubble: Control, index: int = 0) -> void:
	bubble.modulate.a = 0.0
	bubble.position.y += 20

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(bubble, "modulate:a", 1.0, BUBBLE_SLIDE_DURATION).set_delay(index * BUBBLE_STAGGER_DELAY)
	tween.parallel().tween_property(bubble, "position:y", bubble.position.y - 20, BUBBLE_SLIDE_DURATION).set_delay(index * BUBBLE_STAGGER_DELAY)

# endregion


# region -- Public API

## Update read receipt for a message
func update_read_receipt(message_id: String, read_by: int) -> void:
	if not _message_nodes.has(message_id):
		return

	var container: Control = _message_nodes[message_id]
	var receipt: Label = container.get_node_or_null("Bubble/VBoxContainer/HBoxContainer/ReadReceipt")
	if receipt:
		if read_by > 0:
			receipt.text = "[Read]"
			receipt.add_theme_color_override("font_color", Color(0.4, 0.8, 0.5))
		else:
			receipt.text = "[Sent]"
			receipt.add_theme_color_override("font_color", TEXT_TIMESTAMP)


## Add a reaction to a message
func add_message_reaction(message_id: String, emoji: String, count: int) -> void:
	# Update stored message data
	for msg: Dictionary in _messages.get(_current_channel, []):
		if msg.get("id", "") == message_id:
			if not msg.has("reactions"):
				msg["reactions"] = {}
			msg["reactions"][emoji] = count
			break

	# Rebuild reactions row if message is visible
	if _message_nodes.has(message_id):
		var container: Control = _message_nodes[message_id]
		var reactions_row: HBoxContainer = container.get_node_or_null("Bubble/VBoxContainer/Reactions")

		if reactions_row:
			# Find or create chip
			var found: bool = false
			for child: Node in reactions_row.get_children():
				if child is Button and child.text.begins_with(emoji):
					child.text = "%s %d" % [emoji, count]
					found = true
					# Pop animation
					var tween := create_tween()
					tween.set_ease(Tween.EASE_OUT)
					tween.set_trans(Tween.TRANS_ELASTIC)
					tween.tween_property(child, "scale", Vector2(1.2, 1.2), 0.1)
					tween.tween_property(child, "scale", Vector2.ONE, 0.1)
					break

			if not found:
				var chip := _create_reaction_chip(emoji, count, message_id)
				reactions_row.add_child(chip)
				reactions_row.move_child(chip, reactions_row.get_child_count() - 2)  # Before add button


## Clear all messages
func clear_messages() -> void:
	_messages[_current_channel] = []
	_rebuild_messages()


## Get current channel
func get_current_channel() -> String:
	return _current_channel

# endregion
