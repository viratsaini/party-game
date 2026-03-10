## Premium animated panel with smooth entrance/exit transitions.
## Features: multiple animation styles, blur background, scale/fade effects.
## Perfect for menus, dialogs, and overlays.
class_name AnimatedPanel
extends PanelContainer

## Animation style for entrance/exit.
enum AnimationType {
	FADE,              ## Simple fade in/out.
	SCALE,             ## Scale from center.
	SLIDE_UP,          ## Slide from bottom.
	SLIDE_DOWN,        ## Slide from top.
	SLIDE_LEFT,        ## Slide from right.
	SLIDE_RIGHT,       ## Slide from left.
	BLUR_FADE,         ## Fade with blur effect.
	BOUNCE,            ## Bounce entrance.
	ELASTIC,           ## Elastic easing.
	ROTATE_SCALE,      ## Rotate + scale.
}

## Entrance animation type.
@export var entrance_animation: AnimationType = AnimationType.SCALE

## Exit animation type.
@export var exit_animation: AnimationType = AnimationType.FADE

## Animation duration in seconds.
@export_range(0.1, 2.0) var animation_duration: float = 0.4

## Enable blur background overlay.
@export var enable_blur_background: bool = true

## Blur background opacity.
@export_range(0.0, 1.0) var blur_background_alpha: float = 0.7

## Automatically show on ready.
@export var auto_show: bool = false

## Delay before showing (if auto_show is true).
@export_range(0.0, 5.0) var show_delay: float = 0.0

## Tween for animations.
var _tween: Tween = null

## Blur background overlay.
var _blur_overlay: ColorRect = null

## Is currently visible (animation state).
var _is_visible: bool = false

## Original position (for slide animations).
var _original_position: Vector2 = Vector2.ZERO

## Signal emitted when show animation completes.
signal show_completed()

## Signal emitted when hide animation completes.
signal hide_completed()


func _ready() -> void:
	# Store original position.
	_original_position = position

	# Setup blur background if enabled.
	if enable_blur_background:
		_setup_blur_background()

	# Start hidden.
	modulate.a = 0.0
	scale = Vector2.ZERO
	visible = false

	if auto_show:
		if show_delay > 0.0:
			await get_tree().create_timer(show_delay).timeout
		show_panel()


## Setup blur background overlay.
func _setup_blur_background() -> void:
	_blur_overlay = ColorRect.new()
	_blur_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_blur_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_blur_overlay.z_index = z_index - 1

	# Full screen overlay.
	_blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Add as sibling (not child) to avoid affecting panel layout.
	var parent: Node = get_parent()
	if parent:
		parent.add_child(_blur_overlay)
		parent.move_child(_blur_overlay, get_index())


## Show panel with entrance animation.
func show_panel() -> void:
	if _is_visible:
		return

	_is_visible = true
	visible = true

	# Cancel any existing tween.
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_BACK)

	# Animate blur background.
	if _blur_overlay:
		_blur_overlay.visible = true
		_tween.tween_property(_blur_overlay, "color:a", blur_background_alpha, animation_duration)

	# Apply entrance animation.
	match entrance_animation:
		AnimationType.FADE:
			_animate_fade_in(_tween)
		AnimationType.SCALE:
			_animate_scale_in(_tween)
		AnimationType.SLIDE_UP:
			_animate_slide_in(_tween, Vector2(0, 200))
		AnimationType.SLIDE_DOWN:
			_animate_slide_in(_tween, Vector2(0, -200))
		AnimationType.SLIDE_LEFT:
			_animate_slide_in(_tween, Vector2(200, 0))
		AnimationType.SLIDE_RIGHT:
			_animate_slide_in(_tween, Vector2(-200, 0))
		AnimationType.BLUR_FADE:
			_animate_blur_fade_in(_tween)
		AnimationType.BOUNCE:
			_animate_bounce_in(_tween)
		AnimationType.ELASTIC:
			_animate_elastic_in(_tween)
		AnimationType.ROTATE_SCALE:
			_animate_rotate_scale_in(_tween)

	_tween.finished.connect(_on_show_animation_finished)


## Hide panel with exit animation.
func hide_panel() -> void:
	if not _is_visible:
		return

	_is_visible = false

	# Cancel any existing tween.
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_BACK)

	# Animate blur background.
	if _blur_overlay:
		_tween.tween_property(_blur_overlay, "color:a", 0.0, animation_duration * 0.7)

	# Apply exit animation.
	match exit_animation:
		AnimationType.FADE:
			_animate_fade_out(_tween)
		AnimationType.SCALE:
			_animate_scale_out(_tween)
		AnimationType.SLIDE_UP:
			_animate_slide_out(_tween, Vector2(0, -200))
		AnimationType.SLIDE_DOWN:
			_animate_slide_out(_tween, Vector2(0, 200))
		AnimationType.SLIDE_LEFT:
			_animate_slide_out(_tween, Vector2(-200, 0))
		AnimationType.SLIDE_RIGHT:
			_animate_slide_out(_tween, Vector2(200, 0))
		AnimationType.BLUR_FADE:
			_animate_blur_fade_out(_tween)
		AnimationType.BOUNCE:
			_animate_scale_out(_tween)  # Use scale for bounce exit.
		AnimationType.ELASTIC:
			_animate_elastic_out(_tween)
		AnimationType.ROTATE_SCALE:
			_animate_rotate_scale_out(_tween)

	_tween.finished.connect(_on_hide_animation_finished)


## === ANIMATION IMPLEMENTATIONS ===

func _animate_fade_in(tween: Tween) -> void:
	scale = Vector2.ONE
	modulate.a = 0.0
	tween.tween_property(self, "modulate:a", 1.0, animation_duration)


func _animate_fade_out(tween: Tween) -> void:
	tween.tween_property(self, "modulate:a", 0.0, animation_duration * 0.7)


func _animate_scale_in(tween: Tween) -> void:
	scale = Vector2.ZERO
	modulate.a = 0.0
	tween.tween_property(self, "scale", Vector2.ONE, animation_duration)
	tween.tween_property(self, "modulate:a", 1.0, animation_duration * 0.5)


func _animate_scale_out(tween: Tween) -> void:
	tween.tween_property(self, "scale", Vector2.ZERO, animation_duration * 0.7)
	tween.tween_property(self, "modulate:a", 0.0, animation_duration * 0.7)


func _animate_slide_in(tween: Tween, offset: Vector2) -> void:
	position = _original_position + offset
	scale = Vector2.ONE
	modulate.a = 0.0
	tween.tween_property(self, "position", _original_position, animation_duration)
	tween.tween_property(self, "modulate:a", 1.0, animation_duration * 0.5)


func _animate_slide_out(tween: Tween, offset: Vector2) -> void:
	tween.tween_property(self, "position", _original_position + offset, animation_duration * 0.7)
	tween.tween_property(self, "modulate:a", 0.0, animation_duration * 0.7)


func _animate_blur_fade_in(tween: Tween) -> void:
	scale = Vector2.ONE * 0.95
	modulate.a = 0.0
	tween.tween_property(self, "scale", Vector2.ONE, animation_duration)
	tween.tween_property(self, "modulate:a", 1.0, animation_duration)


func _animate_blur_fade_out(tween: Tween) -> void:
	tween.tween_property(self, "scale", Vector2.ONE * 0.95, animation_duration * 0.7)
	tween.tween_property(self, "modulate:a", 0.0, animation_duration * 0.7)


func _animate_bounce_in(tween: Tween) -> void:
	tween.set_trans(Tween.TRANS_BOUNCE)
	scale = Vector2.ZERO
	modulate.a = 0.0
	tween.tween_property(self, "scale", Vector2.ONE, animation_duration)
	tween.tween_property(self, "modulate:a", 1.0, animation_duration * 0.3)


func _animate_elastic_in(tween: Tween) -> void:
	tween.set_trans(Tween.TRANS_ELASTIC)
	scale = Vector2.ZERO
	modulate.a = 0.0
	tween.tween_property(self, "scale", Vector2.ONE, animation_duration * 1.2)
	tween.tween_property(self, "modulate:a", 1.0, animation_duration * 0.3)


func _animate_elastic_out(tween: Tween) -> void:
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2.ZERO, animation_duration * 0.8)
	tween.tween_property(self, "modulate:a", 0.0, animation_duration * 0.8)


func _animate_rotate_scale_in(tween: Tween) -> void:
	scale = Vector2.ZERO
	rotation = deg_to_rad(-90)
	modulate.a = 0.0
	tween.tween_property(self, "scale", Vector2.ONE, animation_duration)
	tween.tween_property(self, "rotation", 0.0, animation_duration)
	tween.tween_property(self, "modulate:a", 1.0, animation_duration * 0.5)


func _animate_rotate_scale_out(tween: Tween) -> void:
	tween.tween_property(self, "scale", Vector2.ZERO, animation_duration * 0.7)
	tween.tween_property(self, "rotation", deg_to_rad(90), animation_duration * 0.7)
	tween.tween_property(self, "modulate:a", 0.0, animation_duration * 0.7)


## === SIGNAL HANDLERS ===

func _on_show_animation_finished() -> void:
	show_completed.emit()


func _on_hide_animation_finished() -> void:
	visible = false
	if _blur_overlay:
		_blur_overlay.visible = false
	hide_completed.emit()


## === CLEANUP ===

func _exit_tree() -> void:
	if _blur_overlay and is_instance_valid(_blur_overlay):
		_blur_overlay.queue_free()


## === UTILITY METHODS ===

## Toggle panel visibility.
func toggle() -> void:
	if _is_visible:
		hide_panel()
	else:
		show_panel()


## Check if panel is currently visible (animation-aware).
func is_panel_visible() -> bool:
	return _is_visible


## Set animation duration dynamically.
func set_animation_duration(duration: float) -> void:
	animation_duration = clampf(duration, 0.1, 2.0)


## Set entrance animation type dynamically.
func set_entrance_animation(anim_type: AnimationType) -> void:
	entrance_animation = anim_type


## Set exit animation type dynamically.
func set_exit_animation(anim_type: AnimationType) -> void:
	exit_animation = anim_type
