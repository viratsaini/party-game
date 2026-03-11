## Rating Stars - Satisfying star rating with glow, particles, and smooth animations
## Features: hover fill with glow, half-star support, scale transition, particle burst
extends Control
class_name RatingStars

## Emitted when rating changes
signal rating_changed(rating: float)
## Emitted when rating is confirmed (click)
signal rating_confirmed(rating: float)

# Configuration
@export var max_stars: int = 5
@export var current_rating: float = 0.0:
	set(value):
		current_rating = clampf(value, 0.0, float(max_stars))
		if is_inside_tree():
			_update_stars_display()
			rating_changed.emit(current_rating)

@export var allow_half_stars: bool = true
@export var allow_clear: bool = true
@export var show_average: bool = true
@export var average_rating: float = 0.0
@export var total_ratings: int = 0
@export var read_only: bool = false

# Visual
@export_group("Visual")
@export var star_size: float = 40.0
@export var star_spacing: float = 8.0
@export var filled_color: Color = Color(1.0, 0.85, 0.2, 1.0)  # Gold
@export var empty_color: Color = Color(0.3, 0.3, 0.35, 1.0)
@export var hover_color: Color = Color(1.0, 0.9, 0.4, 1.0)
@export var glow_color: Color = Color(1.0, 0.85, 0.2, 0.5)

# Animation
@export_group("Animation")
@export var hover_scale: float = 1.15
@export var click_scale: float = 1.3
@export var animation_duration: float = 0.2
@export var particle_count: int = 8
@export var enable_particles: bool = true

# Internal nodes
var _container: HBoxContainer
var _stars: Array[Control] = []
var _info_label: Label
var _reset_btn: Button
var _particle_container: Control

# State
var _hover_rating: float = -1.0
var _is_hovering: bool = false
var _active_tweens: Dictionary = {}
var _particles: Array[Control] = []


func _ready() -> void:
	_setup_ui()
	_update_stars_display()


func _setup_ui() -> void:
	custom_minimum_size = Vector2((star_size + star_spacing) * max_stars + 100, star_size + 30)

	var main := VBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	# Stars container
	var stars_row := HBoxContainer.new()
	stars_row.add_theme_constant_override("separation", int(star_spacing))
	main.add_child(stars_row)

	_container = HBoxContainer.new()
	_container.add_theme_constant_override("separation", int(star_spacing))
	stars_row.add_child(_container)

	# Create stars
	for i in range(max_stars):
		var star := _create_star(i)
		_container.add_child(star)
		_stars.append(star)

	# Reset button
	if allow_clear and not read_only:
		_reset_btn = Button.new()
		_reset_btn.text = "Clear"
		_reset_btn.flat = true
		_reset_btn.custom_minimum_size = Vector2(50, star_size)
		_reset_btn.add_theme_font_size_override("font_size", 12)
		_reset_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1.0))
		_reset_btn.pressed.connect(_clear_rating)
		_reset_btn.modulate.a = 0.0
		stars_row.add_child(_reset_btn)

	# Info label (average rating)
	if show_average:
		var info_row := HBoxContainer.new()
		info_row.add_theme_constant_override("separation", 10)
		main.add_child(info_row)

		_info_label = Label.new()
		_info_label.add_theme_font_size_override("font_size", 13)
		_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1.0))
		_update_info_label()
		info_row.add_child(_info_label)

	# Particle container
	_particle_container = Control.new()
	_particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particle_container)


func _create_star(index: int) -> Control:
	var star := Control.new()
	star.custom_minimum_size = Vector2(star_size, star_size)
	star.mouse_filter = Control.MOUSE_FILTER_STOP
	star.set_meta("index", index)

	# Star drawing
	star.draw.connect(func() -> void: _draw_star(star))

	if not read_only:
		star.gui_input.connect(func(event: InputEvent) -> void: _on_star_input(star, event))
		star.mouse_entered.connect(func() -> void: _on_star_hover_enter(star))
		star.mouse_exited.connect(func() -> void: _on_star_hover_exit(star))

	return star


func _draw_star(star: Control) -> void:
	var size: Vector2 = star.size
	var center: Vector2 = size * 0.5
	var outer_radius: float = minf(size.x, size.y) * 0.45
	var inner_radius: float = outer_radius * 0.4
	var index: int = star.get_meta("index")

	# Calculate fill amount
	var display_rating: float = _hover_rating if _is_hovering and _hover_rating >= 0 else current_rating
	var star_fill: float = clampf(display_rating - index, 0.0, 1.0)

	# Generate star points
	var points: PackedVector2Array = _generate_star_points(center, outer_radius, inner_radius, 5)

	# Draw glow if filled
	if star_fill > 0:
		var glow_radius: float = outer_radius * 1.3
		var glow_points := _generate_star_points(center, glow_radius, inner_radius * 1.2, 5)

		# Multiple glow layers
		for layer in range(3):
			var alpha: float = 0.1 * (3 - layer) * star_fill
			var layer_radius: float = outer_radius * (1.1 + layer * 0.15)
			var layer_points := _generate_star_points(center, layer_radius, inner_radius * (1.1 + layer * 0.1), 5)
			star.draw_polygon(layer_points, PackedColorArray([Color(glow_color.r, glow_color.g, glow_color.b, alpha)]))

	# Draw empty star background
	star.draw_polygon(points, PackedColorArray([empty_color]))

	# Draw filled portion
	if star_fill > 0:
		if star_fill >= 1.0:
			# Fully filled
			var fill_color := hover_color if _is_hovering else filled_color
			star.draw_polygon(points, PackedColorArray([fill_color]))
		else:
			# Partial fill (half star)
			_draw_partial_star(star, center, outer_radius, inner_radius, star_fill)

	# Draw outline
	var outline_color := Color(filled_color.r, filled_color.g, filled_color.b, 0.3)
	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		star.draw_line(points[i], points[next_i], outline_color, 1.5)


func _draw_partial_star(star: Control, center: Vector2, outer_r: float, inner_r: float, fill: float) -> void:
	var points := _generate_star_points(center, outer_r, inner_r, 5)
	var fill_color := hover_color if _is_hovering else filled_color

	# Clip to left portion
	var clip_x: float = center.x - outer_r + (outer_r * 2.0 * fill)

	var clipped_points: PackedVector2Array = []
	for point in points:
		if point.x <= clip_x:
			clipped_points.append(point)
		else:
			# Find intersection
			clipped_points.append(Vector2(clip_x, point.y))

	if clipped_points.size() >= 3:
		star.draw_polygon(clipped_points, PackedColorArray([fill_color]))


func _generate_star_points(center: Vector2, outer_r: float, inner_r: float, num_points: int) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var angle_step: float = PI / num_points
	var start_angle: float = -PI / 2  # Start from top

	for i in range(num_points * 2):
		var angle: float = start_angle + i * angle_step
		var radius: float = outer_r if i % 2 == 0 else inner_r
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	return points


func _on_star_input(star: Control, event: InputEvent) -> void:
	if read_only:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var index: int = star.get_meta("index")
			var rating: float = _calculate_rating_from_position(star, mb.position)
			current_rating = rating
			_animate_star_click(star)
			_spawn_particles(star)
			rating_confirmed.emit(current_rating)


func _on_star_hover_enter(star: Control) -> void:
	if read_only:
		return

	_is_hovering = true
	_animate_star_hover(star, true)
	_show_reset_button()


func _on_star_hover_exit(star: Control) -> void:
	if read_only:
		return

	_animate_star_hover(star, false)


func _input(event: InputEvent) -> void:
	if read_only:
		return

	if event is InputEventMouseMotion and _is_hovering:
		_update_hover_rating(event.global_position)


func _update_hover_rating(global_pos: Vector2) -> void:
	var found := false

	for star in _stars:
		var star_rect := Rect2(star.global_position, star.size)
		if star_rect.has_point(global_pos):
			var local_pos: Vector2 = global_pos - star.global_position
			_hover_rating = _calculate_rating_from_position(star, local_pos)
			found = true
			break

	if not found:
		_is_hovering = false
		_hover_rating = -1.0
		_hide_reset_button()

	_update_stars_display()


func _calculate_rating_from_position(star: Control, local_pos: Vector2) -> float:
	var index: int = star.get_meta("index")
	var half_width: float = star.size.x * 0.5

	if allow_half_stars:
		if local_pos.x < half_width:
			return float(index) + 0.5
		else:
			return float(index) + 1.0
	else:
		return float(index) + 1.0


func _update_stars_display() -> void:
	for star in _stars:
		star.queue_redraw()


func _animate_star_hover(star: Control, entering: bool) -> void:
	var index: int = star.get_meta("index")
	var tween_key := "hover_%d" % index

	if _active_tweens.has(tween_key):
		var old_tween: Tween = _active_tweens[tween_key]
		if old_tween and old_tween.is_valid():
			old_tween.kill()

	var tween := create_tween()
	_active_tweens[tween_key] = tween

	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK if entering else Tween.TRANS_CUBIC)

	var target_scale: Vector2 = Vector2(hover_scale, hover_scale) if entering else Vector2.ONE
	star.pivot_offset = star.size * 0.5

	tween.tween_property(star, "scale", target_scale, animation_duration)

	# Also animate subsequent stars slightly
	if entering:
		for i in range(index + 1, _stars.size()):
			var delay: float = (i - index) * 0.03
			var next_star: Control = _stars[i]
			next_star.pivot_offset = next_star.size * 0.5

			var cascade_tween := create_tween()
			cascade_tween.tween_interval(delay)
			cascade_tween.tween_property(next_star, "scale", Vector2(1.05, 1.05), animation_duration * 0.5)
			cascade_tween.tween_property(next_star, "scale", Vector2.ONE, animation_duration * 0.5)


func _animate_star_click(star: Control) -> void:
	var index: int = star.get_meta("index")
	star.pivot_offset = star.size * 0.5

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# Pop animation
	tween.tween_property(star, "scale", Vector2(click_scale, click_scale), animation_duration * 0.3)
	tween.tween_property(star, "scale", Vector2.ONE, animation_duration * 0.5)

	# Cascade animation to all filled stars
	for i in range(index + 1):
		var filled_star: Control = _stars[i]
		filled_star.pivot_offset = filled_star.size * 0.5

		var delay: float = (index - i) * 0.02
		var cascade_tween := create_tween()
		cascade_tween.tween_interval(delay)
		cascade_tween.tween_property(filled_star, "scale", Vector2(1.1, 1.1), animation_duration * 0.2)
		cascade_tween.tween_property(filled_star, "scale", Vector2.ONE, animation_duration * 0.3)


func _spawn_particles(star: Control) -> void:
	if not enable_particles:
		return

	var star_center: Vector2 = star.global_position + star.size * 0.5 - _particle_container.global_position

	for i in range(particle_count):
		var particle := _create_particle()
		particle.position = star_center
		_particle_container.add_child(particle)

		var angle: float = (float(i) / particle_count) * TAU + randf() * 0.5
		var distance: float = randf_range(30, 80)
		var target_pos: Vector2 = star_center + Vector2(cos(angle), sin(angle)) * distance

		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)

		tween.tween_property(particle, "position", target_pos, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.5)

		tween.chain().tween_callback(particle.queue_free)


func _create_particle() -> Control:
	var particle := Control.new()
	particle.custom_minimum_size = Vector2(8, 8)
	particle.pivot_offset = Vector2(4, 4)

	particle.draw.connect(func() -> void:
		var colors := [filled_color, Color.WHITE, Color(1, 0.9, 0.5)]
		var color: Color = colors[randi() % colors.size()]
		particle.draw_circle(Vector2(4, 4), 4, color)
	)

	particle.queue_redraw()
	return particle


func _show_reset_button() -> void:
	if _reset_btn:
		var tween := create_tween()
		tween.tween_property(_reset_btn, "modulate:a", 1.0, 0.2)


func _hide_reset_button() -> void:
	if _reset_btn:
		var tween := create_tween()
		tween.tween_property(_reset_btn, "modulate:a", 0.0, 0.2)


func _clear_rating() -> void:
	current_rating = 0.0
	rating_confirmed.emit(0.0)

	# Animate all stars shrinking
	for star in _stars:
		star.pivot_offset = star.size * 0.5
		var tween := create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(star, "scale", Vector2(0.8, 0.8), 0.1)
		tween.tween_property(star, "scale", Vector2.ONE, 0.2)


func _update_info_label() -> void:
	if _info_label and show_average:
		if total_ratings > 0:
			_info_label.text = "%.1f average (%d ratings)" % [average_rating, total_ratings]
		else:
			_info_label.text = "No ratings yet"


# Public API
func get_rating() -> float:
	return current_rating


func set_rating(rating: float, animate: bool = true) -> void:
	if animate:
		var target := clampf(rating, 0.0, float(max_stars))
		var tween := create_tween()
		tween.tween_method(func(val: float) -> void:
			current_rating = val
		, current_rating, target, 0.3)
	else:
		current_rating = rating


func set_average(avg: float, count: int) -> void:
	average_rating = avg
	total_ratings = count
	_update_info_label()


func clear() -> void:
	_clear_rating()


func set_read_only(readonly: bool) -> void:
	read_only = readonly
	if _reset_btn:
		_reset_btn.visible = not readonly
