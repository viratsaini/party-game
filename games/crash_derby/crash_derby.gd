## Crash Derby — Bumper car arena combat mini-game.
##
## Server-authoritative match logic: push opponents off a shrinking circular
## platform.  Last player standing wins.  If the 2-minute timer expires the
## player closest to the arena centre wins.  The platform shrinks every 15 s
## by collapsing outer ring segments.  Power-ups spawn periodically on the
## playing surface: Super Boost, Magnet, Shield, and Size-Up.
class_name CrashDerby
extends Node3D


# region — Constants

const BUMPER_CAR_SCENE: PackedScene = preload("res://games/crash_derby/bumper_car.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud/game_hud.tscn")

const ROUND_DURATION: float = 120.0        ## 2 minutes
const SHRINK_INTERVAL: float = 15.0        ## Platform section collapses every 15 s
const KILL_ZONE_Y: float = -10.0           ## Below this Y the player is eliminated
const POWERUP_SPAWN_INTERVAL: float = 10.0 ## Seconds between power-up spawns
const POWERUP_COLLECT_RADIUS: float = 1.8  ## Distance to collect a power-up
const MAX_ACTIVE_POWERUPS: int = 3         ## Cap on power-ups on the field

## Power-up types.
enum PowerUpType { SUPER_BOOST = 0, MAGNET = 1, SHIELD = 2, SIZE_UP = 3 }

## Colours for each power-up pickup sphere.
const POWERUP_COLORS: Dictionary = {
	PowerUpType.SUPER_BOOST: Color(1.0, 0.5, 0.0),   # orange
	PowerUpType.MAGNET:      Color(0.6, 0.2, 0.9),   # purple
	PowerUpType.SHIELD:      Color(0.0, 0.8, 1.0),   # cyan
	PowerUpType.SIZE_UP:     Color(0.1, 0.9, 0.2),   # green
}

## Points awarded per finishing placement (index 0 = 1st place).
const PLACEMENT_SCORES: Array[int] = [10, 8, 6, 5, 4, 3, 2, 1]

# endregion


# region — State

## Peer-id → BumperCar node.
var car_nodes: Dictionary = {}

## Cached spawn positions from Marker3D children of SpawnPoints.
var spawn_positions: Array[Vector3] = []

## Ordered list of eliminated peer-ids (first entry = first eliminated = worst).
var elimination_order: Array[int] = []

## Shrink bookkeeping.
var _shrink_timer: float = 0.0
var _shrink_stage: int = 0  ## 0 = full, 1 = outer removed, 2 = middle removed

## Power-up system.
var _active_powerups: Array[Dictionary] = []  ## { "node": Node3D, "type": int, "id": int }
var _powerup_spawn_timer: float = 0.0
var _next_powerup_id: int = 0
var _powerup_positions: Array[Vector3] = []

## Per-peer stored inputs (server only).
var _player_inputs: Dictionary = {}  ## peer_id → { "move": Vector2, "brake": bool }

## Client-side local input cache.
var _local_move_input: Vector2 = Vector2.ZERO
var _local_braking: bool = false
var _local_boost_cooldown: float = 0.0

## HUD instance for the local player.
var _hud: CanvasLayer = null

## Local peer convenience cache.
var _local_peer_id: int = 0

## Prevents double-ending the round.
var _round_finished: bool = false

# endregion


# region — Node References

@onready var players_node: Node3D = $Players
@onready var spawn_points_node: Node3D = $SpawnPoints
@onready var powerup_points_node: Node3D = $PowerUpPoints
@onready var kill_zone: Area3D = $KillZone
@onready var outer_ring: StaticBody3D = $Arena/OuterRing
@onready var middle_ring: StaticBody3D = $Arena/MiddleRing
@onready var inner_circle: StaticBody3D = $Arena/InnerCircle
@onready var car_spawner: MultiplayerSpawner = $CarSpawner

# endregion


# region — Lifecycle

func _ready() -> void:
	_local_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	# Cache spawn positions.
	for child: Node in spawn_points_node.get_children():
		if child is Marker3D:
			spawn_positions.append((child as Marker3D).global_position)

	# Cache power-up spawn positions.
	for child: Node in powerup_points_node.get_children():
		if child is Marker3D:
			_powerup_positions.append((child as Marker3D).global_position)

	# Configure spawner.
	car_spawner.spawn_path = NodePath("../Players")
	car_spawner.add_spawnable_scene("res://games/crash_derby/bumper_car.tscn")

	# Connect GameManager signals.
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.countdown_tick.connect(_on_countdown_tick)
	GameManager.countdown_finished.connect(_on_countdown_finished)
	GameManager.game_timer_updated.connect(_on_game_timer_updated)
	GameManager.round_ended.connect(_on_round_ended)

	# Connect kill zone.
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_body_entered)

	# Spawn bumper cars.
	_spawn_cars()

	# Instantiate HUD.
	_setup_hud()

	# Server kicks off the countdown.
	if _is_server():
		GameManager.start_countdown(3)

	AudioManager.play_music("crash_derby")


func _physics_process(delta: float) -> void:
	# Local boost cooldown for HUD feedback (all peers).
	if _local_boost_cooldown > 0.0:
		_local_boost_cooldown = maxf(_local_boost_cooldown - delta, 0.0)

	# All clients: forward current input to the server each physics frame.
	if GameManager.current_state == GameManager.GameState.PLAYING and not _is_local_eliminated():
		if _is_server():
			# Host player — store input directly (no RPC to self).
			_player_inputs[_local_peer_id] = {"move": _local_move_input, "brake": _local_braking}
		else:
			_request_input.rpc_id(1, _local_move_input, _local_braking)

	# ── Server-only logic below ──────────────────────────────────────────
	if not _is_server():
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Apply stored inputs to each bumper car.
	for peer_id: int in _player_inputs:
		var car: BumperCar = car_nodes.get(peer_id) as BumperCar
		if car and not car.is_eliminated:
			var input_data: Dictionary = _player_inputs[peer_id]
			car.set_input(
				input_data.get("move", Vector2.ZERO) as Vector2,
				input_data.get("brake", false) as bool,
			)

	# Platform shrink timer.
	_shrink_timer += delta
	if _shrink_timer >= SHRINK_INTERVAL:
		_shrink_timer = 0.0
		_advance_shrink()

	# Power-up spawning.
	_powerup_spawn_timer += delta
	if _powerup_spawn_timer >= POWERUP_SPAWN_INTERVAL:
		_powerup_spawn_timer = 0.0
		_try_spawn_powerup()

	# Check power-up collection.
	_check_powerup_collection()

	# Check for a winner (last standing).
	_check_winner()


func _exit_tree() -> void:
	GameManager.state_changed.disconnect(_on_state_changed)
	GameManager.countdown_tick.disconnect(_on_countdown_tick)
	GameManager.countdown_finished.disconnect(_on_countdown_finished)
	GameManager.game_timer_updated.disconnect(_on_game_timer_updated)
	GameManager.round_ended.disconnect(_on_round_ended)

	if is_instance_valid(_hud):
		_hud.queue_free()

# endregion


# region — Car Spawning

func _spawn_cars() -> void:
	var idx: int = 0
	for peer_id: int in Lobby.players:
		var info: Dictionary = Lobby.players[peer_id]
		var car: BumperCar = BUMPER_CAR_SCENE.instantiate() as BumperCar
		car.name = str(peer_id)

		# Place at spawn point (cycle if more players than points).
		var spawn_pos: Vector3 = spawn_positions[idx % spawn_positions.size()]

		# Face toward the arena centre.
		var dir: Vector3 = -spawn_pos
		dir.y = 0.0
		var facing: float = atan2(dir.x, dir.z)

		car.setup(
			peer_id,
			info.get("name", "Player") as String,
			info.get("color", Color.WHITE) as Color,
			spawn_pos,
			facing,
		)

		players_node.add_child(car, true)
		car_nodes[peer_id] = car
		_player_inputs[peer_id] = {"move": Vector2.ZERO, "brake": false}

		idx += 1

# endregion


# region — HUD

func _setup_hud() -> void:
	_hud = HUD_SCENE.instantiate() as CanvasLayer
	add_child(_hud)

	# Action buttons: BOOST (one-shot) and BRAKE (held).
	var buttons: Array[Dictionary] = [
		{
			"text": "BOOST",
			"color": Color(1.0, 0.5, 0.1, 0.85),
			"callback": Callable(self, "_on_boost_pressed"),
		},
		{
			"text": "BRAKE",
			"color": Color(0.8, 0.2, 0.2, 0.85),
			"callback": Callable(self, "_on_brake_pressed"),
		},
	]
	_hud.set_action_buttons(buttons)

	# Wire up brake release for held-button behaviour.
	if _hud._action_button_nodes.size() > 1:
		var brake_btn: Control = _hud._action_button_nodes[1]
		if brake_btn.has_signal("button_released"):
			brake_btn.button_released.connect(_on_brake_released)

	# Connect joystick.
	_hud.connect_joystick(Callable(self, "_on_joystick_input"))

	# Initial display values.
	_hud.set_timer(ROUND_DURATION)
	_hud.set_score(0)

# endregion


# region — Input Callbacks

func _on_joystick_input(value: Vector2) -> void:
	_local_move_input = value


func _on_boost_pressed() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if _is_local_eliminated():
		return
	if _local_boost_cooldown > 0.0:
		return

	_local_boost_cooldown = BumperCar.BOOST_COOLDOWN
	_request_boost.rpc_id(1)


func _on_brake_pressed() -> void:
	_local_braking = true


func _on_brake_released() -> void:
	_local_braking = false

# endregion


# region — Server RPCs — Input

## Unreliable per-frame input from a remote client.
@rpc("any_peer", "unreliable")
func _request_input(move: Vector2, braking: bool) -> void:
	if not _is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	if not car_nodes.has(sender_id):
		return
	_player_inputs[sender_id] = {"move": move, "brake": braking}


## Client requests a boost.  Server validates cooldown and applies the impulse.
@rpc("any_peer", "reliable")
func _request_boost() -> void:
	if not _is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var car: BumperCar = car_nodes.get(sender_id) as BumperCar
	if car and not car.is_eliminated:
		car.apply_boost()

# endregion


# region — Platform Shrinking

func _advance_shrink() -> void:
	if _shrink_stage >= 2:
		return  # Already at minimum size.

	match _shrink_stage:
		0:
			_shrink_stage = 1
			_rpc_collapse_ring.rpc(0)
			_rpc_show_event.rpc("Arena shrinking!", Color.ORANGE_RED)
		1:
			_shrink_stage = 2
			_rpc_collapse_ring.rpc(1)
			_rpc_show_event.rpc("Final ring! Hold on!", Color.RED)


## Visual + physics collapse of a platform ring on all peers.
@rpc("authority", "call_local", "reliable")
func _rpc_collapse_ring(ring_index: int) -> void:
	var ring: StaticBody3D = null
	match ring_index:
		0: ring = outer_ring
		1: ring = middle_ring
	if not ring or not is_instance_valid(ring):
		return

	# Disable collision immediately so players fall through.
	for child: Node in ring.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)

	# Animate the ring mesh falling away, then free the node.
	var tween: Tween = create_tween()
	tween.tween_property(ring, "position:y", -20.0, 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(ring.queue_free)

	AudioManager.play_sfx("collapse")

# endregion


# region — Kill Zone / Elimination

func _on_kill_zone_body_entered(body: Node) -> void:
	if not _is_server() or _round_finished:
		return
	if not body is BumperCar:
		return

	var car: BumperCar = body as BumperCar
	if car.is_eliminated:
		return
	_eliminate_player(car.peer_id)


func _eliminate_player(peer_id: int) -> void:
	var car: BumperCar = car_nodes.get(peer_id) as BumperCar
	if not car or car.is_eliminated:
		return

	# Server eliminates locally first so winner checks see updated state.
	car.eliminate()
	elimination_order.append(peer_id)

	var alive_count: int = _count_alive()
	var pname: String = Lobby.players.get(peer_id, {}).get("name", "Player") as String
	_rpc_show_event.rpc("%s eliminated! %d remaining" % [pname, alive_count], Color.RED)
	_rpc_eliminate.rpc(peer_id)

	# Immediate winner check.
	_check_winner()


## Replicate elimination to all peers (including server for spectator logic).
@rpc("authority", "call_local", "reliable")
func _rpc_eliminate(peer_id: int) -> void:
	var car: BumperCar = car_nodes.get(peer_id) as BumperCar
	if car and not car.is_eliminated:
		car.eliminate()

	# If the local player was eliminated, switch to spectator.
	if peer_id == _local_peer_id:
		_switch_to_spectator()
		if is_instance_valid(_hud):
			_hud.show_message("Eliminated! Spectating...", 3.0)

# endregion


# region — Winner / Round End

func _check_winner() -> void:
	if _round_finished:
		return

	# Need at least 2 players for the "last standing" rule to apply.
	if car_nodes.size() <= 1:
		return

	var alive_count: int = _count_alive()

	if alive_count <= 1:
		if alive_count == 1:
			var winner_id: int = _get_last_alive_peer_id()
			var winner_name: String = Lobby.players.get(winner_id, {}).get("name", "Player") as String
			_rpc_show_event.rpc("%s wins!" % winner_name, Color.GOLD)
		_end_round()


func _end_round() -> void:
	if not _is_server() or _round_finished:
		return
	_round_finished = true

	var results: Array = []

	# Rank alive players by distance to centre (closest = best).
	var alive: Array[Dictionary] = []
	for peer_id: int in car_nodes:
		var car: BumperCar = car_nodes[peer_id] as BumperCar
		if car and not car.is_eliminated:
			alive.append({"peer_id": peer_id, "distance": car.get_distance_to_center()})

	alive.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["distance"] as float) < (b["distance"] as float)
	)

	# Alive players take the top placements.
	for entry: Dictionary in alive:
		results.append({
			"peer_id": entry["peer_id"] as int,
			"score": 0,
			"placement": 0,
		})

	# Eliminated players in reverse order (last eliminated = best among them).
	for i: int in range(elimination_order.size() - 1, -1, -1):
		results.append({
			"peer_id": elimination_order[i],
			"score": 0,
			"placement": 0,
		})

	# Assign placements and award scores.
	for i: int in results.size():
		results[i]["placement"] = i + 1
		if i < PLACEMENT_SCORES.size():
			results[i]["score"] = PLACEMENT_SCORES[i]
			Lobby.add_score(results[i]["peer_id"] as int, PLACEMENT_SCORES[i] as int)

	GameManager.end_round(results)

# endregion


# region — Spectator

func _switch_to_spectator() -> void:
	for peer_id: int in car_nodes:
		var car: BumperCar = car_nodes[peer_id] as BumperCar
		if car and not car.is_eliminated and peer_id != _local_peer_id:
			car.activate_camera()
			return

# endregion


# region — Power-Up System

func _try_spawn_powerup() -> void:
	if _powerup_positions.is_empty():
		return
	if _active_powerups.size() >= MAX_ACTIVE_POWERUPS:
		return

	var pos: Vector3 = _powerup_positions[randi() % _powerup_positions.size()]
	pos.y = 1.0  # Float above the platform.
	var type: int = randi() % 4
	var id: int = _next_powerup_id
	_next_powerup_id += 1

	_rpc_spawn_powerup.rpc(pos, type, id)


## Create a glowing pickup sphere on all peers.
@rpc("authority", "call_local", "reliable")
func _rpc_spawn_powerup(pos: Vector3, type: int, powerup_id: int) -> void:
	var node: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = POWERUP_COLORS.get(type, Color.WHITE) as Color
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.5
	sphere.material = mat
	node.mesh = sphere
	node.position = pos
	node.name = "PowerUp_%d" % powerup_id
	add_child(node)

	# Server tracks active power-ups for collection logic.
	if _is_server():
		_active_powerups.append({"node": node, "type": type, "id": powerup_id})


func _check_powerup_collection() -> void:
	for powerup: Dictionary in _active_powerups.duplicate():
		var p_node: MeshInstance3D = powerup["node"] as MeshInstance3D
		if not is_instance_valid(p_node):
			_active_powerups.erase(powerup)
			continue

		for peer_id: int in car_nodes:
			var car: BumperCar = car_nodes[peer_id] as BumperCar
			if not car or car.is_eliminated:
				continue
			if car.global_position.distance_to(p_node.global_position) < POWERUP_COLLECT_RADIUS:
				_apply_powerup(peer_id, powerup["type"] as int)
				_rpc_remove_powerup.rpc(powerup["id"] as int)
				_active_powerups.erase(powerup)
				break


func _apply_powerup(peer_id: int, type: int) -> void:
	var car: BumperCar = car_nodes.get(peer_id) as BumperCar
	if not car:
		return

	match type:
		PowerUpType.SUPER_BOOST:
			car.activate_super_boost()
		PowerUpType.MAGNET:
			car.activate_magnet()
		PowerUpType.SHIELD:
			car.activate_shield()
		PowerUpType.SIZE_UP:
			car.activate_size_up()

	var pname: String = Lobby.players.get(peer_id, {}).get("name", "Player") as String
	var type_name: String = _get_powerup_name(type)
	_rpc_show_event.rpc("%s got %s!" % [pname, type_name], POWERUP_COLORS.get(type, Color.WHITE) as Color)


## Remove a collected power-up visual from all peers.
@rpc("authority", "call_local", "reliable")
func _rpc_remove_powerup(powerup_id: int) -> void:
	var node: Node = get_node_or_null("PowerUp_%d" % powerup_id)
	if node:
		node.queue_free()

# endregion


# region — GameManager Signal Handlers

func _on_state_changed(_old_state: int, new_state: int) -> void:
	match new_state:
		GameManager.GameState.PLAYING:
			if _is_server():
				GameManager.start_game_timer(ROUND_DURATION)
		GameManager.GameState.ROUND_END:
			pass
		GameManager.GameState.RESULTS:
			_show_results()


func _on_countdown_tick(seconds_left: int) -> void:
	if is_instance_valid(_hud):
		_hud.show_countdown(seconds_left)


func _on_countdown_finished() -> void:
	if is_instance_valid(_hud):
		_hud.show_countdown(0)  # "GO!"


func _on_game_timer_updated(time_remaining: float) -> void:
	if is_instance_valid(_hud):
		_hud.set_timer(time_remaining)

	# Server: time's up — end the round.
	if _is_server() and time_remaining <= 0.0:
		_end_round()


func _on_round_ended(_results: Array) -> void:
	if is_instance_valid(_hud):
		_hud.show_message("Round Over!", 3.0)


func _show_results() -> void:
	if is_instance_valid(_hud):
		_hud.show_message("Match Complete!", 3.0)

# endregion


# region — Client RPCs (Notifications)

@rpc("authority", "call_local", "reliable")
func _rpc_show_event(text: String, color: Color) -> void:
	if is_instance_valid(_hud):
		_hud.add_kill_feed_entry(text, color)

# endregion


# region — Helpers

func _get_local_car() -> BumperCar:
	return car_nodes.get(_local_peer_id) as BumperCar


func _is_local_eliminated() -> bool:
	var car: BumperCar = _get_local_car()
	return car == null or car.is_eliminated


func _count_alive() -> int:
	var count: int = 0
	for peer_id: int in car_nodes:
		var car: BumperCar = car_nodes[peer_id] as BumperCar
		if car and not car.is_eliminated:
			count += 1
	return count


func _get_last_alive_peer_id() -> int:
	for peer_id: int in car_nodes:
		var car: BumperCar = car_nodes[peer_id] as BumperCar
		if car and not car.is_eliminated:
			return peer_id
	return -1


func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()


func _get_powerup_name(type: int) -> String:
	match type:
		PowerUpType.SUPER_BOOST: return "Super Boost"
		PowerUpType.MAGNET: return "Magnet"
		PowerUpType.SHIELD: return "Shield"
		PowerUpType.SIZE_UP: return "Size-Up"
	return "Power-Up"

# endregion
