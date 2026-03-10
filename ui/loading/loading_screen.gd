## LoadingScreen — Displays during scene transitions with progress indicator
extends CanvasLayer

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var loading_label: Label = %LoadingLabel
@onready var tip_label: Label = %TipLabel
@onready var spinner: Control = %Spinner

var _loading_tips: Array[String] = [
	"Pro tip: Use the virtual joystick for smooth movement!",
	"Did you know? You can chat with other players in the lobby!",
	"Tip: Make sure all players are ready before starting the game.",
	"Remember: Communication is key to winning mini-games!",
	"Fun fact: This game supports up to 8 players on LAN!",
	"Hint: Check your connection quality in the lobby.",
	"Tip: Choose your character wisely - each has a unique look!",
	"Pro tip: Stay close to your teammates in team-based games.",
]

var _current_scene: String = ""
var _loader: ResourceLoader.ThreadLoadStatus

func _ready() -> void:
	visible = false
	_randomize_tip()

func show_loading(scene_path: String) -> void:
	_current_scene = scene_path
	visible = true
	progress_bar.value = 0
	_randomize_tip()
	_start_spinner_animation()

	# Start loading the scene
	ResourceLoader.load_threaded_request(scene_path)

func _process(_delta: float) -> void:
	if not visible or _current_scene.is_empty():
		return

	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_current_scene, progress)

	if progress.size() > 0:
		progress_bar.value = progress[0] * 100

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_on_loading_complete()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_on_loading_failed()

func _on_loading_complete() -> void:
	var resource: Resource = ResourceLoader.load_threaded_get(_current_scene)
	if resource is PackedScene:
		progress_bar.value = 100
		await get_tree().create_timer(0.3).timeout
		get_tree().change_scene_to_packed(resource)
		hide_loading()

func _on_loading_failed() -> void:
	loading_label.text = "Failed to load scene!"
	loading_label.add_theme_color_override("font_color", Color.RED)
	if is_instance_valid(NotificationManager):
		NotificationManager.show_error("Failed to load scene!")

func hide_loading() -> void:
	visible = false
	_current_scene = ""

func _randomize_tip() -> void:
	if tip_label and _loading_tips.size() > 0:
		tip_label.text = _loading_tips[randi() % _loading_tips.size()]

func _start_spinner_animation() -> void:
	if not spinner:
		return

	var tween := create_tween().set_loops()
	tween.tween_property(spinner, "rotation", TAU, 1.0).from(0.0)
