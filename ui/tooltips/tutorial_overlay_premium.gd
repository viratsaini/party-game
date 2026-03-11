## TutorialOverlayPremium - Advanced tutorial system with spotlight, animations, and progress
## Features: spotlight effect, animated arrows, pulse highlights, step counter, pause/resume
extends CanvasLayer

class_name TutorialOverlayPremium

## Emitted when tutorial completes
signal tutorial_completed(tutorial_id: String)
## Emitted when tutorial is skipped
signal tutorial_skipped(tutorial_id: String, at_step: int)
## Emitted when step changes
signal step_changed(step_index: int, total_steps: int)
## Emitted when tutorial is paused/resumed
signal tutorial_paused(is_paused: bool)

# =====================================================================
# CONFIGURATION
# =====================================================================

## How fast the spotlight transitions between targets
@export var spotlight_transition_speed: float = 0.4
## Spotlight padding around target element
@export var spotlight_padding: float = 20.0
## Pulse animation scale multiplier
@export var pulse_scale: float = 1.08
## Arrow bounce distance
@export var arrow_bounce_distance: float = 15.0

# =====================================================================
# INTERNAL STATE
# =====================================================================

# UI Elements
var _overlay_root: Control
var _dim_layer: ColorRect
var _spotlight_mask: Control
var _spotlight_hole: Control
var _arrow: Control
var _info_panel: Panel
var _step_indicator: HBoxContainer
var _progress_bar: ProgressBar
var _title_label: Label
var _description_label: RichTextLabel
var _skip_button: Button
var _next_button: Button
var _pause_button: Button

# Tutorial state
var _current_tutorial: Dictionary = {}
var _current_step_index: int = 0
var _is_active: bool = false
var _is_paused: bool = false
var _target_element: Control = null

# Tweens
var _spotlight_tween: Tween = null
var _arrow_tween: Tween = null
var _pulse_tween: Tween = null
var _panel_tween: Tween = null

# Step dots for indicator
var _step_dots: Array[Control] = []

# =====================================================================
# LIFECYCLE
# =====================================================================

func _ready() -> void:
	layer = 99  # Below tooltips
	_create_overlay_ui()
	_hide_immediate()


func _process(_delta: float) -> void:
	if not _is_active or _is_paused:
		return

	# Update spotlight position if target moved
	if _target_element and is_instance_valid(_target_element):
		_update_spotlight_position(_target_element.get_global_rect())


# =====================================================================
# UI CREATION
# =====================================================================

func _create_overlay_ui() -> void:
	# Root container
	_overlay_root = Control.new()
	_overlay_root.name = "TutorialOverlayRoot"
	_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay_root)

	# Dimming layer with spotlight hole
	_dim_layer = ColorRect.new()
	_dim_layer.name = "DimLayer"
	_dim_layer.color = Color(0.0, 0.0, 0.0, 0.75)
	_dim_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(_dim_layer)

	# Spotlight container (shader-based hole)
	_spotlight_mask = Control.new()
	_spotlight_mask.name = "SpotlightMask"
	_spotlight_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spotlight_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(_spotlight_mask)

	# Spotlight highlight effect
	_spotlight_hole = _create_spotlight_highlight()
	_spotlight_mask.add_child(_spotlight_hole)

	# Arrow indicator
	_arrow = _create_animated_arrow()
	_overlay_root.add_child(_arrow)

	# Info panel
	_info_panel = _create_info_panel()
	_overlay_root.add_child(_info_panel)


func _create_spotlight_highlight() -> Control:
	var container := Control.new()
	container.name = "SpotlightHighlight"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Outer glow ring
	var glow_ring := Panel.new()
	glow_ring.name = "GlowRing"
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(0, 0, 0, 0)
	glow_style.border_color = Color(0.4, 0.7, 1.0, 0.8)
	glow_style.set_border_width_all(3)
	glow_style.set_corner_radius_all(12)
	glow_ring.add_theme_stylebox_override("panel", glow_style)
	glow_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(glow_ring)

	# Inner clear area (punch through dim)
	var clear_area := ColorRect.new()
	clear_area.name = "ClearArea"
	clear_area.color = Color(0, 0, 0, 0)  # Transparent
	clear_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clear_area.offset_left = 3
	clear_area.offset_top = 3
	clear_area.offset_right = -3
	clear_area.offset_bottom = -3
	container.add_child(clear_area)

	return container


func _create_animated_arrow() -> Control:
	var container := Control.new()
	container.name = "ArrowContainer"

	# Arrow polygon pointing down
	var arrow := Polygon2D.new()
	arrow.name = "Arrow"
	arrow.polygon = PackedVector2Array([
		Vector2(-15, 0),
		Vector2(15, 0),
		Vector2(0, 25)
	])
	arrow.color = Color(1.0, 0.8, 0.2, 1.0)  # Golden
	container.add_child(arrow)

	# Arrow glow
	var arrow_glow := Polygon2D.new()
	arrow_glow.name = "ArrowGlow"
	arrow_glow.polygon = PackedVector2Array([
		Vector2(-18, -3),
		Vector2(18, -3),
		Vector2(0, 30)
	])
	arrow_glow.color = Color(1.0, 0.8, 0.2, 0.3)
	arrow_glow.z_index = -1
	container.add_child(arrow_glow)

	return container


func _create_info_panel() -> Panel:
	var panel := Panel.new()
	panel.name = "InfoPanel"
	_setup_info_panel_style(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Progress area (step indicator + progress bar)
	var progress_area := VBoxContainer.new()
	progress_area.name = "ProgressArea"
	progress_area.add_theme_constant_override("separation", 8)
	vbox.add_child(progress_area)

	# Step indicator (dots)
	_step_indicator = HBoxContainer.new()
	_step_indicator.name = "StepIndicator"
	_step_indicator.add_theme_constant_override("separation", 8)
	_step_indicator.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_area.add_child(_step_indicator)

	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.custom_minimum_size.y = 6
	_progress_bar.show_percentage = false
	_setup_progress_bar_style(_progress_bar)
	progress_area.add_child(_progress_bar)

	# Title
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Description
	_description_label = RichTextLabel.new()
	_description_label.name = "Description"
	_description_label.bbcode_enabled = true
	_description_label.fit_content = true
	_description_label.scroll_active = false
	_description_label.add_theme_font_size_override("normal_font_size", 16)
	_description_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9, 1.0))
	_description_label.custom_minimum_size.x = 350
	vbox.add_child(_description_label)

	# Button row
	var button_row := HBoxContainer.new()
	button_row.name = "Buttons"
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_row)

	# Skip button
	_skip_button = _create_styled_button("Skip", Color(0.4, 0.4, 0.45, 0.9))
	_skip_button.pressed.connect(_on_skip_pressed)
	button_row.add_child(_skip_button)

	# Pause button
	_pause_button = _create_styled_button("Pause", Color(0.5, 0.4, 0.3, 0.9))
	_pause_button.pressed.connect(_on_pause_pressed)
	button_row.add_child(_pause_button)

	# Next button (primary)
	_next_button = _create_styled_button("Next", Color(0.3, 0.5, 0.8, 1.0), true)
	_next_button.pressed.connect(_on_next_pressed)
	button_row.add_child(_next_button)

	return panel


func _setup_info_panel_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.98)
	style.border_color = Color(0.3, 0.5, 0.8, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", style)


func _setup_progress_bar_style(bar: ProgressBar) -> void:
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.22, 0.28, 1.0)
	bg_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.6, 1.0, 1.0)
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)


func _create_styled_button(text: String, color: Color, is_primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(90, 40)

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)

	if is_primary:
		style.border_color = Color(0.5, 0.7, 1.0, 0.8)
		style.set_border_width_all(2)
		# Add glow effect
		style.shadow_color = Color(0.3, 0.5, 1.0, 0.4)
		style.shadow_size = 6

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", _create_hover_style(style, is_primary))
	button.add_theme_stylebox_override("pressed", _create_pressed_style(style))
	button.add_theme_font_size_override("font_size", 14)

	return button


func _create_hover_style(base: StyleBoxFlat, is_primary: bool) -> StyleBoxFlat:
	var style := base.duplicate() as StyleBoxFlat
	style.bg_color = style.bg_color.lightened(0.15)
	if is_primary:
		style.shadow_size = 10
	return style


func _create_pressed_style(base: StyleBoxFlat) -> StyleBoxFlat:
	var style := base.duplicate() as StyleBoxFlat
	style.bg_color = style.bg_color.darkened(0.1)
	return style


# =====================================================================
# PUBLIC API
# =====================================================================

## Start a tutorial with steps
## Step format: { "title": String, "description": String, "target": NodePath or Control (optional),
##               "position": String ("top", "bottom", "left", "right", "center"),
##               "action": String (optional) - what user needs to do }
func start_tutorial(tutorial_id: String, steps: Array) -> void:
	if _is_active:
		end_tutorial()

	_current_tutorial = {
		"id": tutorial_id,
		"steps": steps
	}
	_current_step_index = 0
	_is_active = true
	_is_paused = false

	_create_step_dots(steps.size())
	_show_overlay()
	_show_step(_current_step_index)


## Go to next step
func next_step() -> void:
	if not _is_active or _is_paused:
		return

	var steps: Array = _current_tutorial.get("steps", [])

	if _current_step_index >= steps.size() - 1:
		# Tutorial complete
		_complete_tutorial()
	else:
		_current_step_index += 1
		_show_step(_current_step_index)
		step_changed.emit(_current_step_index, steps.size())


## Go to previous step
func previous_step() -> void:
	if not _is_active or _is_paused:
		return

	if _current_step_index > 0:
		_current_step_index -= 1
		_show_step(_current_step_index)
		var steps: Array = _current_tutorial.get("steps", [])
		step_changed.emit(_current_step_index, steps.size())


## Skip the tutorial
func skip_tutorial() -> void:
	if not _is_active:
		return

	var tutorial_id: String = _current_tutorial.get("id", "")
	var step: int = _current_step_index

	end_tutorial()
	tutorial_skipped.emit(tutorial_id, step)


## Pause/resume the tutorial
func toggle_pause() -> void:
	if not _is_active:
		return

	_is_paused = not _is_paused
	_pause_button.text = "Resume" if _is_paused else "Pause"

	if _is_paused:
		_stop_animations()
		_dim_layer.color.a = 0.85  # Dim more when paused
	else:
		_dim_layer.color.a = 0.75
		_start_pulse_animation()
		_start_arrow_animation()

	tutorial_paused.emit(_is_paused)


## End the tutorial (without completion)
func end_tutorial() -> void:
	_is_active = false
	_is_paused = false
	_stop_animations()
	_hide_overlay()
	_current_tutorial = {}
	_current_step_index = 0


## Jump to specific step
func go_to_step(step_index: int) -> void:
	if not _is_active:
		return

	var steps: Array = _current_tutorial.get("steps", [])
	if step_index >= 0 and step_index < steps.size():
		_current_step_index = step_index
		_show_step(_current_step_index)
		step_changed.emit(_current_step_index, steps.size())


# =====================================================================
# INTERNAL METHODS
# =====================================================================

func _show_step(index: int) -> void:
	var steps: Array = _current_tutorial.get("steps", [])
	if index >= steps.size():
		return

	var step: Dictionary = steps[index]

	# Update content
	_title_label.text = step.get("title", "Step " + str(index + 1))
	_description_label.text = step.get("description", "")

	# Update progress
	_progress_bar.max_value = steps.size()
	_progress_bar.value = index + 1
	_update_step_dots(index)

	# Update button text
	if index >= steps.size() - 1:
		_next_button.text = "Finish"
	else:
		_next_button.text = "Next"

	# Handle target element
	var target = step.get("target")
	_target_element = null

	if target != null:
		if target is Control:
			_target_element = target
		elif target is NodePath:
			var node := get_node_or_null(target)
			if node is Control:
				_target_element = node

	# Position spotlight and panel
	if _target_element and is_instance_valid(_target_element):
		var target_rect := _target_element.get_global_rect()
		_animate_spotlight_to(target_rect)
		_position_panel_around(target_rect, step.get("position", "bottom"))
		_position_arrow(target_rect, step.get("position", "bottom"))
		_spotlight_hole.visible = true
		_arrow.visible = true
		_start_pulse_animation()
		_start_arrow_animation()
	else:
		# No target - center everything
		_spotlight_hole.visible = false
		_arrow.visible = false
		_center_panel()
		_stop_animations()

	# Animate panel in
	_animate_panel_in()


func _animate_spotlight_to(target_rect: Rect2) -> void:
	var padded_rect := target_rect.grow(spotlight_padding)

	if _spotlight_tween and _spotlight_tween.is_valid():
		_spotlight_tween.kill()

	_spotlight_tween = create_tween()
	_spotlight_tween.set_ease(Tween.EASE_OUT)
	_spotlight_tween.set_trans(Tween.TRANS_CUBIC)
	_spotlight_tween.set_parallel(true)
	_spotlight_tween.tween_property(_spotlight_hole, "position", padded_rect.position, spotlight_transition_speed)
	_spotlight_tween.tween_property(_spotlight_hole, "size", padded_rect.size, spotlight_transition_speed)


func _update_spotlight_position(target_rect: Rect2) -> void:
	var padded_rect := target_rect.grow(spotlight_padding)
	_spotlight_hole.position = padded_rect.position
	_spotlight_hole.size = padded_rect.size


func _position_panel_around(target_rect: Rect2, position_hint: String) -> void:
	await get_tree().process_frame
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := _info_panel.get_combined_minimum_size()
	var margin := 30.0

	var panel_pos := Vector2.ZERO

	match position_hint:
		"top":
			panel_pos.x = target_rect.position.x + target_rect.size.x / 2 - panel_size.x / 2
			panel_pos.y = target_rect.position.y - panel_size.y - margin
		"bottom":
			panel_pos.x = target_rect.position.x + target_rect.size.x / 2 - panel_size.x / 2
			panel_pos.y = target_rect.end.y + margin
		"left":
			panel_pos.x = target_rect.position.x - panel_size.x - margin
			panel_pos.y = target_rect.position.y + target_rect.size.y / 2 - panel_size.y / 2
		"right":
			panel_pos.x = target_rect.end.x + margin
			panel_pos.y = target_rect.position.y + target_rect.size.y / 2 - panel_size.y / 2
		_:  # center or auto
			panel_pos.x = viewport_size.x / 2 - panel_size.x / 2
			panel_pos.y = target_rect.end.y + margin

	# Clamp to viewport
	panel_pos.x = clampf(panel_pos.x, margin, viewport_size.x - panel_size.x - margin)
	panel_pos.y = clampf(panel_pos.y, margin, viewport_size.y - panel_size.y - margin)

	_info_panel.position = panel_pos
	_info_panel.size = panel_size


func _center_panel() -> void:
	await get_tree().process_frame
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := _info_panel.get_combined_minimum_size()

	_info_panel.position = (viewport_size - panel_size) / 2
	_info_panel.size = panel_size


func _position_arrow(target_rect: Rect2, position_hint: String) -> void:
	var arrow_pos := Vector2.ZERO
	var rotation := 0.0

	match position_hint:
		"top":
			arrow_pos = Vector2(target_rect.position.x + target_rect.size.x / 2, target_rect.position.y - 10)
			rotation = PI  # Point up
		"bottom":
			arrow_pos = Vector2(target_rect.position.x + target_rect.size.x / 2, target_rect.end.y + 10)
			rotation = 0  # Point down (default)
		"left":
			arrow_pos = Vector2(target_rect.position.x - 10, target_rect.position.y + target_rect.size.y / 2)
			rotation = PI / 2  # Point left
		"right":
			arrow_pos = Vector2(target_rect.end.x + 10, target_rect.position.y + target_rect.size.y / 2)
			rotation = -PI / 2  # Point right
		_:
			arrow_pos = Vector2(target_rect.position.x + target_rect.size.x / 2, target_rect.end.y + 10)
			rotation = 0

	_arrow.position = arrow_pos
	_arrow.rotation = rotation


func _animate_panel_in() -> void:
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()

	_info_panel.modulate.a = 0.0
	_info_panel.scale = Vector2(0.95, 0.95)
	_info_panel.pivot_offset = _info_panel.size / 2

	_panel_tween = create_tween()
	_panel_tween.set_ease(Tween.EASE_OUT)
	_panel_tween.set_trans(Tween.TRANS_BACK)
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(_info_panel, "modulate:a", 1.0, 0.3)
	_panel_tween.tween_property(_info_panel, "scale", Vector2.ONE, 0.35)


func _start_pulse_animation() -> void:
	if not _target_element or not is_instance_valid(_target_element):
		return

	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	# Pulse the glow ring
	var glow_ring: Panel = _spotlight_hole.get_node_or_null("GlowRing")
	if glow_ring:
		_pulse_tween = create_tween()
		_pulse_tween.set_loops()
		_pulse_tween.tween_property(glow_ring, "modulate:a", 0.5, 0.8).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_property(glow_ring, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT)


func _start_arrow_animation() -> void:
	if _arrow_tween and _arrow_tween.is_valid():
		_arrow_tween.kill()

	var base_pos := _arrow.position

	_arrow_tween = create_tween()
	_arrow_tween.set_loops()
	_arrow_tween.set_ease(Tween.EASE_IN_OUT)
	_arrow_tween.set_trans(Tween.TRANS_SINE)

	# Bounce based on rotation
	var bounce_offset := Vector2(0, arrow_bounce_distance)
	if absf(_arrow.rotation) > 0.1:
		bounce_offset = Vector2(arrow_bounce_distance, 0).rotated(_arrow.rotation - PI/2)

	_arrow_tween.tween_property(_arrow, "position", base_pos + bounce_offset, 0.5)
	_arrow_tween.tween_property(_arrow, "position", base_pos, 0.5)


func _stop_animations() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _arrow_tween and _arrow_tween.is_valid():
		_arrow_tween.kill()


func _create_step_dots(count: int) -> void:
	# Clear existing dots
	for dot in _step_dots:
		if is_instance_valid(dot):
			dot.queue_free()
	_step_dots.clear()

	for i in range(count):
		var dot := Panel.new()
		dot.name = "Dot_" + str(i)
		dot.custom_minimum_size = Vector2(10, 10)
		_setup_dot_style(dot, false)
		_step_indicator.add_child(dot)
		_step_dots.append(dot)


func _setup_dot_style(dot: Panel, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(5)

	if is_active:
		style.bg_color = Color(0.3, 0.6, 1.0, 1.0)
		style.border_color = Color(0.5, 0.7, 1.0, 0.8)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.3, 0.35, 0.4, 0.8)

	dot.add_theme_stylebox_override("panel", style)


func _update_step_dots(active_index: int) -> void:
	for i in range(_step_dots.size()):
		_setup_dot_style(_step_dots[i], i == active_index)


func _show_overlay() -> void:
	_overlay_root.visible = true
	_overlay_root.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(_overlay_root, "modulate:a", 1.0, 0.3)


func _hide_overlay() -> void:
	var tween := create_tween()
	tween.tween_property(_overlay_root, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void: _overlay_root.visible = false)


func _hide_immediate() -> void:
	_overlay_root.visible = false


func _complete_tutorial() -> void:
	var tutorial_id: String = _current_tutorial.get("id", "")
	end_tutorial()
	tutorial_completed.emit(tutorial_id)


# =====================================================================
# SIGNAL HANDLERS
# =====================================================================

func _on_skip_pressed() -> void:
	skip_tutorial()


func _on_next_pressed() -> void:
	next_step()


func _on_pause_pressed() -> void:
	toggle_pause()
