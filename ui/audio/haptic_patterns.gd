## HapticPatterns - Advanced haptic feedback system with battery awareness for BattleZone Party.
##
## This system provides a comprehensive haptic pattern library with device capability
## detection, battery-aware intensity scaling, synchronized haptic sequences,
## custom pattern composition, and accessibility features. Designed for immersive
## tactile feedback that enhances UI and gameplay interactions.
class_name HapticPatterns
extends RefCounted


# -- Signals --

## Emitted when a haptic pattern is triggered.
signal pattern_triggered(pattern_id: String, intensity: float)

## Emitted when battery level affects haptic intensity.
signal battery_throttled(current_level: float, reduction_percent: float)

## Emitted when device capabilities are detected.
signal capabilities_detected(caps: Dictionary)

## Emitted when a haptic sequence completes.
signal sequence_completed(sequence_id: String)


# -- Constants --

## Minimum battery level before haptic reduction kicks in.
const BATTERY_REDUCTION_THRESHOLD: float = 0.30

## Battery level for minimal haptics only.
const BATTERY_MINIMAL_THRESHOLD: float = 0.15

## Battery level to completely disable haptics.
const BATTERY_DISABLE_THRESHOLD: float = 0.05

## Maximum pattern duration in milliseconds.
const MAX_PATTERN_DURATION_MS: int = 2500

## Minimum time between haptic events (throttling).
const MIN_EVENT_INTERVAL_MS: float = 25.0

## Default intensity levels for each strength.
const INTENSITY_ULTRA_LIGHT: float = 0.1
const INTENSITY_LIGHT: float = 0.25
const INTENSITY_MEDIUM: float = 0.5
const INTENSITY_HEAVY: float = 0.75
const INTENSITY_IMPACT: float = 1.0


# -- Enums --

## Predefined haptic pattern categories.
enum PatternCategory {
	UI_BASIC,       ## Button taps, hovers
	UI_NAVIGATION,  ## Menu navigation, tab switches
	UI_FEEDBACK,    ## Success, error, warning
	UI_SPECIAL,     ## Achievements, rewards
	GAMEPLAY,       ## Combat, pickups
	AMBIENT,        ## Environmental effects
	RHYTHM,         ## Musical/beat patterns
	CUSTOM,         ## User-defined patterns
}

## Haptic waveform types (for advanced devices).
enum WaveformType {
	CLICK,          ## Sharp click
	TICK,           ## Soft tick
	THUD,           ## Heavy impact
	BUZZ,           ## Continuous vibration
	DOUBLE_CLICK,   ## Two quick clicks
	RAMP_UP,        ## Increasing intensity
	RAMP_DOWN,      ## Decreasing intensity
	PULSE,          ## Rhythmic pulse
	CUSTOM_WAVE,    ## Custom waveform data
}

## Device haptic capability levels.
enum CapabilityLevel {
	NONE,           ## No haptic support
	BASIC,          ## Simple on/off vibration
	STANDARD,       ## Intensity control
	ADVANCED,       ## Waveform control (iOS CoreHaptics, Android VibrationEffect)
	PREMIUM,        ## Full waveform + multiple actuators
}


# -- Pattern Definition Classes --

## Single haptic element within a pattern.
class HapticElement extends RefCounted:
	## Duration in milliseconds.
	var duration_ms: int = 50
	## Intensity (0.0 - 1.0).
	var intensity: float = 0.5
	## Waveform type.
	var waveform: int = WaveformType.CLICK
	## Frequency for supported devices (Hz).
	var frequency: float = 200.0
	## Sharpness (iOS-specific, 0.0 - 1.0).
	var sharpness: float = 0.5

	func _init(dur: int = 50, intens: float = 0.5, wave: int = WaveformType.CLICK) -> void:
		duration_ms = dur
		intensity = intens
		waveform = wave


## Pause between haptic elements.
class HapticPause extends RefCounted:
	## Pause duration in milliseconds.
	var duration_ms: int = 50

	func _init(dur: int = 50) -> void:
		duration_ms = dur


## Complete haptic pattern definition.
class HapticPattern extends RefCounted:
	## Unique pattern identifier.
	var id: String = ""
	## Pattern category.
	var category: int = PatternCategory.UI_BASIC
	## Sequence of elements and pauses.
	var sequence: Array = []  # Array of HapticElement or HapticPause
	## Total duration in milliseconds.
	var total_duration_ms: int = 0
	## Priority level (0-5, higher = more important).
	var priority: int = 2
	## Whether this pattern can be interrupted.
	var interruptible: bool = true
	## Intensity multiplier applied to all elements.
	var intensity_scale: float = 1.0
	## Description for accessibility.
	var description: String = ""

	func add_element(element: HapticElement) -> HapticPattern:
		sequence.append(element)
		total_duration_ms += element.duration_ms
		return self

	func add_pause(duration_ms_val: int) -> HapticPattern:
		var pause := HapticPause.new(duration_ms_val)
		sequence.append(pause)
		total_duration_ms += duration_ms_val
		return self

	func calculate_duration() -> void:
		total_duration_ms = 0
		for item in sequence:
			if item is HapticElement:
				total_duration_ms += (item as HapticElement).duration_ms
			elif item is HapticPause:
				total_duration_ms += (item as HapticPause).duration_ms


## Active sequence state for playback tracking.
class SequenceState extends RefCounted:
	var pattern: HapticPattern = null
	var current_index: int = 0
	var elapsed_ms: float = 0.0
	var current_item_elapsed: float = 0.0
	var is_playing: bool = false
	var loop: bool = false
	var on_complete: Callable = Callable()


# -- State --

## All registered patterns.
var _patterns: Dictionary = {}  # String -> HapticPattern

## Device capability level.
var _capability_level: int = CapabilityLevel.NONE

## Detailed device capabilities.
var _device_caps: Dictionary = {
	"has_haptics": false,
	"supports_intensity": false,
	"supports_waveforms": false,
	"supports_frequency": false,
	"supports_sharpness": false,
	"max_intensity": 1.0,
	"min_duration_ms": 10,
	"max_duration_ms": 5000,
	"actuator_count": 1,
	"platform": "unknown",
}

## Current battery level (0.0 - 1.0).
var _battery_level: float = 1.0

## Battery-based intensity multiplier.
var _battery_multiplier: float = 1.0

## Whether haptics are globally enabled.
var _enabled: bool = true

## Global intensity multiplier (user setting).
var _global_intensity: float = 1.0

## Active haptic sequences.
var _active_sequences: Dictionary = {}  # String -> SequenceState

## Last haptic trigger time for throttling.
var _last_trigger_time_ms: float = 0.0

## Haptic event count this second for rate limiting.
var _events_this_second: int = 0
var _second_start_time: float = 0.0

## Maximum events per second.
var _max_events_per_second: int = 30


# -- Initialization --

func _init() -> void:
	_detect_capabilities()
	_register_all_patterns()


## Detect device haptic capabilities.
func _detect_capabilities() -> void:
	if OS.has_feature("android"):
		_detect_android_capabilities()
	elif OS.has_feature("ios"):
		_detect_ios_capabilities()
	elif OS.has_feature("web"):
		_detect_web_capabilities()
	else:
		_detect_desktop_capabilities()

	capabilities_detected.emit(_device_caps)


func _detect_android_capabilities() -> void:
	_device_caps["platform"] = "android"
	_device_caps["has_haptics"] = true

	# Android API 26+ supports VibrationEffect with amplitude
	# API 30+ supports VibrationEffect.Composition for waveforms
	# For now, assume standard level - could use JNI to query SDK version
	_capability_level = CapabilityLevel.STANDARD
	_device_caps["supports_intensity"] = true
	_device_caps["supports_waveforms"] = false  # Would need API 30+ check
	_device_caps["min_duration_ms"] = 10
	_device_caps["max_duration_ms"] = 5000


func _detect_ios_capabilities() -> void:
	_device_caps["platform"] = "ios"
	_device_caps["has_haptics"] = true

	# iOS Core Haptics (iPhone 8+) supports full waveform control
	# Older devices use UIFeedbackGenerator with preset patterns
	_capability_level = CapabilityLevel.ADVANCED
	_device_caps["supports_intensity"] = true
	_device_caps["supports_waveforms"] = true
	_device_caps["supports_sharpness"] = true
	_device_caps["min_duration_ms"] = 5
	_device_caps["max_duration_ms"] = 3000


func _detect_web_capabilities() -> void:
	_device_caps["platform"] = "web"

	# Web Vibration API is basic - on/off only
	# Modern browsers may support pattern arrays
	if OS.has_feature("web"):
		# Check for vibration support via JavaScript
		var has_vibrate = JavaScriptBridge.eval("'vibrate' in navigator")
		_device_caps["has_haptics"] = has_vibrate == true
		_capability_level = CapabilityLevel.BASIC if _device_caps["has_haptics"] else CapabilityLevel.NONE
		_device_caps["supports_intensity"] = false
		_device_caps["min_duration_ms"] = 50
		_device_caps["max_duration_ms"] = 10000
	else:
		_capability_level = CapabilityLevel.NONE


func _detect_desktop_capabilities() -> void:
	_device_caps["platform"] = "desktop"

	# Desktop typically has no standard haptic API
	# Some gaming peripherals have haptics but require specific SDKs
	_capability_level = CapabilityLevel.NONE
	_device_caps["has_haptics"] = false


## Register all default haptic patterns.
func _register_all_patterns() -> void:
	_register_ui_basic_patterns()
	_register_ui_navigation_patterns()
	_register_ui_feedback_patterns()
	_register_ui_special_patterns()
	_register_gameplay_patterns()
	_register_rhythm_patterns()


func _register_ui_basic_patterns() -> void:
	# Tick - Very light tap for hover
	var tick := HapticPattern.new()
	tick.id = "tick"
	tick.category = PatternCategory.UI_BASIC
	tick.priority = 0
	tick.description = "Very light tap"
	tick.add_element(HapticElement.new(10, INTENSITY_ULTRA_LIGHT, WaveformType.TICK))
	_register_pattern(tick)

	# Light Tap - Button hover
	var light_tap := HapticPattern.new()
	light_tap.id = "light_tap"
	light_tap.category = PatternCategory.UI_BASIC
	light_tap.priority = 1
	light_tap.description = "Light tap for hover"
	light_tap.add_element(HapticElement.new(15, INTENSITY_LIGHT, WaveformType.TICK))
	_register_pattern(light_tap)

	# Medium Tap - Button press
	var medium_tap := HapticPattern.new()
	medium_tap.id = "medium_tap"
	medium_tap.category = PatternCategory.UI_BASIC
	medium_tap.priority = 2
	medium_tap.description = "Standard button press"
	medium_tap.add_element(HapticElement.new(25, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(medium_tap)

	# Heavy Tap - Confirm action
	var heavy_tap := HapticPattern.new()
	heavy_tap.id = "heavy_tap"
	heavy_tap.category = PatternCategory.UI_BASIC
	heavy_tap.priority = 3
	heavy_tap.description = "Heavy confirmation tap"
	heavy_tap.add_element(HapticElement.new(40, INTENSITY_HEAVY, WaveformType.CLICK))
	_register_pattern(heavy_tap)

	# Impact - Strong press
	var impact := HapticPattern.new()
	impact.id = "impact"
	impact.category = PatternCategory.UI_BASIC
	impact.priority = 4
	impact.description = "Strong impact"
	impact.add_element(HapticElement.new(60, INTENSITY_IMPACT, WaveformType.THUD))
	_register_pattern(impact)

	# Double Tap - Toggle
	var double_tap := HapticPattern.new()
	double_tap.id = "double_tap"
	double_tap.category = PatternCategory.UI_BASIC
	double_tap.priority = 2
	double_tap.description = "Double tap for toggle"
	double_tap.add_element(HapticElement.new(20, INTENSITY_MEDIUM, WaveformType.CLICK))
	double_tap.add_pause(40)
	double_tap.add_element(HapticElement.new(20, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(double_tap)

	# Triple Tap - Triple action
	var triple_tap := HapticPattern.new()
	triple_tap.id = "triple_tap"
	triple_tap.category = PatternCategory.UI_BASIC
	triple_tap.priority = 2
	triple_tap.description = "Triple tap"
	triple_tap.add_element(HapticElement.new(15, INTENSITY_LIGHT, WaveformType.CLICK))
	triple_tap.add_pause(35)
	triple_tap.add_element(HapticElement.new(15, INTENSITY_LIGHT, WaveformType.CLICK))
	triple_tap.add_pause(35)
	triple_tap.add_element(HapticElement.new(15, INTENSITY_LIGHT, WaveformType.CLICK))
	_register_pattern(triple_tap)

	# Long Press - Press and hold
	var long_press := HapticPattern.new()
	long_press.id = "long_press"
	long_press.category = PatternCategory.UI_BASIC
	long_press.priority = 2
	long_press.description = "Long press feedback"
	long_press.add_element(HapticElement.new(150, INTENSITY_MEDIUM, WaveformType.BUZZ))
	_register_pattern(long_press)

	# Slider Tick - Fine control
	var slider_tick := HapticPattern.new()
	slider_tick.id = "slider_tick"
	slider_tick.category = PatternCategory.UI_BASIC
	slider_tick.priority = 0
	slider_tick.description = "Slider tick"
	slider_tick.add_element(HapticElement.new(8, INTENSITY_ULTRA_LIGHT, WaveformType.TICK))
	_register_pattern(slider_tick)

	# Slider Snap - Value snap
	var slider_snap := HapticPattern.new()
	slider_snap.id = "slider_snap"
	slider_snap.category = PatternCategory.UI_BASIC
	slider_snap.priority = 1
	slider_snap.description = "Slider snap to value"
	slider_snap.add_element(HapticElement.new(20, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(slider_snap)


func _register_ui_navigation_patterns() -> void:
	# Menu Navigate
	var navigate := HapticPattern.new()
	navigate.id = "navigate"
	navigate.category = PatternCategory.UI_NAVIGATION
	navigate.priority = 1
	navigate.description = "Menu item navigation"
	navigate.add_element(HapticElement.new(12, INTENSITY_LIGHT, WaveformType.TICK))
	_register_pattern(navigate)

	# Menu Select
	var select := HapticPattern.new()
	select.id = "select"
	select.category = PatternCategory.UI_NAVIGATION
	select.priority = 2
	select.description = "Menu item selection"
	select.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(select)

	# Menu Back
	var back := HapticPattern.new()
	back.id = "back"
	back.category = PatternCategory.UI_NAVIGATION
	back.priority = 2
	back.description = "Navigate back"
	back.add_element(HapticElement.new(25, INTENSITY_LIGHT, WaveformType.CLICK))
	back.add_pause(30)
	back.add_element(HapticElement.new(15, 0.15, WaveformType.TICK))
	_register_pattern(back)

	# Tab Switch
	var tab_switch := HapticPattern.new()
	tab_switch.id = "tab_switch"
	tab_switch.category = PatternCategory.UI_NAVIGATION
	tab_switch.priority = 2
	tab_switch.description = "Switch tabs"
	tab_switch.add_element(HapticElement.new(18, INTENSITY_LIGHT, WaveformType.CLICK))
	_register_pattern(tab_switch)

	# Swipe Left
	var swipe_left := HapticPattern.new()
	swipe_left.id = "swipe_left"
	swipe_left.category = PatternCategory.UI_NAVIGATION
	swipe_left.priority = 1
	swipe_left.description = "Swipe left gesture"
	swipe_left.add_element(HapticElement.new(15, INTENSITY_LIGHT, WaveformType.TICK))
	swipe_left.add_pause(20)
	swipe_left.add_element(HapticElement.new(20, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(swipe_left)

	# Swipe Right
	var swipe_right := HapticPattern.new()
	swipe_right.id = "swipe_right"
	swipe_right.category = PatternCategory.UI_NAVIGATION
	swipe_right.priority = 1
	swipe_right.description = "Swipe right gesture"
	swipe_right.add_element(HapticElement.new(20, INTENSITY_MEDIUM, WaveformType.CLICK))
	swipe_right.add_pause(20)
	swipe_right.add_element(HapticElement.new(15, INTENSITY_LIGHT, WaveformType.TICK))
	_register_pattern(swipe_right)

	# Scroll
	var scroll := HapticPattern.new()
	scroll.id = "scroll"
	scroll.category = PatternCategory.UI_NAVIGATION
	scroll.priority = 0
	scroll.description = "List scrolling"
	scroll.add_element(HapticElement.new(5, INTENSITY_ULTRA_LIGHT, WaveformType.TICK))
	_register_pattern(scroll)

	# Scroll End
	var scroll_end := HapticPattern.new()
	scroll_end.id = "scroll_end"
	scroll_end.category = PatternCategory.UI_NAVIGATION
	scroll_end.priority = 1
	scroll_end.description = "Reached scroll boundary"
	scroll_end.add_element(HapticElement.new(30, INTENSITY_LIGHT, WaveformType.THUD))
	_register_pattern(scroll_end)

	# Panel Open
	var panel_open := HapticPattern.new()
	panel_open.id = "panel_open"
	panel_open.category = PatternCategory.UI_NAVIGATION
	panel_open.priority = 2
	panel_open.description = "Panel opening"
	panel_open.add_element(HapticElement.new(15, INTENSITY_LIGHT, WaveformType.TICK))
	panel_open.add_pause(40)
	panel_open.add_element(HapticElement.new(35, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(panel_open)

	# Panel Close
	var panel_close := HapticPattern.new()
	panel_close.id = "panel_close"
	panel_close.category = PatternCategory.UI_NAVIGATION
	panel_close.priority = 2
	panel_close.description = "Panel closing"
	panel_close.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	panel_close.add_pause(30)
	panel_close.add_element(HapticElement.new(12, INTENSITY_LIGHT, WaveformType.TICK))
	_register_pattern(panel_close)


func _register_ui_feedback_patterns() -> void:
	# Success
	var success := HapticPattern.new()
	success.id = "success"
	success.category = PatternCategory.UI_FEEDBACK
	success.priority = 4
	success.description = "Success confirmation"
	success.add_element(HapticElement.new(20, INTENSITY_LIGHT, WaveformType.TICK))
	success.add_pause(60)
	success.add_element(HapticElement.new(40, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(success)

	# Error
	var error := HapticPattern.new()
	error.id = "error"
	error.category = PatternCategory.UI_FEEDBACK
	error.priority = 4
	error.description = "Error feedback"
	error.add_element(HapticElement.new(60, INTENSITY_HEAVY, WaveformType.THUD))
	error.add_pause(80)
	error.add_element(HapticElement.new(60, INTENSITY_HEAVY, WaveformType.THUD))
	_register_pattern(error)

	# Warning
	var warning := HapticPattern.new()
	warning.id = "warning"
	warning.category = PatternCategory.UI_FEEDBACK
	warning.priority = 4
	warning.description = "Warning alert"
	warning.add_element(HapticElement.new(40, INTENSITY_MEDIUM, WaveformType.CLICK))
	warning.add_pause(60)
	warning.add_element(HapticElement.new(40, INTENSITY_MEDIUM, WaveformType.CLICK))
	warning.add_pause(60)
	warning.add_element(HapticElement.new(30, INTENSITY_LIGHT, WaveformType.TICK))
	_register_pattern(warning)

	# Notification
	var notification := HapticPattern.new()
	notification.id = "notification"
	notification.category = PatternCategory.UI_FEEDBACK
	notification.priority = 3
	notification.description = "Notification alert"
	notification.add_element(HapticElement.new(25, INTENSITY_MEDIUM, WaveformType.CLICK))
	notification.add_pause(80)
	notification.add_element(HapticElement.new(50, INTENSITY_LIGHT, WaveformType.BUZZ))
	_register_pattern(notification)

	# Confirm
	var confirm := HapticPattern.new()
	confirm.id = "confirm"
	confirm.category = PatternCategory.UI_FEEDBACK
	confirm.priority = 3
	confirm.description = "Action confirmed"
	confirm.add_element(HapticElement.new(35, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(confirm)

	# Cancel
	var cancel := HapticPattern.new()
	cancel.id = "cancel"
	cancel.category = PatternCategory.UI_FEEDBACK
	cancel.priority = 2
	cancel.description = "Action cancelled"
	cancel.add_element(HapticElement.new(25, INTENSITY_LIGHT, WaveformType.CLICK))
	_register_pattern(cancel)

	# Disabled
	var disabled := HapticPattern.new()
	disabled.id = "disabled"
	disabled.category = PatternCategory.UI_FEEDBACK
	disabled.priority = 1
	disabled.description = "Disabled control feedback"
	disabled.add_element(HapticElement.new(15, INTENSITY_ULTRA_LIGHT, WaveformType.TICK))
	_register_pattern(disabled)


func _register_ui_special_patterns() -> void:
	# Achievement
	var achievement := HapticPattern.new()
	achievement.id = "achievement"
	achievement.category = PatternCategory.UI_SPECIAL
	achievement.priority = 5
	achievement.interruptible = false
	achievement.description = "Achievement unlocked"
	achievement.add_element(HapticElement.new(30, INTENSITY_LIGHT, WaveformType.TICK))
	achievement.add_pause(50)
	achievement.add_element(HapticElement.new(50, INTENSITY_MEDIUM, WaveformType.CLICK))
	achievement.add_pause(70)
	achievement.add_element(HapticElement.new(80, INTENSITY_HEAVY, WaveformType.THUD))
	achievement.add_pause(80)
	achievement.add_element(HapticElement.new(40, INTENSITY_MEDIUM, WaveformType.CLICK))
	achievement.add_pause(40)
	achievement.add_element(HapticElement.new(40, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(achievement)

	# Level Up
	var level_up := HapticPattern.new()
	level_up.id = "level_up"
	level_up.category = PatternCategory.UI_SPECIAL
	level_up.priority = 5
	level_up.interruptible = false
	level_up.description = "Level up celebration"
	# Ramp up pattern
	level_up.add_element(HapticElement.new(20, 0.2, WaveformType.TICK))
	level_up.add_pause(30)
	level_up.add_element(HapticElement.new(25, 0.35, WaveformType.CLICK))
	level_up.add_pause(30)
	level_up.add_element(HapticElement.new(30, 0.5, WaveformType.CLICK))
	level_up.add_pause(30)
	level_up.add_element(HapticElement.new(40, 0.7, WaveformType.CLICK))
	level_up.add_pause(40)
	level_up.add_element(HapticElement.new(80, INTENSITY_IMPACT, WaveformType.THUD))
	_register_pattern(level_up)

	# Unlock
	var unlock := HapticPattern.new()
	unlock.id = "unlock"
	unlock.category = PatternCategory.UI_SPECIAL
	unlock.priority = 4
	unlock.description = "Item unlocked"
	unlock.add_element(HapticElement.new(40, INTENSITY_MEDIUM, WaveformType.CLICK))
	unlock.add_pause(60)
	unlock.add_element(HapticElement.new(60, INTENSITY_HEAVY, WaveformType.THUD))
	_register_pattern(unlock)

	# Purchase
	var purchase := HapticPattern.new()
	purchase.id = "purchase"
	purchase.category = PatternCategory.UI_SPECIAL
	purchase.priority = 4
	purchase.description = "Purchase completed"
	purchase.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	purchase.add_pause(50)
	purchase.add_element(HapticElement.new(50, INTENSITY_MEDIUM, WaveformType.CLICK))
	purchase.add_pause(50)
	purchase.add_element(HapticElement.new(40, INTENSITY_HEAVY, WaveformType.THUD))
	_register_pattern(purchase)

	# Reward
	var reward := HapticPattern.new()
	reward.id = "reward"
	reward.category = PatternCategory.UI_SPECIAL
	reward.priority = 5
	reward.interruptible = false
	reward.description = "Reward received"
	reward.add_element(HapticElement.new(25, INTENSITY_LIGHT, WaveformType.TICK))
	reward.add_pause(40)
	reward.add_element(HapticElement.new(40, INTENSITY_MEDIUM, WaveformType.CLICK))
	reward.add_pause(60)
	reward.add_element(HapticElement.new(70, INTENSITY_HEAVY, WaveformType.THUD))
	reward.add_pause(100)
	reward.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	reward.add_pause(30)
	reward.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(reward)

	# Coins
	var coins := HapticPattern.new()
	coins.id = "coins"
	coins.category = PatternCategory.UI_SPECIAL
	coins.priority = 3
	coins.description = "Coins collected"
	coins.add_element(HapticElement.new(15, INTENSITY_LIGHT, WaveformType.TICK))
	coins.add_pause(30)
	coins.add_element(HapticElement.new(20, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(coins)


func _register_gameplay_patterns() -> void:
	# Explosion Light
	var explosion_light := HapticPattern.new()
	explosion_light.id = "explosion_light"
	explosion_light.category = PatternCategory.GAMEPLAY
	explosion_light.priority = 4
	explosion_light.description = "Light explosion impact"
	explosion_light.add_element(HapticElement.new(80, INTENSITY_HEAVY, WaveformType.THUD))
	explosion_light.add_element(HapticElement.new(60, INTENSITY_MEDIUM, WaveformType.BUZZ))
	explosion_light.add_element(HapticElement.new(40, INTENSITY_LIGHT, WaveformType.TICK))
	_register_pattern(explosion_light)

	# Explosion Heavy
	var explosion_heavy := HapticPattern.new()
	explosion_heavy.id = "explosion_heavy"
	explosion_heavy.category = PatternCategory.GAMEPLAY
	explosion_heavy.priority = 5
	explosion_heavy.interruptible = false
	explosion_heavy.description = "Heavy explosion impact"
	explosion_heavy.add_element(HapticElement.new(120, INTENSITY_IMPACT, WaveformType.THUD))
	explosion_heavy.add_element(HapticElement.new(80, INTENSITY_HEAVY, WaveformType.BUZZ))
	explosion_heavy.add_element(HapticElement.new(60, INTENSITY_MEDIUM, WaveformType.BUZZ))
	explosion_heavy.add_element(HapticElement.new(40, INTENSITY_LIGHT, WaveformType.TICK))
	_register_pattern(explosion_heavy)

	# Hit Received
	var hit := HapticPattern.new()
	hit.id = "hit"
	hit.category = PatternCategory.GAMEPLAY
	hit.priority = 4
	hit.description = "Damage received"
	hit.add_element(HapticElement.new(50, INTENSITY_HEAVY, WaveformType.THUD))
	_register_pattern(hit)

	# Hit Marker (dealt damage)
	var hit_marker := HapticPattern.new()
	hit_marker.id = "hit_marker"
	hit_marker.category = PatternCategory.GAMEPLAY
	hit_marker.priority = 3
	hit_marker.description = "Damage dealt confirmation"
	hit_marker.add_element(HapticElement.new(25, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(hit_marker)

	# Kill
	var kill := HapticPattern.new()
	kill.id = "kill"
	kill.category = PatternCategory.GAMEPLAY
	kill.priority = 5
	kill.description = "Kill confirmed"
	kill.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	kill.add_pause(40)
	kill.add_element(HapticElement.new(60, INTENSITY_HEAVY, WaveformType.THUD))
	_register_pattern(kill)

	# Pickup
	var pickup := HapticPattern.new()
	pickup.id = "pickup"
	pickup.category = PatternCategory.GAMEPLAY
	pickup.priority = 2
	pickup.description = "Item picked up"
	pickup.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(pickup)

	# Power Up
	var power_up := HapticPattern.new()
	power_up.id = "power_up"
	power_up.category = PatternCategory.GAMEPLAY
	power_up.priority = 4
	power_up.description = "Power-up activated"
	power_up.add_element(HapticElement.new(20, INTENSITY_LIGHT, WaveformType.TICK))
	power_up.add_pause(30)
	power_up.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	power_up.add_pause(40)
	power_up.add_element(HapticElement.new(50, INTENSITY_HEAVY, WaveformType.THUD))
	_register_pattern(power_up)

	# Weapon Fire
	var weapon_fire := HapticPattern.new()
	weapon_fire.id = "weapon_fire"
	weapon_fire.category = PatternCategory.GAMEPLAY
	weapon_fire.priority = 3
	weapon_fire.description = "Weapon fired"
	weapon_fire.add_element(HapticElement.new(35, INTENSITY_MEDIUM, WaveformType.THUD))
	_register_pattern(weapon_fire)

	# Reload
	var reload := HapticPattern.new()
	reload.id = "reload"
	reload.category = PatternCategory.GAMEPLAY
	reload.priority = 2
	reload.description = "Weapon reload"
	reload.add_element(HapticElement.new(20, INTENSITY_LIGHT, WaveformType.CLICK))
	reload.add_pause(100)
	reload.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.THUD))
	_register_pattern(reload)

	# Jump
	var jump := HapticPattern.new()
	jump.id = "jump"
	jump.category = PatternCategory.GAMEPLAY
	jump.priority = 1
	jump.description = "Player jump"
	jump.add_element(HapticElement.new(20, INTENSITY_LIGHT, WaveformType.TICK))
	_register_pattern(jump)

	# Land
	var land := HapticPattern.new()
	land.id = "land"
	land.category = PatternCategory.GAMEPLAY
	land.priority = 2
	land.description = "Player landing"
	land.add_element(HapticElement.new(40, INTENSITY_MEDIUM, WaveformType.THUD))
	_register_pattern(land)


func _register_rhythm_patterns() -> void:
	# Heartbeat
	var heartbeat := HapticPattern.new()
	heartbeat.id = "heartbeat"
	heartbeat.category = PatternCategory.RHYTHM
	heartbeat.priority = 2
	heartbeat.description = "Heartbeat rhythm"
	heartbeat.add_element(HapticElement.new(40, INTENSITY_HEAVY, WaveformType.THUD))
	heartbeat.add_pause(60)
	heartbeat.add_element(HapticElement.new(35, INTENSITY_MEDIUM, WaveformType.THUD))
	heartbeat.add_pause(300)
	_register_pattern(heartbeat)

	# Countdown Tick
	var countdown := HapticPattern.new()
	countdown.id = "countdown"
	countdown.category = PatternCategory.RHYTHM
	countdown.priority = 4
	countdown.description = "Countdown tick"
	countdown.add_element(HapticElement.new(40, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(countdown)

	# Countdown Final
	var countdown_final := HapticPattern.new()
	countdown_final.id = "countdown_final"
	countdown_final.category = PatternCategory.RHYTHM
	countdown_final.priority = 5
	countdown_final.description = "Countdown final beat"
	countdown_final.add_element(HapticElement.new(80, INTENSITY_IMPACT, WaveformType.THUD))
	_register_pattern(countdown_final)

	# Pulse
	var pulse := HapticPattern.new()
	pulse.id = "pulse"
	pulse.category = PatternCategory.RHYTHM
	pulse.priority = 2
	pulse.description = "Rhythmic pulse"
	pulse.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	pulse.add_pause(80)
	pulse.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	pulse.add_pause(80)
	pulse.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	_register_pattern(pulse)

	# Ramp Up
	var ramp_up := HapticPattern.new()
	ramp_up.id = "ramp_up"
	ramp_up.category = PatternCategory.RHYTHM
	ramp_up.priority = 3
	ramp_up.description = "Increasing intensity"
	ramp_up.add_element(HapticElement.new(20, INTENSITY_ULTRA_LIGHT, WaveformType.TICK))
	ramp_up.add_pause(30)
	ramp_up.add_element(HapticElement.new(25, INTENSITY_LIGHT, WaveformType.CLICK))
	ramp_up.add_pause(30)
	ramp_up.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	ramp_up.add_pause(30)
	ramp_up.add_element(HapticElement.new(40, INTENSITY_HEAVY, WaveformType.THUD))
	_register_pattern(ramp_up)

	# Ramp Down
	var ramp_down := HapticPattern.new()
	ramp_down.id = "ramp_down"
	ramp_down.category = PatternCategory.RHYTHM
	ramp_down.priority = 3
	ramp_down.description = "Decreasing intensity"
	ramp_down.add_element(HapticElement.new(40, INTENSITY_HEAVY, WaveformType.THUD))
	ramp_down.add_pause(30)
	ramp_down.add_element(HapticElement.new(30, INTENSITY_MEDIUM, WaveformType.CLICK))
	ramp_down.add_pause(30)
	ramp_down.add_element(HapticElement.new(25, INTENSITY_LIGHT, WaveformType.CLICK))
	ramp_down.add_pause(30)
	ramp_down.add_element(HapticElement.new(20, INTENSITY_ULTRA_LIGHT, WaveformType.TICK))
	_register_pattern(ramp_down)


func _register_pattern(pattern: HapticPattern) -> void:
	pattern.calculate_duration()
	_patterns[pattern.id] = pattern


# -- Public API: Pattern Playback --

## Play a registered haptic pattern by ID.
func play(pattern_id: String) -> bool:
	if not _can_play():
		return false

	if not _patterns.has(pattern_id):
		push_warning("HapticPatterns: Pattern '%s' not found" % pattern_id)
		return false

	var pattern: HapticPattern = _patterns[pattern_id]
	return _execute_pattern(pattern)


## Play a pattern with custom intensity multiplier.
func play_with_intensity(pattern_id: String, intensity_mult: float) -> bool:
	if not _can_play():
		return false

	if not _patterns.has(pattern_id):
		return false

	var pattern: HapticPattern = _patterns[pattern_id]
	return _execute_pattern(pattern, intensity_mult)


## Start a looping pattern.
func start_loop(pattern_id: String, sequence_id: String = "") -> bool:
	if not _patterns.has(pattern_id):
		return false

	var seq_id := sequence_id if not sequence_id.is_empty() else pattern_id + "_loop"
	var pattern: HapticPattern = _patterns[pattern_id]

	var state := SequenceState.new()
	state.pattern = pattern
	state.is_playing = true
	state.loop = true

	_active_sequences[seq_id] = state
	return true


## Stop a looping pattern.
func stop_loop(sequence_id: String) -> void:
	if _active_sequences.has(sequence_id):
		_active_sequences.erase(sequence_id)
		sequence_completed.emit(sequence_id)


## Stop all active patterns.
func stop_all() -> void:
	var seq_ids := _active_sequences.keys()
	for seq_id: String in seq_ids:
		sequence_completed.emit(seq_id)
	_active_sequences.clear()


## Play a simple vibration (bypass pattern system).
func vibrate_simple(duration_ms: int, intensity: float = 0.5) -> bool:
	if not _can_play():
		return false

	var final_intensity := _calculate_final_intensity(intensity)
	_execute_vibration(duration_ms, final_intensity)
	_update_throttle()
	return true


## Create and play a custom pattern on-the-fly.
func play_custom(elements: Array) -> bool:
	if not _can_play():
		return false

	var pattern := HapticPattern.new()
	pattern.id = "_custom_%d" % Time.get_ticks_msec()
	pattern.category = PatternCategory.CUSTOM
	pattern.priority = 3

	for item in elements:
		if item is Dictionary:
			if item.has("duration") and item.has("intensity"):
				var elem := HapticElement.new()
				elem.duration_ms = item.get("duration", 50) as int
				elem.intensity = item.get("intensity", 0.5) as float
				elem.waveform = item.get("waveform", WaveformType.CLICK) as int
				pattern.add_element(elem)
			elif item.has("pause"):
				pattern.add_pause(item.get("pause", 50) as int)

	pattern.calculate_duration()
	return _execute_pattern(pattern)


# -- Public API: Convenience Methods --

## Light tick feedback.
func tick() -> void:
	play("tick")


## Standard tap feedback.
func tap() -> void:
	play("medium_tap")


## Heavy impact feedback.
func impact() -> void:
	play("impact")


## Success feedback.
func success() -> void:
	play("success")


## Error feedback.
func error() -> void:
	play("error")


## Warning feedback.
func warning() -> void:
	play("warning")


## Achievement feedback.
func achievement() -> void:
	play("achievement")


## Notification feedback.
func notification() -> void:
	play("notification")


# -- Battery Management --

## Update battery level for intensity scaling.
func update_battery_level(level: float) -> void:
	_battery_level = clampf(level, 0.0, 1.0)
	_calculate_battery_multiplier()


func _calculate_battery_multiplier() -> void:
	var old_mult := _battery_multiplier

	if _battery_level <= BATTERY_DISABLE_THRESHOLD:
		_battery_multiplier = 0.0
	elif _battery_level <= BATTERY_MINIMAL_THRESHOLD:
		_battery_multiplier = 0.25
	elif _battery_level <= BATTERY_REDUCTION_THRESHOLD:
		# Linear interpolation between minimal and reduction thresholds
		var t := (_battery_level - BATTERY_MINIMAL_THRESHOLD) / (BATTERY_REDUCTION_THRESHOLD - BATTERY_MINIMAL_THRESHOLD)
		_battery_multiplier = lerp(0.25, 0.7, t)
	else:
		_battery_multiplier = 1.0

	if abs(_battery_multiplier - old_mult) > 0.01:
		var reduction := (1.0 - _battery_multiplier) * 100.0
		battery_throttled.emit(_battery_level, reduction)


# -- Settings --

## Enable or disable haptics globally.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		stop_all()


## Check if haptics are enabled.
func is_enabled() -> bool:
	return _enabled and _device_caps["has_haptics"]


## Set global intensity multiplier (0.0 - 1.0).
func set_global_intensity(intensity: float) -> void:
	_global_intensity = clampf(intensity, 0.0, 1.0)


## Get global intensity setting.
func get_global_intensity() -> float:
	return _global_intensity


## Set maximum events per second.
func set_max_events_per_second(max_events: int) -> void:
	_max_events_per_second = clampi(max_events, 1, 60)


# -- Capability Queries --

## Get device capability level.
func get_capability_level() -> CapabilityLevel:
	return _capability_level as CapabilityLevel


## Get detailed device capabilities.
func get_capabilities() -> Dictionary:
	return _device_caps.duplicate()


## Check if device supports haptics.
func has_haptics() -> bool:
	return _device_caps["has_haptics"]


## Check if device supports intensity control.
func supports_intensity() -> bool:
	return _device_caps["supports_intensity"]


## Check if device supports waveform control.
func supports_waveforms() -> bool:
	return _device_caps["supports_waveforms"]


# -- Pattern Queries --

## Get all registered pattern IDs.
func get_pattern_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_patterns.keys())
	return result


## Get patterns by category.
func get_patterns_by_category(category: PatternCategory) -> Array[String]:
	var result: Array[String] = []
	for id: String in _patterns:
		var pattern: HapticPattern = _patterns[id]
		if pattern.category == category:
			result.append(id)
	return result


## Get pattern info.
func get_pattern_info(pattern_id: String) -> Dictionary:
	if not _patterns.has(pattern_id):
		return {}

	var pattern: HapticPattern = _patterns[pattern_id]
	return {
		"id": pattern.id,
		"category": pattern.category,
		"priority": pattern.priority,
		"duration_ms": pattern.total_duration_ms,
		"interruptible": pattern.interruptible,
		"description": pattern.description,
		"element_count": pattern.sequence.size(),
	}


# -- Internal Execution --

func _can_play() -> bool:
	if not _enabled or not _device_caps["has_haptics"]:
		return false

	if _battery_multiplier <= 0.0:
		return false

	var current_time := Time.get_ticks_msec() as float

	# Throttle check
	if current_time - _last_trigger_time_ms < MIN_EVENT_INTERVAL_MS:
		return false

	# Rate limit check
	if current_time - _second_start_time >= 1000.0:
		_second_start_time = current_time
		_events_this_second = 0

	if _events_this_second >= _max_events_per_second:
		return false

	return true


func _update_throttle() -> void:
	_last_trigger_time_ms = Time.get_ticks_msec() as float
	_events_this_second += 1


func _execute_pattern(pattern: HapticPattern, intensity_mult: float = 1.0) -> bool:
	if pattern.total_duration_ms > MAX_PATTERN_DURATION_MS:
		push_warning("HapticPatterns: Pattern '%s' exceeds max duration" % pattern.id)

	# Build platform-specific pattern
	var durations: Array[int] = []
	var intensities: Array[float] = []

	for item in pattern.sequence:
		if item is HapticElement:
			var elem := item as HapticElement
			durations.append(elem.duration_ms)
			intensities.append(elem.intensity * intensity_mult * pattern.intensity_scale)
		elif item is HapticPause:
			var pause := item as HapticPause
			durations.append(pause.duration_ms)
			intensities.append(0.0)

	_execute_pattern_platform(durations, intensities)
	_update_throttle()

	var final_intensity := _calculate_final_intensity(pattern.intensity_scale * intensity_mult)
	pattern_triggered.emit(pattern.id, final_intensity)

	return true


func _calculate_final_intensity(base_intensity: float) -> float:
	return base_intensity * _global_intensity * _battery_multiplier


func _execute_vibration(duration_ms: int, intensity: float) -> void:
	duration_ms = mini(duration_ms, MAX_PATTERN_DURATION_MS)
	var final_intensity := _calculate_final_intensity(intensity)

	if final_intensity <= 0.0:
		return

	if OS.has_feature("android"):
		_vibrate_android(duration_ms, final_intensity)
	elif OS.has_feature("ios"):
		_vibrate_ios(duration_ms, final_intensity)
	elif OS.has_feature("web"):
		_vibrate_web(duration_ms)


func _execute_pattern_platform(durations: Array[int], intensities: Array[float]) -> void:
	# Apply global multipliers to intensities
	var final_intensities: Array[float] = []
	for i: float in intensities:
		final_intensities.append(_calculate_final_intensity(i))

	if OS.has_feature("android"):
		_vibrate_pattern_android(durations, final_intensities)
	elif OS.has_feature("ios"):
		_vibrate_pattern_ios(durations, final_intensities)
	elif OS.has_feature("web"):
		_vibrate_pattern_web(durations)
	else:
		# Desktop fallback - no-op
		pass


# -- Platform Implementations --

func _vibrate_android(duration_ms: int, intensity: float) -> void:
	if _capability_level >= CapabilityLevel.STANDARD:
		# Use VibrationEffect with amplitude (API 26+)
		# Would need JNI or plugin for full implementation
		pass
	# Fallback to Input.vibrate_handheld
	Input.vibrate_handheld(duration_ms)


func _vibrate_pattern_android(durations: Array[int], intensities: Array[float]) -> void:
	# For complex patterns, use VibrationEffect.createWaveform (API 26+)
	# Fallback: single vibration with total duration
	var total_duration := 0
	for d: int in durations:
		total_duration += d
	Input.vibrate_handheld(mini(total_duration, MAX_PATTERN_DURATION_MS))


func _vibrate_ios(duration_ms: int, intensity: float) -> void:
	# iOS Core Haptics - requires native plugin
	# Fallback to Input.vibrate_handheld
	Input.vibrate_handheld(duration_ms)


func _vibrate_pattern_ios(durations: Array[int], intensities: Array[float]) -> void:
	# iOS Core Haptics with CHHapticPattern - requires native plugin
	var total_duration := 0
	for d: int in durations:
		total_duration += d
	Input.vibrate_handheld(mini(total_duration, MAX_PATTERN_DURATION_MS))


func _vibrate_web(duration_ms: int) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate(%d)" % duration_ms)


func _vibrate_pattern_web(durations: Array[int]) -> void:
	if OS.has_feature("web"):
		var pattern_str := str(durations).replace("[", "").replace("]", "")
		JavaScriptBridge.eval("navigator.vibrate([%s])" % pattern_str)


# -- Statistics --

## Get haptic system statistics.
func get_stats() -> Dictionary:
	return {
		"enabled": _enabled,
		"has_haptics": _device_caps["has_haptics"],
		"capability_level": _capability_level,
		"platform": _device_caps["platform"],
		"battery_level": _battery_level,
		"battery_multiplier": _battery_multiplier,
		"global_intensity": _global_intensity,
		"registered_patterns": _patterns.size(),
		"active_sequences": _active_sequences.size(),
		"events_this_second": _events_this_second,
		"max_events_per_second": _max_events_per_second,
	}
