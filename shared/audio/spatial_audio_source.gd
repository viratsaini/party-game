## SpatialAudioSource - A reusable 3D audio source component for BattleZone Party.
##
## Attach to any Node3D to give it spatial audio capabilities with automatic
## distance attenuation, occlusion, doppler effects, and priority management.
## Works seamlessly with AudioManager for consistent audio behavior.
class_name SpatialAudioSource
extends Node3D


# -- Signals --

## Emitted when the sound starts playing.
signal playback_started()

## Emitted when the sound stops (either finished or interrupted).
signal playback_stopped()

## Emitted when occlusion state changes.
signal occlusion_changed(is_occluded: bool)


# -- Exports --

@export_group("Audio Source")

## The sound effect key registered with AudioManager.
@export var sfx_key: String = ""

## Volume offset in dB relative to the base sound.
@export_range(-40.0, 20.0, 0.1) var volume_db: float = 0.0

## Pitch scale multiplier.
@export_range(0.1, 4.0, 0.01) var pitch_scale: float = 1.0

## Random pitch variation (+/- this value).
@export_range(0.0, 1.0, 0.01) var pitch_variance: float = 0.0

## Priority level for voice stealing when pool is exhausted.
@export_enum("Low:0", "Normal:1", "High:2", "Critical:3", "Essential:4")
var priority: int = 1

@export_group("Attenuation")

## Maximum distance at which the sound can be heard.
@export_range(1.0, 200.0, 1.0) var max_distance: float = 50.0

## Distance at which the sound is at full volume.
@export_range(0.1, 20.0, 0.1) var unit_size: float = 2.0

## Attenuation model: 0=Inverse Distance, 1=Inverse Square, 2=Logarithmic, 3=Disabled
@export_enum("Inverse Distance:0", "Inverse Square:1", "Logarithmic:2", "Disabled:3")
var attenuation_model: int = 0

@export_group("Doppler")

## Enable doppler effect for moving sounds.
@export var doppler_enabled: bool = false

## Doppler tracking mode (0=Disabled, 1=Idle Step, 2=Physics Step)
@export_enum("Disabled:0", "Idle Step:1", "Physics Step:2")
var doppler_tracking: int = 0

@export_group("Occlusion")

## Enable occlusion checks (muffled when behind walls).
@export var occlusion_enabled: bool = true

## How much to reduce volume when occluded (in dB).
@export_range(0.0, 40.0, 1.0) var occlusion_attenuation_db: float = 12.0

## Physics layers to check for occlusion.
@export_flags_3d_physics var occlusion_mask: int = 1

@export_group("Playback")

## Automatically play when the node enters the scene tree.
@export var autoplay: bool = false

## Loop the sound continuously.
@export var loop: bool = false

## Minimum interval between repeated plays (prevents sound spam).
@export_range(0.0, 5.0, 0.01) var min_play_interval: float = 0.0


# -- State --

## Currently active AudioStreamPlayer3D from the pool.
var _current_player: AudioStreamPlayer3D = null

## Is the sound currently playing.
var _is_playing: bool = false

## Time of last play request (for interval limiting).
var _last_play_time: float = 0.0

## Current occlusion state.
var _is_occluded: bool = false

## Cached listener position for occlusion checks.
var _listener_position: Vector3 = Vector3.ZERO

## Timer for occlusion updates.
var _occlusion_timer: float = 0.0
const OCCLUSION_CHECK_INTERVAL: float = 0.1


# -- Lifecycle --

func _ready() -> void:
	if autoplay:
		# Defer autoplay to ensure scene is fully loaded
		call_deferred("play")


func _process(delta: float) -> void:
	if not _is_playing or not is_instance_valid(_current_player):
		return

	# Update player position to follow this node
	_current_player.global_position = global_position

	# Check if playback finished
	if not _current_player.playing:
		if loop:
			# Restart for looping
			_current_player.play()
		else:
			_stop_internal()
		return

	# Update occlusion
	if occlusion_enabled:
		_occlusion_timer += delta
		if _occlusion_timer >= OCCLUSION_CHECK_INTERVAL:
			_occlusion_timer = 0.0
			_update_occlusion()


# -- Public API --

## Play the sound at the current position.
func play() -> void:
	if sfx_key.is_empty():
		push_warning("SpatialAudioSource: Cannot play - sfx_key is empty.")
		return

	# Check play interval limit
	var current_time := Time.get_ticks_msec() / 1000.0
	if min_play_interval > 0.0 and current_time - _last_play_time < min_play_interval:
		return

	_last_play_time = current_time

	# Stop any currently playing sound from this source
	if _is_playing:
		stop()

	# Request a player from AudioManager
	_current_player = AudioManager.play_sfx_3d_advanced(sfx_key, global_position, {
		"volume_db": volume_db,
		"priority": priority,
		"max_distance": max_distance,
		"unit_size": unit_size,
		"pitch_scale": pitch_scale,
		"pitch_variance": pitch_variance,
		"doppler": doppler_enabled,
		"attenuation_model": attenuation_model,
	})

	if _current_player:
		_is_playing = true
		_is_occluded = false
		_occlusion_timer = 0.0

		# Apply doppler tracking mode
		match doppler_tracking:
			0: _current_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
			1: _current_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
			2: _current_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP

		playback_started.emit()


## Stop the currently playing sound.
func stop() -> void:
	_stop_internal()


## Check if the sound is currently playing.
func is_playing() -> bool:
	return _is_playing and is_instance_valid(_current_player) and _current_player.playing


## Get the current playback position in seconds.
func get_playback_position() -> float:
	if is_instance_valid(_current_player):
		return _current_player.get_playback_position()
	return 0.0


## Seek to a specific position in the sound.
func seek(position: float) -> void:
	if is_instance_valid(_current_player):
		_current_player.seek(position)


## Set volume in dB (runtime adjustment).
func set_volume_db_runtime(db: float) -> void:
	volume_db = db
	if is_instance_valid(_current_player):
		var final_db := volume_db
		if _is_occluded:
			final_db -= occlusion_attenuation_db
		_current_player.volume_db = final_db


## Set pitch scale (runtime adjustment).
func set_pitch_scale_runtime(scale: float) -> void:
	pitch_scale = scale
	if is_instance_valid(_current_player):
		_current_player.pitch_scale = scale


## Check if the sound is currently occluded.
func is_occluded() -> bool:
	return _is_occluded


# -- Internal --

func _stop_internal() -> void:
	if is_instance_valid(_current_player):
		_current_player.stop()

	_current_player = null
	_is_playing = false
	_is_occluded = false

	playback_stopped.emit()


func _update_occlusion() -> void:
	if not is_instance_valid(_current_player):
		return

	# Get listener position (camera)
	var viewport := get_viewport()
	if not viewport:
		return

	var camera := viewport.get_camera_3d()
	if not camera:
		return

	_listener_position = camera.global_position

	# Perform raycast from listener to sound source
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return

	var query := PhysicsRayQueryParameters3D.create(
		_listener_position,
		global_position,
		occlusion_mask
	)
	query.hit_from_inside = false
	query.hit_back_faces = false

	var result := space_state.intersect_ray(query)
	var was_occluded := _is_occluded
	_is_occluded = not result.is_empty()

	# Apply occlusion effect
	if _is_occluded != was_occluded:
		_apply_occlusion_effect()
		occlusion_changed.emit(_is_occluded)


func _apply_occlusion_effect() -> void:
	if not is_instance_valid(_current_player):
		return

	if _is_occluded:
		# Reduce volume and apply low-pass effect (simulated via volume)
		_current_player.volume_db = volume_db - occlusion_attenuation_db
	else:
		# Restore normal volume
		_current_player.volume_db = volume_db


# -- Static Factory Methods --

## Create a one-shot spatial sound at a position (auto-frees when done).
static func play_at(
	sfx_key: String,
	position: Vector3,
	config: Dictionary = {}
) -> AudioStreamPlayer3D:
	return AudioManager.play_sfx_3d_advanced(sfx_key, position, config)


## Create a looping ambient sound source at a position.
static func create_ambient_source(
	parent: Node,
	sfx_key: String,
	position: Vector3,
	max_distance: float = 30.0
) -> SpatialAudioSource:
	var source := SpatialAudioSource.new()
	source.sfx_key = sfx_key
	source.position = position
	source.max_distance = max_distance
	source.loop = true
	source.autoplay = true
	source.priority = 0  # LOW
	parent.add_child(source)
	return source


## Create a positional sound emitter (for moving objects).
static func create_positional_emitter(
	parent: Node3D,
	sfx_key: String,
	doppler: bool = true
) -> SpatialAudioSource:
	var source := SpatialAudioSource.new()
	source.sfx_key = sfx_key
	source.doppler_enabled = doppler
	source.doppler_tracking = 2  # Physics step
	source.autoplay = false
	parent.add_child(source)
	return source
