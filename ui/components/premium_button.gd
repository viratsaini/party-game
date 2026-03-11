## Premium animated button with advanced visual effects.
## Features: elastic hover, press feedback, particles, glow, ripple, sound.
## Supports multiple visual styles and customization options.
class_name PremiumButton
extends Button

## Visual style presets.
enum ButtonStyle {
	DEFAULT,      ## Standard button.
	PRIMARY,      ## Emphasized primary action.
	SECONDARY,    ## Secondary action.
	SUCCESS,      ## Success/confirm action.
	DANGER,       ## Destructive/cancel action.
	GHOST,        ## Transparent with border.
}

## Button style.
@export var button_style: ButtonStyle = ButtonStyle.DEFAULT

## Enable hover animation.
@export var enable_hover_animation: bool = true

## Enable press feedback.
@export var enable_press_feedback: bool = true

## Enable glow effect on hover.
@export var enable_glow: bool = true

## Enable particle effects on press.
@export var enable_particles: bool = true

## Enable ripple effect on press.
@export var enable_ripple: bool = true

## Enable sound feedback.
@export var enable_sound: bool = true

## Hover scale multiplier.
@export_range(1.0, 1.5) var hover_scale: float = 1.05

## Press scale multiplier.
@export_range(0.8, 1.0) var press_scale: float = 0.95

## Animation duration.
@export_range(0.1, 1.0) var animation_duration: float = 0.3

## Glow intensity.
@export_range(0.0, 3.0) var glow_intensity: float = 1.5

## Current scale (for animation).
var _current_scale: float = 1.0

## Target scale (for animation).
var _target_scale: float = 1.0

## Is currently hovered.
var _is_hovered: bool = false

## Is currently pressed.
var _is_pressed: bool = false

## Glow effect node.
var _glow_effect: ColorRect = null

## Ripple effect timer.
var _ripple_time: float = 0.0
var _ripple_active: bool = false
var _ripple_center: Vector2 = Vector2.ZERO

## Particle instances (pooled).
var _particles: Array[Control] = []


func _ready() -> void:
	# Apply style colors.
	_apply_button_style()

	# Setup glow effect layer.
	if enable_glow:
		_setup_glow_effect()

	# Connect signals.
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(_on_pressed)


func _process(delta: float) -> void:
	# Smooth scale animation using lerp.
	_current_scale = lerp(_current_scale, _target_scale, delta / animation_duration * 10.0)
	scale = Vector2.ONE * _current_scale

	# Update glow effect.
	if _glow_effect and enable_glow:
		var glow_alpha: float = 0.0 if not _is_hovered else glow_intensity * 0.3
		_glow_effect.modulate.a = lerp(_glow_effect.modulate.a, glow_alpha, delta * 10.0)

	# Update ripple effect.
	if _ripple_active:
		_ripple_time += delta * 3.0
		if _ripple_time >= 1.0:
			_ripple_active = false
			_ripple_time = 0.0
		queue_redraw()


func _draw() -> void:
	# Draw ripple effect if active.
	if _ripple_active and enable_ripple:
		_draw_ripple_effect()


## Draw ripple expanding from press position.
func _draw_ripple_effect() -> void:
	var ripple_radius: float = _ripple_time * maxf(size.x, size.y) * 1.5
	var ripple_alpha: float = 1.0 - _ripple_time

	var ripple_color: Color = _get_style_color()
	ripple_color.a = ripple_alpha * 0.3

	# Draw filled circle.
	draw_circle(_ripple_center, ripple_radius, ripple_color)


## Apply visual style to button.
func _apply_button_style() -> void:
	var style_color: Color = _get_style_color()

	# Create StyleBoxFlat for the button.
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = style_color
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.border_width_bottom = 2
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_color = style_color.lightened(0.2)
	style_normal.content_margin_bottom = 12
	style_normal.content_margin_left = 24
	style_normal.content_margin_right = 24
	style_normal.content_margin_top = 12

	var style_hover: StyleBoxFlat = style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = style_color.lightened(0.15)
	style_hover.border_color = style_color.lightened(0.3)

	var style_pressed: StyleBoxFlat = style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = style_color.darkened(0.1)
	style_pressed.border_color = style_color

	var style_disabled: StyleBoxFlat = style_normal.duplicate() as StyleBoxFlat
	style_disabled.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	style_disabled.border_color = Color(0.5, 0.5, 0.5, 0.5)

	add_theme_stylebox_override("normal", style_normal)
	add_theme_stylebox_override("hover", style_hover)
	add_theme_stylebox_override("pressed", style_pressed)
	add_theme_stylebox_override("disabled", style_disabled)


## Get color for current button style.
func _get_style_color() -> Color:
	match button_style:
		ButtonStyle.DEFAULT:
			return Color(0.25, 0.3, 0.35, 0.9)
		ButtonStyle.PRIMARY:
			return Color(0.2, 0.5, 0.9, 0.95)
		ButtonStyle.SECONDARY:
			return Color(0.4, 0.45, 0.5, 0.9)
		ButtonStyle.SUCCESS:
			return Color(0.2, 0.7, 0.3, 0.95)
		ButtonStyle.DANGER:
			return Color(0.9, 0.2, 0.2, 0.95)
		ButtonStyle.GHOST:
			return Color(0.0, 0.0, 0.0, 0.3)
		_:
			return Color(0.25, 0.3, 0.35, 0.9)


## Setup glow effect background layer.
func _setup_glow_effect() -> void:
	_glow_effect = ColorRect.new()
	_glow_effect.color = _get_style_color().lightened(0.5)
	_glow_effect.color.a = 0.0
	_glow_effect.z_index = -1
	_glow_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Slightly larger than button for glow.
	_glow_effect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow_effect.offset_left = -4
	_glow_effect.offset_right = 4
	_glow_effect.offset_top = -4
	_glow_effect.offset_bottom = 4

	add_child(_glow_effect)
	move_child(_glow_effect, 0)


## Spawn particle effect at position.
func _spawn_particles(pos: Vector2) -> void:
	if not enable_particles:
		return

	# Create simple particle burst.
	var particle_count: int = 8
	for i: int in range(particle_count):
		var angle: float = (float(i) / float(particle_count)) * TAU
		var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * 100.0

		var particle: Control = Control.new()
		particle.set_anchors_preset(Control.PRESET_CENTER)
		particle.size = Vector2(4, 4)
		particle.position = pos
		particle.modulate = _get_style_color().lightened(0.5)
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Store velocity in metadata.
		particle.set_meta("velocity", velocity)
		particle.set_meta("lifetime", 0.0)

		add_child(particle)
		_particles.append(particle)

	# Start particle update timer.
	_update_particles()


## Update active particles.
func _update_particles() -> void:
	var delta: float = get_process_delta_time()

	var i: int = _particles.size() - 1
	while i >= 0:
		var particle: Control = _particles[i]
		var velocity: Vector2 = particle.get_meta("velocity") as Vector2
		var lifetime: float = particle.get_meta("lifetime") as float

		lifetime += delta
		particle.set_meta("lifetime", lifetime)

		# Update position.
		particle.position += velocity * delta

		# Fade out.
		particle.modulate.a = 1.0 - (lifetime / 0.5)

		# Remove if expired.
		if lifetime > 0.5:
			particle.queue_free()
			_particles.remove_at(i)

		i -= 1


## Signal handlers.
func _on_mouse_entered() -> void:
	if not enable_hover_animation or disabled:
		return

	_is_hovered = true
	_target_scale = hover_scale

	if enable_sound:
		_play_sound("hover")


func _on_mouse_exited() -> void:
	if not enable_hover_animation:
		return

	_is_hovered = false
	_target_scale = 1.0


func _on_button_down() -> void:
	if not enable_press_feedback or disabled:
		return

	_is_pressed = true
	_target_scale = press_scale

	# Start ripple effect.
	if enable_ripple:
		_ripple_center = get_local_mouse_position()
		_ripple_active = true
		_ripple_time = 0.0


func _on_button_up() -> void:
	if not enable_press_feedback:
		return

	_is_pressed = false
	_target_scale = hover_scale if _is_hovered else 1.0


func _on_pressed() -> void:
	if disabled:
		return

	# Spawn particles.
	if enable_particles:
		_spawn_particles(get_local_mouse_position())

	# Play sound.
	if enable_sound:
		_play_sound("press")


## Play UI sound effect.
func _play_sound(sound_type: String) -> void:
	# Integrate with AudioManager if available.
	if has_node("/root/AudioManager"):
		var audio_manager: Node = get_node("/root/AudioManager")
		match sound_type:
			"hover":
				audio_manager.call("play_sfx", "ui_hover")
			"press":
				audio_manager.call("play_sfx", "ui_press")
