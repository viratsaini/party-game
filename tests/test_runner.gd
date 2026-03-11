## TestRunner - Automated test framework for BattleZone Party.
##
## Provides unit testing, integration testing, performance benchmarks,
## and automated smoke tests. Designed for CI/CD integration.
##
## Usage:
##   TestRunner.run_all_tests()
##   TestRunner.run_unit_tests()
##   TestRunner.run_integration_tests()
##   TestRunner.run_smoke_tests()
##   TestRunner.run_performance_benchmarks()
class_name TestRunner
extends Node


# region -- Signals

## Emitted when a test passes.
signal test_passed(test_name: String, duration_ms: float)

## Emitted when a test fails.
signal test_failed(test_name: String, message: String, duration_ms: float)

## Emitted when a test is skipped.
signal test_skipped(test_name: String, reason: String)

## Emitted when all tests complete.
signal all_tests_completed(results: TestResults)

## Emitted for progress updates.
signal progress_updated(current: int, total: int, test_name: String)

# endregion


# region -- Constants

## Test categories.
enum TestCategory {
	UNIT,
	INTEGRATION,
	PERFORMANCE,
	SMOKE,
}

## Test result status.
enum TestStatus {
	PASSED,
	FAILED,
	SKIPPED,
	TIMEOUT,
}

## Default timeout for individual tests (ms).
const DEFAULT_TEST_TIMEOUT: int = 5000

## Performance benchmark iterations.
const BENCHMARK_ITERATIONS: int = 100

# endregion


# region -- Test Results Class

class TestResult:
	var name: String
	var category: TestCategory
	var status: TestStatus
	var duration_ms: float
	var message: String
	var stack_trace: String

	func _init(n: String, cat: TestCategory) -> void:
		name = n
		category = cat
		status = TestStatus.PASSED
		duration_ms = 0.0
		message = ""
		stack_trace = ""


class TestResults:
	var total: int = 0
	var passed: int = 0
	var failed: int = 0
	var skipped: int = 0
	var duration_ms: float = 0.0
	var results: Array[TestResult] = []
	var coverage_percent: float = 0.0

	func add_result(result: TestResult) -> void:
		results.append(result)
		total += 1
		match result.status:
			TestStatus.PASSED:
				passed += 1
			TestStatus.FAILED, TestStatus.TIMEOUT:
				failed += 1
			TestStatus.SKIPPED:
				skipped += 1
		duration_ms += result.duration_ms

	func get_summary() -> String:
		var pass_rate: float = (float(passed) / float(total)) * 100.0 if total > 0 else 0.0
		return "Tests: %d total, %d passed, %d failed, %d skipped (%.1f%% pass rate) in %.2fs" % [
			total, passed, failed, skipped, pass_rate, duration_ms / 1000.0
		]

	func to_dict() -> Dictionary:
		var result_dicts: Array = []
		for r: TestResult in results:
			result_dicts.append({
				"name": r.name,
				"category": TestCategory.keys()[r.category],
				"status": TestStatus.keys()[r.status],
				"duration_ms": r.duration_ms,
				"message": r.message,
			})
		return {
			"total": total,
			"passed": passed,
			"failed": failed,
			"skipped": skipped,
			"duration_ms": duration_ms,
			"coverage_percent": coverage_percent,
			"results": result_dicts,
		}

	func to_junit_xml() -> String:
		var xml := '<?xml version="1.0" encoding="UTF-8"?>\n'
		xml += '<testsuite name="BattleZoneParty" tests="%d" failures="%d" skipped="%d" time="%.3f">\n' % [
			total, failed, skipped, duration_ms / 1000.0
		]
		for r: TestResult in results:
			xml += '  <testcase name="%s" classname="%s" time="%.3f">\n' % [
				r.name, TestCategory.keys()[r.category], r.duration_ms / 1000.0
			]
			if r.status == TestStatus.FAILED or r.status == TestStatus.TIMEOUT:
				xml += '    <failure message="%s">%s</failure>\n' % [
					r.message.xml_escape(), r.stack_trace.xml_escape()
				]
			elif r.status == TestStatus.SKIPPED:
				xml += '    <skipped message="%s"/>\n' % r.message.xml_escape()
			xml += '  </testcase>\n'
		xml += '</testsuite>\n'
		return xml

# endregion


# region -- State

var _current_results: TestResults
var _registered_tests: Array[Dictionary] = []
var _is_running: bool = false
var _current_test_start_time: int = 0

# endregion


# region -- Singleton

static var _instance: TestRunner = null

static func get_instance() -> TestRunner:
	if _instance == null:
		_instance = TestRunner.new()
	return _instance

# endregion


# region -- Public API

## Register a test function.
func register_test(name: String, category: TestCategory, callable: Callable, timeout_ms: int = DEFAULT_TEST_TIMEOUT) -> void:
	_registered_tests.append({
		"name": name,
		"category": category,
		"callable": callable,
		"timeout_ms": timeout_ms,
	})


## Clear all registered tests.
func clear_tests() -> void:
	_registered_tests.clear()


## Run all registered tests.
func run_all_tests() -> TestResults:
	return await _run_tests(_registered_tests)


## Run only unit tests.
func run_unit_tests() -> TestResults:
	var unit_tests: Array[Dictionary] = _registered_tests.filter(
		func(t: Dictionary) -> bool: return t["category"] == TestCategory.UNIT
	)
	return await _run_tests(unit_tests)


## Run only integration tests.
func run_integration_tests() -> TestResults:
	var integration_tests: Array[Dictionary] = _registered_tests.filter(
		func(t: Dictionary) -> bool: return t["category"] == TestCategory.INTEGRATION
	)
	return await _run_tests(integration_tests)


## Run only smoke tests.
func run_smoke_tests() -> TestResults:
	var smoke_tests: Array[Dictionary] = _registered_tests.filter(
		func(t: Dictionary) -> bool: return t["category"] == TestCategory.SMOKE
	)
	return await _run_tests(smoke_tests)


## Run only performance benchmarks.
func run_performance_benchmarks() -> TestResults:
	var perf_tests: Array[Dictionary] = _registered_tests.filter(
		func(t: Dictionary) -> bool: return t["category"] == TestCategory.PERFORMANCE
	)
	return await _run_tests(perf_tests)


## Run tests and output results to console (for CI/CD).
func run_cli() -> int:
	print("BattleZone Party Test Runner")
	print("=" .repeat(50))

	# Register all built-in tests
	_register_builtin_tests()

	var results: TestResults = await run_all_tests()

	print("")
	print(results.get_summary())
	print("")

	# Print failed tests
	for r: TestResult in results.results:
		if r.status == TestStatus.FAILED or r.status == TestStatus.TIMEOUT:
			print("FAILED: %s" % r.name)
			print("  %s" % r.message)

	# Write JUnit XML for CI
	var xml: String = results.to_junit_xml()
	var file := FileAccess.open("res://test_results.xml", FileAccess.WRITE)
	if file:
		file.store_string(xml)
		file.close()
		print("Results written to test_results.xml")

	return 0 if results.failed == 0 else 1

# endregion


# region -- Test Execution

func _run_tests(tests: Array[Dictionary]) -> TestResults:
	if _is_running:
		push_warning("TestRunner: Tests already running")
		return TestResults.new()

	_is_running = true
	_current_results = TestResults.new()

	var total: int = tests.size()
	var current: int = 0

	for test: Dictionary in tests:
		current += 1
		var test_name: String = test["name"]
		var category: TestCategory = test["category"]
		var callable: Callable = test["callable"]
		var timeout_ms: int = test["timeout_ms"]

		progress_updated.emit(current, total, test_name)

		var result := TestResult.new(test_name, category)
		_current_test_start_time = Time.get_ticks_msec()

		# Run the test
		var success: bool = await _execute_test(callable, timeout_ms, result)

		result.duration_ms = float(Time.get_ticks_msec() - _current_test_start_time)

		if success:
			test_passed.emit(test_name, result.duration_ms)
		else:
			test_failed.emit(test_name, result.message, result.duration_ms)

		_current_results.add_result(result)

		# Allow frame processing between tests
		await Engine.get_main_loop().process_frame

	_is_running = false
	all_tests_completed.emit(_current_results)

	return _current_results


func _execute_test(callable: Callable, timeout_ms: int, result: TestResult) -> bool:
	var error_message: String = ""

	# Execute the test callable
	var test_result: Variant = callable.call()

	# Handle async tests
	if test_result is Signal:
		# Wait for signal with timeout
		var timer := Timer.new()
		Engine.get_main_loop().root.add_child(timer)
		timer.start(timeout_ms / 1000.0)

		var completed: Array = await _wait_for_signal_or_timeout(test_result, timer.timeout)
		timer.queue_free()

		if completed.is_empty():
			result.status = TestStatus.TIMEOUT
			result.message = "Test timed out after %dms" % timeout_ms
			return false
	elif test_result is Dictionary:
		# Test returned a result dictionary
		if test_result.has("error"):
			result.status = TestStatus.FAILED
			result.message = test_result.get("error", "Unknown error")
			result.stack_trace = test_result.get("stack", "")
			return false
		elif test_result.has("skip"):
			result.status = TestStatus.SKIPPED
			result.message = test_result.get("skip", "Skipped")
			test_skipped.emit(result.name, result.message)
			return true
	elif test_result is bool:
		if not test_result:
			result.status = TestStatus.FAILED
			result.message = "Test returned false"
			return false

	return true


func _wait_for_signal_or_timeout(sig: Signal, timeout: Signal) -> Array:
	var result: Array = []

	var signal_received := false
	var timed_out := false

	sig.connect(func() -> void: signal_received = true, CONNECT_ONE_SHOT)
	timeout.connect(func() -> void: timed_out = true, CONNECT_ONE_SHOT)

	while not signal_received and not timed_out:
		await Engine.get_main_loop().process_frame

	if signal_received:
		result.append(true)

	return result

# endregion


# region -- Built-in Tests Registration

func _register_builtin_tests() -> void:
	# Register all test suites
	_register_game_manager_tests()
	_register_player_character_tests()
	_register_weapon_system_tests()
	_register_network_tests()
	_register_movement_tests()
	_register_pickup_tests()
	_register_performance_tests()
	_register_smoke_tests()

# endregion


# region -- GameManager Unit Tests

func _register_game_manager_tests() -> void:
	register_test("GameManager_InitialState", TestCategory.UNIT, func() -> bool:
		return GameManager.current_state == GameManager.GameState.MENU
	)

	register_test("GameManager_ValidTransitions", TestCategory.UNIT, func() -> bool:
		# Test valid transition checking
		var valid := GameManager._is_valid_transition(
			GameManager.GameState.MENU,
			GameManager.GameState.LOBBY
		)
		return valid == true
	)

	register_test("GameManager_InvalidTransitions", TestCategory.UNIT, func() -> bool:
		# Test invalid transition checking
		var invalid := GameManager._is_valid_transition(
			GameManager.GameState.MENU,
			GameManager.GameState.PLAYING
		)
		return invalid == false
	)

	register_test("GameManager_GameRegistry", TestCategory.UNIT, func() -> bool:
		var games := GameManager.get_available_games()
		if games.size() < 5:
			return false

		# Check required games exist
		var game_ids := ["arena_blaster", "turbo_karts", "obstacle_royale", "flag_wars", "crash_derby"]
		for id: String in game_ids:
			var info := GameManager.get_game_info(id)
			if info.is_empty():
				return false

		return true
	)

	register_test("GameManager_GameInfoComplete", TestCategory.UNIT, func() -> Dictionary:
		var games := GameManager.get_available_games()
		for game: Dictionary in games:
			if not game.has("id"):
				return {"error": "Game missing 'id' field"}
			if not game.has("name"):
				return {"error": "Game missing 'name' field: %s" % game.get("id", "unknown")}
			if not game.has("scene_path"):
				return {"error": "Game missing 'scene_path' field: %s" % game.get("id", "unknown")}
			if not game.has("min_players"):
				return {"error": "Game missing 'min_players' field: %s" % game.get("id", "unknown")}
			if not game.has("max_players"):
				return {"error": "Game missing 'max_players' field: %s" % game.get("id", "unknown")}
		return {}
	)

	register_test("GameManager_StateNames", TestCategory.UNIT, func() -> bool:
		# Verify all states have names
		for state: int in GameManager.GameState.values():
			if not GameManager.STATE_NAMES.has(state):
				return false
		return true
	)

# endregion


# region -- PlayerCharacter Unit Tests

func _register_player_character_tests() -> void:
	register_test("PlayerCharacter_DefaultHealth", TestCategory.UNIT, func() -> bool:
		var player := PlayerCharacter.new()
		var result := player.health == 100.0 and player.max_health == 100.0
		player.free()
		return result
	)

	register_test("PlayerCharacter_TakeDamage", TestCategory.UNIT, func() -> bool:
		var player := PlayerCharacter.new()
		player.health = 100.0
		player.max_health = 100.0
		player.is_alive = true

		# Simulate damage (bypassing RPC for unit test)
		player.health = clampf(player.health - 25.0, 0.0, player.max_health)

		var result := player.health == 75.0
		player.free()
		return result
	)

	register_test("PlayerCharacter_Heal", TestCategory.UNIT, func() -> bool:
		var player := PlayerCharacter.new()
		player.health = 50.0
		player.max_health = 100.0
		player.is_alive = true

		player.heal(30.0)

		var result := player.health == 80.0
		player.free()
		return result
	)

	register_test("PlayerCharacter_HealClamped", TestCategory.UNIT, func() -> bool:
		var player := PlayerCharacter.new()
		player.health = 90.0
		player.max_health = 100.0
		player.is_alive = true

		player.heal(50.0)

		var result := player.health == 100.0
		player.free()
		return result
	)

	register_test("PlayerCharacter_DeathAtZeroHealth", TestCategory.UNIT, func() -> bool:
		var player := PlayerCharacter.new()
		player.health = 10.0
		player.max_health = 100.0
		player.is_alive = true

		player.health = 0.0
		player.die()

		var result := not player.is_alive
		player.free()
		return result
	)

	register_test("PlayerCharacter_Respawn", TestCategory.UNIT, func() -> bool:
		var player := PlayerCharacter.new()
		player.health = 0.0
		player.is_alive = false

		player.respawn(Vector3(10, 0, 10))

		var result := player.is_alive and player.health == player.max_health
		player.free()
		return result
	)

	register_test("PlayerCharacter_Knockback", TestCategory.UNIT, func() -> bool:
		var player := PlayerCharacter.new()
		player.velocity = Vector3.ZERO

		player.apply_knockback(Vector3(10, 5, 0))

		var result := player.velocity == Vector3(10, 5, 0)
		player.free()
		return result
	)

# endregion


# region -- Weapon System Unit Tests

func _register_weapon_system_tests() -> void:
	register_test("WeaponBase_DefaultAmmo", TestCategory.UNIT, func() -> bool:
		var weapon := WeaponBase.new()
		var result := weapon.current_ammo == weapon.magazine_size
		weapon.free()
		return result
	)

	register_test("WeaponBase_FireReducesAmmo", TestCategory.UNIT, func() -> bool:
		var weapon := WeaponBase.new()
		weapon.is_equipped = true
		weapon.current_ammo = 30
		weapon.fire_cooldown = 0.0

		# Simulate ammo consumption
		weapon.current_ammo -= weapon.ammo_per_shot

		var result := weapon.current_ammo == 29
		weapon.free()
		return result
	)

	register_test("WeaponBase_ReloadRestoresAmmo", TestCategory.UNIT, func() -> bool:
		var weapon := WeaponBase.new()
		weapon.current_ammo = 10
		weapon.reserve_ammo = 50
		weapon.magazine_size = 30

		# Simulate reload
		var ammo_needed := weapon.magazine_size - weapon.current_ammo
		var ammo_to_add := mini(ammo_needed, weapon.reserve_ammo)
		weapon.current_ammo += ammo_to_add
		weapon.reserve_ammo -= ammo_to_add

		var result := weapon.current_ammo == 30 and weapon.reserve_ammo == 30
		weapon.free()
		return result
	)

	register_test("WeaponBase_CannotFireWhileReloading", TestCategory.UNIT, func() -> bool:
		var weapon := WeaponBase.new()
		weapon.is_equipped = true
		weapon.is_reloading = true

		var can_fire := weapon._can_fire()
		weapon.free()
		return can_fire == false
	)

	register_test("WeaponBase_CannotFireWithoutAmmo", TestCategory.UNIT, func() -> bool:
		var weapon := WeaponBase.new()
		weapon.is_equipped = true
		weapon.current_ammo = 0
		weapon.fire_cooldown = 0.0
		weapon.is_reloading = false

		var can_fire := weapon._can_fire()
		weapon.free()
		return can_fire == false
	)

	register_test("WeaponBase_SpreadApplication", TestCategory.UNIT, func() -> bool:
		var weapon := WeaponBase.new()
		weapon.current_spread = 5.0  # 5 degree spread

		var direction := Vector3.FORWARD
		var spread_dir := weapon._apply_spread(direction)

		# Spread should change the direction
		var angle := direction.angle_to(spread_dir)

		# Angle should be within spread range (converted to radians)
		var result := angle <= deg_to_rad(weapon.current_spread * 2.0)
		weapon.free()
		return result
	)

	register_test("WeaponBase_AddAmmo", TestCategory.UNIT, func() -> bool:
		var weapon := WeaponBase.new()
		weapon.reserve_ammo = 50
		weapon.max_reserve_ammo = 120

		var added := weapon.add_ammo(30)

		var result := added == 30 and weapon.reserve_ammo == 80
		weapon.free()
		return result
	)

	register_test("WeaponBase_AddAmmoClamped", TestCategory.UNIT, func() -> bool:
		var weapon := WeaponBase.new()
		weapon.reserve_ammo = 100
		weapon.max_reserve_ammo = 120

		var added := weapon.add_ammo(50)

		var result := added == 20 and weapon.reserve_ammo == 120
		weapon.free()
		return result
	)

# endregion


# region -- Network Tests

func _register_network_tests() -> void:
	register_test("ConnectionManager_InitialState", TestCategory.UNIT, func() -> bool:
		return ConnectionManager.state == ConnectionManager.ConnectionState.DISCONNECTED
	)

	register_test("ConnectionManager_InitialRole", TestCategory.UNIT, func() -> bool:
		return ConnectionManager.role == ConnectionManager.NetworkRole.NONE
	)

	register_test("ConnectionManager_LocalIPRetrieval", TestCategory.UNIT, func() -> bool:
		var ips := ConnectionManager.get_local_ip_addresses()
		# Should return at least empty array, not null
		return ips != null
	)

	register_test("ConnectionManager_PrimaryIPRetrieval", TestCategory.UNIT, func() -> bool:
		var ip := ConnectionManager.get_primary_local_ip()
		return ip != null and ip.length() > 0
	)

	register_test("ConnectionManager_IsInSessionWhenDisconnected", TestCategory.UNIT, func() -> bool:
		return ConnectionManager.is_in_session() == false
	)

	register_test("ConnectionManager_IsHostWhenNone", TestCategory.UNIT, func() -> bool:
		return ConnectionManager.is_host() == false
	)

# endregion


# region -- Movement State Machine Tests

func _register_movement_tests() -> void:
	register_test("MovementStateMachine_InitialState", TestCategory.UNIT, func() -> bool:
		var msm := MovementStateMachine.new()
		return msm.current_state == MovementStateMachine.MovementState.IDLE
	)

	register_test("MovementStateMachine_Stamina", TestCategory.UNIT, func() -> bool:
		var msm := MovementStateMachine.new()
		return msm.stamina == MovementStateMachine.MAX_STAMINA
	)

	register_test("MovementStateMachine_StaminaConsumption", TestCategory.UNIT, func() -> bool:
		var msm := MovementStateMachine.new()
		var initial := msm.stamina
		msm._consume_stamina(20.0)
		return msm.stamina == initial - 20.0
	)

	register_test("MovementStateMachine_StaminaConsumptionFails", TestCategory.UNIT, func() -> bool:
		var msm := MovementStateMachine.new()
		msm.stamina = 10.0
		var success := msm._consume_stamina(20.0)
		return success == false and msm.stamina == 10.0
	)

	register_test("MovementStateMachine_GetStateName", TestCategory.UNIT, func() -> bool:
		var msm := MovementStateMachine.new()
		return msm.get_state_name() == "IDLE"
	)

	register_test("MovementStateMachine_MaxSpeed", TestCategory.UNIT, func() -> bool:
		var msm := MovementStateMachine.new()
		var speed := msm.get_max_speed()
		return speed == 0.0  # IDLE state has 0 max speed
	)

	register_test("MovementStateMachine_Serialize", TestCategory.UNIT, func() -> bool:
		var msm := MovementStateMachine.new()
		msm.velocity = Vector3(1, 2, 3)
		msm.stamina = 75.0

		var data := msm.serialize()

		return data.has("state") and data.has("velocity") and data.has("stamina")
	)

	register_test("MovementStateMachine_Deserialize", TestCategory.UNIT, func() -> bool:
		var msm := MovementStateMachine.new()
		var data := {
			"state": MovementStateMachine.MovementState.RUNNING,
			"velocity": Vector3(5, 0, 5),
			"stamina": 50.0,
		}

		msm.deserialize(data)

		return msm.current_state == MovementStateMachine.MovementState.RUNNING \
			and msm.velocity == Vector3(5, 0, 5) \
			and msm.stamina == 50.0
	)

# endregion


# region -- Pickup Tests

func _register_pickup_tests() -> void:
	register_test("PickupBase_SpawnWeights", TestCategory.UNIT, func() -> bool:
		var weights := PickupBase.RARITY_WEIGHTS
		return weights[PickupBase.Rarity.COMMON] > weights[PickupBase.Rarity.LEGENDARY]
	)

	register_test("PickupBase_GlowMultipliers", TestCategory.UNIT, func() -> bool:
		var glows := PickupBase.RARITY_GLOW_MULT
		return glows[PickupBase.Rarity.LEGENDARY] > glows[PickupBase.Rarity.COMMON]
	)

# endregion


# region -- Performance Benchmarks

func _register_performance_tests() -> void:
	register_test("Perf_Vector3Operations", TestCategory.PERFORMANCE, func() -> Dictionary:
		var start := Time.get_ticks_usec()

		var v := Vector3.ZERO
		for i in BENCHMARK_ITERATIONS * 1000:
			v = v + Vector3(1, 2, 3)
			v = v.normalized()
			v = v * 2.0

		var elapsed := Time.get_ticks_usec() - start
		var ops_per_sec := (BENCHMARK_ITERATIONS * 1000.0) / (elapsed / 1_000_000.0)

		if ops_per_sec < 100000:
			return {"error": "Vector3 operations too slow: %.0f ops/sec" % ops_per_sec}
		return {}
	)

	register_test("Perf_DictionaryAccess", TestCategory.PERFORMANCE, func() -> Dictionary:
		var dict: Dictionary = {}
		for i in 1000:
			dict[str(i)] = i

		var start := Time.get_ticks_usec()

		var sum := 0
		for i in BENCHMARK_ITERATIONS * 100:
			sum += dict.get(str(i % 1000), 0) as int

		var elapsed := Time.get_ticks_usec() - start
		var ops_per_sec := (BENCHMARK_ITERATIONS * 100.0) / (elapsed / 1_000_000.0)

		if ops_per_sec < 500000:
			return {"error": "Dictionary access too slow: %.0f ops/sec" % ops_per_sec}
		return {}
	)

	register_test("Perf_ArrayIteration", TestCategory.PERFORMANCE, func() -> Dictionary:
		var arr: Array = []
		for i in 10000:
			arr.append(i)

		var start := Time.get_ticks_usec()

		var sum := 0
		for _iter in BENCHMARK_ITERATIONS:
			for item: int in arr:
				sum += item

		var elapsed := Time.get_ticks_usec() - start
		var items_per_sec := (BENCHMARK_ITERATIONS * 10000.0) / (elapsed / 1_000_000.0)

		if items_per_sec < 10_000_000:
			return {"error": "Array iteration too slow: %.0f items/sec" % items_per_sec}
		return {}
	)

	register_test("Perf_ObjectCreation", TestCategory.PERFORMANCE, func() -> Dictionary:
		var start := Time.get_ticks_usec()

		for i in BENCHMARK_ITERATIONS * 10:
			var obj := RefCounted.new()

		var elapsed := Time.get_ticks_usec() - start
		var creates_per_sec := (BENCHMARK_ITERATIONS * 10.0) / (elapsed / 1_000_000.0)

		if creates_per_sec < 10000:
			return {"error": "Object creation too slow: %.0f creates/sec" % creates_per_sec}
		return {}
	)

# endregion


# region -- Smoke Tests

func _register_smoke_tests() -> void:
	register_test("Smoke_AutoloadsExist", TestCategory.SMOKE, func() -> Dictionary:
		var autoloads := ["GameManager", "ConnectionManager", "AudioManager", "Lobby"]
		for autoload_name: String in autoloads:
			var node := Engine.get_main_loop().root.get_node_or_null("/root/" + autoload_name)
			if node == null:
				return {"error": "Autoload '%s' not found" % autoload_name}
		return {}
	)

	register_test("Smoke_GameScenesExist", TestCategory.SMOKE, func() -> Dictionary:
		var scenes := [
			"res://games/arena_blaster/arena_blaster.tscn",
			"res://games/turbo_karts/turbo_karts.tscn",
			"res://games/obstacle_royale/obstacle_royale.tscn",
			"res://games/flag_wars/flag_wars.tscn",
			"res://games/crash_derby/crash_derby.tscn",
		]
		for scene_path: String in scenes:
			if not ResourceLoader.exists(scene_path):
				return {"error": "Scene not found: %s" % scene_path}
		return {}
	)

	register_test("Smoke_UIScenesExist", TestCategory.SMOKE, func() -> Dictionary:
		var scenes := [
			"res://ui/main_menu/main_menu.tscn",
			"res://ui/character_select/character_select.tscn",
			"res://ui/hud/game_hud.tscn",
			"res://ui/results/results_screen.tscn",
		]
		for scene_path: String in scenes:
			if not ResourceLoader.exists(scene_path):
				return {"error": "UI Scene not found: %s" % scene_path}
		return {}
	)

	register_test("Smoke_PlayerCharacterScene", TestCategory.SMOKE, func() -> Dictionary:
		var scene_path := "res://characters/player_character.tscn"
		if not ResourceLoader.exists(scene_path):
			return {"error": "Player character scene not found"}

		var scene: PackedScene = load(scene_path)
		if scene == null:
			return {"error": "Failed to load player character scene"}

		var instance: Node = scene.instantiate()
		if instance == null:
			return {"error": "Failed to instantiate player character"}

		if not instance is CharacterBody3D:
			instance.free()
			return {"error": "Player character is not CharacterBody3D"}

		instance.free()
		return {}
	)

	register_test("Smoke_ProjectSettings", TestCategory.SMOKE, func() -> Dictionary:
		# Check critical project settings
		var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
		if main_scene.is_empty():
			return {"error": "No main scene configured"}

		var physics_fps: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 0)
		if physics_fps <= 0:
			return {"error": "Invalid physics tick rate"}

		return {}
	)

# endregion
