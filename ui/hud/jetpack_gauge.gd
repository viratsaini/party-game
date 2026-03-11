## JetpackGauge -- Mobile-friendly fuel indicator UI for the jetpack.
##
## A vertical bar gauge showing jetpack fuel level with animated feedback,
## boost indicator, and power-up state visualization.
##
## Features:
##   - Smooth animated fill transitions
##   - Color changes based on fuel level (full -> low -> depleted)
##   - Boost flash effect
##   - Unlimited fuel power-up glow
##   - Mobile-optimized touch-friendly size
class_name JetpackGauge
extends Control

# =============================================================================
# region -- Signals
# =============================================================================

## Emitted when gauge is tapped (could trigger jetpack).
signal gauge_pressed()

# endregion

# =============================================================================
# region -- Constants
# =============================================================================

## Gauge colors at different fuel levels.
const COLOR_FULL: Color = Color(0.2, 0.8, 1.0, 0.9)       # Cyan
const COLOR_HIGH: Color = Color(0.3, 0.9, 0.5, 0.9)       # Green
const COLOR_MEDIUM: Color = Color(1.0, 0.8, 0.2, 0.9)     # Yellow
const COLOR_LOW: Color = Color(1.0, 0.4, 0.1, 0.9)        # Orange
const COLOR_CRITICAL: Color = Color(1.0, 0.2, 0.2, 0.9)   # Red
const COLOR_DEPLETED: Color = Color(0.4, 0.2, 0.2, 0.5)   # Dark red

## Background and border colors.
const COLOR_BG: Color = Color(0.1, 0.1, 0.15, 0.7)
const COLOR_BORDER: Color = Color(0.5, 0.5, 0.6, 0.8)

## Boost flash color.
const COLOR_BOOST_FLASH: Color = Color(1.0, 1.0, 1.0, 0.8)

## Unlimited fuel glow color.
const COLOR_UNLIMITED: Color = Color(0.6, 0.8, 1.0, 1.0)

## Animation speeds.
const FILL_ANIMATION_SPEED: float = 5.0
const FLASH_DURATION: float = 0.15
const PULSE_SPEED: float = 3.0

## Gauge dimensions (mobile-friendly).
const DEFAULT_WIDTH: float = 40.0
const DEFAULT_HEIGHT: float = 120.0
const BORDER_WIDTH: float = 3.0
const CORNER_RADIUS: float = 8.0
const INNER_PADDING: float = 4.0

## Fuel level thresholds.
const THRESHOLD_HIGH: float = 0.75
const THRESHOLD_MEDIUM: float = 0.5
const THRESHOLD_LOW: float = 0.25
const THRESHOLD_CRITICAL: float = 0.1

# endregion

# =============================================================================
# region -- Exports
# =============================================================================

## Current fuel level (0.0 - 1.0).
@export_range(0.0, 1.0) var fuel_level: float = 1.0:
	set(value):
		_target_fuel = clampf(value, 0.0, 1.0)

## Whether boost is available.
@export var boost_available: bool = true

## Whether unlimited fuel power-up is active.
@export var unlimited_fuel: bool = false:
	set(value):
		unlimited_fuel = value
		queue_redraw()

## Show numeric percentage.
@export var show_percentage: bool = false

## Gauge width.
@export var gauge_width: float = DEFAULT_WIDTH

## Gauge height.
@export var gauge_height: float = DEFAULT_HEIGHT

# endregion

# =============================================================================
# region -- State
# =============================================================================

## Current displayed fuel (animated).
var _displayed_fuel: float = 1.0

## Target fuel level for animation.
var _target_fuel: float = 1.0

## Flash effect timer.
var _flash_timer: float = 0.0
var _is_flashing: bool = false

## Pulse effect for low fuel warning.
var _pulse_phase: float = 0.0

## Whether gauge was just boosted (for visual feedback).
var _boost_triggered: bool = false

# endregion

# =============================================================================
# region -- Lifecycle
# =============================================================================

func _ready() -> void:
	custom_minimum_size = Vector2(gauge_width, gauge_height)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _process(delta: float) -> void:
	# Animate fuel level
	if not is_equal_approx(_displayed_fuel, _target_fuel):
		_displayed_fuel = move_toward(_displayed_fuel, _target_fuel, FILL_ANIMATION_SPEED * delta)
		queue_redraw()

	# Process flash effect
	if _is_flashing:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_is_flashing = false
			_boost_triggered = false
		queue_redraw()

	# Process pulse for low fuel
	if _displayed_fuel < THRESHOLD_LOW and not unlimited_fuel:
		_pulse_phase += PULSE_SPEED * delta
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(gauge_width, gauge_height))

	# Draw background
	_draw_background(rect)

	# Draw fuel fill
	_draw_fuel_fill(rect)

	# Draw border
	_draw_border(rect)

	# Draw boost indicator
	if boost_available:
		_draw_boost_indicator(rect)

	# Draw unlimited fuel effect
	if unlimited_fuel:
		_draw_unlimited_effect(rect)

	# Draw flash effect
	if _is_flashing:
		_draw_flash_effect(rect)

	# Draw percentage text
	if show_percentage:
		_draw_percentage(rect)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			gauge_pressed.emit()

# endregion

# =============================================================================
# region -- Drawing
# =============================================================================

func _draw_background(rect: Rect2) -> void:
	# Background with rounded corners
	var bg_rect := rect.grow(-BORDER_WIDTH * 0.5)
	draw_rect(bg_rect, COLOR_BG, true)


func _draw_fuel_fill(rect: Rect2) -> void:
	var inner_rect := rect.grow(-BORDER_WIDTH - INNER_PADDING)

	# Calculate fill height (from bottom to top)
	var fill_height := inner_rect.size.y * _displayed_fuel
	var fill_rect := Rect2(
		inner_rect.position + Vector2(0, inner_rect.size.y - fill_height),
		Vector2(inner_rect.size.x, fill_height)
	)

	# Get color based on fuel level
	var fill_color := _get_fuel_color(_displayed_fuel)

	# Apply pulse effect for low fuel
	if _displayed_fuel < THRESHOLD_LOW and not unlimited_fuel:
		var pulse := (sin(_pulse_phase) + 1.0) * 0.5
		fill_color = fill_color.lerp(COLOR_CRITICAL, pulse * 0.3)

	# Draw fill
	draw_rect(fill_rect, fill_color, true)

	# Add gradient highlight on the left edge
	var highlight_rect := Rect2(
		fill_rect.position,
		Vector2(3.0, fill_rect.size.y)
	)
	var highlight_color := Color(1.0, 1.0, 1.0, 0.2)
	draw_rect(highlight_rect, highlight_color, true)


func _draw_border(rect: Rect2) -> void:
	# Draw border outline
	var border_rect := rect.grow(-BORDER_WIDTH * 0.5)
	draw_rect(border_rect, COLOR_BORDER, false, BORDER_WIDTH)

	# Draw tick marks for fuel levels
	var inner_rect := rect.grow(-BORDER_WIDTH - INNER_PADDING)
	var tick_positions := [0.25, 0.5, 0.75]

	for pos in tick_positions:
		var y_pos := inner_rect.position.y + inner_rect.size.y * (1.0 - pos)
		var tick_start := Vector2(inner_rect.position.x - 2, y_pos)
		var tick_end := Vector2(inner_rect.position.x + 4, y_pos)
		draw_line(tick_start, tick_end, COLOR_BORDER, 1.0)


func _draw_boost_indicator(rect: Rect2) -> void:
	# Small indicator showing boost is ready
	var indicator_size := 8.0
	var indicator_pos := Vector2(
		rect.position.x + rect.size.x - indicator_size - 4,
		rect.position.y + 4
	)

	# Draw boost arrow/chevron
	var points := PackedVector2Array([
		indicator_pos + Vector2(indicator_size * 0.5, 0),
		indicator_pos + Vector2(indicator_size, indicator_size * 0.5),
		indicator_pos + Vector2(indicator_size * 0.5, indicator_size),
	])

	var boost_color := COLOR_FULL if boost_available else COLOR_DEPLETED
	if _boost_triggered:
		boost_color = COLOR_BOOST_FLASH

	draw_polyline(points, boost_color, 2.0)


func _draw_unlimited_effect(rect: Rect2) -> void:
	# Draw glowing border for unlimited fuel
	var glow_rect := rect.grow(2.0)

	# Pulsing glow
	var pulse := (sin(_pulse_phase * 2.0) + 1.0) * 0.5
	var glow_color := COLOR_UNLIMITED
	glow_color.a = 0.3 + pulse * 0.4

	draw_rect(glow_rect, glow_color, false, 4.0)

	# Draw infinity symbol or star indicator
	var center := rect.position + rect.size * 0.5
	var symbol_y := rect.position.y + rect.size.y - 15

	# Simple infinity symbol using two circles
	var circle_radius := 5.0
	var circle_offset := 4.0
	draw_arc(
		Vector2(center.x - circle_offset, symbol_y),
		circle_radius, 0, TAU, 12, COLOR_UNLIMITED, 2.0
	)
	draw_arc(
		Vector2(center.x + circle_offset, symbol_y),
		circle_radius, 0, TAU, 12, COLOR_UNLIMITED, 2.0
	)


func _draw_flash_effect(rect: Rect2) -> void:
	# White flash overlay
	var flash_alpha := _flash_timer / FLASH_DURATION
	var flash_color := COLOR_BOOST_FLASH
	flash_color.a *= flash_alpha

	draw_rect(rect, flash_color, true)


func _draw_percentage(rect: Rect2) -> void:
	var percentage := int(_displayed_fuel * 100)
	var text := "%d%%" % percentage

	var font := ThemeDB.fallback_font
	var font_size := 14

	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := Vector2(
		rect.position.x + (rect.size.x - text_size.x) * 0.5,
		rect.position.y + rect.size.y + text_size.y + 4
	)

	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

# endregion

# =============================================================================
# region -- Color Calculation
# =============================================================================

func _get_fuel_color(fuel: float) -> Color:
	if unlimited_fuel:
		return COLOR_UNLIMITED

	if fuel <= 0.0:
		return COLOR_DEPLETED
	elif fuel < THRESHOLD_CRITICAL:
		return COLOR_CRITICAL
	elif fuel < THRESHOLD_LOW:
		return COLOR_LOW
	elif fuel < THRESHOLD_MEDIUM:
		return COLOR_MEDIUM
	elif fuel < THRESHOLD_HIGH:
		return COLOR_HIGH
	else:
		return COLOR_FULL

# endregion

# =============================================================================
# region -- Public API
# =============================================================================

## Set fuel level (triggers animation).
func set_fuel(value: float) -> void:
	fuel_level = value


## Trigger boost flash effect.
func flash_boost() -> void:
	_is_flashing = true
	_flash_timer = FLASH_DURATION
	_boost_triggered = true
	queue_redraw()


## Set whether boost is available.
func set_boost_available(available: bool) -> void:
	boost_available = available
	queue_redraw()


## Set unlimited fuel state.
func set_unlimited(is_unlimited: bool) -> void:
	unlimited_fuel = is_unlimited


## Connect to a JetpackController for automatic updates.
func connect_to_jetpack(jetpack: JetpackController) -> void:
	if jetpack:
		jetpack.fuel_changed.connect(_on_fuel_changed)
		jetpack.boost_triggered.connect(_on_boost_triggered)
		jetpack.unlimited_fuel_changed.connect(_on_unlimited_fuel_changed)


## Disconnect from a JetpackController.
func disconnect_from_jetpack(jetpack: JetpackController) -> void:
	if jetpack:
		if jetpack.fuel_changed.is_connected(_on_fuel_changed):
			jetpack.fuel_changed.disconnect(_on_fuel_changed)
		if jetpack.boost_triggered.is_connected(_on_boost_triggered):
			jetpack.boost_triggered.disconnect(_on_boost_triggered)
		if jetpack.unlimited_fuel_changed.is_connected(_on_unlimited_fuel_changed):
			jetpack.unlimited_fuel_changed.disconnect(_on_unlimited_fuel_changed)

# endregion

# =============================================================================
# region -- Signal Handlers
# =============================================================================

func _on_fuel_changed(fuel_normalized: float) -> void:
	fuel_level = fuel_normalized


func _on_boost_triggered() -> void:
	flash_boost()


func _on_unlimited_fuel_changed(is_unlimited: bool) -> void:
	unlimited_fuel = is_unlimited

# endregion
