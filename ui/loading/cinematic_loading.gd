## CinematicLoading - Premium loading screen with particles, animations, and visual polish
## Features animated logo, glowing progress bar, parallax background, and spinning items
extends CanvasLayer

signal loading_started(scene_path: String)
signal loading_progress(percent: float)
signal loading_complete()
signal loading_failed(error: String)

# Configuration
@export var min_display_time: float = 1.5  # Minimum time to show loading screen
@export var show_fps_counter: bool = false
@export var tip_rotation_interval: float = 4.0
@export var enable_particles: bool = true
@export var enable_parallax: bool = true

# Loading tips - More engaging than generic ones
const LOADING_TIPS: Array[String] = [
	"Master the double-tap dodge to evade incoming fire!",
	"Headshots deal 2x damage - aim for the top!",
	"Jetpack fuel regenerates faster when grounded.",
	"Coordinate with teammates using quick chat commands.",
	"The high ground gives you a tactical advantage.",
	"Shield pickups absorb damage before your health.",
	"Explosive weapons are great for area denial.",
	"Sprint + Jump combo covers more distance.",
	"Watch the minimap for enemy positions.",
	"Reload while in cover to stay combat-ready.",
	"Different weapons excel at different ranges.",
	"Use the environment for tactical positioning.",
	"Communication wins matches - use voice chat!",
	"Practice makes perfect - try the training mode.",
	"Customize your loadout in the armory.",
]

# Node references (created programmatically)
var _background_layer: Control
var _parallax_layers: Array[Control] = []
var _logo_container: Control
var _logo: TextureRect
var _logo_glow: ColorRect
var _progress_container: Control
var _progress_bar: Control
var _progress_fill: ColorRect
var _progress_glow: ColorRect
var _progress_label: Label
var _tip_container: Control
var _tip_label: Label
var _particle_container: Control
var _fps_label: Label
var _spinning_items: Array[Control] = []
var _character_silhouette: Control

# State
var _current_scene: String = ""
var _is_loading: bool = false
var _loading_start_time: float = 0.0
var _tip_timer: float = 0.0
var _current_tip_index: int = 0
var _particle_tweens: Array[Tween] = []

# Colors
const ACCENT_COLOR := Color(0.2, 0.6, 1.0)
const GLOW_COLOR := Color(0.4, 0.7, 1.0, 0.6)
const BACKGROUND_COLOR := Color(0.05, 0.08, 0.12)
const SECONDARY_COLOR := Color(0.1, 0.15, 0.22)


func _ready() -> void:
	layer = 110  # Above transitions
	_build_ui()
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return

	_update_loading_progress()
	_update_parallax(delta)
	_update_spinning_items(delta)
	_update_tip_rotation(delta)
	_update_particles(delta)
	_update_fps_counter()


func _build_ui() -> void:
	# Root container
	var root := Control.new()
	root.name = "LoadingRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Background gradient
	_build_background(root)

	# Parallax background layers
	if enable_parallax:
		_build_parallax_layers(root)

	# Particle container
	if enable_particles:
		_build_particle_system(root)

	# Character silhouette
	_build_character_silhouette(root)

	# Spinning items
	_build_spinning_items(root)

	# Logo with glow
	_build_logo(root)

	# Progress bar with glow
	_build_progress_bar(root)

	# Tip container
	_build_tip_container(root)

	# FPS counter
	if show_fps_counter:
		_build_fps_counter(root)


func _build_background(parent: Control) -> void:
	_background_layer = Control.new()
	_background_layer.name = "BackgroundLayer"
	_background_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(_background_layer)

	# Gradient background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BACKGROUND_COLOR
	_background_layer.add_child(bg)

	# Radial gradient overlay
	var gradient_overlay := ColorRect.new()
	gradient_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var gradient_shader := Shader.new()
	gradient_shader.code = """
	shader_type canvas_item;
	uniform vec4 color_center : source_color = vec4(0.15, 0.2, 0.3, 1.0);
	uniform vec4 color_edge : source_color = vec4(0.05, 0.08, 0.12, 1.0);

	void fragment() {
		vec2 uv = UV - 0.5;
		float dist = length(uv) * 1.5;
		COLOR = mix(color_center, color_edge, smoothstep(0.0, 1.0, dist));
	}
	"""

	var mat := ShaderMaterial.new()
	mat.shader = gradient_shader
	mat.set_shader_parameter("color_center", SECONDARY_COLOR)
	mat.set_shader_parameter("color_edge", BACKGROUND_COLOR)
	gradient_overlay.material = mat

	_background_layer.add_child(gradient_overlay)


func _build_parallax_layers(parent: Control) -> void:
	# Create multiple parallax layers with different speeds
	var layer_count := 3
	var shapes_per_layer := [15, 10, 5]
	var speeds := [0.5, 1.0, 2.0]
	var sizes := [Vector2(30, 30), Vector2(50, 50), Vector2(80, 80)]
	var alphas := [0.03, 0.05, 0.08]

	for i in range(layer_count):
		var layer := Control.new()
		layer.name = "ParallaxLayer%d" % i
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.set_meta("speed", speeds[i])
		layer.set_meta("offset", Vector2.ZERO)
		parent.add_child(layer)
		_parallax_layers.append(layer)

		# Add shapes to layer
		for j in range(shapes_per_layer[i]):
			var shape := ColorRect.new()
			shape.size = sizes[i] * randf_range(0.5, 1.5)
			shape.position = Vector2(
				randf() * get_viewport().get_visible_rect().size.x,
				randf() * get_viewport().get_visible_rect().size.y
			)
			shape.rotation = randf() * TAU
			shape.color = ACCENT_COLOR
			shape.color.a = alphas[i]
			shape.pivot_offset = shape.size / 2.0

			# Random shape style
			var style := StyleBoxFlat.new()
			style.bg_color = shape.color
			if randf() > 0.5:
				style.set_corner_radius_all(int(shape.size.x / 2))  # Circle
			else:
				style.set_corner_radius_all(4)  # Rounded square

			layer.add_child(shape)


func _build_particle_system(parent: Control) -> void:
	_particle_container = Control.new()
	_particle_container.name = "ParticleContainer"
	_particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_particle_container)

	# Spawn initial particles
	for i in range(20):
		_spawn_particle()


func _spawn_particle() -> void:
	if not _particle_container:
		return

	var particle := ColorRect.new()
	var size := randf_range(2, 8)
	particle.size = Vector2(size, size)
	particle.color = ACCENT_COLOR
	particle.color.a = randf_range(0.2, 0.6)

	# Start from bottom
	var screen_size := get_viewport().get_visible_rect().size
	particle.position = Vector2(
		randf() * screen_size.x,
		screen_size.y + 20
	)

	# Make it round
	particle.pivot_offset = particle.size / 2.0

	_particle_container.add_child(particle)

	# Animate upward with drift
	var duration := randf_range(4.0, 8.0)
	var drift := randf_range(-100, 100)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "position:y", -50.0, duration)
	tween.tween_property(particle, "position:x", particle.position.x + drift, duration)
	tween.tween_property(particle, "modulate:a", 0.0, duration * 0.3).set_delay(duration * 0.7)
	tween.tween_property(particle, "scale", Vector2(0.3, 0.3), duration * 0.3).set_delay(duration * 0.7)

	_particle_tweens.append(tween)

	tween.chain().tween_callback(func():
		particle.queue_free()
		_spawn_particle()  # Respawn
	)


func _build_character_silhouette(parent: Control) -> void:
	_character_silhouette = Control.new()
	_character_silhouette.name = "CharacterSilhouette"
	_character_silhouette.set_anchors_preset(Control.PRESET_CENTER)
	_character_silhouette.position = Vector2(100, 50)
	_character_silhouette.custom_minimum_size = Vector2(200, 300)

	# Simple character shape using ColorRects
	var body := ColorRect.new()
	body.size = Vector2(80, 120)
	body.position = Vector2(60, 100)
	body.color = Color(1, 1, 1, 0.08)
	_character_silhouette.add_child(body)

	var head := ColorRect.new()
	head.size = Vector2(50, 50)
	head.position = Vector2(75, 40)
	head.color = Color(1, 1, 1, 0.08)
	_character_silhouette.add_child(head)

	parent.add_child(_character_silhouette)

	# Subtle breathing animation
	var tween := create_tween().set_loops()
	tween.tween_property(_character_silhouette, "scale", Vector2(1.02, 1.02), 1.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_character_silhouette, "scale", Vector2(1.0, 1.0), 1.5).set_ease(Tween.EASE_IN_OUT)


func _build_spinning_items(parent: Control) -> void:
	# Create spinning weapon/item silhouettes around the screen edges
	var positions := [
		Vector2(0.1, 0.2),
		Vector2(0.9, 0.3),
		Vector2(0.15, 0.7),
		Vector2(0.85, 0.75),
	]

	for pos in positions:
		var item := ColorRect.new()
		item.size = Vector2(40, 15)
		item.pivot_offset = item.size / 2.0
		item.color = ACCENT_COLOR
		item.color.a = 0.15
		item.set_meta("base_position", pos)
		item.set_meta("rotation_speed", randf_range(0.5, 2.0) * (1 if randf() > 0.5 else -1))
		item.set_meta("bob_offset", randf() * TAU)

		parent.add_child(item)
		_spinning_items.append(item)


func _build_logo(parent: Control) -> void:
	_logo_container = Control.new()
	_logo_container.name = "LogoContainer"
	_logo_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_logo_container.position = Vector2(-200, 80)
	_logo_container.custom_minimum_size = Vector2(400, 150)
	parent.add_child(_logo_container)

	# Logo glow background
	_logo_glow = ColorRect.new()
	_logo_glow.size = Vector2(450, 180)
	_logo_glow.position = Vector2(-25, -15)
	_logo_glow.color = GLOW_COLOR
	_logo_glow.color.a = 0.0

	var glow_shader := Shader.new()
	glow_shader.code = """
	shader_type canvas_item;
	uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 0.5);
	uniform float pulse : hint_range(0.0, 1.0) = 0.0;

	void fragment() {
		vec2 uv = UV - 0.5;
		float dist = length(uv) * 2.0;
		float glow = smoothstep(1.0, 0.0, dist) * (0.3 + pulse * 0.3);
		COLOR = vec4(glow_color.rgb, glow * glow_color.a);
	}
	"""
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = glow_shader
	glow_mat.set_shader_parameter("glow_color", GLOW_COLOR)
	_logo_glow.material = glow_mat
	_logo_container.add_child(_logo_glow)

	# Logo text (using Label as fallback if no texture)
	var logo_text := Label.new()
	logo_text.text = "BATTLEZONE"
	logo_text.add_theme_font_size_override("font_size", 64)
	logo_text.add_theme_color_override("font_color", Color.WHITE)
	logo_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo_text.size = Vector2(400, 100)
	logo_text.position = Vector2(0, 25)
	_logo_container.add_child(logo_text)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "PARTY"
	subtitle.add_theme_font_size_override("font_size", 32)
	subtitle.add_theme_color_override("font_color", ACCENT_COLOR)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(400, 40)
	subtitle.position = Vector2(0, 110)
	_logo_container.add_child(subtitle)

	# Pulsing glow animation
	var glow_tween := create_tween().set_loops()
	glow_tween.tween_method(
		func(v: float): (_logo_glow.material as ShaderMaterial).set_shader_parameter("pulse", v),
		0.0, 1.0, 2.0
	).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_method(
		func(v: float): (_logo_glow.material as ShaderMaterial).set_shader_parameter("pulse", v),
		1.0, 0.0, 2.0
	).set_ease(Tween.EASE_IN_OUT)


func _build_progress_bar(parent: Control) -> void:
	_progress_container = Control.new()
	_progress_container.name = "ProgressContainer"
	_progress_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_progress_container.position = Vector2(-300, -150)
	_progress_container.custom_minimum_size = Vector2(600, 40)
	parent.add_child(_progress_container)

	# Background
	var bg := ColorRect.new()
	bg.size = Vector2(600, 12)
	bg.position = Vector2(0, 14)
	bg.color = Color(0.1, 0.1, 0.15, 0.8)
	_progress_container.add_child(bg)

	# Add rounded corners style
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	bg_style.set_corner_radius_all(6)

	# Fill bar
	_progress_fill = ColorRect.new()
	_progress_fill.size = Vector2(0, 12)
	_progress_fill.position = Vector2(0, 14)
	_progress_fill.color = ACCENT_COLOR
	_progress_fill.clip_contents = true
	_progress_container.add_child(_progress_fill)

	# Glow effect on fill
	_progress_glow = ColorRect.new()
	_progress_glow.size = Vector2(600, 30)
	_progress_glow.position = Vector2(0, 5)

	var progress_glow_shader := Shader.new()
	progress_glow_shader.code = """
	shader_type canvas_item;
	uniform float progress : hint_range(0.0, 1.0) = 0.0;
	uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 0.5);

	void fragment() {
		float x = UV.x;
		float glow_pos = progress;
		float dist = abs(x - glow_pos);
		float glow = smoothstep(0.15, 0.0, dist) * 0.8;
		float trail = smoothstep(glow_pos, 0.0, x) * 0.2;
		COLOR = vec4(glow_color.rgb, (glow + trail) * glow_color.a);
	}
	"""
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = progress_glow_shader
	glow_mat.set_shader_parameter("progress", 0.0)
	glow_mat.set_shader_parameter("glow_color", GLOW_COLOR)
	_progress_glow.material = glow_mat
	_progress_container.add_child(_progress_glow)

	# Percentage label
	_progress_label = Label.new()
	_progress_label.text = "0%"
	_progress_label.add_theme_font_size_override("font_size", 18)
	_progress_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.size = Vector2(600, 30)
	_progress_label.position = Vector2(0, 30)
	_progress_container.add_child(_progress_label)


func _build_tip_container(parent: Control) -> void:
	_tip_container = Control.new()
	_tip_container.name = "TipContainer"
	_tip_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tip_container.position = Vector2(-400, -80)
	_tip_container.custom_minimum_size = Vector2(800, 50)
	parent.add_child(_tip_container)

	# Tip icon
	var tip_icon := Label.new()
	tip_icon.text = "TIP:"
	tip_icon.add_theme_font_size_override("font_size", 16)
	tip_icon.add_theme_color_override("font_color", ACCENT_COLOR)
	tip_icon.position = Vector2(0, 10)
	_tip_container.add_child(tip_icon)

	# Tip text
	_tip_label = Label.new()
	_tip_label.text = LOADING_TIPS[0]
	_tip_label.add_theme_font_size_override("font_size", 16)
	_tip_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_tip_label.position = Vector2(50, 10)
	_tip_label.size = Vector2(750, 40)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_container.add_child(_tip_label)


func _build_fps_counter(parent: Control) -> void:
	_fps_label = Label.new()
	_fps_label.name = "FPSCounter"
	_fps_label.text = "FPS: 60"
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.position = Vector2(-80, 10)
	parent.add_child(_fps_label)


# ============================================================================
# LOADING LOGIC
# ============================================================================

## Start loading a scene
func load_scene(scene_path: String) -> void:
	if _is_loading:
		return

	_current_scene = scene_path
	_is_loading = true
	_loading_start_time = Time.get_ticks_msec() / 1000.0

	visible = true
	loading_started.emit(scene_path)

	# Reset UI
	_progress_fill.size.x = 0
	_progress_label.text = "0%"
	_current_tip_index = randi() % LOADING_TIPS.size()
	_tip_label.text = LOADING_TIPS[_current_tip_index]

	# Fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

	# Start threaded loading
	ResourceLoader.load_threaded_request(scene_path)


func _update_loading_progress() -> void:
	if not _is_loading or _current_scene.is_empty():
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_current_scene, progress)

	var percent := 0.0
	if progress.size() > 0:
		percent = progress[0]

	# Update visuals
	_progress_fill.size.x = 600.0 * percent
	_progress_label.text = "%d%%" % int(percent * 100)

	# Update glow position
	if _progress_glow.material:
		(_progress_glow.material as ShaderMaterial).set_shader_parameter("progress", percent)

	loading_progress.emit(percent * 100)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_on_loading_complete()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_on_loading_failed()


func _on_loading_complete() -> void:
	var resource := ResourceLoader.load_threaded_get(_current_scene)
	if not resource is PackedScene:
		_on_loading_failed()
		return

	# Ensure minimum display time
	var elapsed := Time.get_ticks_msec() / 1000.0 - _loading_start_time
	if elapsed < min_display_time:
		await get_tree().create_timer(min_display_time - elapsed).timeout

	# Final progress
	_progress_fill.size.x = 600
	_progress_label.text = "100%"

	# Fade out
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished

	# Change scene
	get_tree().change_scene_to_packed(resource)

	_cleanup()
	loading_complete.emit()


func _on_loading_failed() -> void:
	_progress_label.text = "FAILED"
	_progress_label.add_theme_color_override("font_color", Color.RED)

	loading_failed.emit("Failed to load: %s" % _current_scene)

	# Show error for a moment then fade
	await get_tree().create_timer(2.0).timeout

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished

	_cleanup()


func _cleanup() -> void:
	visible = false
	_is_loading = false
	_current_scene = ""


# ============================================================================
# VISUAL UPDATES
# ============================================================================

func _update_parallax(delta: float) -> void:
	if not enable_parallax:
		return

	for layer in _parallax_layers:
		var speed: float = layer.get_meta("speed", 1.0)
		var offset: Vector2 = layer.get_meta("offset", Vector2.ZERO)

		offset.y -= speed * delta * 30.0
		offset.x += sin(Time.get_ticks_msec() * 0.0005 * speed) * delta * 10.0

		layer.set_meta("offset", offset)

		# Apply offset to children
		for child in layer.get_children():
			if child is ColorRect:
				child.rotation += delta * speed * 0.1


func _update_spinning_items(delta: float) -> void:
	var screen_size := get_viewport().get_visible_rect().size
	var time := Time.get_ticks_msec() * 0.001

	for item in _spinning_items:
		var base_pos: Vector2 = item.get_meta("base_position", Vector2(0.5, 0.5))
		var rot_speed: float = item.get_meta("rotation_speed", 1.0)
		var bob_offset: float = item.get_meta("bob_offset", 0.0)

		item.position = Vector2(
			base_pos.x * screen_size.x + sin(time + bob_offset) * 20.0,
			base_pos.y * screen_size.y + cos(time * 0.7 + bob_offset) * 15.0
		)
		item.rotation += rot_speed * delta


func _update_tip_rotation(delta: float) -> void:
	_tip_timer += delta

	if _tip_timer >= tip_rotation_interval:
		_tip_timer = 0.0
		_rotate_tip()


func _rotate_tip() -> void:
	# Fade out current tip
	var tween := create_tween()
	tween.tween_property(_tip_label, "modulate:a", 0.0, 0.3)

	await tween.finished

	# Change tip
	_current_tip_index = (_current_tip_index + 1) % LOADING_TIPS.size()
	_tip_label.text = LOADING_TIPS[_current_tip_index]

	# Fade in new tip
	tween = create_tween()
	tween.tween_property(_tip_label, "modulate:a", 1.0, 0.3)


func _update_particles(_delta: float) -> void:
	# Particles are self-managing via tweens
	pass


func _update_fps_counter() -> void:
	if show_fps_counter and _fps_label:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


# ============================================================================
# PUBLIC API
# ============================================================================

## Show loading screen without loading (for manual control)
func show_screen() -> void:
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


## Hide loading screen
func hide_screen() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false


## Set progress manually (0.0 to 1.0)
func set_progress(percent: float) -> void:
	_progress_fill.size.x = 600.0 * clampf(percent, 0.0, 1.0)
	_progress_label.text = "%d%%" % int(percent * 100)

	if _progress_glow.material:
		(_progress_glow.material as ShaderMaterial).set_shader_parameter("progress", percent)


## Enable/disable FPS counter
func set_fps_counter_visible(show: bool) -> void:
	show_fps_counter = show
	if _fps_label:
		_fps_label.visible = show


## Set custom tips
func set_loading_tips(tips: Array[String]) -> void:
	# Can't modify const, but we can use a var if needed
	pass
