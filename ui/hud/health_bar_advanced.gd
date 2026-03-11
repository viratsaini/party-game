## Advanced health bar with damage flash, smooth animations, and visual effects.
## Supports health segments, damage preview, and healing effects.
class_name HealthBarAdvanced
extends Control

## Signal emitted when health reaches zero.
signal health_depleted

## Signal emitted when health changes.
signal health_changed(new_health: float, max_health: float)

## Current health value.
var current_health: float = 100.0:
	set(value):
		var old_health: float = current_health
		current_health = clampf(value, 0.0, max_health)
		_on_health_changed(old_health, current_health)

## Maximum health value.
var max_health: float = 100.0:
	set(value):
		max_health = maxf(value, 1.0)
		queue_redraw()

## Shield/armor amount (displayed as extension to health bar).
var shield: float = 0.0:
	set(value):
		shield = maxf(value, 0.0)
		queue_redraw()

## Maximum shield value.
var max_shield: float = 50.0

## Delayed health (for damage preview effect).
var _delayed_health: float = 100.0

## Damage flash intensity.
var _damage_flash: float = 0.0

## Healing flash intensity.
var _heal_flash: float = 0.0

## Low health pulse.
var _low_health_pulse: float = 0.0

## Tweens.
var _damage_tween: Tween = null
var _heal_tween: Tween = null

## Layout constants.
const BAR_HEIGHT: float = 16.0
const BAR_WIDTH: float = 200.0
const CORNER_RADIUS: float = 4.0
const BORDER_WIDTH: float = 2.0
const SEGMENT_COUNT: int = 10  ## Number of health segments.

## Colors.
const BACKGROUND_COLOR: Color = Color(0.1, 0.1, 0.1, 0.8)
const BORDER_COLOR: Color = Color(0.3, 0.3, 0.3, 0.9)
const HEALTH_COLOR_HIGH: Color = Color(0.2, 0.85, 0.3, 1.0)
const HEALTH_COLOR_MED: Color = Color(0.95, 0.8, 0.2, 1.0)
const HEALTH_COLOR_LOW: Color = Color(0.95, 0.25, 0.2, 1.0)
const DAMAGE_PREVIEW_COLOR: Color = Color(1.0, 0.3, 0.2, 0.6)
const SHIELD_COLOR: Color = Color(0.3, 0.7, 1.0, 0.9)
const DAMAGE_FLASH_COLOR: Color = Color(1.0, 0.2, 0.1, 0.8)
const HEAL_FLASH_COLOR: Color = Color(0.3, 1.0, 0.4, 0.6)
const SEGMENT_LINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.3)

## Low health threshold (percentage).
const LOW_HEALTH_THRESHOLD: float = 0.25


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT + 20)
	_delayed_health = current_health


func _process(delta: float) -> void:
	# Smooth delayed health catch-up.
	if absf(_delayed_health - current_health) > 0.1:
		_delayed_health = lerpf(_delayed_health, current_health, delta * 3.0)
		queue_redraw()

	# Update low health pulse.
	if _is_low_health():
		_low_health_pulse = fmod(_low_health_pulse + delta * 3.0, TAU)
		queue_redraw()

	# Decay flash effects.
	if _damage_flash > 0.0:
		_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
		queue_redraw()

	if _heal_flash > 0.0:
		_heal_flash = maxf(_heal_flash - delta * 3.0, 0.0)
		queue_redraw()


func _draw() -> void:
	var bar_rect: Rect2 = Rect2(0, 10, BAR_WIDTH, BAR_HEIGHT)

	# Draw background.
	_draw_rounded_rect(bar_rect, BACKGROUND_COLOR)

	# Draw damage preview (delayed health).
	if _delayed_health > current_health:
		var preview_width: float = (_delayed_health / max_health) * BAR_WIDTH
		var preview_rect: Rect2 = Rect2(0, 10, preview_width, BAR_HEIGHT)
		_draw_rounded_rect(preview_rect, DAMAGE_PREVIEW_COLOR)

	# Draw health fill.
	var health_percent: float = current_health / max_health
	var health_width: float = health_percent * BAR_WIDTH
	var health_rect: Rect2 = Rect2(0, 10, health_width, BAR_HEIGHT)
	var health_color: Color = _get_health_color(health_percent)

	# Apply pulse for low health.
	if _is_low_health():
		var pulse: float = (sin(_low_health_pulse) + 1.0) * 0.5
		health_color = health_color.lerp(Color.WHITE, pulse * 0.2)

	_draw_rounded_rect(health_rect, health_color)

	# Draw shield bar (above health).
	if shield > 0.0:
		var shield_percent: float = minf(shield / max_shield, 1.0)
		var shield_width: float = shield_percent * BAR_WIDTH
		var shield_rect: Rect2 = Rect2(0, 6, shield_width, 4)
		_draw_rounded_rect(shield_rect, SHIELD_COLOR)

	# Draw segment lines.
	_draw_segments(bar_rect)

	# Draw border.
	_draw_rounded_rect_outline(bar_rect, BORDER_COLOR)

	# Draw flash effects.
	if _damage_flash > 0.0:
		var flash_color: Color = DAMAGE_FLASH_COLOR
		flash_color.a = _damage_flash
		_draw_rounded_rect(bar_rect, flash_color)

	if _heal_flash > 0.0:
		var flash_color: Color = HEAL_FLASH_COLOR
		flash_color.a = _heal_flash
		_draw_rounded_rect(bar_rect, flash_color)

	# Draw health text.
	_draw_health_text(bar_rect)


## Draw rounded rectangle.
func _draw_rounded_rect(rect: Rect2, color: Color) -> void:
	# Simple rectangle for performance (rounded corners would need more complex drawing).
	draw_rect(rect, color)


## Draw rounded rectangle outline.
func _draw_rounded_rect_outline(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color, false, BORDER_WIDTH)


## Draw segment lines on the health bar.
func _draw_segments(bar_rect: Rect2) -> void:
	var segment_width: float = bar_rect.size.x / float(SEGMENT_COUNT)

	for i: int in range(1, SEGMENT_COUNT):
		var x: float = bar_rect.position.x + i * segment_width
		draw_line(
			Vector2(x, bar_rect.position.y),
			Vector2(x, bar_rect.position.y + bar_rect.size.y),
			SEGMENT_LINE_COLOR,
			1.0
		)


## Draw health text overlay.
func _draw_health_text(bar_rect: Rect2) -> void:
	var font: Font = ThemeDB.fallback_font
	var health_text: String = "%d / %d" % [int(current_health), int(max_health)]

	var text_size: Vector2 = font.get_string_size(health_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	var text_pos: Vector2 = Vector2(
		bar_rect.position.x + bar_rect.size.x * 0.5 - text_size.x * 0.5,
		bar_rect.position.y + bar_rect.size.y * 0.5 + text_size.y * 0.25
	)

	# Shadow.
	draw_string(font, text_pos + Vector2(1, 1), health_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0, 0, 0, 0.7))
	# Text.
	draw_string(font, text_pos, health_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)


## Get health color based on percentage.
func _get_health_color(percent: float) -> Color:
	if percent > 0.6:
		return HEALTH_COLOR_HIGH
	elif percent > 0.25:
		var t: float = (percent - 0.25) / 0.35
		return HEALTH_COLOR_LOW.lerp(HEALTH_COLOR_MED, t)
	else:
		return HEALTH_COLOR_LOW


## Check if health is low.
func _is_low_health() -> bool:
	return (current_health / max_health) <= LOW_HEALTH_THRESHOLD


## Handle health change.
func _on_health_changed(old_health: float, new_health: float) -> void:
	health_changed.emit(new_health, max_health)

	if new_health < old_health:
		# Damage taken.
		_trigger_damage_flash()
	elif new_health > old_health:
		# Health gained.
		_trigger_heal_flash()

	if new_health <= 0.0:
		health_depleted.emit()

	queue_redraw()


## Trigger damage flash effect.
func _trigger_damage_flash() -> void:
	_damage_flash = 1.0

	if _damage_tween and _damage_tween.is_valid():
		_damage_tween.kill()


## Trigger heal flash effect.
func _trigger_heal_flash() -> void:
	_heal_flash = 0.8
	_delayed_health = current_health  # No delay for healing.

	if _heal_tween and _heal_tween.is_valid():
		_heal_tween.kill()


## Set health values.
func set_health(current: float, maximum: float) -> void:
	max_health = maximum
	current_health = current


## Set shield values.
func set_shield(current: float, maximum: float = -1.0) -> void:
	if maximum > 0.0:
		max_shield = maximum
	shield = current


## Apply damage.
func apply_damage(amount: float) -> void:
	current_health -= amount


## Apply healing.
func heal(amount: float) -> void:
	current_health += amount


## Reset to full health.
func reset_to_full() -> void:
	_delayed_health = max_health
	current_health = max_health
	shield = 0.0
	_damage_flash = 0.0
	_heal_flash = 0.0
	queue_redraw()
