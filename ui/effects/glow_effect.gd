## Dynamic glow effect system for ultra-premium UI visuals.
## Provides smooth, animated glow effects for buttons, panels, and UI elements
## with support for color cycling, pulsing, and reactive feedback.
class_name UIGlowEffect
extends Control

# ══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ══════════════════════════════════════════════════════════════════════════════

signal glow_pulse_completed
signal glow_state_changed(state: GlowState)


# ══════════════════════════════════════════════════════════════════════════════
# ENUMS
# ══════════════════════════════════════════════════════════════════════════════

enum GlowState {
	IDLE,
	HOVER,
	ACTIVE,
	DISABLED,
	PULSE,
	ALERT
}


# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

## Glow colors per button type
const GLOW_COLORS: Dictionary = {
	"primary": Color(0.3, 0.7, 1.0),      # Blue - main actions
	"secondary": Color(0.6, 0.4, 1.0),    # Purple - secondary actions
	"success": Color(0.3, 0.9, 0.4),      # Green - confirm/success
	"warning": Color(1.0, 0.7, 0.2),      # Orange - caution
	"danger": Color(1.0, 0.3, 0.3),       # Red - destructive
	"gold": Color(1.0, 0.85, 0.3),        # Gold - premium/special
	"cyan": Color(0.2, 0.9, 0.9),         # Cyan - info
	"neutral": Color(0.7, 0.7, 0.8),      # Gray - neutral
}


## Glow intensity by state
const INTENSITY_IDLE: float = 0.15
const INTENSITY_HOVER: float = 0.5
const INTENSITY_ACTIVE: float = 0.8
const INTENSITY_PULSE_MIN: float = 0.1
const INTENSITY_PULSE_MAX: float = 0.4


## Animation timing
const PULSE_DURATION: float = 2.0
const TRANSITION_DURATION: float = 0.2
const ALERT_FLASH_DURATION: float = 0.3


# ══════════════════════════════════════════════════════════════════════════════
# STATE
# ══════════════════════════════════════════════════════════════════════════════

var _state: GlowState = GlowState.IDLE
var _glow_color: Color = GLOW_COLORS["primary"]
var _current_intensity: float = 0.0
var _target_intensity: float = 0.0
var _pulse_tween: Tween = null
var _transition_tween: Tween = null

## Glow visual properties
var _glow_size: float = 15.0
var _glow_softness: float = 0.8
var _inner_glow: bool = true
var _outer_glow: bool = true

## Scanline effect
var _scanline_enabled: bool = false
var _scanline_offset: float = 0.0
var _scanline_speed: float = 50.0


# ══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ══════════════════════════════════════════════════════════════════════════════

@export var glow_type: String = "primary":
	set(value):
		glow_type = value
		if GLOW_COLORS.has(value):
			_glow_color = GLOW_COLORS[value]

@export var auto_pulse: bool = false
@export var pulse_on_idle: bool = true
@export var glow_size: float = 15.0:
	set(value):
		glow_size = value
		_glow_size = value

@export var enable_scanlines: bool = false:
	set(value):
		enable_scanlines = value
		_scanline_enabled = value


# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

	if GLOW_COLORS.has(glow_type):
		_glow_color = GLOW_COLORS[glow_type]

	if auto_pulse:
		start_pulse()


func _process(delta: float) -> void:
	# Smooth intensity transition
	_current_intensity = lerpf(_current_intensity, _target_intensity, delta * 10.0)

	# Update scanline
	if _scanline_enabled:
		_scanline_offset += delta * _scanline_speed
		if _scanline_offset > size.y:
			_scanline_offset = -20

	queue_redraw()


func _draw() -> void:
	if _current_intensity <= 0.01:
		return

	_draw_glow()

	if _scanline_enabled:
		_draw_scanlines()


# ══════════════════════════════════════════════════════════════════════════════
# GLOW RENDERING
# ══════════════════════════════════════════════════════════════════════════════

func _draw_glow() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var glow_color: Color = _glow_color
	glow_color.a = _current_intensity

	# Outer glow (multiple expanding rectangles with decreasing alpha)
	if _outer_glow:
		var layers: int = 8
		for i in range(layers):
			var t: float = float(i) / layers
			var expand: float = t * _glow_size
			var alpha: float = (1.0 - t * t) * glow_color.a * 0.3

			var layer_color: Color = glow_color
			layer_color.a = alpha

			var expanded_rect: Rect2 = rect.grow(expand)
			_draw_rounded_rect_outline(expanded_rect, layer_color, 2.0, 8.0 + expand * 0.5)

	# Inner glow
	if _inner_glow:
		var inner_layers: int = 4
		for i in range(inner_layers):
			var t: float = float(i) / inner_layers
			var inset: float = t * 5.0
			var alpha: float = (1.0 - t) * glow_color.a * 0.5

			var layer_color: Color = glow_color
			layer_color.a = alpha

			var inset_rect: Rect2 = rect.grow(-inset)
			if inset_rect.size.x > 0 and inset_rect.size.y > 0:
				draw_rect(inset_rect, layer_color, false, 2.0)

	# Edge highlight
	var edge_color: Color = glow_color
	edge_color.a = _current_intensity * 0.8
	_draw_rounded_rect_outline(rect, edge_color, 2.0, 8.0)


func _draw_rounded_rect_outline(rect: Rect2, color: Color, width: float, radius: float) -> void:
	# Draw rounded rectangle outline using line segments
	var points: PackedVector2Array = _get_rounded_rect_points(rect, radius)
	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		draw_line(points[i], points[next_i], color, width, true)


func _get_rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segments_per_corner: int = 4

	# Clamp radius
	radius = minf(radius, minf(rect.size.x, rect.size.y) / 2.0)

	# Top-left corner
	for i in range(segments_per_corner + 1):
		var angle: float = PI + (PI / 2) * (float(i) / segments_per_corner)
		var point: Vector2 = rect.position + Vector2(radius, radius)
		point += Vector2(cos(angle), sin(angle)) * radius
		points.append(point)

	# Top-right corner
	for i in range(segments_per_corner + 1):
		var angle: float = -PI / 2 + (PI / 2) * (float(i) / segments_per_corner)
		var point: Vector2 = rect.position + Vector2(rect.size.x - radius, radius)
		point += Vector2(cos(angle), sin(angle)) * radius
		points.append(point)

	# Bottom-right corner
	for i in range(segments_per_corner + 1):
		var angle: float = 0 + (PI / 2) * (float(i) / segments_per_corner)
		var point: Vector2 = rect.position + Vector2(rect.size.x - radius, rect.size.y - radius)
		point += Vector2(cos(angle), sin(angle)) * radius
		points.append(point)

	# Bottom-left corner
	for i in range(segments_per_corner + 1):
		var angle: float = PI / 2 + (PI / 2) * (float(i) / segments_per_corner)
		var point: Vector2 = rect.position + Vector2(radius, rect.size.y - radius)
		point += Vector2(cos(angle), sin(angle)) * radius
		points.append(point)

	return points


func _draw_scanlines() -> void:
	var scanline_color := Color(1.0, 1.0, 1.0, 0.03)
	var line_spacing: float = 4.0

	var y: float = fmod(_scanline_offset, line_spacing)
	while y < size.y:
		draw_line(
			Vector2(0, y),
			Vector2(size.x, y),
			scanline_color,
			1.0
		)
		y += line_spacing

	# Moving highlight scanline
	if _scanline_offset >= 0 and _scanline_offset < size.y:
		var highlight_color := Color(_glow_color.r, _glow_color.g, _glow_color.b, 0.2)
		draw_line(
			Vector2(0, _scanline_offset),
			Vector2(size.x, _scanline_offset),
			highlight_color,
			2.0
		)


# ══════════════════════════════════════════════════════════════════════════════
# STATE MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

func set_state(state: GlowState) -> void:
	if _state == state:
		return

	_state = state
	glow_state_changed.emit(state)

	match state:
		GlowState.IDLE:
			if pulse_on_idle:
				start_pulse()
			else:
				_transition_to_intensity(INTENSITY_IDLE)
		GlowState.HOVER:
			stop_pulse()
			_transition_to_intensity(INTENSITY_HOVER)
		GlowState.ACTIVE:
			stop_pulse()
			_flash_and_settle(INTENSITY_ACTIVE, INTENSITY_HOVER)
		GlowState.DISABLED:
			stop_pulse()
			_transition_to_intensity(0.0)
		GlowState.PULSE:
			start_pulse()
		GlowState.ALERT:
			_alert_flash()


func _transition_to_intensity(intensity: float) -> void:
	if _transition_tween:
		_transition_tween.kill()

	_transition_tween = create_tween()
	_transition_tween.tween_property(self, "_target_intensity", intensity, TRANSITION_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)


func _flash_and_settle(flash_intensity: float, settle_intensity: float) -> void:
	if _transition_tween:
		_transition_tween.kill()

	_transition_tween = create_tween()
	_transition_tween.tween_property(self, "_target_intensity", flash_intensity, 0.05)
	_transition_tween.tween_property(self, "_target_intensity", settle_intensity, 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)


func _alert_flash() -> void:
	if _transition_tween:
		_transition_tween.kill()

	_transition_tween = create_tween()
	_transition_tween.set_loops(3)

	_transition_tween.tween_property(self, "_target_intensity", INTENSITY_ACTIVE, ALERT_FLASH_DURATION / 2)
	_transition_tween.tween_property(self, "_target_intensity", INTENSITY_IDLE, ALERT_FLASH_DURATION / 2)


# ══════════════════════════════════════════════════════════════════════════════
# PULSE ANIMATION
# ══════════════════════════════════════════════════════════════════════════════

func start_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()

	_pulse_tween = create_tween()
	_pulse_tween.set_loops()

	_pulse_tween.tween_property(self, "_target_intensity", INTENSITY_PULSE_MAX, PULSE_DURATION / 2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	_pulse_tween.tween_property(self, "_target_intensity", INTENSITY_PULSE_MIN, PULSE_DURATION / 2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


func stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null


## Pulse once (non-looping)
func pulse_once(intensity: float = INTENSITY_PULSE_MAX) -> void:
	if _pulse_tween:
		_pulse_tween.kill()

	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "_target_intensity", intensity, PULSE_DURATION / 4)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	_pulse_tween.tween_property(self, "_target_intensity", INTENSITY_IDLE, PULSE_DURATION / 2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	_pulse_tween.tween_callback(func(): glow_pulse_completed.emit())


# ══════════════════════════════════════════════════════════════════════════════
# COLOR MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

func set_glow_color(color: Color) -> void:
	_glow_color = color


func set_glow_type(type: String) -> void:
	if GLOW_COLORS.has(type):
		_glow_color = GLOW_COLORS[type]
		glow_type = type


## Animate color transition
func transition_color(to_color: Color, duration: float = 0.3) -> Tween:
	var tween: Tween = create_tween()
	tween.tween_property(self, "_glow_color", to_color, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	return tween


## Color cycling animation
func start_color_cycle(colors: Array[Color], duration_per_color: float = 1.0) -> void:
	if colors.is_empty():
		return

	var tween: Tween = create_tween()
	tween.set_loops()

	for color in colors:
		tween.tween_property(self, "_glow_color", color, duration_per_color)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)


# ══════════════════════════════════════════════════════════════════════════════
# UTILITY
# ══════════════════════════════════════════════════════════════════════════════

## Get current intensity
func get_intensity() -> float:
	return _current_intensity


## Set intensity directly (no animation)
func set_intensity(intensity: float) -> void:
	_target_intensity = intensity
	_current_intensity = intensity


## Configure glow appearance
func configure(p_size: float, p_softness: float, p_inner: bool, p_outer: bool) -> void:
	_glow_size = p_size
	_glow_softness = p_softness
	_inner_glow = p_inner
	_outer_glow = p_outer


# ══════════════════════════════════════════════════════════════════════════════
# STATIC HELPERS
# ══════════════════════════════════════════════════════════════════════════════

## Create a glow effect for a control
static func create_for_control(control: Control, type: String = "primary") -> UIGlowEffect:
	var glow := UIGlowEffect.new()
	glow.glow_type = type
	glow.size = control.size
	glow.position = Vector2.ZERO

	# Add as first child so it renders behind content
	control.add_child(glow)
	control.move_child(glow, 0)

	# Keep size synced
	control.resized.connect(func(): glow.size = control.size)

	return glow


## Apply glow effect to a button with automatic state handling
static func apply_to_button(button: Button, type: String = "primary") -> UIGlowEffect:
	var glow := create_for_control(button, type)

	# Connect button signals
	button.mouse_entered.connect(func(): glow.set_state(GlowState.HOVER))
	button.mouse_exited.connect(func(): glow.set_state(GlowState.IDLE))
	button.pressed.connect(func(): glow.set_state(GlowState.ACTIVE))
	button.button_down.connect(func(): glow.set_state(GlowState.ACTIVE))
	button.button_up.connect(func():
		if button.is_hovered():
			glow.set_state(GlowState.HOVER)
		else:
			glow.set_state(GlowState.IDLE)
	)

	# Handle disabled state
	button.draw.connect(func():
		if button.disabled:
			glow.set_state(GlowState.DISABLED)
	)

	return glow


## Apply glow effect to a panel
static func apply_to_panel(panel: PanelContainer, type: String = "neutral") -> UIGlowEffect:
	var glow := create_for_control(panel, type)
	glow.pulse_on_idle = false
	glow.set_intensity(INTENSITY_IDLE)
	return glow
