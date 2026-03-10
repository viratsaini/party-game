## ConnectionManager — Autoload singleton managing all networking for BattleZone Party.
##
## Handles P2P local multiplayer where one device acts as host (server-player)
## and others connect as clients over WiFi/LAN using ENetMultiplayerPeer.
##
## Features:
##   - LAN hosting and client connections on a configurable port
##   - Connection state machine: DISCONNECTED → CONNECTING → CONNECTED → IN_GAME
##   - UDP broadcast-based auto-discovery of LAN games
##   - Per-peer ping / network-quality monitoring
##   - Graceful disconnect and clean shutdown
##   - Host-migration signalling (handled externally by Lobby)
##
## Future expansion points:
##   - Bluetooth / Nearby Connections can be added by implementing an
##     alternative discovery + transport backend and swapping the peer provider.
extends Node

# =============================================================================
# region — Enums
# =============================================================================

## Possible states the connection manager can be in.
enum ConnectionState {
	DISCONNECTED,  ## No active network session.
	CONNECTING,    ## Client is attempting to reach the host.
	CONNECTED,     ## Link established; in lobby / pre-game.
	IN_GAME,       ## Game round is in progress.
}

## Role of this device in the current session.
enum NetworkRole {
	NONE,    ## Not participating.
	HOST,    ## Server-player (authoritative).
	CLIENT,  ## Connected to a host.
}

# endregion

# =============================================================================
# region — Signals
# =============================================================================

## Emitted on the client when it successfully connects to the host.
signal connected_to_host()

## Emitted when this device disconnects (intentional or not).
signal disconnected_from_host()

## Emitted on the client when the connection attempt fails.
signal connection_failed()

## Emitted on all peers when a new peer joins the session.
## [param peer_id] The unique multiplayer ID of the new peer.
signal peer_joined(peer_id: int)

## Emitted on all peers when a peer leaves the session.
## [param peer_id] The unique multiplayer ID of the departing peer.
signal peer_left(peer_id: int)

## Emitted whenever the connection state changes.
## [param old_state] Previous [enum ConnectionState].
## [param new_state] Current [enum ConnectionState].
signal state_changed(old_state: ConnectionState, new_state: ConnectionState)

## Emitted when the host disconnects unexpectedly and migration may be needed.
## The Lobby (or another system) should handle the actual migration logic.
## [param old_host_id] The peer id of the host that was lost.
signal host_migration_requested(old_host_id: int)

## Emitted when a LAN game is discovered via UDP broadcast.
## [param host_info] Dictionary with keys: ip, port, game_name, host_name, player_count, max_players.
signal lan_game_discovered(host_info: Dictionary)

## Emitted when the ping value for a peer is updated.
## [param peer_id] The peer whose ping changed.
## [param ping_ms] Round-trip time in milliseconds.
signal ping_updated(peer_id: int, ping_ms: int)

# endregion

# =============================================================================
# region — Constants
# =============================================================================

const GAME_NAME: String = "BattleZone Party"

## Protocol version — bump when wire-incompatible changes are made.
const PROTOCOL_VERSION: int = 1

## Special multicast / broadcast address for LAN discovery.
const BROADCAST_ADDRESS: String = "255.255.255.255"

## Magic header prepended to every discovery packet to avoid collisions.
const DISCOVERY_MAGIC: String = "BZPARTY"

# endregion

# =============================================================================
# region — Exports / Configuration
# =============================================================================

## Port used for the ENet game connection.
@export var game_port: int = 7070

## Port used for UDP LAN discovery broadcasts.
@export var discovery_port: int = 7071

## Maximum number of players allowed in a session (including the host).
@export var max_players: int = 8

## Interval (seconds) between outgoing LAN discovery broadcasts when hosting.
@export var broadcast_interval: float = 1.0

## Interval (seconds) between ping measurement requests.
@export var ping_interval: float = 2.0

## How long (seconds) a client waits before treating a connection attempt as failed.
@export var connection_timeout: float = 10.0

# endregion

# =============================================================================
# region — Runtime State
# =============================================================================

## Current connection state.
var state: ConnectionState = ConnectionState.DISCONNECTED:
	set(value):
		if state != value:
			var old: ConnectionState = state
			state = value
			state_changed.emit(old, value)

## Current role of this device.
var role: NetworkRole = NetworkRole.NONE

## Convenience — the unique peer id assigned to this device (0 when offline).
var my_peer_id: int = 0

## Convenience — name the host chose to advertise on LAN.
var host_name: String = ""

## Connected peer ids mapped to their latest ping in ms. Keys are [int], values [int].
var peer_pings: Dictionary = {}

## Connected peer ids mapped to metadata dictionaries (player name, etc.).
var peer_info: Dictionary = {}

# endregion

# =============================================================================
# region — Internals
# =============================================================================

var _enet_peer: ENetMultiplayerPeer = null

## UDP socket used for LAN discovery (broadcast on host, listen on client).
var _discovery_socket: PacketPeerUDP = null

## Timer driving periodic LAN broadcasts (host-side).
var _broadcast_timer: Timer = null

## Timer driving periodic ping requests.
var _ping_timer: Timer = null

## Timer for client connection timeout.
var _connection_timer: Timer = null

## Timestamps of outgoing ping requests keyed by peer id.
var _ping_pending: Dictionary = {}

## Whether we are currently listening for LAN broadcasts (client-side).
var _is_listening_for_broadcasts: bool = false

## Whether we are currently broadcasting (host-side).
var _is_broadcasting: bool = false

# endregion

# =============================================================================
# region — Lifecycle
# =============================================================================

func _ready() -> void:
	# Wire up Godot multiplayer signals.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Create reusable timers.
	_broadcast_timer = Timer.new()
	_broadcast_timer.wait_time = broadcast_interval
	_broadcast_timer.one_shot = false
	_broadcast_timer.timeout.connect(_on_broadcast_timeout)
	add_child(_broadcast_timer)

	_ping_timer = Timer.new()
	_ping_timer.wait_time = ping_interval
	_ping_timer.one_shot = false
	_ping_timer.timeout.connect(_on_ping_timeout)
	add_child(_ping_timer)

	_connection_timer = Timer.new()
	_connection_timer.wait_time = connection_timeout
	_connection_timer.one_shot = true
	_connection_timer.timeout.connect(_on_connection_timeout)
	add_child(_connection_timer)


func _process(_delta: float) -> void:
	if _is_listening_for_broadcasts and _discovery_socket != null:
		_poll_discovery_packets()

# endregion

# =============================================================================
# region — Public API — Hosting
# =============================================================================

## Create a server on this device making it the host-player.
## Returns [constant OK] on success or an [enum Error] code on failure.
func host_game(player_name: String = "Host") -> Error:
	if state != ConnectionState.DISCONNECTED:
		push_warning("ConnectionManager: Cannot host — already in state %s." % ConnectionState.keys()[state])
		return ERR_ALREADY_IN_USE

	host_name = player_name

	_enet_peer = ENetMultiplayerPeer.new()
	var err: Error = _enet_peer.create_server(game_port, max_players - 1) # max_players includes host
	if err != OK:
		push_error("ConnectionManager: Failed to create server on port %d — %s." % [game_port, error_string(err)])
		_enet_peer = null
		return err

	multiplayer.multiplayer_peer = _enet_peer
	role = NetworkRole.HOST
	my_peer_id = multiplayer.get_unique_id()
	state = ConnectionState.CONNECTED

	# Register host in peer info.
	peer_info[my_peer_id] = {"name": player_name}
	peer_pings[my_peer_id] = 0

	_start_ping_monitoring()
	print("ConnectionManager: Server started on port %d. Local IPs: %s" % [game_port, str(get_local_ip_addresses())])
	return OK


## Begin broadcasting this game on the LAN so clients can discover it.
func start_lan_broadcast() -> void:
	if role != NetworkRole.HOST:
		push_warning("ConnectionManager: Only the host can broadcast.")
		return

	stop_lan_broadcast()

	_discovery_socket = PacketPeerUDP.new()
	_discovery_socket.set_broadcast_enabled(true)
	var err: Error = _discovery_socket.set_dest_address(BROADCAST_ADDRESS, discovery_port)
	if err != OK:
		push_error("ConnectionManager: Failed to set broadcast destination — %s." % error_string(err))
		return

	_is_broadcasting = true
	_broadcast_timer.start()
	# Send one broadcast immediately.
	_send_broadcast_packet()
	print("ConnectionManager: LAN broadcast started on port %d." % discovery_port)


## Stop broadcasting this game on the LAN.
func stop_lan_broadcast() -> void:
	_is_broadcasting = false
	_broadcast_timer.stop()

	if _discovery_socket != null:
		_discovery_socket.close()
		_discovery_socket = null

# endregion

# =============================================================================
# region — Public API — Joining
# =============================================================================

## Attempt to connect to a host at the given IP address.
## Returns [constant OK] if the attempt was initiated.
func join_game(host_ip: String, player_name: String = "Player") -> Error:
	if state != ConnectionState.DISCONNECTED:
		push_warning("ConnectionManager: Cannot join — already in state %s." % ConnectionState.keys()[state])
		return ERR_ALREADY_IN_USE

	_enet_peer = ENetMultiplayerPeer.new()
	var err: Error = _enet_peer.create_client(host_ip, game_port)
	if err != OK:
		push_error("ConnectionManager: Failed to create client to %s:%d — %s." % [host_ip, game_port, error_string(err)])
		_enet_peer = null
		return err

	multiplayer.multiplayer_peer = _enet_peer
	role = NetworkRole.CLIENT
	host_name = player_name
	state = ConnectionState.CONNECTING

	_connection_timer.start()
	print("ConnectionManager: Connecting to %s:%d …" % [host_ip, game_port])
	return OK

# endregion

# =============================================================================
# region — Public API — Discovery (Client-Side Listening)
# =============================================================================

## Start listening for LAN broadcasts from hosts.
func start_lan_discovery() -> void:
	stop_lan_discovery()

	_discovery_socket = PacketPeerUDP.new()
	var err: Error = _discovery_socket.bind(discovery_port)
	if err != OK:
		push_error("ConnectionManager: Failed to bind discovery socket on port %d — %s." % [discovery_port, error_string(err)])
		return

	_is_listening_for_broadcasts = true
	print("ConnectionManager: Listening for LAN broadcasts on port %d." % discovery_port)


## Stop listening for LAN broadcasts.
func stop_lan_discovery() -> void:
	_is_listening_for_broadcasts = false

	if _discovery_socket != null:
		_discovery_socket.close()
		_discovery_socket = null

# endregion

# =============================================================================
# region — Public API — Session Control
# =============================================================================

## Transition to the IN_GAME state.  Should be called by the Lobby/GameManager
## when all players are ready and the round starts.
func set_in_game() -> void:
	if state == ConnectionState.CONNECTED:
		state = ConnectionState.IN_GAME


## Transition back to CONNECTED (lobby) from IN_GAME.
func set_in_lobby() -> void:
	if state == ConnectionState.IN_GAME:
		state = ConnectionState.CONNECTED


## Cleanly leave the current session and reset all networking state.
func disconnect_from_session() -> void:
	print("ConnectionManager: Disconnecting from session.")
	_cleanup()


## Full shutdown — call when returning to the main menu or quitting the app.
func shutdown() -> void:
	print("ConnectionManager: Shutting down all connections.")
	stop_lan_broadcast()
	stop_lan_discovery()
	_cleanup()

# endregion

# =============================================================================
# region — Public API — Network Quality
# =============================================================================

## Returns the latest known ping (ms) for the given peer, or -1 if unknown.
func get_ping(peer_id: int) -> int:
	return peer_pings.get(peer_id, -1) as int


## Returns a snapshot dictionary of all peer pings.  Keys are peer ids ([int]),
## values are round-trip times in milliseconds ([int]).
func get_all_pings() -> Dictionary:
	return peer_pings.duplicate()


## Returns the number of currently connected peers (including self when hosting).
func get_player_count() -> int:
	return peer_info.size()

# endregion

# =============================================================================
# region — Public API — Utilities
# =============================================================================

## Returns an array of local (non-loopback, IPv4) addresses suitable for
## display to the user (so other devices know where to connect).
func get_local_ip_addresses() -> PackedStringArray:
	var addresses: PackedStringArray = PackedStringArray()
	for ip: String in IP.get_local_addresses():
		# Filter out loopback and IPv6 for simplicity.
		if ip == "127.0.0.1" or ip == "::1":
			continue
		if ip.contains(":"):
			continue  # Skip IPv6
		addresses.append(ip)
	return addresses


## Returns the first usable local IP address, or "unknown" if none found.
func get_primary_local_ip() -> String:
	var addrs: PackedStringArray = get_local_ip_addresses()
	if addrs.size() > 0:
		return addrs[0]
	return "unknown"


## Whether this device is the session host.
func is_host() -> bool:
	return role == NetworkRole.HOST


## Whether this device is currently in an active session (connected or in-game).
func is_in_session() -> bool:
	return state == ConnectionState.CONNECTED or state == ConnectionState.IN_GAME

# endregion

# =============================================================================
# region — Ping System (RPCs)
# =============================================================================

## Host periodically pings every connected peer.
@rpc("authority", "call_remote", "unreliable")
func _rpc_ping(timestamp_ms: int) -> void:
	# Client receives ping — immediately pong back.
	_rpc_pong.rpc_id(1, timestamp_ms)


## Client responds with the original timestamp so the host can compute RTT.
@rpc("any_peer", "call_remote", "unreliable")
func _rpc_pong(original_timestamp_ms: int) -> void:
	if not is_host():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var now_ms: int = Time.get_ticks_msec()
	var rtt: int = now_ms - original_timestamp_ms
	peer_pings[sender_id] = rtt
	ping_updated.emit(sender_id, rtt)

	# Relay updated ping to the peer that sent it so they know their own ping.
	_rpc_receive_ping_value.rpc_id(sender_id, rtt)


## Let a client know its own ping value (sent from host).
@rpc("authority", "call_remote", "reliable")
func _rpc_receive_ping_value(ping_ms: int) -> void:
	peer_pings[multiplayer.get_unique_id()] = ping_ms
	ping_updated.emit(multiplayer.get_unique_id(), ping_ms)

# endregion

# =============================================================================
# region — Peer Info Exchange (RPCs)
# =============================================================================

## Called by a newly connected client to register its info with the host.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_peer_info(info: Dictionary) -> void:
	if not is_host():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	peer_info[sender_id] = info
	# Broadcast updated roster to everyone.
	_rpc_sync_peer_info.rpc(peer_info)


## Host pushes the full peer-info roster to all clients.
@rpc("authority", "call_local", "reliable")
func _rpc_sync_peer_info(info: Dictionary) -> void:
	peer_info = info

# endregion

# =============================================================================
# region — Internal — Multiplayer Signal Handlers
# =============================================================================

func _on_peer_connected(peer_id: int) -> void:
	print("ConnectionManager: Peer %d connected." % peer_id)
	peer_pings[peer_id] = 0
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("ConnectionManager: Peer %d disconnected." % peer_id)
	peer_pings.erase(peer_id)
	peer_info.erase(peer_id)
	peer_left.emit(peer_id)

	# If we are the host, push updated roster.
	if is_host() and multiplayer.multiplayer_peer != null:
		_rpc_sync_peer_info.rpc(peer_info)


func _on_connected_to_server() -> void:
	print("ConnectionManager: Successfully connected to host.")
	_connection_timer.stop()
	my_peer_id = multiplayer.get_unique_id()
	state = ConnectionState.CONNECTED

	# Send our info to the host.
	_rpc_register_peer_info.rpc_id(1, {"name": host_name})
	_start_ping_monitoring()
	connected_to_host.emit()


func _on_connection_failed() -> void:
	print("ConnectionManager: Connection to host failed.")
	_connection_timer.stop()
	_cleanup()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	print("ConnectionManager: Host disconnected unexpectedly.")
	var old_host_id: int = 1  # Server is always id 1 in Godot.
	_cleanup()
	disconnected_from_host.emit()
	host_migration_requested.emit(old_host_id)


func _on_connection_timeout() -> void:
	print("ConnectionManager: Connection attempt timed out.")
	_cleanup()
	connection_failed.emit()

# endregion

# =============================================================================
# region — Internal — Discovery
# =============================================================================

func _send_broadcast_packet() -> void:
	if _discovery_socket == null:
		return

	var data: Dictionary = {
		"magic": DISCOVERY_MAGIC,
		"version": PROTOCOL_VERSION,
		"game_name": GAME_NAME,
		"host_name": host_name,
		"port": game_port,
		"player_count": get_player_count(),
		"max_players": max_players,
	}

	var json_str: String = JSON.stringify(data)
	var packet: PackedByteArray = json_str.to_utf8_buffer()
	_discovery_socket.put_packet(packet)


func _poll_discovery_packets() -> void:
	while _discovery_socket != null and _discovery_socket.get_available_packet_count() > 0:
		var packet: PackedByteArray = _discovery_socket.get_packet()
		var sender_ip: String = _discovery_socket.get_packet_ip()
		var json_str: String = packet.get_string_from_utf8()

		var json: JSON = JSON.new()
		var parse_err: Error = json.parse(json_str)
		if parse_err != OK:
			continue

		var data: Variant = json.data
		if not data is Dictionary:
			continue

		var dict: Dictionary = data as Dictionary
		if dict.get("magic", "") != DISCOVERY_MAGIC:
			continue
		if dict.get("version", 0) != PROTOCOL_VERSION:
			continue

		var host_info: Dictionary = {
			"ip": sender_ip,
			"port": dict.get("port", game_port) as int,
			"game_name": dict.get("game_name", "") as String,
			"host_name": dict.get("host_name", "") as String,
			"player_count": dict.get("player_count", 0) as int,
			"max_players": dict.get("max_players", max_players) as int,
		}

		lan_game_discovered.emit(host_info)

# endregion

# =============================================================================
# region — Internal — Ping Monitoring
# =============================================================================

func _start_ping_monitoring() -> void:
	_ping_timer.start()


func _stop_ping_monitoring() -> void:
	_ping_timer.stop()
	_ping_pending.clear()


func _on_ping_timeout() -> void:
	if is_host():
		var now_ms: int = Time.get_ticks_msec()
		# Ping every connected peer (not ourselves).
		for peer_id: int in multiplayer.get_peers():
			_rpc_ping.rpc_id(peer_id, now_ms)

# endregion

# =============================================================================
# region — Internal — Broadcast Timer
# =============================================================================

func _on_broadcast_timeout() -> void:
	if _is_broadcasting:
		_send_broadcast_packet()

# endregion

# =============================================================================
# region — Internal — Cleanup
# =============================================================================

## Resets all networking state to a clean DISCONNECTED baseline.
func _cleanup() -> void:
	_stop_ping_monitoring()
	_connection_timer.stop()
	stop_lan_broadcast()
	stop_lan_discovery()

	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		# Close gracefully — ENet will send disconnect packets.
		multiplayer.multiplayer_peer.close()

	multiplayer.multiplayer_peer = null
	_enet_peer = null

	state = ConnectionState.DISCONNECTED
	role = NetworkRole.NONE
	my_peer_id = 0
	host_name = ""
	peer_pings.clear()
	peer_info.clear()
	_ping_pending.clear()

# endregion
