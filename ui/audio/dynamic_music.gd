## DynamicMusic - Layered dynamic music system for BattleZone Party.
##
## Provides a sophisticated music system with layered tracks, intensity-based
## crossfading, context-aware transitions, and seamless music state changes
## for menus, gameplay, victory, defeat, and ambient situations.
class_name DynamicMusic
extends Node


# -- Signals --

## Emitted when the music state changes.
signal state_changed(old_state: MusicState, new_state: MusicState)

## Emitted when intensity level changes.
signal intensity_changed(old_intensity: float, new_intensity: float)

## Emitted when a music layer is activated/deactivated.
signal layer_changed(layer_name: String, active: bool)

## Emitted when a stinger plays.
signal stinger_played(stinger_name: String)

## Emitted on each beat (for UI sync).
signal beat_pulse(beat_number: int, measure: int)

## Emitted when music transitions.
signal transition_started(from_state: MusicState, to_state: MusicState)
signal transition_completed(new_state: MusicState)


# -- Enums --

## High-level music states.
enum MusicState {
	NONE,
	MENU,
	LOBBY,
	LOADING,
	GAMEPLAY_CALM,
	GAMEPLAY_ACTION,
	GAMEPLAY_INTENSE,
	BOSS,
	VICTORY,
	DEFEAT,
	AMBIENT,
	COUNTDOWN,
	OVERTIME,
	RESULTS,
}

## Music layer types for vertical mixing.
enum LayerType {
	BASE,           ## Always playing when state is active
	PERCUSSION,     ## Drums and rhythm
	MELODY,         ## Lead instruments
	ATMOSPHERE,     ## Pads and ambience
	TENSION,        ## Builds drama
	ACTION,         ## Combat intensity
	STINGER,        ## Short impact sounds
	TRANSITION,     ## Crossfade elements
}


# -- Constants --

## Default BPM for beat sync.
const DEFAULT_BPM: float = 120.0

## Standard crossfade duration.
const DEFAULT_CROSSFADE: float = 2.0

## Intensity thresholds for automatic layer control.
const INTENSITY_LOW: float = 0.25
const INTENSITY_MEDIUM: float = 0.5
const INTENSITY_HIGH: float = 0.75


# -- Exports --

@export_group("Music Configuration")

## Current BPM for beat synchronization.
@export_range(60, 200, 1) var bpm: float = DEFAULT_BPM

## Beats per measure for beat tracking.
@export_range(2, 8, 1) var beats_per_measure: int = 4

## Enable beat-synced transitions.
@export var beat_synced_transitions: bool = true

## Crossfade duration for state transitions.
@export_range(0.0, 5.0, 0.1) var crossfade_duration: float = DEFAULT_CROSSFADE

@export_group("Layer Configuration")

## Enable layer system (vertical mixing).
@export var layers_enabled: bool = true

## Number of intensity levels for automatic layer control.
@export_range(2, 5, 1) var intensity_levels: int = 3

## Fade duration for individual layers.
@export_range(0.1, 3.0, 0.1) var layer_fade_duration: float = 0.5

@export_group("Intensity System")

## Current music intensity (0-1).
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.0

## How quickly intensity decays when no events occur.
@export_range(0.0, 1.0, 0.01) var intensity_decay_rate: float = 0.1

## Minimum intensity event to register.
@export_range(0.0, 0.5, 0.01) var intensity_threshold: float = 0.05


# -- State --

## Current music state.
var _current_state: MusicState = MusicState.NONE

## Target state for transitions.
var _target_state: MusicState = MusicState.NONE

## Whether we're currently transitioning.
var _is_transitioning: bool = false

## Active music tracks per layer.
var _active_layers: Dictionary = {}  # LayerType -> AudioStreamPlayer

## Layer configurations.
var _layer_configs: Dictionary = {}  # LayerType -> LayerConfig

## State configurations.
var _state_configs: Dictionary = {}  # MusicState -> StateConfig

## Stinger sounds.
var _stingers: Dictionary = {}  # String -> AudioStream

## Beat tracking state.
var _beat_timer: float = 0.0
var _current_beat: int = 0
var _current_measure: int = 0

## Intensity tracking.
var _target_intensity: float = 0.0
var _intensity_events: Array[float] = []

## Audio stream players for layers.
var _layer_players: Dictionary = {}  # LayerType -> AudioStreamPlayer

## Transition tween.
var _transition_tween: Tween = null


# -- Configuration Classes --

class LayerConfig extends RefCounted:
	var stream: AudioStream = null
	var volume_db: float = 0.0
	var intensity_min: float = 0.0    ## Layer activates above this intensity
	var intensity_max: float = 1.0    ## Layer fades out above this
	var layer_type: int = LayerType.BASE
	var bus: String = "Music"
	var loop: bool = true
	var sync_to_base: bool = true     ## Keep in sync with base layer


class StateConfig extends RefCounted:
	var layers: Dictionary = {}       ## LayerType -> LayerConfig
	var base_intensity: float = 0.0   ## Starting intensity for this state
	var allow_intensity_changes: bool = true
	var transition_stinger: String = ""  ## Stinger to play on transition
	var next_state: int = -1          ## Auto-transition to this state
	var next_state_delay: float = 0.0


# -- Lifecycle --

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_layer_players()
	_register_default_states()
	_register_default_stingers()


func _process(delta: float) -> void:
	_update_beat_tracking(delta)
	_update_intensity(delta)
	_update_layers(delta)


# -- Initialization --

func _create_layer_players() -> void:
	for layer_type: int in LayerType.values():
		var player := AudioStreamPlayer.new()
		player.name = "MusicLayer_%d" % layer_type
		player.bus = AudioManager.BUS_MUSIC
		player.volume_db = -80.0  # Start silent
		add_child(player)
		_layer_players[layer_type] = player


func _register_default_states() -> void:
	# Menu state - calm, melodic
	var menu_config := StateConfig.new()
	menu_config.base_intensity = 0.2
	menu_config.allow_intensity_changes = false
	_state_configs[MusicState.MENU] = menu_config

	# Lobby state - building anticipation
	var lobby_config := StateConfig.new()
	lobby_config.base_intensity = 0.3
	lobby_config.allow_intensity_changes = true
	_state_configs[MusicState.LOBBY] = lobby_config

	# Loading state - ambient tension
	var loading_config := StateConfig.new()
	loading_config.base_intensity = 0.4
	loading_config.allow_intensity_changes = false
	_state_configs[MusicState.LOADING] = loading_config

	# Gameplay calm - low tension
	var gameplay_calm := StateConfig.new()
	gameplay_calm.base_intensity = 0.3
	gameplay_calm.allow_intensity_changes = true
	_state_configs[MusicState.GAMEPLAY_CALM] = gameplay_calm

	# Gameplay action - medium tension
	var gameplay_action := StateConfig.new()
	gameplay_action.base_intensity = 0.6
	gameplay_action.allow_intensity_changes = true
	_state_configs[MusicState.GAMEPLAY_ACTION] = gameplay_action

	# Gameplay intense - high tension
	var gameplay_intense := StateConfig.new()
	gameplay_intense.base_intensity = 0.9
	gameplay_intense.allow_intensity_changes = true
	gameplay_intense.transition_stinger = "combat_escalate"
	_state_configs[MusicState.GAMEPLAY_INTENSE] = gameplay_intense

	# Victory state - triumphant
	var victory_config := StateConfig.new()
	victory_config.base_intensity = 0.7
	victory_config.allow_intensity_changes = false
	victory_config.transition_stinger = "victory"
	_state_configs[MusicState.VICTORY] = victory_config

	# Defeat state - somber
	var defeat_config := StateConfig.new()
	defeat_config.base_intensity = 0.4
	defeat_config.allow_intensity_changes = false
	defeat_config.transition_stinger = "defeat"
	_state_configs[MusicState.DEFEAT] = defeat_config

	# Countdown state - building tension
	var countdown_config := StateConfig.new()
	countdown_config.base_intensity = 0.5
	countdown_config.allow_intensity_changes = true
	_state_configs[MusicState.COUNTDOWN] = countdown_config

	# Overtime state - maximum tension
	var overtime_config := StateConfig.new()
	overtime_config.base_intensity = 1.0
	overtime_config.allow_intensity_changes = false
	overtime_config.transition_stinger = "overtime"
	_state_configs[MusicState.OVERTIME] = overtime_config

	# Results state - relaxed
	var results_config := StateConfig.new()
	results_config.base_intensity = 0.3
	results_config.allow_intensity_changes = false
	_state_configs[MusicState.RESULTS] = results_config


func _register_default_stingers() -> void:
	# Register stinger sound effects
	# These would be loaded from audio files in production
	# _stingers["victory"] = preload("res://audio/stingers/victory.ogg")
	# _stingers["defeat"] = preload("res://audio/stingers/defeat.ogg")
	# etc.
	pass


# -- Public API: State Control --

## Change to a new music state with crossfade.
func set_state(new_state: MusicState, instant: bool = false) -> void:
	if new_state == _current_state and not _is_transitioning:
		return

	var old_state := _current_state
	_target_state = new_state

	if instant:
		_instant_transition(new_state)
	else:
		_start_transition(old_state, new_state)


## Get the current music state.
func get_state() -> MusicState:
	return _current_state


## Check if currently transitioning.
func is_transitioning() -> bool:
	return _is_transitioning


## Set state by name (convenience method).
func set_state_name(state_name: String, instant: bool = false) -> void:
	var state := _name_to_state(state_name)
	if state >= 0:
		set_state(state, instant)


# -- Public API: Intensity Control --

## Add intensity from a gameplay event.
func add_intensity(amount: float) -> void:
	if amount < intensity_threshold:
		return

	_target_intensity = clampf(_target_intensity + amount, 0.0, 1.0)
	_intensity_events.append(amount)

	# Limit event history
	while _intensity_events.size() > 100:
		_intensity_events.remove_at(0)


## Set intensity directly.
func set_intensity(value: float) -> void:
	_target_intensity = clampf(value, 0.0, 1.0)


## Get current intensity.
func get_intensity() -> float:
	return intensity


## Reset intensity to state default.
func reset_intensity() -> void:
	if _state_configs.has(_current_state):
		var config: StateConfig = _state_configs[_current_state]
		_target_intensity = config.base_intensity
		intensity = config.base_intensity


# -- Public API: Layer Control --

## Manually enable/disable a specific layer.
func set_layer_enabled(layer_type: LayerType, enabled: bool, fade: bool = true) -> void:
	if not layers_enabled:
		return

	if not _layer_players.has(layer_type):
		return

	var player: AudioStreamPlayer = _layer_players[layer_type]

	if enabled:
		_fade_layer_in(player, fade)
	else:
		_fade_layer_out(player, fade)

	layer_changed.emit(_get_layer_name(layer_type), enabled)


## Check if a layer is currently active.
func is_layer_active(layer_type: LayerType) -> bool:
	if not _layer_players.has(layer_type):
		return false
	var player: AudioStreamPlayer = _layer_players[layer_type]
	return player.playing and player.volume_db > -60.0


## Get all active layer names.
func get_active_layers() -> Array[String]:
	var active: Array[String] = []
	for layer_type: int in _layer_players:
		if is_layer_active(layer_type):
			active.append(_get_layer_name(layer_type))
	return active


# -- Public API: Stingers --

## Play a stinger sound (short impactful audio).
func play_stinger(stinger_name: String, volume_db: float = 0.0) -> void:
	if not _stingers.has(stinger_name):
		# Try to play via AudioManager
		var sfx_key := "stinger_%s" % stinger_name
		if AudioManager._sfx_registry.has(sfx_key):
			AudioManager.play_sfx(sfx_key, volume_db)
			stinger_played.emit(stinger_name)
		return

	var stream: AudioStream = _stingers[stinger_name]
	var player := _layer_players.get(LayerType.STINGER) as AudioStreamPlayer

	if player:
		player.stream = stream
		player.volume_db = volume_db
		player.play()
		stinger_played.emit(stinger_name)


## Play victory stinger.
func play_victory_stinger() -> void:
	play_stinger("victory", 3.0)


## Play defeat stinger.
func play_defeat_stinger() -> void:
	play_stinger("defeat", 0.0)


## Play kill confirmation stinger.
func play_kill_stinger() -> void:
	play_stinger("kill", -3.0)


## Play elimination stinger.
func play_elimination_stinger() -> void:
	play_stinger("elimination", 0.0)


## Play countdown tick stinger.
func play_countdown_stinger(seconds_remaining: int) -> void:
	if seconds_remaining <= 3:
		play_stinger("countdown_final", 0.0)
	else:
		play_stinger("countdown_tick", -6.0)


# -- Public API: Beat Sync --

## Get current beat within measure.
func get_current_beat() -> int:
	return _current_beat


## Get current measure number.
func get_current_measure() -> int:
	return _current_measure


## Get time until next beat in seconds.
func get_time_to_next_beat() -> float:
	var beat_duration := 60.0 / bpm
	return beat_duration - _beat_timer


## Wait until the next beat boundary.
func wait_for_beat() -> void:
	var wait_time := get_time_to_next_beat()
	await get_tree().create_timer(wait_time).timeout


## Wait until the next measure boundary.
func wait_for_measure() -> void:
	var beats_until_measure := beats_per_measure - _current_beat
	var beat_duration := 60.0 / bpm
	var wait_time := beats_until_measure * beat_duration - _beat_timer
	await get_tree().create_timer(wait_time).timeout


# -- Transitions --

func _start_transition(from_state: MusicState, to_state: MusicState) -> void:
	_is_transitioning = true
	transition_started.emit(from_state, to_state)

	# Play transition stinger if configured
	if _state_configs.has(to_state):
		var config: StateConfig = _state_configs[to_state]
		if not config.transition_stinger.is_empty():
			play_stinger(config.transition_stinger)

	# Wait for beat if synced
	if beat_synced_transitions:
		await wait_for_beat()

	# Perform crossfade
	_crossfade_to_state(to_state)


func _crossfade_to_state(new_state: MusicState) -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	var old_state := _current_state
	_current_state = new_state

	# Set new intensity based on state
	if _state_configs.has(new_state):
		var config: StateConfig = _state_configs[new_state]
		_target_intensity = config.base_intensity

	_transition_tween = create_tween().set_parallel(true)

	# Fade out old layers
	for layer_type: int in _layer_players:
		var player: AudioStreamPlayer = _layer_players[layer_type]
		if player.playing and player.volume_db > -60.0:
			_transition_tween.tween_property(player, "volume_db", -80.0, crossfade_duration)

	_transition_tween.chain().tween_callback(_complete_transition)

	state_changed.emit(old_state, new_state)


func _complete_transition() -> void:
	_is_transitioning = false
	_target_state = _current_state

	# Start new state's base layer
	_activate_state_layers(_current_state)

	transition_completed.emit(_current_state)


func _instant_transition(new_state: MusicState) -> void:
	var old_state := _current_state
	_current_state = new_state
	_target_state = new_state
	_is_transitioning = false

	# Stop all current layers
	for layer_type: int in _layer_players:
		var player: AudioStreamPlayer = _layer_players[layer_type]
		player.stop()
		player.volume_db = -80.0

	# Set intensity
	if _state_configs.has(new_state):
		var config: StateConfig = _state_configs[new_state]
		intensity = config.base_intensity
		_target_intensity = config.base_intensity

	# Activate new state layers
	_activate_state_layers(new_state)

	state_changed.emit(old_state, new_state)


func _activate_state_layers(state: MusicState) -> void:
	if not _state_configs.has(state):
		return

	var config: StateConfig = _state_configs[state]

	# Activate layers defined for this state
	for layer_type: int in config.layers:
		var layer_config: LayerConfig = config.layers[layer_type]
		if layer_config.stream:
			var player: AudioStreamPlayer = _layer_players[layer_type]
			player.stream = layer_config.stream
			player.volume_db = layer_config.volume_db
			player.play()


# -- Layer Updates --

func _fade_layer_in(player: AudioStreamPlayer, fade: bool) -> void:
	if fade:
		var tween := create_tween()
		tween.tween_property(player, "volume_db", 0.0, layer_fade_duration)
	else:
		player.volume_db = 0.0

	if not player.playing:
		player.play()


func _fade_layer_out(player: AudioStreamPlayer, fade: bool) -> void:
	if fade:
		var tween := create_tween()
		tween.tween_property(player, "volume_db", -80.0, layer_fade_duration)
		tween.tween_callback(player.stop)
	else:
		player.stop()
		player.volume_db = -80.0


func _update_layers(_delta: float) -> void:
	if not layers_enabled or _is_transitioning:
		return

	if not _state_configs.has(_current_state):
		return

	var config: StateConfig = _state_configs[_current_state]

	# Auto-manage layers based on intensity
	for layer_type: int in config.layers:
		if layer_type == LayerType.BASE:
			continue  # Base always plays

		var layer_config: LayerConfig = config.layers[layer_type]
		var should_play := intensity >= layer_config.intensity_min and intensity <= layer_config.intensity_max

		var player: AudioStreamPlayer = _layer_players[layer_type]
		var is_playing := player.playing and player.volume_db > -60.0

		if should_play and not is_playing:
			_fade_layer_in(player, true)
			layer_changed.emit(_get_layer_name(layer_type), true)
		elif not should_play and is_playing:
			_fade_layer_out(player, true)
			layer_changed.emit(_get_layer_name(layer_type), false)


# -- Beat Tracking --

func _update_beat_tracking(delta: float) -> void:
	if _current_state == MusicState.NONE:
		return

	var beat_duration := 60.0 / bpm
	_beat_timer += delta

	if _beat_timer >= beat_duration:
		_beat_timer -= beat_duration
		_current_beat += 1

		if _current_beat >= beats_per_measure:
			_current_beat = 0
			_current_measure += 1

		beat_pulse.emit(_current_beat, _current_measure)


# -- Intensity Updates --

func _update_intensity(delta: float) -> void:
	if not _state_configs.has(_current_state):
		return

	var config: StateConfig = _state_configs[_current_state]

	if not config.allow_intensity_changes:
		intensity = config.base_intensity
		return

	# Decay intensity over time
	if _target_intensity > config.base_intensity:
		_target_intensity = maxf(_target_intensity - intensity_decay_rate * delta, config.base_intensity)

	# Smooth intensity changes
	var old_intensity := intensity
	intensity = lerpf(intensity, _target_intensity, 5.0 * delta)

	if abs(intensity - old_intensity) > 0.01:
		intensity_changed.emit(old_intensity, intensity)

		# Notify AudioManager
		AudioManager.set_music_intensity(intensity)


# -- Utilities --

func _get_layer_name(layer_type: LayerType) -> String:
	match layer_type:
		LayerType.BASE: return "base"
		LayerType.PERCUSSION: return "percussion"
		LayerType.MELODY: return "melody"
		LayerType.ATMOSPHERE: return "atmosphere"
		LayerType.TENSION: return "tension"
		LayerType.ACTION: return "action"
		LayerType.STINGER: return "stinger"
		LayerType.TRANSITION: return "transition"
		_: return "unknown"


func _get_state_name(state: MusicState) -> String:
	match state:
		MusicState.NONE: return "none"
		MusicState.MENU: return "menu"
		MusicState.LOBBY: return "lobby"
		MusicState.LOADING: return "loading"
		MusicState.GAMEPLAY_CALM: return "gameplay_calm"
		MusicState.GAMEPLAY_ACTION: return "gameplay_action"
		MusicState.GAMEPLAY_INTENSE: return "gameplay_intense"
		MusicState.BOSS: return "boss"
		MusicState.VICTORY: return "victory"
		MusicState.DEFEAT: return "defeat"
		MusicState.AMBIENT: return "ambient"
		MusicState.COUNTDOWN: return "countdown"
		MusicState.OVERTIME: return "overtime"
		MusicState.RESULTS: return "results"
		_: return "unknown"


func _name_to_state(name: String) -> int:
	match name:
		"none": return MusicState.NONE
		"menu": return MusicState.MENU
		"lobby": return MusicState.LOBBY
		"loading": return MusicState.LOADING
		"gameplay_calm": return MusicState.GAMEPLAY_CALM
		"gameplay_action": return MusicState.GAMEPLAY_ACTION
		"gameplay_intense": return MusicState.GAMEPLAY_INTENSE
		"boss": return MusicState.BOSS
		"victory": return MusicState.VICTORY
		"defeat": return MusicState.DEFEAT
		"ambient": return MusicState.AMBIENT
		"countdown": return MusicState.COUNTDOWN
		"overtime": return MusicState.OVERTIME
		"results": return MusicState.RESULTS
		_: return -1


# -- Configuration API --

## Register a complete music state with layers.
func register_state(state: MusicState, layers: Dictionary, base_intensity: float = 0.5) -> void:
	var config := StateConfig.new()
	config.base_intensity = base_intensity

	for layer_type: int in layers:
		var layer_data: Dictionary = layers[layer_type]
		var layer_config := LayerConfig.new()
		layer_config.stream = layer_data.get("stream")
		layer_config.volume_db = layer_data.get("volume_db", 0.0)
		layer_config.intensity_min = layer_data.get("intensity_min", 0.0)
		layer_config.intensity_max = layer_data.get("intensity_max", 1.0)
		layer_config.layer_type = layer_type
		config.layers[layer_type] = layer_config

	_state_configs[state] = config


## Register a stinger sound.
func register_stinger(name: String, stream: AudioStream) -> void:
	_stingers[name] = stream


## Set BPM for beat synchronization.
func set_bpm(new_bpm: float) -> void:
	bpm = clampf(new_bpm, 60.0, 200.0)


# -- Gameplay Integration Helpers --

## Called when a player scores a kill.
func on_kill() -> void:
	add_intensity(0.15)
	play_kill_stinger()


## Called when the local player takes damage.
func on_damage_taken(damage_percent: float) -> void:
	add_intensity(damage_percent * 0.2)


## Called when player count changes (fewer players = more tension).
func on_players_changed(current_players: int, total_players: int) -> void:
	var survival_ratio := float(current_players) / float(total_players)
	if survival_ratio < 0.25:
		set_state(MusicState.GAMEPLAY_INTENSE)
	elif survival_ratio < 0.5:
		set_state(MusicState.GAMEPLAY_ACTION)
	else:
		set_state(MusicState.GAMEPLAY_CALM)


## Called when match timer reaches warning thresholds.
func on_timer_warning(seconds_remaining: int) -> void:
	if seconds_remaining <= 10:
		add_intensity(0.3)
	elif seconds_remaining <= 30:
		add_intensity(0.15)


## Called when overtime begins.
func on_overtime_start() -> void:
	set_state(MusicState.OVERTIME)


## Called when match ends.
func on_match_end(is_victory: bool) -> void:
	if is_victory:
		set_state(MusicState.VICTORY)
	else:
		set_state(MusicState.DEFEAT)


## Called when returning to menu.
func on_return_to_menu() -> void:
	set_state(MusicState.MENU)


# -- Debug --

## Get current music system state.
func get_debug_info() -> Dictionary:
	return {
		"state": _get_state_name(_current_state),
		"target_state": _get_state_name(_target_state),
		"is_transitioning": _is_transitioning,
		"intensity": intensity,
		"target_intensity": _target_intensity,
		"bpm": bpm,
		"current_beat": _current_beat,
		"current_measure": _current_measure,
		"active_layers": get_active_layers(),
	}
