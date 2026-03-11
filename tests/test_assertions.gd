## TestAssertions - Assertion helpers for BattleZone Party tests.
##
## Provides fluent assertion methods with detailed error messages.
## Compatible with the TestRunner framework.
class_name TestAssertions
extends RefCounted


# region -- State

var _errors: Array[String] = []
var _context: String = ""

# endregion


# region -- Factory

static func create(context: String = "") -> TestAssertions:
	var assertions := TestAssertions.new()
	assertions._context = context
	return assertions

# endregion


# region -- Results

## Check if all assertions passed.
func passed() -> bool:
	return _errors.is_empty()


## Get all error messages.
func get_errors() -> Array[String]:
	return _errors


## Get formatted error message.
func get_error_message() -> String:
	if _errors.is_empty():
		return ""
	return "\n".join(_errors)


## Get result dictionary for TestRunner.
func result() -> Dictionary:
	if passed():
		return {}
	return {"error": get_error_message()}

# endregion


# region -- Basic Assertions

## Assert that a condition is true.
func assert_true(condition: bool, message: String = "") -> TestAssertions:
	if not condition:
		_add_error("Expected true, got false", message)
	return self


## Assert that a condition is false.
func assert_false(condition: bool, message: String = "") -> TestAssertions:
	if condition:
		_add_error("Expected false, got true", message)
	return self


## Assert that a value is null.
func assert_null(value: Variant, message: String = "") -> TestAssertions:
	if value != null:
		_add_error("Expected null, got: %s" % str(value), message)
	return self


## Assert that a value is not null.
func assert_not_null(value: Variant, message: String = "") -> TestAssertions:
	if value == null:
		_add_error("Expected non-null value", message)
	return self

# endregion


# region -- Equality Assertions

## Assert that two values are equal.
func assert_equal(actual: Variant, expected: Variant, message: String = "") -> TestAssertions:
	if actual != expected:
		_add_error("Expected '%s', got '%s'" % [str(expected), str(actual)], message)
	return self


## Assert that two values are not equal.
func assert_not_equal(actual: Variant, expected: Variant, message: String = "") -> TestAssertions:
	if actual == expected:
		_add_error("Expected values to differ, both are '%s'" % str(actual), message)
	return self


## Assert that two floats are approximately equal.
func assert_approx_equal(actual: float, expected: float, epsilon: float = 0.0001, message: String = "") -> TestAssertions:
	if absf(actual - expected) > epsilon:
		_add_error("Expected ~%.6f, got %.6f (epsilon: %.6f)" % [expected, actual, epsilon], message)
	return self


## Assert that two Vector3s are approximately equal.
func assert_vector3_approx_equal(actual: Vector3, expected: Vector3, epsilon: float = 0.0001, message: String = "") -> TestAssertions:
	if actual.distance_to(expected) > epsilon:
		_add_error("Expected ~%s, got %s" % [str(expected), str(actual)], message)
	return self

# endregion


# region -- Comparison Assertions

## Assert that a value is greater than another.
func assert_greater_than(actual: Variant, threshold: Variant, message: String = "") -> TestAssertions:
	if actual <= threshold:
		_add_error("Expected %s > %s" % [str(actual), str(threshold)], message)
	return self


## Assert that a value is greater than or equal to another.
func assert_greater_than_or_equal(actual: Variant, threshold: Variant, message: String = "") -> TestAssertions:
	if actual < threshold:
		_add_error("Expected %s >= %s" % [str(actual), str(threshold)], message)
	return self


## Assert that a value is less than another.
func assert_less_than(actual: Variant, threshold: Variant, message: String = "") -> TestAssertions:
	if actual >= threshold:
		_add_error("Expected %s < %s" % [str(actual), str(threshold)], message)
	return self


## Assert that a value is less than or equal to another.
func assert_less_than_or_equal(actual: Variant, threshold: Variant, message: String = "") -> TestAssertions:
	if actual > threshold:
		_add_error("Expected %s <= %s" % [str(actual), str(threshold)], message)
	return self


## Assert that a value is within a range.
func assert_in_range(actual: Variant, min_val: Variant, max_val: Variant, message: String = "") -> TestAssertions:
	if actual < min_val or actual > max_val:
		_add_error("Expected %s in range [%s, %s]" % [str(actual), str(min_val), str(max_val)], message)
	return self

# endregion


# region -- Collection Assertions

## Assert that a collection is empty.
func assert_empty(collection: Variant, message: String = "") -> TestAssertions:
	var is_empty: bool = false
	if collection is Array:
		is_empty = collection.is_empty()
	elif collection is Dictionary:
		is_empty = collection.is_empty()
	elif collection is String:
		is_empty = collection.is_empty()
	else:
		_add_error("Cannot check emptiness of type: %s" % typeof(collection), message)
		return self

	if not is_empty:
		_add_error("Expected empty collection, got size %d" % _get_size(collection), message)
	return self


## Assert that a collection is not empty.
func assert_not_empty(collection: Variant, message: String = "") -> TestAssertions:
	var is_empty: bool = true
	if collection is Array:
		is_empty = collection.is_empty()
	elif collection is Dictionary:
		is_empty = collection.is_empty()
	elif collection is String:
		is_empty = collection.is_empty()
	else:
		_add_error("Cannot check emptiness of type: %s" % typeof(collection), message)
		return self

	if is_empty:
		_add_error("Expected non-empty collection", message)
	return self


## Assert that a collection has a specific size.
func assert_size(collection: Variant, expected_size: int, message: String = "") -> TestAssertions:
	var size := _get_size(collection)
	if size != expected_size:
		_add_error("Expected size %d, got %d" % [expected_size, size], message)
	return self


## Assert that a collection contains a value.
func assert_contains(collection: Variant, value: Variant, message: String = "") -> TestAssertions:
	var contains: bool = false
	if collection is Array:
		contains = collection.has(value)
	elif collection is Dictionary:
		contains = collection.has(value)
	elif collection is String:
		contains = collection.contains(str(value))
	else:
		_add_error("Cannot check containment in type: %s" % typeof(collection), message)
		return self

	if not contains:
		_add_error("Expected collection to contain '%s'" % str(value), message)
	return self


## Assert that a collection does not contain a value.
func assert_not_contains(collection: Variant, value: Variant, message: String = "") -> TestAssertions:
	var contains: bool = true
	if collection is Array:
		contains = collection.has(value)
	elif collection is Dictionary:
		contains = collection.has(value)
	elif collection is String:
		contains = collection.contains(str(value))
	else:
		_add_error("Cannot check containment in type: %s" % typeof(collection), message)
		return self

	if contains:
		_add_error("Expected collection to not contain '%s'" % str(value), message)
	return self

# endregion


# region -- Type Assertions

## Assert that a value is of a specific type.
func assert_type(value: Variant, expected_type: int, message: String = "") -> TestAssertions:
	var actual_type := typeof(value)
	if actual_type != expected_type:
		_add_error("Expected type %d, got type %d" % [expected_type, actual_type], message)
	return self


## Assert that a value is an instance of a class.
func assert_instance_of(value: Variant, expected_class: Variant, message: String = "") -> TestAssertions:
	if not is_instance_of(value, expected_class):
		_add_error("Expected instance of %s" % str(expected_class), message)
	return self

# endregion


# region -- String Assertions

## Assert that a string starts with a prefix.
func assert_starts_with(text: String, prefix: String, message: String = "") -> TestAssertions:
	if not text.begins_with(prefix):
		_add_error("Expected '%s' to start with '%s'" % [text, prefix], message)
	return self


## Assert that a string ends with a suffix.
func assert_ends_with(text: String, suffix: String, message: String = "") -> TestAssertions:
	if not text.ends_with(suffix):
		_add_error("Expected '%s' to end with '%s'" % [text, suffix], message)
	return self


## Assert that a string matches a pattern.
func assert_matches(text: String, pattern: String, message: String = "") -> TestAssertions:
	var regex := RegEx.new()
	var err := regex.compile(pattern)
	if err != OK:
		_add_error("Invalid regex pattern: %s" % pattern, message)
		return self

	if not regex.search(text):
		_add_error("Expected '%s' to match pattern '%s'" % [text, pattern], message)
	return self

# endregion


# region -- Signal Assertions (for integration with scenes)

## Assert that a signal was emitted (requires manual tracking).
func assert_signal_emitted(tracker: Dictionary, signal_name: String, message: String = "") -> TestAssertions:
	if not tracker.has(signal_name) or tracker[signal_name] == 0:
		_add_error("Expected signal '%s' to be emitted" % signal_name, message)
	return self


## Assert that a signal was emitted a specific number of times.
func assert_signal_count(tracker: Dictionary, signal_name: String, expected_count: int, message: String = "") -> TestAssertions:
	var actual_count: int = tracker.get(signal_name, 0)
	if actual_count != expected_count:
		_add_error("Expected signal '%s' emitted %d times, got %d" % [signal_name, expected_count, actual_count], message)
	return self

# endregion


# region -- Performance Assertions

## Assert that an operation completes within a time limit.
func assert_performance(start_usec: int, max_usec: int, message: String = "") -> TestAssertions:
	var elapsed := Time.get_ticks_usec() - start_usec
	if elapsed > max_usec:
		_add_error("Expected completion in %d usec, took %d usec" % [max_usec, elapsed], message)
	return self


## Assert that operations per second meet a threshold.
func assert_ops_per_second(operations: int, elapsed_usec: int, min_ops_per_sec: float, message: String = "") -> TestAssertions:
	var ops_per_sec := float(operations) / (float(elapsed_usec) / 1_000_000.0)
	if ops_per_sec < min_ops_per_sec:
		_add_error("Expected %.0f ops/sec, got %.0f ops/sec" % [min_ops_per_sec, ops_per_sec], message)
	return self

# endregion


# region -- Internal

func _add_error(error: String, custom_message: String) -> void:
	var full_error := error
	if not custom_message.is_empty():
		full_error = "%s: %s" % [custom_message, error]
	if not _context.is_empty():
		full_error = "[%s] %s" % [_context, full_error]
	_errors.append(full_error)


func _get_size(collection: Variant) -> int:
	if collection is Array:
		return collection.size()
	elif collection is Dictionary:
		return collection.size()
	elif collection is String:
		return collection.length()
	return 0

# endregion
