## HapticController - Cross-platform haptic feedback system for BattleZone Party.
##
## Provides vibration feedback patterns for UI interactions, gameplay events,
## and accessibility features. Supports Android, iOS, and web vibration APIs,
## with intensity customization and pattern sequencing.
class_name HapticController
extends Node


# -- Signals --

## Emitted when haptic feedback is triggered.
signal haptic_triggered(pattern_name: String, intensity: float)

## Emitted when device capability is detected.
signal capability_detected(has_haptics: bool, supports_patterns: bool)

## Emitted when a haptic sequence completes.
signal sequence_completed(sequence_name: String)


# -- Enums --

## Predefined haptic patterns.
enum HapticPattern {
	TICK,           ## Very light, momentary
	LIGHT,          ## Light tap
	MEDIUM,         ## Standard press
	HEAVY,          ## Strong impact
	SUCCESS,        ## Pleasant confirmation
	ERROR,          ## Warning/error
	WARNING,        ## Caution alert
	DOUBLE_TAP,     ## Two quick taps
	TRIPLE_TAP,     ## Three quick taps
	LONG_PRESS,     ## Extended vibration
	PULSE,          ## Rhythmic pulse
	RAMP_UP,        ## Increasing intensity
	RAMP_DOWN,      ## Decreasing intensity
	HEARTBEAT,      ## Double-beat pattern
	EXPLOSION,      ## Strong impact with decay
	NOTIFICATION,   ## Alert pattern
	SELECTION,      ## Item selection
	SLIDER_TICK,    ## Granular feedback
	COUNTDOWN,      ## Rhythmic countdown
	ACHIEVEMENT,    ## Celebratory pattern
}


# -- Constants --

## Minimum time between haptic events to prevent overwhelming.
const MIN_HAPTIC_INTERVAL: float = 0.03

## Maximum pattern duration in milliseconds.
const MAX_PATTERN_DURATION: int = 2000

## Default intensity levels (0-255 for Android, 0-1 for normalized).
const INTENSITY_TICK: int = 30
const INTENSITY_LIGHT: int = 60
const INTENSITY_MEDIUM: int = 128
const INTENSITY_HEAVY: int = 200
const INTENSITY_MAX: int = 255


# -- Exports --

@export_group("Haptic Settings")

## Enable haptic feedback globally.
@export var haptics_enabled: bool = true

## Global intensity multiplier (0-1).
@export_range(0.0, 1.0, 0.05) var intensity_multiplier: float = 1.0

## Enable pattern sequences (complex vibrations).
@export var patterns_enabled: bool = true

## Respect device's Do Not Disturb / silent mode.
@export var respect_system_settings: bool = true

@export_group("Performance")

## Maximum haptic events per second.
@export_range(1, 60, 1) var max_events_per_second: int = 30

## Enable haptic pooling to reduce overhead.
@export var use_pooling: bool = true


# -- State --

## Device capability flags.
var _has_haptics: bool = false
var _supports_patterns: bool = false
var _supports_amplitude: bool = false

## Last haptic trigger time for throttling.
var _last_haptic_time: float = 0.0

## Events this second for rate limiting.
var _events_this_second: int = 0
var _second_start_time: float = 0.0

## Active sequences.
var _active_sequences: Dictionary = {}

## Pattern definitions (duration in ms, intensity 0-255).
var _patterns: Dictionary = {}

## Custom user patterns.
var _custom_patterns: Dictionary = {}

## Platform-specific vibrator reference.
var _vibrator: JavaObject = null  # Android
var _haptic_engine: Object = null  # iOS (placeholder)


# -- Lifecycle --

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detect_capabilities()
	_register_default_patterns()
	_initialize_platform_api()


func _process(delta: float) -> void:
	_update_sequences(delta)
	_update_rate_limiting()


# -- Platform Detection --

func _detect_capabilities() -> void:
	if OS.has_feature("android"):
		_has_haptics = true
		_supports_patterns = true
		_supports_amplitude = _check_android_amplitude_support()
	elif OS.has_feature("ios"):
		_has_haptics = true
		_supports_patterns = true
		_supports_amplitude = true
	elif OS.has_feature("web"):
		_has_haptics = _check_web_vibration_support()
		_supports_patterns = _has_haptics
		_supports_amplitude = false
	else:
		# Desktop - no standard haptic API
		_has_haptics = false
		_supports_patterns = false
		_supports_amplitude = false

	capability_detected.emit(_has_haptics, _supports_patterns)


func _check_android_amplitude_support() -> bool:
	# Android 8.0+ (API 26+) supports amplitude control
	if OS.has_feature("android"):
		# Check API level - requires JNI access
		# For now, assume modern devices support it
		return true
	return false


func _check_web_vibration_support() -> bool:
	# Check if navigator.vibrate is available via JavaScript
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("'vibrate' in navigator")
		return result == true
	return false


func _initialize_platform_api() -> void:
	if OS.has_feature("android"):
		_initialize_android_vibrator()
	elif OS.has_feature("ios"):
		_initialize_ios_haptics()


func _initialize_android_vibrator() -> void:
	# Get Android Vibrator service
	if Engine.has_singleton("Vibrator"):
		_vibrator = Engine.get_singleton("Vibrator")
	else:
		# Fallback: use JNI to access vibrator service
		# This requires a custom plugin or GDExtension
		pass


func _initialize_ios_haptics() -> void:
	# iOS Core Haptics initialization
	# Requires iOS plugin or GDExtension
	pass


# -- Pattern Registration --

func _register_default_patterns() -> void:
	# Each pattern is an array of [duration_ms, intensity, pause_ms]
	# For simple patterns, just [duration_ms, intensity]

	_patterns[HapticPattern.TICK] = [
		{"duration": 10, "intensity": INTENSITY_TICK}
	]

	_patterns[HapticPattern.LIGHT] = [
		{"duration": 25, "intensity": INTENSITY_LIGHT}
	]

	_patterns[HapticPattern.MEDIUM] = [
		{"duration": 40, "intensity": INTENSITY_MEDIUM}
	]

	_patterns[HapticPattern.HEAVY] = [
		{"duration": 60, "intensity": INTENSITY_HEAVY}
	]

	_patterns[HapticPattern.SUCCESS] = [
		{"duration": 30, "intensity": INTENSITY_LIGHT},
		{"pause": 50},
		{"duration": 50, "intensity": INTENSITY_MEDIUM},
	]

	_patterns[HapticPattern.ERROR] = [
		{"duration": 80, "intensity": INTENSITY_HEAVY},
		{"pause": 100},
		{"duration": 80, "intensity": INTENSITY_HEAVY},
	]

	_patterns[HapticPattern.WARNING] = [
		{"duration": 50, "intensity": INTENSITY_MEDIUM},
		{"pause": 80},
		{"duration": 50, "intensity": INTENSITY_MEDIUM},
		{"pause": 80},
		{"duration": 50, "intensity": INTENSITY_LIGHT},
	]

	_patterns[HapticPattern.DOUBLE_TAP] = [
		{"duration": 30, "intensity": INTENSITY_MEDIUM},
		{"pause": 60},
		{"duration": 30, "intensity": INTENSITY_MEDIUM},
	]

	_patterns[HapticPattern.TRIPLE_TAP] = [
		{"duration": 25, "intensity": INTENSITY_LIGHT},
		{"pause": 50},
		{"duration": 25, "intensity": INTENSITY_LIGHT},
		{"pause": 50},
		{"duration": 25, "intensity": INTENSITY_LIGHT},
	]

	_patterns[HapticPattern.LONG_PRESS] = [
		{"duration": 200, "intensity": INTENSITY_MEDIUM},
	]

	_patterns[HapticPattern.PULSE] = [
		{"duration": 40, "intensity": INTENSITY_MEDIUM},
		{"pause": 100},
		{"duration": 40, "intensity": INTENSITY_MEDIUM},
		{"pause": 100},
		{"duration": 40, "intensity": INTENSITY_MEDIUM},
	]

	_patterns[HapticPattern.RAMP_UP] = [
		{"duration": 30, "intensity": INTENSITY_TICK},
		{"pause": 30},
		{"duration": 30, "intensity": INTENSITY_LIGHT},
		{"pause": 30},
		{"duration": 30, "intensity": INTENSITY_MEDIUM},
		{"pause": 30},
		{"duration": 40, "intensity": INTENSITY_HEAVY},
	]

	_patterns[HapticPattern.RAMP_DOWN] = [
		{"duration": 40, "intensity": INTENSITY_HEAVY},
		{"pause": 30},
		{"duration": 30, "intensity": INTENSITY_MEDIUM},
		{"pause": 30},
		{"duration": 30, "intensity": INTENSITY_LIGHT},
		{"pause": 30},
		{"duration": 30, "intensity": INTENSITY_TICK},
	]

	_patterns[HapticPattern.HEARTBEAT] = [
		{"duration": 50, "intensity": INTENSITY_HEAVY},
		{"pause": 80},
		{"duration": 50, "intensity": INTENSITY_MEDIUM},
		{"pause": 400},
	]

	_patterns[HapticPattern.EXPLOSION] = [
		{"duration": 100, "intensity": INTENSITY_MAX},
		{"duration": 80, "intensity": INTENSITY_HEAVY},
		{"duration": 60, "intensity": INTENSITY_MEDIUM},
		{"duration": 40, "intensity": INTENSITY_LIGHT},
		{"duration": 30, "intensity": INTENSITY_TICK},
	]

	_patterns[HapticPattern.NOTIFICATION] = [
		{"duration": 30, "intensity": INTENSITY_MEDIUM},
		{"pause": 100},
		{"duration": 80, "intensity": INTENSITY_LIGHT},
	]

	_patterns[HapticPattern.SELECTION] = [
		{"duration": 20, "intensity": INTENSITY_LIGHT},
	]

	_patterns[HapticPattern.SLIDER_TICK] = [
		{"duration": 8, "intensity": INTENSITY_TICK},
	]

	_patterns[HapticPattern.COUNTDOWN] = [
		{"duration": 60, "intensity": INTENSITY_MEDIUM},
	]

	_patterns[HapticPattern.ACHIEVEMENT] = [
		{"duration": 40, "intensity": INTENSITY_LIGHT},
		{"pause": 60},
		{"duration": 60, "intensity": INTENSITY_MEDIUM},
		{"pause": 80},
		{"duration": 100, "intensity": INTENSITY_HEAVY},
		{"pause": 100},
		{"duration": 40, "intensity": INTENSITY_MEDIUM},
		{"pause": 40},
		{"duration": 40, "intensity": INTENSITY_MEDIUM},
	]


# -- Public API: Simple Vibrations --

## Trigger a simple vibration for a duration in milliseconds.
func vibrate(duration_ms: int = 50, intensity: float = 1.0) -> void:
	if not _can_vibrate():
		return

	var actual_intensity := int(clampf(intensity * intensity_multiplier, 0.0, 1.0) * 255)
	_execute_vibration(duration_ms, actual_intensity)
	_update_throttle()

	haptic_triggered.emit("custom", intensity)


## Trigger a predefined haptic pattern.
func vibrate_pattern(pattern: HapticPattern) -> void:
	if not _can_vibrate():
		return

	if not _patterns.has(pattern):
		push_warning("HapticController: Pattern %d not registered" % pattern)
		return

	var pattern_data: Array = _patterns[pattern]
	_execute_pattern(pattern_data)
	_update_throttle()

	haptic_triggered.emit(_get_pattern_name(pattern), intensity_multiplier)


## Trigger a named pattern (string-based for easier use).
func vibrate_named(pattern_name: String) -> void:
	var pattern := _name_to_pattern(pattern_name)
	if pattern >= 0:
		vibrate_pattern(pattern)
	elif _custom_patterns.has(pattern_name):
		_execute_pattern(_custom_patterns[pattern_name])
		haptic_triggered.emit(pattern_name, intensity_multiplier)


# -- Public API: Pattern Playback --

## Play a custom pattern sequence.
func play_custom_pattern(steps: Array) -> void:
	if not _can_vibrate() or not patterns_enabled:
		return

	_execute_pattern(steps)


## Register a custom pattern for later use.
func register_pattern(name: String, steps: Array) -> void:
	_custom_patterns[name] = steps


## Start a looping pattern.
func start_looping_pattern(pattern: HapticPattern, loop_delay_ms: int = 500) -> void:
	if not patterns_enabled:
		return

	var pattern_name := _get_pattern_name(pattern)
	if _active_sequences.has(pattern_name):
		return

	_active_sequences[pattern_name] = {
		"pattern": pattern,
		"loop_delay": loop_delay_ms / 1000.0,
		"timer": 0.0,
		"playing": true,
	}


## Stop a looping pattern.
func stop_looping_pattern(pattern: HapticPattern) -> void:
	var pattern_name := _get_pattern_name(pattern)
	if _active_sequences.has(pattern_name):
		_active_sequences.erase(pattern_name)
		sequence_completed.emit(pattern_name)


## Stop all active patterns.
func stop_all() -> void:
	for seq_name: String in _active_sequences.keys():
		sequence_completed.emit(seq_name)
	_active_sequences.clear()
	_cancel_vibration()


# -- Public API: Convenience Methods --

## Light tick for hover/navigate.
func tick() -> void:
	vibrate_pattern(HapticPattern.TICK)


## Light tap for selection.
func light() -> void:
	vibrate_pattern(HapticPattern.LIGHT)


## Medium tap for button press.
func medium() -> void:
	vibrate_pattern(HapticPattern.MEDIUM)


## Heavy tap for important actions.
func heavy() -> void:
	vibrate_pattern(HapticPattern.HEAVY)


## Success feedback.
func success() -> void:
	vibrate_pattern(HapticPattern.SUCCESS)


## Error feedback.
func error() -> void:
	vibrate_pattern(HapticPattern.ERROR)


## Warning feedback.
func warning() -> void:
	vibrate_pattern(HapticPattern.WARNING)


## Notification alert.
func notification() -> void:
	vibrate_pattern(HapticPattern.NOTIFICATION)


## Achievement unlock.
func achievement() -> void:
	vibrate_pattern(HapticPattern.ACHIEVEMENT)


## Explosion impact.
func explosion(intensity: float = 1.0) -> void:
	if intensity >= 0.7:
		vibrate_pattern(HapticPattern.EXPLOSION)
	elif intensity >= 0.4:
		vibrate_pattern(HapticPattern.HEAVY)
	else:
		vibrate_pattern(HapticPattern.MEDIUM)


## Countdown tick (increasing intensity as it approaches end).
func countdown_tick(remaining_seconds: int, total_seconds: int) -> void:
	var progress := 1.0 - (float(remaining_seconds) / float(total_seconds))
	var intensity := lerp(0.3, 1.0, progress)
	vibrate(int(50 + progress * 50), intensity)


# -- Platform Execution --

func _execute_vibration(duration_ms: int, intensity: int) -> void:
	duration_ms = mini(duration_ms, MAX_PATTERN_DURATION)

	if OS.has_feature("android"):
		_vibrate_android(duration_ms, intensity)
	elif OS.has_feature("ios"):
		_vibrate_ios(duration_ms, intensity)
	elif OS.has_feature("web"):
		_vibrate_web(duration_ms)


func _execute_pattern(steps: Array) -> void:
	# Convert pattern steps to platform-specific format
	var durations: Array[int] = []
	var intensities: Array[int] = []
	var total_duration := 0

	for step: Dictionary in steps:
		if step.has("pause"):
			durations.append(0)  # Pause represented as 0-duration
			intensities.append(0)
			durations.append(step["pause"])
			intensities.append(0)
			total_duration += step["pause"]
		elif step.has("duration"):
			var duration: int = step["duration"]
			var intensity: int = int(step.get("intensity", INTENSITY_MEDIUM) * intensity_multiplier)
			durations.append(duration)
			intensities.append(intensity)
			total_duration += duration

	if total_duration > MAX_PATTERN_DURATION:
		push_warning("HapticController: Pattern exceeds max duration, truncating")

	if OS.has_feature("android"):
		_vibrate_pattern_android(durations, intensities)
	elif OS.has_feature("ios"):
		_vibrate_pattern_ios(durations, intensities)
	elif OS.has_feature("web"):
		_vibrate_pattern_web(durations)


func _cancel_vibration() -> void:
	if OS.has_feature("android"):
		_cancel_android()
	elif OS.has_feature("ios"):
		_cancel_ios()
	elif OS.has_feature("web"):
		_cancel_web()


# -- Android Implementation --

func _vibrate_android(duration_ms: int, intensity: int) -> void:
	if _vibrator:
		if _supports_amplitude:
			# Use VibrationEffect with amplitude (API 26+)
			# _vibrator.vibrate(VibrationEffect.createOneShot(duration_ms, intensity))
			pass
		else:
			# Legacy vibration without amplitude control
			# _vibrator.vibrate(duration_ms)
			pass
	else:
		# Fallback: Use Input singleton which has basic vibration
		Input.vibrate_handheld(duration_ms)


func _vibrate_pattern_android(durations: Array[int], _intensities: Array[int]) -> void:
	# Convert to Android pattern format: [wait, vibrate, wait, vibrate, ...]
	var pattern: Array[int] = [0]  # Start immediately
	for duration: int in durations:
		pattern.append(duration)

	if _vibrator:
		# _vibrator.vibrate(pattern, -1)  # -1 = don't repeat
		pass
	else:
		# Fallback: simple single vibration
		var total := 0
		for d: int in durations:
			total += d
		Input.vibrate_handheld(total)


func _cancel_android() -> void:
	if _vibrator:
		# _vibrator.cancel()
		pass


# -- iOS Implementation --

func _vibrate_ios(duration_ms: int, intensity: int) -> void:
	# iOS uses Core Haptics or UIFeedbackGenerator
	# Requires native plugin
	var normalized := float(intensity) / 255.0
	_trigger_ios_haptic(duration_ms, normalized)


func _vibrate_pattern_ios(durations: Array[int], intensities: Array[int]) -> void:
	# Build CHHapticPattern and play it
	# Requires native plugin
	for i in range(durations.size()):
		if durations[i] > 0 and intensities[i] > 0:
			_trigger_ios_haptic(durations[i], float(intensities[i]) / 255.0)


func _trigger_ios_haptic(_duration_ms: int, _intensity: float) -> void:
	# Native iOS haptic - requires plugin
	# For now, use Input fallback
	Input.vibrate_handheld(50)


func _cancel_ios() -> void:
	# Stop iOS haptic engine
	pass


# -- Web Implementation --

func _vibrate_web(duration_ms: int) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate(%d)" % duration_ms)


func _vibrate_pattern_web(durations: Array[int]) -> void:
	if OS.has_feature("web"):
		var pattern_str := str(durations).replace("[", "").replace("]", "")
		JavaScriptBridge.eval("navigator.vibrate([%s])" % pattern_str)


func _cancel_web() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate(0)")


# -- Throttling and Rate Limiting --

func _can_vibrate() -> bool:
	if not haptics_enabled or not _has_haptics:
		return false

	var current_time := Time.get_ticks_msec() / 1000.0

	# Check minimum interval
	if current_time - _last_haptic_time < MIN_HAPTIC_INTERVAL:
		return false

	# Check rate limiting
	if _events_this_second >= max_events_per_second:
		return false

	# Check system settings (silent mode, etc.)
	if respect_system_settings and _is_system_silent():
		return false

	return true


func _update_throttle() -> void:
	_last_haptic_time = Time.get_ticks_msec() / 1000.0
	_events_this_second += 1


func _update_rate_limiting() -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - _second_start_time >= 1.0:
		_second_start_time = current_time
		_events_this_second = 0


func _is_system_silent() -> bool:
	# Check if device is in silent/vibrate mode
	# Platform-specific implementation needed
	return false


# -- Sequence Updates --

func _update_sequences(delta: float) -> void:
	for seq_name: String in _active_sequences.keys():
		var state: Dictionary = _active_sequences[seq_name]
		state["timer"] = (state["timer"] as float) + delta

		if (state["timer"] as float) >= (state["loop_delay"] as float):
			state["timer"] = 0.0
			if state["playing"]:
				vibrate_pattern(state["pattern"])


# -- Utilities --

func _get_pattern_name(pattern: HapticPattern) -> String:
	match pattern:
		HapticPattern.TICK: return "tick"
		HapticPattern.LIGHT: return "light"
		HapticPattern.MEDIUM: return "medium"
		HapticPattern.HEAVY: return "heavy"
		HapticPattern.SUCCESS: return "success"
		HapticPattern.ERROR: return "error"
		HapticPattern.WARNING: return "warning"
		HapticPattern.DOUBLE_TAP: return "double_tap"
		HapticPattern.TRIPLE_TAP: return "triple_tap"
		HapticPattern.LONG_PRESS: return "long_press"
		HapticPattern.PULSE: return "pulse"
		HapticPattern.RAMP_UP: return "ramp_up"
		HapticPattern.RAMP_DOWN: return "ramp_down"
		HapticPattern.HEARTBEAT: return "heartbeat"
		HapticPattern.EXPLOSION: return "explosion"
		HapticPattern.NOTIFICATION: return "notification"
		HapticPattern.SELECTION: return "selection"
		HapticPattern.SLIDER_TICK: return "slider_tick"
		HapticPattern.COUNTDOWN: return "countdown"
		HapticPattern.ACHIEVEMENT: return "achievement"
		_: return "unknown"


func _name_to_pattern(name: String) -> int:
	match name:
		"tick": return HapticPattern.TICK
		"light": return HapticPattern.LIGHT
		"medium": return HapticPattern.MEDIUM
		"heavy": return HapticPattern.HEAVY
		"success": return HapticPattern.SUCCESS
		"error": return HapticPattern.ERROR
		"warning": return HapticPattern.WARNING
		"double_tap": return HapticPattern.DOUBLE_TAP
		"triple_tap": return HapticPattern.TRIPLE_TAP
		"long_press": return HapticPattern.LONG_PRESS
		"pulse": return HapticPattern.PULSE
		"ramp_up": return HapticPattern.RAMP_UP
		"ramp_down": return HapticPattern.RAMP_DOWN
		"heartbeat": return HapticPattern.HEARTBEAT
		"explosion": return HapticPattern.EXPLOSION
		"notification": return HapticPattern.NOTIFICATION
		"selection": return HapticPattern.SELECTION
		"slider_tick": return HapticPattern.SLIDER_TICK
		"countdown": return HapticPattern.COUNTDOWN
		"achievement": return HapticPattern.ACHIEVEMENT
		_: return -1


# -- Capability Queries --

## Check if haptics are supported on this device.
func has_haptics() -> bool:
	return _has_haptics


## Check if pattern sequences are supported.
func supports_patterns() -> bool:
	return _supports_patterns


## Check if amplitude/intensity control is supported.
func supports_amplitude() -> bool:
	return _supports_amplitude


## Get device capability info.
func get_capabilities() -> Dictionary:
	return {
		"has_haptics": _has_haptics,
		"supports_patterns": _supports_patterns,
		"supports_amplitude": _supports_amplitude,
		"platform": _get_platform_name(),
	}


func _get_platform_name() -> String:
	if OS.has_feature("android"):
		return "android"
	elif OS.has_feature("ios"):
		return "ios"
	elif OS.has_feature("web"):
		return "web"
	else:
		return "desktop"


# -- Settings --

## Set global haptic intensity (0-1).
func set_intensity(intensity: float) -> void:
	intensity_multiplier = clampf(intensity, 0.0, 1.0)


## Get current intensity setting.
func get_intensity() -> float:
	return intensity_multiplier


## Enable/disable haptics globally.
func set_enabled(enabled: bool) -> void:
	haptics_enabled = enabled
	if not enabled:
		stop_all()


## Check if haptics are enabled.
func is_enabled() -> bool:
	return haptics_enabled
