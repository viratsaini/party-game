## MatchCountdown - Dramatic 3-2-1-GO countdown with screen shake and particles
## Plays at match start with team names, map info, and synchronized effects
extends CanvasLayer

signal countdown_started()
signal countdown_tick(number: int)
signal countdown_complete()

# Configuration
@export var shake_intensity: float = 15.0
@export var particle_count: int = 30
@export var enable_sound_sync: bool = true
@export var show_team_names: bool = true
@export var show_map_name: bool = true

# Node references
var _root: Control
var _number_label: Label
var _go_label: Label
var _team_container: Control
var _team_red_label: Label
var _team_blue_label: Label
var _map_container: Control
var _map_name_label: Label
var _particle_container: Control
var _vs_label: Label

# State
var _is_counting: bool = false
var _current_number: int = 3

# Colors
const COUNTDOWN_COLORS := {
	3: Color(1.0, 0.3, 0.3),   # Red
	2: Color(1.0, 0.7, 0.2),   # Orange
	1: Color(1.0, 1.0, 0.3),   # Yellow
	0: Color(0.3, 1.0, 0.3),   # Green (GO)
}

const TEAM_RED_COLOR := Color(0.9, 0.2, 0.2)
const TEAM_BLUE_COLOR := Color(0.2, 0.4, 0.9)


func _ready() -> void:
	layer = 90
	_build_ui()
	visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "CountdownRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Semi-transparent overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(overlay)

	# Particle container (behind numbers)
	_particle_container = Control.new()
	_particle_container.name = "ParticleContainer"
	_particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_particle_container)

	# Main countdown number
	_number_label = Label.new()
	_number_label.name = "NumberLabel"
	_number_label.text = "3"
	_number_label.add_theme_font_size_override("font_size", 300)
	_number_label.add_theme_color_override("font_color", COUNTDOWN_COLORS[3])
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_label.set_anchors_preset(Control.PRESET_CENTER)
	_number_label.position = Vector2(-150, -180)
	_number_label.size = Vector2(300, 360)
	_number_label.pivot_offset = Vector2(150, 180)
	_number_label.visible = false
	_root.add_child(_number_label)

	# GO label (separate for different styling)
	_go_label = Label.new()
	_go_label.name = "GoLabel"
	_go_label.text = "GO!"
	_go_label.add_theme_font_size_override("font_size", 200)
	_go_label.add_theme_color_override("font_color", COUNTDOWN_COLORS[0])
	_go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_go_label.set_anchors_preset(Control.PRESET_CENTER)
	_go_label.position = Vector2(-200, -120)
	_go_label.size = Vector2(400, 240)
	_go_label.pivot_offset = Vector2(200, 120)
	_go_label.visible = false
	_root.add_child(_go_label)

	# Team names container
	_build_team_display()

	# Map name container
	_build_map_display()


func _build_team_display() -> void:
	_team_container = Control.new()
	_team_container.name = "TeamContainer"
	_team_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_team_container.custom_minimum_size = Vector2(0, 100)
	_team_container.position = Vector2(0, 80)
	_team_container.visible = false
	_root.add_child(_team_container)

	# Red team (left side)
	_team_red_label = Label.new()
	_team_red_label.text = "RED TEAM"
	_team_red_label.add_theme_font_size_override("font_size", 48)
	_team_red_label.add_theme_color_override("font_color", TEAM_RED_COLOR)
	_team_red_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_team_red_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_team_red_label.position = Vector2(-300, 0)  # Start off-screen
	_team_red_label.size = Vector2(400, 60)
	_team_container.add_child(_team_red_label)

	# VS label
	_vs_label = Label.new()
	_vs_label.text = "VS"
	_vs_label.add_theme_font_size_override("font_size", 36)
	_vs_label.add_theme_color_override("font_color", Color.WHITE)
	_vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_vs_label.position = Vector2(-40, 10)
	_vs_label.size = Vector2(80, 50)
	_vs_label.modulate.a = 0
	_team_container.add_child(_vs_label)

	# Blue team (right side)
	_team_blue_label = Label.new()
	_team_blue_label.text = "BLUE TEAM"
	_team_blue_label.add_theme_font_size_override("font_size", 48)
	_team_blue_label.add_theme_color_override("font_color", TEAM_BLUE_COLOR)
	_team_blue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_team_blue_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_team_blue_label.position = Vector2(0, 0)  # Start off-screen (will be positioned)
	_team_blue_label.size = Vector2(400, 60)
	_team_container.add_child(_team_blue_label)


func _build_map_display() -> void:
	_map_container = Control.new()
	_map_container.name = "MapContainer"
	_map_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_map_container.custom_minimum_size = Vector2(0, 80)
	_map_container.position = Vector2(0, -150)
	_map_container.visible = false
	_root.add_child(_map_container)

	_map_name_label = Label.new()
	_map_name_label.text = "ARENA MAP"
	_map_name_label.add_theme_font_size_override("font_size", 36)
	_map_name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_map_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_name_label.set_anchors_preset(Control.PRESET_CENTER)
	_map_name_label.position = Vector2(0, -100)  # Start below screen
	_map_name_label.size = Vector2(600, 50)
	_map_container.add_child(_map_name_label)


# ============================================================================
# PUBLIC API
# ============================================================================

## Start the countdown
func start_countdown(team_red_name: String = "RED TEAM", team_blue_name: String = "BLUE TEAM", map_name: String = "") -> void:
	if _is_counting:
		return

	_is_counting = true
	visible = true
	countdown_started.emit()

	# Set team names
	_team_red_label.text = team_red_name.to_upper()
	_team_blue_label.text = team_blue_name.to_upper()

	# Set map name
	if map_name.is_empty():
		show_map_name = false
	else:
		_map_name_label.text = map_name.to_upper()

	# Animate team names sliding in
	if show_team_names:
		await _animate_team_names_in()

	# Animate map name sliding in
	if show_map_name:
		await _animate_map_name_in()

	# Brief pause before countdown
	await get_tree().create_timer(0.3).timeout

	# Countdown sequence
	await _show_number(3)
	await _show_number(2)
	await _show_number(1)
	await _show_go()

	# Cleanup
	await get_tree().create_timer(0.3).timeout
	await _fade_out()

	_is_counting = false
	countdown_complete.emit()


## Start countdown for free-for-all (no teams)
func start_countdown_ffa(map_name: String = "") -> void:
	if _is_counting:
		return

	_is_counting = true
	visible = true
	show_team_names = false
	countdown_started.emit()

	if not map_name.is_empty():
		_map_name_label.text = map_name.to_upper()
		show_map_name = true
		await _animate_map_name_in()

	await get_tree().create_timer(0.3).timeout

	await _show_number(3)
	await _show_number(2)
	await _show_number(1)
	await _show_go()

	await get_tree().create_timer(0.3).timeout
	await _fade_out()

	_is_counting = false
	countdown_complete.emit()


# ============================================================================
# ANIMATIONS
# ============================================================================

func _animate_team_names_in() -> void:
	_team_container.visible = true
	var screen_width := get_viewport().get_visible_rect().size.x

	# Start positions (off screen)
	_team_red_label.position.x = -400
	_team_blue_label.position.x = screen_width

	# Target positions
	var red_target := 50.0
	var blue_target := screen_width - 450.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(_team_red_label, "position:x", red_target, 0.5)
	tween.tween_property(_team_blue_label, "position:x", blue_target, 0.5)
	tween.tween_property(_vs_label, "modulate:a", 1.0, 0.3).set_delay(0.3)

	await tween.finished


func _animate_map_name_in() -> void:
	_map_container.visible = true
	_map_name_label.position.y = 100  # Start below

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_map_name_label, "position:y", 0.0, 0.4)

	await tween.finished


func _show_number(num: int) -> void:
	_current_number = num
	countdown_tick.emit(num)

	_number_label.text = str(num)
	_number_label.add_theme_color_override("font_color", COUNTDOWN_COLORS[num])
	_number_label.visible = true
	_number_label.scale = Vector2(0.3, 0.3)
	_number_label.modulate.a = 0.0

	# Play sound
	if enable_sound_sync:
		_play_countdown_sound(num)

	# Scale in with overshoot
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(_number_label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(_number_label, "modulate:a", 1.0, 0.15)

	await tween.finished

	# Screen shake
	_trigger_screen_shake()

	# Spawn particles
	_spawn_number_particles(COUNTDOWN_COLORS[num])

	# Scale down and hold
	tween = create_tween()
	tween.tween_property(_number_label, "scale", Vector2(1.0, 1.0), 0.1)

	await tween.finished
	await get_tree().create_timer(0.5).timeout

	# Scale out
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_number_label, "scale", Vector2(0.5, 0.5), 0.15)
	tween.tween_property(_number_label, "modulate:a", 0.0, 0.15)

	await tween.finished
	_number_label.visible = false


func _show_go() -> void:
	countdown_tick.emit(0)

	_go_label.visible = true
	_go_label.scale = Vector2(0.2, 0.2)
	_go_label.modulate.a = 0.0
	_go_label.rotation = deg_to_rad(-10)

	# Play sound
	if enable_sound_sync:
		_play_go_sound()

	# Explosive scale in
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)

	tween.tween_property(_go_label, "scale", Vector2(1.3, 1.3), 0.4)
	tween.tween_property(_go_label, "modulate:a", 1.0, 0.1)
	tween.tween_property(_go_label, "rotation", 0.0, 0.3)

	# Heavy screen shake
	_trigger_go_shake()

	# Particle burst
	_spawn_go_particles()

	await tween.finished

	# Pulse effect
	tween = create_tween()
	tween.tween_property(_go_label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN_OUT)

	await tween.finished
	await get_tree().create_timer(0.3).timeout

	# Fade out
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_go_label, "scale", Vector2(2.0, 2.0), 0.3)
	tween.tween_property(_go_label, "modulate:a", 0.0, 0.3)

	await tween.finished
	_go_label.visible = false


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false
	_root.modulate.a = 1.0

	# Reset visibility
	_team_container.visible = false
	_map_container.visible = false


# ============================================================================
# EFFECTS
# ============================================================================

func _trigger_screen_shake() -> void:
	# Use TransitionEffects if available
	if has_node("/root/TransitionEffects"):
		var effects = get_node("/root/TransitionEffects")
		effects.shake_screen(shake_intensity, 0.15, 40.0)
	else:
		# Fallback: shake the root control
		var original_pos := _root.position
		var tween := create_tween()
		for i in range(5):
			var offset := Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
			tween.tween_property(_root, "position", original_pos + offset, 0.03)
		tween.tween_property(_root, "position", original_pos, 0.03)


func _trigger_go_shake() -> void:
	if has_node("/root/TransitionEffects"):
		var effects = get_node("/root/TransitionEffects")
		effects.explosion_shake()
	else:
		var original_pos := _root.position
		var tween := create_tween()
		for i in range(8):
			var intensity := shake_intensity * 1.5 * (1.0 - i / 8.0)
			var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
			tween.tween_property(_root, "position", original_pos + offset, 0.025)
		tween.tween_property(_root, "position", original_pos, 0.03)


func _spawn_number_particles(color: Color) -> void:
	var center := get_viewport().get_visible_rect().size / 2.0

	for i in range(particle_count):
		var particle := ColorRect.new()
		var size := randf_range(8, 20)
		particle.size = Vector2(size, size)
		particle.position = center
		particle.color = color
		particle.color.a = randf_range(0.6, 1.0)
		particle.pivot_offset = particle.size / 2.0
		particle.rotation = randf() * TAU

		_particle_container.add_child(particle)

		# Animate outward
		var angle := randf() * TAU
		var distance := randf_range(150, 400)
		var target_pos := center + Vector2(cos(angle), sin(angle)) * distance

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_pos, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.5)
		tween.tween_property(particle, "rotation", particle.rotation + randf_range(-PI, PI), 0.5)

		tween.chain().tween_callback(particle.queue_free)


func _spawn_go_particles() -> void:
	var center := get_viewport().get_visible_rect().size / 2.0
	var go_color := COUNTDOWN_COLORS[0]

	# More particles for GO
	for i in range(particle_count * 2):
		var particle := ColorRect.new()
		var size := randf_range(10, 30)
		particle.size = Vector2(size, size)
		particle.position = center
		particle.color = go_color
		particle.color.a = randf_range(0.7, 1.0)
		particle.pivot_offset = particle.size / 2.0

		_particle_container.add_child(particle)

		# Animate outward with more energy
		var angle := randf() * TAU
		var distance := randf_range(200, 600)
		var target_pos := center + Vector2(cos(angle), sin(angle)) * distance

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_pos, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.tween_property(particle, "modulate:a", 0.0, 0.6).set_delay(0.2)
		tween.tween_property(particle, "scale", Vector2(0.1, 0.1), 0.8)
		tween.tween_property(particle, "rotation", randf() * TAU * 2, 0.8)

		tween.chain().tween_callback(particle.queue_free)

	# Add some star bursts
	_spawn_star_burst(center, go_color)


func _spawn_star_burst(pos: Vector2, color: Color) -> void:
	var ray_count := 12

	for i in range(ray_count):
		var ray := ColorRect.new()
		ray.size = Vector2(4, 60)
		ray.position = pos
		ray.color = color
		ray.pivot_offset = Vector2(2, 0)
		ray.rotation = (TAU / ray_count) * i

		_particle_container.add_child(ray)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(ray, "size:y", 200.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.tween_property(ray, "modulate:a", 0.0, 0.3).set_delay(0.1)

		tween.chain().tween_callback(ray.queue_free)


# ============================================================================
# SOUND
# ============================================================================

func _play_countdown_sound(num: int) -> void:
	if has_node("/root/AudioManager"):
		var audio = get_node("/root/AudioManager")
		if audio.has_method("play_ui_sound"):
			audio.play_ui_sound("countdown_tick")


func _play_go_sound() -> void:
	if has_node("/root/AudioManager"):
		var audio = get_node("/root/AudioManager")
		if audio.has_method("play_ui_sound"):
			audio.play_ui_sound("countdown_go")
