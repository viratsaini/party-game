## GraphicsPreview - Before/After comparison slider with live preview and FPS counter.
##
## Features:
## - Before/After comparison slider
## - Live preview of settings
## - FPS counter display
## - Warning for performance-heavy options
## - Animated quality indicators
## - Smooth transitions
class_name GraphicsPreview
extends Control

# ============================================================================ #
#                                   SIGNALS                                     #
# ============================================================================ #

## Emitted when comparison slider moves.
signal comparison_changed(position: float)

## Emitted when preset is selected.
signal preset_selected(preset_index: int)

# ============================================================================ #
#                                  CONSTANTS                                    #
# ============================================================================ #

const SLIDER_WIDTH: float = 4.0
const HANDLE_SIZE: float = 40.0
const FPS_UPDATE_INTERVAL: float = 0.5
const WARNING_FADE_DURATION: float = 0.3

const COLORS := {
	"slider": Color(1.0, 1.0, 1.0, 0.9),
	"slider_glow": Color(1.0, 1.0, 1.0, 0.4),
	"handle": Color(1.0, 1.0, 1.0, 1.0),
	"handle_border": Color(0.2, 0.6, 1.0, 1.0),

	"fps_good": Color(0.3, 0.9, 0.4, 1.0),
	"fps_medium": Color(1.0, 0.8, 0.2, 1.0),
	"fps_bad": Color(1.0, 0.3, 0.3, 1.0),

	"label_before": Color(0.8, 0.4, 0.3, 1.0),
	"label_after": Color(0.3, 0.8, 0.4, 1.0),

	"warning_bg": Color(0.8, 0.3, 0.2, 0.9),
	"warning_text": Color(1.0, 1.0, 1.0, 1.0),

	"indicator_low": Color(0.5, 0.5, 0.55, 1.0),
	"indicator_medium": Color(0.8, 0.7, 0.3, 1.0),
	"indicator_high": Color(0.3, 0.8, 0.5, 1.0),
	"indicator_ultra": Color(0.4, 0.6, 1.0, 1.0),
}

const PRESETS := {
	0: {"name": "Low", "color": "indicator_low"},
	1: {"name": "Medium", "color": "indicator_medium"},
	2: {"name": "High", "color": "indicator_high"},
	3: {"name": "Ultra", "color": "indicator_ultra"},
	4: {"name": "Custom", "color": "indicator_high"},
}

# ============================================================================ #
#                                  EXPORTS                                      #
# ============================================================================ #

## Before image texture (low quality preview).
@export var before_texture: Texture2D

## After image texture (high quality preview).
@export var after_texture: Texture2D

## Current quality preset index.
@export var current_preset: int = 2

## Show FPS counter.
@export var show_fps: bool = true

## Show performance warnings.
@export var show_warnings: bool = true

# ============================================================================ #
#                                   STATE                                       #
# ============================================================================ #

## Comparison slider position (0-1).
var slider_position: float = 0.5

## Is slider being dragged.
var is_dragging: bool = false

## Current FPS value.
var current_fps: float = 60.0

## FPS update timer.
var fps_timer: float = 0.0

## FPS history for smoothing.
var fps_history: Array[float] = []

## Warning message.
var warning_message: String = ""

## Warning visibility.
var warning_visible: bool = false

## Warning fade progress.
var warning_fade: float = 0.0

## Quality indicator animations.
var indicator_pulses: Array[float] = [0.0, 0.0, 0.0, 0.0]

## Hover state for slider.
var is_hovering_slider: bool = false

# ============================================================================ #
#                                 LIFECYCLE                                     #
# ============================================================================ #

func _ready() -> void:
	custom_minimum_size = Vector2(400, 250)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Initialize FPS history.
	for i: int in 10:
		fps_history.append(60.0)


func _process(delta: float) -> void:
	# Update FPS counter.
	fps_timer += delta
	if fps_timer >= FPS_UPDATE_INTERVAL:
		fps_timer = 0.0
		_update_fps()

	# Update warning fade.
	var target_fade := 1.0 if warning_visible else 0.0
	warning_fade = lerpf(warning_fade, target_fade, 8.0 * delta)

	# Update quality indicator pulses.
	for i: int in indicator_pulses.size():
		if i == current_preset:
			indicator_pulses[i] = lerpf(indicator_pulses[i], 1.0, 6.0 * delta)
		else:
			indicator_pulses[i] = lerpf(indicator_pulses[i], 0.0, 6.0 * delta)

	queue_redraw()


func _draw() -> void:
	_draw_preview_area()
	_draw_comparison_slider()
	_draw_labels()
	if show_fps:
		_draw_fps_counter()
	_draw_quality_indicators()
	if warning_fade > 0.01:
		_draw_warning()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _is_point_on_slider(event.position):
					is_dragging = true
					_update_slider_position(event.position)
			else:
				is_dragging = false

	elif event is InputEventMouseMotion:
		is_hovering_slider = _is_point_on_slider(event.position)
		if is_dragging:
			_update_slider_position(event.position)

# ============================================================================ #
#                                  DRAWING                                      #
# ============================================================================ #

func _draw_preview_area() -> void:
	var preview_rect := _get_preview_rect()

	# Background.
	draw_rect(preview_rect, Color(0.1, 0.1, 0.12, 1.0))

	# Before image (left side).
	if before_texture:
		var before_rect := Rect2(
			preview_rect.position,
			Vector2(preview_rect.size.x * slider_position, preview_rect.size.y)
		)
		var src_rect := Rect2(
			Vector2.ZERO,
			Vector2(before_texture.get_width() * slider_position, before_texture.get_height())
		)
		draw_texture_rect_region(before_texture, before_rect, src_rect)
	else:
		# Placeholder gradient.
		var before_rect := Rect2(
			preview_rect.position,
			Vector2(preview_rect.size.x * slider_position, preview_rect.size.y)
		)
		_draw_placeholder_before(before_rect)

	# After image (right side).
	if after_texture:
		var after_rect := Rect2(
			Vector2(preview_rect.position.x + preview_rect.size.x * slider_position, preview_rect.position.y),
			Vector2(preview_rect.size.x * (1.0 - slider_position), preview_rect.size.y)
		)
		var src_rect := Rect2(
			Vector2(after_texture.get_width() * slider_position, 0),
			Vector2(after_texture.get_width() * (1.0 - slider_position), after_texture.get_height())
		)
		draw_texture_rect_region(after_texture, after_rect, src_rect)
	else:
		# Placeholder gradient.
		var after_rect := Rect2(
			Vector2(preview_rect.position.x + preview_rect.size.x * slider_position, preview_rect.position.y),
			Vector2(preview_rect.size.x * (1.0 - slider_position), preview_rect.size.y)
		)
		_draw_placeholder_after(after_rect)

	# Border.
	draw_rect(preview_rect, Color(0.3, 0.3, 0.35, 1.0), false, 2.0)


func _draw_placeholder_before(rect: Rect2) -> void:
	# Simulated low quality (pixelated, desaturated).
	var step := 20.0
	for x: float in range(rect.position.x, rect.end.x, step):
		for y: float in range(rect.position.y, rect.end.y, step):
			var t := (x - rect.position.x) / rect.size.x
			var base_color := Color(0.3 + t * 0.2, 0.25, 0.35 - t * 0.1)
			draw_rect(Rect2(Vector2(x, y), Vector2(step, step)), base_color.darkened(0.2))


func _draw_placeholder_after(rect: Rect2) -> void:
	# Simulated high quality (smooth gradients, vibrant).
	# Simple gradient for demo.
	for i: int in int(rect.size.x):
		var x := rect.position.x + i
		var t := float(i) / rect.size.x
		var color := Color(0.4 + t * 0.3, 0.35 + t * 0.2, 0.5 - t * 0.1)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), color, 1.0)


func _draw_comparison_slider() -> void:
	var preview_rect := _get_preview_rect()
	var slider_x := preview_rect.position.x + preview_rect.size.x * slider_position

	# Glow.
	if is_hovering_slider or is_dragging:
		var glow_width := 12.0
		draw_rect(
			Rect2(Vector2(slider_x - glow_width / 2, preview_rect.position.y), Vector2(glow_width, preview_rect.size.y)),
			COLORS["slider_glow"]
		)

	# Slider line.
	draw_line(
		Vector2(slider_x, preview_rect.position.y),
		Vector2(slider_x, preview_rect.end.y),
		COLORS["slider"], SLIDER_WIDTH
	)

	# Handle.
	var handle_y := preview_rect.position.y + preview_rect.size.y / 2
	var handle_rect := Rect2(
		Vector2(slider_x - HANDLE_SIZE / 2, handle_y - HANDLE_SIZE / 2),
		Vector2(HANDLE_SIZE, HANDLE_SIZE)
	)

	# Handle background.
	draw_circle(Vector2(slider_x, handle_y), HANDLE_SIZE / 2, COLORS["handle"])

	# Handle border.
	draw_arc(
		Vector2(slider_x, handle_y), HANDLE_SIZE / 2,
		0, TAU, 24, COLORS["handle_border"], 3.0, true
	)

	# Handle arrows.
	var arrow_size := 8.0
	var arrow_color := COLORS["handle_border"]

	# Left arrow.
	var left_points: PackedVector2Array = [
		Vector2(slider_x - arrow_size, handle_y),
		Vector2(slider_x - arrow_size / 2, handle_y - arrow_size / 2),
		Vector2(slider_x - arrow_size / 2, handle_y + arrow_size / 2)
	]
	draw_colored_polygon(left_points, arrow_color)

	# Right arrow.
	var right_points: PackedVector2Array = [
		Vector2(slider_x + arrow_size, handle_y),
		Vector2(slider_x + arrow_size / 2, handle_y - arrow_size / 2),
		Vector2(slider_x + arrow_size / 2, handle_y + arrow_size / 2)
	]
	draw_colored_polygon(right_points, arrow_color)


func _draw_labels() -> void:
	var preview_rect := _get_preview_rect()
	var font := ThemeDB.fallback_font
	var font_size := 12

	# Before label.
	var before_text := "BEFORE"
	draw_string(
		font,
		Vector2(preview_rect.position.x + 10, preview_rect.position.y + 20),
		before_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLORS["label_before"]
	)

	# After label.
	var after_text := "AFTER"
	var after_size := font.get_string_size(after_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size)
	draw_string(
		font,
		Vector2(preview_rect.end.x - after_size.x - 10, preview_rect.position.y + 20),
		after_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size, COLORS["label_after"]
	)


func _draw_fps_counter() -> void:
	var preview_rect := _get_preview_rect()
	var font := ThemeDB.fallback_font

	var fps_text := "%d FPS" % roundi(current_fps)
	var fps_color: Color

	if current_fps >= 60:
		fps_color = COLORS["fps_good"]
	elif current_fps >= 30:
		fps_color = COLORS["fps_medium"]
	else:
		fps_color = COLORS["fps_bad"]

	# Background.
	var text_size := font.get_string_size(fps_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	var bg_rect := Rect2(
		Vector2(preview_rect.end.x - text_size.x - 20, preview_rect.end.y - 30),
		Vector2(text_size.x + 12, 22)
	)
	draw_rect(bg_rect, Color(0, 0, 0, 0.6))

	# Text.
	draw_string(
		font,
		Vector2(bg_rect.position.x + 6, bg_rect.position.y + 16),
		fps_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fps_color
	)


func _draw_quality_indicators() -> void:
	var indicator_y := size.y - 30
	var indicator_spacing := 80.0
	var start_x := (size.x - (PRESETS.size() - 1) * indicator_spacing) / 2

	var font := ThemeDB.fallback_font
	var font_size := 11

	for i: int in PRESETS.size():
		if i == 4:  # Skip "Custom".
			continue

		var preset: Dictionary = PRESETS[i]
		var x := start_x + i * indicator_spacing
		var is_selected := i == current_preset

		# Indicator dot.
		var dot_radius := 6.0 + indicator_pulses[i] * 2.0
		var color: Color = COLORS[preset["color"]]

		if is_selected:
			# Glow.
			draw_circle(Vector2(x, indicator_y), dot_radius + 4, Color(color, 0.3))

		draw_circle(Vector2(x, indicator_y), dot_radius, color)

		if is_selected:
			# Border.
			draw_arc(Vector2(x, indicator_y), dot_radius + 2, 0, TAU, 16, Color.WHITE, 2.0, true)

		# Label.
		var label_color := Color.WHITE if is_selected else COLORS["indicator_low"]
		var label_size := font.get_string_size(preset["name"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(
			font,
			Vector2(x - label_size.x / 2, indicator_y + 18),
			preset["name"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, label_color
		)


func _draw_warning() -> void:
	if warning_message.is_empty():
		return

	var font := ThemeDB.fallback_font
	var font_size := 12
	var text_size := font.get_string_size(warning_message, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

	var warning_rect := Rect2(
		Vector2((size.x - text_size.x - 30) / 2, 10),
		Vector2(text_size.x + 30, 28)
	)

	# Background.
	var bg_color := COLORS["warning_bg"]
	bg_color.a *= warning_fade
	_draw_rounded_rect(warning_rect, 6.0, bg_color)

	# Warning icon.
	var icon_x := warning_rect.position.x + 12
	var icon_y := warning_rect.position.y + 14
	var icon_color := Color(COLORS["warning_text"], warning_fade)
	draw_circle(Vector2(icon_x, icon_y - 3), 2, icon_color)
	draw_rect(Rect2(Vector2(icon_x - 1.5, icon_y), Vector2(3, 6)), icon_color)

	# Text.
	var text_color := Color(COLORS["warning_text"], warning_fade)
	draw_string(
		font,
		Vector2(warning_rect.position.x + 25, warning_rect.position.y + 18),
		warning_message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color
	)


func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var inner_rect := Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2, rect.size.y)
	draw_rect(inner_rect, color)
	draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius * 2), color)

	draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.end.y - radius), radius, color)

# ============================================================================ #
#                                  HELPERS                                      #
# ============================================================================ #

func _get_preview_rect() -> Rect2:
	return Rect2(
		Vector2(10, 10),
		Vector2(size.x - 20, size.y - 70)
	)


func _is_point_on_slider(point: Vector2) -> bool:
	var preview_rect := _get_preview_rect()
	var slider_x := preview_rect.position.x + preview_rect.size.x * slider_position

	return abs(point.x - slider_x) < HANDLE_SIZE and preview_rect.has_point(point)


func _update_slider_position(mouse_pos: Vector2) -> void:
	var preview_rect := _get_preview_rect()
	var new_position := (mouse_pos.x - preview_rect.position.x) / preview_rect.size.x
	slider_position = clampf(new_position, 0.05, 0.95)
	comparison_changed.emit(slider_position)


func _update_fps() -> void:
	var new_fps := Engine.get_frames_per_second()
	fps_history.push_back(new_fps)
	if fps_history.size() > 10:
		fps_history.pop_front()

	# Smooth FPS value.
	var sum := 0.0
	for fps: float in fps_history:
		sum += fps
	current_fps = sum / fps_history.size()

# ============================================================================ #
#                                PUBLIC API                                     #
# ============================================================================ #

## Set quality preset.
func set_preset(preset_index: int) -> void:
	if preset_index >= 0 and preset_index < PRESETS.size():
		current_preset = preset_index
		preset_selected.emit(preset_index)


## Show warning message.
func show_warning(message: String) -> void:
	warning_message = message
	warning_visible = true


## Hide warning.
func hide_warning() -> void:
	warning_visible = false


## Set comparison slider position (0-1).
func set_slider_position(position: float) -> void:
	slider_position = clampf(position, 0.05, 0.95)


## Get current FPS.
func get_fps() -> float:
	return current_fps
