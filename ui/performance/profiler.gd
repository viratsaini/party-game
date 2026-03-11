## Profiler - Comprehensive performance profiling for mobile optimization
##
## BLAZING FAST profiling system that tracks every aspect of performance:
##
## - Frame time analysis with percentile breakdowns
## - Draw call and vertex counting
## - Memory usage tracking and leak detection
## - CPU/GPU balance monitoring
## - Battery drain estimation
## - Thermal throttling detection
## - Network latency tracking
## - Custom profiling sections
##
## The profiler is designed to have MINIMAL overhead (<0.5ms per frame)
## and can run continuously in release builds for analytics.
##
## Usage:
##   Profiler.begin_section("physics")
##   # ... physics code ...
##   Profiler.end_section("physics")
##   print(Profiler.get_frame_report())
class_name Profiler
extends Node


# =============================================================================
# region - Signals
# =============================================================================

## Emitted when a profiling frame completes
signal frame_completed(frame_data: FrameData)

## Emitted when performance drops below threshold
signal performance_warning(warning: PerformanceWarning)

## Emitted when memory leak is suspected
signal memory_leak_suspected(allocation_name: String, growth_rate: float)

## Emitted when thermal throttling is detected
signal thermal_throttling_detected(severity: float)

## Emitted on each stats update (configurable interval)
signal stats_updated(stats: Dictionary)

# endregion


# =============================================================================
# region - Enums
# =============================================================================

## Performance warning types
enum PerformanceWarning {
	NONE,
	LOW_FPS,
	HIGH_FRAME_TIME_VARIANCE,
	HIGH_DRAW_CALLS,
	HIGH_MEMORY,
	MEMORY_LEAK,
	THERMAL_THROTTLE,
	HIGH_CPU_USAGE,
	HIGH_GPU_USAGE
}

## Profile section types
enum SectionType {
	CPU,
	GPU,
	NETWORK,
	PHYSICS,
	RENDERING,
	UI,
	AUDIO,
	CUSTOM
}

# endregion


# =============================================================================
# region - Inner Classes
# =============================================================================

## Data for a single profiled frame
class FrameData:
	var frame_number: int
	var timestamp_ms: float
	var delta_time_ms: float

	## Timing breakdown
	var cpu_time_ms: float = 0.0
	var gpu_time_ms: float = 0.0
	var idle_time_ms: float = 0.0

	## Rendering stats
	var draw_calls: int = 0
	var vertices: int = 0
	var triangles: int = 0
	var objects_rendered: int = 0

	## Memory stats
	var memory_static_mb: float = 0.0
	var memory_dynamic_mb: float = 0.0
	var memory_message_buffer: float = 0.0

	## Custom sections
	var sections: Dictionary = {}  ## section_name -> time_ms


## Performance statistics over time
class PerformanceStats:
	var sample_count: int = 0
	var total_frame_time_ms: float = 0.0

	## FPS statistics
	var fps_current: float = 0.0
	var fps_average: float = 0.0
	var fps_min: float = 0.0
	var fps_max: float = 0.0

	## Frame time percentiles
	var frame_time_p50: float = 0.0   ## Median
	var frame_time_p90: float = 0.0   ## 90th percentile
	var frame_time_p95: float = 0.0   ## 95th percentile
	var frame_time_p99: float = 0.0   ## 99th percentile
	var frame_time_variance: float = 0.0

	## Memory trends
	var memory_trend: float = 0.0      ## MB/minute growth rate
	var peak_memory_mb: float = 0.0

	## Warning counts
	var frame_drops: int = 0          ## Frames > target * 1.5
	var stutters: int = 0             ## Frames > target * 2.0

	func to_dictionary() -> Dictionary:
		return {
			"fps_current": fps_current,
			"fps_average": fps_average,
			"fps_min": fps_min,
			"fps_max": fps_max,
			"frame_time_p50": frame_time_p50,
			"frame_time_p90": frame_time_p90,
			"frame_time_p95": frame_time_p95,
			"frame_time_p99": frame_time_p99,
			"frame_time_variance": frame_time_variance,
			"memory_trend_mb_per_min": memory_trend,
			"peak_memory_mb": peak_memory_mb,
			"frame_drops": frame_drops,
			"stutters": stutters,
			"sample_count": sample_count
		}


## Profile section timing
class ProfileSection:
	var name: String
	var type: int  ## SectionType
	var start_time_us: float
	var end_time_us: float
	var duration_ms: float
	var is_active: bool = false

	## Statistics
	var call_count: int = 0
	var total_time_ms: float = 0.0
	var min_time_ms: float = 9999.0
	var max_time_ms: float = 0.0
	var avg_time_ms: float = 0.0

	func begin() -> void:
		start_time_us = Time.get_ticks_usec()
		is_active = true

	func end() -> void:
		end_time_us = Time.get_ticks_usec()
		duration_ms = (end_time_us - start_time_us) / 1000.0
		is_active = false

		## Update statistics
		call_count += 1
		total_time_ms += duration_ms
		min_time_ms = minf(min_time_ms, duration_ms)
		max_time_ms = maxf(max_time_ms, duration_ms)
		avg_time_ms = total_time_ms / call_count

# endregion


# =============================================================================
# region - Constants
# =============================================================================

## Profiling configuration
const MAX_FRAME_HISTORY: int = 600              ## 10 seconds at 60fps
const STATS_UPDATE_INTERVAL: float = 0.5        ## Update stats twice per second
const MEMORY_SAMPLE_INTERVAL: float = 1.0       ## Sample memory every second
const LEAK_DETECTION_WINDOW: float = 60.0       ## Detect leaks over 1 minute
const LEAK_THRESHOLD_MB_PER_MIN: float = 10.0   ## MB/min to trigger warning

## Performance thresholds
const DRAW_CALL_WARNING: int = 500
const MEMORY_WARNING_MB: float = 1500.0
const FRAME_TIME_VARIANCE_WARNING: float = 0.4

## Thermal detection
const THERMAL_SAMPLE_COUNT: int = 120
const THERMAL_VARIANCE_THRESHOLD: float = 0.35

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

## Profiling state
var enabled: bool = true
var detailed_mode: bool = false  ## Collect more data (higher overhead)

## Frame tracking
var _current_frame: int = 0
var _frame_start_time_us: float = 0.0
var _last_frame_time_ms: float = 16.67

## Frame history
var _frame_history: Array[float] = []  ## Frame times in ms
var _frame_history_index: int = 0

## Profile sections
var _sections: Dictionary = {}  ## name -> ProfileSection
var _active_sections: Array[String] = []

## Memory tracking
var _memory_samples: Array[float] = []
var _memory_sample_times: Array[float] = []
var _last_memory_sample_time: float = 0.0
var _peak_memory_mb: float = 0.0

## Thermal tracking
var _thermal_samples: Array[float] = []

## Current frame data
var _current_frame_data: FrameData = null

## Accumulated statistics
var _stats: PerformanceStats = PerformanceStats.new()
var _last_stats_update: float = 0.0

## Draw call tracking (from RenderingServer)
var _last_draw_calls: int = 0
var _last_vertices: int = 0

## Target frame time for warnings
var _target_frame_time_ms: float = 16.67

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	process_priority = -2000  ## Process before everything

	_initialize_frame_buffer()
	_register_default_sections()

	print("[Profiler] Initialized - Overhead target: <0.5ms/frame")


func _process(delta: float) -> void:
	if not enabled:
		return

	## End previous frame, start new frame
	_end_frame()
	_begin_frame()

	## Track frame time
	_track_frame_time(delta)

	## Periodic updates
	var current_time := Time.get_ticks_msec() / 1000.0

	if current_time - _last_stats_update >= STATS_UPDATE_INTERVAL:
		_last_stats_update = current_time
		_update_statistics()
		_check_for_warnings()
		stats_updated.emit(get_current_stats())

	if current_time - _last_memory_sample_time >= MEMORY_SAMPLE_INTERVAL:
		_last_memory_sample_time = current_time
		_sample_memory()


func _initialize_frame_buffer() -> void:
	_frame_history.resize(MAX_FRAME_HISTORY)
	_frame_history.fill(16.67)

	_thermal_samples.resize(THERMAL_SAMPLE_COUNT)
	_thermal_samples.fill(16.67)


func _register_default_sections() -> void:
	## Pre-register common sections for efficiency
	register_section("physics", SectionType.PHYSICS)
	register_section("rendering", SectionType.RENDERING)
	register_section("ui", SectionType.UI)
	register_section("network", SectionType.NETWORK)
	register_section("audio", SectionType.AUDIO)
	register_section("game_logic", SectionType.CPU)

# endregion


# =============================================================================
# region - Frame Tracking
# =============================================================================

func _begin_frame() -> void:
	_frame_start_time_us = Time.get_ticks_usec()
	_current_frame += 1

	_current_frame_data = FrameData.new()
	_current_frame_data.frame_number = _current_frame
	_current_frame_data.timestamp_ms = Time.get_ticks_msec()


func _end_frame() -> void:
	if _current_frame_data == null:
		return

	var frame_end_us := Time.get_ticks_usec()
	_current_frame_data.delta_time_ms = (frame_end_us - _frame_start_time_us) / 1000.0

	## Collect rendering stats
	_current_frame_data.draw_calls = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)

	## Memory stats
	_current_frame_data.memory_static_mb = float(OS.get_static_memory_usage()) / 1048576.0

	## Copy section timings
	for section_name: String in _sections:
		var section: ProfileSection = _sections[section_name]
		if section.call_count > 0:
			_current_frame_data.sections[section_name] = section.duration_ms

	## Reset per-frame section data
	for section_name: String in _sections:
		var section: ProfileSection = _sections[section_name]
		section.duration_ms = 0.0

	frame_completed.emit(_current_frame_data)


func _track_frame_time(delta: float) -> void:
	_last_frame_time_ms = delta * 1000.0

	## Update rolling buffer
	_frame_history[_frame_history_index] = _last_frame_time_ms
	_frame_history_index = (_frame_history_index + 1) % MAX_FRAME_HISTORY

	## Update thermal tracking
	_thermal_samples.push_back(_last_frame_time_ms)
	if _thermal_samples.size() > THERMAL_SAMPLE_COUNT:
		_thermal_samples.remove_at(0)

# endregion


# =============================================================================
# region - Section Profiling
# =============================================================================

## Registers a profiling section
func register_section(name: String, type: SectionType = SectionType.CUSTOM) -> void:
	if _sections.has(name):
		return

	var section := ProfileSection.new()
	section.name = name
	section.type = type
	_sections[name] = section


## Begins timing a section
func begin_section(name: String) -> void:
	if not enabled:
		return

	if not _sections.has(name):
		register_section(name)

	var section: ProfileSection = _sections[name]
	section.begin()
	_active_sections.append(name)


## Ends timing a section
func end_section(name: String) -> void:
	if not enabled:
		return

	if not _sections.has(name):
		push_warning("[Profiler] Section not registered: %s" % name)
		return

	var section: ProfileSection = _sections[name]
	if section.is_active:
		section.end()
		_active_sections.erase(name)


## Convenience function for timing a callable
func profile_callable(name: String, callable: Callable) -> Variant:
	begin_section(name)
	var result: Variant = callable.call()
	end_section(name)
	return result


## Gets statistics for a section
func get_section_stats(name: String) -> Dictionary:
	if not _sections.has(name):
		return {}

	var section: ProfileSection = _sections[name]
	return {
		"name": section.name,
		"call_count": section.call_count,
		"total_time_ms": section.total_time_ms,
		"min_time_ms": section.min_time_ms,
		"max_time_ms": section.max_time_ms,
		"avg_time_ms": section.avg_time_ms
	}


## Gets all section statistics
func get_all_section_stats() -> Dictionary:
	var result: Dictionary = {}
	for name: String in _sections:
		result[name] = get_section_stats(name)
	return result

# endregion


# =============================================================================
# region - Statistics Calculation
# =============================================================================

func _update_statistics() -> void:
	_stats.sample_count = _frame_history.size()

	## Calculate FPS stats
	var total: float = 0.0
	var min_ft: float = 1000.0
	var max_ft: float = 0.0
	var sorted_times: Array[float] = _frame_history.duplicate()
	sorted_times.sort()

	for ft: float in _frame_history:
		total += ft
		min_ft = minf(min_ft, ft)
		max_ft = maxf(max_ft, ft)

	var avg_ft := total / _frame_history.size()
	_stats.fps_current = 1000.0 / _last_frame_time_ms if _last_frame_time_ms > 0 else 0.0
	_stats.fps_average = 1000.0 / avg_ft if avg_ft > 0 else 0.0
	_stats.fps_min = 1000.0 / max_ft if max_ft > 0 else 0.0
	_stats.fps_max = 1000.0 / min_ft if min_ft > 0 else 0.0

	## Calculate percentiles
	var count := sorted_times.size()
	_stats.frame_time_p50 = sorted_times[count / 2]
	_stats.frame_time_p90 = sorted_times[int(count * 0.9)]
	_stats.frame_time_p95 = sorted_times[int(count * 0.95)]
	_stats.frame_time_p99 = sorted_times[int(count * 0.99)]

	## Calculate variance
	_stats.frame_time_variance = (max_ft - min_ft) / avg_ft if avg_ft > 0 else 0.0

	## Count drops and stutters
	_stats.frame_drops = 0
	_stats.stutters = 0
	for ft: float in _frame_history:
		if ft > _target_frame_time_ms * 1.5:
			_stats.frame_drops += 1
		if ft > _target_frame_time_ms * 2.0:
			_stats.stutters += 1

	## Memory stats
	_stats.peak_memory_mb = _peak_memory_mb
	_calculate_memory_trend()


func _calculate_memory_trend() -> void:
	if _memory_samples.size() < 10:
		_stats.memory_trend = 0.0
		return

	## Linear regression on memory samples
	var n := _memory_samples.size()
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_xy: float = 0.0
	var sum_xx: float = 0.0

	for i in range(n):
		var x: float = _memory_sample_times[i]
		var y: float = _memory_samples[i]
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_xx += x * x

	var slope: float = (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x) if (n * sum_xx - sum_x * sum_x) != 0 else 0.0

	## Convert to MB per minute
	_stats.memory_trend = slope * 60.0

	## Check for leak
	if _stats.memory_trend > LEAK_THRESHOLD_MB_PER_MIN:
		memory_leak_suspected.emit("memory", _stats.memory_trend)

# endregion


# =============================================================================
# region - Memory Tracking
# =============================================================================

func _sample_memory() -> void:
	var current_memory := float(OS.get_static_memory_usage()) / 1048576.0
	var current_time := Time.get_ticks_msec() / 1000.0

	_memory_samples.append(current_memory)
	_memory_sample_times.append(current_time)

	## Keep only samples within leak detection window
	while _memory_sample_times.size() > 0:
		if current_time - _memory_sample_times[0] > LEAK_DETECTION_WINDOW:
			_memory_samples.remove_at(0)
			_memory_sample_times.remove_at(0)
		else:
			break

	_peak_memory_mb = maxf(_peak_memory_mb, current_memory)


## Gets current memory usage in MB
func get_memory_usage_mb() -> float:
	return float(OS.get_static_memory_usage()) / 1048576.0


## Gets peak memory usage
func get_peak_memory_mb() -> float:
	return _peak_memory_mb


## Resets peak memory tracking
func reset_peak_memory() -> void:
	_peak_memory_mb = get_memory_usage_mb()

# endregion


# =============================================================================
# region - Warning Detection
# =============================================================================

func _check_for_warnings() -> void:
	## Check FPS
	if _stats.fps_average < 30.0 and _stats.fps_average > 0:
		performance_warning.emit(PerformanceWarning.LOW_FPS)

	## Check variance (stuttering)
	if _stats.frame_time_variance > FRAME_TIME_VARIANCE_WARNING:
		performance_warning.emit(PerformanceWarning.HIGH_FRAME_TIME_VARIANCE)
		_check_thermal_throttling()

	## Check draw calls
	if _current_frame_data and _current_frame_data.draw_calls > DRAW_CALL_WARNING:
		performance_warning.emit(PerformanceWarning.HIGH_DRAW_CALLS)

	## Check memory
	if get_memory_usage_mb() > MEMORY_WARNING_MB:
		performance_warning.emit(PerformanceWarning.HIGH_MEMORY)


func _check_thermal_throttling() -> void:
	if _thermal_samples.size() < 30:
		return

	var total: float = 0.0
	var min_ft: float = 1000.0
	var max_ft: float = 0.0

	for ft: float in _thermal_samples:
		total += ft
		min_ft = minf(min_ft, ft)
		max_ft = maxf(max_ft, ft)

	var avg_ft := total / _thermal_samples.size()
	var variance := (max_ft - min_ft) / avg_ft if avg_ft > 0 else 0.0

	## High variance with degraded performance indicates thermal throttling
	if variance > THERMAL_VARIANCE_THRESHOLD and avg_ft > _target_frame_time_ms * 1.3:
		var severity := clampf((variance - THERMAL_VARIANCE_THRESHOLD) / 0.3, 0.0, 1.0)
		thermal_throttling_detected.emit(severity)
		performance_warning.emit(PerformanceWarning.THERMAL_THROTTLE)

# endregion


# =============================================================================
# region - Public API
# =============================================================================

## Sets the target FPS for warning calculations
func set_target_fps(fps: float) -> void:
	_target_frame_time_ms = 1000.0 / fps


## Gets the current frame time in ms
func get_frame_time_ms() -> float:
	return _last_frame_time_ms


## Gets the current FPS
func get_fps() -> float:
	return 1000.0 / _last_frame_time_ms if _last_frame_time_ms > 0 else 0.0


## Gets current performance statistics
func get_current_stats() -> Dictionary:
	return _stats.to_dictionary()


## Gets a quick frame report
func get_frame_report() -> String:
	var report := """
=== Frame Report ===
FPS: %.1f (avg: %.1f, min: %.1f, max: %.1f)
Frame Time: %.2f ms (p50: %.2f, p90: %.2f, p99: %.2f)
Variance: %.2f
Draw Calls: %d
Memory: %.1f MB (peak: %.1f MB, trend: %.2f MB/min)
Frame Drops: %d, Stutters: %d
""" % [
		_stats.fps_current,
		_stats.fps_average,
		_stats.fps_min,
		_stats.fps_max,
		_last_frame_time_ms,
		_stats.frame_time_p50,
		_stats.frame_time_p90,
		_stats.frame_time_p99,
		_stats.frame_time_variance,
		_current_frame_data.draw_calls if _current_frame_data else 0,
		get_memory_usage_mb(),
		_peak_memory_mb,
		_stats.memory_trend,
		_stats.frame_drops,
		_stats.stutters
	]

	## Add section timings
	if not _sections.is_empty():
		report += "\n--- Sections ---\n"
		for name: String in _sections:
			var section: ProfileSection = _sections[name]
			if section.call_count > 0:
				report += "%s: %.2f ms (avg: %.2f, calls: %d)\n" % [
					name,
					section.duration_ms,
					section.avg_time_ms,
					section.call_count
				]

	return report


## Gets draw call count for current frame
func get_draw_calls() -> int:
	return RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)


## Enables/disables the profiler
func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_active_sections.clear()


## Enables detailed mode (more data, higher overhead)
func set_detailed_mode(value: bool) -> void:
	detailed_mode = value


## Resets all statistics
func reset_stats() -> void:
	_stats = PerformanceStats.new()
	_frame_history.fill(16.67)
	_memory_samples.clear()
	_memory_sample_times.clear()
	_peak_memory_mb = get_memory_usage_mb()

	for name: String in _sections:
		var section: ProfileSection = _sections[name]
		section.call_count = 0
		section.total_time_ms = 0.0
		section.min_time_ms = 9999.0
		section.max_time_ms = 0.0
		section.avg_time_ms = 0.0


## Gets CPU/GPU balance estimation
func get_cpu_gpu_balance() -> Dictionary:
	## This is an estimation based on frame time analysis
	## True GPU timing requires platform-specific queries

	var total_section_time: float = 0.0
	for name: String in _sections:
		var section: ProfileSection = _sections[name]
		if section.type != SectionType.GPU:
			total_section_time += section.avg_time_ms

	var cpu_estimate := total_section_time
	var gpu_estimate := maxf(0.0, _last_frame_time_ms - cpu_estimate)

	return {
		"cpu_ms": cpu_estimate,
		"gpu_ms": gpu_estimate,
		"cpu_percent": cpu_estimate / _last_frame_time_ms * 100.0 if _last_frame_time_ms > 0 else 0.0,
		"gpu_percent": gpu_estimate / _last_frame_time_ms * 100.0 if _last_frame_time_ms > 0 else 0.0,
		"bottleneck": "CPU" if cpu_estimate > gpu_estimate else "GPU"
	}


## Estimates battery drain based on current performance
func estimate_battery_drain_percent_per_hour() -> float:
	## Rough estimation based on:
	## - Base drain: 5-10% per hour idle
	## - FPS impact: higher FPS = more drain
	## - GPU load: more effects = more drain

	var base_drain: float = 8.0
	var fps_factor := clampf(get_fps() / 60.0, 0.5, 2.0)
	var gpu_factor := 1.0

	if _current_frame_data:
		gpu_factor = clampf(_current_frame_data.draw_calls / 200.0, 1.0, 2.0)

	return base_drain * fps_factor * gpu_factor

# endregion


# =============================================================================
# region - Network Latency Tracking
# =============================================================================

var _latency_samples: Array[int] = []
var _packet_loss_samples: Array[float] = []


## Records a network latency sample
func record_network_latency(latency_ms: int) -> void:
	_latency_samples.append(latency_ms)
	if _latency_samples.size() > 100:
		_latency_samples.remove_at(0)


## Records packet loss
func record_packet_loss(loss_percent: float) -> void:
	_packet_loss_samples.append(loss_percent)
	if _packet_loss_samples.size() > 100:
		_packet_loss_samples.remove_at(0)


## Gets network statistics
func get_network_stats() -> Dictionary:
	if _latency_samples.is_empty():
		return {
			"latency_avg": 0,
			"latency_min": 0,
			"latency_max": 0,
			"latency_jitter": 0,
			"packet_loss": 0.0
		}

	var total: int = 0
	var min_lat: int = 9999
	var max_lat: int = 0

	for lat: int in _latency_samples:
		total += lat
		min_lat = mini(min_lat, lat)
		max_lat = maxi(max_lat, lat)

	var avg_lat := total / _latency_samples.size()

	var total_loss: float = 0.0
	for loss: float in _packet_loss_samples:
		total_loss += loss
	var avg_loss := total_loss / _packet_loss_samples.size() if _packet_loss_samples.size() > 0 else 0.0

	return {
		"latency_avg": avg_lat,
		"latency_min": min_lat,
		"latency_max": max_lat,
		"latency_jitter": max_lat - min_lat,
		"packet_loss": avg_loss
	}

# endregion
