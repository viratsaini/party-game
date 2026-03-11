## Premium directional damage indicator system.
## Features 3D perspective arrows, intensity-based colors, fade trails,
## screen crack effects, blur/chromatic aberration overlays, and premium animations.
## Designed for competitive mobile game quality (PUBG/CoD/Apex style).
class_name DamageIndicator
extends Control

## Signal emitted when heavy damage is taken (for external screen effects).
signal heavy_damage_taken(damage: float, direction: float)

## Signal emitted for critical damage (for camera shake triggers).
signal critical_damage_taken(damage: float)

## Duration in seconds before an indicator starts fading.
const INDICATOR_DURATION: float = 2.0
## Time for the fade-out animation.
const FADE_DURATION: float = 0.6
## Distance from screen center where indicators are drawn.
const INDICATOR_DISTANCE: float = 180.0
## Base size of each indicator arrow.
const BASE_ARROW_SIZE: float = 50.0
## Maximum number of simultaneous indicators.
const MAX_INDICATORS: int = 12
## Heavy damage threshold for screen effects.
const HEAVY_DAMAGE_THRESHOLD: float = 30.0
## Critical damage threshold.
const CRITICAL_DAMAGE_THRESHOLD: float = 50.0

## Active damage indicators.
var _indicators: Array[Dictionary] = []

## Reference to the local player for calculating relative directions.
var _local_player: Node3D = null

## Screen effect state.
var _screen_crack_intensity: float = 0.0
var _chromatic_aberration: float = 0.0
var _vignette_intensity: float = 0.0
var _blur_intensity: float = 0.0

## Global damage flash.
var _damage_flash: float = 0.0

## Screen shake offset (for use by parent).
var screen_shake_offset: Vector2 = Vector2.ZERO

# ── Color Palette ────────────────────────────────────────────────────────────

## Damage indicator gradient (low to high damage).
const COLOR_LOW_DAMAGE: Color = Color(1.0, 0.7, 0.3, 0.7)
const COLOR_MED_DAMAGE: Color = Color(1.0, 0.4, 0.2, 0.85)
const COLOR_HIGH_DAMAGE: Color = Color(1.0, 0.15, 0.1, 0.95)
const COLOR_CRITICAL_DAMAGE: Color = Color(1.0, 0.05, 0.05, 1.0)

## Glow colors.
const GLOW_COLOR: Color = Color(1.0, 0.3, 0.1, 0.4)
const TRAIL_COLOR: Color = Color(1.0, 0.2, 0.1, 0.3)

## Screen effect colors.
const VIGNETTE_COLOR: Color = Color(0.6, 0.0, 0.0, 0.5)
const FLASH_COLOR: Color = Color(1.0, 0.2, 0.1, 0.4)
const CRACK_COLOR: Color = Color(0.1, 0.0, 0.0, 0.8)

# ── Timing Constants ─────────────────────────────────────────────────────────

const EFFECT_DECAY_SPEED: float = 2.0
const FLASH_DECAY_SPEED: float = 4.0
const BLUR_DECAY_SPEED: float = 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var needs_redraw: bool = false

	# Update all indicators.
	var i: int = _indicators.size() - 1
	while i >= 0:
		var indicator: Dictionary = _indicators[i]
		indicator["time_remaining"] = (indicator["time_remaining"] as float) - delta

		if indicator["time_remaining"] <= 0.0:
			_indicators.remove_at(i)
			needs_redraw = true
		else:
			# Update intensity based on remaining time.
			if indicator["time_remaining"] < FADE_DURATION:
				indicator["intensity"] = indicator["time_remaining"] / FADE_DURATION
				needs_redraw = true

			# Update trail effect.
			if indicator.has("trail_positions"):
				var trail: Array = indicator["trail_positions"] as Array
				# Decay trail.
				for j: int in range(trail.size() - 1, -1, -1):
					trail[j]["alpha"] = (trail[j]["alpha"] as float) * 0.95
					if (trail[j]["alpha"] as float) < 0.05:
						trail.remove_at(j)
				needs_redraw = true

			# Update pulse for fresh indicators.
			if indicator.has("pulse_phase"):
				indicator["pulse_phase"] = fmod((indicator["pulse_phase"] as float) + delta * 6.0, TAU)
				needs_redraw = true

		i -= 1

	# Decay screen effects.
	if _screen_crack_intensity > 0.0:
		_screen_crack_intensity = maxf(_screen_crack_intensity - EFFECT_DECAY_SPEED * delta, 0.0)
		needs_redraw = true

	if _chromatic_aberration > 0.0:
		_chromatic_aberration = maxf(_chromatic_aberration - EFFECT_DECAY_SPEED * delta, 0.0)
		needs_redraw = true

	if _vignette_intensity > 0.0:
		_vignette_intensity = maxf(_vignette_intensity - EFFECT_DECAY_SPEED * delta, 0.0)
		needs_redraw = true

	if _blur_intensity > 0.0:
		_blur_intensity = maxf(_blur_intensity - BLUR_DECAY_SPEED * delta, 0.0)
		needs_redraw = true

	if _damage_flash > 0.0:
		_damage_flash = maxf(_damage_flash - FLASH_DECAY_SPEED * delta, 0.0)
		needs_redraw = true

	if needs_redraw or not _indicators.is_empty():
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5

	# Draw screen effects first (background layer).
	_draw_screen_effects(center)

	# Draw damage indicators.
	if not _indicators.is_empty():
		for indicator: Dictionary in _indicators:
			_draw_indicator(center, indicator)


## Draw screen-wide damage effects.
func _draw_screen_effects(center: Vector2) -> void:
	# Damage flash overlay.
	if _damage_flash > 0.0:
		var flash_color: Color = FLASH_COLOR
		flash_color.a *= _damage_flash
		draw_rect(Rect2(Vector2.ZERO, size), flash_color)

	# Vignette effect.
	if _vignette_intensity > 0.0:
		_draw_vignette(_vignette_intensity)

	# Screen crack effect.
	if _screen_crack_intensity > 0.0:
		_draw_screen_cracks(center, _screen_crack_intensity)

	# Chromatic aberration indicator (visual hint - actual effect needs shader).
	if _chromatic_aberration > 0.0:
		_draw_chromatic_hint(center, _chromatic_aberration)


## Draw vignette effect.
func _draw_vignette(intensity: float) -> void:
	var edge_width: float = 80.0 + intensity * 60.0
	var alpha: float = intensity * VIGNETTE_COLOR.a

	# Create gradient rectangles for edges.
	var vignette_color: Color = VIGNETTE_COLOR
	vignette_color.a = alpha

	# Draw using multiple overlapping rectangles with decreasing alpha.
	var steps: int = 8
	for i: int in range(steps):
		var step_alpha: float = alpha * (1.0 - float(i) / float(steps))
		var step_width: float = edge_width * (1.0 - float(i) / float(steps))
		var col: Color = Color(VIGNETTE_COLOR.r, VIGNETTE_COLOR.g, VIGNETTE_COLOR.b, step_alpha)

		# Top.
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, step_width)), col)
		# Bottom.
		draw_rect(Rect2(Vector2(0, size.y - step_width), Vector2(size.x, step_width)), col)
		# Left.
		draw_rect(Rect2(Vector2.ZERO, Vector2(step_width, size.y)), col)
		# Right.
		draw_rect(Rect2(Vector2(size.x - step_width, 0), Vector2(step_width, size.y)), col)


## Draw screen crack effect.
func _draw_screen_cracks(center: Vector2, intensity: float) -> void:
	var crack_color: Color = CRACK_COLOR
	crack_color.a *= intensity

	# Generate procedural cracks from impact point (center).
	var crack_count: int = int(3 + intensity * 4)
	var seed_val: int = 12345  # Consistent random for visual stability.

	for i: int in range(crack_count):
		var angle: float = (float(i) / float(crack_count)) * TAU + sin(float(seed_val + i)) * 0.5
		var length: float = 100.0 + intensity * 150.0 + cos(float(seed_val + i * 2)) * 50.0

		var current: Vector2 = center

		# Draw branching crack line.
		var segments: int = 4 + i % 3
		for j: int in range(segments):
			var segment_angle: float = angle + sin(float(j + seed_val + i)) * 0.4
			var segment_length: float = length / float(segments) * (1.0 + sin(float(j * 3 + seed_val)) * 0.3)
			var next: Vector2 = current + Vector2(cos(segment_angle), sin(segment_angle)) * segment_length

			var line_width: float = (2.0 - float(j) * 0.3) * intensity
			draw_line(current, next, crack_color, maxf(line_width, 0.5))

			# Branch lines.
			if j > 0 and j % 2 == 0:
				var branch_angle: float = segment_angle + (0.5 if i % 2 == 0 else -0.5)
				var branch_length: float = segment_length * 0.5
				var branch_end: Vector2 = current + Vector2(cos(branch_angle), sin(branch_angle)) * branch_length
				draw_line(current, branch_end, crack_color, line_width * 0.5)

			current = next


## Draw chromatic aberration hint (edge color separation).
func _draw_chromatic_hint(_center: Vector2, intensity: float) -> void:
	var alpha: float = intensity * 0.3

	# Draw colored edge hints.
	var edge_width: float = 20.0

	# Red shift on one side.
	var red_color: Color = Color(1.0, 0.0, 0.0, alpha)
	draw_rect(Rect2(Vector2.ZERO, Vector2(edge_width, size.y)), red_color)

	# Cyan shift on other side.
	var cyan_color: Color = Color(0.0, 1.0, 1.0, alpha)
	draw_rect(Rect2(Vector2(size.x - edge_width, 0), Vector2(edge_width, size.y)), cyan_color)


## Draw a single damage indicator.
func _draw_indicator(center: Vector2, indicator: Dictionary) -> void:
	var angle: float = indicator["angle"] as float
	var intensity: float = indicator["intensity"] as float
	var damage: float = indicator.get("damage_amount", 25.0) as float

	# Calculate arrow properties based on damage.
	var damage_ratio: float = clampf(damage / CRITICAL_DAMAGE_THRESHOLD, 0.0, 1.0)
	var arrow_scale: float = 0.7 + damage_ratio * 0.6
	var arrow_size: float = BASE_ARROW_SIZE * arrow_scale

	# Get color based on damage amount.
	var arrow_color: Color = _get_damage_color(damage)
	arrow_color.a *= intensity

	# Calculate position.
	var direction: Vector2 = Vector2(cos(angle), sin(angle))
	var distance: float = INDICATOR_DISTANCE + damage_ratio * 30.0
	var pos: Vector2 = center + direction * distance

	# Draw trail effect.
	if indicator.has("trail_positions"):
		_draw_trail(indicator["trail_positions"] as Array, angle, arrow_size * 0.8)

	# Draw glow layer.
	_draw_arrow_glow(pos, angle, arrow_size * 1.3, arrow_color, intensity)

	# Draw main 3D-style arrow.
	_draw_3d_arrow(pos, angle, arrow_size, arrow_color, intensity)

	# Draw pulse effect for fresh damage.
	if indicator.has("pulse_phase"):
		var pulse: float = (sin(indicator["pulse_phase"] as float) + 1.0) * 0.5
		if pulse > 0.5:
			_draw_pulse_ring(pos, arrow_size, arrow_color, (pulse - 0.5) * 2.0 * intensity)


## Draw 3D-perspective arrow.
func _draw_3d_arrow(pos: Vector2, angle: float, arrow_size: float, color: Color, _intensity: float) -> void:
	var half_size: float = arrow_size * 0.5

	# Arrow tip points toward center (opposite of damage direction).
	var tip_direction: Vector2 = Vector2(cos(angle + PI), sin(angle + PI))
	var perpendicular: Vector2 = Vector2(-tip_direction.y, tip_direction.x)

	# Main arrow shape with 3D perspective effect.
	var tip: Vector2 = pos + tip_direction * half_size

	# Back corners - wider for 3D effect.
	var back_offset: float = half_size * 0.8
	var side_offset: float = half_size * 0.5

	var back_left: Vector2 = pos - tip_direction * back_offset + perpendicular * side_offset
	var back_right: Vector2 = pos - tip_direction * back_offset - perpendicular * side_offset

	# Inner notch for arrow shape.
	var notch_depth: float = half_size * 0.3
	var notch: Vector2 = pos - tip_direction * notch_depth

	# Draw shadow layer for 3D effect.
	var shadow_offset: Vector2 = Vector2(2, 2)
	var shadow_color: Color = Color(0.0, 0.0, 0.0, color.a * 0.4)
	var shadow_points: PackedVector2Array = PackedVector2Array([
		tip + shadow_offset,
		back_left + shadow_offset,
		notch + shadow_offset,
		back_right + shadow_offset
	])
	draw_polygon(shadow_points, PackedColorArray([shadow_color, shadow_color, shadow_color, shadow_color]))

	# Draw main arrow.
	var main_points: PackedVector2Array = PackedVector2Array([tip, back_left, notch, back_right])
	draw_polygon(main_points, PackedColorArray([color, color, color, color]))

	# Draw highlight edge for 3D effect.
	var highlight_color: Color = color.lightened(0.4)
	highlight_color.a = color.a * 0.7
	draw_line(tip, back_left, highlight_color, 2.0)

	# Draw outline.
	var outline_color: Color = color.darkened(0.3)
	outline_color.a = color.a
	draw_polyline(PackedVector2Array([tip, back_left, notch, back_right, tip]), outline_color, 1.5)


## Draw arrow glow effect.
func _draw_arrow_glow(pos: Vector2, angle: float, glow_size: float, _color: Color, intensity: float) -> void:
	var glow_color: Color = GLOW_COLOR
	glow_color.a *= intensity * 0.5

	var tip_direction: Vector2 = Vector2(cos(angle + PI), sin(angle + PI))
	var perpendicular: Vector2 = Vector2(-tip_direction.y, tip_direction.x)

	var half_size: float = glow_size * 0.5
	var tip: Vector2 = pos + tip_direction * half_size
	var back_left: Vector2 = pos - tip_direction * half_size * 0.6 + perpendicular * half_size * 0.4
	var back_right: Vector2 = pos - tip_direction * half_size * 0.6 - perpendicular * half_size * 0.4

	var glow_points: PackedVector2Array = PackedVector2Array([tip, back_left, back_right])
	draw_polygon(glow_points, PackedColorArray([glow_color, glow_color, glow_color]))


## Draw trail effect.
func _draw_trail(trail_positions: Array, angle: float, trail_size: float) -> void:
	for trail_data in trail_positions:
		var trail_pos: Vector2 = trail_data["position"] as Vector2
		var trail_alpha: float = trail_data["alpha"] as float

		var trail_color: Color = TRAIL_COLOR
		trail_color.a *= trail_alpha

		var tip_direction: Vector2 = Vector2(cos(angle + PI), sin(angle + PI))
		var perpendicular: Vector2 = Vector2(-tip_direction.y, tip_direction.x)

		var sz: float = trail_size * trail_alpha
		var tip: Vector2 = trail_pos + tip_direction * sz * 0.5
		var back_left: Vector2 = trail_pos - tip_direction * sz * 0.3 + perpendicular * sz * 0.25
		var back_right: Vector2 = trail_pos - tip_direction * sz * 0.3 - perpendicular * sz * 0.25

		draw_polygon(
			PackedVector2Array([tip, back_left, back_right]),
			PackedColorArray([trail_color, trail_color, trail_color])
		)


## Draw pulse ring effect.
func _draw_pulse_ring(pos: Vector2, ring_size: float, color: Color, pulse_intensity: float) -> void:
	var ring_color: Color = color
	ring_color.a *= pulse_intensity * 0.5

	var ring_radius: float = ring_size * (0.8 + pulse_intensity * 0.4)
	draw_arc(pos, ring_radius, 0.0, TAU, 24, ring_color, 2.0)


## Get damage color based on amount.
func _get_damage_color(damage: float) -> Color:
	if damage >= CRITICAL_DAMAGE_THRESHOLD:
		return COLOR_CRITICAL_DAMAGE
	elif damage >= HEAVY_DAMAGE_THRESHOLD:
		var t: float = (damage - HEAVY_DAMAGE_THRESHOLD) / (CRITICAL_DAMAGE_THRESHOLD - HEAVY_DAMAGE_THRESHOLD)
		return COLOR_HIGH_DAMAGE.lerp(COLOR_CRITICAL_DAMAGE, t)
	elif damage >= 15.0:
		var t: float = (damage - 15.0) / (HEAVY_DAMAGE_THRESHOLD - 15.0)
		return COLOR_MED_DAMAGE.lerp(COLOR_HIGH_DAMAGE, t)
	else:
		var t: float = damage / 15.0
		return COLOR_LOW_DAMAGE.lerp(COLOR_MED_DAMAGE, t)


## Show a damage indicator from a specific world position.
func show_damage_from_position(damage_source_position: Vector3, damage_amount: float = 25.0) -> void:
	if not _local_player:
		return

	# Calculate direction from player to damage source.
	var player_pos: Vector3 = _local_player.global_position
	var to_source: Vector3 = damage_source_position - player_pos
	to_source.y = 0.0  # Flatten to horizontal plane.

	if to_source.length_squared() < 0.01:
		return

	to_source = to_source.normalized()

	# Get player's forward direction.
	var player_forward: Vector3 = -_local_player.global_transform.basis.z
	player_forward.y = 0.0
	player_forward = player_forward.normalized()

	# Calculate angle relative to player's facing direction.
	var angle: float = atan2(to_source.x, to_source.z)
	var player_angle: float = atan2(player_forward.x, player_forward.z)
	var relative_angle: float = angle - player_angle

	# Convert to screen space.
	var screen_angle: float = -relative_angle - PI * 0.5

	_add_indicator(screen_angle, damage_amount)

	# Trigger screen effects for heavy damage.
	_trigger_damage_effects(damage_amount, screen_angle)


## Show a damage indicator from a specific screen angle.
func show_damage_from_angle(angle_radians: float, damage_amount: float = 25.0) -> void:
	_add_indicator(angle_radians, damage_amount)
	_trigger_damage_effects(damage_amount, angle_radians)


## Internal: Add a new indicator or merge with existing one.
func _add_indicator(angle: float, damage_amount: float) -> void:
	# Normalize angle to [0, 2*PI].
	angle = fmod(angle + TAU, TAU)

	# Check if there's already an indicator at a similar angle.
	for indicator: Dictionary in _indicators:
		var existing_angle: float = indicator["angle"] as float
		var angle_diff: float = absf(angle - existing_angle)
		if angle_diff > PI:
			angle_diff = TAU - angle_diff

		if angle_diff < deg_to_rad(25.0):
			# Refresh and intensify existing indicator.
			indicator["time_remaining"] = INDICATOR_DURATION
			indicator["intensity"] = 1.0
			indicator["damage_amount"] = maxf(indicator.get("damage_amount", 25.0) as float, damage_amount)
			indicator["pulse_phase"] = 0.0

			# Add to trail.
			if not indicator.has("trail_positions"):
				indicator["trail_positions"] = []
			var trail: Array = indicator["trail_positions"] as Array
			var center: Vector2 = size * 0.5
			var direction: Vector2 = Vector2(cos(angle), sin(angle))
			trail.append({
				"position": center + direction * INDICATOR_DISTANCE,
				"alpha": 0.8,
			})
			if trail.size() > 5:
				trail.remove_at(0)

			return

	# Remove oldest indicator if at capacity.
	if _indicators.size() >= MAX_INDICATORS:
		var oldest_idx: int = 0
		var oldest_time: float = _indicators[0]["time_remaining"] as float
		for i: int in range(1, _indicators.size()):
			if (_indicators[i]["time_remaining"] as float) < oldest_time:
				oldest_time = _indicators[i]["time_remaining"] as float
				oldest_idx = i
		_indicators.remove_at(oldest_idx)

	# Add new indicator.
	_indicators.append({
		"angle": angle,
		"time_remaining": INDICATOR_DURATION,
		"intensity": 1.0,
		"damage_amount": damage_amount,
		"pulse_phase": 0.0,
		"trail_positions": [],
	})


## Trigger screen damage effects based on damage amount.
func _trigger_damage_effects(damage: float, direction: float) -> void:
	# Always show some flash.
	_damage_flash = clampf(damage / 50.0, 0.3, 0.8)

	# Vignette for medium+ damage.
	if damage >= 15.0:
		_vignette_intensity = clampf(damage / 60.0, 0.2, 0.8)

	# Screen crack for heavy damage.
	if damage >= HEAVY_DAMAGE_THRESHOLD:
		_screen_crack_intensity = clampf((damage - HEAVY_DAMAGE_THRESHOLD) / 50.0, 0.3, 1.0)
		heavy_damage_taken.emit(damage, direction)

	# Chromatic aberration for very heavy damage.
	if damage >= 40.0:
		_chromatic_aberration = clampf((damage - 40.0) / 40.0, 0.2, 1.0)

	# Blur for critical damage.
	if damage >= CRITICAL_DAMAGE_THRESHOLD:
		_blur_intensity = clampf((damage - CRITICAL_DAMAGE_THRESHOLD) / 30.0, 0.2, 0.6)
		critical_damage_taken.emit(damage)


# ── Public API ───────────────────────────────────────────────────────────────

## Set the local player reference for direction calculations.
func set_local_player(player: Node3D) -> void:
	_local_player = player


## Clear all active indicators.
func clear_indicators() -> void:
	_indicators.clear()
	queue_redraw()


## Reset all screen effects.
func reset_effects() -> void:
	_screen_crack_intensity = 0.0
	_chromatic_aberration = 0.0
	_vignette_intensity = 0.0
	_blur_intensity = 0.0
	_damage_flash = 0.0
	queue_redraw()


## Get current blur intensity (for external post-processing).
func get_blur_intensity() -> float:
	return _blur_intensity


## Get current chromatic aberration (for external shader).
func get_chromatic_aberration() -> float:
	return _chromatic_aberration


## Get current vignette intensity.
func get_vignette_intensity() -> float:
	return _vignette_intensity
