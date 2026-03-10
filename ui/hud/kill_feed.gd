## Animated kill feed system for displaying player eliminations.
## Supports weapon icons, team colors, and smooth animations.
class_name KillFeed
extends VBoxContainer

## Maximum number of visible entries at once.
const MAX_ENTRIES: int = 5
## How long an entry stays visible before fading.
const ENTRY_LIFETIME: float = 5.0
## Duration of fade-out animation.
const FADE_DURATION: float = 0.8
## Duration of slide-in animation.
const SLIDE_IN_DURATION: float = 0.3
## Horizontal slide distance for entry animation.
const SLIDE_DISTANCE: float = 100.0

## Weapon icon textures (loaded dynamically or set via export).
var weapon_icons: Dictionary = {}

## Entry scene - we create entries programmatically for flexibility.
var _entries: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)

	# Pre-load weapon icons if they exist.
	_load_weapon_icons()


## Load weapon icons from the assets folder.
func _load_weapon_icons() -> void:
	var icon_paths: Dictionary = {
		"blaster": "res://assets/icons/weapon_blaster.png",
		"rapid_fire": "res://assets/icons/weapon_rapid.png",
		"power_shot": "res://assets/icons/weapon_power.png",
		"rocket": "res://assets/icons/weapon_rocket.png",
		"shotgun": "res://assets/icons/weapon_shotgun.png",
		"sniper": "res://assets/icons/weapon_sniper.png",
		"melee": "res://assets/icons/weapon_melee.png",
		"explosion": "res://assets/icons/weapon_explosion.png",
		"environment": "res://assets/icons/weapon_environment.png",
		"default": "res://assets/icons/weapon_default.png",
	}

	for weapon_id: String in icon_paths:
		var path: String = icon_paths[weapon_id]
		if ResourceLoader.exists(path):
			weapon_icons[weapon_id] = load(path) as Texture2D


## Add a kill entry to the feed.
## [param killer_name] Name of the player who got the kill.
## [param victim_name] Name of the player who was eliminated.
## [param weapon_id] Identifier for the weapon used (for icon lookup).
## [param killer_color] Team/player color for the killer.
## [param victim_color] Team/player color for the victim.
func add_kill(
	killer_name: String,
	victim_name: String,
	weapon_id: String = "default",
	killer_color: Color = Color.WHITE,
	victim_color: Color = Color.WHITE
) -> void:
	var entry: Control = _create_kill_entry(killer_name, victim_name, weapon_id, killer_color, victim_color)
	add_child(entry)
	move_child(entry, 0)
	_entries.insert(0, entry)

	# Animate entry.
	_animate_entry_in(entry)

	# Remove oldest entries if over limit.
	while _entries.size() > MAX_ENTRIES:
		var oldest: Control = _entries.pop_back()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Schedule fade-out.
	_schedule_fade_out(entry)


## Add a generic event entry (not a kill, just text).
## [param text] The event text to display.
## [param color] Color of the text.
func add_event(text: String, color: Color = Color.WHITE) -> void:
	var entry: Control = _create_event_entry(text, color)
	add_child(entry)
	move_child(entry, 0)
	_entries.insert(0, entry)

	# Animate entry.
	_animate_entry_in(entry)

	# Remove oldest entries if over limit.
	while _entries.size() > MAX_ENTRIES:
		var oldest: Control = _entries.pop_back()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Schedule fade-out.
	_schedule_fade_out(entry)


## Create a kill entry with killer, weapon icon, and victim.
func _create_kill_entry(
	killer_name: String,
	victim_name: String,
	weapon_id: String,
	killer_color: Color,
	victim_color: Color
) -> Control:
	var container: HBoxContainer = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background panel for better readability.
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Killer name.
	var killer_label: Label = Label.new()
	killer_label.text = killer_name
	killer_label.add_theme_color_override("font_color", killer_color)
	killer_label.add_theme_font_size_override("font_size", 16)
	killer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	killer_label.add_theme_constant_override("shadow_offset_x", 1)
	killer_label.add_theme_constant_override("shadow_offset_y", 1)
	content.add_child(killer_label)

	# Weapon icon.
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if weapon_icons.has(weapon_id):
		icon_rect.texture = weapon_icons[weapon_id]
	elif weapon_icons.has("default"):
		icon_rect.texture = weapon_icons["default"]
	else:
		# Create a simple skull placeholder.
		var skull_label: Label = Label.new()
		skull_label.text = ">"
		skull_label.add_theme_color_override("font_color", Color.RED)
		skull_label.add_theme_font_size_override("font_size", 16)
		content.add_child(skull_label)
		icon_rect.queue_free()
		icon_rect = null

	if icon_rect:
		content.add_child(icon_rect)

	# Victim name.
	var victim_label: Label = Label.new()
	victim_label.text = victim_name
	victim_label.add_theme_color_override("font_color", victim_color)
	victim_label.add_theme_font_size_override("font_size", 16)
	victim_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	victim_label.add_theme_constant_override("shadow_offset_x", 1)
	victim_label.add_theme_constant_override("shadow_offset_y", 1)
	content.add_child(victim_label)

	panel.add_child(content)
	container.add_child(panel)

	return container


## Create a simple event entry (text only).
func _create_event_entry(text: String, color: Color) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(label)

	return panel


## Animate an entry sliding in from the left.
func _animate_entry_in(entry: Control) -> void:
	entry.modulate.a = 0.0
	entry.position.x = -SLIDE_DISTANCE

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(entry, "modulate:a", 1.0, SLIDE_IN_DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_property(entry, "position:x", 0.0, SLIDE_IN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Schedule an entry to fade out after ENTRY_LIFETIME.
func _schedule_fade_out(entry: Control) -> void:
	# Wait for lifetime.
	var timer: SceneTreeTimer = get_tree().create_timer(ENTRY_LIFETIME - FADE_DURATION)
	timer.timeout.connect(_fade_out_entry.bind(entry))


## Fade out and remove an entry.
func _fade_out_entry(entry: Control) -> void:
	if not is_instance_valid(entry):
		return

	var tween: Tween = create_tween()
	tween.tween_property(entry, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func() -> void:
		if is_instance_valid(entry):
			_entries.erase(entry)
			entry.queue_free()
	)


## Clear all entries.
func clear() -> void:
	for entry: Control in _entries:
		if is_instance_valid(entry):
			entry.queue_free()
	_entries.clear()
