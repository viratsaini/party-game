## DailyChallengesManager Autoload Singleton
##
## Manages daily challenges (3 per day) and weekly missions.
## Challenges refresh at midnight UTC. Weeklies refresh on Monday.
## All data persists to user:// for cross-session retention.
##
## Daily challenges: Quick, achievable goals (kills, games, etc.)
## Weekly missions: Longer-term goals with better rewards
extends Node


# region — Signals

## Emitted when daily challenges refresh.
signal dailies_refreshed(challenges: Array)

## Emitted when weekly missions refresh.
signal weeklies_refreshed(missions: Array)

## Emitted when a challenge is completed.
signal challenge_completed(challenge_id: String, rewards: Dictionary)

## Emitted when a mission is completed.
signal mission_completed(mission_id: String, rewards: Dictionary)

## Emitted when challenge progress updates.
signal challenge_progress(challenge_id: String, current: int, target: int)

## Emitted when mission progress updates.
signal mission_progress(mission_id: String, current: int, target: int)

## Emitted when data is loaded.
signal data_loaded()

# endregion


# region — Constants

## Save file path.
const SAVE_PATH: String = "user://challenges_data.json"

## Number of daily challenges to generate.
const DAILY_CHALLENGE_COUNT: int = 3

## Number of weekly missions to generate.
const WEEKLY_MISSION_COUNT: int = 5

## Daily challenge templates - randomized each day.
const DAILY_TEMPLATES: Array = [
	{
		"type": "kills",
		"name": "Eliminator",
		"description": "Get %d kills in any game mode.",
		"min_target": 5,
		"max_target": 15,
		"stat": "daily_kills",
		"xp": 100,
		"coins": 50,
	},
	{
		"type": "headshots",
		"name": "Precision",
		"description": "Land %d headshots.",
		"min_target": 3,
		"max_target": 8,
		"stat": "daily_headshots",
		"xp": 150,
		"coins": 75,
	},
	{
		"type": "wins",
		"name": "Victor",
		"description": "Win %d matches.",
		"min_target": 1,
		"max_target": 3,
		"stat": "daily_wins",
		"xp": 200,
		"coins": 100,
	},
	{
		"type": "matches",
		"name": "Active Player",
		"description": "Play %d matches.",
		"min_target": 3,
		"max_target": 7,
		"stat": "daily_matches",
		"xp": 75,
		"coins": 50,
	},
	{
		"type": "streak",
		"name": "On Fire",
		"description": "Get a kill streak of %d.",
		"min_target": 3,
		"max_target": 5,
		"stat": "daily_best_streak",
		"xp": 125,
		"coins": 75,
	},
	{
		"type": "assists",
		"name": "Team Support",
		"description": "Get %d assists.",
		"min_target": 5,
		"max_target": 12,
		"stat": "daily_assists",
		"xp": 100,
		"coins": 50,
	},
	{
		"type": "damage",
		"name": "Damage Dealer",
		"description": "Deal %d damage.",
		"min_target": 500,
		"max_target": 1500,
		"stat": "daily_damage",
		"xp": 100,
		"coins": 60,
	},
	{
		"type": "arena_kills",
		"name": "Arena Fighter",
		"description": "Get %d kills in Arena Blaster.",
		"min_target": 5,
		"max_target": 12,
		"stat": "daily_arena_kills",
		"xp": 125,
		"coins": 75,
	},
	{
		"type": "kart_finish",
		"name": "Racer",
		"description": "Finish %d Turbo Karts races.",
		"min_target": 2,
		"max_target": 5,
		"stat": "daily_kart_races",
		"xp": 100,
		"coins": 50,
	},
	{
		"type": "obstacle_survive",
		"name": "Survivor",
		"description": "Survive for %d minutes in Obstacle Royale.",
		"min_target": 5,
		"max_target": 15,
		"stat": "daily_obstacle_time",
		"xp": 100,
		"coins": 60,
	},
	{
		"type": "flag_captures",
		"name": "Flag Runner",
		"description": "Capture %d flags in Flag Wars.",
		"min_target": 2,
		"max_target": 5,
		"stat": "daily_flag_captures",
		"xp": 150,
		"coins": 100,
	},
	{
		"type": "crash_hits",
		"name": "Wrecker",
		"description": "Hit %d opponents in Crash Derby.",
		"min_target": 10,
		"max_target": 25,
		"stat": "daily_crash_hits",
		"xp": 100,
		"coins": 60,
	},
	{
		"type": "no_deaths",
		"name": "Untouchable",
		"description": "Complete a match without dying.",
		"min_target": 1,
		"max_target": 1,
		"stat": "daily_perfect_matches",
		"xp": 200,
		"coins": 125,
	},
	{
		"type": "first_place",
		"name": "Champion",
		"description": "Finish in 1st place %d times.",
		"min_target": 1,
		"max_target": 3,
		"stat": "daily_first_places",
		"xp": 175,
		"coins": 100,
	},
	{
		"type": "playtime",
		"name": "Dedicated",
		"description": "Play for %d minutes.",
		"min_target": 15,
		"max_target": 45,
		"stat": "daily_playtime",
		"xp": 100,
		"coins": 50,
	},
]

## Weekly mission templates - larger goals with better rewards.
const WEEKLY_TEMPLATES: Array = [
	{
		"type": "weekly_kills",
		"name": "Weekly Warrior",
		"description": "Get %d kills this week.",
		"min_target": 50,
		"max_target": 100,
		"stat": "weekly_kills",
		"xp": 500,
		"coins": 300,
		"crate": "rare",
	},
	{
		"type": "weekly_wins",
		"name": "Weekly Champion",
		"description": "Win %d matches this week.",
		"min_target": 10,
		"max_target": 20,
		"stat": "weekly_wins",
		"xp": 750,
		"coins": 500,
		"crate": "epic",
	},
	{
		"type": "weekly_matches",
		"name": "Weekly Grinder",
		"description": "Play %d matches this week.",
		"min_target": 25,
		"max_target": 50,
		"stat": "weekly_matches",
		"xp": 400,
		"coins": 250,
		"crate": "uncommon",
	},
	{
		"type": "weekly_headshots",
		"name": "Weekly Sniper",
		"description": "Land %d headshots this week.",
		"min_target": 25,
		"max_target": 50,
		"stat": "weekly_headshots",
		"xp": 600,
		"coins": 350,
		"crate": "rare",
	},
	{
		"type": "weekly_streak",
		"name": "Weekly Streak",
		"description": "Get a %d kill streak.",
		"min_target": 7,
		"max_target": 10,
		"stat": "weekly_best_streak",
		"xp": 500,
		"coins": 300,
		"crate": "rare",
	},
	{
		"type": "weekly_all_modes",
		"name": "All-Rounder",
		"description": "Win at least once in each game mode.",
		"min_target": 5,
		"max_target": 5,
		"stat": "weekly_modes_won",
		"xp": 1000,
		"coins": 600,
		"crate": "epic",
	},
	{
		"type": "weekly_team_wins",
		"name": "Team Effort",
		"description": "Win %d team matches this week.",
		"min_target": 10,
		"max_target": 20,
		"stat": "weekly_team_wins",
		"xp": 600,
		"coins": 400,
		"crate": "rare",
	},
	{
		"type": "weekly_playtime",
		"name": "Weekly Dedication",
		"description": "Play for %d hours this week.",
		"min_target": 3,
		"max_target": 8,
		"stat": "weekly_playtime_hours",
		"xp": 500,
		"coins": 300,
		"crate": "uncommon",
	},
	{
		"type": "weekly_perfect",
		"name": "Weekly Perfectionist",
		"description": "Complete %d matches without dying.",
		"min_target": 3,
		"max_target": 7,
		"stat": "weekly_perfect_matches",
		"xp": 800,
		"coins": 500,
		"crate": "epic",
	},
	{
		"type": "weekly_damage",
		"name": "Weekly Damage",
		"description": "Deal %d total damage this week.",
		"min_target": 5000,
		"max_target": 15000,
		"stat": "weekly_damage",
		"xp": 500,
		"coins": 300,
		"crate": "uncommon",
	},
]

# endregion


# region — State

## Current challenges and missions data.
var _data: Dictionary = {
	"daily_challenges": [],
	"weekly_missions": [],
	"daily_refresh_date": "",
	"weekly_refresh_date": "",
	"daily_stats": {},
	"weekly_stats": {},
	"completed_dailies": [],
	"completed_weeklies": [],
}

# endregion


# region — Lifecycle

func _ready() -> void:
	load_data()
	_check_refresh()


## Check if challenges need to refresh.
func _check_refresh() -> void:
	var today: String = Time.get_date_string_from_system()
	var monday: String = _get_current_monday()

	# Check daily refresh
	if _data["daily_refresh_date"] != today:
		_refresh_dailies()
		_data["daily_refresh_date"] = today
		_data["daily_stats"] = {}
		_data["completed_dailies"] = []
		save_data()

	# Check weekly refresh
	if _data["weekly_refresh_date"] != monday:
		_refresh_weeklies()
		_data["weekly_refresh_date"] = monday
		_data["weekly_stats"] = {}
		_data["completed_weeklies"] = []
		save_data()


## Get the Monday of the current week (ISO format).
func _get_current_monday() -> String:
	var datetime: Dictionary = Time.get_date_dict_from_system()
	var weekday: int = datetime.get("weekday", 0)  # Sunday = 0
	var days_since_monday: int = (weekday + 6) % 7

	# Subtract days to get to Monday
	var unix_time: int = int(Time.get_unix_time_from_system())
	var monday_unix: int = unix_time - (days_since_monday * 86400)
	var monday_dict: Dictionary = Time.get_date_dict_from_unix_time(monday_unix)

	return "%04d-%02d-%02d" % [monday_dict["year"], monday_dict["month"], monday_dict["day"]]

# endregion


# region — Challenge Generation

## Refresh daily challenges with new random ones.
func _refresh_dailies() -> void:
	_data["daily_challenges"] = []

	# Shuffle and pick templates
	var available: Array = DAILY_TEMPLATES.duplicate()
	available.shuffle()

	for i: int in range(mini(DAILY_CHALLENGE_COUNT, available.size())):
		var template: Dictionary = available[i]
		var challenge: Dictionary = _generate_challenge_from_template(template, "daily_%d" % i)
		_data["daily_challenges"].append(challenge)

	dailies_refreshed.emit(_data["daily_challenges"])


## Refresh weekly missions with new random ones.
func _refresh_weeklies() -> void:
	_data["weekly_missions"] = []

	# Shuffle and pick templates
	var available: Array = WEEKLY_TEMPLATES.duplicate()
	available.shuffle()

	for i: int in range(mini(WEEKLY_MISSION_COUNT, available.size())):
		var template: Dictionary = available[i]
		var mission: Dictionary = _generate_challenge_from_template(template, "weekly_%d" % i)
		_data["weekly_missions"].append(mission)

	weeklies_refreshed.emit(_data["weekly_missions"])


## Generate a challenge from a template with randomized target.
func _generate_challenge_from_template(template: Dictionary, challenge_id: String) -> Dictionary:
	var min_target: int = template.get("min_target", 1)
	var max_target: int = template.get("max_target", 10)
	var target: int = randi_range(min_target, max_target)

	var description: String = template.get("description", "")
	if description.contains("%d"):
		description = description % target

	return {
		"id": challenge_id,
		"type": template.get("type", ""),
		"name": template.get("name", "Challenge"),
		"description": description,
		"target": target,
		"stat": template.get("stat", ""),
		"xp": template.get("xp", 100),
		"coins": template.get("coins", 50),
		"crate": template.get("crate", ""),
		"completed": false,
	}

# endregion


# region — Progress Tracking

## Update a daily stat and check challenge completion.
func update_daily_stat(stat_name: String, value: int = 1, mode: String = "add") -> void:
	match mode:
		"add":
			var current: int = _data["daily_stats"].get(stat_name, 0)
			_data["daily_stats"][stat_name] = current + value
		"max":
			var current: int = _data["daily_stats"].get(stat_name, 0)
			_data["daily_stats"][stat_name] = maxi(current, value)
		"set":
			_data["daily_stats"][stat_name] = value

	_check_daily_completion(stat_name)
	save_data()


## Update a weekly stat and check mission completion.
func update_weekly_stat(stat_name: String, value: int = 1, mode: String = "add") -> void:
	match mode:
		"add":
			var current: int = _data["weekly_stats"].get(stat_name, 0)
			_data["weekly_stats"][stat_name] = current + value
		"max":
			var current: int = _data["weekly_stats"].get(stat_name, 0)
			_data["weekly_stats"][stat_name] = maxi(current, value)
		"set":
			_data["weekly_stats"][stat_name] = value

	_check_weekly_completion(stat_name)
	save_data()


## Check all daily challenges for completion.
func _check_daily_completion(updated_stat: String) -> void:
	for challenge: Dictionary in _data["daily_challenges"]:
		if challenge.get("completed", false):
			continue

		if challenge.get("stat", "") != updated_stat:
			continue

		var target: int = challenge.get("target", 1)
		var current: int = _data["daily_stats"].get(updated_stat, 0)

		# Emit progress
		challenge_progress.emit(challenge["id"], current, target)

		if current >= target:
			_complete_daily_challenge(challenge)


## Check all weekly missions for completion.
func _check_weekly_completion(updated_stat: String) -> void:
	for mission: Dictionary in _data["weekly_missions"]:
		if mission.get("completed", false):
			continue

		if mission.get("stat", "") != updated_stat:
			continue

		var target: int = mission.get("target", 1)
		var current: int = _data["weekly_stats"].get(updated_stat, 0)

		# Emit progress
		mission_progress.emit(mission["id"], current, target)

		if current >= target:
			_complete_weekly_mission(mission)


## Complete a daily challenge and grant rewards.
func _complete_daily_challenge(challenge: Dictionary) -> void:
	challenge["completed"] = true
	_data["completed_dailies"].append(challenge["id"])

	var rewards: Dictionary = {
		"xp": challenge.get("xp", 100),
		"coins": challenge.get("coins", 50),
	}

	# Grant rewards
	_grant_rewards(rewards)

	challenge_completed.emit(challenge["id"], rewards)


## Complete a weekly mission and grant rewards.
func _complete_weekly_mission(mission: Dictionary) -> void:
	mission["completed"] = true
	_data["completed_weeklies"].append(mission["id"])

	var rewards: Dictionary = {
		"xp": mission.get("xp", 500),
		"coins": mission.get("coins", 300),
		"crate": mission.get("crate", ""),
	}

	# Grant rewards
	_grant_rewards(rewards)

	mission_completed.emit(mission["id"], rewards)


## Grant rewards to the player.
func _grant_rewards(rewards: Dictionary) -> void:
	var progression: Node = get_node_or_null("/root/ProgressionManager")
	if progression:
		if rewards.has("xp"):
			progression.add_xp(rewards["xp"], "challenge")
		if rewards.has("coins"):
			progression.add_coins(rewards["coins"])

# endregion


# region — Getters

## Get all daily challenges.
func get_daily_challenges() -> Array:
	_check_refresh()
	return _data["daily_challenges"].duplicate(true)


## Get all weekly missions.
func get_weekly_missions() -> Array:
	_check_refresh()
	return _data["weekly_missions"].duplicate(true)


## Get progress for a specific daily challenge.
func get_daily_progress(challenge_id: String) -> Dictionary:
	for challenge: Dictionary in _data["daily_challenges"]:
		if challenge["id"] == challenge_id:
			var stat: String = challenge.get("stat", "")
			var target: int = challenge.get("target", 1)
			var current: int = _data["daily_stats"].get(stat, 0)
			var completed: bool = challenge.get("completed", false)

			return {
				"current": current,
				"target": target,
				"percentage": clampf(float(current) / float(target), 0.0, 1.0),
				"completed": completed,
			}

	return {"current": 0, "target": 0, "percentage": 0.0, "completed": false}


## Get progress for a specific weekly mission.
func get_weekly_progress(mission_id: String) -> Dictionary:
	for mission: Dictionary in _data["weekly_missions"]:
		if mission["id"] == mission_id:
			var stat: String = mission.get("stat", "")
			var target: int = mission.get("target", 1)
			var current: int = _data["weekly_stats"].get(stat, 0)
			var completed: bool = mission.get("completed", false)

			return {
				"current": current,
				"target": target,
				"percentage": clampf(float(current) / float(target), 0.0, 1.0),
				"completed": completed,
			}

	return {"current": 0, "target": 0, "percentage": 0.0, "completed": false}


## Get count of completed daily challenges.
func get_completed_daily_count() -> int:
	return _data["completed_dailies"].size()


## Get count of completed weekly missions.
func get_completed_weekly_count() -> int:
	return _data["completed_weeklies"].size()


## Get time until daily refresh (seconds).
func get_time_until_daily_refresh() -> int:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)  # UTC
	var seconds_since_midnight: int = now["hour"] * 3600 + now["minute"] * 60 + now["second"]
	return 86400 - seconds_since_midnight


## Get time until weekly refresh (seconds).
func get_time_until_weekly_refresh() -> int:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)  # UTC
	var weekday: int = now.get("weekday", 0)
	var days_until_monday: int = (8 - weekday) % 7
	if days_until_monday == 0:
		days_until_monday = 7

	var seconds_since_midnight: int = now["hour"] * 3600 + now["minute"] * 60 + now["second"]
	return (days_until_monday * 86400) - seconds_since_midnight


## Format time remaining as a string.
func format_time_remaining(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60

	if hours > 24:
		var days: int = hours / 24
		return "%dd %dh" % [days, hours % 24]
	elif hours > 0:
		return "%dh %dm" % [hours, minutes]
	else:
		return "%dm" % minutes

# endregion


# region — Persistence

## Save challenge data to disk.
func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string: String = JSON.stringify(_data, "\t")
		file.store_string(json_string)
		file.close()
	else:
		push_error("DailyChallengesManager.save_data(): Could not open save file.")


## Load challenge data from disk.
func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_refresh_dailies()
		_refresh_weeklies()
		_data["daily_refresh_date"] = Time.get_date_string_from_system()
		_data["weekly_refresh_date"] = _get_current_monday()
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
			push_error("DailyChallengesManager.load_data(): JSON parse error.")
	else:
		push_error("DailyChallengesManager.load_data(): Could not open save file.")

	data_loaded.emit()


## Merge loaded data with defaults.
func _merge_loaded_data(loaded: Dictionary) -> void:
	for key: String in _data:
		if loaded.has(key):
			_data[key] = loaded[key]


## Reset all challenge data (for testing).
func reset_data() -> void:
	_data = {
		"daily_challenges": [],
		"weekly_missions": [],
		"daily_refresh_date": "",
		"weekly_refresh_date": "",
		"daily_stats": {},
		"weekly_stats": {},
		"completed_dailies": [],
		"completed_weeklies": [],
	}
	_check_refresh()
	save_data()

# endregion
