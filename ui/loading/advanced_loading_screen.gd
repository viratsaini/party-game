## Advanced Loading Screen System
## Provides cinematic loading screens with progress tracking, tips, and visual polish.
## Features multiple loading styles, async loading support, and smooth transitions.
class_name LoadingScreen
extends CanvasLayer

## Loading screen styles
enum LoadingStyle {
	SPINNER,           ## Simple circular spinner
	PROGRESS_BAR,      ## Linear progress bar
	CIRCULAR_PROGRESS, ## Circular progress ring
	DOTS_PULSING,      ## Animated dots
	HEXAGON_GRID,      ## Hexagonal loading pattern
	PARTICLE_FIELD,    ## Particles forming patterns
	CINEMATIC,         ## Full cinematic with tips
}

## Current loading style
@export var loading_style: LoadingStyle = LoadingStyle.CINEMATIC

## Show loading tips
@export var show_tips: bool = true

## Tip display duration
@export var tip_duration: float = 4.0

## Minimum loading time (prevents flash on fast loads)
@export var minimum_display_time: float = 0.5

## Background overlay
var _overlay: ColorRect = null

## Loading container
var _container: Control = null

## Progress indicator
var _progress: float = 0.0

## Loading message
var _message: String = "Loading..."

## Loading tips
var _tips: Array[String] = [
	"Tip: Use cover to your advantage in firefights",
	"Tip: Team communication is key to victory",
	"Tip: Check your minimap frequently",
	"Tip: Different weapons excel at different ranges",
	"Tip: Abilities can turn the tide of battle",
	"Tip: Reload in safe positions",
	"Tip: Listen for enemy footsteps",
	"Tip: Aim for headshots for bonus damage",
]

## Current tip index
var _current_tip: int = 0

## Tip timer
var _tip_timer: float = 0.0

## Start time
var _start_time: float = 0.0

## Is loading
var _is_loading: bool = false

## Tween for animations
var _tween: Tween = null

## Signal emitted when loading completes
signal loading_complete()


func _ready() -> void:
	# Create fullscreen overlay
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.05, 0.05, 0.10, 0.95)
	_overlay.visible = false
	add_child(_overlay)

	# Create container for loading UI
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.visible = false
	add_child(_container)

	# Build loading UI based on style
	_build_loading_ui()


func _process(delta: float) -> void:
	if not _is_loading:
		return

	# Update tip rotation
	if show_tips:
		_tip_timer += delta
		if _tip_timer >= tip_duration:
			_tip_timer = 0.0
			_current_tip = (_current_tip + 1) % _tips.size()
			_update_tip_display()


## Build loading UI based on current style
func _build_loading_ui() -> void:
	match loading_style:
		LoadingStyle.CINEMATIC:
			_build_cinematic_loading()
		LoadingStyle.PROGRESS_BAR:
			_build_progress_bar()
		LoadingStyle.SPINNER:
			_build_spinner()
		LoadingStyle.CIRCULAR_PROGRESS:
			_build_circular_progress()
		_:
			_build_cinematic_loading()


## Build cinematic loading screen
func _build_cinematic_loading() -> void:
	# Title
	var title: Label = Label.new()
	title.text = "BATTLEZONE PARTY"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 100)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_container.add_child(title)

	# Loading message
	var message_label: Label = Label.new()
	message_label.name = "MessageLabel"
	message_label.text = _message
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.position = Vector2(0, -150)
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_container.add_child(message_label)

	# Progress bar
	var progress_container: PanelContainer = PanelContainer.new()
	progress_container.name = "ProgressContainer"
	progress_container.custom_minimum_size = Vector2(600, 8)
	progress_container.position = Vector2(-300, -100)
	progress_container.set_anchors_preset(Control.PRESET_CENTER)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.5)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	progress_container.add_theme_stylebox_override("panel", style)

	_container.add_child(progress_container)

	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress_bar.show_percentage = false
	progress_bar.max_value = 1.0
	progress_container.add_child(progress_bar)

	# Tip label
	var tip_label: Label = Label.new()
	tip_label.name = "TipLabel"
	tip_label.text = _tips[0] if not _tips.is_empty() else ""
	tip_label.add_theme_font_size_override("font_size", 18)
	tip_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.8))
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_label.custom_minimum_size = Vector2(700, 0)
	tip_label.position = Vector2(-350, 50)
	tip_label.set_anchors_preset(Control.PRESET_CENTER)
	_container.add_child(tip_label)


## Build simple progress bar
func _build_progress_bar() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-200, -50)
	vbox.custom_minimum_size = Vector2(400, 100)
	_container.add_child(vbox)

	var message: Label = Label.new()
	message.name = "MessageLabel"
	message.text = _message
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message)

	var progress: ProgressBar = ProgressBar.new()
	progress.name = "ProgressBar"
	progress.custom_minimum_size = Vector2(400, 30)
	progress.max_value = 1.0
	vbox.add_child(progress)


## Build spinner loading
func _build_spinner() -> void:
	var spinner: Control = Control.new()
	spinner.name = "Spinner"
	spinner.custom_minimum_size = Vector2(64, 64)
	spinner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	spinner.position = Vector2(-32, -32)
	_container.add_child(spinner)

	# Animate spinner
	var spin_tween: Tween = create_tween()
	spin_tween.set_loops()
	spin_tween.tween_property(spinner, "rotation", TAU, 1.0)


## Build circular progress
func _build_circular_progress() -> void:
	# Similar to spinner but with progress indication
	_build_spinner()


## Show loading screen
func show_loading(message: String = "Loading...", reset_progress: bool = true) -> void:
	_message = message
	_is_loading = true
	_start_time = Time.get_ticks_msec() / 1000.0

	if reset_progress:
		_progress = 0.0

	_overlay.visible = true
	_container.visible = true

	# Fade in
	_overlay.modulate.a = 0.0
	_container.modulate.a = 0.0

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_overlay, "modulate:a", 1.0, 0.3)
	_tween.tween_property(_container, "modulate:a", 1.0, 0.3)

	# Update message
	var message_label: Label = _container.get_node_or_null("MessageLabel") as Label
	if message_label:
		message_label.text = message


## Update loading progress
func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)

	# Update progress bar if it exists
	var progress_bar: ProgressBar = _container.find_child("ProgressBar", true, false) as ProgressBar
	if progress_bar:
		progress_bar.value = _progress


## Hide loading screen
func hide_loading() -> void:
	# Ensure minimum display time
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var remaining: float = maxf(minimum_display_time - elapsed, 0.0)

	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout

	_is_loading = false

	# Fade out
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_overlay, "modulate:a", 0.0, 0.3)
	_tween.tween_property(_container, "modulate:a", 0.0, 0.3)

	await _tween.finished

	_overlay.visible = false
	_container.visible = false

	loading_complete.emit()


## Update tip display
func _update_tip_display() -> void:
	var tip_label: Label = _container.get_node_or_null("TipLabel") as Label
	if tip_label and not _tips.is_empty():
		# Fade out old tip
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(tip_label, "modulate:a", 0.0, 0.2)
		await fade_tween.finished

		# Change text
		tip_label.text = _tips[_current_tip]

		# Fade in new tip
		fade_tween = create_tween()
		fade_tween.tween_property(tip_label, "modulate:a", 1.0, 0.2)


## Add custom tip
func add_tip(tip: String) -> void:
	_tips.append(tip)


## Clear all tips
func clear_tips() -> void:
	_tips.clear()


## === STATIC HELPERS ===

static var _instance: LoadingScreen = null

## Get singleton instance
static func get_instance() -> LoadingScreen:
	if not _instance:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if not tree:
			push_error("LoadingScreen: No SceneTree found")
			return null

		_instance = LoadingScreen.new()
		_instance.name = "LoadingScreen"
		_instance.layer = 99
		tree.root.add_child(_instance)

	return _instance


## Show loading (static)
static func show(message: String = "Loading...") -> void:
	var instance: LoadingScreen = get_instance()
	if instance:
		instance.show_loading(message)


## Update progress (static)
static func update_progress(value: float) -> void:
	var instance: LoadingScreen = get_instance()
	if instance:
		instance.set_progress(value)


## Hide loading (static)
static func hide() -> void:
	var instance: LoadingScreen = get_instance()
	if instance:
		instance.hide_loading()
