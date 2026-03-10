## AchievementManager Autoload Singleton
##
## Manages 50+ achievements across categories: Combat, Progression, Social, and Mastery.
## Tracks progress automatically based on player stats and events.
## Persists to user:// for cross-session retention.
##
## Achievement categories:
##   - Combat: kills, streaks, headshots, damage dealt
##   - Progression: levels, games played, time played
##   - Social: friends, parties, coop wins
##   - Mastery: weapon mastery, game mode mastery, perfect games
extends Node


# region — Signals

## Emitted when an achievement is unlocked.
signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)

## Emitted when achievement progress is updated.
signal achievement_progress(achievement_id: String, current: int, target: int)

## Emitted when data is loaded.
signal data_loaded()

## Emitted when data is saved.
signal data_saved()

# endregion


# region — Constants

## Save file path.
const SAVE_PATH: String = "user://achievement_data.json"

## Achievement rarity tiers with XP rewards.
const RARITY_REWARDS: Dictionary = {
	"common": {"xp": 50, "coins": 25},
	"uncommon": {"xp": 100, "coins": 50},
	"rare": {"xp": 200, "coins": 100},
	"epic": {"xp": 500, "coins": 250},
	"legendary": {"xp": 1000, "coins": 500},
}

## All achievements organized by category.
const ACHIEVEMENTS: Dictionary = {
	# =====================================================
	# COMBAT ACHIEVEMENTS (15 achievements)
	# =====================================================
	"first_blood": {
		"name": "First Blood",
		"description": "Get your first kill in any match.",
		"category": "combat",
		"rarity": "common",
		"stat": "total_kills",
		"target": 1,
		"icon": "kill",
		"hidden": false,
	},
	"killer": {
		"name": "Killer",
		"description": "Get 50 kills in total.",
		"category": "combat",
		"rarity": "common",
		"stat": "total_kills",
		"target": 50,
		"icon": "kill",
		"hidden": false,
	},
	"slayer": {
		"name": "Slayer",
		"description": "Get 250 kills in total.",
		"category": "combat",
		"rarity": "uncommon",
		"stat": "total_kills",
		"target": 250,
		"icon": "kill",
		"hidden": false,
	},
	"executioner": {
		"name": "Executioner",
		"description": "Get 1000 kills in total.",
		"category": "combat",
		"rarity": "rare",
		"stat": "total_kills",
		"target": 1000,
		"icon": "kill",
		"hidden": false,
	},
	"death_incarnate": {
		"name": "Death Incarnate",
		"description": "Get 5000 kills in total.",
		"category": "combat",
		"rarity": "legendary",
		"stat": "total_kills",
		"target": 5000,
		"icon": "kill",
		"hidden": false,
	},
	"sharpshooter": {
		"name": "Sharpshooter",
		"description": "Land 25 headshots.",
		"category": "combat",
		"rarity": "uncommon",
		"stat": "headshots",
		"target": 25,
		"icon": "headshot",
		"hidden": false,
	},
	"sniper_elite": {
		"name": "Sniper Elite",
		"description": "Land 100 headshots.",
		"category": "combat",
		"rarity": "rare",
		"stat": "headshots",
		"target": 100,
		"icon": "headshot",
		"hidden": false,
	},
	"aimbot": {
		"name": "Aimbot",
		"description": "Land 500 headshots.",
		"category": "combat",
		"rarity": "epic",
		"stat": "headshots",
		"target": 500,
		"icon": "headshot",
		"hidden": false,
	},
	"killing_spree": {
		"name": "Killing Spree",
		"description": "Get a 3-kill streak.",
		"category": "combat",
		"rarity": "common",
		"stat": "max_kill_streak",
		"target": 3,
		"icon": "streak",
		"hidden": false,
	},
	"rampage": {
		"name": "Rampage",
		"description": "Get a 5-kill streak.",
		"category": "combat",
		"rarity": "uncommon",
		"stat": "max_kill_streak",
		"target": 5,
		"icon": "streak",
		"hidden": false,
	},
	"unstoppable": {
		"name": "Unstoppable",
		"description": "Get a 7-kill streak.",
		"category": "combat",
		"rarity": "rare",
		"stat": "max_kill_streak",
		"target": 7,
		"icon": "streak",
		"hidden": false,
	},
	"godlike": {
		"name": "Godlike",
		"description": "Get a 10-kill streak.",
		"category": "combat",
		"rarity": "epic",
		"stat": "max_kill_streak",
		"target": 10,
		"icon": "streak",
		"hidden": false,
	},
	"demolitions_expert": {
		"name": "Demolitions Expert",
		"description": "Get 50 explosive kills.",
		"category": "combat",
		"rarity": "rare",
		"stat": "explosive_kills",
		"target": 50,
		"icon": "explosive",
		"hidden": false,
	},
	"double_kill": {
		"name": "Double Kill",
		"description": "Kill 2 enemies within 3 seconds.",
		"category": "combat",
		"rarity": "uncommon",
		"stat": "double_kills",
		"target": 1,
		"icon": "multi_kill",
		"hidden": false,
	},
	"multi_kill_master": {
		"name": "Multi-Kill Master",
		"description": "Get 25 double kills.",
		"category": "combat",
		"rarity": "rare",
		"stat": "double_kills",
		"target": 25,
		"icon": "multi_kill",
		"hidden": false,
	},

	# =====================================================
	# PROGRESSION ACHIEVEMENTS (12 achievements)
	# =====================================================
	"rookie": {
		"name": "Rookie",
		"description": "Reach level 5.",
		"category": "progression",
		"rarity": "common",
		"stat": "player_level",
		"target": 5,
		"icon": "level",
		"hidden": false,
	},
	"experienced": {
		"name": "Experienced",
		"description": "Reach level 15.",
		"category": "progression",
		"rarity": "common",
		"stat": "player_level",
		"target": 15,
		"icon": "level",
		"hidden": false,
	},
	"veteran": {
		"name": "Veteran",
		"description": "Reach level 25.",
		"category": "progression",
		"rarity": "uncommon",
		"stat": "player_level",
		"target": 25,
		"icon": "level",
		"hidden": false,
	},
	"elite": {
		"name": "Elite",
		"description": "Reach level 50.",
		"category": "progression",
		"rarity": "rare",
		"stat": "player_level",
		"target": 50,
		"icon": "level",
		"hidden": false,
	},
	"master": {
		"name": "Master",
		"description": "Reach level 75.",
		"category": "progression",
		"rarity": "epic",
		"stat": "player_level",
		"target": 75,
		"icon": "level",
		"hidden": false,
	},
	"legend": {
		"name": "Legend",
		"description": "Reach level 100.",
		"category": "progression",
		"rarity": "legendary",
		"stat": "player_level",
		"target": 100,
		"icon": "level",
		"hidden": false,
	},
	"prestige_1": {
		"name": "Prestige I",
		"description": "Reach Prestige 1.",
		"category": "progression",
		"rarity": "epic",
		"stat": "prestige_level",
		"target": 1,
		"icon": "prestige",
		"hidden": false,
	},
	"prestige_5": {
		"name": "Prestige V",
		"description": "Reach Prestige 5.",
		"category": "progression",
		"rarity": "legendary",
		"stat": "prestige_level",
		"target": 5,
		"icon": "prestige",
		"hidden": false,
	},
	"games_10": {
		"name": "Getting Started",
		"description": "Play 10 matches.",
		"category": "progression",
		"rarity": "common",
		"stat": "matches_played",
		"target": 10,
		"icon": "games",
		"hidden": false,
	},
	"games_50": {
		"name": "Regular Player",
		"description": "Play 50 matches.",
		"category": "progression",
		"rarity": "uncommon",
		"stat": "matches_played",
		"target": 50,
		"icon": "games",
		"hidden": false,
	},
	"games_200": {
		"name": "Dedicated Player",
		"description": "Play 200 matches.",
		"category": "progression",
		"rarity": "rare",
		"stat": "matches_played",
		"target": 200,
		"icon": "games",
		"hidden": false,
	},
	"games_1000": {
		"name": "No Life",
		"description": "Play 1000 matches.",
		"category": "progression",
		"rarity": "legendary",
		"stat": "matches_played",
		"target": 1000,
		"icon": "games",
		"hidden": false,
	},

	# =====================================================
	# SOCIAL ACHIEVEMENTS (10 achievements)
	# =====================================================
	"first_friend": {
		"name": "First Friend",
		"description": "Add your first friend.",
		"category": "social",
		"rarity": "common",
		"stat": "friends_added",
		"target": 1,
		"icon": "friend",
		"hidden": false,
	},
	"social_butterfly": {
		"name": "Social Butterfly",
		"description": "Add 10 friends.",
		"category": "social",
		"rarity": "uncommon",
		"stat": "friends_added",
		"target": 10,
		"icon": "friend",
		"hidden": false,
	},
	"popular": {
		"name": "Popular",
		"description": "Add 25 friends.",
		"category": "social",
		"rarity": "rare",
		"stat": "friends_added",
		"target": 25,
		"icon": "friend",
		"hidden": false,
	},
	"party_starter": {
		"name": "Party Starter",
		"description": "Host your first party.",
		"category": "social",
		"rarity": "common",
		"stat": "parties_hosted",
		"target": 1,
		"icon": "party",
		"hidden": false,
	},
	"party_animal": {
		"name": "Party Animal",
		"description": "Host 25 parties.",
		"category": "social",
		"rarity": "uncommon",
		"stat": "parties_hosted",
		"target": 25,
		"icon": "party",
		"hidden": false,
	},
	"team_player": {
		"name": "Team Player",
		"description": "Win 10 team matches.",
		"category": "social",
		"rarity": "uncommon",
		"stat": "team_wins",
		"target": 10,
		"icon": "team",
		"hidden": false,
	},
	"cooperative": {
		"name": "Cooperative",
		"description": "Win 50 team matches.",
		"category": "social",
		"rarity": "rare",
		"stat": "team_wins",
		"target": 50,
		"icon": "team",
		"hidden": false,
	},
	"played_with_50": {
		"name": "World Traveler",
		"description": "Play with 50 different players.",
		"category": "social",
		"rarity": "rare",
		"stat": "unique_players_played_with",
		"target": 50,
		"icon": "players",
		"hidden": false,
	},
	"invited_friends": {
		"name": "Recruiter",
		"description": "Invite 5 friends to a match.",
		"category": "social",
		"rarity": "uncommon",
		"stat": "friends_invited",
		"target": 5,
		"icon": "invite",
		"hidden": false,
	},
	"chat_active": {
		"name": "Chatterbox",
		"description": "Send 100 chat messages.",
		"category": "social",
		"rarity": "common",
		"stat": "chat_messages_sent",
		"target": 100,
		"icon": "chat",
		"hidden": false,
	},

	# =====================================================
	# MASTERY ACHIEVEMENTS (13 achievements)
	# =====================================================
	"blaster_master": {
		"name": "Blaster Master",
		"description": "Get 100 kills with the Blaster.",
		"category": "mastery",
		"rarity": "uncommon",
		"stat": "weapon_kills_blaster",
		"target": 100,
		"icon": "weapon",
		"hidden": false,
	},
	"shotgun_surgeon": {
		"name": "Shotgun Surgeon",
		"description": "Get 100 kills with the Shotgun.",
		"category": "mastery",
		"rarity": "uncommon",
		"stat": "weapon_kills_shotgun",
		"target": 100,
		"icon": "weapon",
		"hidden": false,
	},
	"sniper_ace": {
		"name": "Sniper Ace",
		"description": "Get 100 kills with the Sniper.",
		"category": "mastery",
		"rarity": "rare",
		"stat": "weapon_kills_sniper",
		"target": 100,
		"icon": "weapon",
		"hidden": false,
	},
	"rocket_scientist": {
		"name": "Rocket Scientist",
		"description": "Get 100 kills with the Rocket Launcher.",
		"category": "mastery",
		"rarity": "rare",
		"stat": "weapon_kills_rocket_launcher",
		"target": 100,
		"icon": "weapon",
		"hidden": false,
	},
	"arena_champion": {
		"name": "Arena Champion",
		"description": "Win 25 Arena Blaster matches.",
		"category": "mastery",
		"rarity": "rare",
		"stat": "arena_blaster_wins",
		"target": 25,
		"icon": "game_mode",
		"hidden": false,
	},
	"speed_demon": {
		"name": "Speed Demon",
		"description": "Win 25 Turbo Karts matches.",
		"category": "mastery",
		"rarity": "rare",
		"stat": "turbo_karts_wins",
		"target": 25,
		"icon": "game_mode",
		"hidden": false,
	},
	"survivor": {
		"name": "Survivor",
		"description": "Win 25 Obstacle Royale matches.",
		"category": "mastery",
		"rarity": "rare",
		"stat": "obstacle_royale_wins",
		"target": 25,
		"icon": "game_mode",
		"hidden": false,
	},
	"flag_bearer": {
		"name": "Flag Bearer",
		"description": "Win 25 Flag Wars matches.",
		"category": "mastery",
		"rarity": "rare",
		"stat": "flag_wars_wins",
		"target": 25,
		"icon": "game_mode",
		"hidden": false,
	},
	"demolition_derby": {
		"name": "Demolition Derby",
		"description": "Win 25 Crash Derby matches.",
		"category": "mastery",
		"rarity": "rare",
		"stat": "crash_derby_wins",
		"target": 25,
		"icon": "game_mode",
		"hidden": false,
	},
	"perfectionist": {
		"name": "Perfectionist",
		"description": "Win a match without dying.",
		"category": "mastery",
		"rarity": "epic",
		"stat": "perfect_games",
		"target": 1,
		"icon": "perfect",
		"hidden": false,
	},
	"flawless_5": {
		"name": "Flawless",
		"description": "Win 5 matches without dying.",
		"category": "mastery",
		"rarity": "legendary",
		"stat": "perfect_games",
		"target": 5,
		"icon": "perfect",
		"hidden": false,
	},
	"winner": {
		"name": "Winner",
		"description": "Win 50 matches total.",
		"category": "mastery",
		"rarity": "uncommon",
		"stat": "total_wins",
		"target": 50,
		"icon": "win",
		"hidden": false,
	},
	"champion": {
		"name": "Champion",
		"description": "Win 200 matches total.",
		"category": "mastery",
		"rarity": "epic",
		"stat": "total_wins",
		"target": 200,
		"icon": "win",
		"hidden": false,
	},

	# =====================================================
	# HIDDEN / SECRET ACHIEVEMENTS (5 achievements)
	# =====================================================
	"pacifist": {
		"name": "Pacifist",
		"description": "Win a match with 0 kills.",
		"category": "mastery",
		"rarity": "epic",
		"stat": "pacifist_wins",
		"target": 1,
		"icon": "secret",
		"hidden": true,
	},
	"comeback_king": {
		"name": "Comeback King",
		"description": "Win after being last place at halftime.",
		"category": "mastery",
		"rarity": "epic",
		"stat": "comebacks",
		"target": 1,
		"icon": "secret",
		"hidden": true,
	},
	"night_owl": {
		"name": "Night Owl",
		"description": "Play a match after midnight.",
		"category": "social",
		"rarity": "uncommon",
		"stat": "midnight_games",
		"target": 1,
		"icon": "secret",
		"hidden": true,
	},
	"early_bird": {
		"name": "Early Bird",
		"description": "Play a match before 6 AM.",
		"category": "social",
		"rarity": "uncommon",
		"stat": "early_games",
		"target": 1,
		"icon": "secret",
		"hidden": true,
	},
	"dedication": {
		"name": "Dedication",
		"description": "Play for 100 hours total.",
		"category": "progression",
		"rarity": "legendary",
		"stat": "playtime_hours",
		"target": 100,
		"icon": "time",
		"hidden": true,
	},
}

# endregion


# region — State

## Player achievement data.
var _data: Dictionary = {
	"unlocked": {},  # achievement_id -> unlock_timestamp
	"progress": {},  # achievement_id -> current_progress (for non-stat achievements)
	"notified": {},  # achievement_id -> bool (has been shown to player)
}

# endregion


# region — Lifecycle

func _ready() -> void:
	load_data()

# endregion


# region — Achievement Checking

## Check all achievements against current stats.
## Call this periodically or after stat updates.
func check_all_achievements() -> void:
	if not is_instance_valid(get_node_or_null("/root/StatsTracker")):
		return

	var stats_tracker: Node = get_node("/root/StatsTracker")

	for achievement_id: String in ACHIEVEMENTS:
		if is_unlocked(achievement_id):
			continue

		var achievement: Dictionary = ACHIEVEMENTS[achievement_id]
		var stat_name: String = achievement.get("stat", "")
		var target: int = achievement.get("target", 1)

		if stat_name.is_empty():
			continue

		var current_value: int = stats_tracker.get_stat(stat_name)
		_update_progress(achievement_id, current_value, target)

		if current_value >= target:
			unlock_achievement(achievement_id)


## Check a specific stat and update related achievements.
func check_stat(stat_name: String, value: int) -> void:
	for achievement_id: String in ACHIEVEMENTS:
		if is_unlocked(achievement_id):
			continue

		var achievement: Dictionary = ACHIEVEMENTS[achievement_id]
		if achievement.get("stat", "") != stat_name:
			continue

		var target: int = achievement.get("target", 1)
		_update_progress(achievement_id, value, target)

		if value >= target:
			unlock_achievement(achievement_id)


## Update progress for an achievement.
func _update_progress(achievement_id: String, current: int, target: int) -> void:
	var previous: int = _data["progress"].get(achievement_id, 0)

	if current != previous:
		_data["progress"][achievement_id] = current
		achievement_progress.emit(achievement_id, current, target)

# endregion


# region — Achievement Unlocking

## Unlock an achievement by ID.
func unlock_achievement(achievement_id: String) -> bool:
	if not ACHIEVEMENTS.has(achievement_id):
		push_warning("AchievementManager.unlock_achievement(): Unknown achievement '%s'." % achievement_id)
		return false

	if is_unlocked(achievement_id):
		return false

	var achievement: Dictionary = ACHIEVEMENTS[achievement_id]
	var timestamp: String = Time.get_datetime_string_from_system()

	_data["unlocked"][achievement_id] = timestamp
	_data["notified"][achievement_id] = false

	# Grant rewards
	_grant_achievement_rewards(achievement)

	achievement_unlocked.emit(achievement_id, achievement)
	save_data()
	return true


## Grant rewards for unlocking an achievement.
func _grant_achievement_rewards(achievement: Dictionary) -> void:
	var rarity: String = achievement.get("rarity", "common")
	var rewards: Dictionary = RARITY_REWARDS.get(rarity, RARITY_REWARDS["common"])

	# Add XP if ProgressionManager exists
	var progression: Node = get_node_or_null("/root/ProgressionManager")
	if progression:
		progression.add_xp(rewards["xp"], "achievement")
		progression.add_coins(rewards["coins"])

# endregion


# region — Getters

## Check if an achievement is unlocked.
func is_unlocked(achievement_id: String) -> bool:
	return _data["unlocked"].has(achievement_id)


## Get achievement data by ID.
func get_achievement(achievement_id: String) -> Dictionary:
	if not ACHIEVEMENTS.has(achievement_id):
		return {}

	var achievement: Dictionary = ACHIEVEMENTS[achievement_id].duplicate()
	achievement["id"] = achievement_id
	achievement["unlocked"] = is_unlocked(achievement_id)

	if is_unlocked(achievement_id):
		achievement["unlock_date"] = _data["unlocked"][achievement_id]

	return achievement


## Get all achievements.
func get_all_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for achievement_id: String in ACHIEVEMENTS:
		var achievement: Dictionary = get_achievement(achievement_id)
		result.append(achievement)

	return result


## Get achievements by category.
func get_achievements_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for achievement_id: String in ACHIEVEMENTS:
		var achievement: Dictionary = ACHIEVEMENTS[achievement_id]
		if achievement.get("category", "") == category:
			result.append(get_achievement(achievement_id))

	return result


## Get unlocked achievements.
func get_unlocked_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for achievement_id: String in _data["unlocked"]:
		if ACHIEVEMENTS.has(achievement_id):
			result.append(get_achievement(achievement_id))

	return result


## Get locked achievements (excluding hidden ones).
func get_locked_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for achievement_id: String in ACHIEVEMENTS:
		if is_unlocked(achievement_id):
			continue

		var achievement: Dictionary = ACHIEVEMENTS[achievement_id]
		if achievement.get("hidden", false):
			continue

		result.append(get_achievement(achievement_id))

	return result


## Get achievement progress (current / target).
func get_progress(achievement_id: String) -> Dictionary:
	if not ACHIEVEMENTS.has(achievement_id):
		return {"current": 0, "target": 0, "percentage": 0.0}

	var achievement: Dictionary = ACHIEVEMENTS[achievement_id]
	var target: int = achievement.get("target", 1)
	var current: int = _data["progress"].get(achievement_id, 0)

	# Try to get current value from StatsTracker
	var stats_tracker: Node = get_node_or_null("/root/StatsTracker")
	if stats_tracker:
		var stat_name: String = achievement.get("stat", "")
		if not stat_name.is_empty():
			current = stats_tracker.get_stat(stat_name)

	if is_unlocked(achievement_id):
		current = target

	var percentage: float = float(current) / float(target) if target > 0 else 0.0

	return {
		"current": current,
		"target": target,
		"percentage": clampf(percentage, 0.0, 1.0),
	}


## Get total achievement count.
func get_total_count() -> int:
	return ACHIEVEMENTS.size()


## Get unlocked achievement count.
func get_unlocked_count() -> int:
	return _data["unlocked"].size()


## Get completion percentage.
func get_completion_percentage() -> float:
	var total: int = get_total_count()
	if total == 0:
		return 0.0
	return float(get_unlocked_count()) / float(total) * 100.0


## Get recently unlocked achievements (not yet notified).
func get_pending_notifications() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for achievement_id: String in _data["unlocked"]:
		if not _data["notified"].get(achievement_id, true):
			if ACHIEVEMENTS.has(achievement_id):
				result.append(get_achievement(achievement_id))

	return result


## Mark an achievement as notified.
func mark_notified(achievement_id: String) -> void:
	if _data["notified"].has(achievement_id):
		_data["notified"][achievement_id] = true
		save_data()

# endregion


# region — Category Info

## Get all categories with counts.
func get_categories() -> Array[Dictionary]:
	var categories: Dictionary = {}

	for achievement_id: String in ACHIEVEMENTS:
		var achievement: Dictionary = ACHIEVEMENTS[achievement_id]
		var category: String = achievement.get("category", "misc")

		if not categories.has(category):
			categories[category] = {"name": category.capitalize(), "total": 0, "unlocked": 0}

		categories[category]["total"] += 1

		if is_unlocked(achievement_id):
			categories[category]["unlocked"] += 1

	var result: Array[Dictionary] = []
	for category: String in categories:
		var cat_data: Dictionary = categories[category]
		cat_data["id"] = category
		result.append(cat_data)

	return result

# endregion


# region — Persistence

## Save achievement data to disk.
func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string: String = JSON.stringify(_data, "\t")
		file.store_string(json_string)
		file.close()
		data_saved.emit()
	else:
		push_error("AchievementManager.save_data(): Could not open save file.")


## Load achievement data from disk.
func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
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
			push_error("AchievementManager.load_data(): JSON parse error.")
	else:
		push_error("AchievementManager.load_data(): Could not open save file.")

	data_loaded.emit()


## Merge loaded data with defaults.
func _merge_loaded_data(loaded: Dictionary) -> void:
	if loaded.has("unlocked") and loaded["unlocked"] is Dictionary:
		_data["unlocked"] = loaded["unlocked"]
	if loaded.has("progress") and loaded["progress"] is Dictionary:
		_data["progress"] = loaded["progress"]
	if loaded.has("notified") and loaded["notified"] is Dictionary:
		_data["notified"] = loaded["notified"]


## Reset all achievement data.
func reset_data() -> void:
	_data = {
		"unlocked": {},
		"progress": {},
		"notified": {},
	}
	save_data()

# endregion
