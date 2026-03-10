## ProgressionManager Autoload Singleton
##
## Manages player XP, leveling (1-100), weapon unlocks, and prestige system.
## All data persists to user:// for cross-session retention.
## XP curve is exponential with reasonable caps for fair progression.
##
## Usage:
##   ProgressionManager.add_xp(amount)
##   ProgressionManager.get_level()
##   ProgressionManager.is_weapon_unlocked("shotgun")
extends Node


# region — Signals

## Emitted when the player gains XP.
signal xp_gained(amount: int, total_xp: int)

## Emitted when the player levels up.
signal level_up(new_level: int, rewards: Dictionary)

## Emitted when a weapon is unlocked.
signal weapon_unlocked(weapon_id: String, weapon_data: Dictionary)

## Emitted when the player prestiges.
signal prestige_gained(prestige_level: int)

## Emitted when progression data is loaded.
signal data_loaded()

## Emitted when progression data is saved.
signal data_saved()

# endregion


# region — Constants

## Maximum player level before prestige.
const MAX_LEVEL: int = 100

## Maximum prestige level.
const MAX_PRESTIGE: int = 10

## Base XP required for level 2.
const BASE_XP: int = 100

## XP growth rate per level (exponential factor).
const XP_GROWTH_RATE: float = 1.15

## XP cap per level to prevent extreme grinding.
const XP_CAP_PER_LEVEL: int = 50000

## Save file path.
const SAVE_PATH: String = "user://progression_data.json"

## XP awarded for various actions.
const XP_REWARDS: Dictionary = {
	"match_win": 150,
	"match_complete": 50,
	"kill": 15,
	"assist": 8,
	"headshot": 25,
	"objective_capture": 30,
	"objective_defend": 20,
	"first_blood": 50,
	"kill_streak_3": 30,
	"kill_streak_5": 50,
	"kill_streak_7": 75,
	"kill_streak_10": 100,
	"play_minute": 2,
	"daily_first_match": 100,
	"team_win": 75,
}

## Weapon definitions with unlock requirements.
const WEAPONS: Dictionary = {
	"blaster": {
		"name": "Blaster",
		"description": "Standard energy pistol. Reliable and accurate.",
		"unlock_level": 1,
		"damage": 25,
		"fire_rate": 0.3,
		"range": 50,
		"category": "pistol",
	},
	"rapid_fire": {
		"name": "Rapid Fire",
		"description": "High fire rate submachine gun. Great for close combat.",
		"unlock_level": 5,
		"damage": 12,
		"fire_rate": 0.08,
		"range": 35,
		"category": "smg",
	},
	"shotgun": {
		"name": "Shotgun",
		"description": "Devastating at close range. Spread damage.",
		"unlock_level": 10,
		"damage": 80,
		"fire_rate": 0.8,
		"range": 20,
		"category": "shotgun",
	},
	"sniper": {
		"name": "Sniper Rifle",
		"description": "Long range precision weapon. High damage, slow fire rate.",
		"unlock_level": 15,
		"damage": 100,
		"fire_rate": 1.5,
		"range": 100,
		"category": "sniper",
	},
	"assault_rifle": {
		"name": "Assault Rifle",
		"description": "Balanced automatic rifle. Good at all ranges.",
		"unlock_level": 20,
		"damage": 20,
		"fire_rate": 0.12,
		"range": 60,
		"category": "rifle",
	},
	"rocket_launcher": {
		"name": "Rocket Launcher",
		"description": "Explosive projectile weapon. Area damage.",
		"unlock_level": 25,
		"damage": 150,
		"fire_rate": 2.0,
		"range": 80,
		"category": "explosive",
	},
	"flamethrower": {
		"name": "Flamethrower",
		"description": "Continuous fire damage. Burns enemies over time.",
		"unlock_level": 30,
		"damage": 8,
		"fire_rate": 0.05,
		"range": 15,
		"category": "special",
	},
	"plasma_cannon": {
		"name": "Plasma Cannon",
		"description": "Charged shot weapon. Maximum damage when fully charged.",
		"unlock_level": 40,
		"damage": 120,
		"fire_rate": 1.2,
		"range": 70,
		"category": "special",
	},
	"minigun": {
		"name": "Minigun",
		"description": "Extremely high fire rate. Requires spin-up time.",
		"unlock_level": 50,
		"damage": 8,
		"fire_rate": 0.03,
		"range": 45,
		"category": "heavy",
	},
	"laser_beam": {
		"name": "Laser Beam",
		"description": "Continuous beam weapon. Perfect accuracy.",
		"unlock_level": 60,
		"damage": 30,
		"fire_rate": 0.0,
		"range": 80,
		"category": "special",
	},
	"grenade_launcher": {
		"name": "Grenade Launcher",
		"description": "Arcing explosives. Bounces before detonation.",
		"unlock_level": 70,
		"damage": 100,
		"fire_rate": 1.0,
		"range": 50,
		"category": "explosive",
	},
	"railgun": {
		"name": "Railgun",
		"description": "Penetrating shot. Goes through multiple targets.",
		"unlock_level": 80,
		"damage": 90,
		"fire_rate": 1.8,
		"range": 120,
		"category": "special",
	},
	"disintegrator": {
		"name": "Disintegrator",
		"description": "Ultimate weapon. Vaporizes enemies instantly.",
		"unlock_level": 100,
		"damage": 200,
		"fire_rate": 3.0,
		"range": 60,
		"category": "legendary",
	},
}

## Level rewards - what players get at each level.
const LEVEL_REWARDS: Dictionary = {
	5: {"coins": 500, "crate": "common"},
	10: {"coins": 1000, "crate": "common", "title": "Rookie"},
	15: {"coins": 750, "crate": "uncommon"},
	20: {"coins": 1500, "crate": "uncommon", "skin": "camo_basic"},
	25: {"coins": 1000, "crate": "rare", "title": "Veteran"},
	30: {"coins": 2000, "crate": "rare"},
	35: {"coins": 1500, "crate": "rare"},
	40: {"coins": 2500, "crate": "epic", "skin": "gold_trim"},
	45: {"coins": 2000, "crate": "epic"},
	50: {"coins": 5000, "crate": "epic", "title": "Elite"},
	55: {"coins": 2500, "crate": "epic"},
	60: {"coins": 3000, "crate": "legendary"},
	65: {"coins": 3000, "crate": "legendary"},
	70: {"coins": 4000, "crate": "legendary", "skin": "neon_glow"},
	75: {"coins": 5000, "crate": "legendary", "title": "Master"},
	80: {"coins": 5000, "crate": "legendary"},
	85: {"coins": 6000, "crate": "legendary"},
	90: {"coins": 7500, "crate": "legendary", "skin": "platinum"},
	95: {"coins": 8000, "crate": "legendary"},
	100: {"coins": 10000, "crate": "legendary", "title": "Legend", "skin": "legendary_set"},
}

# endregion


# region — State

## Current player progression data.
var _data: Dictionary = {
	"total_xp": 0,
	"level": 1,
	"prestige": 0,
	"coins": 0,
	"gems": 0,
	"unlocked_weapons": ["blaster"],
	"unlocked_skins": [],
	"unlocked_titles": [],
	"equipped_weapon": "blaster",
	"equipped_title": "",
	"first_match_today": true,
	"last_play_date": "",
}

## Cache for XP thresholds per level.
var _xp_thresholds: Array[int] = []

# endregion


# region — Lifecycle

func _ready() -> void:
	_calculate_xp_thresholds()
	load_data()


## Pre-calculate XP required for each level.
func _calculate_xp_thresholds() -> void:
	_xp_thresholds.clear()
	_xp_thresholds.append(0)  # Level 1 starts at 0 XP

	var cumulative_xp: int = 0
	for level: int in range(2, MAX_LEVEL + 2):
		var xp_for_level: int = int(BASE_XP * pow(XP_GROWTH_RATE, level - 2))
		xp_for_level = mini(xp_for_level, XP_CAP_PER_LEVEL)
		cumulative_xp += xp_for_level
		_xp_thresholds.append(cumulative_xp)

# endregion


# region — XP and Leveling

## Add XP to the player's total. Handles level ups automatically.
func add_xp(amount: int, source: String = "") -> void:
	if amount <= 0:
		return

	var old_level: int = _data["level"]
	_data["total_xp"] = (_data["total_xp"] as int) + amount

	# Check for level ups
	_update_level()

	xp_gained.emit(amount, _data["total_xp"])

	# Emit level up events for each level gained
	var new_level: int = _data["level"]
	for lvl: int in range(old_level + 1, new_level + 1):
		var rewards: Dictionary = _get_level_rewards(lvl)
		_apply_level_rewards(rewards)
		level_up.emit(lvl, rewards)
		_check_weapon_unlocks(lvl)

	save_data()


## Award XP for a specific action.
func award_xp_for(action: String) -> void:
	if XP_REWARDS.has(action):
		var amount: int = XP_REWARDS[action]

		# Check for first match of the day bonus
		if action == "match_complete":
			var today: String = Time.get_date_string_from_system()
			if _data["last_play_date"] != today:
				_data["last_play_date"] = today
				_data["first_match_today"] = true

			if _data["first_match_today"]:
				_data["first_match_today"] = false
				add_xp(XP_REWARDS["daily_first_match"], "daily_first_match")

		add_xp(amount, action)


## Update the player's level based on total XP.
func _update_level() -> void:
	var total_xp: int = _data["total_xp"]

	for level: int in range(MAX_LEVEL, 0, -1):
		if total_xp >= _xp_thresholds[level - 1]:
			_data["level"] = level
			break


## Get rewards for reaching a specific level.
func _get_level_rewards(level: int) -> Dictionary:
	var rewards: Dictionary = {"coins": 100 + (level * 10)}  # Base reward for every level

	if LEVEL_REWARDS.has(level):
		var special_rewards: Dictionary = LEVEL_REWARDS[level]
		for key: String in special_rewards:
			rewards[key] = special_rewards[key]

	return rewards


## Apply rewards to the player's account.
func _apply_level_rewards(rewards: Dictionary) -> void:
	if rewards.has("coins"):
		_data["coins"] = (_data["coins"] as int) + (rewards["coins"] as int)

	if rewards.has("title"):
		var titles: Array = _data["unlocked_titles"]
		if rewards["title"] not in titles:
			titles.append(rewards["title"])

	if rewards.has("skin"):
		var skins: Array = _data["unlocked_skins"]
		if rewards["skin"] not in skins:
			skins.append(rewards["skin"])


## Check and unlock weapons based on current level.
func _check_weapon_unlocks(level: int) -> void:
	var unlocked_weapons: Array = _data["unlocked_weapons"]

	for weapon_id: String in WEAPONS:
		var weapon: Dictionary = WEAPONS[weapon_id]
		if weapon["unlock_level"] == level and weapon_id not in unlocked_weapons:
			unlocked_weapons.append(weapon_id)
			weapon_unlocked.emit(weapon_id, weapon)

# endregion


# region — Prestige System

## Reset level to 1 and gain prestige if at max level.
func prestige() -> bool:
	if _data["level"] < MAX_LEVEL:
		push_warning("ProgressionManager.prestige(): Must be level %d to prestige." % MAX_LEVEL)
		return false

	if _data["prestige"] >= MAX_PRESTIGE:
		push_warning("ProgressionManager.prestige(): Already at max prestige.")
		return false

	_data["prestige"] = (_data["prestige"] as int) + 1
	_data["total_xp"] = 0
	_data["level"] = 1

	# Prestige rewards - keep unlocked weapons, add special prestige rewards
	var prestige_coins: int = 5000 * (_data["prestige"] as int)
	_data["coins"] = (_data["coins"] as int) + prestige_coins

	prestige_gained.emit(_data["prestige"])
	save_data()
	return true

# endregion


# region — Getters

## Get current player level.
func get_level() -> int:
	return _data["level"]


## Get current prestige level.
func get_prestige() -> int:
	return _data["prestige"]


## Get total XP earned.
func get_total_xp() -> int:
	return _data["total_xp"]


## Get XP required for the current level.
func get_xp_for_current_level() -> int:
	var level: int = _data["level"]
	if level >= MAX_LEVEL:
		return 0
	return _xp_thresholds[level] - _xp_thresholds[level - 1]


## Get XP progress within the current level.
func get_current_level_xp() -> int:
	var level: int = _data["level"]
	if level >= MAX_LEVEL:
		return 0
	return _data["total_xp"] - _xp_thresholds[level - 1]


## Get progress percentage to next level (0.0 to 1.0).
func get_level_progress() -> float:
	var xp_for_level: int = get_xp_for_current_level()
	if xp_for_level == 0:
		return 1.0
	return float(get_current_level_xp()) / float(xp_for_level)


## Get XP required to reach a specific level.
func get_xp_for_level(level: int) -> int:
	if level < 1 or level > MAX_LEVEL:
		return 0
	return _xp_thresholds[level - 1]


## Get current coin balance.
func get_coins() -> int:
	return _data["coins"]


## Get current gem balance.
func get_gems() -> int:
	return _data["gems"]


## Check if a weapon is unlocked.
func is_weapon_unlocked(weapon_id: String) -> bool:
	return weapon_id in _data["unlocked_weapons"]


## Get all unlocked weapons.
func get_unlocked_weapons() -> Array:
	return _data["unlocked_weapons"].duplicate()


## Get all weapons (locked and unlocked).
func get_all_weapons() -> Dictionary:
	return WEAPONS.duplicate(true)


## Get weapon data by ID.
func get_weapon_data(weapon_id: String) -> Dictionary:
	if WEAPONS.has(weapon_id):
		var data: Dictionary = WEAPONS[weapon_id].duplicate()
		data["unlocked"] = is_weapon_unlocked(weapon_id)
		return data
	return {}


## Get next weapon unlock.
func get_next_weapon_unlock() -> Dictionary:
	var current_level: int = _data["level"]
	var next_weapon: Dictionary = {}
	var lowest_unlock_level: int = MAX_LEVEL + 1

	for weapon_id: String in WEAPONS:
		var weapon: Dictionary = WEAPONS[weapon_id]
		var unlock_level: int = weapon["unlock_level"]
		if unlock_level > current_level and unlock_level < lowest_unlock_level:
			lowest_unlock_level = unlock_level
			next_weapon = weapon.duplicate()
			next_weapon["id"] = weapon_id

	return next_weapon


## Get equipped weapon ID.
func get_equipped_weapon() -> String:
	return _data["equipped_weapon"]


## Get equipped title.
func get_equipped_title() -> String:
	return _data["equipped_title"]


## Get all unlocked titles.
func get_unlocked_titles() -> Array:
	return _data["unlocked_titles"].duplicate()


## Get all unlocked skins.
func get_unlocked_skins() -> Array:
	return _data["unlocked_skins"].duplicate()

# endregion


# region — Setters

## Set equipped weapon.
func set_equipped_weapon(weapon_id: String) -> bool:
	if not is_weapon_unlocked(weapon_id):
		push_warning("ProgressionManager.set_equipped_weapon(): Weapon '%s' not unlocked." % weapon_id)
		return false

	_data["equipped_weapon"] = weapon_id
	save_data()
	return true


## Set equipped title.
func set_equipped_title(title: String) -> bool:
	if title != "" and title not in _data["unlocked_titles"]:
		push_warning("ProgressionManager.set_equipped_title(): Title '%s' not unlocked." % title)
		return false

	_data["equipped_title"] = title
	save_data()
	return true


## Add coins to the player's balance.
func add_coins(amount: int) -> void:
	if amount > 0:
		_data["coins"] = (_data["coins"] as int) + amount
		save_data()


## Spend coins (returns false if insufficient).
func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return false
	if _data["coins"] < amount:
		return false

	_data["coins"] = (_data["coins"] as int) - amount
	save_data()
	return true


## Add gems to the player's balance.
func add_gems(amount: int) -> void:
	if amount > 0:
		_data["gems"] = (_data["gems"] as int) + amount
		save_data()


## Spend gems (returns false if insufficient).
func spend_gems(amount: int) -> bool:
	if amount <= 0:
		return false
	if _data["gems"] < amount:
		return false

	_data["gems"] = (_data["gems"] as int) - amount
	save_data()
	return true

# endregion


# region — Persistence

## Save progression data to disk.
func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string: String = JSON.stringify(_data, "\t")
		file.store_string(json_string)
		file.close()
		data_saved.emit()
	else:
		push_error("ProgressionManager.save_data(): Could not open save file.")


## Load progression data from disk.
func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		# First time - use defaults
		data_loaded.emit()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string: String = file.get_as_text()
		file.close()

		var json := JSON.new()
		var parse_result := json.parse(json_string)

		if parse_result == OK:
			var loaded_data: Variant = json.data
			if loaded_data is Dictionary:
				_merge_loaded_data(loaded_data)
		else:
			push_error("ProgressionManager.load_data(): JSON parse error.")
	else:
		push_error("ProgressionManager.load_data(): Could not open save file.")

	data_loaded.emit()


## Merge loaded data with defaults (handles missing keys from updates).
func _merge_loaded_data(loaded: Dictionary) -> void:
	for key: String in _data:
		if loaded.has(key):
			_data[key] = loaded[key]


## Reset all progression data (for testing or new game).
func reset_data() -> void:
	_data = {
		"total_xp": 0,
		"level": 1,
		"prestige": 0,
		"coins": 0,
		"gems": 0,
		"unlocked_weapons": ["blaster"],
		"unlocked_skins": [],
		"unlocked_titles": [],
		"equipped_weapon": "blaster",
		"equipped_title": "",
		"first_match_today": true,
		"last_play_date": "",
	}
	save_data()

# endregion
