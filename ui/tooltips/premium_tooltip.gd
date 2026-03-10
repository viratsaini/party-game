## PremiumTooltip - Smart tooltip system with smooth cursor following and rich content
## Features: cursor lag, adaptive positioning, gradient borders, glow effects, rich content
extends CanvasLayer

class_name PremiumTooltip

## Emitted when tooltip becomes visible
signal tooltip_shown(tooltip_id: String)
## Emitted when tooltip hides
signal tooltip_hidden(tooltip_id: String)

# =====================================================================
# CONFIGURATION
# =====================================================================

## Delay before tooltip appears (seconds)
@export var show_delay: float = 0.3
## How smoothly the tooltip follows cursor (lower = smoother)
@export var follow_smoothness: float = 8.0
## Distance from cursor
@export var cursor_offset: Vector2 = Vector2(20, 20)
## Maximum width before text wraps
@export var max_width: float = 400.0
## Padding inside tooltip
@export var padding: Vector2 = Vector2(16, 12)

# =====================================================================
# INTERNAL STATE
# =====================================================================

var _tooltip_container: Control
var _background_panel: Panel
var _border_glow: Panel
var _arrow: Polygon2D
var _content_container: VBoxContainer
var _title_label: Label
var _description_label: RichTextLabel
var _stats_container: HBoxContainer
var _icon_display: TextureRect

var _current_target: Control = null
var _current_tooltip_id: String = ""
var _target_position: Vector2 = Vector2.ZERO
var _actual_position: Vector2 = Vector2.ZERO
var _hover_timer: float = 0.0
var _is_showing: bool = false
var _fade_tween: Tween = null
var _glow_tween: Tween = null
var _border_animation_time: float = 0.0

# Tooltip data cache
var _registered_tooltips: Dictionary = {}
var _tooltip_queue: Array[Dictionary] = []

# =====================================================================
# LIFECYCLE
# =====================================================================

func _ready() -> void:
	layer = 100  # Always on top
	_create_tooltip_ui()
	_hide_immediate()
	set_process(true)


func _process(delta: float) -> void:
	if not _is_showing:
		# Check hover timer
		if _current_target and is_instance_valid(_current_target):
			if _is_mouse_over_target():
				_hover_timer += delta
				if _hover_timer >= show_delay:
					_show_tooltip()
			else:
				_reset_hover()
		return

	# Update target position with cursor
	_target_position = get_viewport().get_mouse_position() + cursor_offset

	# Smooth follow with lag (feels organic)
	_actual_position = _actual_position.lerp(_target_position, delta * follow_smoothness)

	# Adapt position to screen edges
	_adapt_position_to_screen()

	# Apply position
	_tooltip_container.global_position = _actual_position

	# Update arrow position
	_update_arrow_position()

	# Animate border gradient
	_border_animation_time += delta
	_update_border_gradient()

	# Check if we should hide (mouse left target)
	if _current_target and is_instance_valid(_current_target):
		if not _is_mouse_over_target() and not _is_mouse_over_tooltip():
			hide_tooltip()


# =====================================================================
# UI CREATION
# =====================================================================

func _create_tooltip_ui() -> void:
	# Main container
	_tooltip_container = Control.new()
	_tooltip_container.name = "TooltipContainer"
	_tooltip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip_container)

	# Glow layer (behind panel)
	_border_glow = Panel.new()
	_border_glow.name = "BorderGlow"
	_border_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_container.add_child(_border_glow)
	_setup_glow_style(_border_glow)

	# Main background panel
	_background_panel = Panel.new()
	_background_panel.name = "Background"
	_background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_container.add_child(_background_panel)
	_setup_panel_style(_background_panel)

	# Arrow/pointer
	_arrow = Polygon2D.new()
	_arrow.name = "Arrow"
	_arrow.polygon = PackedVector2Array([
		Vector2(-10, 0),
		Vector2(10, 0),
		Vector2(0, 12)
	])
	_arrow.color = Color(0.12, 0.14, 0.18, 0.98)
	_tooltip_container.add_child(_arrow)

	# Content container
	_content_container = VBoxContainer.new()
	_content_container.name = "Content"
	_content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_panel.add_child(_content_container)

	# Header with icon and title
	var header := HBoxContainer.new()
	header.name = "Header"
	_content_container.add_child(header)

	# Icon
	_icon_display = TextureRect.new()
	_icon_display.name = "Icon"
	_icon_display.custom_minimum_size = Vector2(24, 24)
	_icon_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_display.visible = false
	header.add_child(_icon_display)

	# Title
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	header.add_child(_title_label)

	# Description (RichTextLabel for formatting)
	_description_label = RichTextLabel.new()
	_description_label.name = "Description"
	_description_label.bbcode_enabled = true
	_description_label.fit_content = true
	_description_label.scroll_active = false
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.add_theme_font_size_override("normal_font_size", 14)
	_description_label.add_theme_color_override("default_color", Color(0.8, 0.8, 0.85, 1.0))
	_content_container.add_child(_description_label)

	# Stats container (for showing values)
	_stats_container = HBoxContainer.new()
	_stats_container.name = "Stats"
	_stats_container.visible = false
	_content_container.add_child(_stats_container)


func _setup_panel_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.98)
	style.border_color = Color(0.3, 0.5, 0.8, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 8
	style.shadow_offset = Vector2(2, 4)
	panel.add_theme_stylebox_override("panel", style)


func _setup_glow_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 1.0, 0.15)
	style.set_corner_radius_all(12)
	style.set_expand_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)


# =====================================================================
# PUBLIC API
# =====================================================================

## Register a tooltip for an element
func register_tooltip(target: Control, tooltip_id: String, data: Dictionary) -> void:
	_registered_tooltips[tooltip_id] = {
		"target": target,
		"data": data
	}

	# Connect signals
	if not target.mouse_entered.is_connected(_on_target_mouse_entered.bind(target, tooltip_id)):
		target.mouse_entered.connect(_on_target_mouse_entered.bind(target, tooltip_id))
		target.mouse_exited.connect(_on_target_mouse_exited.bind(target, tooltip_id))


## Unregister a tooltip
func unregister_tooltip(tooltip_id: String) -> void:
	if _registered_tooltips.has(tooltip_id):
		var info: Dictionary = _registered_tooltips[tooltip_id]
		var target: Control = info.get("target")
		if is_instance_valid(target):
			if target.mouse_entered.is_connected(_on_target_mouse_entered):
				target.mouse_entered.disconnect(_on_target_mouse_entered)
				target.mouse_exited.disconnect(_on_target_mouse_exited)
		_registered_tooltips.erase(tooltip_id)


## Show tooltip with custom content immediately
func show_custom_tooltip(data: Dictionary, position: Vector2 = Vector2.ZERO) -> void:
	_populate_content(data)
	_target_position = position if position != Vector2.ZERO else get_viewport().get_mouse_position() + cursor_offset
	_actual_position = _target_position
	_show_tooltip()


## Hide the current tooltip
func hide_tooltip() -> void:
	if not _is_showing:
		return

	_is_showing = false

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_IN)
	_fade_tween.set_trans(Tween.TRANS_QUAD)
	_fade_tween.tween_property(_tooltip_container, "modulate:a", 0.0, 0.15)
	_fade_tween.tween_callback(_hide_immediate)

	tooltip_hidden.emit(_current_tooltip_id)


## Create a stat display widget
func create_stat_widget(icon_path: String, value: String, color: Color = Color.WHITE) -> Control:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	if not icon_path.is_empty():
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = color
		if ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		container.add_child(icon)

	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	container.add_child(label)

	return container


# =====================================================================
# INTERNAL METHODS
# =====================================================================

func _on_target_mouse_entered(target: Control, tooltip_id: String) -> void:
	_current_target = target
	_current_tooltip_id = tooltip_id
	_hover_timer = 0.0

	# Preload content
	if _registered_tooltips.has(tooltip_id):
		_populate_content(_registered_tooltips[tooltip_id].get("data", {}))


func _on_target_mouse_exited(_target: Control, _tooltip_id: String) -> void:
	# Small delay to allow moving to tooltip itself
	await get_tree().create_timer(0.05).timeout
	if not _is_mouse_over_tooltip():
		_reset_hover()
		hide_tooltip()


func _is_mouse_over_target() -> bool:
	if not _current_target or not is_instance_valid(_current_target):
		return false
	return _current_target.get_global_rect().has_point(get_viewport().get_mouse_position())


func _is_mouse_over_tooltip() -> bool:
	if not _is_showing:
		return false
	var tooltip_rect := Rect2(_tooltip_container.global_position, _background_panel.size)
	return tooltip_rect.has_point(get_viewport().get_mouse_position())


func _reset_hover() -> void:
	_current_target = null
	_current_tooltip_id = ""
	_hover_timer = 0.0


func _show_tooltip() -> void:
	if _is_showing:
		return

	_is_showing = true
	_tooltip_container.visible = true
	_actual_position = _target_position

	# Update size based on content
	_update_tooltip_size()

	# Fade in animation
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_tooltip_container.modulate.a = 0.0
	_tooltip_container.scale = Vector2(0.95, 0.95)

	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.set_trans(Tween.TRANS_BACK)
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(_tooltip_container, "modulate:a", 1.0, 0.2)
	_fade_tween.tween_property(_tooltip_container, "scale", Vector2.ONE, 0.25)

	# Start glow animation
	_start_glow_animation()

	tooltip_shown.emit(_current_tooltip_id)


func _hide_immediate() -> void:
	_tooltip_container.visible = false
	_tooltip_container.modulate.a = 0.0
	_is_showing = false
	_stop_glow_animation()


func _populate_content(data: Dictionary) -> void:
	# Title
	var title: String = data.get("title", "")
	_title_label.text = title
	_title_label.visible = not title.is_empty()

	# Icon
	var icon_path: String = data.get("icon", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		_icon_display.texture = load(icon_path)
		_icon_display.visible = true
	else:
		_icon_display.visible = false

	# Description (supports BBCode)
	var description: String = data.get("description", "")
	_description_label.text = description
	_description_label.visible = not description.is_empty()

	# Stats
	var stats: Array = data.get("stats", [])
	_populate_stats(stats)

	# Custom content callback
	if data.has("custom_content"):
		var callback: Callable = data.get("custom_content")
		if callback.is_valid():
			var custom_node: Control = callback.call()
			if custom_node:
				_content_container.add_child(custom_node)


func _populate_stats(stats: Array) -> void:
	# Clear existing stats
	for child in _stats_container.get_children():
		child.queue_free()

	if stats.is_empty():
		_stats_container.visible = false
		return

	_stats_container.visible = true

	for stat in stats:
		var widget := create_stat_widget(
			stat.get("icon", ""),
			stat.get("value", ""),
			stat.get("color", Color.WHITE)
		)
		_stats_container.add_child(widget)

		# Add separator
		var separator := VSeparator.new()
		separator.modulate = Color(1, 1, 1, 0.3)
		_stats_container.add_child(separator)

	# Remove last separator
	if _stats_container.get_child_count() > 0:
		_stats_container.get_child(_stats_container.get_child_count() - 1).queue_free()


func _update_tooltip_size() -> void:
	# Calculate content size
	_description_label.custom_minimum_size.x = min(_description_label.get_content_width(), max_width)

	await get_tree().process_frame

	var content_size := _content_container.get_combined_minimum_size()
	var panel_size := content_size + padding * 2

	_background_panel.custom_minimum_size = panel_size
	_background_panel.size = panel_size

	# Glow slightly larger
	_border_glow.custom_minimum_size = panel_size + Vector2(12, 12)
	_border_glow.size = panel_size + Vector2(12, 12)
	_border_glow.position = Vector2(-6, -6)


func _adapt_position_to_screen() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var tooltip_size := _background_panel.size
	var margin := 10.0

	# Check right edge
	if _actual_position.x + tooltip_size.x > viewport_size.x - margin:
		_actual_position.x = viewport_size.x - tooltip_size.x - margin

	# Check bottom edge
	if _actual_position.y + tooltip_size.y > viewport_size.y - margin:
		_actual_position.y = get_viewport().get_mouse_position().y - tooltip_size.y - cursor_offset.y

	# Check left edge
	if _actual_position.x < margin:
		_actual_position.x = margin

	# Check top edge
	if _actual_position.y < margin:
		_actual_position.y = margin


func _update_arrow_position() -> void:
	if not _current_target or not is_instance_valid(_current_target):
		_arrow.visible = false
		return

	_arrow.visible = true
	var target_center := _current_target.global_position + _current_target.size / 2
	var tooltip_rect := Rect2(_tooltip_container.global_position, _background_panel.size)

	# Position arrow to point at target
	var arrow_pos := Vector2.ZERO

	if target_center.y < tooltip_rect.position.y:
		# Target above - arrow at top
		arrow_pos = Vector2(tooltip_rect.size.x / 2, 0)
		_arrow.rotation = PI
	elif target_center.y > tooltip_rect.end.y:
		# Target below - arrow at bottom
		arrow_pos = Vector2(tooltip_rect.size.x / 2, tooltip_rect.size.y)
		_arrow.rotation = 0
	elif target_center.x < tooltip_rect.position.x:
		# Target left - arrow at left
		arrow_pos = Vector2(0, tooltip_rect.size.y / 2)
		_arrow.rotation = PI / 2
	else:
		# Target right - arrow at right
		arrow_pos = Vector2(tooltip_rect.size.x, tooltip_rect.size.y / 2)
		_arrow.rotation = -PI / 2

	_arrow.position = arrow_pos


func _update_border_gradient() -> void:
	# Animate border color gradient
	var style: StyleBoxFlat = _background_panel.get_theme_stylebox("panel")
	if style:
		var hue := fmod(_border_animation_time * 0.1, 1.0)
		var gradient_color := Color.from_hsv(0.55 + sin(_border_animation_time) * 0.1, 0.6, 0.9, 0.8)
		style.border_color = gradient_color


func _start_glow_animation() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()

	_glow_tween = create_tween()
	_glow_tween.set_loops()
	_glow_tween.tween_property(_border_glow, "modulate:a", 0.6, 1.0)
	_glow_tween.tween_property(_border_glow, "modulate:a", 1.0, 1.0)


func _stop_glow_animation() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null
