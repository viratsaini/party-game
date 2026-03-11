## UIEasing - Comprehensive easing functions for UI animations.
##
## Provides all standard easing curves plus custom bezier and spring physics.
## Each easing type has in, out, and in_out variants.
##
## Usage:
##   var value := UIEasing.elastic_out(t)
##   var custom := UIEasing.bezier(t, 0.25, 0.1, 0.25, 1.0)
##   var spring := UIEasing.spring(t, 0.3, 8.0)
class_name UIEasing
extends RefCounted


# region - Constants

## Common presets for bezier curves (CSS-style)
const BEZIER_PRESETS: Dictionary = {
	"ease": [0.25, 0.1, 0.25, 1.0],
	"ease_in": [0.42, 0.0, 1.0, 1.0],
	"ease_out": [0.0, 0.0, 0.58, 1.0],
	"ease_in_out": [0.42, 0.0, 0.58, 1.0],
	"material_standard": [0.4, 0.0, 0.2, 1.0],
	"material_decelerate": [0.0, 0.0, 0.2, 1.0],
	"material_accelerate": [0.4, 0.0, 1.0, 1.0],
	"swift_out": [0.55, 0.0, 0.1, 1.0],
	"anticipate": [0.36, 0.0, 0.66, -0.56],
	"overshoot": [0.34, 1.56, 0.64, 1.0],
}

## Spring presets [damping, frequency]
const SPRING_PRESETS: Dictionary = {
	"gentle": [0.6, 6.0],
	"bouncy": [0.3, 8.0],
	"stiff": [0.8, 12.0],
	"wobbly": [0.2, 6.0],
	"slow": [0.7, 4.0],
}

# endregion


# region - Linear

## Linear interpolation (no easing)
static func linear(t: float) -> float:
	return clampf(t, 0.0, 1.0)

# endregion


# region - Quadratic

static func quad_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t


static func quad_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)


static func quad_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t < 0.5:
		return 2.0 * t * t
	else:
		return 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0

# endregion


# region - Cubic

static func cubic_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t


static func cubic_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


static func cubic_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t < 0.5:
		return 4.0 * t * t * t
	else:
		return 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0

# endregion


# region - Quartic

static func quart_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * t


static func quart_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 4.0)


static func quart_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t < 0.5:
		return 8.0 * t * t * t * t
	else:
		return 1.0 - pow(-2.0 * t + 2.0, 4.0) / 2.0

# endregion


# region - Quintic

static func quint_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * t * t


static func quint_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 5.0)


static func quint_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t < 0.5:
		return 16.0 * t * t * t * t * t
	else:
		return 1.0 - pow(-2.0 * t + 2.0, 5.0) / 2.0

# endregion


# region - Sine

static func sine_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - cos((t * PI) / 2.0)


static func sine_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return sin((t * PI) / 2.0)


static func sine_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return -(cos(PI * t) - 1.0) / 2.0

# endregion


# region - Exponential

static func expo_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t == 0.0:
		return 0.0
	return pow(2.0, 10.0 * t - 10.0)


static func expo_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t == 1.0:
		return 1.0
	return 1.0 - pow(2.0, -10.0 * t)


static func expo_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t == 0.0:
		return 0.0
	if t == 1.0:
		return 1.0
	if t < 0.5:
		return pow(2.0, 20.0 * t - 10.0) / 2.0
	else:
		return (2.0 - pow(2.0, -20.0 * t + 10.0)) / 2.0

# endregion


# region - Circular

static func circ_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - sqrt(1.0 - pow(t, 2.0))


static func circ_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return sqrt(1.0 - pow(t - 1.0, 2.0))


static func circ_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t < 0.5:
		return (1.0 - sqrt(1.0 - pow(2.0 * t, 2.0))) / 2.0
	else:
		return (sqrt(1.0 - pow(-2.0 * t + 2.0, 2.0)) + 1.0) / 2.0

# endregion


# region - Elastic

static func elastic_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t == 0.0:
		return 0.0
	if t == 1.0:
		return 1.0
	var c4: float = (2.0 * PI) / 3.0
	return -pow(2.0, 10.0 * t - 10.0) * sin((t * 10.0 - 10.75) * c4)


static func elastic_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t == 0.0:
		return 0.0
	if t == 1.0:
		return 1.0
	var c4: float = (2.0 * PI) / 3.0
	return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0


static func elastic_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t == 0.0:
		return 0.0
	if t == 1.0:
		return 1.0
	var c5: float = (2.0 * PI) / 4.5
	if t < 0.5:
		return -(pow(2.0, 20.0 * t - 10.0) * sin((20.0 * t - 11.125) * c5)) / 2.0
	else:
		return (pow(2.0, -20.0 * t + 10.0) * sin((20.0 * t - 11.125) * c5)) / 2.0 + 1.0


## Configurable elastic easing
static func elastic_custom(t: float, amplitude: float = 1.0, period: float = 0.3) -> float:
	t = clampf(t, 0.0, 1.0)
	if t == 0.0:
		return 0.0
	if t == 1.0:
		return 1.0

	var s: float
	if amplitude < 1.0:
		amplitude = 1.0
		s = period / 4.0
	else:
		s = period / (2.0 * PI) * asin(1.0 / amplitude)

	return amplitude * pow(2.0, -10.0 * t) * sin((t - s) * (2.0 * PI) / period) + 1.0

# endregion


# region - Back

static func back_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return c3 * t * t * t - c1 * t * t


static func back_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


static func back_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var c1: float = 1.70158
	var c2: float = c1 * 1.525
	if t < 0.5:
		return (pow(2.0 * t, 2.0) * ((c2 + 1.0) * 2.0 * t - c2)) / 2.0
	else:
		return (pow(2.0 * t - 2.0, 2.0) * ((c2 + 1.0) * (t * 2.0 - 2.0) + c2) + 2.0) / 2.0


## Configurable back easing with custom overshoot
static func back_custom(t: float, overshoot: float = 1.70158) -> float:
	t = clampf(t, 0.0, 1.0)
	var c3: float = overshoot + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + overshoot * pow(t - 1.0, 2.0)

# endregion


# region - Bounce

static func bounce_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var n1: float = 7.5625
	var d1: float = 2.75

	if t < 1.0 / d1:
		return n1 * t * t
	elif t < 2.0 / d1:
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	elif t < 2.5 / d1:
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	else:
		t -= 2.625 / d1
		return n1 * t * t + 0.984375


static func bounce_in(t: float) -> float:
	return 1.0 - bounce_out(1.0 - t)


static func bounce_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t < 0.5:
		return (1.0 - bounce_out(1.0 - 2.0 * t)) / 2.0
	else:
		return (1.0 + bounce_out(2.0 * t - 1.0)) / 2.0

# endregion


# region - Spring Physics

## Spring physics simulation - the most natural feeling easing
## [param t] Progress (0-1)
## [param damping] Damping ratio (0-1, lower = more bouncy)
## [param frequency] Oscillation frequency (higher = faster)
static func spring(t: float, damping: float = 0.4, frequency: float = 6.0) -> float:
	t = clampf(t, 0.0, 1.0)
	damping = clampf(damping, 0.01, 1.0)

	var omega: float = frequency * 2.0 * PI
	var damped_omega: float = omega * sqrt(maxf(1.0 - damping * damping, 0.001))

	var decay: float = exp(-damping * omega * t)
	var oscillation: float = cos(damped_omega * t) + (damping * omega / damped_omega) * sin(damped_omega * t)

	return 1.0 - decay * oscillation


## Spring from preset name
static func spring_preset(t: float, preset_name: String) -> float:
	if not SPRING_PRESETS.has(preset_name):
		push_warning("UIEasing: Unknown spring preset '%s', using default" % preset_name)
		return spring(t)

	var params: Array = SPRING_PRESETS[preset_name]
	return spring(t, params[0], params[1])


## Advanced spring with velocity
## Returns both position and velocity for physics simulations
static func spring_with_velocity(t: float, damping: float = 0.4, frequency: float = 6.0) -> Dictionary:
	t = clampf(t, 0.0, 1.0)
	damping = clampf(damping, 0.01, 1.0)

	var omega: float = frequency * 2.0 * PI
	var damped_omega: float = omega * sqrt(maxf(1.0 - damping * damping, 0.001))

	var decay: float = exp(-damping * omega * t)
	var cos_term: float = cos(damped_omega * t)
	var sin_term: float = sin(damped_omega * t)

	var position: float = 1.0 - decay * (cos_term + (damping * omega / damped_omega) * sin_term)

	# Calculate velocity (derivative)
	var velocity: float = decay * omega * ((damping * omega / damped_omega) * cos_term - sin_term)
	velocity += damping * omega * decay * (cos_term + (damping * omega / damped_omega) * sin_term)

	return {
		"position": position,
		"velocity": velocity,
	}

# endregion


# region - Bezier Curves

## Cubic bezier easing (CSS-style)
## [param t] Progress (0-1)
## [param x1] First control point X
## [param y1] First control point Y
## [param x2] Second control point X
## [param y2] Second control point Y
static func bezier(t: float, x1: float, y1: float, x2: float, y2: float) -> float:
	t = clampf(t, 0.0, 1.0)

	# Newton-Raphson iteration to find t for given x
	var ax: float = 1.0 - 3.0 * x2 + 3.0 * x1
	var bx: float = 3.0 * x2 - 6.0 * x1
	var cx: float = 3.0 * x1

	var ay: float = 1.0 - 3.0 * y2 + 3.0 * y1
	var by: float = 3.0 * y2 - 6.0 * y1
	var cy: float = 3.0 * y1

	# Find t for x using Newton-Raphson
	var guess_t: float = t
	for _i in range(8):
		var current_x: float = ((ax * guess_t + bx) * guess_t + cx) * guess_t
		var current_slope: float = (3.0 * ax * guess_t + 2.0 * bx) * guess_t + cx

		if abs(current_slope) < 0.000001:
			break

		guess_t = guess_t - (current_x - t) / current_slope

	guess_t = clampf(guess_t, 0.0, 1.0)

	# Calculate y for found t
	return ((ay * guess_t + by) * guess_t + cy) * guess_t


## Bezier from preset name
static func bezier_preset(t: float, preset_name: String) -> float:
	if not BEZIER_PRESETS.has(preset_name):
		push_warning("UIEasing: Unknown bezier preset '%s', using linear" % preset_name)
		return t

	var params: Array = BEZIER_PRESETS[preset_name]
	return bezier(t, params[0], params[1], params[2], params[3])

# endregion


# region - Special Easing

## Smooth step (Hermite interpolation)
static func smooth_step(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Smoother step (Ken Perlin's improved version)
static func smoother_step(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## Step function (instant transition at threshold)
static func step(t: float, threshold: float = 0.5) -> float:
	return 1.0 if t >= threshold else 0.0


## Triangle wave
static func triangle(t: float) -> float:
	t = fmod(t, 1.0)
	if t < 0.5:
		return t * 2.0
	else:
		return 2.0 - t * 2.0


## Sine wave (oscillating 0-1)
static func sine_wave(t: float, frequency: float = 1.0) -> float:
	return (sin(t * frequency * 2.0 * PI) + 1.0) / 2.0

# endregion


# region - Utility Functions

## Combine two easing functions (blend between them)
static func blend(ease1: float, ease2: float, blend_factor: float) -> float:
	return lerpf(ease1, ease2, clampf(blend_factor, 0.0, 1.0))


## Reverse an easing (flip horizontally and vertically)
static func reverse(eased_value: float) -> float:
	return 1.0 - eased_value


## Mirror an easing (play forward then backward)
static func mirror(t: float, ease_func: Callable) -> float:
	if t < 0.5:
		return ease_func.call(t * 2.0)
	else:
		return ease_func.call(2.0 - t * 2.0)


## Repeat an easing multiple times
static func repeat_ease(t: float, repeats: int, ease_func: Callable) -> float:
	var local_t: float = fmod(t * float(repeats), 1.0)
	return ease_func.call(local_t)

# endregion


# region - Easing by Name

## Get easing function by name string
static func get_easing(name: String) -> Callable:
	match name.to_lower():
		"linear": return linear
		"quad_in", "quadin": return quad_in
		"quad_out", "quadout": return quad_out
		"quad_in_out", "quadinout": return quad_in_out
		"cubic_in", "cubicin": return cubic_in
		"cubic_out", "cubicout": return cubic_out
		"cubic_in_out", "cubicinout": return cubic_in_out
		"quart_in", "quartin": return quart_in
		"quart_out", "quartout": return quart_out
		"quart_in_out", "quartinout": return quart_in_out
		"quint_in", "quintin": return quint_in
		"quint_out", "quintout": return quint_out
		"quint_in_out", "quintinout": return quint_in_out
		"sine_in", "sinein": return sine_in
		"sine_out", "sineout": return sine_out
		"sine_in_out", "sineinout": return sine_in_out
		"expo_in", "expoin": return expo_in
		"expo_out", "expoout": return expo_out
		"expo_in_out", "expoinout": return expo_in_out
		"circ_in", "circin": return circ_in
		"circ_out", "circout": return circ_out
		"circ_in_out", "circinout": return circ_in_out
		"elastic_in", "elasticin": return elastic_in
		"elastic_out", "elasticout": return elastic_out
		"elastic_in_out", "elasticinout": return elastic_in_out
		"back_in", "backin": return back_in
		"back_out", "backout": return back_out
		"back_in_out", "backinout": return back_in_out
		"bounce_in", "bouncein": return bounce_in
		"bounce_out", "bounceout": return bounce_out
		"bounce_in_out", "bounceinout": return bounce_in_out
		"smooth_step", "smoothstep": return smooth_step
		"smoother_step", "smootherstep": return smoother_step
		_:
			push_warning("UIEasing: Unknown easing '%s', using linear" % name)
			return linear


## Apply easing by name
static func ease_by_name(t: float, name: String) -> float:
	var ease_func: Callable = get_easing(name)
	return ease_func.call(t)

# endregion
