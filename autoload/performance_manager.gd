## PerformanceManager — Core performance optimization system for BattleZone Party
##
## Manages all performance-related subsystems including:
## - Quality settings and presets
## - LOD (Level of Detail) management
## - Object pooling coordination
## - Dynamic resolution scaling
## - Thermal throttling detection
## - Battery optimization
## - Memory budget monitoring
## - Performance profiling and metrics
##
## Target: 60 FPS on mid-range mobile, 30 FPS on low-end
## Memory: <2GB RAM usage
## Battery: <20% drain per hour
extends Node


# region — Enums

## Quality preset levels
enum QualityPreset {
	LOW,
	MEDIUM,
	HIGH,
	ULTRA,
	CUSTOM
}

## Power modes for battery optimization
enum PowerMode {
	PERFORMANCE,   ## Maximum quality, 60 FPS target
	BALANCED,      ## Good quality, 45 FPS target, reduced effects
	POWER_SAVER,   ## Minimal effects, 30 FPS target
	AUTO           ## Automatic switching based on battery/thermal state
}

## Performance warning levels
enum PerformanceWarning {
	NONE,
	LOW_FPS,
	HIGH_MEMORY,
	THERMAL_THROTTLE,
	LOW_BATTERY,
	CRITICAL
}

# endregion


# region — Signals

## Emitted when the quality preset changes
signal quality_preset_changed(preset: QualityPreset)

## Emitted when power mode changes
signal power_mode_changed(mode: PowerMode)

## Emitted when a performance warning is triggered
signal performance_warning(warning: PerformanceWarning, message: String)

## Emitted when FPS drops below target
signal fps_warning(current_fps: float, target_fps: float)

## Emitted when thermal throttling is detected
signal thermal_throttling_detected(severity: float)

## Emitted when memory usage exceeds budget
signal memory_warning(used_mb: float, budget_mb: float)

## Emitted when performance metrics are updated (every frame)
signal metrics_updated(metrics: Dictionary)

# endregion


# region — Constants

## Frame rate targets for different quality levels
const FPS_TARGETS: Dictionary = {
	QualityPreset.LOW: 30,
	QualityPreset.MEDIUM: 45,
	QualityPreset.HIGH: 60,
	QualityPreset.ULTRA: 60,
}

## Memory budget in MB for different quality levels
const MEMORY_BUDGETS: Dictionary = {
	QualityPreset.LOW: 512,
	QualityPreset.MEDIUM: 1024,
	QualityPreset.HIGH: 1536,
	QualityPreset.ULTRA: 2048,
}

## Default quality settings per preset
const DEFAULT_QUALITY_SETTINGS: Dictionary = {
	QualityPreset.LOW: {
		"shadow_quality": 0,        # Off
		"shadow_resolution": 512,
		"particle_limit": 50,
		"particle_quality": 0.3,
		"post_processing": false,
		"bloom_enabled": false,
		"ssao_enabled": false,
		"ssr_enabled": false,
		"dof_enabled": false,
		"motion_blur": false,
		"draw_distance": 50.0,
		"lod_bias": 2.0,           # More aggressive LOD
		"texture_quality": 0,       # Low
		"msaa": 0,
		"fxaa": false,
		"vsync": true,
		"resolution_scale": 0.5,
	},
	QualityPreset.MEDIUM: {
		"shadow_quality": 1,        # Low
		"shadow_resolution": 1024,
		"particle_limit": 150,
		"particle_quality": 0.6,
		"post_processing": true,
		"bloom_enabled": true,
		"ssao_enabled": false,
		"ssr_enabled": false,
		"dof_enabled": false,
		"motion_blur": false,
		"draw_distance": 100.0,
		"lod_bias": 1.5,
		"texture_quality": 1,       # Medium
		"msaa": 0,
		"fxaa": true,
		"vsync": true,
		"resolution_scale": 0.75,
	},
	QualityPreset.HIGH: {
		"shadow_quality": 2,        # Medium
		"shadow_resolution": 2048,
		"particle_limit": 300,
		"particle_quality": 0.9,
		"post_processing": true,
		"bloom_enabled": true,
		"ssao_enabled": true,
		"ssr_enabled": false,
		"dof_enabled": false,
		"motion_blur": false,
		"draw_distance": 200.0,
		"lod_bias": 1.0,
		"texture_quality": 2,       # High
		"msaa": 2,
		"fxaa": true,
		"vsync": true,
		"resolution_scale": 1.0,
	},
	QualityPreset.ULTRA: {
		"shadow_quality": 3,        # Ultra
		"shadow_resolution": 4096,
		"particle_limit": 500,
		"particle_quality": 1.0,
		"post_processing": true,
		"bloom_enabled": true,
		"ssao_enabled": true,
		"ssr_enabled": true,
		"dof_enabled": true,
		"motion_blur": true,
		"draw_distance": 500.0,
		"lod_bias": 0.5,
		"texture_quality": 3,       # Ultra
		"msaa": 4,
		"fxaa": true,
		"vsync": true,
		"resolution_scale": 1.0,
	},
}

## Performance thresholds
const FPS_WARNING_THRESHOLD: float = 0.8      # Warn at 80% of target
const FPS_CRITICAL_THRESHOLD: float = 0.5     # Critical at 50% of target
const MEMORY_WARNING_THRESHOLD: float = 0.85  # Warn at 85% of budget
const THERMAL_SAMPLE_WINDOW: float = 2.0      # Seconds to sample thermal state
const FRAME_TIME_SAMPLE_COUNT: int = 60       # Frames to average for FPS
const METRICS_UPDATE_INTERVAL: float = 0.5    # How often to emit metrics

# endregion


# region — State Variables

## Current quality preset
var current_preset: QualityPreset = QualityPreset.MEDIUM

## Current power mode
var current_power_mode: PowerMode = PowerMode.AUTO

## Active quality settings (may differ from preset if custom)
var quality_settings: Dictionary = {}

## Whether auto-quality adjustment is enabled
var auto_quality_enabled: bool = true

## Debug overlay visible state
var debug_overlay_visible: bool = false

## Performance metrics tracking
var _frame_times: Array[float] = []
var _last_metrics_update: float = 0.0
var _metrics_accumulator: float = 0.0
var _frame_count: int = 0

## Thermal monitoring
var _thermal_frame_times: Array[float] = []
var _thermal_warning_active: bool = false
var _last_thermal_check: float = 0.0

## Memory monitoring
var _last_memory_check: float = 0.0
var _memory_check_interval: float = 1.0  # Check every second

## Current performance state
var _current_fps: float = 60.0
var _current_frame_time: float = 0.016
var _current_memory_mb: float = 0.0
var _draw_calls: int = 0
var _vertices: int = 0
var _objects_rendered: int = 0

## Auto-quality state
var _consecutive_low_fps_frames: int = 0
var _consecutive_high_fps_frames: int = 0
var _auto_quality_cooldown: float = 0.0

## References to subsystems
var _quality_settings_system: Node = null
var _lod_controller: Node = null
var _object_pool_manager: Node = null
var _dynamic_resolution: Node = null
var _thermal_monitor: Node = null
var _battery_optimizer: Node = null
var _memory_budget: Node = null

# endregion


# region — Lifecycle

func _ready() -> void:
	# Initialize with default medium settings
	quality_settings = DEFAULT_QUALITY_SETTINGS[QualityPreset.MEDIUM].duplicate()

	# Detect device capabilities and set initial quality
	_auto_detect_quality()

	# Apply initial settings
	_apply_quality_settings()

	# Set up performance monitoring
	_initialize_monitoring()

	print("[PerformanceManager] Initialized with preset: %s" % QualityPreset.keys()[current_preset])


func _process(delta: float) -> void:
	_track_frame_time(delta)
	_update_metrics(delta)
	_check_thermal_state(delta)
	_check_memory_usage(delta)
	_process_auto_quality(delta)


func _initialize_monitoring() -> void:
	# Pre-allocate frame time arrays
	_frame_times.resize(FRAME_TIME_SAMPLE_COUNT)
	_frame_times.fill(0.016)  # Assume 60 FPS initially

	_thermal_frame_times.resize(int(THERMAL_SAMPLE_WINDOW * 60))
	_thermal_frame_times.fill(0.016)

# endregion


# region — Quality Presets API

## Applies a quality preset
func set_quality_preset(preset: QualityPreset) -> void:
	if preset == QualityPreset.CUSTOM:
		push_warning("[PerformanceManager] Use set_custom_quality_setting() for custom presets")
		return

	current_preset = preset
	quality_settings = DEFAULT_QUALITY_SETTINGS[preset].duplicate()
	_apply_quality_settings()

	# Update FPS target
	Engine.max_fps = FPS_TARGETS.get(preset, 60)

	quality_preset_changed.emit(preset)
	print("[PerformanceManager] Quality preset changed to: %s" % QualityPreset.keys()[preset])


## Gets the current quality preset
func get_quality_preset() -> QualityPreset:
	return current_preset


## Gets a copy of the current quality settings
func get_quality_settings() -> Dictionary:
	return quality_settings.duplicate()


## Sets a specific quality setting (switches to CUSTOM preset)
func set_custom_quality_setting(setting_name: String, value: Variant) -> void:
	if not quality_settings.has(setting_name):
		push_error("[PerformanceManager] Unknown quality setting: %s" % setting_name)
		return

	quality_settings[setting_name] = value
	current_preset = QualityPreset.CUSTOM
	_apply_single_setting(setting_name, value)
	quality_preset_changed.emit(QualityPreset.CUSTOM)


## Gets a specific quality setting value
func get_quality_setting(setting_name: String) -> Variant:
	return quality_settings.get(setting_name, null)

# endregion


# region — Power Mode API

## Sets the power mode
func set_power_mode(mode: PowerMode) -> void:
	current_power_mode = mode
	_apply_power_mode(mode)
	power_mode_changed.emit(mode)
	print("[PerformanceManager] Power mode changed to: %s" % PowerMode.keys()[mode])


## Gets the current power mode
func get_power_mode() -> PowerMode:
	return current_power_mode


func _apply_power_mode(mode: PowerMode) -> void:
	match mode:
		PowerMode.PERFORMANCE:
			Engine.max_fps = 60
			auto_quality_enabled = false
			# Don't change quality preset, user controls it

		PowerMode.BALANCED:
			Engine.max_fps = 45
			auto_quality_enabled = true
			# Enable automatic quality adjustments

		PowerMode.POWER_SAVER:
			Engine.max_fps = 30
			auto_quality_enabled = true
			# Force lower quality for battery
			if current_preset > QualityPreset.LOW:
				set_quality_preset(QualityPreset.LOW)

		PowerMode.AUTO:
			auto_quality_enabled = true
			# System will automatically adjust based on conditions

# endregion


# region — Performance Metrics

## Returns current performance metrics
func get_performance_metrics() -> Dictionary:
	return {
		"fps": _current_fps,
		"frame_time_ms": _current_frame_time * 1000.0,
		"target_fps": FPS_TARGETS.get(current_preset, 60),
		"memory_mb": _current_memory_mb,
		"memory_budget_mb": MEMORY_BUDGETS.get(current_preset, 1024),
		"draw_calls": _draw_calls,
		"vertices": _vertices,
		"objects_rendered": _objects_rendered,
		"quality_preset": QualityPreset.keys()[current_preset],
		"power_mode": PowerMode.keys()[current_power_mode],
		"thermal_throttling": _thermal_warning_active,
		"resolution_scale": quality_settings.get("resolution_scale", 1.0),
	}


## Returns the current FPS
func get_current_fps() -> float:
	return _current_fps


## Returns whether performance is currently acceptable
func is_performance_acceptable() -> bool:
	var target_fps: float = FPS_TARGETS.get(current_preset, 60)
	return _current_fps >= target_fps * FPS_WARNING_THRESHOLD


func _track_frame_time(delta: float) -> void:
	# Shift array and add new frame time
	_frame_times.push_back(delta)
	if _frame_times.size() > FRAME_TIME_SAMPLE_COUNT:
		_frame_times.remove_at(0)

	# Calculate average FPS
	var total: float = 0.0
	for ft: float in _frame_times:
		total += ft
	_current_frame_time = total / _frame_times.size()
	_current_fps = 1.0 / _current_frame_time if _current_frame_time > 0 else 60.0


func _update_metrics(delta: float) -> void:
	_metrics_accumulator += delta
	_frame_count += 1

	if _metrics_accumulator >= METRICS_UPDATE_INTERVAL:
		# Get rendering statistics
		var rendering_info := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		)
		_draw_calls = rendering_info

		# Emit metrics update
		var metrics := get_performance_metrics()
		metrics_updated.emit(metrics)

		_metrics_accumulator = 0.0
		_frame_count = 0

# endregion


# region — Thermal Monitoring

func _check_thermal_state(delta: float) -> void:
	_last_thermal_check += delta

	if _last_thermal_check < THERMAL_SAMPLE_WINDOW:
		# Add frame time to thermal sample
		_thermal_frame_times.push_back(delta)
		if _thermal_frame_times.size() > int(THERMAL_SAMPLE_WINDOW * 60):
			_thermal_frame_times.remove_at(0)
		return

	_last_thermal_check = 0.0

	# Analyze frame time variance - high variance often indicates thermal throttling
	if _thermal_frame_times.is_empty():
		return

	var total: float = 0.0
	var min_ft: float = 1.0
	var max_ft: float = 0.0

	for ft: float in _thermal_frame_times:
		total += ft
		min_ft = min(min_ft, ft)
		max_ft = max(max_ft, ft)

	var avg_ft: float = total / _thermal_frame_times.size()
	var variance: float = max_ft - min_ft
	var variance_ratio: float = variance / avg_ft if avg_ft > 0 else 0.0

	# If frame time variance is high and average FPS is dropping, likely thermal throttling
	var target_ft: float = 1.0 / FPS_TARGETS.get(current_preset, 60)
	var performance_ratio: float = target_ft / avg_ft if avg_ft > 0 else 1.0

	if variance_ratio > 0.5 and performance_ratio < 0.7:
		if not _thermal_warning_active:
			_thermal_warning_active = true
			var severity: float = 1.0 - performance_ratio
			thermal_throttling_detected.emit(severity)
			performance_warning.emit(
				PerformanceWarning.THERMAL_THROTTLE,
				"Thermal throttling detected. Reducing quality to cool down."
			)

			# Auto-reduce quality if enabled
			if auto_quality_enabled and current_preset > QualityPreset.LOW:
				set_quality_preset(current_preset - 1)
	else:
		_thermal_warning_active = false

# endregion


# region — Memory Monitoring

func _check_memory_usage(delta: float) -> void:
	_last_memory_check += delta

	if _last_memory_check < _memory_check_interval:
		return

	_last_memory_check = 0.0

	# Get memory usage (Godot provides limited memory info)
	var static_memory: int = OS.get_static_memory_usage()
	_current_memory_mb = static_memory / 1048576.0  # Convert to MB

	var budget: float = MEMORY_BUDGETS.get(current_preset, 1024)
	var usage_ratio: float = _current_memory_mb / budget

	if usage_ratio > MEMORY_WARNING_THRESHOLD:
		memory_warning.emit(_current_memory_mb, budget)
		performance_warning.emit(
			PerformanceWarning.HIGH_MEMORY,
			"Memory usage at %.1f%% of budget" % (usage_ratio * 100)
		)

# endregion


# region — Auto Quality Adjustment

func _process_auto_quality(delta: float) -> void:
	if not auto_quality_enabled:
		return

	if _auto_quality_cooldown > 0:
		_auto_quality_cooldown -= delta
		return

	var target_fps: float = FPS_TARGETS.get(current_preset, 60)
	var fps_ratio: float = _current_fps / target_fps

	# Check for consistently low FPS
	if fps_ratio < FPS_WARNING_THRESHOLD:
		_consecutive_low_fps_frames += 1
		_consecutive_high_fps_frames = 0

		if _consecutive_low_fps_frames >= 60:  # 1 second of low FPS
			_downgrade_quality()
			_consecutive_low_fps_frames = 0
			_auto_quality_cooldown = 5.0  # Wait 5 seconds before next adjustment

	# Check for consistently high FPS (can upgrade)
	elif fps_ratio > 1.1:  # 10% above target
		_consecutive_high_fps_frames += 1
		_consecutive_low_fps_frames = 0

		if _consecutive_high_fps_frames >= 300:  # 5 seconds of high FPS
			_upgrade_quality()
			_consecutive_high_fps_frames = 0
			_auto_quality_cooldown = 10.0  # Wait longer before upgrading again

	else:
		_consecutive_low_fps_frames = 0
		_consecutive_high_fps_frames = 0


func _downgrade_quality() -> void:
	if current_preset == QualityPreset.CUSTOM:
		# Reduce individual settings
		_reduce_quality_incrementally()
	elif current_preset > QualityPreset.LOW:
		set_quality_preset(current_preset - 1)
		fps_warning.emit(_current_fps, FPS_TARGETS.get(current_preset, 60))


func _upgrade_quality() -> void:
	if current_preset == QualityPreset.CUSTOM:
		return  # Don't auto-upgrade custom settings

	if current_preset < QualityPreset.ULTRA:
		set_quality_preset(current_preset + 1)


func _reduce_quality_incrementally() -> void:
	# Reduce quality settings one by one in order of impact
	var reduction_order: Array[String] = [
		"ssao_enabled",
		"ssr_enabled",
		"motion_blur",
		"dof_enabled",
		"bloom_enabled",
		"particle_quality",
		"shadow_quality",
		"resolution_scale",
	]

	for setting: String in reduction_order:
		var current_value: Variant = quality_settings.get(setting)
		if current_value == null:
			continue

		if current_value is bool and current_value:
			set_custom_quality_setting(setting, false)
			return
		elif current_value is float and current_value > 0.3:
			set_custom_quality_setting(setting, current_value * 0.8)
			return
		elif current_value is int and current_value > 0:
			set_custom_quality_setting(setting, current_value - 1)
			return

# endregion


# region — Quality Settings Application

func _apply_quality_settings() -> void:
	# Apply all quality settings to the engine
	for setting_name: String in quality_settings:
		_apply_single_setting(setting_name, quality_settings[setting_name])


func _apply_single_setting(setting_name: String, value: Variant) -> void:
	match setting_name:
		"shadow_quality":
			_apply_shadow_quality(value as int)

		"shadow_resolution":
			# Shadow resolution is applied via DirectionalLight3D
			pass

		"particle_limit":
			# Stored for use by particle systems
			pass

		"particle_quality":
			# Stored for use by particle systems
			pass

		"post_processing":
			# Applied to WorldEnvironment
			_apply_post_processing(value as bool)

		"bloom_enabled":
			_apply_bloom(value as bool)

		"ssao_enabled":
			_apply_ssao(value as bool)

		"ssr_enabled":
			_apply_ssr(value as bool)

		"dof_enabled":
			_apply_dof(value as bool)

		"motion_blur":
			_apply_motion_blur(value as bool)

		"draw_distance":
			# Applied to Camera3D far plane
			pass

		"lod_bias":
			_apply_lod_bias(value as float)

		"texture_quality":
			_apply_texture_quality(value as int)

		"msaa":
			_apply_msaa(value as int)

		"fxaa":
			_apply_fxaa(value as bool)

		"vsync":
			_apply_vsync(value as bool)

		"resolution_scale":
			_apply_resolution_scale(value as float)


func _apply_shadow_quality(level: int) -> void:
	match level:
		0:  # Off
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_HARD
			)
		1:  # Low
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW
			)
		2:  # Medium
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_LOW
			)
		3:  # High/Ultra
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
			)


func _apply_post_processing(enabled: bool) -> void:
	# Post-processing is typically controlled via WorldEnvironment
	# This sets a flag that game scenes should respect
	pass


func _apply_bloom(enabled: bool) -> void:
	# Bloom is controlled via Environment resource
	pass


func _apply_ssao(enabled: bool) -> void:
	if enabled:
		RenderingServer.environment_set_ssao_quality(
			RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
			true,  # half_size
			0.5,   # adaptive_target
			2,     # blur_passes
			0.7    # fadeout_from
		)


func _apply_ssr(enabled: bool) -> void:
	# SSR is controlled via Environment resource
	pass


func _apply_dof(enabled: bool) -> void:
	# DOF is controlled via Camera3D attributes or Environment
	pass


func _apply_motion_blur(enabled: bool) -> void:
	# Motion blur is typically a post-process shader
	pass


func _apply_lod_bias(bias: float) -> void:
	RenderingServer.mesh_set_lod_threshold(0, bias * 1000.0)


func _apply_texture_quality(level: int) -> void:
	# Texture quality affects mipmap bias
	var mipmap_bias: float = (3 - level) * 1.0  # Higher bias = lower quality
	# Note: This would require custom implementation per-material
	pass


func _apply_msaa(level: int) -> void:
	var viewport := get_viewport()
	if viewport:
		match level:
			0:
				viewport.msaa_3d = Viewport.MSAA_DISABLED
			2:
				viewport.msaa_3d = Viewport.MSAA_2X
			4:
				viewport.msaa_3d = Viewport.MSAA_4X
			8:
				viewport.msaa_3d = Viewport.MSAA_8X


func _apply_fxaa(enabled: bool) -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if enabled else Viewport.SCREEN_SPACE_AA_DISABLED


func _apply_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)


func _apply_resolution_scale(scale: float) -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.scaling_3d_scale = clamp(scale, 0.25, 1.0)

# endregion


# region — Device Auto-Detection

func _auto_detect_quality() -> void:
	# Get device information
	var processor_count: int = OS.get_processor_count()
	var video_adapter: String = RenderingServer.get_video_adapter_name()
	var platform: String = OS.get_name()

	print("[PerformanceManager] Detecting device capabilities...")
	print("  Platform: %s" % platform)
	print("  Processor cores: %d" % processor_count)
	print("  GPU: %s" % video_adapter)

	# Simple heuristic based detection
	var detected_preset: QualityPreset = QualityPreset.MEDIUM

	if platform in ["Android", "iOS"]:
		# Mobile platforms
		if processor_count <= 4:
			detected_preset = QualityPreset.LOW
		elif processor_count <= 6:
			detected_preset = QualityPreset.MEDIUM
		else:
			detected_preset = QualityPreset.HIGH
	else:
		# Desktop platforms
		if processor_count <= 2:
			detected_preset = QualityPreset.LOW
		elif processor_count <= 4:
			detected_preset = QualityPreset.MEDIUM
		elif processor_count <= 8:
			detected_preset = QualityPreset.HIGH
		else:
			detected_preset = QualityPreset.ULTRA

	# Check for known low-end GPUs
	var low_end_gpus: Array[String] = [
		"Mali-400", "Mali-T720", "Adreno 306", "Adreno 308",
		"PowerVR SGX544", "Intel HD Graphics"
	]

	for gpu: String in low_end_gpus:
		if gpu.to_lower() in video_adapter.to_lower():
			detected_preset = QualityPreset.LOW
			break

	current_preset = detected_preset
	quality_settings = DEFAULT_QUALITY_SETTINGS[detected_preset].duplicate()
	Engine.max_fps = FPS_TARGETS.get(detected_preset, 60)

	print("[PerformanceManager] Auto-detected quality preset: %s" % QualityPreset.keys()[detected_preset])

# endregion


# region — Debug Overlay

## Toggles the performance debug overlay
func toggle_debug_overlay() -> void:
	debug_overlay_visible = not debug_overlay_visible
	# The actual overlay is managed by PerformanceOverlay scene


## Returns formatted debug text for the overlay
func get_debug_text() -> String:
	var metrics := get_performance_metrics()

	var text: String = """
FPS: %.1f / %d (%.1f ms)
Memory: %.1f / %.1f MB
Draw Calls: %d
Quality: %s
Power Mode: %s
Resolution: %.0f%%
Thermal: %s
""" % [
		metrics.fps,
		metrics.target_fps,
		metrics.frame_time_ms,
		metrics.memory_mb,
		metrics.memory_budget_mb,
		metrics.draw_calls,
		metrics.quality_preset,
		metrics.power_mode,
		metrics.resolution_scale * 100,
		"THROTTLING" if metrics.thermal_throttling else "OK"
	]

	return text

# endregion


# region — Profiling Integration

## Starts a profiled section
func begin_profile(section_name: String) -> void:
	if OS.is_debug_build():
		# In debug builds, we can use Godot's built-in profiler
		pass


## Ends a profiled section and returns duration in ms
func end_profile(section_name: String) -> float:
	if OS.is_debug_build():
		pass
	return 0.0


## Records a custom metric for profiling
func record_metric(metric_name: String, value: float) -> void:
	# Custom metrics can be displayed in the debug overlay
	pass

# endregion


# region — Utility Functions

## Gets the particle limit for the current quality settings
func get_particle_limit() -> int:
	return quality_settings.get("particle_limit", 150)


## Gets the particle quality multiplier (0.0 - 1.0)
func get_particle_quality() -> float:
	return quality_settings.get("particle_quality", 0.6)


## Gets the draw distance for the current quality settings
func get_draw_distance() -> float:
	return quality_settings.get("draw_distance", 100.0)


## Gets the LOD bias for the current quality settings
func get_lod_bias() -> float:
	return quality_settings.get("lod_bias", 1.0)


## Returns true if a specific effect is enabled
func is_effect_enabled(effect_name: String) -> bool:
	return quality_settings.get(effect_name, false)


## Saves current settings to user preferences
func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("performance", "preset", current_preset)
	config.set_value("performance", "power_mode", current_power_mode)
	config.set_value("performance", "auto_quality", auto_quality_enabled)

	for key: String in quality_settings:
		config.set_value("quality", key, quality_settings[key])

	var err := config.save("user://performance_settings.cfg")
	if err != OK:
		push_error("[PerformanceManager] Failed to save settings: %d" % err)


## Loads settings from user preferences
func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load("user://performance_settings.cfg")

	if err != OK:
		print("[PerformanceManager] No saved settings found, using defaults")
		return

	current_preset = config.get_value("performance", "preset", QualityPreset.MEDIUM)
	current_power_mode = config.get_value("performance", "power_mode", PowerMode.AUTO)
	auto_quality_enabled = config.get_value("performance", "auto_quality", true)

	if current_preset != QualityPreset.CUSTOM:
		quality_settings = DEFAULT_QUALITY_SETTINGS[current_preset].duplicate()
	else:
		for key: String in DEFAULT_QUALITY_SETTINGS[QualityPreset.MEDIUM]:
			quality_settings[key] = config.get_value("quality", key, DEFAULT_QUALITY_SETTINGS[QualityPreset.MEDIUM][key])

	_apply_quality_settings()
	Engine.max_fps = FPS_TARGETS.get(current_preset, 60)

	print("[PerformanceManager] Loaded settings - Preset: %s" % QualityPreset.keys()[current_preset])

# endregion
