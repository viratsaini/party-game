@tool
class_name BackgroundGenerator
extends RefCounted
## Procedural Background Generator for BattleZone Party
## Creates dynamic, animated-ready background textures
## Optimized for mobile performance

enum BackgroundStyle {
	GRADIENT_RADIAL,
	GRADIENT_LINEAR,
	CYBER_GRID,
	PARTICLE_FIELD,
	HEXAGON_PATTERN,
	CIRCUIT_BOARD,
	NEBULA,
	GEOMETRIC_WAVES
}

# Color schemes for different moods
const COLOR_SCHEMES := {
	"battlezone": {
		"primary": Color(0.08, 0.08, 0.14, 1.0),
		"secondary": Color(0.12, 0.12, 0.22, 1.0),
		"accent": Color(0.3, 0.5, 0.9, 1.0),
		"highlight": Color(0.9, 0.7, 0.2, 1.0)
	},
	"neon": {
		"primary": Color(0.02, 0.02, 0.06, 1.0),
		"secondary": Color(0.05, 0.02, 0.1, 1.0),
		"accent": Color(0.0, 1.0, 0.9, 1.0),
		"highlight": Color(1.0, 0.0, 0.8, 1.0)
	},
	"sunset": {
		"primary": Color(0.15, 0.08, 0.12, 1.0),
		"secondary": Color(0.25, 0.1, 0.15, 1.0),
		"accent": Color(0.95, 0.4, 0.2, 1.0),
		"highlight": Color(1.0, 0.8, 0.3, 1.0)
	},
	"forest": {
		"primary": Color(0.04, 0.1, 0.06, 1.0),
		"secondary": Color(0.06, 0.15, 0.08, 1.0),
		"accent": Color(0.3, 0.8, 0.4, 1.0),
		"highlight": Color(0.8, 0.95, 0.4, 1.0)
	},
	"ice": {
		"primary": Color(0.08, 0.12, 0.18, 1.0),
		"secondary": Color(0.1, 0.15, 0.25, 1.0),
		"accent": Color(0.5, 0.8, 1.0, 1.0),
		"highlight": Color(0.9, 0.95, 1.0, 1.0)
	}
}


## Generate a radial gradient background (center to edge)
static func generate_radial_gradient(
	width: int = 1080,
	height: int = 1920,
	center_color: Color = Color(0.15, 0.15, 0.25, 1.0),
	edge_color: Color = Color(0.05, 0.05, 0.1, 1.0),
	center_offset: Vector2 = Vector2(0.5, 0.35)  # Slightly above center
) -> ImageTexture:

	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)

	var center_x := width * center_offset.x
	var center_y := height * center_offset.y
	var max_dist := sqrt(pow(width, 2) + pow(height, 2)) * 0.6

	for y in range(height):
		for x in range(width):
			var dist := sqrt(pow(x - center_x, 2) + pow(y - center_y, 2))
			var t: float = clampf(dist / max_dist, 0.0, 1.0)
			# Apply easing for smoother gradient
			t = t * t * (3.0 - 2.0 * t)  # Smoothstep
			var color := center_color.lerp(edge_color, t)
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


## Generate a linear gradient background
static func generate_linear_gradient(
	width: int = 1080,
	height: int = 1920,
	top_color: Color = Color(0.18, 0.15, 0.25, 1.0),
	bottom_color: Color = Color(0.05, 0.05, 0.1, 1.0),
	angle_degrees: float = 0.0  # 0 = top to bottom
) -> ImageTexture:

	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)

	var angle_rad := deg_to_rad(angle_degrees)
	var dir_x := sin(angle_rad)
	var dir_y := cos(angle_rad)

	# Calculate projection range
	var corners := [
		Vector2(0, 0), Vector2(width, 0),
		Vector2(0, height), Vector2(width, height)
	]
	var min_proj := INF
	var max_proj := -INF

	for corner in corners:
		var proj: float = corner.x * dir_x + corner.y * dir_y
		min_proj = minf(min_proj, proj)
		max_proj = maxf(max_proj, proj)

	var proj_range := max_proj - min_proj

	for y in range(height):
		for x in range(width):
			var proj: float = x * dir_x + y * dir_y
			var t: float = (proj - min_proj) / proj_range
			t = clampf(t, 0.0, 1.0)
			var color := top_color.lerp(bottom_color, t)
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


## Generate a cyberpunk-style grid background
static func generate_cyber_grid(
	width: int = 1080,
	height: int = 1920,
	scheme_name: String = "battlezone",
	grid_spacing: int = 60,
	line_thickness: int = 2,
	perspective_strength: float = 0.4
) -> ImageTexture:

	var scheme: Dictionary = COLOR_SCHEMES.get(scheme_name, COLOR_SCHEMES["battlezone"])
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)

	# Fill with base gradient
	for y in range(height):
		var t: float = float(y) / float(height)
		var base_color: Color = scheme["primary"].lerp(scheme["secondary"], t)
		for x in range(width):
			image.set_pixel(x, y, base_color)

	# Draw grid lines with perspective
	var horizon_y := height * 0.3
	var grid_color := Color(scheme["accent"].r, scheme["accent"].g, scheme["accent"].b, 0.3)
	var bright_grid_color := Color(scheme["accent"].r, scheme["accent"].g, scheme["accent"].b, 0.6)

	# Horizontal lines (with perspective spacing)
	var current_y := int(horizon_y)
	var spacing := 20.0
	var line_count := 0

	while current_y < height:
		var is_major := (line_count % 5 == 0)
		var color := bright_grid_color if is_major else grid_color
		var thickness := line_thickness * 2 if is_major else line_thickness

		for dy in range(thickness):
			var py := current_y + dy
			if py >= 0 and py < height:
				for x in range(width):
					var existing := image.get_pixel(x, py)
					var blended := _alpha_blend(existing, color)
					image.set_pixel(x, py, blended)

		spacing *= (1.0 + perspective_strength * 0.1)
		current_y += int(spacing)
		line_count += 1

	# Vertical lines (converging to horizon)
	var vanishing_x := width * 0.5
	var num_lines := 20

	for i in range(-num_lines, num_lines + 1):
		var is_major := (i % 5 == 0)
		var color := bright_grid_color if is_major else grid_color
		var thickness := line_thickness * 2 if is_major else line_thickness

		var bottom_x := vanishing_x + i * grid_spacing

		for y in range(int(horizon_y), height):
			var t: float = float(y - horizon_y) / float(height - horizon_y)
			var x_pos: float = lerpf(vanishing_x, bottom_x, t)

			for dx in range(-thickness / 2, thickness / 2 + 1):
				var px := int(x_pos) + dx
				if px >= 0 and px < width:
					var existing := image.get_pixel(px, y)
					var blended := _alpha_blend(existing, color)
					image.set_pixel(px, y, blended)

	# Add glow at horizon
	_add_horizon_glow(image, int(horizon_y), width, scheme["accent"])

	return ImageTexture.create_from_image(image)


## Generate a particle/star field background
static func generate_particle_field(
	width: int = 1080,
	height: int = 1920,
	scheme_name: String = "battlezone",
	particle_count: int = 200,
	seed_value: int = 12345
) -> ImageTexture:

	var scheme: Dictionary = COLOR_SCHEMES.get(scheme_name, COLOR_SCHEMES["battlezone"])
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)

	# Fill with gradient base
	for y in range(height):
		var t: float = float(y) / float(height)
		var base_color: Color = scheme["primary"].lerp(scheme["secondary"], t * 0.5)
		for x in range(width):
			image.set_pixel(x, y, base_color)

	# Add particles using seeded random
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	for i in range(particle_count):
		var px := rng.randi() % width
		var py := rng.randi() % height
		var size := rng.randf_range(1.0, 4.0)
		var brightness := rng.randf_range(0.3, 1.0)

		# Choose color (mostly accent, some highlights)
		var particle_color: Color
		if rng.randf() < 0.2:
			particle_color = scheme["highlight"]
		else:
			particle_color = scheme["accent"]

		particle_color.a = brightness

		# Draw particle with glow
		_draw_particle(image, px, py, size, particle_color)

	# Add some larger "nebula" patches
	for i in range(5):
		var cx := rng.randi() % width
		var cy := rng.randi() % height
		var radius := rng.randf_range(100, 300)
		var nebula_color: Color = scheme["accent"]
		nebula_color.a = rng.randf_range(0.02, 0.06)
		_draw_nebula_patch(image, cx, cy, radius, nebula_color)

	return ImageTexture.create_from_image(image)


## Generate hexagon pattern background
static func generate_hexagon_pattern(
	width: int = 1080,
	height: int = 1920,
	scheme_name: String = "battlezone",
	hex_size: int = 50
) -> ImageTexture:

	var scheme: Dictionary = COLOR_SCHEMES.get(scheme_name, COLOR_SCHEMES["battlezone"])
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)

	# Fill base
	for y in range(height):
		var t: float = float(y) / float(height)
		var base_color: Color = scheme["primary"].lerp(scheme["secondary"], t)
		for x in range(width):
			image.set_pixel(x, y, base_color)

	# Draw hexagon grid
	var hex_height := hex_size * 2
	var hex_width := hex_size * sqrt(3.0)
	var vert_spacing := hex_height * 0.75

	var row := 0
	var y_pos := -hex_size

	while y_pos < height + hex_size:
		var x_offset: float = hex_width / 2 if row % 2 == 1 else 0
		var x_pos := -hex_width + x_offset

		while x_pos < width + hex_width:
			# Calculate distance from center for color variation
			var center_dist := sqrt(pow(x_pos - width / 2, 2) + pow(y_pos - height / 3, 2))
			var max_dist := sqrt(pow(width, 2) + pow(height, 2)) * 0.5
			var dist_factor := 1.0 - clampf(center_dist / max_dist, 0.0, 1.0)

			var hex_color: Color = scheme["accent"]
			hex_color.a = 0.1 + dist_factor * 0.15

			_draw_hexagon(image, int(x_pos), int(y_pos), hex_size, hex_color, 2)
			x_pos += hex_width

		y_pos += vert_spacing
		row += 1

	return ImageTexture.create_from_image(image)


## Generate circuit board pattern background
static func generate_circuit_board(
	width: int = 1080,
	height: int = 1920,
	scheme_name: String = "neon",
	line_spacing: int = 80,
	seed_value: int = 42
) -> ImageTexture:

	var scheme: Dictionary = COLOR_SCHEMES.get(scheme_name, COLOR_SCHEMES["neon"])
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)

	# Fill base
	for y in range(height):
		var t: float = float(y) / float(height)
		var base_color: Color = scheme["primary"].lerp(scheme["secondary"], t)
		for x in range(width):
			image.set_pixel(x, y, base_color)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var trace_color: Color = scheme["accent"]
	trace_color.a = 0.4
	var node_color: Color = scheme["highlight"]
	node_color.a = 0.6

	# Draw circuit traces
	var num_traces := 40

	for i in range(num_traces):
		var start_x := rng.randi() % width
		var start_y := rng.randi() % height
		var trace_length := rng.randi_range(3, 8)

		var current_x := start_x
		var current_y := start_y

		# Draw starting node
		_draw_circuit_node(image, current_x, current_y, 6, node_color)

		for _j in range(trace_length):
			# Choose direction (orthogonal movement)
			var direction := rng.randi() % 4
			var segment_length := rng.randi_range(40, 150)

			var next_x := current_x
			var next_y := current_y

			match direction:
				0: next_x = mini(current_x + segment_length, width - 1)  # Right
				1: next_x = maxi(current_x - segment_length, 0)          # Left
				2: next_y = mini(current_y + segment_length, height - 1) # Down
				3: next_y = maxi(current_y - segment_length, 0)          # Up

			# Draw trace segment
			_draw_circuit_trace(image, current_x, current_y, next_x, next_y, 2, trace_color)

			current_x = next_x
			current_y = next_y

			# Occasionally add a node
			if rng.randf() < 0.3:
				_draw_circuit_node(image, current_x, current_y, 4, node_color)

		# End node
		_draw_circuit_node(image, current_x, current_y, 6, node_color)

	return ImageTexture.create_from_image(image)


## Generate complete background with multiple layers
static func generate_layered_background(
	width: int = 1080,
	height: int = 1920,
	scheme_name: String = "battlezone"
) -> ImageTexture:

	var scheme: Dictionary = COLOR_SCHEMES.get(scheme_name, COLOR_SCHEMES["battlezone"])
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)

	# Layer 1: Base radial gradient
	for y in range(height):
		for x in range(width):
			var center_x := width * 0.5
			var center_y := height * 0.3
			var dist := sqrt(pow(x - center_x, 2) + pow(y - center_y, 2))
			var max_dist := sqrt(pow(width, 2) + pow(height, 2)) * 0.6
			var t: float = clampf(dist / max_dist, 0.0, 1.0)
			t = t * t
			var color: Color = scheme["primary"].lerp(scheme["secondary"], t)
			image.set_pixel(x, y, color)

	# Layer 2: Subtle vignette
	_apply_vignette(image, 0.3)

	# Layer 3: Top accent glow
	var glow_color: Color = scheme["accent"]
	glow_color.a = 0.15
	for y in range(mini(400, height)):
		var t: float = float(y) / 400.0
		var alpha: float = (1.0 - t) * glow_color.a
		var row_color := Color(glow_color.r, glow_color.g, glow_color.b, alpha)
		for x in range(width):
			var existing := image.get_pixel(x, y)
			var blended := _additive_blend(existing, row_color)
			image.set_pixel(x, y, blended)

	return ImageTexture.create_from_image(image)


# ============ HELPER FUNCTIONS ============

static func _alpha_blend(base: Color, top: Color) -> Color:
	var out_a := top.a + base.a * (1.0 - top.a)
	if out_a < 0.001:
		return Color(0, 0, 0, 0)

	var out_r := (top.r * top.a + base.r * base.a * (1.0 - top.a)) / out_a
	var out_g := (top.g * top.a + base.g * base.a * (1.0 - top.a)) / out_a
	var out_b := (top.b * top.a + base.b * base.a * (1.0 - top.a)) / out_a

	return Color(out_r, out_g, out_b, out_a)


static func _additive_blend(base: Color, top: Color) -> Color:
	return Color(
		minf(base.r + top.r * top.a, 1.0),
		minf(base.g + top.g * top.a, 1.0),
		minf(base.b + top.b * top.a, 1.0),
		base.a
	)


static func _add_horizon_glow(image: Image, horizon_y: int, width: int, color: Color) -> void:
	var glow_height := 100
	var glow_color := Color(color.r, color.g, color.b, 0.2)

	for dy in range(-glow_height, glow_height):
		var y := horizon_y + dy
		if y < 0 or y >= image.get_height():
			continue

		var t: float = 1.0 - abs(float(dy)) / float(glow_height)
		t = t * t
		var row_color := Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * t)

		for x in range(width):
			var existing := image.get_pixel(x, y)
			var blended := _additive_blend(existing, row_color)
			image.set_pixel(x, y, blended)


static func _draw_particle(image: Image, cx: int, cy: int, size: float, color: Color) -> void:
	var radius := int(ceil(size * 3))

	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
				continue

			var dist := sqrt(float(dx * dx + dy * dy))
			if dist <= size * 3:
				var intensity := exp(-dist * dist / (2.0 * size * size))
				var pixel_color := Color(color.r, color.g, color.b, color.a * intensity)
				var existing := image.get_pixel(x, y)
				var blended := _additive_blend(existing, pixel_color)
				image.set_pixel(x, y, blended)


static func _draw_nebula_patch(image: Image, cx: int, cy: int, radius: float, color: Color) -> void:
	var int_radius := int(radius)

	for dy in range(-int_radius, int_radius + 1):
		for dx in range(-int_radius, int_radius + 1):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
				continue

			var dist := sqrt(float(dx * dx + dy * dy))
			if dist <= radius:
				var t: float = dist / radius
				var intensity := (1.0 - t * t) * color.a
				var pixel_color := Color(color.r, color.g, color.b, intensity)
				var existing := image.get_pixel(x, y)
				var blended := _additive_blend(existing, pixel_color)
				image.set_pixel(x, y, blended)


static func _draw_hexagon(image: Image, cx: int, cy: int, size: int, color: Color, thickness: int) -> void:
	# Calculate hexagon vertices
	var vertices: Array[Vector2] = []
	for i in range(6):
		var angle := deg_to_rad(60.0 * i - 30.0)
		var vx := cx + size * cos(angle)
		var vy := cy + size * sin(angle)
		vertices.append(Vector2(vx, vy))

	# Draw hexagon edges
	for i in range(6):
		var v1 := vertices[i]
		var v2 := vertices[(i + 1) % 6]
		_draw_line(image, int(v1.x), int(v1.y), int(v2.x), int(v2.y), color, thickness)


static func _draw_line(image: Image, x1: int, y1: int, x2: int, y2: int, color: Color, thickness: int) -> void:
	var dx: int = abs(x2 - x1)
	var dy: int = abs(y2 - y1)
	var sx: int = 1 if x1 < x2 else -1
	var sy: int = 1 if y1 < y2 else -1
	var err: int = dx - dy

	var x: int = x1
	var y: int = y1

	while true:
		# Draw with thickness
		for ty in range(-thickness / 2, thickness / 2 + 1):
			for tx in range(-thickness / 2, thickness / 2 + 1):
				var px := x + tx
				var py := y + ty
				if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
					var existing := image.get_pixel(px, py)
					var blended := _alpha_blend(existing, color)
					image.set_pixel(px, py, blended)

		if x == x2 and y == y2:
			break

		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy


static func _draw_circuit_trace(image: Image, x1: int, y1: int, x2: int, y2: int, thickness: int, color: Color) -> void:
	_draw_line(image, x1, y1, x2, y2, color, thickness)


static func _draw_circuit_node(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
				continue

			var dist := sqrt(float(dx * dx + dy * dy))
			if dist <= radius:
				var existing := image.get_pixel(x, y)
				var blended := _alpha_blend(existing, color)
				image.set_pixel(x, y, blended)


static func _apply_vignette(image: Image, strength: float) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var center_x := width / 2.0
	var center_y := height / 2.0
	var max_dist := sqrt(center_x * center_x + center_y * center_y)

	for y in range(height):
		for x in range(width):
			var dist := sqrt(pow(x - center_x, 2) + pow(y - center_y, 2))
			var t: float = clampf(dist / max_dist, 0.0, 1.0)
			var darkening: float = t * t * strength

			var pixel := image.get_pixel(x, y)
			pixel.r *= (1.0 - darkening)
			pixel.g *= (1.0 - darkening)
			pixel.b *= (1.0 - darkening)
			image.set_pixel(x, y, pixel)
