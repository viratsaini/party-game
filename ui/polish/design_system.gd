## DesignSystem - Comprehensive UI design system for BattleZone Party
##
## Provides consistent visual design through:
## - Color palette with semantic naming
## - Typography scale (modular)
## - 4px grid spacing system
## - Icon style guidelines
## - Animation timing standards
## - Shadow/glow standards
## - Component presets
##
## Usage:
##   var primary_color = DesignSystem.get_color("primary")
##   var heading_size = DesignSystem.get_font_size("heading.lg")
##   var padding = DesignSystem.spacing(4)  # 16px
class_name DesignSystem
extends RefCounted


# =============================================================================
# region - Color Palette
# =============================================================================

## Color categories
enum ColorCategory {
	PRIMARY,
	SECONDARY,
	ACCENT,
	SUCCESS,
	WARNING,
	ERROR,
	INFO,
	NEUTRAL,
	SURFACE,
	BACKGROUND
}

## Primary brand colors
const COLORS_PRIMARY: Dictionary = {
	"50": Color("e3f2fd"),
	"100": Color("bbdefb"),
	"200": Color("90caf9"),
	"300": Color("64b5f6"),
	"400": Color("42a5f5"),
	"500": Color("2196f3"),  # Main primary
	"600": Color("1e88e5"),
	"700": Color("1976d2"),
	"800": Color("1565c0"),
	"900": Color("0d47a1")
}

## Secondary colors
const COLORS_SECONDARY: Dictionary = {
	"50": Color("fce4ec"),
	"100": Color("f8bbd0"),
	"200": Color("f48fb1"),
	"300": Color("f06292"),
	"400": Color("ec407a"),
	"500": Color("e91e63"),  # Main secondary
	"600": Color("d81b60"),
	"700": Color("c2185b"),
	"800": Color("ad1457"),
	"900": Color("880e4f")
}

## Accent colors (for highlights, CTAs)
const COLORS_ACCENT: Dictionary = {
	"50": Color("fff8e1"),
	"100": Color("ffecb3"),
	"200": Color("ffe082"),
	"300": Color("ffd54f"),
	"400": Color("ffca28"),
	"500": Color("ffc107"),  # Main accent
	"600": Color("ffb300"),
	"700": Color("ffa000"),
	"800": Color("ff8f00"),
	"900": Color("ff6f00")
}

## Success/positive colors
const COLORS_SUCCESS: Dictionary = {
	"50": Color("e8f5e9"),
	"100": Color("c8e6c9"),
	"200": Color("a5d6a7"),
	"300": Color("81c784"),
	"400": Color("66bb6a"),
	"500": Color("4caf50"),  # Main success
	"600": Color("43a047"),
	"700": Color("388e3c"),
	"800": Color("2e7d32"),
	"900": Color("1b5e20")
}

## Warning colors
const COLORS_WARNING: Dictionary = {
	"50": Color("fff3e0"),
	"100": Color("ffe0b2"),
	"200": Color("ffcc80"),
	"300": Color("ffb74d"),
	"400": Color("ffa726"),
	"500": Color("ff9800"),  # Main warning
	"600": Color("fb8c00"),
	"700": Color("f57c00"),
	"800": Color("ef6c00"),
	"900": Color("e65100")
}

## Error/danger colors
const COLORS_ERROR: Dictionary = {
	"50": Color("ffebee"),
	"100": Color("ffcdd2"),
	"200": Color("ef9a9a"),
	"300": Color("e57373"),
	"400": Color("ef5350"),
	"500": Color("f44336"),  # Main error
	"600": Color("e53935"),
	"700": Color("d32f2f"),
	"800": Color("c62828"),
	"900": Color("b71c1c")
}

## Info colors
const COLORS_INFO: Dictionary = {
	"50": Color("e1f5fe"),
	"100": Color("b3e5fc"),
	"200": Color("81d4fa"),
	"300": Color("4fc3f7"),
	"400": Color("29b6f6"),
	"500": Color("03a9f4"),  # Main info
	"600": Color("039be5"),
	"700": Color("0288d1"),
	"800": Color("0277bd"),
	"900": Color("01579b")
}

## Neutral/grayscale colors
const COLORS_NEUTRAL: Dictionary = {
	"0": Color("ffffff"),
	"50": Color("fafafa"),
	"100": Color("f5f5f5"),
	"200": Color("eeeeee"),
	"300": Color("e0e0e0"),
	"400": Color("bdbdbd"),
	"500": Color("9e9e9e"),
	"600": Color("757575"),
	"700": Color("616161"),
	"800": Color("424242"),
	"900": Color("212121"),
	"1000": Color("000000")
}

## Surface colors (cards, panels)
const COLORS_SURFACE: Dictionary = {
	"default": Color("1e1e2e"),
	"elevated": Color("2a2a3e"),
	"hover": Color("363650"),
	"pressed": Color("424260"),
	"disabled": Color("181825"),
	"overlay": Color("00000080"),
	"glass": Color("ffffff10")
}

## Background colors
const COLORS_BACKGROUND: Dictionary = {
	"default": Color("11111b"),
	"secondary": Color("181825"),
	"tertiary": Color("1e1e2e")
}

## Semantic color mapping
const SEMANTIC_COLORS: Dictionary = {
	# Text colors
	"text.primary": "neutral.100",
	"text.secondary": "neutral.400",
	"text.disabled": "neutral.600",
	"text.hint": "neutral.500",
	"text.inverse": "neutral.900",

	# Interactive
	"interactive.default": "primary.500",
	"interactive.hover": "primary.400",
	"interactive.pressed": "primary.600",
	"interactive.disabled": "neutral.600",

	# Status
	"status.online": "success.500",
	"status.offline": "neutral.500",
	"status.busy": "warning.500",
	"status.error": "error.500",

	# Game specific
	"health.full": "success.500",
	"health.medium": "warning.500",
	"health.low": "error.500",
	"shield.active": "info.500",
	"ammo.full": "primary.500",
	"ammo.low": "warning.500",
	"ammo.empty": "error.500",

	# Team colors
	"team.red": "error.500",
	"team.blue": "primary.500",
	"team.green": "success.500",
	"team.yellow": "accent.500"
}

# endregion


# =============================================================================
# region - Typography Scale
# =============================================================================

## Base font size in pixels
const FONT_SIZE_BASE: float = 16.0

## Modular scale ratio (1.250 - Major Third)
const SCALE_RATIO: float = 1.250

## Font size scale
const FONT_SIZES: Dictionary = {
	# Display sizes (heroes, titles)
	"display.2xl": 72,  # 72px
	"display.xl": 60,   # 60px
	"display.lg": 48,   # 48px
	"display.md": 36,   # 36px
	"display.sm": 30,   # 30px

	# Heading sizes
	"heading.xl": 32,   # 32px - H1
	"heading.lg": 24,   # 24px - H2
	"heading.md": 20,   # 20px - H3
	"heading.sm": 18,   # 18px - H4
	"heading.xs": 16,   # 16px - H5

	# Body sizes
	"body.lg": 18,      # 18px
	"body.md": 16,      # 16px - Default
	"body.sm": 14,      # 14px
	"body.xs": 12,      # 12px

	# Caption/label sizes
	"caption": 12,      # 12px
	"overline": 10,     # 10px
	"micro": 9          # 9px
}

## Line height multipliers
const LINE_HEIGHTS: Dictionary = {
	"tight": 1.1,
	"snug": 1.25,
	"normal": 1.5,
	"relaxed": 1.75,
	"loose": 2.0
}

## Font weights
const FONT_WEIGHTS: Dictionary = {
	"thin": 100,
	"extralight": 200,
	"light": 300,
	"regular": 400,
	"medium": 500,
	"semibold": 600,
	"bold": 700,
	"extrabold": 800,
	"black": 900
}

## Letter spacing (em units)
const LETTER_SPACING: Dictionary = {
	"tighter": -0.05,
	"tight": -0.025,
	"normal": 0.0,
	"wide": 0.025,
	"wider": 0.05,
	"widest": 0.1
}

# endregion


# =============================================================================
# region - Spacing System (4px Grid)
# =============================================================================

## Base spacing unit in pixels
const SPACING_UNIT: float = 4.0

## Spacing scale (multipliers of base unit)
const SPACING_SCALE: Dictionary = {
	"0": 0,       # 0px
	"px": 1,      # 1px
	"0.5": 2,     # 2px
	"1": 4,       # 4px
	"1.5": 6,     # 6px
	"2": 8,       # 8px
	"2.5": 10,    # 10px
	"3": 12,      # 12px
	"3.5": 14,    # 14px
	"4": 16,      # 16px
	"5": 20,      # 20px
	"6": 24,      # 24px
	"7": 28,      # 28px
	"8": 32,      # 32px
	"9": 36,      # 36px
	"10": 40,     # 40px
	"11": 44,     # 44px
	"12": 48,     # 48px
	"14": 56,     # 56px
	"16": 64,     # 64px
	"20": 80,     # 80px
	"24": 96,     # 96px
	"28": 112,    # 112px
	"32": 128,    # 128px
	"36": 144,    # 144px
	"40": 160,    # 160px
	"44": 176,    # 176px
	"48": 192,    # 192px
	"52": 208,    # 208px
	"56": 224,    # 224px
	"60": 240,    # 240px
	"64": 256,    # 256px
	"72": 288,    # 288px
	"80": 320,    # 320px
	"96": 384     # 384px
}

## Common component sizes
const COMPONENT_SIZES: Dictionary = {
	# Buttons
	"button.height.sm": 32,
	"button.height.md": 40,
	"button.height.lg": 48,
	"button.height.xl": 56,
	"button.padding.sm": 12,
	"button.padding.md": 16,
	"button.padding.lg": 20,

	# Inputs
	"input.height.sm": 32,
	"input.height.md": 40,
	"input.height.lg": 48,
	"input.padding": 12,

	# Icons
	"icon.xs": 12,
	"icon.sm": 16,
	"icon.md": 20,
	"icon.lg": 24,
	"icon.xl": 32,
	"icon.2xl": 48,

	# Touch targets (minimum for accessibility)
	"touch.min": 44,

	# Avatar
	"avatar.xs": 24,
	"avatar.sm": 32,
	"avatar.md": 40,
	"avatar.lg": 48,
	"avatar.xl": 64,
	"avatar.2xl": 96,

	# Cards
	"card.padding.sm": 12,
	"card.padding.md": 16,
	"card.padding.lg": 24,
	"card.radius.sm": 8,
	"card.radius.md": 12,
	"card.radius.lg": 16
}

# endregion


# =============================================================================
# region - Animation Standards
# =============================================================================

## Animation duration presets (in seconds)
const ANIMATION_DURATIONS: Dictionary = {
	"instant": 0.0,
	"fastest": 0.05,
	"faster": 0.1,
	"fast": 0.15,
	"normal": 0.2,
	"slow": 0.3,
	"slower": 0.4,
	"slowest": 0.5,

	# Specific use cases
	"button.press": 0.05,
	"button.release": 0.15,
	"hover.in": 0.1,
	"hover.out": 0.15,
	"panel.enter": 0.3,
	"panel.exit": 0.25,
	"modal.enter": 0.35,
	"modal.exit": 0.25,
	"toast.enter": 0.25,
	"toast.exit": 0.2,
	"fade.in": 0.2,
	"fade.out": 0.15,
	"slide.in": 0.3,
	"slide.out": 0.25,
	"scale.in": 0.25,
	"scale.out": 0.2,
	"page.transition": 0.4
}

## Standard easing curves
const EASING_CURVES: Dictionary = {
	# General purpose
	"ease.default": {"trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_OUT},
	"ease.linear": {"trans": Tween.TRANS_LINEAR, "ease": Tween.EASE_IN_OUT},
	"ease.in": {"trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_IN},
	"ease.out": {"trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_OUT},
	"ease.in.out": {"trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_IN_OUT},

	# Emphasis
	"ease.back.out": {"trans": Tween.TRANS_BACK, "ease": Tween.EASE_OUT},
	"ease.back.in": {"trans": Tween.TRANS_BACK, "ease": Tween.EASE_IN},
	"ease.elastic.out": {"trans": Tween.TRANS_ELASTIC, "ease": Tween.EASE_OUT},
	"ease.bounce.out": {"trans": Tween.TRANS_BOUNCE, "ease": Tween.EASE_OUT},

	# Specific use cases
	"button.press": {"trans": Tween.TRANS_QUAD, "ease": Tween.EASE_OUT},
	"button.release": {"trans": Tween.TRANS_BACK, "ease": Tween.EASE_OUT},
	"panel.enter": {"trans": Tween.TRANS_BACK, "ease": Tween.EASE_OUT},
	"panel.exit": {"trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_IN},
	"hover": {"trans": Tween.TRANS_QUAD, "ease": Tween.EASE_OUT},
	"spring": {"trans": Tween.TRANS_SPRING, "ease": Tween.EASE_OUT}
}

# endregion


# =============================================================================
# region - Shadow & Glow Standards
# =============================================================================

## Shadow presets
const SHADOWS: Dictionary = {
	"none": {
		"offset": Vector2.ZERO,
		"size": 0,
		"color": Color.TRANSPARENT
	},
	"sm": {
		"offset": Vector2(0, 1),
		"size": 2,
		"color": Color(0, 0, 0, 0.05)
	},
	"md": {
		"offset": Vector2(0, 4),
		"size": 6,
		"color": Color(0, 0, 0, 0.1)
	},
	"lg": {
		"offset": Vector2(0, 10),
		"size": 15,
		"color": Color(0, 0, 0, 0.15)
	},
	"xl": {
		"offset": Vector2(0, 20),
		"size": 25,
		"color": Color(0, 0, 0, 0.2)
	},
	"2xl": {
		"offset": Vector2(0, 25),
		"size": 50,
		"color": Color(0, 0, 0, 0.25)
	},
	"inner": {
		"offset": Vector2(0, 2),
		"size": 4,
		"color": Color(0, 0, 0, 0.06)
	}
}

## Glow presets
const GLOWS: Dictionary = {
	"none": {
		"size": 0,
		"color": Color.TRANSPARENT
	},
	"primary.sm": {
		"size": 4,
		"color": Color("2196f340")
	},
	"primary.md": {
		"size": 8,
		"color": Color("2196f360")
	},
	"primary.lg": {
		"size": 16,
		"color": Color("2196f380")
	},
	"accent.sm": {
		"size": 4,
		"color": Color("ffc10740")
	},
	"accent.md": {
		"size": 8,
		"color": Color("ffc10760")
	},
	"accent.lg": {
		"size": 16,
		"color": Color("ffc10780")
	},
	"error.sm": {
		"size": 4,
		"color": Color("f4433640")
	},
	"error.md": {
		"size": 8,
		"color": Color("f4433660")
	},
	"success.sm": {
		"size": 4,
		"color": Color("4caf5040")
	},
	"success.md": {
		"size": 8,
		"color": Color("4caf5060")
	}
}

## Border radius presets
const BORDER_RADIUS: Dictionary = {
	"none": 0,
	"sm": 4,
	"md": 8,
	"lg": 12,
	"xl": 16,
	"2xl": 24,
	"3xl": 32,
	"full": 9999,

	# Component specific
	"button": 8,
	"card": 12,
	"modal": 16,
	"input": 6,
	"badge": 4,
	"avatar": 9999,
	"tooltip": 6
}

# endregion


# =============================================================================
# region - Public API
# =============================================================================

## Gets a color by name (e.g., "primary.500", "error.300", "neutral.100")
static func get_color(name: String) -> Color:
	# Check semantic colors first
	if SEMANTIC_COLORS.has(name):
		name = SEMANTIC_COLORS[name]

	var parts: PackedStringArray = name.split(".")
	if parts.size() != 2:
		push_warning("[DesignSystem] Invalid color name: %s" % name)
		return Color.MAGENTA

	var category: String = parts[0]
	var shade: String = parts[1]

	var palette: Dictionary
	match category:
		"primary":
			palette = COLORS_PRIMARY
		"secondary":
			palette = COLORS_SECONDARY
		"accent":
			palette = COLORS_ACCENT
		"success":
			palette = COLORS_SUCCESS
		"warning":
			palette = COLORS_WARNING
		"error":
			palette = COLORS_ERROR
		"info":
			palette = COLORS_INFO
		"neutral":
			palette = COLORS_NEUTRAL
		"surface":
			palette = COLORS_SURFACE
		"background":
			palette = COLORS_BACKGROUND
		_:
			push_warning("[DesignSystem] Unknown color category: %s" % category)
			return Color.MAGENTA

	if not palette.has(shade):
		push_warning("[DesignSystem] Unknown shade: %s for %s" % [shade, category])
		return Color.MAGENTA

	return palette[shade]


## Gets a font size by name
static func get_font_size(name: String) -> int:
	if FONT_SIZES.has(name):
		return FONT_SIZES[name]

	push_warning("[DesignSystem] Unknown font size: %s" % name)
	return FONT_SIZES["body.md"]


## Gets line height multiplier
static func get_line_height(name: String) -> float:
	if LINE_HEIGHTS.has(name):
		return LINE_HEIGHTS[name]

	return LINE_HEIGHTS["normal"]


## Gets spacing in pixels by scale key or multiplier
static func spacing(value: Variant) -> float:
	if value is String:
		if SPACING_SCALE.has(value):
			return SPACING_SCALE[value]
		push_warning("[DesignSystem] Unknown spacing key: %s" % value)
		return 0.0
	elif value is int or value is float:
		return float(value) * SPACING_UNIT
	return 0.0


## Gets component size by name
static func get_component_size(name: String) -> float:
	if COMPONENT_SIZES.has(name):
		return COMPONENT_SIZES[name]

	push_warning("[DesignSystem] Unknown component size: %s" % name)
	return 0.0


## Gets animation duration by name
static func get_duration(name: String) -> float:
	if ANIMATION_DURATIONS.has(name):
		return ANIMATION_DURATIONS[name]

	push_warning("[DesignSystem] Unknown duration: %s" % name)
	return ANIMATION_DURATIONS["normal"]


## Gets easing configuration by name
static func get_easing(name: String) -> Dictionary:
	if EASING_CURVES.has(name):
		return EASING_CURVES[name]

	push_warning("[DesignSystem] Unknown easing: %s" % name)
	return EASING_CURVES["ease.default"]


## Gets shadow configuration by name
static func get_shadow(name: String) -> Dictionary:
	if SHADOWS.has(name):
		return SHADOWS[name]

	push_warning("[DesignSystem] Unknown shadow: %s" % name)
	return SHADOWS["none"]


## Gets glow configuration by name
static func get_glow(name: String) -> Dictionary:
	if GLOWS.has(name):
		return GLOWS[name]

	push_warning("[DesignSystem] Unknown glow: %s" % name)
	return GLOWS["none"]


## Gets border radius by name
static func get_radius(name: String) -> float:
	if BORDER_RADIUS.has(name):
		return BORDER_RADIUS[name]

	push_warning("[DesignSystem] Unknown radius: %s" % name)
	return BORDER_RADIUS["md"]


## Creates a Vector2 for padding/margin (uniform)
static func padding(value: Variant) -> Vector2:
	var px: float = spacing(value)
	return Vector2(px, px)


## Creates a Vector2 for padding/margin (horizontal, vertical)
static func padding_xy(h: Variant, v: Variant) -> Vector2:
	return Vector2(spacing(h), spacing(v))


## Creates Rect2 margins (top, right, bottom, left)
static func margins(top: Variant, right: Variant, bottom: Variant, left: Variant) -> Dictionary:
	return {
		"top": spacing(top),
		"right": spacing(right),
		"bottom": spacing(bottom),
		"left": spacing(left)
	}


## Gets contrasting text color for a background color
static func get_contrast_color(background: Color) -> Color:
	var luminance: float = 0.299 * background.r + 0.587 * background.g + 0.114 * background.b
	return get_color("neutral.900") if luminance > 0.5 else get_color("neutral.100")


## Applies opacity to a color
static func with_opacity(color: Color, opacity: float) -> Color:
	return Color(color.r, color.g, color.b, opacity)


## Lightens a color
static func lighten(color: Color, amount: float) -> Color:
	return color.lightened(clampf(amount, 0.0, 1.0))


## Darkens a color
static func darken(color: Color, amount: float) -> Color:
	return color.darkened(clampf(amount, 0.0, 1.0))

# endregion


# =============================================================================
# region - Component Presets
# =============================================================================

## Gets button style configuration
static func get_button_style(variant: String = "primary", size: String = "md") -> Dictionary:
	var height: float = get_component_size("button.height." + size)
	var padding_h: float = get_component_size("button.padding." + size)
	var font_size: int = get_font_size("body." + size if size != "xl" else "body.lg")
	var radius: float = get_radius("button")

	var bg_color: Color
	var text_color: Color
	var hover_color: Color
	var pressed_color: Color

	match variant:
		"primary":
			bg_color = get_color("primary.500")
			text_color = get_color("neutral.0")
			hover_color = get_color("primary.400")
			pressed_color = get_color("primary.600")
		"secondary":
			bg_color = get_color("secondary.500")
			text_color = get_color("neutral.0")
			hover_color = get_color("secondary.400")
			pressed_color = get_color("secondary.600")
		"success":
			bg_color = get_color("success.500")
			text_color = get_color("neutral.0")
			hover_color = get_color("success.400")
			pressed_color = get_color("success.600")
		"error":
			bg_color = get_color("error.500")
			text_color = get_color("neutral.0")
			hover_color = get_color("error.400")
			pressed_color = get_color("error.600")
		"ghost":
			bg_color = Color.TRANSPARENT
			text_color = get_color("primary.500")
			hover_color = with_opacity(get_color("primary.500"), 0.1)
			pressed_color = with_opacity(get_color("primary.500"), 0.2)
		"outline":
			bg_color = Color.TRANSPARENT
			text_color = get_color("primary.500")
			hover_color = with_opacity(get_color("primary.500"), 0.1)
			pressed_color = with_opacity(get_color("primary.500"), 0.2)
		_:
			bg_color = get_color("neutral.700")
			text_color = get_color("neutral.100")
			hover_color = get_color("neutral.600")
			pressed_color = get_color("neutral.800")

	return {
		"height": height,
		"padding_horizontal": padding_h,
		"font_size": font_size,
		"border_radius": radius,
		"background_color": bg_color,
		"text_color": text_color,
		"hover_color": hover_color,
		"pressed_color": pressed_color,
		"animation_duration": get_duration("button.press"),
		"easing": get_easing("button.press")
	}


## Gets panel style configuration
static func get_panel_style(variant: String = "default") -> Dictionary:
	var padding_val: float = spacing(4)
	var radius: float = get_radius("card")

	match variant:
		"elevated":
			return {
				"background_color": get_color("surface.elevated"),
				"padding": padding_val,
				"border_radius": radius,
				"shadow": get_shadow("lg")
			}
		"glass":
			return {
				"background_color": get_color("surface.glass"),
				"padding": padding_val,
				"border_radius": radius,
				"shadow": get_shadow("md")
			}
		_:
			return {
				"background_color": get_color("surface.default"),
				"padding": padding_val,
				"border_radius": radius,
				"shadow": get_shadow("sm")
			}


## Gets input field style configuration
static func get_input_style(size: String = "md") -> Dictionary:
	var height: float = get_component_size("input.height." + size)
	var padding_val: float = get_component_size("input.padding")
	var font_size: int = get_font_size("body." + size)
	var radius: float = get_radius("input")

	return {
		"height": height,
		"padding": padding_val,
		"font_size": font_size,
		"border_radius": radius,
		"background_color": get_color("surface.default"),
		"border_color": get_color("neutral.600"),
		"focus_border_color": get_color("primary.500"),
		"text_color": get_color("neutral.100"),
		"placeholder_color": get_color("neutral.500")
	}

# endregion


# =============================================================================
# region - Micro-Interaction System
# =============================================================================

## Complete button interaction system with press -> release -> settle
static func apply_button_microinteractions(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return

	# Store original values
	button.set_meta("_original_scale", button.scale)
	button.pivot_offset = button.size / 2

	# Disconnect existing signals to avoid duplicates
	_disconnect_if_connected(button, "mouse_entered")
	_disconnect_if_connected(button, "mouse_exited")
	_disconnect_if_connected(button, "button_down")
	_disconnect_if_connected(button, "button_up")
	_disconnect_if_connected(button, "focus_entered")
	_disconnect_if_connected(button, "focus_exited")

	# Connect hover states
	button.mouse_entered.connect(_on_button_hover_enter.bind(button))
	button.mouse_exited.connect(_on_button_hover_exit.bind(button))

	# Connect press states with sequence
	button.button_down.connect(_on_button_press_start.bind(button))
	button.button_up.connect(_on_button_press_release.bind(button))

	# Connect focus states for accessibility
	button.focus_entered.connect(_on_button_focus_enter.bind(button))
	button.focus_exited.connect(_on_button_focus_exit.bind(button))


static func _disconnect_if_connected(button: BaseButton, signal_name: String) -> void:
	var sig: Signal = button.get(signal_name)
	for connection: Dictionary in sig.get_connections():
		sig.disconnect(connection["callable"])


static func _on_button_hover_enter(button: BaseButton) -> void:
	if button.disabled:
		return

	button.set_meta("_is_hovered", true)
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	_play_ui_sound("hover")


static func _on_button_hover_exit(button: BaseButton) -> void:
	button.set_meta("_is_hovered", false)
	if button.get_meta("_is_pressed", false):
		return

	var original_scale: Vector2 = button.get_meta("_original_scale", Vector2.ONE)
	var tween := button.create_tween()
	tween.tween_property(button, "scale", original_scale, 0.15)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)


static func _on_button_press_start(button: BaseButton) -> void:
	if button.disabled:
		return

	button.set_meta("_is_pressed", true)

	# Press animation - quick squish
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

	_play_ui_sound("click")


static func _on_button_press_release(button: BaseButton) -> void:
	button.set_meta("_is_pressed", false)

	var is_hovered: bool = button.get_meta("_is_hovered", false)
	var target_scale := Vector2(1.05, 1.05) if is_hovered else Vector2.ONE
	var original_scale: Vector2 = button.get_meta("_original_scale", Vector2.ONE)

	# Release animation - bounce back with overshoot then settle
	var tween := button.create_tween()
	tween.set_parallel(false)

	# Overshoot
	tween.tween_property(button, "scale", target_scale * 1.08, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# Settle
	tween.tween_property(button, "scale", target_scale if is_hovered else original_scale, 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)


static func _on_button_focus_enter(button: BaseButton) -> void:
	# Add focus glow
	var tween := button.create_tween()
	tween.tween_property(button, "modulate", Color(1.1, 1.1, 1.2), 0.1)


static func _on_button_focus_exit(button: BaseButton) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "modulate", Color.WHITE, 0.1)


## Play UI sound with fallback
static func _play_ui_sound(sound_name: String) -> void:
	var root := Engine.get_main_loop()
	if root is SceneTree:
		var manager := root.root.get_node_or_null("AudioManager")
		if manager and manager.has_method("play_sfx"):
			manager.play_sfx("ui_" + sound_name)

# endregion


# =============================================================================
# region - Panel Polish System
# =============================================================================

## Complete panel entrance/exit animation system
static func apply_panel_polish(panel: Control, entrance_direction: Vector2 = Vector2.DOWN) -> void:
	if not is_instance_valid(panel):
		return

	panel.set_meta("_original_position", panel.position)
	panel.set_meta("_entrance_direction", entrance_direction)
	panel.set_meta("_is_animated", true)

	if not panel.visibility_changed.is_connected(_on_panel_visibility_changed.bind(panel)):
		panel.visibility_changed.connect(_on_panel_visibility_changed.bind(panel))


static func _on_panel_visibility_changed(panel: Control) -> void:
	if panel.visible and panel.get_meta("_is_animated", true):
		animate_panel_entrance(panel)


## Animate panel entrance with scale, fade, and slide
static func animate_panel_entrance(panel: Control, direction: Vector2 = Vector2.ZERO) -> Tween:
	if not is_instance_valid(panel):
		return null

	var entrance_dir: Vector2 = direction if direction != Vector2.ZERO else panel.get_meta("_entrance_direction", Vector2.DOWN)
	var original_pos: Vector2 = panel.get_meta("_original_position", panel.position)

	# Set initial state
	panel.position = original_pos + entrance_dir * 50
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2

	var tween := panel.create_tween()
	tween.set_parallel(true)

	# Position animation
	tween.tween_property(panel, "position", original_pos, 0.32)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	# Scale animation with back easing for overshoot
	tween.tween_property(panel, "scale", Vector2.ONE, 0.32)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# Fade animation
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	_play_ui_sound("panel_open")

	return tween


## Animate panel exit
static func animate_panel_exit(panel: Control, direction: Vector2 = Vector2.ZERO, hide_after: bool = true) -> Tween:
	if not is_instance_valid(panel):
		return null

	var exit_dir: Vector2 = direction if direction != Vector2.ZERO else panel.get_meta("_entrance_direction", Vector2.DOWN)
	var target_pos: Vector2 = panel.position + exit_dir * 50

	panel.pivot_offset = panel.size / 2

	var tween := panel.create_tween()
	tween.set_parallel(true)

	tween.tween_property(panel, "position", target_pos, 0.25)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	tween.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.25)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	tween.tween_property(panel, "modulate:a", 0.0, 0.15)

	if hide_after:
		tween.chain().tween_callback(func(): panel.visible = false)

	_play_ui_sound("panel_close")

	return tween

# endregion


# =============================================================================
# region - Stagger Animation System
# =============================================================================

## Animate a group of elements with staggered timing
static func animate_stagger_entrance(
	elements: Array,
	base_delay: float = 0.05,
	animation_type: String = "fade_slide"
) -> Array[Tween]:
	var tweens: Array[Tween] = []

	for i: int in range(elements.size()):
		var element: Node = elements[i]
		if not is_instance_valid(element) or not element is Control:
			continue

		var control: Control = element as Control
		var delay: float = i * base_delay

		var tween := control.create_tween()
		tween.set_parallel(true)

		match animation_type:
			"fade_slide":
				control.modulate.a = 0.0
				control.position.y += 20
				var target_pos := control.position - Vector2(0, 20)

				tween.tween_property(control, "modulate:a", 1.0, 0.2).set_delay(delay)
				tween.tween_property(control, "position", target_pos, 0.3).set_delay(delay)\
					.set_trans(Tween.TRANS_CUBIC)\
					.set_ease(Tween.EASE_OUT)

			"scale":
				control.scale = Vector2.ZERO
				control.pivot_offset = control.size / 2

				tween.tween_property(control, "scale", Vector2.ONE, 0.3).set_delay(delay)\
					.set_trans(Tween.TRANS_BACK)\
					.set_ease(Tween.EASE_OUT)

			"fade":
				control.modulate.a = 0.0
				tween.tween_property(control, "modulate:a", 1.0, 0.2).set_delay(delay)

		tweens.append(tween)

	return tweens

# endregion


# =============================================================================
# region - Loading & Progress States
# =============================================================================

## Create a skeleton loading state
static func create_skeleton_loader(target: Control) -> Control:
	var skeleton := ColorRect.new()
	skeleton.name = "SkeletonLoader"
	skeleton.set_anchors_preset(Control.PRESET_FULL_RECT)
	skeleton.color = Color(0.2, 0.2, 0.25)

	# Create shimmer animation
	var tween := skeleton.create_tween()
	tween.set_loops()
	tween.tween_property(skeleton, "modulate", Color(1.2, 1.2, 1.2), 0.8)
	tween.tween_property(skeleton, "modulate", Color.WHITE, 0.8)

	target.add_child(skeleton)
	return skeleton


## Remove skeleton loader with fade
static func remove_skeleton_loader(target: Control) -> void:
	var skeleton := target.get_node_or_null("SkeletonLoader")
	if skeleton:
		var tween := skeleton.create_tween()
		tween.tween_property(skeleton, "modulate:a", 0.0, 0.2)
		tween.tween_callback(skeleton.queue_free)


## Create loading spinner
static func create_loading_spinner(parent: Control, size: float = 48.0) -> Control:
	var spinner := Control.new()
	spinner.name = "LoadingSpinner"
	spinner.custom_minimum_size = Vector2(size, size)

	# Create spinner segments
	var segment_count: int = 8
	for i: int in range(segment_count):
		var segment := ColorRect.new()
		segment.size = Vector2(4, size * 0.3)
		segment.position = Vector2(size / 2 - 2, 0)
		segment.pivot_offset = Vector2(2, size / 2)
		segment.rotation = (TAU / segment_count) * i
		segment.modulate.a = 1.0 - (float(i) / segment_count) * 0.7
		segment.color = get_color("primary.500")
		spinner.add_child(segment)

	# Rotate spinner
	spinner.ready.connect(func():
		var tween := spinner.create_tween()
		tween.set_loops()
		tween.tween_property(spinner, "rotation", TAU, 1.0).from(0.0)\
			.set_trans(Tween.TRANS_LINEAR)
	)

	parent.add_child(spinner)
	return spinner

# endregion


# =============================================================================
# region - Feedback States (Success, Error, Warning)
# =============================================================================

## Show success celebration
static func show_success_celebration(
	container: Control,
	message: String = "Success!",
	duration: float = 2.0
) -> Control:
	var overlay := ColorRect.new()
	overlay.name = "SuccessCelebration"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.2, 0.8, 0.3, 0.1)
	overlay.modulate.a = 0.0

	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.set_anchors_preset(Control.PRESET_CENTER)
	overlay.add_child(center)

	var icon := Label.new()
	icon.text = "OK"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 48)
	icon.add_theme_color_override("font_color", get_color("success.500"))
	icon.scale = Vector2.ZERO
	icon.pivot_offset = Vector2(24, 24)
	center.add_child(icon)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", get_color("success.500"))
	label.modulate.a = 0.0
	center.add_child(label)

	container.add_child(overlay)

	# Animate entrance
	var tween := container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)

	tween.chain().tween_property(label, "modulate:a", 1.0, 0.2)

	# Auto-dismiss
	tween.chain().tween_interval(duration)
	tween.chain().tween_property(overlay, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(overlay.queue_free)

	_play_ui_sound("success")

	return overlay


## Show error state with shake
static func show_error_state(
	container: Control,
	message: String = "An error occurred",
	retry_callback: Callable = Callable()
) -> Control:
	var overlay := ColorRect.new()
	overlay.name = "ErrorOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.9, 0.2, 0.2, 0.1)
	overlay.modulate.a = 0.0

	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.add_theme_constant_override("separation", 16)
	overlay.add_child(center)

	var icon := Label.new()
	icon.text = "X"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 48)
	icon.add_theme_color_override("font_color", get_color("error.500"))
	center.add_child(icon)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 300
	center.add_child(label)

	if retry_callback.is_valid():
		var retry_btn := Button.new()
		retry_btn.text = "Try Again"
		retry_btn.custom_minimum_size = Vector2(120, 44)
		retry_btn.pressed.connect(func():
			_dismiss_overlay(overlay)
			retry_callback.call()
		)
		center.add_child(retry_btn)
		apply_button_microinteractions(retry_btn)

	container.add_child(overlay)

	# Fade in and shake
	var tween := container.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.15)

	# Shake icon
	var original_x: float = icon.position.x
	for i: int in range(3):
		tween.tween_property(icon, "position:x", original_x + 10, 0.05)
		tween.tween_property(icon, "position:x", original_x - 10, 0.05)
	tween.tween_property(icon, "position:x", original_x, 0.05)

	_play_ui_sound("error")

	return overlay


static func _dismiss_overlay(overlay: Control) -> void:
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tween.tween_callback(overlay.queue_free)

# endregion


# =============================================================================
# region - Empty States
# =============================================================================

## Create an empty state placeholder with helpful guidance
static func create_empty_state(
	container: Control,
	title: String,
	description: String,
	action_text: String = "",
	action_callback: Callable = Callable()
) -> Control:
	var empty := VBoxContainer.new()
	empty.name = "EmptyState"
	empty.alignment = BoxContainer.ALIGNMENT_CENTER
	empty.set_anchors_preset(Control.PRESET_CENTER)
	empty.add_theme_constant_override("separation", 16)

	var icon := Label.new()
	icon.text = "?"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 64)
	icon.add_theme_color_override("font_color", get_color("neutral.400"))
	empty.add_child(icon)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", get_color("neutral.200"))
	empty.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", get_color("neutral.500"))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 300
	empty.add_child(desc_label)

	if not action_text.is_empty() and action_callback.is_valid():
		var action_btn := Button.new()
		action_btn.text = action_text
		action_btn.custom_minimum_size = Vector2(150, 44)
		action_btn.pressed.connect(action_callback)
		empty.add_child(action_btn)
		apply_button_microinteractions(action_btn)

	container.add_child(empty)

	# Animate entrance
	empty.modulate.a = 0.0
	var tween := empty.create_tween()
	tween.tween_property(empty, "modulate:a", 1.0, 0.3)

	return empty

# endregion


# =============================================================================
# region - Accessibility Helpers
# =============================================================================

## Apply WCAG AAA focus indicator to a control
static func apply_focus_indicator(control: Control) -> void:
	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_width_left = 3
	focus_style.border_width_right = 3
	focus_style.border_width_top = 3
	focus_style.border_width_bottom = 3
	focus_style.border_color = Color(1.0, 0.76, 0.03)  # High visibility yellow
	focus_style.corner_radius_bottom_left = 6
	focus_style.corner_radius_bottom_right = 6
	focus_style.corner_radius_top_left = 6
	focus_style.corner_radius_top_right = 6

	control.add_theme_stylebox_override("focus", focus_style)


## Validate and fix touch target size
static func ensure_touch_target(control: Control, min_size: float = 44.0) -> void:
	if control.custom_minimum_size.x < min_size:
		control.custom_minimum_size.x = min_size
	if control.custom_minimum_size.y < min_size:
		control.custom_minimum_size.y = min_size


## Set accessibility label for screen readers
static func set_accessibility_label(control: Control, label: String) -> void:
	control.set_meta("accessibility_label", label)


## Get accessibility label
static func get_accessibility_label(control: Control) -> String:
	return control.get_meta("accessibility_label", control.name)

# endregion


# =============================================================================
# region - Performance Utilities
# =============================================================================

## Check if animation should run based on user preferences
static func should_animate() -> bool:
	# Check for accessibility manager
	var root := Engine.get_main_loop()
	if root is SceneTree:
		var access_mgr := root.root.get_node_or_null("AccessibilityManager")
		if access_mgr and access_mgr.get("reduce_motion"):
			return false
	return true


## Get adjusted animation duration for accessibility
static func get_adjusted_duration(base_duration: float) -> float:
	if not should_animate():
		return 0.0

	var root := Engine.get_main_loop()
	if root is SceneTree:
		var access_mgr := root.root.get_node_or_null("AccessibilityManager")
		if access_mgr and access_mgr.has_method("get_animation_duration_multiplier"):
			return base_duration * access_mgr.get_animation_duration_multiplier()

	return base_duration

# endregion
