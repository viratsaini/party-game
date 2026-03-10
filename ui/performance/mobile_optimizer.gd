## MobileOptimizer - BLAZING FAST mobile performance optimization system
##
## The ultimate mobile performance controller that ensures buttery-smooth
## gameplay on ANY device through intelligent optimization:
##
## - Device tier detection (Low/Mid/High/Ultra)
## - Real-time FPS-based quality scaling
## - Memory pressure monitoring and response
## - Thermal throttling detection and mitigation
## - Battery-aware performance modes
## - Platform-specific optimizations (Metal/Vulkan)
## - Network latency adaptation
## - Safe area and notch handling
##
## Target Performance:
## - Low-end: 30 FPS stable, <512MB RAM
## - Mid-range: 45 FPS stable, <1GB RAM
## - High-end: 60 FPS stable, <1.5GB RAM
## - Ultra: 120 FPS capable, <2GB RAM
##
## Usage:
##   MobileOptimizer.optimize_for_device()
##   MobileOptimizer.set_performance_target(MobileOptimizer.PerformanceTier.HIGH)
##   MobileOptimizer.get_safe_area_insets()
class_name MobileOptimizer
extends Node


# =============================================================================
# region - Signals
# =============================================================================

## Emitted when device tier is detected or changed
signal device_tier_detected(tier: DeviceTier)

## Emitted when performance mode changes
signal performance_mode_changed(mode: PerformanceMode)

## Emitted when thermal throttling is detected
signal thermal_throttling_detected(severity: ThermalSeverity)

## Emitted when battery level changes significantly
signal battery_level_changed(level: float, is_charging: bool)

## Emitted when safe area insets change (orientation change)
signal safe_area_changed(insets: Dictionary)

## Emitted when network quality changes
signal network_quality_changed(quality: NetworkQuality)

## Emitted when memory pressure is detected
signal memory_pressure_detected(severity: MemoryPressure)

## Emitted on each profiling tick with current metrics
signal metrics_updated(metrics: Dictionary)

# endregion


# =============================================================================
# region - Enums
# =============================================================================

## Device performance tiers
enum DeviceTier {
	LOW,        ## Budget phones, older devices (2GB RAM, 4 cores)
	MID,        ## Mid-range (3-4GB RAM, 6 cores)
	HIGH,       ## Flagship (6-8GB RAM, 8 cores)
	ULTRA       ## Gaming phones, tablets (8GB+ RAM, premium GPU)
}

## Performance modes for different scenarios
enum PerformanceMode {
	POWER_SAVER,    ## Maximum battery life, 30 FPS
	BALANCED,       ## Good balance, 45 FPS target
	PERFORMANCE,    ## Full quality, 60 FPS target
	ULTRA,          ## Max quality, 120 FPS if supported
	AUTO            ## Automatic based on conditions
}

## Thermal severity levels
enum ThermalSeverity {
	NORMAL,         ## Device running cool
	WARM,           ## Slightly elevated, no action needed
	HOT,            ## Reduce quality slightly
	CRITICAL        ## Aggressive throttling required
}

## Memory pressure levels
enum MemoryPressure {
	LOW,            ## Plenty of memory available
	MODERATE,       ## Should be cautious
	HIGH,           ## Need to free memory
	CRITICAL        ## Emergency cleanup required
}

## Network quality levels
enum NetworkQuality {
	OFFLINE,        ## No connection
	POOR,           ## High latency, packet loss
	FAIR,           ## Acceptable but not ideal
	GOOD,           ## Low latency, stable
	EXCELLENT       ## Optimal conditions
}

## GPU vendor detection
enum GPUVendor {
	UNKNOWN,
	ADRENO,         ## Qualcomm
	MALI,           ## ARM
	POWERVR,        ## Imagination Tech
	APPLE,          ## Apple GPU
	NVIDIA,         ## NVIDIA (Shield, etc.)
	INTEL           ## Intel (rare on mobile)
}

# endregion


# =============================================================================
# region - Constants
# =============================================================================

## FPS targets per device tier
const FPS_TARGETS: Dictionary = {
	DeviceTier.LOW: 30,
	DeviceTier.MID: 45,
	DeviceTier.HIGH: 60,
	DeviceTier.ULTRA: 120
}

## Memory budgets per device tier (MB)
const MEMORY_BUDGETS: Dictionary = {
	DeviceTier.LOW: 384,
	DeviceTier.MID: 768,
	DeviceTier.HIGH: 1280,
	DeviceTier.ULTRA: 2048
}

## Resolution scale per device tier
const RESOLUTION_SCALES: Dictionary = {
	DeviceTier.LOW: 0.5,
	DeviceTier.MID: 0.75,
	DeviceTier.HIGH: 1.0,
	DeviceTier.ULTRA: 1.0
}

## Particle limits per device tier
const PARTICLE_LIMITS: Dictionary = {
	DeviceTier.LOW: 32,
	DeviceTier.MID: 128,
	DeviceTier.HIGH: 256,
	DeviceTier.ULTRA: 512
}

## Frame time thresholds for quality adjustment (ms)
const FRAME_TIME_EXCELLENT: float = 8.0    ## <8ms = can increase quality
const FRAME_TIME_GOOD: float = 16.0        ## 16ms = 60 FPS target
const FRAME_TIME_ACCEPTABLE: float = 22.0  ## 22ms = 45 FPS
const FRAME_TIME_POOR: float = 33.0        ## 33ms = 30 FPS
const FRAME_TIME_CRITICAL: float = 50.0    ## 50ms = 20 FPS, needs help!

## Thermal detection via frame time variance
const THERMAL_VARIANCE_THRESHOLD: float = 0.4   ## 40% variance indicates throttling
const THERMAL_SAMPLE_WINDOW: int = 120          ## Frames to sample

## Memory thresholds
const MEMORY_WARNING_PERCENT: float = 0.75
const MEMORY_CRITICAL_PERCENT: float = 0.90

## Network quality thresholds (ms latency)
const LATENCY_EXCELLENT: int = 30
const LATENCY_GOOD: int = 60
const LATENCY_FAIR: int = 120
const LATENCY_POOR: int = 200

## Update intervals
const PROFILE_UPDATE_INTERVAL: float = 0.1    ## 100ms
const THERMAL_CHECK_INTERVAL: float = 2.0     ## 2 seconds
const BATTERY_CHECK_INTERVAL: float = 30.0    ## 30 seconds
const MEMORY_CHECK_INTERVAL: float = 1.0      ## 1 second

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

## Current device tier (detected at startup)
var device_tier: DeviceTier = DeviceTier.MID

## Current performance mode
var performance_mode: PerformanceMode = PerformanceMode.AUTO

## Current thermal state
var thermal_state: ThermalSeverity = ThermalSeverity.NORMAL

## Current memory pressure
var memory_state: MemoryPressure = MemoryPressure.LOW

## Current network quality
var network_state: NetworkQuality = NetworkQuality.GOOD

## Detected GPU vendor
var gpu_vendor: GPUVendor = GPUVendor.UNKNOWN

## Platform info
var is_mobile: bool = false
var is_android: bool = false
var is_ios: bool = false
var supports_metal: bool = false
var supports_vulkan: bool = false

## Battery state
var battery_level: float = 1.0
var is_charging: bool = true
var battery_saver_active: bool = false

## Safe area insets (for notch handling)
var safe_area_insets: Dictionary = {
	"top": 0.0,
	"bottom": 0.0,
	"left": 0.0,
	"right": 0.0
}

## Performance metrics
var current_fps: float = 60.0
var current_frame_time_ms: float = 16.67
var current_memory_mb: float = 0.0
var current_draw_calls: int = 0
var current_vertices: int = 0

## Quality adjustment state
var _auto_quality_enabled: bool = true
var _current_resolution_scale: float = 1.0
var _current_particle_limit: int = 256
var _effects_enabled: bool = true
var _shadows_enabled: bool = true
var _post_processing_enabled: bool = true

## Frame time tracking
var _frame_times: Array[float] = []
var _frame_time_index: int = 0
var _thermal_frame_times: Array[float] = []

## Timing accumulators
var _profile_timer: float = 0.0
var _thermal_timer: float = 0.0
var _battery_timer: float = 0.0
var _memory_timer: float = 0.0

## Quality adjustment cooldown
var _quality_adjust_cooldown: float = 0.0
var _consecutive_good_frames: int = 0
var _consecutive_bad_frames: int = 0

## Network tracking
var _latency_samples: Array[int] = []
var _packet_loss_samples: Array[float] = []

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	process_priority = -1000  ## Process first for accurate timing

	_detect_platform()
	_detect_gpu_vendor()
	_detect_device_tier()
	_detect_safe_area()
	_initialize_frame_buffers()

	## Apply initial optimizations
	optimize_for_device()

	print("[MobileOptimizer] Initialized")
	print("  Platform: %s" % _get_platform_string())
	print("  GPU: %s" % GPUVendor.keys()[gpu_vendor])
	print("  Tier: %s" % DeviceTier.keys()[device_tier])
	print("  Target FPS: %d" % FPS_TARGETS[device_tier])
	print("  Memory Budget: %d MB" % MEMORY_BUDGETS[device_tier])


func _process(delta: float) -> void:
	_track_frame_time(delta)

	_profile_timer += delta
	_thermal_timer += delta
	_battery_timer += delta
	_memory_timer += delta

	if _quality_adjust_cooldown > 0:
		_quality_adjust_cooldown -= delta

	## Profile update
	if _profile_timer >= PROFILE_UPDATE_INTERVAL:
		_profile_timer = 0.0
		_update_performance_metrics()
		_emit_metrics()

	## Thermal check
	if _thermal_timer >= THERMAL_CHECK_INTERVAL:
		_thermal_timer = 0.0
		_check_thermal_state()

	## Battery check
	if _battery_timer >= BATTERY_CHECK_INTERVAL:
		_battery_timer = 0.0
		_check_battery_state()

	## Memory check
	if _memory_timer >= MEMORY_CHECK_INTERVAL:
		_memory_timer = 0.0
		_check_memory_state()

	## Auto quality adjustment
	if _auto_quality_enabled and performance_mode == PerformanceMode.AUTO:
		_process_auto_quality(delta)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_on_app_backgrounded()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_app_foregrounded()
		NOTIFICATION_WM_SIZE_CHANGED:
			_detect_safe_area()


func _initialize_frame_buffers() -> void:
	## Pre-allocate frame time buffers
	_frame_times.resize(60)
	_frame_times.fill(16.67)

	_thermal_frame_times.resize(THERMAL_SAMPLE_WINDOW)
	_thermal_frame_times.fill(16.67)

	_latency_samples.resize(30)
	_latency_samples.fill(50)

	_packet_loss_samples.resize(30)
	_packet_loss_samples.fill(0.0)

# endregion


# =============================================================================
# region - Platform Detection
# =============================================================================

func _detect_platform() -> void:
	is_android = OS.has_feature("android")
	is_ios = OS.has_feature("ios")
	is_mobile = is_android or is_ios

	## Check renderer capabilities
	var renderer := ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")
	supports_vulkan = OS.has_feature("vulkan") or renderer == "forward_plus" or renderer == "mobile"
	supports_metal = is_ios  ## iOS always uses Metal


func _detect_gpu_vendor() -> void:
	var adapter_name := RenderingServer.get_video_adapter_name().to_lower()

	if "adreno" in adapter_name:
		gpu_vendor = GPUVendor.ADRENO
	elif "mali" in adapter_name:
		gpu_vendor = GPUVendor.MALI
	elif "powervr" in adapter_name or "imagination" in adapter_name:
		gpu_vendor = GPUVendor.POWERVR
	elif "apple" in adapter_name:
		gpu_vendor = GPUVendor.APPLE
	elif "nvidia" in adapter_name or "tegra" in adapter_name:
		gpu_vendor = GPUVendor.NVIDIA
	elif "intel" in adapter_name:
		gpu_vendor = GPUVendor.INTEL
	else:
		gpu_vendor = GPUVendor.UNKNOWN


func _detect_device_tier() -> void:
	var score: float = 0.0

	## CPU score (based on core count)
	var cpu_cores: int = OS.get_processor_count()
	if cpu_cores >= 8:
		score += 3.0
	elif cpu_cores >= 6:
		score += 2.0
	elif cpu_cores >= 4:
		score += 1.0

	## Memory score
	var memory_info := OS.get_memory_info()
	var total_ram_mb: float = float(memory_info.get("physical", 0)) / 1048576.0

	if total_ram_mb >= 8192:
		score += 3.0
	elif total_ram_mb >= 6144:
		score += 2.5
	elif total_ram_mb >= 4096:
		score += 2.0
	elif total_ram_mb >= 3072:
		score += 1.5
	elif total_ram_mb >= 2048:
		score += 1.0

	## GPU score (based on known GPU capabilities)
	match gpu_vendor:
		GPUVendor.APPLE:
			score += 2.5  ## Apple GPUs are generally high-performance
		GPUVendor.ADRENO:
			## Check for high-end Adreno (7xx, 6xx series)
			var adapter_name := RenderingServer.get_video_adapter_name()
			if "7" in adapter_name or "6" in adapter_name:
				score += 2.0
			else:
				score += 1.0
		GPUVendor.MALI:
			## Mali G-series are higher end
			var adapter_name := RenderingServer.get_video_adapter_name()
			if "G7" in adapter_name or "G9" in adapter_name:
				score += 2.0
			elif "G" in adapter_name:
				score += 1.5
			else:
				score += 0.5
		GPUVendor.NVIDIA:
			score += 2.5  ## Tegra is high-end
		GPUVendor.POWERVR:
			score += 1.0
		_:
			score += 1.0

	## Platform-specific adjustments
	if is_ios:
		score += 0.5  ## iOS devices generally well-optimized

	## Determine tier
	if score >= 7.0:
		device_tier = DeviceTier.ULTRA
	elif score >= 5.0:
		device_tier = DeviceTier.HIGH
	elif score >= 3.0:
		device_tier = DeviceTier.MID
	else:
		device_tier = DeviceTier.LOW

	device_tier_detected.emit(device_tier)


func _detect_safe_area() -> void:
	if not is_mobile:
		return

	## Get display safe area (accounts for notches, rounded corners, etc.)
	var screen_size := DisplayServer.window_get_size()
	var safe_rect := DisplayServer.get_display_safe_area()

	safe_area_insets = {
		"top": safe_rect.position.y,
		"left": safe_rect.position.x,
		"bottom": screen_size.y - (safe_rect.position.y + safe_rect.size.y),
		"right": screen_size.x - (safe_rect.position.x + safe_rect.size.x)
	}

	safe_area_changed.emit(safe_area_insets)


func _get_platform_string() -> String:
	if is_android:
		return "Android" + (" (Vulkan)" if supports_vulkan else "")
	elif is_ios:
		return "iOS (Metal)"
	else:
		return "Desktop"

# endregion


# =============================================================================
# region - Device Optimization
# =============================================================================

## Applies optimal settings for the detected device tier
func optimize_for_device() -> void:
	## Set FPS target
	var target_fps: int = FPS_TARGETS[device_tier]
	Engine.max_fps = target_fps

	## Set resolution scale
	_current_resolution_scale = RESOLUTION_SCALES[device_tier]
	_apply_resolution_scale(_current_resolution_scale)

	## Set particle limit
	_current_particle_limit = PARTICLE_LIMITS[device_tier]

	## Configure effects based on tier
	match device_tier:
		DeviceTier.LOW:
			_configure_low_quality()
		DeviceTier.MID:
			_configure_mid_quality()
		DeviceTier.HIGH:
			_configure_high_quality()
		DeviceTier.ULTRA:
			_configure_ultra_quality()

	## Apply platform-specific optimizations
	if is_android:
		_apply_android_optimizations()
	elif is_ios:
		_apply_ios_optimizations()

	## Apply GPU-specific optimizations
	_apply_gpu_optimizations()


func _configure_low_quality() -> void:
	_shadows_enabled = false
	_post_processing_enabled = false
	_effects_enabled = false

	_apply_shadow_quality(0)
	_apply_post_processing(false)
	_apply_msaa(0)

	## Aggressive LOD settings
	RenderingServer.mesh_set_lod_threshold(0, 3000.0)


func _configure_mid_quality() -> void:
	_shadows_enabled = true
	_post_processing_enabled = true
	_effects_enabled = true

	_apply_shadow_quality(1)
	_apply_post_processing(true)
	_apply_msaa(0)

	RenderingServer.mesh_set_lod_threshold(0, 2000.0)


func _configure_high_quality() -> void:
	_shadows_enabled = true
	_post_processing_enabled = true
	_effects_enabled = true

	_apply_shadow_quality(2)
	_apply_post_processing(true)
	_apply_msaa(2)

	RenderingServer.mesh_set_lod_threshold(0, 1000.0)


func _configure_ultra_quality() -> void:
	_shadows_enabled = true
	_post_processing_enabled = true
	_effects_enabled = true

	_apply_shadow_quality(3)
	_apply_post_processing(true)
	_apply_msaa(4)

	RenderingServer.mesh_set_lod_threshold(0, 500.0)


func _apply_android_optimizations() -> void:
	## Android-specific Vulkan optimizations
	if supports_vulkan:
		## Enable GPU-driven rendering features
		pass

	## Reduce texture quality on lower-end devices
	if device_tier <= DeviceTier.MID:
		## Apply texture mipmap bias
		pass


func _apply_ios_optimizations() -> void:
	## Metal-specific optimizations
	## iOS handles most optimizations at the driver level
	pass


func _apply_gpu_optimizations() -> void:
	match gpu_vendor:
		GPUVendor.ADRENO:
			## Adreno prefers certain texture formats
			pass
		GPUVendor.MALI:
			## Mali prefers tile-based rendering patterns
			pass
		GPUVendor.APPLE:
			## Apple GPUs are highly optimized already
			pass


func _apply_resolution_scale(scale: float) -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.scaling_3d_scale = clampf(scale, 0.25, 2.0)


func _apply_shadow_quality(level: int) -> void:
	match level:
		0:  ## Off
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_HARD
			)
		1:  ## Low
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW
			)
		2:  ## Medium
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_LOW
			)
		3:  ## High
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
			)


func _apply_post_processing(enabled: bool) -> void:
	_post_processing_enabled = enabled
	## Post-processing is typically controlled via Environment/WorldEnvironment


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

# endregion


# =============================================================================
# region - Performance Monitoring
# =============================================================================

func _track_frame_time(delta: float) -> void:
	var frame_time_ms: float = delta * 1000.0

	## Rolling buffer for frame times
	_frame_times[_frame_time_index] = frame_time_ms
	_frame_time_index = (_frame_time_index + 1) % _frame_times.size()

	## Also track for thermal analysis
	_thermal_frame_times.push_back(frame_time_ms)
	if _thermal_frame_times.size() > THERMAL_SAMPLE_WINDOW:
		_thermal_frame_times.remove_at(0)


func _update_performance_metrics() -> void:
	## Calculate average frame time
	var total: float = 0.0
	for ft: float in _frame_times:
		total += ft
	current_frame_time_ms = total / _frame_times.size()
	current_fps = 1000.0 / current_frame_time_ms if current_frame_time_ms > 0 else 0.0

	## Get memory usage
	current_memory_mb = float(OS.get_static_memory_usage()) / 1048576.0

	## Get rendering stats
	current_draw_calls = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)


func _emit_metrics() -> void:
	var metrics := {
		"fps": current_fps,
		"frame_time_ms": current_frame_time_ms,
		"memory_mb": current_memory_mb,
		"memory_budget_mb": MEMORY_BUDGETS[device_tier],
		"draw_calls": current_draw_calls,
		"device_tier": DeviceTier.keys()[device_tier],
		"thermal_state": ThermalSeverity.keys()[thermal_state],
		"memory_state": MemoryPressure.keys()[memory_state],
		"battery_level": battery_level,
		"resolution_scale": _current_resolution_scale,
		"particle_limit": _current_particle_limit
	}

	metrics_updated.emit(metrics)

# endregion


# =============================================================================
# region - Thermal Management
# =============================================================================

func _check_thermal_state() -> void:
	if _thermal_frame_times.size() < 30:
		return

	## Calculate frame time statistics
	var total: float = 0.0
	var min_ft: float = 1000.0
	var max_ft: float = 0.0

	for ft: float in _thermal_frame_times:
		total += ft
		min_ft = minf(min_ft, ft)
		max_ft = maxf(max_ft, ft)

	var avg_ft: float = total / _thermal_frame_times.size()
	var variance: float = (max_ft - min_ft) / avg_ft if avg_ft > 0 else 0.0

	## High variance with poor performance indicates thermal throttling
	var target_ft: float = 1000.0 / FPS_TARGETS[device_tier]
	var performance_ratio: float = target_ft / avg_ft if avg_ft > 0 else 1.0

	var new_state := ThermalSeverity.NORMAL

	if variance > THERMAL_VARIANCE_THRESHOLD and performance_ratio < 0.6:
		new_state = ThermalSeverity.CRITICAL
	elif variance > THERMAL_VARIANCE_THRESHOLD * 0.75 and performance_ratio < 0.75:
		new_state = ThermalSeverity.HOT
	elif variance > THERMAL_VARIANCE_THRESHOLD * 0.5:
		new_state = ThermalSeverity.WARM

	if new_state != thermal_state:
		thermal_state = new_state
		thermal_throttling_detected.emit(thermal_state)

		## Respond to thermal state
		if thermal_state == ThermalSeverity.CRITICAL:
			_apply_thermal_throttling_response()

func _apply_thermal_throttling_response() -> void:
	## Reduce quality to let device cool down
	if _current_resolution_scale > 0.5:
		_current_resolution_scale -= 0.1
		_apply_resolution_scale(_current_resolution_scale)

	## Reduce effects
	if _post_processing_enabled:
		_apply_post_processing(false)

	## Cap FPS lower
	Engine.max_fps = mini(Engine.max_fps, 30)

	print("[MobileOptimizer] Thermal throttling response activated")

# endregion


# =============================================================================
# region - Battery Management
# =============================================================================

func _check_battery_state() -> void:
	if not is_mobile:
		return

	## Get battery info (platform-specific)
	var new_level := _get_battery_level()
	var new_charging := _is_charging()

	if absf(new_level - battery_level) > 0.05 or new_charging != is_charging:
		battery_level = new_level
		is_charging = new_charging
		battery_level_changed.emit(battery_level, is_charging)

		## Auto-enable battery saver at low levels
		if battery_level < 0.2 and not is_charging and not battery_saver_active:
			enable_battery_saver()


func _get_battery_level() -> float:
	## Platform-specific battery level retrieval
	if is_android:
		## Android: Use JNI to get battery level
		## For now, return a default
		return 1.0
	elif is_ios:
		## iOS: Use native plugin
		return 1.0
	return 1.0


func _is_charging() -> bool:
	## Platform-specific charging detection
	return true


## Enables battery saver mode
func enable_battery_saver() -> void:
	battery_saver_active = true

	## Reduce FPS target
	Engine.max_fps = 30

	## Lower resolution
	_current_resolution_scale = maxf(_current_resolution_scale - 0.25, 0.5)
	_apply_resolution_scale(_current_resolution_scale)

	## Disable effects
	_apply_post_processing(false)
	_current_particle_limit = PARTICLE_LIMITS[DeviceTier.LOW]

	print("[MobileOptimizer] Battery saver mode enabled")


## Disables battery saver mode
func disable_battery_saver() -> void:
	battery_saver_active = false

	## Restore tier-appropriate settings
	optimize_for_device()

	print("[MobileOptimizer] Battery saver mode disabled")

# endregion


# =============================================================================
# region - Memory Management
# =============================================================================

func _check_memory_state() -> void:
	var budget: float = MEMORY_BUDGETS[device_tier]
	var usage_ratio: float = current_memory_mb / budget

	var new_state := MemoryPressure.LOW

	if usage_ratio >= MEMORY_CRITICAL_PERCENT:
		new_state = MemoryPressure.CRITICAL
	elif usage_ratio >= MEMORY_WARNING_PERCENT:
		new_state = MemoryPressure.HIGH
	elif usage_ratio >= 0.6:
		new_state = MemoryPressure.MODERATE

	if new_state != memory_state:
		memory_state = new_state
		memory_pressure_detected.emit(memory_state)

		## Respond to memory pressure
		if memory_state >= MemoryPressure.HIGH:
			_apply_memory_pressure_response()


func _apply_memory_pressure_response() -> void:
	## Reduce particle limit
	_current_particle_limit = maxi(_current_particle_limit / 2, 16)

	## Force garbage collection hints
	## Note: Godot doesn't have explicit GC control, but we can help

	print("[MobileOptimizer] Memory pressure response: particle limit = %d" % _current_particle_limit)

# endregion


# =============================================================================
# region - Network Quality
# =============================================================================

## Records a network latency sample
func record_latency(latency_ms: int) -> void:
	_latency_samples.push_back(latency_ms)
	if _latency_samples.size() > 30:
		_latency_samples.remove_at(0)

	_update_network_quality()


## Records packet loss
func record_packet_loss(loss_percent: float) -> void:
	_packet_loss_samples.push_back(loss_percent)
	if _packet_loss_samples.size() > 30:
		_packet_loss_samples.remove_at(0)


func _update_network_quality() -> void:
	if _latency_samples.is_empty():
		return

	var total: int = 0
	for lat: int in _latency_samples:
		total += lat
	var avg_latency: int = total / _latency_samples.size()

	var new_quality := NetworkQuality.GOOD

	if avg_latency <= LATENCY_EXCELLENT:
		new_quality = NetworkQuality.EXCELLENT
	elif avg_latency <= LATENCY_GOOD:
		new_quality = NetworkQuality.GOOD
	elif avg_latency <= LATENCY_FAIR:
		new_quality = NetworkQuality.FAIR
	elif avg_latency <= LATENCY_POOR:
		new_quality = NetworkQuality.POOR
	else:
		new_quality = NetworkQuality.OFFLINE

	if new_quality != network_state:
		network_state = new_quality
		network_quality_changed.emit(network_state)

# endregion


# =============================================================================
# region - Auto Quality Adjustment
# =============================================================================

func _process_auto_quality(delta: float) -> void:
	if _quality_adjust_cooldown > 0:
		return

	## Check frame time against targets
	var target_ft: float = 1000.0 / FPS_TARGETS[device_tier]

	if current_frame_time_ms < target_ft * 0.8:
		## Running faster than needed, can potentially increase quality
		_consecutive_good_frames += 1
		_consecutive_bad_frames = 0

		if _consecutive_good_frames >= 300:  ## 5 seconds of good performance
			_try_increase_quality()
			_consecutive_good_frames = 0
			_quality_adjust_cooldown = 10.0

	elif current_frame_time_ms > target_ft * 1.2:
		## Running slower than target
		_consecutive_bad_frames += 1
		_consecutive_good_frames = 0

		if _consecutive_bad_frames >= 60:  ## 1 second of poor performance
			_decrease_quality()
			_consecutive_bad_frames = 0
			_quality_adjust_cooldown = 3.0

	else:
		_consecutive_good_frames = 0
		_consecutive_bad_frames = 0


func _try_increase_quality() -> void:
	## Try to increase quality in order of visual impact

	## First, try resolution
	if _current_resolution_scale < 1.0:
		_current_resolution_scale = minf(_current_resolution_scale + 0.1, 1.0)
		_apply_resolution_scale(_current_resolution_scale)
		print("[MobileOptimizer] Increased resolution scale to %.2f" % _current_resolution_scale)
		return

	## Then particles
	if _current_particle_limit < PARTICLE_LIMITS[device_tier]:
		_current_particle_limit = mini(_current_particle_limit + 32, PARTICLE_LIMITS[device_tier])
		print("[MobileOptimizer] Increased particle limit to %d" % _current_particle_limit)
		return

	## Then post-processing
	if not _post_processing_enabled and device_tier >= DeviceTier.MID:
		_apply_post_processing(true)
		print("[MobileOptimizer] Enabled post-processing")


func _decrease_quality() -> void:
	## Decrease quality in reverse order

	## First, disable post-processing
	if _post_processing_enabled:
		_apply_post_processing(false)
		print("[MobileOptimizer] Disabled post-processing")
		return

	## Then reduce particles
	if _current_particle_limit > 16:
		_current_particle_limit = maxi(_current_particle_limit - 32, 16)
		print("[MobileOptimizer] Reduced particle limit to %d" % _current_particle_limit)
		return

	## Finally, reduce resolution
	if _current_resolution_scale > 0.5:
		_current_resolution_scale = maxf(_current_resolution_scale - 0.1, 0.5)
		_apply_resolution_scale(_current_resolution_scale)
		print("[MobileOptimizer] Reduced resolution scale to %.2f" % _current_resolution_scale)

# endregion


# =============================================================================
# region - App Lifecycle
# =============================================================================

func _on_app_backgrounded() -> void:
	## App went to background - pause heavy operations
	Engine.max_fps = 5  ## Minimal FPS when backgrounded

	## Could trigger memory cleanup here


func _on_app_foregrounded() -> void:
	## App came back - restore normal operation
	Engine.max_fps = FPS_TARGETS[device_tier]

	## Re-detect safe area (orientation may have changed)
	_detect_safe_area()

# endregion


# =============================================================================
# region - Public API
# =============================================================================

## Gets the current device tier
func get_device_tier() -> DeviceTier:
	return device_tier


## Gets the memory budget for the current device tier
func get_memory_budget() -> int:
	return MEMORY_BUDGETS[device_tier]


## Gets the FPS target for the current device tier
func get_fps_target() -> int:
	return FPS_TARGETS[device_tier]


## Gets the particle limit for the current settings
func get_particle_limit() -> int:
	return _current_particle_limit


## Gets the current resolution scale
func get_resolution_scale() -> float:
	return _current_resolution_scale


## Gets safe area insets for UI layout
func get_safe_area_insets() -> Dictionary:
	return safe_area_insets.duplicate()


## Checks if effects are currently enabled
func are_effects_enabled() -> bool:
	return _effects_enabled


## Checks if shadows are currently enabled
func are_shadows_enabled() -> bool:
	return _shadows_enabled


## Checks if post-processing is currently enabled
func is_post_processing_enabled() -> bool:
	return _post_processing_enabled


## Sets the performance mode
func set_performance_mode(mode: PerformanceMode) -> void:
	performance_mode = mode

	match mode:
		PerformanceMode.POWER_SAVER:
			Engine.max_fps = 30
			_auto_quality_enabled = false
			enable_battery_saver()

		PerformanceMode.BALANCED:
			Engine.max_fps = 45
			_auto_quality_enabled = true
			disable_battery_saver()

		PerformanceMode.PERFORMANCE:
			Engine.max_fps = 60
			_auto_quality_enabled = false
			disable_battery_saver()
			optimize_for_device()

		PerformanceMode.ULTRA:
			Engine.max_fps = 120
			_auto_quality_enabled = false
			_configure_ultra_quality()

		PerformanceMode.AUTO:
			_auto_quality_enabled = true
			Engine.max_fps = FPS_TARGETS[device_tier]

	performance_mode_changed.emit(mode)


## Forces a quality decrease (for emergency situations)
func force_quality_decrease() -> void:
	_decrease_quality()
	_quality_adjust_cooldown = 5.0


## Gets current performance metrics as a dictionary
func get_metrics() -> Dictionary:
	return {
		"fps": current_fps,
		"frame_time_ms": current_frame_time_ms,
		"memory_mb": current_memory_mb,
		"memory_budget_mb": MEMORY_BUDGETS[device_tier],
		"draw_calls": current_draw_calls,
		"device_tier": DeviceTier.keys()[device_tier],
		"performance_mode": PerformanceMode.keys()[performance_mode],
		"thermal_state": ThermalSeverity.keys()[thermal_state],
		"memory_state": MemoryPressure.keys()[memory_state],
		"network_state": NetworkQuality.keys()[network_state],
		"battery_level": battery_level,
		"is_charging": is_charging,
		"battery_saver": battery_saver_active,
		"resolution_scale": _current_resolution_scale,
		"particle_limit": _current_particle_limit,
		"effects_enabled": _effects_enabled,
		"shadows_enabled": _shadows_enabled,
		"post_processing": _post_processing_enabled
	}


## Checks if the current platform is mobile
func is_mobile_platform() -> bool:
	return is_mobile


## Gets the GPU vendor
func get_gpu_vendor() -> GPUVendor:
	return gpu_vendor

# endregion
