## Directional damage indicator system.
## Shows red arrow arcs on screen edges indicating damage direction.
## Automatically fades out after a configurable duration.
class_name DamageIndicator
extends Control

## Duration in seconds before an indicator starts fading.
const INDICATOR_DURATION: float = 1.5
## Time for the fade-out animation.
const FADE_DURATION: float = 0.5
## Distance from screen center where indicators are drawn.
const INDICATOR_DISTANCE: float = 150.0
## Size of each indicator arrow.
const INDICATOR_SIZE: float = 60.0
## Base color for damage indicators.
const INDICATOR_COLOR: Color = Color(1.0, 0.15, 0.1, 0.9)
## Maximum number of simultaneous indicators.
const MAX_INDICATORS: int = 8

## Active damage indicators.
## Each entry: {angle: float, time_remaining: float, intensity: float, damage_amount: float}
var _indicators: Array[Dictionary] = []

## Reference to the local player for calculating relative directions.
var _local_player: Node3D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	# Update all indicators.
	var i: int = _indicators.size() - 1
	while i >= 0:
		var indicator: Dictionary = _indicators[i]
		indicator["time_remaining"] = (indicator["time_remaining"] as float) - delta

		if indicator["time_remaining"] <= 0.0:
			_indicators.remove_at(i)
		elif indicator["time_remaining"] < FADE_DURATION:
			# Fade out during the last FADE_DURATION seconds.
			indicator["intensity"] = indicator["time_remaining"] / FADE_DURATION

		i -= 1

	queue_redraw()


func _draw() -> void:
	if _indicators.is_empty():
		return

	var center: Vector2 = size * 0.5

	for indicator: Dictionary in _indicators:
		var angle: float = indicator["angle"] as float
		var intensity: float = indicator["intensity"] as float
		var damage: float = indicator.get("damage_amount", 25.0) as float

		# Scale indicator based on damage amount (larger damage = larger indicator).
		var damage_scale: float = clampf(damage / 50.0, 0.5, 1.5)
		var current_size: float = INDICATOR_SIZE * damage_scale

		# Calculate position on screen edge based on angle.
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var pos: Vector2 = center + direction * INDICATOR_DISTANCE

		# Draw the damage indicator arrow.
		_draw_damage_arrow(pos, angle, current_size, intensity)


## Draw a damage indicator arrow at the specified position.
func _draw_damage_arrow(pos: Vector2, angle: float, arrow_size: float, intensity: float) -> void:
	var color: Color = INDICATOR_COLOR
	color.a *= intensity

	# Create arrow points.
	var half_size: float = arrow_size * 0.5
	var arrow_length: float = arrow_size * 0.8

	# Arrow tip points toward center (opposite of damage direction).
	var tip_direction: Vector2 = Vector2(cos(angle + PI), sin(angle + PI))
	var perpendicular: Vector2 = Vector2(-tip_direction.y, tip_direction.x)

	var tip: Vector2 = pos + tip_direction * half_size
	var base_left: Vector2 = pos - tip_direction * half_size + perpendicular * half_size * 0.6
	var base_right: Vector2 = pos - tip_direction * half_size - perpendicular * half_size * 0.6
	var base_center: Vector2 = pos - tip_direction * half_size * 0.3

	# Draw the arrow shape.
	var points: PackedVector2Array = PackedVector2Array([tip, base_left, base_center, base_right])
	var colors: PackedColorArray = PackedColorArray([color, color, color, color])
	draw_polygon(points, colors)

	# Draw glow effect (larger, more transparent version).
	var glow_color: Color = color
	glow_color.a *= 0.3
	var glow_scale: float = 1.4
	var glow_tip: Vector2 = pos + tip_direction * half_size * glow_scale
	var glow_base_left: Vector2 = pos - tip_direction * half_size * glow_scale + perpendicular * half_size * 0.6 * glow_scale
	var glow_base_right: Vector2 = pos - tip_direction * half_size * glow_scale - perpendicular * half_size * 0.6 * glow_scale
	var glow_base_center: Vector2 = pos - tip_direction * half_size * 0.3 * glow_scale

	var glow_points: PackedVector2Array = PackedVector2Array([glow_tip, glow_base_left, glow_base_center, glow_base_right])
	var glow_colors: PackedColorArray = PackedColorArray([glow_color, glow_color, glow_color, glow_color])
	draw_polygon(glow_points, glow_colors)


## Show a damage indicator from a specific world position.
## [param damage_source_position] World position where the damage came from.
## [param damage_amount] Amount of damage taken (affects indicator size).
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
	# We want the angle on screen, so we use atan2 with the world directions.
	var angle: float = atan2(to_source.x, to_source.z)
	var player_angle: float = atan2(player_forward.x, player_forward.z)
	var relative_angle: float = angle - player_angle

	# Convert to screen space (rotate 90 degrees since screen Y is down).
	var screen_angle: float = -relative_angle - PI * 0.5

	_add_indicator(screen_angle, damage_amount)


## Show a damage indicator from a specific screen angle.
## [param angle_radians] Angle in radians (0 = right, PI/2 = down).
## [param damage_amount] Amount of damage taken.
func show_damage_from_angle(angle_radians: float, damage_amount: float = 25.0) -> void:
	_add_indicator(angle_radians, damage_amount)


## Internal: Add a new indicator or merge with existing one at similar angle.
func _add_indicator(angle: float, damage_amount: float) -> void:
	# Normalize angle to [0, 2*PI].
	angle = fmod(angle + TAU, TAU)

	# Check if there's already an indicator at a similar angle (within 30 degrees).
	for indicator: Dictionary in _indicators:
		var existing_angle: float = indicator["angle"] as float
		var angle_diff: float = absf(angle - existing_angle)
		if angle_diff > PI:
			angle_diff = TAU - angle_diff

		if angle_diff < deg_to_rad(30.0):
			# Refresh existing indicator.
			indicator["time_remaining"] = INDICATOR_DURATION
			indicator["intensity"] = 1.0
			indicator["damage_amount"] = maxf(indicator.get("damage_amount", 25.0) as float, damage_amount)
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
	})


## Set the local player reference for direction calculations.
func set_local_player(player: Node3D) -> void:
	_local_player = player


## Clear all active indicators.
func clear_indicators() -> void:
	_indicators.clear()
	queue_redraw()
