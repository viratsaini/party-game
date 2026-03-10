## GameManager Autoload Singleton
##
## Orchestrates the mini-game lifecycle for BattleZone Party.
## Server-authoritative state machine that manages game registration,
## countdown synchronization, match timers, and round/match flow.
##
## State flow: MENU → LOBBY → LOADING → COUNTDOWN → PLAYING → ROUND_END → RESULTS → LOBBY
extends Node


# region — Enums

## All possible states in the game lifecycle.
enum GameState {
	MENU,
	LOBBY,
	LOADING,
	COUNTDOWN,
	PLAYING,
	ROUND_END,
	RESULTS,
}

# endregion


# region — Signals

## Emitted whenever the state machine transitions.
signal state_changed(old_state: int, new_state: int)

## Emitted each second during the pre-game countdown (3-2-1).
signal countdown_tick(seconds_left: int)

## Emitted when the countdown reaches zero.
signal countdown_finished()

## Emitted every frame while the match timer is running.
signal game_timer_updated(time_remaining: float)

## Emitted when a single round ends with per-player results.
signal round_ended(results: Array)

## Emitted when the entire match ends with final standings.
signal match_ended(final_results: Array)

# endregion


# region — Constants

## Valid state transitions. Key = origin state, Value = array of allowed targets.
const VALID_TRANSITIONS: Dictionary = {
	GameState.MENU:      [GameState.LOBBY],
	GameState.LOBBY:     [GameState.LOADING, GameState.MENU],
	GameState.LOADING:   [GameState.COUNTDOWN, GameState.LOBBY],
	GameState.COUNTDOWN: [GameState.PLAYING, GameState.LOBBY],
	GameState.PLAYING:   [GameState.ROUND_END, GameState.LOBBY],
	GameState.ROUND_END: [GameState.COUNTDOWN, GameState.PLAYING, GameState.RESULTS, GameState.LOBBY],
	GameState.RESULTS:   [GameState.LOBBY],
}

## Human-readable names for each state (useful for debugging / UI).
const STATE_NAMES: Dictionary = {
	GameState.MENU:      "MENU",
	GameState.LOBBY:     "LOBBY",
	GameState.LOADING:   "LOADING",
	GameState.COUNTDOWN: "COUNTDOWN",
	GameState.PLAYING:   "PLAYING",
	GameState.ROUND_END: "ROUND_END",
	GameState.RESULTS:   "RESULTS",
}

# endregion


# region — Game Registry

## Registry of available mini-games. Key = game id (String), Value = Dictionary.
## Each entry: {id, name, description, scene_path, icon_path, min_players, max_players, supported_modes}
var _game_registry: Dictionary = {}

# endregion


# region — Current Game State

## The id of the currently selected game (empty when none).
var current_game_id: String = ""

## The currently selected mode for the active game (e.g. "ffa", "race").
var current_mode: String = ""

## The active state in the lifecycle state machine.
var current_state: GameState = GameState.MENU

## Current round number (1-indexed). Reset when a new match starts.
var round_number: int = 0

## Maximum number of rounds for the current match.
var max_rounds: int = 3

## Time remaining on the match timer (seconds). Only ticks while PLAYING.
var game_timer: float = 0.0

## Accumulated results for each completed round.
## Each element: {peer_id: int, score: int, placement: int}
var round_results: Array = []

# endregion


# region — Internal

## Whether the match timer is actively counting down.
var _timer_running: bool = false

## Remaining seconds in the pre-game countdown (3-2-1).
var _countdown_seconds: int = 0

## Whether a countdown sequence is currently in progress.
var _countdown_active: bool = false

## Internal accumulator for the once-per-second countdown tick.
var _countdown_accumulator: float = 0.0

# endregion


# region — Lifecycle

func _ready() -> void:
	_register_default_games()


func _process(delta: float) -> void:
	_process_game_timer(delta)
	_process_countdown(delta)

# endregion


# region — Default Game Registration

## Registers the five built-in mini-games.
func _register_default_games() -> void:
	register_game({
		"id": "arena_blaster",
		"name": "Arena Blaster",
		"description": "Fast-paced arena shooter with power-ups and destructible cover.",
		"scene_path": "res://games/arena_blaster/arena_blaster.tscn",
		"icon_path": "",
		"min_players": 2,
		"max_players": 8,
		"supported_modes": ["ffa", "teams"] as Array[String],
	})

	register_game({
		"id": "turbo_karts",
		"name": "Turbo Karts",
		"description": "High-speed kart racing with boosts, traps, and shortcuts.",
		"scene_path": "res://games/turbo_karts/turbo_karts.tscn",
		"icon_path": "",
		"min_players": 2,
		"max_players": 8,
		"supported_modes": ["race", "elimination"] as Array[String],
	})

	register_game({
		"id": "obstacle_royale",
		"name": "Obstacle Royale",
		"description": "Navigate deadly obstacle courses — last one standing wins.",
		"scene_path": "res://games/obstacle_royale/obstacle_royale.tscn",
		"icon_path": "",
		"min_players": 2,
		"max_players": 8,
		"supported_modes": ["rounds", "survival"] as Array[String],
	})

	register_game({
		"id": "flag_wars",
		"name": "Flag Wars",
		"description": "Capture enemy flags while defending your own in team-based chaos.",
		"scene_path": "res://games/flag_wars/flag_wars.tscn",
		"icon_path": "",
		"min_players": 4,
		"max_players": 8,
		"supported_modes": ["classic", "multi_flag"] as Array[String],
	})

	register_game({
		"id": "crash_derby",
		"name": "Crash Derby",
		"description": "Vehicular destruction in a shrinking arena. Smash or be smashed.",
		"scene_path": "res://games/crash_derby/crash_derby.tscn",
		"icon_path": "",
		"min_players": 2,
		"max_players": 8,
		"supported_modes": ["last_standing", "points"] as Array[String],
	})

# endregion


# region — Game Registry API

## Registers (or overwrites) a mini-game in the registry.
## [param game_info] must contain at minimum: id, name, scene_path, min_players, max_players, supported_modes.
func register_game(game_info: Dictionary) -> void:
	var required_keys: Array[String] = [
		"id", "name", "scene_path", "min_players", "max_players", "supported_modes",
	]
	for key: String in required_keys:
		if not game_info.has(key):
			push_error("GameManager.register_game(): Missing required key '%s'." % key)
			return

	var id: String = game_info["id"]
	if _game_registry.has(id):
		push_warning("GameManager.register_game(): Overwriting existing game '%s'." % id)

	# Ensure optional keys have defaults.
	if not game_info.has("description"):
		game_info["description"] = ""
	if not game_info.has("icon_path"):
		game_info["icon_path"] = ""

	_game_registry[id] = game_info


## Returns an array of all registered game dictionaries.
func get_available_games() -> Array[Dictionary]:
	var games: Array[Dictionary] = []
	for key: String in _game_registry:
		games.append(_game_registry[key])
	return games


## Returns the info dictionary for a specific game, or an empty Dictionary if not found.
func get_game_info(game_id: String) -> Dictionary:
	if _game_registry.has(game_id):
		return _game_registry[game_id]
	push_warning("GameManager.get_game_info(): Unknown game id '%s'." % game_id)
	return {}

# endregion


# region — State Machine

## Returns the current lifecycle state.
func get_state() -> GameState:
	return current_state


## Returns [code]true[/code] when the game is in a playable state (COUNTDOWN or PLAYING).
func is_game_active() -> bool:
	return current_state == GameState.COUNTDOWN or current_state == GameState.PLAYING


## Attempts a state transition. Only the server (multiplayer authority) may call this.
## Invalid transitions are rejected with an error.
func transition_to(new_state: GameState) -> void:
	if not _is_server():
		push_error("GameManager.transition_to(): Only the server can change states.")
		return

	if not _is_valid_transition(current_state, new_state):
		push_error(
			"GameManager.transition_to(): Invalid transition %s → %s."
			% [STATE_NAMES.get(current_state, "?"), STATE_NAMES.get(new_state, "?")]
		)
		return

	var old_state: GameState = current_state
	current_state = new_state
	_on_state_entered(new_state)
	state_changed.emit(old_state, new_state)
	_rpc_sync_state.rpc(old_state, new_state)


## Validates whether a transition from [param from] to [param to] is allowed.
func _is_valid_transition(from: GameState, to: GameState) -> bool:
	if VALID_TRANSITIONS.has(from):
		return to in (VALID_TRANSITIONS[from] as Array)
	return false


## Hook called on the server immediately after entering [param new_state].
func _on_state_entered(new_state: GameState) -> void:
	match new_state:
		GameState.LOADING:
			_load_current_game()
		GameState.RESULTS:
			_timer_running = false
			_countdown_active = false
		GameState.LOBBY:
			_reset_match_state()
		_:
			pass


## Syncs a state transition to all clients via RPC.
@rpc("authority", "call_remote", "reliable")
func _rpc_sync_state(old_state: int, new_state: int) -> void:
	current_state = new_state as GameState
	state_changed.emit(old_state, new_state)

# endregion


# region — Game Selection

## Selects the game and mode for the upcoming match. Server-only.
func set_current_game(game_id: String, mode: String) -> void:
	if not _is_server():
		push_error("GameManager.set_current_game(): Only the server can select games.")
		return

	var info: Dictionary = get_game_info(game_id)
	if info.is_empty():
		push_error("GameManager.set_current_game(): Unknown game '%s'." % game_id)
		return

	var modes: Array = info.get("supported_modes", [])
	if mode not in modes:
		push_error(
			"GameManager.set_current_game(): Mode '%s' not supported by '%s'. Available: %s"
			% [mode, game_id, str(modes)]
		)
		return

	current_game_id = game_id
	current_mode = mode
	_rpc_sync_game_selection.rpc(game_id, mode)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_game_selection(game_id: String, mode: String) -> void:
	current_game_id = game_id
	current_mode = mode

# endregion


# region — Scene Loading

## Initiates loading for the currently selected game scene (server-side).
func _load_current_game() -> void:
	var info: Dictionary = get_game_info(current_game_id)
	if info.is_empty():
		push_error("GameManager._load_current_game(): No game selected.")
		transition_to(GameState.LOBBY)
		return

	var scene_path: String = info["scene_path"]
	if not ResourceLoader.exists(scene_path):
		push_error("GameManager._load_current_game(): Scene not found at '%s'." % scene_path)
		transition_to(GameState.LOBBY)
		return

	# For a real project you'd use ResourceLoader.load_threaded_request() here.
	# Simplified: change scene and move to COUNTDOWN once ready.
	get_tree().change_scene_to_file(scene_path)
	# Allow one frame for the scene to initialise before transitioning.
	await get_tree().process_frame
	transition_to(GameState.COUNTDOWN)

# endregion


# region — Countdown

## Starts a synchronised countdown (3-2-1-GO) across all peers. Server-only.
## [param seconds] Number of seconds to count down (default 3).
func start_countdown(seconds: int = 3) -> void:
	if not _is_server():
		push_error("GameManager.start_countdown(): Only the server can start countdowns.")
		return

	if current_state != GameState.COUNTDOWN:
		push_error("GameManager.start_countdown(): Must be in COUNTDOWN state.")
		return

	_begin_countdown(seconds)
	_rpc_start_countdown.rpc(seconds)


@rpc("authority", "call_remote", "reliable")
func _rpc_start_countdown(seconds: int) -> void:
	_begin_countdown(seconds)


## Internal: sets up local countdown variables.
func _begin_countdown(seconds: int) -> void:
	_countdown_seconds = seconds
	_countdown_accumulator = 0.0
	_countdown_active = true
	countdown_tick.emit(_countdown_seconds)


## Processes the countdown each frame, emitting [signal countdown_tick] every second.
func _process_countdown(delta: float) -> void:
	if not _countdown_active:
		return

	_countdown_accumulator += delta
	if _countdown_accumulator >= 1.0:
		_countdown_accumulator -= 1.0
		_countdown_seconds -= 1

		if _countdown_seconds > 0:
			countdown_tick.emit(_countdown_seconds)
		else:
			_countdown_active = false
			countdown_finished.emit()
			# Server transitions to PLAYING after countdown.
			if _is_server():
				transition_to(GameState.PLAYING)

# endregion


# region — Game Timer

## Starts the in-match timer. Server-only, runs while in PLAYING state.
## [param seconds] Duration of the round / match in seconds.
func start_game_timer(seconds: float) -> void:
	if not _is_server():
		push_error("GameManager.start_game_timer(): Only the server can start the timer.")
		return

	if current_state != GameState.PLAYING:
		push_error("GameManager.start_game_timer(): Must be in PLAYING state.")
		return

	game_timer = seconds
	_timer_running = true
	_rpc_sync_game_timer.rpc(seconds)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_game_timer(seconds: float) -> void:
	game_timer = seconds
	_timer_running = true


## Ticks the match timer and emits updates / expiry.
func _process_game_timer(delta: float) -> void:
	if not _timer_running:
		return
	if current_state != GameState.PLAYING:
		return

	game_timer -= delta
	if game_timer <= 0.0:
		game_timer = 0.0
		_timer_running = false
		game_timer_updated.emit(game_timer)
		# Server decides what happens when time runs out.
		if _is_server():
			end_round(round_results.duplicate())
	else:
		game_timer_updated.emit(game_timer)

# endregion


# region — Round & Match Flow

## Called by the active mini-game when a round ends.
## [param results] Array of {peer_id: int, score: int, placement: int}.
func end_round(results: Array) -> void:
	if not _is_server():
		push_error("GameManager.end_round(): Only the server can end a round.")
		return

	if current_state != GameState.PLAYING:
		push_error("GameManager.end_round(): Must be in PLAYING state.")
		return

	_timer_running = false
	round_results = results.duplicate()
	round_number += 1
	transition_to(GameState.ROUND_END)
	round_ended.emit(results)
	_rpc_sync_round_end.rpc(results, round_number)

	# If we've reached max rounds, finish the match automatically.
	if round_number >= max_rounds:
		end_match(results)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_round_end(results: Array, round_num: int) -> void:
	round_results = results.duplicate()
	round_number = round_num
	round_ended.emit(results)


## Ends the entire match and shows the results screen.
## [param final_results] The final standings array.
func end_match(final_results: Array) -> void:
	if not _is_server():
		push_error("GameManager.end_match(): Only the server can end a match.")
		return

	# Ensure we can reach RESULTS (from ROUND_END or PLAYING via ROUND_END).
	if current_state == GameState.PLAYING:
		# Force through ROUND_END first.
		current_state = GameState.ROUND_END

	transition_to(GameState.RESULTS)
	match_ended.emit(final_results)
	_rpc_sync_match_end.rpc(final_results)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_match_end(final_results: Array) -> void:
	match_ended.emit(final_results)


## Returns all peers to the lobby. Server-only RPC scene change.
func return_to_lobby() -> void:
	if not _is_server():
		push_error("GameManager.return_to_lobby(): Only the server can return to lobby.")
		return

	transition_to(GameState.LOBBY)
	_rpc_return_to_lobby.rpc()


@rpc("authority", "call_remote", "reliable")
func _rpc_return_to_lobby() -> void:
	_reset_match_state()
	get_tree().change_scene_to_file("res://ui/character_select/character_select.tscn")

# endregion


# region — Internal Helpers

## Resets all per-match state variables so a fresh match can begin.
func _reset_match_state() -> void:
	current_game_id = ""
	current_mode = ""
	round_number = 0
	game_timer = 0.0
	_timer_running = false
	_countdown_active = false
	_countdown_seconds = 0
	_countdown_accumulator = 0.0
	round_results.clear()


## Returns [code]true[/code] if this peer is the multiplayer server (or if
## multiplayer is not initialised, treats the local instance as the authority).
func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
