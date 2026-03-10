## Flag Wars — Two-team Capture the Flag mini-game.
##
## Server-authoritative match logic: first to 3 captures or most captures in 3 minutes.
## Players are split into Red and Blue teams based on join order.
## Pick up the enemy flag by walking into it, return it to your own base to score.
## Tag enemies carrying the flag to force a drop; dropped flags return after 10 seconds.
## Players respawn at their team's base after a 3-second delay on death.
## Abilities: Sprint (2× speed, 3 s duration, 8 s cooldown),
##            Smoke (hide from minimap 5 s — visual cue only in this version).
class_name FlagWars
extends Node3D


# region — Constants

const PLAYER_CHARACTER_SCENE: PackedScene = preload("res://characters/player_character.tscn")
const FLAG_MARKER_SCENE: PackedScene = preload("res://games/flag_wars/flag_marker.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud/game_hud.tscn")

const ROUND_DURATION: float = 180.0        ## 3 minutes
const RESPAWN_DELAY: float = 3.0
const CAPTURES_TO_WIN: int = 3
const FLAG_RETURN_DELAY: float = 10.0      ## Dropped flag auto-returns after 10 s
const FLAG_PICKUP_RADIUS: float = 2.0

const SPRINT_SPEED_MULT: float = 2.0
const SPRINT_DURATION: float = 3.0
const SPRINT_COOLDOWN: float = 8.0

const SMOKE_DURATION: float = 5.0
const SMOKE_COOLDOWN: float = 15.0

const CAPTURE_SCORE: int = 500             ## Lobby points per successful capture
const TAG_SCORE: int = 100                 ## Points for tagging a flag carrier

# endregion


# region — State

## Team assignments — peer_id → "red" or "blue".
var teams: Dictionary = {}

## Score per team.
var team_scores: Dictionary = {"red": 0, "blue": 0}

## Flag state per team.
## { "red": { "position": Vector3, "carrier_id": int (-1 = none), "at_base": bool },
##   "blue": { ... } }
var flag_states: Dictionary = {
	"red": {"position": Vector3.ZERO, "carrier_id": -1, "at_base": true},
	"blue": {"position": Vector3.ZERO, "carrier_id": -1, "at_base": true},
}

## Peer-id → PlayerCharacter node.
var player_nodes: Dictionary = {}

## Spawn positions per team — populated from scene Marker3D nodes.
var spawn_positions: Dictionary = {"red": [] as Array[Vector3], "blue": [] as Array[Vector3]}

## Flag base positions (where flags start and must be returned to).
var flag_base_positions: Dictionary = {"red": Vector3.ZERO, "blue": Vector3.ZERO}

## Per-peer sprint cooldown remaining.
var _sprint_cooldowns: Dictionary = {}

## Per-peer sprint active timer remaining.
var _sprint_active_timers: Dictionary = {}

## Per-peer smoke cooldown remaining.
var _smoke_cooldowns: Dictionary = {}

## Per-peer smoke active timer remaining.
var _smoke_active_timers: Dictionary = {}

## Timers for dropped flag auto-return (team → float seconds remaining).
var _flag_return_timers: Dictionary = {"red": -1.0, "blue": -1.0}

## FlagMarker node references per team.
var _flag_markers: Dictionary = {}

## HUD instance for the local player.
var _hud: CanvasLayer = null

## Local peer convenience cache.
var _local_peer_id: int = 0

# endregion


# region — Node References

@onready var players_node: Node3D = $Players
@onready var red_spawn_points: Node3D = $SpawnPoints/RedSpawns
@onready var blue_spawn_points: Node3D = $SpawnPoints/BlueSpawns
@onready var red_flag_spawn: Marker3D = $Field/RedBase/FlagSpawn
@onready var blue_flag_spawn: Marker3D = $Field/BlueBase/FlagSpawn
@onready var red_flag_area: Area3D = $Field/RedBase/FlagArea
@onready var blue_flag_area: Area3D = $Field/BlueBase/FlagArea
@onready var red_base_area: Area3D = $Field/RedBase/BaseArea
@onready var blue_base_area: Area3D = $Field/BlueBase/BaseArea
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner

# endregion


# region — Lifecycle

func _ready() -> void:
	_local_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	# Cache spawn positions per team.
	for child: Node in red_spawn_points.get_children():
		if child is Marker3D:
			(spawn_positions["red"] as Array[Vector3]).append((child as Marker3D).global_position)
	for child: Node in blue_spawn_points.get_children():
		if child is Marker3D:
			(spawn_positions["blue"] as Array[Vector3]).append((child as Marker3D).global_position)

	# Cache flag base positions.
	flag_base_positions["red"] = red_flag_spawn.global_position
	flag_base_positions["blue"] = blue_flag_spawn.global_position

	# Set initial flag positions.
	flag_states["red"]["position"] = flag_base_positions["red"]
	flag_states["blue"]["position"] = flag_base_positions["blue"]

	# Configure spawner.
	player_spawner.spawn_path = NodePath("../Players")
	player_spawner.add_spawnable_scene("res://characters/player_character.tscn")

	# Connect flag pickup areas.
	red_flag_area.body_entered.connect(_on_flag_area_body_entered.bind("red"))
	blue_flag_area.body_entered.connect(_on_flag_area_body_entered.bind("blue"))

	# Connect base areas (for returning / capturing).
	red_base_area.body_entered.connect(_on_base_area_body_entered.bind("red"))
	blue_base_area.body_entered.connect(_on_base_area_body_entered.bind("blue"))

	# Connect GameManager signals.
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.countdown_tick.connect(_on_countdown_tick)
	GameManager.countdown_finished.connect(_on_countdown_finished)
	GameManager.game_timer_updated.connect(_on_game_timer_updated)
	GameManager.round_ended.connect(_on_round_ended)

	# Assign teams, spawn players, create flags, setup HUD.
	_assign_teams()
	_spawn_players()
	_create_flag_markers()
	_setup_hud()

	# Server starts the 3-2-1 countdown.
	if _is_server():
		GameManager.start_countdown(3)

	AudioManager.play_music("flag_wars")


func _physics_process(delta: float) -> void:
	if not _is_server():
		return

	# Tick sprint cooldowns.
	for peer_id: int in _sprint_cooldowns.keys():
		_sprint_cooldowns[peer_id] = maxf((_sprint_cooldowns[peer_id] as float) - delta, 0.0)

	# Tick sprint active timers.
	for peer_id: int in _sprint_active_timers.keys().duplicate():
		_sprint_active_timers[peer_id] = (_sprint_active_timers[peer_id] as float) - delta
		if (_sprint_active_timers[peer_id] as float) <= 0.0:
			_end_sprint(peer_id)
			_sprint_active_timers.erase(peer_id)

	# Tick smoke cooldowns.
	for peer_id: int in _smoke_cooldowns.keys():
		_smoke_cooldowns[peer_id] = maxf((_smoke_cooldowns[peer_id] as float) - delta, 0.0)

	# Tick smoke active timers.
	for peer_id: int in _smoke_active_timers.keys().duplicate():
		_smoke_active_timers[peer_id] = (_smoke_active_timers[peer_id] as float) - delta
		if (_smoke_active_timers[peer_id] as float) <= 0.0:
			_end_smoke(peer_id)
			_smoke_active_timers.erase(peer_id)

	# Tick dropped flag return timers.
	for team: String in ["red", "blue"]:
		if (_flag_return_timers[team] as float) > 0.0:
			_flag_return_timers[team] = (_flag_return_timers[team] as float) - delta
			if (_flag_return_timers[team] as float) <= 0.0:
				_return_flag_to_base(team)

	# Update carried flag positions to follow carrier.
	for team: String in ["red", "blue"]:
		var carrier_id: int = flag_states[team]["carrier_id"] as int
		if carrier_id > 0:
			var carrier: PlayerCharacter = player_nodes.get(carrier_id) as PlayerCharacter
			if carrier and carrier.is_alive:
				flag_states[team]["position"] = carrier.global_position + Vector3(0.0, 2.5, 0.0)
				_update_flag_marker_position(team, flag_states[team]["position"] as Vector3)


func _exit_tree() -> void:
	GameManager.state_changed.disconnect(_on_state_changed)
	GameManager.countdown_tick.disconnect(_on_countdown_tick)
	GameManager.countdown_finished.disconnect(_on_countdown_finished)
	GameManager.game_timer_updated.disconnect(_on_game_timer_updated)
	GameManager.round_ended.disconnect(_on_round_ended)

	if is_instance_valid(_hud):
		_hud.queue_free()

# endregion


# region — Team Assignment

## Split players evenly into Red and Blue teams based on join order.
func _assign_teams() -> void:
	var idx: int = 0
	for peer_id: int in Lobby.players:
		if idx % 2 == 0:
			teams[peer_id] = "red"
		else:
			teams[peer_id] = "blue"
		idx += 1

## Return the opposing team name.
func _opposing_team(team: String) -> String:
	return "blue" if team == "red" else "red"

# endregion


# region — Player Spawning

func _spawn_players() -> void:
	var red_idx: int = 0
	var blue_idx: int = 0

	for peer_id: int in Lobby.players:
		var info: Dictionary = Lobby.players[peer_id]
		var character: PlayerCharacter = PLAYER_CHARACTER_SCENE.instantiate() as PlayerCharacter
		character.name = str(peer_id)

		# Determine spawn based on team.
		var team: String = teams[peer_id] as String
		var team_spawns: Array[Vector3] = spawn_positions[team] as Array[Vector3]
		var spawn_pos: Vector3

		if team == "red":
			spawn_pos = team_spawns[red_idx % team_spawns.size()]
			red_idx += 1
		else:
			spawn_pos = team_spawns[blue_idx % team_spawns.size()]
			blue_idx += 1

		character.position = spawn_pos

		# Configure authority and visuals.
		character.setup_for_authority(peer_id)
		character.set_player_name_label(info.get("name", "Player"))

		# Team colour overrides player colour.
		var team_color: Color = Color(0.9, 0.2, 0.2) if team == "red" else Color(0.2, 0.4, 0.9)
		character.set_player_color(team_color)

		# Connect signals.
		character.died.connect(_on_player_died)
		character.action_triggered.connect(_on_player_action_triggered.bind(peer_id))

		players_node.add_child(character, true)
		player_nodes[peer_id] = character

		# Init cooldown tracking.
		_sprint_cooldowns[peer_id] = 0.0
		_smoke_cooldowns[peer_id] = 0.0

# endregion


# region — Flag Markers

func _create_flag_markers() -> void:
	for team: String in ["red", "blue"]:
		var marker: Node3D = FLAG_MARKER_SCENE.instantiate()
		marker.name = "%s_flag" % team
		marker.set("team", team)
		marker.position = flag_base_positions[team]
		add_child(marker, true)
		_flag_markers[team] = marker


func _update_flag_marker_position(team: String, pos: Vector3) -> void:
	var marker: Node3D = _flag_markers.get(team) as Node3D
	if marker:
		marker.global_position = pos


func _update_flag_marker_state(team: String) -> void:
	var marker: Node3D = _flag_markers.get(team) as Node3D
	if not marker:
		return
	var state: Dictionary = flag_states[team]
	marker.set("is_at_base", state["at_base"] as bool)
	marker.set("carrier_id", state["carrier_id"] as int)
	marker.global_position = state["position"] as Vector3

# endregion


# region — HUD

func _setup_hud() -> void:
	_hud = HUD_SCENE.instantiate() as CanvasLayer
	add_child(_hud)

	# Configure action buttons — SPRINT + GRAB/DROP.
	var buttons: Array[Dictionary] = [
		{
			"text": "SPRINT",
			"color": Color(0.25, 0.6, 1.0, 0.85),
			"callback": Callable(self, "_on_sprint_pressed"),
		},
		{
			"text": "GRAB",
			"color": Color(1.0, 0.75, 0.1, 0.85),
			"callback": Callable(self, "_on_grab_drop_pressed"),
		},
	]
	_hud.set_action_buttons(buttons)

	# Connect joystick to local player movement.
	_hud.connect_joystick(Callable(self, "_on_joystick_input"))

	# Initial HUD values.
	_hud.set_timer(ROUND_DURATION)
	_update_score_hud()
	_hud.set_health(100.0, 100.0)

	# Keep local player health synced to HUD.
	var local_char: PlayerCharacter = _get_local_character()
	if local_char:
		local_char.health_changed.connect(_on_local_health_changed)


func _update_score_hud() -> void:
	if is_instance_valid(_hud):
		var text: String = "RED %d - %d BLUE" % [team_scores["red"] as int, team_scores["blue"] as int]
		_hud.set_score(0)  # Reset numeric score.
		_hud.show_message(text, 2.0)


func _update_score_hud_persistent() -> void:
	## Use the score label to display team scores.
	if is_instance_valid(_hud):
		_hud.score_label.text = "RED %d - %d BLUE" % [team_scores["red"] as int, team_scores["blue"] as int]

# endregion


# region — Input Callbacks

func _on_joystick_input(value: Vector2) -> void:
	var local_char: PlayerCharacter = _get_local_character()
	if local_char:
		local_char.set_movement_input(value)


func _on_sprint_pressed() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var local_char: PlayerCharacter = _get_local_character()
	if not local_char or not local_char.is_alive:
		return
	_request_sprint.rpc_id(1)


func _on_grab_drop_pressed() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var local_char: PlayerCharacter = _get_local_character()
	if not local_char or not local_char.is_alive:
		return
	_request_grab_drop.rpc_id(1)


func _on_player_action_triggered(peer_id: int) -> void:
	# Action button triggers grab/drop by default for this game.
	pass

# endregion


# region — Server RPCs — Actions

## Client requests sprint ability.
@rpc("any_peer", "reliable")
func _request_sprint() -> void:
	if not _is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1

	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Cooldown check.
	if (_sprint_cooldowns.get(sender_id, 0.0) as float) > 0.0:
		return

	var character: PlayerCharacter = player_nodes.get(sender_id) as PlayerCharacter
	if not character or not character.is_alive:
		return

	_sprint_cooldowns[sender_id] = SPRINT_COOLDOWN
	_sprint_active_timers[sender_id] = SPRINT_DURATION
	character.speed *= SPRINT_SPEED_MULT
	_rpc_sprint_effect.rpc(sender_id, true)
	AudioManager.play_sfx("sprint")


func _end_sprint(peer_id: int) -> void:
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if character:
		character.speed = 8.0  # Reset to default.
	_rpc_sprint_effect.rpc(peer_id, false)


@rpc("authority", "call_remote", "reliable")
func _rpc_sprint_effect(peer_id: int, active: bool) -> void:
	# Visual feedback for sprint — could add particle trail etc.
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if character and active:
		character.speed *= SPRINT_SPEED_MULT
	elif character and not active:
		character.speed = 8.0


## Client requests grab (pick up nearby flag) or drop (release carried flag).
@rpc("any_peer", "reliable")
func _request_grab_drop() -> void:
	if not _is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1

	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	var character: PlayerCharacter = player_nodes.get(sender_id) as PlayerCharacter
	if not character or not character.is_alive:
		return

	var player_team: String = teams.get(sender_id, "") as String
	if player_team.is_empty():
		return

	# Check if player is carrying a flag — if so, drop it.
	var enemy_team: String = _opposing_team(player_team)
	if (flag_states[enemy_team]["carrier_id"] as int) == sender_id:
		_drop_flag(enemy_team, character.global_position)
		return

	# Otherwise try to pick up a nearby enemy flag.
	_try_pickup_flag(sender_id, player_team, character.global_position)


## Client requests smoke ability.
@rpc("any_peer", "reliable")
func _request_smoke() -> void:
	if not _is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1

	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	if (_smoke_cooldowns.get(sender_id, 0.0) as float) > 0.0:
		return

	var character: PlayerCharacter = player_nodes.get(sender_id) as PlayerCharacter
	if not character or not character.is_alive:
		return

	_smoke_cooldowns[sender_id] = SMOKE_COOLDOWN
	_smoke_active_timers[sender_id] = SMOKE_DURATION
	_rpc_smoke_effect.rpc(sender_id, true)
	AudioManager.play_sfx("smoke")


func _end_smoke(peer_id: int) -> void:
	_rpc_smoke_effect.rpc(peer_id, false)


@rpc("authority", "call_local", "reliable")
func _rpc_smoke_effect(peer_id: int, active: bool) -> void:
	# Visual: could hide player blip on minimap. For now, just feedback.
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if not character:
		return
	if active:
		character.modulate = Color(1.0, 1.0, 1.0, 0.3)
	else:
		character.modulate = Color.WHITE

# endregion


# region — Flag Logic (Server)

## Attempt to pick up the enemy flag.
func _try_pickup_flag(peer_id: int, player_team: String, player_pos: Vector3) -> void:
	var enemy_team: String = _opposing_team(player_team)
	var state: Dictionary = flag_states[enemy_team]

	# Can only pick up if nobody else is carrying it.
	if (state["carrier_id"] as int) != -1:
		return

	# Distance check.
	var flag_pos: Vector3 = state["position"] as Vector3
	if player_pos.distance_to(flag_pos) > FLAG_PICKUP_RADIUS:
		return

	# Pick it up.
	_pickup_flag(enemy_team, peer_id)


func _pickup_flag(team: String, carrier_peer_id: int) -> void:
	flag_states[team]["carrier_id"] = carrier_peer_id
	flag_states[team]["at_base"] = false
	_flag_return_timers[team] = -1.0  # Cancel any pending return.

	_update_flag_marker_state(team)
	_rpc_flag_picked_up.rpc(team, carrier_peer_id)

	var carrier_name: String = Lobby.players.get(carrier_peer_id, {}).get("name", "Player") as String
	var team_upper: String = team.to_upper()
	_rpc_event_feed.rpc("%s grabbed the %s flag!" % [carrier_name, team_upper], Color.YELLOW)
	AudioManager.play_sfx("flag_grab")


func _drop_flag(team: String, drop_pos: Vector3) -> void:
	var carrier_id: int = flag_states[team]["carrier_id"] as int
	flag_states[team]["carrier_id"] = -1
	flag_states[team]["position"] = drop_pos
	flag_states[team]["at_base"] = false
	_flag_return_timers[team] = FLAG_RETURN_DELAY

	_update_flag_marker_state(team)
	_rpc_flag_dropped.rpc(team, drop_pos)

	var dropper_name: String = "Unknown"
	if carrier_id > 0:
		dropper_name = Lobby.players.get(carrier_id, {}).get("name", "Player") as String
	_rpc_event_feed.rpc("%s dropped the %s flag!" % [dropper_name, team.to_upper()], Color.ORANGE)
	AudioManager.play_sfx("flag_drop")


func _return_flag_to_base(team: String) -> void:
	flag_states[team]["carrier_id"] = -1
	flag_states[team]["position"] = flag_base_positions[team]
	flag_states[team]["at_base"] = true
	_flag_return_timers[team] = -1.0

	_update_flag_marker_state(team)
	_rpc_flag_returned.rpc(team)
	_rpc_event_feed.rpc("The %s flag has returned to base!" % team.to_upper(), Color.WHITE)
	AudioManager.play_sfx("flag_return")


func _capture_flag(capturing_team: String) -> void:
	var enemy_team: String = _opposing_team(capturing_team)

	# Return the enemy flag to its base.
	_return_flag_to_base(enemy_team)

	# Increment score.
	team_scores[capturing_team] = (team_scores[capturing_team] as int) + 1

	# Award lobby score to the capturing carrier.
	var carrier_id: int = -1
	# The carrier was just cleared by _return_flag_to_base, but we can
	# reconstruct from the RPC call context. We store it before returning.
	# Actually, let's refactor: we call _capture_flag before _return_flag_to_base.
	# (Handled by the caller.)

	_rpc_flag_captured.rpc(capturing_team, team_scores["red"] as int, team_scores["blue"] as int)
	_rpc_event_feed.rpc("%s team SCORES! (%d - %d)" % [
		capturing_team.to_upper(),
		team_scores["red"] as int,
		team_scores["blue"] as int,
	], Color.GREEN)
	AudioManager.play_sfx("flag_capture")

	# Check win condition.
	if (team_scores[capturing_team] as int) >= CAPTURES_TO_WIN:
		_end_round()

# endregion


# region — Area3D Callbacks (Server)

func _on_flag_area_body_entered(body: Node3D, flag_team: String) -> void:
	if not _is_server():
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if not body is CharacterBody3D:
		return

	var peer_id: int = _peer_id_from_body(body)
	if peer_id == 0:
		return

	var player_team: String = teams.get(peer_id, "") as String
	if player_team.is_empty():
		return

	# Can only pick up the ENEMY flag.
	if player_team == flag_team:
		return

	# Only if flag is at base or on ground (not carried).
	var state: Dictionary = flag_states[flag_team]
	if (state["carrier_id"] as int) != -1:
		return

	_pickup_flag(flag_team, peer_id)


func _on_base_area_body_entered(body: Node3D, base_team: String) -> void:
	if not _is_server():
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if not body is CharacterBody3D:
		return

	var peer_id: int = _peer_id_from_body(body)
	if peer_id == 0:
		return

	var player_team: String = teams.get(peer_id, "") as String
	if player_team.is_empty():
		return

	# Only interact with your OWN base.
	if player_team != base_team:
		return

	# Check if this player is carrying the enemy flag.
	var enemy_team: String = _opposing_team(player_team)
	if (flag_states[enemy_team]["carrier_id"] as int) != peer_id:
		return

	# CAPTURE! Award score before returning flag.
	Lobby.add_score(peer_id, CAPTURE_SCORE)
	var carrier_name: String = Lobby.players.get(peer_id, {}).get("name", "Player") as String
	_capture_flag(player_team)

# endregion


# region — Flag Sync RPCs

@rpc("authority", "call_local", "reliable")
func _rpc_flag_picked_up(team: String, carrier_peer_id: int) -> void:
	flag_states[team]["carrier_id"] = carrier_peer_id
	flag_states[team]["at_base"] = false
	_update_flag_marker_state(team)


@rpc("authority", "call_local", "reliable")
func _rpc_flag_dropped(team: String, drop_pos: Vector3) -> void:
	flag_states[team]["carrier_id"] = -1
	flag_states[team]["position"] = drop_pos
	flag_states[team]["at_base"] = false
	_update_flag_marker_state(team)


@rpc("authority", "call_local", "reliable")
func _rpc_flag_returned(team: String) -> void:
	flag_states[team]["carrier_id"] = -1
	flag_states[team]["position"] = flag_base_positions[team]
	flag_states[team]["at_base"] = true
	_update_flag_marker_state(team)


@rpc("authority", "call_local", "reliable")
func _rpc_flag_captured(capturing_team: String, red_score: int, blue_score: int) -> void:
	team_scores["red"] = red_score
	team_scores["blue"] = blue_score
	_update_score_hud_persistent()


@rpc("authority", "call_local", "reliable")
func _rpc_event_feed(text: String, color: Color) -> void:
	if is_instance_valid(_hud):
		_hud.add_kill_feed_entry(text, color)


@rpc("authority", "call_local", "reliable")
func _rpc_update_team_scores(red_score: int, blue_score: int) -> void:
	team_scores["red"] = red_score
	team_scores["blue"] = blue_score
	_update_score_hud_persistent()

# endregion


# region — Combat Events

func _on_player_died(peer_id: int) -> void:
	if not _is_server():
		return

	var player_team: String = teams.get(peer_id, "") as String
	var victim_name: String = Lobby.players.get(peer_id, {}).get("name", "Player") as String

	# If the dead player was carrying a flag, drop it.
	for team: String in ["red", "blue"]:
		if (flag_states[team]["carrier_id"] as int) == peer_id:
			var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
			var drop_pos: Vector3 = character.global_position if character else flag_base_positions[team]
			_drop_flag(team, drop_pos)
			break

	_rpc_event_feed.rpc("%s was eliminated!" % victim_name, Color.RED)

	# Schedule respawn at team base.
	_start_respawn_timer(peer_id)


## Called externally when a player tags an enemy flag carrier (e.g. melee range).
func register_tag(tagger_peer_id: int, victim_peer_id: int) -> void:
	if not _is_server():
		return
	if tagger_peer_id == victim_peer_id:
		return

	var tagger_team: String = teams.get(tagger_peer_id, "") as String
	var victim_team: String = teams.get(victim_peer_id, "") as String

	# Can only tag enemies.
	if tagger_team == victim_team:
		return

	# Check if victim is carrying tagger's flag.
	if (flag_states[tagger_team]["carrier_id"] as int) == victim_peer_id:
		Lobby.add_score(tagger_peer_id, TAG_SCORE)

		var victim_char: PlayerCharacter = player_nodes.get(victim_peer_id) as PlayerCharacter
		if victim_char:
			victim_char.take_damage(100.0, tagger_peer_id)

		var tagger_name: String = Lobby.players.get(tagger_peer_id, {}).get("name", "Player") as String
		var victim_name: String = Lobby.players.get(victim_peer_id, {}).get("name", "Player") as String
		_rpc_event_feed.rpc("%s tagged %s!" % [tagger_name, victim_name], Color.YELLOW)
		AudioManager.play_sfx("tag")

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

	var player_team: String = teams.get(peer_id, "") as String
	var spawn_pos: Vector3 = _get_team_spawn_position(player_team)
	character.respawn(spawn_pos)
	_rpc_respawn_player.rpc(peer_id, spawn_pos)


@rpc("authority", "call_remote", "reliable")
func _rpc_respawn_player(peer_id: int, pos: Vector3) -> void:
	var character: PlayerCharacter = player_nodes.get(peer_id) as PlayerCharacter
	if character:
		character.respawn(pos)

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

	# Server: end round when timer runs out.
	if _is_server() and time_remaining <= 0.0:
		_end_round()


func _on_round_ended(results: Array) -> void:
	if is_instance_valid(_hud):
		var winning_team: String = "TIE"
		if (team_scores["red"] as int) > (team_scores["blue"] as int):
			winning_team = "RED"
		elif (team_scores["blue"] as int) > (team_scores["red"] as int):
			winning_team = "BLUE"
		_hud.show_message("Round Over! %s wins!" % winning_team, 3.0)

# endregion


# region — Round End / Results

func _end_round() -> void:
	if not _is_server():
		return

	var results: Array = []
	var winning_team: String = ""
	if (team_scores["red"] as int) > (team_scores["blue"] as int):
		winning_team = "red"
	elif (team_scores["blue"] as int) > (team_scores["red"] as int):
		winning_team = "blue"

	# Build results — winning team members ranked higher.
	var winners: Array[Dictionary] = []
	var losers: Array[Dictionary] = []
	var tied: Array[Dictionary] = []

	for peer_id: int in teams:
		var player_team: String = teams[peer_id] as String
		var entry: Dictionary = {
			"peer_id": peer_id,
			"score": team_scores.get(player_team, 0) as int,
			"team": player_team,
			"placement": 0,
		}
		if winning_team.is_empty():
			tied.append(entry)
		elif player_team == winning_team:
			winners.append(entry)
		else:
			losers.append(entry)

	var placement: int = 1
	if winning_team.is_empty():
		# Tie — everyone gets same placement.
		for entry: Dictionary in tied:
			entry["placement"] = 1
			results.append(entry)
	else:
		for entry: Dictionary in winners:
			entry["placement"] = placement
			results.append(entry)
		placement = winners.size() + 1
		for entry: Dictionary in losers:
			entry["placement"] = placement
			results.append(entry)

	GameManager.end_round(results)


func _show_results() -> void:
	if is_instance_valid(_hud):
		_hud.show_message("Match Complete!", 3.0)

# endregion


# region — Health HUD Sync

func _on_local_health_changed(new_health: float, max_health: float) -> void:
	if is_instance_valid(_hud):
		_hud.set_health(new_health, max_health)

# endregion


# region — Helpers

func _get_local_character() -> PlayerCharacter:
	return player_nodes.get(_local_peer_id) as PlayerCharacter


func _get_team_spawn_position(team: String) -> Vector3:
	var team_spawns: Array[Vector3] = spawn_positions.get(team, []) as Array[Vector3]
	if team_spawns.is_empty():
		return Vector3(0.0, 1.0, 0.0)
	return team_spawns[randi() % team_spawns.size()]


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
