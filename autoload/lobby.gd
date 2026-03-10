## Lobby — Autoload singleton managing player registry, ready-up, game selection,
## session leaderboard, and loading coordination for BattleZone Party.
##
## Depends on the [ConnectionManager] autoload for all networking primitives.
## Players are registered in a dictionary keyed by their unique multiplayer peer id.
## The host is authoritative over game selection and the start sequence.
##
## Typical flow:
##   1. Player sets local info (name, character, colour) before connecting.
##   2. On connection, peers exchange registration RPCs.
##   3. Host selects a mini-game; players toggle ready.
##   4. Host calls [method start_game] — if all are ready the game loads on every peer.
##   5. Each peer calls [method player_loaded] once its scene is ready.
##   6. When every peer has loaded, [signal game_loading_complete] fires.
##   7. During gameplay, [method add_score] updates the session leaderboard.
##   8. If the host disconnects, the session ends cleanly via [signal session_ended].
extends Node

# =============================================================================
# region — Signals
# =============================================================================

## Emitted when a new player has been fully registered.
## [param peer_id] Unique multiplayer id of the new player.
## [param info] Player info dictionary (see [member players]).
signal player_joined(peer_id: int, info: Dictionary)

## Emitted when a player leaves the session.
## [param peer_id] Unique multiplayer id of the departing player.
signal player_left(peer_id: int)

## Emitted when any field of a player's info changes.
## [param peer_id] Unique multiplayer id of the updated player.
## [param info] The full updated info dictionary.
signal player_updated(peer_id: int, info: Dictionary)

## Emitted when every registered player has set their ready flag to [code]true[/code].
signal all_players_ready()

## Emitted on all peers when the host initiates the game start sequence.
## [param game_id] Identifier of the selected mini-game.
signal game_starting(game_id: String)

## Emitted on all peers once every connected peer has reported that it finished loading.
signal game_loading_complete()

## Emitted when the session must end (e.g. host disconnected).
## [param reason] Human-readable explanation.
signal session_ended(reason: String)

## Emitted whenever the leaderboard changes (score added, player removed, reset).
## [param leaderboard] Sorted array of dictionaries — see [method get_leaderboard].
signal leaderboard_updated(leaderboard: Array)

# endregion

# =============================================================================
# region — Constants
# =============================================================================

## Default player info template.  Every new entry in [member players] starts as a copy.
const _DEFAULT_PLAYER_INFO: Dictionary = {
	"name": "Player",
	"character_id": 0,
	"color": Color.WHITE,
	"ready": false,
	"score": 0,
	"wins": 0,
}

# endregion

# =============================================================================
# region — State
# =============================================================================

## Master player registry.  Keys are [int] peer ids, values are info dictionaries
## with the following shape:
## [codeblock]
## {
##     name:         String,
##     character_id: int,
##     color:        Color,
##     ready:        bool,
##     score:        int,
##     wins:         int,
## }
## [/codeblock]
var players: Dictionary = {}

## The mini-game id chosen by the host (empty string ≈ none selected).
var selected_game_id: String = ""

## Scene resource path that was last sent via [method load_game].
var current_game_scene: String = ""

## Set of peer ids that have reported their scene load complete.
var _peers_loaded: Dictionary = {}

## Local player info — set before connecting so it can be sent on registration.
var _local_name: String = "Player"
var _local_character_id: int = 0
var _local_color: Color = Color.WHITE

# endregion

# =============================================================================
# region — Lifecycle
# =============================================================================

func _ready() -> void:
	_connect_connection_manager_signals()


## Wire up to [ConnectionManager] signals.  Separated for clarity and testability.
func _connect_connection_manager_signals() -> void:
	if not is_instance_valid(ConnectionManager):
		push_error("Lobby: ConnectionManager autoload not found.")
		return

	ConnectionManager.peer_joined.connect(_on_peer_joined)
	ConnectionManager.peer_left.connect(_on_peer_left)
	ConnectionManager.connected_to_host.connect(_on_connected_to_host)
	ConnectionManager.disconnected_from_host.connect(_on_disconnected_from_host)
	ConnectionManager.connection_failed.connect(_on_connection_failed)

# endregion

# =============================================================================
# region — Local Player Setters
# =============================================================================

## Set the display name used for this device's player.
## Should be called *before* connecting so the name is included in registration.
func set_local_player_name(p_name: String) -> void:
	_local_name = p_name if p_name.strip_edges() != "" else "Player"
	_update_local_player_field("name", _local_name)


## Set the character / skin id for this device's player.
func set_local_character(character_id: int) -> void:
	_local_character_id = character_id
	_update_local_player_field("character_id", _local_character_id)


## Set the colour tint for this device's player.
func set_local_color(color: Color) -> void:
	_local_color = color
	_update_local_player_field("color", _local_color)


## Internal helper — if already registered, push the field change to all peers.
func _update_local_player_field(field: String, value: Variant) -> void:
	var my_id: int = _get_my_peer_id()
	if my_id == 0:
		return  # Not connected yet; value is stored locally and sent on registration.
	if not players.has(my_id):
		return

	players[my_id][field] = value
	player_updated.emit(my_id, players[my_id])
	_rpc_broadcast_player_update.rpc(my_id, field, _variant_to_transportable(value))

# endregion

# =============================================================================
# region — Ready-Up
# =============================================================================

## Toggle the ready flag for the local player and broadcast the change.
func toggle_ready() -> void:
	var my_id: int = _get_my_peer_id()
	if my_id == 0 or not players.has(my_id):
		push_warning("Lobby.toggle_ready(): local player not registered yet.")
		return

	var new_ready: bool = not players[my_id]["ready"]
	players[my_id]["ready"] = new_ready
	player_updated.emit(my_id, players[my_id])
	_rpc_broadcast_player_update.rpc(my_id, "ready", new_ready)
	_check_all_ready()

# endregion

# =============================================================================
# region — Game Selection & Start (Host Only)
# =============================================================================

## Host selects a mini-game.  The choice is replicated to all clients.
func select_game(game_id: String) -> void:
	if not _is_host():
		push_warning("Lobby.select_game(): only the host may select a game.")
		return

	selected_game_id = game_id
	_rpc_set_selected_game.rpc(game_id)


## Host initiates the game start sequence.
## All players must be ready, and a game must be selected.
func start_game() -> void:
	if not _is_host():
		push_warning("Lobby.start_game(): only the host may start the game.")
		return

	if selected_game_id.is_empty():
		push_warning("Lobby.start_game(): no game selected.")
		return

	if not _are_all_players_ready():
		push_warning("Lobby.start_game(): not all players are ready.")
		return

	_rpc_notify_game_starting.rpc(selected_game_id)


## Host tells every peer to load a specific game scene.
## Resets the loaded-peers tracker so [signal game_loading_complete] fires
## only once *every* current peer has called [method player_loaded].
func load_game(game_scene_path: String) -> void:
	if not _is_host():
		push_warning("Lobby.load_game(): only the host may initiate loading.")
		return

	current_game_scene = game_scene_path
	_peers_loaded.clear()
	_rpc_load_game_scene.rpc(game_scene_path)

# endregion

# =============================================================================
# region — Loading Coordination
# =============================================================================

## Each peer calls this once it has finished loading / instantiating the game scene.
## When every connected peer has reported in, [signal game_loading_complete] fires.
func player_loaded() -> void:
	var my_id: int = _get_my_peer_id()
	if my_id == 0:
		return
	_rpc_report_player_loaded.rpc_id(1, my_id)  # Report to host.

	# If we *are* the host, handle locally too.
	if _is_host():
		_handle_player_loaded(my_id)

# endregion

# =============================================================================
# region — Scoring & Leaderboard
# =============================================================================

## Add [param points] to the given peer's session score.  Typically called by the
## host or the authoritative game mode script.
func add_score(peer_id: int, points: int) -> void:
	if not players.has(peer_id):
		push_warning("Lobby.add_score(): peer %d not found." % peer_id)
		return

	players[peer_id]["score"] = (players[peer_id]["score"] as int) + points
	player_updated.emit(peer_id, players[peer_id])
	leaderboard_updated.emit(get_leaderboard())


## Record a round win for the given peer.
func add_win(peer_id: int) -> void:
	if not players.has(peer_id):
		push_warning("Lobby.add_win(): peer %d not found." % peer_id)
		return

	players[peer_id]["wins"] = (players[peer_id]["wins"] as int) + 1
	player_updated.emit(peer_id, players[peer_id])
	leaderboard_updated.emit(get_leaderboard())


## Return a sorted leaderboard array.  Each element:
## [codeblock]
## { peer_id: int, name: String, score: int, wins: int }
## [/codeblock]
## Sorted descending by score, then by wins as tie-breaker.
func get_leaderboard() -> Array:
	var board: Array = []
	for peer_id: int in players:
		var info: Dictionary = players[peer_id]
		board.append({
			"peer_id": peer_id,
			"name": info.get("name", "Player"),
			"score": info.get("score", 0),
			"wins": info.get("wins", 0),
		})

	board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["wins"] > b["wins"]
	)
	return board

# endregion

# =============================================================================
# region — Session Management
# =============================================================================

## Full reset — clears players, scores, selection, and loaded tracking.
## Call when returning to the main menu or starting a brand-new session.
func reset_session() -> void:
	players.clear()
	selected_game_id = ""
	current_game_scene = ""
	_peers_loaded.clear()
	leaderboard_updated.emit(get_leaderboard())


## Soft reset between rounds — clears ready flags but keeps scores / wins.
func reset_ready_states() -> void:
	for peer_id: int in players:
		players[peer_id]["ready"] = false
		player_updated.emit(peer_id, players[peer_id])

# endregion

# =============================================================================
# region — ConnectionManager Signal Handlers
# =============================================================================

func _on_peer_joined(peer_id: int) -> void:
	# A new peer connected.  If we are the host we send them our local info
	# immediately.  Clients also send theirs — registration is a two-way exchange.
	_send_registration_to(peer_id)


func _on_peer_left(peer_id: int) -> void:
	if not players.has(peer_id):
		return

	players.erase(peer_id)
	_peers_loaded.erase(peer_id)
	player_left.emit(peer_id)
	leaderboard_updated.emit(get_leaderboard())

	# Re-evaluate readiness — someone leaving may make "all ready" true or false.
	_check_all_ready()


func _on_connected_to_host() -> void:
	# Client is now connected.  Register self with the host (the host's
	# _on_peer_joined already fires for us, but we also push our info).
	_register_local_player()


func _on_disconnected_from_host() -> void:
	session_ended.emit("Disconnected from host.")
	reset_session()


func _on_connection_failed() -> void:
	session_ended.emit("Connection failed.")
	reset_session()

# endregion

# =============================================================================
# region — Registration Helpers
# =============================================================================

## Register the local player in the [member players] dictionary and broadcast
## info to all other peers.
func _register_local_player() -> void:
	var my_id: int = _get_my_peer_id()
	if my_id == 0:
		return

	var info: Dictionary = _make_local_info()
	players[my_id] = info
	player_joined.emit(my_id, info)
	leaderboard_updated.emit(get_leaderboard())


## Send local player info to a specific peer via RPC.
func _send_registration_to(peer_id: int) -> void:
	var my_id: int = _get_my_peer_id()
	if my_id == 0:
		return

	# Make sure we are registered locally first.
	if not players.has(my_id):
		_register_local_player()

	var info: Dictionary = _make_local_info()
	# Send as serialisable types (Color → array).
	var transport_info: Dictionary = _info_to_transport(info)
	_rpc_receive_registration.rpc_id(peer_id, my_id, transport_info)


## Build a fresh info dictionary from the current local settings.
func _make_local_info() -> Dictionary:
	return {
		"name": _local_name,
		"character_id": _local_character_id,
		"color": _local_color,
		"ready": false,
		"score": 0,
		"wins": 0,
	}

# endregion

# =============================================================================
# region — RPCs — Registration
# =============================================================================

## Receive another peer's registration payload.
@rpc("any_peer", "reliable")
func _rpc_receive_registration(peer_id: int, transport_info: Dictionary) -> void:
	var info: Dictionary = _transport_to_info(transport_info)
	# Preserve existing score/wins if the player is re-registering (e.g. reconnect).
	if players.has(peer_id):
		info["score"] = players[peer_id].get("score", 0)
		info["wins"] = players[peer_id].get("wins", 0)

	players[peer_id] = info
	player_joined.emit(peer_id, info)
	leaderboard_updated.emit(get_leaderboard())

	# If we are the host, relay this new player's info to everyone else so all
	# clients have a full registry.
	if _is_host():
		for other_id: int in players:
			if other_id == peer_id or other_id == _get_my_peer_id():
				continue
			var relay_transport: Dictionary = _info_to_transport(players[other_id])
			_rpc_receive_registration.rpc_id(peer_id, other_id, relay_transport)

# endregion

# =============================================================================
# region — RPCs — Player Updates
# =============================================================================

## Broadcast a single-field update so every peer stays in sync.
@rpc("any_peer", "reliable")
func _rpc_broadcast_player_update(peer_id: int, field: String, value: Variant) -> void:
	if not players.has(peer_id):
		push_warning("Lobby._rpc_broadcast_player_update(): unknown peer %d." % peer_id)
		return

	# Convert colour arrays back to Color on the receiving end.
	if field == "color" and value is Array:
		var arr: Array = value
		if arr.size() == 4:
			value = Color(arr[0], arr[1], arr[2], arr[3])

	players[peer_id][field] = value
	player_updated.emit(peer_id, players[peer_id])

	if field == "ready":
		_check_all_ready()

# endregion

# =============================================================================
# region — RPCs — Game Selection & Start
# =============================================================================

## Host replicates the selected game id to all clients.
@rpc("authority", "reliable")
func _rpc_set_selected_game(game_id: String) -> void:
	selected_game_id = game_id


## Host notifies all peers that the game is starting.
@rpc("authority", "reliable")
func _rpc_notify_game_starting(game_id: String) -> void:
	selected_game_id = game_id
	game_starting.emit(game_id)

# endregion

# =============================================================================
# region — RPCs — Loading Coordination
# =============================================================================

## Host tells all peers to load a given scene.
@rpc("authority", "reliable")
func _rpc_load_game_scene(game_scene_path: String) -> void:
	current_game_scene = game_scene_path
	_peers_loaded.clear()
	# The receiver should now begin loading the scene.  The game's scene manager
	# or UI layer is expected to listen for [signal game_starting] and then
	# begin a scene transition using [member current_game_scene].


## A peer reports to the host that it has finished loading.
@rpc("any_peer", "reliable")
func _rpc_report_player_loaded(peer_id: int) -> void:
	if not _is_host():
		return
	_handle_player_loaded(peer_id)


## Host-side: mark a peer as loaded and check if everyone is done.
func _handle_player_loaded(peer_id: int) -> void:
	_peers_loaded[peer_id] = true

	# Check against all currently registered players.
	var all_loaded: bool = true
	for pid: int in players:
		if not _peers_loaded.has(pid):
			all_loaded = false
			break

	if all_loaded:
		_rpc_all_peers_loaded.rpc()
		game_loading_complete.emit()


## Host tells every peer that loading is complete across the board.
@rpc("authority", "reliable")
func _rpc_all_peers_loaded() -> void:
	game_loading_complete.emit()

# endregion

# =============================================================================
# region — Utility Helpers
# =============================================================================

## Return this device's multiplayer peer id, or 0 if offline.
func _get_my_peer_id() -> int:
	if multiplayer == null:
		return 0
	if multiplayer.multiplayer_peer == null:
		return 0
	if not multiplayer.has_multiplayer_peer():
		return 0
	return multiplayer.get_unique_id()


## Convenience check for host authority.
func _is_host() -> bool:
	return multiplayer != null and multiplayer.is_server()


## Check whether every registered player has [code]ready == true[/code] and
## emit [signal all_players_ready] if so.  Requires at least one player.
func _check_all_ready() -> void:
	if players.is_empty():
		return
	if _are_all_players_ready():
		all_players_ready.emit()


## Pure query — returns [code]true[/code] when every player's ready flag is set.
func _are_all_players_ready() -> bool:
	for peer_id: int in players:
		if not players[peer_id].get("ready", false):
			return false
	return true

# endregion

# =============================================================================
# region — Serialisation Helpers
# =============================================================================
# Color is not trivially serialised over RPC, so we convert to/from arrays.

## Convert a player info dictionary to a transport-safe version (Color → Array).
func _info_to_transport(info: Dictionary) -> Dictionary:
	var t: Dictionary = info.duplicate()
	if t.has("color") and t["color"] is Color:
		var c: Color = t["color"]
		t["color"] = [c.r, c.g, c.b, c.a]
	return t


## Convert a transport dictionary back to a proper info dictionary (Array → Color).
func _transport_to_info(transport: Dictionary) -> Dictionary:
	var info: Dictionary = transport.duplicate()
	if info.has("color") and info["color"] is Array:
		var arr: Array = info["color"]
		if arr.size() == 4:
			info["color"] = Color(arr[0], arr[1], arr[2], arr[3])
	return info


## Convert a single Variant to transport form (used by field-level updates).
func _variant_to_transportable(value: Variant) -> Variant:
	if value is Color:
		var c: Color = value
		return [c.r, c.g, c.b, c.a]
	return value

# endregion
