## VictoryScreen - Premium victory/defeat screen with confetti, podium, and MVP showcase
## Displays match results with dramatic animations and particle effects
extends CanvasLayer

signal screen_shown()
signal screen_hidden()
signal continue_pressed()

enum ScreenType {
	VICTORY,
	DEFEAT,
	DRAW
}

# Configuration
@export var confetti_count: int = 100
@export var firework_count: int = 5
@export var stats_count_duration: float = 1.5
@export var xp_animation_duration: float = 2.0

# Node references
var _root: Control
var _background: ColorRect
var _title_label: Label
var _subtitle_label: Label
var _podium_container: Control
var _podium_spots: Array[Control] = []
var _mvp_container: Control
var _mvp_portrait: Control
var _mvp_name_label: Label
var _mvp_stats_label: Label
var _stats_container: Control
var _xp_container: Control
var _xp_bar: Control
var _xp_label: Label
var _particle_container: Control
var _continue_button: Button

# State
var _screen_type: ScreenType = ScreenType.VICTORY
var _is_showing: bool = false
var _players: Array[Dictionary] = []
var _mvp_data: Dictionary = {}

# Colors
const VICTORY_COLOR := Color(1.0, 0.85, 0.2)  # Gold
const DEFEAT_COLOR := Color(0.4, 0.4, 0.5)    # Desaturated
const DRAW_COLOR := Color(0.6, 0.6, 0.7)      # Silver

const PLACEMENT_COLORS := [
	Color(1.0, 0.84, 0.0),   # 1st - Gold
	Color(0.75, 0.75, 0.75), # 2nd - Silver
	Color(0.8, 0.5, 0.2),    # 3rd - Bronze
]

# Desaturation shader
const DESATURATE_SHADER := """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = texture(SCREEN_TEXTURE, UV);

	// Desaturation
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(vec3(gray), col.rgb, saturation);

	// Brightness
	col.rgb *= brightness;

	// Vignette
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	col.rgb *= 1.0 - (smoothstep(0.5, 1.5, dist) * vignette);

	COLOR = col;
}
"""


func _ready() -> void:
	layer = 95
	_build_ui()
	visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "VictoryRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Background with optional shader
	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0, 0, 0, 0.85)
	_root.add_child(_background)

	# Particle container
	_particle_container = Control.new()
	_particle_container.name = "ParticleContainer"
	_particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_particle_container)

	# Title
	_build_title()

	# Podium
	_build_podium()

	# MVP showcase
	_build_mvp_showcase()

	# Stats display
	_build_stats_display()

	# XP bar
	_build_xp_bar()

	# Continue button
	_build_continue_button()


func _build_title() -> void:
	_title_label = Label.new()
	_title_label.text = "VICTORY"
	_title_label.add_theme_font_size_override("font_size", 96)
	_title_label.add_theme_color_override("font_color", VICTORY_COLOR)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.position = Vector2(-300, 50)
	_title_label.size = Vector2(600, 120)
	_title_label.pivot_offset = Vector2(300, 60)
	_root.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Your team won the match!"
	_subtitle_label.add_theme_font_size_override("font_size", 24)
	_subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_subtitle_label.position = Vector2(-300, 160)
	_subtitle_label.size = Vector2(600, 40)
	_root.add_child(_subtitle_label)


func _build_podium() -> void:
	_podium_container = Control.new()
	_podium_container.name = "PodiumContainer"
	_podium_container.set_anchors_preset(Control.PRESET_CENTER)
	_podium_container.position = Vector2(-300, -100)
	_podium_container.custom_minimum_size = Vector2(600, 300)
	_root.add_child(_podium_container)

	# Create 3 podium spots (1st in center, 2nd left, 3rd right)
	var podium_positions := [
		Vector2(250, 50),   # 1st place (center, higher)
		Vector2(50, 100),   # 2nd place (left)
		Vector2(450, 130),  # 3rd place (right)
	]

	var podium_sizes := [
		Vector2(100, 150),  # 1st
		Vector2(90, 120),   # 2nd
		Vector2(80, 100),   # 3rd
	]

	for i in range(3):
		var spot := Control.new()
		spot.name = "PodiumSpot%d" % (i + 1)
		spot.position = podium_positions[i]
		spot.custom_minimum_size = podium_sizes[i]
		_podium_container.add_child(spot)
		_podium_spots.append(spot)

		# Podium base
		var base := ColorRect.new()
		base.size = Vector2(podium_sizes[i].x, 40)
		base.position = Vector2(0, podium_sizes[i].y - 40)
		base.color = PLACEMENT_COLORS[i].darkened(0.5)
		spot.add_child(base)

		# Rank number
		var rank_label := Label.new()
		rank_label.text = str(i + 1)
		rank_label.add_theme_font_size_override("font_size", 24)
		rank_label.add_theme_color_override("font_color", PLACEMENT_COLORS[i])
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.size = Vector2(podium_sizes[i].x, 30)
		rank_label.position = Vector2(0, podium_sizes[i].y - 35)
		spot.add_child(rank_label)

		# Player representation (will be filled in)
		var player_rect := ColorRect.new()
		player_rect.name = "PlayerRect"
		player_rect.size = Vector2(60, 80)
		player_rect.position = Vector2((podium_sizes[i].x - 60) / 2, podium_sizes[i].y - 130)
		player_rect.color = PLACEMENT_COLORS[i]
		player_rect.visible = false
		spot.add_child(player_rect)

		# Player name
		var name_label := Label.new()
		name_label.name = "NameLabel"
		name_label.text = ""
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size = Vector2(podium_sizes[i].x + 40, 25)
		name_label.position = Vector2(-20, podium_sizes[i].y - 150)
		spot.add_child(name_label)

		# Score
		var score_label := Label.new()
		score_label.name = "ScoreLabel"
		score_label.text = ""
		score_label.add_theme_font_size_override("font_size", 14)
		score_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.size = Vector2(podium_sizes[i].x, 20)
		score_label.position = Vector2(0, podium_sizes[i].y + 5)
		spot.add_child(score_label)

		# Spotlight effect for 1st place
		if i == 0:
			var spotlight := ColorRect.new()
			spotlight.name = "Spotlight"
			spotlight.size = Vector2(200, 300)
			spotlight.position = Vector2(-50, -150)

			var spotlight_shader := Shader.new()
			spotlight_shader.code = """
			shader_type canvas_item;
			uniform vec4 color : source_color = vec4(1.0, 0.9, 0.5, 0.3);
			uniform float pulse : hint_range(0.0, 1.0) = 0.0;

			void fragment() {
				vec2 uv = UV - vec2(0.5, 0.0);
				float cone = 1.0 - smoothstep(0.0, 0.5, abs(uv.x) / (UV.y + 0.1));
				float fade = 1.0 - UV.y;
				float alpha = cone * fade * (0.3 + pulse * 0.2);
				COLOR = vec4(color.rgb, alpha);
			}
			"""
			var mat := ShaderMaterial.new()
			mat.shader = spotlight_shader
			mat.set_shader_parameter("color", Color(1.0, 0.9, 0.5, 0.5))
			spotlight.material = mat
			spot.add_child(spotlight)
			spot.move_child(spotlight, 0)


func _build_mvp_showcase() -> void:
	_mvp_container = Control.new()
	_mvp_container.name = "MVPContainer"
	_mvp_container.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_mvp_container.position = Vector2(-280, -100)
	_mvp_container.custom_minimum_size = Vector2(250, 200)
	_mvp_container.visible = false
	_root.add_child(_mvp_container)

	# MVP badge
	var badge := Label.new()
	badge.text = "MVP"
	badge.add_theme_font_size_override("font_size", 32)
	badge.add_theme_color_override("font_color", VICTORY_COLOR)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.size = Vector2(250, 45)
	_mvp_container.add_child(badge)

	# Portrait frame
	_mvp_portrait = ColorRect.new()
	_mvp_portrait.size = Vector2(100, 100)
	_mvp_portrait.position = Vector2(75, 50)
	_mvp_portrait.color = VICTORY_COLOR
	_mvp_container.add_child(_mvp_portrait)

	# Name
	_mvp_name_label = Label.new()
	_mvp_name_label.text = "Player Name"
	_mvp_name_label.add_theme_font_size_override("font_size", 20)
	_mvp_name_label.add_theme_color_override("font_color", Color.WHITE)
	_mvp_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mvp_name_label.size = Vector2(250, 30)
	_mvp_name_label.position = Vector2(0, 160)
	_mvp_container.add_child(_mvp_name_label)

	# Stats
	_mvp_stats_label = Label.new()
	_mvp_stats_label.text = "15 Kills | 3 Deaths"
	_mvp_stats_label.add_theme_font_size_override("font_size", 14)
	_mvp_stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_mvp_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mvp_stats_label.size = Vector2(250, 25)
	_mvp_stats_label.position = Vector2(0, 185)
	_mvp_container.add_child(_mvp_stats_label)


func _build_stats_display() -> void:
	_stats_container = Control.new()
	_stats_container.name = "StatsContainer"
	_stats_container.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_stats_container.position = Vector2(30, -80)
	_stats_container.custom_minimum_size = Vector2(200, 160)
	_stats_container.visible = false
	_root.add_child(_stats_container)

	# Stats header
	var header := Label.new()
	header.text = "YOUR STATS"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	header.size = Vector2(200, 25)
	_stats_container.add_child(header)


func _build_xp_bar() -> void:
	_xp_container = Control.new()
	_xp_container.name = "XPContainer"
	_xp_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_xp_container.position = Vector2(0, -200)
	_xp_container.custom_minimum_size = Vector2(0, 80)
	_xp_container.visible = false
	_root.add_child(_xp_container)

	# XP label
	_xp_label = Label.new()
	_xp_label.text = "Level 5 - 450 / 1000 XP"
	_xp_label.add_theme_font_size_override("font_size", 16)
	_xp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_xp_label.position = Vector2(-200, 0)
	_xp_label.size = Vector2(400, 25)
	_xp_container.add_child(_xp_label)

	# XP bar background
	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(500, 20)
	bar_bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar_bg.position = Vector2(-250, 30)
	bar_bg.color = Color(0.15, 0.15, 0.2)
	_xp_container.add_child(bar_bg)

	# XP bar fill
	_xp_bar = ColorRect.new()
	_xp_bar.size = Vector2(0, 20)
	_xp_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_xp_bar.position = Vector2(-250, 30)
	_xp_bar.color = Color(0.3, 0.6, 1.0)
	_xp_container.add_child(_xp_bar)


func _build_continue_button() -> void:
	_continue_button = Button.new()
	_continue_button.text = "CONTINUE"
	_continue_button.custom_minimum_size = Vector2(200, 50)
	_continue_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_continue_button.position = Vector2(-100, -50)
	_continue_button.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.9)
	style.set_corner_radius_all(8)
	_continue_button.add_theme_stylebox_override("normal", style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.6, 1.0)
	hover_style.set_corner_radius_all(8)
	_continue_button.add_theme_stylebox_override("hover", hover_style)

	_continue_button.pressed.connect(_on_continue_pressed)
	_root.add_child(_continue_button)


# ============================================================================
# PUBLIC API
# ============================================================================

## Show victory screen
func show_victory(players: Array[Dictionary], mvp: Dictionary = {}, subtitle: String = "Your team won!") -> void:
	_screen_type = ScreenType.VICTORY
	_players = players
	_mvp_data = mvp

	_title_label.text = "VICTORY"
	_title_label.add_theme_color_override("font_color", VICTORY_COLOR)
	_subtitle_label.text = subtitle

	await _show_screen()

	# Spawn confetti and fireworks
	_spawn_confetti()
	_spawn_fireworks()


## Show defeat screen
func show_defeat(players: Array[Dictionary], subtitle: String = "Better luck next time!") -> void:
	_screen_type = ScreenType.DEFEAT
	_players = players
	_mvp_data = {}

	_title_label.text = "DEFEAT"
	_title_label.add_theme_color_override("font_color", DEFEAT_COLOR)
	_subtitle_label.text = subtitle

	# Apply desaturation
	_apply_desaturation()

	await _show_screen()


## Show draw screen
func show_draw(players: Array[Dictionary], subtitle: String = "It's a tie!") -> void:
	_screen_type = ScreenType.DRAW
	_players = players
	_mvp_data = {}

	_title_label.text = "DRAW"
	_title_label.add_theme_color_override("font_color", DRAW_COLOR)
	_subtitle_label.text = subtitle

	await _show_screen()


## Hide the screen
func hide_screen_animated() -> void:
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.3)
	await tween.finished

	visible = false
	_is_showing = false
	screen_hidden.emit()


# ============================================================================
# ANIMATIONS
# ============================================================================

func _show_screen() -> void:
	visible = true
	_is_showing = true
	_root.modulate.a = 0.0

	# Reset positions for animations
	_title_label.scale = Vector2(0.5, 0.5)
	_title_label.modulate.a = 0.0

	# Fade in background
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.3)
	await tween.finished

	# Animate title
	await _animate_title()

	# Populate and animate podium
	await _animate_podium()

	# Show MVP if available
	if not _mvp_data.is_empty():
		await _animate_mvp()

	# Show stats
	await _animate_stats()

	# Show XP gain
	await _animate_xp_gain()

	# Show continue button
	_continue_button.visible = true
	_continue_button.modulate.a = 0.0
	tween = create_tween()
	tween.tween_property(_continue_button, "modulate:a", 1.0, 0.3)

	screen_shown.emit()


func _animate_title() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(_title_label, "scale", Vector2(1.0, 1.0), 0.5)
	tween.tween_property(_title_label, "modulate:a", 1.0, 0.3)

	await tween.finished

	# Screen shake for impact
	if has_node("/root/TransitionEffects"):
		get_node("/root/TransitionEffects").impact_shake()


func _animate_podium() -> void:
	_podium_container.visible = true

	# Fill podium data
	for i in range(mini(_players.size(), 3)):
		var spot := _podium_spots[i]
		var player := _players[i]

		var player_rect: ColorRect = spot.get_node("PlayerRect")
		var name_label: Label = spot.get_node("NameLabel")
		var score_label: Label = spot.get_node("ScoreLabel")

		player_rect.visible = true
		name_label.text = player.get("name", "Player %d" % (i + 1))
		score_label.text = "%d pts" % player.get("score", 0)

		# Animate each spot
		spot.modulate.a = 0.0
		spot.position.y += 50

		var delay := i * 0.2
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)

		tween.tween_property(spot, "modulate:a", 1.0, 0.3).set_delay(delay)
		tween.parallel().tween_property(spot, "position:y", spot.position.y - 50, 0.4).set_delay(delay)

	await get_tree().create_timer(0.8).timeout


func _animate_mvp() -> void:
	_mvp_container.visible = true
	_mvp_name_label.text = _mvp_data.get("name", "MVP")
	_mvp_stats_label.text = "%d Kills | %d Deaths" % [
		_mvp_data.get("kills", 0),
		_mvp_data.get("deaths", 0)
	]

	# Dramatic zoom in
	_mvp_container.scale = Vector2(0.5, 0.5)
	_mvp_container.modulate.a = 0.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(_mvp_container, "scale", Vector2(1.0, 1.0), 0.6)
	tween.parallel().tween_property(_mvp_container, "modulate:a", 1.0, 0.3)

	await tween.finished


func _animate_stats() -> void:
	_stats_container.visible = true

	# Clear previous stats
	for child in _stats_container.get_children():
		if child.name != "":
			continue
		child.queue_free()

	# Example stats (would come from actual game data)
	var stats := {
		"Kills": 10,
		"Deaths": 5,
		"Assists": 3,
		"Damage": 2500,
		"Accuracy": 65,
	}

	var y_offset := 30.0
	var delay := 0.0

	for stat_name in stats.keys():
		var row := HBoxContainer.new()
		row.position = Vector2(0, y_offset)
		row.custom_minimum_size = Vector2(200, 25)

		var label := Label.new()
		label.text = stat_name + ":"
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		label.custom_minimum_size = Vector2(100, 25)
		row.add_child(label)

		var value_label := Label.new()
		value_label.text = "0"
		value_label.add_theme_font_size_override("font_size", 14)
		value_label.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(value_label)

		_stats_container.add_child(row)

		# Animate count up
		var target_value: int = stats[stat_name]
		var suffix := "%" if stat_name == "Accuracy" else ""

		row.modulate.a = 0.0

		var tween := create_tween()
		tween.tween_property(row, "modulate:a", 1.0, 0.2).set_delay(delay)
		tween.tween_method(
			func(v: int): value_label.text = str(v) + suffix,
			0, target_value, stats_count_duration
		).set_delay(delay + 0.1)

		y_offset += 25.0
		delay += 0.1

	await get_tree().create_timer(delay + stats_count_duration).timeout


func _animate_xp_gain() -> void:
	_xp_container.visible = true

	# Example XP data
	var current_xp := 450
	var xp_gained := 150
	var xp_needed := 1000
	var level := 5

	_xp_label.text = "Level %d - %d / %d XP (+%d)" % [level, current_xp, xp_needed, xp_gained]

	# Animate XP bar fill
	var start_percent := float(current_xp) / xp_needed
	var end_percent := float(current_xp + xp_gained) / xp_needed

	_xp_bar.size.x = 500.0 * start_percent

	var tween := create_tween()
	tween.tween_property(_xp_bar, "size:x", 500.0 * end_percent, xp_animation_duration).set_ease(Tween.EASE_OUT)

	# Add glow effect during animation
	var original_color := _xp_bar.color
	tween.parallel().tween_property(_xp_bar, "color", Color(0.5, 0.8, 1.0), xp_animation_duration * 0.5)
	tween.tween_property(_xp_bar, "color", original_color, xp_animation_duration * 0.5)

	await tween.finished


func _apply_desaturation() -> void:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = DESATURATE_SHADER
	mat.shader = shader
	mat.set_shader_parameter("saturation", 0.3)
	mat.set_shader_parameter("brightness", 0.7)
	mat.set_shader_parameter("vignette", 0.5)
	_background.material = mat


# ============================================================================
# PARTICLE EFFECTS
# ============================================================================

func _spawn_confetti() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	var colors := [
		Color(1.0, 0.3, 0.3),
		Color(0.3, 1.0, 0.3),
		Color(0.3, 0.3, 1.0),
		Color(1.0, 1.0, 0.3),
		Color(1.0, 0.3, 1.0),
		Color(0.3, 1.0, 1.0),
		VICTORY_COLOR,
	]

	for i in range(confetti_count):
		var confetti := ColorRect.new()
		var width := randf_range(5, 15)
		var height := randf_range(10, 25)
		confetti.size = Vector2(width, height)
		confetti.position = Vector2(
			randf() * screen_size.x,
			-50 - randf() * 200
		)
		confetti.color = colors[randi() % colors.size()]
		confetti.pivot_offset = confetti.size / 2.0
		confetti.rotation = randf() * TAU

		_particle_container.add_child(confetti)

		# Animate falling
		var fall_duration := randf_range(3.0, 6.0)
		var horizontal_drift := randf_range(-100, 100)
		var target_y := screen_size.y + 50

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(confetti, "position:y", target_y, fall_duration)
		tween.tween_property(confetti, "position:x", confetti.position.x + horizontal_drift, fall_duration)
		tween.tween_property(confetti, "rotation", confetti.rotation + randf_range(-TAU * 2, TAU * 2), fall_duration)

		# Wobble effect
		var wobble_tween := create_tween().set_loops(int(fall_duration * 2))
		wobble_tween.tween_property(confetti, "rotation", confetti.rotation + 0.3, 0.25)
		wobble_tween.tween_property(confetti, "rotation", confetti.rotation - 0.3, 0.25)

		tween.chain().tween_callback(confetti.queue_free)


func _spawn_fireworks() -> void:
	for i in range(firework_count):
		await get_tree().create_timer(randf_range(0.3, 1.0)).timeout
		_spawn_single_firework()


func _spawn_single_firework() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	var burst_pos := Vector2(
		randf_range(100, screen_size.x - 100),
		randf_range(100, screen_size.y * 0.5)
	)

	var burst_color := Color(
		randf_range(0.5, 1.0),
		randf_range(0.5, 1.0),
		randf_range(0.5, 1.0)
	)

	# Create burst particles
	var particle_count := randi_range(20, 40)

	for i in range(particle_count):
		var particle := ColorRect.new()
		var size := randf_range(3, 8)
		particle.size = Vector2(size, size)
		particle.position = burst_pos
		particle.color = burst_color
		particle.pivot_offset = particle.size / 2.0

		_particle_container.add_child(particle)

		var angle := (TAU / particle_count) * i + randf_range(-0.2, 0.2)
		var distance := randf_range(80, 200)
		var target_pos := burst_pos + Vector2(cos(angle), sin(angle)) * distance

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_pos, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.tween_property(particle, "position:y", target_pos.y + 100, 1.0).set_delay(0.6)  # Gravity
		tween.tween_property(particle, "modulate:a", 0.0, 0.8).set_delay(0.4)
		tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 1.0)

		tween.chain().tween_callback(particle.queue_free)

	# Play sound
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").call("play_ui_sound", "firework")


func _on_continue_pressed() -> void:
	continue_pressed.emit()
	hide_screen_animated()
