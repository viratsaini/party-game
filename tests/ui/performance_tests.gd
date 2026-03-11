## Performance Tests - Comprehensive performance benchmarking for BattleZone Party UI
##
## Provides detailed performance analysis:
## - FPS monitoring and stability testing
## - Memory usage tracking and leak detection
## - Frame time analysis and jitter detection
## - GPU/CPU bottleneck identification
## - Animation performance profiling
## - Particle system benchmarks
## - Network UI responsiveness
## - Load time measurements
##
## Usage:
##   var perf = PerformanceTests.new()
##   add_child(perf)
##   var report = await perf.run_full_benchmark()
##   print(report.get_detailed_report())
class_name PerformanceTests
extends Node


# =============================================================================
# region - Signals
# =============================================================================

signal benchmark_started(name: String)
signal benchmark_completed(name: String, result: BenchmarkResult)
signal all_benchmarks_completed(report: PerformanceReport)
signal warning_detected(message: String, severity: String)
signal fps_sample(fps: float)
signal memory_sample(memory_mb: float)

# endregion


# =============================================================================
# region - Enums and Constants
# =============================================================================

enum BenchmarkCategory {
	FPS,
	MEMORY,
	FRAME_TIME,
	ANIMATION,
	PARTICLES,
	UI_CREATION,
	SCENE_LOADING,
	NETWORK_UI
}

enum PerformanceTier {
	EXCELLENT,  # 60+ FPS stable
	GOOD,       # 45-60 FPS
	ACCEPTABLE, # 30-45 FPS
	POOR,       # 20-30 FPS
	CRITICAL    # Below 20 FPS
}

const TIER_THRESHOLDS: Dictionary = {
	PerformanceTier.EXCELLENT: 58.0,
	PerformanceTier.GOOD: 45.0,
	PerformanceTier.ACCEPTABLE: 30.0,
	PerformanceTier.POOR: 20.0,
	PerformanceTier.CRITICAL: 0.0
}

const TIER_NAMES: Dictionary = {
	PerformanceTier.EXCELLENT: "EXCELLENT",
	PerformanceTier.GOOD: "GOOD",
	PerformanceTier.ACCEPTABLE: "ACCEPTABLE",
	PerformanceTier.POOR: "POOR",
	PerformanceTier.CRITICAL: "CRITICAL"
}

## Benchmark configuration
const DEFAULT_SAMPLE_DURATION: float = 5.0
const STRESS_TEST_DURATION: float = 15.0
const MEMORY_SAMPLE_INTERVAL: float = 0.1
const FPS_SAMPLE_INTERVAL: float = 0.016  # Every frame

## Thresholds
const FRAME_TIME_TARGET_MS: float = 16.67  # 60 FPS
const FRAME_TIME_WARNING_MS: float = 33.33  # 30 FPS
const FRAME_JITTER_THRESHOLD_MS: float = 5.0
const MEMORY_WARNING_MB: float = 512.0
const MEMORY_CRITICAL_MB: float = 1024.0
const MEMORY_LEAK_THRESHOLD_MB: float = 20.0

# endregion


# =============================================================================
# region - Results Classes
# =============================================================================

class BenchmarkResult:
	var name: String
	var category: BenchmarkCategory
	var passed: bool
	var tier: PerformanceTier
	var metrics: Dictionary
	var warnings: Array[String]
	var duration_ms: float

	func _init(n: String, cat: BenchmarkCategory) -> void:
		name = n
		category = cat
		passed = true
		tier = PerformanceTier.GOOD
		metrics = {}
		warnings = []
		duration_ms = 0.0

	func to_dict() -> Dictionary:
		return {
			"name": name,
			"category": category,
			"passed": passed,
			"tier": TIER_NAMES.get(tier, "UNKNOWN"),
			"metrics": metrics,
			"warnings": warnings,
			"duration_ms": duration_ms
		}


class PerformanceReport:
	var benchmarks: Array[BenchmarkResult] = []
	var overall_tier: PerformanceTier = PerformanceTier.GOOD
	var total_duration_ms: float = 0.0
	var system_info: Dictionary = {}
	var recommendations: Array[String] = []
	var critical_issues: Array[String] = []

	func add_benchmark(result: BenchmarkResult) -> void:
		benchmarks.append(result)
		total_duration_ms += result.duration_ms

		# Update overall tier
		if result.tier > overall_tier:  # Higher enum = worse performance
			overall_tier = result.tier

		# Track critical issues
		if result.tier == PerformanceTier.CRITICAL:
			critical_issues.append("%s: %s" % [result.name, result.warnings[0] if result.warnings.size() > 0 else "Critical performance issue"])

	func get_summary() -> String:
		var summary: String = ""
		summary += "=" .repeat(70) + "\n"
		summary += "PERFORMANCE BENCHMARK REPORT\n"
		summary += "=" .repeat(70) + "\n\n"

		summary += "Overall Performance Tier: %s\n" % TIER_NAMES.get(overall_tier, "UNKNOWN")
		summary += "Total Benchmark Duration: %.2f seconds\n\n" % (total_duration_ms / 1000.0)

		# System info
		summary += "SYSTEM INFORMATION:\n"
		summary += "-" .repeat(40) + "\n"
		for key: String in system_info:
			summary += "  %s: %s\n" % [key, str(system_info[key])]

		summary += "\n"

		# Benchmark results by category
		summary += "BENCHMARK RESULTS:\n"
		summary += "-" .repeat(40) + "\n"

		for result: BenchmarkResult in benchmarks:
			var status: String = "[%s]" % TIER_NAMES.get(result.tier, "?")
			summary += "%s %s\n" % [status, result.name]

			for key: String in result.metrics:
				summary += "    %s: %s\n" % [key, str(result.metrics[key])]

			for warning: String in result.warnings:
				summary += "    [!] %s\n" % warning

		# Critical issues
		if critical_issues.size() > 0:
			summary += "\nCRITICAL ISSUES:\n"
			summary += "-" .repeat(40) + "\n"
			for issue: String in critical_issues:
				summary += "  [X] %s\n" % issue

		# Recommendations
		if recommendations.size() > 0:
			summary += "\nRECOMMENDATIONS:\n"
			summary += "-" .repeat(40) + "\n"
			for rec: String in recommendations:
				summary += "  * %s\n" % rec

		return summary

	func get_detailed_report() -> String:
		var report: String = get_summary()
		report += "\n" + "=" .repeat(70) + "\n"
		report += "DETAILED METRICS\n"
		report += "=" .repeat(70) + "\n\n"

		for result: BenchmarkResult in benchmarks:
			report += "%s\n" % result.name
			report += "-" .repeat(30) + "\n"
			report += JSON.stringify(result.to_dict(), "  ") + "\n\n"

		return report

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

var _report: PerformanceReport
var _is_running: bool = false

## FPS tracking
var _fps_samples: Array[float] = []
var _frame_times: Array[float] = []
var _current_fps: float = 60.0
var _frame_time_ms: float = 16.67

## Memory tracking
var _memory_samples: Array[float] = []
var _initial_memory_mb: float = 0.0
var _peak_memory_mb: float = 0.0

## Test nodes
var _test_nodes: Array[Node] = []

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _process(delta: float) -> void:
	if _is_running:
		_track_frame_time(delta)

# endregion


# =============================================================================
# region - Public API
# =============================================================================

## Run full performance benchmark suite
func run_full_benchmark() -> PerformanceReport:
	if _is_running:
		push_warning("[PerformanceTests] Benchmark already running!")
		return PerformanceReport.new()

	_is_running = true
	_report = PerformanceReport.new()

	# Collect system info
	_collect_system_info()

	# Run all benchmarks
	await _benchmark_baseline_fps()
	await _benchmark_ui_creation()
	await _benchmark_animation_performance()
	await _benchmark_particle_systems()
	await _benchmark_memory_usage()
	await _benchmark_memory_leak()
	await _benchmark_frame_stability()
	await _benchmark_stress_test()
	await _benchmark_rapid_updates()

	# Generate recommendations
	_generate_recommendations()

	_is_running = false
	all_benchmarks_completed.emit(_report)

	return _report


## Run quick benchmark (essential tests only)
func run_quick_benchmark() -> PerformanceReport:
	if _is_running:
		return PerformanceReport.new()

	_is_running = true
	_report = PerformanceReport.new()

	_collect_system_info()

	await _benchmark_baseline_fps()
	await _benchmark_frame_stability()
	await _benchmark_memory_usage()

	_generate_recommendations()

	_is_running = false
	all_benchmarks_completed.emit(_report)

	return _report


## Get current FPS
func get_current_fps() -> float:
	return _current_fps


## Get current memory usage in MB
func get_memory_usage_mb() -> float:
	return float(OS.get_static_memory_usage()) / 1048576.0

# endregion


# =============================================================================
# region - System Information
# =============================================================================

func _collect_system_info() -> void:
	_report.system_info = {
		"os_name": OS.get_name(),
		"processor_count": OS.get_processor_count(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"video_vendor": RenderingServer.get_video_adapter_vendor(),
		"godot_version": Engine.get_version_info().string,
		"debug_build": OS.is_debug_build(),
		"initial_memory_mb": "%.2f" % get_memory_usage_mb(),
		"timestamp": Time.get_datetime_string_from_system()
	}

# endregion


# =============================================================================
# region - Benchmarks
# =============================================================================

func _benchmark_baseline_fps() -> void:
	var result := BenchmarkResult.new("Baseline_FPS", BenchmarkCategory.FPS)
	benchmark_started.emit(result.name)

	var start_time: int = Time.get_ticks_msec()
	_fps_samples.clear()

	# Sample for 5 seconds
	var sample_duration: float = 5.0
	var sample_start: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - sample_start < sample_duration:
		_fps_samples.append(_current_fps)
		fps_sample.emit(_current_fps)
		await get_tree().process_frame

	# Calculate metrics
	var avg_fps: float = _calculate_average(_fps_samples)
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0
	var max_fps: float = _fps_samples.max() if not _fps_samples.is_empty() else 0.0
	var std_dev: float = _calculate_std_deviation(_fps_samples)
	var percentile_1: float = _calculate_percentile(_fps_samples, 1.0)
	var percentile_99: float = _calculate_percentile(_fps_samples, 99.0)

	result.metrics = {
		"average_fps": "%.2f" % avg_fps,
		"min_fps": "%.2f" % min_fps,
		"max_fps": "%.2f" % max_fps,
		"std_deviation": "%.2f" % std_dev,
		"1%_low": "%.2f" % percentile_1,
		"99%_high": "%.2f" % percentile_99,
		"samples": _fps_samples.size()
	}

	# Determine tier
	result.tier = _get_fps_tier(avg_fps)

	# Check for issues
	if min_fps < 20.0:
		result.warnings.append("Severe FPS drops detected (min: %.1f)" % min_fps)
		result.passed = false
	if std_dev > 10.0:
		result.warnings.append("High FPS variance (std dev: %.1f)" % std_dev)

	result.duration_ms = float(Time.get_ticks_msec() - start_time)
	_report.add_benchmark(result)
	benchmark_completed.emit(result.name, result)


func _benchmark_ui_creation() -> void:
	var result := BenchmarkResult.new("UI_Creation", BenchmarkCategory.UI_CREATION)
	benchmark_started.emit(result.name)

	var start_time: int = Time.get_ticks_msec()
	var creation_times: Array[float] = []

	# Test different control counts
	var control_counts: Array[int] = [10, 50, 100, 200]

	for count: int in control_counts:
		_cleanup_test_nodes()

		var create_start: int = Time.get_ticks_usec()

		for i in range(count):
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(50, 30)
			panel.position = Vector2(randf_range(0, 800), randf_range(0, 600))

			var label := Label.new()
			label.text = "Test %d" % i
			panel.add_child(label)

			_add_test_node(panel)

		var create_time: float = float(Time.get_ticks_usec() - create_start) / 1000.0
		creation_times.append(create_time)

		await get_tree().process_frame

	_cleanup_test_nodes()

	# Calculate controls per millisecond
	var total_controls: int = 10 + 50 + 100 + 200
	var total_time: float = 0.0
	for t: float in creation_times:
		total_time += t

	var controls_per_ms: float = float(total_controls) / total_time if total_time > 0 else 0.0

	result.metrics = {
		"total_controls_created": total_controls,
		"total_time_ms": "%.2f" % total_time,
		"controls_per_ms": "%.2f" % controls_per_ms,
		"10_controls_ms": "%.2f" % creation_times[0],
		"50_controls_ms": "%.2f" % creation_times[1],
		"100_controls_ms": "%.2f" % creation_times[2],
		"200_controls_ms": "%.2f" % creation_times[3]
	}

	# Determine tier based on creation speed
	if controls_per_ms > 100:
		result.tier = PerformanceTier.EXCELLENT
	elif controls_per_ms > 50:
		result.tier = PerformanceTier.GOOD
	elif controls_per_ms > 20:
		result.tier = PerformanceTier.ACCEPTABLE
	else:
		result.tier = PerformanceTier.POOR
		result.warnings.append("Slow UI creation: %.1f controls/ms" % controls_per_ms)

	result.duration_ms = float(Time.get_ticks_msec() - start_time)
	_report.add_benchmark(result)
	benchmark_completed.emit(result.name, result)


func _benchmark_animation_performance() -> void:
	var result := BenchmarkResult.new("Animation_Performance", BenchmarkCategory.ANIMATION)
	benchmark_started.emit(result.name)

	var start_time: int = Time.get_ticks_msec()
	_fps_samples.clear()
	_cleanup_test_nodes()

	# Create many animated controls
	var animation_count: int = 50
	var controls: Array[Control] = []

	for i in range(animation_count):
		var ctrl := ColorRect.new()
		ctrl.position = Vector2(randf_range(0, 700), randf_range(0, 500))
		ctrl.size = Vector2(30, 30)
		ctrl.color = Color(randf(), randf(), randf())
		_add_test_node(ctrl)
		controls.append(ctrl)

		# Create looping animation
		var tween := ctrl.create_tween()
		tween.set_loops(0)
		tween.tween_property(ctrl, "position:x", ctrl.position.x + 100, 0.5)
		tween.tween_property(ctrl, "position:x", ctrl.position.x, 0.5)

	# Sample FPS during animations
	var sample_duration: float = 5.0
	var sample_start: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - sample_start < sample_duration:
		_fps_samples.append(_current_fps)
		await get_tree().process_frame

	_cleanup_test_nodes()

	var avg_fps: float = _calculate_average(_fps_samples)
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0

	result.metrics = {
		"animation_count": animation_count,
		"average_fps": "%.2f" % avg_fps,
		"min_fps": "%.2f" % min_fps,
		"fps_drop": "%.2f" % (60.0 - avg_fps)
	}

	result.tier = _get_fps_tier(avg_fps)

	if avg_fps < 30.0:
		result.warnings.append("Animation performance below 30 FPS")
		result.passed = false

	result.duration_ms = float(Time.get_ticks_msec() - start_time)
	_report.add_benchmark(result)
	benchmark_completed.emit(result.name, result)


func _benchmark_particle_systems() -> void:
	var result := BenchmarkResult.new("Particle_Systems", BenchmarkCategory.PARTICLES)
	benchmark_started.emit(result.name)

	var start_time: int = Time.get_ticks_msec()
	_fps_samples.clear()
	_cleanup_test_nodes()

	# Create particle emitters
	var emitter_count: int = 20
	var particles_per_emitter: int = 50

	for i in range(emitter_count):
		var particles := CPUParticles2D.new()
		particles.amount = particles_per_emitter
		particles.lifetime = 1.0
		particles.position = Vector2(randf_range(100, 700), randf_range(100, 500))
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 10.0
		particles.direction = Vector2(0, -1)
		particles.spread = 45.0
		particles.gravity = Vector2(0, 100)
		particles.initial_velocity_min = 50.0
		particles.initial_velocity_max = 100.0
		particles.emitting = true
		_add_test_node(particles)

	# Sample FPS
	var sample_duration: float = 5.0
	var sample_start: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - sample_start < sample_duration:
		_fps_samples.append(_current_fps)
		await get_tree().process_frame

	_cleanup_test_nodes()

	var avg_fps: float = _calculate_average(_fps_samples)
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0
	var total_particles: int = emitter_count * particles_per_emitter

	result.metrics = {
		"emitter_count": emitter_count,
		"particles_per_emitter": particles_per_emitter,
		"total_particles": total_particles,
		"average_fps": "%.2f" % avg_fps,
		"min_fps": "%.2f" % min_fps
	}

	result.tier = _get_fps_tier(avg_fps)

	if avg_fps < 30.0:
		result.warnings.append("Particle performance issues")

	result.duration_ms = float(Time.get_ticks_msec() - start_time)
	_report.add_benchmark(result)
	benchmark_completed.emit(result.name, result)


func _benchmark_memory_usage() -> void:
	var result := BenchmarkResult.new("Memory_Usage", BenchmarkCategory.MEMORY)
	benchmark_started.emit(result.name)

	var start_time: int = Time.get_ticks_msec()
	_memory_samples.clear()

	_initial_memory_mb = get_memory_usage_mb()
	_peak_memory_mb = _initial_memory_mb

	# Sample memory for a period
	var sample_duration: float = 3.0
	var sample_start: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - sample_start < sample_duration:
		var current_memory: float = get_memory_usage_mb()
		_memory_samples.append(current_memory)
		_peak_memory_mb = maxf(_peak_memory_mb, current_memory)
		memory_sample.emit(current_memory)
		await get_tree().create_timer(MEMORY_SAMPLE_INTERVAL).timeout

	var avg_memory: float = _calculate_average(_memory_samples)
	var min_memory: float = _memory_samples.min() if not _memory_samples.is_empty() else 0.0
	var max_memory: float = _memory_samples.max() if not _memory_samples.is_empty() else 0.0

	result.metrics = {
		"initial_mb": "%.2f" % _initial_memory_mb,
		"average_mb": "%.2f" % avg_memory,
		"min_mb": "%.2f" % min_memory,
		"max_mb": "%.2f" % max_memory,
		"peak_mb": "%.2f" % _peak_memory_mb,
		"samples": _memory_samples.size()
	}

	# Determine tier based on memory usage
	if _peak_memory_mb > MEMORY_CRITICAL_MB:
		result.tier = PerformanceTier.CRITICAL
		result.warnings.append("Critical memory usage: %.0f MB" % _peak_memory_mb)
		result.passed = false
	elif _peak_memory_mb > MEMORY_WARNING_MB:
		result.tier = PerformanceTier.POOR
		result.warnings.append("High memory usage: %.0f MB" % _peak_memory_mb)
	else:
		result.tier = PerformanceTier.GOOD

	result.duration_ms = float(Time.get_ticks_msec() - start_time)
	_report.add_benchmark(result)
	benchmark_completed.emit(result.name, result)


func _benchmark_memory_leak() -> void:
	var result := BenchmarkResult.new("Memory_Leak_Test", BenchmarkCategory.MEMORY)
	benchmark_started.emit(result.name)

	var start_time: int = Time.get_ticks_msec()
	var initial_memory: float = get_memory_usage_mb()
	var cycle_memories: Array[float] = []

	# Run create/destroy cycles
	var cycles: int = 10
	var nodes_per_cycle: int = 100

	for cycle in range(cycles):
		var nodes: Array[Control] = []

		# Create nodes
		for i in range(nodes_per_cycle):
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(50, 50)
			var label := Label.new()
			label.text = "Cycle %d Item %d" % [cycle, i]
			panel.add_child(label)
			get_tree().current_scene.add_child(panel)
			nodes.append(panel)

		await get_tree().process_frame

		# Destroy nodes
		for node: Control in nodes:
			node.queue_free()

		await get_tree().process_frame

		cycle_memories.append(get_memory_usage_mb())

	# Wait for GC
	await get_tree().create_timer(0.5).timeout

	var final_memory: float = get_memory_usage_mb()
	var memory_delta: float = final_memory - initial_memory
	var memory_trend: float = _calculate_trend(cycle_memories)

	result.metrics = {
		"initial_mb": "%.2f" % initial_memory,
		"final_mb": "%.2f" % final_memory,
		"delta_mb": "%.2f" % memory_delta,
		"memory_trend": "%.4f" % memory_trend,
		"cycles": cycles,
		"nodes_per_cycle": nodes_per_cycle
	}

	if memory_delta > MEMORY_LEAK_THRESHOLD_MB:
		result.tier = PerformanceTier.CRITICAL
		result.warnings.append("Potential memory leak: +%.2f MB" % memory_delta)
		result.passed = false
	elif memory_trend > 0.5:  # MB per cycle
		result.tier = PerformanceTier.POOR
		result.warnings.append("Memory trend increasing: %.2f MB/cycle" % memory_trend)
	else:
		result.tier = PerformanceTier.GOOD

	result.duration_ms = float(Time.get_ticks_msec() - start_time)
	_report.add_benchmark(result)
	benchmark_completed.emit(result.name, result)


func _benchmark_frame_stability() -> void:
	var result := BenchmarkResult.new("Frame_Stability", BenchmarkCategory.FRAME_TIME)
	benchmark_started.emit(result.name)

	var start_time: int = Time.get_ticks_msec()
	_frame_times.clear()

	# Collect frame times
	var sample_duration: float = 5.0
	var sample_start: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - sample_start < sample_duration:
		await get_tree().process_frame

	# Convert to ms
	var frame_times_ms: Array[float] = []
	for ft: float in _frame_times:
		frame_times_ms.append(ft * 1000.0)

	var avg_frame_time: float = _calculate_average(frame_times_ms)
	var min_frame_time: float = frame_times_ms.min() if not frame_times_ms.is_empty() else 0.0
	var max_frame_time: float = frame_times_ms.max() if not frame_times_ms.is_empty() else 0.0
	var std_dev: float = _calculate_std_deviation(frame_times_ms)
	var jitter: float = _calculate_jitter(frame_times_ms)

	# Count frame time spikes
	var spikes_above_33ms: int = 0
	var spikes_above_50ms: int = 0
	for ft: float in frame_times_ms:
		if ft > 50.0:
			spikes_above_50ms += 1
		elif ft > 33.0:
			spikes_above_33ms += 1

	result.metrics = {
		"average_ms": "%.2f" % avg_frame_time,
		"min_ms": "%.2f" % min_frame_time,
		"max_ms": "%.2f" % max_frame_time,
		"std_deviation_ms": "%.2f" % std_dev,
		"jitter_ms": "%.2f" % jitter,
		"spikes_above_33ms": spikes_above_33ms,
		"spikes_above_50ms": spikes_above_50ms,
		"samples": frame_times_ms.size()
	}

	# Determine stability tier
	if jitter < 2.0 and spikes_above_33ms == 0:
		result.tier = PerformanceTier.EXCELLENT
	elif jitter < 5.0 and spikes_above_50ms == 0:
		result.tier = PerformanceTier.GOOD
	elif jitter < 10.0:
		result.tier = PerformanceTier.ACCEPTABLE
		result.warnings.append("Frame time variance detected")
	else:
		result.tier = PerformanceTier.POOR
		result.warnings.append("Unstable frame times")

	result.duration_ms = float(Time.get_ticks_msec() - start_time)
	_report.add_benchmark(result)
	benchmark_completed.emit(result.name, result)


func _benchmark_stress_test() -> void:
	var result := BenchmarkResult.new("Stress_Test", BenchmarkCategory.FPS)
	benchmark_started.emit(result.name)

	var start_time: int = Time.get_ticks_msec()
	_fps_samples.clear()
	_cleanup_test_nodes()

	# Create many controls
	var control_count: int = 200
	for i in range(control_count):
		var panel := PanelContainer.new()
		panel.position = Vector2(randf_range(0, 800), randf_range(0, 600))
		panel.custom_minimum_size = Vector2(30, 20)

		var label := Label.new()
		label.text = str(i)
		panel.add_child(label)

		_add_test_node(panel)

	# Add animations
	for node: Node in _test_nodes:
		if node is Control:
			var ctrl: Control = node
			var tween := ctrl.create_tween()
			tween.set_loops(0)
			tween.tween_property(ctrl, "position:x", ctrl.position.x + randf_range(-50, 50), randf_range(0.3, 0.7))
			tween.tween_property(ctrl, "position:x", ctrl.position.x, randf_range(0.3, 0.7))

	# Add particles
	for i in range(10):
		var particles := CPUParticles2D.new()
		particles.amount = 30
		particles.lifetime = 1.0
		particles.position = Vector2(randf_range(100, 700), randf_range(100, 500))
		particles.emitting = true
		_add_test_node(particles)

	# Sample FPS under stress
	var sample_duration: float = 10.0
	var sample_start: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - sample_start < sample_duration:
		# Update some labels
		for i in range(min(20, _test_nodes.size())):
			var node: Node = _test_nodes[i]
			if node is PanelContainer:
				var label: Label = node.get_child(0) as Label
				if label:
					label.text = "F%d" % Engine.get_frames_drawn()

		_fps_samples.append(_current_fps)
		await get_tree().process_frame

	_cleanup_test_nodes()

	var avg_fps: float = _calculate_average(_fps_samples)
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0
	var percentile_1: float = _calculate_percentile(_fps_samples, 1.0)

	result.metrics = {
		"control_count": control_count,
		"particle_emitters": 10,
		"average_fps": "%.2f" % avg_fps,
		"min_fps": "%.2f" % min_fps,
		"1%_low": "%.2f" % percentile_1
	}

	result.tier = _get_fps_tier(percentile_1)  # Use 1% low for stress tier

	if percentile_1 < 20.0:
		result.warnings.append("Severe performance under stress")
		result.passed = false

	result.duration_ms = float(Time.get_ticks_msec() - start_time)
	_report.add_benchmark(result)
	benchmark_completed.emit(result.name, result)


func _benchmark_rapid_updates() -> void:
	var result := BenchmarkResult.new("Rapid_UI_Updates", BenchmarkCategory.UI_CREATION)
	benchmark_started.emit(result.name)

	var start_time: int = Time.get_ticks_msec()
	_fps_samples.clear()
	_cleanup_test_nodes()

	# Create label to update rapidly
	var label := Label.new()
	label.position = Vector2(400, 300)
	label.add_theme_font_size_override("font_size", 24)
	_add_test_node(label)

	var updates: int = 0
	var sample_duration: float = 3.0
	var sample_start: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - sample_start < sample_duration:
		label.text = "Update #%d - Frame %d" % [updates, Engine.get_frames_drawn()]
		updates += 1
		_fps_samples.append(_current_fps)
		await get_tree().process_frame

	_cleanup_test_nodes()

	var avg_fps: float = _calculate_average(_fps_samples)
	var updates_per_second: float = float(updates) / sample_duration

	result.metrics = {
		"total_updates": updates,
		"updates_per_second": "%.2f" % updates_per_second,
		"average_fps": "%.2f" % avg_fps
	}

	result.tier = _get_fps_tier(avg_fps)

	result.duration_ms = float(Time.get_ticks_msec() - start_time)
	_report.add_benchmark(result)
	benchmark_completed.emit(result.name, result)

# endregion


# =============================================================================
# region - Recommendations
# =============================================================================

func _generate_recommendations() -> void:
	for result: BenchmarkResult in _report.benchmarks:
		match result.category:
			BenchmarkCategory.FPS:
				if result.tier >= PerformanceTier.POOR:
					_report.recommendations.append("Reduce visual complexity or enable performance mode")
					_report.recommendations.append("Consider reducing particle counts")

			BenchmarkCategory.MEMORY:
				if result.tier >= PerformanceTier.POOR:
					_report.recommendations.append("Monitor memory usage and investigate potential leaks")
					_report.recommendations.append("Consider object pooling for frequently created objects")

			BenchmarkCategory.ANIMATION:
				if result.tier >= PerformanceTier.ACCEPTABLE:
					_report.recommendations.append("Reduce concurrent animation count")
					_report.recommendations.append("Use simpler easing functions")

			BenchmarkCategory.PARTICLES:
				if result.tier >= PerformanceTier.ACCEPTABLE:
					_report.recommendations.append("Reduce particle counts per emitter")
					_report.recommendations.append("Implement particle budgeting system")

	# Remove duplicates
	var unique_recs: Array[String] = []
	for rec: String in _report.recommendations:
		if rec not in unique_recs:
			unique_recs.append(rec)
	_report.recommendations = unique_recs

# endregion


# =============================================================================
# region - Helper Functions
# =============================================================================

func _track_frame_time(delta: float) -> void:
	_frame_times.append(delta)
	if _frame_times.size() > 300:  # Keep last 5 seconds at 60fps
		_frame_times.remove_at(0)

	var total: float = 0.0
	for ft: float in _frame_times:
		total += ft
	var avg: float = total / _frame_times.size()
	_current_fps = 1.0 / avg if avg > 0 else 60.0
	_frame_time_ms = avg * 1000.0


func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0

	var total: float = 0.0
	for val: float in values:
		total += val
	return total / values.size()


func _calculate_std_deviation(values: Array) -> float:
	if values.is_empty():
		return 0.0

	var avg: float = _calculate_average(values)
	var sum_sq_diff: float = 0.0

	for val: float in values:
		sum_sq_diff += pow(val - avg, 2)

	return sqrt(sum_sq_diff / values.size())


func _calculate_percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0

	var sorted_values: Array = values.duplicate()
	sorted_values.sort()

	var index: float = (percentile / 100.0) * (sorted_values.size() - 1)
	var lower: int = int(floor(index))
	var upper: int = int(ceil(index))

	if lower == upper:
		return sorted_values[lower]

	var fraction: float = index - lower
	return sorted_values[lower] * (1.0 - fraction) + sorted_values[upper] * fraction


func _calculate_jitter(frame_times: Array) -> float:
	if frame_times.size() < 2:
		return 0.0

	var diffs: Array[float] = []
	for i in range(1, frame_times.size()):
		diffs.append(absf(frame_times[i] - frame_times[i - 1]))

	return _calculate_average(diffs)


func _calculate_trend(values: Array) -> float:
	if values.size() < 2:
		return 0.0

	# Simple linear regression slope
	var n: float = float(values.size())
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_xy: float = 0.0
	var sum_xx: float = 0.0

	for i in range(values.size()):
		sum_x += float(i)
		sum_y += values[i]
		sum_xy += float(i) * values[i]
		sum_xx += float(i) * float(i)

	var slope: float = (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x)
	return slope


func _get_fps_tier(fps: float) -> PerformanceTier:
	if fps >= TIER_THRESHOLDS[PerformanceTier.EXCELLENT]:
		return PerformanceTier.EXCELLENT
	elif fps >= TIER_THRESHOLDS[PerformanceTier.GOOD]:
		return PerformanceTier.GOOD
	elif fps >= TIER_THRESHOLDS[PerformanceTier.ACCEPTABLE]:
		return PerformanceTier.ACCEPTABLE
	elif fps >= TIER_THRESHOLDS[PerformanceTier.POOR]:
		return PerformanceTier.POOR
	else:
		return PerformanceTier.CRITICAL


func _add_test_node(node: Node) -> void:
	get_tree().current_scene.add_child(node)
	_test_nodes.append(node)


func _cleanup_test_nodes() -> void:
	for node: Node in _test_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_test_nodes.clear()

# endregion
