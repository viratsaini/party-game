@tool
class_name UITextureGenerator
extends RefCounted
## Professional UI Texture Generator for BattleZone Party
## Generates high-quality button textures, backgrounds, and UI elements
## using procedural generation techniques optimized for mobile

# Button texture presets
enum ButtonStyle {
	PRIMARY,      # Main action buttons (blue gradient)
	SECONDARY,    # Secondary actions (gray/silver)
	SUCCESS,      # Confirm/success (green gradient)
	DANGER,       # Cancel/quit (red gradient)
	WARNING,      # Caution (orange/yellow)
	ACCENT,       # Highlighted/special (purple/gold)
	GHOST,        # Transparent with border
	NEON          # Cyberpunk neon glow style
}

enum BackgroundStyle {
	GRADIENT_RADIAL,
	GRADIENT_LINEAR,
	CYBER_GRID,
	PARTICLE_FIELD,
	HEXAGON_PATTERN,
	CIRCUIT_BOARD
}

# Color palettes for different button styles
const BUTTON_COLORS := {
	ButtonStyle.PRIMARY: {
		"top": Color(0.2, 0.5, 0.95, 1.0),
		"bottom": Color(0.1, 0.3, 0.7, 1.0),
		"border": Color(0.4, 0.7, 1.0, 0.8),
		"glow": Color(0.3, 0.6, 1.0, 0.4),
		"shadow": Color(0.05, 0.1, 0.2, 0.6)
	},
	ButtonStyle.SECONDARY: {
		"top": Color(0.35, 0.35, 0.4, 1.0),
		"bottom": Color(0.2, 0.2, 0.25, 1.0),
		"border": Color(0.5, 0.5, 0.55, 0.7),
		"glow": Color(0.4, 0.4, 0.45, 0.3),
		"shadow": Color(0.1, 0.1, 0.12, 0.5)
	},
	ButtonStyle.SUCCESS: {
		"top": Color(0.2, 0.75, 0.35, 1.0),
		"bottom": Color(0.1, 0.5, 0.2, 1.0),
		"border": Color(0.4, 0.9, 0.5, 0.8),
		"glow": Color(0.3, 0.8, 0.4, 0.4),
		"shadow": Color(0.05, 0.15, 0.07, 0.6)
	},
	ButtonStyle.DANGER: {
		"top": Color(0.9, 0.25, 0.2, 1.0),
		"bottom": Color(0.6, 0.12, 0.1, 1.0),
		"border": Color(1.0, 0.4, 0.35, 0.8),
		"glow": Color(0.95, 0.3, 0.25, 0.4),
		"shadow": Color(0.2, 0.05, 0.04, 0.6)
	},
	ButtonStyle.WARNING: {
		"top": Color(0.95, 0.7, 0.15, 1.0),
		"bottom": Color(0.85, 0.5, 0.1, 1.0),
		"border": Color(1.0, 0.85, 0.3, 0.8),
		"glow": Color(0.95, 0.75, 0.2, 0.4),
		"shadow": Color(0.25, 0.15, 0.03, 0.6)
	},
	ButtonStyle.ACCENT: {
		"top": Color(0.7, 0.3, 0.9, 1.0),
		"bottom": Color(0.45, 0.15, 0.65, 1.0),
		"border": Color(0.85, 0.5, 1.0, 0.8),
		"glow": Color(0.75, 0.4, 0.95, 0.4),
		"shadow": Color(0.15, 0.05, 0.2, 0.6)
	},
	ButtonStyle.GHOST: {
		"top": Color(0.2, 0.2, 0.25, 0.3),
		"bottom": Color(0.15, 0.15, 0.2, 0.2),
		"border": Color(0.6, 0.6, 0.7, 0.6),
		"glow": Color(0.5, 0.5, 0.6, 0.2),
		"shadow": Color(0.0, 0.0, 0.0, 0.3)
	},
	ButtonStyle.NEON: {
		"top": Color(0.05, 0.05, 0.1, 0.95),
		"bottom": Color(0.02, 0.02, 0.05, 0.98),
		"border": Color(0.0, 1.0, 0.9, 1.0),
		"glow": Color(0.0, 0.95, 0.85, 0.6),
		"shadow": Color(0.0, 0.3, 0.28, 0.4)
	}
}


## Generate a professional button texture with gradients, shadows, and borders
## Returns an ImageTexture ready for use in UI
static func generate_button_texture(
	width: int = 400,
	height: int = 150,
	style: ButtonStyle = ButtonStyle.PRIMARY,
	corner_radius: int = 20,
	border_width: int = 3,
	shadow_offset: int = 6,
	shadow_blur: int = 8
) -> ImageTexture:

	var colors: Dictionary = BUTTON_COLORS[style]

	# Create image with space for shadow
	var total_width := width + shadow_blur * 2
	var total_height := height + shadow_blur * 2 + shadow_offset
	var image := Image.create(total_width, total_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var offset_x := shadow_blur
	var offset_y := shadow_blur

	# Draw shadow first (offset and blurred)
	_draw_rounded_rect_gradient(
		image,
		offset_x + shadow_offset / 2,
		offset_y + shadow_offset,
		width,
		height,
		corner_radius,
		colors["shadow"],
		colors["shadow"],
		shadow_blur
	)

	# Draw outer glow
	_draw_rounded_rect_glow(
		image,
		offset_x,
		offset_y,
		width,
		height,
		corner_radius,
		colors["glow"],
		8
	)

	# Draw main button body with gradient
	_draw_rounded_rect_gradient(
		image,
		offset_x,
		offset_y,
		width,
		height,
		corner_radius,
		colors["top"],
		colors["bottom"],
		0
	)

	# Draw inner highlight (top edge shine)
	_draw_inner_highlight(
		image,
		offset_x,
		offset_y,
		width,
		height,
		corner_radius,
		Color(1.0, 1.0, 1.0, 0.15)
	)

	# Draw border
	_draw_rounded_border(
		image,
		offset_x,
		offset_y,
		width,
		height,
		corner_radius,
		colors["border"],
		border_width
	)

	var texture := ImageTexture.create_from_image(image)
	return texture


## Generate a hover state button texture (brighter)
static func generate_button_hover_texture(
	width: int = 400,
	height: int = 150,
	style: ButtonStyle = ButtonStyle.PRIMARY,
	corner_radius: int = 20,
	border_width: int = 3
) -> ImageTexture:

	var colors: Dictionary = BUTTON_COLORS[style].duplicate()
	# Brighten colors for hover state
	colors["top"] = _brighten_color(colors["top"], 0.15)
	colors["bottom"] = _brighten_color(colors["bottom"], 0.1)
	colors["border"] = _brighten_color(colors["border"], 0.2)
	colors["glow"] = Color(colors["glow"].r, colors["glow"].g, colors["glow"].b, colors["glow"].a + 0.2)

	var total_width := width + 16
	var total_height := height + 16 + 6
	var image := Image.create(total_width, total_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var offset_x := 8
	var offset_y := 8

	# Enhanced glow for hover
	_draw_rounded_rect_glow(image, offset_x, offset_y, width, height, corner_radius, colors["glow"], 12)

	# Draw main body
	_draw_rounded_rect_gradient(image, offset_x, offset_y, width, height, corner_radius, colors["top"], colors["bottom"], 0)

	# Inner highlight
	_draw_inner_highlight(image, offset_x, offset_y, width, height, corner_radius, Color(1.0, 1.0, 1.0, 0.25))

	# Border
	_draw_rounded_border(image, offset_x, offset_y, width, height, corner_radius, colors["border"], border_width)

	return ImageTexture.create_from_image(image)


## Generate a pressed state button texture (darker, less shadow)
static func generate_button_pressed_texture(
	width: int = 400,
	height: int = 150,
	style: ButtonStyle = ButtonStyle.PRIMARY,
	corner_radius: int = 20,
	border_width: int = 3
) -> ImageTexture:

	var colors: Dictionary = BUTTON_COLORS[style].duplicate()
	# Darken colors for pressed state
	colors["top"] = _darken_color(colors["top"], 0.15)
	colors["bottom"] = _darken_color(colors["bottom"], 0.1)

	var total_width := width + 16
	var total_height := height + 16
	var image := Image.create(total_width, total_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var offset_x := 8
	var offset_y := 10  # Slight downward shift for pressed feel

	# Minimal glow when pressed
	_draw_rounded_rect_glow(image, offset_x, offset_y, width, height, corner_radius, colors["glow"], 4)

	# Draw main body (inverted gradient for pressed feel)
	_draw_rounded_rect_gradient(image, offset_x, offset_y, width, height, corner_radius, colors["bottom"], colors["top"], 0)

	# Inner shadow instead of highlight
	_draw_inner_shadow(image, offset_x, offset_y, width, height, corner_radius, Color(0.0, 0.0, 0.0, 0.2))

	# Border
	_draw_rounded_border(image, offset_x, offset_y, width, height, corner_radius, colors["border"], border_width)

	return ImageTexture.create_from_image(image)


## Generate a disabled button texture
static func generate_button_disabled_texture(
	width: int = 400,
	height: int = 150,
	corner_radius: int = 20,
	border_width: int = 2
) -> ImageTexture:

	var total_width := width + 16
	var total_height := height + 16
	var image := Image.create(total_width, total_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var offset_x := 8
	var offset_y := 8

	# Desaturated gray colors
	var top_color := Color(0.25, 0.25, 0.28, 0.6)
	var bottom_color := Color(0.18, 0.18, 0.2, 0.6)
	var border_color := Color(0.35, 0.35, 0.38, 0.4)

	# Draw main body
	_draw_rounded_rect_gradient(image, offset_x, offset_y, width, height, corner_radius, top_color, bottom_color, 0)

	# Border
	_draw_rounded_border(image, offset_x, offset_y, width, height, corner_radius, border_color, border_width)

	return ImageTexture.create_from_image(image)


## Generate a complete button texture set (normal, hover, pressed, disabled)
static func generate_button_texture_set(
	width: int = 400,
	height: int = 150,
	style: ButtonStyle = ButtonStyle.PRIMARY,
	corner_radius: int = 20
) -> Dictionary:
	return {
		"normal": generate_button_texture(width, height, style, corner_radius),
		"hover": generate_button_hover_texture(width, height, style, corner_radius),
		"pressed": generate_button_pressed_texture(width, height, style, corner_radius),
		"disabled": generate_button_disabled_texture(width, height, corner_radius)
	}


# ============ HELPER DRAWING FUNCTIONS ============

static func _draw_rounded_rect_gradient(
	image: Image,
	x: int, y: int,
	width: int, height: int,
	radius: int,
	top_color: Color,
	bottom_color: Color,
	blur: int = 0
) -> void:

	for py in range(height):
		var t: float = float(py) / float(height)
		var color := top_color.lerp(bottom_color, t)

		# Apply blur by reducing alpha at edges
		if blur > 0:
			var edge_dist := mini(mini(py, height - py - 1), blur)
			var alpha_mult := float(edge_dist) / float(blur)
			color.a *= alpha_mult

		for px in range(width):
			# Check if pixel is inside rounded rect
			if _is_inside_rounded_rect(px, py, width, height, radius):
				var abs_x := x + px
				var abs_y := y + py
				if abs_x >= 0 and abs_x < image.get_width() and abs_y >= 0 and abs_y < image.get_height():
					# Alpha blend with existing pixel
					var existing := image.get_pixel(abs_x, abs_y)
					var blended := _alpha_blend(existing, color)
					image.set_pixel(abs_x, abs_y, blended)


static func _draw_rounded_rect_glow(
	image: Image,
	x: int, y: int,
	width: int, height: int,
	radius: int,
	glow_color: Color,
	glow_size: int
) -> void:

	for py in range(-glow_size, height + glow_size):
		for px in range(-glow_size, width + glow_size):
			var abs_x := x + px
			var abs_y := y + py

			if abs_x < 0 or abs_x >= image.get_width() or abs_y < 0 or abs_y >= image.get_height():
				continue

			# Calculate distance to rounded rect edge
			var dist := _distance_to_rounded_rect(px, py, width, height, radius)

			if dist > 0 and dist < glow_size:
				var intensity: float = 1.0 - (dist / float(glow_size))
				intensity = intensity * intensity  # Quadratic falloff
				var color := Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * intensity)

				var existing := image.get_pixel(abs_x, abs_y)
				var blended := _alpha_blend(existing, color)
				image.set_pixel(abs_x, abs_y, blended)


static func _draw_rounded_border(
	image: Image,
	x: int, y: int,
	width: int, height: int,
	radius: int,
	border_color: Color,
	border_width: int
) -> void:

	for py in range(height):
		for px in range(width):
			# Check if pixel is on the border
			var is_inside := _is_inside_rounded_rect(px, py, width, height, radius)
			var is_inside_inner := _is_inside_rounded_rect(
				px - border_width, py - border_width,
				width - border_width * 2, height - border_width * 2,
				maxi(0, radius - border_width)
			)

			# Adjust for offset check
			if px < border_width or py < border_width or px >= width - border_width or py >= height - border_width:
				is_inside_inner = false

			if is_inside and not is_inside_inner:
				var abs_x := x + px
				var abs_y := y + py
				if abs_x >= 0 and abs_x < image.get_width() and abs_y >= 0 and abs_y < image.get_height():
					var existing := image.get_pixel(abs_x, abs_y)
					var blended := _alpha_blend(existing, border_color)
					image.set_pixel(abs_x, abs_y, blended)


static func _draw_inner_highlight(
	image: Image,
	x: int, y: int,
	width: int, height: int,
	radius: int,
	highlight_color: Color
) -> void:

	var highlight_height := mini(height / 3, 40)

	for py in range(highlight_height):
		var t: float = float(py) / float(highlight_height)
		var alpha: float = (1.0 - t) * highlight_color.a
		var color := Color(highlight_color.r, highlight_color.g, highlight_color.b, alpha)

		for px in range(width):
			if _is_inside_rounded_rect(px, py, width, height, radius):
				var abs_x := x + px
				var abs_y := y + py
				if abs_x >= 0 and abs_x < image.get_width() and abs_y >= 0 and abs_y < image.get_height():
					var existing := image.get_pixel(abs_x, abs_y)
					var blended := _alpha_blend(existing, color)
					image.set_pixel(abs_x, abs_y, blended)


static func _draw_inner_shadow(
	image: Image,
	x: int, y: int,
	width: int, height: int,
	radius: int,
	shadow_color: Color
) -> void:

	var shadow_height := mini(height / 4, 30)

	for py in range(shadow_height):
		var t: float = float(py) / float(shadow_height)
		var alpha: float = (1.0 - t) * shadow_color.a
		var color := Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha)

		for px in range(width):
			if _is_inside_rounded_rect(px, py, width, height, radius):
				var abs_x := x + px
				var abs_y := y + py
				if abs_x >= 0 and abs_x < image.get_width() and abs_y >= 0 and abs_y < image.get_height():
					var existing := image.get_pixel(abs_x, abs_y)
					var blended := _alpha_blend(existing, color)
					image.set_pixel(abs_x, abs_y, blended)


static func _is_inside_rounded_rect(px: int, py: int, width: int, height: int, radius: int) -> bool:
	# Quick rejection
	if px < 0 or px >= width or py < 0 or py >= height:
		return false

	# Check corners
	if px < radius and py < radius:
		# Top-left corner
		return _point_in_circle(px, py, radius, radius, radius)
	elif px >= width - radius and py < radius:
		# Top-right corner
		return _point_in_circle(px, py, width - radius - 1, radius, radius)
	elif px < radius and py >= height - radius:
		# Bottom-left corner
		return _point_in_circle(px, py, radius, height - radius - 1, radius)
	elif px >= width - radius and py >= height - radius:
		# Bottom-right corner
		return _point_in_circle(px, py, width - radius - 1, height - radius - 1, radius)

	return true


static func _point_in_circle(px: int, py: int, cx: int, cy: int, r: int) -> bool:
	var dx := px - cx
	var dy := py - cy
	return (dx * dx + dy * dy) <= (r * r)


static func _distance_to_rounded_rect(px: int, py: int, width: int, height: int, radius: int) -> float:
	# Calculate distance from point to rounded rect (negative = inside)
	var dx := 0.0
	var dy := 0.0

	if px < 0:
		dx = -px
	elif px >= width:
		dx = px - width + 1

	if py < 0:
		dy = -py
	elif py >= height:
		dy = py - height + 1

	# Handle corners
	if px < radius and py < radius:
		var corner_dist := sqrt(pow(px - radius, 2) + pow(py - radius, 2))
		return corner_dist - radius
	elif px >= width - radius and py < radius:
		var corner_dist := sqrt(pow(px - (width - radius - 1), 2) + pow(py - radius, 2))
		return corner_dist - radius
	elif px < radius and py >= height - radius:
		var corner_dist := sqrt(pow(px - radius, 2) + pow(py - (height - radius - 1), 2))
		return corner_dist - radius
	elif px >= width - radius and py >= height - radius:
		var corner_dist := sqrt(pow(px - (width - radius - 1), 2) + pow(py - (height - radius - 1), 2))
		return corner_dist - radius

	return sqrt(dx * dx + dy * dy)


static func _alpha_blend(base: Color, top: Color) -> Color:
	var out_a := top.a + base.a * (1.0 - top.a)
	if out_a < 0.001:
		return Color(0, 0, 0, 0)

	var out_r := (top.r * top.a + base.r * base.a * (1.0 - top.a)) / out_a
	var out_g := (top.g * top.a + base.g * base.a * (1.0 - top.a)) / out_a
	var out_b := (top.b * top.a + base.b * base.a * (1.0 - top.a)) / out_a

	return Color(out_r, out_g, out_b, out_a)


static func _brighten_color(color: Color, amount: float) -> Color:
	return Color(
		minf(color.r + amount, 1.0),
		minf(color.g + amount, 1.0),
		minf(color.b + amount, 1.0),
		color.a
	)


static func _darken_color(color: Color, amount: float) -> Color:
	return Color(
		maxf(color.r - amount, 0.0),
		maxf(color.g - amount, 0.0),
		maxf(color.b - amount, 0.0),
		color.a
	)
