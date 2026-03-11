## Custom easing functions for ultra-premium UI animations.
## Provides elastic, back, bounce, spring, and other advanced easing curves
## that go beyond Godot's built-in Tween transitions.
class_name UIEasing
extends RefCounted


# ══════════════════════════════════════════════════════════════════════════════
# ELASTIC EASING - Rubber band / spring oscillation effect
# ══════════════════════════════════════════════════════════════════════════════

## Elastic ease-in: Starts slow with oscillation, accelerates
static func elastic_in(t: float, amplitude: float = 1.0, period: float = 0.3) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0

	var s: float = period / TAU * asin(1.0 / amplitude)
	t -= 1.0
	return -(amplitude * pow(2.0, 10.0 * t) * sin((t - s) * TAU / period))


## Elastic ease-out: Fast start, bouncy deceleration - MOST COMMON for UI
static func elastic_out(t: float, amplitude: float = 1.0, period: float = 0.3) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0

	var s: float = period / TAU * asin(1.0 / amplitude)
	return amplitude * pow(2.0, -10.0 * t) * sin((t - s) * TAU / period) + 1.0


## Elastic ease-in-out: Oscillates at both ends
static func elastic_in_out(t: float, amplitude: float = 1.0, period: float = 0.45) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0

	var s: float = period / TAU * asin(1.0 / amplitude)
	t = t * 2.0 - 1.0

	if t < 0.0:
		return -0.5 * amplitude * pow(2.0, 10.0 * t) * sin((t - s) * TAU / period)
	else:
		return amplitude * pow(2.0, -10.0 * t) * sin((t - s) * TAU / period) * 0.5 + 1.0


# ══════════════════════════════════════════════════════════════════════════════
# BACK EASING - Overshoots target then returns (anticipation effect)
# ══════════════════════════════════════════════════════════════════════════════

## Back ease-in: Pulls back before accelerating forward
static func back_in(t: float, overshoot: float = 1.70158) -> float:
	return t * t * ((overshoot + 1.0) * t - overshoot)


## Back ease-out: Overshoots target, bounces back - Great for buttons
static func back_out(t: float, overshoot: float = 1.70158) -> float:
	t -= 1.0
	return t * t * ((overshoot + 1.0) * t + overshoot) + 1.0


## Back ease-in-out: Anticipation and follow-through
static func back_in_out(t: float, overshoot: float = 1.70158) -> float:
	var s: float = overshoot * 1.525
	t *= 2.0

	if t < 1.0:
		return 0.5 * (t * t * ((s + 1.0) * t - s))
	else:
		t -= 2.0
		return 0.5 * (t * t * ((s + 1.0) * t + s) + 2.0)


# ══════════════════════════════════════════════════════════════════════════════
# BOUNCE EASING - Ball-bounce physics
# ══════════════════════════════════════════════════════════════════════════════

## Bounce ease-out: Natural ball bounce at end
static func bounce_out(t: float) -> float:
	if t < 1.0 / 2.75:
		return 7.5625 * t * t
	elif t < 2.0 / 2.75:
		t -= 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	elif t < 2.5 / 2.75:
		t -= 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	else:
		t -= 2.625 / 2.75
		return 7.5625 * t * t + 0.984375


## Bounce ease-in: Bounces before reaching destination
static func bounce_in(t: float) -> float:
	return 1.0 - bounce_out(1.0 - t)


## Bounce ease-in-out: Bounces on both sides
static func bounce_in_out(t: float) -> float:
	if t < 0.5:
		return bounce_in(t * 2.0) * 0.5
	else:
		return bounce_out(t * 2.0 - 1.0) * 0.5 + 0.5


# ══════════════════════════════════════════════════════════════════════════════
# SPRING EASING - Damped spring physics (realistic mechanical feel)
# ══════════════════════════════════════════════════════════════════════════════

## Spring: Realistic damped oscillation (best for button press/release)
## damping: 0.0 = no damping (infinite bounce), 1.0 = critically damped (no overshoot)
## frequency: Oscillation speed, higher = faster wobble
static func spring(t: float, damping: float = 0.4, frequency: float = 4.0) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0

	var decay: float = exp(-damping * frequency * t)
	var oscillation: float = cos(frequency * TAU * t * (1.0 - damping))
	return 1.0 - decay * oscillation


## Spring with configurable overshoot amount
static func spring_overshoot(t: float, overshoot: float = 0.3) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0

	# Use critically damped spring with extra kick
	var omega: float = 10.0
	var zeta: float = 0.5  # Underdamped for overshoot
	var decay: float = exp(-zeta * omega * t)
	var phase: float = omega * sqrt(1.0 - zeta * zeta) * t

	return 1.0 - decay * (cos(phase) + zeta / sqrt(1.0 - zeta * zeta) * sin(phase)) * (1.0 + overshoot)


## Gentle spring: Minimal overshoot, smooth settle
static func spring_gentle(t: float) -> float:
	return spring(t, 0.6, 3.0)


## Snappy spring: Quick response, slight overshoot
static func spring_snappy(t: float) -> float:
	return spring(t, 0.35, 5.0)


## Wobbly spring: More oscillation, playful feel
static func spring_wobbly(t: float) -> float:
	return spring(t, 0.25, 6.0)


# ══════════════════════════════════════════════════════════════════════════════
# EXPO EASING - Exponential curves (very snappy)
# ══════════════════════════════════════════════════════════════════════════════

## Expo ease-in: Slow start, explosive acceleration
static func expo_in(t: float) -> float:
	if t <= 0.0:
		return 0.0
	return pow(2.0, 10.0 * (t - 1.0))


## Expo ease-out: Explosive start, smooth landing
static func expo_out(t: float) -> float:
	if t >= 1.0:
		return 1.0
	return 1.0 - pow(2.0, -10.0 * t)


## Expo ease-in-out: Sharp in the middle
static func expo_in_out(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0

	t *= 2.0
	if t < 1.0:
		return 0.5 * pow(2.0, 10.0 * (t - 1.0))
	else:
		return 0.5 * (2.0 - pow(2.0, -10.0 * (t - 1.0)))


# ══════════════════════════════════════════════════════════════════════════════
# CIRC EASING - Circular motion curves
# ══════════════════════════════════════════════════════════════════════════════

## Circ ease-in: Slow acceleration from zero
static func circ_in(t: float) -> float:
	return 1.0 - sqrt(1.0 - t * t)


## Circ ease-out: Quick deceleration to stop
static func circ_out(t: float) -> float:
	t -= 1.0
	return sqrt(1.0 - t * t)


## Circ ease-in-out: Smooth arc
static func circ_in_out(t: float) -> float:
	t *= 2.0
	if t < 1.0:
		return -0.5 * (sqrt(1.0 - t * t) - 1.0)
	else:
		t -= 2.0
		return 0.5 * (sqrt(1.0 - t * t) + 1.0)


# ══════════════════════════════════════════════════════════════════════════════
# SPECIAL UI EASING - Optimized for specific UI interactions
# ══════════════════════════════════════════════════════════════════════════════

## Button press: Quick squish with satisfying settle
static func button_press(t: float) -> float:
	# Fast down, bouncy up
	if t < 0.3:
		return expo_out(t / 0.3) * 0.3
	else:
		var t2: float = (t - 0.3) / 0.7
		return 0.3 + spring_snappy(t2) * 0.7


## Button release: Snappy return with slight overshoot
static func button_release(t: float) -> float:
	return back_out(t, 2.5)


## Menu slide: Smooth glide with gentle settle
static func menu_slide(t: float) -> float:
	return spring_gentle(t)


## Panel reveal: Dramatic entrance with settle
static func panel_reveal(t: float) -> float:
	return elastic_out(t, 1.0, 0.4)


## Hover scale: Subtle and responsive
static func hover_scale(t: float) -> float:
	return back_out(t, 1.2)


## Glow pulse: Smooth breathing effect
static func glow_pulse(t: float) -> float:
	return sin(t * PI) * sin(t * PI)


## Shake intensity: For error feedback
static func shake(t: float, intensity: float = 1.0) -> float:
	var decay: float = 1.0 - t
	return sin(t * 40.0) * decay * intensity


## Glitch: Random-ish stutter effect
static func glitch(t: float, seed_val: float = 0.0) -> float:
	var random_factor: float = fmod(sin(t * 100.0 + seed_val) * 43758.5453, 1.0)
	var base: float = expo_out(t)
	var glitch_amount: float = (1.0 - t) * 0.3
	return base + random_factor * glitch_amount - glitch_amount * 0.5


## Heartbeat: Double pulse effect
static func heartbeat(t: float) -> float:
	var t2: float = fmod(t * 2.0, 1.0)
	if t < 0.5:
		return pow(sin(t2 * PI), 2.0)
	else:
		return pow(sin(t2 * PI), 2.0) * 0.6


# ══════════════════════════════════════════════════════════════════════════════
# BEZIER EASING - Custom cubic bezier curves
# ══════════════════════════════════════════════════════════════════════════════

## Cubic bezier: Mimics CSS cubic-bezier() for web-familiar animations
static func cubic_bezier(t: float, p1x: float, p1y: float, p2x: float, p2y: float) -> float:
	# Newton-Raphson iteration to find t for x
	var cx: float = 3.0 * p1x
	var bx: float = 3.0 * (p2x - p1x) - cx
	var ax: float = 1.0 - cx - bx

	var cy: float = 3.0 * p1y
	var by: float = 3.0 * (p2y - p1y) - cy
	var ay: float = 1.0 - cy - by

	# Find t for given x using Newton's method
	var guess_t: float = t
	for _i in range(8):
		var current_x: float = ((ax * guess_t + bx) * guess_t + cx) * guess_t
		var current_slope: float = (3.0 * ax * guess_t + 2.0 * bx) * guess_t + cx
		if abs(current_slope) < 0.000001:
			break
		guess_t -= (current_x - t) / current_slope

	# Calculate y for the found t
	return ((ay * guess_t + by) * guess_t + cy) * guess_t


## iOS spring animation preset
static func ios_spring(t: float) -> float:
	return cubic_bezier(t, 0.5, 1.8, 0.5, 0.8)


## Material Design standard curve
static func material_standard(t: float) -> float:
	return cubic_bezier(t, 0.4, 0.0, 0.2, 1.0)


## Material Design deceleration
static func material_decelerate(t: float) -> float:
	return cubic_bezier(t, 0.0, 0.0, 0.2, 1.0)


## Material Design acceleration
static func material_accelerate(t: float) -> float:
	return cubic_bezier(t, 0.4, 0.0, 1.0, 1.0)


# ══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

## Interpolate any value using custom easing
static func interpolate(from: float, to: float, t: float, easing_func: Callable) -> float:
	var eased_t: float = easing_func.call(t)
	return from + (to - from) * eased_t


## Interpolate Vector2 using custom easing
static func interpolate_v2(from: Vector2, to: Vector2, t: float, easing_func: Callable) -> Vector2:
	var eased_t: float = easing_func.call(t)
	return from.lerp(to, eased_t)


## Interpolate Color using custom easing
static func interpolate_color(from: Color, to: Color, t: float, easing_func: Callable) -> Color:
	var eased_t: float = easing_func.call(t)
	return from.lerp(to, eased_t)


## Chain multiple easings for complex curves
static func chain(t: float, easings: Array[Callable], breakpoints: Array[float]) -> float:
	if easings.is_empty():
		return t

	var segment: int = 0
	var prev_bp: float = 0.0

	for i in range(breakpoints.size()):
		if t < breakpoints[i]:
			break
		prev_bp = breakpoints[i]
		segment = i + 1

	if segment >= easings.size():
		segment = easings.size() - 1

	var next_bp: float = 1.0 if segment >= breakpoints.size() else breakpoints[segment]
	var local_t: float = (t - prev_bp) / (next_bp - prev_bp)

	return easings[segment].call(local_t)


## Reverse an easing function
static func reverse(t: float, easing_func: Callable) -> float:
	return 1.0 - easing_func.call(1.0 - t)


## Mirror an easing (ease-in becomes ease-in-out style)
static func mirror(t: float, easing_func: Callable) -> float:
	if t < 0.5:
		return easing_func.call(t * 2.0) * 0.5
	else:
		return 1.0 - easing_func.call((1.0 - t) * 2.0) * 0.5
