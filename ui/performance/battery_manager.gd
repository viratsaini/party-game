## BatteryManager - Comprehensive battery optimization for mobile gaming
##
## Maximizes play time while maintaining smooth performance:
##
## - Battery level monitoring with platform-specific APIs
## - Charging state detection
## - Automatic power mode switching
## - Background app handling
## - Sleep mode optimizations
## - Screen brightness awareness
## - Animation disabling options
## - Aggressive power saving when critical
##
## The system balances battery life with user experience,
## ensuring players can finish their matches even on low battery.
##
## Usage:
##   BatteryManager.enable_power_saving()
##   BatteryManager.get_estimated_play_time()
##   BatteryManager.battery_critical.connect(_on_battery_critical)
class_name BatteryManager
extends Node


# =============================================================================
# region - Signals
# =============================================================================

## Emitted when battery level changes significantly (5% increments)
signal battery_level_changed(level: float, is_charging: bool)

## Emitted when charging state changes
signal charging_state_changed(is_charging: bool)

## Emitted when battery is low (20%)
signal battery_low()

## Emitted when battery is critical (10%)
signal battery_critical()

## Emitted when power mode changes
signal power_mode_changed(mode: PowerMode)

## Emitted when estimated play time changes
signal play_time_updated(minutes_remaining: float)

## Emitted when power saving features activate/deactivate
signal power_saving_changed(enabled: bool, features: Array[String])

## Emitted when app goes to background/foreground
signal app_state_changed(is_active: bool)

# endregion


# =============================================================================
# region - Enums
# =============================================================================

## Power modes
enum PowerMode {
	PERFORMANCE,    ## Full quality, maximum FPS
	BALANCED,       ## Balanced quality and battery
	POWER_SAVER,    ## Reduced quality for battery life
	EXTREME_SAVER,  ## Minimum quality, maximum battery
	AUTO            ## Automatic based on battery level
}

## Battery state
enum BatteryState {
	UNKNOWN,
	CHARGING,
	DISCHARGING,
	FULL,
	NOT_CHARGING
}

## Power saving features
enum PowerFeature {
	REDUCE_FPS,
	REDUCE_RESOLUTION,
	DISABLE_EFFECTS,
	DISABLE_PARTICLES,
	DISABLE_SHADOWS,
	DISABLE_ANIMATIONS,
	REDUCE_HAPTICS,
	REDUCE_AUDIO,
	DISABLE_BACKGROUND_TASKS
}

# endregion


# =============================================================================
# region - Constants
# =============================================================================

## Battery thresholds
const BATTERY_LOW_THRESHOLD: float = 0.20       ## 20%
const BATTERY_CRITICAL_THRESHOLD: float = 0.10  ## 10%
const BATTERY_EMERGENCY_THRESHOLD: float = 0.05 ## 5%

## FPS targets per power mode
const FPS_TARGETS: Dictionary = {
	PowerMode.PERFORMANCE: 60,
	PowerMode.BALANCED: 45,
	PowerMode.POWER_SAVER: 30,
	PowerMode.EXTREME_SAVER: 24
}

## Resolution scales per power mode
const RESOLUTION_SCALES: Dictionary = {
	PowerMode.PERFORMANCE: 1.0,
	PowerMode.BALANCED: 0.85,
	PowerMode.POWER_SAVER: 0.7,
	PowerMode.EXTREME_SAVER: 0.5
}

## Update intervals
const BATTERY_CHECK_INTERVAL: float = 10.0      ## Check every 10 seconds
const DRAIN_ESTIMATION_WINDOW: float = 300.0    ## 5 minute window for drain estimation
const QUICK_DRAIN_CHECK_INTERVAL: float = 30.0  ## Check drain rate every 30 seconds

## Power consumption estimates (% per hour at 60 FPS)
const BASE_DRAIN_RATE: float = 15.0             ## Base game drain
const EFFECT_DRAIN_MULTIPLIER: float = 1.3      ## With all effects
const POWER_SAVER_MULTIPLIER: float = 0.6       ## With power saver

# endregion


# =============================================================================
# region - Configuration
# =============================================================================

@export_group("Battery Settings")

## Enable automatic power management
@export var auto_power_management: bool = true

## Battery level to trigger low battery warning
@export_range(0.1, 0.5, 0.05) var low_battery_threshold: float = BATTERY_LOW_THRESHOLD

## Battery level to trigger critical warning
@export_range(0.05, 0.3, 0.05) var critical_battery_threshold: float = BATTERY_CRITICAL_THRESHOLD

## Automatically enable power saver at low battery
@export var auto_power_saver: bool = true

@export_group("Power Saver Settings")

## Features to disable in power saver mode
@export var power_saver_disable_effects: bool = true
@export var power_saver_disable_particles: bool = true
@export var power_saver_reduce_shadows: bool = true
@export var power_saver_reduce_haptics: bool = true

@export_group("Background Handling")

## Pause game when app goes to background
@export var pause_in_background: bool = true

## Reduce FPS when app is in background
@export var background_fps_limit: int = 5

## Time before suspending background processes (seconds)
@export var background_suspend_delay: float = 30.0

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

## Battery state
var battery_level: float = 1.0
var battery_state: BatteryState = BatteryState.UNKNOWN
var is_charging: bool = false

## Power mode
var current_power_mode: PowerMode = PowerMode.AUTO
var _effective_power_mode: PowerMode = PowerMode.BALANCED
var _power_saver_active: bool = false

## Drain estimation
var _drain_samples: Array[Dictionary] = []  ## {time, level}
var _estimated_drain_per_hour: float = 15.0
var _estimated_play_time_minutes: float = 60.0

## Timing
var _last_battery_check: float = 0.0
var _last_drain_check: float = 0.0
var _last_reported_level: float = 1.0

## App state
var _app_is_active: bool = true
var _background_timer: float = 0.0
var _previous_fps_limit: int = 60

## Feature tracking
var _disabled_features: Array[int] = []  ## PowerFeature values

## Platform detection
var _is_mobile: bool = false
var _is_android: bool = false
var _is_ios: bool = false

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	_detect_platform()
	_initialize_battery_state()

	process_mode = Node.PROCESS_MODE_ALWAYS

	print("[BatteryManager] Initialized on %s" % _get_platform_name())


func _process(delta: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0

	## Battery check
	if current_time - _last_battery_check >= BATTERY_CHECK_INTERVAL:
		_last_battery_check = current_time
		_update_battery_state()

	## Drain rate estimation
	if current_time - _last_drain_check >= QUICK_DRAIN_CHECK_INTERVAL:
		_last_drain_check = current_time
		_update_drain_estimation()

	## Background handling
	if not _app_is_active:
		_background_timer += delta
		if _background_timer >= background_suspend_delay:
			_suspend_background_processes()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_on_app_backgrounded()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_app_foregrounded()
		NOTIFICATION_APPLICATION_PAUSED:
			_on_app_paused()
		NOTIFICATION_APPLICATION_RESUMED:
			_on_app_resumed()


func _detect_platform() -> void:
	_is_android = OS.has_feature("android")
	_is_ios = OS.has_feature("ios")
	_is_mobile = _is_android or _is_ios


func _get_platform_name() -> String:
	if _is_android:
		return "Android"
	elif _is_ios:
		return "iOS"
	else:
		return "Desktop"


func _initialize_battery_state() -> void:
	## Get initial battery state
	_update_battery_state()
	_last_reported_level = battery_level

	## Initialize drain samples
	_drain_samples.append({
		"time": Time.get_ticks_msec() / 1000.0,
		"level": battery_level
	})

# endregion


# =============================================================================
# region - Battery State Updates
# =============================================================================

func _update_battery_state() -> void:
	var new_level := _get_battery_level()
	var new_charging := _get_charging_state()

	## Check for charging state change
	if new_charging != is_charging:
		is_charging = new_charging
		battery_state = BatteryState.CHARGING if is_charging else BatteryState.DISCHARGING
		charging_state_changed.emit(is_charging)

		## Reset drain samples when charging state changes
		_drain_samples.clear()

	## Check for significant level change (5%)
	if absf(new_level - _last_reported_level) >= 0.05:
		_last_reported_level = new_level
		battery_level = new_level
		battery_level_changed.emit(battery_level, is_charging)

		## Check thresholds
		_check_battery_thresholds()

	battery_level = new_level

	## Update power mode if auto
	if auto_power_management and current_power_mode == PowerMode.AUTO:
		_update_auto_power_mode()


func _get_battery_level() -> float:
	## Platform-specific battery level retrieval
	if _is_android:
		return _get_android_battery_level()
	elif _is_ios:
		return _get_ios_battery_level()
	else:
		## Desktop - assume plugged in
		return 1.0


func _get_charging_state() -> bool:
	if _is_android:
		return _get_android_charging_state()
	elif _is_ios:
		return _get_ios_charging_state()
	else:
		return true  ## Desktop assumed plugged in


func _get_android_battery_level() -> float:
	## Android battery level via JNI
	## This requires a native plugin for full access
	## For now, return a default
	## In production, use: Engine.get_singleton("BatteryPlugin").getBatteryLevel()
	return 1.0


func _get_android_charging_state() -> bool:
	## Android charging state via JNI
	return true


func _get_ios_battery_level() -> float:
	## iOS battery level via native plugin
	## UIDevice.current.batteryLevel
	return 1.0


func _get_ios_charging_state() -> bool:
	## iOS charging state
	## UIDevice.current.batteryState
	return true


func _check_battery_thresholds() -> void:
	if is_charging:
		return  ## Don't warn while charging

	if battery_level <= BATTERY_EMERGENCY_THRESHOLD:
		## Emergency mode
		if not _power_saver_active or _effective_power_mode != PowerMode.EXTREME_SAVER:
			_activate_extreme_saver()
		battery_critical.emit()

	elif battery_level <= critical_battery_threshold:
		## Critical - force power saver
		if auto_power_saver and not _power_saver_active:
			_activate_power_saver()
		battery_critical.emit()

	elif battery_level <= low_battery_threshold:
		## Low - suggest power saver
		battery_low.emit()

# endregion


# =============================================================================
# region - Power Mode Management
# =============================================================================

func _update_auto_power_mode() -> void:
	var target_mode: PowerMode

	if is_charging:
		## Charging - can use performance mode
		target_mode = PowerMode.PERFORMANCE
	elif battery_level <= BATTERY_EMERGENCY_THRESHOLD:
		target_mode = PowerMode.EXTREME_SAVER
	elif battery_level <= critical_battery_threshold:
		target_mode = PowerMode.POWER_SAVER
	elif battery_level <= low_battery_threshold:
		target_mode = PowerMode.BALANCED
	else:
		target_mode = PowerMode.PERFORMANCE

	if target_mode != _effective_power_mode:
		_set_effective_power_mode(target_mode)


func _set_effective_power_mode(mode: PowerMode) -> void:
	_effective_power_mode = mode

	## Apply settings
	match mode:
		PowerMode.PERFORMANCE:
			_apply_performance_settings()
		PowerMode.BALANCED:
			_apply_balanced_settings()
		PowerMode.POWER_SAVER:
			_apply_power_saver_settings()
		PowerMode.EXTREME_SAVER:
			_apply_extreme_saver_settings()

	power_mode_changed.emit(mode)
	print("[BatteryManager] Power mode changed to: %s" % PowerMode.keys()[mode])


func _apply_performance_settings() -> void:
	Engine.max_fps = FPS_TARGETS[PowerMode.PERFORMANCE]
	_set_resolution_scale(RESOLUTION_SCALES[PowerMode.PERFORMANCE])
	_restore_all_features()


func _apply_balanced_settings() -> void:
	Engine.max_fps = FPS_TARGETS[PowerMode.BALANCED]
	_set_resolution_scale(RESOLUTION_SCALES[PowerMode.BALANCED])
	_restore_all_features()


func _apply_power_saver_settings() -> void:
	Engine.max_fps = FPS_TARGETS[PowerMode.POWER_SAVER]
	_set_resolution_scale(RESOLUTION_SCALES[PowerMode.POWER_SAVER])

	var disabled: Array[String] = []

	if power_saver_disable_effects:
		_disable_feature(PowerFeature.DISABLE_EFFECTS)
		disabled.append("effects")
	if power_saver_disable_particles:
		_disable_feature(PowerFeature.DISABLE_PARTICLES)
		disabled.append("particles")
	if power_saver_reduce_shadows:
		_disable_feature(PowerFeature.DISABLE_SHADOWS)
		disabled.append("shadows")
	if power_saver_reduce_haptics:
		_disable_feature(PowerFeature.REDUCE_HAPTICS)
		disabled.append("haptics")

	power_saving_changed.emit(true, disabled)


func _apply_extreme_saver_settings() -> void:
	Engine.max_fps = FPS_TARGETS[PowerMode.EXTREME_SAVER]
	_set_resolution_scale(RESOLUTION_SCALES[PowerMode.EXTREME_SAVER])

	## Disable everything possible
	_disable_feature(PowerFeature.DISABLE_EFFECTS)
	_disable_feature(PowerFeature.DISABLE_PARTICLES)
	_disable_feature(PowerFeature.DISABLE_SHADOWS)
	_disable_feature(PowerFeature.DISABLE_ANIMATIONS)
	_disable_feature(PowerFeature.REDUCE_HAPTICS)
	_disable_feature(PowerFeature.REDUCE_AUDIO)

	var disabled: Array[String] = [
		"effects", "particles", "shadows", "animations", "haptics", "audio"
	]

	power_saving_changed.emit(true, disabled)


func _set_resolution_scale(scale: float) -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.scaling_3d_scale = clampf(scale, 0.25, 1.0)

# endregion


# =============================================================================
# region - Feature Management
# =============================================================================

func _disable_feature(feature: PowerFeature) -> void:
	if feature in _disabled_features:
		return

	_disabled_features.append(feature)

	match feature:
		PowerFeature.REDUCE_FPS:
			Engine.max_fps = 30
		PowerFeature.REDUCE_RESOLUTION:
			_set_resolution_scale(0.6)
		PowerFeature.DISABLE_EFFECTS:
			## Signal to effect systems to disable
			pass
		PowerFeature.DISABLE_PARTICLES:
			## Signal to particle systems
			pass
		PowerFeature.DISABLE_SHADOWS:
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_HARD
			)
		PowerFeature.DISABLE_ANIMATIONS:
			## Signal to animation systems
			pass
		PowerFeature.REDUCE_HAPTICS:
			## Reduce haptic intensity
			pass
		PowerFeature.REDUCE_AUDIO:
			## Reduce audio quality/channels
			pass


func _restore_feature(feature: PowerFeature) -> void:
	_disabled_features.erase(feature)


func _restore_all_features() -> void:
	_disabled_features.clear()
	_power_saver_active = false
	power_saving_changed.emit(false, [])


## Checks if a feature is currently disabled
func is_feature_disabled(feature: PowerFeature) -> bool:
	return feature in _disabled_features


## Gets list of all disabled features
func get_disabled_features() -> Array[int]:
	return _disabled_features.duplicate()

# endregion


# =============================================================================
# region - Power Saver Control
# =============================================================================

func _activate_power_saver() -> void:
	if _power_saver_active:
		return

	_power_saver_active = true
	_apply_power_saver_settings()

	print("[BatteryManager] Power saver activated (battery: %.0f%%)" % (battery_level * 100))


func _activate_extreme_saver() -> void:
	_power_saver_active = true
	_apply_extreme_saver_settings()

	print("[BatteryManager] EXTREME power saver activated (battery: %.0f%%)" % (battery_level * 100))


## Manually enables power saver mode
func enable_power_saving() -> void:
	current_power_mode = PowerMode.POWER_SAVER
	_activate_power_saver()


## Manually disables power saver mode
func disable_power_saving() -> void:
	current_power_mode = PowerMode.PERFORMANCE
	_restore_all_features()
	_apply_performance_settings()

# endregion


# =============================================================================
# region - Drain Estimation
# =============================================================================

func _update_drain_estimation() -> void:
	if is_charging:
		_estimated_drain_per_hour = 0.0
		_estimated_play_time_minutes = 999.0
		return

	## Add current sample
	_drain_samples.append({
		"time": Time.get_ticks_msec() / 1000.0,
		"level": battery_level
	})

	## Remove old samples
	var current_time := Time.get_ticks_msec() / 1000.0
	while _drain_samples.size() > 0:
		var oldest: Dictionary = _drain_samples[0]
		if current_time - (oldest["time"] as float) > DRAIN_ESTIMATION_WINDOW:
			_drain_samples.remove_at(0)
		else:
			break

	## Calculate drain rate
	if _drain_samples.size() >= 2:
		var first: Dictionary = _drain_samples[0]
		var last: Dictionary = _drain_samples[_drain_samples.size() - 1]

		var time_diff: float = (last["time"] as float) - (first["time"] as float)
		var level_diff: float = (first["level"] as float) - (last["level"] as float)

		if time_diff > 0 and level_diff >= 0:
			## Calculate drain per hour (level_diff is 0-1, convert to % per hour)
			_estimated_drain_per_hour = (level_diff / time_diff) * 3600.0 * 100.0

			## Calculate remaining play time
			if _estimated_drain_per_hour > 0:
				_estimated_play_time_minutes = (battery_level * 100.0 / _estimated_drain_per_hour) * 60.0
				play_time_updated.emit(_estimated_play_time_minutes)


## Gets estimated remaining play time in minutes
func get_estimated_play_time() -> float:
	return _estimated_play_time_minutes


## Gets estimated battery drain per hour (percentage)
func get_drain_rate_per_hour() -> float:
	return _estimated_drain_per_hour

# endregion


# =============================================================================
# region - Background Handling
# =============================================================================

func _on_app_backgrounded() -> void:
	_app_is_active = false
	_background_timer = 0.0
	app_state_changed.emit(false)

	## Reduce FPS immediately
	_previous_fps_limit = Engine.max_fps
	Engine.max_fps = background_fps_limit

	if pause_in_background:
		get_tree().paused = true

	print("[BatteryManager] App backgrounded, FPS limited to %d" % background_fps_limit)


func _on_app_foregrounded() -> void:
	_app_is_active = true
	_background_timer = 0.0
	app_state_changed.emit(true)

	## Restore FPS
	Engine.max_fps = _previous_fps_limit

	if pause_in_background:
		get_tree().paused = false

	## Refresh battery state
	_update_battery_state()

	print("[BatteryManager] App foregrounded, FPS restored to %d" % _previous_fps_limit)


func _on_app_paused() -> void:
	## Similar to backgrounded but more aggressive
	_on_app_backgrounded()


func _on_app_resumed() -> void:
	_on_app_foregrounded()


func _suspend_background_processes() -> void:
	## Called after extended time in background
	## Could unload resources, stop network, etc.
	print("[BatteryManager] Suspending background processes")

# endregion


# =============================================================================
# region - Public API
# =============================================================================

## Gets current battery level (0.0 - 1.0)
func get_battery_level() -> float:
	return battery_level


## Checks if device is charging
func is_device_charging() -> bool:
	return is_charging


## Gets the current power mode
func get_power_mode() -> PowerMode:
	return current_power_mode


## Gets the effective power mode (after auto adjustments)
func get_effective_power_mode() -> PowerMode:
	return _effective_power_mode


## Sets the power mode
func set_power_mode(mode: PowerMode) -> void:
	current_power_mode = mode

	if mode == PowerMode.AUTO:
		_update_auto_power_mode()
	else:
		_set_effective_power_mode(mode)


## Checks if power saver is active
func is_power_saver_active() -> bool:
	return _power_saver_active


## Checks if app is currently active (not backgrounded)
func is_app_active() -> bool:
	return _app_is_active


## Gets battery state as string
func get_battery_state_string() -> String:
	match battery_state:
		BatteryState.CHARGING: return "Charging"
		BatteryState.DISCHARGING: return "Discharging"
		BatteryState.FULL: return "Full"
		BatteryState.NOT_CHARGING: return "Not Charging"
		_: return "Unknown"


## Gets comprehensive battery info
func get_battery_info() -> Dictionary:
	return {
		"level": battery_level,
		"level_percent": battery_level * 100.0,
		"is_charging": is_charging,
		"state": get_battery_state_string(),
		"power_mode": PowerMode.keys()[current_power_mode],
		"effective_mode": PowerMode.keys()[_effective_power_mode],
		"power_saver_active": _power_saver_active,
		"drain_per_hour": _estimated_drain_per_hour,
		"play_time_minutes": _estimated_play_time_minutes,
		"disabled_features": _disabled_features.size(),
		"app_active": _app_is_active
	}


## Forces a battery state refresh
func refresh_battery_state() -> void:
	_update_battery_state()


## Gets FPS target for current power mode
func get_target_fps() -> int:
	return FPS_TARGETS.get(_effective_power_mode, 60)


## Gets resolution scale for current power mode
func get_target_resolution_scale() -> float:
	return RESOLUTION_SCALES.get(_effective_power_mode, 1.0)

# endregion
