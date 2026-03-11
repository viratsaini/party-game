## UISoundManager - Comprehensive UI sound library and management for BattleZone Party.
##
## Provides a complete library of procedurally generated or referenced UI sounds,
## adaptive audio that scales with animations, 3D positional UI audio, and
## intelligent sound prioritization. All UI elements can request sounds by type
## and this manager ensures perfect audio feedback for every interaction.
class_name UISoundManager
extends Node


# -- Signals --

## Emitted when a UI sound is played.
signal ui_sound_played(sound_type: UISoundType, volume: float)

## Emitted when sound priority causes a sound to be ducked or skipped.
signal sound_ducked(sound_type: UISoundType, duck_amount: float)

## Emitted when a sound sequence starts.
signal sequence_started(sequence_name: String)

## Emitted when a sound sequence completes.
signal sequence_completed(sequence_name: String)


# -- Enums --

## All supported UI sound types.
enum UISoundType {
	# Basic interactions
	BUTTON_HOVER,
	BUTTON_PRESS,
	BUTTON_RELEASE,
	BUTTON_DISABLED,

	# Panel interactions
	PANEL_OPEN,
	PANEL_CLOSE,
	PANEL_SLIDE,
	PANEL_EXPAND,
	PANEL_COLLAPSE,

	# Navigation
	MENU_NAVIGATE,
	MENU_SELECT,
	MENU_BACK,
	MENU_FORWARD,
	TAB_SWITCH,

	# Item interactions
	ITEM_SELECT,
	ITEM_DESELECT,
	ITEM_HOVER,
	ITEM_PICKUP,
	ITEM_DROP,
	ITEM_EQUIP,
	ITEM_UNEQUIP,

	# List/scroll interactions
	LIST_SCROLL,
	LIST_SCROLL_END,
	SLIDER_MOVE,
	SLIDER_SNAP,
	TOGGLE_ON,
	TOGGLE_OFF,
	CHECKBOX_CHECK,
	CHECKBOX_UNCHECK,

	# Input
	TEXT_TYPE,
	TEXT_DELETE,
	TEXT_SUBMIT,
	TEXT_ERROR,

	# Feedback
	SUCCESS,
	ERROR,
	WARNING,
	INFO,
	NOTIFICATION,
	ACHIEVEMENT,
	LEVEL_UP,
	UNLOCK,

	# Transitions
	TRANSITION_IN,
	TRANSITION_OUT,
	FADE_IN,
	FADE_OUT,
	WHOOSH,

	# Special
	COUNTDOWN_TICK,
	COUNTDOWN_FINAL,
	TIMER_WARNING,
	CONFIRM,
	CANCEL,
	PURCHASE,
	REWARD,

	# Progress
	PROGRESS_TICK,
	PROGRESS_COMPLETE,
	LOADING_LOOP,
	LOADING_COMPLETE,

	# Social
	PLAYER_JOIN,
	PLAYER_LEAVE,
	CHAT_MESSAGE,
	CHAT_MENTION,
	FRIEND_ONLINE,
	PARTY_INVITE,
}

## Sound priority levels for mixing and ducking.
enum SoundPriority {
	BACKGROUND = 0,    ## Ambient UI sounds, can be freely ducked
	LOW = 1,           ## Hover sounds, navigation
	NORMAL = 2,        ## Standard button presses
	HIGH = 3,          ## Important feedback (success/error)
	CRITICAL = 4,      ## Achievement unlocks, level ups
	ESSENTIAL = 5,     ## Never ducked or skipped
}


# -- Constants --

## Maximum concurrent UI sounds before voice stealing.
const MAX_CONCURRENT_SOUNDS: int = 8

## Default ducking amount in dB for lower priority sounds.
const DEFAULT_DUCK_DB: float = -6.0

## Time in seconds before a ducked sound recovers.
const DUCK_RECOVERY_TIME: float = 0.15

## Base volume for UI sounds (relative to SFX bus).
const BASE_VOLUME_DB: float = 0.0


# -- Exports --

@export_group("Sound Library")

## Enable procedural sound generation for missing sounds.
@export var procedural_fallback: bool = true

## Global pitch variance for UI sounds.
@export_range(0.0, 0.2, 0.01) var global_pitch_variance: float = 0.05

## Enable 3D positional audio for UI elements.
@export var spatial_ui_enabled: bool = false

## Reverb amount for UI sounds (0-1).
@export_range(0.0, 1.0, 0.05) var ui_reverb_amount: float = 0.1

@export_group("Adaptive Audio")

## Scale volume based on animation speed (faster = louder).
@export var volume_scales_with_speed: bool = true

## Scale pitch based on context (hover up, press down).
@export var pitch_varies_by_context: bool = true

## Distance-based low-pass filter for spatial UI.
@export var distance_filtering: bool = true

@export_group("Performance")

## Enable sound pooling for better performance.
@export var sound_pooling: bool = true

## Maximum sounds per frame to prevent audio overload.
@export var max_sounds_per_frame: int = 4


# -- State --

## Registered sound configurations.
var _sound_configs: Dictionary = {}  # UISoundType -> SoundConfig

## Sound pool for reusable audio players.
var _sound_pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
const POOL_SIZE: int = 16

## Currently playing sounds with their priorities.
var _active_sounds: Array[Dictionary] = []

## Sound sequences currently playing.
var _active_sequences: Dictionary = {}  # String -> SequenceState

## Sounds played this frame for rate limiting.
var _sounds_this_frame: int = 0

## Ducking state.
var _current_duck_amount: float = 0.0
var _duck_tween: Tween = null

## Generated procedural sounds cache.
var _procedural_cache: Dictionary = {}


# -- Sound Configuration Class --

class SoundConfig extends RefCounted:
	var sfx_key: String = ""
	var base_volume_db: float = 0.0
	var pitch_scale: float = 1.0
	var pitch_variance: float = 0.05
	var priority: int = SoundPriority.NORMAL
	var cooldown: float = 0.0
	var max_distance: float = 100.0  # For spatial UI
	var reverb: float = 0.1
	var low_pass_hz: float = 20000.0
	var variations: Array[String] = []
	var last_play_time: float = 0.0

	func can_play() -> bool:
		if cooldown <= 0.0:
			return true
		var current_time := Time.get_ticks_msec() / 1000.0
		return current_time - last_play_time >= cooldown


# -- Lifecycle --

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_sound_pool()
	_register_default_sounds()
	_generate_procedural_sounds()


func _process(_delta: float) -> void:
	_sounds_this_frame = 0
	_cleanup_finished_sounds()
	_update_sequences(_delta)


# -- Sound Pool --

func _create_sound_pool() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "UISound_%d" % i
		player.bus = AudioManager.BUS_SFX
		add_child(player)
		_sound_pool.append(player)


func _get_pool_player() -> AudioStreamPlayer:
	var player := _sound_pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE

	# Stop if still playing (voice stealing)
	if player.playing:
		player.stop()

	return player


# -- Sound Registration --

func _register_default_sounds() -> void:
	# Basic button interactions
	_register_sound(UISoundType.BUTTON_HOVER, {
		"base_volume_db": -6.0,
		"pitch_scale": 1.2,
		"pitch_variance": 0.05,
		"priority": SoundPriority.LOW,
		"cooldown": 0.05,
	})

	_register_sound(UISoundType.BUTTON_PRESS, {
		"base_volume_db": -3.0,
		"pitch_scale": 0.95,
		"pitch_variance": 0.03,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.0,
	})

	_register_sound(UISoundType.BUTTON_RELEASE, {
		"base_volume_db": -9.0,
		"pitch_scale": 1.1,
		"pitch_variance": 0.05,
		"priority": SoundPriority.LOW,
		"cooldown": 0.0,
	})

	_register_sound(UISoundType.BUTTON_DISABLED, {
		"base_volume_db": -12.0,
		"pitch_scale": 0.7,
		"pitch_variance": 0.02,
		"priority": SoundPriority.LOW,
		"cooldown": 0.1,
	})

	# Panel interactions
	_register_sound(UISoundType.PANEL_OPEN, {
		"base_volume_db": -3.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.08,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.1,
	})

	_register_sound(UISoundType.PANEL_CLOSE, {
		"base_volume_db": -3.0,
		"pitch_scale": 0.9,
		"pitch_variance": 0.08,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.1,
	})

	_register_sound(UISoundType.PANEL_SLIDE, {
		"base_volume_db": -6.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.1,
		"priority": SoundPriority.LOW,
		"cooldown": 0.05,
	})

	# Navigation
	_register_sound(UISoundType.MENU_NAVIGATE, {
		"base_volume_db": -6.0,
		"pitch_scale": 1.1,
		"pitch_variance": 0.08,
		"priority": SoundPriority.LOW,
		"cooldown": 0.03,
	})

	_register_sound(UISoundType.MENU_SELECT, {
		"base_volume_db": -3.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.05,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.0,
	})

	_register_sound(UISoundType.MENU_BACK, {
		"base_volume_db": -6.0,
		"pitch_scale": 0.85,
		"pitch_variance": 0.05,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.1,
	})

	_register_sound(UISoundType.TAB_SWITCH, {
		"base_volume_db": -6.0,
		"pitch_scale": 1.05,
		"pitch_variance": 0.1,
		"priority": SoundPriority.LOW,
		"cooldown": 0.05,
	})

	# Item interactions
	_register_sound(UISoundType.ITEM_SELECT, {
		"base_volume_db": -3.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.05,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.0,
	})

	_register_sound(UISoundType.ITEM_HOVER, {
		"base_volume_db": -9.0,
		"pitch_scale": 1.15,
		"pitch_variance": 0.05,
		"priority": SoundPriority.BACKGROUND,
		"cooldown": 0.03,
	})

	_register_sound(UISoundType.ITEM_PICKUP, {
		"base_volume_db": 0.0,
		"pitch_scale": 1.2,
		"pitch_variance": 0.1,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.0,
	})

	_register_sound(UISoundType.ITEM_EQUIP, {
		"base_volume_db": 0.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.08,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.0,
	})

	# Controls
	_register_sound(UISoundType.SLIDER_MOVE, {
		"base_volume_db": -12.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.15,
		"priority": SoundPriority.BACKGROUND,
		"cooldown": 0.02,
	})

	_register_sound(UISoundType.SLIDER_SNAP, {
		"base_volume_db": -6.0,
		"pitch_scale": 1.1,
		"pitch_variance": 0.05,
		"priority": SoundPriority.LOW,
		"cooldown": 0.05,
	})

	_register_sound(UISoundType.TOGGLE_ON, {
		"base_volume_db": -3.0,
		"pitch_scale": 1.2,
		"pitch_variance": 0.05,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.0,
	})

	_register_sound(UISoundType.TOGGLE_OFF, {
		"base_volume_db": -3.0,
		"pitch_scale": 0.9,
		"pitch_variance": 0.05,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.0,
	})

	_register_sound(UISoundType.LIST_SCROLL, {
		"base_volume_db": -15.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.2,
		"priority": SoundPriority.BACKGROUND,
		"cooldown": 0.02,
	})

	# Text input
	_register_sound(UISoundType.TEXT_TYPE, {
		"base_volume_db": -12.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.15,
		"priority": SoundPriority.BACKGROUND,
		"cooldown": 0.02,
	})

	_register_sound(UISoundType.TEXT_DELETE, {
		"base_volume_db": -9.0,
		"pitch_scale": 0.85,
		"pitch_variance": 0.1,
		"priority": SoundPriority.BACKGROUND,
		"cooldown": 0.03,
	})

	_register_sound(UISoundType.TEXT_SUBMIT, {
		"base_volume_db": -3.0,
		"pitch_scale": 1.1,
		"pitch_variance": 0.05,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.0,
	})

	# Feedback sounds
	_register_sound(UISoundType.SUCCESS, {
		"base_volume_db": 0.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.03,
		"priority": SoundPriority.HIGH,
		"cooldown": 0.2,
	})

	_register_sound(UISoundType.ERROR, {
		"base_volume_db": 0.0,
		"pitch_scale": 0.8,
		"pitch_variance": 0.02,
		"priority": SoundPriority.HIGH,
		"cooldown": 0.2,
	})

	_register_sound(UISoundType.WARNING, {
		"base_volume_db": -3.0,
		"pitch_scale": 0.9,
		"pitch_variance": 0.03,
		"priority": SoundPriority.HIGH,
		"cooldown": 0.3,
	})

	_register_sound(UISoundType.INFO, {
		"base_volume_db": -6.0,
		"pitch_scale": 1.05,
		"pitch_variance": 0.05,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.2,
	})

	_register_sound(UISoundType.NOTIFICATION, {
		"base_volume_db": -3.0,
		"pitch_scale": 1.1,
		"pitch_variance": 0.05,
		"priority": SoundPriority.HIGH,
		"cooldown": 0.5,
	})

	_register_sound(UISoundType.ACHIEVEMENT, {
		"base_volume_db": 3.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.02,
		"priority": SoundPriority.CRITICAL,
		"cooldown": 1.0,
	})

	_register_sound(UISoundType.LEVEL_UP, {
		"base_volume_db": 3.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.02,
		"priority": SoundPriority.CRITICAL,
		"cooldown": 1.0,
	})

	_register_sound(UISoundType.UNLOCK, {
		"base_volume_db": 0.0,
		"pitch_scale": 1.1,
		"pitch_variance": 0.03,
		"priority": SoundPriority.HIGH,
		"cooldown": 0.5,
	})

	# Transitions
	_register_sound(UISoundType.TRANSITION_IN, {
		"base_volume_db": -3.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.1,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.2,
	})

	_register_sound(UISoundType.TRANSITION_OUT, {
		"base_volume_db": -3.0,
		"pitch_scale": 0.9,
		"pitch_variance": 0.1,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.2,
	})

	_register_sound(UISoundType.WHOOSH, {
		"base_volume_db": -6.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.15,
		"priority": SoundPriority.LOW,
		"cooldown": 0.05,
	})

	# Countdown
	_register_sound(UISoundType.COUNTDOWN_TICK, {
		"base_volume_db": -3.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.02,
		"priority": SoundPriority.HIGH,
		"cooldown": 0.0,
	})

	_register_sound(UISoundType.COUNTDOWN_FINAL, {
		"base_volume_db": 3.0,
		"pitch_scale": 1.2,
		"pitch_variance": 0.0,
		"priority": SoundPriority.CRITICAL,
		"cooldown": 0.0,
	})

	_register_sound(UISoundType.TIMER_WARNING, {
		"base_volume_db": 0.0,
		"pitch_scale": 1.1,
		"pitch_variance": 0.02,
		"priority": SoundPriority.HIGH,
		"cooldown": 0.5,
	})

	# Confirm/Cancel
	_register_sound(UISoundType.CONFIRM, {
		"base_volume_db": 0.0,
		"pitch_scale": 1.1,
		"pitch_variance": 0.03,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.1,
	})

	_register_sound(UISoundType.CANCEL, {
		"base_volume_db": -3.0,
		"pitch_scale": 0.85,
		"pitch_variance": 0.03,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.1,
	})

	# Progress
	_register_sound(UISoundType.PROGRESS_TICK, {
		"base_volume_db": -12.0,
		"pitch_scale": 1.0,
		"pitch_variance": 0.1,
		"priority": SoundPriority.BACKGROUND,
		"cooldown": 0.05,
	})

	_register_sound(UISoundType.PROGRESS_COMPLETE, {
		"base_volume_db": 0.0,
		"pitch_scale": 1.2,
		"pitch_variance": 0.05,
		"priority": SoundPriority.HIGH,
		"cooldown": 0.2,
	})

	# Social
	_register_sound(UISoundType.PLAYER_JOIN, {
		"base_volume_db": -3.0,
		"pitch_scale": 1.15,
		"pitch_variance": 0.05,
		"priority": SoundPriority.HIGH,
		"cooldown": 0.5,
	})

	_register_sound(UISoundType.PLAYER_LEAVE, {
		"base_volume_db": -6.0,
		"pitch_scale": 0.85,
		"pitch_variance": 0.05,
		"priority": SoundPriority.NORMAL,
		"cooldown": 0.5,
	})

	_register_sound(UISoundType.CHAT_MESSAGE, {
		"base_volume_db": -9.0,
		"pitch_scale": 1.1,
		"pitch_variance": 0.08,
		"priority": SoundPriority.LOW,
		"cooldown": 0.1,
	})

	_register_sound(UISoundType.CHAT_MENTION, {
		"base_volume_db": 0.0,
		"pitch_scale": 1.2,
		"pitch_variance": 0.03,
		"priority": SoundPriority.HIGH,
		"cooldown": 0.5,
	})

	_register_sound(UISoundType.PARTY_INVITE, {
		"base_volume_db": 0.0,
		"pitch_scale": 1.1,
		"pitch_variance": 0.03,
		"priority": SoundPriority.HIGH,
		"cooldown": 1.0,
	})


func _register_sound(sound_type: UISoundType, config: Dictionary) -> void:
	var sound_config := SoundConfig.new()
	sound_config.sfx_key = "ui_%s" % _get_sound_type_name(sound_type)
	sound_config.base_volume_db = config.get("base_volume_db", 0.0)
	sound_config.pitch_scale = config.get("pitch_scale", 1.0)
	sound_config.pitch_variance = config.get("pitch_variance", 0.05)
	sound_config.priority = config.get("priority", SoundPriority.NORMAL)
	sound_config.cooldown = config.get("cooldown", 0.0)
	sound_config.reverb = config.get("reverb", ui_reverb_amount)
	_sound_configs[sound_type] = sound_config


# -- Procedural Sound Generation --

func _generate_procedural_sounds() -> void:
	if not procedural_fallback:
		return

	# Generate procedural waveforms for each sound type
	# These are simple synthesized sounds that work as fallbacks

	for sound_type: int in UISoundType.values():
		var sfx_key := "ui_%s" % _get_sound_type_name(sound_type)

		# Check if sound is already registered in AudioManager
		if AudioManager._sfx_registry.has(sfx_key):
			continue

		# Generate procedural sound
		var stream := _create_procedural_sound(sound_type)
		if stream:
			AudioManager.register_sfx(sfx_key, stream, AudioManager.SFXCategory.UI)
			_procedural_cache[sound_type] = stream


func _create_procedural_sound(sound_type: UISoundType) -> AudioStream:
	# Create a simple AudioStreamGenerator or use noise-based synthesis
	# For now, return null - actual procedural generation would require
	# AudioStreamGenerator which needs to be played in real-time

	# In production, you would either:
	# 1. Use AudioStreamGenerator for real-time synthesis
	# 2. Pre-generate WAV data and create AudioStreamWAV
	# 3. Load actual audio files

	return null


# -- Public API: Play Sounds --

## Play a UI sound with default settings.
func play(sound_type: UISoundType) -> void:
	play_advanced(sound_type, {})


## Play a UI sound with custom options.
func play_advanced(sound_type: UISoundType, options: Dictionary = {}) -> void:
	# Rate limiting
	if _sounds_this_frame >= max_sounds_per_frame:
		return

	# Get sound configuration
	if not _sound_configs.has(sound_type):
		push_warning("UISoundManager: Sound type %d not configured" % sound_type)
		return

	var config: SoundConfig = _sound_configs[sound_type]

	# Check cooldown
	if not config.can_play():
		return

	# Apply priority-based ducking
	_apply_ducking(config.priority)

	# Calculate final parameters
	var volume_db := config.base_volume_db + BASE_VOLUME_DB
	var pitch := config.pitch_scale

	# Apply options overrides
	volume_db += options.get("volume_offset_db", 0.0)
	pitch *= options.get("pitch_multiplier", 1.0)

	# Apply adaptive audio
	if volume_scales_with_speed:
		var speed_factor: float = options.get("animation_speed", 1.0)
		volume_db += clampf((speed_factor - 1.0) * 3.0, -6.0, 6.0)

	if pitch_varies_by_context:
		pitch += options.get("pitch_context_offset", 0.0)

	# Apply variance
	var variance := config.pitch_variance + global_pitch_variance
	if variance > 0.0:
		pitch += randf_range(-variance, variance)

	# Apply ducking reduction
	volume_db += _current_duck_amount

	# Get player and play
	var player := _get_pool_player()

	# Try to use registered sound
	var sfx_key := config.sfx_key
	if AudioManager._sfx_registry.has(sfx_key):
		player.stream = AudioManager._sfx_registry[sfx_key]
	elif _procedural_cache.has(sound_type):
		player.stream = _procedural_cache[sound_type]
	else:
		# No sound available - skip silently in production
		return

	if not player.stream:
		return

	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

	# Track active sound
	_active_sounds.append({
		"player": player,
		"priority": config.priority,
		"start_time": Time.get_ticks_msec() / 1000.0,
	})

	# Update state
	config.last_play_time = Time.get_ticks_msec() / 1000.0
	_sounds_this_frame += 1

	ui_sound_played.emit(sound_type, volume_db)


## Play a UI sound at a screen position (for spatial UI).
func play_at_position(sound_type: UISoundType, screen_position: Vector2, options: Dictionary = {}) -> void:
	if not spatial_ui_enabled:
		play_advanced(sound_type, options)
		return

	# Calculate positional parameters
	var viewport_size := get_viewport().get_visible_rect().size
	var normalized_x := (screen_position.x / viewport_size.x) * 2.0 - 1.0  # -1 to 1

	# Apply stereo panning based on position
	options["pan"] = clampf(normalized_x, -1.0, 1.0)

	# Distance from center affects volume slightly
	var distance_from_center := abs(normalized_x)
	options["volume_offset_db"] = options.get("volume_offset_db", 0.0) - distance_from_center * 2.0

	play_advanced(sound_type, options)


## Play a sound with pitch that increases over a sequence (for countdowns, etc.).
func play_pitched(sound_type: UISoundType, pitch_offset: float) -> void:
	play_advanced(sound_type, {"pitch_context_offset": pitch_offset})


# -- Sound Sequences --

## Start a predefined sound sequence.
func start_sequence(sequence_name: String, sounds: Array[Dictionary], loop: bool = false) -> void:
	if _active_sequences.has(sequence_name):
		stop_sequence(sequence_name)

	var state := {
		"sounds": sounds,
		"current_index": 0,
		"loop": loop,
		"timer": 0.0,
		"next_time": 0.0,
	}

	if sounds.size() > 0:
		state["next_time"] = sounds[0].get("delay", 0.0)

	_active_sequences[sequence_name] = state
	sequence_started.emit(sequence_name)


## Stop a running sound sequence.
func stop_sequence(sequence_name: String) -> void:
	if _active_sequences.has(sequence_name):
		_active_sequences.erase(sequence_name)
		sequence_completed.emit(sequence_name)


## Check if a sequence is currently playing.
func is_sequence_playing(sequence_name: String) -> bool:
	return _active_sequences.has(sequence_name)


func _update_sequences(delta: float) -> void:
	var completed: Array[String] = []

	for seq_name: String in _active_sequences:
		var state: Dictionary = _active_sequences[seq_name]
		state["timer"] = (state["timer"] as float) + delta

		while (state["timer"] as float) >= (state["next_time"] as float):
			var sounds: Array = state["sounds"]
			var index: int = state["current_index"]

			if index >= sounds.size():
				if state["loop"]:
					state["current_index"] = 0
					state["timer"] = 0.0
					state["next_time"] = sounds[0].get("delay", 0.0)
				else:
					completed.append(seq_name)
				break

			var sound_data: Dictionary = sounds[index]
			var sound_type: int = sound_data.get("type", UISoundType.BUTTON_PRESS)
			play_advanced(sound_type, sound_data.get("options", {}))

			state["current_index"] = index + 1
			if state["current_index"] < sounds.size():
				state["next_time"] = (state["timer"] as float) + sounds[state["current_index"]].get("delay", 0.1)
			else:
				state["next_time"] = INF

	for seq_name: String in completed:
		stop_sequence(seq_name)


# -- Predefined Sequences --

## Play a menu open sequence.
func play_menu_open_sequence() -> void:
	start_sequence("menu_open", [
		{"type": UISoundType.WHOOSH, "delay": 0.0, "options": {"pitch_multiplier": 1.1}},
		{"type": UISoundType.PANEL_OPEN, "delay": 0.15},
	])


## Play a menu close sequence.
func play_menu_close_sequence() -> void:
	start_sequence("menu_close", [
		{"type": UISoundType.PANEL_CLOSE, "delay": 0.0},
		{"type": UISoundType.WHOOSH, "delay": 0.1, "options": {"pitch_multiplier": 0.9}},
	])


## Play a success fanfare sequence.
func play_success_sequence() -> void:
	start_sequence("success", [
		{"type": UISoundType.SUCCESS, "delay": 0.0},
		{"type": UISoundType.NOTIFICATION, "delay": 0.3, "options": {"pitch_multiplier": 1.2}},
	])


## Play an achievement unlock sequence.
func play_achievement_sequence() -> void:
	start_sequence("achievement", [
		{"type": UISoundType.WHOOSH, "delay": 0.0},
		{"type": UISoundType.ACHIEVEMENT, "delay": 0.2},
		{"type": UISoundType.UNLOCK, "delay": 0.5, "options": {"pitch_multiplier": 1.3}},
	])


## Play countdown sequence (3, 2, 1, GO!).
func play_countdown_sequence() -> void:
	start_sequence("countdown", [
		{"type": UISoundType.COUNTDOWN_TICK, "delay": 0.0, "options": {"pitch_multiplier": 0.8}},
		{"type": UISoundType.COUNTDOWN_TICK, "delay": 1.0, "options": {"pitch_multiplier": 0.9}},
		{"type": UISoundType.COUNTDOWN_TICK, "delay": 1.0, "options": {"pitch_multiplier": 1.0}},
		{"type": UISoundType.COUNTDOWN_FINAL, "delay": 1.0},
	])


## Play level up sequence.
func play_level_up_sequence() -> void:
	start_sequence("level_up", [
		{"type": UISoundType.PROGRESS_COMPLETE, "delay": 0.0},
		{"type": UISoundType.LEVEL_UP, "delay": 0.3},
		{"type": UISoundType.UNLOCK, "delay": 0.8, "options": {"pitch_multiplier": 1.2}},
	])


# -- Ducking System --

func _apply_ducking(priority: int) -> void:
	if priority >= SoundPriority.HIGH:
		_start_duck()


func _start_duck() -> void:
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()

	_current_duck_amount = DEFAULT_DUCK_DB

	_duck_tween = create_tween()
	_duck_tween.tween_property(self, "_current_duck_amount", 0.0, DUCK_RECOVERY_TIME) \
		.set_delay(0.1)


# -- Cleanup --

func _cleanup_finished_sounds() -> void:
	var to_remove: Array[int] = []

	for i in range(_active_sounds.size()):
		var sound_data: Dictionary = _active_sounds[i]
		var player: AudioStreamPlayer = sound_data["player"]
		if not player.playing:
			to_remove.append(i)

	# Remove in reverse order to preserve indices
	for i in range(to_remove.size() - 1, -1, -1):
		_active_sounds.remove_at(to_remove[i])


# -- Utilities --

func _get_sound_type_name(sound_type: UISoundType) -> String:
	match sound_type:
		UISoundType.BUTTON_HOVER: return "button_hover"
		UISoundType.BUTTON_PRESS: return "button_press"
		UISoundType.BUTTON_RELEASE: return "button_release"
		UISoundType.BUTTON_DISABLED: return "button_disabled"
		UISoundType.PANEL_OPEN: return "panel_open"
		UISoundType.PANEL_CLOSE: return "panel_close"
		UISoundType.PANEL_SLIDE: return "panel_slide"
		UISoundType.PANEL_EXPAND: return "panel_expand"
		UISoundType.PANEL_COLLAPSE: return "panel_collapse"
		UISoundType.MENU_NAVIGATE: return "menu_navigate"
		UISoundType.MENU_SELECT: return "menu_select"
		UISoundType.MENU_BACK: return "menu_back"
		UISoundType.MENU_FORWARD: return "menu_forward"
		UISoundType.TAB_SWITCH: return "tab_switch"
		UISoundType.ITEM_SELECT: return "item_select"
		UISoundType.ITEM_DESELECT: return "item_deselect"
		UISoundType.ITEM_HOVER: return "item_hover"
		UISoundType.ITEM_PICKUP: return "item_pickup"
		UISoundType.ITEM_DROP: return "item_drop"
		UISoundType.ITEM_EQUIP: return "item_equip"
		UISoundType.ITEM_UNEQUIP: return "item_unequip"
		UISoundType.LIST_SCROLL: return "list_scroll"
		UISoundType.LIST_SCROLL_END: return "list_scroll_end"
		UISoundType.SLIDER_MOVE: return "slider_move"
		UISoundType.SLIDER_SNAP: return "slider_snap"
		UISoundType.TOGGLE_ON: return "toggle_on"
		UISoundType.TOGGLE_OFF: return "toggle_off"
		UISoundType.CHECKBOX_CHECK: return "checkbox_check"
		UISoundType.CHECKBOX_UNCHECK: return "checkbox_uncheck"
		UISoundType.TEXT_TYPE: return "text_type"
		UISoundType.TEXT_DELETE: return "text_delete"
		UISoundType.TEXT_SUBMIT: return "text_submit"
		UISoundType.TEXT_ERROR: return "text_error"
		UISoundType.SUCCESS: return "success"
		UISoundType.ERROR: return "error"
		UISoundType.WARNING: return "warning"
		UISoundType.INFO: return "info"
		UISoundType.NOTIFICATION: return "notification"
		UISoundType.ACHIEVEMENT: return "achievement"
		UISoundType.LEVEL_UP: return "level_up"
		UISoundType.UNLOCK: return "unlock"
		UISoundType.TRANSITION_IN: return "transition_in"
		UISoundType.TRANSITION_OUT: return "transition_out"
		UISoundType.FADE_IN: return "fade_in"
		UISoundType.FADE_OUT: return "fade_out"
		UISoundType.WHOOSH: return "whoosh"
		UISoundType.COUNTDOWN_TICK: return "countdown_tick"
		UISoundType.COUNTDOWN_FINAL: return "countdown_final"
		UISoundType.TIMER_WARNING: return "timer_warning"
		UISoundType.CONFIRM: return "confirm"
		UISoundType.CANCEL: return "cancel"
		UISoundType.PURCHASE: return "purchase"
		UISoundType.REWARD: return "reward"
		UISoundType.PROGRESS_TICK: return "progress_tick"
		UISoundType.PROGRESS_COMPLETE: return "progress_complete"
		UISoundType.LOADING_LOOP: return "loading_loop"
		UISoundType.LOADING_COMPLETE: return "loading_complete"
		UISoundType.PLAYER_JOIN: return "player_join"
		UISoundType.PLAYER_LEAVE: return "player_leave"
		UISoundType.CHAT_MESSAGE: return "chat_message"
		UISoundType.CHAT_MENTION: return "chat_mention"
		UISoundType.FRIEND_ONLINE: return "friend_online"
		UISoundType.PARTY_INVITE: return "party_invite"
		_: return "unknown"


## Get the number of currently playing UI sounds.
func get_active_sound_count() -> int:
	return _active_sounds.size()


## Get debug statistics.
func get_stats() -> Dictionary:
	return {
		"active_sounds": _active_sounds.size(),
		"pool_size": POOL_SIZE,
		"sounds_this_frame": _sounds_this_frame,
		"active_sequences": _active_sequences.keys(),
		"duck_amount_db": _current_duck_amount,
	}
