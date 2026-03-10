## In-game HUD overlay for mobile party games.
## Manages joystick, action buttons, timer, score, health, kill feed,
## countdown and pause functionality.
extends CanvasLayer

## Emitted when the player taps the pause button.
signal pause_requested

# ── Node references ───────────────────────────────────────────────────────────
@onready var hud_root: Control = %HUDRoot
@onready var joystick: Control = %VirtualJoystick  # VirtualJoystick class
@onready var action_buttons_container: Control = %ActionButtons
@onready var timer_label: Label = %TimerLabel
@onready var score_label: Label = %ScoreLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var kill_feed: VBoxContainer = %KillFeed
@onready var countdown_label: Label = %CountdownLabel
@onready var message_label: Label = %MessageLabel
@onready var pause_button: Button = %PauseButton

# ── Constants ─────────────────────────────────────────────────────────────────
const MAX_KILL_FEED_ENTRIES: int = 3
const ACTION_BUTTON_SCENE: PackedScene = preload("res://ui/touch_controls/action_button.tscn")

# ── Internal state ────────────────────────────────────────────────────────────
var _message_tween: Tween = null
var _countdown_tween: Tween = null
var _joystick_callback: Callable = Callable()
var _action_button_nodes: Array[Control] = []


func _ready() -> void:
	countdown_label.visible = false
	message_label.visible = false

	pause_button.pressed.connect(_on_pause_pressed)

	# Forward joystick output if a callback is connected.
	if joystick.has_signal("joystick_changed"):
		joystick.joystick_changed.connect(_on_joystick_changed)


# ── Public API ────────────────────────────────────────────────────────────────

## Display a timer value formatted as MM:SS.
func set_timer(seconds: float) -> void:
	var total_secs: int = maxi(int(seconds), 0)
	var mins: int = total_secs / 60
	var secs: int = total_secs % 60
	timer_label.text = "%02d:%02d" % [mins, secs]


## Update the score display.
func set_score(score: int) -> void:
	score_label.text = "Score: %d" % score


## Update the health bar.
func set_health(current: float, max_val: float) -> void:
	health_bar.max_value = max_val
	health_bar.value = current


## Add a kill-feed / event entry at the top. Oldest entries are removed
## when the list exceeds MAX_KILL_FEED_ENTRIES.
func add_kill_feed_entry(text: String, color: Color = Color.WHITE) -> void:
	var entry := Label.new()
	entry.text = text
	entry.add_theme_color_override("font_color", color)
	entry.add_theme_font_size_override("font_size", 20)
	kill_feed.add_child(entry)
	kill_feed.move_child(entry, 0)

	# Trim old entries.
	while kill_feed.get_child_count() > MAX_KILL_FEED_ENTRIES:
		var old: Node = kill_feed.get_child(kill_feed.get_child_count() - 1)
		kill_feed.remove_child(old)
		old.queue_free()

	# Auto-fade after 5 seconds.
	var tween: Tween = create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(entry, "modulate:a", 0.0, 1.0)
	tween.tween_callback(entry.queue_free)


## Show a large countdown number in the centre of the screen with a scale
## pop animation. Pass 0 to display "GO!".
func show_countdown(number: int) -> void:
	if _countdown_tween and _countdown_tween.is_valid():
		_countdown_tween.kill()

	countdown_label.text = "GO!" if number == 0 else str(number)
	countdown_label.visible = true
	countdown_label.modulate = Color.WHITE
	countdown_label.pivot_offset = countdown_label.size * 0.5
	countdown_label.scale = Vector2(1.6, 1.6)

	_countdown_tween = create_tween()
	_countdown_tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_countdown_tween.tween_interval(0.5)
	_countdown_tween.tween_property(countdown_label, "modulate:a", 0.0, 0.15)
	_countdown_tween.tween_callback(func() -> void: countdown_label.visible = false)


## Show a temporary centred message that fades out after [duration] seconds.
func show_message(text: String, duration: float = 2.0) -> void:
	if _message_tween and _message_tween.is_valid():
		_message_tween.kill()

	message_label.text = text
	message_label.visible = true
	message_label.modulate = Color.WHITE

	_message_tween = create_tween()
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.4)
	_message_tween.tween_callback(func() -> void: message_label.visible = false)


## Configure the right-side action buttons dynamically.
## Each dictionary: { "text": String, "color": Color, "callback": Callable }
func set_action_buttons(buttons: Array[Dictionary]) -> void:
	# Remove existing dynamic buttons.
	for btn: Control in _action_button_nodes:
		if is_instance_valid(btn):
			btn.queue_free()
	_action_button_nodes.clear()

	var offset_y: float = 0.0
	for i: int in buttons.size():
		var cfg: Dictionary = buttons[i]
		var btn_instance: Control = ACTION_BUTTON_SCENE.instantiate()
		action_buttons_container.add_child(btn_instance)

		btn_instance.button_text = cfg.get("text", "A") as String
		btn_instance.button_color = cfg.get("color", Color(1.0, 0.3, 0.3, 0.8)) as Color
		btn_instance.position = Vector2(0.0, offset_y)
		offset_y -= 130.0  # Stack upward

		if cfg.has("callback"):
			var cb: Callable = cfg["callback"] as Callable
			if cb.is_valid():
				btn_instance.button_pressed.connect(cb)

		_action_button_nodes.append(btn_instance)


## Connect a Callable to receive joystick output (Vector2) every time it changes.
func connect_joystick(callback: Callable) -> void:
	_joystick_callback = callback


# ── Internals ─────────────────────────────────────────────────────────────────

func _on_joystick_changed(value: Vector2) -> void:
	if _joystick_callback.is_valid():
		_joystick_callback.call(value)


func _on_pause_pressed() -> void:
	pause_requested.emit()
