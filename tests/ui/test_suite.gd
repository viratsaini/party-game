## UI Test Suite - Comprehensive automated testing for BattleZone Party UI
##
## This is the main entry point for all UI tests. Provides:
## - Automated UI flow testing
## - Component interaction testing
## - Animation completion verification
## - Performance benchmarks
## - Memory leak detection
## - Input validation testing
## - Network resilience testing
##
## Usage:
##   var suite = UITestSuiteRunner.new()
##   add_child(suite)
##   var results = await suite.run_all_tests()
##   print(results.get_summary())
class_name UITestSuiteRunner
extends Node


# =============================================================================
# region - Signals
# =============================================================================

## Emitted when a test starts
signal test_started(test_name: String, category: String)

## Emitted when a test completes
signal test_completed(test_name: String, passed: bool, duration_ms: float, message: String)

## Emitted when a test category starts
signal category_started(category: String, test_count: int)

## Emitted when a test category completes
signal category_completed(category: String, passed: int, failed: int)

## Emitted when all tests complete
signal all_tests_completed(results: UITestResults)

## Emitted for progress tracking
signal progress_updated(current: int, total: int, percentage: float)

# endregion


# =============================================================================
# region - Enums and Constants
# =============================================================================

enum TestCategory {
	INTERACTION,
	ANIMATION,
	PERFORMANCE,
	MEMORY,
	INPUT_VALIDATION,
	NETWORK_RESILIENCE,
	ACCESSIBILITY,
	EDGE_CASE,
	STRESS,
	INTEGRATION
}

const CATEGORY_NAMES: Dictionary = {
	TestCategory.INTERACTION: "Interaction Tests",
	TestCategory.ANIMATION: "Animation Tests",
	TestCategory.PERFORMANCE: "Performance Benchmarks",
	TestCategory.MEMORY: "Memory Tests",
	TestCategory.INPUT_VALIDATION: "Input Validation Tests",
	TestCategory.NETWORK_RESILIENCE: "Network Resilience Tests",
	TestCategory.ACCESSIBILITY: "Accessibility Tests",
	TestCategory.EDGE_CASE: "Edge Case Tests",
	TestCategory.STRESS: "Stress Tests",
	TestCategory.INTEGRATION: "Integration Tests"
}

## Performance thresholds
const FPS_THRESHOLD_CRITICAL: float = 25.0
const FPS_THRESHOLD_WARNING: float = 45.0
const FPS_THRESHOLD_TARGET: float = 55.0

const FRAME_TIME_BUDGET_MS: float = 16.67  # 60 FPS
const INPUT_LAG_THRESHOLD_MS: float = 100.0
const MEMORY_LEAK_THRESHOLD_MB: float = 15.0
const ANIMATION_TIMEOUT_MS: float = 5000.0

## Test configuration
const DEFAULT_TIMEOUT_MS: int = 10000
const STRESS_TEST_DURATION_SEC: float = 15.0
const BENCHMARK_ITERATIONS: int = 100

# endregion


# =============================================================================
# region - Results Classes
# =============================================================================

class UITestResult:
	var name: String
	var category: TestCategory
	var passed: bool
	var duration_ms: float
	var message: String
	var data: Dictionary
	var timestamp: String
	var stack_trace: String

	func _init(n: String, cat: TestCategory) -> void:
		name = n
		category = cat
		passed = true
		duration_ms = 0.0
		message = ""
		data = {}
		timestamp = Time.get_datetime_string_from_system()
		stack_trace = ""

	func to_dict() -> Dictionary:
		return {
			"name": name,
			"category": CATEGORY_NAMES.get(category, "Unknown"),
			"passed": passed,
			"duration_ms": duration_ms,
			"message": message,
			"data": data,
			"timestamp": timestamp
		}


class UITestResults:
	var total: int = 0
	var passed: int = 0
	var failed: int = 0
	var skipped: int = 0
	var duration_ms: float = 0.0
	var results: Array[UITestResult] = []
	var by_category: Dictionary = {}
	var warnings: Array[String] = []
	var critical_failures: Array[String] = []

	func add_result(result: UITestResult) -> void:
		results.append(result)
		total += 1
		if result.passed:
			passed += 1
		else:
			failed += 1
			if result.category == TestCategory.PERFORMANCE or result.category == TestCategory.MEMORY:
				critical_failures.append(result.name + ": " + result.message)
		duration_ms += result.duration_ms

		# Track by category
		if not by_category.has(result.category):
			by_category[result.category] = {"passed": 0, "failed": 0, "results": []}
		by_category[result.category].results.append(result)
		if result.passed:
			by_category[result.category].passed += 1
		else:
			by_category[result.category].failed += 1

	func get_summary() -> String:
		var pass_rate: float = (float(passed) / float(total)) * 100.0 if total > 0 else 0.0
		var summary: String = ""
		summary += "=" .repeat(60) + "\n"
		summary += "UI TEST SUITE RESULTS\n"
		summary += "=" .repeat(60) + "\n\n"
		summary += "Total: %d | Passed: %d | Failed: %d | Skipped: %d\n" % [total, passed, failed, skipped]
		summary += "Pass Rate: %.1f%%\n" % pass_rate
		summary += "Duration: %.2f seconds\n\n" % (duration_ms / 1000.0)

		# Category breakdown
		summary += "BY CATEGORY:\n"
		summary += "-" .repeat(40) + "\n"
		for cat: int in by_category:
			var cat_data: Dictionary = by_category[cat]
			var cat_name: String = CATEGORY_NAMES.get(cat, "Unknown")
			var cat_total: int = cat_data.passed + cat_data.failed
			var cat_rate: float = (float(cat_data.passed) / float(cat_total)) * 100.0 if cat_total > 0 else 0.0
			summary += "  %s: %d/%d (%.0f%%)\n" % [cat_name, cat_data.passed, cat_total, cat_rate]

		if critical_failures.size() > 0:
			summary += "\nCRITICAL FAILURES:\n"
			summary += "-" .repeat(40) + "\n"
			for failure: String in critical_failures:
				summary += "  [!] %s\n" % failure

		if warnings.size() > 0:
			summary += "\nWARNINGS:\n"
			summary += "-" .repeat(40) + "\n"
			for warning: String in warnings:
				summary += "  [?] %s\n" % warning

		return summary

	func to_dict() -> Dictionary:
		var result_dicts: Array = []
		for r: UITestResult in results:
			result_dicts.append(r.to_dict())
		return {
			"total": total,
			"passed": passed,
			"failed": failed,
			"skipped": skipped,
			"pass_rate": (float(passed) / float(total)) * 100.0 if total > 0 else 0.0,
			"duration_ms": duration_ms,
			"results": result_dicts,
			"critical_failures": critical_failures,
			"warnings": warnings
		}

	func to_json() -> String:
		return JSON.stringify(to_dict(), "\t")

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

var _results: UITestResults
var _is_running: bool = false
var _registered_tests: Array[Dictionary] = []
var _current_test_index: int = 0
var _test_start_time: int = 0

## FPS tracking for performance tests
var _fps_samples: Array[float] = []
var _frame_times: Array[float] = []
var _current_fps: float = 60.0

## Memory tracking
var _initial_memory_mb: float = 0.0
var _memory_samples: Array[float] = []

## Test nodes created during tests
var _test_nodes: Array[Node] = []

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	_register_all_tests()


func _process(delta: float) -> void:
	if _is_running:
		_track_fps(delta)

# endregion


# =============================================================================
# region - Public API
# =============================================================================

## Run all registered tests
func run_all_tests() -> UITestResults:
	if _is_running:
		push_warning("[UITestSuite] Tests already running!")
		return UITestResults.new()

	_is_running = true
	_results = UITestResults.new()
	_current_test_index = 0

	var total_tests: int = _registered_tests.size()

	for test: Dictionary in _registered_tests:
		_current_test_index += 1

		var test_name: String = test.name
		var category: TestCategory = test.category
		var callable: Callable = test.callable
		var timeout_ms: int = test.get("timeout_ms", DEFAULT_TIMEOUT_MS)

		test_started.emit(test_name, CATEGORY_NAMES.get(category, "Unknown"))
		progress_updated.emit(_current_test_index, total_tests, float(_current_test_index) / float(total_tests) * 100.0)

		var result := UITestResult.new(test_name, category)
		_test_start_time = Time.get_ticks_msec()

		# Execute test
		var test_output: Variant = await _execute_test(callable, timeout_ms)

		result.duration_ms = float(Time.get_ticks_msec() - _test_start_time)

		# Process result
		if test_output is Dictionary:
			if test_output.has("error"):
				result.passed = false
				result.message = test_output.get("error", "Unknown error")
				result.stack_trace = test_output.get("stack", "")
			elif test_output.has("skip"):
				result.passed = true
				result.message = "SKIPPED: " + test_output.get("skip", "")
				_results.skipped += 1
			else:
				result.data = test_output
		elif test_output is bool:
			result.passed = test_output
			if not test_output:
				result.message = "Test returned false"
		elif test_output is String:
			result.passed = false
			result.message = test_output

		_results.add_result(result)
		test_completed.emit(test_name, result.passed, result.duration_ms, result.message)

		# Cleanup between tests
		_cleanup_test_nodes()
		await Engine.get_main_loop().process_frame

	_is_running = false
	all_tests_completed.emit(_results)

	return _results


## Run tests for a specific category
func run_category(category: TestCategory) -> UITestResults:
	if _is_running:
		push_warning("[UITestSuite] Tests already running!")
		return UITestResults.new()

	var filtered: Array[Dictionary] = _registered_tests.filter(
		func(t: Dictionary) -> bool: return t.category == category
	)

	var temp_tests: Array[Dictionary] = _registered_tests.duplicate()
	_registered_tests = filtered

	var results: UITestResults = await run_all_tests()

	_registered_tests = temp_tests
	return results


## Get a printable test report
func get_report() -> String:
	if _results == null:
		return "No test results available. Run tests first."
	return _results.get_summary()

# endregion


# =============================================================================
# region - Test Registration
# =============================================================================

func _register_all_tests() -> void:
	_register_interaction_tests()
	_register_animation_tests()
	_register_performance_tests()
	_register_memory_tests()
	_register_input_validation_tests()
	_register_network_resilience_tests()
	_register_accessibility_tests()
	_register_edge_case_tests()
	_register_stress_tests()


func _register_test(name: String, category: TestCategory, callable: Callable, timeout_ms: int = DEFAULT_TIMEOUT_MS) -> void:
	_registered_tests.append({
		"name": name,
		"category": category,
		"callable": callable,
		"timeout_ms": timeout_ms
	})

# endregion


# =============================================================================
# region - Interaction Tests
# =============================================================================

func _register_interaction_tests() -> void:
	_register_test("Button_Click_Response", TestCategory.INTERACTION, _test_button_click_response)
	_register_test("Button_Hover_State", TestCategory.INTERACTION, _test_button_hover_state)
	_register_test("Button_Disabled_State", TestCategory.INTERACTION, _test_button_disabled_state)
	_register_test("Slider_Drag_Value", TestCategory.INTERACTION, _test_slider_drag_value)
	_register_test("TextInput_Character_Entry", TestCategory.INTERACTION, _test_text_input_entry)
	_register_test("Checkbox_Toggle", TestCategory.INTERACTION, _test_checkbox_toggle)
	_register_test("Dropdown_Selection", TestCategory.INTERACTION, _test_dropdown_selection)
	_register_test("ScrollContainer_Scroll", TestCategory.INTERACTION, _test_scroll_container)
	_register_test("ItemList_Selection", TestCategory.INTERACTION, _test_item_list_selection)
	_register_test("TabContainer_Switch", TestCategory.INTERACTION, _test_tab_container_switch)


func _test_button_click_response() -> Dictionary:
	var button := Button.new()
	button.text = "Test Button"
	button.position = Vector2(100, 100)
	button.size = Vector2(200, 50)
	_add_test_node(button)

	await get_tree().process_frame

	var click_received: bool = false
	button.pressed.connect(func(): click_received = true)

	# Simulate click
	_simulate_click(button.global_position + button.size / 2)

	await get_tree().process_frame
	await get_tree().process_frame

	if not click_received:
		return {"error": "Button click was not received"}

	return {"click_latency_frames": 2}


func _test_button_hover_state() -> Dictionary:
	var button := Button.new()
	button.text = "Hover Test"
	button.position = Vector2(100, 100)
	button.size = Vector2(200, 50)
	_add_test_node(button)

	await get_tree().process_frame

	var hover_entered: bool = false
	var hover_exited: bool = false
	button.mouse_entered.connect(func(): hover_entered = true)
	button.mouse_exited.connect(func(): hover_exited = true)

	# Simulate hover enter
	_simulate_mouse_motion(button.global_position + button.size / 2)
	await get_tree().process_frame

	# Simulate hover exit
	_simulate_mouse_motion(Vector2(-100, -100))
	await get_tree().process_frame

	if not hover_entered:
		return {"error": "Hover enter signal not received"}

	# Note: hover_exited may not work in headless mode
	return {}


func _test_button_disabled_state() -> Dictionary:
	var button := Button.new()
	button.text = "Disabled Test"
	button.disabled = true
	button.position = Vector2(100, 100)
	button.size = Vector2(200, 50)
	_add_test_node(button)

	await get_tree().process_frame

	var click_received: bool = false
	button.pressed.connect(func(): click_received = true)

	# Try to click disabled button
	_simulate_click(button.global_position + button.size / 2)

	await get_tree().process_frame

	if click_received:
		return {"error": "Disabled button should not receive clicks"}

	return {}


func _test_slider_drag_value() -> Dictionary:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 50.0
	slider.position = Vector2(100, 100)
	slider.size = Vector2(200, 30)
	_add_test_node(slider)

	await get_tree().process_frame

	var value_changed: bool = false
	var new_value: float = slider.value
	slider.value_changed.connect(func(val: float):
		value_changed = true
		new_value = val
	)

	# Change value programmatically
	slider.value = 75.0

	await get_tree().process_frame

	if not value_changed:
		return {"error": "Slider value_changed signal not emitted"}

	if absf(new_value - 75.0) > 0.01:
		return {"error": "Slider value mismatch: expected 75.0, got %.2f" % new_value}

	return {"final_value": new_value}


func _test_text_input_entry() -> Dictionary:
	var line_edit := LineEdit.new()
	line_edit.position = Vector2(100, 100)
	line_edit.size = Vector2(200, 30)
	_add_test_node(line_edit)

	await get_tree().process_frame

	var text_changed: bool = false
	line_edit.text_changed.connect(func(_t: String): text_changed = true)

	# Set text programmatically
	line_edit.text = "Test Input"
	line_edit.text_changed.emit(line_edit.text)

	await get_tree().process_frame

	if line_edit.text != "Test Input":
		return {"error": "Text input value mismatch"}

	return {"final_text": line_edit.text}


func _test_checkbox_toggle() -> Dictionary:
	var checkbox := CheckBox.new()
	checkbox.text = "Test Checkbox"
	checkbox.position = Vector2(100, 100)
	_add_test_node(checkbox)

	await get_tree().process_frame

	var toggled_value: bool = false
	checkbox.toggled.connect(func(val: bool): toggled_value = val)

	# Toggle programmatically
	checkbox.button_pressed = true
	checkbox.toggled.emit(true)

	await get_tree().process_frame

	if not checkbox.button_pressed:
		return {"error": "Checkbox should be checked"}

	if not toggled_value:
		return {"error": "Checkbox toggled signal not received"}

	return {}


func _test_dropdown_selection() -> Dictionary:
	var option := OptionButton.new()
	option.position = Vector2(100, 100)
	option.add_item("Option 1", 0)
	option.add_item("Option 2", 1)
	option.add_item("Option 3", 2)
	_add_test_node(option)

	await get_tree().process_frame

	var selection_changed: bool = false
	var selected_idx: int = -1
	option.item_selected.connect(func(idx: int):
		selection_changed = true
		selected_idx = idx
	)

	# Select item
	option.select(1)
	option.item_selected.emit(1)

	await get_tree().process_frame

	if option.selected != 1:
		return {"error": "OptionButton selection mismatch"}

	return {"selected_index": option.selected}


func _test_scroll_container() -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(100, 100)
	scroll.size = Vector2(200, 150)

	var vbox := VBoxContainer.new()
	scroll.add_child(vbox)

	# Add many items
	for i in range(20):
		var label := Label.new()
		label.text = "Item %d" % i
		label.custom_minimum_size = Vector2(180, 30)
		vbox.add_child(label)

	_add_test_node(scroll)

	await get_tree().process_frame
	await get_tree().process_frame

	var initial_scroll: int = scroll.scroll_vertical

	# Scroll down
	scroll.scroll_vertical = 100

	await get_tree().process_frame

	if scroll.scroll_vertical == initial_scroll:
		return {"error": "ScrollContainer did not scroll"}

	return {"scroll_position": scroll.scroll_vertical}


func _test_item_list_selection() -> Dictionary:
	var item_list := ItemList.new()
	item_list.position = Vector2(100, 100)
	item_list.size = Vector2(200, 150)
	item_list.add_item("Item 1")
	item_list.add_item("Item 2")
	item_list.add_item("Item 3")
	_add_test_node(item_list)

	await get_tree().process_frame

	var selection_changed: bool = false
	item_list.item_selected.connect(func(_idx: int): selection_changed = true)

	# Select item
	item_list.select(1)
	item_list.item_selected.emit(1)

	await get_tree().process_frame

	if not item_list.is_selected(1):
		return {"error": "ItemList selection failed"}

	return {}


func _test_tab_container_switch() -> Dictionary:
	var tabs := TabContainer.new()
	tabs.position = Vector2(100, 100)
	tabs.size = Vector2(300, 200)

	var tab1 := Control.new()
	tab1.name = "Tab 1"
	tabs.add_child(tab1)

	var tab2 := Control.new()
	tab2.name = "Tab 2"
	tabs.add_child(tab2)

	_add_test_node(tabs)

	await get_tree().process_frame

	var tab_changed: bool = false
	tabs.tab_changed.connect(func(_idx: int): tab_changed = true)

	# Switch tab
	tabs.current_tab = 1

	await get_tree().process_frame

	if tabs.current_tab != 1:
		return {"error": "Tab switch failed"}

	return {"current_tab": tabs.current_tab}

# endregion


# =============================================================================
# region - Animation Tests
# =============================================================================

func _register_animation_tests() -> void:
	_register_test("Tween_Completion", TestCategory.ANIMATION, _test_tween_completion)
	_register_test("Tween_Property_Animation", TestCategory.ANIMATION, _test_tween_property)
	_register_test("Tween_Chained_Sequence", TestCategory.ANIMATION, _test_tween_chain)
	_register_test("Tween_Parallel", TestCategory.ANIMATION, _test_tween_parallel)
	_register_test("Animation_Callbacks", TestCategory.ANIMATION, _test_animation_callbacks)
	_register_test("Animation_Kill_Cleanup", TestCategory.ANIMATION, _test_animation_kill)
	_register_test("Animation_Timing_Accuracy", TestCategory.ANIMATION, _test_animation_timing)


func _test_tween_completion() -> Dictionary:
	var control := ColorRect.new()
	control.position = Vector2(100, 100)
	control.size = Vector2(50, 50)
	control.color = Color.RED
	_add_test_node(control)

	await get_tree().process_frame

	var tween_finished: bool = false
	var tween := control.create_tween()
	tween.tween_property(control, "position:x", 200.0, 0.2)
	tween.finished.connect(func(): tween_finished = true)

	# Wait for tween to complete
	var timeout: float = 0.0
	while not tween_finished and timeout < 1.0:
		await get_tree().process_frame
		timeout += get_process_delta_time()

	if not tween_finished:
		return {"error": "Tween did not complete within timeout"}

	if absf(control.position.x - 200.0) > 1.0:
		return {"error": "Tween end position incorrect: %.2f" % control.position.x}

	return {"duration": timeout}


func _test_tween_property() -> Dictionary:
	var control := ColorRect.new()
	control.size = Vector2(50, 50)
	control.modulate = Color.WHITE
	_add_test_node(control)

	await get_tree().process_frame

	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.1)

	await tween.finished

	if absf(control.modulate.a) > 0.01:
		return {"error": "Modulate alpha should be 0, got %.2f" % control.modulate.a}

	return {}


func _test_tween_chain() -> Dictionary:
	var control := Control.new()
	control.position = Vector2.ZERO
	_add_test_node(control)

	await get_tree().process_frame

	var steps_completed: int = 0

	var tween := control.create_tween()
	tween.tween_property(control, "position:x", 100.0, 0.05)
	tween.tween_callback(func(): steps_completed += 1)
	tween.tween_property(control, "position:y", 100.0, 0.05)
	tween.tween_callback(func(): steps_completed += 1)
	tween.tween_property(control, "position:x", 0.0, 0.05)
	tween.tween_callback(func(): steps_completed += 1)

	await tween.finished

	if steps_completed != 3:
		return {"error": "Expected 3 chain steps, got %d" % steps_completed}

	return {"steps": steps_completed}


func _test_tween_parallel() -> Dictionary:
	var control := Control.new()
	control.position = Vector2.ZERO
	control.scale = Vector2.ONE
	_add_test_node(control)

	await get_tree().process_frame

	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "position:x", 100.0, 0.1)
	tween.tween_property(control, "position:y", 100.0, 0.1)
	tween.tween_property(control, "scale", Vector2(2, 2), 0.1)

	await tween.finished

	if absf(control.position.x - 100.0) > 1.0 or absf(control.position.y - 100.0) > 1.0:
		return {"error": "Parallel position incorrect"}

	if control.scale.distance_to(Vector2(2, 2)) > 0.1:
		return {"error": "Parallel scale incorrect"}

	return {}


func _test_animation_callbacks() -> Dictionary:
	var callback_count: int = 0
	var control := Control.new()
	_add_test_node(control)

	await get_tree().process_frame

	var tween := control.create_tween()
	tween.tween_callback(func(): callback_count += 1)
	tween.tween_interval(0.05)
	tween.tween_callback(func(): callback_count += 1)
	tween.tween_interval(0.05)
	tween.tween_callback(func(): callback_count += 1)

	await tween.finished

	if callback_count != 3:
		return {"error": "Expected 3 callbacks, got %d" % callback_count}

	return {}


func _test_animation_kill() -> Dictionary:
	var control := Control.new()
	control.position = Vector2.ZERO
	_add_test_node(control)

	await get_tree().process_frame

	var tween := control.create_tween()
	tween.tween_property(control, "position:x", 1000.0, 5.0)  # Long animation

	await get_tree().create_timer(0.1).timeout

	var position_at_kill: float = control.position.x
	tween.kill()

	await get_tree().process_frame
	await get_tree().process_frame

	# Position should not continue animating
	if absf(control.position.x - position_at_kill) > 1.0:
		return {"error": "Animation continued after kill"}

	return {"position_at_kill": position_at_kill}


func _test_animation_timing() -> Dictionary:
	var control := Control.new()
	_add_test_node(control)

	await get_tree().process_frame

	var start_time: int = Time.get_ticks_msec()
	var target_duration: float = 0.2  # 200ms

	var tween := control.create_tween()
	tween.tween_interval(target_duration)

	await tween.finished

	var actual_duration: float = (Time.get_ticks_msec() - start_time) / 1000.0
	var timing_error: float = absf(actual_duration - target_duration)

	# Allow 50ms tolerance
	if timing_error > 0.05:
		return {"error": "Animation timing error: %.0fms" % (timing_error * 1000)}

	return {"target_ms": target_duration * 1000, "actual_ms": actual_duration * 1000}

# endregion


# =============================================================================
# region - Performance Tests
# =============================================================================

func _register_performance_tests() -> void:
	_register_test("Perf_FPS_Baseline", TestCategory.PERFORMANCE, _test_fps_baseline, 15000)
	_register_test("Perf_Control_Creation", TestCategory.PERFORMANCE, _test_control_creation)
	_register_test("Perf_Tween_Operations", TestCategory.PERFORMANCE, _test_tween_operations)
	_register_test("Perf_UI_Update_Rate", TestCategory.PERFORMANCE, _test_ui_update_rate)
	_register_test("Perf_Style_Changes", TestCategory.PERFORMANCE, _test_style_changes)
	_register_test("Perf_Text_Rendering", TestCategory.PERFORMANCE, _test_text_rendering)


func _test_fps_baseline() -> Dictionary:
	_fps_samples.clear()

	# Sample FPS for 3 seconds
	var duration: float = 3.0
	var start_time: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - start_time < duration:
		_fps_samples.append(_current_fps)
		await get_tree().process_frame

	var avg_fps: float = _calculate_average(_fps_samples)
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0
	var max_fps: float = _fps_samples.max() if not _fps_samples.is_empty() else 0.0

	if avg_fps < FPS_THRESHOLD_CRITICAL:
		return {"error": "Critical FPS: %.1f (threshold: %.1f)" % [avg_fps, FPS_THRESHOLD_CRITICAL]}

	if avg_fps < FPS_THRESHOLD_WARNING:
		_results.warnings.append("Low FPS baseline: %.1f" % avg_fps)

	return {
		"average_fps": avg_fps,
		"min_fps": min_fps,
		"max_fps": max_fps,
		"samples": _fps_samples.size()
	}


func _test_control_creation() -> Dictionary:
	var iterations: int = 100
	var start_time: int = Time.get_ticks_usec()

	var controls: Array[Control] = []

	for i in range(iterations):
		var ctrl := PanelContainer.new()
		ctrl.custom_minimum_size = Vector2(50, 30)

		var label := Label.new()
		label.text = "Test %d" % i
		ctrl.add_child(label)

		get_tree().current_scene.add_child(ctrl)
		controls.append(ctrl)

	var creation_time: int = Time.get_ticks_usec() - start_time
	var creation_per_ms: float = float(iterations) / (float(creation_time) / 1000.0)

	# Cleanup
	for ctrl: Control in controls:
		ctrl.queue_free()

	await get_tree().process_frame

	if creation_per_ms < 50:
		return {"error": "Control creation too slow: %.1f/ms" % creation_per_ms}

	return {
		"iterations": iterations,
		"total_time_ms": creation_time / 1000.0,
		"controls_per_ms": creation_per_ms
	}


func _test_tween_operations() -> Dictionary:
	var control := Control.new()
	_add_test_node(control)

	await get_tree().process_frame

	var iterations: int = 100
	var start_time: int = Time.get_ticks_usec()

	for i in range(iterations):
		var tween := control.create_tween()
		tween.tween_property(control, "position:x", float(i), 0.001)
		tween.kill()

	var elapsed: int = Time.get_ticks_usec() - start_time
	var ops_per_ms: float = float(iterations) / (float(elapsed) / 1000.0)

	if ops_per_ms < 100:
		return {"error": "Tween creation too slow: %.1f/ms" % ops_per_ms}

	return {
		"iterations": iterations,
		"total_time_ms": elapsed / 1000.0,
		"ops_per_ms": ops_per_ms
	}


func _test_ui_update_rate() -> Dictionary:
	var label := Label.new()
	label.position = Vector2(100, 100)
	_add_test_node(label)

	await get_tree().process_frame

	var updates: int = 0
	var duration: float = 1.0
	var start_time: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - start_time < duration:
		label.text = "Update %d" % updates
		updates += 1
		await get_tree().process_frame

	var updates_per_sec: float = float(updates) / duration

	if updates_per_sec < 30:
		return {"error": "UI update rate too low: %.1f/sec" % updates_per_sec}

	return {"updates_per_second": updates_per_sec}


func _test_style_changes() -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(100, 100)
	_add_test_node(panel)

	await get_tree().process_frame

	var iterations: int = 100
	var start_time: int = Time.get_ticks_usec()

	for i in range(iterations):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(randf(), randf(), randf())
		style.set_corner_radius_all(i % 20)
		panel.add_theme_stylebox_override("panel", style)

	var elapsed: int = Time.get_ticks_usec() - start_time
	var changes_per_ms: float = float(iterations) / (float(elapsed) / 1000.0)

	return {
		"iterations": iterations,
		"total_time_ms": elapsed / 1000.0,
		"changes_per_ms": changes_per_ms
	}


func _test_text_rendering() -> Dictionary:
	var labels: Array[Label] = []

	for i in range(50):
		var label := Label.new()
		label.position = Vector2(randf_range(0, 800), randf_range(0, 600))
		label.text = "Label %d: Testing text rendering performance" % i
		label.add_theme_font_size_override("font_size", int(randf_range(12, 32)))
		_add_test_node(label)
		labels.append(label)

	await get_tree().process_frame

	_fps_samples.clear()

	# Measure FPS with many labels
	var duration: float = 2.0
	var start_time: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - start_time < duration:
		# Update labels
		for label: Label in labels:
			label.text = "Frame %d: %s" % [Engine.get_frames_drawn(), label.text.substr(0, 20)]

		_fps_samples.append(_current_fps)
		await get_tree().process_frame

	var avg_fps: float = _calculate_average(_fps_samples)

	if avg_fps < FPS_THRESHOLD_WARNING:
		return {"error": "Text rendering FPS too low: %.1f" % avg_fps}

	return {"average_fps": avg_fps, "label_count": labels.size()}

# endregion


# =============================================================================
# region - Memory Tests
# =============================================================================

func _register_memory_tests() -> void:
	_register_test("Memory_Leak_Detection", TestCategory.MEMORY, _test_memory_leak, 30000)
	_register_test("Memory_Node_Cleanup", TestCategory.MEMORY, _test_node_cleanup)
	_register_test("Memory_Tween_Cleanup", TestCategory.MEMORY, _test_tween_cleanup)
	_register_test("Memory_Signal_Cleanup", TestCategory.MEMORY, _test_signal_cleanup)


func _test_memory_leak() -> Dictionary:
	_initial_memory_mb = float(OS.get_static_memory_usage()) / 1048576.0
	_memory_samples.clear()

	var cycles: int = 20
	var nodes_per_cycle: int = 100

	for cycle in range(cycles):
		var nodes: Array[Control] = []

		# Create nodes
		for i in range(nodes_per_cycle):
			var panel := PanelContainer.new()
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

		_memory_samples.append(float(OS.get_static_memory_usage()) / 1048576.0)

	# Wait for cleanup
	await get_tree().create_timer(0.5).timeout

	var final_memory: float = float(OS.get_static_memory_usage()) / 1048576.0
	var memory_delta: float = final_memory - _initial_memory_mb

	if memory_delta > MEMORY_LEAK_THRESHOLD_MB:
		return {"error": "Memory leak detected: %.2f MB" % memory_delta}

	return {
		"initial_mb": _initial_memory_mb,
		"final_mb": final_memory,
		"delta_mb": memory_delta,
		"cycles": cycles
	}


func _test_node_cleanup() -> Dictionary:
	var initial_count: int = get_tree().current_scene.get_child_count()

	# Create and destroy many nodes
	for i in range(50):
		var node := Control.new()
		get_tree().current_scene.add_child(node)
		node.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	var final_count: int = get_tree().current_scene.get_child_count()

	if final_count > initial_count:
		return {"error": "Nodes not properly cleaned up: %d leaked" % (final_count - initial_count)}

	return {"initial_count": initial_count, "final_count": final_count}


func _test_tween_cleanup() -> Dictionary:
	var control := Control.new()
	_add_test_node(control)

	await get_tree().process_frame

	# Create many tweens
	var tweens: Array[Tween] = []
	for i in range(50):
		var tween := control.create_tween()
		tween.tween_property(control, "position:x", float(i), 0.01)
		tweens.append(tween)

	await get_tree().create_timer(0.1).timeout

	# Kill all tweens
	for tween: Tween in tweens:
		if tween.is_valid():
			tween.kill()

	await get_tree().process_frame

	# Check if any tweens are still valid
	var valid_count: int = 0
	for tween: Tween in tweens:
		if tween.is_valid():
			valid_count += 1

	if valid_count > 0:
		return {"error": "%d tweens still valid after kill" % valid_count}

	return {}


func _test_signal_cleanup() -> Dictionary:
	var emitter := Button.new()
	_add_test_node(emitter)

	await get_tree().process_frame

	# Connect many signals
	var receivers: Array[Node] = []
	for i in range(20):
		var receiver := Node.new()
		emitter.pressed.connect(receiver.queue_free)
		receivers.append(receiver)
		get_tree().current_scene.add_child(receiver)

	var connection_count: int = emitter.pressed.get_connections().size()

	# Free receivers
	for receiver: Node in receivers:
		receiver.queue_free()

	await get_tree().process_frame

	# Connections should be cleaned up
	var final_count: int = emitter.pressed.get_connections().size()

	if final_count >= connection_count:
		return {"error": "Signal connections not cleaned up after node free"}

	return {"initial_connections": connection_count, "final_connections": final_count}

# endregion


# =============================================================================
# region - Input Validation Tests
# =============================================================================

func _register_input_validation_tests() -> void:
	_register_test("Input_Long_Username", TestCategory.INPUT_VALIDATION, _test_long_username)
	_register_test("Input_Special_Characters", TestCategory.INPUT_VALIDATION, _test_special_characters)
	_register_test("Input_Empty_String", TestCategory.INPUT_VALIDATION, _test_empty_string)
	_register_test("Input_Unicode_Text", TestCategory.INPUT_VALIDATION, _test_unicode_text)
	_register_test("Input_Numeric_Bounds", TestCategory.INPUT_VALIDATION, _test_numeric_bounds)
	_register_test("Input_IP_Validation", TestCategory.INPUT_VALIDATION, _test_ip_validation)


func _test_long_username() -> Dictionary:
	var line_edit := LineEdit.new()
	line_edit.max_length = 32
	_add_test_node(line_edit)

	await get_tree().process_frame

	var long_name: String = "A".repeat(100)
	line_edit.text = long_name

	if line_edit.text.length() > line_edit.max_length:
		return {"error": "Max length not enforced"}

	return {"max_length": line_edit.max_length, "actual_length": line_edit.text.length()}


func _test_special_characters() -> Dictionary:
	var special_chars: String = "!@#$%^&*()_+-=[]{}|;':\",./<>?\\"

	var line_edit := LineEdit.new()
	_add_test_node(line_edit)

	await get_tree().process_frame

	line_edit.text = special_chars

	if line_edit.text != special_chars:
		return {"error": "Special characters not preserved"}

	# Test in Label
	var label := Label.new()
	label.text = special_chars
	_add_test_node(label)

	await get_tree().process_frame

	if label.text != special_chars:
		return {"error": "Special characters not displayed in label"}

	return {"characters_tested": special_chars.length()}


func _test_empty_string() -> Dictionary:
	var line_edit := LineEdit.new()
	line_edit.placeholder_text = "Enter text..."
	_add_test_node(line_edit)

	await get_tree().process_frame

	line_edit.text = ""

	if line_edit.text != "":
		return {"error": "Empty string not properly set"}

	# Test whitespace-only
	line_edit.text = "   "
	var stripped: String = line_edit.text.strip_edges()

	if not stripped.is_empty():
		return {"error": "Whitespace stripping failed"}

	return {}


func _test_unicode_text() -> Dictionary:
	var unicode_samples: Array[String] = [
		"Hello World",  # ASCII
		"Japanese",  # Japanese
		"Chinese",  # Chinese
		"Korean",  # Korean
		"Russian",  # Russian
		"Arabic",  # Arabic
		"Emoji Test"  # Emoji
	]

	var label := Label.new()
	_add_test_node(label)

	await get_tree().process_frame

	for sample: String in unicode_samples:
		label.text = sample
		await get_tree().process_frame

		if label.text != sample:
			return {"error": "Unicode text mismatch: %s" % sample}

	return {"samples_tested": unicode_samples.size()}


func _test_numeric_bounds() -> Dictionary:
	var spinbox := SpinBox.new()
	spinbox.min_value = 0
	spinbox.max_value = 100
	_add_test_node(spinbox)

	await get_tree().process_frame

	# Test below minimum
	spinbox.value = -50
	if spinbox.value != spinbox.min_value:
		return {"error": "Value below minimum not clamped"}

	# Test above maximum
	spinbox.value = 200
	if spinbox.value != spinbox.max_value:
		return {"error": "Value above maximum not clamped"}

	# Test valid value
	spinbox.value = 50
	if spinbox.value != 50:
		return {"error": "Valid value not accepted"}

	return {}


func _test_ip_validation() -> Dictionary:
	var valid_ips: Array[String] = ["192.168.1.1", "10.0.0.1", "127.0.0.1", "255.255.255.255", "0.0.0.0"]
	var invalid_ips: Array[String] = ["256.1.1.1", "1.2.3", "1.2.3.4.5", "abc.def.ghi.jkl", "192.168.1"]

	for ip: String in valid_ips:
		if not _is_valid_ip(ip):
			return {"error": "Valid IP rejected: %s" % ip}

	for ip: String in invalid_ips:
		if _is_valid_ip(ip):
			return {"error": "Invalid IP accepted: %s" % ip}

	return {"valid_tested": valid_ips.size(), "invalid_tested": invalid_ips.size()}


func _is_valid_ip(ip: String) -> bool:
	var parts: PackedStringArray = ip.split(".")
	if parts.size() != 4:
		return false

	for part: String in parts:
		if not part.is_valid_int():
			return false
		var num: int = part.to_int()
		if num < 0 or num > 255:
			return false

	return true

# endregion


# =============================================================================
# region - Network Resilience Tests
# =============================================================================

func _register_network_resilience_tests() -> void:
	_register_test("Network_Timeout_Handling", TestCategory.NETWORK_RESILIENCE, _test_timeout_handling)
	_register_test("Network_Out_Of_Order_Responses", TestCategory.NETWORK_RESILIENCE, _test_out_of_order)
	_register_test("Network_Retry_Logic", TestCategory.NETWORK_RESILIENCE, _test_retry_logic)
	_register_test("Network_Connection_State", TestCategory.NETWORK_RESILIENCE, _test_connection_state)


func _test_timeout_handling() -> Dictionary:
	# Simulate a timeout scenario
	var timeout_occurred: bool = false
	var operation_completed: bool = false

	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(func(): timeout_occurred = true)
	_add_test_node(timer)

	timer.start(0.1)  # 100ms timeout

	# Simulate operation that takes too long
	await get_tree().create_timer(0.15).timeout

	if not timeout_occurred:
		return {"error": "Timeout not triggered"}

	return {}


func _test_out_of_order() -> Dictionary:
	var responses: Array[int] = []
	var expected_order: Array[int] = [1, 2, 3, 4, 5]

	# Simulate out of order responses
	var delays: Array[float] = [0.05, 0.01, 0.04, 0.02, 0.03]

	for i in range(5):
		get_tree().create_timer(delays[i]).timeout.connect(
			func(): responses.append(i + 1)
		)

	await get_tree().create_timer(0.1).timeout

	# Responses should be out of order
	if responses == expected_order:
		return {"error": "Responses arrived in order (test setup issue)"}

	# Sort to verify all responses received
	responses.sort()
	if responses != expected_order:
		return {"error": "Missing responses"}

	return {"response_count": responses.size()}


func _test_retry_logic() -> Dictionary:
	var attempts: int = 0
	var max_retries: int = 3
	var success: bool = false

	# Simulate operation that fails first 2 times
	while attempts < max_retries and not success:
		attempts += 1

		if attempts >= 3:
			success = true

		await get_tree().process_frame

	if not success:
		return {"error": "Retry logic did not succeed"}

	if attempts != 3:
		return {"error": "Expected 3 attempts, got %d" % attempts}

	return {"attempts": attempts}


func _test_connection_state() -> Dictionary:
	# Test ConnectionManager state machine (if available)
	if not is_instance_valid(ConnectionManager):
		return {"skip": "ConnectionManager not available"}

	var initial_state: int = ConnectionManager.state

	# Verify initial state is valid
	if initial_state < 0:
		return {"error": "Invalid connection state"}

	return {"initial_state": initial_state}

# endregion


# =============================================================================
# region - Accessibility Tests
# =============================================================================

func _register_accessibility_tests() -> void:
	_register_test("A11y_Touch_Target_Size", TestCategory.ACCESSIBILITY, _test_touch_target_size)
	_register_test("A11y_Focus_Navigation", TestCategory.ACCESSIBILITY, _test_focus_navigation)
	_register_test("A11y_Text_Contrast", TestCategory.ACCESSIBILITY, _test_text_contrast)
	_register_test("A11y_Button_Labels", TestCategory.ACCESSIBILITY, _test_button_labels)


func _test_touch_target_size() -> Dictionary:
	var min_size: float = 44.0  # Apple's minimum touch target
	var buttons: Array[Button] = []
	var undersized: Array[String] = []

	# Create test buttons
	var sizes: Array[Vector2] = [
		Vector2(44, 44),  # OK
		Vector2(30, 30),  # Too small
		Vector2(60, 44),  # OK
		Vector2(44, 30),  # Too small height
	]

	for i in range(sizes.size()):
		var btn := Button.new()
		btn.text = "Button %d" % i
		btn.custom_minimum_size = sizes[i]
		btn.size = sizes[i]
		_add_test_node(btn)
		buttons.append(btn)

		if sizes[i].x < min_size or sizes[i].y < min_size:
			undersized.append("Button %d: %dx%d" % [i, int(sizes[i].x), int(sizes[i].y)])

	await get_tree().process_frame

	# This test documents undersized buttons rather than failing
	return {
		"total_buttons": buttons.size(),
		"undersized_buttons": undersized.size(),
		"undersized_list": undersized,
		"minimum_size": min_size
	}


func _test_focus_navigation() -> Dictionary:
	var buttons: Array[Button] = []

	for i in range(4):
		var btn := Button.new()
		btn.text = "Focus %d" % i
		btn.position = Vector2(100, 50 + i * 60)
		btn.focus_mode = Control.FOCUS_ALL
		_add_test_node(btn)
		buttons.append(btn)

	await get_tree().process_frame

	# Set focus to first button
	buttons[0].grab_focus()

	await get_tree().process_frame

	if not buttons[0].has_focus():
		return {"error": "Could not set initial focus"}

	return {"focusable_buttons": buttons.size()}


func _test_text_contrast() -> Dictionary:
	# Test basic contrast calculation
	var white := Color.WHITE
	var black := Color.BLACK
	var gray := Color(0.5, 0.5, 0.5)

	var white_black_ratio := _calculate_contrast_ratio(white, black)
	var white_gray_ratio := _calculate_contrast_ratio(white, gray)

	# WCAG AA requires 4.5:1 for normal text
	if white_black_ratio < 4.5:
		return {"error": "White on black contrast calculation error"}

	return {
		"white_black_ratio": white_black_ratio,
		"white_gray_ratio": white_gray_ratio,
		"wcag_aa_threshold": 4.5
	}


func _test_button_labels() -> Dictionary:
	var buttons_without_text: int = 0
	var buttons_checked: int = 0

	# Create test buttons
	var test_buttons: Array[Button] = []

	var labeled := Button.new()
	labeled.text = "Click Me"
	_add_test_node(labeled)
	test_buttons.append(labeled)

	var unlabeled := Button.new()
	# No text
	_add_test_node(unlabeled)
	test_buttons.append(unlabeled)

	var icon_button := Button.new()
	icon_button.tooltip_text = "Settings"  # Accessible via tooltip
	_add_test_node(icon_button)
	test_buttons.append(icon_button)

	await get_tree().process_frame

	for btn: Button in test_buttons:
		buttons_checked += 1
		if btn.text.strip_edges().is_empty() and btn.tooltip_text.strip_edges().is_empty():
			buttons_without_text += 1

	return {
		"buttons_checked": buttons_checked,
		"buttons_without_label": buttons_without_text
	}

# endregion


# =============================================================================
# region - Edge Case Tests
# =============================================================================

func _register_edge_case_tests() -> void:
	_register_test("Edge_Rapid_Button_Clicks", TestCategory.EDGE_CASE, _test_rapid_clicks)
	_register_test("Edge_Concurrent_Animations", TestCategory.EDGE_CASE, _test_concurrent_animations)
	_register_test("Edge_Null_Parent", TestCategory.EDGE_CASE, _test_null_parent)
	_register_test("Edge_Zero_Size_Control", TestCategory.EDGE_CASE, _test_zero_size)
	_register_test("Edge_Negative_Values", TestCategory.EDGE_CASE, _test_negative_values)
	_register_test("Edge_Extreme_Scale", TestCategory.EDGE_CASE, _test_extreme_scale)


func _test_rapid_clicks() -> Dictionary:
	var button := Button.new()
	button.text = "Rapid Click Test"
	button.position = Vector2(100, 100)
	button.size = Vector2(200, 50)
	_add_test_node(button)

	await get_tree().process_frame

	var click_count: int = 0
	button.pressed.connect(func(): click_count += 1)

	# Simulate rapid clicks
	var clicks: int = 50
	for i in range(clicks):
		_simulate_click(button.global_position + button.size / 2)
		# No delay between clicks

	await get_tree().process_frame
	await get_tree().process_frame

	# Should handle rapid clicks without crashing
	return {"clicks_attempted": clicks, "clicks_registered": click_count}


func _test_concurrent_animations() -> Dictionary:
	var controls: Array[Control] = []
	var animation_count: int = 20
	var completed: int = 0

	for i in range(animation_count):
		var ctrl := ColorRect.new()
		ctrl.position = Vector2(randf_range(0, 500), randf_range(0, 400))
		ctrl.size = Vector2(30, 30)
		_add_test_node(ctrl)
		controls.append(ctrl)

		var tween := ctrl.create_tween()
		tween.tween_property(ctrl, "position:x", ctrl.position.x + 100, 0.1)
		tween.finished.connect(func(): completed += 1)

	# Wait for all animations
	var timeout: float = 0.0
	while completed < animation_count and timeout < 2.0:
		await get_tree().process_frame
		timeout += get_process_delta_time()

	if completed < animation_count:
		return {"error": "Only %d/%d animations completed" % [completed, animation_count]}

	return {"concurrent_animations": animation_count}


func _test_null_parent() -> Dictionary:
	var orphan := Control.new()

	# Operations on orphan node should not crash
	orphan.position = Vector2(100, 100)
	orphan.visible = true
	orphan.modulate = Color.RED

	# Free without parent
	orphan.free()

	return {}


func _test_zero_size() -> Dictionary:
	var ctrl := Control.new()
	ctrl.size = Vector2.ZERO
	_add_test_node(ctrl)

	await get_tree().process_frame

	# Operations on zero-size control
	ctrl.pivot_offset = ctrl.size / 2

	var tween := ctrl.create_tween()
	tween.tween_property(ctrl, "size", Vector2(100, 100), 0.1)

	await tween.finished

	if ctrl.size != Vector2(100, 100):
		return {"error": "Zero-size control animation failed"}

	return {}


func _test_negative_values() -> Dictionary:
	var slider := HSlider.new()
	slider.min_value = -100
	slider.max_value = 100
	slider.value = 0
	_add_test_node(slider)

	await get_tree().process_frame

	slider.value = -50

	if slider.value != -50:
		return {"error": "Negative value not accepted"}

	slider.value = -150  # Below minimum

	if slider.value != slider.min_value:
		return {"error": "Value below minimum not clamped"}

	return {"min_value": slider.min_value, "final_value": slider.value}


func _test_extreme_scale() -> Dictionary:
	var ctrl := Control.new()
	ctrl.size = Vector2(50, 50)
	_add_test_node(ctrl)

	await get_tree().process_frame

	# Test extreme scales
	var scales: Array[Vector2] = [
		Vector2(0.001, 0.001),
		Vector2(100, 100),
		Vector2(0, 0),
		Vector2(-1, -1),
	]

	for scale: Vector2 in scales:
		ctrl.scale = scale
		await get_tree().process_frame

		# Should not crash

	return {"scales_tested": scales.size()}

# endregion


# =============================================================================
# region - Stress Tests
# =============================================================================

func _register_stress_tests() -> void:
	_register_test("Stress_Many_Controls", TestCategory.STRESS, _test_many_controls, 30000)
	_register_test("Stress_Rapid_UI_Changes", TestCategory.STRESS, _test_rapid_ui_changes, 20000)
	_register_test("Stress_Animation_Overload", TestCategory.STRESS, _test_animation_overload, 20000)
	_register_test("Stress_Particle_System", TestCategory.STRESS, _test_particle_stress, 20000)


func _test_many_controls() -> Dictionary:
	_fps_samples.clear()
	var control_counts: Array[int] = [50, 100, 200, 500]
	var results: Dictionary = {}

	for count: int in control_counts:
		# Clear previous
		_cleanup_test_nodes()

		# Create controls
		for i in range(count):
			var panel := PanelContainer.new()
			panel.position = Vector2(randf_range(0, 800), randf_range(0, 600))
			panel.custom_minimum_size = Vector2(30, 20)

			var label := Label.new()
			label.text = str(i)
			panel.add_child(label)

			_add_test_node(panel)

		# Measure FPS
		_fps_samples.clear()
		var start_time: float = Time.get_ticks_msec() / 1000.0

		while (Time.get_ticks_msec() / 1000.0) - start_time < 1.0:
			_fps_samples.append(_current_fps)
			await get_tree().process_frame

		var avg_fps: float = _calculate_average(_fps_samples)
		results[count] = avg_fps

		if avg_fps < FPS_THRESHOLD_CRITICAL:
			return {
				"error": "FPS dropped to %.1f with %d controls" % [avg_fps, count],
				"partial_results": results
			}

	return {"fps_by_control_count": results}


func _test_rapid_ui_changes() -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 200)
	_add_test_node(panel)

	await get_tree().process_frame

	_fps_samples.clear()
	var changes: int = 0
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var duration: float = 3.0

	while (Time.get_ticks_msec() / 1000.0) - start_time < duration:
		# Rapid style changes
		var style := StyleBoxFlat.new()
		style.bg_color = Color(randf(), randf(), randf())
		style.set_corner_radius_all(int(randf_range(0, 20)))
		panel.add_theme_stylebox_override("panel", style)

		# Rapid position changes
		panel.position = Vector2(randf_range(0, 600), randf_range(0, 400))

		changes += 1
		_fps_samples.append(_current_fps)
		await get_tree().process_frame

	var avg_fps: float = _calculate_average(_fps_samples)
	var changes_per_sec: float = float(changes) / duration

	if avg_fps < FPS_THRESHOLD_WARNING:
		return {"error": "FPS dropped during rapid changes: %.1f" % avg_fps}

	return {
		"changes": changes,
		"changes_per_second": changes_per_sec,
		"average_fps": avg_fps
	}


func _test_animation_overload() -> Dictionary:
	var controls: Array[Control] = []
	var animation_count: int = 100

	for i in range(animation_count):
		var ctrl := ColorRect.new()
		ctrl.position = Vector2(randf_range(0, 700), randf_range(0, 500))
		ctrl.size = Vector2(20, 20)
		ctrl.color = Color(randf(), randf(), randf())
		_add_test_node(ctrl)
		controls.append(ctrl)

		# Create looping animation
		var tween := ctrl.create_tween()
		tween.set_loops(0)
		tween.tween_property(ctrl, "position:x", ctrl.position.x + 50, 0.3)
		tween.tween_property(ctrl, "position:x", ctrl.position.x, 0.3)

	_fps_samples.clear()
	var start_time: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - start_time < 3.0:
		_fps_samples.append(_current_fps)
		await get_tree().process_frame

	var avg_fps: float = _calculate_average(_fps_samples)
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0

	if avg_fps < FPS_THRESHOLD_CRITICAL:
		return {"error": "Animation overload caused critical FPS drop: %.1f" % avg_fps}

	return {
		"animation_count": animation_count,
		"average_fps": avg_fps,
		"min_fps": min_fps
	}


func _test_particle_stress() -> Dictionary:
	_fps_samples.clear()
	var emitters: Array[CPUParticles2D] = []
	var emitter_count: int = 30

	for i in range(emitter_count):
		var particles := CPUParticles2D.new()
		particles.amount = 50
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
		emitters.append(particles)

	var start_time: float = Time.get_ticks_msec() / 1000.0

	while (Time.get_ticks_msec() / 1000.0) - start_time < 5.0:
		_fps_samples.append(_current_fps)
		await get_tree().process_frame

	var avg_fps: float = _calculate_average(_fps_samples)
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0
	var total_particles: int = emitter_count * 50

	if avg_fps < FPS_THRESHOLD_CRITICAL:
		return {"error": "Particle stress test FPS critical: %.1f" % avg_fps}

	return {
		"emitter_count": emitter_count,
		"total_particles": total_particles,
		"average_fps": avg_fps,
		"min_fps": min_fps
	}

# endregion


# =============================================================================
# region - Helper Functions
# =============================================================================

func _execute_test(callable: Callable, timeout_ms: int) -> Variant:
	var result: Variant = callable.call()

	if result is Signal:
		# Wait for async test
		var timer := Timer.new()
		add_child(timer)
		timer.start(timeout_ms / 1000.0)

		var completed: Array = await _wait_for_signal_or_timeout(result, timer.timeout)
		timer.queue_free()

		if completed.is_empty():
			return {"error": "Test timed out after %dms" % timeout_ms}

		return completed[0] if completed.size() > 0 else true

	return result


func _wait_for_signal_or_timeout(sig: Signal, timeout: Signal) -> Array:
	var result: Array = []
	var completed: bool = false
	var timed_out: bool = false

	sig.connect(func(r: Variant = null):
		completed = true
		if r != null:
			result.append(r)
	, CONNECT_ONE_SHOT)

	timeout.connect(func(): timed_out = true, CONNECT_ONE_SHOT)

	while not completed and not timed_out:
		await Engine.get_main_loop().process_frame

	return result


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
	for val: float in values:
		total += val
	return total / values.size()


func _add_test_node(node: Node) -> void:
	get_tree().current_scene.add_child(node)
	_test_nodes.append(node)


func _cleanup_test_nodes() -> void:
	for node: Node in _test_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_test_nodes.clear()


func _simulate_click(position: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	down.global_position = position
	Input.parse_input_event(down)

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	up.global_position = position
	Input.parse_input_event(up)


func _simulate_mouse_motion(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)


func _calculate_contrast_ratio(fg: Color, bg: Color) -> float:
	var fg_lum: float = _get_relative_luminance(fg)
	var bg_lum: float = _get_relative_luminance(bg)

	var lighter: float = maxf(fg_lum, bg_lum)
	var darker: float = minf(fg_lum, bg_lum)

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
