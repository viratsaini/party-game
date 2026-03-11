## AnimatedResults - Premium animated scoreboard with smooth transitions
## Features row-by-row slide-in, stats bar fills, award badges, and screenshot mode
extends CanvasLayer

signal results_shown()
signal results_hidden()
signal screenshot_mode_toggled(enabled: bool)

# Configuration
@export var row_animation_delay: float = 0.1
@export var stats_fill_duration: float = 0.8
@export var badge_pop_delay: float = 0.15
@export var scroll_speed: float = 300.0

# Node references
var _root: Control
var _background: ColorRect
var _header_container: Control
var _title_label: Label
var _scoreboard_container: ScrollContainer
var _scoreboard_list: VBoxContainer
var _stats_panel: Control
var _awards_container: Control
var _personal_best_container: Control
var _screenshot_overlay: Control

# State
var _is_showing: bool = false
var _screenshot_mode: bool = false
var _entries: Array[Dictionary] = []
var _personal_bests: Array[String] = []
var _awards: Array[Dictionary] = []

# Colors
const PLACEMENT_COLORS := [
	Color(1.0, 0.84, 0.0),   # Gold
	Color(0.75, 0.75, 0.75), # Silver
	Color(0.8, 0.5, 0.2),    # Bronze
]

const ACCENT_COLOR := Color(0.3, 0.6, 1.0)
const PERSONAL_BEST_COLOR := Color(0.2, 0.9, 0.4)
const BACKGROUND_COLOR := Color(0.08, 0.1, 0.14)


func _ready() -> void:
	layer = 85
	_build_ui()
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Toggle screenshot mode
	if event.is_action_pressed("screenshot") or (event is InputEventKey and event.keycode == KEY_F12 and event.pressed):
		toggle_screenshot_mode()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "ResultsRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Background
	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.color = BACKGROUND_COLOR
	_root.add_child(_background)

	# Header
	_build_header()

	# Main scoreboard
	_build_scoreboard()

	# Stats panel
	_build_stats_panel()

	# Awards section
	_build_awards_section()

	# Personal best indicators
	_build_personal_bests()

	# Screenshot mode overlay
	_build_screenshot_overlay()


func _build_header() -> void:
	_header_container = Control.new()
	_header_container.name = "HeaderContainer"
	_header_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header_container.custom_minimum_size = Vector2(0, 100)
	_root.add_child(_header_container)

	_title_label = Label.new()
	_title_label.text = "MATCH RESULTS"
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.set_anchors_preset(Control.PRESET_CENTER)
	_title_label.position = Vector2(-200, 25)
	_title_label.size = Vector2(400, 60)
	_header_container.add_child(_title_label)


func _build_scoreboard() -> void:
	_scoreboard_container = ScrollContainer.new()
	_scoreboard_container.name = "ScoreboardContainer"
	_scoreboard_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scoreboard_container.offset_top = 120
	_scoreboard_container.offset_bottom = -200
	_scoreboard_container.offset_left = 50
	_scoreboard_container.offset_right = -350
	_root.add_child(_scoreboard_container)

	_scoreboard_list = VBoxContainer.new()
	_scoreboard_list.name = "ScoreboardList"
	_scoreboard_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scoreboard_list.add_theme_constant_override("separation", 8)
	_scoreboard_container.add_child(_scoreboard_list)


func _build_stats_panel() -> void:
	_stats_panel = Control.new()
	_stats_panel.name = "StatsPanel"
	_stats_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_stats_panel.offset_left = -320
	_stats_panel.offset_top = 120
	_stats_panel.offset_bottom = -200
	_stats_panel.offset_right = -30
	_root.add_child(_stats_panel)

	# Panel background
	var panel_bg := ColorRect.new()
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.color = Color(0.12, 0.14, 0.18)
	_stats_panel.add_child(panel_bg)

	# Header
	var header := Label.new()
	header.text = "MATCH STATS"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", ACCENT_COLOR)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 15)
	header.size = Vector2(290, 30)
	_stats_panel.add_child(header)


func _build_awards_section() -> void:
	_awards_container = Control.new()
	_awards_container.name = "AwardsContainer"
	_awards_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_awards_container.offset_top = -180
	_awards_container.offset_bottom = -20
	_awards_container.offset_left = 50
	_awards_container.offset_right = -50
	_root.add_child(_awards_container)

	# Title
	var title := Label.new()
	title.text = "MATCH AWARDS"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	title.position = Vector2(0, 0)
	title.size = Vector2(200, 25)
	_awards_container.add_child(title)


func _build_personal_bests() -> void:
	_personal_best_container = Control.new()
	_personal_best_container.name = "PersonalBestContainer"
	_personal_best_container.visible = false
	_root.add_child(_personal_best_container)


func _build_screenshot_overlay() -> void:
	_screenshot_overlay = Control.new()
	_screenshot_overlay.name = "ScreenshotOverlay"
	_screenshot_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screenshot_overlay.visible = false
	_screenshot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_screenshot_overlay)

	var hint := Label.new()
	hint.text = "Screenshot Mode - Press F12 to exit"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position = Vector2(0, -30)
	hint.size = Vector2(0, 25)
	_screenshot_overlay.add_child(hint)


# ============================================================================
# PUBLIC API
# ============================================================================

## Show results with player data
func show_results(players: Array[Dictionary], stats: Dictionary = {}, awards: Array[Dictionary] = [], personal_bests: Array[String] = []) -> void:
	_entries = players
	_awards = awards
	_personal_bests = personal_bests

	visible = true
	_is_showing = true
	_root.modulate.a = 0.0

	# Fade in
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.3)
	await tween.finished

	# Animate header
	await _animate_header()

	# Populate and animate scoreboard
	await _animate_scoreboard()

	# Show stats panel
	await _animate_stats(stats)

	# Show awards
	await _animate_awards()

	results_shown.emit()


## Hide results
func hide_results() -> void:
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.3)
	await tween.finished

	visible = false
	_is_showing = false
	_clear_scoreboard()

	results_hidden.emit()


## Toggle screenshot mode (hides UI chrome)
func toggle_screenshot_mode() -> void:
	_screenshot_mode = not _screenshot_mode
	_screenshot_overlay.visible = _screenshot_mode

	var elements := [_header_container, _stats_panel, _awards_container]

	if _screenshot_mode:
		# Fade out UI elements
		for element in elements:
			var tween := create_tween()
			tween.tween_property(element, "modulate:a", 0.0, 0.2)
	else:
		# Fade in UI elements
		for element in elements:
			var tween := create_tween()
			tween.tween_property(element, "modulate:a", 1.0, 0.2)

	screenshot_mode_toggled.emit(_screenshot_mode)


# ============================================================================
# ANIMATIONS
# ============================================================================

func _animate_header() -> void:
	_title_label.position.y = -50
	_title_label.modulate.a = 0.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_title_label, "position:y", 25.0, 0.4)
	tween.parallel().tween_property(_title_label, "modulate:a", 1.0, 0.3)

	await tween.finished


func _animate_scoreboard() -> void:
	_clear_scoreboard()

	var screen_width := get_viewport().get_visible_rect().size.x

	for i in range(_entries.size()):
		var entry := _entries[i]
		var row := _create_scoreboard_row(i, entry)
		_scoreboard_list.add_child(row)

		# Start off-screen
		row.position.x = -screen_width
		row.modulate.a = 0.0

		# Slide in with delay
		var delay := i * row_animation_delay
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(row, "position:x", 0.0, 0.4).set_delay(delay)
		tween.parallel().tween_property(row, "modulate:a", 1.0, 0.3).set_delay(delay)

		# Check for personal best
		var player_name: String = entry.get("name", "")
		if player_name in _personal_bests:
			_add_personal_best_glow(row, delay + 0.4)

	await get_tree().create_timer(_entries.size() * row_animation_delay + 0.5).timeout


func _create_scoreboard_row(index: int, data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)

	# Color based on placement
	if index < PLACEMENT_COLORS.size():
		style.bg_color = PLACEMENT_COLORS[index].darkened(0.7)
		style.border_color = PLACEMENT_COLORS[index]
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.12, 0.14, 0.18)

	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)

	# Rank
	var rank_label := Label.new()
	rank_label.text = "#%d" % (index + 1)
	rank_label.custom_minimum_size = Vector2(50, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 28)
	if index < PLACEMENT_COLORS.size():
		rank_label.add_theme_color_override("font_color", PLACEMENT_COLORS[index])
	hbox.add_child(rank_label)

	# Player name
	var name_label := Label.new()
	name_label.text = data.get("name", "Player")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(name_label)

	# Stats columns
	var kills_label := _create_stat_column("K", data.get("kills", 0))
	var deaths_label := _create_stat_column("D", data.get("deaths", 0))
	var assists_label := _create_stat_column("A", data.get("assists", 0))
	hbox.add_child(kills_label)
	hbox.add_child(deaths_label)
	hbox.add_child(assists_label)

	# Score
	var score_label := Label.new()
	score_label.text = str(data.get("score", 0))
	score_label.custom_minimum_size = Vector2(80, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_color_override("font_color", ACCENT_COLOR)
	hbox.add_child(score_label)

	panel.add_child(hbox)
	return panel


func _create_stat_column(label_text: String, value: int) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(40, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.add_theme_font_size_override("font_size", 20)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(value_label)

	return vbox


func _add_personal_best_glow(row: Control, delay: float) -> void:
	# Add glowing border effect
	var glow := ColorRect.new()
	glow.name = "PersonalBestGlow"
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var glow_shader := Shader.new()
	glow_shader.code = """
	shader_type canvas_item;
	uniform vec4 glow_color : source_color = vec4(0.2, 0.9, 0.4, 1.0);
	uniform float pulse : hint_range(0.0, 1.0) = 0.0;

	void fragment() {
		vec2 uv = UV;
		float border = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
		float glow = smoothstep(0.0, 0.1, border) * (1.0 - smoothstep(0.1, 0.15, border));
		glow *= 0.5 + pulse * 0.5;
		COLOR = vec4(glow_color.rgb, glow * glow_color.a);
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = glow_shader
	mat.set_shader_parameter("glow_color", PERSONAL_BEST_COLOR)
	glow.material = mat
	glow.modulate.a = 0.0

	row.add_child(glow)

	# Animate glow appearance
	var tween := create_tween()
	tween.tween_property(glow, "modulate:a", 1.0, 0.3).set_delay(delay)

	# Pulsing animation
	var pulse_tween := create_tween().set_loops()
	pulse_tween.tween_method(
		func(v: float): mat.set_shader_parameter("pulse", v),
		0.0, 1.0, 1.0
	).set_delay(delay)
	pulse_tween.tween_method(
		func(v: float): mat.set_shader_parameter("pulse", v),
		1.0, 0.0, 1.0
	)

	# Add "NEW PB" badge
	var badge := Label.new()
	badge.text = "PB!"
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", PERSONAL_BEST_COLOR)
	badge.position = Vector2(-30, 5)
	badge.modulate.a = 0.0

	row.add_child(badge)

	var badge_tween := create_tween()
	badge_tween.tween_property(badge, "modulate:a", 1.0, 0.2).set_delay(delay + 0.2)


func _animate_stats(stats: Dictionary) -> void:
	# Clear previous stats
	for child in _stats_panel.get_children():
		if child is ColorRect or child.name == "":
			continue
		if child is Label and child.position.y > 30:
			child.queue_free()

	var stat_entries := [
		{"name": "Total Kills", "key": "total_kills", "max": 100},
		{"name": "Total Deaths", "key": "total_deaths", "max": 100},
		{"name": "Damage Dealt", "key": "damage_dealt", "max": 10000},
		{"name": "Headshots", "key": "headshots", "max": 50},
		{"name": "Accuracy", "key": "accuracy", "max": 100, "suffix": "%"},
		{"name": "Match Duration", "key": "duration", "format": "time"},
	]

	var y_offset := 60.0

	for i in range(stat_entries.size()):
		var entry := stat_entries[i]
		var value = stats.get(entry.key, 0)

		var row := _create_stats_row(entry, value)
		row.position = Vector2(15, y_offset)
		row.modulate.a = 0.0
		_stats_panel.add_child(row)

		# Animate row appearance
		var delay := i * 0.1
		var tween := create_tween()
		tween.tween_property(row, "modulate:a", 1.0, 0.3).set_delay(delay)

		# Animate stat bar if applicable
		if entry.has("max"):
			var bar: ColorRect = row.get_node_or_null("StatBar")
			if bar:
				var target_width := (float(value) / entry.max) * 250.0
				bar.size.x = 0
				tween.tween_property(bar, "size:x", target_width, stats_fill_duration).set_delay(delay + 0.2)

		y_offset += 50.0

	await get_tree().create_timer(stat_entries.size() * 0.1 + stats_fill_duration).timeout


func _create_stats_row(entry: Dictionary, value) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(260, 45)

	# Label
	var label := Label.new()
	label.text = entry.name
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	label.size = Vector2(150, 20)
	container.add_child(label)

	# Value
	var value_label := Label.new()
	if entry.has("format") and entry.format == "time":
		var minutes := int(value) / 60
		var seconds := int(value) % 60
		value_label.text = "%d:%02d" % [minutes, seconds]
	else:
		value_label.text = str(value) + entry.get("suffix", "")

	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.position = Vector2(150, 0)
	value_label.size = Vector2(100, 20)
	container.add_child(value_label)

	# Bar (if applicable)
	if entry.has("max"):
		var bar_bg := ColorRect.new()
		bar_bg.size = Vector2(250, 8)
		bar_bg.position = Vector2(0, 25)
		bar_bg.color = Color(0.2, 0.2, 0.25)
		container.add_child(bar_bg)

		var bar := ColorRect.new()
		bar.name = "StatBar"
		bar.size = Vector2(0, 8)
		bar.position = Vector2(0, 25)
		bar.color = ACCENT_COLOR
		container.add_child(bar)

	return container


func _animate_awards() -> void:
	if _awards.is_empty():
		return

	# Clear previous awards
	for child in _awards_container.get_children():
		if child is Label and child.position.y == 0:
			continue
		child.queue_free()

	var x_offset := 0.0

	for i in range(_awards.size()):
		var award := _awards[i]
		var badge := _create_award_badge(award)
		badge.position = Vector2(x_offset, 35)
		badge.scale = Vector2(0.3, 0.3)
		badge.modulate.a = 0.0
		badge.pivot_offset = badge.custom_minimum_size / 2.0
		_awards_container.add_child(badge)

		# Pop animation
		var delay := i * badge_pop_delay
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(badge, "scale", Vector2(1.0, 1.0), 0.5).set_delay(delay)
		tween.parallel().tween_property(badge, "modulate:a", 1.0, 0.2).set_delay(delay)

		x_offset += 130.0

	await get_tree().create_timer(_awards.size() * badge_pop_delay + 0.5).timeout


func _create_award_badge(award: Dictionary) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(120, 120)

	# Badge background
	var bg := ColorRect.new()
	bg.size = Vector2(100, 100)
	bg.position = Vector2(10, 0)
	bg.color = Color(0.15, 0.15, 0.2)
	container.add_child(bg)

	# Award icon (represented as colored rect)
	var icon := ColorRect.new()
	icon.size = Vector2(50, 50)
	icon.position = Vector2(35, 10)
	icon.color = award.get("color", ACCENT_COLOR)
	container.add_child(icon)

	# Award name
	var name_label := Label.new()
	name_label.text = award.get("name", "Award")
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(100, 20)
	name_label.position = Vector2(10, 65)
	container.add_child(name_label)

	# Player name
	var player_label := Label.new()
	player_label.text = award.get("player", "")
	player_label.add_theme_font_size_override("font_size", 10)
	player_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.size = Vector2(100, 18)
	player_label.position = Vector2(10, 82)
	container.add_child(player_label)

	return container


func _clear_scoreboard() -> void:
	for child in _scoreboard_list.get_children():
		child.queue_free()


# ============================================================================
# UTILITY
# ============================================================================

## Scroll scoreboard smoothly
func scroll_to_player(player_name: String) -> void:
	for i in range(_scoreboard_list.get_child_count()):
		var row := _scoreboard_list.get_child(i)
		# Find player row and scroll to it
		# Implementation depends on row structure


## Add entry dynamically (for live updates)
func add_entry(data: Dictionary) -> void:
	_entries.append(data)
	var row := _create_scoreboard_row(_entries.size() - 1, data)
	row.modulate.a = 0.0
	_scoreboard_list.add_child(row)

	var tween := create_tween()
	tween.tween_property(row, "modulate:a", 1.0, 0.3)


## Update entry (for live score updates)
func update_entry(index: int, data: Dictionary) -> void:
	if index < 0 or index >= _scoreboard_list.get_child_count():
		return

	_entries[index] = data
	var old_row := _scoreboard_list.get_child(index)
	var new_row := _create_scoreboard_row(index, data)

	_scoreboard_list.remove_child(old_row)
	_scoreboard_list.add_child(new_row)
	_scoreboard_list.move_child(new_row, index)
	old_row.queue_free()

	# Highlight the update
	new_row.modulate = Color(1.2, 1.2, 1.2)
	var tween := create_tween()
	tween.tween_property(new_row, "modulate", Color.WHITE, 0.5)
