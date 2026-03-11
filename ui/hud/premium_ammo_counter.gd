## Premium competitive-grade ammo counter system.
## Features digital flip animations, circular reload progress indicator,
## magazine visualization with individual bullet icons, low ammo warnings,
## and smooth count-down animations. Designed for PUBG/CoD Mobile quality.
class_name PremiumAmmoCounter
extends Control

## Signal emitted when ammo reaches zero.
signal ammo_depleted
## Signal emitted when reload completes.
signal reload_completed
## Signal emitted when ammo changes.
signal ammo_changed(current: int, max_ammo: int)

## Current ammo in magazine.
var current_ammo: int = 30:
	set(value):
		var old_ammo: int = current_ammo
		current_ammo = maxi(value, 0)
		_on_ammo_changed(old_ammo, current_ammo)
		if current_ammo == 0:
			ammo_depleted.emit()

## Maximum ammo in magazine.
var max_ammo: int = 30:
	set(value):
		max_ammo = maxi(value, 1)
		_rebuild_bullet_display()
		queue_redraw()

## Reserve ammo.
var reserve_ammo: int = 120:
	set(value):
		reserve_ammo = maxi(value, 0)
		queue_redraw()

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

# ── Animation State ──────────────────────────────────────────────────────────

## Display values for flip animation.
var _display_ammo: float = 30.0
var _display_reserve: float = 120.0

## Flip animation state per digit.
var _digit_flips: Array[Dictionary] = []

## Low ammo pulse phase.
var _low_ammo_pulse: float = 0.0

## Reload ring pulse phase.
var _reload_pulse: float = 0.0

## Ammo change scale animation.
var _ammo_scale: float = 1.0

## Fire flash effect.
var _fire_flash: float = 0.0

## Individual bullet states for magazine visualization.
var _bullet_states: Array[Dictionary] = []

## Tween references.
var _ammo_tween: Tween = null
var _flip_tween: Tween = null

# ── Layout Constants ─────────────────────────────────────────────────────────

const DISPLAY_WIDTH: float = 160.0
const DISPLAY_HEIGHT: float = 80.0
const DIGIT_WIDTH: float = 28.0
const DIGIT_HEIGHT: float = 42.0
const DIGIT_SPACING: float = 2.0
const RELOAD_RING_RADIUS: float = 35.0
const RELOAD_RING_WIDTH: float = 4.0
const BULLET_WIDTH: float = 4.0
const BULLET_HEIGHT: float = 12.0
const BULLET_SPACING: float = 2.0
const MAX_VISIBLE_BULLETS: int = 15

# ── Premium Color Palette ────────────────────────────────────────────────────

## Background colors.
const BG_COLOR: Color = Color(0.06, 0.06, 0.1, 0.85)
const BG_INNER_COLOR: Color = Color(0.04, 0.04, 0.08, 0.9)
const BORDER_COLOR: Color = Color(0.2, 0.2, 0.25, 0.9)
const BORDER_HIGHLIGHT: Color = Color(0.35, 0.35, 0.4, 0.4)

## Digit colors.
const DIGIT_BG_COLOR: Color = Color(0.02, 0.02, 0.05, 0.95)
const DIGIT_COLOR_NORMAL: Color = Color(1.0, 1.0, 1.0, 1.0)
const DIGIT_COLOR_LOW: Color = Color(1.0, 0.4, 0.2, 1.0)
const DIGIT_COLOR_CRITICAL: Color = Color(1.0, 0.2, 0.15, 1.0)
const DIGIT_GLOW_COLOR: Color = Color(0.3, 0.8, 1.0, 0.4)

## Reserve ammo colors.
const RESERVE_COLOR: Color = Color(0.65, 0.65, 0.7, 0.9)
const RESERVE_LOW_COLOR: Color = Color(1.0, 0.6, 0.3, 0.9)

## Reload indicator colors.
const RELOAD_BG_COLOR: Color = Color(0.15, 0.15, 0.2, 0.7)
const RELOAD_PROGRESS_COLOR: Color = Color(0.2, 0.85, 1.0, 0.95)
const RELOAD_GLOW_COLOR: Color = Color(0.3, 0.9, 1.0, 0.5)
const RELOAD_TEXT_COLOR: Color = Color(0.3, 0.9, 1.0, 1.0)

## Bullet visualization colors.
const BULLET_LOADED_COLOR: Color = Color(0.95, 0.85, 0.3, 1.0)
const BULLET_EMPTY_COLOR: Color = Color(0.25, 0.25, 0.3, 0.5)
const BULLET_FIRING_COLOR: Color = Color(1.0, 0.5, 0.2, 1.0)

## Effect colors.
const FIRE_FLASH_COLOR: Color = Color(1.0, 0.6, 0.2, 0.6)
const LOW_AMMO_PULSE_COLOR: Color = Color(1.0, 0.3, 0.2, 0.3)

## Infinite ammo color.
const INFINITE_COLOR: Color = Color(0.7, 0.9, 1.0, 0.95)

# ── Thresholds ───────────────────────────────────────────────────────────────

const LOW_AMMO_THRESHOLD: float = 0.3
const CRITICAL_AMMO_THRESHOLD: float = 0.15
const LOW_RESERVE_THRESHOLD: int = 30

# ── Timing Constants ─────────────────────────────────────────────────────────

const DIGIT_LERP_SPEED: float = 15.0
const FLIP_DURATION: float = 0.12
const SCALE_BOUNCE_DURATION: float = 0.15
const FIRE_FLASH_DECAY: float = 8.0
const LOW_AMMO_PULSE_SPEED: float = 5.0
const RELOAD_PULSE_SPEED: float = 4.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(DISPLAY_WIDTH, DISPLAY_HEIGHT + 30)

	_display_ammo = float(current_ammo)
	_display_reserve = float(reserve_ammo)

	_rebuild_bullet_display()


func _process(delta: float) -> void:
	var needs_redraw: bool = false

	# Update digit display with smooth interpolation.
	if absf(_display_ammo - float(current_ammo)) > 0.01:
		_display_ammo = lerpf(_display_ammo, float(current_ammo), DIGIT_LERP_SPEED * delta)
		needs_redraw = true

	if absf(_display_reserve - float(reserve_ammo)) > 0.01:
		_display_reserve = lerpf(_display_reserve, float(reserve_ammo), DIGIT_LERP_SPEED * delta)
		needs_redraw = true

	# Update low ammo pulse.
	if _is_low_ammo() and not _is_reloading:
		_low_ammo_pulse = fmod(_low_ammo_pulse + LOW_AMMO_PULSE_SPEED * delta, TAU)
		needs_redraw = true
	else:
		_low_ammo_pulse = 0.0

	# Update reload pulse.
	if _is_reloading:
		_reload_pulse = fmod(_reload_pulse + RELOAD_PULSE_SPEED * delta, TAU)
		needs_redraw = true

	# Decay fire flash.
	if _fire_flash > 0.0:
		_fire_flash = maxf(_fire_flash - FIRE_FLASH_DECAY * delta, 0.0)
		needs_redraw = true

	# Update bullet animations.
	for bullet: Dictionary in _bullet_states:
		if bullet.has("animating") and bullet["animating"] as bool:
			bullet["anim_progress"] = (bullet["anim_progress"] as float) + delta * 8.0
			if (bullet["anim_progress"] as float) >= 1.0:
				bullet["animating"] = false
				bullet["anim_progress"] = 1.0
			needs_redraw = true

	if needs_redraw or _is_reloading:
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5

	if _is_reloading:
		_draw_reload_display(center)
	else:
		_draw_ammo_display(center)


## Draw the main ammo counter display.
func _draw_ammo_display(center: Vector2) -> void:
	var display_rect: Rect2 = Rect2(
		center - Vector2(DISPLAY_WIDTH * 0.5, DISPLAY_HEIGHT * 0.5 + 10),
		Vector2(DISPLAY_WIDTH, DISPLAY_HEIGHT)
	)

	# Draw background panel.
	_draw_display_background(display_rect)

	# Draw ammo digits.
	var digits_y: float = display_rect.position.y + 12

	if infinite_ammo:
		_draw_infinite_symbol(Vector2(display_rect.position.x + display_rect.size.x * 0.5, digits_y + DIGIT_HEIGHT * 0.5))
	else:
		_draw_ammo_digits(Vector2(display_rect.position.x + 15, digits_y))

		# Draw reserve ammo.
		if show_reserve:
			_draw_reserve_ammo(Vector2(display_rect.position.x + display_rect.size.x - 15, digits_y + DIGIT_HEIGHT * 0.5))

	# Draw bullet magazine visualization.
	if not infinite_ammo and max_ammo <= MAX_VISIBLE_BULLETS:
		_draw_bullet_magazine(Vector2(center.x, display_rect.position.y + display_rect.size.y - 8))

	# Draw low ammo pulse overlay.
	if _is_low_ammo() and not infinite_ammo:
		var pulse: float = (sin(_low_ammo_pulse) + 1.0) * 0.5
		var pulse_color: Color = LOW_AMMO_PULSE_COLOR
		pulse_color.a *= pulse
		draw_rect(display_rect, pulse_color)

	# Draw fire flash.
	if _fire_flash > 0.0:
		var flash_color: Color = FIRE_FLASH_COLOR
		flash_color.a *= _fire_flash
		draw_rect(display_rect, flash_color)


## Draw display background with premium styling.
func _draw_display_background(rect: Rect2) -> void:
	# Outer background.
	draw_rect(rect, BG_COLOR)

	# Inner darker area.
	var inner: Rect2 = rect.grow(-3)
	draw_rect(inner, BG_INNER_COLOR)

	# Border.
	draw_rect(rect, BORDER_COLOR, false, 2.0)

	# Top highlight.
	var highlight: Rect2 = Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6, 1))
	draw_rect(highlight, BORDER_HIGHLIGHT)


## Draw ammo digits with flip animation effect.
func _draw_ammo_digits(pos: Vector2) -> void:
	var ammo_str: String = "%02d" % int(round(_display_ammo))
	var digit_color: Color = _get_digit_color()

	# Apply scale animation.
	var scale: float = _ammo_scale

	for i: int in range(ammo_str.length()):
		var digit_x: float = pos.x + i * (DIGIT_WIDTH + DIGIT_SPACING)
		var digit_rect: Rect2 = Rect2(Vector2(digit_x, pos.y), Vector2(DIGIT_WIDTH, DIGIT_HEIGHT))

		# Scale from center.
		if scale != 1.0:
			var center: Vector2 = digit_rect.get_center()
			digit_rect.position = center - digit_rect.size * scale * 0.5
			digit_rect.size *= scale

		# Draw digit background.
		draw_rect(digit_rect, DIGIT_BG_COLOR)

		# Draw digit.
		var font: Font = ThemeDB.fallback_font
		var digit_text: String = ammo_str[i]
		var font_size: int = int(28 * scale)
		var text_size: Vector2 = font.get_string_size(digit_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = Vector2(
			digit_rect.get_center().x - text_size.x * 0.5,
			digit_rect.get_center().y + text_size.y * 0.35
		)

		# Draw shadow.
		draw_string(font, text_pos + Vector2(1, 1), digit_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.8))

		# Draw main digit.
		draw_string(font, text_pos, digit_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, digit_color)

		# Draw glow for emphasis.
		if _is_critical_ammo():
			var pulse: float = (sin(_low_ammo_pulse * 2.0) + 1.0) * 0.5
			var glow_color: Color = digit_color
			glow_color.a = pulse * 0.3
			draw_rect(digit_rect.grow(2), glow_color)

		# Draw border.
		draw_rect(digit_rect, BORDER_COLOR, false, 1.0)


## Draw reserve ammo count.
func _draw_reserve_ammo(pos: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var reserve_text: String = "/ %d" % int(round(_display_reserve))

	var color: Color = RESERVE_COLOR
	if reserve_ammo < LOW_RESERVE_THRESHOLD:
		color = RESERVE_LOW_COLOR

	var text_size: Vector2 = font.get_string_size(reserve_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 16)
	var text_pos: Vector2 = Vector2(pos.x - text_size.x, pos.y + text_size.y * 0.35)

	# Shadow.
	draw_string(font, text_pos + Vector2(1, 1), reserve_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, Color(0, 0, 0, 0.6))
	# Main text.
	draw_string(font, text_pos, reserve_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, color)


## Draw infinite ammo symbol.
func _draw_infinite_symbol(center: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var inf_text: String = "INF"

	var text_size: Vector2 = font.get_string_size(inf_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	var text_pos: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)

	# Glow effect.
	var glow_color: Color = INFINITE_COLOR
	glow_color.a = 0.3
	draw_string(font, text_pos + Vector2(-1, -1), inf_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 34, glow_color)
	draw_string(font, text_pos + Vector2(1, 1), inf_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 34, glow_color)

	# Main text.
	draw_string(font, text_pos, inf_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 32, INFINITE_COLOR)


## Draw bullet magazine visualization.
func _draw_bullet_magazine(center: Vector2) -> void:
	var bullet_count: int = mini(max_ammo, MAX_VISIBLE_BULLETS)
	var total_width: float = bullet_count * (BULLET_WIDTH + BULLET_SPACING) - BULLET_SPACING
	var start_x: float = center.x - total_width * 0.5

	for i: int in range(bullet_count):
		var x: float = start_x + i * (BULLET_WIDTH + BULLET_SPACING)
		var bullet_rect: Rect2 = Rect2(Vector2(x, center.y - BULLET_HEIGHT * 0.5), Vector2(BULLET_WIDTH, BULLET_HEIGHT))

		var is_loaded: bool = i < current_ammo
		var color: Color = BULLET_LOADED_COLOR if is_loaded else BULLET_EMPTY_COLOR

		# Check for animation state.
		if i < _bullet_states.size():
			var state: Dictionary = _bullet_states[i]
			if state.get("animating", false) as bool:
				var progress: float = state.get("anim_progress", 1.0) as float
				if state.get("is_firing", false) as bool:
					# Firing animation: flash orange then disappear.
					color = BULLET_FIRING_COLOR.lerp(BULLET_EMPTY_COLOR, progress)
					bullet_rect.position.y -= (1.0 - progress) * 3.0
				else:
					# Reload animation: pop in from bottom.
					color.a *= progress
					bullet_rect.position.y += (1.0 - progress) * 5.0

		# Draw bullet.
		draw_rect(bullet_rect, color)

		# Draw casing line at top for loaded bullets.
		if is_loaded or (i < _bullet_states.size() and _bullet_states[i].get("animating", false) as bool):
			var casing_rect: Rect2 = Rect2(bullet_rect.position, Vector2(BULLET_WIDTH, 2))
			var casing_color: Color = color.darkened(0.3)
			draw_rect(casing_rect, casing_color)


## Draw reload display with circular progress.
func _draw_reload_display(center: Vector2) -> void:
	# Background circle.
	var bg_color: Color = RELOAD_BG_COLOR
	draw_circle(center, RELOAD_RING_RADIUS + 10, bg_color)

	# Progress ring background.
	draw_arc(center, RELOAD_RING_RADIUS, 0.0, TAU, 64, Color(0.15, 0.15, 0.2, 0.5), RELOAD_RING_WIDTH + 2)

	# Progress ring fill.
	var progress_angle: float = _reload_progress * TAU
	var start_angle: float = -PI * 0.5  # Start from top.

	if progress_angle > 0.001:
		# Draw progress arc.
		draw_arc(center, RELOAD_RING_RADIUS, start_angle, start_angle + progress_angle, 64, RELOAD_PROGRESS_COLOR, RELOAD_RING_WIDTH)

		# Draw glow at progress tip.
		var tip_angle: float = start_angle + progress_angle
		var tip_pos: Vector2 = center + Vector2(cos(tip_angle), sin(tip_angle)) * RELOAD_RING_RADIUS
		var glow_size: float = RELOAD_RING_WIDTH * 2.0
		var pulse: float = (sin(_reload_pulse) + 1.0) * 0.5
		var glow_color: Color = RELOAD_GLOW_COLOR
		glow_color.a = 0.4 + pulse * 0.3
		draw_circle(tip_pos, glow_size, glow_color)

	# Draw center text.
	var font: Font = ThemeDB.fallback_font
	var percent_text: String = "%d%%" % int(_reload_progress * 100)
	var text_size: Vector2 = font.get_string_size(percent_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	var text_pos: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35 - 5)

	draw_string(font, text_pos, percent_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, RELOAD_TEXT_COLOR)

	# Draw "RELOADING" label.
	var reload_text: String = "RELOADING"
	var label_size: Vector2 = font.get_string_size(reload_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	var label_pos: Vector2 = Vector2(center.x - label_size.x * 0.5, center.y + 20)

	draw_string(font, label_pos, reload_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.6, 0.6, 0.65, 0.9))


## Get digit color based on ammo state.
func _get_digit_color() -> Color:
	if _is_critical_ammo():
		return DIGIT_COLOR_CRITICAL
	elif _is_low_ammo():
		return DIGIT_COLOR_LOW
	return DIGIT_COLOR_NORMAL


## Check if ammo is low.
func _is_low_ammo() -> bool:
	if max_ammo == 0:
		return false
	return float(current_ammo) / float(max_ammo) <= LOW_AMMO_THRESHOLD


## Check if ammo is critical.
func _is_critical_ammo() -> bool:
	if max_ammo == 0:
		return false
	return float(current_ammo) / float(max_ammo) <= CRITICAL_AMMO_THRESHOLD


## Handle ammo change.
func _on_ammo_changed(old_ammo: int, new_ammo: int) -> void:
	ammo_changed.emit(new_ammo, max_ammo)

	if new_ammo < old_ammo:
		# Ammo consumed (firing).
		_trigger_fire_animation(old_ammo - new_ammo)
	elif new_ammo > old_ammo:
		# Ammo added (reload).
		_trigger_reload_animation(old_ammo, new_ammo)

	queue_redraw()


## Trigger fire animation.
func _trigger_fire_animation(shots: int) -> void:
	_fire_flash = 0.6

	# Animate scale bounce.
	if _ammo_tween and _ammo_tween.is_valid():
		_ammo_tween.kill()

	_ammo_scale = 1.1
	_ammo_tween = create_tween()
	_ammo_tween.tween_property(self, "_ammo_scale", 1.0, SCALE_BOUNCE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Animate bullets being consumed.
	for i: int in range(current_ammo, current_ammo + shots):
		if i < _bullet_states.size():
			_bullet_states[i]["animating"] = true
			_bullet_states[i]["anim_progress"] = 0.0
			_bullet_states[i]["is_firing"] = true


## Trigger reload fill animation.
func _trigger_reload_animation(old_ammo: int, new_ammo: int) -> void:
	# Animate bullets being loaded.
	for i: int in range(old_ammo, new_ammo):
		if i < _bullet_states.size():
			_bullet_states[i]["animating"] = true
			_bullet_states[i]["anim_progress"] = 0.0
			_bullet_states[i]["is_firing"] = false


## Rebuild bullet display array.
func _rebuild_bullet_display() -> void:
	_bullet_states.clear()
	for i: int in range(max_ammo):
		_bullet_states.append({
			"animating": false,
			"anim_progress": 1.0,
			"is_firing": false,
		})


# ── Public API ───────────────────────────────────────────────────────────────

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
func start_reload(duration: float) -> void:
	if _is_reloading:
		return

	_is_reloading = true
	_reload_progress = 0.0
	_reload_pulse = 0.0

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


## Finish reload and refill ammo.
func _finish_reload() -> void:
	_is_reloading = false
	_reload_progress = 0.0

	if not infinite_ammo:
		var needed: int = max_ammo - current_ammo
		var available: int = mini(needed, reserve_ammo)
		reserve_ammo -= available
		current_ammo += available

	reload_completed.emit()
	queue_redraw()


## Check if currently reloading.
func is_reloading() -> bool:
	return _is_reloading


## Set infinite ammo mode.
func set_infinite_ammo(enabled: bool) -> void:
	infinite_ammo = enabled
	queue_redraw()


## Full refill.
func refill_all(max_reserve: int = -1) -> void:
	current_ammo = max_ammo
	if max_reserve >= 0:
		reserve_ammo = max_reserve
	queue_redraw()


## Get reload progress (0.0 to 1.0).
func get_reload_progress() -> float:
	return _reload_progress
