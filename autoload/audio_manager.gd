## AudioManager — autoload singleton that manages all audio for BattleZone Party.
##
## Handles background music with crossfade transitions, one-shot and spatial SFX,
## per-category volume control, and persistent audio preferences.
extends Node

# ── Signals ──────────────────────────────────────────────────────────────────

## Emitted whenever any volume or mute setting changes.
signal settings_changed

# ── Constants ────────────────────────────────────────────────────────────────

const SETTINGS_PATH: String = "user://audio_settings.cfg"
const SFX_POOL_SIZE: int = 8

## Audio buses expected to exist in the project (index 0 = Master).
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"

## SFX categories — used for per-category volume offsets.
enum SFXCategory { UI, GAMEPLAY, IMPACT, AMBIENT }

# ── Exported / Configurable ──────────────────────────────────────────────────

## Default crossfade duration in seconds when none is specified.
@export var default_crossfade: float = 1.0

# ── Volume state (0.0 – 1.0 linear) ─────────────────────────────────────────

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

var muted: bool = false:
	set(v):
		muted = v
		AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_MASTER), muted)
		settings_changed.emit()

## Per-category volume offsets in dB (additive on top of SFX bus).
var category_volume_db: Dictionary = {
	SFXCategory.UI: 0.0,
	SFXCategory.GAMEPLAY: 0.0,
	SFXCategory.IMPACT: 0.0,
	SFXCategory.AMBIENT: -6.0,
}

# ── Registries ───────────────────────────────────────────────────────────────

## Registered music streams keyed by string identifier.
var _music_registry: Dictionary = {}  # String -> AudioStream

## Registered SFX streams keyed by string identifier.
var _sfx_registry: Dictionary = {}    # String -> AudioStream

## Optional mapping of sfx key -> SFXCategory for automatic category volumes.
var _sfx_categories: Dictionary = {}  # String -> SFXCategory

# ── Internal nodes ───────────────────────────────────────────────────────────

## Two music players used for crossfading (A ↔ B).
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
## Which player is currently "active" (true = A, false = B).
var _music_active_is_a: bool = true

## Pool of AudioStreamPlayers for one-shot SFX.
var _sfx_pool: Array[AudioStreamPlayer] = []
## Index cycling through the pool (round-robin).
var _sfx_pool_index: int = 0

## Currently playing music key (empty string = nothing).
var _current_music_key: String = ""

## Tween references so we can kill in-progress crossfades.
var _fade_tween: Tween = null

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_create_music_players()
	_create_sfx_pool()
	load_settings()


## Make sure the required audio buses exist at runtime.  If the project
## doesn't ship a bus layout with Music / SFX buses we create them in code
## so nothing breaks.
func _ensure_audio_buses() -> void:
	for bus_name: StringName in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)
	# Apply saved / default volumes to buses.
	_apply_bus_volume(BUS_MASTER, master_volume)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	_apply_bus_volume(BUS_SFX, sfx_volume)
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

# ── Music ────────────────────────────────────────────────────────────────────

## Play a music track by its registered key, crossfading from the current
## track over [param fade_duration] seconds.  If the same key is already
## playing the call is ignored.
func play_music(key: String, fade_duration: float = 1.0) -> void:
	if key == _current_music_key:
		return

	if not _music_registry.has(key):
		push_warning("AudioManager: music key '%s' not registered — skipping." % key)
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

# ── SFX ──────────────────────────────────────────────────────────────────────

## Play a one-shot sound effect.  Returns the [AudioStreamPlayer] used so the
## caller can adjust pitch, etc.  Returns [code]null[/code] if the key is not
## registered.
func play_sfx(key: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not _sfx_registry.has(key):
		push_warning("AudioManager: sfx key '%s' not registered — skipping." % key)
		return null

	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE

	player.stream = _sfx_registry[key]
	player.volume_db = volume_db + _get_category_offset(key)
	player.play()
	return player


## Play a spatial (3-D) sound effect at the given world [param position].
## Returns the [AudioStreamPlayer3D] node so the caller can parent / move it.
## The node auto-frees when playback finishes.
## Returns [code]null[/code] if the key is not registered.
func play_sfx_3d(key: String, position: Vector3, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	if not _sfx_registry.has(key):
		push_warning("AudioManager: sfx key '%s' not registered — skipping." % key)
		return null

	var player := AudioStreamPlayer3D.new()
	player.name = &"SFX3D_%s" % key
	player.bus = BUS_SFX
	player.stream = _sfx_registry[key]
	player.volume_db = volume_db + _get_category_offset(key)
	# Add to tree so it can play, then position it.
	add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()
	return player

# ── Registration ─────────────────────────────────────────────────────────────

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

# ── Volume helpers ───────────────────────────────────────────────────────────

## Set master volume (0.0 – 1.0 linear).
func set_master_volume(value: float) -> void:
	master_volume = value


## Set music volume (0.0 – 1.0 linear).
func set_music_volume(value: float) -> void:
	music_volume = value


## Set SFX volume (0.0 – 1.0 linear).
func set_sfx_volume(value: float) -> void:
	sfx_volume = value


## Set the volume offset in dB for a specific SFX category.
func set_category_volume_db(category: SFXCategory, db: float) -> void:
	category_volume_db[category] = db


## Toggle global mute on / off.
func toggle_mute() -> void:
	muted = not muted

# ── Persistence ──────────────────────────────────────────────────────────────

## Save current audio preferences to disk.
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "muted", muted)
	for cat_key: int in category_volume_db:
		cfg.set_value("audio_categories", str(cat_key), category_volume_db[cat_key])
	var err: Error = cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("AudioManager: failed to save settings — error %d." % err)


## Load audio preferences from disk.  Falls back to defaults silently when the
## file does not exist yet.
func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(SETTINGS_PATH)
	if err != OK:
		# File likely doesn't exist yet — keep defaults.
		return
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
	muted = cfg.get_value("audio", "muted", muted)
	for cat_key: int in category_volume_db:
		category_volume_db[cat_key] = cfg.get_value(
			"audio_categories", str(cat_key), category_volume_db[cat_key]
		)

# ── Internal ─────────────────────────────────────────────────────────────────

## Convert a linear 0.0–1.0 value to dB and apply it to a bus.
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
