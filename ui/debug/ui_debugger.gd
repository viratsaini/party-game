## UIDebugger - Comprehensive UI debugging tools for BattleZone Party
##
## Provides visual debugging through:
## - Performance overlay (FPS, memory, draw calls)
## - Animation debugger with timeline
## - Layout bounds visualizer
## - Touch target visualizer
## - Accessibility checker
## - Theme preview tool
##
## Usage:
##   UIDebugger.toggle_performance_overlay()
##   UIDebugger.show_layout_bounds()
##   UIDebugger.highlight_touch_targets()
class_name UIDebugger
extends CanvasLayer


# =============================================================================
# region - Signals
# =============================================================================

## Emitted when debug mode changes
signal debug_mode_changed(enabled: bool)

## Emitted when a UI issue is detected
signal issue_detected(issue_type: String, node: Node, message: String)

# endregion


# =============================================================================
# region - Enums
# =============================================================================

## Debug overlay modes
enum OverlayMode {
	NONE,
	PERFORMANCE,
	LAYOUT,
	TOUCH_TARGETS,
	ACCESSIBILITY,
	ANIMATION,
	THEME,
	ALL
}

# endregion


# =============================================================================
# region - Constants
# =============================================================================

## Overlay colors
const COLOR_FPS_GOOD: Color = Color(0.3, 1.0, 0.3, 0.9)
const COLOR_FPS_WARN: Color = Color(1.0, 0.8, 0.3, 0.9)
const COLOR_FPS_BAD: Color = Color(1.0, 0.3, 0.3, 0.9)
const COLOR_LAYOUT_BOUNDS: Color = Color(0.0, 1.0, 0.0, 0.3)
const COLOR_LAYOUT_MARGIN: Color = Color(1.0, 0.5, 0.0, 0.2)
const COLOR_TOUCH_OK: Color = Color(0.0, 1.0, 0.0, 0.4)
const COLOR_TOUCH_SMALL: Color = Color(1.0, 0.0, 0.0, 0.4)
const COLOR_A11Y_ERROR: Color = Color(1.0, 0.0, 0.0, 0.5)
const COLOR_A11Y_WARN: Color = Color(1.0, 1.0, 0.0, 0.5)

## Minimum touch target size
const MIN_TOUCH_SIZE: float = 44.0

## Performance thresholds
const FPS_GOOD: float = 55.0
const FPS_WARN: float = 40.0

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

## Current overlay mode
var current_mode: OverlayMode = OverlayMode.NONE

## Whether debug mode is enabled
var debug_enabled: bool = false

## Performance tracking
var _fps_samples: Array[float] = []
var _frame_times: Array[float] = []
var _current_fps: float = 60.0
var _current_frame_time: float = 0.016
var _draw_calls: int = 0

## Memory tracking
var _current_memory_mb: float = 0.0
var _peak_memory_mb: float = 0.0

## Animation tracking
var _active_tweens: Array[WeakRef] = []
var _animation_history: Array[Dictionary] = []

## UI references
var _overlay_container: Control = null
var _performance_panel: PanelContainer = null
var _fps_label: Label = null
var _memory_label: Label = null
var _draw_calls_label: Label = null
var _frame_time_label: Label = null
var _graph_control: Control = null

## Layout visualization
var _layout_overlay: Control = null

## Touch target visualization
var _touch_overlay: Control = null

## Accessibility overlay
var _a11y_overlay: Control = null

## Animation timeline
var _animation_panel: PanelContainer = null

## Theme preview
var _theme_panel: PanelContainer = null

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	layer = 100  # Ensure debug overlay is on top
	_create_overlay_container()


func _process(delta: float) -> void:
	if not debug_enabled:
		return

	_track_performance(delta)
	_update_overlays()


func _input(event: InputEvent) -> void:
	# Toggle debug overlay with F3
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			toggle_debug_mode()
		elif event.keycode == KEY_F4 and debug_enabled:
			cycle_overlay_mode()

# endregion


# =============================================================================
# region - Main API
# =============================================================================

## Toggles debug mode on/off
func toggle_debug_mode() -> void:
	debug_enabled = not debug_enabled
	_overlay_container.visible = debug_enabled

	if debug_enabled:
		set_overlay_mode(OverlayMode.PERFORMANCE)
	else:
		set_overlay_mode(OverlayMode.NONE)

	debug_mode_changed.emit(debug_enabled)


## Sets the current overlay mode
func set_overlay_mode(mode: OverlayMode) -> void:
	current_mode = mode
	_update_overlay_visibility()


## Cycles through overlay modes
func cycle_overlay_mode() -> void:
	var next_mode: int = (current_mode + 1) % OverlayMode.size()
	set_overlay_mode(next_mode as OverlayMode)


## Toggles performance overlay
func toggle_performance_overlay() -> void:
	if current_mode == OverlayMode.PERFORMANCE:
		set_overlay_mode(OverlayMode.NONE)
	else:
		set_overlay_mode(OverlayMode.PERFORMANCE)


## Shows layout bounds for all controls
func show_layout_bounds() -> void:
	set_overlay_mode(OverlayMode.LAYOUT)


## Highlights touch targets
func highlight_touch_targets() -> void:
	set_overlay_mode(OverlayMode.TOUCH_TARGETS)


## Shows accessibility checker
func show_accessibility_checker() -> void:
	set_overlay_mode(OverlayMode.ACCESSIBILITY)


## Shows animation debugger
func show_animation_debugger() -> void:
	set_overlay_mode(OverlayMode.ANIMATION)


## Shows theme preview
func show_theme_preview() -> void:
	set_overlay_mode(OverlayMode.THEME)

# endregion


# =============================================================================
# region - Overlay Creation
# =============================================================================

func _create_overlay_container() -> void:
	_overlay_container = Control.new()
	_overlay_container.name = "DebugOverlayContainer"
	_overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_container.visible = false
	add_child(_overlay_container)

	_create_performance_panel()
	_create_layout_overlay()
	_create_touch_overlay()
	_create_a11y_overlay()
	_create_animation_panel()
	_create_theme_panel()


func _create_performance_panel() -> void:
	_performance_panel = PanelContainer.new()
	_performance_panel.name = "PerformancePanel"
	_performance_panel.position = Vector2(10, 10)
	_performance_panel.custom_minimum_size = Vector2(220, 180)
	_performance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_performance_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	_performance_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Performance"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# FPS
	_fps_label = Label.new()
	_fps_label.text = "FPS: 60"
	_fps_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_fps_label)

	# Frame time
	_frame_time_label = Label.new()
	_frame_time_label.text = "Frame: 16.67 ms"
	_frame_time_label.add_theme_font_size_override("font_size", 12)
	_frame_time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_frame_time_label)

	# Memory
	_memory_label = Label.new()
	_memory_label.text = "Memory: 0 MB"
	_memory_label.add_theme_font_size_override("font_size", 12)
	_memory_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_memory_label)

	# Draw calls
	_draw_calls_label = Label.new()
	_draw_calls_label.text = "Draw Calls: 0"
	_draw_calls_label.add_theme_font_size_override("font_size", 12)
	_draw_calls_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_draw_calls_label)

	# FPS Graph
	_graph_control = Control.new()
	_graph_control.custom_minimum_size = Vector2(200, 50)
	_graph_control.draw.connect(_draw_fps_graph)
	vbox.add_child(_graph_control)

	_overlay_container.add_child(_performance_panel)


func _create_layout_overlay() -> void:
	_layout_overlay = Control.new()
	_layout_overlay.name = "LayoutOverlay"
	_layout_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_overlay.draw.connect(_draw_layout_bounds)
	_layout_overlay.visible = false
	_overlay_container.add_child(_layout_overlay)


func _create_touch_overlay() -> void:
	_touch_overlay = Control.new()
	_touch_overlay.name = "TouchOverlay"
	_touch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_overlay.draw.connect(_draw_touch_targets)
	_touch_overlay.visible = false
	_overlay_container.add_child(_touch_overlay)


func _create_a11y_overlay() -> void:
	_a11y_overlay = Control.new()
	_a11y_overlay.name = "AccessibilityOverlay"
	_a11y_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_a11y_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_a11y_overlay.draw.connect(_draw_accessibility_issues)
	_a11y_overlay.visible = false
	_overlay_container.add_child(_a11y_overlay)


func _create_animation_panel() -> void:
	_animation_panel = PanelContainer.new()
	_animation_panel.name = "AnimationPanel"
	_animation_panel.position = Vector2(10, 200)
	_animation_panel.custom_minimum_size = Vector2(300, 150)
	_animation_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animation_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_animation_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	_animation_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Animation Debugger"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var info := Label.new()
	info.text = "Active Tweens: 0\nTotal This Frame: 0\nAnimation Budget: 0.0 ms"
	info.name = "AnimInfo"
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(info)

	_overlay_container.add_child(_animation_panel)


func _create_theme_panel() -> void:
	_theme_panel = PanelContainer.new()
	_theme_panel.name = "ThemePanel"
	_theme_panel.position = Vector2(240, 10)
	_theme_panel.custom_minimum_size = Vector2(250, 300)
	_theme_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_theme_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_theme_panel.add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230, 280)
	_theme_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "Theme Preview"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Color swatches
	var colors_label := Label.new()
	colors_label.text = "Color Palette"
	colors_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(colors_label)

	var color_grid := GridContainer.new()
	color_grid.columns = 5

	var color_names: Array[String] = [
		"primary", "secondary", "accent", "success", "error",
		"warning", "info", "neutral.100", "neutral.500", "neutral.900"
	]

	for color_name: String in color_names:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(30, 30)
		# Use a placeholder color; in real usage, get from DesignSystem
		swatch.color = Color.from_hsv(randf(), 0.7, 0.9)
		swatch.tooltip_text = color_name
		color_grid.add_child(swatch)

	vbox.add_child(color_grid)

	# Typography samples
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var typo_label := Label.new()
	typo_label.text = "Typography"
	typo_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(typo_label)

	var sizes: Array[int] = [24, 20, 16, 14, 12]
	var size_names: Array[String] = ["H1", "H2", "Body", "Small", "Caption"]

	for i in range(sizes.size()):
		var sample := Label.new()
		sample.text = "%s (%dpx)" % [size_names[i], sizes[i]]
		sample.add_theme_font_size_override("font_size", sizes[i])
		sample.add_theme_color_override("font_color", Color.WHITE)
		vbox.add_child(sample)

	# Spacing samples
	var sep3 := HSeparator.new()
	vbox.add_child(sep3)

	var spacing_label := Label.new()
	spacing_label.text = "Spacing (4px grid)"
	spacing_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(spacing_label)

	var spacing_flow := HBoxContainer.new()
	var spacing_sizes: Array[int] = [4, 8, 12, 16, 24, 32]

	for sp: int in spacing_sizes:
		var box := ColorRect.new()
		box.custom_minimum_size = Vector2(sp, 20)
		box.color = Color(0.3, 0.6, 1.0, 0.7)
		box.tooltip_text = "%dpx" % sp
		spacing_flow.add_child(box)

	vbox.add_child(spacing_flow)

	_overlay_container.add_child(_theme_panel)

# endregion


# =============================================================================
# region - Performance Tracking
# =============================================================================

func _track_performance(delta: float) -> void:
	# Track frame time
	_frame_times.append(delta)
	if _frame_times.size() > 120:
		_frame_times.remove_at(0)

	# Calculate FPS
	var total: float = 0.0
	for ft: float in _frame_times:
		total += ft
	_current_frame_time = total / _frame_times.size()
	_current_fps = 1.0 / _current_frame_time if _current_frame_time > 0 else 60.0

	# Store FPS sample for graph
	_fps_samples.append(_current_fps)
	if _fps_samples.size() > 100:
		_fps_samples.remove_at(0)

	# Memory tracking
	_current_memory_mb = float(OS.get_static_memory_usage()) / 1048576.0
	_peak_memory_mb = maxf(_peak_memory_mb, _current_memory_mb)

	# Draw calls
	_draw_calls = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)


func _update_overlays() -> void:
	if current_mode == OverlayMode.PERFORMANCE or current_mode == OverlayMode.ALL:
		_update_performance_panel()

	# Request redraws for visual overlays
	if _layout_overlay.visible:
		_layout_overlay.queue_redraw()
	if _touch_overlay.visible:
		_touch_overlay.queue_redraw()
	if _a11y_overlay.visible:
		_a11y_overlay.queue_redraw()
	if _graph_control.visible:
		_graph_control.queue_redraw()


func _update_performance_panel() -> void:
	# Update FPS with color coding
	var fps_color: Color
	if _current_fps >= FPS_GOOD:
		fps_color = COLOR_FPS_GOOD
	elif _current_fps >= FPS_WARN:
		fps_color = COLOR_FPS_WARN
	else:
		fps_color = COLOR_FPS_BAD

	_fps_label.text = "FPS: %.1f" % _current_fps
	_fps_label.add_theme_color_override("font_color", fps_color)

	_frame_time_label.text = "Frame: %.2f ms" % (_current_frame_time * 1000.0)
	_memory_label.text = "Memory: %.1f MB (peak: %.1f)" % [_current_memory_mb, _peak_memory_mb]
	_draw_calls_label.text = "Draw Calls: %d" % _draw_calls


func _update_overlay_visibility() -> void:
	_performance_panel.visible = current_mode in [OverlayMode.PERFORMANCE, OverlayMode.ALL]
	_layout_overlay.visible = current_mode in [OverlayMode.LAYOUT, OverlayMode.ALL]
	_touch_overlay.visible = current_mode in [OverlayMode.TOUCH_TARGETS, OverlayMode.ALL]
	_a11y_overlay.visible = current_mode in [OverlayMode.ACCESSIBILITY, OverlayMode.ALL]
	_animation_panel.visible = current_mode in [OverlayMode.ANIMATION, OverlayMode.ALL]
	_theme_panel.visible = current_mode == OverlayMode.THEME

# endregion


# =============================================================================
# region - Drawing Functions
# =============================================================================

func _draw_fps_graph() -> void:
	if _fps_samples.is_empty():
		return

	var rect := _graph_control.get_rect()
	var width: float = rect.size.x
	var height: float = rect.size.y

	# Background
	_graph_control.draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.05, 0.05, 0.05, 0.8))

	# Draw 60 FPS line
	var fps_60_y: float = height - (60.0 / 120.0 * height)
	_graph_control.draw_line(
		Vector2(0, fps_60_y),
		Vector2(width, fps_60_y),
		Color(0.3, 0.3, 0.3, 0.5),
		1.0
	)

	# Draw 30 FPS line
	var fps_30_y: float = height - (30.0 / 120.0 * height)
	_graph_control.draw_line(
		Vector2(0, fps_30_y),
		Vector2(width, fps_30_y),
		Color(0.5, 0.3, 0.3, 0.5),
		1.0
	)

	# Draw FPS graph
	var points: PackedVector2Array = []
	var sample_width: float = width / float(_fps_samples.size())

	for i in range(_fps_samples.size()):
		var fps: float = _fps_samples[i]
		var x: float = i * sample_width
		var y: float = height - clampf(fps / 120.0, 0.0, 1.0) * height
		points.append(Vector2(x, y))

	if points.size() >= 2:
		var color: Color
		if _current_fps >= FPS_GOOD:
			color = COLOR_FPS_GOOD
		elif _current_fps >= FPS_WARN:
			color = COLOR_FPS_WARN
		else:
			color = COLOR_FPS_BAD

		_graph_control.draw_polyline(points, color, 1.5, true)


func _draw_layout_bounds() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var controls := _get_all_controls(root)

	for control: Control in controls:
		if not control.visible:
			continue

		var rect := Rect2(control.global_position, control.size)

		# Draw bounds
		_layout_overlay.draw_rect(rect, COLOR_LAYOUT_BOUNDS, false, 1.0)

		# Draw margins if applicable
		var margin_top: float = control.get_theme_constant("margin_top", "MarginContainer") if control.has_theme_constant("margin_top", "MarginContainer") else 0
		var margin_right: float = control.get_theme_constant("margin_right", "MarginContainer") if control.has_theme_constant("margin_right", "MarginContainer") else 0
		var margin_bottom: float = control.get_theme_constant("margin_bottom", "MarginContainer") if control.has_theme_constant("margin_bottom", "MarginContainer") else 0
		var margin_left: float = control.get_theme_constant("margin_left", "MarginContainer") if control.has_theme_constant("margin_left", "MarginContainer") else 0

		if margin_top > 0 or margin_right > 0 or margin_bottom > 0 or margin_left > 0:
			var margin_rect := Rect2(
				rect.position - Vector2(margin_left, margin_top),
				rect.size + Vector2(margin_left + margin_right, margin_top + margin_bottom)
			)
			_layout_overlay.draw_rect(margin_rect, COLOR_LAYOUT_MARGIN)


func _draw_touch_targets() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var controls := _get_all_controls(root)

	for control: Control in controls:
		if not control.visible or not control is BaseButton:
			continue

		var rect := Rect2(control.global_position, control.size)
		var is_too_small: bool = control.size.x < MIN_TOUCH_SIZE or control.size.y < MIN_TOUCH_SIZE

		var color: Color = COLOR_TOUCH_SMALL if is_too_small else COLOR_TOUCH_OK
		_touch_overlay.draw_rect(rect, color)

		# Draw size label
		var size_text: String = "%dx%d" % [int(control.size.x), int(control.size.y)]
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 10
		var text_pos: Vector2 = rect.position + Vector2(2, font_size + 2)

		_touch_overlay.draw_string(font, text_pos, size_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

		if is_too_small:
			issue_detected.emit("touch_target", control, "Touch target too small: %s" % size_text)


func _draw_accessibility_issues() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var controls := _get_all_controls(root)

	for control: Control in controls:
		if not control.visible:
			continue

		var issues: Array[String] = []

		# Check touch target size for buttons
		if control is BaseButton:
			if control.size.x < MIN_TOUCH_SIZE or control.size.y < MIN_TOUCH_SIZE:
				issues.append("Small touch target")

		# Check focus mode
		if control is BaseButton and control.focus_mode == Control.FOCUS_NONE:
			issues.append("No focus mode")

		# Check for text contrast (simplified)
		if control is Label:
			var label := control as Label
			if label.text.strip_edges().is_empty():
				issues.append("Empty label")

		if issues.size() > 0:
			var rect := Rect2(control.global_position, control.size)
			var color: Color = COLOR_A11Y_ERROR if issues.size() > 1 else COLOR_A11Y_WARN
			_a11y_overlay.draw_rect(rect, color)

			# Draw issue icon
			_a11y_overlay.draw_circle(rect.position + Vector2(8, 8), 6, color.lightened(0.3))

			for issue: String in issues:
				issue_detected.emit("accessibility", control, issue)

# endregion


# =============================================================================
# region - Helper Functions
# =============================================================================

func _get_all_controls(root: Node) -> Array[Control]:
	var controls: Array[Control] = []

	if root is Control:
		controls.append(root)

	for child: Node in root.get_children():
		controls.append_array(_get_all_controls(child))

	return controls

# endregion


# =============================================================================
# region - Public API
# =============================================================================

## Gets current performance metrics
func get_performance_metrics() -> Dictionary:
	return {
		"fps": _current_fps,
		"frame_time_ms": _current_frame_time * 1000.0,
		"memory_mb": _current_memory_mb,
		"peak_memory_mb": _peak_memory_mb,
		"draw_calls": _draw_calls
	}


## Logs all UI issues in the current scene
func audit_current_scene() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var root := get_tree().current_scene

	if root == null:
		return issues

	var controls := _get_all_controls(root)

	for control: Control in controls:
		if not control.visible:
			continue

		# Touch target check
		if control is BaseButton:
			if control.size.x < MIN_TOUCH_SIZE or control.size.y < MIN_TOUCH_SIZE:
				issues.append({
					"type": "touch_target",
					"node": control.name,
					"path": str(control.get_path()),
					"message": "Touch target too small: %dx%d" % [int(control.size.x), int(control.size.y)]
				})

			# Focus check
			if control.focus_mode == Control.FOCUS_NONE:
				issues.append({
					"type": "focus",
					"node": control.name,
					"path": str(control.get_path()),
					"message": "Button has no focus mode"
				})

		# Empty label check
		if control is Label:
			var label := control as Label
			if label.text.strip_edges().is_empty():
				issues.append({
					"type": "empty_content",
					"node": control.name,
					"path": str(control.get_path()),
					"message": "Label has no text"
				})

	return issues


## Prints a performance report to console
func print_performance_report() -> void:
	var metrics := get_performance_metrics()
	print("=== UI Performance Report ===")
	print("FPS: %.1f" % metrics.fps)
	print("Frame Time: %.2f ms" % metrics.frame_time_ms)
	print("Memory: %.1f MB (peak: %.1f MB)" % [metrics.memory_mb, metrics.peak_memory_mb])
	print("Draw Calls: %d" % metrics.draw_calls)

	var issues := audit_current_scene()
	if issues.size() > 0:
		print("\n=== UI Issues (%d) ===" % issues.size())
		for issue: Dictionary in issues:
			print("[%s] %s: %s" % [issue.type, issue.node, issue.message])
	else:
		print("\nNo UI issues detected!")

# endregion
