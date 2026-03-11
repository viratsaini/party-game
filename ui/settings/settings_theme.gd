## SettingsTheme - Centralized theme constants and styling for the premium settings UI.
##
## Provides consistent colors, fonts, and styling across all settings components.
class_name SettingsTheme
extends RefCounted

# ============================================================================ #
#                               COLOR PALETTE                                   #
# ============================================================================ #

## Primary brand colors.
const ACCENT_PRIMARY := Color(0.2, 0.6, 1.0, 1.0)
const ACCENT_SECONDARY := Color(0.3, 0.8, 0.5, 1.0)
const ACCENT_WARNING := Color(1.0, 0.7, 0.2, 1.0)
const ACCENT_ERROR := Color(1.0, 0.35, 0.35, 1.0)
const ACCENT_SUCCESS := Color(0.3, 0.9, 0.4, 1.0)

## Background colors.
const BG_DARKEST := Color(0.06, 0.06, 0.08, 1.0)
const BG_DARK := Color(0.08, 0.08, 0.1, 1.0)
const BG_MEDIUM := Color(0.12, 0.12, 0.15, 1.0)
const BG_LIGHT := Color(0.16, 0.16, 0.2, 1.0)
const BG_HIGHLIGHT := Color(0.2, 0.2, 0.25, 1.0)

## Text colors.
const TEXT_PRIMARY := Color(1.0, 1.0, 1.0, 1.0)
const TEXT_SECONDARY := Color(0.75, 0.75, 0.8, 1.0)
const TEXT_TERTIARY := Color(0.5, 0.5, 0.55, 1.0)
const TEXT_DISABLED := Color(0.35, 0.35, 0.4, 1.0)

## Border colors.
const BORDER_SUBTLE := Color(0.25, 0.25, 0.3, 1.0)
const BORDER_NORMAL := Color(0.35, 0.35, 0.4, 1.0)
const BORDER_FOCUS := Color(0.4, 0.6, 0.9, 1.0)

## Glow colors.
const GLOW_BLUE := Color(0.3, 0.7, 1.0, 0.5)
const GLOW_GREEN := Color(0.3, 0.9, 0.5, 0.5)
const GLOW_ORANGE := Color(1.0, 0.6, 0.2, 0.5)
const GLOW_RED := Color(1.0, 0.4, 0.4, 0.5)

# ============================================================================ #
#                               FONT SIZES                                      #
# ============================================================================ #

const FONT_SIZE_HEADER := 28
const FONT_SIZE_TITLE := 22
const FONT_SIZE_SUBTITLE := 18
const FONT_SIZE_LABEL := 14
const FONT_SIZE_BODY := 13
const FONT_SIZE_CAPTION := 11
const FONT_SIZE_TINY := 9

# ============================================================================ #
#                               SPACING                                         #
# ============================================================================ #

const PADDING_XS := 4
const PADDING_SM := 8
const PADDING_MD := 16
const PADDING_LG := 24
const PADDING_XL := 40

const MARGIN_XS := 4
const MARGIN_SM := 8
const MARGIN_MD := 16
const MARGIN_LG := 24
const MARGIN_XL := 40

const CORNER_RADIUS_SM := 4.0
const CORNER_RADIUS_MD := 8.0
const CORNER_RADIUS_LG := 12.0

# ============================================================================ #
#                               ANIMATION                                       #
# ============================================================================ #

const ANIM_INSTANT := 0.0
const ANIM_FAST := 0.1
const ANIM_NORMAL := 0.2
const ANIM_SLOW := 0.35
const ANIM_VERY_SLOW := 0.5

const SPRING_STIFFNESS := 200.0
const SPRING_DAMPING := 15.0

# ============================================================================ #
#                               COMPONENT SIZES                                 #
# ============================================================================ #

const BUTTON_HEIGHT := 40
const BUTTON_MIN_WIDTH := 100
const SLIDER_HEIGHT := 30
const SLIDER_TRACK_HEIGHT := 6
const SLIDER_THUMB_SIZE := 24
const TOGGLE_WIDTH := 52
const TOGGLE_HEIGHT := 28
const DROPDOWN_HEIGHT := 36
const DROPDOWN_ITEM_HEIGHT := 38
const INPUT_HEIGHT := 36
const TAB_HEIGHT := 50

# ============================================================================ #
#                               STYLE HELPERS                                   #
# ============================================================================ #

## Create a StyleBoxFlat with common settings.
static func create_panel_style(
	bg_color: Color = BG_MEDIUM,
	border_color: Color = BORDER_SUBTLE,
	border_width: int = 1,
	corner_radius: float = CORNER_RADIUS_MD
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.corner_radius_top_left = int(corner_radius)
	style.corner_radius_top_right = int(corner_radius)
	style.corner_radius_bottom_left = int(corner_radius)
	style.corner_radius_bottom_right = int(corner_radius)
	return style


## Create a button style.
static func create_button_style(
	bg_color: Color,
	accent_color: Color,
	hover_lighten: float = 0.1
) -> Dictionary:
	var normal := create_panel_style(bg_color.darkened(0.2), accent_color.darkened(0.3), 0, CORNER_RADIUS_SM)
	normal.border_width_bottom = 3
	normal.border_color = accent_color.darkened(0.2)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg_color.lightened(hover_lighten)
	hover.border_color = accent_color

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg_color.darkened(0.1)
	pressed.border_width_bottom = 1

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = BG_DARK
	disabled.border_color = BORDER_SUBTLE

	return {
		"normal": normal,
		"hover": hover,
		"pressed": pressed,
		"disabled": disabled,
	}


## Get a gradient from low to high values.
static func create_value_gradient(low_color: Color, high_color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, low_color)
	gradient.add_point(1.0, high_color)
	return gradient


## Interpolate between two colors based on a value (0-1).
static func get_value_color(value: float, low: Color, mid: Color, high: Color) -> Color:
	if value < 0.5:
		return low.lerp(mid, value * 2.0)
	else:
		return mid.lerp(high, (value - 0.5) * 2.0)


## Create glow effect layers data.
static func get_glow_layers(color: Color, intensity: float = 1.0, layers: int = 4) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in layers:
		var layer_alpha := (1.0 - float(i) / float(layers + 1)) * intensity * 0.4
		var layer_size := float(i + 1) * 3.0
		result.append({
			"color": Color(color, layer_alpha),
			"size": layer_size,
		})
	return result

# ============================================================================ #
#                               PRESETS                                         #
# ============================================================================ #

## Standard color presets for different states.
const STATE_COLORS := {
	"normal": {
		"bg": BG_MEDIUM,
		"border": BORDER_SUBTLE,
		"text": TEXT_PRIMARY,
	},
	"hover": {
		"bg": BG_LIGHT,
		"border": BORDER_FOCUS,
		"text": TEXT_PRIMARY,
	},
	"pressed": {
		"bg": BG_DARK,
		"border": ACCENT_PRIMARY,
		"text": TEXT_PRIMARY,
	},
	"disabled": {
		"bg": BG_DARKEST,
		"border": BORDER_SUBTLE,
		"text": TEXT_DISABLED,
	},
	"focused": {
		"bg": BG_MEDIUM,
		"border": ACCENT_PRIMARY,
		"text": TEXT_PRIMARY,
	},
}

## Quality level colors.
const QUALITY_COLORS := {
	"low": Color(0.6, 0.6, 0.65, 1.0),
	"medium": Color(0.9, 0.75, 0.3, 1.0),
	"high": Color(0.4, 0.85, 0.5, 1.0),
	"ultra": Color(0.4, 0.65, 1.0, 1.0),
}

## FPS indicator colors.
const FPS_COLORS := {
	"excellent": Color(0.3, 0.95, 0.4, 1.0),  # 120+ FPS
	"great": Color(0.4, 0.9, 0.5, 1.0),       # 90+ FPS
	"good": Color(0.5, 0.85, 0.4, 1.0),       # 60+ FPS
	"okay": Color(0.9, 0.8, 0.3, 1.0),        # 45+ FPS
	"poor": Color(0.95, 0.55, 0.3, 1.0),      # 30+ FPS
	"bad": Color(0.95, 0.35, 0.35, 1.0),      # <30 FPS
}

## Get FPS color based on value.
static func get_fps_color(fps: float) -> Color:
	if fps >= 120:
		return FPS_COLORS["excellent"]
	elif fps >= 90:
		return FPS_COLORS["great"]
	elif fps >= 60:
		return FPS_COLORS["good"]
	elif fps >= 45:
		return FPS_COLORS["okay"]
	elif fps >= 30:
		return FPS_COLORS["poor"]
	else:
		return FPS_COLORS["bad"]
