## Turbo Karts — Arcade kart racing mini-game for BattleZone Party.
##
## Server-authoritative race logic: 3-lap oval track race with a 3-minute time limit.
## Players collect power-ups (Boost, Shield, Missile) scattered around the track.
## First to complete 3 laps wins; if time expires, player with most laps/progress wins.
## Checkpoint validation and lap counting are handled exclusively on the server
## and replicated to all clients via reliable RPCs.
class_name TurboKarts
extends Node3D


# region — Constants

const KART_SCENE: PackedScene = preload("res://games/turbo_karts/kart_controller.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud/game_hud.tscn")

const TOTAL_LAPS: int = 3
const ROUND_DURATION: float = 180.0       ## 3 minutes
const POWERUP_RESPAWN_TIME: float = 8.0
const TOTAL_CHECKPOINTS: int = 4

# endregion


# region — State

## Peer-id → KartController node.
var kart_nodes: Dictionary = {}

## Cached spawn positions / rotations from Marker3D children.
var spawn_positions: Array[Vector3] = []
var spawn_rotations: Array[float] = []

## Ordered list of peer_ids who crossed the finish line.
var finish_order: Array[int] = []

## HUD instance for the local player.
var _hud: CanvasLayer = null

## Local peer convenience cache.
var _local_peer_id: int = 0

## Per power-up spawn index → seconds until respawn.
var _powerup_timers: Dictionary = {}

# endregion


# region — Node References

@onready var players_node: Node3D = $Players
@onready var spawn_points_node: Node3D = $SpawnPoints
@onready var checkpoints_node: Node3D = $Checkpoints
@onready var lap_line: Area3D = $LapLine
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var powerup_spawns_node: Node3D = $PowerUpSpawns

# endregion


# region — Lifecycle

func _ready() -> void:
	_local_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	# Cache spawn positions.
	for child: Node in spawn_points_node.get_children():
		if child is Marker3D:
			spawn_positions.append((child as Marker3D).global_position)
			spawn_rotations.append((child as Marker3D).rotation.y)

	# Configure spawner.
	player_spawner.spawn_path = NodePath("../Players")
	player_spawner.add_spawnable_scene("res://games/turbo_karts/kart_controller.tscn")

	# Connect GameManager signals.
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.countdown_tick.connect(_on_countdown_tick)
	GameManager.countdown_finished.connect(_on_countdown_finished)
	GameManager.game_timer_updated.connect(_on_game_timer_updated)
	GameManager.round_ended.connect(_on_round_ended)

	# Connect checkpoint areas.
	_connect_checkpoints()

	# Connect lap/finish line.
	if lap_line:
		lap_line.body_entered.connect(_on_lap_line_body_entered)

	# Spawn karts.
	_spawn_karts()

	# Setup HUD.
	_setup_hud()

	# Server kicks off the pre-race countdown.
	if _is_server():
		GameManager.start_countdown(3)

	AudioManager.play_music("turbo_karts")


func _physics_process(delta: float) -> void:
	if _is_server():
		_process_powerup_respawns(delta)

	_update_local_hud()


func _exit_tree() -> void:
	GameManager.state_changed.disconnect(_on_state_changed)
	GameManager.countdown_tick.disconnect(_on_countdown_tick)
	GameManager.countdown_finished.disconnect(_on_countdown_finished)
	GameManager.game_timer_updated.disconnect(_on_game_timer_updated)
	GameManager.round_ended.disconnect(_on_round_ended)

	if is_instance_valid(_hud):
		_hud.queue_free()

# endregion


# region — Kart Spawning

func _spawn_karts() -> void:
	var idx: int = 0
	for peer_id: int in Lobby.players:
		var info: Dictionary = Lobby.players[peer_id]
		var kart: KartController = KART_SCENE.instantiate() as KartController
		kart.name = str(peer_id)

		var spawn_pos: Vector3 = spawn_positions[idx % spawn_positions.size()]
		var spawn_rot: float = spawn_rotations[idx % spawn_rotations.size()]

		kart.setup(
			peer_id,
			info.get("name", "Player") as String,
			info.get("color", Color.WHITE) as Color,
			spawn_pos,
			spawn_rot,
		)

		players_node.add_child(kart, true)
		kart_nodes[peer_id] = kart
		idx += 1

# endregion


# region — Checkpoint System

func _connect_checkpoints() -> void:
	for i: int in checkpoints_node.get_child_count():
		var cp: Area3D = checkpoints_node.get_child(i) as Area3D
		if cp:
			cp.body_entered.connect(_on_checkpoint_body_entered.bind(i))


func _on_checkpoint_body_entered(body: Node3D, checkpoint_index: int) -> void:
	if not _is_server():
		return
	if not body is KartController:
		return

	var kart: KartController = body as KartController
	if kart.finished:
		return

	var expected: int = (kart.current_checkpoint + 1) % TOTAL_CHECKPOINTS
	if checkpoint_index == expected:
		kart.current_checkpoint = checkpoint_index
		_rpc_set_checkpoint.rpc(kart.peer_id, checkpoint_index)


func _on_lap_line_body_entered(body: Node3D) -> void:
	if not _is_server():
		return
	if not body is KartController:
		return

	var kart: KartController = body as KartController
	if kart.finished:
		return
	# All checkpoints must have been visited this lap.
	if kart.current_checkpoint != TOTAL_CHECKPOINTS - 1:
		return

	kart.current_lap += 1
	kart.current_checkpoint = -1
	_rpc_set_lap.rpc(kart.peer_id, kart.current_lap)

	var player_name: String = Lobby.players.get(kart.peer_id, {}).get("name", "Player") as String
	_rpc_race_event.rpc("Lap %d/%d — %s" % [kart.current_lap, TOTAL_LAPS, player_name], Color.YELLOW)
	AudioManager.play_sfx("lap_complete")

	# Check finish condition.
	if kart.current_lap >= TOTAL_LAPS:
		_register_finish(kart)

# endregion


# region — Race Finish

func _register_finish(kart: KartController) -> void:
	if kart.finished:
		return
	kart.finished = true
	kart.finish_time = ROUND_DURATION - GameManager.game_timer
	finish_order.append(kart.peer_id)

	var placement: int = finish_order.size()
	var points: int = (Lobby.players.size() - placement + 1) * 100
	Lobby.add_score(kart.peer_id, points)

	var player_name: String = Lobby.players.get(kart.peer_id, {}).get("name", "Player") as String
	_rpc_race_event.rpc("%s finished #%d!" % [player_name, placement], Color.GREEN)
	_rpc_set_finished.rpc(kart.peer_id)

	# Check if all players have finished.
	if finish_order.size() >= kart_nodes.size():
		_end_round()

# endregion


# region — HUD

func _setup_hud() -> void:
	_hud = HUD_SCENE.instantiate() as CanvasLayer
	add_child(_hud)

	var buttons: Array[Dictionary] = [
		{
			"text": "BOOST",
			"color": Color(1.0, 0.6, 0.1, 0.85),
			"callback": Callable(self, "_on_boost_pressed"),
		},
		{
			"text": "ITEM",
			"color": Color(0.3, 0.8, 0.3, 0.85),
			"callback": Callable(self, "_on_item_pressed"),
		},
	]
	_hud.set_action_buttons(buttons)

	_hud.connect_joystick(Callable(self, "_on_joystick_input"))

	_hud.set_timer(ROUND_DURATION)
	_hud.set_score(0)
	_hud.set_health(100.0, 100.0)  # Not used in racing; avoids an empty health bar.


func _update_local_hud() -> void:
	var kart: KartController = kart_nodes.get(_local_peer_id) as KartController
	if kart and is_instance_valid(_hud):
		_hud.set_score(kart.current_lap)

# endregion


# region — Input Callbacks

func _on_joystick_input(value: Vector2) -> void:
	var kart: KartController = _get_local_kart()
	if not kart:
		return

	kart.set_steering(value.x)
	# Joystick Y: negative = up (forward on screen). Invert for throttle.
	kart.set_throttle(-value.y)


func _on_boost_pressed() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var kart: KartController = _get_local_kart()
	if kart:
		kart.activate_boost()


func _on_item_pressed() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var kart: KartController = _get_local_kart()
	if not kart or kart.held_item == KartController.ItemType.NONE:
		return

	# Missile needs server-side processing.
	if kart.held_item == KartController.ItemType.MISSILE:
		_request_fire_missile.rpc_id(1)

	kart.use_item()

# endregion


# region — Server RPCs — Actions

## Client requests a missile launch. Server spawns the projectile.
@rpc("any_peer", "reliable")
func _request_fire_missile() -> void:
	if not _is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	var kart: KartController = kart_nodes.get(sender_id) as KartController
	if not kart:
		return

	# TODO: spawn a missile projectile at kart.global_position heading kart forward direction.
	AudioManager.play_sfx("missile_launch")

# endregion


# region — Race-State RPCs (server → all clients)

@rpc("authority", "call_local", "reliable")
func _rpc_set_checkpoint(peer_id: int, checkpoint_index: int) -> void:
	var kart: KartController = kart_nodes.get(peer_id) as KartController
	if kart:
		kart.current_checkpoint = checkpoint_index


@rpc("authority", "call_local", "reliable")
func _rpc_set_lap(peer_id: int, lap: int) -> void:
	var kart: KartController = kart_nodes.get(peer_id) as KartController
	if kart:
		kart.current_lap = lap
		kart.current_checkpoint = -1


@rpc("authority", "call_local", "reliable")
func _rpc_set_finished(peer_id: int) -> void:
	var kart: KartController = kart_nodes.get(peer_id) as KartController
	if kart:
		kart.finished = true
		kart.set_race_started(false)


@rpc("authority", "call_local", "reliable")
func _rpc_collect_item(peer_id: int, item_type: int) -> void:
	var kart: KartController = kart_nodes.get(peer_id) as KartController
	if kart:
		kart.collect_item(item_type)


@rpc("authority", "call_local", "reliable")
func _rpc_race_event(text: String, color: Color) -> void:
	if is_instance_valid(_hud):
		_hud.add_kill_feed_entry(text, color)

# endregion


# region — Power-Up System

func _spawn_initial_powerups() -> void:
	if not powerup_spawns_node:
		return
	for i: int in powerup_spawns_node.get_child_count():
		_spawn_powerup_at(i)


func _process_powerup_respawns(delta: float) -> void:
	for idx: int in _powerup_timers.keys().duplicate():
		_powerup_timers[idx] = (_powerup_timers[idx] as float) - delta
		if (_powerup_timers[idx] as float) <= 0.0:
			_powerup_timers.erase(idx)
			_spawn_powerup_at(idx)


func _spawn_powerup_at(spawn_index: int) -> void:
	if not powerup_spawns_node:
		return
	if spawn_index >= powerup_spawns_node.get_child_count():
		return

	var spawn_marker: Marker3D = powerup_spawns_node.get_child(spawn_index) as Marker3D
	if not spawn_marker:
		return

	# Create an Area3D power-up at the marker's position.
	var pickup: Area3D = Area3D.new()
	pickup.name = "PowerUp_%d" % spawn_index
	pickup.position = spawn_marker.global_position
	pickup.collision_layer = 0
	pickup.collision_mask = 2   # Detect karts (layer 2).
	pickup.monitoring = true
	pickup.monitorable = false

	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(2.0, 2.0, 2.0)
	shape_node.shape = box_shape
	pickup.add_child(shape_node)

	# Glowing cube visual.
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(1.0, 1.0, 1.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.0)
	mat.emission_energy_multiplier = 0.5
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	mesh_inst.position.y = 0.5
	pickup.add_child(mesh_inst)

	# Random item type.
	var item_type: int = [
		KartController.ItemType.BOOST,
		KartController.ItemType.SHIELD,
		KartController.ItemType.MISSILE,
	].pick_random()
	pickup.set_meta("item_type", item_type)
	pickup.set_meta("spawn_index", spawn_index)

	pickup.body_entered.connect(_on_powerup_collected.bind(pickup))
	add_child(pickup, true)


func _on_powerup_collected(body: Node3D, pickup: Area3D) -> void:
	if not _is_server():
		return
	if not body is KartController:
		return

	var kart: KartController = body as KartController
	if kart.held_item != KartController.ItemType.NONE:
		return   # Already carrying an item.

	var item_type: int = pickup.get_meta("item_type", 0) as int
	var spawn_index: int = pickup.get_meta("spawn_index", -1) as int

	_rpc_collect_item.rpc(kart.peer_id, item_type)
	AudioManager.play_sfx("pickup")
	pickup.queue_free()

	# Schedule a respawn.
	if spawn_index >= 0:
		_powerup_timers[spawn_index] = POWERUP_RESPAWN_TIME

# endregion


# region — GameManager Signal Handlers

func _on_state_changed(old_state: int, new_state: int) -> void:
	match new_state:
		GameManager.GameState.PLAYING:
			# Start the race for every kart.
			for kart: KartController in kart_nodes.values():
				kart.set_race_started(true)
			if _is_server():
				GameManager.start_game_timer(ROUND_DURATION)
				_spawn_initial_powerups()
		GameManager.GameState.ROUND_END:
			for kart: KartController in kart_nodes.values():
				kart.set_race_started(false)
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

	# When the timer expires, end the round.
	if _is_server() and time_remaining <= 0.0:
		_end_round()


func _on_round_ended(results: Array) -> void:
	if is_instance_valid(_hud):
		_hud.show_message("Race Over!", 3.0)

# endregion


# region — Round End / Results

func _end_round() -> void:
	if not _is_server():
		return

	var results: Array = []

	# Finished players first (already in finish order).
	for i: int in finish_order.size():
		var pid: int = finish_order[i]
		results.append({
			"peer_id": pid,
			"score": (Lobby.players.size() - i) * 100,
			"laps": TOTAL_LAPS,
			"placement": i + 1,
		})

	# Unfinished players sorted by progress (laps desc, then checkpoint desc).
	var unfinished: Array = []
	for peer_id: int in kart_nodes:
		if peer_id not in finish_order:
			var kart: KartController = kart_nodes[peer_id] as KartController
			unfinished.append({
				"peer_id": peer_id,
				"score": 0,
				"laps": kart.current_lap,
				"checkpoint": kart.current_checkpoint,
				"placement": 0,
			})

	unfinished.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (a["laps"] as int) != (b["laps"] as int):
			return (a["laps"] as int) > (b["laps"] as int)
		return (a["checkpoint"] as int) > (b["checkpoint"] as int)
	)

	var next_placement: int = finish_order.size() + 1
	for entry: Dictionary in unfinished:
		entry["placement"] = next_placement
		next_placement += 1
		results.append(entry)

	GameManager.end_round(results)


func _show_results() -> void:
	if is_instance_valid(_hud):
		_hud.show_message("Race Complete!", 3.0)

# endregion


# region — Helpers

func _get_local_kart() -> KartController:
	return kart_nodes.get(_local_peer_id) as KartController


func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
