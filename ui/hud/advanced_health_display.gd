## Premium competitive-grade health display system.
## Features segmented health bars, shield overlay, critical health effects,
## smooth value interpolation, damage flash with screen effects, and healing animations.
## Designed to match PUBG Mobile / Call of Duty Mobile quality standards.
class_name AdvancedHealthDisplay
extends Control

## Signal emitted when health reaches zero.
signal health_depleted
## Signal emitted when health changes.
signal health_changed(new_health: float, max_health: float)
## Signal emitted when critical health state changes.
signal critical_health_changed(is_critical: bool)

## Health segment visual configuration.
enum SegmentStyle {
	CONTINUOUS,       ## Smooth continuous bar.
	SEGMENTED,        ## Divided into segments (like armor plates).
	NOTCHED,          ## Small notches marking segments.
}

## Current health value (displayed value, interpolated).
var _display_health: float = 100.0
## Target health value (actual game value).
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

## Shield/armor amount.
var shield: float = 0.0:
	set(value):
		var old_shield: float = shield
		shield = clampf(value, 0.0, max_shield)
		if shield != old_shield:
			_trigger_shield_flash(shield < old_shield)
			queue_redraw()

## Maximum shield value.
var max_shield: float = 100.0

## Delayed health (for damage preview effect).
var _delayed_health: float = 100.0

## Delayed shield for preview.
var _delayed_shield: float = 0.0

## Current segment style.
var segment_style: SegmentStyle = SegmentStyle.SEGMENTED

## Number of health segments.
var segment_count: int = 5

## Number of shield segments.
var shield_segment_count: int = 4

# ── Animation State ──────────────────────────────────────────────────────────

## Damage flash intensity (0.0 - 1.0).
var _damage_flash: float = 0.0

## Heal glow intensity.
var _heal_glow: float = 0.0

## Shield flash intensity.
var _shield_flash: float = 0.0

## Shield damage state.
var _shield_damaged: bool = false

## Critical health pulse phase.
var _critical_pulse: float = 0.0

## Was critical last frame.
var _was_critical: bool = false

## Screen vignette intensity for critical health.
var _vignette_intensity: float = 0.0

## Screen shake offset.
var _shake_offset: Vector2 = Vector2.ZERO

## Regeneration animation phase.
var _regen_phase: float = 0.0

## Is currently regenerating.
var _is_regenerating: bool = false

## Segment fill animations (for segment pop-in effect).
var _segment_fills: Array[float] = []

## Glow trail positions for regeneration effect.
var _regen_glow_positions: Array[float] = []

# ── Tweens ───────────────────────────────────────────────────────────────────

var _damage_tween: Tween = null
var _heal_tween: Tween = null
var _shield_tween: Tween = null
var _shake_tween: Tween = null

# ── Layout Constants ─────────────────────────────────────────────────────────

const BAR_WIDTH: float = 240.0
const BAR_HEIGHT: float = 20.0
const SHIELD_BAR_HEIGHT: float = 8.0
const CORNER_RADIUS: float = 4.0
const BORDER_WIDTH: float = 2.0
const SEGMENT_GAP: float = 2.0
const INNER_PADDING: float = 3.0

# ── Premium Color Palette ────────────────────────────────────────────────────

## Background colors.
const BG_COLOR: Color = Color(0.08, 0.08, 0.12, 0.9)
const BG_INNER_COLOR: Color = Color(0.05, 0.05, 0.08, 0.95)
const BORDER_COLOR: Color = Color(0.25, 0.25, 0.3, 0.95)
const BORDER_HIGHLIGHT: Color = Color(0.4, 0.4, 0.5, 0.5)

## Health gradient colors.
const HEALTH_COLOR_FULL: Color = Color(0.15, 0.95, 0.35, 1.0)
const HEALTH_COLOR_HIGH: Color = Color(0.4, 0.9, 0.25, 1.0)
const HEALTH_COLOR_MED: Color = Color(0.95, 0.85, 0.15, 1.0)
const HEALTH_COLOR_LOW: Color = Color(0.95, 0.4, 0.15, 1.0)
const HEALTH_COLOR_CRITICAL: Color = Color(0.95, 0.15, 0.15, 1.0)

## Shield colors.
const SHIELD_COLOR_PRIMARY: Color = Color(0.2, 0.7, 1.0, 1.0)
const SHIELD_COLOR_SECONDARY: Color = Color(0.4, 0.85, 1.0, 1.0)
const SHIELD_GLOW_COLOR: Color = Color(0.3, 0.8, 1.0, 0.4)

## Effect colors.
const DAMAGE_FLASH_COLOR: Color = Color(1.0, 0.15, 0.1, 0.9)
const DAMAGE_PREVIEW_COLOR: Color = Color(1.0, 0.25, 0.15, 0.65)
const HEAL_GLOW_COLOR: Color = Color(0.3, 1.0, 0.5, 0.7)
const REGEN_GLOW_COLOR: Color = Color(0.4, 1.0, 0.6, 0.8)
const SEGMENT_OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
const CRITICAL_PULSE_COLOR: Color = Color(1.0, 0.2, 0.15, 0.6)

## Vignette color for critical health.
const VIGNETTE_COLOR: Color = Color(0.8, 0.0, 0.0, 0.35)

## Thresholds.
const CRITICAL_THRESHOLD: float = 0.2
const LOW_THRESHOLD: float = 0.4
const MED_THRESHOLD: float = 0.7

# ── Timing Constants ─────────────────────────────────────────────────────────

const HEALTH_LERP_SPEED: float = 8.0
const DELAYED_HEALTH_LERP_SPEED: float = 2.5
const FLASH_DECAY_SPEED: float = 4.0
const GLOW_DECAY_SPEED: float = 3.0
const CRITICAL_PULSE_SPEED: float = 6.0
const REGEN_GLOW_SPEED: float = 3.0
const SHAKE_INTENSITY: float = 4.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BAR_WIDTH + 40, BAR_HEIGHT + SHIELD_BAR_HEIGHT + 30)

	_display_health = current_health
	_delayed_health = current_health
	_delayed_shield = shield

	# Initialize segment fill states.
	_segment_fills.resize(segment_count)
	for i: int in range(segment_count):
		_segment_fills[i] = 1.0


func _process(delta: float) -> void:
	var needs_redraw: bool = false

	# Smooth health interpolation.
	if absf(_display_health - current_health) > 0.1:
		_display_health = lerpf(_display_health, current_health, HEALTH_LERP_SPEED * delta)
		needs_redraw = true
	else:
		_display_health = current_health

	# Delayed health catch-up (damage preview).
	if _delayed_health > current_health:
		if absf(_delayed_health - current_health) > 0.1:
			_delayed_health = lerpf(_delayed_health, current_health, DELAYED_HEALTH_LERP_SPEED * delta)
			needs_redraw = true
		else:
			_delayed_health = current_health
	elif _delayed_health < current_health:
		_delayed_health = current_health

	# Delayed shield catch-up.
	if _delayed_shield > shield:
		_delayed_shield = lerpf(_delayed_shield, shield, DELAYED_HEALTH_LERP_SPEED * delta)
		needs_redraw = true
	elif _delayed_shield < shield:
		_delayed_shield = shield

	# Decay flash effects.
	if _damage_flash > 0.0:
		_damage_flash = maxf(_damage_flash - FLASH_DECAY_SPEED * delta, 0.0)
		needs_redraw = true

	if _heal_glow > 0.0:
		_heal_glow = maxf(_heal_glow - GLOW_DECAY_SPEED * delta, 0.0)
		needs_redraw = true

	if _shield_flash > 0.0:
		_shield_flash = maxf(_shield_flash - FLASH_DECAY_SPEED * delta, 0.0)
		needs_redraw = true

	# Critical health effects.
	var is_critical: bool = _is_critical_health()
	if is_critical:
		_critical_pulse = fmod(_critical_pulse + CRITICAL_PULSE_SPEED * delta, TAU)
		_vignette_intensity = lerpf(_vignette_intensity, 0.8, delta * 4.0)
		needs_redraw = true
	else:
		if _vignette_intensity > 0.01:
			_vignette_intensity = lerpf(_vignette_intensity, 0.0, delta * 6.0)
			needs_redraw = true
		_critical_pulse = 0.0

	# Check for critical state change.
	if is_critical != _was_critical:
		_was_critical = is_critical
		critical_health_changed.emit(is_critical)

	# Regeneration glow animation.
	if _is_regenerating:
		_regen_phase = fmod(_regen_phase + REGEN_GLOW_SPEED * delta, 1.0)
		needs_redraw = true

	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	var base_pos: Vector2 = Vector2(20, 15) + _shake_offset

	# Draw shield bar first (above health bar).
	if max_shield > 0.0:
		_draw_shield_bar(base_pos)
		base_pos.y += SHIELD_BAR_HEIGHT + 4

	# Draw main health bar.
	_draw_health_bar(base_pos)

	# Draw health text overlay.
	_draw_health_text(base_pos)

	# Draw critical vignette effect.
	if _vignette_intensity > 0.01:
		_draw_critical_vignette()


## Draw the main health bar with all effects.
func _draw_health_bar(pos: Vector2) -> void:
	var bar_rect: Rect2 = Rect2(pos, Vector2(BAR_WIDTH, BAR_HEIGHT))

	# Draw background with inner shadow effect.
	_draw_bar_background(bar_rect)

	var inner_rect: Rect2 = bar_rect.grow(-INNER_PADDING)

	# Draw damage preview (delayed health).
	if _delayed_health > _display_health:
		var preview_percent: float = _delayed_health / max_health
		var preview_width: float = preview_percent * inner_rect.size.x
		var preview_rect: Rect2 = Rect2(inner_rect.position, Vector2(preview_width, inner_rect.size.y))
		draw_rect(preview_rect, DAMAGE_PREVIEW_COLOR)

	# Draw health fill based on segment style.
	match segment_style:
		SegmentStyle.CONTINUOUS:
			_draw_continuous_health(inner_rect)
		SegmentStyle.SEGMENTED:
			_draw_segmented_health(inner_rect)
		SegmentStyle.NOTCHED:
			_draw_notched_health(inner_rect)

	# Draw healing glow overlay.
	if _heal_glow > 0.0:
		var glow_color: Color = HEAL_GLOW_COLOR
		glow_color.a *= _heal_glow
		var health_percent: float = _display_health / max_health
		var glow_rect: Rect2 = Rect2(inner_rect.position, Vector2(health_percent * inner_rect.size.x, inner_rect.size.y))
		draw_rect(glow_rect, glow_color)

	# Draw regeneration animation.
	if _is_regenerating:
		_draw_regen_effect(inner_rect)

	# Draw damage flash overlay.
	if _damage_flash > 0.0:
		var flash_color: Color = DAMAGE_FLASH_COLOR
		flash_color.a *= _damage_flash * 0.6
		draw_rect(bar_rect, flash_color)

	# Draw critical pulse overlay.
	if _is_critical_health():
		var pulse: float = (sin(_critical_pulse) + 1.0) * 0.5
		var pulse_color: Color = CRITICAL_PULSE_COLOR
		pulse_color.a *= pulse * 0.4
		draw_rect(bar_rect, pulse_color)

	# Draw border and highlight.
	_draw_bar_border(bar_rect)


## Draw bar background with gradient and inner shadow.
func _draw_bar_background(rect: Rect2) -> void:
	# Outer background.
	draw_rect(rect, BG_COLOR)

	# Inner darker area.
	var inner: Rect2 = rect.grow(-INNER_PADDING)
	draw_rect(inner, BG_INNER_COLOR)


## Draw bar border with highlight.
func _draw_bar_border(rect: Rect2) -> void:
	# Main border.
	draw_rect(rect, BORDER_COLOR, false, BORDER_WIDTH)

	# Top highlight.
	var highlight_rect: Rect2 = Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 1))
	draw_rect(highlight_rect, BORDER_HIGHLIGHT)


## Draw continuous health fill.
func _draw_continuous_health(rect: Rect2) -> void:
	var health_percent: float = _display_health / max_health
	if health_percent <= 0.0:
		return

	var fill_width: float = health_percent * rect.size.x
	var fill_rect: Rect2 = Rect2(rect.position, Vector2(fill_width, rect.size.y))
	var color: Color = _get_health_color(health_percent)

	# Draw gradient fill.
	_draw_gradient_fill(fill_rect, color, color.lightened(0.2))

	# Draw shine effect.
	_draw_bar_shine(fill_rect)


## Draw segmented health fill (armor plate style).
func _draw_segmented_health(rect: Rect2) -> void:
	var health_percent: float = _display_health / max_health
	var segment_width: float = (rect.size.x - (segment_count - 1) * SEGMENT_GAP) / float(segment_count)
	var base_color: Color = _get_health_color(health_percent)

	for i: int in range(segment_count):
		var segment_start: float = float(i) / float(segment_count)
		var segment_end: float = float(i + 1) / float(segment_count)

		var x: float = rect.position.x + i * (segment_width + SEGMENT_GAP)
		var segment_rect: Rect2 = Rect2(Vector2(x, rect.position.y), Vector2(segment_width, rect.size.y))

		# Calculate fill for this segment.
		var fill: float = 0.0
		if health_percent >= segment_end:
			fill = 1.0
		elif health_percent > segment_start:
			fill = (health_percent - segment_start) / (segment_end - segment_start)

		if fill > 0.0:
			# Animate segment fill.
			var anim_fill: float = fill
			if i < _segment_fills.size():
				anim_fill = minf(fill, _segment_fills[i])

			var fill_rect: Rect2 = Rect2(
				segment_rect.position,
				Vector2(segment_rect.size.x * anim_fill, segment_rect.size.y)
			)

			# Segment color with slight variation.
			var seg_color: Color = base_color.lerp(base_color.lightened(0.1), float(i) / float(segment_count) * 0.3)
			_draw_gradient_fill(fill_rect, seg_color, seg_color.lightened(0.15))
			_draw_bar_shine(fill_rect)

		# Draw segment outline.
		draw_rect(segment_rect, SEGMENT_OUTLINE_COLOR, false, 1.0)


## Draw notched health fill.
func _draw_notched_health(rect: Rect2) -> void:
	var health_percent: float = _display_health / max_health
	var fill_width: float = health_percent * rect.size.x
	var fill_rect: Rect2 = Rect2(rect.position, Vector2(fill_width, rect.size.y))
	var color: Color = _get_health_color(health_percent)

	# Draw main fill.
	_draw_gradient_fill(fill_rect, color, color.lightened(0.2))
	_draw_bar_shine(fill_rect)

	# Draw notch lines.
	var notch_width: float = rect.size.x / float(segment_count)
	for i: int in range(1, segment_count):
		var x: float = rect.position.x + i * notch_width
		draw_line(
			Vector2(x, rect.position.y),
			Vector2(x, rect.position.y + rect.size.y),
			SEGMENT_OUTLINE_COLOR,
			2.0
		)


## Draw gradient fill for health bars.
func _draw_gradient_fill(rect: Rect2, top_color: Color, bottom_color: Color) -> void:
	# Simple two-color vertical gradient using polygon.
	var points: PackedVector2Array = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y)
	])
	var colors: PackedColorArray = PackedColorArray([
		top_color.lightened(0.1),
		top_color.lightened(0.1),
		top_color.darkened(0.1),
		top_color.darkened(0.1)
	])
	draw_polygon(points, colors)


## Draw shine/gloss effect on bar.
func _draw_bar_shine(rect: Rect2) -> void:
	if rect.size.x <= 0:
		return

	var shine_rect: Rect2 = Rect2(
		rect.position + Vector2(1, 1),
		Vector2(rect.size.x - 2, rect.size.y * 0.35)
	)
	var shine_color: Color = Color(1.0, 1.0, 1.0, 0.15)
	draw_rect(shine_rect, shine_color)


## Draw shield bar.
func _draw_shield_bar(pos: Vector2) -> void:
	var bar_rect: Rect2 = Rect2(pos, Vector2(BAR_WIDTH, SHIELD_BAR_HEIGHT))

	# Background.
	draw_rect(bar_rect, BG_COLOR)

	var inner_rect: Rect2 = bar_rect.grow(-1)

	# Draw shield preview (delayed).
	if _delayed_shield > shield:
		var preview_percent: float = _delayed_shield / max_shield
		var preview_width: float = preview_percent * inner_rect.size.x
		var preview_rect: Rect2 = Rect2(inner_rect.position, Vector2(preview_width, inner_rect.size.y))
		draw_rect(preview_rect, Color(SHIELD_COLOR_PRIMARY.r, SHIELD_COLOR_PRIMARY.g, SHIELD_COLOR_PRIMARY.b, 0.4))

	# Draw shield segments.
	if shield > 0.0:
		var shield_percent: float = shield / max_shield
		var segment_width: float = (inner_rect.size.x - (shield_segment_count - 1) * SEGMENT_GAP) / float(shield_segment_count)

		for i: int in range(shield_segment_count):
			var segment_start: float = float(i) / float(shield_segment_count)
			var segment_end: float = float(i + 1) / float(shield_segment_count)

			var x: float = inner_rect.position.x + i * (segment_width + SEGMENT_GAP)
			var segment_rect: Rect2 = Rect2(Vector2(x, inner_rect.position.y), Vector2(segment_width, inner_rect.size.y))

			var fill: float = 0.0
			if shield_percent >= segment_end:
				fill = 1.0
			elif shield_percent > segment_start:
				fill = (shield_percent - segment_start) / (segment_end - segment_start)

			if fill > 0.0:
				var fill_rect: Rect2 = Rect2(
					segment_rect.position,
					Vector2(segment_rect.size.x * fill, segment_rect.size.y)
				)

				# Shield gradient with glow.
				var color: Color = SHIELD_COLOR_PRIMARY.lerp(SHIELD_COLOR_SECONDARY, float(i) / float(shield_segment_count))
				draw_rect(fill_rect, color)

				# Shine.
				var shine_rect: Rect2 = Rect2(fill_rect.position, Vector2(fill_rect.size.x, fill_rect.size.y * 0.4))
				draw_rect(shine_rect, Color(1.0, 1.0, 1.0, 0.2))

			# Segment outline.
			draw_rect(segment_rect, SEGMENT_OUTLINE_COLOR, false, 1.0)

	# Shield flash overlay.
	if _shield_flash > 0.0:
		var flash_color: Color = SHIELD_COLOR_PRIMARY if not _shield_damaged else DAMAGE_FLASH_COLOR
		flash_color.a = _shield_flash * 0.5
		draw_rect(bar_rect, flash_color)

	# Border.
	draw_rect(bar_rect, BORDER_COLOR, false, 1.0)


## Draw regeneration glow effect.
func _draw_regen_effect(rect: Rect2) -> void:
	var health_percent: float = _display_health / max_health
	var fill_width: float = health_percent * rect.size.x

	# Animated glow at the edge of health.
	var glow_x: float = rect.position.x + fill_width
	var glow_width: float = 20.0
	var pulse: float = (sin(_regen_phase * TAU) + 1.0) * 0.5

	var glow_color: Color = REGEN_GLOW_COLOR
	glow_color.a *= 0.3 + pulse * 0.4

	# Draw glow gradient.
	for i: int in range(int(glow_width)):
		var alpha: float = (1.0 - float(i) / glow_width) * glow_color.a
		var x: float = glow_x - float(i)
		if x >= rect.position.x:
			var line_color: Color = glow_color
			line_color.a = alpha
			draw_line(
				Vector2(x, rect.position.y),
				Vector2(x, rect.position.y + rect.size.y),
				line_color,
				1.0
			)


## Draw health text overlay.
func _draw_health_text(bar_pos: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var bar_rect: Rect2 = Rect2(bar_pos, Vector2(BAR_WIDTH, BAR_HEIGHT))

	# Current health / max health.
	var health_text: String = "%d" % int(_display_health)
	var max_text: String = " / %d" % int(max_health)

	var health_size: Vector2 = font.get_string_size(health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var max_size: Vector2 = font.get_string_size(max_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)

	var total_width: float = health_size.x + max_size.x
	var text_x: float = bar_rect.position.x + (bar_rect.size.x - total_width) * 0.5
	var text_y: float = bar_rect.position.y + bar_rect.size.y * 0.5 + health_size.y * 0.3

	# Health color based on amount.
	var health_percent: float = _display_health / max_health
	var text_color: Color = _get_health_color(health_percent)
	if _is_critical_health():
		var pulse: float = (sin(_critical_pulse) + 1.0) * 0.5
		text_color = text_color.lerp(Color.WHITE, pulse * 0.3)

	# Shadow.
	draw_string(font, Vector2(text_x + 1, text_y + 1), health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.8))
	# Main text.
	draw_string(font, Vector2(text_x, text_y), health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)

	# Max health (smaller, gray).
	draw_string(font, Vector2(text_x + health_size.x + 1, text_y + 1), max_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(text_x + health_size.x, text_y), max_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.7, 0.7, 0.9))


## Draw critical health vignette effect.
func _draw_critical_vignette() -> void:
	# This is drawn as part of the control - for full-screen effect,
	# this should be handled by a parent or shader.
	var pulse: float = (sin(_critical_pulse) + 1.0) * 0.5
	var alpha: float = _vignette_intensity * (0.5 + pulse * 0.5)

	# Draw red tint on edges (simplified vignette).
	var edge_size: float = 40.0
	var vignette_color: Color = VIGNETTE_COLOR
	vignette_color.a = alpha * 0.3

	# Top edge.
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, edge_size)), vignette_color)
	# Bottom edge.
	draw_rect(Rect2(Vector2(0, size.y - edge_size), Vector2(size.x, edge_size)), vignette_color)
	# Left edge.
	draw_rect(Rect2(Vector2.ZERO, Vector2(edge_size, size.y)), vignette_color)
	# Right edge.
	draw_rect(Rect2(Vector2(size.x - edge_size, 0), Vector2(edge_size, size.y)), vignette_color)


## Get health color based on percentage.
func _get_health_color(percent: float) -> Color:
	if percent >= MED_THRESHOLD:
		var t: float = (percent - MED_THRESHOLD) / (1.0 - MED_THRESHOLD)
		return HEALTH_COLOR_HIGH.lerp(HEALTH_COLOR_FULL, t)
	elif percent >= LOW_THRESHOLD:
		var t: float = (percent - LOW_THRESHOLD) / (MED_THRESHOLD - LOW_THRESHOLD)
		return HEALTH_COLOR_MED.lerp(HEALTH_COLOR_HIGH, t)
	elif percent >= CRITICAL_THRESHOLD:
		var t: float = (percent - CRITICAL_THRESHOLD) / (LOW_THRESHOLD - CRITICAL_THRESHOLD)
		return HEALTH_COLOR_LOW.lerp(HEALTH_COLOR_MED, t)
	else:
		var t: float = percent / CRITICAL_THRESHOLD
		return HEALTH_COLOR_CRITICAL.lerp(HEALTH_COLOR_LOW, t)


## Check if health is critical.
func _is_critical_health() -> bool:
	return (current_health / max_health) <= CRITICAL_THRESHOLD


## Check if health is low.
func _is_low_health() -> bool:
	return (current_health / max_health) <= LOW_THRESHOLD


## Handle health change.
func _on_health_changed(old_health: float, new_health: float) -> void:
	health_changed.emit(new_health, max_health)

	if new_health < old_health:
		_trigger_damage_flash(old_health - new_health)
	elif new_health > old_health:
		_trigger_heal_glow()

	if new_health <= 0.0:
		health_depleted.emit()

	queue_redraw()


## Trigger damage flash effect.
func _trigger_damage_flash(damage_amount: float) -> void:
	# Scale flash intensity by damage.
	var intensity: float = clampf(damage_amount / 50.0, 0.5, 1.0)
	_damage_flash = intensity

	if _damage_tween and _damage_tween.is_valid():
		_damage_tween.kill()

	# Trigger screen shake for heavy damage.
	if damage_amount >= 20.0:
		_trigger_shake(damage_amount)


## Trigger heal glow effect.
func _trigger_heal_glow() -> void:
	_heal_glow = 1.0
	_delayed_health = current_health  # No delay for healing.

	if _heal_tween and _heal_tween.is_valid():
		_heal_tween.kill()


## Trigger shield flash.
func _trigger_shield_flash(is_damage: bool) -> void:
	_shield_flash = 1.0
	_shield_damaged = is_damage


## Trigger screen shake.
func _trigger_shake(damage: float) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	var intensity: float = clampf(damage / 30.0, 0.3, 1.0) * SHAKE_INTENSITY

	_shake_tween = create_tween()
	_shake_tween.tween_method(_apply_shake.bind(intensity), 1.0, 0.0, 0.3)
	_shake_tween.tween_callback(func() -> void: _shake_offset = Vector2.ZERO)


## Apply shake offset.
func _apply_shake(progress: float, intensity: float) -> void:
	var shake: float = intensity * progress
	_shake_offset = Vector2(
		randf_range(-shake, shake),
		randf_range(-shake, shake)
	)
	queue_redraw()


# ── Public API ───────────────────────────────────────────────────────────────

## Set health values.
func set_health(current: float, maximum: float) -> void:
	max_health = maximum
	current_health = current


## Set shield values.
func set_shield_values(current: float, maximum: float = -1.0) -> void:
	if maximum > 0.0:
		max_shield = maximum
	shield = current


## Apply damage.
func apply_damage(amount: float) -> void:
	current_health -= amount


## Apply healing.
func heal(amount: float) -> void:
	current_health += amount


## Start regeneration animation.
func start_regeneration() -> void:
	_is_regenerating = true
	_regen_phase = 0.0


## Stop regeneration animation.
func stop_regeneration() -> void:
	_is_regenerating = false


## Set segment style.
func set_segment_style(style: SegmentStyle) -> void:
	segment_style = style
	queue_redraw()


## Reset to full health.
func reset_to_full() -> void:
	_delayed_health = max_health
	_delayed_shield = max_shield
	current_health = max_health
	shield = max_shield if max_shield > 0 else 0.0
	_damage_flash = 0.0
	_heal_glow = 0.0
	_shield_flash = 0.0
	_critical_pulse = 0.0
	_vignette_intensity = 0.0
	_shake_offset = Vector2.ZERO
	_is_regenerating = false
	queue_redraw()
