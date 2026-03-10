## Ultra-premium competitive ammo counter with AAA-quality effects.
## Features per-bullet 3D visualization, physics-based magazine reload animation,
## bullet trajectory tracers, weapon heat indicator, jam probability display,
## and empty magazine shake. Designed for esports-ready FPS HUDs.
class_name UltraAmmoCounter
extends Control

## Signal emitted when ammo reaches zero.
signal ammo_depleted
## Signal emitted when reload completes.
signal reload_completed
## Signal emitted when ammo changes.
signal ammo_changed(current: int, max_ammo: int)
## Signal emitted when weapon jams.
signal weapon_jammed

# ── Ammo Values ───────────────────────────────────────────────────────────────

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

## Weapon heat level (0.0 to 1.0) for energy weapons.
var weapon_heat: float = 0.0:
	set(value):
		weapon_heat = clampf(value, 0.0, 1.0)
		queue_redraw()

## Whether this is an energy weapon (shows heat instead of bullets).
var is_energy_weapon: bool = false

## Jam probability (0.0 to 1.0).
var jam_probability: float = 0.0:
	set(value):
		jam_probability = clampf(value, 0.0, 1.0)
		queue_redraw()

## Whether weapon is currently jammed.
var is_jammed: bool = false

# ── Display Values ────────────────────────────────────────────────────────────

var _display_ammo: float = 30.0
var _display_reserve: float = 120.0
var _display_heat: float = 0.0

# ── Animation State ───────────────────────────────────────────────────────────

## Reload progress (0.0 to 1.0).
var _reload_progress: float = 0.0

## Whether currently reloading.
var _is_reloading: bool = false

## Magazine animation state.
var _mag_out_progress: float = 0.0  ## Magazine sliding out.
var _mag_in_progress: float = 0.0   ## New magazine sliding in.
var _mag_rotation: float = 0.0      ## Magazine rotation (physics).
var _mag_velocity: float = 0.0      ## Magazine fall velocity.

## Low ammo pulse phase.
var _low_ammo_pulse: float = 0.0

## Reload ring pulse phase.
var _reload_pulse: float = 0.0

## Ammo change scale animation.
var _ammo_scale: float = 1.0

## Fire flash effect.
var _fire_flash: float = 0.0

## Empty magazine shake.
var _empty_shake: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO

## Jam warning pulse.
var _jam_pulse: float = 0.0

## Heat warning pulse.
var _heat_pulse: float = 0.0

## Individual bullet states for magazine visualization.
var _bullet_states: Array[Dictionary] = []

## Last 3 shot tracer positions (for trajectory visualization).
var _tracer_positions: Array[Dictionary] = []
const MAX_TRACERS: int = 3

# ── Tweens ────────────────────────────────────────────────────────────────────

var _reload_tween: Tween = null
var _ammo_tween: Tween = null
var _shake_tween: Tween = null
var _mag_tween: Tween = null

# ── Layout Constants ──────────────────────────────────────────────────────────

const DISPLAY_WIDTH: float = 200.0
const DISPLAY_HEIGHT: float = 100.0
const DIGIT_WIDTH: float = 32.0
const DIGIT_HEIGHT: float = 48.0
const DIGIT_SPACING: float = 3.0
const RELOAD_RING_RADIUS: float = 40.0
const RELOAD_RING_WIDTH: float = 5.0
const BULLET_WIDTH: float = 6.0
const BULLET_HEIGHT: float = 16.0
const BULLET_SPACING: float = 3.0
const MAX_VISIBLE_BULLETS: int = 20
const MAGAZINE_WIDTH: float = 24.0
const MAGAZINE_HEIGHT: float = 50.0
const HEAT_BAR_WIDTH: float = 120.0
const HEAT_BAR_HEIGHT: float = 8.0

# ── Premium Color Palette ─────────────────────────────────────────────────────

## Background colors.
const BG_COLOR: Color = Color(0.05, 0.05, 0.08, 0.88)
const BG_INNER_COLOR: Color = Color(0.03, 0.03, 0.05, 0.92)
const BORDER_COLOR: Color = Color(0.18, 0.18, 0.22, 0.92)
const BORDER_HIGHLIGHT: Color = Color(0.32, 0.32, 0.38, 0.45)

## Digit colors.
const DIGIT_BG_COLOR: Color = Color(0.02, 0.02, 0.04, 0.95)
const DIGIT_COLOR_NORMAL: Color = Color(1.0, 1.0, 1.0, 1.0)
const DIGIT_COLOR_LOW: Color = Color(1.0, 0.45, 0.18, 1.0)
const DIGIT_COLOR_CRITICAL: Color = Color(1.0, 0.18, 0.12, 1.0)
const DIGIT_COLOR_EMPTY: Color = Color(0.7, 0.15, 0.1, 1.0)
const DIGIT_GLOW_COLOR: Color = Color(0.25, 0.8, 1.0, 0.45)

## Reserve ammo colors.
const RESERVE_COLOR: Color = Color(0.62, 0.62, 0.68, 0.92)
const RESERVE_LOW_COLOR: Color = Color(1.0, 0.58, 0.28, 0.92)

## Reload indicator colors.
const RELOAD_BG_COLOR: Color = Color(0.12, 0.12, 0.18, 0.75)
const RELOAD_PROGRESS_COLOR: Color = Color(0.18, 0.88, 1.0, 0.95)
const RELOAD_GLOW_COLOR: Color = Color(0.28, 0.92, 1.0, 0.55)
const RELOAD_TEXT_COLOR: Color = Color(0.28, 0.92, 1.0, 1.0)

## Bullet visualization colors.
const BULLET_LOADED_COLOR: Color = Color(0.95, 0.88, 0.28, 1.0)
const BULLET_CASING_COLOR: Color = Color(0.75, 0.55, 0.2, 1.0)
const BULLET_EMPTY_COLOR: Color = Color(0.22, 0.22, 0.28, 0.55)
const BULLET_FIRING_COLOR: Color = Color(1.0, 0.55, 0.18, 1.0)
const BULLET_TIP_COLOR: Color = Color(0.85, 0.65, 0.35, 1.0)

## Magazine colors.
const MAGAZINE_COLOR: Color = Color(0.25, 0.25, 0.3, 1.0)
const MAGAZINE_HIGHLIGHT_COLOR: Color = Color(0.35, 0.35, 0.42, 1.0)

## Effect colors.
const FIRE_FLASH_COLOR: Color = Color(1.0, 0.58, 0.18, 0.65)
const LOW_AMMO_PULSE_COLOR: Color = Color(1.0, 0.28, 0.18, 0.35)
const EMPTY_SHAKE_COLOR: Color = Color(1.0, 0.15, 0.1, 0.5)

## Tracer colors.
const TRACER_COLOR_START: Color = Color(1.0, 0.9, 0.5, 0.9)
const TRACER_COLOR_END: Color = Color(1.0, 0.5, 0.2, 0.0)

## Heat indicator colors.
const HEAT_COLOR_COOL: Color = Color(0.3, 0.8, 1.0, 1.0)
const HEAT_COLOR_WARM: Color = Color(1.0, 0.8, 0.2, 1.0)
const HEAT_COLOR_HOT: Color = Color(1.0, 0.4, 0.1, 1.0)
const HEAT_COLOR_CRITICAL: Color = Color(1.0, 0.15, 0.1, 1.0)
const HEAT_GLOW_COLOR: Color = Color(1.0, 0.5, 0.2, 0.5)

## Jam indicator colors.
const JAM_WARNING_COLOR: Color = Color(1.0, 0.6, 0.2, 1.0)
const JAM_CRITICAL_COLOR: Color = Color(1.0, 0.2, 0.15, 1.0)
const JAMMED_COLOR: Color = Color(1.0, 0.15, 0.1, 1.0)

## Infinite ammo color.
const INFINITE_COLOR: Color = Color(0.68, 0.92, 1.0, 0.95)

# ── Thresholds ────────────────────────────────────────────────────────────────

const LOW_AMMO_THRESHOLD: float = 0.3
const CRITICAL_AMMO_THRESHOLD: float = 0.15
const LOW_RESERVE_THRESHOLD: int = 30
const HEAT_WARNING_THRESHOLD: float = 0.7
const HEAT_CRITICAL_THRESHOLD: float = 0.9
const JAM_WARNING_THRESHOLD: float = 0.3
const JAM_CRITICAL_THRESHOLD: float = 0.6

# ── Timing Constants ──────────────────────────────────────────────────────────

const DIGIT_LERP_SPEED: float = 18.0
const HEAT_LERP_SPEED: float = 8.0
const FLIP_DURATION: float = 0.1
const SCALE_BOUNCE_DURATION: float = 0.12
const FIRE_FLASH_DECAY: float = 10.0
const LOW_AMMO_PULSE_SPEED: float = 6.0
const RELOAD_PULSE_SPEED: float = 5.0
const EMPTY_SHAKE_DECAY: float = 8.0
const JAM_PULSE_SPEED: float = 8.0
const HEAT_PULSE_SPEED: float = 6.0
const TRACER_LIFETIME: float = 0.5
const MAG_PHYSICS_GRAVITY: float = 15.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(DISPLAY_WIDTH, DISPLAY_HEIGHT + 40)

	_display_ammo = float(current_ammo)
	_display_reserve = float(reserve_ammo)
	_display_heat = weapon_heat

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

	# Update heat display.
	if absf(_display_heat - weapon_heat) > 0.01:
		_display_heat = lerpf(_display_heat, weapon_heat, HEAT_LERP_SPEED * delta)
		needs_redraw = true

	# Update low ammo pulse.
	if _is_low_ammo() and not _is_reloading and not infinite_ammo:
		_low_ammo_pulse = fmod(_low_ammo_pulse + LOW_AMMO_PULSE_SPEED * delta, TAU)
		needs_redraw = true
	else:
		_low_ammo_pulse = 0.0

	# Update reload pulse.
	if _is_reloading:
		_reload_pulse = fmod(_reload_pulse + RELOAD_PULSE_SPEED * delta, TAU)
		needs_redraw = true

	# Update jam warning pulse.
	if jam_probability > JAM_WARNING_THRESHOLD and not is_jammed:
		_jam_pulse = fmod(_jam_pulse + JAM_PULSE_SPEED * delta, TAU)
		needs_redraw = true

	# Update heat warning pulse.
	if weapon_heat > HEAT_WARNING_THRESHOLD:
		_heat_pulse = fmod(_heat_pulse + HEAT_PULSE_SPEED * delta, TAU)
		needs_redraw = true

	# Decay fire flash.
	if _fire_flash > 0.0:
		_fire_flash = maxf(_fire_flash - FIRE_FLASH_DECAY * delta, 0.0)
		needs_redraw = true

	# Decay empty shake.
	if _empty_shake > 0.0:
		_empty_shake = maxf(_empty_shake - EMPTY_SHAKE_DECAY * delta, 0.0)
		_shake_offset = Vector2(
			randf_range(-_empty_shake, _empty_shake) * 4.0,
			randf_range(-_empty_shake, _empty_shake) * 2.0
		)
		needs_redraw = true

	# Update magazine physics during reload.
	if _is_reloading:
		needs_redraw = _update_magazine_physics(delta) or needs_redraw

	# Update bullet animations.
	for bullet: Dictionary in _bullet_states:
		if bullet.get("animating", false) as bool:
			bullet["anim_progress"] = (bullet["anim_progress"] as float) + delta * 10.0
			if (bullet["anim_progress"] as float) >= 1.0:
				bullet["animating"] = false
				bullet["anim_progress"] = 1.0
			needs_redraw = true

	# Update tracer positions.
	needs_redraw = _update_tracers(delta) or needs_redraw

	if needs_redraw or _is_reloading:
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5 + _shake_offset

	if _is_reloading:
		_draw_reload_display_v2(center)
	else:
		_draw_ammo_display_v2(center)

	# Draw tracers (last 3 shots).
	_draw_bullet_tracers()


## Draw the main ammo counter display.
func _draw_ammo_display_v2(center: Vector2) -> void:
	var display_rect: Rect2 = Rect2(
		center - Vector2(DISPLAY_WIDTH * 0.5, DISPLAY_HEIGHT * 0.5 + 15),
		Vector2(DISPLAY_WIDTH, DISPLAY_HEIGHT)
	)

	# Draw background panel.
	_draw_display_background(display_rect)

	# Draw ammo digits or energy bar.
	var digits_y: float = display_rect.position.y + 14

	if infinite_ammo:
		_draw_infinite_symbol(Vector2(display_rect.position.x + display_rect.size.x * 0.5, digits_y + DIGIT_HEIGHT * 0.5))
	elif is_energy_weapon:
		_draw_energy_heat_bar(display_rect)
	else:
		_draw_ammo_digits_v2(Vector2(display_rect.position.x + 18, digits_y))

		# Draw reserve ammo.
		if show_reserve:
			_draw_reserve_ammo_v2(Vector2(display_rect.position.x + display_rect.size.x - 18, digits_y + DIGIT_HEIGHT * 0.5))

	# Draw 3D bullet magazine visualization.
	if not infinite_ammo and not is_energy_weapon and max_ammo <= MAX_VISIBLE_BULLETS:
		_draw_bullet_magazine_3d(Vector2(center.x, display_rect.position.y + display_rect.size.y - 12))

	# Draw jam probability indicator.
	if jam_probability > 0.0 and not is_energy_weapon:
		_draw_jam_indicator(display_rect)

	# Draw jammed overlay.
	if is_jammed:
		_draw_jammed_overlay(display_rect)

	# Draw low ammo pulse overlay.
	if _is_low_ammo() and not infinite_ammo and not is_energy_weapon:
		var pulse: float = (sin(_low_ammo_pulse) + 1.0) * 0.5
		var pulse_color: Color = LOW_AMMO_PULSE_COLOR
		pulse_color.a *= pulse
		draw_rect(display_rect, pulse_color)

	# Draw fire flash.
	if _fire_flash > 0.0:
		var flash_color: Color = FIRE_FLASH_COLOR
		flash_color.a *= _fire_flash
		draw_rect(display_rect, flash_color)

	# Draw empty shake overlay.
	if _empty_shake > 0.0:
		var shake_color: Color = EMPTY_SHAKE_COLOR
		shake_color.a *= _empty_shake * 0.5
		draw_rect(display_rect, shake_color)


## Draw display background with premium styling.
func _draw_display_background(rect: Rect2) -> void:
	draw_rect(rect, BG_COLOR)
	var inner: Rect2 = rect.grow(-4)
	draw_rect(inner, BG_INNER_COLOR)
	draw_rect(rect, BORDER_COLOR, false, 2.5)
	var highlight: Rect2 = Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 1))
	draw_rect(highlight, BORDER_HIGHLIGHT)


## Draw ammo digits with enhanced animation effects.
func _draw_ammo_digits_v2(pos: Vector2) -> void:
	var ammo_str: String = "%02d" % int(round(_display_ammo))
	var digit_color: Color = _get_digit_color()

	var scale: float = _ammo_scale

	for i: int in range(ammo_str.length()):
		var digit_x: float = pos.x + i * (DIGIT_WIDTH + DIGIT_SPACING)
		var digit_rect: Rect2 = Rect2(Vector2(digit_x, pos.y), Vector2(DIGIT_WIDTH, DIGIT_HEIGHT))

		# Scale from center.
		if scale != 1.0:
			var rect_center: Vector2 = digit_rect.get_center()
			digit_rect.position = rect_center - digit_rect.size * scale * 0.5
			digit_rect.size *= scale

		# Draw digit background with gradient.
		draw_rect(digit_rect, DIGIT_BG_COLOR)

		# Draw digit.
		var font: Font = ThemeDB.fallback_font
		var digit_text: String = ammo_str[i]
		var font_size: int = int(32 * scale)
		var text_size: Vector2 = font.get_string_size(digit_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = Vector2(
			digit_rect.get_center().x - text_size.x * 0.5,
			digit_rect.get_center().y + text_size.y * 0.35
		)

		# Draw shadow.
		draw_string(font, text_pos + Vector2(1, 1), digit_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.85))

		# Draw main digit.
		draw_string(font, text_pos, digit_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, digit_color)

		# Draw glow for critical/empty state.
		if _is_critical_ammo() or current_ammo == 0:
			var pulse: float = (sin(_low_ammo_pulse * 2.0) + 1.0) * 0.5
			var glow_color: Color = digit_color
			glow_color.a = pulse * 0.35
			draw_rect(digit_rect.grow(3), glow_color)

		# Draw border.
		draw_rect(digit_rect, BORDER_COLOR, false, 1.5)


## Draw reserve ammo count.
func _draw_reserve_ammo_v2(pos: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var reserve_text: String = "/ %d" % int(round(_display_reserve))

	var color: Color = RESERVE_COLOR
	if reserve_ammo < LOW_RESERVE_THRESHOLD:
		color = RESERVE_LOW_COLOR

	var text_size: Vector2 = font.get_string_size(reserve_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 18)
	var text_pos: Vector2 = Vector2(pos.x - text_size.x, pos.y + text_size.y * 0.35)

	draw_string(font, text_pos + Vector2(1, 1), reserve_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 18, Color(0, 0, 0, 0.65))
	draw_string(font, text_pos, reserve_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 18, color)


## Draw infinite ammo symbol.
func _draw_infinite_symbol(center: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var inf_text: String = "INF"

	var text_size: Vector2 = font.get_string_size(inf_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 36)
	var text_pos: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)

	# Glow effect.
	var glow_color: Color = INFINITE_COLOR
	glow_color.a = 0.35
	draw_string(font, text_pos + Vector2(-1, -1), inf_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 38, glow_color)
	draw_string(font, text_pos + Vector2(1, 1), inf_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 38, glow_color)

	draw_string(font, text_pos, inf_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 36, INFINITE_COLOR)


## Draw 3D-style bullet magazine visualization.
func _draw_bullet_magazine_3d(center: Vector2) -> void:
	var bullet_count: int = mini(max_ammo, MAX_VISIBLE_BULLETS)
	var total_width: float = bullet_count * (BULLET_WIDTH + BULLET_SPACING) - BULLET_SPACING
	var start_x: float = center.x - total_width * 0.5

	for i: int in range(bullet_count):
		var x: float = start_x + i * (BULLET_WIDTH + BULLET_SPACING)
		var bullet_rect: Rect2 = Rect2(Vector2(x, center.y - BULLET_HEIGHT * 0.5), Vector2(BULLET_WIDTH, BULLET_HEIGHT))

		var is_loaded: bool = i < current_ammo
		var base_color: Color = BULLET_LOADED_COLOR if is_loaded else BULLET_EMPTY_COLOR

		# Check for animation state.
		var anim_offset: Vector2 = Vector2.ZERO
		var anim_alpha: float = 1.0

		if i < _bullet_states.size():
			var state: Dictionary = _bullet_states[i]
			if state.get("animating", false) as bool:
				var progress: float = state.get("anim_progress", 1.0) as float
				if state.get("is_firing", false) as bool:
					# Firing animation: flash and fly up.
					base_color = BULLET_FIRING_COLOR.lerp(BULLET_EMPTY_COLOR, progress)
					anim_offset.y = -(1.0 - progress) * 8.0
					anim_alpha = 1.0 - progress * 0.3
				else:
					# Reload animation: slide in from bottom.
					anim_alpha = progress
					anim_offset.y = (1.0 - progress) * 12.0

		bullet_rect.position += anim_offset

		if is_loaded or anim_alpha < 1.0:
			# Draw 3D bullet with casing, body, and tip.
			_draw_3d_bullet(bullet_rect, base_color, anim_alpha)
		else:
			# Draw empty slot.
			var empty_color: Color = BULLET_EMPTY_COLOR
			empty_color.a = 0.4
			draw_rect(bullet_rect, empty_color)


## Draw a 3D-style bullet.
func _draw_3d_bullet(rect: Rect2, base_color: Color, alpha: float) -> void:
	var color: Color = base_color
	color.a *= alpha

	# Bullet body (main part).
	var body_rect: Rect2 = Rect2(rect.position + Vector2(0, 3), Vector2(rect.size.x, rect.size.y - 5))
	draw_rect(body_rect, color)

	# Bullet tip (darker).
	var tip_rect: Rect2 = Rect2(rect.position, Vector2(rect.size.x, 3))
	var tip_color: Color = BULLET_TIP_COLOR
	tip_color.a *= alpha
	draw_rect(tip_rect, tip_color)

	# Casing bottom (brass color).
	var casing_rect: Rect2 = Rect2(rect.position + Vector2(0, rect.size.y - 2), Vector2(rect.size.x, 2))
	var casing_color: Color = BULLET_CASING_COLOR
	casing_color.a *= alpha
	draw_rect(casing_rect, casing_color)

	# 3D highlight.
	var highlight_rect: Rect2 = Rect2(rect.position + Vector2(1, 4), Vector2(rect.size.x * 0.3, rect.size.y - 7))
	var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.25 * alpha)
	draw_rect(highlight_rect, highlight_color)


## Draw energy weapon heat bar.
func _draw_energy_heat_bar(display_rect: Rect2) -> void:
	var bar_x: float = display_rect.position.x + (display_rect.size.x - HEAT_BAR_WIDTH) * 0.5
	var bar_y: float = display_rect.position.y + 20

	var bar_rect: Rect2 = Rect2(Vector2(bar_x, bar_y), Vector2(HEAT_BAR_WIDTH, HEAT_BAR_HEIGHT))

	# Background.
	draw_rect(bar_rect, DIGIT_BG_COLOR)

	# Heat fill.
	var fill_width: float = _display_heat * bar_rect.size.x
	var fill_rect: Rect2 = Rect2(bar_rect.position, Vector2(fill_width, bar_rect.size.y))

	var heat_color: Color = _get_heat_color(_display_heat)

	# Pulsing glow for high heat.
	if weapon_heat > HEAT_WARNING_THRESHOLD:
		var pulse: float = (sin(_heat_pulse) + 1.0) * 0.5
		heat_color = heat_color.lerp(HEAT_COLOR_CRITICAL, pulse * 0.3)

	draw_rect(fill_rect, heat_color)

	# Heat glow effect.
	if weapon_heat > HEAT_WARNING_THRESHOLD:
		var glow_color: Color = HEAT_GLOW_COLOR
		glow_color.a *= (_display_heat - HEAT_WARNING_THRESHOLD) / (1.0 - HEAT_WARNING_THRESHOLD)
		draw_rect(fill_rect.grow(2), glow_color)

	# Border.
	draw_rect(bar_rect, BORDER_COLOR, false, 1.5)

	# Heat percentage text.
	var font: Font = ThemeDB.fallback_font
	var heat_text: String = "%d%%" % int(_display_heat * 100)
	var text_size: Vector2 = font.get_string_size(heat_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	var text_pos: Vector2 = Vector2(
		bar_rect.get_center().x - text_size.x * 0.5,
		bar_rect.position.y + bar_rect.size.y + 18
	)

	var text_color: Color = heat_color if weapon_heat > HEAT_WARNING_THRESHOLD else Color.WHITE
	draw_string(font, text_pos, heat_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, text_color)

	# "HEAT" label.
	var label_pos: Vector2 = Vector2(bar_rect.get_center().x, bar_rect.position.y - 8)
	var label_size: Vector2 = font.get_string_size("HEAT", HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	draw_string(font, Vector2(label_pos.x - label_size.x * 0.5, label_pos.y), "HEAT", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.7, 0.7, 0.75, 0.9))


## Draw jam probability indicator.
func _draw_jam_indicator(display_rect: Rect2) -> void:
	var indicator_pos: Vector2 = Vector2(display_rect.position.x + display_rect.size.x - 30, display_rect.position.y + 8)

	var jam_color: Color = JAM_WARNING_COLOR
	if jam_probability > JAM_CRITICAL_THRESHOLD:
		jam_color = JAM_CRITICAL_COLOR
		var pulse: float = (sin(_jam_pulse) + 1.0) * 0.5
		jam_color = jam_color.lerp(Color.WHITE, pulse * 0.3)

	# Draw warning triangle.
	var triangle_size: float = 12.0
	var points: PackedVector2Array = PackedVector2Array([
		indicator_pos + Vector2(0, -triangle_size),
		indicator_pos + Vector2(triangle_size * 0.866, triangle_size * 0.5),
		indicator_pos + Vector2(-triangle_size * 0.866, triangle_size * 0.5),
	])
	var colors: PackedColorArray = PackedColorArray([jam_color, jam_color, jam_color])
	draw_polygon(points, colors)

	# Draw exclamation mark.
	var font: Font = ThemeDB.fallback_font
	draw_string(font, indicator_pos + Vector2(-3, 5), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.BLACK)

	# Draw probability text.
	var prob_text: String = "%d%%" % int(jam_probability * 100)
	var text_size: Vector2 = font.get_string_size(prob_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
	draw_string(font, indicator_pos + Vector2(-text_size.x * 0.5, triangle_size + 12), prob_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, jam_color)


## Draw jammed weapon overlay.
func _draw_jammed_overlay(display_rect: Rect2) -> void:
	# Red tint.
	var overlay_color: Color = JAMMED_COLOR
	overlay_color.a = 0.3
	draw_rect(display_rect, overlay_color)

	# "JAMMED" text.
	var font: Font = ThemeDB.fallback_font
	var jammed_text: String = "JAMMED"
	var text_size: Vector2 = font.get_string_size(jammed_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	var text_pos: Vector2 = display_rect.get_center() - text_size * 0.5 + Vector2(0, text_size.y * 0.35)

	# Pulsing.
	var pulse: float = (sin(_jam_pulse) + 1.0) * 0.5
	var text_color: Color = JAMMED_COLOR.lerp(Color.WHITE, pulse * 0.3)

	draw_string(font, text_pos + Vector2(1, 1), jammed_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(0, 0, 0, 0.8))
	draw_string(font, text_pos, jammed_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, text_color)


## Draw bullet trajectory tracers.
func _draw_bullet_tracers() -> void:
	for tracer: Dictionary in _tracer_positions:
		var start: Vector2 = tracer.get("start", Vector2.ZERO) as Vector2
		var end: Vector2 = tracer.get("end", Vector2.ZERO) as Vector2
		var life: float = tracer.get("life", 0.0) as float

		var alpha: float = life / TRACER_LIFETIME
		var color_start: Color = TRACER_COLOR_START
		var color_end: Color = TRACER_COLOR_END

		color_start.a *= alpha
		color_end.a *= alpha * 0.5

		# Draw gradient line.
		var segments: int = 8
		for i: int in range(segments):
			var t1: float = float(i) / float(segments)
			var t2: float = float(i + 1) / float(segments)

			var p1: Vector2 = start.lerp(end, t1)
			var p2: Vector2 = start.lerp(end, t2)

			var c1: Color = color_start.lerp(color_end, t1)
			var c2: Color = color_start.lerp(color_end, t2)

			var avg_color: Color = c1.lerp(c2, 0.5)
			var width: float = lerpf(3.0, 1.0, t1) * alpha

			draw_line(p1, p2, avg_color, width)


## Draw reload display with physics-based magazine animation.
func _draw_reload_display_v2(center: Vector2) -> void:
	# Draw circular progress in background.
	var bg_color: Color = RELOAD_BG_COLOR
	draw_circle(center, RELOAD_RING_RADIUS + 15, bg_color)

	# Progress ring background.
	draw_arc(center, RELOAD_RING_RADIUS, 0.0, TAU, 64, Color(0.12, 0.12, 0.18, 0.55), RELOAD_RING_WIDTH + 3)

	# Progress ring fill.
	var progress_angle: float = _reload_progress * TAU
	var start_angle: float = -PI * 0.5

	if progress_angle > 0.001:
		draw_arc(center, RELOAD_RING_RADIUS, start_angle, start_angle + progress_angle, 64, RELOAD_PROGRESS_COLOR, RELOAD_RING_WIDTH)

		# Glow at progress tip.
		var tip_angle: float = start_angle + progress_angle
		var tip_pos: Vector2 = center + Vector2(cos(tip_angle), sin(tip_angle)) * RELOAD_RING_RADIUS
		var pulse: float = (sin(_reload_pulse) + 1.0) * 0.5
		var glow_color: Color = RELOAD_GLOW_COLOR
		glow_color.a = 0.45 + pulse * 0.35
		draw_circle(tip_pos, RELOAD_RING_WIDTH * 2.5, glow_color)

	# Draw magazine animation in center.
	_draw_magazine_animation(center)

	# Draw percentage text.
	var font: Font = ThemeDB.fallback_font
	var percent_text: String = "%d%%" % int(_reload_progress * 100)
	var text_size: Vector2 = font.get_string_size(percent_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	var text_pos: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + RELOAD_RING_RADIUS + 25)

	draw_string(font, text_pos, percent_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, RELOAD_TEXT_COLOR)


## Draw physics-based magazine reload animation.
func _draw_magazine_animation(center: Vector2) -> void:
	# Magazine position based on animation state.
	var mag_center: Vector2 = center

	if _mag_out_progress > 0.0 and _mag_out_progress < 1.0:
		# Magazine sliding out and falling.
		mag_center.y += _mag_out_progress * 40.0
		mag_center.x -= _mag_out_progress * 15.0
	elif _mag_in_progress > 0.0:
		# New magazine sliding in from below.
		var ease_progress: float = 1.0 - pow(1.0 - _mag_in_progress, 3.0)
		mag_center.y += (1.0 - ease_progress) * 50.0
		mag_center.x += (1.0 - ease_progress) * 10.0

	# Draw magazine.
	var mag_rect: Rect2 = Rect2(
		mag_center - Vector2(MAGAZINE_WIDTH * 0.5, MAGAZINE_HEIGHT * 0.5),
		Vector2(MAGAZINE_WIDTH, MAGAZINE_HEIGHT)
	)

	# Apply rotation.
	var rotation: float = _mag_rotation

	# Save transform.
	var old_transform: Transform2D = get_viewport_transform()

	# Draw rotated magazine (simplified - just draw rectangle).
	draw_set_transform(mag_center, rotation, Vector2.ONE)

	var local_rect: Rect2 = Rect2(-Vector2(MAGAZINE_WIDTH * 0.5, MAGAZINE_HEIGHT * 0.5), Vector2(MAGAZINE_WIDTH, MAGAZINE_HEIGHT))

	# Magazine body.
	draw_rect(local_rect, MAGAZINE_COLOR)

	# Magazine highlight.
	var highlight: Rect2 = Rect2(local_rect.position + Vector2(2, 2), Vector2(local_rect.size.x * 0.3, local_rect.size.y - 4))
	draw_rect(highlight, MAGAZINE_HIGHLIGHT_COLOR)

	# Magazine ridges.
	for i: int in range(4):
		var ridge_y: float = local_rect.position.y + 8 + i * 10
		draw_line(
			Vector2(local_rect.position.x, ridge_y),
			Vector2(local_rect.position.x + local_rect.size.x, ridge_y),
			Color(0.15, 0.15, 0.2, 0.8),
			1.5
		)

	# Reset transform.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Update magazine physics during reload.
func _update_magazine_physics(delta: float) -> bool:
	var needs_update: bool = false

	if _mag_out_progress > 0.0 and _mag_out_progress < 1.0:
		# Apply gravity to rotation.
		_mag_velocity += MAG_PHYSICS_GRAVITY * delta
		_mag_rotation += _mag_velocity * delta * 0.1
		needs_update = true

	return needs_update


## Update tracer positions.
func _update_tracers(delta: float) -> bool:
	var needs_update: bool = false

	for i: int in range(_tracer_positions.size() - 1, -1, -1):
		var tracer: Dictionary = _tracer_positions[i]
		tracer["life"] = (tracer["life"] as float) - delta

		if (tracer["life"] as float) <= 0.0:
			_tracer_positions.remove_at(i)

		needs_update = true

	return needs_update


## Get digit color based on ammo state.
func _get_digit_color() -> Color:
	if current_ammo == 0:
		return DIGIT_COLOR_EMPTY
	elif _is_critical_ammo():
		return DIGIT_COLOR_CRITICAL
	elif _is_low_ammo():
		return DIGIT_COLOR_LOW
	return DIGIT_COLOR_NORMAL


## Get heat color based on level.
func _get_heat_color(heat: float) -> Color:
	if heat >= HEAT_CRITICAL_THRESHOLD:
		return HEAT_COLOR_CRITICAL
	elif heat >= HEAT_WARNING_THRESHOLD:
		var t: float = (heat - HEAT_WARNING_THRESHOLD) / (HEAT_CRITICAL_THRESHOLD - HEAT_WARNING_THRESHOLD)
		return HEAT_COLOR_HOT.lerp(HEAT_COLOR_CRITICAL, t)
	elif heat >= 0.4:
		var t: float = (heat - 0.4) / (HEAT_WARNING_THRESHOLD - 0.4)
		return HEAT_COLOR_WARM.lerp(HEAT_COLOR_HOT, t)
	else:
		var t: float = heat / 0.4
		return HEAT_COLOR_COOL.lerp(HEAT_COLOR_WARM, t)


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
		_trigger_fire_animation_v2(old_ammo - new_ammo)
	elif new_ammo > old_ammo:
		_trigger_reload_bullet_animation(old_ammo, new_ammo)

	# Empty magazine shake.
	if new_ammo == 0 and old_ammo > 0:
		_trigger_empty_shake()

	queue_redraw()


## Trigger enhanced fire animation.
func _trigger_fire_animation_v2(shots: int) -> void:
	_fire_flash = 0.7

	# Animate scale bounce.
	if _ammo_tween and _ammo_tween.is_valid():
		_ammo_tween.kill()

	_ammo_scale = 1.12
	_ammo_tween = create_tween()
	_ammo_tween.tween_property(self, "_ammo_scale", 1.0, SCALE_BOUNCE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Animate bullets being consumed.
	for i: int in range(current_ammo, current_ammo + shots):
		if i < _bullet_states.size():
			_bullet_states[i]["animating"] = true
			_bullet_states[i]["anim_progress"] = 0.0
			_bullet_states[i]["is_firing"] = true

	# Add tracer for shot.
	_add_tracer()


## Add a tracer visualization.
func _add_tracer() -> void:
	# Random tracer position (simulating bullet trajectory).
	var tracer_start: Vector2 = size * 0.5 + Vector2(randf_range(-30, 30), randf_range(-10, 10))
	var tracer_end: Vector2 = tracer_start + Vector2(randf_range(50, 120), randf_range(-40, 40))

	_tracer_positions.append({
		"start": tracer_start,
		"end": tracer_end,
		"life": TRACER_LIFETIME,
	})

	# Keep only last MAX_TRACERS.
	while _tracer_positions.size() > MAX_TRACERS:
		_tracer_positions.remove_at(0)


## Trigger reload bullet animation.
func _trigger_reload_bullet_animation(old_ammo: int, new_ammo: int) -> void:
	for i: int in range(old_ammo, new_ammo):
		if i < _bullet_states.size():
			_bullet_states[i]["animating"] = true
			_bullet_states[i]["anim_progress"] = 0.0
			_bullet_states[i]["is_firing"] = false


## Trigger empty magazine shake.
func _trigger_empty_shake() -> void:
	_empty_shake = 1.0

	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "_empty_shake", 0.0, 0.5).set_ease(Tween.EASE_OUT)


## Rebuild bullet display array.
func _rebuild_bullet_display() -> void:
	_bullet_states.clear()
	for i: int in range(max_ammo):
		_bullet_states.append({
			"animating": false,
			"anim_progress": 1.0,
			"is_firing": false,
		})


# ── Public API ────────────────────────────────────────────────────────────────

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

	# Check for jam.
	if jam_probability > 0.0 and randf() < jam_probability:
		is_jammed = true
		weapon_jammed.emit()
		return false

	if current_ammo >= amount:
		current_ammo -= amount
		return true

	return false


## Start reload animation with physics.
func start_reload(duration: float) -> void:
	if _is_reloading:
		return

	_is_reloading = true
	_reload_progress = 0.0
	_reload_pulse = 0.0
	_mag_out_progress = 0.0
	_mag_in_progress = 0.0
	_mag_rotation = 0.0
	_mag_velocity = randf_range(-2.0, 2.0)
	is_jammed = false

	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()

	# Magazine out animation (first 30% of reload).
	var mag_out_duration: float = duration * 0.3
	var mag_in_duration: float = duration * 0.3

	_reload_tween = create_tween()

	# Phase 1: Magazine slides out.
	_reload_tween.tween_property(self, "_mag_out_progress", 1.0, mag_out_duration).set_ease(Tween.EASE_IN)

	# Phase 2: Wait briefly.
	_reload_tween.tween_interval(duration * 0.1)

	# Phase 3: New magazine slides in.
	_reload_tween.tween_property(self, "_mag_in_progress", 1.0, mag_in_duration).set_ease(Tween.EASE_OUT)

	# Overall progress.
	var progress_tween: Tween = create_tween()
	progress_tween.tween_property(self, "_reload_progress", 1.0, duration)
	progress_tween.tween_callback(_finish_reload)


## Cancel reload.
func cancel_reload() -> void:
	if not _is_reloading:
		return

	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()

	_is_reloading = false
	_reload_progress = 0.0
	_mag_out_progress = 0.0
	_mag_in_progress = 0.0
	queue_redraw()


## Finish reload and refill ammo.
func _finish_reload() -> void:
	_is_reloading = false
	_reload_progress = 0.0
	_mag_out_progress = 0.0
	_mag_in_progress = 0.0

	if not infinite_ammo:
		var needed: int = max_ammo - current_ammo
		var available: int = mini(needed, reserve_ammo)
		reserve_ammo -= available
		current_ammo += available

	reload_completed.emit()
	queue_redraw()


## Clear weapon jam.
func clear_jam() -> void:
	is_jammed = false
	jam_probability = maxf(jam_probability - 0.1, 0.0)
	queue_redraw()


## Add heat to energy weapon.
func add_heat(amount: float) -> void:
	weapon_heat = minf(weapon_heat + amount, 1.0)


## Cool down energy weapon.
func cool_down(amount: float) -> void:
	weapon_heat = maxf(weapon_heat - amount, 0.0)


## Check if currently reloading.
func is_reloading() -> bool:
	return _is_reloading


## Set infinite ammo mode.
func set_infinite_ammo(enabled: bool) -> void:
	infinite_ammo = enabled
	queue_redraw()


## Set energy weapon mode.
func set_energy_weapon(enabled: bool) -> void:
	is_energy_weapon = enabled
	queue_redraw()


## Full refill.
func refill_all(max_reserve: int = -1) -> void:
	current_ammo = max_ammo
	if max_reserve >= 0:
		reserve_ammo = max_reserve
	weapon_heat = 0.0
	is_jammed = false
	jam_probability = 0.0
	queue_redraw()


## Get reload progress (0.0 to 1.0).
func get_reload_progress() -> float:
	return _reload_progress
