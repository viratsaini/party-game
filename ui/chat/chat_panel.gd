## ChatPanel — UI component for the in-game chat
extends PanelContainer

@onready var message_scroll: ScrollContainer = %MessageScroll
@onready var message_list: VBoxContainer = %MessageList
@onready var input_row: HBoxContainer = %InputRow
@onready var message_input: LineEdit = %MessageInput
@onready var send_button: Button = %SendButton
@onready var toggle_button: Button = %ToggleButton

var _collapsed: bool = false
var _expanded_size: Vector2
var _collapsed_size: Vector2

func _ready() -> void:
	_expanded_size = size
	_collapsed_size = Vector2(size.x, 50)

	send_button.pressed.connect(_on_send_pressed)
	message_input.text_submitted.connect(_on_text_submitted)
	toggle_button.pressed.connect(_on_toggle_pressed)

	if is_instance_valid(ChatManager):
		ChatManager.message_received.connect(_on_message_received)
		ChatManager.system_message.connect(_on_system_message)

	# Load message history
	_load_message_history()

func _on_send_pressed() -> void:
	_send_current_message()

func _on_text_submitted(_text: String) -> void:
	_send_current_message()

func _send_current_message() -> void:
	var msg: String = message_input.text.strip_edges()
	if msg.is_empty():
		return

	if is_instance_valid(ChatManager):
		ChatManager.send_message(msg)

	message_input.clear()

func _on_message_received(sender_name: String, message: String, _sender_id: int) -> void:
	_add_message_to_list(sender_name, message, false)

func _on_system_message(message: String) -> void:
	_add_message_to_list("[SYSTEM]", message, true)

func _add_message_to_list(sender: String, message: String, is_system: bool) -> void:
	var msg_label := Label.new()
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.theme_override_font_sizes["font_size"] = 16

	if is_system:
		msg_label.text = message
		msg_label.theme_override_colors["font_color"] = Color(0.7, 0.7, 0.7, 1)
	else:
		msg_label.text = "[%s]: %s" % [sender, message]
		msg_label.theme_override_colors["font_color"] = Color(0.95, 0.95, 0.95, 1)

	message_list.add_child(msg_label)

	# Limit message count
	while message_list.get_child_count() > 50:
		var first_child: Node = message_list.get_child(0)
		first_child.queue_free()

	# Auto-scroll to bottom
	await get_tree().process_frame
	message_scroll.scroll_vertical = int(message_scroll.get_v_scroll_bar().max_value)

func _load_message_history() -> void:
	if not is_instance_valid(ChatManager):
		return

	for msg_data: Dictionary in ChatManager.get_message_history():
		var sender: String = msg_data.get("sender", "")
		var message: String = msg_data.get("message", "")
		var is_system: bool = sender == "[SYSTEM]"
		_add_message_to_list(sender, message, is_system)

func _on_toggle_pressed() -> void:
	_collapsed = not _collapsed
	if _collapsed:
		toggle_button.text = "+"
		message_scroll.visible = false
		input_row.visible = false
		custom_minimum_size = _collapsed_size
	else:
		toggle_button.text = "−"
		message_scroll.visible = true
		input_row.visible = true
		custom_minimum_size = _expanded_size
