@tool
extends EditorScript
## Editor Tool: Pre-generate UI Assets
## Run this script from the Godot Editor (Script > Run) to generate all UI assets
## and save them to the assets directory for optimal runtime performance

const OUTPUT_PATH := "res://assets/generated/"


func _run() -> void:
	print("=== BattleZone Party UI Asset Generator ===")
	print("Starting asset generation...")

	# Ensure output directories exist
	_ensure_directories()

	# Generate all assets
	_generate_button_textures()
	_generate_background_textures()
	_generate_icon_textures()

	print("=== Asset generation complete! ===")
	print("Assets saved to: ", OUTPUT_PATH)


func _ensure_directories() -> void:
	var dirs := [
		OUTPUT_PATH,
		OUTPUT_PATH + "buttons/",
		OUTPUT_PATH + "backgrounds/",
		OUTPUT_PATH + "icons/"
	]

	for dir_path in dirs:
		var dir := DirAccess.open("res://")
		if dir:
			var relative_path := dir_path.replace("res://", "")
			if not dir.dir_exists(relative_path):
				dir.make_dir_recursive(relative_path)
				print("Created directory: ", dir_path)


func _generate_button_textures() -> void:
	print("\n--- Generating Button Textures ---")

	var sizes := [
		{"name": "large", "width": 400, "height": 150},
		{"name": "medium", "width": 300, "height": 80},
		{"name": "small", "width": 200, "height": 60}
	]

	var styles := {
		UITextureGenerator.ButtonStyle.PRIMARY: "primary",
		UITextureGenerator.ButtonStyle.SECONDARY: "secondary",
		UITextureGenerator.ButtonStyle.SUCCESS: "success",
		UITextureGenerator.ButtonStyle.DANGER: "danger",
		UITextureGenerator.ButtonStyle.WARNING: "warning",
		UITextureGenerator.ButtonStyle.ACCENT: "accent",
		UITextureGenerator.ButtonStyle.NEON: "neon"
	}

	for size_config in sizes:
		for style_enum in styles:
			var style_name: String = styles[style_enum]
			var textures := UITextureGenerator.generate_button_texture_set(
				size_config["width"],
				size_config["height"],
				style_enum
			)

			for state in ["normal", "hover", "pressed", "disabled"]:
				var texture: ImageTexture = textures[state]
				var image := texture.get_image()
				var filename := "button_%s_%s_%s.png" % [style_name, size_config["name"], state]
				var path := OUTPUT_PATH + "buttons/" + filename
				var error := image.save_png(path)
				if error == OK:
					print("  Saved: ", filename)
				else:
					print("  ERROR saving: ", filename)

	print("Button textures complete!")


func _generate_background_textures() -> void:
	print("\n--- Generating Background Textures ---")

	var schemes := ["battlezone", "neon", "sunset", "forest", "ice"]
	var width := 1080
	var height := 1920

	# Radial gradient
	var radial := BackgroundGenerator.generate_radial_gradient(width, height)
	_save_background(radial, "radial_gradient")

	# Linear gradient
	var linear := BackgroundGenerator.generate_linear_gradient(width, height)
	_save_background(linear, "linear_gradient")

	# Scheme-based backgrounds
	for scheme in schemes:
		# Cyber grid
		var cyber := BackgroundGenerator.generate_cyber_grid(width, height, scheme)
		_save_background(cyber, "cyber_grid_" + scheme)

		# Particle field
		var particles := BackgroundGenerator.generate_particle_field(width, height, scheme)
		_save_background(particles, "particles_" + scheme)

		# Hexagon pattern
		var hexagon := BackgroundGenerator.generate_hexagon_pattern(width, height, scheme)
		_save_background(hexagon, "hexagon_" + scheme)

		# Circuit board
		var circuit := BackgroundGenerator.generate_circuit_board(width, height, scheme)
		_save_background(circuit, "circuit_" + scheme)

		# Layered
		var layered := BackgroundGenerator.generate_layered_background(width, height, scheme)
		_save_background(layered, "layered_" + scheme)

	print("Background textures complete!")


func _save_background(texture: ImageTexture, name: String) -> void:
	var image := texture.get_image()
	var filename := "bg_%s.png" % name
	var path := OUTPUT_PATH + "backgrounds/" + filename
	var error := image.save_png(path)
	if error == OK:
		print("  Saved: ", filename)
	else:
		print("  ERROR saving: ", filename)


func _generate_icon_textures() -> void:
	print("\n--- Generating Icon Textures ---")

	var sizes := [32, 64, 128]
	var color_variants := {
		"white": Color(0.95, 0.95, 0.95, 1.0),
		"accent": Color(0.3, 0.6, 1.0, 1.0),
		"gold": Color(1.0, 0.85, 0.2, 1.0),
		"success": Color(0.3, 0.85, 0.4, 1.0),
		"danger": Color(0.95, 0.3, 0.25, 1.0)
	}

	var icon_names := {
		IconGenerator.IconType.PLAY: "play",
		IconGenerator.IconType.PAUSE: "pause",
		IconGenerator.IconType.SETTINGS_GEAR: "settings",
		IconGenerator.IconType.HOME: "home",
		IconGenerator.IconType.BACK_ARROW: "back",
		IconGenerator.IconType.FORWARD_ARROW: "forward",
		IconGenerator.IconType.REFRESH: "refresh",
		IconGenerator.IconType.CLOSE_X: "close",
		IconGenerator.IconType.CHECK: "check",
		IconGenerator.IconType.PLUS: "plus",
		IconGenerator.IconType.MINUS: "minus",
		IconGenerator.IconType.STAR: "star",
		IconGenerator.IconType.HEART: "heart",
		IconGenerator.IconType.SHIELD: "shield",
		IconGenerator.IconType.SWORD: "sword",
		IconGenerator.IconType.TROPHY: "trophy",
		IconGenerator.IconType.CROWN: "crown",
		IconGenerator.IconType.LIGHTNING: "lightning",
		IconGenerator.IconType.FIRE: "fire",
		IconGenerator.IconType.CROSSHAIR: "crosshair",
		IconGenerator.IconType.CONTROLLER: "controller",
		IconGenerator.IconType.WIFI: "wifi",
		IconGenerator.IconType.VOLUME_HIGH: "volume_high",
		IconGenerator.IconType.VOLUME_MUTE: "volume_mute",
		IconGenerator.IconType.USER: "user",
		IconGenerator.IconType.USERS: "users",
		IconGenerator.IconType.CHAT: "chat",
		IconGenerator.IconType.FLAG: "flag",
		IconGenerator.IconType.TIMER: "timer",
		IconGenerator.IconType.COIN: "coin"
	}

	# Generate standard white icons at all sizes
	for icon_type in icon_names:
		var name: String = icon_names[icon_type]
		for size in sizes:
			var texture := IconGenerator.generate_icon(
				icon_type,
				size,
				color_variants["white"],
				false
			)
			var image := texture.get_image()
			var filename := "icon_%s_%d.png" % [name, size]
			var path := OUTPUT_PATH + "icons/" + filename
			var error := image.save_png(path)
			if error == OK:
				print("  Saved: ", filename)
			else:
				print("  ERROR saving: ", filename)

	# Generate colored variants for common icons at 64px
	var common_icons := [
		IconGenerator.IconType.STAR,
		IconGenerator.IconType.HEART,
		IconGenerator.IconType.CHECK,
		IconGenerator.IconType.CLOSE_X
	]

	for icon_type in common_icons:
		var name: String = icon_names[icon_type]
		for color_name in color_variants:
			if color_name == "white":
				continue  # Already generated
			var color: Color = color_variants[color_name]
			var texture := IconGenerator.generate_icon(icon_type, 64, color, true)
			var image := texture.get_image()
			var filename := "icon_%s_%s_64.png" % [name, color_name]
			var path := OUTPUT_PATH + "icons/" + filename
			var error := image.save_png(path)
			if error == OK:
				print("  Saved: ", filename)
			else:
				print("  ERROR saving: ", filename)

	print("Icon textures complete!")
