## ProfileManager - Settings profiles and cloud sync system.
##
## Manages saving, loading, and syncing user settings profiles including
## accessibility settings, theme preferences, HUD layouts, control mappings,
## and all customization options. Supports multiple profiles, export/import,
## and cloud synchronization.
extends Node

# -- Signals --

## Emitted when a profile is loaded.
signal profile_loaded(profile_name: String)
## Emitted when a profile is saved.
signal profile_saved(profile_name: String)
## Emitted when a profile is deleted.
signal profile_deleted(profile_name: String)
## Emitted when a profile is created.
signal profile_created(profile_name: String)
## Emitted when active profile changes.
signal active_profile_changed(profile_name: String)
## Emitted when sync status changes.
signal sync_status_changed(status: SyncStatus)
## Emitted when sync completes.
signal sync_completed(success: bool, message: String)
## Emitted when settings change history is updated.
signal history_updated

# -- Constants --

const PROFILES_PATH: String = "user://profiles/"
const ACTIVE_PROFILE_PATH: String = "user://active_profile.cfg"
const SYNC_METADATA_PATH: String = "user://sync_metadata.cfg"
const HISTORY_PATH: String = "user://settings_history.cfg"
const DEFAULT_PROFILE_NAME: String = "Default"
const MAX_PROFILES: int = 10
const MAX_HISTORY_ENTRIES: int = 50
const PROFILE_VERSION: int = 1

# -- Enums --

## Cloud sync status.
enum SyncStatus {
	DISABLED,
	IDLE,
	SYNCING,
	ERROR,
	OFFLINE
}

## Profile data categories.
enum ProfileCategory {
	ALL,
	ACCESSIBILITY,
	THEME,
	HUD_LAYOUT,
	CONTROLS,
	AUDIO,
	GRAPHICS,
	GAMEPLAY
}

# -- State --

## Current sync status.
var sync_status: SyncStatus = SyncStatus.DISABLED:
	set(value):
		sync_status = value
		sync_status_changed.emit(value)

## Currently active profile name.
var active_profile: String = DEFAULT_PROFILE_NAME:
	set(value):
		if value != active_profile:
			active_profile = value
			_save_active_profile()
			active_profile_changed.emit(value)

## All loaded profiles.
var profiles: Dictionary = {}  # profile_name -> ProfileData

## Settings change history.
var settings_history: Array[Dictionary] = []

## Cloud sync enabled.
var cloud_sync_enabled: bool = false

## Last sync timestamp.
var last_sync_time: int = 0

## User ID for cloud sync (placeholder).
var cloud_user_id: String = ""

## Pending sync data.
var _pending_sync: Dictionary = {}

## Sync queue for offline changes.
var _sync_queue: Array[Dictionary] = []


# -- Lifecycle --

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_profiles_directory()
	_load_profiles()
	_load_active_profile()
	_load_sync_metadata()
	_load_history()


func _ensure_profiles_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("profiles"):
		dir.make_dir("profiles")


# -- Public API: Profile Management --

## Get list of all profile names.
func get_profile_names() -> Array[String]:
	var names: Array[String] = []
	for name: String in profiles.keys():
		names.append(name)

	# Ensure default is always first
	if DEFAULT_PROFILE_NAME in names:
		names.erase(DEFAULT_PROFILE_NAME)
		names.insert(0, DEFAULT_PROFILE_NAME)

	return names


## Get profile count.
func get_profile_count() -> int:
	return profiles.size()


## Check if profile exists.
func profile_exists(profile_name: String) -> bool:
	return profiles.has(profile_name)


## Get profile data.
func get_profile(profile_name: String) -> Dictionary:
	if profiles.has(profile_name):
		return profiles[profile_name].duplicate(true)
	return {}


## Get active profile data.
func get_active_profile() -> Dictionary:
	return get_profile(active_profile)


## Create a new profile.
func create_profile(profile_name: String, copy_from: String = "") -> bool:
	if profiles.size() >= MAX_PROFILES:
		push_warning("ProfileManager: Maximum profile limit reached")
		return false

	if profiles.has(profile_name):
		push_warning("ProfileManager: Profile '%s' already exists" % profile_name)
		return false

	if profile_name.is_empty() or profile_name.length() > 32:
		push_warning("ProfileManager: Invalid profile name")
		return false

	var profile_data: Dictionary

	if not copy_from.is_empty() and profiles.has(copy_from):
		profile_data = profiles[copy_from].duplicate(true)
	else:
		profile_data = _create_default_profile_data()

	profile_data["name"] = profile_name
	profile_data["created_at"] = Time.get_unix_time_from_system()
	profile_data["modified_at"] = Time.get_unix_time_from_system()
	profile_data["version"] = PROFILE_VERSION

	profiles[profile_name] = profile_data
	_save_profile(profile_name)

	_add_history_entry("create_profile", {"profile": profile_name})
	profile_created.emit(profile_name)

	return true


## Delete a profile.
func delete_profile(profile_name: String) -> bool:
	if profile_name == DEFAULT_PROFILE_NAME:
		push_warning("ProfileManager: Cannot delete default profile")
		return false

	if not profiles.has(profile_name):
		return false

	profiles.erase(profile_name)

	# Delete file
	var path := PROFILES_PATH + profile_name.to_lower().replace(" ", "_") + ".profile"
	var dir := DirAccess.open(PROFILES_PATH)
	if dir:
		dir.remove(path)

	# Switch to default if this was active
	if active_profile == profile_name:
		active_profile = DEFAULT_PROFILE_NAME
		load_profile(DEFAULT_PROFILE_NAME)

	_add_history_entry("delete_profile", {"profile": profile_name})
	profile_deleted.emit(profile_name)

	return true


## Rename a profile.
func rename_profile(old_name: String, new_name: String) -> bool:
	if old_name == DEFAULT_PROFILE_NAME:
		push_warning("ProfileManager: Cannot rename default profile")
		return false

	if not profiles.has(old_name):
		return false

	if profiles.has(new_name):
		push_warning("ProfileManager: Profile '%s' already exists" % new_name)
		return false

	var profile_data: Dictionary = profiles[old_name]
	profile_data["name"] = new_name
	profile_data["modified_at"] = Time.get_unix_time_from_system()

	profiles[new_name] = profile_data
	profiles.erase(old_name)

	# Delete old file
	var old_path := PROFILES_PATH + old_name.to_lower().replace(" ", "_") + ".profile"
	var dir := DirAccess.open(PROFILES_PATH)
	if dir:
		dir.remove(old_path)

	# Save new file
	_save_profile(new_name)

	# Update active if needed
	if active_profile == old_name:
		active_profile = new_name

	return true


## Load and apply a profile.
func load_profile(profile_name: String) -> bool:
	if not profiles.has(profile_name):
		push_warning("ProfileManager: Profile '%s' not found" % profile_name)
		return false

	var profile_data: Dictionary = profiles[profile_name]

	# Apply settings to all systems
	_apply_accessibility_settings(profile_data.get("accessibility", {}))
	_apply_theme_settings(profile_data.get("theme", {}))
	_apply_hud_settings(profile_data.get("hud", {}))
	_apply_control_settings(profile_data.get("controls", {}))
	_apply_audio_settings(profile_data.get("audio", {}))
	_apply_graphics_settings(profile_data.get("graphics", {}))
	_apply_gameplay_settings(profile_data.get("gameplay", {}))

	active_profile = profile_name
	_add_history_entry("load_profile", {"profile": profile_name})
	profile_loaded.emit(profile_name)

	return true


## Save current settings to active profile.
func save_active_profile() -> bool:
	return save_profile(active_profile)


## Save current settings to a specific profile.
func save_profile(profile_name: String) -> bool:
	if not profiles.has(profile_name):
		# Create new profile
		if not create_profile(profile_name):
			return false

	var profile_data := _gather_current_settings()
	profile_data["name"] = profile_name
	profile_data["modified_at"] = Time.get_unix_time_from_system()
	profile_data["version"] = PROFILE_VERSION

	if profiles.has(profile_name):
		profile_data["created_at"] = profiles[profile_name].get("created_at", Time.get_unix_time_from_system())
	else:
		profile_data["created_at"] = Time.get_unix_time_from_system()

	profiles[profile_name] = profile_data
	_save_profile(profile_name)

	_add_history_entry("save_profile", {"profile": profile_name})
	profile_saved.emit(profile_name)

	# Queue for cloud sync if enabled
	if cloud_sync_enabled:
		_queue_sync(profile_name, profile_data)

	return true


## Save specific category to active profile.
func save_category(category: ProfileCategory) -> void:
	if not profiles.has(active_profile):
		return

	var profile_data: Dictionary = profiles[active_profile]
	var category_data := _gather_category_settings(category)

	match category:
		ProfileCategory.ACCESSIBILITY:
			profile_data["accessibility"] = category_data
		ProfileCategory.THEME:
			profile_data["theme"] = category_data
		ProfileCategory.HUD_LAYOUT:
			profile_data["hud"] = category_data
		ProfileCategory.CONTROLS:
			profile_data["controls"] = category_data
		ProfileCategory.AUDIO:
			profile_data["audio"] = category_data
		ProfileCategory.GRAPHICS:
			profile_data["graphics"] = category_data
		ProfileCategory.GAMEPLAY:
			profile_data["gameplay"] = category_data

	profile_data["modified_at"] = Time.get_unix_time_from_system()
	profiles[active_profile] = profile_data
	_save_profile(active_profile)


# -- Public API: Export/Import --

## Export profile to JSON string.
func export_profile_json(profile_name: String) -> String:
	if not profiles.has(profile_name):
		return ""

	var profile_data: Dictionary = profiles[profile_name]
	var export_data := _serialize_profile(profile_data)

	return JSON.stringify(export_data, "  ")


## Import profile from JSON string.
func import_profile_json(json_string: String, profile_name: String) -> bool:
	var json := JSON.new()
	var err := json.parse(json_string)

	if err != OK:
		push_warning("ProfileManager: Failed to parse profile JSON - %s" % json.get_error_message())
		return false

	var data: Variant = json.data
	if not data is Dictionary:
		push_warning("ProfileManager: Invalid profile data format")
		return false

	var profile_data := _deserialize_profile(data as Dictionary)
	profile_data["name"] = profile_name
	profile_data["imported_at"] = Time.get_unix_time_from_system()

	profiles[profile_name] = profile_data
	_save_profile(profile_name)

	_add_history_entry("import_profile", {"profile": profile_name})
	profile_created.emit(profile_name)

	return true


## Export profile to clipboard.
func export_to_clipboard(profile_name: String) -> void:
	var json := export_profile_json(profile_name)
	if not json.is_empty():
		DisplayServer.clipboard_set(json)


## Import profile from clipboard.
func import_from_clipboard(profile_name: String) -> bool:
	var json := DisplayServer.clipboard_get()
	return import_profile_json(json, profile_name)


## Export all profiles to a single JSON file.
func export_all_profiles_json() -> String:
	var export_data := {
		"version": PROFILE_VERSION,
		"exported_at": Time.get_unix_time_from_system(),
		"profiles": {}
	}

	for name: String in profiles.keys():
		export_data["profiles"][name] = _serialize_profile(profiles[name])

	return JSON.stringify(export_data, "  ")


## Import all profiles from JSON.
func import_all_profiles_json(json_string: String, overwrite: bool = false) -> Dictionary:
	var result := {
		"success": false,
		"imported": 0,
		"skipped": 0,
		"errors": []
	}

	var json := JSON.new()
	var err := json.parse(json_string)

	if err != OK:
		result["errors"].append("Failed to parse JSON: %s" % json.get_error_message())
		return result

	var data: Variant = json.data
	if not data is Dictionary:
		result["errors"].append("Invalid data format")
		return result

	var import_data := data as Dictionary
	if not import_data.has("profiles"):
		result["errors"].append("No profiles found in data")
		return result

	var profiles_data: Dictionary = import_data["profiles"]

	for name: String in profiles_data.keys():
		if profiles.has(name) and not overwrite:
			result["skipped"] += 1
			continue

		var profile_data := _deserialize_profile(profiles_data[name] as Dictionary)
		profile_data["name"] = name
		profile_data["imported_at"] = Time.get_unix_time_from_system()

		profiles[name] = profile_data
		_save_profile(name)
		result["imported"] += 1

	result["success"] = true
	return result


# -- Public API: Cloud Sync --

## Enable cloud sync.
func enable_cloud_sync(user_id: String) -> void:
	cloud_user_id = user_id
	cloud_sync_enabled = true
	sync_status = SyncStatus.IDLE
	_save_sync_metadata()

	# Attempt initial sync
	sync_now()


## Disable cloud sync.
func disable_cloud_sync() -> void:
	cloud_sync_enabled = false
	cloud_user_id = ""
	sync_status = SyncStatus.DISABLED
	_save_sync_metadata()


## Trigger immediate sync.
func sync_now() -> void:
	if not cloud_sync_enabled:
		sync_completed.emit(false, "Cloud sync is disabled")
		return

	if sync_status == SyncStatus.SYNCING:
		return

	sync_status = SyncStatus.SYNCING
	_perform_sync()


## Check if any changes are pending sync.
func has_pending_sync() -> bool:
	return not _sync_queue.is_empty()


## Get pending sync count.
func get_pending_sync_count() -> int:
	return _sync_queue.size()


# -- Public API: Settings History --

## Get settings change history.
func get_history() -> Array[Dictionary]:
	return settings_history.duplicate()


## Get recent history entries.
func get_recent_history(count: int = 10) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start := maxi(0, settings_history.size() - count)

	for i: int in range(start, settings_history.size()):
		result.append(settings_history[i])

	return result


## Clear settings history.
func clear_history() -> void:
	settings_history.clear()
	_save_history()
	history_updated.emit()


## Revert to a specific history entry.
func revert_to_history(entry_index: int) -> bool:
	if entry_index < 0 or entry_index >= settings_history.size():
		return false

	var entry: Dictionary = settings_history[entry_index]
	var profile_name: String = entry.get("profile", active_profile)

	if entry.has("before_state"):
		var before_state: Dictionary = entry["before_state"]

		# Apply the before state
		if profiles.has(profile_name):
			profiles[profile_name] = before_state.duplicate(true)
			_save_profile(profile_name)

			if profile_name == active_profile:
				load_profile(profile_name)

			return true

	return false


# -- Public API: Reset --

## Reset active profile to defaults.
func reset_active_profile() -> void:
	reset_profile(active_profile)


## Reset specific profile to defaults.
func reset_profile(profile_name: String) -> void:
	if not profiles.has(profile_name):
		return

	var profile_data := _create_default_profile_data()
	profile_data["name"] = profile_name
	profile_data["created_at"] = profiles[profile_name].get("created_at", Time.get_unix_time_from_system())
	profile_data["modified_at"] = Time.get_unix_time_from_system()
	profile_data["version"] = PROFILE_VERSION

	profiles[profile_name] = profile_data
	_save_profile(profile_name)

	if profile_name == active_profile:
		load_profile(profile_name)

	_add_history_entry("reset_profile", {"profile": profile_name})


## Reset all profiles.
func reset_all_profiles() -> void:
	# Clear all except default
	var to_delete: Array[String] = []
	for name: String in profiles.keys():
		if name != DEFAULT_PROFILE_NAME:
			to_delete.append(name)

	for name: String in to_delete:
		delete_profile(name)

	# Reset default
	reset_profile(DEFAULT_PROFILE_NAME)


# -- Internal Methods: Profile Data --

func _create_default_profile_data() -> Dictionary:
	return {
		"name": DEFAULT_PROFILE_NAME,
		"version": PROFILE_VERSION,
		"created_at": Time.get_unix_time_from_system(),
		"modified_at": Time.get_unix_time_from_system(),
		"accessibility": _get_default_accessibility(),
		"theme": _get_default_theme(),
		"hud": _get_default_hud(),
		"controls": _get_default_controls(),
		"audio": _get_default_audio(),
		"graphics": _get_default_graphics(),
		"gameplay": _get_default_gameplay(),
	}


func _gather_current_settings() -> Dictionary:
	return {
		"accessibility": _gather_category_settings(ProfileCategory.ACCESSIBILITY),
		"theme": _gather_category_settings(ProfileCategory.THEME),
		"hud": _gather_category_settings(ProfileCategory.HUD_LAYOUT),
		"controls": _gather_category_settings(ProfileCategory.CONTROLS),
		"audio": _gather_category_settings(ProfileCategory.AUDIO),
		"graphics": _gather_category_settings(ProfileCategory.GRAPHICS),
		"gameplay": _gather_category_settings(ProfileCategory.GAMEPLAY),
	}


func _gather_category_settings(category: ProfileCategory) -> Dictionary:
	match category:
		ProfileCategory.ACCESSIBILITY:
			return _gather_accessibility_settings()
		ProfileCategory.THEME:
			return _gather_theme_settings()
		ProfileCategory.HUD_LAYOUT:
			return _gather_hud_settings()
		ProfileCategory.CONTROLS:
			return _gather_control_settings()
		ProfileCategory.AUDIO:
			return _gather_audio_settings()
		ProfileCategory.GRAPHICS:
			return _gather_graphics_settings()
		ProfileCategory.GAMEPLAY:
			return _gather_gameplay_settings()
		_:
			return {}


# -- Internal Methods: Gather Settings --

func _gather_accessibility_settings() -> Dictionary:
	# Would gather from AccessibilityManager
	# This is a placeholder implementation
	return {
		"colorblind_mode": 0,
		"high_contrast": false,
		"large_text": false,
		"ui_scale": 1.0,
		"reduce_motion": false,
		"subtitles": false,
		"screen_reader": false,
	}


func _gather_theme_settings() -> Dictionary:
	# Would gather from ThemeEngine
	return {
		"active_theme": "Default",
		"primary_color": "#3399FF",
		"secondary_color": "#2672BF",
		"accent_color": "#FFB333",
	}


func _gather_hud_settings() -> Dictionary:
	# Would gather from HUDEditor
	return {
		"layout": "Default",
		"elements": {}
	}


func _gather_control_settings() -> Dictionary:
	# Would gather control bindings
	return {
		"input_mode": "standard",
		"sensitivity": 1.0,
		"invert_y": false,
	}


func _gather_audio_settings() -> Dictionary:
	# Would gather from AudioManager
	return {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
	}


func _gather_graphics_settings() -> Dictionary:
	# Would gather from GraphicsManager
	return {
		"quality": "high",
		"vsync": true,
		"fullscreen": true,
	}


func _gather_gameplay_settings() -> Dictionary:
	return {
		"auto_aim": false,
		"vibration": true,
	}


# -- Internal Methods: Apply Settings --

func _apply_accessibility_settings(settings: Dictionary) -> void:
	# Would apply to AccessibilityManager
	pass


func _apply_theme_settings(settings: Dictionary) -> void:
	# Would apply to ThemeEngine
	pass


func _apply_hud_settings(settings: Dictionary) -> void:
	# Would apply to HUDEditor
	pass


func _apply_control_settings(settings: Dictionary) -> void:
	# Would apply control bindings
	pass


func _apply_audio_settings(settings: Dictionary) -> void:
	# Would apply to AudioManager
	pass


func _apply_graphics_settings(settings: Dictionary) -> void:
	# Would apply to GraphicsManager
	pass


func _apply_gameplay_settings(settings: Dictionary) -> void:
	# Would apply gameplay settings
	pass


# -- Internal Methods: Default Settings --

func _get_default_accessibility() -> Dictionary:
	return {
		"colorblind_mode": 0,
		"high_contrast": false,
		"large_text": false,
		"text_size_preset": 1,
		"ui_scale": 1.0,
		"reduce_motion": false,
		"reduce_screen_flash": false,
		"flash_intensity": 1.0,
		"subtitles": false,
		"subtitle_size": 1.0,
		"visual_sound_indicators": false,
		"mono_audio": false,
		"screen_reader": false,
		"text_to_speech": false,
		"keyboard_navigation": true,
		"controller_support": true,
		"touch_hold_duration": 0.4,
		"double_tap_prevention": false,
		"simplified_language": false,
		"animation_speed": 1,
		"confirm_important_actions": true,
	}


func _get_default_theme() -> Dictionary:
	return {
		"active_theme": "Default",
		"custom_colors": {},
		"font_family": "",
		"font_size_base": 16,
	}


func _get_default_hud() -> Dictionary:
	return {
		"active_layout": "Default",
		"elements": {},
		"mode_layouts": {},
	}


func _get_default_controls() -> Dictionary:
	return {
		"input_mode": "standard",
		"sensitivity_x": 1.0,
		"sensitivity_y": 1.0,
		"invert_y": false,
		"invert_x": false,
		"bindings": {},
	}


func _get_default_audio() -> Dictionary:
	return {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
		"ambient_volume": 0.7,
		"voice_volume": 1.0,
		"muted": false,
	}


func _get_default_graphics() -> Dictionary:
	return {
		"quality_preset": "high",
		"resolution_scale": 1.0,
		"vsync": true,
		"fullscreen": true,
		"max_fps": 60,
		"shadows": true,
		"bloom": true,
		"anti_aliasing": 1,
	}


func _get_default_gameplay() -> Dictionary:
	return {
		"auto_aim": false,
		"aim_assist_strength": 0.5,
		"vibration": true,
		"vibration_intensity": 1.0,
		"crosshair_style": 0,
		"crosshair_color": "#FFFFFF",
		"hit_marker": true,
		"damage_numbers": true,
	}


# -- Internal Methods: Persistence --

func _save_profile(profile_name: String) -> void:
	if not profiles.has(profile_name):
		return

	var profile_data: Dictionary = profiles[profile_name]
	var path := PROFILES_PATH + profile_name.to_lower().replace(" ", "_") + ".profile"

	var cfg := ConfigFile.new()

	# Metadata
	cfg.set_value("meta", "name", profile_data.get("name", profile_name))
	cfg.set_value("meta", "version", profile_data.get("version", PROFILE_VERSION))
	cfg.set_value("meta", "created_at", profile_data.get("created_at", 0))
	cfg.set_value("meta", "modified_at", profile_data.get("modified_at", 0))

	# Categories
	for category: String in ["accessibility", "theme", "hud", "controls", "audio", "graphics", "gameplay"]:
		if profile_data.has(category):
			for key: String in (profile_data[category] as Dictionary).keys():
				cfg.set_value(category, key, (profile_data[category] as Dictionary)[key])

	var err := cfg.save(path)
	if err != OK:
		push_warning("ProfileManager: Failed to save profile '%s'" % profile_name)


func _load_profiles() -> void:
	var dir := DirAccess.open(PROFILES_PATH)
	if not dir:
		# Create default profile if directory doesn't exist
		create_profile(DEFAULT_PROFILE_NAME)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".profile"):
			_load_profile_file(PROFILES_PATH + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	# Ensure default profile exists
	if not profiles.has(DEFAULT_PROFILE_NAME):
		create_profile(DEFAULT_PROFILE_NAME)


func _load_profile_file(path: String) -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return

	var profile_data := {}

	# Metadata
	profile_data["name"] = cfg.get_value("meta", "name", "")
	profile_data["version"] = cfg.get_value("meta", "version", PROFILE_VERSION)
	profile_data["created_at"] = cfg.get_value("meta", "created_at", 0)
	profile_data["modified_at"] = cfg.get_value("meta", "modified_at", 0)

	# Categories
	for category: String in ["accessibility", "theme", "hud", "controls", "audio", "graphics", "gameplay"]:
		if cfg.has_section(category):
			profile_data[category] = {}
			for key: String in cfg.get_section_keys(category):
				(profile_data[category] as Dictionary)[key] = cfg.get_value(category, key)

	var profile_name: String = profile_data.get("name", "")
	if not profile_name.is_empty():
		profiles[profile_name] = profile_data


func _save_active_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("active", "profile_name", active_profile)
	cfg.save(ACTIVE_PROFILE_PATH)


func _load_active_profile() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(ACTIVE_PROFILE_PATH)

	if err == OK:
		var profile_name: String = cfg.get_value("active", "profile_name", DEFAULT_PROFILE_NAME)
		if profiles.has(profile_name):
			active_profile = profile_name


func _save_sync_metadata() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sync", "enabled", cloud_sync_enabled)
	cfg.set_value("sync", "user_id", cloud_user_id)
	cfg.set_value("sync", "last_sync", last_sync_time)
	cfg.save(SYNC_METADATA_PATH)


func _load_sync_metadata() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SYNC_METADATA_PATH)

	if err == OK:
		cloud_sync_enabled = cfg.get_value("sync", "enabled", false)
		cloud_user_id = cfg.get_value("sync", "user_id", "")
		last_sync_time = cfg.get_value("sync", "last_sync", 0)

		if cloud_sync_enabled:
			sync_status = SyncStatus.IDLE


func _save_history() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("history", "entries", settings_history)
	cfg.save(HISTORY_PATH)


func _load_history() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(HISTORY_PATH)

	if err == OK:
		var entries: Variant = cfg.get_value("history", "entries", [])
		if entries is Array:
			settings_history.assign(entries)


# -- Internal Methods: History --

func _add_history_entry(action: String, data: Dictionary) -> void:
	var entry := {
		"timestamp": Time.get_unix_time_from_system(),
		"action": action,
		"data": data,
		"profile": active_profile,
	}

	# Store before state for reverting
	if profiles.has(active_profile):
		entry["before_state"] = profiles[active_profile].duplicate(true)

	settings_history.append(entry)

	# Limit history size
	while settings_history.size() > MAX_HISTORY_ENTRIES:
		settings_history.remove_at(0)

	_save_history()
	history_updated.emit()


# -- Internal Methods: Sync --

func _queue_sync(profile_name: String, profile_data: Dictionary) -> void:
	_sync_queue.append({
		"profile_name": profile_name,
		"profile_data": profile_data,
		"timestamp": Time.get_unix_time_from_system()
	})


func _perform_sync() -> void:
	# This is a placeholder for cloud sync implementation
	# In a real implementation, this would:
	# 1. Connect to cloud service
	# 2. Upload pending changes
	# 3. Download remote changes
	# 4. Resolve conflicts
	# 5. Update local state

	# Simulate async sync
	await get_tree().create_timer(1.0).timeout

	# Mark sync complete
	_sync_queue.clear()
	last_sync_time = Time.get_unix_time_from_system() as int
	sync_status = SyncStatus.IDLE
	_save_sync_metadata()

	sync_completed.emit(true, "Sync completed successfully")


# -- Internal Methods: Serialization --

func _serialize_profile(profile_data: Dictionary) -> Dictionary:
	var result := {}

	for key: String in profile_data.keys():
		var value: Variant = profile_data[key]

		if value is Color:
			result[key] = "#" + (value as Color).to_html(true)
		elif value is Vector2:
			result[key] = {"x": (value as Vector2).x, "y": (value as Vector2).y}
		elif value is Dictionary:
			result[key] = _serialize_profile(value as Dictionary)
		else:
			result[key] = value

	return result


func _deserialize_profile(data: Dictionary) -> Dictionary:
	var result := {}

	for key: String in data.keys():
		var value: Variant = data[key]

		if value is String and (value as String).begins_with("#"):
			result[key] = Color(value as String)
		elif value is Dictionary:
			var dict_val := value as Dictionary
			if dict_val.has("x") and dict_val.has("y") and dict_val.size() == 2:
				result[key] = Vector2(dict_val["x"] as float, dict_val["y"] as float)
			else:
				result[key] = _deserialize_profile(dict_val)
		else:
			result[key] = value

	return result
