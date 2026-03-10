## TutorialManager — Autoload singleton for managing first-time user tutorial
## Provides interactive tutorial system with step-by-step guides
extends Node

signal tutorial_started()
signal tutorial_step_changed(step_index: int)
signal tutorial_completed()

const TUTORIAL_SAVE_PATH: String = "user://tutorial_state.cfg"

var _tutorial_completed: bool = false
var _current_step: int = 0
var _tutorial_active: bool = false

## Tutorial steps configuration
var tutorial_steps: Array[Dictionary] = [
	{
		"title": "Welcome to BattleZone Party!",
		"description": "Let's show you around. This is a multiplayer party game where you can compete with friends in various mini-games.",
		"highlight": "",
		"action": "tap_anywhere"
	},
	{
		"title": "Connect with Friends",
		"description": "You can connect with other players on the same WiFi network. Just tap 'JOIN ROOM' and your device will automatically discover nearby games!",
		"highlight": "join_button",
		"action": "understand"
	},
	{
		"title": "Host Your Own Game",
		"description": "Want to be the host? Tap 'CREATE ROOM' to start your own game. Your friends can then join you automatically!",
		"highlight": "create_button",
		"action": "understand"
	},
	{
		"title": "Customize Your Settings",
		"description": "Tap 'SETTINGS' to change your name, adjust volume, and personalize your experience.",
		"highlight": "settings_button",
		"action": "understand"
	},
	{
		"title": "Ready to Play!",
		"description": "You're all set! Create or join a room to start playing with your friends. Have fun!",
		"highlight": "",
		"action": "complete"
	}
]

func _ready() -> void:
	_load_tutorial_state()

func _load_tutorial_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(TUTORIAL_SAVE_PATH) == OK:
		_tutorial_completed = cfg.get_value("tutorial", "completed", false)

func _save_tutorial_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("tutorial", "completed", _tutorial_completed)
	cfg.save(TUTORIAL_SAVE_PATH)

func is_tutorial_completed() -> bool:
	return _tutorial_completed

func should_show_tutorial() -> bool:
	return not _tutorial_completed

func start_tutorial() -> void:
	_tutorial_active = true
	_current_step = 0
	tutorial_started.emit()
	tutorial_step_changed.emit(_current_step)

func next_step() -> void:
	if not _tutorial_active:
		return

	_current_step += 1

	if _current_step >= tutorial_steps.size():
		complete_tutorial()
	else:
		tutorial_step_changed.emit(_current_step)

func complete_tutorial() -> void:
	_tutorial_active = false
	_tutorial_completed = true
	_save_tutorial_state()
	tutorial_completed.emit()

func skip_tutorial() -> void:
	complete_tutorial()

func get_current_step() -> Dictionary:
	if _current_step < tutorial_steps.size():
		return tutorial_steps[_current_step]
	return {}

func is_tutorial_active() -> bool:
	return _tutorial_active
