extends Control
## UI Asset Demo - Demonstrates the procedural UI asset generation system
## This script shows how to use the texture generators at runtime

# Reference to the asset manager (would typically be an autoload)
var asset_manager: ProceduralUIAssets

# Demo UI elements
@onready var demo_container: VBoxContainer = $DemoContainer
@onready var background_rect: TextureRect = $BackgroundRect


func _ready() -> void:
	# Create asset manager instance
	asset_manager = ProceduralUIAssets.new()
	add_child(asset_manager)

	# Wait for assets to be ready
	asset_manager.assets_generated.connect(_on_assets_ready)
	asset_manager.generation_progress.connect(_on_generation_progress)

	# Generate demo UI
	_setup_demo_ui()


func _on_assets_ready() -> void:
	print("All assets generated successfully!")
	print("Cache stats: ", asset_manager.get_cache_stats())


func _on_generation_progress(current: int, total: int) -> void:
	print("Generating assets: %d / %d" % [current, total])


func _setup_demo_ui() -> void:
	# Example 1: Apply procedural background
	_setup_background()

	# Example 2: Create styled buttons
	_create_demo_buttons()

	# Example 3: Create icon display
	_create_icon_showcase()


func _setup_background() -> void:
	# Create a TextureRect for the background if it doesn't exist
	if not background_rect:
		background_rect = TextureRect.new()
		background_rect.name = "BackgroundRect"
		background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(background_rect)
		move_child(background_rect, 0)

	# Apply a cyber grid background
	var bg_texture := BackgroundGenerator.generate_cyber_grid(1080, 1920, "battlezone")
	background_rect.texture = bg_texture


func _create_demo_buttons() -> void:
	if not demo_container:
		demo_container = VBoxContainer.new()
		demo_container.name = "DemoContainer"
		demo_container.set_anchors_preset(Control.PRESET_CENTER)
		demo_container.add_theme_constant_override("separation", 20)
		add_child(demo_container)

	# Create buttons with different styles
	var button_configs := [
		{"text": "PRIMARY ACTION", "style": UITextureGenerator.ButtonStyle.PRIMARY},
		{"text": "SECONDARY", "style": UITextureGenerator.ButtonStyle.SECONDARY},
		{"text": "CONFIRM", "style": UITextureGenerator.ButtonStyle.SUCCESS},
		{"text": "CANCEL", "style": UITextureGenerator.ButtonStyle.DANGER},
		{"text": "WARNING", "style": UITextureGenerator.ButtonStyle.WARNING},
		{"text": "SPECIAL", "style": UITextureGenerator.ButtonStyle.ACCENT},
		{"text": "NEON STYLE", "style": UITextureGenerator.ButtonStyle.NEON}
	]

	for config in button_configs:
		var button := Button.new()
		button.text = config["text"]
		button.custom_minimum_size = Vector2(400, 80)
		button.add_theme_font_size_override("font_size", 28)

		# Apply procedural button textures
		asset_manager.apply_button_style(button, config["style"], Vector2(400, 80))

		demo_container.add_child(button)


func _create_icon_showcase() -> void:
	var icon_container := HBoxContainer.new()
	icon_container.name = "IconShowcase"
	icon_container.add_theme_constant_override("separation", 16)

	# Common icons to showcase
	var icons := [
		IconGenerator.IconType.PLAY,
		IconGenerator.IconType.SETTINGS_GEAR,
		IconGenerator.IconType.USER,
		IconGenerator.IconType.CONTROLLER,
		IconGenerator.IconType.STAR,
		IconGenerator.IconType.TROPHY,
		IconGenerator.IconType.LIGHTNING
	]

	for icon_type in icons:
		var texture_rect := TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(64, 64)
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# Generate icon with glow
		texture_rect.texture = IconGenerator.generate_icon(
			icon_type,
			64,
			Color(0.95, 0.95, 0.95, 1.0),
			true,
			Color(0.3, 0.6, 1.0, 0.4)
		)

		icon_container.add_child(texture_rect)

	demo_container.add_child(icon_container)


## Example: Generate and save textures to disk (useful for editor tools)
func save_generated_assets(base_path: String) -> void:
	# Generate button textures for all styles
	for style in UITextureGenerator.ButtonStyle.values():
		var style_name := UITextureGenerator.ButtonStyle.keys()[style].to_lower()
		var textures := UITextureGenerator.generate_button_texture_set(400, 150, style)

		for state in ["normal", "hover", "pressed", "disabled"]:
			var texture: ImageTexture = textures[state]
			var image := texture.get_image()
			var path := "%s/buttons/button_%s_%s.png" % [base_path, style_name, state]
			image.save_png(path)
			print("Saved: ", path)

	# Generate background textures
	var backgrounds := {
		"radial": BackgroundGenerator.generate_radial_gradient(1080, 1920),
		"cyber_grid": BackgroundGenerator.generate_cyber_grid(1080, 1920),
		"particles": BackgroundGenerator.generate_particle_field(1080, 1920),
		"hexagon": BackgroundGenerator.generate_hexagon_pattern(1080, 1920),
		"circuit": BackgroundGenerator.generate_circuit_board(1080, 1920)
	}

	for bg_name in backgrounds:
		var texture: ImageTexture = backgrounds[bg_name]
		var image := texture.get_image()
		var path := "%s/backgrounds/%s.png" % [base_path, bg_name]
		image.save_png(path)
		print("Saved: ", path)

	# Generate icons
	for icon_type in IconGenerator.IconType.values():
		var type_name := IconGenerator.IconType.keys()[icon_type].to_lower()
		var texture := IconGenerator.generate_icon(icon_type, 128, Color(0.95, 0.95, 0.95, 1.0))
		var image := texture.get_image()
		var path := "%s/icons/icon_%s.png" % [base_path, type_name]
		image.save_png(path)
		print("Saved: ", path)

	print("All assets saved to: ", base_path)


## Example: Create a complete styled panel with procedural elements
func create_styled_panel(title: String, width: int = 500, height: int = 400) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, height)

	# Create panel background stylebox
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.5, 0.9, 0.5)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20

	panel.add_theme_stylebox_override("panel", style)

	# Add content
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)

	# Title label
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1.0))
	vbox.add_child(title_label)

	# Add a separator
	var separator := HSeparator.new()
	vbox.add_child(separator)

	# Content placeholder
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	panel.add_child(vbox)

	return panel


## Utility: Get a random variation of a background for visual interest
func get_random_background(width: int = 1080, height: int = 1920) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var schemes := ["battlezone", "neon", "sunset", "forest", "ice"]
	var scheme: String = schemes[rng.randi() % schemes.size()]

	var styles := [
		BackgroundGenerator.BackgroundStyle.GRADIENT_RADIAL,
		BackgroundGenerator.BackgroundStyle.CYBER_GRID,
		BackgroundGenerator.BackgroundStyle.PARTICLE_FIELD,
		BackgroundGenerator.BackgroundStyle.HEXAGON_PATTERN,
		BackgroundGenerator.BackgroundStyle.CIRCUIT_BOARD
	]
	var style: int = styles[rng.randi() % styles.size()]

	match style:
		BackgroundGenerator.BackgroundStyle.GRADIENT_RADIAL:
			return BackgroundGenerator.generate_radial_gradient(width, height)
		BackgroundGenerator.BackgroundStyle.CYBER_GRID:
			return BackgroundGenerator.generate_cyber_grid(width, height, scheme)
		BackgroundGenerator.BackgroundStyle.PARTICLE_FIELD:
			return BackgroundGenerator.generate_particle_field(width, height, scheme, 200, rng.randi())
		BackgroundGenerator.BackgroundStyle.HEXAGON_PATTERN:
			return BackgroundGenerator.generate_hexagon_pattern(width, height, scheme)
		BackgroundGenerator.BackgroundStyle.CIRCUIT_BOARD:
			return BackgroundGenerator.generate_circuit_board(width, height, scheme, 80, rng.randi())
		_:
			return BackgroundGenerator.generate_layered_background(width, height, scheme)
