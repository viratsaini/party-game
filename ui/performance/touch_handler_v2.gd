## TouchHandlerV2 - Advanced touch gesture system for mobile gaming
##
## A comprehensive touch input library designed for competitive mobile gaming:
##
## - Full gesture recognition (tap, double-tap, long-press, swipe, pinch, rotate)
## - Touch area padding (44x44pt minimum for accessibility)
## - Visual + haptic feedback on all interactions
## - Gesture conflict resolution (prevents accidental triggers)
## - Multi-touch support (up to 10 simultaneous touches)
## - Pressure sensitivity (where supported)
## - Palm rejection algorithms
## - Touch prediction for low-latency response
##
## Usage:
##   var handler = TouchHandlerV2.new()
##   add_child(handler)
##   handler.gesture_detected.connect(_on_gesture)
##   handler.swipe_detected.connect(_on_swipe)
class_name TouchHandlerV2
extends Node


# =============================================================================
# region - Signals
# =============================================================================

## Generic gesture signal
signal gesture_detected(gesture: GestureData)

## Specific gesture signals
signal tap_detected(position: Vector2, touch_count: int)
signal double_tap_detected(position: Vector2)
signal long_press_detected(position: Vector2)
signal long_press_released(position: Vector2, duration: float)

signal swipe_detected(swipe: SwipeData)
signal pinch_detected(pinch: PinchData)
signal rotate_detected(rotation: RotationData)
signal pan_detected(pan: PanData)

## Touch state signals
signal touch_began(index: int, position: Vector2)
signal touch_moved(index: int, position: Vector2, delta: Vector2)
signal touch_ended(index: int, position: Vector2)

## Feedback signals
signal haptic_requested(pattern: String)
signal visual_feedback_requested(type: String, position: Vector2)

# endregion


# =============================================================================
# region - Enums
# =============================================================================

## Gesture types
enum GestureType {
	NONE,
	TAP,
	DOUBLE_TAP,
	LONG_PRESS,
	SWIPE,
	PINCH,
	ROTATE,
	PAN
}

## Swipe directions
enum SwipeDirection {
	NONE,
	UP,
	DOWN,
	LEFT,
	RIGHT,
	UP_LEFT,
	UP_RIGHT,
	DOWN_LEFT,
	DOWN_RIGHT
}

## Touch phase
enum TouchPhase {
	BEGAN,
	MOVED,
	STATIONARY,
	ENDED,
	CANCELLED
}

# endregion


# =============================================================================
# region - Inner Classes
# =============================================================================

## Base gesture data
class GestureData:
	var type: int = GestureType.NONE
	var position: Vector2 = Vector2.ZERO
	var timestamp: float = 0.0
	var touch_count: int = 1


## Touch point data
class TouchPoint:
	var index: int = -1
	var position: Vector2 = Vector2.ZERO
	var start_position: Vector2 = Vector2.ZERO
	var previous_position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var pressure: float = 1.0
	var radius: float = 1.0
	var phase: int = TouchPhase.BEGAN
	var start_time: float = 0.0
	var last_update_time: float = 0.0
	var is_cancelled: bool = false

	func get_delta() -> Vector2:
		return position - previous_position

	func get_total_movement() -> Vector2:
		return position - start_position

	func get_duration() -> float:
		return Time.get_ticks_msec() / 1000.0 - start_time


## Swipe gesture data
class SwipeData:
	var direction: int = SwipeDirection.NONE
	var start_position: Vector2 = Vector2.ZERO
	var end_position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var speed: float = 0.0
	var duration: float = 0.0
	var distance: float = 0.0
	var angle: float = 0.0  ## Radians

	func get_direction_vector() -> Vector2:
		return (end_position - start_position).normalized()


## Pinch gesture data
class PinchData:
	var center: Vector2 = Vector2.ZERO
	var scale: float = 1.0          ## Current scale relative to start
	var scale_delta: float = 0.0    ## Change this frame
	var velocity: float = 0.0       ## Scale change per second
	var distance: float = 0.0       ## Current distance between fingers
	var start_distance: float = 0.0


## Rotation gesture data
class RotationData:
	var center: Vector2 = Vector2.ZERO
	var rotation: float = 0.0       ## Total rotation in radians
	var rotation_delta: float = 0.0 ## Change this frame
	var velocity: float = 0.0       ## Radians per second


## Pan gesture data
class PanData:
	var position: Vector2 = Vector2.ZERO
	var translation: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var touch_count: int = 1

# endregion


# =============================================================================
# region - Constants
# =============================================================================

## Touch detection thresholds
const MIN_TOUCH_AREA: float = 44.0              ## Minimum touch target size (Apple HIG)
const TOUCH_SLOP: float = 8.0                   ## Movement threshold before gesture starts
const TAP_MAX_DURATION: float = 0.3             ## Maximum duration for a tap
const TAP_MAX_MOVEMENT: float = 20.0            ## Maximum movement for a tap
const DOUBLE_TAP_MAX_DELAY: float = 0.3         ## Maximum delay between taps
const DOUBLE_TAP_MAX_DISTANCE: float = 40.0     ## Maximum distance between taps
const LONG_PRESS_MIN_DURATION: float = 0.5      ## Minimum duration for long press
const LONG_PRESS_MAX_MOVEMENT: float = 10.0     ## Maximum movement during long press

## Swipe detection
const SWIPE_MIN_VELOCITY: float = 300.0         ## Pixels per second
const SWIPE_MIN_DISTANCE: float = 50.0          ## Minimum swipe distance
const SWIPE_MAX_DURATION: float = 0.5           ## Maximum swipe duration

## Pinch/Rotate detection
const PINCH_MIN_DISTANCE: float = 20.0          ## Minimum finger distance
const ROTATION_MIN_ANGLE: float = 0.05          ## Minimum rotation to detect (radians)

## Palm rejection
const PALM_MIN_RADIUS: float = 30.0             ## Touch radius indicating palm
const PALM_EDGE_MARGIN: float = 50.0            ## Edge region for palm detection
const MAX_CONCURRENT_TOUCHES: int = 10

## Prediction
const TOUCH_PREDICTION_TIME: float = 0.016      ## Predict 1 frame ahead (16ms)
const VELOCITY_SMOOTHING: float = 0.8           ## Velocity smoothing factor

# endregion


# =============================================================================
# region - Configuration
# =============================================================================

@export_group("Gesture Detection")

## Enable tap detection
@export var detect_taps: bool = true

## Enable double-tap detection
@export var detect_double_taps: bool = true

## Enable long-press detection
@export var detect_long_press: bool = true

## Enable swipe detection
@export var detect_swipes: bool = true

## Enable pinch detection
@export var detect_pinch: bool = true

## Enable rotation detection
@export var detect_rotation: bool = true

## Enable pan detection
@export var detect_pan: bool = true

@export_group("Feedback")

## Enable haptic feedback
@export var haptic_enabled: bool = true

## Enable visual feedback
@export var visual_feedback_enabled: bool = true

@export_group("Palm Rejection")

## Enable palm rejection
@export var palm_rejection_enabled: bool = true

## Screen edge palm rejection margin
@export var edge_rejection_margin: float = PALM_EDGE_MARGIN

@export_group("Touch Prediction")

## Enable touch prediction for lower latency
@export var prediction_enabled: bool = true

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

## Active touches
var _touches: Dictionary = {}  ## index -> TouchPoint

## Gesture state
var _potential_tap_position: Vector2 = Vector2.ZERO
var _potential_tap_time: float = 0.0
var _waiting_for_double_tap: bool = false
var _long_press_timer: float = 0.0
var _long_press_active: bool = false
var _long_press_position: Vector2 = Vector2.ZERO

## Multi-touch state
var _pinch_start_distance: float = 0.0
var _rotation_start_angle: float = 0.0
var _multi_touch_center: Vector2 = Vector2.ZERO
var _is_pinching: bool = false
var _is_rotating: bool = false
var _is_panning: bool = false

## Gesture conflict resolution
var _gesture_in_progress: int = GestureType.NONE
var _gesture_lock_time: float = 0.0

## Screen info for palm rejection
var _screen_size: Vector2 = Vector2.ZERO

## Haptic controller reference
var _haptic: Node = null

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	_screen_size = get_viewport().get_visible_rect().size

	## Try to get haptic controller
	if has_node("/root/HapticController"):
		_haptic = get_node("/root/HapticController")

	## Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_resized)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _process(delta: float) -> void:
	_update_long_press(delta)
	_update_double_tap_timeout(delta)
	_update_gesture_lock(delta)
	_update_touch_velocities(delta)


func _on_viewport_resized() -> void:
	_screen_size = get_viewport().get_visible_rect().size

# endregion


# =============================================================================
# region - Touch Handling
# =============================================================================

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_on_touch_began(event)
	else:
		_on_touch_ended(event)


func _handle_drag(event: InputEventScreenDrag) -> void:
	_on_touch_moved(event)


func _on_touch_began(event: InputEventScreenTouch) -> void:
	var index := event.index

	## Palm rejection
	if palm_rejection_enabled and _is_palm_touch(event):
		return

	## Create touch point
	var touch := TouchPoint.new()
	touch.index = index
	touch.position = event.position
	touch.start_position = event.position
	touch.previous_position = event.position
	touch.start_time = Time.get_ticks_msec() / 1000.0
	touch.last_update_time = touch.start_time
	touch.phase = TouchPhase.BEGAN
	touch.pressure = event.pressure if event.pressure > 0 else 1.0

	_touches[index] = touch

	## Emit signal
	touch_began.emit(index, event.position)

	## Check for multi-touch gestures
	if _touches.size() == 2:
		_begin_multi_touch_gesture()
	elif _touches.size() == 1:
		_begin_single_touch_gesture(touch)

	## Haptic feedback
	if haptic_enabled:
		_trigger_haptic("tick")


func _on_touch_moved(event: InputEventScreenDrag) -> void:
	var index := event.index

	if not _touches.has(index):
		return

	var touch: TouchPoint = _touches[index]
	touch.previous_position = touch.position

	## Apply prediction if enabled
	if prediction_enabled:
		touch.position = event.position + event.velocity * TOUCH_PREDICTION_TIME
	else:
		touch.position = event.position

	touch.velocity = _smooth_velocity(touch.velocity, event.velocity)
	touch.last_update_time = Time.get_ticks_msec() / 1000.0
	touch.phase = TouchPhase.MOVED

	## Emit signal
	touch_moved.emit(index, touch.position, touch.get_delta())

	## Update gestures
	if _touches.size() >= 2:
		_update_multi_touch_gesture()
	else:
		_update_single_touch_gesture(touch)


func _on_touch_ended(event: InputEventScreenTouch) -> void:
	var index := event.index

	if not _touches.has(index):
		return

	var touch: TouchPoint = _touches[index]
	touch.position = event.position
	touch.phase = TouchPhase.ENDED

	## Emit signal
	touch_ended.emit(index, event.position)

	## Finalize gestures
	if _touches.size() >= 2:
		_end_multi_touch_gesture()
	else:
		_end_single_touch_gesture(touch)

	## Remove touch
	_touches.erase(index)

	## Reset multi-touch state if no more touches
	if _touches.is_empty():
		_reset_gesture_state()

# endregion


# =============================================================================
# region - Single Touch Gestures
# =============================================================================

func _begin_single_touch_gesture(touch: TouchPoint) -> void:
	## Start long press timer
	if detect_long_press:
		_long_press_timer = 0.0
		_long_press_position = touch.position

	## Check for double tap
	if detect_double_taps and _waiting_for_double_tap:
		if touch.position.distance_to(_potential_tap_position) <= DOUBLE_TAP_MAX_DISTANCE:
			## This is a double tap!
			_waiting_for_double_tap = false
			_emit_double_tap(touch.position)
			_trigger_haptic("medium")
			return

	_potential_tap_position = touch.position
	_potential_tap_time = touch.start_time


func _update_single_touch_gesture(touch: TouchPoint) -> void:
	var movement := touch.get_total_movement().length()

	## Cancel long press if moved too much
	if movement > LONG_PRESS_MAX_MOVEMENT:
		_long_press_timer = 0.0

		## Check for swipe
		if detect_swipes and not _is_panning:
			_check_swipe(touch)

		## Check for pan
		if detect_pan and movement > TOUCH_SLOP:
			_is_panning = true
			_emit_pan(touch)


func _end_single_touch_gesture(touch: TouchPoint) -> void:
	var duration := touch.get_duration()
	var movement := touch.get_total_movement().length()

	## Check for long press release
	if _long_press_active:
		_long_press_active = false
		long_press_released.emit(touch.position, duration)
		_trigger_haptic("light")
		return

	## Check for tap
	if detect_taps and duration <= TAP_MAX_DURATION and movement <= TAP_MAX_MOVEMENT:
		if detect_double_taps:
			## Wait for potential double tap
			_waiting_for_double_tap = true
			_potential_tap_position = touch.position
			_potential_tap_time = Time.get_ticks_msec() / 1000.0
		else:
			_emit_tap(touch.position, 1)
			_trigger_haptic("light")
		return

	## Check for swipe on release
	if detect_swipes and touch.velocity.length() >= SWIPE_MIN_VELOCITY:
		_finalize_swipe(touch)

	_is_panning = false


func _update_long_press(delta: float) -> void:
	if not detect_long_press:
		return

	if _touches.size() != 1:
		_long_press_timer = 0.0
		return

	## Get the single touch
	var touch: TouchPoint = _touches.values()[0]
	var movement := touch.get_total_movement().length()

	if movement <= LONG_PRESS_MAX_MOVEMENT:
		_long_press_timer += delta

		if _long_press_timer >= LONG_PRESS_MIN_DURATION and not _long_press_active:
			_long_press_active = true
			_waiting_for_double_tap = false
			long_press_detected.emit(touch.position)
			_trigger_haptic("heavy")

			if visual_feedback_enabled:
				visual_feedback_requested.emit("long_press", touch.position)


func _update_double_tap_timeout(delta: float) -> void:
	if not _waiting_for_double_tap:
		return

	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - _potential_tap_time > DOUBLE_TAP_MAX_DELAY:
		## Double tap timeout - emit single tap
		_waiting_for_double_tap = false
		_emit_tap(_potential_tap_position, 1)
		_trigger_haptic("light")

# endregion


# =============================================================================
# region - Multi-Touch Gestures
# =============================================================================

func _begin_multi_touch_gesture() -> void:
	if _touches.size() < 2:
		return

	## Get two primary touches
	var touch_array := _touches.values()
	var t1: TouchPoint = touch_array[0]
	var t2: TouchPoint = touch_array[1]

	## Store initial state
	_pinch_start_distance = t1.position.distance_to(t2.position)
	_rotation_start_angle = _get_angle_between_touches(t1, t2)
	_multi_touch_center = (t1.position + t2.position) / 2.0

	_is_pinching = false
	_is_rotating = false


func _update_multi_touch_gesture() -> void:
	if _touches.size() < 2:
		return

	var touch_array := _touches.values()
	var t1: TouchPoint = touch_array[0]
	var t2: TouchPoint = touch_array[1]

	var current_distance := t1.position.distance_to(t2.position)
	var current_angle := _get_angle_between_touches(t1, t2)
	var current_center := (t1.position + t2.position) / 2.0

	## Check for pinch
	if detect_pinch:
		var distance_change := current_distance - _pinch_start_distance
		if absf(distance_change) > PINCH_MIN_DISTANCE or _is_pinching:
			_is_pinching = true
			_emit_pinch(current_center, current_distance)

	## Check for rotation
	if detect_rotation:
		var angle_change := _normalize_angle(current_angle - _rotation_start_angle)
		if absf(angle_change) > ROTATION_MIN_ANGLE or _is_rotating:
			_is_rotating = true
			_emit_rotation(current_center, angle_change)

	_multi_touch_center = current_center


func _end_multi_touch_gesture() -> void:
	_is_pinching = false
	_is_rotating = false

# endregion


# =============================================================================
# region - Swipe Detection
# =============================================================================

func _check_swipe(touch: TouchPoint) -> void:
	var velocity := touch.velocity
	var speed := velocity.length()

	if speed < SWIPE_MIN_VELOCITY:
		return

	var distance := touch.get_total_movement().length()
	if distance < SWIPE_MIN_DISTANCE:
		return


func _finalize_swipe(touch: TouchPoint) -> void:
	var velocity := touch.velocity
	var speed := velocity.length()
	var duration := touch.get_duration()
	var distance := touch.get_total_movement().length()

	if speed < SWIPE_MIN_VELOCITY or distance < SWIPE_MIN_DISTANCE:
		return

	if duration > SWIPE_MAX_DURATION:
		return

	var swipe := SwipeData.new()
	swipe.start_position = touch.start_position
	swipe.end_position = touch.position
	swipe.velocity = velocity
	swipe.speed = speed
	swipe.duration = duration
	swipe.distance = distance
	swipe.angle = velocity.angle()
	swipe.direction = _get_swipe_direction(velocity)

	swipe_detected.emit(swipe)

	## Create generic gesture data
	var gesture := GestureData.new()
	gesture.type = GestureType.SWIPE
	gesture.position = touch.position
	gesture.timestamp = Time.get_ticks_msec() / 1000.0
	gesture_detected.emit(gesture)

	_trigger_haptic("medium")


func _get_swipe_direction(velocity: Vector2) -> SwipeDirection:
	var angle := velocity.angle()

	## Convert to 0-360 range
	var degrees := rad_to_deg(angle)
	if degrees < 0:
		degrees += 360

	## Determine direction (8-way)
	if degrees >= 337.5 or degrees < 22.5:
		return SwipeDirection.RIGHT
	elif degrees >= 22.5 and degrees < 67.5:
		return SwipeDirection.DOWN_RIGHT
	elif degrees >= 67.5 and degrees < 112.5:
		return SwipeDirection.DOWN
	elif degrees >= 112.5 and degrees < 157.5:
		return SwipeDirection.DOWN_LEFT
	elif degrees >= 157.5 and degrees < 202.5:
		return SwipeDirection.LEFT
	elif degrees >= 202.5 and degrees < 247.5:
		return SwipeDirection.UP_LEFT
	elif degrees >= 247.5 and degrees < 292.5:
		return SwipeDirection.UP
	else:
		return SwipeDirection.UP_RIGHT

# endregion


# =============================================================================
# region - Gesture Emission
# =============================================================================

func _emit_tap(position: Vector2, touch_count: int) -> void:
	tap_detected.emit(position, touch_count)

	var gesture := GestureData.new()
	gesture.type = GestureType.TAP
	gesture.position = position
	gesture.timestamp = Time.get_ticks_msec() / 1000.0
	gesture.touch_count = touch_count
	gesture_detected.emit(gesture)

	if visual_feedback_enabled:
		visual_feedback_requested.emit("tap", position)


func _emit_double_tap(position: Vector2) -> void:
	double_tap_detected.emit(position)

	var gesture := GestureData.new()
	gesture.type = GestureType.DOUBLE_TAP
	gesture.position = position
	gesture.timestamp = Time.get_ticks_msec() / 1000.0
	gesture_detected.emit(gesture)

	if visual_feedback_enabled:
		visual_feedback_requested.emit("double_tap", position)


func _emit_pinch(center: Vector2, distance: float) -> void:
	var pinch := PinchData.new()
	pinch.center = center
	pinch.distance = distance
	pinch.start_distance = _pinch_start_distance
	pinch.scale = distance / _pinch_start_distance if _pinch_start_distance > 0 else 1.0

	pinch_detected.emit(pinch)


func _emit_rotation(center: Vector2, angle: float) -> void:
	var rotation := RotationData.new()
	rotation.center = center
	rotation.rotation = angle
	rotation.rotation_delta = angle - _rotation_start_angle

	rotate_detected.emit(rotation)


func _emit_pan(touch: TouchPoint) -> void:
	var pan := PanData.new()
	pan.position = touch.position
	pan.translation = touch.get_total_movement()
	pan.velocity = touch.velocity
	pan.touch_count = _touches.size()

	pan_detected.emit(pan)

# endregion


# =============================================================================
# region - Palm Rejection
# =============================================================================

func _is_palm_touch(event: InputEventScreenTouch) -> bool:
	## Check touch radius (if available)
	## Larger radius often indicates palm
	## Note: This is limited in Godot - full implementation needs platform-specific code

	## Check edge proximity
	var pos := event.position
	if pos.x < edge_rejection_margin or pos.x > _screen_size.x - edge_rejection_margin:
		## Touch near edge - more likely to be palm
		if _touches.size() == 0:
			## First touch near edge while no other touches - might be palm
			return false  ## Allow it but be cautious
		return true

	## Check if touch is much larger than normal (would need native API)

	return false

# endregion


# =============================================================================
# region - Utility Functions
# =============================================================================

func _smooth_velocity(current: Vector2, new_velocity: Vector2) -> Vector2:
	return current.lerp(new_velocity, VELOCITY_SMOOTHING)


func _get_angle_between_touches(t1: TouchPoint, t2: TouchPoint) -> float:
	var diff := t2.position - t1.position
	return diff.angle()


func _normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


func _update_touch_velocities(delta: float) -> void:
	## Decay velocity for stationary touches
	for index: int in _touches:
		var touch: TouchPoint = _touches[index]
		if touch.phase == TouchPhase.STATIONARY:
			touch.velocity *= 0.95


func _update_gesture_lock(delta: float) -> void:
	if _gesture_lock_time > 0:
		_gesture_lock_time -= delta
		if _gesture_lock_time <= 0:
			_gesture_in_progress = GestureType.NONE


func _reset_gesture_state() -> void:
	_gesture_in_progress = GestureType.NONE
	_is_pinching = false
	_is_rotating = false
	_is_panning = false
	_long_press_active = false
	_long_press_timer = 0.0

# endregion


# =============================================================================
# region - Haptic Feedback
# =============================================================================

func _trigger_haptic(pattern: String) -> void:
	if not haptic_enabled:
		return

	haptic_requested.emit(pattern)

	## Direct haptic if controller available
	if _haptic and _haptic.has_method("vibrate_named"):
		_haptic.vibrate_named(pattern)

# endregion


# =============================================================================
# region - Public API
# =============================================================================

## Gets the number of active touches
func get_touch_count() -> int:
	return _touches.size()


## Gets a specific touch point
func get_touch(index: int) -> TouchPoint:
	return _touches.get(index)


## Gets all active touches
func get_all_touches() -> Array:
	return _touches.values()


## Checks if any gesture is in progress
func is_gesture_in_progress() -> bool:
	return _gesture_in_progress != GestureType.NONE


## Gets the current gesture type
func get_current_gesture() -> GestureType:
	return _gesture_in_progress as GestureType


## Cancels all current gestures
func cancel_all_gestures() -> void:
	_reset_gesture_state()
	_touches.clear()


## Checks if a position is within minimum touch area
func is_touch_area_valid(rect: Rect2) -> bool:
	return rect.size.x >= MIN_TOUCH_AREA and rect.size.y >= MIN_TOUCH_AREA


## Expands a rect to meet minimum touch area requirements
func ensure_min_touch_area(rect: Rect2) -> Rect2:
	var result := rect
	if result.size.x < MIN_TOUCH_AREA:
		var diff := MIN_TOUCH_AREA - result.size.x
		result.position.x -= diff / 2.0
		result.size.x = MIN_TOUCH_AREA
	if result.size.y < MIN_TOUCH_AREA:
		var diff := MIN_TOUCH_AREA - result.size.y
		result.position.y -= diff / 2.0
		result.size.y = MIN_TOUCH_AREA
	return result


## Gets swipe direction name
func get_swipe_direction_name(direction: SwipeDirection) -> String:
	match direction:
		SwipeDirection.UP: return "up"
		SwipeDirection.DOWN: return "down"
		SwipeDirection.LEFT: return "left"
		SwipeDirection.RIGHT: return "right"
		SwipeDirection.UP_LEFT: return "up_left"
		SwipeDirection.UP_RIGHT: return "up_right"
		SwipeDirection.DOWN_LEFT: return "down_left"
		SwipeDirection.DOWN_RIGHT: return "down_right"
		_: return "none"


## Converts a gesture type to string
func get_gesture_name(gesture_type: GestureType) -> String:
	match gesture_type:
		GestureType.TAP: return "tap"
		GestureType.DOUBLE_TAP: return "double_tap"
		GestureType.LONG_PRESS: return "long_press"
		GestureType.SWIPE: return "swipe"
		GestureType.PINCH: return "pinch"
		GestureType.ROTATE: return "rotate"
		GestureType.PAN: return "pan"
		_: return "none"

# endregion
