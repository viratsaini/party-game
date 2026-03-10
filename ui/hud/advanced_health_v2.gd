## Ultra-premium competitive health system with AAA-quality effects.
## Features heartbeat animation, electric shield charging, tunnel vision,
## regeneration particles, directional damage tints, overheal golden glow,
## and individual segment animations. Designed for esports-ready FPS HUDs.
class_name AdvancedHealthV2
extends Control

## Signal emitted when health reaches zero.
signal health_depleted
## Signal emitted when health changes.
signal health_changed(new_health: float, max_health: float)
## Signal emitted when critical health state changes.
signal critical_health_changed(is_critical: bool)
## Signal emitted when overheal is active.
signal overheal_active(amount: float)

# ── Health Values ─────────────────────────────────────────────────────────────

## Current health value.
var current_health: float = 100.0:
	set(value):
		var old_health: float = current_health
		current_health = clampf(value, 0.0, max_health + overheal_max)
		_on_health_changed(old_health, current_health)

## Maximum base health value.
var max_health: float = 100.0:
	set(value):
		max_health = maxf(value, 1.0)
		_rebuild_segments()
		queue_redraw()

## Overheal amount (above max health).
var overheal_max: float = 50.0

## Shield/armor amount.
var shield: float = 0.0:
	set(value):
		var old_shield: float = shield
		shield = clampf(value, 0.0, max_shield)
		if shield != old_shield:
			_on_shield_changed(old_shield, shield)

## Maximum shield value.
var max_shield: float = 100.0

## Whether shield is currently charging.
var shield_charging: bool = false:
	set(value):
		shield_charging = value
		if value:
			_charge_phase = 0.0

# ── Display Values ────────────────────────────────────────────────────────────

var _display_health: float = 100.0
var _display_shield: float = 0.0
var _delayed_health: float = 100.0
var _delayed_shield: float = 0.0

# ── Segment Animation State ───────────────────────────────────────────────────

## Number of health segments.
var segment_count: int = 10
## Shield segments.
var shield_segment_count: int = 4

## Per-segment fill values (0.0 to 1.0) with animation states.
var _segment_states: Array[Dictionary] = []
var _shield_segment_states: Array[Dictionary] = []

# ── Animation State ───────────────────────────────────────────────────────────

## Damage flash intensity.
var _damage_flash: float = 0.0

## Heal glow intensity.
var _heal_glow: float = 0.0

## Shield flash intensity.
var _shield_flash: float = 0.0
var _shield_damaged: bool = false

## Critical health effects.
var _critical_pulse: float = 0.0
var _was_critical: bool = false

## Heartbeat animation for critical health.
var _heartbeat_phase: float = 0.0
var _heartbeat_scale: float = 1.0
var _heartbeat_interval: float = 0.0

## Tunnel vision effect intensity.
var _tunnel_vision: float = 0.0
var _tunnel_vision_target: float = 0.0

## Red border pulse for critical health.
var _red_border_pulse: float = 0.0

## Shield charging electric arc effect.
var _charge_phase: float = 0.0
var _arc_positions: Array[Vector2] = []
var _arc_targets: Array[Vector2] = []

## Regeneration animation.
var _is_regenerating: bool = false
var _regen_phase: float = 0.0
var _regen_particles: Array[Dictionary] = []

## Directional damage effect.
var _damage_direction: float = 0.0  ## Angle in radians.
var _damage_tint_intensity: float = 0.0
var _blur_pulse: float = 0.0

## Overheal golden glow.
var _overheal_glow: float = 0.0
var _overheal_halo_phase: float = 0.0

## Screen shake.
var _shake_offset: Vector2 = Vector2.ZERO

# ── Tweens ────────────────────────────────────────────────────────────────────

var _damage_tween: Tween = null
var _heal_tween: Tween = null
var _shield_tween: Tween = null
var _shake_tween: Tween = null
var _heartbeat_tween: Tween = null

# ── Layout Constants ──────────────────────────────────────────────────────────

const BAR_WIDTH: float = 280.0
const BAR_HEIGHT: float = 24.0
const SHIELD_BAR_HEIGHT: float = 10.0
const SEGMENT_GAP: float = 3.0
const INNER_PADDING: float = 4.0
const BORDER_WIDTH: float = 3.0
const CORNER_RADIUS: float = 6.0

# ── Premium Color Palette ─────────────────────────────────────────────────────

## Background colors.
const BG_COLOR: Color = Color(0.06, 0.06, 0.1, 0.92)
const BG_INNER_COLOR: Color = Color(0.03, 0.03, 0.06, 0.95)
const BORDER_COLOR: Color = Color(0.22, 0.22, 0.28, 0.95)
const BORDER_HIGHLIGHT: Color = Color(0.4, 0.4, 0.5, 0.5)

## Health gradient colors.
const HEALTH_COLOR_FULL: Color = Color(0.1, 0.95, 0.35, 1.0)
const HEALTH_COLOR_HIGH: Color = Color(0.35, 0.92, 0.25, 1.0)
const HEALTH_COLOR_MED: Color = Color(0.95, 0.88, 0.12, 1.0)
const HEALTH_COLOR_LOW: Color = Color(0.95, 0.45, 0.12, 1.0)
const HEALTH_COLOR_CRITICAL: Color = Color(0.95, 0.12, 0.12, 1.0)

## Overheal colors.
const OVERHEAL_COLOR: Color = Color(1.0, 0.85, 0.3, 1.0)
const OVERHEAL_GLOW_COLOR: Color = Color(1.0, 0.9, 0.5, 0.6)
const OVERHEAL_HALO_COLOR: Color = Color(1.0, 0.95, 0.7, 0.3)

## Shield colors.
const SHIELD_COLOR_PRIMARY: Color = Color(0.15, 0.7, 1.0, 1.0)
const SHIELD_COLOR_SECONDARY: Color = Color(0.35, 0.88, 1.0, 1.0)
const SHIELD_GLOW_COLOR: Color = Color(0.25, 0.8, 1.0, 0.5)
const SHIELD_CHARGE_COLOR: Color = Color(0.5, 0.95, 1.0, 1.0)
const SHIELD_ARC_COLOR: Color = Color(0.7, 0.95, 1.0, 0.9)

## Effect colors.
const DAMAGE_FLASH_COLOR: Color = Color(1.0, 0.12, 0.08, 0.9)
const DAMAGE_PREVIEW_COLOR: Color = Color(1.0, 0.22, 0.12, 0.65)
const HEAL_GLOW_COLOR: Color = Color(0.25, 1.0, 0.5, 0.75)
const REGEN_GLOW_COLOR: Color = Color(0.35, 1.0, 0.55, 0.85)
const REGEN_PARTICLE_COLOR: Color = Color(0.5, 1.0, 0.7, 0.9)
const SEGMENT_OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const CRITICAL_PULSE_COLOR: Color = Color(1.0, 0.18, 0.12, 0.65)
const CRITICAL_BORDER_COLOR: Color = Color(1.0, 0.15, 0.1, 0.85)

## Tunnel vision / vignette colors.
const TUNNEL_INNER_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const TUNNEL_OUTER_COLOR: Color = Color(0.6, 0.0, 0.0, 0.5)
const DAMAGE_TINT_COLOR: Color = Color(0.8, 0.1, 0.05, 0.4)

## Heartbeat colors.
const HEARTBEAT_COLOR: Color = Color(1.0, 0.2, 0.15, 0.9)

## Thresholds.
const CRITICAL_THRESHOLD: float = 0.2
const LOW_THRESHOLD: float = 0.4
const MED_THRESHOLD: float = 0.7

# ── Timing Constants ──────────────────────────────────────────────────────────

const HEALTH_LERP_SPEED: float = 10.0
const DELAYED_LERP_SPEED: float = 2.0
const FLASH_DECAY_SPEED: float = 5.0
const GLOW_DECAY_SPEED: float = 3.5
const CRITICAL_PULSE_SPEED: float = 7.0
const HEARTBEAT_BPM: float = 120.0  ## Beats per minute at critical.
const TUNNEL_LERP_SPEED: float = 4.0
const CHARGE_ARC_SPEED: float = 12.0
const REGEN_PARTICLE_SPEED: float = 2.5
const OVERHEAL_PULSE_SPEED: float = 3.0
const DAMAGE_TINT_DECAY: float = 2.5
const BLUR_PULSE_DECAY: float = 4.0
const RED_BORDER_PULSE_SPEED: float = 8.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BAR_WIDTH + 60, BAR_HEIGHT + SHIELD_BAR_HEIGHT + 80)

	_display_health = current_health
	_delayed_health = current_health
	_display_shield = shield
	_delayed_shield = shield

	_rebuild_segments()
	_initialize_arc_positions()


func _process(delta: float) -> void:
	var needs_redraw: bool = false

	# Smooth health interpolation.
	if absf(_display_health - current_health) > 0.05:
		_display_health = lerpf(_display_health, current_health, HEALTH_LERP_SPEED * delta)
		needs_redraw = true
	else:
		_display_health = current_health

	# Delayed health catch-up (damage preview).
	if _delayed_health > current_health:
		if absf(_delayed_health - current_health) > 0.05:
			_delayed_health = lerpf(_delayed_health, current_health, DELAYED_LERP_SPEED * delta)
			needs_redraw = true
		else:
			_delayed_health = current_health
	elif _delayed_health < current_health:
		_delayed_health = current_health

	# Shield interpolation.
	if absf(_display_shield - shield) > 0.05:
		_display_shield = lerpf(_display_shield, shield, HEALTH_LERP_SPEED * delta)
		needs_redraw = true
	else:
		_display_shield = shield

	if _delayed_shield > shield:
		_delayed_shield = lerpf(_delayed_shield, shield, DELAYED_LERP_SPEED * delta)
		needs_redraw = true
	elif _delayed_shield < shield:
		_delayed_shield = shield

	# Update segment animations.
	needs_redraw = _update_segment_animations(delta) or needs_redraw

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

	# Damage directional tint decay.
	if _damage_tint_intensity > 0.0:
		_damage_tint_intensity = maxf(_damage_tint_intensity - DAMAGE_TINT_DECAY * delta, 0.0)
		needs_redraw = true

	# Blur pulse decay.
	if _blur_pulse > 0.0:
		_blur_pulse = maxf(_blur_pulse - BLUR_PULSE_DECAY * delta, 0.0)
		needs_redraw = true

	# Critical health effects.
	var is_critical: bool = _is_critical_health()
	if is_critical:
		_critical_pulse = fmod(_critical_pulse + CRITICAL_PULSE_SPEED * delta, TAU)
		_red_border_pulse = fmod(_red_border_pulse + RED_BORDER_PULSE_SPEED * delta, TAU)
		_tunnel_vision_target = 0.85
		_update_heartbeat(delta)
		needs_redraw = true
	else:
		_critical_pulse = 0.0
		_red_border_pulse = 0.0
		_tunnel_vision_target = 0.0
		_heartbeat_scale = 1.0

	# Smooth tunnel vision transition.
	if absf(_tunnel_vision - _tunnel_vision_target) > 0.01:
		_tunnel_vision = lerpf(_tunnel_vision, _tunnel_vision_target, TUNNEL_LERP_SPEED * delta)
		needs_redraw = true
	else:
		_tunnel_vision = _tunnel_vision_target

	# Check for critical state change.
	if is_critical != _was_critical:
		_was_critical = is_critical
		critical_health_changed.emit(is_critical)

	# Shield charging electric arcs.
	if shield_charging:
		_charge_phase = fmod(_charge_phase + CHARGE_ARC_SPEED * delta, TAU)
		_update_arc_positions(delta)
		needs_redraw = true

	# Regeneration animation.
	if _is_regenerating:
		_regen_phase = fmod(_regen_phase + REGEN_PARTICLE_SPEED * delta, 1.0)
		_update_regen_particles(delta)
		needs_redraw = true

	# Overheal glow.
	var overheal_amount: float = maxf(current_health - max_health, 0.0)
	if overheal_amount > 0.0:
		_overheal_glow = lerpf(_overheal_glow, 1.0, delta * 4.0)
		_overheal_halo_phase = fmod(_overheal_halo_phase + OVERHEAL_PULSE_SPEED * delta, TAU)
		needs_redraw = true
	else:
		if _overheal_glow > 0.01:
			_overheal_glow = lerpf(_overheal_glow, 0.0, delta * 6.0)
			needs_redraw = true

	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	var base_pos: Vector2 = Vector2(30, 25) + _shake_offset

	# Draw tunnel vision effect (full screen overlay simulation).
	if _tunnel_vision > 0.01:
		_draw_tunnel_vision()

	# Draw directional damage tint.
	if _damage_tint_intensity > 0.01:
		_draw_directional_damage_tint()

	# Draw shield bar first (above health bar).
	if max_shield > 0.0:
		_draw_shield_bar_v2(base_pos)
		base_pos.y += SHIELD_BAR_HEIGHT + 6

	# Draw main health bar with segments.
	_draw_health_bar_v2(base_pos)

	# Draw heartbeat indicator for critical health.
	if _is_critical_health():
		_draw_heartbeat_indicator(base_pos)

	# Draw overheal halo effect.
	if _overheal_glow > 0.01:
		_draw_overheal_halo(base_pos)

	# Draw health text overlay.
	_draw_health_text_v2(base_pos)


## Draw the main health bar with individual segment animations.
func _draw_health_bar_v2(pos: Vector2) -> void:
	var bar_rect: Rect2 = Rect2(pos, Vector2(BAR_WIDTH, BAR_HEIGHT))

	# Draw background with inner shadow.
	_draw_premium_background(bar_rect)

	var inner_rect: Rect2 = bar_rect.grow(-INNER_PADDING)

	# Draw damage preview (delayed health).
	if _delayed_health > _display_health:
		var preview_percent: float = _delayed_health / max_health
		var preview_width: float = minf(preview_percent, 1.0) * inner_rect.size.x
		var preview_rect: Rect2 = Rect2(inner_rect.position, Vector2(preview_width, inner_rect.size.y))
		draw_rect(preview_rect, DAMAGE_PREVIEW_COLOR)

	# Draw health segments with individual animations.
	_draw_animated_segments(inner_rect)

	# Draw overheal extension.
	var overheal_amount: float = maxf(_display_health - max_health, 0.0)
	if overheal_amount > 0.0:
		_draw_overheal_bar(inner_rect, overheal_amount)

	# Draw healing glow overlay.
	if _heal_glow > 0.0:
		var glow_color: Color = HEAL_GLOW_COLOR
		glow_color.a *= _heal_glow
		var health_percent: float = minf(_display_health / max_health, 1.0)
		var glow_rect: Rect2 = Rect2(inner_rect.position, Vector2(health_percent * inner_rect.size.x, inner_rect.size.y))
		draw_rect(glow_rect, glow_color)

	# Draw regeneration particle effect.
	if _is_regenerating:
		_draw_regen_particles(inner_rect)

	# Draw damage flash overlay.
	if _damage_flash > 0.0:
		var flash_color: Color = DAMAGE_FLASH_COLOR
		flash_color.a *= _damage_flash * 0.65
		draw_rect(bar_rect, flash_color)

	# Draw critical pulse overlay.
	if _is_critical_health():
		var pulse: float = (sin(_critical_pulse) + 1.0) * 0.5
		var pulse_color: Color = CRITICAL_PULSE_COLOR
		pulse_color.a *= pulse * 0.45
		draw_rect(bar_rect, pulse_color)

	# Draw border with potential critical pulsing.
	_draw_bar_border_v2(bar_rect)


## Draw animated health segments.
func _draw_animated_segments(rect: Rect2) -> void:
	var health_percent: float = minf(_display_health / max_health, 1.0)
	var segment_width: float = (rect.size.x - (segment_count - 1) * SEGMENT_GAP) / float(segment_count)
	var base_color: Color = _get_health_color(health_percent)

	for i: int in range(segment_count):
		if i >= _segment_states.size():
			continue

		var state: Dictionary = _segment_states[i]
		var segment_start: float = float(i) / float(segment_count)
		var segment_end: float = float(i + 1) / float(segment_count)

		var x: float = rect.position.x + i * (segment_width + SEGMENT_GAP)
		var segment_rect: Rect2 = Rect2(Vector2(x, rect.position.y), Vector2(segment_width, rect.size.y))

		# Calculate target fill for this segment.
		var target_fill: float = 0.0
		if health_percent >= segment_end:
			target_fill = 1.0
		elif health_percent > segment_start:
			target_fill = (health_percent - segment_start) / (segment_end - segment_start)

		# Get animated fill value.
		var current_fill: float = state.get("fill", 0.0) as float
		var anim_scale: float = state.get("scale", 1.0) as float
		var is_depleting: bool = state.get("depleting", false) as bool
		var is_filling: bool = state.get("filling", false) as bool

		if current_fill > 0.0:
			# Apply scale animation to segment.
			var scaled_rect: Rect2 = segment_rect
			if anim_scale != 1.0:
				var center: Vector2 = segment_rect.get_center()
				scaled_rect.size *= anim_scale
				scaled_rect.position = center - scaled_rect.size * 0.5

			var fill_rect: Rect2 = Rect2(
				scaled_rect.position,
				Vector2(scaled_rect.size.x * current_fill, scaled_rect.size.y)
			)

			# Segment color with gradient variation.
			var seg_color: Color = base_color.lerp(base_color.lightened(0.12), float(i) / float(segment_count) * 0.4)

			# Add glow for filling segments.
			if is_filling:
				seg_color = seg_color.lerp(HEAL_GLOW_COLOR, 0.3)

			# Add flash for depleting segments.
			if is_depleting:
				seg_color = seg_color.lerp(DAMAGE_FLASH_COLOR, 0.4)

			_draw_segment_gradient(fill_rect, seg_color, seg_color.lightened(0.18))
			_draw_segment_shine(fill_rect)

		# Draw segment outline.
		draw_rect(segment_rect, SEGMENT_OUTLINE_COLOR, false, 1.5)


## Draw segment with gradient fill.
func _draw_segment_gradient(rect: Rect2, top_color: Color, _bottom_color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y)
	])
	var colors: PackedColorArray = PackedColorArray([
		top_color.lightened(0.12),
		top_color.lightened(0.12),
		top_color.darkened(0.12),
		top_color.darkened(0.12)
	])
	draw_polygon(points, colors)


## Draw shine effect on segment.
func _draw_segment_shine(rect: Rect2) -> void:
	if rect.size.x <= 0:
		return

	var shine_rect: Rect2 = Rect2(
		rect.position + Vector2(1, 1),
		Vector2(rect.size.x - 2, rect.size.y * 0.32)
	)
	draw_rect(shine_rect, Color(1.0, 1.0, 1.0, 0.18))


## Draw overheal bar extension.
func _draw_overheal_bar(base_rect: Rect2, overheal_amount: float) -> void:
	var overheal_percent: float = overheal_amount / overheal_max
	var overheal_width: float = overheal_percent * base_rect.size.x * 0.3  # Max 30% extension.

	var overheal_rect: Rect2 = Rect2(
		base_rect.position + Vector2(base_rect.size.x + 4, 0),
		Vector2(overheal_width, base_rect.size.y)
	)

	# Golden glow background.
	var glow_rect: Rect2 = overheal_rect.grow(3)
	var glow_color: Color = OVERHEAL_GLOW_COLOR
	glow_color.a *= _overheal_glow * 0.6
	draw_rect(glow_rect, glow_color)

	# Overheal bar.
	var pulse: float = (sin(_overheal_halo_phase) + 1.0) * 0.5
	var bar_color: Color = OVERHEAL_COLOR.lerp(OVERHEAL_COLOR.lightened(0.2), pulse * 0.3)
	draw_rect(overheal_rect, bar_color)

	# Shine.
	var shine_rect: Rect2 = Rect2(overheal_rect.position, Vector2(overheal_rect.size.x, overheal_rect.size.y * 0.35))
	draw_rect(shine_rect, Color(1.0, 1.0, 1.0, 0.25))


## Draw overheal halo effect around health bar.
func _draw_overheal_halo(bar_pos: Vector2) -> void:
	var bar_rect: Rect2 = Rect2(bar_pos, Vector2(BAR_WIDTH, BAR_HEIGHT))
	var center: Vector2 = bar_rect.get_center()

	var pulse: float = (sin(_overheal_halo_phase) + 1.0) * 0.5
	var halo_size: float = bar_rect.size.x * 0.6 + pulse * 20.0

	# Draw expanding halo rings.
	for i: int in range(3):
		var ring_size: float = halo_size + i * 15.0
		var ring_alpha: float = (1.0 - float(i) / 3.0) * 0.2 * _overheal_glow
		var ring_color: Color = OVERHEAL_HALO_COLOR
		ring_color.a = ring_alpha
		draw_arc(center, ring_size, 0.0, TAU, 32, ring_color, 2.0)


## Draw shield bar with charging effects.
func _draw_shield_bar_v2(pos: Vector2) -> void:
	var bar_rect: Rect2 = Rect2(pos, Vector2(BAR_WIDTH, SHIELD_BAR_HEIGHT))

	# Background.
	draw_rect(bar_rect, BG_COLOR)

	var inner_rect: Rect2 = bar_rect.grow(-2)

	# Draw shield preview (delayed).
	if _delayed_shield > _display_shield:
		var preview_percent: float = _delayed_shield / max_shield
		var preview_width: float = preview_percent * inner_rect.size.x
		var preview_rect: Rect2 = Rect2(inner_rect.position, Vector2(preview_width, inner_rect.size.y))
		var preview_color: Color = SHIELD_COLOR_PRIMARY
		preview_color.a = 0.4
		draw_rect(preview_rect, preview_color)

	# Draw shield segments.
	if _display_shield > 0.0:
		var shield_percent: float = _display_shield / max_shield
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

				var color: Color = SHIELD_COLOR_PRIMARY.lerp(SHIELD_COLOR_SECONDARY, float(i) / float(shield_segment_count))

				# Add charging glow.
				if shield_charging:
					var charge_pulse: float = (sin(_charge_phase + float(i) * 0.5) + 1.0) * 0.5
					color = color.lerp(SHIELD_CHARGE_COLOR, charge_pulse * 0.4)

				draw_rect(fill_rect, color)

				# Shine.
				var shine_rect: Rect2 = Rect2(fill_rect.position, Vector2(fill_rect.size.x, fill_rect.size.y * 0.4))
				draw_rect(shine_rect, Color(1.0, 1.0, 1.0, 0.22))

			draw_rect(segment_rect, SEGMENT_OUTLINE_COLOR, false, 1.0)

	# Draw electric arcs when charging.
	if shield_charging:
		_draw_electric_arcs(inner_rect)

	# Shield flash overlay.
	if _shield_flash > 0.0:
		var flash_color: Color = SHIELD_COLOR_PRIMARY if not _shield_damaged else DAMAGE_FLASH_COLOR
		flash_color.a = _shield_flash * 0.55
		draw_rect(bar_rect, flash_color)

	# Border.
	var border_color: Color = BORDER_COLOR
	if shield_charging:
		var pulse: float = (sin(_charge_phase * 2.0) + 1.0) * 0.5
		border_color = border_color.lerp(SHIELD_CHARGE_COLOR, pulse * 0.5)
	draw_rect(bar_rect, border_color, false, 2.0)


## Draw electric arc effect for shield charging.
func _draw_electric_arcs(rect: Rect2) -> void:
	var arc_color: Color = SHIELD_ARC_COLOR

	for i: int in range(_arc_positions.size()):
		var start: Vector2 = _arc_positions[i]
		var target: Vector2 = _arc_targets[i]

		# Draw jagged lightning line.
		var points: PackedVector2Array = PackedVector2Array()
		points.append(rect.position + start * rect.size)

		var segments: int = 4
		for j: int in range(1, segments):
			var t: float = float(j) / float(segments)
			var mid: Vector2 = start.lerp(target, t)
			mid += Vector2(randf_range(-0.08, 0.08), randf_range(-0.15, 0.15))
			points.append(rect.position + mid * rect.size)

		points.append(rect.position + target * rect.size)

		# Draw glow.
		var glow_color: Color = arc_color
		glow_color.a = 0.3
		draw_polyline(points, glow_color, 4.0)

		# Draw core.
		draw_polyline(points, arc_color, 1.5)


## Draw heartbeat indicator for critical health.
func _draw_heartbeat_indicator(bar_pos: Vector2) -> void:
	var indicator_pos: Vector2 = bar_pos + Vector2(-25, BAR_HEIGHT * 0.5)

	# Scale with heartbeat.
	var base_size: float = 10.0 * _heartbeat_scale

	# Draw heart shape (simplified as diamond).
	var heart_color: Color = HEARTBEAT_COLOR
	var pulse: float = (_heartbeat_scale - 1.0) * 2.0
	heart_color.a = 0.6 + pulse * 0.4

	var points: PackedVector2Array = PackedVector2Array([
		indicator_pos + Vector2(0, -base_size),
		indicator_pos + Vector2(base_size * 0.7, 0),
		indicator_pos + Vector2(0, base_size),
		indicator_pos + Vector2(-base_size * 0.7, 0),
	])
	var colors: PackedColorArray = PackedColorArray([heart_color, heart_color, heart_color, heart_color])
	draw_polygon(points, colors)

	# Draw glow when beating.
	if _heartbeat_scale > 1.0:
		var glow_color: Color = HEARTBEAT_COLOR
		glow_color.a = pulse * 0.5
		draw_circle(indicator_pos, base_size * 1.5, glow_color)


## Draw tunnel vision / vignette effect.
func _draw_tunnel_vision() -> void:
	var center: Vector2 = size * 0.5
	var max_radius: float = size.length() * 0.5
	var inner_radius: float = max_radius * (1.0 - _tunnel_vision * 0.6)

	# Draw radial gradient vignette (approximated with concentric rings).
	var rings: int = 20
	for i: int in range(rings):
		var t: float = float(i) / float(rings)
		var radius: float = lerpf(inner_radius, max_radius, t)
		var alpha: float = t * t * _tunnel_vision * 0.7

		var ring_color: Color = TUNNEL_OUTER_COLOR
		ring_color.a = alpha

		draw_arc(center, radius, 0.0, TAU, 32, ring_color, max_radius / float(rings) + 2.0)

	# Add pulsing red overlay at edges.
	var pulse: float = (sin(_critical_pulse) + 1.0) * 0.5
	var edge_color: Color = CRITICAL_PULSE_COLOR
	edge_color.a = pulse * _tunnel_vision * 0.3

	# Draw edge rectangles.
	var edge_size: float = 60.0 * _tunnel_vision
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, edge_size)), edge_color)
	draw_rect(Rect2(Vector2(0, size.y - edge_size), Vector2(size.x, edge_size)), edge_color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(edge_size, size.y)), edge_color)
	draw_rect(Rect2(Vector2(size.x - edge_size, 0), Vector2(edge_size, size.y)), edge_color)


## Draw directional damage tint based on damage direction.
func _draw_directional_damage_tint() -> void:
	var center: Vector2 = size * 0.5
	var tint_color: Color = DAMAGE_TINT_COLOR
	tint_color.a *= _damage_tint_intensity

	# Calculate direction vector.
	var dir: Vector2 = Vector2(cos(_damage_direction), sin(_damage_direction))

	# Draw gradient from damage direction.
	var edge_pos: Vector2 = center + dir * size.length() * 0.5
	var perpendicular: Vector2 = dir.orthogonal()

	# Create a wedge shape for directional tint.
	var spread: float = PI * 0.4
	var inner_dist: float = size.length() * 0.3
	var outer_dist: float = size.length() * 0.6

	for i: int in range(10):
		var angle_offset: float = lerpf(-spread, spread, float(i) / 9.0)
		var angle: float = _damage_direction + angle_offset

		var outer_point: Vector2 = center + Vector2(cos(angle), sin(angle)) * outer_dist
		var wedge_color: Color = tint_color
		wedge_color.a *= 1.0 - absf(float(i) - 4.5) / 4.5

		draw_line(center + Vector2(cos(angle), sin(angle)) * inner_dist, outer_point, wedge_color, 15.0)


## Draw bar border with critical pulsing.
func _draw_bar_border_v2(rect: Rect2) -> void:
	var border_color: Color = BORDER_COLOR

	if _is_critical_health():
		var pulse: float = (sin(_red_border_pulse) + 1.0) * 0.5
		border_color = border_color.lerp(CRITICAL_BORDER_COLOR, pulse * 0.8)

	draw_rect(rect, border_color, false, BORDER_WIDTH)

	# Top highlight.
	var highlight_rect: Rect2 = Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6, 1))
	draw_rect(highlight_rect, BORDER_HIGHLIGHT)


## Draw premium background with inner shadow.
func _draw_premium_background(rect: Rect2) -> void:
	draw_rect(rect, BG_COLOR)
	var inner: Rect2 = rect.grow(-INNER_PADDING)
	draw_rect(inner, BG_INNER_COLOR)


## Draw regeneration particle effects.
func _draw_regen_particles(rect: Rect2) -> void:
	var health_percent: float = minf(_display_health / max_health, 1.0)
	var fill_edge_x: float = rect.position.x + health_percent * rect.size.x

	for particle: Dictionary in _regen_particles:
		var pos: Vector2 = particle.get("pos", Vector2.ZERO) as Vector2
		var life: float = particle.get("life", 0.0) as float
		var particle_size: float = particle.get("size", 3.0) as float

		# Particle position relative to fill edge.
		var screen_pos: Vector2 = Vector2(
			fill_edge_x - 10.0 + pos.x * 20.0,
			rect.position.y + pos.y * rect.size.y
		)

		var alpha: float = life * 0.9
		var color: Color = REGEN_PARTICLE_COLOR
		color.a = alpha

		draw_circle(screen_pos, particle_size * life, color)


## Draw health text overlay.
func _draw_health_text_v2(bar_pos: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var bar_rect: Rect2 = Rect2(bar_pos, Vector2(BAR_WIDTH, BAR_HEIGHT))

	# Current health.
	var display_value: int = int(_display_health)
	var health_text: String = "%d" % display_value
	var max_text: String = " / %d" % int(max_health)

	# Add overheal indicator.
	if _display_health > max_health:
		health_text = "%d (+%d)" % [int(max_health), int(_display_health - max_health)]
		max_text = ""

	var health_size: Vector2 = font.get_string_size(health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var max_size: Vector2 = font.get_string_size(max_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

	var total_width: float = health_size.x + max_size.x
	var text_x: float = bar_rect.position.x + (bar_rect.size.x - total_width) * 0.5
	var text_y: float = bar_rect.position.y + bar_rect.size.y * 0.5 + health_size.y * 0.32

	# Health color based on amount.
	var health_percent: float = minf(_display_health / max_health, 1.0)
	var text_color: Color = _get_health_color(health_percent)

	# Overheal golden color.
	if _display_health > max_health:
		text_color = OVERHEAL_COLOR

	# Critical pulsing.
	if _is_critical_health():
		var pulse: float = (sin(_critical_pulse) + 1.0) * 0.5
		text_color = text_color.lerp(Color.WHITE, pulse * 0.35)

	# Shadow.
	draw_string(font, Vector2(text_x + 1, text_y + 1), health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.85))
	# Main text.
	draw_string(font, Vector2(text_x, text_y), health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)

	# Max health (smaller, gray).
	if max_text != "":
		draw_string(font, Vector2(text_x + health_size.x + 1, text_y + 1), max_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.65))
		draw_string(font, Vector2(text_x + health_size.x, text_y), max_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.72, 0.72, 0.92))


# ── Helper Functions ──────────────────────────────────────────────────────────

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


## Rebuild segment states array.
func _rebuild_segments() -> void:
	_segment_states.clear()
	for i: int in range(segment_count):
		_segment_states.append({
			"fill": 1.0,
			"target_fill": 1.0,
			"scale": 1.0,
			"depleting": false,
			"filling": false,
		})

	_shield_segment_states.clear()
	for i: int in range(shield_segment_count):
		_shield_segment_states.append({
			"fill": 0.0,
			"scale": 1.0,
		})


## Initialize electric arc positions.
func _initialize_arc_positions() -> void:
	_arc_positions.clear()
	_arc_targets.clear()

	for i: int in range(3):
		_arc_positions.append(Vector2(randf(), randf()))
		_arc_targets.append(Vector2(randf(), randf()))


## Update segment animations.
func _update_segment_animations(delta: float) -> bool:
	var needs_redraw: bool = false
	var health_percent: float = minf(_display_health / max_health, 1.0)

	for i: int in range(segment_count):
		if i >= _segment_states.size():
			continue

		var state: Dictionary = _segment_states[i]
		var segment_start: float = float(i) / float(segment_count)
		var segment_end: float = float(i + 1) / float(segment_count)

		# Calculate target fill.
		var target_fill: float = 0.0
		if health_percent >= segment_end:
			target_fill = 1.0
		elif health_percent > segment_start:
			target_fill = (health_percent - segment_start) / (segment_end - segment_start)

		var current_fill: float = state.get("fill", 0.0) as float
		var current_scale: float = state.get("scale", 1.0) as float

		# Animate fill change.
		if absf(current_fill - target_fill) > 0.01:
			var is_depleting: bool = current_fill > target_fill
			var is_filling: bool = current_fill < target_fill

			state["depleting"] = is_depleting
			state["filling"] = is_filling

			var speed: float = 6.0 if is_depleting else 4.0
			state["fill"] = lerpf(current_fill, target_fill, speed * delta)

			# Scale bounce on change.
			if is_depleting:
				state["scale"] = lerpf(current_scale, 0.9, delta * 8.0)
			elif is_filling:
				state["scale"] = lerpf(current_scale, 1.1, delta * 6.0)

			needs_redraw = true
		else:
			state["fill"] = target_fill
			state["depleting"] = false
			state["filling"] = false

			# Return scale to normal.
			if absf(current_scale - 1.0) > 0.01:
				state["scale"] = lerpf(current_scale, 1.0, delta * 10.0)
				needs_redraw = true

	return needs_redraw


## Update heartbeat animation.
func _update_heartbeat(delta: float) -> void:
	var bps: float = HEARTBEAT_BPM / 60.0
	_heartbeat_interval += delta

	if _heartbeat_interval >= 1.0 / bps:
		_heartbeat_interval = 0.0
		_trigger_heartbeat_pulse()


## Trigger a single heartbeat pulse.
func _trigger_heartbeat_pulse() -> void:
	if _heartbeat_tween and _heartbeat_tween.is_valid():
		_heartbeat_tween.kill()

	_heartbeat_tween = create_tween()
	_heartbeat_tween.tween_property(self, "_heartbeat_scale", 1.35, 0.08).set_ease(Tween.EASE_OUT)
	_heartbeat_tween.tween_property(self, "_heartbeat_scale", 1.0, 0.15).set_ease(Tween.EASE_IN)


## Update electric arc positions for charging effect.
func _update_arc_positions(delta: float) -> void:
	for i: int in range(_arc_positions.size()):
		var current: Vector2 = _arc_positions[i]
		var target: Vector2 = _arc_targets[i]

		# Move toward target.
		_arc_positions[i] = current.lerp(target, delta * 8.0)

		# If close to target, pick new target.
		if current.distance_to(target) < 0.05:
			_arc_targets[i] = Vector2(randf(), randf())


## Update regeneration particles.
func _update_regen_particles(delta: float) -> void:
	# Spawn new particles.
	if randf() < delta * 15.0:
		_regen_particles.append({
			"pos": Vector2(randf(), randf()),
			"life": 1.0,
			"size": randf_range(2.0, 5.0),
			"vel": Vector2(randf_range(-0.5, 0.5), randf_range(-1.0, -0.3)),
		})

	# Update existing particles.
	for i: int in range(_regen_particles.size() - 1, -1, -1):
		var particle: Dictionary = _regen_particles[i]
		particle["life"] = (particle["life"] as float) - delta * 1.5
		var vel: Vector2 = particle.get("vel", Vector2.ZERO) as Vector2
		particle["pos"] = (particle["pos"] as Vector2) + vel * delta

		if (particle["life"] as float) <= 0.0:
			_regen_particles.remove_at(i)


## Handle health change.
func _on_health_changed(old_health: float, new_health: float) -> void:
	health_changed.emit(new_health, max_health)

	if new_health < old_health:
		_trigger_damage_effects(old_health - new_health)
	elif new_health > old_health:
		_trigger_heal_effects()

	# Check overheal.
	if new_health > max_health:
		overheal_active.emit(new_health - max_health)

	if new_health <= 0.0:
		health_depleted.emit()

	queue_redraw()


## Handle shield change.
func _on_shield_changed(old_shield: float, new_shield: float) -> void:
	_shield_flash = 1.0
	_shield_damaged = new_shield < old_shield


## Trigger damage visual effects.
func _trigger_damage_effects(damage_amount: float) -> void:
	var intensity: float = clampf(damage_amount / 50.0, 0.5, 1.0)
	_damage_flash = intensity
	_blur_pulse = intensity * 0.6

	# Random damage direction (in a real game, this would come from the attacker).
	_damage_direction = randf() * TAU
	_damage_tint_intensity = intensity * 0.8

	# Trigger screen shake for heavy damage.
	if damage_amount >= 15.0:
		_trigger_shake(damage_amount)


## Trigger heal visual effects.
func _trigger_heal_effects() -> void:
	_heal_glow = 1.0
	_delayed_health = current_health


## Trigger screen shake.
func _trigger_shake(damage: float) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	var intensity: float = clampf(damage / 30.0, 0.25, 1.0) * 6.0

	_shake_tween = create_tween()
	_shake_tween.tween_method(_apply_shake.bind(intensity), 1.0, 0.0, 0.35)
	_shake_tween.tween_callback(func() -> void: _shake_offset = Vector2.ZERO)


## Apply shake offset.
func _apply_shake(progress: float, intensity: float) -> void:
	var shake: float = intensity * progress
	_shake_offset = Vector2(
		randf_range(-shake, shake),
		randf_range(-shake, shake)
	)
	queue_redraw()


# ── Public API ────────────────────────────────────────────────────────────────

## Set health values.
func set_health(current: float, maximum: float) -> void:
	max_health = maximum
	current_health = current


## Set shield values.
func set_shield_values(current: float, maximum: float = -1.0) -> void:
	if maximum > 0.0:
		max_shield = maximum
	shield = current


## Apply damage from a direction (angle in radians).
func apply_damage_from_direction(amount: float, direction: float) -> void:
	_damage_direction = direction
	current_health -= amount


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
	_regen_particles.clear()


## Stop regeneration animation.
func stop_regeneration() -> void:
	_is_regenerating = false
	_regen_particles.clear()


## Start shield charging effect.
func start_shield_charging() -> void:
	shield_charging = true


## Stop shield charging effect.
func stop_shield_charging() -> void:
	shield_charging = false


## Apply overheal.
func apply_overheal(amount: float) -> void:
	current_health = minf(current_health + amount, max_health + overheal_max)


## Reset to full health.
func reset_to_full() -> void:
	_display_health = max_health
	_delayed_health = max_health
	_display_shield = max_shield
	_delayed_shield = max_shield
	current_health = max_health
	shield = max_shield if max_shield > 0 else 0.0
	_damage_flash = 0.0
	_heal_glow = 0.0
	_shield_flash = 0.0
	_critical_pulse = 0.0
	_tunnel_vision = 0.0
	_tunnel_vision_target = 0.0
	_heartbeat_scale = 1.0
	_overheal_glow = 0.0
	_damage_tint_intensity = 0.0
	_blur_pulse = 0.0
	_shake_offset = Vector2.ZERO
	_is_regenerating = false
	_regen_particles.clear()
	shield_charging = false
	queue_redraw()
