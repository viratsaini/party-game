## ChatManager — Autoload singleton for in-game chat system
extends Node

signal message_received(sender_name: String, message: String, sender_id: int)
signal system_message(message: String)

const MAX_MESSAGE_HISTORY: int = 100

var message_history: Array[Dictionary] = []

func _ready() -> void:
	if is_instance_valid(ConnectionManager):
		ConnectionManager.peer_joined.connect(_on_peer_joined)
		ConnectionManager.peer_left.connect(_on_peer_left)

func send_message(message: String) -> void:
	if message.strip_edges().is_empty():
		return

	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if my_id == 0:
		return

	var player_name: String = _get_player_name(my_id)
	_rpc_broadcast_message.rpc(player_name, message, my_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_broadcast_message(sender_name: String, message: String, sender_id: int) -> void:
	_add_message(sender_name, message, sender_id)
	message_received.emit(sender_name, message, sender_id)

func add_system_message(message: String) -> void:
	_add_message("[SYSTEM]", message, 0)
	system_message.emit(message)

func _add_message(sender: String, message: String, sender_id: int) -> void:
	var msg_data: Dictionary = {
		"sender": sender,
		"message": message,
		"sender_id": sender_id,
		"timestamp": Time.get_ticks_msec()
	}
	message_history.append(msg_data)

	# Keep history within limits
	if message_history.size() > MAX_MESSAGE_HISTORY:
		message_history.remove_at(0)

func get_message_history() -> Array[Dictionary]:
	return message_history.duplicate()

func clear_history() -> void:
	message_history.clear()

func _get_player_name(peer_id: int) -> String:
	if is_instance_valid(Lobby) and Lobby.players.has(peer_id):
		return Lobby.players[peer_id].get("name", "Player")
	return "Player"

func _on_peer_joined(peer_id: int) -> void:
	var player_name: String = _get_player_name(peer_id)
	add_system_message("%s joined the game" % player_name)

func _on_peer_left(peer_id: int) -> void:
	var player_name: String = _get_player_name(peer_id)
	add_system_message("%s left the game" % player_name)
