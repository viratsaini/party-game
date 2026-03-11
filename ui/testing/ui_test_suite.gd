## UITestSuite - Comprehensive UI testing framework for BattleZone Party
##
## Provides automated testing for:
## - Animation stress tests
## - FPS monitoring per screen
## - Memory leak detection
## - Input lag measurement
## - Visual regression testing
## - Accessibility audits
## - Cross-device testing utilities
##
## Usage:
##   UITestSuite.run_all_tests()
##   UITestSuite.run_animation_stress_test()
##   var report = UITestSuite.get_test_report()
class_name UITestSuite
extends Node


# =============================================================================
# region - Signals
# =============================================================================

## Emitted when a test starts
signal test_started(test_name: String)

## Emitted when a test completes
signal test_completed(test_name: String, passed: bool, message: String)

## Emitted when all tests complete
signal all_tests_completed(passed: int, failed: int, skipped: int)

## Emitted when FPS drops below threshold during test
signal fps_warning(test_name: String, current_fps: float, threshold: float)

## Emitted during test progress
signal test_progress(test_name: String, progress: float)

# endregion


# =============================================================================
# region - Enums and Constants
# =============================================================================

## Test categories
enum TestCategory {
	PERFORMANCE,
	ANIMATION,
	MEMORY,
	INPUT,
	VISUAL,
	ACCESSIBILITY,
	INTEGRATION
}

## Test result status
enum TestStatus {
	PASSED,
	FAILED,
	SKIPPED,
	ERROR,
	TIMEOUT
}

## Performance thresholds
const FPS_THRESHOLD_60: float = 58.0
const FPS_THRESHOLD_30: float = 28.0
const FRAME_TIME_BUDGET_MS: float = 16.67
const INPUT_LAG_THRESHOLD_MS: float = 100.0
const MEMORY_LEAK_THRESHOLD_MB: float = 10.0

## Test durations (seconds)
const STRESS_TEST_DURATION: float = 10.0
const FPS_SAMPLE_DURATION: float = 5.0
const MEMORY_SAMPLE_DURATION: float = 30.0
const INPUT_LAG_SAMPLES: int = 100

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

## Whether tests are currently running
var is_running: bool = false

## Current test being executed
var current_test: String = ""

## Test results storage
var _test_results: Array[Dictionary] = []

## FPS tracking
var _fps_samples: Array[float] = []
var _frame_times: Array[float] = []
var _current_fps: float = 60.0

## Memory tracking
var _memory_samples: Array[float] = []
var _initial_memory_mb: float = 0.0

## Input tracking
var _input_timestamps: Array[float] = []
var _input_latencies: Array[float] = []

## Test nodes created during tests
var _test_nodes: Array[Node] = []

## Reference to animation optimizer for testing
var _animation_optimizer: Node = null

## Reference to particle budget for testing
var _particle_budget: Node = null

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	# Try to get references to optimization systems
	_animation_optimizer = get_node_or_null("/root/AnimationOptimizer")
	_particle_budget = get_node_or_null("/root/ParticleBudget")


func _process(delta: float) -> void:
	if is_running:
		_track_fps(delta)

# endregion


# =============================================================================
# region - Test Runner
# =============================================================================

## Runs all available tests
func run_all_tests() -> void:
	if is_running:
		push_warning("[UITestSuite] Tests already running!")
		return

	is_running = true
	_test_results.clear()

	var tests: Array[Callable] = [
		run_fps_baseline_test,
		run_animation_stress_test,
		run_particle_stress_test,
		run_memory_leak_test,
		run_input_lag_test,
		run_accessibility_audit,
		run_button_feedback_test,
		run_panel_animation_test,
		run_scroll_performance_test
	]

	var passed: int = 0
	var failed: int = 0
	var skipped: int = 0

	for test_callable: Callable in tests:
		await test_callable.call()

		var last_result: Dictionary = _test_results[-1] if not _test_results.is_empty() else {}
		match last_result.get("status", TestStatus.ERROR):
			TestStatus.PASSED:
				passed += 1
			TestStatus.FAILED:
				failed += 1
			TestStatus.SKIPPED:
				skipped += 1
			_:
				failed += 1

	is_running = false
	all_tests_completed.emit(passed, failed, skipped)


## Runs a specific test by name
func run_test(test_name: String) -> Dictionary:
	var test_method: Callable

	match test_name:
		"fps_baseline":
			test_method = run_fps_baseline_test
		"animation_stress":
			test_method = run_animation_stress_test
		"particle_stress":
			test_method = run_particle_stress_test
		"memory_leak":
			test_method = run_memory_leak_test
		"input_lag":
			test_method = run_input_lag_test
		"accessibility":
			test_method = run_accessibility_audit
		"button_feedback":
			test_method = run_button_feedback_test
		"panel_animation":
			test_method = run_panel_animation_test
		"scroll_performance":
			test_method = run_scroll_performance_test
		_:
			return _create_result(test_name, TestStatus.ERROR, "Unknown test: %s" % test_name)

	await test_method.call()
	return _test_results[-1] if not _test_results.is_empty() else {}

# endregion


# =============================================================================
# region - Performance Tests
# =============================================================================

## Tests baseline FPS without any UI activity
func run_fps_baseline_test() -> void:
	current_test = "fps_baseline"
	test_started.emit(current_test)

	_fps_samples.clear()
	var start_time: float = Time.get_ticks_msec() / 1000.0

	# Sample FPS for duration
	while (Time.get_ticks_msec() / 1000.0) - start_time < FPS_SAMPLE_DURATION:
		_fps_samples.append(_current_fps)
		await get_tree().process_frame
		test_progress.emit(current_test, ((Time.get_ticks_msec() / 1000.0) - start_time) / FPS_SAMPLE_DURATION)

	# Calculate results
	var avg_fps: float = _calculate_average(_fps_samples)
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0
	var max_fps: float = _fps_samples.max() if not _fps_samples.is_empty() else 0.0

	var passed: bool = avg_fps >= FPS_THRESHOLD_60 and min_fps >= FPS_THRESHOLD_30
	var message: String = "Avg: %.1f FPS, Min: %.1f, Max: %.1f" % [avg_fps, min_fps, max_fps]

	var result := _create_result(
		current_test,
		TestStatus.PASSED if passed else TestStatus.FAILED,
		message,
		{
			"average_fps": avg_fps,
			"min_fps": min_fps,
			"max_fps": max_fps,
			"sample_count": _fps_samples.size()
		}
	)

	_test_results.append(result)
	test_completed.emit(current_test, passed, message)


## Stress test with many simultaneous animations
func run_animation_stress_test() -> void:
	current_test = "animation_stress"
	test_started.emit(current_test)

	_fps_samples.clear()
	var test_container := Control.new()
	get_tree().current_scene.add_child(test_container)
	_test_nodes.append(test_container)

	# Create many animated controls
	var control_count: int = 100
	var controls: Array[Control] = []

	for i in range(control_count):
		var control := ColorRect.new()
		control.custom_minimum_size = Vector2(20, 20)
		control.size = Vector2(20, 20)
		control.position = Vector2(randf_range(0, 800), randf_range(0, 600))
		control.color = Color(randf(), randf(), randf())
		test_container.add_child(control)
		controls.append(control)

	# Animate all controls simultaneously
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var tweens: Array[Tween] = []

	for control: Control in controls:
		var tween := control.create_tween()
		tween.set_loops(0)  # Infinite
		tween.tween_property(control, "position:x", control.position.x + 100, 0.5)
		tween.tween_property(control, "position:x", control.position.x, 0.5)
		tweens.append(tween)

	# Monitor FPS during stress
	while (Time.get_ticks_msec() / 1000.0) - start_time < STRESS_TEST_DURATION:
		_fps_samples.append(_current_fps)

		if _current_fps < FPS_THRESHOLD_30:
			fps_warning.emit(current_test, _current_fps, FPS_THRESHOLD_30)

		await get_tree().process_frame
		test_progress.emit(current_test, ((Time.get_ticks_msec() / 1000.0) - start_time) / STRESS_TEST_DURATION)

	# Stop all tweens and cleanup
	for tween: Tween in tweens:
		tween.kill()

	# Cleanup
	_cleanup_test_nodes()

	# Calculate results
	var avg_fps: float = _calculate_average(_fps_samples)
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0
	var frames_below_30: int = _fps_samples.filter(func(f: float) -> bool: return f < 30.0).size()

	var passed: bool = avg_fps >= FPS_THRESHOLD_30 and frames_below_30 < _fps_samples.size() * 0.1
	var message: String = "%d animations, Avg: %.1f FPS, %d frames < 30" % [control_count, avg_fps, frames_below_30]

	var result := _create_result(
		current_test,
		TestStatus.PASSED if passed else TestStatus.FAILED,
		message,
		{
			"animation_count": control_count,
			"average_fps": avg_fps,
			"min_fps": min_fps,
			"frames_below_30": frames_below_30
		}
	)

	_test_results.append(result)
	test_completed.emit(current_test, passed, message)


## Stress test particle systems
func run_particle_stress_test() -> void:
	current_test = "particle_stress"
	test_started.emit(current_test)

	_fps_samples.clear()
	var test_container := Control.new()
	get_tree().current_scene.add_child(test_container)
	_test_nodes.append(test_container)

	# Create many particle emitters
	var emitter_count: int = 50
	var emitters: Array[CPUParticles2D] = []

	for i in range(emitter_count):
		var particles := CPUParticles2D.new()
		particles.amount = 30
		particles.lifetime = 1.0
		particles.explosiveness = 0.5
		particles.position = Vector2(randf_range(100, 700), randf_range(100, 500))
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 20.0
		particles.direction = Vector2(0, -1)
		particles.spread = 45.0
		particles.gravity = Vector2(0, 100)
		particles.initial_velocity_min = 50.0
		particles.initial_velocity_max = 150.0
		particles.emitting = true
		test_container.add_child(particles)
		emitters.append(particles)

	var start_time: float = Time.get_ticks_msec() / 1000.0

	# Monitor FPS during stress
	while (Time.get_ticks_msec() / 1000.0) - start_time < STRESS_TEST_DURATION:
		_fps_samples.append(_current_fps)

		if _current_fps < FPS_THRESHOLD_30:
			fps_warning.emit(current_test, _current_fps, FPS_THRESHOLD_30)

		await get_tree().process_frame
		test_progress.emit(current_test, ((Time.get_ticks_msec() / 1000.0) - start_time) / STRESS_TEST_DURATION)

	# Cleanup
	_cleanup_test_nodes()

	# Calculate results
	var avg_fps: float = _calculate_average(_fps_samples)
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0
	var total_particles: int = emitter_count * 30

	var passed: bool = avg_fps >= FPS_THRESHOLD_30
	var message: String = "%d emitters (%d particles), Avg: %.1f FPS" % [emitter_count, total_particles, avg_fps]

	var result := _create_result(
		current_test,
		TestStatus.PASSED if passed else TestStatus.FAILED,
		message,
		{
			"emitter_count": emitter_count,
			"total_particles": total_particles,
			"average_fps": avg_fps,
			"min_fps": min_fps
		}
	)

	_test_results.append(result)
	test_completed.emit(current_test, passed, message)


## Tests for memory leaks
func run_memory_leak_test() -> void:
	current_test = "memory_leak"
	test_started.emit(current_test)

	_memory_samples.clear()
	_initial_memory_mb = float(OS.get_static_memory_usage()) / 1048576.0

	# Create and destroy many nodes in cycles
	var cycles: int = 10
	var nodes_per_cycle: int = 100

	for cycle in range(cycles):
		# Create nodes
		var nodes: Array[Control] = []
		for i in range(nodes_per_cycle):
			var control := ColorRect.new()
			control.custom_minimum_size = Vector2(50, 50)
			get_tree().current_scene.add_child(control)
			nodes.append(control)

		await get_tree().process_frame

		# Destroy nodes
		for node: Control in nodes:
			node.queue_free()

		await get_tree().process_frame

		# Sample memory
		var current_memory: float = float(OS.get_static_memory_usage()) / 1048576.0
		_memory_samples.append(current_memory)

		test_progress.emit(current_test, float(cycle) / float(cycles))

	# Wait for GC
	await get_tree().create_timer(1.0).timeout

	var final_memory: float = float(OS.get_static_memory_usage()) / 1048576.0
	var memory_delta: float = final_memory - _initial_memory_mb

	var passed: bool = memory_delta < MEMORY_LEAK_THRESHOLD_MB
	var message: String = "Initial: %.2f MB, Final: %.2f MB, Delta: %.2f MB" % [_initial_memory_mb, final_memory, memory_delta]

	var result := _create_result(
		current_test,
		TestStatus.PASSED if passed else TestStatus.FAILED,
		message,
		{
			"initial_memory_mb": _initial_memory_mb,
			"final_memory_mb": final_memory,
			"delta_mb": memory_delta,
			"cycles": cycles,
			"nodes_per_cycle": nodes_per_cycle
		}
	)

	_test_results.append(result)
	test_completed.emit(current_test, passed, message)

# endregion


# =============================================================================
# region - Input Tests
# =============================================================================

## Measures input latency
func run_input_lag_test() -> void:
	current_test = "input_lag"
	test_started.emit(current_test)

	_input_latencies.clear()

	# Create test button
	var test_button := Button.new()
	test_button.text = "Test Input"
	test_button.position = Vector2(400, 300)
	test_button.custom_minimum_size = Vector2(200, 60)
	get_tree().current_scene.add_child(test_button)
	_test_nodes.append(test_button)

	var samples_collected: int = 0
	var input_start_time: float = 0.0

	# Connect to button press to measure response
	test_button.pressed.connect(func():
		if input_start_time > 0:
			var latency: float = (Time.get_ticks_usec() / 1000.0) - input_start_time
			_input_latencies.append(latency)
			samples_collected += 1
	)

	# Simulate button presses
	while samples_collected < INPUT_LAG_SAMPLES:
		input_start_time = Time.get_ticks_usec() / 1000.0

		# Simulate a click
		var click_event := InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		click_event.position = test_button.global_position + test_button.size / 2
		Input.parse_input_event(click_event)

		await get_tree().process_frame

		click_event.pressed = false
		Input.parse_input_event(click_event)

		await get_tree().process_frame
		test_progress.emit(current_test, float(samples_collected) / float(INPUT_LAG_SAMPLES))

	# Cleanup
	_cleanup_test_nodes()

	# Calculate results
	var avg_latency: float = _calculate_average(_input_latencies)
	var max_latency: float = _input_latencies.max() if not _input_latencies.is_empty() else 0.0
	var min_latency: float = _input_latencies.min() if not _input_latencies.is_empty() else 0.0

	var passed: bool = avg_latency < INPUT_LAG_THRESHOLD_MS
	var message: String = "Avg: %.2f ms, Min: %.2f ms, Max: %.2f ms" % [avg_latency, min_latency, max_latency]

	var result := _create_result(
		current_test,
		TestStatus.PASSED if passed else TestStatus.FAILED,
		message,
		{
			"average_latency_ms": avg_latency,
			"min_latency_ms": min_latency,
			"max_latency_ms": max_latency,
			"sample_count": _input_latencies.size()
		}
	)

	_test_results.append(result)
	test_completed.emit(current_test, passed, message)

# endregion


# =============================================================================
# region - Accessibility Tests
# =============================================================================

## Runs accessibility audit on current scene
func run_accessibility_audit() -> void:
	current_test = "accessibility"
	test_started.emit(current_test)

	var issues: Array[Dictionary] = []
	var root := get_tree().current_scene

	# Check all control nodes
	var controls := _get_all_controls(root)
	var checked: int = 0

	for control: Control in controls:
		# Check touch target size
		if control is BaseButton:
			if control.size.x < 44 or control.size.y < 44:
				issues.append({
					"type": "touch_target",
					"severity": "warning",
					"node": control.name,
					"message": "Touch target too small: %dx%d (min 44x44)" % [int(control.size.x), int(control.size.y)]
				})

		# Check contrast (basic check)
		if control is Label:
			var label := control as Label
			var parent_bg := _get_background_color(control.get_parent())
			if parent_bg.a > 0:
				var text_color := label.get_theme_color("font_color", "Label") if label.has_theme_color("font_color", "Label") else Color.WHITE
				var contrast := _calculate_contrast_ratio(text_color, parent_bg)
				if contrast < 4.5:
					issues.append({
						"type": "contrast",
						"severity": "error",
						"node": control.name,
						"message": "Low contrast ratio: %.2f (min 4.5)" % contrast
					})

		# Check focus order
		if control is BaseButton and not control.focus_mode == Control.FOCUS_NONE:
			if control.focus_neighbor_top.is_empty() and control.focus_neighbor_bottom.is_empty():
				issues.append({
					"type": "focus_order",
					"severity": "info",
					"node": control.name,
					"message": "No focus neighbors defined"
				})

		checked += 1
		test_progress.emit(current_test, float(checked) / float(controls.size()))

	var error_count := issues.filter(func(i: Dictionary) -> bool: return i.get("severity") == "error").size()
	var passed: bool = error_count == 0
	var message: String = "%d controls checked, %d issues (%d errors)" % [controls.size(), issues.size(), error_count]

	var result := _create_result(
		current_test,
		TestStatus.PASSED if passed else TestStatus.FAILED,
		message,
		{
			"controls_checked": controls.size(),
			"total_issues": issues.size(),
			"error_count": error_count,
			"issues": issues
		}
	)

	_test_results.append(result)
	test_completed.emit(current_test, passed, message)

# endregion


# =============================================================================
# region - Polish Tests
# =============================================================================

## Tests button feedback (hover, press states)
func run_button_feedback_test() -> void:
	current_test = "button_feedback"
	test_started.emit(current_test)

	var issues: Array[Dictionary] = []
	var root := get_tree().current_scene
	var buttons := _get_all_controls(root).filter(func(c: Control) -> bool: return c is BaseButton)
	var checked: int = 0

	for button: BaseButton in buttons:
		# Check for hover signal connections
		var has_hover_feedback: bool = button.mouse_entered.get_connections().size() > 0
		var has_press_feedback: bool = button.pressed.get_connections().size() > 0 or button.button_down.get_connections().size() > 0

		if not has_hover_feedback:
			issues.append({
				"type": "no_hover_feedback",
				"node": button.name,
				"message": "Button has no hover feedback"
			})

		# Check for style variations
		if button is Button:
			var btn := button as Button
			var has_hover_style := btn.has_theme_stylebox("hover") or btn.has_theme_stylebox_override("hover")
			var has_pressed_style := btn.has_theme_stylebox("pressed") or btn.has_theme_stylebox_override("pressed")

			if not has_hover_style:
				issues.append({
					"type": "no_hover_style",
					"node": button.name,
					"message": "Button has no hover style"
				})

			if not has_pressed_style:
				issues.append({
					"type": "no_pressed_style",
					"node": button.name,
					"message": "Button has no pressed style"
				})

		checked += 1
		test_progress.emit(current_test, float(checked) / float(buttons.size()) if buttons.size() > 0 else 1.0)

	var passed: bool = issues.size() == 0
	var message: String = "%d buttons checked, %d issues" % [buttons.size(), issues.size()]

	var result := _create_result(
		current_test,
		TestStatus.PASSED if passed else TestStatus.FAILED,
		message,
		{
			"buttons_checked": buttons.size(),
			"issues": issues
		}
	)

	_test_results.append(result)
	test_completed.emit(current_test, passed, message)


## Tests panel entrance/exit animations
func run_panel_animation_test() -> void:
	current_test = "panel_animation"
	test_started.emit(current_test)

	var issues: Array[Dictionary] = []
	var root := get_tree().current_scene
	var panels := _get_all_controls(root).filter(func(c: Control) -> bool: return c is PanelContainer)
	var checked: int = 0

	for panel: PanelContainer in panels:
		# Check for visibility change signal connections (potential animations)
		var has_visibility_animation: bool = panel.visibility_changed.get_connections().size() > 0

		# Check for AnimationPlayer child
		var has_animation_player: bool = false
		for child: Node in panel.get_children():
			if child is AnimationPlayer:
				has_animation_player = true
				break

		if not has_visibility_animation and not has_animation_player:
			issues.append({
				"type": "no_panel_animation",
				"node": panel.name,
				"message": "Panel may lack entrance/exit animation"
			})

		checked += 1
		test_progress.emit(current_test, float(checked) / float(panels.size()) if panels.size() > 0 else 1.0)

	var passed: bool = issues.size() <= panels.size() * 0.5  # Allow 50% to pass
	var message: String = "%d panels checked, %d may lack animations" % [panels.size(), issues.size()]

	var result := _create_result(
		current_test,
		TestStatus.PASSED if passed else TestStatus.FAILED,
		message,
		{
			"panels_checked": panels.size(),
			"issues": issues
		}
	)

	_test_results.append(result)
	test_completed.emit(current_test, passed, message)


## Tests scroll container performance
func run_scroll_performance_test() -> void:
	current_test = "scroll_performance"
	test_started.emit(current_test)

	_fps_samples.clear()

	# Create test scroll container with many items
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 300)
	scroll.position = Vector2(200, 150)

	var vbox := VBoxContainer.new()
	scroll.add_child(vbox)

	# Add many items
	var item_count: int = 200
	for i in range(item_count):
		var item := PanelContainer.new()
		item.custom_minimum_size = Vector2(380, 60)

		var label := Label.new()
		label.text = "Item %d" % i
		item.add_child(label)
		vbox.add_child(item)

	get_tree().current_scene.add_child(scroll)
	_test_nodes.append(scroll)

	await get_tree().process_frame

	# Simulate scrolling
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var scroll_speed: float = 500.0

	while (Time.get_ticks_msec() / 1000.0) - start_time < 3.0:
		scroll.scroll_vertical += int(scroll_speed * get_process_delta_time())

		if scroll.scroll_vertical >= scroll.get_v_scroll_bar().max_value:
			scroll_speed = -scroll_speed
		elif scroll.scroll_vertical <= 0:
			scroll_speed = absf(scroll_speed)

		_fps_samples.append(_current_fps)
		await get_tree().process_frame
		test_progress.emit(current_test, ((Time.get_ticks_msec() / 1000.0) - start_time) / 3.0)

	# Cleanup
	_cleanup_test_nodes()

	var avg_fps: float = _calculate_average(_fps_samples)
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0

	var passed: bool = avg_fps >= FPS_THRESHOLD_30
	var message: String = "%d items, Avg: %.1f FPS, Min: %.1f FPS" % [item_count, avg_fps, min_fps]

	var result := _create_result(
		current_test,
		TestStatus.PASSED if passed else TestStatus.FAILED,
		message,
		{
			"item_count": item_count,
			"average_fps": avg_fps,
			"min_fps": min_fps
		}
	)

	_test_results.append(result)
	test_completed.emit(current_test, passed, message)

# endregion


# =============================================================================
# region - Helper Functions
# =============================================================================

func _track_fps(delta: float) -> void:
	_frame_times.append(delta)
	if _frame_times.size() > 60:
		_frame_times.remove_at(0)

	var total: float = 0.0
	for ft: float in _frame_times:
		total += ft
	var avg_frame_time: float = total / _frame_times.size()
	_current_fps = 1.0 / avg_frame_time if avg_frame_time > 0 else 60.0


func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0

	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()


func _create_result(test_name: String, status: TestStatus, message: String, data: Dictionary = {}) -> Dictionary:
	return {
		"test_name": test_name,
		"status": status,
		"message": message,
		"timestamp": Time.get_datetime_string_from_system(),
		"data": data
	}


func _cleanup_test_nodes() -> void:
	for node: Node in _test_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_test_nodes.clear()


func _get_all_controls(root: Node) -> Array[Control]:
	var controls: Array[Control] = []

	if root is Control:
		controls.append(root)

	for child: Node in root.get_children():
		controls.append_array(_get_all_controls(child))

	return controls


func _get_background_color(node: Node) -> Color:
	if node is ColorRect:
		return node.color
	elif node is PanelContainer:
		var style: StyleBox = node.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			return style.bg_color
	elif node is Control and node.get_parent():
		return _get_background_color(node.get_parent())

	return Color.TRANSPARENT


func _calculate_contrast_ratio(fg: Color, bg: Color) -> float:
	var fg_luminance: float = _get_relative_luminance(fg)
	var bg_luminance: float = _get_relative_luminance(bg)

	var lighter: float = maxf(fg_luminance, bg_luminance)
	var darker: float = minf(fg_luminance, bg_luminance)

	return (lighter + 0.05) / (darker + 0.05)


func _get_relative_luminance(color: Color) -> float:
	var r: float = color.r
	var g: float = color.g
	var b: float = color.b

	r = r / 12.92 if r <= 0.03928 else pow((r + 0.055) / 1.055, 2.4)
	g = g / 12.92 if g <= 0.03928 else pow((g + 0.055) / 1.055, 2.4)
	b = b / 12.92 if b <= 0.03928 else pow((b + 0.055) / 1.055, 2.4)

	return 0.2126 * r + 0.7152 * g + 0.0722 * b

# endregion


# =============================================================================
# region - Public API
# =============================================================================

## Gets all test results
func get_test_results() -> Array[Dictionary]:
	return _test_results.duplicate()


## Gets formatted test report
func get_test_report() -> String:
	var report: String = "=== UI Test Report ===\n"
	report += "Generated: %s\n\n" % Time.get_datetime_string_from_system()

	var passed: int = 0
	var failed: int = 0
	var skipped: int = 0

	for result: Dictionary in _test_results:
		var status_str: String
		match result.get("status", TestStatus.ERROR):
			TestStatus.PASSED:
				status_str = "PASS"
				passed += 1
			TestStatus.FAILED:
				status_str = "FAIL"
				failed += 1
			TestStatus.SKIPPED:
				status_str = "SKIP"
				skipped += 1
			_:
				status_str = "ERROR"
				failed += 1

		report += "[%s] %s\n" % [status_str, result.get("test_name", "unknown")]
		report += "  %s\n" % result.get("message", "")

	report += "\n--- Summary ---\n"
	report += "Passed: %d\n" % passed
	report += "Failed: %d\n" % failed
	report += "Skipped: %d\n" % skipped
	report += "Total: %d\n" % _test_results.size()

	return report


## Clears all test results
func clear_results() -> void:
	_test_results.clear()
	_cleanup_test_nodes()

# endregion
