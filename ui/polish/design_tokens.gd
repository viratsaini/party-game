## DesignTokens - Ultra-precise design tokens for pixel-perfect UI polish
##
## This singleton provides the ULTIMATE source of truth for all visual design decisions.
## Every value follows strict mathematical ratios for absolute visual harmony.
##
## Token Categories:
## - Animation Timing (Golden Ratio based: 200ms, 320ms, 520ms)
## - Corner Radii (4px, 8px, 12px, 16px scale)
## - Shadow Elevations (2dp, 4dp, 8dp, 16dp)
## - Typography Scale (12px, 14px, 16px, 20px, 24px, 32px)
## - Spacing Grid (4px base, multiples of 4)
## - Icon Sizes (16px, 24px, 32px, 48px)
## - Touch Targets (minimum 44x44)
## - Contrast Ratios (WCAG AAA: 7:1)
##
## Usage:
##   var duration = DesignTokens.TIMING_FAST
##   var radius = DesignTokens.RADIUS_MD
##   DesignTokens.apply_shadow(panel, DesignTokens.ELEVATION_2DP)
class_name DesignTokens
extends RefCounted


# =============================================================================
# region - Animation Timing (Golden Ratio Based)
# =============================================================================

## The golden ratio for calculating harmonious timing sequences
const GOLDEN_RATIO: float = 1.618

## Base timing unit in seconds
const TIMING_UNIT: float = 0.2

## Instant - No animation (accessibility: reduce motion)
const TIMING_INSTANT: float = 0.0

## Micro - For subtle micro-interactions (50ms)
const TIMING_MICRO: float = 0.05

## Fast - Quick feedback, hover states (200ms - base)
const TIMING_FAST: float = 0.2

## Medium - Standard transitions (320ms - Golden Ratio)
const TIMING_MEDIUM: float = 0.32  # 0.2 * 1.618 rounded

## Slow - Panel transitions, modal entrances (520ms - Golden Ratio^2)
const TIMING_SLOW: float = 0.52   # 0.32 * 1.618 rounded

## Very Slow - Celebration animations, reveals (840ms - Golden Ratio^3)
const TIMING_VERY_SLOW: float = 0.84

## Ultra Slow - Epic moments, achievements (1360ms - Golden Ratio^4)
const TIMING_ULTRA_SLOW: float = 1.36

## Button States - Press/Release/Settle Sequence
const TIMING_BUTTON_PRESS: float = 0.05       ## Instant press feedback
const TIMING_BUTTON_RELEASE: float = 0.15     ## Release bounce
const TIMING_BUTTON_SETTLE: float = 0.2       ## Final settle

## Hover States
const TIMING_HOVER_ENTER: float = 0.1         ## Quick response
const TIMING_HOVER_EXIT: float = 0.15         ## Slightly slower exit

## Panel Transitions
const TIMING_PANEL_ENTER: float = 0.32        ## Entrance animation
const TIMING_PANEL_EXIT: float = 0.25         ## Faster exit (feels responsive)

## Modal/Dialog
const TIMING_MODAL_ENTER: float = 0.35
const TIMING_MODAL_EXIT: float = 0.25

## Toast/Notification
const TIMING_TOAST_ENTER: float = 0.25
const TIMING_TOAST_EXIT: float = 0.2

## Page Transitions
const TIMING_PAGE_TRANSITION: float = 0.4

## Loading/Progress
const TIMING_LOADING_SPIN: float = 1.0        ## Full rotation duration
const TIMING_PROGRESS_UPDATE: float = 0.3     ## Progress bar updates

## Stagger Delays (for sequential animations)
const TIMING_STAGGER_FAST: float = 0.05
const TIMING_STAGGER_NORMAL: float = 0.1
const TIMING_STAGGER_SLOW: float = 0.15

# endregion


# =============================================================================
# region - Corner Radii (4px Scale)
# =============================================================================

## No radius - Sharp corners
const RADIUS_NONE: float = 0.0

## Extra Small - 4px (badges, tags)
const RADIUS_XS: float = 4.0

## Small - 8px (buttons, inputs)
const RADIUS_SM: float = 8.0

## Medium - 12px (cards, panels)
const RADIUS_MD: float = 12.0

## Large - 16px (modals, dialogs)
const RADIUS_LG: float = 16.0

## Extra Large - 24px (hero sections)
const RADIUS_XL: float = 24.0

## 2X Large - 32px (special containers)
const RADIUS_2XL: float = 32.0

## Full/Pill - Maximum radius for pill shapes
const RADIUS_FULL: float = 9999.0

## Component-specific radii
const RADIUS_BUTTON: float = 8.0
const RADIUS_BUTTON_SM: float = 4.0
const RADIUS_BUTTON_LG: float = 12.0
const RADIUS_INPUT: float = 6.0
const RADIUS_CARD: float = 12.0
const RADIUS_MODAL: float = 16.0
const RADIUS_TOOLTIP: float = 6.0
const RADIUS_BADGE: float = 4.0
const RADIUS_AVATAR: float = 9999.0
const RADIUS_CHECKBOX: float = 4.0
const RADIUS_PROGRESS: float = 9999.0

# endregion


# =============================================================================
# region - Shadow Elevations (Material Design Inspired)
# =============================================================================

## 0dp - No elevation (flat)
const ELEVATION_0DP: Dictionary = {
	"offset": Vector2.ZERO,
	"blur": 0.0,
	"spread": 0.0,
	"color": Color.TRANSPARENT
}

## 2dp - Subtle elevation (cards at rest)
const ELEVATION_2DP: Dictionary = {
	"offset": Vector2(0, 1),
	"blur": 3.0,
	"spread": 0.0,
	"color": Color(0, 0, 0, 0.12)
}

## 4dp - Low elevation (raised buttons, FABs)
const ELEVATION_4DP: Dictionary = {
	"offset": Vector2(0, 2),
	"blur": 4.0,
	"spread": 0.0,
	"color": Color(0, 0, 0, 0.14)
}

## 8dp - Medium elevation (menus, dialogs)
const ELEVATION_8DP: Dictionary = {
	"offset": Vector2(0, 5),
	"blur": 10.0,
	"spread": 0.0,
	"color": Color(0, 0, 0, 0.18)
}

## 16dp - High elevation (modals, notifications)
const ELEVATION_16DP: Dictionary = {
	"offset": Vector2(0, 8),
	"blur": 20.0,
	"spread": 0.0,
	"color": Color(0, 0, 0, 0.22)
}

## 24dp - Maximum elevation (floating elements)
const ELEVATION_24DP: Dictionary = {
	"offset": Vector2(0, 12),
	"blur": 30.0,
	"spread": 0.0,
	"color": Color(0, 0, 0, 0.25)
}

## Inner shadow for pressed states
const SHADOW_INNER: Dictionary = {
	"offset": Vector2(0, 2),
	"blur": 4.0,
	"spread": -1.0,
	"color": Color(0, 0, 0, 0.08)
}

## Glow shadows for emphasis
const GLOW_PRIMARY: Dictionary = {
	"offset": Vector2.ZERO,
	"blur": 12.0,
	"spread": 2.0,
	"color": Color(0.13, 0.59, 0.95, 0.4)  # Primary blue
}

const GLOW_SUCCESS: Dictionary = {
	"offset": Vector2.ZERO,
	"blur": 12.0,
	"spread": 2.0,
	"color": Color(0.3, 0.69, 0.31, 0.4)   # Success green
}

const GLOW_ERROR: Dictionary = {
	"offset": Vector2.ZERO,
	"blur": 12.0,
	"spread": 2.0,
	"color": Color(0.96, 0.26, 0.21, 0.4)  # Error red
}

const GLOW_WARNING: Dictionary = {
	"offset": Vector2.ZERO,
	"blur": 12.0,
	"spread": 2.0,
	"color": Color(1.0, 0.6, 0.0, 0.4)     # Warning orange
}

const GLOW_ACCENT: Dictionary = {
	"offset": Vector2.ZERO,
	"blur": 16.0,
	"spread": 4.0,
	"color": Color(1.0, 0.76, 0.03, 0.5)   # Accent gold
}

# endregion


# =============================================================================
# region - Typography Scale
# =============================================================================

## Font sizes in pixels
const FONT_SIZE_MICRO: int = 9
const FONT_SIZE_XS: int = 10
const FONT_SIZE_SM: int = 12
const FONT_SIZE_BASE: int = 14
const FONT_SIZE_MD: int = 16
const FONT_SIZE_LG: int = 20
const FONT_SIZE_XL: int = 24
const FONT_SIZE_2XL: int = 32
const FONT_SIZE_3XL: int = 40
const FONT_SIZE_4XL: int = 48
const FONT_SIZE_5XL: int = 64
const FONT_SIZE_6XL: int = 72

## Display/Hero sizes
const FONT_SIZE_DISPLAY_SM: int = 30
const FONT_SIZE_DISPLAY_MD: int = 36
const FONT_SIZE_DISPLAY_LG: int = 48
const FONT_SIZE_DISPLAY_XL: int = 60
const FONT_SIZE_DISPLAY_2XL: int = 72

## Line heights (multipliers)
const LINE_HEIGHT_TIGHT: float = 1.1
const LINE_HEIGHT_SNUG: float = 1.25
const LINE_HEIGHT_NORMAL: float = 1.5
const LINE_HEIGHT_RELAXED: float = 1.75
const LINE_HEIGHT_LOOSE: float = 2.0

## Letter spacing (em units)
const LETTER_SPACING_TIGHTER: float = -0.05
const LETTER_SPACING_TIGHT: float = -0.025
const LETTER_SPACING_NORMAL: float = 0.0
const LETTER_SPACING_WIDE: float = 0.025
const LETTER_SPACING_WIDER: float = 0.05
const LETTER_SPACING_WIDEST: float = 0.1

## Font weights
const FONT_WEIGHT_THIN: int = 100
const FONT_WEIGHT_LIGHT: int = 300
const FONT_WEIGHT_REGULAR: int = 400
const FONT_WEIGHT_MEDIUM: int = 500
const FONT_WEIGHT_SEMIBOLD: int = 600
const FONT_WEIGHT_BOLD: int = 700
const FONT_WEIGHT_EXTRABOLD: int = 800
const FONT_WEIGHT_BLACK: int = 900

# endregion


# =============================================================================
# region - Spacing Grid (4px Base)
# =============================================================================

## Base spacing unit
const SPACING_UNIT: float = 4.0

## Spacing scale
const SPACE_0: float = 0.0
const SPACE_PX: float = 1.0
const SPACE_0_5: float = 2.0    # 0.5 units
const SPACE_1: float = 4.0      # 1 unit
const SPACE_1_5: float = 6.0    # 1.5 units
const SPACE_2: float = 8.0      # 2 units
const SPACE_2_5: float = 10.0   # 2.5 units
const SPACE_3: float = 12.0     # 3 units
const SPACE_3_5: float = 14.0   # 3.5 units
const SPACE_4: float = 16.0     # 4 units
const SPACE_5: float = 20.0     # 5 units
const SPACE_6: float = 24.0     # 6 units
const SPACE_7: float = 28.0     # 7 units
const SPACE_8: float = 32.0     # 8 units
const SPACE_9: float = 36.0     # 9 units
const SPACE_10: float = 40.0    # 10 units
const SPACE_11: float = 44.0    # 11 units (touch target)
const SPACE_12: float = 48.0    # 12 units
const SPACE_14: float = 56.0    # 14 units
const SPACE_16: float = 64.0    # 16 units
const SPACE_20: float = 80.0    # 20 units
const SPACE_24: float = 96.0    # 24 units
const SPACE_28: float = 112.0   # 28 units
const SPACE_32: float = 128.0   # 32 units
const SPACE_36: float = 144.0   # 36 units
const SPACE_40: float = 160.0   # 40 units
const SPACE_48: float = 192.0   # 48 units
const SPACE_56: float = 224.0   # 56 units
const SPACE_64: float = 256.0   # 64 units

## Common component padding
const PADDING_BUTTON_SM: Vector2 = Vector2(12, 8)
const PADDING_BUTTON_MD: Vector2 = Vector2(16, 12)
const PADDING_BUTTON_LG: Vector2 = Vector2(24, 16)
const PADDING_INPUT: Vector2 = Vector2(12, 10)
const PADDING_CARD: Vector2 = Vector2(16, 16)
const PADDING_MODAL: Vector2 = Vector2(24, 20)
const PADDING_SECTION: Vector2 = Vector2(24, 32)

# endregion


# =============================================================================
# region - Icon Sizes
# =============================================================================

## Icon size scale
const ICON_XS: float = 12.0
const ICON_SM: float = 16.0
const ICON_MD: float = 20.0
const ICON_BASE: float = 24.0
const ICON_LG: float = 32.0
const ICON_XL: float = 48.0
const ICON_2XL: float = 64.0
const ICON_3XL: float = 96.0

## Icon sizes for specific contexts
const ICON_BUTTON: float = 20.0
const ICON_MENU: float = 24.0
const ICON_NAV: float = 24.0
const ICON_TOOLBAR: float = 20.0
const ICON_AVATAR_SM: float = 32.0
const ICON_AVATAR_MD: float = 40.0
const ICON_AVATAR_LG: float = 64.0

# endregion


# =============================================================================
# region - Touch Targets & Accessibility
# =============================================================================

## Minimum touch target (WCAG 2.5.5 Level AAA)
const TOUCH_TARGET_MIN: float = 44.0

## Recommended touch target
const TOUCH_TARGET_RECOMMENDED: float = 48.0

## Comfortable touch target
const TOUCH_TARGET_COMFORTABLE: float = 56.0

## Minimum spacing between touch targets
const TOUCH_TARGET_SPACING: float = 8.0

## WCAG Contrast Requirements
const CONTRAST_RATIO_AA_NORMAL: float = 4.5   # Normal text AA
const CONTRAST_RATIO_AA_LARGE: float = 3.0    # Large text AA
const CONTRAST_RATIO_AAA_NORMAL: float = 7.0  # Normal text AAA
const CONTRAST_RATIO_AAA_LARGE: float = 4.5   # Large text AAA

## Focus indicator sizes
const FOCUS_RING_WIDTH: float = 3.0
const FOCUS_RING_OFFSET: float = 2.0
const FOCUS_RING_RADIUS_OFFSET: float = 2.0

# endregion


# =============================================================================
# region - Interactive Element Feedback
# =============================================================================

## Hover scale factors
const SCALE_HOVER: float = 1.05
const SCALE_HOVER_SUBTLE: float = 1.02
const SCALE_HOVER_STRONG: float = 1.08

## Press scale factors
const SCALE_PRESS: float = 0.95
const SCALE_PRESS_SUBTLE: float = 0.98
const SCALE_PRESS_STRONG: float = 0.92

## Settle scale (returns to normal)
const SCALE_NORMAL: float = 1.0

## Opacity values
const OPACITY_DISABLED: float = 0.5
const OPACITY_HOVER_OVERLAY: float = 0.08
const OPACITY_PRESS_OVERLAY: float = 0.12
const OPACITY_FOCUS_OVERLAY: float = 0.12
const OPACITY_SELECTED_OVERLAY: float = 0.16

## Button state colors (overlays)
const OVERLAY_HOVER: Color = Color(1, 1, 1, 0.08)
const OVERLAY_PRESS: Color = Color(0, 0, 0, 0.12)
const OVERLAY_FOCUS: Color = Color(1, 1, 1, 0.12)
const OVERLAY_DISABLED: Color = Color(0, 0, 0, 0.38)

# endregion


# =============================================================================
# region - Easing Curves
# =============================================================================

## Standard easing (default for most animations)
const EASE_STANDARD: Dictionary = {
	"trans": Tween.TRANS_CUBIC,
	"ease": Tween.EASE_OUT
}

## Decelerate (entering elements)
const EASE_DECELERATE: Dictionary = {
	"trans": Tween.TRANS_CUBIC,
	"ease": Tween.EASE_OUT
}

## Accelerate (exiting elements)
const EASE_ACCELERATE: Dictionary = {
	"trans": Tween.TRANS_CUBIC,
	"ease": Tween.EASE_IN
}

## Standard symmetrical (for reversible animations)
const EASE_SYMMETRIC: Dictionary = {
	"trans": Tween.TRANS_CUBIC,
	"ease": Tween.EASE_IN_OUT
}

## Elastic (for bouncy/playful animations)
const EASE_ELASTIC: Dictionary = {
	"trans": Tween.TRANS_ELASTIC,
	"ease": Tween.EASE_OUT
}

## Back (for overshoot effects)
const EASE_BACK: Dictionary = {
	"trans": Tween.TRANS_BACK,
	"ease": Tween.EASE_OUT
}

## Bounce (for impact effects)
const EASE_BOUNCE: Dictionary = {
	"trans": Tween.TRANS_BOUNCE,
	"ease": Tween.EASE_OUT
}

## Spring (natural physical motion)
const EASE_SPRING: Dictionary = {
	"trans": Tween.TRANS_SPRING,
	"ease": Tween.EASE_OUT
}

## Button-specific easings
const EASE_BUTTON_PRESS: Dictionary = {
	"trans": Tween.TRANS_QUAD,
	"ease": Tween.EASE_OUT
}

const EASE_BUTTON_RELEASE: Dictionary = {
	"trans": Tween.TRANS_BACK,
	"ease": Tween.EASE_OUT
}

## Panel-specific easings
const EASE_PANEL_ENTER: Dictionary = {
	"trans": Tween.TRANS_BACK,
	"ease": Tween.EASE_OUT
}

const EASE_PANEL_EXIT: Dictionary = {
	"trans": Tween.TRANS_CUBIC,
	"ease": Tween.EASE_IN
}

# endregion


# =============================================================================
# region - Color Tokens
# =============================================================================

## Primary palette (Blue)
const COLOR_PRIMARY_50: Color = Color("e3f2fd")
const COLOR_PRIMARY_100: Color = Color("bbdefb")
const COLOR_PRIMARY_200: Color = Color("90caf9")
const COLOR_PRIMARY_300: Color = Color("64b5f6")
const COLOR_PRIMARY_400: Color = Color("42a5f5")
const COLOR_PRIMARY_500: Color = Color("2196f3")  # Main
const COLOR_PRIMARY_600: Color = Color("1e88e5")
const COLOR_PRIMARY_700: Color = Color("1976d2")
const COLOR_PRIMARY_800: Color = Color("1565c0")
const COLOR_PRIMARY_900: Color = Color("0d47a1")

## Success palette (Green)
const COLOR_SUCCESS_50: Color = Color("e8f5e9")
const COLOR_SUCCESS_500: Color = Color("4caf50")  # Main
const COLOR_SUCCESS_700: Color = Color("388e3c")

## Warning palette (Orange)
const COLOR_WARNING_50: Color = Color("fff3e0")
const COLOR_WARNING_500: Color = Color("ff9800")  # Main
const COLOR_WARNING_700: Color = Color("f57c00")

## Error palette (Red)
const COLOR_ERROR_50: Color = Color("ffebee")
const COLOR_ERROR_500: Color = Color("f44336")   # Main
const COLOR_ERROR_700: Color = Color("d32f2f")

## Neutral palette
const COLOR_NEUTRAL_0: Color = Color("ffffff")
const COLOR_NEUTRAL_50: Color = Color("fafafa")
const COLOR_NEUTRAL_100: Color = Color("f5f5f5")
const COLOR_NEUTRAL_200: Color = Color("eeeeee")
const COLOR_NEUTRAL_300: Color = Color("e0e0e0")
const COLOR_NEUTRAL_400: Color = Color("bdbdbd")
const COLOR_NEUTRAL_500: Color = Color("9e9e9e")
const COLOR_NEUTRAL_600: Color = Color("757575")
const COLOR_NEUTRAL_700: Color = Color("616161")
const COLOR_NEUTRAL_800: Color = Color("424242")
const COLOR_NEUTRAL_900: Color = Color("212121")
const COLOR_NEUTRAL_1000: Color = Color("000000")

## Surface colors (Dark theme)
const COLOR_SURFACE_DEFAULT: Color = Color("1e1e2e")
const COLOR_SURFACE_ELEVATED: Color = Color("2a2a3e")
const COLOR_SURFACE_HOVER: Color = Color("363650")
const COLOR_SURFACE_PRESSED: Color = Color("424260")
const COLOR_SURFACE_DISABLED: Color = Color("181825")

## Background colors
const COLOR_BACKGROUND_DEFAULT: Color = Color("11111b")
const COLOR_BACKGROUND_SECONDARY: Color = Color("181825")
const COLOR_BACKGROUND_TERTIARY: Color = Color("1e1e2e")

## Text colors
const COLOR_TEXT_PRIMARY: Color = Color("f5f5f5")
const COLOR_TEXT_SECONDARY: Color = Color("bdbdbd")
const COLOR_TEXT_DISABLED: Color = Color("757575")
const COLOR_TEXT_HINT: Color = Color("9e9e9e")

## Focus color
const COLOR_FOCUS: Color = Color("ffc107")  # Bright yellow for visibility

# endregion


# =============================================================================
# region - Z-Index Layers
# =============================================================================

const Z_INDEX_DEFAULT: int = 0
const Z_INDEX_DROPDOWN: int = 1000
const Z_INDEX_STICKY: int = 1100
const Z_INDEX_FIXED: int = 1200
const Z_INDEX_MODAL_BACKDROP: int = 1300
const Z_INDEX_MODAL: int = 1400
const Z_INDEX_POPOVER: int = 1500
const Z_INDEX_TOOLTIP: int = 1600
const Z_INDEX_NOTIFICATION: int = 1700
const Z_INDEX_OVERLAY: int = 1800
const Z_INDEX_DEBUG: int = 9999

# endregion


# =============================================================================
# region - Static Utility Functions
# =============================================================================

## Gets spacing value by multiplier
static func spacing(multiplier: float) -> float:
	return multiplier * SPACING_UNIT


## Creates a Vector2 for uniform padding
static func padding_uniform(value: float) -> Vector2:
	return Vector2(value, value)


## Creates a Vector2 for horizontal/vertical padding
static func padding_xy(horizontal: float, vertical: float) -> Vector2:
	return Vector2(horizontal, vertical)


## Applies consistent tween settings
static func apply_tween_ease(tween: Tween, ease_config: Dictionary) -> Tween:
	return tween.set_trans(ease_config.get("trans", Tween.TRANS_CUBIC))\
		.set_ease(ease_config.get("ease", Tween.EASE_OUT))


## Creates a consistent shadow StyleBoxFlat
static func create_shadow_stylebox(elevation: Dictionary, radius: float = RADIUS_MD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.shadow_offset = elevation.get("offset", Vector2.ZERO)
	style.shadow_size = int(elevation.get("blur", 0))
	style.shadow_color = elevation.get("color", Color.TRANSPARENT)
	return style


## Creates focus indicator StyleBox
static func create_focus_stylebox(color: Color = COLOR_FOCUS, width: float = FOCUS_RING_WIDTH) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_width_left = int(width)
	style.border_width_right = int(width)
	style.border_width_top = int(width)
	style.border_width_bottom = int(width)
	style.border_color = color
	style.corner_radius_bottom_left = int(RADIUS_SM + FOCUS_RING_RADIUS_OFFSET)
	style.corner_radius_bottom_right = int(RADIUS_SM + FOCUS_RING_RADIUS_OFFSET)
	style.corner_radius_top_left = int(RADIUS_SM + FOCUS_RING_RADIUS_OFFSET)
	style.corner_radius_top_right = int(RADIUS_SM + FOCUS_RING_RADIUS_OFFSET)
	return style


## Calculates contrast ratio between two colors (WCAG)
static func calculate_contrast_ratio(foreground: Color, background: Color) -> float:
	var fg_luminance := get_relative_luminance(foreground)
	var bg_luminance := get_relative_luminance(background)
	var lighter := maxf(fg_luminance, bg_luminance)
	var darker := minf(fg_luminance, bg_luminance)
	return (lighter + 0.05) / (darker + 0.05)


## Gets relative luminance of a color
static func get_relative_luminance(color: Color) -> float:
	var r := color.r
	var g := color.g
	var b := color.b
	r = r / 12.92 if r <= 0.03928 else pow((r + 0.055) / 1.055, 2.4)
	g = g / 12.92 if g <= 0.03928 else pow((g + 0.055) / 1.055, 2.4)
	b = b / 12.92 if b <= 0.03928 else pow((b + 0.055) / 1.055, 2.4)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b


## Checks if contrast meets WCAG AAA requirements
static func meets_wcag_aaa(foreground: Color, background: Color, large_text: bool = false) -> bool:
	var ratio := calculate_contrast_ratio(foreground, background)
	return ratio >= CONTRAST_RATIO_AAA_LARGE if large_text else ratio >= CONTRAST_RATIO_AAA_NORMAL


## Validates touch target size
static func validate_touch_target(control: Control) -> bool:
	return control.size.x >= TOUCH_TARGET_MIN and control.size.y >= TOUCH_TARGET_MIN


## Gets animation duration based on user preferences (accessibility)
static func get_animation_duration(base_duration: float, reduce_motion: bool = false) -> float:
	if reduce_motion:
		return TIMING_INSTANT
	return base_duration


## Gets appropriate icon size for context
static func get_icon_size(context: String) -> float:
	match context:
		"button": return ICON_BUTTON
		"menu": return ICON_MENU
		"nav": return ICON_NAV
		"toolbar": return ICON_TOOLBAR
		_: return ICON_BASE


## Creates a complete button press-release-settle animation sequence
static func create_button_animation_sequence(
	button: Control,
	on_press: Callable = Callable(),
	on_release: Callable = Callable()
) -> void:
	# Ensure pivot is centered
	button.pivot_offset = button.size / 2

	button.button_down.connect(func():
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2.ONE * SCALE_PRESS, TIMING_BUTTON_PRESS)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		if on_press.is_valid():
			on_press.call()
	)

	button.button_up.connect(func():
		var tween := button.create_tween()
		tween.set_parallel(false)
		# Release with overshoot
		tween.tween_property(button, "scale", Vector2.ONE * SCALE_HOVER, TIMING_BUTTON_RELEASE)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
		# Settle back to normal
		tween.tween_property(button, "scale", Vector2.ONE, TIMING_BUTTON_SETTLE)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)
		if on_release.is_valid():
			on_release.call()
	)

# endregion
