## Animated ammo counter with reload progress indicator.
## Displays current ammo, reserve ammo, and reload animation.
class_name AmmoCounter
extends Control

## Signal emitted when ammo reaches zero.
signal ammo_depleted

## Current ammo in magazine.
var current_ammo: int = 12:
	set(value):
		current_ammo = maxi(value, 0)
		_update_display()
		if current_ammo == 0:
			ammo_depleted.emit()

## Maximum ammo in magazine.
var max_ammo: int = 12:
	set(value):
		max_ammo = maxi(value, 1)
		_update_display()

## Reserve ammo (optional).
var reserve_ammo: int = 36:
	set(value):
		reserve_ammo = maxi(value, 0)
		_update_display()

## Whether to show reserve ammo.
var show_reserve: bool = true

## Whether infinite ammo mode is active.
var infinite_ammo: bool = false

## Reload progress (0.0 to 1.0).
var _reload_progress: float = 0.0

## Whether currently reloading.
var _is_reloading: bool = false

## Reload tween reference.
var _reload_tween: Tween = null

## Animation tween for ammo change.
var _ammo_tween: Tween = null

## Visual state.
var _display_scale: float = 1.0
var _low_ammo_flash: float = 0.0

## Low ammo threshold (percentage).
const LOW_AMMO_THRESHOLD: float = 0.25

## Colors.
const NORMAL_COLOR: Color = Color.WHITE
const LOW_AMMO_COLOR: Color = Color(1.0, 0.4, 0.2, 1.0)
const RELOAD_BAR_BG_COLOR: Color = Color(0.2, 0.2, 0.2, 0.8)
const RELOAD_BAR_FILL_COLOR: Color = Color(0.3, 0.8, 1.0, 0.9)
const INFINITE_COLOR: Color = Color(0.8, 0.9, 1.0, 0.9)

## Layout constants.
const AMMO_FONT_SIZE: int = 32
const RESERVE_FONT_SIZE: int = 18
const RELOAD_BAR_HEIGHT: float = 4.0
const RELOAD_BAR_WIDTH: float = 80.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 60)


func _process(delta: float) -> void:
	# Update low ammo flash.
	if _is_low_ammo() and not _is_reloading:
		_low_ammo_flash = fmod(_low_ammo_flash + delta * 4.0, TAU)
	else:
		_low_ammo_flash = 0.0

	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var center_x: float = size.x * 0.5

	# Calculate colors.
	var ammo_color: Color = _get_ammo_color()

	if _is_reloading:
		# Draw reload bar.
		_draw_reload_bar(Vector2(center_x, size.y * 0.5))

		# Draw "RELOADING" text.
		var reload_text: String = "RELOADING"
		var reload_size: Vector2 = font.get_string_size(reload_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		var reload_pos: Vector2 = Vector2(center_x - reload_size.x * 0.5, size.y * 0.3)
		draw_string(font, reload_pos, reload_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, RELOAD_BAR_FILL_COLOR)
	else:
		# Draw ammo count.
		_draw_ammo_count(font, center_x, ammo_color)


## Draw the main ammo count display.
func _draw_ammo_count(font: Font, center_x: float, color: Color) -> void:
	var ammo_text: String
	var reserve_text: String = ""

	if infinite_ammo:
		ammo_text = "INF"
		color = INFINITE_COLOR
	else:
		ammo_text = str(current_ammo)
		if show_reserve:
			reserve_text = "/ %d" % reserve_ammo

	# Calculate positions.
	var ammo_size: Vector2 = font.get_string_size(ammo_text, HORIZONTAL_ALIGNMENT_CENTER, -1, AMMO_FONT_SIZE)

	# Apply scale animation.
	var scaled_size: int = int(float(AMMO_FONT_SIZE) * _display_scale)

	# Draw shadow.
	var shadow_offset: Vector2 = Vector2(2, 2)
	var shadow_color: Color = Color(0, 0, 0, 0.6)

	# Main ammo count.
	var ammo_pos: Vector2 = Vector2(center_x - ammo_size.x * 0.5 * _display_scale, size.y * 0.6)
	draw_string(font, ammo_pos + shadow_offset, ammo_text, HORIZONTAL_ALIGNMENT_CENTER, -1, scaled_size, shadow_color)
	draw_string(font, ammo_pos, ammo_text, HORIZONTAL_ALIGNMENT_CENTER, -1, scaled_size, color)

	# Reserve ammo (smaller, to the right).
	if show_reserve and reserve_text != "":
		var reserve_size: Vector2 = font.get_string_size(reserve_text, HORIZONTAL_ALIGNMENT_CENTER, -1, RESERVE_FONT_SIZE)
		var reserve_pos: Vector2 = Vector2(center_x + ammo_size.x * 0.5 * _display_scale + 4, size.y * 0.55)

		var reserve_color: Color = Color(0.7, 0.7, 0.7, 0.9)
		draw_string(font, reserve_pos + shadow_offset * 0.5, reserve_text, HORIZONTAL_ALIGNMENT_LEFT, -1, RESERVE_FONT_SIZE, shadow_color)
		draw_string(font, reserve_pos, reserve_text, HORIZONTAL_ALIGNMENT_LEFT, -1, RESERVE_FONT_SIZE, reserve_color)

	# Draw bullet icons (optional visual).
	if not infinite_ammo and max_ammo <= 8:
		_draw_bullet_icons(center_x, size.y * 0.8, color)


## Draw individual bullet icons for low-capacity weapons.
func _draw_bullet_icons(center_x: float, y_pos: float, color: Color) -> void:
	var bullet_width: float = 6.0
	var bullet_height: float = 12.0
	var spacing: float = 3.0
	var total_width: float = max_ammo * (bullet_width + spacing) - spacing
	var start_x: float = center_x - total_width * 0.5

	for i: int in range(max_ammo):
		var x: float = start_x + i * (bullet_width + spacing)
		var rect: Rect2 = Rect2(x, y_pos - bullet_height * 0.5, bullet_width, bullet_height)

		if i < current_ammo:
			# Filled bullet.
			draw_rect(rect, color)
		else:
			# Empty bullet outline.
			var empty_color: Color = color
			empty_color.a = 0.3
			draw_rect(rect, empty_color, false, 1.0)


## Draw the reload progress bar.
func _draw_reload_bar(center: Vector2) -> void:
	var bar_rect: Rect2 = Rect2(
		center.x - RELOAD_BAR_WIDTH * 0.5,
		center.y - RELOAD_BAR_HEIGHT * 0.5,
		RELOAD_BAR_WIDTH,
		RELOAD_BAR_HEIGHT
	)

	# Background.
	draw_rect(bar_rect, RELOAD_BAR_BG_COLOR)

	# Fill.
	var fill_rect: Rect2 = bar_rect
	fill_rect.size.x *= _reload_progress
	draw_rect(fill_rect, RELOAD_BAR_FILL_COLOR)

	# Border.
	draw_rect(bar_rect, Color(0.5, 0.5, 0.5, 0.5), false, 1.0)


## Get the color for the ammo display.
func _get_ammo_color() -> Color:
	if infinite_ammo:
		return INFINITE_COLOR

	if _is_low_ammo():
		var flash: float = (sin(_low_ammo_flash) + 1.0) * 0.5
		return NORMAL_COLOR.lerp(LOW_AMMO_COLOR, 0.5 + flash * 0.5)

	return NORMAL_COLOR


## Check if ammo is low.
func _is_low_ammo() -> bool:
	if max_ammo == 0:
		return false
	return float(current_ammo) / float(max_ammo) <= LOW_AMMO_THRESHOLD


## Update display with animation.
func _update_display() -> void:
	# Animate scale on ammo change.
	if _ammo_tween and _ammo_tween.is_valid():
		_ammo_tween.kill()

	_display_scale = 1.15
	_ammo_tween = create_tween()
	_ammo_tween.tween_property(self, "_display_scale", 1.0, 0.15).set_ease(Tween.EASE_OUT)

	queue_redraw()


## Set ammo values.
func set_ammo(current: int, maximum: int, reserve: int = -1) -> void:
	max_ammo = maximum
	current_ammo = current
	if reserve >= 0:
		reserve_ammo = reserve


## Consume ammo (returns true if successful).
func consume(amount: int = 1) -> bool:
	if infinite_ammo:
		return true

	if current_ammo >= amount:
		current_ammo -= amount
		return true

	return false


## Start reload animation.
## [param duration] Total reload time in seconds.
func start_reload(duration: float) -> void:
	if _is_reloading:
		return

	_is_reloading = true
	_reload_progress = 0.0

	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()

	_reload_tween = create_tween()
	_reload_tween.tween_property(self, "_reload_progress", 1.0, duration)
	_reload_tween.tween_callback(_finish_reload)


## Cancel reload.
func cancel_reload() -> void:
	if not _is_reloading:
		return

	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()

	_is_reloading = false
	_reload_progress = 0.0
	queue_redraw()


## Internal: Finish reload and refill ammo.
func _finish_reload() -> void:
	_is_reloading = false
	_reload_progress = 0.0

	if not infinite_ammo:
		var needed: int = max_ammo - current_ammo
		var available: int = mini(needed, reserve_ammo)
		reserve_ammo -= available
		current_ammo += available

	queue_redraw()


## Check if currently reloading.
func is_reloading() -> bool:
	return _is_reloading


## Set infinite ammo mode.
func set_infinite_ammo(enabled: bool) -> void:
	infinite_ammo = enabled
	queue_redraw()


## Full refill (max ammo and reserve).
func refill_all(max_reserve: int = -1) -> void:
	current_ammo = max_ammo
	if max_reserve >= 0:
		reserve_ammo = max_reserve
	queue_redraw()
