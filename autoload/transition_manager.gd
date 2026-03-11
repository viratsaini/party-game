## TransitionManager - Central manager for all premium UI transitions and effects
## Autoload that provides easy access to scene transitions, loading screens, and effects
extends Node

# References to transition systems
var scene_transition: Node
var transition_effects: Node
var cinematic_loading: Node
var match_countdown: Node
var victory_screen: Node
var animated_results: Node
var premium_toast: Node
var animated_dialog: Node

# Quick access to transition types
const Transition = preload("res://ui/transitions/scene_transition.gd").TransitionType
const Toast = preload("res://ui/notifications/premium_toast.gd").ToastType


func _ready() -> void:
	_initialize_systems()


func _initialize_systems() -> void:
	# Scene Transition
	var scene_trans_script := load("res://ui/transitions/scene_transition.gd")
	if scene_trans_script:
		scene_transition = scene_trans_script.new()
		scene_transition.name = "SceneTransition"
		add_child(scene_transition)

	# Transition Effects
	var effects_script := load("res://ui/transitions/transition_effects.gd")
	if effects_script:
		transition_effects = effects_script.new()
		transition_effects.name = "TransitionEffects"
		add_child(transition_effects)

	# Cinematic Loading
	var loading_script := load("res://ui/loading/cinematic_loading.gd")
	if loading_script:
		cinematic_loading = loading_script.new()
		cinematic_loading.name = "CinematicLoading"
		add_child(cinematic_loading)

	# Match Countdown
	var countdown_script := load("res://ui/transitions/match_countdown.gd")
	if countdown_script:
		match_countdown = countdown_script.new()
		match_countdown.name = "MatchCountdown"
		add_child(match_countdown)

	# Victory Screen
	var victory_script := load("res://ui/results/victory_screen.gd")
	if victory_script:
		victory_screen = victory_script.new()
		victory_screen.name = "VictoryScreen"
		add_child(victory_screen)

	# Animated Results
	var results_script := load("res://ui/results/animated_results.gd")
	if results_script:
		animated_results = results_script.new()
		animated_results.name = "AnimatedResults"
		add_child(animated_results)

	# Premium Toast
	var toast_script := load("res://ui/notifications/premium_toast.gd")
	if toast_script:
		premium_toast = toast_script.new()
		premium_toast.name = "PremiumToast"
		add_child(premium_toast)

	# Animated Dialog
	var dialog_script := load("res://ui/modals/animated_dialog.gd")
	if dialog_script:
		animated_dialog = dialog_script.new()
		animated_dialog.name = "AnimatedDialog"
		add_child(animated_dialog)


# ============================================================================
# SCENE TRANSITIONS
# ============================================================================

## Transition to a new scene with specified effect
func transition_to(scene_path: String, effect: int = Transition.FADE_VIGNETTE, duration: float = 0.8) -> void:
	if scene_transition:
		scene_transition.transition_to_scene(scene_path, effect, duration)


## Transition with callback at midpoint
func transition_with_callback(callback: Callable, effect: int = Transition.FADE_VIGNETTE, duration: float = 0.8) -> void:
	if scene_transition:
		scene_transition.transition_with_callback(callback, effect, duration)


## Quick fade to black and back
func fade_transition(scene_path: String, duration: float = 0.6) -> void:
	transition_to(scene_path, Transition.FADE_BLACK, duration)


## Circular wipe transition
func wipe_transition(scene_path: String, duration: float = 0.8) -> void:
	transition_to(scene_path, Transition.WIPE_CIRCULAR, duration)


## Shatter effect transition
func shatter_transition(scene_path: String, duration: float = 1.0) -> void:
	transition_to(scene_path, Transition.SHATTER, duration)


## Flash screen (for impacts)
func flash_screen(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	if scene_transition:
		scene_transition.flash_screen(color, duration)


# ============================================================================
# SCREEN EFFECTS
# ============================================================================

## Screen shake
func shake(intensity: float = 10.0, duration: float = 0.3) -> void:
	if transition_effects:
		transition_effects.shake_screen(intensity, duration)


## Impact shake (strong, short)
func impact_shake() -> void:
	if transition_effects:
		transition_effects.impact_shake()


## Explosion shake (very strong)
func explosion_shake() -> void:
	if transition_effects:
		transition_effects.explosion_shake()


## Enter slow motion
func slow_motion(time_scale: float = 0.3, transition_time: float = 0.1) -> void:
	if transition_effects:
		transition_effects.enter_slow_motion(time_scale, transition_time)


## Exit slow motion
func normal_speed(transition_time: float = 0.2) -> void:
	if transition_effects:
		transition_effects.exit_slow_motion(transition_time)


## Quick slow motion pulse
func slow_motion_pulse(time_scale: float = 0.2, hold: float = 0.3) -> void:
	if transition_effects:
		transition_effects.pulse_slow_motion(time_scale, hold)


## Chromatic aberration pulse
func chromatic_pulse(intensity: float = 15.0, duration: float = 0.3) -> void:
	if transition_effects:
		transition_effects.pulse_chromatic_aberration(intensity, duration)


## Combined impact effect
func impact_effect() -> void:
	if transition_effects:
		transition_effects.impact_effect()


## Damage received effect
func damage_effect() -> void:
	if transition_effects:
		transition_effects.damage_effect()


## Critical hit effect
func critical_hit_effect() -> void:
	if transition_effects:
		transition_effects.critical_hit_effect()


## Death effect
func death_effect() -> void:
	if transition_effects:
		transition_effects.death_effect()


# ============================================================================
# LOADING SCREENS
# ============================================================================

## Show premium loading screen for scene
func load_scene(scene_path: String) -> void:
	if cinematic_loading:
		cinematic_loading.load_scene(scene_path)


## Show loading screen manually
func show_loading() -> void:
	if cinematic_loading:
		cinematic_loading.show_screen()


## Hide loading screen
func hide_loading() -> void:
	if cinematic_loading:
		cinematic_loading.hide_screen()


## Set loading progress manually
func set_loading_progress(percent: float) -> void:
	if cinematic_loading:
		cinematic_loading.set_progress(percent)


# ============================================================================
# MATCH COUNTDOWN
# ============================================================================

## Start team match countdown
func start_countdown(team_red: String = "RED TEAM", team_blue: String = "BLUE TEAM", map_name: String = "") -> void:
	if match_countdown:
		match_countdown.start_countdown(team_red, team_blue, map_name)


## Start free-for-all countdown
func start_countdown_ffa(map_name: String = "") -> void:
	if match_countdown:
		match_countdown.start_countdown_ffa(map_name)


# ============================================================================
# VICTORY / DEFEAT
# ============================================================================

## Show victory screen
func show_victory(players: Array[Dictionary], mvp: Dictionary = {}, subtitle: String = "Your team won!") -> void:
	if victory_screen:
		victory_screen.show_victory(players, mvp, subtitle)


## Show defeat screen
func show_defeat(players: Array[Dictionary], subtitle: String = "Better luck next time!") -> void:
	if victory_screen:
		victory_screen.show_defeat(players, subtitle)


## Show draw screen
func show_draw(players: Array[Dictionary], subtitle: String = "It's a tie!") -> void:
	if victory_screen:
		victory_screen.show_draw(players, subtitle)


# ============================================================================
# RESULTS SCREEN
# ============================================================================

## Show animated results
func show_results(players: Array[Dictionary], stats: Dictionary = {}, awards: Array[Dictionary] = [], personal_bests: Array[String] = []) -> void:
	if animated_results:
		animated_results.show_results(players, stats, awards, personal_bests)


## Hide results
func hide_results() -> void:
	if animated_results:
		animated_results.hide_results()


# ============================================================================
# NOTIFICATIONS
# ============================================================================

## Show basic notification
func notify(message: String, type: int = Toast.INFO, duration: float = 4.0) -> int:
	if premium_toast:
		return premium_toast.show_notification(message, type, duration)
	return -1


## Show info notification
func notify_info(message: String) -> int:
	if premium_toast:
		return premium_toast.show_info(message)
	return -1


## Show success notification
func notify_success(message: String) -> int:
	if premium_toast:
		return premium_toast.show_success(message)
	return -1


## Show warning notification
func notify_warning(message: String) -> int:
	if premium_toast:
		return premium_toast.show_warning(message)
	return -1


## Show error notification
func notify_error(message: String) -> int:
	if premium_toast:
		return premium_toast.show_error(message)
	return -1


## Show achievement unlocked
func achievement_unlocked(title: String, description: String) -> int:
	if premium_toast:
		return premium_toast.show_achievement(title, description)
	return -1


## Show level up
func level_up(new_level: int) -> int:
	if premium_toast:
		return premium_toast.show_level_up(new_level)
	return -1


## Show new item obtained
func new_item(item_name: String, rarity: String = "common") -> int:
	if premium_toast:
		return premium_toast.show_new_item(item_name, rarity)
	return -1


## Show challenge complete
func challenge_complete(challenge_name: String, reward: String = "") -> int:
	if premium_toast:
		return premium_toast.show_challenge_complete(challenge_name, reward)
	return -1


## Dismiss notification
func dismiss_notification(id: int) -> void:
	if premium_toast:
		premium_toast.dismiss(id)


## Dismiss all notifications
func dismiss_all_notifications() -> void:
	if premium_toast:
		premium_toast.dismiss_all()


# ============================================================================
# DIALOGS
# ============================================================================

## Show info dialog
func dialog_info(title: String, message: String, button: String = "OK") -> void:
	if animated_dialog:
		animated_dialog.show_info(title, message, button)


## Show confirmation dialog
func dialog_confirm(title: String, message: String, confirm: String = "Confirm", cancel: String = "Cancel") -> void:
	if animated_dialog:
		animated_dialog.show_confirm(title, message, confirm, cancel)


## Show warning dialog
func dialog_warning(title: String, message: String, button: String = "OK") -> void:
	if animated_dialog:
		animated_dialog.show_warning(title, message, button)


## Show error dialog
func dialog_error(title: String, message: String, button: String = "OK") -> void:
	if animated_dialog:
		animated_dialog.show_error(title, message, button)


## Show input dialog
func dialog_input(title: String, message: String, placeholder: String = "", confirm: String = "Submit", cancel: String = "Cancel") -> void:
	if animated_dialog:
		animated_dialog.show_input(title, message, placeholder, confirm, cancel)


## Get dialog input text
func get_dialog_input() -> String:
	if animated_dialog:
		return animated_dialog.get_input_text()
	return ""


## Close current dialog
func close_dialog() -> void:
	if animated_dialog:
		animated_dialog.close_dialog()


## Close all dialogs
func close_all_dialogs() -> void:
	if animated_dialog:
		animated_dialog.close_all()


## Connect to dialog signals
func connect_dialog_confirmed(callback: Callable) -> void:
	if animated_dialog:
		animated_dialog.dialog_confirmed.connect(callback)


func connect_dialog_cancelled(callback: Callable) -> void:
	if animated_dialog:
		animated_dialog.dialog_cancelled.connect(callback)
