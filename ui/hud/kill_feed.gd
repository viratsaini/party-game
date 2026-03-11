## Premium animated kill feed system with competitive game polish.
## Features elastic slide-in animations, weapon icons with glow, headshot indicators,
## multi-kill combo system, kill streak announcements, and smooth scrolling.
## Designed for PUBG/CoD/Apex Mobile quality standards.
class_name KillFeed
extends VBoxContainer

## Signal emitted when a kill streak milestone is reached.
signal kill_streak_milestone(streak_count: int, player_name: String)

## Signal emitted when a multi-kill occurs.
signal multi_kill_achieved(kill_count: int, player_name: String)

## Maximum number of visible entries at once.
const MAX_ENTRIES: int = 6
## How long an entry stays visible before fading.
const ENTRY_LIFETIME: float = 6.0
## Duration of fade-out animation.
const FADE_DURATION: float = 0.8
## Duration of slide-in animation.
const SLIDE_IN_DURATION: float = 0.35
## Horizontal slide distance for entry animation.
const SLIDE_DISTANCE: float = 120.0
## Time window for multi-kill detection.
const MULTI_KILL_WINDOW: float = 4.0

## Kill streak milestones.
const STREAK_MILESTONES: Array[int] = [3, 5, 7, 10, 15, 20, 25]

## Weapon icon textures (loaded dynamically or set via export).
var weapon_icons: Dictionary = {}

## Entry scene - we create entries programmatically.
var _entries: Array[Control] = []

## Kill tracking for multi-kills and streaks.
var _player_kill_times: Dictionary = {}  # player_name -> Array[float]
var _player_kill_streaks: Dictionary = {}  # player_name -> int

## Local player name for highlighting.
var local_player_name: String = ""

# ── Color Palette ────────────────────────────────────────────────────────────

## Background colors.
const BG_COLOR_NORMAL: Color = Color(0.0, 0.0, 0.0, 0.65)
const BG_COLOR_HEADSHOT: Color = Color(0.4, 0.25, 0.0, 0.7)
const BG_COLOR_MULTI_KILL: Color = Color(0.3, 0.0, 0.0, 0.75)
const BG_COLOR_LOCAL_KILL: Color = Color(0.0, 0.15, 0.3, 0.7)
const BG_COLOR_LOCAL_DEATH: Color = Color(0.3, 0.0, 0.0, 0.7)

## Text colors.
const TEXT_COLOR_KILLER: Color = Color(1.0, 1.0, 1.0, 1.0)
const TEXT_COLOR_VICTIM: Color = Color(0.85, 0.85, 0.85, 1.0)
const TEXT_COLOR_HEADSHOT: Color = Color(1.0, 0.85, 0.2, 1.0)
const TEXT_COLOR_LOCAL: Color = Color(0.4, 0.9, 1.0, 1.0)

## Icon colors.
const ICON_COLOR_NORMAL: Color = Color(1.0, 1.0, 1.0, 0.9)
const ICON_COLOR_HEADSHOT: Color = Color(1.0, 0.85, 0.2, 1.0)
const ICON_GLOW_COLOR: Color = Color(1.0, 0.6, 0.2, 0.5)

## Multi-kill colors.
const MULTI_KILL_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0),      # Double Kill.
	Color(1.0, 0.85, 0.2, 1.0),    # Triple Kill.
	Color(1.0, 0.5, 0.2, 1.0),     # Quad Kill.
	Color(1.0, 0.2, 0.2, 1.0),     # Penta Kill.
	Color(0.8, 0.2, 1.0, 1.0),     # Legendary.
]

## Streak announcement colors.
const STREAK_COLOR: Color = Color(1.0, 0.7, 0.2, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 5)

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
		"headshot": "res://assets/icons/headshot.png",
		"default": "res://assets/icons/weapon_default.png",
	}

	for weapon_id: String in icon_paths:
		var path: String = icon_paths[weapon_id]
		if ResourceLoader.exists(path):
			weapon_icons[weapon_id] = load(path) as Texture2D


## Add a kill entry to the feed.
func add_kill(
	killer_name: String,
	victim_name: String,
	weapon_id: String = "default",
	killer_color: Color = Color.WHITE,
	victim_color: Color = Color.WHITE,
	is_headshot: bool = false
) -> void:
	# Track kill for multi-kill and streak detection.
	var multi_kill_count: int = _track_kill(killer_name)
	var streak_count: int = _player_kill_streaks.get(killer_name, 0) as int

	# Create the entry with all info.
	var entry: Control = _create_premium_kill_entry(
		killer_name,
		victim_name,
		weapon_id,
		killer_color,
		victim_color,
		is_headshot,
		multi_kill_count,
		streak_count
	)

	add_child(entry)
	move_child(entry, 0)
	_entries.insert(0, entry)

	# Animate entry with elastic easing.
	_animate_entry_in_elastic(entry, is_headshot or multi_kill_count > 1)

	# Remove oldest entries if over limit.
	while _entries.size() > MAX_ENTRIES:
		var oldest: Control = _entries.pop_back()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Schedule fade-out.
	_schedule_fade_out(entry)

	# Check for kill streak announcement.
	if streak_count in STREAK_MILESTONES:
		_add_streak_announcement(killer_name, streak_count)
		kill_streak_milestone.emit(streak_count, killer_name)

	# Check for multi-kill announcement.
	if multi_kill_count >= 2:
		multi_kill_achieved.emit(multi_kill_count, killer_name)


## Add a generic event entry (not a kill, just text).
func add_event(text: String, color: Color = Color.WHITE, icon_text: String = "") -> void:
	var entry: Control = _create_event_entry(text, color, icon_text)
	add_child(entry)
	move_child(entry, 0)
	_entries.insert(0, entry)

	# Animate entry.
	_animate_entry_in_elastic(entry, false)

	# Remove oldest entries if over limit.
	while _entries.size() > MAX_ENTRIES:
		var oldest: Control = _entries.pop_back()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Schedule fade-out.
	_schedule_fade_out(entry)


## Track a kill and return multi-kill count.
func _track_kill(killer_name: String) -> int:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	# Initialize tracking arrays if needed.
	if not _player_kill_times.has(killer_name):
		_player_kill_times[killer_name] = []

	# Add current kill time.
	var kill_times: Array = _player_kill_times[killer_name] as Array
	kill_times.append(current_time)

	# Remove old kills outside the multi-kill window.
	var valid_kills: Array = []
	for kill_time in kill_times:
		if current_time - (kill_time as float) <= MULTI_KILL_WINDOW:
			valid_kills.append(kill_time)
	_player_kill_times[killer_name] = valid_kills

	# Update kill streak.
	if not _player_kill_streaks.has(killer_name):
		_player_kill_streaks[killer_name] = 0
	_player_kill_streaks[killer_name] = (_player_kill_streaks[killer_name] as int) + 1

	return valid_kills.size()


## Reset kill streak for a player (on death).
func reset_kill_streak(player_name: String) -> void:
	_player_kill_streaks[player_name] = 0
	_player_kill_times.erase(player_name)


## Create a premium kill entry with all effects.
func _create_premium_kill_entry(
	killer_name: String,
	victim_name: String,
	weapon_id: String,
	killer_color: Color,
	victim_color: Color,
	is_headshot: bool,
	multi_kill_count: int,
	_streak_count: int
) -> Control:
	var container: Control = Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.custom_minimum_size = Vector2(0, 36)

	# Determine background color.
	var bg_color: Color = BG_COLOR_NORMAL
	var is_local_kill: bool = killer_name == local_player_name
	var is_local_death: bool = victim_name == local_player_name

	if is_local_kill:
		bg_color = BG_COLOR_LOCAL_KILL
	elif is_local_death:
		bg_color = BG_COLOR_LOCAL_DEATH
	elif is_headshot:
		bg_color = BG_COLOR_HEADSHOT
	elif multi_kill_count >= 2:
		bg_color = BG_COLOR_MULTI_KILL

	# Background panel.
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6

	# Add border for special kills.
	if is_headshot or multi_kill_count >= 2 or is_local_kill:
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = TEXT_COLOR_HEADSHOT if is_headshot else (TEXT_COLOR_LOCAL if is_local_kill else MULTI_KILL_COLORS[mini(multi_kill_count - 2, 4)])

	panel.add_theme_stylebox_override("panel", style)

	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Killer name.
	var killer_label: Label = Label.new()
	killer_label.text = killer_name
	var final_killer_color: Color = TEXT_COLOR_LOCAL if is_local_kill else killer_color
	killer_label.add_theme_color_override("font_color", final_killer_color)
	killer_label.add_theme_font_size_override("font_size", 16)
	killer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	killer_label.add_theme_constant_override("shadow_offset_x", 1)
	killer_label.add_theme_constant_override("shadow_offset_y", 1)
	content.add_child(killer_label)

	# Headshot icon (if applicable).
	if is_headshot:
		var headshot_label: Label = Label.new()
		headshot_label.text = "[HS]"
		headshot_label.add_theme_color_override("font_color", TEXT_COLOR_HEADSHOT)
		headshot_label.add_theme_font_size_override("font_size", 12)
		content.add_child(headshot_label)

	# Weapon icon.
	var icon_container: Control = Control.new()
	icon_container.custom_minimum_size = Vector2(28, 24)
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if weapon_icons.has(weapon_id):
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = weapon_icons[weapon_id]
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.modulate = ICON_COLOR_HEADSHOT if is_headshot else ICON_COLOR_NORMAL
		icon_container.add_child(icon_rect)
	elif weapon_icons.has("default"):
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = weapon_icons["default"]
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(icon_rect)
	else:
		var arrow_label: Label = Label.new()
		arrow_label.text = ">"
		arrow_label.add_theme_color_override("font_color", ICON_COLOR_HEADSHOT if is_headshot else Color.WHITE)
		arrow_label.add_theme_font_size_override("font_size", 18)
		icon_container.add_child(arrow_label)

	content.add_child(icon_container)

	# Victim name.
	var victim_label: Label = Label.new()
	victim_label.text = victim_name
	var final_victim_color: Color = TEXT_COLOR_LOCAL if is_local_death else victim_color
	victim_label.add_theme_color_override("font_color", final_victim_color)
	victim_label.add_theme_font_size_override("font_size", 16)
	victim_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	victim_label.add_theme_constant_override("shadow_offset_x", 1)
	victim_label.add_theme_constant_override("shadow_offset_y", 1)
	content.add_child(victim_label)

	# Multi-kill indicator.
	if multi_kill_count >= 2:
		var multi_label: Label = Label.new()
		multi_label.text = _get_multi_kill_text(multi_kill_count)
		var multi_color: Color = MULTI_KILL_COLORS[mini(multi_kill_count - 2, 4)]
		multi_label.add_theme_color_override("font_color", multi_color)
		multi_label.add_theme_font_size_override("font_size", 14)
		content.add_child(multi_label)

	panel.add_child(content)
	container.add_child(panel)

	return container


## Create a simple event entry (text only).
func _create_event_entry(text: String, color: Color, icon_text: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG_COLOR_NORMAL
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Optional icon.
	if icon_text != "":
		var icon_label: Label = Label.new()
		icon_label.text = icon_text
		icon_label.add_theme_color_override("font_color", color)
		icon_label.add_theme_font_size_override("font_size", 16)
		content.add_child(icon_label)

	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	content.add_child(label)

	panel.add_child(content)
	return panel


## Add a kill streak announcement.
func _add_streak_announcement(player_name: String, streak_count: int) -> void:
	var streak_text: String = _get_streak_text(streak_count)
	var announcement_text: String = "%s: %s (%d KILLS)" % [player_name, streak_text, streak_count]

	var entry: Control = _create_streak_announcement_entry(announcement_text)
	add_child(entry)
	move_child(entry, 0)
	_entries.insert(0, entry)

	# Dramatic animation for streak.
	_animate_streak_announcement(entry)

	# Remove oldest entries if over limit.
	while _entries.size() > MAX_ENTRIES:
		var oldest: Control = _entries.pop_back()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Schedule fade-out (longer for streaks).
	var timer: SceneTreeTimer = get_tree().create_timer(ENTRY_LIFETIME + 2.0 - FADE_DURATION)
	timer.timeout.connect(_fade_out_entry.bind(entry))


## Create a streak announcement entry with special styling.
func _create_streak_announcement_entry(text: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.2, 0.0, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = STREAK_COLOR
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", STREAK_COLOR)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)

	return panel


## Animate entry with elastic slide-in.
func _animate_entry_in_elastic(entry: Control, is_special: bool) -> void:
	entry.modulate.a = 0.0
	entry.position.x = -SLIDE_DISTANCE

	var duration: float = SLIDE_IN_DURATION
	var trans: Tween.TransitionType = Tween.TRANS_BACK

	if is_special:
		duration *= 1.2
		trans = Tween.TRANS_ELASTIC

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(entry, "modulate:a", 1.0, duration * 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(entry, "position:x", 0.0, duration).set_trans(trans).set_ease(Tween.EASE_OUT)

	# Scale pop for special entries.
	if is_special:
		entry.pivot_offset = Vector2(entry.custom_minimum_size.x * 0.5 if entry.custom_minimum_size.x > 0 else 100, entry.custom_minimum_size.y * 0.5 if entry.custom_minimum_size.y > 0 else 18)
		entry.scale = Vector2(1.15, 1.15)
		tween.tween_property(entry, "scale", Vector2.ONE, duration * 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Animate streak announcement with dramatic effect.
func _animate_streak_announcement(entry: Control) -> void:
	entry.modulate.a = 0.0
	entry.position.x = -SLIDE_DISTANCE * 1.5
	entry.pivot_offset = Vector2(150, 18)
	entry.scale = Vector2(0.5, 0.5)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(entry, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(entry, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(entry, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Pulse effect after entry.
	tween.chain().tween_property(entry, "scale", Vector2(1.05, 1.05), 0.15)
	tween.tween_property(entry, "scale", Vector2.ONE, 0.15)


## Schedule an entry to fade out after ENTRY_LIFETIME.
func _schedule_fade_out(entry: Control) -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(ENTRY_LIFETIME - FADE_DURATION)
	timer.timeout.connect(_fade_out_entry.bind(entry))


## Fade out and remove an entry.
func _fade_out_entry(entry: Control) -> void:
	if not is_instance_valid(entry):
		return

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(entry, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_property(entry, "position:x", -SLIDE_DISTANCE * 0.5, FADE_DURATION).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(entry):
			_entries.erase(entry)
			entry.queue_free()
	)


## Get multi-kill display text.
func _get_multi_kill_text(count: int) -> String:
	match count:
		2:
			return "DOUBLE KILL"
		3:
			return "TRIPLE KILL"
		4:
			return "QUAD KILL"
		5:
			return "PENTA KILL"
		_:
			return "MULTI KILL x%d" % count


## Get streak display text.
func _get_streak_text(streak: int) -> String:
	if streak >= 25:
		return "GODLIKE"
	elif streak >= 20:
		return "UNSTOPPABLE"
	elif streak >= 15:
		return "LEGENDARY"
	elif streak >= 10:
		return "DOMINATING"
	elif streak >= 7:
		return "RAMPAGE"
	elif streak >= 5:
		return "KILLING SPREE"
	elif streak >= 3:
		return "ON FIRE"
	return "STREAK"


# ── Public API ───────────────────────────────────────────────────────────────

## Set the local player name for highlighting.
func set_local_player_name(player_name: String) -> void:
	local_player_name = player_name


## Get current kill streak for a player.
func get_kill_streak(player_name: String) -> int:
	return _player_kill_streaks.get(player_name, 0) as int


## Clear all entries.
func clear() -> void:
	for entry: Control in _entries:
		if is_instance_valid(entry):
			entry.queue_free()
	_entries.clear()


## Reset all kill tracking.
func reset_tracking() -> void:
	_player_kill_times.clear()
	_player_kill_streaks.clear()
