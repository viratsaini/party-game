## HintSystem - Contextual hints with first-time detection, pro tips, and tracking
## Features: first-time hints, pro tips, session tracking, animated icons, dismiss behavior
extends Node

class_name HintSystem

## Emitted when a hint is shown
signal hint_shown(hint_id: String, hint_type: String)
## Emitted when a hint is dismissed
signal hint_dismissed(hint_id: String)
## Emitted when all hints for a topic are completed
signal hints_completed(topic: String)

# =====================================================================
# ENUMS
# =====================================================================

enum HintType {
	FIRST_TIME,    # Only shown once ever
	CONTEXTUAL,    # Shown when relevant context triggers
	PRO_TIP,       # Random helpful tips
	WARNING,       # Important warnings
	CELEBRATION    # Achievement/milestone hints
}

enum HintPriority {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
	CRITICAL = 3
}

# =====================================================================
# CONFIGURATION
# =====================================================================

## Minimum time between pro tips (seconds)
@export var pro_tip_cooldown: float = 60.0
## Maximum hints to show per session
@export var max_hints_per_session: int = 10
## Auto-dismiss delay for non-critical hints (seconds)
@export var auto_dismiss_delay: float = 8.0
## Save file path for hint history
@export var save_path: String = "user://hint_history.json"

# =====================================================================
# INTERNAL STATE
# =====================================================================

# Registered hints
var _hints: Dictionary = {}  # hint_id -> HintData

# Tracking
var _shown_ever: Dictionary = {}      # hint_id -> bool (persistent)
var _shown_this_session: Array[String] = []
var _dismissed_this_session: Array[String] = []
var _hints_shown_count: int = 0
var _last_pro_tip_time: float = -INF

# Active hint display
var _hint_container: CanvasLayer
var _active_hints: Array[Control] = []
var _hint_queue: Array[Dictionary] = []
var _processing_queue: bool = false

# Pro tips pool
var _pro_tips: Array[String] = []
var _shown_pro_tips: Array[String] = []

# =====================================================================
# HINT DATA STRUCTURE
# =====================================================================

class HintData:
	var id: String
	var type: HintType
	var priority: HintPriority
	var title: String
	var message: String
	var icon_type: String  # "info", "tip", "warning", "star", "custom"
	var custom_icon: Texture2D
	var topic: String
	var conditions: Callable  # Returns bool - should show?
	var auto_dismiss: bool
	var dismiss_delay: float
	var target_element: Control  # Optional - position near element
	var position_hint: String  # "top", "bottom", "left", "right", "center"

# =====================================================================
# LIFECYCLE
# =====================================================================

func _ready() -> void:
	_create_hint_container()
	_load_history()
	_setup_default_pro_tips()


func _process(delta: float) -> void:
	# Process hint queue
	if not _hint_queue.is_empty() and not _processing_queue:
		_process_next_hint()


# =====================================================================
# UI CREATION
# =====================================================================

func _create_hint_container() -> void:
	_hint_container = CanvasLayer.new()
	_hint_container.name = "HintContainer"
	_hint_container.layer = 97
	add_child(_hint_container)


func _create_hint_popup(hint_data: HintData) -> Control:
	var popup := Panel.new()
	popup.name = "HintPopup_" + hint_data.id
	_setup_popup_style(popup, hint_data.type)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	popup.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	# Animated icon
	var icon_container := _create_animated_icon(hint_data.icon_type, hint_data.type)
	hbox.add_child(icon_container)

	# Content
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(content)

	# Title (if present)
	if not hint_data.title.is_empty():
		var title := Label.new()
		title.text = hint_data.title
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", _get_title_color(hint_data.type))
		content.add_child(title)

	# Message
	var message := Label.new()
	message.text = hint_data.message
	message.add_theme_font_size_override("font_size", 13)
	message.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.x = 280
	content.add_child(message)

	# Dismiss button
	var dismiss := Button.new()
	dismiss.text = "X"
	dismiss.custom_minimum_size = Vector2(24, 24)
	dismiss.pressed.connect(_on_hint_dismiss.bind(popup, hint_data.id))
	_setup_dismiss_button(dismiss)
	hbox.add_child(dismiss)

	# Store data
	popup.set_meta("hint_id", hint_data.id)
	popup.set_meta("hint_data", hint_data)

	return popup


func _setup_popup_style(popup: Panel, type: HintType) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 10
	style.shadow_offset = Vector2(2, 4)

	match type:
		HintType.FIRST_TIME:
			style.bg_color = Color(0.12, 0.18, 0.25, 0.98)
			style.border_color = Color(0.3, 0.5, 0.8, 0.7)
		HintType.CONTEXTUAL:
			style.bg_color = Color(0.15, 0.17, 0.22, 0.98)
			style.border_color = Color(0.4, 0.45, 0.55, 0.6)
		HintType.PRO_TIP:
			style.bg_color = Color(0.18, 0.15, 0.1, 0.98)
			style.border_color = Color(0.7, 0.55, 0.2, 0.7)
		HintType.WARNING:
			style.bg_color = Color(0.25, 0.12, 0.1, 0.98)
			style.border_color = Color(0.8, 0.4, 0.2, 0.8)
		HintType.CELEBRATION:
			style.bg_color = Color(0.1, 0.2, 0.15, 0.98)
			style.border_color = Color(0.3, 0.8, 0.4, 0.7)

	style.set_border_width_all(2)
	popup.add_theme_stylebox_override("panel", style)


func _create_animated_icon(icon_type: String, hint_type: HintType) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(32, 32)

	var icon := Label.new()
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_theme_font_size_override("font_size", 20)

	# Set icon based on type
	match icon_type:
		"info":
			icon.text = "i"
			icon.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		"tip":
			icon.text = "*"
			icon.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		"warning":
			icon.text = "!"
			icon.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		"star":
			icon.text = "*"
			icon.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		_:
			icon.text = "?"
			icon.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))

	container.add_child(icon)

	# Add animation based on hint type
	_animate_icon(icon, hint_type)

	return container


func _animate_icon(icon: Label, hint_type: HintType) -> void:
	var tween := create_tween()
	tween.set_loops()

	match hint_type:
		HintType.FIRST_TIME:
			# Gentle pulse
			tween.tween_property(icon, "modulate:a", 0.6, 0.8)
			tween.tween_property(icon, "modulate:a", 1.0, 0.8)

		HintType.PRO_TIP:
			# Sparkle effect
			tween.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.3)
			tween.tween_property(icon, "scale", Vector2.ONE, 0.3)
			tween.tween_interval(1.5)

		HintType.WARNING:
			# Attention-grabbing shake
			var base_pos := icon.position
			tween.tween_property(icon, "position:x", base_pos.x - 3, 0.05)
			tween.tween_property(icon, "position:x", base_pos.x + 3, 0.1)
			tween.tween_property(icon, "position:x", base_pos.x, 0.05)
			tween.tween_interval(2.0)

		HintType.CELEBRATION:
			# Bounce
			tween.tween_property(icon, "position:y", icon.position.y - 5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(icon, "position:y", icon.position.y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tween.tween_interval(1.0)

		_:
			# Default gentle rotation
			tween.tween_property(icon, "rotation", 0.1, 0.5)
			tween.tween_property(icon, "rotation", -0.1, 0.5)
			tween.tween_property(icon, "rotation", 0.0, 0.5)


func _get_title_color(type: HintType) -> Color:
	match type:
		HintType.FIRST_TIME:
			return Color(0.6, 0.8, 1.0)
		HintType.PRO_TIP:
			return Color(1.0, 0.85, 0.4)
		HintType.WARNING:
			return Color(1.0, 0.6, 0.4)
		HintType.CELEBRATION:
			return Color(0.5, 1.0, 0.6)
		_:
			return Color(0.9, 0.9, 0.95)


func _setup_dismiss_button(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.35, 0.6)
	style.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.5, 0.3, 0.3, 0.8)
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_font_size_override("font_size", 12)


# =====================================================================
# PUBLIC API
# =====================================================================

## Register a hint
func register_hint(hint_id: String, data: Dictionary) -> void:
	var hint := HintData.new()
	hint.id = hint_id
	hint.type = data.get("type", HintType.CONTEXTUAL)
	hint.priority = data.get("priority", HintPriority.MEDIUM)
	hint.title = data.get("title", "")
	hint.message = data.get("message", "")
	hint.icon_type = data.get("icon", "info")
	hint.custom_icon = data.get("custom_icon")
	hint.topic = data.get("topic", "general")
	hint.conditions = data.get("conditions", Callable())
	hint.auto_dismiss = data.get("auto_dismiss", true)
	hint.dismiss_delay = data.get("dismiss_delay", auto_dismiss_delay)
	hint.target_element = data.get("target_element")
	hint.position_hint = data.get("position", "bottom")

	_hints[hint_id] = hint


## Unregister a hint
func unregister_hint(hint_id: String) -> void:
	_hints.erase(hint_id)


## Trigger a hint to show (if conditions met)
func trigger_hint(hint_id: String, force: bool = false) -> bool:
	if not _hints.has(hint_id):
		return false

	var hint: HintData = _hints[hint_id]

	# Check if already shown this session (prevent spam)
	if hint_id in _shown_this_session and not force:
		return false

	# Check if first-time hint already shown ever
	if hint.type == HintType.FIRST_TIME and _shown_ever.get(hint_id, false) and not force:
		return false

	# Check session limit
	if _hints_shown_count >= max_hints_per_session and hint.priority < HintPriority.HIGH:
		return false

	# Check conditions
	if hint.conditions.is_valid() and not hint.conditions.call():
		return false

	# Add to queue
	_queue_hint(hint)
	return true


## Show a one-off hint (not registered)
func show_quick_hint(message: String, type: HintType = HintType.CONTEXTUAL, title: String = "") -> void:
	var hint := HintData.new()
	hint.id = "quick_" + str(Time.get_ticks_msec())
	hint.type = type
	hint.priority = HintPriority.MEDIUM
	hint.title = title
	hint.message = message
	hint.icon_type = _get_default_icon(type)
	hint.auto_dismiss = true
	hint.dismiss_delay = auto_dismiss_delay
	hint.position_hint = "bottom"

	_queue_hint(hint)


## Trigger a random pro tip
func trigger_pro_tip() -> bool:
	var current_time := Time.get_ticks_msec() / 1000.0

	# Check cooldown
	if current_time - _last_pro_tip_time < pro_tip_cooldown:
		return false

	# Get available tips
	var available: Array[String] = []
	for tip in _pro_tips:
		if tip not in _shown_pro_tips:
			available.append(tip)

	if available.is_empty():
		# Reset pool
		_shown_pro_tips.clear()
		available = _pro_tips.duplicate()

	if available.is_empty():
		return false

	# Pick random tip
	var tip: String = available[randi() % available.size()]
	_shown_pro_tips.append(tip)
	_last_pro_tip_time = current_time

	show_quick_hint(tip, HintType.PRO_TIP, "Pro Tip")
	return true


## Add a pro tip to the pool
func add_pro_tip(tip: String) -> void:
	if tip not in _pro_tips:
		_pro_tips.append(tip)


## Dismiss a specific hint
func dismiss_hint(hint_id: String) -> void:
	for popup in _active_hints:
		if is_instance_valid(popup) and popup.get_meta("hint_id", "") == hint_id:
			_dismiss_popup(popup, hint_id)
			return


## Dismiss all active hints
func dismiss_all_hints() -> void:
	for popup in _active_hints.duplicate():
		if is_instance_valid(popup):
			var hint_id: String = popup.get_meta("hint_id", "")
			_dismiss_popup(popup, hint_id)


## Check if a hint has been shown ever
func was_hint_shown(hint_id: String) -> bool:
	return _shown_ever.get(hint_id, false)


## Check if a hint was shown this session
func was_hint_shown_this_session(hint_id: String) -> bool:
	return hint_id in _shown_this_session


## Reset all hint history (for testing/debug)
func reset_history() -> void:
	_shown_ever.clear()
	_save_history()


## Get all hints for a topic
func get_hints_for_topic(topic: String) -> Array[String]:
	var result: Array[String] = []
	for hint_id in _hints:
		var hint: HintData = _hints[hint_id]
		if hint.topic == topic:
			result.append(hint_id)
	return result


# =====================================================================
# INTERNAL METHODS
# =====================================================================

func _queue_hint(hint: HintData) -> void:
	# Insert based on priority
	var insert_index := _hint_queue.size()

	for i in range(_hint_queue.size()):
		var queued: Dictionary = _hint_queue[i]
		if hint.priority > queued.get("priority", 0):
			insert_index = i
			break

	_hint_queue.insert(insert_index, {
		"hint": hint,
		"priority": hint.priority
	})


func _process_next_hint() -> void:
	if _hint_queue.is_empty():
		return

	_processing_queue = true

	var queued: Dictionary = _hint_queue.pop_front()
	var hint: HintData = queued.get("hint")

	_show_hint(hint)

	# Small delay before next hint
	await get_tree().create_timer(0.3).timeout
	_processing_queue = false


func _show_hint(hint: HintData) -> void:
	var popup := _create_hint_popup(hint)
	_hint_container.add_child(popup)
	_active_hints.append(popup)

	# Position popup
	await get_tree().process_frame
	_position_popup(popup, hint)

	# Animate in
	_animate_popup_in(popup)

	# Track
	_shown_this_session.append(hint.id)
	_hints_shown_count += 1

	if hint.type == HintType.FIRST_TIME:
		_shown_ever[hint.id] = true
		_save_history()

	hint_shown.emit(hint.id, HintType.keys()[hint.type])

	# Auto-dismiss
	if hint.auto_dismiss:
		_schedule_auto_dismiss(popup, hint.id, hint.dismiss_delay)


func _position_popup(popup: Control, hint: HintData) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var popup_size := popup.get_combined_minimum_size()
	var margin := 20.0

	if hint.target_element and is_instance_valid(hint.target_element):
		var target_rect := hint.target_element.get_global_rect()

		match hint.position_hint:
			"top":
				popup.position = Vector2(
					target_rect.position.x + target_rect.size.x / 2 - popup_size.x / 2,
					target_rect.position.y - popup_size.y - margin
				)
			"bottom":
				popup.position = Vector2(
					target_rect.position.x + target_rect.size.x / 2 - popup_size.x / 2,
					target_rect.end.y + margin
				)
			"left":
				popup.position = Vector2(
					target_rect.position.x - popup_size.x - margin,
					target_rect.position.y + target_rect.size.y / 2 - popup_size.y / 2
				)
			"right":
				popup.position = Vector2(
					target_rect.end.x + margin,
					target_rect.position.y + target_rect.size.y / 2 - popup_size.y / 2
				)
	else:
		# Default: bottom center, stacked
		var stack_offset := _active_hints.find(popup) * (popup_size.y + 10)
		popup.position = Vector2(
			viewport_size.x / 2 - popup_size.x / 2,
			viewport_size.y - popup_size.y - margin - stack_offset
		)

	# Clamp to viewport
	popup.position.x = clampf(popup.position.x, margin, viewport_size.x - popup_size.x - margin)
	popup.position.y = clampf(popup.position.y, margin, viewport_size.y - popup_size.y - margin)


func _animate_popup_in(popup: Control) -> void:
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.9, 0.9)
	popup.pivot_offset = popup.size / 2

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(popup, "modulate:a", 1.0, 0.25)
	tween.tween_property(popup, "scale", Vector2.ONE, 0.3)


func _animate_popup_out(popup: Control) -> Tween:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	tween.tween_property(popup, "modulate:a", 0.0, 0.2)
	tween.tween_property(popup, "position:y", popup.position.y + 20, 0.2)
	return tween


func _schedule_auto_dismiss(popup: Control, hint_id: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout

	if is_instance_valid(popup) and popup.is_inside_tree():
		_dismiss_popup(popup, hint_id)


func _dismiss_popup(popup: Control, hint_id: String) -> void:
	if popup in _active_hints:
		_active_hints.erase(popup)

	if hint_id not in _dismissed_this_session:
		_dismissed_this_session.append(hint_id)

	var tween := _animate_popup_out(popup)
	tween.tween_callback(popup.queue_free)

	hint_dismissed.emit(hint_id)

	# Check if all hints for topic completed
	var hint_data = popup.get_meta("hint_data") as HintData
	if hint_data:
		_check_topic_completion(hint_data.topic)


func _check_topic_completion(topic: String) -> void:
	var topic_hints := get_hints_for_topic(topic)

	for hint_id in topic_hints:
		if not _shown_ever.get(hint_id, false):
			return  # Not all shown

	hints_completed.emit(topic)


func _get_default_icon(type: HintType) -> String:
	match type:
		HintType.FIRST_TIME:
			return "info"
		HintType.PRO_TIP:
			return "tip"
		HintType.WARNING:
			return "warning"
		HintType.CELEBRATION:
			return "star"
		_:
			return "info"


func _setup_default_pro_tips() -> void:
	_pro_tips = [
		"Use the jetpack sparingly - it recharges faster when grounded!",
		"Headshots deal 2x damage. Aim high!",
		"The minimap shows enemy positions when they fire.",
		"Crouching improves accuracy significantly.",
		"Reload behind cover to stay safe.",
		"Pick up fallen weapons for extra ammo.",
		"Communication with your team is key to victory!",
		"Learn the map layouts to find the best ambush spots.",
		"Grenades can flush enemies out of cover.",
		"Double-tap to dodge incoming fire!"
	]


func _save_history() -> void:
	var data := {
		"shown_ever": _shown_ever,
		"version": 1
	}

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _load_history() -> void:
	if not FileAccess.file_exists(save_path):
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()

	if result != OK:
		return

	var data: Dictionary = json.data
	_shown_ever = data.get("shown_ever", {})


# =====================================================================
# SIGNAL HANDLERS
# =====================================================================

func _on_hint_dismiss(popup: Control, hint_id: String) -> void:
	_dismiss_popup(popup, hint_id)
