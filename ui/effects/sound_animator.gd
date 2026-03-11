## SoundAnimator - Animation-synchronized sound playback system.
##
## Integrates sounds with UI animations for polished feedback:
## - Animation event-triggered sounds
## - Sound curves that match animation easing
## - Spatial audio for UI elements
## - Volume based on animation intensity
##
## Usage:
##   SoundAnimator.play_with_animation("button_click", animation_duration)
##   SoundAnimator.bind_to_tween(tween, "whoosh", 0.3)
##   SoundAnimator.spatial_ui_sound(control, "popup")
extends Node


# region - Signals

## Emitted when a sound starts playing
signal sound_started(sound_key: String)

## Emitted when a sound finishes
signal sound_finished(sound_key: String)

## Emitted when sound settings change
signal settings_changed

# endregion


# region - Enums

## Sound categories for UI
enum SoundCategory {
	BUTTON,
	PANEL,
	NOTIFICATION,
	FEEDBACK,
	AMBIENT,
	TRANSITION,
}

## Volume curve types
enum VolumeCurve {
	LINEAR,
	EASE_IN,
	EASE_OUT,
	EASE_IN_OUT,
	PULSE,
	FADE_IN,
	FADE_OUT,
}

## Pitch variation modes
enum PitchMode {
	FIXED,
	RANDOM,
	ASCENDING,
	DESCENDING,
	INTENSITY_BASED,
}

# endregion


# region - Constants

## Default sound definitions
const SOUND_DEFINITIONS: Dictionary = {
	# Button sounds
	"button_hover": {
		"category": SoundCategory.BUTTON,
		"volume_db": -12.0,
		"pitch_base": 1.2,
		"pitch_variance": 0.05,
	},
	"button_click": {
		"category": SoundCategory.BUTTON,
		"volume_db": -6.0,
		"pitch_base": 1.0,
		"pitch_variance": 0.08,
	},
	"button_release": {
		"category": SoundCategory.BUTTON,
		"volume_db": -10.0,
		"pitch_base": 1.1,
		"pitch_variance": 0.05,
	},

	# Panel sounds
	"panel_open": {
		"category": SoundCategory.PANEL,
		"volume_db": -8.0,
		"pitch_base": 1.0,
		"pitch_variance": 0.03,
	},
	"panel_close": {
		"category": SoundCategory.PANEL,
		"volume_db": -10.0,
		"pitch_base": 0.9,
		"pitch_variance": 0.03,
	},
	"panel_slide": {
		"category": SoundCategory.PANEL,
		"volume_db": -12.0,
		"pitch_base": 1.0,
		"pitch_variance": 0.05,
	},

	# Notification sounds
	"notification_pop": {
		"category": SoundCategory.NOTIFICATION,
		"volume_db": -4.0,
		"pitch_base": 1.2,
		"pitch_variance": 0.1,
	},
	"notification_success": {
		"category": SoundCategory.NOTIFICATION,
		"volume_db": -6.0,
		"pitch_base": 1.3,
		"pitch_variance": 0.05,
	},
	"notification_error": {
		"category": SoundCategory.NOTIFICATION,
		"volume_db": -4.0,
		"pitch_base": 0.8,
		"pitch_variance": 0.05,
	},
	"notification_warning": {
		"category": SoundCategory.NOTIFICATION,
		"volume_db": -6.0,
		"pitch_base": 1.0,
		"pitch_variance": 0.05,
	},

	# Feedback sounds
	"feedback_positive": {
		"category": SoundCategory.FEEDBACK,
		"volume_db": -8.0,
		"pitch_base": 1.2,
		"pitch_variance": 0.1,
	},
	"feedback_negative": {
		"category": SoundCategory.FEEDBACK,
		"volume_db": -6.0,
		"pitch_base": 0.7,
		"pitch_variance": 0.05,
	},
	"shake": {
		"category": SoundCategory.FEEDBACK,
		"volume_db": -10.0,
		"pitch_base": 0.9,
		"pitch_variance": 0.1,
	},
	"bounce": {
		"category": SoundCategory.FEEDBACK,
		"volume_db": -12.0,
		"pitch_base": 1.1,
		"pitch_variance": 0.1,
	},

	# Transition sounds
	"whoosh": {
		"category": SoundCategory.TRANSITION,
		"volume_db": -10.0,
		"pitch_base": 1.0,
		"pitch_variance": 0.15,
	},
	"swoosh_in": {
		"category": SoundCategory.TRANSITION,
		"volume_db": -8.0,
		"pitch_base": 1.1,
		"pitch_variance": 0.1,
	},
	"swoosh_out": {
		"category": SoundCategory.TRANSITION,
		"volume_db": -8.0,
		"pitch_base": 0.9,
		"pitch_variance": 0.1,
	},
	"pop_in": {
		"category": SoundCategory.TRANSITION,
		"volume_db": -10.0,
		"pitch_base": 1.3,
		"pitch_variance": 0.1,
	},
	"pop_out": {
		"category": SoundCategory.TRANSITION,
		"volume_db": -12.0,
		"pitch_base": 0.8,
		"pitch_variance": 0.1,
	},

	# Typewriter sounds
	"type_char": {
		"category": SoundCategory.FEEDBACK,
		"volume_db": -18.0,
		"pitch_base": 1.0,
		"pitch_variance": 0.3,
	},

	# Special sounds
	"sparkle": {
		"category": SoundCategory.FEEDBACK,
		"volume_db": -14.0,
		"pitch_base": 1.5,
		"pitch_variance": 0.2,
	},
	"coin": {
		"category": SoundCategory.FEEDBACK,
		"volume_db": -8.0,
		"pitch_base": 1.2,
		"pitch_variance": 0.15,
	},
	"achievement": {
		"category": SoundCategory.NOTIFICATION,
		"volume_db": -4.0,
		"pitch_base": 1.0,
		"pitch_variance": 0.0,
	},
}

## Volume multipliers per category
const CATEGORY_VOLUMES: Dictionary = {
	SoundCategory.BUTTON: 1.0,
	SoundCategory.PANEL: 0.9,
	SoundCategory.NOTIFICATION: 1.2,
	SoundCategory.FEEDBACK: 1.0,
	SoundCategory.AMBIENT: 0.6,
	SoundCategory.TRANSITION: 0.8,
}

## Maximum concurrent UI sounds
const MAX_CONCURRENT_SOUNDS: int = 8

# endregion


# region - State

## Sound pool for playback
var _sound_pool: Array[AudioStreamPlayer] = []

## Pool index for round-robin
var _pool_index: int = 0

## Global volume modifier
var _global_volume_modifier: float = 1.0

## Category volume modifiers
var _category_volumes: Dictionary = {}

## Sound enabled flag
var _sounds_enabled: bool = true

## Recently played sounds (for rate limiting)
var _recent_sounds: Dictionary = {}  ## sound_key -> timestamp

## Minimum time between same sound plays
var _sound_cooldowns: Dictionary = {}

## Active tween bindings
var _tween_bindings: Dictionary = {}  ## Tween -> {sound_key, played}

# endregion


# region - Lifecycle

func _ready() -> void:
	_initialize_sound_pool()
	_initialize_category_volumes()
	print("[SoundAnimator] Sound animation system ready with %d sound definitions" % SOUND_DEFINITIONS.size())


func _process(_delta: float) -> void:
	_cleanup_recent_sounds()
	_cleanup_tween_bindings()


func _initialize_sound_pool() -> void:
	for i in range(MAX_CONCURRENT_SOUNDS):
		var player := AudioStreamPlayer.new()
		player.name = "UISoundPlayer_%d" % i
		player.bus = "SFX"  # Assumes SFX bus exists
		player.finished.connect(_on_sound_finished.bind(player))
		add_child(player)
		_sound_pool.append(player)


func _initialize_category_volumes() -> void:
	for category: int in CATEGORY_VOLUMES.keys():
		_category_volumes[category] = CATEGORY_VOLUMES[category]

# endregion


# region - Public API

## Plays a UI sound synchronized with an animation duration
func play_with_animation(
	sound_key: String,
	animation_duration: float,
	delay: float = 0.0,
	intensity: float = 1.0
) -> AudioStreamPlayer:
	if not _sounds_enabled:
		return null

	if delay > 0.0:
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func() -> void:
			_play_sound(sound_key, intensity, animation_duration)
		)
		return null

	return _play_sound(sound_key, intensity, animation_duration)


## Plays a UI sound immediately
func play(sound_key: String, intensity: float = 1.0) -> AudioStreamPlayer:
	if not _sounds_enabled:
		return null
	return _play_sound(sound_key, intensity)


## Plays a sound at a specific point in a tween's progress
func bind_to_tween(
	tween: Tween,
	sound_key: String,
	trigger_progress: float = 0.0,
	intensity: float = 1.0
) -> void:
	if not _sounds_enabled or not tween.is_valid():
		return

	_tween_bindings[tween] = {
		"sound_key": sound_key,
		"trigger_progress": trigger_progress,
		"intensity": intensity,
		"played": false,
	}

	# For immediate triggers (progress = 0)
	if trigger_progress <= 0.0:
		play(sound_key, intensity)
		_tween_bindings[tween]["played"] = true


## Plays a sound with positional audio based on UI element position
func spatial_ui_sound(
	control: Control,
	sound_key: String,
	intensity: float = 1.0
) -> AudioStreamPlayer:
	if not _sounds_enabled or not is_instance_valid(control):
		return null

	var player := _play_sound(sound_key, intensity)
	if player:
		# Calculate stereo pan based on horizontal position
		var viewport_width: float = control.get_viewport_rect().size.x
		var center_x: float = control.global_position.x + control.size.x / 2.0
		var pan: float = (center_x / viewport_width - 0.5) * 2.0
		# Note: AudioStreamPlayer doesn't have pan, would need AudioStreamPlayer2D
		# This is a simplified version

	return player


## Plays a sequence of sounds with timing
func play_sequence(
	sounds: Array[Dictionary],  ## [{key: String, delay: float, intensity: float}]
) -> void:
	if not _sounds_enabled:
		return

	var cumulative_delay: float = 0.0

	for sound_data: Dictionary in sounds:
		var sound_key: String = sound_data.get("key", "")
		var delay: float = sound_data.get("delay", 0.0)
		var intensity: float = sound_data.get("intensity", 1.0)

		cumulative_delay += delay

		if cumulative_delay > 0.0:
			var timer := get_tree().create_timer(cumulative_delay)
			timer.timeout.connect(func() -> void:
				_play_sound(sound_key, intensity)
			)
		else:
			_play_sound(sound_key, intensity)


## Plays ascending/descending pitch sequence (for combos, scores, etc.)
func play_ascending_sequence(
	sound_key: String,
	count: int,
	interval: float = 0.1,
	pitch_increment: float = 0.1,
	start_pitch: float = 0.8
) -> void:
	if not _sounds_enabled:
		return

	for i in range(count):
		var delay: float = float(i) * interval
		var pitch: float = start_pitch + float(i) * pitch_increment

		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func() -> void:
			var player := _play_sound(sound_key, 1.0)
			if player:
				player.pitch_scale = pitch
		)


## Creates a sound that matches animation intensity over time
func play_intensity_sound(
	sound_key: String,
	duration: float,
	volume_curve: VolumeCurve = VolumeCurve.EASE_OUT,
	peak_intensity: float = 1.0
) -> AudioStreamPlayer:
	var player := _play_sound(sound_key, 0.0)
	if not player:
		return null

	var base_volume: float = player.volume_db

	# Create volume animation based on curve
	var tween := create_tween()

	match volume_curve:
		VolumeCurve.LINEAR:
			tween.tween_property(player, "volume_db", base_volume + linear_to_db(peak_intensity), duration)

		VolumeCurve.EASE_IN:
			tween.tween_method(
				func(t: float) -> void:
					player.volume_db = base_volume + linear_to_db(peak_intensity * t * t),
				0.0, 1.0, duration
			)

		VolumeCurve.EASE_OUT:
			tween.tween_method(
				func(t: float) -> void:
					player.volume_db = base_volume + linear_to_db(peak_intensity * (1.0 - pow(1.0 - t, 2.0))),
				0.0, 1.0, duration
			)

		VolumeCurve.EASE_IN_OUT:
			tween.tween_method(
				func(t: float) -> void:
					var curve_t: float
					if t < 0.5:
						curve_t = 2.0 * t * t
					else:
						curve_t = 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
					player.volume_db = base_volume + linear_to_db(peak_intensity * curve_t),
				0.0, 1.0, duration
			)

		VolumeCurve.PULSE:
			tween.tween_method(
				func(t: float) -> void:
					var pulse: float = sin(t * PI) * peak_intensity
					player.volume_db = base_volume + linear_to_db(pulse),
				0.0, 1.0, duration
			)

		VolumeCurve.FADE_IN:
			player.volume_db = -80.0
			tween.tween_property(player, "volume_db", base_volume, duration) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		VolumeCurve.FADE_OUT:
			tween.tween_property(player, "volume_db", -80.0, duration) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	return player


## Sets the global volume modifier (0.0 - 1.0)
func set_global_volume(volume: float) -> void:
	_global_volume_modifier = clampf(volume, 0.0, 1.0)
	settings_changed.emit()


## Sets volume for a specific category
func set_category_volume(category: SoundCategory, volume: float) -> void:
	_category_volumes[category] = clampf(volume, 0.0, 2.0)
	settings_changed.emit()


## Enables or disables all UI sounds
func set_sounds_enabled(enabled: bool) -> void:
	_sounds_enabled = enabled
	if not enabled:
		_stop_all_sounds()
	settings_changed.emit()


## Gets whether sounds are enabled
func are_sounds_enabled() -> bool:
	return _sounds_enabled


## Sets a cooldown for a specific sound (minimum time between plays)
func set_sound_cooldown(sound_key: String, cooldown: float) -> void:
	_sound_cooldowns[sound_key] = cooldown


## Stops all currently playing sounds
func stop_all_sounds() -> void:
	_stop_all_sounds()

# endregion


# region - Sound Playback

func _play_sound(
	sound_key: String,
	intensity: float = 1.0,
	_animation_duration: float = 0.0
) -> AudioStreamPlayer:
	if not SOUND_DEFINITIONS.has(sound_key):
		# Try to play through AudioManager if available
		return _try_audio_manager(sound_key, intensity)

	# Check cooldown
	if _is_sound_on_cooldown(sound_key):
		return null

	var definition: Dictionary = SOUND_DEFINITIONS[sound_key]
	var player := _get_available_player()
	if not player:
		return null

	# Calculate volume
	var base_volume: float = definition.get("volume_db", -10.0)
	var category: int = definition.get("category", SoundCategory.FEEDBACK)
	var category_mult: float = _category_volumes.get(category, 1.0)
	var final_volume: float = base_volume + linear_to_db(intensity * category_mult * _global_volume_modifier)

	# Calculate pitch
	var pitch_base: float = definition.get("pitch_base", 1.0)
	var pitch_variance: float = definition.get("pitch_variance", 0.0)
	var final_pitch: float = pitch_base + randf_range(-pitch_variance, pitch_variance)

	# Configure and play
	player.volume_db = final_volume
	player.pitch_scale = final_pitch

	# Try to get stream from AudioManager
	var stream := _get_sound_stream(sound_key)
	if stream:
		player.stream = stream
		player.play()
		_record_sound_play(sound_key)
		sound_started.emit(sound_key)
		return player

	return null


func _get_available_player() -> AudioStreamPlayer:
	# Round-robin through pool
	for i in range(MAX_CONCURRENT_SOUNDS):
		var idx: int = (_pool_index + i) % MAX_CONCURRENT_SOUNDS
		var player: AudioStreamPlayer = _sound_pool[idx]
		if not player.playing:
			_pool_index = (idx + 1) % MAX_CONCURRENT_SOUNDS
			return player

	# All players busy - steal oldest
	_pool_index = (_pool_index + 1) % MAX_CONCURRENT_SOUNDS
	var player: AudioStreamPlayer = _sound_pool[_pool_index]
	player.stop()
	return player


func _get_sound_stream(sound_key: String) -> AudioStream:
	# Try to get from AudioManager autoload
	var tree := get_tree()
	if tree and tree.root.has_node("AudioManager"):
		var audio_manager: Node = tree.root.get_node("AudioManager")
		if audio_manager.has_method("get_sfx_stream"):
			return audio_manager.get_sfx_stream(sound_key)
		# Fallback: check if it has a registry
		if "_sfx_registry" in audio_manager:
			var registry: Dictionary = audio_manager._sfx_registry
			if registry.has(sound_key):
				return registry[sound_key]

	return null


func _try_audio_manager(sound_key: String, _intensity: float) -> AudioStreamPlayer:
	var tree := get_tree()
	if tree and tree.root.has_node("AudioManager"):
		var audio_manager: Node = tree.root.get_node("AudioManager")
		if audio_manager.has_method("play_sfx"):
			return audio_manager.play_sfx(sound_key)
	return null


func _stop_all_sounds() -> void:
	for player: AudioStreamPlayer in _sound_pool:
		if player.playing:
			player.stop()

# endregion


# region - Cooldown Management

func _is_sound_on_cooldown(sound_key: String) -> bool:
	if not _sound_cooldowns.has(sound_key):
		return false

	var cooldown: float = _sound_cooldowns[sound_key]
	var last_played: float = _recent_sounds.get(sound_key, 0.0)
	var current_time: float = Time.get_ticks_msec() / 1000.0

	return (current_time - last_played) < cooldown


func _record_sound_play(sound_key: String) -> void:
	_recent_sounds[sound_key] = Time.get_ticks_msec() / 1000.0


func _cleanup_recent_sounds() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var keys_to_remove: Array[String] = []

	for key: String in _recent_sounds.keys():
		var cooldown: float = _sound_cooldowns.get(key, 0.1)
		if current_time - _recent_sounds[key] > cooldown * 2.0:
			keys_to_remove.append(key)

	for key: String in keys_to_remove:
		_recent_sounds.erase(key)

# endregion


# region - Tween Binding Management

func _cleanup_tween_bindings() -> void:
	var tweens_to_remove: Array[Tween] = []

	for tween: Tween in _tween_bindings.keys():
		if not tween.is_valid() or not tween.is_running():
			tweens_to_remove.append(tween)

	for tween: Tween in tweens_to_remove:
		_tween_bindings.erase(tween)

# endregion


# region - Callbacks

func _on_sound_finished(player: AudioStreamPlayer) -> void:
	# Could emit sound_finished signal here if we tracked which sound was playing
	pass

# endregion


# region - Utility

## Converts linear volume (0-1) to decibels
func linear_to_db_value(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)

# endregion
