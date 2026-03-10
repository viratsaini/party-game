## UIAnimator - Ultra-premium global UI animation system for AAA-quality animations.
##
## This is an autoload singleton that provides:
## - Global animation controller with queue management
## - Interrupt handling and priority system
## - Performance monitoring and automatic optimization
## - Preset animation library for common UI patterns
## - Fluent sequence builder API for complex animations
## - Sound integration for animation events
## - Object pooling for effects
##
## Usage:
##   UIAnimator.fade_in(node, 0.3)
##   UIAnimator.shake(node, 10.0, 0.5)
##   UIAnimator.sequence().then_fade_in(node1).wait(0.1).then_scale(node2).play()
##
## As Autoload:
##   Add this script to Project Settings > Autoload as "UIAnimator"
extends Node


# region - Signals

## Emitted when an animation starts
signal animation_started(node: Node, animation_type: String)

## Emitted when an animation completes
signal animation_completed(node: Node, animation_type: String)

## Emitted when an animation is interrupted
signal animation_interrupted(node: Node, animation_type: String)

## Emitted when performance optimization is applied
signal performance_optimized(quality_level: float)

## Emitted when animation queue is empty
signal queue_empty

# endregion


# region - Enums

## Animation priority levels
enum Priority {
	LOW = 0,      ## Can be interrupted by anything
	NORMAL = 1,   ## Standard UI animations
	HIGH = 2,     ## Important feedback animations
	CRITICAL = 3, ## Must complete (error states, etc)
}

## Slide directions
enum Direction {
	LEFT,
	RIGHT,
	UP,
	DOWN,
	CENTER,  ## Scale from center
}

## Animation categories for sound mapping
enum AnimationCategory {
	ENTRANCE,
	EXIT,
	FEEDBACK,
	TRANSITION,
	LOOP,
}

# endregion


# region - Constants

## Animation durations (seconds) - tuned for responsiveness
const DURATION_INSTANT: float = 0.08
const DURATION_QUICK: float = 0.15
const DURATION_NORMAL: float = 0.25
const DURATION_SMOOTH: float = 0.4
const DURATION_DRAMATIC: float = 0.6

## Scale values for states
const SCALE_NORMAL: Vector2 = Vector2.ONE
const SCALE_HOVER: Vector2 = Vector2(1.08, 1.08)
const SCALE_PRESS: Vector2 = Vector2(0.92, 0.92)
const SCALE_SPRING_OVERSHOOT: Vector2 = Vector2(1.12, 1.12)

## Glow intensity values
const GLOW_IDLE: float = 0.0
const GLOW_HOVER: float = 0.5
const GLOW_ACTIVE: float = 1.0

## Maximum concurrent animations for performance
const MAX_CONCURRENT_ANIMATIONS: int = 50

## Performance thresholds
const PERFORMANCE_CHECK_INTERVAL: float = 1.0
const TARGET_FRAME_TIME: float = 0.0167  ## ~60 FPS
const QUALITY_REDUCTION_THRESHOLD: float = 0.025  ## ~40 FPS

## Animation presets dictionary
const PRESETS: Dictionary = {
	"button_hover": {
		"scale": Vector2(1.08, 1.08),
		"duration": 0.15,
		"easing": "back_out",
	},
	"button_press": {
		"scale": Vector2(0.92, 0.92),
		"duration": 0.08,
		"easing": "expo_out",
	},
	"button_release": {
		"scale": Vector2(1.0, 1.0),
		"duration": 0.2,
		"easing": "elastic_out",
	},
	"panel_open": {
		"scale": Vector2(1.0, 1.0),
		"duration": 0.4,
		"easing": "back_out",
		"start_scale": Vector2(0.85, 0.85),
	},
	"panel_close": {
		"scale": Vector2(0.85, 0.85),
		"duration": 0.25,
		"easing": "quad_in",
	},
	"notification_enter": {
		"slide_distance": 100,
		"duration": 0.4,
		"easing": "expo_out",
	},
	"notification_exit": {
		"slide_distance": 100,
		"duration": 0.3,
		"easing": "quad_in",
	},
	"error_shake": {
		"intensity": 12.0,
		"duration": 0.5,
		"frequency": 30.0,
	},
	"success_bounce": {
		"scale": Vector2(1.2, 1.2),
		"duration": 0.5,
		"easing": "elastic_out",
	},
	"attention_pulse": {
		"scale_range": 0.08,
		"duration": 1.0,
		"loops": -1,
	},
	"card_flip": {
		"duration": 0.5,
		"easing": "cubic_in_out",
	},
	"tooltip_show": {
		"scale": Vector2(1.0, 1.0),
		"start_scale": Vector2(0.8, 0.8),
		"duration": 0.2,
		"easing": "back_out",
	},
}

# endregion


# region - State Variables

## Singleton instance
static var _instance: Node = null

## Active tweens mapped by node
var _active_tweens: Dictionary = {}  ## Node -> Array[Tween]

## Animation queue for sequenced animations
var _animation_queue: Array[Dictionary] = []

## Priority tracking for active animations
var _animation_priorities: Dictionary = {}  ## Tween -> Priority

## Performance tracking
var _frame_times: Array[float] = []
var _last_perf_check: float = 0.0
var _quality_level: float = 1.0

## Sound mappings for animations
var _animation_sounds: Dictionary = {
	"button_hover": "ui_hover",
	"button_press": "ui_click",
	"button_release": "ui_release",
	"panel_open": "ui_panel_open",
	"panel_close": "ui_panel_close",
	"slide_in": "ui_whoosh",
	"slide_out": "ui_whoosh",
	"pop_in": "ui_pop",
	"pop_out": "ui_pop",
	"shake": "ui_error",
	"success": "ui_success",
	"notification": "ui_notification",
	"typewriter": "ui_type",
}

## Original values storage for restoration
var _original_values: Dictionary = {}  ## Node -> Dictionary

## Animation profiling data
var _profiling_enabled: bool = false
var _profiling_data: Dictionary = {}  ## animation_type -> {count, total_time}

# endregion


# region - Lifecycle

func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[UIAnimator] Global animation system initialized - Premium animations ready")


func _process(delta: float) -> void:
	_track_performance(delta)
	_cleanup_finished_animations()


static func get_instance() -> Node:
	return _instance

# endregion


# region - Core Animation API

## Fades a node in from transparent to opaque
func fade_in(
	node: Node,
	duration: float = DURATION_NORMAL,
	delay: float = 0.0,
	easing: String = "quad_out"
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "modulate", _get_modulate(node))

	var tween := _create_managed_tween(node, "fade_in")
	if delay > 0.0:
		tween.tween_interval(delay)

	_set_modulate_alpha(node, 0.0)
	node.visible = true

	tween.tween_method(
		func(alpha: float) -> void: _set_modulate_alpha(node, alpha),
		0.0, 1.0, duration * _quality_level
	).set_ease(_get_ease_type(easing)).set_trans(_get_trans_type(easing))

	_play_animation_sound("fade_in")
	animation_started.emit(node, "fade_in")

	tween.finished.connect(func() -> void:
		animation_completed.emit(node, "fade_in")
	, CONNECT_ONE_SHOT)

	return tween


## Fades a node out from opaque to transparent
func fade_out(
	node: Node,
	duration: float = DURATION_NORMAL,
	delay: float = 0.0,
	easing: String = "quad_in",
	hide_on_complete: bool = true
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "modulate", _get_modulate(node))

	var tween := _create_managed_tween(node, "fade_out")
	if delay > 0.0:
		tween.tween_interval(delay)

	var start_alpha: float = _get_modulate(node).a

	tween.tween_method(
		func(alpha: float) -> void: _set_modulate_alpha(node, alpha),
		start_alpha, 0.0, duration * _quality_level
	).set_ease(_get_ease_type(easing)).set_trans(_get_trans_type(easing))

	animation_started.emit(node, "fade_out")

	tween.finished.connect(func() -> void:
		if hide_on_complete:
			node.visible = false
		animation_completed.emit(node, "fade_out")
	, CONNECT_ONE_SHOT)

	return tween


## Scales a node with bounce effect
func scale_bounce(
	node: Node,
	target_scale: Vector2 = Vector2.ONE,
	duration: float = DURATION_NORMAL,
	easing: String = "elastic_out"
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "scale", _get_scale(node))

	var tween := _create_managed_tween(node, "scale_bounce")

	tween.tween_property(node, "scale", target_scale, duration * _quality_level) \
		.set_ease(_get_ease_type(easing)) \
		.set_trans(_get_trans_type(easing))

	animation_started.emit(node, "scale_bounce")

	tween.finished.connect(func() -> void:
		animation_completed.emit(node, "scale_bounce")
	, CONNECT_ONE_SHOT)

	return tween


## Shakes a node for error feedback or attention
func shake(
	node: Node,
	intensity: float = 10.0,
	duration: float = 0.5,
	frequency: float = 25.0
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "position", _get_position(node))
	var original_pos: Vector2 = _get_position(node)

	var tween := _create_managed_tween(node, "shake")
	var shake_count: int = int(duration * frequency * _quality_level)
	shake_count = maxi(shake_count, 3)
	var shake_duration: float = duration / float(shake_count)

	for i in range(shake_count):
		var decay: float = 1.0 - (float(i) / float(shake_count))
		var offset := Vector2(
			randf_range(-intensity, intensity) * decay,
			randf_range(-intensity, intensity) * decay * 0.5
		)
		tween.tween_property(node, "position", original_pos + offset, shake_duration) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_SINE)

	# Return to original position
	tween.tween_property(node, "position", original_pos, shake_duration) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_SINE)

	_play_animation_sound("shake")
	animation_started.emit(node, "shake")

	tween.finished.connect(func() -> void:
		_set_position(node, original_pos)
		animation_completed.emit(node, "shake")
	, CONNECT_ONE_SHOT)

	return tween


## Applies a pulsing glow effect to a node
func pulse_glow(
	node: Node,
	glow_color: Color = Color.WHITE,
	speed: float = 1.0,
	intensity: float = 0.3,
	loops: int = -1
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "modulate", _get_modulate(node))
	var original_color: Color = _get_modulate(node)

	var tween := _create_managed_tween(node, "pulse_glow")
	tween.set_loops(loops)

	var pulse_color := original_color.lerp(glow_color, intensity)

	tween.tween_property(node, "modulate", pulse_color, 0.5 / speed) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate", original_color, 0.5 / speed) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)

	animation_started.emit(node, "pulse_glow")

	if loops != -1:
		tween.finished.connect(func() -> void:
			_set_modulate(node, original_color)
			animation_completed.emit(node, "pulse_glow")
		, CONNECT_ONE_SHOT)

	return tween


## Slides a node in from a direction
func slide_in(
	node: Node,
	direction: Direction = Direction.LEFT,
	distance: float = 100.0,
	duration: float = DURATION_SMOOTH,
	easing: String = "expo_out"
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "position", _get_position(node))
	var target_pos: Vector2 = _get_position(node)
	var start_pos: Vector2 = _calculate_slide_position(target_pos, direction, distance)

	_set_position(node, start_pos)
	_set_modulate_alpha(node, 0.0)
	node.visible = true

	var tween := _create_managed_tween(node, "slide_in")
	tween.set_parallel(true)

	tween.tween_property(node, "position", target_pos, duration * _quality_level) \
		.set_ease(_get_ease_type(easing)) \
		.set_trans(_get_trans_type(easing))

	tween.tween_method(
		func(alpha: float) -> void: _set_modulate_alpha(node, alpha),
		0.0, 1.0, duration * _quality_level * 0.6
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	_play_animation_sound("slide_in")
	animation_started.emit(node, "slide_in")

	tween.finished.connect(func() -> void:
		animation_completed.emit(node, "slide_in")
	, CONNECT_ONE_SHOT)

	return tween


## Slides a node out in a direction
func slide_out(
	node: Node,
	direction: Direction = Direction.LEFT,
	distance: float = 100.0,
	duration: float = DURATION_SMOOTH,
	easing: String = "expo_in",
	hide_on_complete: bool = true
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "position", _get_position(node))
	var start_pos: Vector2 = _get_position(node)
	var target_pos: Vector2 = _calculate_slide_position(start_pos, direction, distance)

	var tween := _create_managed_tween(node, "slide_out")
	tween.set_parallel(true)

	tween.tween_property(node, "position", target_pos, duration * _quality_level) \
		.set_ease(_get_ease_type(easing)) \
		.set_trans(_get_trans_type(easing))

	tween.tween_method(
		func(alpha: float) -> void: _set_modulate_alpha(node, alpha),
		1.0, 0.0, duration * _quality_level
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	_play_animation_sound("slide_out")
	animation_started.emit(node, "slide_out")

	tween.finished.connect(func() -> void:
		if hide_on_complete:
			node.visible = false
		_set_position(node, start_pos)
		animation_completed.emit(node, "slide_out")
	, CONNECT_ONE_SHOT)

	return tween


## Rotates a node with spring physics
func rotate_spring(
	node: Node,
	target_rotation: float,
	duration: float = DURATION_NORMAL,
	damping: float = 0.4,
	frequency: float = 6.0
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "rotation", _get_rotation(node))
	var start_rotation: float = _get_rotation(node)

	var tween := _create_managed_tween(node, "rotate_spring")

	# Use spring physics simulation
	var steps: int = int(duration * 60.0 * _quality_level)
	steps = maxi(steps, 10)
	var step_duration: float = duration / float(steps)

	for i in range(steps):
		var t: float = float(i + 1) / float(steps)
		var spring_value: float = UIEasing.spring(t, damping, frequency)
		var rotation: float = lerpf(start_rotation, target_rotation, spring_value)

		tween.tween_property(node, "rotation", rotation, step_duration)

	animation_started.emit(node, "rotate_spring")

	tween.finished.connect(func() -> void:
		animation_completed.emit(node, "rotate_spring")
	, CONNECT_ONE_SHOT)

	return tween


## Transitions a node's color/modulate
func color_transition(
	node: Node,
	target_color: Color,
	duration: float = DURATION_NORMAL,
	easing: String = "quad_in_out"
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "modulate", _get_modulate(node))

	var tween := _create_managed_tween(node, "color_transition")

	tween.tween_property(node, "modulate", target_color, duration * _quality_level) \
		.set_ease(_get_ease_type(easing)) \
		.set_trans(_get_trans_type(easing))

	animation_started.emit(node, "color_transition")

	tween.finished.connect(func() -> void:
		animation_completed.emit(node, "color_transition")
	, CONNECT_ONE_SHOT)

	return tween


## Applies a pop-in effect (scale from 0 with bounce)
func pop_in(
	node: Node,
	duration: float = DURATION_SMOOTH,
	easing: String = "elastic_out"
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "scale", _get_scale(node))
	var target_scale: Vector2 = _get_scale(node)

	_set_scale(node, Vector2.ZERO)
	_set_modulate_alpha(node, 0.0)
	node.visible = true

	var tween := _create_managed_tween(node, "pop_in")
	tween.set_parallel(true)

	tween.tween_property(node, "scale", target_scale, duration * _quality_level) \
		.set_ease(_get_ease_type(easing)) \
		.set_trans(_get_trans_type(easing))

	tween.tween_method(
		func(alpha: float) -> void: _set_modulate_alpha(node, alpha),
		0.0, 1.0, duration * _quality_level * 0.4
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	_play_animation_sound("pop_in")
	animation_started.emit(node, "pop_in")

	tween.finished.connect(func() -> void:
		animation_completed.emit(node, "pop_in")
	, CONNECT_ONE_SHOT)

	return tween


## Applies a pop-out effect (scale to 0)
func pop_out(
	node: Node,
	duration: float = DURATION_NORMAL,
	easing: String = "back_in",
	hide_on_complete: bool = true
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "scale", _get_scale(node))
	var original_scale: Vector2 = _get_scale(node)

	var tween := _create_managed_tween(node, "pop_out")
	tween.set_parallel(true)

	tween.tween_property(node, "scale", Vector2.ZERO, duration * _quality_level) \
		.set_ease(_get_ease_type(easing)) \
		.set_trans(_get_trans_type(easing))

	tween.tween_method(
		func(alpha: float) -> void: _set_modulate_alpha(node, alpha),
		1.0, 0.0, duration * _quality_level
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	_play_animation_sound("pop_out")
	animation_started.emit(node, "pop_out")

	tween.finished.connect(func() -> void:
		if hide_on_complete:
			node.visible = false
		_set_scale(node, original_scale)
		animation_completed.emit(node, "pop_out")
	, CONNECT_ONE_SHOT)

	return tween


## Applies a bounce effect (quick scale up and back)
func bounce(
	node: Node,
	scale_amount: float = 0.15,
	duration: float = DURATION_NORMAL
) -> Tween:
	if not _validate_node(node):
		return null

	var original_scale: Vector2 = _get_scale(node)
	var bounce_scale: Vector2 = original_scale * (1.0 + scale_amount)

	var tween := _create_managed_tween(node, "bounce")

	tween.tween_property(node, "scale", bounce_scale, duration * 0.35) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", original_scale, duration * 0.65) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_ELASTIC)

	animation_started.emit(node, "bounce")

	tween.finished.connect(func() -> void:
		animation_completed.emit(node, "bounce")
	, CONNECT_ONE_SHOT)

	return tween


## Applies a wiggle/jiggle effect
func wiggle(
	node: Node,
	angle: float = 5.0,
	duration: float = DURATION_SMOOTH,
	cycles: int = 3
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "rotation", _get_rotation(node))
	var original_rotation: float = _get_rotation(node)
	var cycle_duration: float = duration / float(cycles)

	var tween := _create_managed_tween(node, "wiggle")

	for i in range(cycles):
		var decay: float = 1.0 - (float(i) / float(cycles))
		var current_angle: float = deg_to_rad(angle * decay)

		tween.tween_property(node, "rotation", original_rotation + current_angle, cycle_duration * 0.25) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_SINE)
		tween.tween_property(node, "rotation", original_rotation - current_angle, cycle_duration * 0.5) \
			.set_ease(Tween.EASE_IN_OUT) \
			.set_trans(Tween.TRANS_SINE)
		tween.tween_property(node, "rotation", original_rotation, cycle_duration * 0.25) \
			.set_ease(Tween.EASE_IN) \
			.set_trans(Tween.TRANS_SINE)

	animation_started.emit(node, "wiggle")

	tween.finished.connect(func() -> void:
		_set_rotation(node, original_rotation)
		animation_completed.emit(node, "wiggle")
	, CONNECT_ONE_SHOT)

	return tween


## Types text into a label character by character
func typewriter(
	label: Label,
	text: String,
	duration: float = 2.0,
	sound_per_char: bool = true
) -> Tween:
	if not is_instance_valid(label):
		return null

	label.text = ""
	label.visible_characters = 0
	label.text = text

	var tween := _create_managed_tween(label, "typewriter")
	var char_count := text.length()

	if char_count == 0:
		return tween

	var char_duration := duration / float(char_count)

	for i in range(char_count):
		tween.tween_property(label, "visible_characters", i + 1, char_duration)
		if sound_per_char and i % 3 == 0:
			tween.tween_callback(func() -> void:
				_play_animation_sound("typewriter")
			)

	animation_started.emit(label, "typewriter")

	tween.finished.connect(func() -> void:
		label.visible_characters = -1
		animation_completed.emit(label, "typewriter")
	, CONNECT_ONE_SHOT)

	return tween


## Applies a heartbeat pulse effect
func heartbeat(
	node: Node,
	scale_amount: float = 0.1,
	duration: float = 1.0,
	loops: int = -1
) -> Tween:
	if not _validate_node(node):
		return null

	var original_scale: Vector2 = _get_scale(node)
	var beat_scale: Vector2 = original_scale * (1.0 + scale_amount)
	var small_beat_scale: Vector2 = original_scale * (1.0 + scale_amount * 0.5)

	var tween := _create_managed_tween(node, "heartbeat")
	tween.set_loops(loops)

	# First beat (bigger)
	tween.tween_property(node, "scale", beat_scale, duration * 0.12) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "scale", original_scale, duration * 0.12) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)

	# Brief pause
	tween.tween_interval(duration * 0.08)

	# Second beat (smaller)
	tween.tween_property(node, "scale", small_beat_scale, duration * 0.10) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "scale", original_scale, duration * 0.10) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)

	# Rest period
	tween.tween_interval(duration * 0.48)

	animation_started.emit(node, "heartbeat")

	return tween


## Idle floating animation
func idle_float(
	node: Node,
	amplitude: float = 5.0,
	duration: float = 3.0,
	loops: int = -1
) -> Tween:
	if not _validate_node(node):
		return null

	var original_pos: Vector2 = _get_position(node)

	var tween := _create_managed_tween(node, "idle_float")
	tween.set_loops(loops)

	tween.tween_property(node, "position:y", original_pos.y - amplitude, duration * 0.5) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "position:y", original_pos.y + amplitude, duration * 0.5) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)

	animation_started.emit(node, "idle_float")

	return tween


## Glitch effect with position jitter
func glitch(
	node: Node,
	intensity: float = 10.0,
	duration: float = 0.5,
	color_shift: bool = true
) -> Tween:
	if not _validate_node(node):
		return null

	_store_original_value(node, "position", _get_position(node))
	_store_original_value(node, "modulate", _get_modulate(node))

	var original_pos: Vector2 = _get_position(node)
	var original_color: Color = _get_modulate(node)

	var tween := _create_managed_tween(node, "glitch")

	var glitch_steps: int = int(duration * 30.0 * _quality_level)
	glitch_steps = maxi(glitch_steps, 5)
	var step_duration: float = duration / float(glitch_steps)

	for i in range(glitch_steps):
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity * 0.3, intensity * 0.3)
		)

		tween.tween_property(node, "position", original_pos + offset, step_duration * 0.5)

		if color_shift and randf() > 0.5:
			var shift_color := Color(
				original_color.r + randf_range(-0.2, 0.2),
				original_color.g + randf_range(-0.2, 0.2),
				original_color.b + randf_range(-0.2, 0.2),
				original_color.a
			)
			tween.parallel().tween_property(node, "modulate", shift_color, step_duration * 0.5)

		tween.tween_property(node, "position", original_pos, step_duration * 0.5)
		if color_shift:
			tween.parallel().tween_property(node, "modulate", original_color, step_duration * 0.5)

	animation_started.emit(node, "glitch")

	tween.finished.connect(func() -> void:
		_set_position(node, original_pos)
		_set_modulate(node, original_color)
		animation_completed.emit(node, "glitch")
	, CONNECT_ONE_SHOT)

	return tween

# endregion


# region - Button Animations

## Animate button hover enter with scale and glow
func button_hover_enter(button: Control, duration: float = DURATION_QUICK) -> Tween:
	var tween := _create_managed_tween(button, "button_hover_enter")
	tween.set_parallel(true)

	tween.tween_property(button, "scale", SCALE_HOVER, duration) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)

	var hover_color := Color(1.15, 1.15, 1.2, 1.0)
	tween.tween_property(button, "modulate", hover_color, duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)

	_play_animation_sound("button_hover")
	animation_started.emit(button, "button_hover_enter")

	return tween


## Animate button hover exit
func button_hover_exit(button: Control, duration: float = DURATION_QUICK) -> Tween:
	var tween := _create_managed_tween(button, "button_hover_exit")
	tween.set_parallel(true)

	tween.tween_property(button, "scale", SCALE_NORMAL, duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(button, "modulate", Color.WHITE, duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)

	animation_started.emit(button, "button_hover_exit")

	return tween


## Animate button press with spring physics
func button_press(button: Control) -> Tween:
	var tween := _create_managed_tween(button, "button_press")

	# Quick squish down
	tween.tween_property(button, "scale", SCALE_PRESS, DURATION_INSTANT) \
		.set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT)

	# Spring overshoot
	tween.tween_property(button, "scale", SCALE_SPRING_OVERSHOOT, DURATION_QUICK) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)

	# Settle to hover state
	tween.tween_property(button, "scale", SCALE_HOVER, DURATION_QUICK) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)

	_play_animation_sound("button_press")
	animation_started.emit(button, "button_press")

	return tween


## Button glow pulse for idle state
func button_glow_pulse(button: Control, glow_color: Color = Color(1.0, 0.8, 0.3)) -> Tween:
	var tween := _create_managed_tween(button, "button_glow_pulse")
	tween.set_loops()

	var pulse_color: Color = Color.WHITE.lerp(glow_color, 0.2)

	tween.tween_property(button, "modulate", pulse_color, 1.0) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(button, "modulate", Color.WHITE, 1.0) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	animation_started.emit(button, "button_glow_pulse")

	return tween

# endregion


# region - Panel Animations

## Panel entrance with 3D-like rotation effect
func panel_enter_3d(panel: Control, from_direction: Vector2 = Vector2.RIGHT) -> Tween:
	var original_pos: Vector2 = panel.position

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.position = original_pos + from_direction * 80

	var tween := _create_managed_tween(panel, "panel_enter_3d")
	tween.set_parallel(true)

	tween.tween_property(panel, "modulate:a", 1.0, DURATION_SMOOTH) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(panel, "scale", SCALE_NORMAL, DURATION_SMOOTH) \
		.set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(panel, "position", original_pos, DURATION_SMOOTH) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)

	_play_animation_sound("panel_open")
	animation_started.emit(panel, "panel_enter_3d")

	return tween


## Panel exit with zoom blur effect
func panel_exit_zoom(panel: Control, zoom_direction: float = 1.15) -> Tween:
	var tween := _create_managed_tween(panel, "panel_exit_zoom")
	tween.set_parallel(true)

	var target_scale: Vector2 = SCALE_NORMAL * zoom_direction

	tween.tween_property(panel, "modulate:a", 0.0, DURATION_NORMAL) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)

	tween.tween_property(panel, "scale", target_scale, DURATION_NORMAL) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)

	_play_animation_sound("panel_close")
	animation_started.emit(panel, "panel_exit_zoom")

	return tween


## Panel slide with elastic easing
func panel_slide(panel: Control, target_pos: Vector2, duration: float = DURATION_SMOOTH) -> Tween:
	var tween := _create_managed_tween(panel, "panel_slide")

	tween.tween_property(panel, "position", target_pos, duration) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)

	animation_started.emit(panel, "panel_slide")

	return tween


## Panel reveal with stagger effect for children
func panel_reveal_staggered(panel: Control, stagger_delay: float = 0.05) -> void:
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.95, 0.95)
	panel.visible = true

	var tween := _create_managed_tween(panel, "panel_reveal_staggered")
	tween.tween_property(panel, "modulate:a", 1.0, DURATION_QUICK)
	tween.tween_property(panel, "scale", SCALE_NORMAL, DURATION_NORMAL) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)

	# Stagger children
	var delay: float = DURATION_QUICK
	for child in panel.get_children():
		if child is Control:
			var child_control := child as Control
			var original_y: float = child_control.position.y

			child_control.modulate.a = 0.0
			child_control.position.y += 20

			var child_tween := _create_managed_tween(child_control, "stagger_child")
			child_tween.set_parallel(true)

			child_tween.tween_property(child_control, "modulate:a", 1.0, DURATION_NORMAL) \
				.set_delay(delay)
			child_tween.tween_property(child_control, "position:y", original_y, DURATION_NORMAL) \
				.set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT) \
				.set_delay(delay)

			delay += stagger_delay

	_play_animation_sound("panel_open")
	animation_started.emit(panel, "panel_reveal_staggered")

# endregion


# region - Transition Animations

## Scene transition - zoom out
func transition_zoom_out(root: Control) -> Tween:
	var tween := _create_managed_tween(root, "transition_zoom_out")
	tween.set_parallel(true)

	tween.tween_property(root, "modulate:a", 0.0, DURATION_SMOOTH) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)

	tween.tween_property(root, "scale", Vector2(1.1, 1.1), DURATION_SMOOTH) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)

	animation_started.emit(root, "transition_zoom_out")

	return tween


## Scene transition - slide out
func transition_slide_out(root: Control, direction: Vector2 = Vector2.LEFT) -> Tween:
	var target_pos: Vector2 = root.position + direction * root.size

	var tween := _create_managed_tween(root, "transition_slide_out")
	tween.set_parallel(true)

	tween.tween_property(root, "modulate:a", 0.0, DURATION_SMOOTH) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)

	tween.tween_property(root, "position", target_pos, DURATION_SMOOTH) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_IN)

	animation_started.emit(root, "transition_slide_out")

	return tween


## Crossfade between two controls
func crossfade(from_control: Control, to_control: Control, duration: float = DURATION_SMOOTH) -> Tween:
	var tween := _create_managed_tween(from_control, "crossfade")
	tween.set_parallel(true)

	tween.tween_property(from_control, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)

	to_control.modulate.a = 0.0
	to_control.visible = true

	tween.tween_property(to_control, "modulate:a", 1.0, duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)

	animation_started.emit(from_control, "crossfade")

	tween.finished.connect(func() -> void:
		from_control.visible = false
		animation_completed.emit(from_control, "crossfade")
	, CONNECT_ONE_SHOT)

	return tween


## Cascade entrance for menu items
func cascade_entrance(items: Array, delay_per_item: float = 0.05, parent: Node = null) -> void:
	var base_node: Node = parent if parent else (items[0].get_parent() if not items.is_empty() else null)
	if not base_node:
		return

	var delay: float = 0.0

	for item in items:
		if not item is Control:
			continue

		var control: Control = item as Control
		var original_pos: Vector2 = control.position
		var original_alpha: float = control.modulate.a

		control.modulate.a = 0.0
		control.position.y += 25
		control.scale = Vector2(0.9, 0.9)

		var tween := _create_managed_tween(control, "cascade_entrance")
		tween.set_parallel(true)

		tween.tween_property(control, "modulate:a", original_alpha, DURATION_NORMAL) \
			.set_delay(delay)

		tween.tween_property(control, "position:y", original_pos.y, DURATION_NORMAL) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT) \
			.set_delay(delay)

		tween.tween_property(control, "scale", SCALE_NORMAL, DURATION_NORMAL) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT) \
			.set_delay(delay)

		delay += delay_per_item

# endregion


# region - Feedback Animations

## Success pop animation
func success_pop(control: Control) -> Tween:
	var tween := _create_managed_tween(control, "success_pop")

	tween.set_parallel(true)
	tween.tween_property(control, "scale", Vector2(1.2, 1.2), DURATION_QUICK) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)

	var success_color := Color(0.3, 1.0, 0.3, 1.0)
	tween.tween_property(control, "modulate", success_color, DURATION_QUICK)

	tween.set_parallel(false)

	tween.set_parallel(true)
	tween.tween_property(control, "scale", SCALE_NORMAL, DURATION_NORMAL) \
		.set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(control, "modulate", Color.WHITE, DURATION_NORMAL)

	_play_animation_sound("success")
	animation_started.emit(control, "success_pop")

	return tween


## Attention pulse for important elements
func attention_pulse(control: Control, pulse_color: Color = Color(1.0, 0.8, 0.2), loops: int = 3) -> Tween:
	var tween := _create_managed_tween(control, "attention_pulse")
	tween.set_loops(loops)

	var bright_color: Color = Color.WHITE.lerp(pulse_color, 0.5)

	tween.tween_property(control, "modulate", bright_color, 0.2) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(control, "modulate", Color.WHITE, 0.2) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	animation_started.emit(control, "attention_pulse")

	return tween


## Error indication animation
func error_indication(control: Control, flash_color: Color = Color(1.0, 0.3, 0.3)) -> Tween:
	# Combine shake with color flash
	shake(control, 10.0, 0.4)

	var tween := _create_managed_tween(control, "error_indication")

	tween.tween_property(control, "modulate", flash_color, 0.1)
	tween.tween_property(control, "modulate", Color.WHITE, 0.1)
	tween.tween_property(control, "modulate", flash_color, 0.1)
	tween.tween_property(control, "modulate", Color.WHITE, 0.1)

	_play_animation_sound("shake")
	animation_started.emit(control, "error_indication")

	return tween

# endregion


# region - Preset Animations

## Applies a preset animation by name
func apply_preset(node: Node, preset_name: String) -> Tween:
	if not PRESETS.has(preset_name):
		push_warning("UIAnimator: Unknown preset '%s'" % preset_name)
		return null

	var preset: Dictionary = PRESETS[preset_name]

	match preset_name:
		"button_hover":
			return scale_bounce(node, preset.get("scale", Vector2.ONE), preset.get("duration", 0.15))
		"button_press":
			return scale_bounce(node, preset.get("scale", Vector2.ONE), preset.get("duration", 0.08))
		"button_release":
			return scale_bounce(node, preset.get("scale", Vector2.ONE), preset.get("duration", 0.2))
		"panel_open":
			_set_scale(node, preset.get("start_scale", Vector2(0.85, 0.85)))
			return scale_bounce(node, preset.get("scale", Vector2.ONE), preset.get("duration", 0.4))
		"panel_close":
			return scale_bounce(node, preset.get("scale", Vector2.ONE), preset.get("duration", 0.25))
		"error_shake":
			return shake(node, preset.get("intensity", 12.0), preset.get("duration", 0.5), preset.get("frequency", 30.0))
		"success_bounce":
			return scale_bounce(node, preset.get("scale", Vector2.ONE), preset.get("duration", 0.5))
		"attention_pulse":
			return pulse_glow(node, Color.WHITE, 1.0, preset.get("scale_range", 0.08), preset.get("loops", -1))
		"tooltip_show":
			_set_scale(node, preset.get("start_scale", Vector2(0.8, 0.8)))
			node.modulate.a = 0.0
			node.visible = true
			var tween := _create_managed_tween(node, "tooltip_show")
			tween.set_parallel(true)
			tween.tween_property(node, "scale", preset.get("scale", Vector2.ONE), preset.get("duration", 0.2)) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(node, "modulate:a", 1.0, preset.get("duration", 0.2))
			return tween
		_:
			return null

# endregion


# region - Sequence Builder

## Creates a new animation sequence builder
func sequence() -> AnimationSequence:
	return AnimationSequence.new(self)

# endregion


# region - Animation Management

## Stops all animations on a specific node
func stop_animations(node: Node, restore_original: bool = false) -> void:
	if not is_instance_valid(node):
		return

	if _active_tweens.has(node):
		var tweens: Array = _active_tweens[node]
		for tween: Tween in tweens:
			if is_instance_valid(tween) and tween.is_running():
				tween.kill()
				animation_interrupted.emit(node, "unknown")
		_active_tweens.erase(node)

	if restore_original and _original_values.has(node):
		_restore_original_values(node)


## Stops all active animations globally
func stop_all_animations(restore_original: bool = false) -> void:
	for node: Node in _active_tweens.keys():
		stop_animations(node, restore_original)
	_active_tweens.clear()
	_animation_queue.clear()


## Pauses all animations on a node
func pause_animations(node: Node) -> void:
	if not _active_tweens.has(node):
		return

	for tween: Tween in _active_tweens[node]:
		if is_instance_valid(tween) and tween.is_running():
			tween.pause()


## Resumes all paused animations on a node
func resume_animations(node: Node) -> void:
	if not _active_tweens.has(node):
		return

	for tween: Tween in _active_tweens[node]:
		if is_instance_valid(tween):
			tween.play()


## Checks if a node has any active animations
func is_animating(node: Node) -> bool:
	if not _active_tweens.has(node):
		return false

	for tween: Tween in _active_tweens[node]:
		if is_instance_valid(tween) and tween.is_running():
			return true

	return false


## Gets the current animation count
func get_active_animation_count() -> int:
	var count: int = 0
	for tweens: Array in _active_tweens.values():
		for tween: Tween in tweens:
			if is_instance_valid(tween) and tween.is_running():
				count += 1
	return count


## Resets a control to default state
func reset_state(control: Control) -> void:
	stop_animations(control, true)
	control.scale = SCALE_NORMAL
	control.modulate = Color.WHITE
	control.rotation = 0.0

# endregion


# region - Performance Management

## Sets the quality level (0.0-1.0) for performance optimization
func set_quality_level(quality: float) -> void:
	_quality_level = clampf(quality, 0.1, 1.0)
	performance_optimized.emit(_quality_level)


## Gets the current quality level
func get_quality_level() -> float:
	return _quality_level


## Gets performance statistics
func get_performance_stats() -> Dictionary:
	var avg_frame_time: float = 0.0
	if not _frame_times.is_empty():
		for ft: float in _frame_times:
			avg_frame_time += ft
		avg_frame_time /= _frame_times.size()

	return {
		"active_animations": get_active_animation_count(),
		"quality_level": _quality_level,
		"average_frame_time_ms": avg_frame_time * 1000.0,
		"estimated_fps": 1.0 / avg_frame_time if avg_frame_time > 0.0 else 0.0,
	}


## Enables performance profiling
func enable_profiling(enabled: bool = true) -> void:
	_profiling_enabled = enabled
	if not enabled:
		_profiling_data.clear()


## Gets profiling data
func get_profiling_data() -> Dictionary:
	return _profiling_data.duplicate()


func _track_performance(delta: float) -> void:
	_frame_times.append(delta)
	if _frame_times.size() > 60:
		_frame_times.remove_at(0)

	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_perf_check > PERFORMANCE_CHECK_INTERVAL:
		_last_perf_check = current_time
		_auto_adjust_quality()


func _auto_adjust_quality() -> void:
	if _frame_times.size() < 30:
		return

	var avg_frame_time: float = 0.0
	for ft: float in _frame_times:
		avg_frame_time += ft
	avg_frame_time /= _frame_times.size()

	# Reduce quality if performance is suffering
	if avg_frame_time > QUALITY_REDUCTION_THRESHOLD:
		set_quality_level(_quality_level * 0.9)
	elif avg_frame_time < TARGET_FRAME_TIME and _quality_level < 1.0:
		set_quality_level(minf(_quality_level * 1.05, 1.0))

# endregion


# region - Utility Functions

## Calculate parallax offset based on mouse position
func calculate_parallax_offset(viewport_size: Vector2, mouse_pos: Vector2, depth: float = 1.0) -> Vector2:
	var center: Vector2 = viewport_size / 2
	var offset: Vector2 = (mouse_pos - center) / center
	return offset * depth * 20.0


## Calculate magnetic snap offset towards cursor
func calculate_magnetic_offset(control: Control, cursor_pos: Vector2, radius: float = 100.0, strength: float = 0.3) -> Vector2:
	var control_center: Vector2 = control.global_position + control.size / 2
	var distance: float = control_center.distance_to(cursor_pos)

	if distance > radius or distance < 1.0:
		return Vector2.ZERO

	var direction: Vector2 = (cursor_pos - control_center).normalized()
	var factor: float = (1.0 - distance / radius) * strength

	return direction * factor * 20.0


## Apply parallax to multiple layers
func apply_parallax_layers(layers: Array, mouse_pos: Vector2, viewport_size: Vector2) -> void:
	for i in range(layers.size()):
		if not layers[i] is Control:
			continue

		var layer: Control = layers[i] as Control
		var depth: float = float(i + 1) / float(layers.size())
		var offset: Vector2 = calculate_parallax_offset(viewport_size, mouse_pos, depth)

		layer.position = layer.position.lerp(offset, 0.1)

# endregion


# region - Internal Helpers

func _validate_node(node: Node) -> bool:
	if not is_instance_valid(node):
		push_warning("UIAnimator: Invalid node provided")
		return false
	return true


func _create_managed_tween(node: Node, animation_type: String) -> Tween:
	# Check if we should throttle animations for performance
	if get_active_animation_count() >= MAX_CONCURRENT_ANIMATIONS:
		_stop_oldest_animation()

	var tween := create_tween()

	if not _active_tweens.has(node):
		_active_tweens[node] = []

	_active_tweens[node].append(tween)

	if _profiling_enabled:
		if not _profiling_data.has(animation_type):
			_profiling_data[animation_type] = {"count": 0, "total_time": 0.0}
		_profiling_data[animation_type]["count"] += 1

	return tween


func _stop_oldest_animation() -> void:
	for node: Node in _active_tweens.keys():
		var tweens: Array = _active_tweens[node]
		for tween: Tween in tweens:
			if is_instance_valid(tween) and tween.is_running():
				tween.kill()
				tweens.erase(tween)
				return


func _cleanup_finished_animations() -> void:
	var nodes_to_clean: Array[Node] = []

	for node: Node in _active_tweens.keys():
		if not is_instance_valid(node):
			nodes_to_clean.append(node)
			continue

		var tweens: Array = _active_tweens[node]
		var i: int = tweens.size() - 1
		while i >= 0:
			var tween: Tween = tweens[i]
			if not is_instance_valid(tween) or not tween.is_running():
				tweens.remove_at(i)
			i -= 1

		if tweens.is_empty():
			nodes_to_clean.append(node)

	for node: Node in nodes_to_clean:
		_active_tweens.erase(node)


func _store_original_value(node: Node, property: String, value: Variant) -> void:
	if not _original_values.has(node):
		_original_values[node] = {}
	if not _original_values[node].has(property):
		_original_values[node][property] = value


func _restore_original_values(node: Node) -> void:
	if not _original_values.has(node):
		return

	var values: Dictionary = _original_values[node]
	for property: String in values.keys():
		match property:
			"modulate":
				_set_modulate(node, values[property])
			"scale":
				_set_scale(node, values[property])
			"position":
				_set_position(node, values[property])
			"rotation":
				_set_rotation(node, values[property])

	_original_values.erase(node)


func _calculate_slide_position(base_pos: Vector2, direction: Direction, distance: float) -> Vector2:
	match direction:
		Direction.LEFT:
			return base_pos + Vector2(-distance, 0)
		Direction.RIGHT:
			return base_pos + Vector2(distance, 0)
		Direction.UP:
			return base_pos + Vector2(0, -distance)
		Direction.DOWN:
			return base_pos + Vector2(0, distance)
		Direction.CENTER:
			return base_pos
	return base_pos


func _play_animation_sound(animation_type: String) -> void:
	if not _animation_sounds.has(animation_type):
		return

	var sound_key: String = _animation_sounds[animation_type]

	# Try to play through AudioManager autoload
	var tree: SceneTree = get_tree()
	if tree and tree.root.has_node("AudioManager"):
		var audio_manager: Node = tree.root.get_node("AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx(sound_key)


# Property accessors for Control vs Node2D compatibility
func _get_modulate(node: Node) -> Color:
	if node is CanvasItem:
		return (node as CanvasItem).modulate
	return Color.WHITE


func _set_modulate(node: Node, color: Color) -> void:
	if node is CanvasItem:
		(node as CanvasItem).modulate = color


func _set_modulate_alpha(node: Node, alpha: float) -> void:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		canvas_item.modulate.a = alpha


func _get_scale(node: Node) -> Vector2:
	if node is Control:
		return (node as Control).scale
	elif node is Node2D:
		return (node as Node2D).scale
	return Vector2.ONE


func _set_scale(node: Node, scale_value: Vector2) -> void:
	if node is Control:
		(node as Control).scale = scale_value
	elif node is Node2D:
		(node as Node2D).scale = scale_value


func _get_position(node: Node) -> Vector2:
	if node is Control:
		return (node as Control).position
	elif node is Node2D:
		return (node as Node2D).position
	return Vector2.ZERO


func _set_position(node: Node, pos: Vector2) -> void:
	if node is Control:
		(node as Control).position = pos
	elif node is Node2D:
		(node as Node2D).position = pos


func _get_rotation(node: Node) -> float:
	if node is Control:
		return (node as Control).rotation
	elif node is Node2D:
		return (node as Node2D).rotation
	return 0.0


func _set_rotation(node: Node, rot: float) -> void:
	if node is Control:
		(node as Control).rotation = rot
	elif node is Node2D:
		(node as Node2D).rotation = rot


func _get_ease_type(easing_name: String) -> Tween.EaseType:
	if "in_out" in easing_name:
		return Tween.EASE_IN_OUT
	elif "out" in easing_name:
		return Tween.EASE_OUT
	elif "in" in easing_name:
		return Tween.EASE_IN
	return Tween.EASE_OUT


func _get_trans_type(easing_name: String) -> Tween.TransitionType:
	var base_name := easing_name.replace("_in_out", "").replace("_out", "").replace("_in", "")

	match base_name:
		"quad":
			return Tween.TRANS_QUAD
		"cubic":
			return Tween.TRANS_CUBIC
		"quart":
			return Tween.TRANS_QUART
		"quint":
			return Tween.TRANS_QUINT
		"sine":
			return Tween.TRANS_SINE
		"expo":
			return Tween.TRANS_EXPO
		"circ":
			return Tween.TRANS_CIRC
		"elastic":
			return Tween.TRANS_ELASTIC
		"back":
			return Tween.TRANS_BACK
		"bounce":
			return Tween.TRANS_BOUNCE
		"spring":
			return Tween.TRANS_SPRING
		_:
			return Tween.TRANS_QUAD

# endregion


# region - Animation Sequence Inner Class

## Fluent animation sequence builder for chaining animations
class AnimationSequence extends RefCounted:
	var _animator: Node
	var _steps: Array[Dictionary] = []
	var _current_tween: Tween = null
	var _is_playing: bool = false
	var _on_complete_callback: Callable

	func _init(animator: Node) -> void:
		_animator = animator

	## Adds a fade in animation to the sequence
	func then_fade_in(node: Node, duration: float = 0.3, easing: String = "quad_out") -> AnimationSequence:
		_steps.append({
			"type": "fade_in",
			"node": node,
			"duration": duration,
			"easing": easing,
			"parallel": false,
		})
		return self

	## Adds a fade out animation to the sequence
	func then_fade_out(node: Node, duration: float = 0.3, easing: String = "quad_in") -> AnimationSequence:
		_steps.append({
			"type": "fade_out",
			"node": node,
			"duration": duration,
			"easing": easing,
			"parallel": false,
		})
		return self

	## Adds a scale animation to the sequence
	func then_scale(node: Node, target_scale: Vector2, duration: float = 0.25, easing: String = "back_out") -> AnimationSequence:
		_steps.append({
			"type": "scale",
			"node": node,
			"target_scale": target_scale,
			"duration": duration,
			"easing": easing,
			"parallel": false,
		})
		return self

	## Adds a slide in animation to the sequence
	func then_slide_in(node: Node, direction: int = 0, distance: float = 100.0, duration: float = 0.4) -> AnimationSequence:
		_steps.append({
			"type": "slide_in",
			"node": node,
			"direction": direction,
			"distance": distance,
			"duration": duration,
			"parallel": false,
		})
		return self

	## Adds a slide out animation to the sequence
	func then_slide_out(node: Node, direction: int = 0, distance: float = 100.0, duration: float = 0.4) -> AnimationSequence:
		_steps.append({
			"type": "slide_out",
			"node": node,
			"direction": direction,
			"distance": distance,
			"duration": duration,
			"parallel": false,
		})
		return self

	## Adds a shake animation to the sequence
	func then_shake(node: Node, intensity: float = 10.0, duration: float = 0.4) -> AnimationSequence:
		_steps.append({
			"type": "shake",
			"node": node,
			"intensity": intensity,
			"duration": duration,
			"parallel": false,
		})
		return self

	## Adds a bounce animation to the sequence
	func then_bounce(node: Node, scale_amount: float = 0.15, duration: float = 0.3) -> AnimationSequence:
		_steps.append({
			"type": "bounce",
			"node": node,
			"scale_amount": scale_amount,
			"duration": duration,
			"parallel": false,
		})
		return self

	## Adds a pop in animation to the sequence
	func then_pop_in(node: Node, duration: float = 0.4) -> AnimationSequence:
		_steps.append({
			"type": "pop_in",
			"node": node,
			"duration": duration,
			"parallel": false,
		})
		return self

	## Adds a pop out animation to the sequence
	func then_pop_out(node: Node, duration: float = 0.25) -> AnimationSequence:
		_steps.append({
			"type": "pop_out",
			"node": node,
			"duration": duration,
			"parallel": false,
		})
		return self

	## Adds a color transition to the sequence
	func then_color(node: Node, target_color: Color, duration: float = 0.3) -> AnimationSequence:
		_steps.append({
			"type": "color",
			"node": node,
			"target_color": target_color,
			"duration": duration,
			"parallel": false,
		})
		return self

	## Adds a wait/delay to the sequence
	func wait(duration: float) -> AnimationSequence:
		_steps.append({
			"type": "wait",
			"duration": duration,
			"parallel": false,
		})
		return self

	## Makes the next animation run in parallel with the previous
	func parallel_fade_in(node: Node, duration: float = 0.3) -> AnimationSequence:
		_steps.append({
			"type": "fade_in",
			"node": node,
			"duration": duration,
			"easing": "quad_out",
			"parallel": true,
		})
		return self

	## Runs a scale animation in parallel
	func parallel_scale(node: Node, target_scale: Vector2, duration: float = 0.25) -> AnimationSequence:
		_steps.append({
			"type": "scale",
			"node": node,
			"target_scale": target_scale,
			"duration": duration,
			"easing": "back_out",
			"parallel": true,
		})
		return self

	## Runs a slide in animation in parallel
	func parallel_slide_in(node: Node, direction: int = 0, distance: float = 100.0, duration: float = 0.4) -> AnimationSequence:
		_steps.append({
			"type": "slide_in",
			"node": node,
			"direction": direction,
			"distance": distance,
			"duration": duration,
			"parallel": true,
		})
		return self

	## Adds a callback to execute
	func then_callback(callable: Callable) -> AnimationSequence:
		_steps.append({
			"type": "callback",
			"callable": callable,
			"parallel": false,
		})
		return self

	## Sets the completion callback
	func on_complete(callable: Callable) -> AnimationSequence:
		_on_complete_callback = callable
		return self

	## Plays the animation sequence
	func play() -> void:
		if _steps.is_empty():
			return

		_is_playing = true
		_play_step(0)

	## Stops the animation sequence
	func stop() -> void:
		_is_playing = false
		if _current_tween and _current_tween.is_valid():
			_current_tween.kill()

	## Checks if the sequence is currently playing
	func is_playing() -> bool:
		return _is_playing

	func _play_step(index: int) -> void:
		if index >= _steps.size() or not _is_playing:
			_is_playing = false
			if _on_complete_callback.is_valid():
				_on_complete_callback.call()
			return

		var step: Dictionary = _steps[index]

		# Find all parallel steps starting from this index
		var parallel_steps: Array[int] = [index]
		var next_sequential_index: int = index + 1

		while next_sequential_index < _steps.size():
			if _steps[next_sequential_index].get("parallel", false):
				parallel_steps.append(next_sequential_index)
				next_sequential_index += 1
			else:
				break

		# Execute all parallel steps
		var max_duration: float = 0.0
		for step_index: int in parallel_steps:
			var current_step: Dictionary = _steps[step_index]
			var duration: float = _execute_step(current_step)
			max_duration = maxf(max_duration, duration)

		# Wait for the longest animation then continue
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree and max_duration > 0.0:
			await tree.create_timer(max_duration).timeout
			_play_step(next_sequential_index)
		elif tree:
			_play_step(next_sequential_index)

	func _execute_step(step: Dictionary) -> float:
		var step_type: String = step.get("type", "")
		var duration: float = step.get("duration", 0.0)

		match step_type:
			"fade_in":
				_animator.fade_in(step["node"], duration, 0.0, step.get("easing", "quad_out"))
			"fade_out":
				_animator.fade_out(step["node"], duration, 0.0, step.get("easing", "quad_in"))
			"scale":
				_animator.scale_bounce(step["node"], step["target_scale"], duration, step.get("easing", "back_out"))
			"slide_in":
				_animator.slide_in(step["node"], step["direction"], step["distance"], duration)
			"slide_out":
				_animator.slide_out(step["node"], step["direction"], step["distance"], duration)
			"shake":
				_animator.shake(step["node"], step["intensity"], duration)
			"bounce":
				_animator.bounce(step["node"], step["scale_amount"], duration)
			"pop_in":
				_animator.pop_in(step["node"], duration)
			"pop_out":
				_animator.pop_out(step["node"], duration)
			"color":
				_animator.color_transition(step["node"], step["target_color"], duration)
			"wait":
				pass
			"callback":
				var callable: Callable = step.get("callable", Callable())
				if callable.is_valid():
					callable.call()
				return 0.0

		return duration

# endregion
