## Design System - Complete Token Library
## Provides all design tokens for consistent UI/UX across the entire application.
## Includes colors, typography, spacing, shadows, animations, and more.
class_name DesignSystem
extends RefCounted

## Color System - Primary Palette
const COLOR_PRIMARY_900: Color = Color(0.05, 0.15, 0.35, 1.0)
const COLOR_PRIMARY_800: Color = Color(0.10, 0.25, 0.45, 1.0)
const COLOR_PRIMARY_700: Color = Color(0.15, 0.35, 0.55, 1.0)
const COLOR_PRIMARY_600: Color = Color(0.20, 0.45, 0.70, 1.0)
const COLOR_PRIMARY_500: Color = Color(0.25, 0.55, 0.85, 1.0)  # Base primary
const COLOR_PRIMARY_400: Color = Color(0.40, 0.65, 0.90, 1.0)
const COLOR_PRIMARY_300: Color = Color(0.55, 0.75, 0.95, 1.0)
const COLOR_PRIMARY_200: Color = Color(0.70, 0.85, 0.97, 1.0)
const COLOR_PRIMARY_100: Color = Color(0.85, 0.93, 0.99, 1.0)

## Secondary Palette
const COLOR_SECONDARY_900: Color = Color(0.25, 0.10, 0.35, 1.0)
const COLOR_SECONDARY_500: Color = Color(0.50, 0.30, 0.70, 1.0)
const COLOR_SECONDARY_100: Color = Color(0.90, 0.85, 0.95, 1.0)

## Success Palette
const COLOR_SUCCESS_900: Color = Color(0.05, 0.25, 0.10, 1.0)
const COLOR_SUCCESS_500: Color = Color(0.20, 0.70, 0.30, 1.0)
const COLOR_SUCCESS_100: Color = Color(0.85, 0.97, 0.88, 1.0)

## Warning Palette
const COLOR_WARNING_900: Color = Color(0.35, 0.25, 0.05, 1.0)
const COLOR_WARNING_500: Color = Color(0.90, 0.70, 0.20, 1.0)
const COLOR_WARNING_100: Color = Color(0.99, 0.95, 0.85, 1.0)

## Error/Danger Palette
const COLOR_DANGER_900: Color = Color(0.35, 0.05, 0.05, 1.0)
const COLOR_DANGER_500: Color = Color(0.90, 0.20, 0.15, 1.0)
const COLOR_DANGER_100: Color = Color(0.99, 0.88, 0.87, 1.0)

## Neutral Palette (Grays)
const COLOR_NEUTRAL_950: Color = Color(0.05, 0.05, 0.05, 1.0)
const COLOR_NEUTRAL_900: Color = Color(0.10, 0.10, 0.10, 1.0)
const COLOR_NEUTRAL_800: Color = Color(0.15, 0.15, 0.15, 1.0)
const COLOR_NEUTRAL_700: Color = Color(0.25, 0.25, 0.25, 1.0)
const COLOR_NEUTRAL_600: Color = Color(0.35, 0.35, 0.35, 1.0)
const COLOR_NEUTRAL_500: Color = Color(0.50, 0.50, 0.50, 1.0)
const COLOR_NEUTRAL_400: Color = Color(0.65, 0.65, 0.65, 1.0)
const COLOR_NEUTRAL_300: Color = Color(0.75, 0.75, 0.75, 1.0)
const COLOR_NEUTRAL_200: Color = Color(0.85, 0.85, 0.85, 1.0)
const COLOR_NEUTRAL_100: Color = Color(0.93, 0.93, 0.93, 1.0)
const COLOR_NEUTRAL_50: Color = Color(0.98, 0.98, 0.98, 1.0)

## Semantic Colors
const COLOR_TEXT_PRIMARY: Color = COLOR_NEUTRAL_950
const COLOR_TEXT_SECONDARY: Color = COLOR_NEUTRAL_700
const COLOR_TEXT_DISABLED: Color = COLOR_NEUTRAL_400
const COLOR_TEXT_INVERSE: Color = COLOR_NEUTRAL_50

const COLOR_BACKGROUND_PRIMARY: Color = COLOR_NEUTRAL_50
const COLOR_BACKGROUND_SECONDARY: Color = COLOR_NEUTRAL_100
const COLOR_BACKGROUND_TERTIARY: Color = COLOR_NEUTRAL_200

const COLOR_BORDER_DEFAULT: Color = COLOR_NEUTRAL_300
const COLOR_BORDER_HOVER: Color = COLOR_NEUTRAL_500
const COLOR_BORDER_ACTIVE: Color = COLOR_PRIMARY_500

## Typography Scale (px)
const FONT_SIZE_XS: int = 12
const FONT_SIZE_SM: int = 14
const FONT_SIZE_BASE: int = 16
const FONT_SIZE_LG: int = 18
const FONT_SIZE_XL: int = 20
const FONT_SIZE_2XL: int = 24
const FONT_SIZE_3XL: int = 30
const FONT_SIZE_4XL: int = 36
const FONT_SIZE_5XL: int = 48
const FONT_SIZE_6XL: int = 64

## Line Heights
const LINE_HEIGHT_TIGHT: float = 1.25
const LINE_HEIGHT_NORMAL: float = 1.5
const LINE_HEIGHT_RELAXED: float = 1.75
const LINE_HEIGHT_LOOSE: float = 2.0

## Font Weights
const FONT_WEIGHT_LIGHT: int = 300
const FONT_WEIGHT_NORMAL: int = 400
const FONT_WEIGHT_MEDIUM: int = 500
const FONT_WEIGHT_SEMIBOLD: int = 600
const FONT_WEIGHT_BOLD: int = 700
const FONT_WEIGHT_EXTRABOLD: int = 800

## Spacing Scale (px) - Multiples of 4
const SPACING_0: int = 0
const SPACING_1: int = 4
const SPACING_2: int = 8
const SPACING_3: int = 12
const SPACING_4: int = 16
const SPACING_5: int = 20
const SPACING_6: int = 24
const SPACING_8: int = 32
const SPACING_10: int = 40
const SPACING_12: int = 48
const SPACING_16: int = 64
const SPACING_20: int = 80
const SPACING_24: int = 96
const SPACING_32: int = 128

## Border Radius Scale (px)
const RADIUS_NONE: int = 0
const RADIUS_SM: int = 4
const RADIUS_BASE: int = 8
const RADIUS_MD: int = 12
const RADIUS_LG: int = 16
const RADIUS_XL: int = 20
const RADIUS_2XL: int = 24
const RADIUS_3XL: int = 32
const RADIUS_FULL: int = 9999

## Shadow Elevations
const SHADOW_NONE: Dictionary = {"offset": Vector2.ZERO, "blur": 0, "spread": 0, "color": Color.TRANSPARENT}
const SHADOW_SM: Dictionary = {"offset": Vector2(0, 1), "blur": 2, "spread": 0, "color": Color(0, 0, 0, 0.05)}
const SHADOW_BASE: Dictionary = {"offset": Vector2(0, 2), "blur": 4, "spread": 0, "color": Color(0, 0, 0, 0.1)}
const SHADOW_MD: Dictionary = {"offset": Vector2(0, 4), "blur": 8, "spread": 0, "color": Color(0, 0, 0, 0.12)}
const SHADOW_LG: Dictionary = {"offset": Vector2(0, 8), "blur": 16, "spread": 0, "color": Color(0, 0, 0, 0.15)}
const SHADOW_XL: Dictionary = {"offset": Vector2(0, 12), "blur": 24, "spread": 0, "color": Color(0, 0, 0, 0.18)}
const SHADOW_2XL: Dictionary = {"offset": Vector2(0, 16), "blur": 32, "spread": 0, "color": Color(0, 0, 0, 0.20)}

## Z-Index Layers
const Z_BACKGROUND: int = 0
const Z_CONTENT: int = 10
const Z_HEADER: int = 20
const Z_OVERLAY: int = 30
const Z_MODAL: int = 40
const Z_POPOVER: int = 50
const Z_TOOLTIP: int = 60
const Z_NOTIFICATION: int = 70

## Animation Durations (ms) - Following Material Design
const DURATION_INSTANT: float = 0.0
const DURATION_FAST: float = 0.1
const DURATION_NORMAL: float = 0.2
const DURATION_MODERATE: float = 0.3
const DURATION_SLOW: float = 0.4
const DURATION_SLOWER: float = 0.5
const DURATION_SLOWEST: float = 0.8

## Animation Timing Functions (mapped to Tween constants)
const EASE_LINEAR: int = Tween.TRANS_LINEAR
const EASE_SINE: int = Tween.TRANS_SINE
const EASE_QUAD: int = Tween.TRANS_QUAD
const EASE_CUBIC: int = Tween.TRANS_CUBIC
const EASE_QUART: int = Tween.TRANS_QUART
const EASE_QUINT: int = Tween.TRANS_QUINT
const EASE_EXPO: int = Tween.TRANS_EXPO
const EASE_CIRC: int = Tween.TRANS_CIRC
const EASE_BACK: int = Tween.TRANS_BACK
const EASE_ELASTIC: int = Tween.TRANS_ELASTIC
const EASE_BOUNCE: int = Tween.TRANS_BOUNCE

## Breakpoints (for responsive design)
const BREAKPOINT_XS: int = 320   # Small phones
const BREAKPOINT_SM: int = 640   # Large phones
const BREAKPOINT_MD: int = 768   # Tablets
const BREAKPOINT_LG: int = 1024  # Small laptops
const BREAKPOINT_XL: int = 1280  # Laptops
const BREAKPOINT_2XL: int = 1536 # Desktops

## Icon Sizes
const ICON_SIZE_XS: int = 12
const ICON_SIZE_SM: int = 16
const ICON_SIZE_BASE: int = 24
const ICON_SIZE_LG: int = 32
const ICON_SIZE_XL: int = 48
const ICON_SIZE_2XL: int = 64

## Touch Target Sizes (minimum for accessibility)
const TOUCH_TARGET_MIN: int = 44  # iOS/Android minimum
const TOUCH_TARGET_COMFORTABLE: int = 48
const TOUCH_TARGET_LARGE: int = 56

## Opacity Levels
const OPACITY_DISABLED: float = 0.38
const OPACITY_INACTIVE: float = 0.60
const OPACITY_ACTIVE: float = 1.0
const OPACITY_HOVER: float = 0.08  # Overlay opacity
const OPACITY_PRESSED: float = 0.12  # Overlay opacity

## Helper Functions

## Get color with alpha adjustment
static func color_with_alpha(color: Color, alpha: float) -> Color:
	var result: Color = color
	result.a = alpha
	return result

## Get spacing value
static func spacing(multiplier: float) -> float:
	return SPACING_4 * multiplier

## Get shadow style for StyleBoxFlat
static func apply_shadow(style_box: StyleBoxFlat, shadow: Dictionary) -> void:
	style_box.shadow_offset = shadow.get("offset", Vector2.ZERO)
	style_box.shadow_size = shadow.get("blur", 0) / 2
	style_box.shadow_color = shadow.get("color", Color.TRANSPARENT)

## Create a standard button StyleBoxFlat
static func create_button_style(
	bg_color: Color,
	border_color: Color = COLOR_TRANSPARENT,
	border_width: int = 0,
	corner_radius: int = RADIUS_BASE,
	shadow: Dictionary = SHADOW_SM
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color

	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width

	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius

	style.content_margin_left = SPACING_4
	style.content_margin_right = SPACING_4
	style.content_margin_top = SPACING_2
	style.content_margin_bottom = SPACING_2

	apply_shadow(style, shadow)

	return style

## Create a panel StyleBoxFlat
static func create_panel_style(
	bg_color: Color = COLOR_BACKGROUND_PRIMARY,
	border_color: Color = COLOR_BORDER_DEFAULT,
	border_width: int = 1,
	corner_radius: int = RADIUS_LG,
	shadow: Dictionary = SHADOW_MD
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color

	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width

	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius

	style.content_margin_left = SPACING_4
	style.content_margin_right = SPACING_4
	style.content_margin_top = SPACING_4
	style.content_margin_bottom = SPACING_4

	apply_shadow(style, shadow)

	return style

## Get responsive breakpoint
static func get_breakpoint(screen_width: float) -> String:
	if screen_width < BREAKPOINT_SM:
		return "xs"
	elif screen_width < BREAKPOINT_MD:
		return "sm"
	elif screen_width < BREAKPOINT_LG:
		return "md"
	elif screen_width < BREAKPOINT_XL:
		return "lg"
	elif screen_width < BREAKPOINT_2XL:
		return "xl"
	else:
		return "2xl"

## Interpolate between two colors
static func lerp_color(from: Color, to: Color, weight: float) -> Color:
	return from.lerp(to, weight)

## Darken a color
static func darken(color: Color, amount: float = 0.1) -> Color:
	return color.darkened(amount)

## Lighten a color
static func lighten(color: Color, amount: float = 0.1) -> Color:
	return color.lightened(amount)

## Adjust color saturation
static func adjust_saturation(color: Color, amount: float) -> Color:
	var hsv: Vector3 = rgb_to_hsv(color)
	hsv.y = clampf(hsv.y + amount, 0.0, 1.0)
	return hsv_to_rgb(hsv, color.a)

## Convert RGB to HSV
static func rgb_to_hsv(color: Color) -> Vector3:
	var r: float = color.r
	var g: float = color.g
	var b: float = color.b

	var max_c: float = maxf(maxf(r, g), b)
	var min_c: float = minf(minf(r, g), b)
	var delta: float = max_c - min_c

	var h: float = 0.0
	var s: float = 0.0 if max_c == 0.0 else delta / max_c
	var v: float = max_c

	if delta != 0.0:
		if max_c == r:
			h = 60.0 * fmod((g - b) / delta, 6.0)
		elif max_c == g:
			h = 60.0 * ((b - r) / delta + 2.0)
		else:
			h = 60.0 * ((r - g) / delta + 4.0)

		if h < 0.0:
			h += 360.0

	return Vector3(h, s, v)

## Convert HSV to RGB
static func hsv_to_rgb(hsv: Vector3, alpha: float = 1.0) -> Color:
	var h: float = hsv.x
	var s: float = hsv.y
	var v: float = hsv.z

	var c: float = v * s
	var x: float = c * (1.0 - absf(fmod(h / 60.0, 2.0) - 1.0))
	var m: float = v - c

	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0

	if h < 60.0:
		r = c; g = x; b = 0.0
	elif h < 120.0:
		r = x; g = c; b = 0.0
	elif h < 180.0:
		r = 0.0; g = c; b = x
	elif h < 240.0:
		r = 0.0; g = x; b = c
	elif h < 300.0:
		r = x; g = 0.0; b = c
	else:
		r = c; g = 0.0; b = x

	return Color(r + m, g + m, b + m, alpha)

## Create gradient
static func create_gradient(colors: Array[Color], offsets: Array[float] = []) -> Gradient:
	var gradient: Gradient = Gradient.new()

	if offsets.is_empty():
		# Evenly distribute colors
		for i: int in colors.size():
			var offset: float = float(i) / float(colors.size() - 1) if colors.size() > 1 else 0.0
			gradient.add_point(offset, colors[i])
	else:
		# Use provided offsets
		for i: int in mini(colors.size(), offsets.size()):
			gradient.add_point(offsets[i], colors[i])

	return gradient

## Constants for common gradients
static func gradient_primary() -> Gradient:
	return create_gradient([COLOR_PRIMARY_600, COLOR_PRIMARY_400])

static func gradient_success() -> Gradient:
	return create_gradient([COLOR_SUCCESS_500, COLOR_SUCCESS_300])

static func gradient_danger() -> Gradient:
	return create_gradient([COLOR_DANGER_600, COLOR_DANGER_400])

const COLOR_TRANSPARENT: Color = Color(0, 0, 0, 0)
