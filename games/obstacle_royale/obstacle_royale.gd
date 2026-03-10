## Obstacle Royale — Fall Guys-inspired obstacle course race mini-game.
##
## Server-authoritative race across a multi-section obstacle course.
## Players must navigate conveyor platforms, swinging pendulums, rotating bars,
## and falling tiles to reach the finish line.  Falling off respawns at the
## last checkpoint (no elimination — just time penalty).  Round timer: 60 seconds.
## Scoring: 1st = 10 pts, 2nd = 8, 3rd = 6, 4th = 5, 5th = 4, 6th = 3, 7th = 2, 8th = 1.
class_name ObstacleRoyale
extends Node3D


# region — Constants

const PLAYER_CHARACTER_SCENE: PackedScene = preload("res://characters/player_character.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud/game_hud.tscn")

const ROUND_DURATION: float = 60.0          ## seconds
const KILL_ZONE_Y: float = -10.0            ## Y threshold that triggers respawn
const DIVE_SPEED: float = 14.0              ## Horizontal burst speed for the dive
const DIVE_VERTICAL: float = 2.0            ## Small upward pop before diving forward
const DIVE_COOLDOWN: float = 1.0

## Points awarded per finishing placement (index 0 = 1st place).
const PLACEMENT_SCORES: Array[int] = [10, 8, 6, 5, 4, 3, 2, 1]

# endregion


# region — State

## Peer-id → PlayerCharacter node.
var player_nodes: Dictionary = {}

## Cached spawn positions from Marker3D children.
var spawn_positions: Array[Vector3] = []

## Ordered list of peer_ids who crossed the finish line (first = 1st place).
var finish_order: Array[int] = []

## Peer-id → index of last reached checkpoint (−1 = start).
var player_checkpoints: Dictionary = {}

## Peer-id → dive cooldown remaining.
var _dive_cooldowns: Dictionary = {}

## Checkpoint world positions (ordered along the course).
var _checkpoint_positions: Array[Vector3] = []

## HUD instance for the local player.
var _hud: CanvasLayer = null

## Local peer convenience cache.
var _local_peer_id: int = 0

# endregion


# region — Node References

@onready var players_node: Node3D = $Players
@onready var spawn_points_node: Node3D = $SpawnPoints
@onready var checkpoints_node: Node3D = $Checkpoints
@onready var finish_line: Area3D = $FinishLine
@onready var kill_zone: Area3D = $KillZone
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner

# endregion


# region — Lifecycle

func _ready() -> void:
	_local_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	# Cache spawn positions.
	for child: Node in spawn_points_node.get_children():
		if child is Marker3D:
			spawn_positions.append((child as Marker3D).global_position)

	# Cache checkpoint positions (ordered by child index).
	for child: Node in checkpoints_node.get_children():
		if child is Marker3D:
			_checkpoint_positions.append((child as Marker3D).global_position)

	# Configure spawner.
	player_spawner.spawn_path = NodePath("../Players")
	player_spawner.add_spawnable_scene("res://characters/player_character.tscn")

	# Connect GameManager signals.
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.countdown_tick.connect(_on_countdown_tick)
	GameManager.countdown_finished.connect(_on_countdown_finished)
	GameManager.game_timer_updated.connect(_on_game_timer_updated)
	GameManager.round_ended.connect(_on_round_ended)

	# Connect finish and kill zone.
	if finish_line:
		finish_line.body_entered.connect(_on_finish_line_body_entered)
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_body_entered)

	# Connect checkpoint areas.
	_connect_checkpoints()

	# Spawn player characters.
	_spawn_players()

	# Setup HUD.
	_setup_hud()

	# Server starts the 3-2-1 countdown.
	if _is_server():
		GameManager.start_countdown(3)

	AudioManager.play_music("obstacle_royale")


func _physics_process(delta: float) -> void:
	if not _is_server():
		return

	# Tick dive cooldowns.
	for peer_id: int in _dive_cooldowns.keys():
		_dive_cooldowns[peer_id] = maxf((_dive_cooldowns[peer_id] as float) - delta, 0.0)

	# Fall detection (backup in case kill zone Area3D is missed).
	for peer_id: int in player_nodes:
		var character: PlayerCharacter = player_nodes[peer_id] as PlayerCharacter
		if character and character.is_alive and character.global_position.y < KILL_ZONE_Y:
			_respawn_at_checkpoint(peer_id)


func _exit_tree() -> void:
	GameManager.state_changed.disconnect(_on_state_changed)
	GameManager.countdown_tick.disconnect(_on_countdown_tick)
	GameManager.countdown_finished.disconnect(_on_countdown_finished)
	GameManager.game_timer_updated.disconnect(_on_game_timer_updated)
	GameManager.round_ended.disconnect(_on_round_ended)

	if is_instance_valid(_hud):
		_hud.queue_free()

# endregion


# region — Player Spawning

func _spawn_players() -> void:
	var idx: int = 0
	for peer_id: int in Lobby.players:
		var info: Dictionary = Lobby.players[peer_id]
		var character: PlayerCharacter = PLAYER_CHARACTER_SCENE.instantiate() as PlayerCharacter
		character.name = str(peer_id)

		# Place at spawn point (cycle if more players than spawn points).
		var spawn_pos: Vector3 = spawn_positions[idx % spawn_positions.size()]
		character.position = spawn_pos

		# Configure authority and visuals.
		character.setup_for_authority(peer_id)
		character.set_player_name_label(info.get("name", "Player"))
		character.set_player_color(info.get("color", Color.WHITE))

		# Connect signals.
		character.died.connect(_on_player_died)

		players_node.add_child(character, true)
		player_nodes[peer_id] = character

		# Init tracking.
		player_checkpoints[peer_id] = -1
		_dive_cooldowns[peer_id] = 0.0

		idx += 1

# endregion


# region — Checkpoint System

func _connect_checkpoints() -> void:
	# Checkpoints are Marker3D nodes; we create Area3D triggers around each one.
	for i: int in checkpoints_node.get_child_count():
		var marker: Node = checkpoints_node.get_child(i)
		if not marker is Marker3D:
			continue

		var area := Area3D.new()
		area.name = "CP_Area_%d" % i
		area.collision_layer = 0
		area.collision_mask = 1  # Players on layer 1.
		area.monitoring = true
		area.monitorable = false

		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(8.0, 4.0, 2.0)
		shape_node.shape = box
		area.add_child(shape_node)

		area.position = (marker as Marker3D).global_position
		add_child(area)
		area.body_entered.connect(_on_checkpoint_body_entered.bind(i))


func _on_checkpoint_body_entered(body: Node3D, checkpoint_index: int) -> void:
	if not _is_server():
		return
	if not body is CharacterBody3D:
		return

	# Find which peer this body belongs to.
	var peer_id: int = _peer_id_from_body(body)
	if peer_id == 0:
		return

	var current_cp: int = player_checkpoints.get(peer_id, -1) as int
	# Only accept the next checkpoint in sequence (or any if first).
	if checkpoint_index == current_cp + 1 or (current_cp == -1 and checkpoint_index == 0):
		player_checkpoints[peer_id] = checkpoint_index
		_rpc_checkpoint_reached.rpc(peer_id, checkpoint_index)


@rpc("authority", "call_local", "reliable")
func _rpc_checkpoint_reached(peer_id: int, checkpoint_index: int) -> void:
	player_checkpoints[peer_id] = checkpoint_index
	# Show a brief HUD message for the local player.
	if peer_id == _local_peer_id and is_instance_valid(_hud):
		_hud.show_message("Checkpoint %d!" % (checkpoint_index + 1), 1.0)

# endregion


# region — Finish Line

func _on_finish_line_body_entered(body: Node3D) -> void:
	if not _is_server():
		return
	if not body is CharacterBody3D:
		return

	var peer_id: int = _peer_id_from_body(body)
	if peer_id == 0:
		return
	if peer_id in finish_order:
		return  # Already finished.

	finish_order.append(peer_id)

	var placement: int = finish_order.size()
	var score: int = PLACEMENT_SCORES[mini(placement - 1, PLACEMENT_SCORES.size() - 1)]
	Lobby.add_score(peer_id, score)

	var player_name: String = Lobby.players.get(peer_id, {}).get("name", "Player") as String
	_rpc_race_event.rpc("%s finished #%d! (+%d pts)" % [player_name, placement, score], Color.GREEN)
	AudioManager.play_sfx("finish")

	# Check if everyone finished.
	if finish_order.size() >= player_nodes.size():
		_end_round()

# endregion


# region — Kill Zone / Respawn

func _on_kill_zone_body_entered(body: Node3D) -> void:
	if not _is_server():
		return
	if not body is CharacterBody3D:
		return

	var peer_id: int = _peer_id_from_body(body)
	if peer_id == 0:
		return

	_respawn_at_checkpoint(peer_id)


func _on_player_died(peer_id: int) -> void:
	if not _is_server():
		return
	# In Obstacle Royale death = respawn at checkpoint, not elimination.
	_respawn_at_checkpoint(peer_id)


func _respawn_at_checkpoint(peer_id: int) -> void:
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if not character:
		return

	# If already finished, don't respawn.
	if peer_id in finish_order:
		return

	var cp_index: int = player_checkpoints.get(peer_id, -1) as int
	var respawn_pos: Vector3 = Vector3.ZERO

	if cp_index >= 0 and cp_index < _checkpoint_positions.size():
		respawn_pos = _checkpoint_positions[cp_index] + Vector3(0.0, 2.0, 0.0)
	elif spawn_positions.size() > 0:
		# No checkpoint reached yet — send back to start.
		respawn_pos = spawn_positions[0] + Vector3(0.0, 1.0, 0.0)
	else:
		respawn_pos = Vector3(0.0, 5.0, 0.0)

	character.respawn(respawn_pos)
	_rpc_respawn_player.rpc(peer_id, respawn_pos)
	AudioManager.play_sfx("respawn")


@rpc("authority", "call_remote", "reliable")
func _rpc_respawn_player(peer_id: int, pos: Vector3) -> void:
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if character:
		character.respawn(pos)

# endregion


# region — HUD

func _setup_hud() -> void:
	_hud = HUD_SCENE.instantiate() as CanvasLayer
	add_child(_hud)

	# Configure action buttons — JUMP + DIVE.
	var buttons: Array[Dictionary] = [
		{
			"text": "JUMP",
			"color": Color(0.3, 0.75, 1.0, 0.85),
			"callback": Callable(self, "_on_jump_pressed"),
		},
		{
			"text": "DIVE",
			"color": Color(1.0, 0.5, 0.15, 0.85),
			"callback": Callable(self, "_on_dive_pressed"),
		},
	]
	_hud.set_action_buttons(buttons)

	# Connect joystick to local player movement.
	_hud.connect_joystick(Callable(self, "_on_joystick_input"))

	# Initial HUD values.
	_hud.set_timer(ROUND_DURATION)
	_hud.set_score(0)
	_hud.set_health(100.0, 100.0)

# endregion


# region — Input Callbacks

func _on_joystick_input(value: Vector2) -> void:
	var local_char: PlayerCharacter = _get_local_character()
	if local_char:
		local_char.set_movement_input(value)


func _on_jump_pressed() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var local_char: PlayerCharacter = _get_local_character()
	if not local_char or not local_char.is_alive:
		return
	local_char.trigger_jump()


func _on_dive_pressed() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var local_char: PlayerCharacter = _get_local_character()
	if not local_char or not local_char.is_alive:
		return
	_request_dive.rpc_id(1)

# endregion


# region — Server RPCs — Actions

## Client requests a fast forward dive.  Server validates cooldown and applies impulse.
@rpc("any_peer", "reliable")
func _request_dive() -> void:
	if not _is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1  # Local server player.

	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Cooldown check.
	if (_dive_cooldowns.get(sender_id, 0.0) as float) > 0.0:
		return

	var character: PlayerCharacter = player_nodes.get(sender_id) as PlayerCharacter
	if not character or not character.is_alive:
		return

	_dive_cooldowns[sender_id] = DIVE_COOLDOWN

	# Compute dive direction from character facing.
	var forward: Vector3 = -character.global_transform.basis.z.normalized()
	var impulse: Vector3 = forward * DIVE_SPEED + Vector3.UP * DIVE_VERTICAL
	character.apply_knockback(impulse)
	_rpc_dive_effect.rpc(sender_id)
	AudioManager.play_sfx("dive")


## Visual / audio feedback for the dive on all clients.
@rpc("authority", "call_remote", "reliable")
func _rpc_dive_effect(peer_id: int) -> void:
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if character:
		# Quick forward impulse on client for smooth visuals.
		var forward: Vector3 = -character.global_transform.basis.z.normalized()
		character.apply_knockback(forward * DIVE_SPEED + Vector3.UP * DIVE_VERTICAL)

# endregion


# region — Race Event RPC

@rpc("authority", "call_local", "reliable")
func _rpc_race_event(text: String, color: Color) -> void:
	if is_instance_valid(_hud):
		_hud.add_kill_feed_entry(text, color)

# endregion


# region — GameManager Signal Handlers

func _on_state_changed(old_state: int, new_state: int) -> void:
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

	# Server: when timer hits zero, end the round.
	if _is_server() and time_remaining <= 0.0:
		_end_round()


func _on_round_ended(results: Array) -> void:
	if is_instance_valid(_hud):
		_hud.show_message("Round Over!", 3.0)

# endregion


# region — Round End / Results

func _end_round() -> void:
	if not _is_server():
		return

	var results: Array = []

	# Players who finished (already ordered).
	for i: int in finish_order.size():
		var pid: int = finish_order[i]
		var score: int = PLACEMENT_SCORES[mini(i, PLACEMENT_SCORES.size() - 1)]
		results.append({
			"peer_id": pid,
			"score": score,
			"placement": i + 1,
			"finished": true,
		})

	# Unfinished players — rank by distance to finish line.
	var unfinished: Array[Dictionary] = []
	for peer_id: int in player_nodes:
		if peer_id in finish_order:
			continue
		var character: PlayerCharacter = player_nodes[peer_id] as PlayerCharacter
		var dist_to_finish: float = 9999.0
		if character and finish_line:
			dist_to_finish = character.global_position.distance_to(finish_line.global_position)
		unfinished.append({
			"peer_id": peer_id,
			"score": 0,
			"distance": dist_to_finish,
			"checkpoint": player_checkpoints.get(peer_id, -1) as int,
			"placement": 0,
			"finished": false,
		})

	# Sort: higher checkpoint first, then shorter distance to finish.
	unfinished.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (a["checkpoint"] as int) != (b["checkpoint"] as int):
			return (a["checkpoint"] as int) > (b["checkpoint"] as int)
		return (a["distance"] as float) < (b["distance"] as float)
	)

	var next_placement: int = finish_order.size() + 1
	for entry: Dictionary in unfinished:
		entry["placement"] = next_placement
		var score: int = PLACEMENT_SCORES[mini(next_placement - 1, PLACEMENT_SCORES.size() - 1)]
		entry["score"] = score
		Lobby.add_score(entry["peer_id"] as int, score)
		next_placement += 1
		results.append(entry)

	GameManager.end_round(results)


func _show_results() -> void:
	if is_instance_valid(_hud):
		_hud.show_message("Race Complete!", 3.0)

# endregion


# region — Helpers

func _get_local_character() -> PlayerCharacter:
	return player_nodes.get(_local_peer_id) as PlayerCharacter


func _peer_id_from_body(body: Node3D) -> int:
	# Player nodes are named with their peer_id.
	if body.name.is_valid_int():
		return body.name.to_int()
	# Walk up to find the PlayerCharacter.
	var parent: Node = body
	while parent:
		if parent is PlayerCharacter:
			return (parent as PlayerCharacter).peer_id
		parent = parent.get_parent()
	return 0


func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
