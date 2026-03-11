## TweenExtensions - Extended tween utilities for UI animations.
##
## Provides helper functions and extension methods for working with tweens:
## - Chaining helpers
## - Property animation shortcuts
## - Animation presets
## - Parallel/sequential composition
##
## Usage:
##   TweenExtensions.fade_in_out(node, 0.3, 1.0, 0.3)
##   TweenExtensions.scale_pop(node, Vector2(1.2, 1.2), 0.3)
##   TweenExtensions.parallel_animations(node, [anim1, anim2])
class_name TweenExtensions
extends RefCounted


# region - Types

## Animation configuration
class AnimationConfig extends RefCounted:
	var property: String
	var start_value: Variant
	var end_value: Variant
	var duration: float
	var ease_type: Tween.EaseType = Tween.EASE_OUT
	var trans_type: Tween.TransitionType = Tween.TRANS_QUAD
	var delay: float = 0.0

	func _init(
		p_property: String = "",
		p_start: Variant = null,
		p_end: Variant = null,
		p_duration: float = 0.3
	) -> void:
		property = p_property
		start_value = p_start
		end_value = p_end
		duration = p_duration

# endregion


# region - Fade Animations

## Fades a node in and then out
static func fade_in_out(
	node: CanvasItem,
	fade_in_duration: float = 0.3,
	hold_duration: float = 1.0,
	fade_out_duration: float = 0.3
) -> Tween:
	node.modulate.a = 0.0
	node.visible = true

	var tween := node.create_tween()

	# Fade in
	tween.tween_property(node, "modulate:a", 1.0, fade_in_duration) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)

	# Hold
	if hold_duration > 0.0:
		tween.tween_interval(hold_duration)

	# Fade out
	tween.tween_property(node, "modulate:a", 0.0, fade_out_duration) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)

	tween.finished.connect(func() -> void:
		node.visible = false
	)

	return tween


## Crossfades between two nodes
static func crossfade_nodes(
	from_node: CanvasItem,
	to_node: CanvasItem,
	duration: float = 0.5
) -> Tween:
	to_node.modulate.a = 0.0
	to_node.visible = true

	var tween := from_node.create_tween()
	tween.set_parallel(true)

	tween.tween_property(from_node, "modulate:a", 0.0, duration) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_CUBIC)

	tween.tween_property(to_node, "modulate:a", 1.0, duration) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_CUBIC)

	tween.finished.connect(func() -> void:
		from_node.visible = false
	)

	return tween


## Blinks a node (flash on/off)
static func blink(
	node: CanvasItem,
	times: int = 3,
	on_duration: float = 0.1,
	off_duration: float = 0.1
) -> Tween:
	var original_alpha := node.modulate.a
	var tween := node.create_tween()

	for _i in range(times):
		tween.tween_property(node, "modulate:a", 0.0, off_duration * 0.5)
		tween.tween_property(node, "modulate:a", original_alpha, on_duration * 0.5)

	return tween

# endregion


# region - Scale Animations

## Scale pop animation (grow and shrink back)
static func scale_pop(
	node: Node,
	peak_scale: Vector2 = Vector2(1.2, 1.2),
	duration: float = 0.3
) -> Tween:
	var original_scale := _get_scale(node)
	var tween := node.create_tween()

	# Pop up
	tween.tween_property(node, "scale", peak_scale, duration * 0.4) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)

	# Settle back
	tween.tween_property(node, "scale", original_scale, duration * 0.6) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_ELASTIC)

	return tween


## Scale squash and stretch
static func squash_stretch(
	node: Node,
	squash_amount: float = 0.2,
	duration: float = 0.4
) -> Tween:
	var original_scale := _get_scale(node)
	var squash_scale := Vector2(original_scale.x * (1.0 + squash_amount), original_scale.y * (1.0 - squash_amount))
	var stretch_scale := Vector2(original_scale.x * (1.0 - squash_amount * 0.5), original_scale.y * (1.0 + squash_amount * 0.5))

	var tween := node.create_tween()

	# Squash
	tween.tween_property(node, "scale", squash_scale, duration * 0.25) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)

	# Stretch
	tween.tween_property(node, "scale", stretch_scale, duration * 0.25) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)

	# Return to normal with bounce
	tween.tween_property(node, "scale", original_scale, duration * 0.5) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_ELASTIC)

	return tween


## Scale breathing animation (subtle continuous scale)
static func scale_breathe(
	node: Node,
	breath_amount: float = 0.05,
	duration: float = 2.0,
	loops: int = -1
) -> Tween:
	var original_scale := _get_scale(node)
	var inhale_scale := original_scale * (1.0 + breath_amount)
	var exhale_scale := original_scale * (1.0 - breath_amount * 0.5)

	var tween := node.create_tween()
	tween.set_loops(loops)

	# Inhale
	tween.tween_property(node, "scale", inhale_scale, duration * 0.4) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)

	# Exhale
	tween.tween_property(node, "scale", exhale_scale, duration * 0.4) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)

	# Return to center
	tween.tween_property(node, "scale", original_scale, duration * 0.2) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)

	return tween

# endregion


# region - Position Animations

## Slide from direction
static func slide_from(
	node: Node,
	direction: Vector2,
	distance: float = 100.0,
	duration: float = 0.4
) -> Tween:
	var target_pos := _get_position(node)
	var start_pos := target_pos + direction.normalized() * distance

	_set_position(node, start_pos)

	var tween := node.create_tween()

	tween.tween_property(node, "position", target_pos, duration) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)

	return tween


## Slide to direction
static func slide_to(
	node: Node,
	direction: Vector2,
	distance: float = 100.0,
	duration: float = 0.4
) -> Tween:
	var start_pos := _get_position(node)
	var target_pos := start_pos + direction.normalized() * distance

	var tween := node.create_tween()

	tween.tween_property(node, "position", target_pos, duration) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_BACK)

	return tween


## Bounce in place
static func bounce_position(
	node: Node,
	height: float = 20.0,
	duration: float = 0.5,
	bounces: int = 2
) -> Tween:
	var original_pos := _get_position(node)
	var tween := node.create_tween()

	for i in range(bounces):
		var bounce_height: float = height * pow(0.5, i)
		var bounce_duration: float = duration / float(bounces) / 2.0

		# Up
		tween.tween_property(node, "position:y", original_pos.y - bounce_height, bounce_duration) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)

		# Down
		tween.tween_property(node, "position:y", original_pos.y, bounce_duration) \
			.set_ease(Tween.EASE_IN) \
			.set_trans(Tween.TRANS_QUAD)

	return tween


## Orbit around a point
static func orbit(
	node: Node,
	center: Vector2,
	radius: float = 50.0,
	duration: float = 2.0,
	loops: int = -1
) -> Tween:
	var tween := node.create_tween()
	tween.set_loops(loops)

	var steps: int = 36  # 10 degree increments
	var step_duration: float = duration / float(steps)

	for i in range(steps):
		var angle: float = (float(i) / float(steps)) * TAU
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		tween.tween_property(node, "position", pos, step_duration)

	return tween

# endregion


# region - Rotation Animations

## Spin animation
static func spin(
	node: Node,
	rotations: float = 1.0,
	duration: float = 0.5,
	clockwise: bool = true
) -> Tween:
	var original_rotation := _get_rotation(node)
	var direction: float = 1.0 if clockwise else -1.0
	var target_rotation := original_rotation + TAU * rotations * direction

	var tween := node.create_tween()

	tween.tween_property(node, "rotation", target_rotation, duration) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_CUBIC)

	return tween


## Wobble rotation
static func wobble(
	node: Node,
	max_angle: float = 15.0,
	duration: float = 0.5,
	wobbles: int = 3
) -> Tween:
	var original_rotation := _get_rotation(node)
	var tween := node.create_tween()
	var wobble_duration: float = duration / float(wobbles)

	for i in range(wobbles):
		var decay: float = 1.0 - (float(i) / float(wobbles))
		var angle: float = deg_to_rad(max_angle * decay)

		tween.tween_property(node, "rotation", original_rotation + angle, wobble_duration * 0.25)
		tween.tween_property(node, "rotation", original_rotation - angle, wobble_duration * 0.5)
		tween.tween_property(node, "rotation", original_rotation, wobble_duration * 0.25)

	return tween

# endregion


# region - Color Animations

## Flash color
static func color_flash(
	node: CanvasItem,
	flash_color: Color,
	duration: float = 0.2
) -> Tween:
	var original_color := node.modulate
	var tween := node.create_tween()

	tween.tween_property(node, "modulate", flash_color, duration * 0.3) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_EXPO)

	tween.tween_property(node, "modulate", original_color, duration * 0.7) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_QUAD)

	return tween


## Rainbow color cycle
static func color_rainbow(
	node: CanvasItem,
	duration: float = 2.0,
	saturation: float = 0.8,
	loops: int = -1
) -> Tween:
	var tween := node.create_tween()
	tween.set_loops(loops)

	var steps: int = 12
	var step_duration: float = duration / float(steps)

	for i in range(steps):
		var hue: float = float(i) / float(steps)
		var color := Color.from_hsv(hue, saturation, 1.0)
		tween.tween_property(node, "modulate", color, step_duration) \
			.set_ease(Tween.EASE_IN_OUT) \
			.set_trans(Tween.TRANS_SINE)

	return tween


## Gradient between two colors
static func color_gradient(
	node: CanvasItem,
	from_color: Color,
	to_color: Color,
	duration: float = 1.0,
	ping_pong: bool = false,
	loops: int = 1
) -> Tween:
	node.modulate = from_color

	var tween := node.create_tween()
	if ping_pong:
		tween.set_loops(loops)

	tween.tween_property(node, "modulate", to_color, duration) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)

	if ping_pong:
		tween.tween_property(node, "modulate", from_color, duration) \
			.set_ease(Tween.EASE_IN_OUT) \
			.set_trans(Tween.TRANS_SINE)

	return tween

# endregion


# region - Complex Animations

## Entrance animation combining scale, fade, and position
static func entrance_complex(
	node: CanvasItem,
	from_direction: Vector2 = Vector2.DOWN,
	distance: float = 50.0,
	duration: float = 0.5
) -> Tween:
	var target_pos := _get_position(node)
	var start_pos := target_pos + from_direction.normalized() * distance

	node.modulate.a = 0.0
	_set_position(node, start_pos)
	_set_scale(node, Vector2(0.8, 0.8))
	node.visible = true

	var tween := node.create_tween()
	tween.set_parallel(true)

	tween.tween_property(node, "modulate:a", 1.0, duration * 0.6) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)

	tween.tween_property(node, "position", target_pos, duration) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)

	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.8) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_ELASTIC)

	return tween


## Exit animation combining scale, fade, and position
static func exit_complex(
	node: CanvasItem,
	to_direction: Vector2 = Vector2.DOWN,
	distance: float = 50.0,
	duration: float = 0.4
) -> Tween:
	var start_pos := _get_position(node)
	var target_pos := start_pos + to_direction.normalized() * distance

	var tween := node.create_tween()
	tween.set_parallel(true)

	tween.tween_property(node, "modulate:a", 0.0, duration) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)

	tween.tween_property(node, "position", target_pos, duration) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_BACK)

	tween.tween_property(node, "scale", Vector2(0.8, 0.8), duration) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)

	tween.finished.connect(func() -> void:
		node.visible = false
		_set_position(node, start_pos)
		_set_scale(node, Vector2.ONE)
	)

	return tween


## Attention grabber (combines multiple effects)
static func grab_attention(
	node: CanvasItem,
	duration: float = 1.0
) -> Tween:
	var original_scale := _get_scale(node)
	var original_rotation := _get_rotation(node)
	var original_color := node.modulate

	var tween := node.create_tween()

	# Initial pop
	tween.tween_property(node, "scale", original_scale * 1.3, duration * 0.1) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_EXPO)

	# Wobble with color flash
	tween.set_parallel(true)

	tween.tween_property(node, "scale", original_scale, duration * 0.3) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_ELASTIC)

	var bright_color := Color(1.5, 1.5, 1.5, original_color.a)
	tween.tween_property(node, "modulate", bright_color, duration * 0.1)

	tween.set_parallel(false)

	# Wobble rotation
	for i in range(2):
		var angle: float = deg_to_rad(10.0 * (1.0 - float(i) * 0.5))
		tween.tween_property(node, "rotation", original_rotation + angle, duration * 0.1)
		tween.tween_property(node, "rotation", original_rotation - angle, duration * 0.1)

	# Return to normal
	tween.set_parallel(true)
	tween.tween_property(node, "rotation", original_rotation, duration * 0.2)
	tween.tween_property(node, "modulate", original_color, duration * 0.2)

	return tween

# endregion


# region - Composition Utilities

## Run multiple tweens in parallel on a node
static func parallel_tweens(
	node: Node,
	configs: Array[AnimationConfig]
) -> Tween:
	var tween := node.create_tween()
	tween.set_parallel(true)

	for config in configs:
		if config.start_value != null:
			node.set(config.property, config.start_value)

		var tweener := tween.tween_property(node, config.property, config.end_value, config.duration)
		tweener.set_ease(config.ease_type)
		tweener.set_trans(config.trans_type)
		if config.delay > 0.0:
			tweener.set_delay(config.delay)

	return tween


## Run multiple tweens in sequence on a node
static func sequential_tweens(
	node: Node,
	configs: Array[AnimationConfig]
) -> Tween:
	var tween := node.create_tween()

	for config in configs:
		if config.start_value != null:
			node.set(config.property, config.start_value)

		if config.delay > 0.0:
			tween.tween_interval(config.delay)

		tween.tween_property(node, config.property, config.end_value, config.duration) \
			.set_ease(config.ease_type) \
			.set_trans(config.trans_type)

	return tween


## Chain multiple tween functions
static func chain(
	node: Node,
	animations: Array[Callable],
	delays: Array[float] = []
) -> void:
	var current_delay: float = 0.0

	for i in range(animations.size()):
		if i < delays.size():
			current_delay += delays[i]

		if current_delay > 0.0:
			var tree := node.get_tree()
			if tree:
				var timer := tree.create_timer(current_delay)
				var anim := animations[i]
				timer.timeout.connect(func() -> void:
					anim.call(node)
				)
		else:
			animations[i].call(node)

# endregion


# region - Property Helpers

static func _get_scale(node: Node) -> Vector2:
	if node is Control:
		return (node as Control).scale
	elif node is Node2D:
		return (node as Node2D).scale
	return Vector2.ONE


static func _set_scale(node: Node, value: Vector2) -> void:
	if node is Control:
		(node as Control).scale = value
	elif node is Node2D:
		(node as Node2D).scale = value


static func _get_position(node: Node) -> Vector2:
	if node is Control:
		return (node as Control).position
	elif node is Node2D:
		return (node as Node2D).position
	return Vector2.ZERO


static func _set_position(node: Node, value: Vector2) -> void:
	if node is Control:
		(node as Control).position = value
	elif node is Node2D:
		(node as Node2D).position = value


static func _get_rotation(node: Node) -> float:
	if node is Control:
		return (node as Control).rotation
	elif node is Node2D:
		return (node as Node2D).rotation
	return 0.0

# endregion
