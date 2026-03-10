## AudioManager - autoload singleton that manages all audio for BattleZone Party.
##
## Handles background music with crossfade transitions, one-shot and spatial SFX,
## per-category volume control, persistent audio preferences, 3D spatial audio
## with occlusion, priority-based voice stealing, and doppler effects.
extends Node

# -- Signals --

## Emitted whenever any volume or mute setting changes.
signal settings_changed

## Emitted when a spatial sound is spawned (useful for debugging).
signal spatial_sound_spawned(player: AudioStreamPlayer3D, key: String, position: Vector3)

## Emitted when music intensity changes.
signal music_intensity_changed(new_intensity: float)

# -- Constants --

const SETTINGS_PATH: String = "user://audio_settings.cfg"
const SFX_POOL_SIZE: int = 8
const SPATIAL_POOL_SIZE: int = 64  ## Max concurrent 3D sounds

## Audio buses expected to exist in the project (index 0 = Master).
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_AMBIENT: StringName = &"Ambient"
const BUS_VOICE: StringName = &"Voice"

## SFX categories - used for per-category volume offsets and priority.
enum SFXCategory {
	UI,
	GAMEPLAY,
	IMPACT,
	AMBIENT,
	VOICE,
	FOOTSTEPS,
	WEAPON,
	EXPLOSION,
	MUSIC_STINGER
}

## Audio priority levels (higher = more important, less likely to be culled)
enum AudioPriority {
	LOW = 0,       ## Ambient sounds, particle effects
	NORMAL = 1,    ## Footsteps, pickups
	HIGH = 2,      ## Weapon fire, impacts
	CRITICAL = 3,  ## Voice lines, explosions, critical gameplay cues
	ESSENTIAL = 4  ## UI feedback, kill confirmations (never culled)
}

## Surface types for footstep and impact sounds
enum SurfaceType {
	DEFAULT,
	CONCRETE,
	METAL,
	WOOD,
	GRASS,
	SAND,
	WATER,
	GRAVEL,
	CARPET
}

# -- Exported / Configurable --

## Default crossfade duration in seconds when none is specified.
@export var default_crossfade: float = 1.0

## Maximum distance for 3D sounds to be heard.
@export var max_audio_distance: float = 50.0

## Reference distance for attenuation (sounds at full volume within this).
@export var reference_distance: float = 2.0

## Doppler tracking mode for fast projectiles.
@export var doppler_tracking: bool = true

## Enable audio occlusion through walls.
@export var occlusion_enabled: bool = true

## Occlusion raycast mask (collision layers to check).
@export_flags_3d_physics var occlusion_mask: int = 1

# -- Volume state (0.0 - 1.0 linear) --

var master_volume: float = 1.0:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volume(BUS_MASTER, master_volume)
		settings_changed.emit()

var music_volume: float = 0.8:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volume(BUS_MUSIC, music_volume)
		settings_changed.emit()

var sfx_volume: float = 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volume(BUS_SFX, sfx_volume)
		settings_changed.emit()

var ambient_volume: float = 0.7:
	set(v):
		ambient_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volume(BUS_AMBIENT, ambient_volume)
		settings_changed.emit()

var voice_volume: float = 1.0:
	set(v):
		voice_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volume(BUS_VOICE, voice_volume)
		settings_changed.emit()

var muted: bool = false:
	set(v):
		muted = v
		AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_MASTER), muted)
		settings_changed.emit()

## Per-category volume offsets in dB (additive on top of SFX bus).
var category_volume_db: Dictionary = {
	SFXCategory.UI: 0.0,
	SFXCategory.GAMEPLAY: 0.0,
	SFXCategory.IMPACT: 2.0,
	SFXCategory.AMBIENT: -6.0,
	SFXCategory.VOICE: 3.0,
	SFXCategory.FOOTSTEPS: -4.0,
	SFXCategory.WEAPON: 0.0,
	SFXCategory.EXPLOSION: 3.0,
	SFXCategory.MUSIC_STINGER: 0.0,
}

## Current music intensity (0.0 - 1.0) for dynamic music system.
var music_intensity: float = 0.0:
	set(v):
		var old_intensity = music_intensity
		music_intensity = clampf(v, 0.0, 1.0)
		if abs(music_intensity - old_intensity) > 0.01:
			music_intensity_changed.emit(music_intensity)

# -- Registries --

## Registered music streams keyed by string identifier.
var _music_registry: Dictionary = {}  # String -> AudioStream

## Registered SFX streams keyed by string identifier.
var _sfx_registry: Dictionary = {}    # String -> AudioStream

## Optional mapping of sfx key -> SFXCategory for automatic category volumes.
var _sfx_categories: Dictionary = {}  # String -> SFXCategory

## Priority mapping for SFX keys.
var _sfx_priorities: Dictionary = {}  # String -> AudioPriority

## Attenuation models per SFX key (optional overrides).
var _sfx_attenuation: Dictionary = {}  # String -> Dictionary

## Surface-specific sound mappings.
var _surface_sounds: Dictionary = {}  # SurfaceType -> Dictionary[String, AudioStream]

# -- Internal nodes --

## Two music players used for crossfading (A <-> B).
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
## Which player is currently "active" (true = A, false = B).
var _music_active_is_a: bool = true

## Pool of AudioStreamPlayers for one-shot SFX.
var _sfx_pool: Array[AudioStreamPlayer] = []
## Index cycling through the pool (round-robin).
var _sfx_pool_index: int = 0

## Pool of AudioStreamPlayer3D for spatial sounds.
var _spatial_pool: Array[AudioStreamPlayer3D] = []
## Active spatial players being tracked.
var _active_spatial_players: Array[AudioStreamPlayer3D] = []

## Currently playing music key (empty string = nothing).
var _current_music_key: String = ""

## Tween references so we can kill in-progress crossfades.
var _fade_tween: Tween = null

## Listener node for spatial audio (usually camera position).
var _listener_node: Node3D = null

## Physics space for occlusion raycasts.
var _space_state: PhysicsDirectSpaceState3D = null

## Occlusion cache to reduce raycast frequency.
var _occlusion_cache: Dictionary = {}  # AudioStreamPlayer3D -> {occluded: bool, time: float}
const OCCLUSION_CACHE_TIME: float = 0.1  # Seconds between occlusion checks

## Performance tracking
var _audio_thread_time_ms: float = 0.0

# -- Lifecycle --

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_create_music_players()
	_create_sfx_pool()
	_create_spatial_pool()
	_register_default_sounds()
	load_settings()


func _process(delta: float) -> void:
	var start_time := Time.get_ticks_usec()

	_update_spatial_audio(delta)
	_update_occlusion(delta)
	_cleanup_finished_players()

	_audio_thread_time_ms = (Time.get_ticks_usec() - start_time) / 1000.0


## Make sure the required audio buses exist at runtime. If the project
## doesn't ship a bus layout with Music / SFX buses we create them in code
## so nothing breaks.
func _ensure_audio_buses() -> void:
	for bus_name: StringName in [BUS_MUSIC, BUS_SFX, BUS_AMBIENT, BUS_VOICE]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)

	# Apply saved / default volumes to buses.
	_apply_bus_volume(BUS_MASTER, master_volume)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	_apply_bus_volume(BUS_SFX, sfx_volume)
	_apply_bus_volume(BUS_AMBIENT, ambient_volume)
	_apply_bus_volume(BUS_VOICE, voice_volume)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_MASTER), muted)


func _create_music_players() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.name = &"MusicA"
	_music_a.bus = BUS_MUSIC
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.name = &"MusicB"
	_music_b.bus = BUS_MUSIC
	_music_b.volume_db = -80.0
	add_child(_music_b)


func _create_sfx_pool() -> void:
	for i: int in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = &"SFX_%d" % i
		player.bus = BUS_SFX
		add_child(player)
		_sfx_pool.append(player)


func _create_spatial_pool() -> void:
	for i: int in SPATIAL_POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.name = &"Spatial_%d" % i
		player.bus = BUS_SFX
		player.max_distance = max_audio_distance
		player.unit_size = reference_distance
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP if doppler_tracking else AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		player.max_polyphony = 1
		add_child(player)
		_spatial_pool.append(player)


func _register_default_sounds() -> void:
	# Register placeholder sound effects for common game events
	# These would be replaced with actual audio files in production
	_register_weapon_sounds()
	_register_footstep_sounds()
	_register_impact_sounds()
	_register_voice_sounds()
	_register_ambient_sounds()
	_register_ui_sounds()


func _register_weapon_sounds() -> void:
	# Weapon firing sounds - different per weapon type
	# In production, load actual audio files like:
	# register_sfx("weapon_blaster", preload("res://audio/weapons/blaster.ogg"), SFXCategory.WEAPON)
	pass


func _register_footstep_sounds() -> void:
	# Footstep sounds per surface type
	# register_sfx("footstep_concrete", preload("res://audio/footsteps/concrete.ogg"), SFXCategory.FOOTSTEPS)
	pass


func _register_impact_sounds() -> void:
	# Impact/hit sounds
	# register_sfx("impact_player", preload("res://audio/impacts/player_hit.ogg"), SFXCategory.IMPACT)
	pass


func _register_voice_sounds() -> void:
	# Voice/grunt sounds
	# register_sfx("grunt_damage", preload("res://audio/voice/damage_grunt.ogg"), SFXCategory.VOICE)
	pass


func _register_ambient_sounds() -> void:
	# Environmental ambient sounds
	# register_sfx("ambient_wind", preload("res://audio/ambient/wind.ogg"), SFXCategory.AMBIENT)
	pass


func _register_ui_sounds() -> void:
	# UI feedback sounds
	# register_sfx("ui_click", preload("res://audio/ui/click.ogg"), SFXCategory.UI)
	pass


# -- Music --

## Play a music track by its registered key, crossfading from the current
## track over [param fade_duration] seconds. If the same key is already
## playing the call is ignored.
func play_music(key: String, fade_duration: float = 1.0) -> void:
	if key == _current_music_key:
		return

	if not _music_registry.has(key):
		push_warning("AudioManager: music key '%s' not registered - skipping." % key)
		return

	var stream: AudioStream = _music_registry[key]
	_current_music_key = key

	# Determine which player fades in and which fades out.
	var incoming: AudioStreamPlayer
	var outgoing: AudioStreamPlayer
	if _music_active_is_a:
		incoming = _music_b
		outgoing = _music_a
	else:
		incoming = _music_a
		outgoing = _music_b
	_music_active_is_a = not _music_active_is_a

	# Prepare incoming player.
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()

	# Kill any existing fade tween.
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(incoming, ^"volume_db", 0.0, fade_duration) \
		.set_trans(Tween.TRANS_LINEAR)
	_fade_tween.tween_property(outgoing, ^"volume_db", -80.0, fade_duration) \
		.set_trans(Tween.TRANS_LINEAR)
	_fade_tween.chain().tween_callback(outgoing.stop)


## Stop the current music track, fading out over [param fade_duration] seconds.
func stop_music(fade_duration: float = 1.0) -> void:
	if _current_music_key.is_empty():
		return

	_current_music_key = ""

	var active: AudioStreamPlayer = _music_a if _music_active_is_a else _music_b

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	if fade_duration <= 0.0:
		active.stop()
		return

	_fade_tween = create_tween()
	_fade_tween.tween_property(active, ^"volume_db", -80.0, fade_duration) \
		.set_trans(Tween.TRANS_LINEAR)
	_fade_tween.tween_callback(active.stop)


## Set music intensity for dynamic music (0.0 = calm, 1.0 = intense).
func set_music_intensity(intensity: float) -> void:
	music_intensity = intensity


# -- SFX --

## Play a one-shot sound effect. Returns the [AudioStreamPlayer] used so the
## caller can adjust pitch, etc. Returns [code]null[/code] if the key is not
## registered.
func play_sfx(key: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not _sfx_registry.has(key):
		push_warning("AudioManager: sfx key '%s' not registered - skipping." % key)
		return null

	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE

	player.stream = _sfx_registry[key]
	player.volume_db = volume_db + _get_category_offset(key)
	player.play()
	return player


## Play a spatial (3-D) sound effect at the given world [param position].
## Returns the [AudioStreamPlayer3D] node so the caller can parent / move it.
## The node is returned to pool when playback finishes.
## Returns [code]null[/code] if the key is not registered or pool exhausted.
func play_sfx_3d(key: String, position: Vector3, volume_db: float = 0.0, priority: AudioPriority = AudioPriority.NORMAL) -> AudioStreamPlayer3D:
	if not _sfx_registry.has(key):
		push_warning("AudioManager: sfx key '%s' not registered - skipping." % key)
		return null

	var player := _get_available_spatial_player(priority)
	if not player:
		return null

	player.stream = _sfx_registry[key]
	player.volume_db = volume_db + _get_category_offset(key)
	player.global_position = position

	# Apply custom attenuation if specified
	if _sfx_attenuation.has(key):
		var attn: Dictionary = _sfx_attenuation[key]
		player.max_distance = attn.get("max_distance", max_audio_distance)
		player.unit_size = attn.get("unit_size", reference_distance)
		if attn.has("attenuation_model"):
			player.attenuation_model = attn["attenuation_model"]

	player.play()
	_active_spatial_players.append(player)

	spatial_sound_spawned.emit(player, key, position)
	return player


## Play a spatial sound with full configuration options.
func play_sfx_3d_advanced(
	key: String,
	position: Vector3,
	config: Dictionary = {}
) -> AudioStreamPlayer3D:
	var volume_db: float = config.get("volume_db", 0.0)
	var priority: int = config.get("priority", AudioPriority.NORMAL)
	var max_dist: float = config.get("max_distance", max_audio_distance)
	var unit_size: float = config.get("unit_size", reference_distance)
	var pitch_scale: float = config.get("pitch_scale", 1.0)
	var pitch_variance: float = config.get("pitch_variance", 0.0)
	var doppler: bool = config.get("doppler", doppler_tracking)
	var attenuation: int = config.get("attenuation_model", AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)

	if not _sfx_registry.has(key):
		push_warning("AudioManager: sfx key '%s' not registered - skipping." % key)
		return null

	var player := _get_available_spatial_player(priority)
	if not player:
		return null

	player.stream = _sfx_registry[key]
	player.volume_db = volume_db + _get_category_offset(key)
	player.global_position = position
	player.max_distance = max_dist
	player.unit_size = unit_size
	player.attenuation_model = attenuation
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP if doppler else AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED

	# Apply pitch with optional variance
	if pitch_variance > 0.0:
		player.pitch_scale = pitch_scale + randf_range(-pitch_variance, pitch_variance)
	else:
		player.pitch_scale = pitch_scale

	player.play()
	_active_spatial_players.append(player)

	spatial_sound_spawned.emit(player, key, position)
	return player


## Play weapon fire sound with appropriate 3D positioning.
func play_weapon_fire(weapon_key: String, position: Vector3, shooter_is_local: bool = false) -> AudioStreamPlayer3D:
	var sfx_key := "weapon_%s" % weapon_key

	# Local player weapons are louder and less positional
	var config := {
		"priority": AudioPriority.HIGH,
		"volume_db": 3.0 if shooter_is_local else 0.0,
		"pitch_variance": 0.05,
	}

	if shooter_is_local:
		# Play 2D sound for local player (no positional attenuation)
		return play_sfx_3d_advanced(sfx_key, position, config)
	else:
		return play_sfx_3d_advanced(sfx_key, position, config)


## Play footstep sound based on surface type.
func play_footstep(position: Vector3, surface: SurfaceType = SurfaceType.DEFAULT) -> AudioStreamPlayer3D:
	var sfx_key := "footstep_%s" % _get_surface_name(surface)

	if not _sfx_registry.has(sfx_key):
		sfx_key = "footstep_default"

	return play_sfx_3d_advanced(sfx_key, position, {
		"priority": AudioPriority.LOW,
		"volume_db": -6.0,
		"pitch_variance": 0.1,
		"max_distance": 20.0,
	})


## Play explosion sound with appropriate distance falloff.
func play_explosion(position: Vector3, size: float = 1.0) -> AudioStreamPlayer3D:
	# Size affects volume and distance
	var volume_boost := clampf(log(size + 1.0) * 6.0, 0.0, 12.0)
	var max_dist := max_audio_distance * clampf(size, 0.5, 3.0)

	return play_sfx_3d_advanced("explosion", position, {
		"priority": AudioPriority.CRITICAL,
		"volume_db": volume_boost,
		"max_distance": max_dist,
		"unit_size": reference_distance * size,
		"pitch_scale": 1.0 / clampf(size, 0.5, 2.0),  # Larger = lower pitch
		"pitch_variance": 0.05,
	})


## Play voice/grunt sound with high priority.
func play_voice(key: String, position: Vector3) -> AudioStreamPlayer3D:
	return play_sfx_3d_advanced(key, position, {
		"priority": AudioPriority.CRITICAL,
		"volume_db": 3.0,
		"max_distance": 30.0,
	})


## Play impact sound at position.
func play_impact(position: Vector3, surface: SurfaceType = SurfaceType.DEFAULT, intensity: float = 1.0) -> AudioStreamPlayer3D:
	var sfx_key := "impact_%s" % _get_surface_name(surface)

	if not _sfx_registry.has(sfx_key):
		sfx_key = "impact_default"

	return play_sfx_3d_advanced(sfx_key, position, {
		"priority": AudioPriority.HIGH,
		"volume_db": clampf(intensity * 6.0, -6.0, 6.0),
		"pitch_variance": 0.1,
	})


# -- Ambient Audio --

## Start playing ambient sound at position (loops).
func play_ambient_3d(key: String, position: Vector3, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var player := play_sfx_3d_advanced(key, position, {
		"priority": AudioPriority.LOW,
		"volume_db": volume_db - 6.0,  # Ambient is quieter by default
		"max_distance": max_audio_distance * 0.5,
	})

	# Note: For looping, the AudioStream itself should have loop enabled
	return player


# -- Spatial Audio Management --

func _get_available_spatial_player(priority: AudioPriority) -> AudioStreamPlayer3D:
	# First, try to find an inactive player
	for player in _spatial_pool:
		if not player.playing and player not in _active_spatial_players:
			return player

	# Pool exhausted - try voice stealing based on priority
	if priority >= AudioPriority.HIGH:
		# Find the lowest priority active sound that's lower than requested
		var lowest_priority: int = priority
		var candidate: AudioStreamPlayer3D = null

		for player in _active_spatial_players:
			var player_priority := _get_player_priority(player)
			if player_priority < lowest_priority:
				lowest_priority = player_priority
				candidate = player

		if candidate:
			candidate.stop()
			_active_spatial_players.erase(candidate)
			return candidate

	# Cannot allocate a player
	push_warning("AudioManager: Spatial audio pool exhausted, priority %d sound rejected." % priority)
	return null


func _get_player_priority(player: AudioStreamPlayer3D) -> AudioPriority:
	# Determine priority based on bus or stored metadata
	# Default to NORMAL if unknown
	return AudioPriority.NORMAL


func _update_spatial_audio(_delta: float) -> void:
	# Update listener position if available
	if not _listener_node or not is_instance_valid(_listener_node):
		_try_find_listener()

	# No complex spatial updates needed - Godot handles 3D audio positioning


func _try_find_listener() -> void:
	# Try to find the active camera as the audio listener
	var viewport := get_viewport()
	if viewport:
		var camera := viewport.get_camera_3d()
		if camera:
			_listener_node = camera


func _update_occlusion(delta: float) -> void:
	if not occlusion_enabled:
		return

	# Get the physics space state once
	if not _space_state:
		var world := get_tree().root.get_world_3d()
		if world:
			_space_state = world.direct_space_state

	if not _space_state or not _listener_node:
		return

	var listener_pos := _listener_node.global_position
	var current_time := Time.get_ticks_msec() / 1000.0

	for player in _active_spatial_players:
		if not is_instance_valid(player) or not player.playing:
			continue

		# Check cache validity
		if _occlusion_cache.has(player):
			var cache: Dictionary = _occlusion_cache[player]
			if current_time - (cache.get("time", 0.0) as float) < OCCLUSION_CACHE_TIME:
				continue

		# Perform occlusion raycast
		var is_occluded := _check_occlusion(listener_pos, player.global_position)
		_occlusion_cache[player] = {"occluded": is_occluded, "time": current_time}

		# Apply occlusion effect (low-pass filter simulation via volume reduction)
		if is_occluded:
			# Muffled: reduce high frequencies by lowering volume
			# In production, use an AudioEffectLowPassFilter on the bus
			player.volume_db = player.volume_db - 6.0 if player.volume_db > -30.0 else player.volume_db
		# Note: We don't restore volume automatically - the sound will finish occluded


func _check_occlusion(from: Vector3, to: Vector3) -> bool:
	if not _space_state:
		return false

	var query := PhysicsRayQueryParameters3D.create(from, to, occlusion_mask)
	query.hit_from_inside = false
	query.hit_back_faces = false

	var result := _space_state.intersect_ray(query)
	return not result.is_empty()


func _cleanup_finished_players() -> void:
	var to_remove: Array[AudioStreamPlayer3D] = []

	for player in _active_spatial_players:
		if not player.playing:
			to_remove.append(player)
			_occlusion_cache.erase(player)

	for player in to_remove:
		_active_spatial_players.erase(player)
		# Reset player state for reuse
		player.pitch_scale = 1.0
		player.volume_db = 0.0
		player.max_distance = max_audio_distance
		player.unit_size = reference_distance


# -- Registration --

## Register an [AudioStream] as a music track under [param key].
func register_music(key: String, stream: AudioStream) -> void:
	if stream == null:
		push_warning("AudioManager: cannot register null stream for music key '%s'." % key)
		return
	_music_registry[key] = stream


## Register an [AudioStream] as a sound effect under [param key], with an
## optional [param category] for per-category volume control.
func register_sfx(key: String, stream: AudioStream, category: SFXCategory = SFXCategory.GAMEPLAY) -> void:
	if stream == null:
		push_warning("AudioManager: cannot register null stream for sfx key '%s'." % key)
		return
	_sfx_registry[key] = stream
	_sfx_categories[key] = category


## Register SFX with priority level.
func register_sfx_with_priority(key: String, stream: AudioStream, category: SFXCategory, priority: AudioPriority) -> void:
	register_sfx(key, stream, category)
	_sfx_priorities[key] = priority


## Register custom attenuation settings for a specific sound.
func register_sfx_attenuation(key: String, max_distance: float, unit_size: float, attenuation_model: int = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE) -> void:
	_sfx_attenuation[key] = {
		"max_distance": max_distance,
		"unit_size": unit_size,
		"attenuation_model": attenuation_model,
	}


## Register a surface-specific sound.
func register_surface_sound(surface: SurfaceType, sound_type: String, stream: AudioStream) -> void:
	if not _surface_sounds.has(surface):
		_surface_sounds[surface] = {}
	_surface_sounds[surface][sound_type] = stream


# -- Volume helpers --

## Set master volume (0.0 - 1.0 linear).
func set_master_volume(value: float) -> void:
	master_volume = value


## Set music volume (0.0 - 1.0 linear).
func set_music_volume(value: float) -> void:
	music_volume = value


## Set SFX volume (0.0 - 1.0 linear).
func set_sfx_volume(value: float) -> void:
	sfx_volume = value


## Set ambient volume (0.0 - 1.0 linear).
func set_ambient_volume(value: float) -> void:
	ambient_volume = value


## Set voice volume (0.0 - 1.0 linear).
func set_voice_volume(value: float) -> void:
	voice_volume = value


## Set the volume offset in dB for a specific SFX category.
func set_category_volume_db(category: SFXCategory, db: float) -> void:
	category_volume_db[category] = db


## Toggle global mute on / off.
func toggle_mute() -> void:
	muted = not muted


# -- Persistence --

## Save current audio preferences to disk.
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "ambient_volume", ambient_volume)
	cfg.set_value("audio", "voice_volume", voice_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "occlusion_enabled", occlusion_enabled)
	cfg.set_value("audio", "doppler_tracking", doppler_tracking)
	for cat_key: int in category_volume_db:
		cfg.set_value("audio_categories", str(cat_key), category_volume_db[cat_key])
	var err: Error = cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("AudioManager: failed to save settings - error %d." % err)


## Load audio preferences from disk. Falls back to defaults silently when the
## file does not exist yet.
func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(SETTINGS_PATH)
	if err != OK:
		# File likely doesn't exist yet - keep defaults.
		return
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
	ambient_volume = cfg.get_value("audio", "ambient_volume", ambient_volume)
	voice_volume = cfg.get_value("audio", "voice_volume", voice_volume)
	muted = cfg.get_value("audio", "muted", muted)
	occlusion_enabled = cfg.get_value("audio", "occlusion_enabled", occlusion_enabled)
	doppler_tracking = cfg.get_value("audio", "doppler_tracking", doppler_tracking)
	for cat_key: int in category_volume_db:
		category_volume_db[cat_key] = cfg.get_value(
			"audio_categories", str(cat_key), category_volume_db[cat_key]
		)


# -- Performance --

## Get the current audio thread time in milliseconds.
func get_audio_thread_time_ms() -> float:
	return _audio_thread_time_ms


## Get the number of active spatial sounds.
func get_active_spatial_count() -> int:
	return _active_spatial_players.size()


## Get pool usage statistics.
func get_pool_stats() -> Dictionary:
	return {
		"spatial_active": _active_spatial_players.size(),
		"spatial_pool_size": SPATIAL_POOL_SIZE,
		"spatial_usage_percent": (_active_spatial_players.size() as float / SPATIAL_POOL_SIZE) * 100.0,
		"audio_thread_time_ms": _audio_thread_time_ms,
	}


# -- Internal --

## Convert a linear 0.0-1.0 value to dB and apply it to a bus.
func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))


## Return the additive dB offset for the SFX category of [param key].
func _get_category_offset(key: String) -> float:
	if _sfx_categories.has(key):
		var cat: SFXCategory = _sfx_categories[key] as SFXCategory
		if category_volume_db.has(cat):
			return category_volume_db[cat]
	return 0.0


## Convert surface type enum to string name.
func _get_surface_name(surface: SurfaceType) -> String:
	match surface:
		SurfaceType.CONCRETE: return "concrete"
		SurfaceType.METAL: return "metal"
		SurfaceType.WOOD: return "wood"
		SurfaceType.GRASS: return "grass"
		SurfaceType.SAND: return "sand"
		SurfaceType.WATER: return "water"
		SurfaceType.GRAVEL: return "gravel"
		SurfaceType.CARPET: return "carpet"
		_: return "default"


## Set the listener node for spatial audio calculations.
func set_listener_node(node: Node3D) -> void:
	_listener_node = node


## Force clear all active spatial sounds (useful for scene transitions).
func clear_all_spatial_sounds() -> void:
	for player in _active_spatial_players:
		if is_instance_valid(player):
			player.stop()
	_active_spatial_players.clear()
	_occlusion_cache.clear()
