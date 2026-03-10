## Arena Blaster — Free-For-All third-person arena shooter mini-game.
##
## Server-authoritative match logic: 2-minute rounds, most kills wins.
## Players respawn 3 seconds after death at a random spawn point.
## Projectile and pickup systems are multiplayer-replicated via spawners.
class_name ArenaBlaster
extends Node3D


# region — Constants

const PLAYER_CHARACTER_SCENE: PackedScene = preload("res://characters/player_character.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://games/arena_blaster/projectile.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud/game_hud.tscn")

const ROUND_DURATION: float = 120.0   ## 2 minutes
const RESPAWN_DELAY: float = 3.0
const SHOOT_COOLDOWN: float = 0.3
const DODGE_DURATION: float = 0.4
const DODGE_SPEED_MULT: float = 2.0
const DODGE_COOLDOWN: float = 1.5
const PROJECTILE_OFFSET: float = 1.2   ## Forward offset from player centre

# endregion


# region — State

## Kill counter per peer_id.
var kills: Dictionary = {}

## Death counter per peer_id.
var deaths: Dictionary = {}

## Peer-id → PlayerCharacter node.
var player_nodes: Dictionary = {}

## Cached spawn positions from Marker3D children.
var spawn_positions: Array[Vector3] = []

## Per-peer cooldown tracker for shooting.
var _shoot_cooldown_timers: Dictionary = {}

## Per-peer dodge cooldown tracker.
var _dodge_cooldown_timers: Dictionary = {}

## Per-peer dodge active timer (remaining seconds of dodge effect).
var _dodge_active_timers: Dictionary = {}

## HUD instance for the local player.
var _hud: CanvasLayer = null

## Local peer convenience cache.
var _local_peer_id: int = 0

# endregion


# region — Node References

@onready var players_node: Node3D = $Players
@onready var projectiles_node: Node3D = $Projectiles
@onready var spawn_points_node: Node3D = $SpawnPoints
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner

# endregion


# region — Lifecycle

func _ready() -> void:
	_local_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	# Cache spawn positions.
	for child: Node in spawn_points_node.get_children():
		if child is Marker3D:
			spawn_positions.append((child as Marker3D).global_position)

	# Configure spawners.
	player_spawner.spawn_path = NodePath("../Players")
	player_spawner.add_spawnable_scene("res://characters/player_character.tscn")

	projectile_spawner.spawn_path = NodePath("../Projectiles")
	projectile_spawner.add_spawnable_scene("res://games/arena_blaster/projectile.tscn")

	# Connect GameManager signals.
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.countdown_tick.connect(_on_countdown_tick)
	GameManager.countdown_finished.connect(_on_countdown_finished)
	GameManager.game_timer_updated.connect(_on_game_timer_updated)
	GameManager.round_ended.connect(_on_round_ended)

	# Spawn player characters.
	_spawn_players()

	# Instantiate HUD.
	_setup_hud()

	# Server kicks off the countdown.
	if _is_server():
		GameManager.start_countdown(3)

	AudioManager.play_music("arena_blaster")


func _physics_process(delta: float) -> void:
	if not _is_server():
		return

	# Tick shoot cooldowns.
	for peer_id: int in _shoot_cooldown_timers.keys():
		_shoot_cooldown_timers[peer_id] = maxf((_shoot_cooldown_timers[peer_id] as float) - delta, 0.0)

	# Tick dodge cooldowns.
	for peer_id: int in _dodge_cooldown_timers.keys():
		_dodge_cooldown_timers[peer_id] = maxf((_dodge_cooldown_timers[peer_id] as float) - delta, 0.0)

	# Tick active dodge effects.
	for peer_id: int in _dodge_active_timers.keys().duplicate():
		_dodge_active_timers[peer_id] = (_dodge_active_timers[peer_id] as float) - delta
		if (_dodge_active_timers[peer_id] as float) <= 0.0:
			_end_dodge(peer_id)
			_dodge_active_timers.erase(peer_id)

	# Check for last-player-standing.
	_check_last_standing()


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

		# Connect combat signals.
		character.died.connect(_on_player_died)
		character.action_triggered.connect(_on_player_action_triggered.bind(peer_id))

		players_node.add_child(character, true)
		player_nodes[peer_id] = character

		# Init tracking.
		kills[peer_id] = 0
		deaths[peer_id] = 0
		_shoot_cooldown_timers[peer_id] = 0.0
		_dodge_cooldown_timers[peer_id] = 0.0

		idx += 1

# endregion


# region — HUD

func _setup_hud() -> void:
	_hud = HUD_SCENE.instantiate() as CanvasLayer
	add_child(_hud)

	# Configure action buttons.
	var buttons: Array[Dictionary] = [
		{
			"text": "SHOOT",
			"color": Color(1.0, 0.25, 0.25, 0.85),
			"callback": Callable(self, "_on_shoot_pressed"),
		},
		{
			"text": "DODGE",
			"color": Color(0.25, 0.6, 1.0, 0.85),
			"callback": Callable(self, "_on_dodge_pressed"),
		},
	]
	_hud.set_action_buttons(buttons)

	# Connect joystick to local player movement.
	_hud.connect_joystick(Callable(self, "_on_joystick_input"))

	# Initial HUD values.
	_hud.set_timer(ROUND_DURATION)
	_hud.set_score(0)
	_hud.set_health(100.0, 100.0)

	# Keep local player health synced to HUD.
	var local_char: PlayerCharacter = _get_local_character()
	if local_char:
		local_char.health_changed.connect(_on_local_health_changed)

# endregion


# region — Input Callbacks

func _on_joystick_input(value: Vector2) -> void:
	var local_char: PlayerCharacter = _get_local_character()
	if local_char:
		local_char.set_movement_input(value)


func _on_shoot_pressed() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var local_char: PlayerCharacter = _get_local_character()
	if not local_char or not local_char.is_alive:
		return

	# Compute aim direction from player facing.
	var forward: Vector3 = -local_char.global_transform.basis.z.normalized()
	_request_shoot.rpc_id(1, forward)


func _on_dodge_pressed() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var local_char: PlayerCharacter = _get_local_character()
	if not local_char or not local_char.is_alive:
		return

	_request_dodge.rpc_id(1)

# endregion


# region — Server RPCs — Actions

## Client asks the server to fire a projectile.
@rpc("any_peer", "reliable")
func _request_shoot(direction: Vector3) -> void:
	if not _is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1  # Local server player.

	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Cooldown check.
	if _shoot_cooldown_timers.get(sender_id, 0.0) as float > 0.0:
		return

	var character: PlayerCharacter = player_nodes.get(sender_id) as PlayerCharacter
	if not character or not character.is_alive:
		return

	_shoot_cooldown_timers[sender_id] = SHOOT_COOLDOWN
	_spawn_projectile(sender_id, character.global_position + Vector3.UP * 1.0, direction.normalized())
	AudioManager.play_sfx("shoot")


## Client asks the server to dodge.
@rpc("any_peer", "reliable")
func _request_dodge() -> void:
	if not _is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1

	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Cooldown check.
	if _dodge_cooldown_timers.get(sender_id, 0.0) as float > 0.0:
		return

	var character: PlayerCharacter = player_nodes.get(sender_id) as PlayerCharacter
	if not character or not character.is_alive:
		return

	_dodge_cooldown_timers[sender_id] = DODGE_COOLDOWN
	_dodge_active_timers[sender_id] = DODGE_DURATION

	# Boost speed during dodge.
	character.speed *= DODGE_SPEED_MULT
	AudioManager.play_sfx("dodge")


func _end_dodge(peer_id: int) -> void:
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if character:
		character.speed = 8.0  # Reset to default.

# endregion


# region — Projectile System

func _spawn_projectile(owner_peer_id: int, origin: Vector3, direction: Vector3) -> void:
	var projectile: Node3D = PROJECTILE_SCENE.instantiate()
	projectile.name = "Proj_%d_%d" % [owner_peer_id, Time.get_ticks_msec()]
	projectile.position = origin + direction * PROJECTILE_OFFSET
	projectile.set("direction", direction)
	projectile.set("owner_peer_id", owner_peer_id)

	# Colour the projectile to match the owner.
	var info: Dictionary = Lobby.players.get(owner_peer_id, {})
	var color: Color = info.get("color", Color.RED) as Color
	projectile.set("projectile_color", color)

	projectiles_node.add_child(projectile, true)

# endregion


# region — Combat Events

func _on_player_died(peer_id: int) -> void:
	if not _is_server():
		return

	deaths[peer_id] = (deaths.get(peer_id, 0) as int) + 1

	# Notify all clients about the death via kill feed.
	var victim_name: String = Lobby.players.get(peer_id, {}).get("name", "Player") as String
	_rpc_kill_feed.rpc("%s was eliminated!" % victim_name, Color.RED)

	# Schedule respawn.
	_start_respawn_timer(peer_id)


func _on_player_action_triggered(peer_id: int) -> void:
	# Action triggered signal — handled via button callbacks instead.
	pass


## Called by projectile when it hits a player — server-only.
func register_kill(killer_peer_id: int, victim_peer_id: int) -> void:
	if not _is_server():
		return
	if killer_peer_id == victim_peer_id:
		return  # No self-kill credit.

	kills[killer_peer_id] = (kills.get(killer_peer_id, 0) as int) + 1
	Lobby.add_score(killer_peer_id, 100)

	# Update HUD for killer.
	_rpc_update_score.rpc_id(killer_peer_id, kills[killer_peer_id] as int)

	var killer_name: String = Lobby.players.get(killer_peer_id, {}).get("name", "Player") as String
	var victim_name: String = Lobby.players.get(victim_peer_id, {}).get("name", "Player") as String
	_rpc_kill_feed.rpc("%s eliminated %s" % [killer_name, victim_name], Color.YELLOW)

	AudioManager.play_sfx("kill")


@rpc("authority", "call_local", "reliable")
func _rpc_kill_feed(text: String, color: Color) -> void:
	if is_instance_valid(_hud):
		_hud.add_kill_feed_entry(text, color)


@rpc("authority", "call_local", "reliable")
func _rpc_update_score(score: int) -> void:
	if is_instance_valid(_hud):
		_hud.set_score(score)

# endregion


# region — Respawn

func _start_respawn_timer(peer_id: int) -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = RESPAWN_DELAY
	timer.one_shot = true
	timer.timeout.connect(_on_respawn_timeout.bind(peer_id, timer))
	add_child(timer)
	timer.start()


func _on_respawn_timeout(peer_id: int, timer: Timer) -> void:
	timer.queue_free()
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if not character:
		return

	var spawn_pos: Vector3 = _get_random_spawn_position()
	character.respawn(spawn_pos)
	_rpc_respawn_player.rpc(peer_id, spawn_pos)


@rpc("authority", "call_remote", "reliable")
func _rpc_respawn_player(peer_id: int, pos: Vector3) -> void:
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if character:
		character.respawn(pos)

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

	# Build results sorted by kills descending.
	var results: Array = []
	for peer_id: int in kills:
		results.append({
			"peer_id": peer_id,
			"score": kills[peer_id] as int,
			"kills": kills[peer_id] as int,
			"deaths": deaths.get(peer_id, 0) as int,
			"placement": 0,
		})

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["kills"] as int) > (b["kills"] as int)
	)

	# Assign placements.
	for i: int in results.size():
		results[i]["placement"] = i + 1

	GameManager.end_round(results)


func _check_last_standing() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Count connected players.
	var connected_count: int = Lobby.players.size()
	if connected_count <= 1:
		_end_round()


func _show_results() -> void:
	if is_instance_valid(_hud):
		_hud.show_message("Match Complete!", 3.0)

# endregion


# region — Health HUD Sync

func _on_local_health_changed(new_health: float, max_health: float) -> void:
	if is_instance_valid(_hud):
		_hud.set_health(new_health, max_health)

# endregion


# region — Pickup Effects (called by pickup.gd)

func apply_pickup_effect(peer_id: int, pickup_type: int) -> void:
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if not character:
		return

	match pickup_type:
		0:  # HEALTH
			character.heal(50.0)
		1:  # SPEED
			character.speed *= 1.5
			_create_timed_reset(peer_id, "speed", 8.0, 5.0)
		2:  # SHIELD
			character.max_health += 50.0
			character.health += 50.0
			character.health_changed.emit(character.health, character.max_health)
			_create_timed_reset(peer_id, "shield", 0.0, 8.0)
		3:  # RAPID_FIRE
			_shoot_cooldown_timers[peer_id] = -999.0  # effectively no cooldown
			_create_timed_reset(peer_id, "rapid_fire", 0.0, 5.0)


func _create_timed_reset(peer_id: int, effect: String, _value: float, duration: float) -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_effect_expired.bind(peer_id, effect, timer))
	add_child(timer)
	timer.start()


func _on_effect_expired(peer_id: int, effect: String, timer: Timer) -> void:
	timer.queue_free()
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if not character:
		return

	match effect:
		"speed":
			character.speed = 8.0
		"shield":
			character.max_health = 100.0
			character.health = minf(character.health, character.max_health)
			character.health_changed.emit(character.health, character.max_health)
		"rapid_fire":
			_shoot_cooldown_timers[peer_id] = 0.0

# endregion


# region — Helpers

func _get_local_character() -> PlayerCharacter:
	return player_nodes.get(_local_peer_id) as PlayerCharacter


func _get_random_spawn_position() -> Vector3:
	if spawn_positions.is_empty():
		return Vector3(0.0, 1.0, 0.0)
	return spawn_positions[randi() % spawn_positions.size()]


func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
