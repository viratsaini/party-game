## Character preview panel with large character display, ability showcase, and stats.
## Inspired by Valorant's agent select and Apex Legends' legend select screens.
class_name CharacterPreview
extends Control

signal ability_selected(ability_index: int)

# ---- Node References (built dynamically) ----
var background_panel: PanelContainer
var character_display: Control
var character_model: ColorRect
var character_glow: ColorRect
var particle_container: Control
var name_container: Control
var name_label: Label
var title_label: Label
var stats_container: VBoxContainer
var abilities_container: HBoxContainer
var description_label: RichTextLabel
var voice_line_button: Button

# ---- State ----
var _current_skin: CharacterSkin = null
var _rotation_tween: Tween = null
var _particle_tween: Tween = null
var _name_tween: Tween = null
var _stats_tweens: Array[Tween] = []
var _character_rotation: float = 0.0
var _particles: Array[Control] = []

# ---- Character Stats (mock data - would come from character abilities system) ----
const CHARACTER_STATS: Dictionary = {
	"Robot": {"offense": 7, "defense": 8, "mobility": 5, "utility": 6},
	"Ninja": {"offense": 9, "defense": 4, "mobility": 10, "utility": 5},
	"Astronaut": {"offense": 6, "defense": 6, "mobility": 7, "utility": 8},
	"Pirate": {"offense": 8, "defense": 5, "mobility": 6, "utility": 7},
	"Knight": {"offense": 6, "defense": 10, "mobility": 4, "utility": 6},
	"Alien": {"offense": 7, "defense": 5, "mobility": 8, "utility": 9},
}

# ---- Character Voice Lines ----
const VOICE_LINES: Dictionary = {
	"Robot": "Systems online. Ready for combat.",
	"Ninja": "The shadows are my ally.",
	"Astronaut": "One small step for victory.",
	"Pirate": "Ahoy! Let's plunder some wins!",
	"Knight": "For honor and glory!",
	"Alien": "Your world will be ours.",
}


func _ready() -> void:
	_build_ui()
	_start_background_animation()


func _build_ui() -> void:
	custom_minimum_size = Vector2(400, 600)

	# Main background panel with gradient
	background_panel = PanelContainer.new()
	background_panel.name = "BackgroundPanel"
	background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_background_style(background_panel)
	add_child(background_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 16)
	background_panel.add_child(main_vbox)

	# Character display area
	character_display = Control.new()
	character_display.name = "CharacterDisplay"
	character_display.custom_minimum_size = Vector2(0, 280)
	character_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(character_display)

	# Character glow (behind model)
	character_glow = ColorRect.new()
	character_glow.name = "CharacterGlow"
	character_glow.set_anchors_preset(Control.PRESET_CENTER)
	character_glow.offset_left = -120
	character_glow.offset_top = -120
	character_glow.offset_right = 120
	character_glow.offset_bottom = 120
	character_glow.color = Color(0.3, 0.6, 1.0, 0.3)
	character_display.add_child(character_glow)

	# Particle container
	particle_container = Control.new()
	particle_container.name = "ParticleContainer"
	particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_display.add_child(particle_container)

	# Character model representation (simplified as 3D would need SubViewport)
	character_model = ColorRect.new()
	character_model.name = "CharacterModel"
	character_model.set_anchors_preset(Control.PRESET_CENTER)
	character_model.offset_left = -80
	character_model.offset_top = -100
	character_model.offset_right = 80
	character_model.offset_bottom = 100
	character_model.color = Color.WHITE
	character_display.add_child(character_model)

	# Name container with dramatic styling
	name_container = Control.new()
	name_container.name = "NameContainer"
	name_container.custom_minimum_size = Vector2(0, 80)
	main_vbox.add_child(name_container)

	# Character name with typewriter reveal
	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	name_label.offset_top = 5
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 42)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_label.add_theme_constant_override("outline_size", 3)
	name_container.add_child(name_label)

	# Character title/type
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.offset_top = 52
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
	name_container.add_child(title_label)

	# Stats section
	_build_stats_section(main_vbox)

	# Abilities section
	_build_abilities_section(main_vbox)

	# Description
	description_label = RichTextLabel.new()
	description_label.name = "DescriptionLabel"
	description_label.custom_minimum_size = Vector2(0, 60)
	description_label.bbcode_enabled = true
	description_label.fit_content = true
	description_label.add_theme_font_size_override("normal_font_size", 16)
	description_label.add_theme_color_override("default_color", Color(0.8, 0.8, 0.85, 1))
	main_vbox.add_child(description_label)

	# Voice line button
	voice_line_button = Button.new()
	voice_line_button.name = "VoiceLineButton"
	voice_line_button.text = "PLAY VOICE LINE"
	voice_line_button.custom_minimum_size = Vector2(0, 45)
	voice_line_button.add_theme_font_size_override("font_size", 16)
	voice_line_button.pressed.connect(_on_voice_line_pressed)
	main_vbox.add_child(voice_line_button)


func _build_stats_section(parent: VBoxContainer) -> void:
	var stats_panel := PanelContainer.new()
	stats_panel.name = "StatsPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.8)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	stats_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(stats_panel)

	stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	stats_container.add_theme_constant_override("separation", 8)
	stats_panel.add_child(stats_container)

	# Stats header
	var header := Label.new()
	header.text = "STATS"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	stats_container.add_child(header)

	# Create stat bars
	var stat_names: Array[String] = ["OFFENSE", "DEFENSE", "MOBILITY", "UTILITY"]
	for stat_name: String in stat_names:
		var stat_row := _create_stat_row(stat_name)
		stats_container.add_child(stat_row)


func _create_stat_row(stat_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = stat_name + "Row"

	var label := Label.new()
	label.text = stat_name
	label.custom_minimum_size = Vector2(80, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
	row.add_child(label)

	var bar_bg := ColorRect.new()
	bar_bg.name = "BarBG"
	bar_bg.custom_minimum_size = Vector2(150, 12)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.color = Color(0.15, 0.15, 0.2, 1)
	row.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.name = "BarFill"
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.offset_right = 0  # Start at 0 width
	bar_fill.color = _get_stat_color(stat_name)
	bar_bg.add_child(bar_fill)

	return row


func _get_stat_color(stat_name: String) -> Color:
	match stat_name:
		"OFFENSE":
			return Color(0.9, 0.3, 0.3, 1)
		"DEFENSE":
			return Color(0.3, 0.6, 0.9, 1)
		"MOBILITY":
			return Color(0.3, 0.9, 0.5, 1)
		"UTILITY":
			return Color(0.9, 0.7, 0.2, 1)
		_:
			return Color.WHITE


func _build_abilities_section(parent: VBoxContainer) -> void:
	var abilities_panel := PanelContainer.new()
	abilities_panel.name = "AbilitiesPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.8)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	abilities_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(abilities_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	abilities_panel.add_child(vbox)

	var header := Label.new()
	header.text = "ABILITIES"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	vbox.add_child(header)

	abilities_container = HBoxContainer.new()
	abilities_container.name = "AbilitiesContainer"
	abilities_container.alignment = BoxContainer.ALIGNMENT_CENTER
	abilities_container.add_theme_constant_override("separation", 12)
	vbox.add_child(abilities_container)


func _apply_background_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	style.border_color = Color(0.2, 0.3, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(20)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)


## Set the character to display
func set_character(skin: CharacterSkin) -> void:
	if not skin:
		return

	var is_new_character: bool = _current_skin != skin
	_current_skin = skin

	# Update visuals
	_update_character_model(skin)
	_update_background_theme(skin)

	if is_new_character:
		_animate_character_change(skin)
	else:
		_update_info_instant(skin)


func _update_character_model(skin: CharacterSkin) -> void:
	if character_model:
		character_model.color = skin.mesh_color

	if character_glow:
		character_glow.color = Color(skin.accent_color.r, skin.accent_color.g, skin.accent_color.b, 0.4)


func _update_background_theme(skin: CharacterSkin) -> void:
	if background_panel:
		var style: StyleBoxFlat = background_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		# Subtle tint based on character
		var tint: Color = skin.mesh_color
		style.bg_color = Color(tint.r * 0.08, tint.g * 0.08, tint.b * 0.1, 0.95)
		style.border_color = Color(skin.accent_color.r * 0.5, skin.accent_color.g * 0.5, skin.accent_color.b * 0.7, 0.8)
		background_panel.add_theme_stylebox_override("panel", style)


func _animate_character_change(skin: CharacterSkin) -> void:
	# Stop existing animations
	_clear_tweens()

	# Animate model entrance
	_animate_model_entrance()

	# Typewriter name effect
	_animate_name_typewriter(skin.skin_name)

	# Update title
	if title_label:
		title_label.text = skin.character_type.to_upper()

	# Animate stats
	_animate_stats(skin.character_type)

	# Update abilities
	_update_abilities(skin.character_type)

	# Update description
	if description_label:
		description_label.text = "[center]%s[/center]" % skin.description

	# Spawn particles
	_spawn_character_particles(skin)


func _update_info_instant(skin: CharacterSkin) -> void:
	if name_label:
		name_label.text = skin.skin_name
		name_label.visible_ratio = 1.0

	if title_label:
		title_label.text = skin.character_type.to_upper()


func _animate_model_entrance() -> void:
	if not character_model:
		return

	character_model.modulate.a = 0.0
	character_model.scale = Vector2(0.8, 0.8)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(character_model, "modulate:a", 1.0, 0.3)
	tween.tween_property(character_model, "scale", Vector2.ONE, 0.4)

	# Also flash the glow
	if character_glow:
		character_glow.modulate.a = 1.5
		tween.tween_property(character_glow, "modulate:a", 1.0, 0.5)


func _animate_name_typewriter(char_name: String) -> void:
	if not name_label:
		return

	name_label.text = char_name
	name_label.visible_ratio = 0.0

	if _name_tween:
		_name_tween.kill()

	_name_tween = create_tween()
	_name_tween.tween_property(name_label, "visible_ratio", 1.0, 0.4).set_trans(Tween.TRANS_LINEAR)


func _animate_stats(character_type: String) -> void:
	# Clear old tweens
	for tween: Tween in _stats_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_stats_tweens.clear()

	var stats: Dictionary = CHARACTER_STATS.get(character_type, {"offense": 5, "defense": 5, "mobility": 5, "utility": 5})

	var stat_rows: Array[String] = ["OFFENSE", "DEFENSE", "MOBILITY", "UTILITY"]
	var delay: float = 0.0

	for stat_name: String in stat_rows:
		var row: HBoxContainer = stats_container.find_child(stat_name + "Row", true, false) as HBoxContainer
		if not row:
			continue

		var bar_bg: ColorRect = row.find_child("BarBG", true, false) as ColorRect
		if not bar_bg:
			continue

		var bar_fill: ColorRect = bar_bg.find_child("BarFill", true, false) as ColorRect
		if not bar_fill:
			continue

		var stat_key: String = stat_name.to_lower()
		var stat_value: int = stats.get(stat_key, 5)
		var target_width: float = bar_bg.size.x * (stat_value / 10.0)

		bar_fill.offset_right = 0

		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(bar_fill, "offset_right", target_width, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_stats_tweens.append(tween)

		delay += 0.08


func _update_abilities(character_type: String) -> void:
	if not abilities_container:
		return

	# Clear existing
	for child: Node in abilities_container.get_children():
		child.queue_free()

	# Create 3 ability icons (simplified - would be actual ability data)
	for i: int in range(3):
		var ability_btn := _create_ability_icon(i, character_type)
		abilities_container.add_child(ability_btn)

		# Animate entrance
		ability_btn.modulate.a = 0.0
		ability_btn.scale = Vector2(0.5, 0.5)

		var tween := create_tween().set_parallel(true)
		tween.tween_interval(0.1 * i)
		tween.tween_property(ability_btn, "modulate:a", 1.0, 0.2)
		tween.tween_property(ability_btn, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _create_ability_icon(index: int, character_type: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(60, 60)

	var ability_names: Array[String] = _get_ability_names(character_type)
	btn.tooltip_text = ability_names[index] if index < ability_names.size() else "Ability " + str(index + 1)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.25, 1)
	style.border_color = Color(0.3, 0.5, 0.8, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.15, 0.2, 0.35, 1)
	hover_style.border_color = Color(0.4, 0.7, 1.0, 1)
	btn.add_theme_stylebox_override("hover", hover_style)

	# Ability key indicator
	var key_label := Label.new()
	key_label.text = ["Q", "E", "X"][index] if index < 3 else "?"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 24)
	key_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 1))
	btn.add_child(key_label)

	btn.pressed.connect(func() -> void: ability_selected.emit(index))

	return btn


func _get_ability_names(character_type: String) -> Array[String]:
	match character_type:
		"Robot":
			return ["Shield Bash", "System Reboot", "Overclock"]
		"Ninja":
			return ["Shadow Step", "Smoke Bomb", "Blade Storm"]
		"Astronaut":
			return ["Gravity Shift", "Oxygen Boost", "Meteor Strike"]
		"Pirate":
			return ["Cannon Blast", "Grapple Hook", "Broadside"]
		"Knight":
			return ["Shield Wall", "Holy Light", "Divine Charge"]
		"Alien":
			return ["Mind Control", "Teleport", "Invasion"]
		_:
			return ["Ability 1", "Ability 2", "Ultimate"]


func _spawn_character_particles(skin: CharacterSkin) -> void:
	# Clear existing particles
	for particle: Control in _particles:
		if is_instance_valid(particle):
			particle.queue_free()
	_particles.clear()

	if not particle_container:
		return

	# Spawn new particles
	for i: int in range(15):
		var particle := ColorRect.new()
		particle.custom_minimum_size = Vector2(4, 4)
		particle.size = Vector2(4, 4)
		particle.color = skin.accent_color
		particle.modulate.a = randf_range(0.3, 0.8)

		# Random position around character
		particle.position = Vector2(
			particle_container.size.x / 2 + randf_range(-100, 100),
			particle_container.size.y / 2 + randf_range(-120, 120)
		)

		particle_container.add_child(particle)
		_particles.append(particle)

		# Animate floating
		_animate_particle(particle, skin.accent_color)


func _animate_particle(particle: ColorRect, color: Color) -> void:
	var tween := create_tween().set_loops()
	var start_y: float = particle.position.y
	var drift: float = randf_range(20, 40)
	var duration: float = randf_range(2.0, 4.0)

	tween.tween_property(particle, "position:y", start_y - drift, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(particle, "position:y", start_y, duration).set_trans(Tween.TRANS_SINE)

	# Also fade in/out
	var fade_tween := create_tween().set_loops()
	fade_tween.tween_property(particle, "modulate:a", 0.8, duration * 0.5)
	fade_tween.tween_property(particle, "modulate:a", 0.2, duration * 0.5)


func _start_background_animation() -> void:
	# Subtle glow pulse
	if not character_glow:
		return

	var tween := create_tween().set_loops()
	tween.tween_property(character_glow, "scale", Vector2(1.05, 1.05), 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(character_glow, "scale", Vector2(0.95, 0.95), 2.0).set_trans(Tween.TRANS_SINE)


func _on_voice_line_pressed() -> void:
	if not _current_skin:
		return

	var voice_line: String = VOICE_LINES.get(_current_skin.character_type, "...")

	# Flash the button
	var original_color: Color = voice_line_button.modulate
	voice_line_button.modulate = Color(1.3, 1.3, 1.5, 1)

	var tween := create_tween()
	tween.tween_property(voice_line_button, "modulate", original_color, 0.3)

	# Would play audio here
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("voice_line")

	# Show voice line text briefly
	if description_label:
		description_label.text = "[center][i]\"%s\"[/i][/center]" % voice_line
		await get_tree().create_timer(2.0).timeout
		if _current_skin:
			description_label.text = "[center]%s[/center]" % _current_skin.description


func _clear_tweens() -> void:
	if _rotation_tween and _rotation_tween.is_valid():
		_rotation_tween.kill()
	if _particle_tween and _particle_tween.is_valid():
		_particle_tween.kill()
	if _name_tween and _name_tween.is_valid():
		_name_tween.kill()

	for tween: Tween in _stats_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_stats_tweens.clear()


## Play lock-in confirmation animation
func play_lock_in_animation() -> void:
	if not character_model:
		return

	# Screen flash
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.8)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

	# Zoom effect on model
	var model_tween := create_tween()
	model_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	model_tween.tween_property(character_model, "scale", Vector2(1.2, 1.2), 0.15)
	model_tween.tween_property(character_model, "scale", Vector2.ONE, 0.2)

	# Name glow
	if name_label:
		name_label.add_theme_color_override("font_color", Color(1.5, 1.5, 1.8, 1))
		var name_color_tween := create_tween()
		name_color_tween.tween_property(name_label, "theme_override_colors/font_color", Color.WHITE, 0.5)

	# Sound
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("lock_in")
