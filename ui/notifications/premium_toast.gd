## PremiumToast - Premium notification/toast system with rich animations
## Supports achievements, level ups, new items with special reveal effects
extends CanvasLayer

signal notification_shown(notification_id: int)
signal notification_dismissed(notification_id: int)

enum ToastType {
	INFO,
	SUCCESS,
	WARNING,
	ERROR,
	ACHIEVEMENT,
	LEVEL_UP,
	NEW_ITEM,
	CHALLENGE_COMPLETE
}

# Configuration
@export var max_visible: int = 5
@export var default_duration: float = 4.0
@export var spacing: float = 10.0
@export var slide_duration: float = 0.3
@export var position_from_top: float = 80.0

# Queue and state
var _queue: Array[Dictionary] = []
var _active_toasts: Array[Control] = []
var _next_id: int = 0
var _container: Control

# Type-specific colors and icons
const TYPE_COLORS := {
	ToastType.INFO: Color(0.2, 0.4, 0.8),
	ToastType.SUCCESS: Color(0.2, 0.7, 0.3),
	ToastType.WARNING: Color(0.9, 0.7, 0.2),
	ToastType.ERROR: Color(0.8, 0.2, 0.2),
	ToastType.ACHIEVEMENT: Color(1.0, 0.84, 0.0),
	ToastType.LEVEL_UP: Color(0.6, 0.3, 1.0),
	ToastType.NEW_ITEM: Color(0.2, 0.8, 0.9),
	ToastType.CHALLENGE_COMPLETE: Color(0.9, 0.4, 0.1),
}

# Shaders
const GOLD_SHINE_SHADER := """
shader_type canvas_item;
uniform float time : hint_range(0.0, 10.0) = 0.0;
uniform vec4 base_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);
uniform float shine_width : hint_range(0.0, 0.5) = 0.15;
uniform float shine_speed : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec4 col = base_color;

	// Animated shine
	float shine_pos = fract(time * shine_speed * 0.3) * 2.0 - 0.5;
	float shine = smoothstep(shine_pos - shine_width, shine_pos, UV.x) *
				  (1.0 - smoothstep(shine_pos, shine_pos + shine_width, UV.x));
	col.rgb += shine * 0.5;

	COLOR = col;
}
"""

const STAR_BURST_SHADER := """
shader_type canvas_item;
uniform float time : hint_range(0.0, 10.0) = 0.0;
uniform vec4 color : source_color = vec4(0.6, 0.3, 1.0, 1.0);
uniform float ray_count : hint_range(4.0, 16.0) = 8.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float angle = atan(uv.y, uv.x);
	float dist = length(uv);

	// Rotating rays
	float rays = abs(sin((angle + time) * ray_count * 0.5));
	float glow = (1.0 - dist * 2.0) * rays * 0.5;

	// Pulse
	glow *= 0.7 + sin(time * 3.0) * 0.3;

	COLOR = vec4(color.rgb, glow * color.a);
}
"""


func _ready() -> void:
	layer = 105
	_setup_container()


func _process(_delta: float) -> void:
	_process_queue()
	_update_shader_time()


func _setup_container() -> void:
	_container = Control.new()
	_container.name = "ToastContainer"
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)


func _update_shader_time() -> void:
	var time := Time.get_ticks_msec() / 1000.0
	for toast in _active_toasts:
		var shader_bg: ColorRect = toast.get_node_or_null("ShaderBG")
		if shader_bg and shader_bg.material:
			(shader_bg.material as ShaderMaterial).set_shader_parameter("time", time)


# ============================================================================
# PUBLIC API
# ============================================================================

## Show a basic notification
func show_notification(message: String, type: ToastType = ToastType.INFO, duration: float = -1.0) -> int:
	var actual_duration := duration if duration > 0 else default_duration
	var id := _next_id
	_next_id += 1

	_queue.append({
		"id": id,
		"message": message,
		"type": type,
		"duration": actual_duration,
		"title": "",
		"icon": "",
		"data": {}
	})

	return id


## Show info notification
func show_info(message: String, duration: float = -1.0) -> int:
	return show_notification(message, ToastType.INFO, duration)


## Show success notification
func show_success(message: String, duration: float = -1.0) -> int:
	return show_notification(message, ToastType.SUCCESS, duration)


## Show warning notification
func show_warning(message: String, duration: float = -1.0) -> int:
	return show_notification(message, ToastType.WARNING, duration)


## Show error notification
func show_error(message: String, duration: float = -1.0) -> int:
	return show_notification(message, ToastType.ERROR, duration)


## Show achievement unlocked with gold shine effect
func show_achievement(title: String, description: String, duration: float = 5.0) -> int:
	var id := _next_id
	_next_id += 1

	_queue.append({
		"id": id,
		"message": description,
		"type": ToastType.ACHIEVEMENT,
		"duration": duration,
		"title": title,
		"icon": "trophy",
		"data": {}
	})

	return id


## Show level up with star burst effect
func show_level_up(new_level: int, duration: float = 5.0) -> int:
	var id := _next_id
	_next_id += 1

	_queue.append({
		"id": id,
		"message": "You've reached a new level!",
		"type": ToastType.LEVEL_UP,
		"duration": duration,
		"title": "LEVEL %d" % new_level,
		"icon": "star",
		"data": {"level": new_level}
	})

	return id


## Show new item with 3D card flip reveal
func show_new_item(item_name: String, item_rarity: String = "common", duration: float = 5.0) -> int:
	var id := _next_id
	_next_id += 1

	var rarity_colors := {
		"common": Color(0.7, 0.7, 0.7),
		"uncommon": Color(0.3, 0.8, 0.3),
		"rare": Color(0.3, 0.5, 1.0),
		"epic": Color(0.7, 0.3, 1.0),
		"legendary": Color(1.0, 0.6, 0.1),
	}

	_queue.append({
		"id": id,
		"message": item_rarity.to_upper(),
		"type": ToastType.NEW_ITEM,
		"duration": duration,
		"title": item_name,
		"icon": "item",
		"data": {
			"rarity": item_rarity,
			"color": rarity_colors.get(item_rarity, Color.WHITE)
		}
	})

	return id


## Show challenge complete notification
func show_challenge_complete(challenge_name: String, reward: String = "", duration: float = 5.0) -> int:
	var id := _next_id
	_next_id += 1

	_queue.append({
		"id": id,
		"message": reward if not reward.is_empty() else "Challenge completed!",
		"type": ToastType.CHALLENGE_COMPLETE,
		"duration": duration,
		"title": challenge_name,
		"icon": "challenge",
		"data": {"reward": reward}
	})

	return id


## Dismiss a specific notification
func dismiss(notification_id: int) -> void:
	for toast in _active_toasts:
		if toast.get_meta("id", -1) == notification_id:
			_dismiss_toast(toast)
			break


## Dismiss all notifications
func dismiss_all() -> void:
	for toast in _active_toasts.duplicate():
		_dismiss_toast(toast)


# ============================================================================
# QUEUE PROCESSING
# ============================================================================

func _process_queue() -> void:
	if _queue.is_empty():
		return

	if _active_toasts.size() >= max_visible:
		return

	var data := _queue.pop_front() as Dictionary
	_show_toast(data)


func _show_toast(data: Dictionary) -> void:
	var toast: Control

	match data.type:
		ToastType.ACHIEVEMENT:
			toast = _create_achievement_toast(data)
		ToastType.LEVEL_UP:
			toast = _create_level_up_toast(data)
		ToastType.NEW_ITEM:
			toast = _create_new_item_toast(data)
		_:
			toast = _create_basic_toast(data)

	toast.set_meta("id", data.id)
	toast.set_meta("duration", data.duration)
	_container.add_child(toast)

	# Position and animate
	_position_toast(toast, _active_toasts.size())
	_active_toasts.append(toast)

	# Animate in
	await _animate_toast_in(toast, data.type)

	notification_shown.emit(data.id)

	# Start timer bar animation
	_animate_timer_bar(toast, data.duration)

	# Auto-dismiss
	await get_tree().create_timer(data.duration).timeout

	if is_instance_valid(toast) and toast.is_inside_tree():
		_dismiss_toast(toast)


func _position_toast(toast: Control, index: int) -> void:
	var screen_width := get_viewport().get_visible_rect().size.x
	var toast_width := toast.custom_minimum_size.x
	var y_offset := position_from_top + (index * (toast.custom_minimum_size.y + spacing))

	toast.position = Vector2((screen_width - toast_width) / 2, y_offset)


func _reposition_toasts() -> void:
	for i in range(_active_toasts.size()):
		var toast := _active_toasts[i]
		var target_y := position_from_top + (i * (toast.custom_minimum_size.y + spacing))

		var tween := create_tween()
		tween.tween_property(toast, "position:y", target_y, 0.2).set_ease(Tween.EASE_OUT)


# ============================================================================
# TOAST CREATION
# ============================================================================

func _create_basic_toast(data: Dictionary) -> Control:
	var toast := Control.new()
	toast.custom_minimum_size = Vector2(400, 80)
	toast.mouse_filter = Control.MOUSE_FILTER_STOP

	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = TYPE_COLORS[data.type].darkened(0.5)
	toast.add_child(bg)

	# Accent bar
	var accent := ColorRect.new()
	accent.size = Vector2(6, 80)
	accent.color = TYPE_COLORS[data.type]
	toast.add_child(accent)

	# Message
	var message := Label.new()
	message.text = data.message
	message.add_theme_font_size_override("font_size", 18)
	message.add_theme_color_override("font_color", Color.WHITE)
	message.position = Vector2(20, 28)
	message.size = Vector2(360, 30)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_child(message)

	# Timer bar
	var timer_bar := _create_timer_bar(TYPE_COLORS[data.type])
	toast.add_child(timer_bar)

	# Close button
	var close_btn := _create_close_button()
	close_btn.pressed.connect(func(): _dismiss_toast(toast))
	toast.add_child(close_btn)

	return toast


func _create_achievement_toast(data: Dictionary) -> Control:
	var toast := Control.new()
	toast.custom_minimum_size = Vector2(450, 100)
	toast.mouse_filter = Control.MOUSE_FILTER_STOP

	# Shader background for gold shine
	var shader_bg := ColorRect.new()
	shader_bg.name = "ShaderBG"
	shader_bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GOLD_SHINE_SHADER
	mat.shader = shader
	mat.set_shader_parameter("base_color", TYPE_COLORS[ToastType.ACHIEVEMENT].darkened(0.4))
	shader_bg.material = mat
	toast.add_child(shader_bg)

	# Trophy icon placeholder
	var icon := ColorRect.new()
	icon.size = Vector2(60, 60)
	icon.position = Vector2(15, 20)
	icon.color = TYPE_COLORS[ToastType.ACHIEVEMENT]
	toast.add_child(icon)

	# "ACHIEVEMENT UNLOCKED" header
	var header := Label.new()
	header.text = "ACHIEVEMENT UNLOCKED"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", TYPE_COLORS[ToastType.ACHIEVEMENT])
	header.position = Vector2(90, 15)
	toast.add_child(header)

	# Achievement title
	var title := Label.new()
	title.text = data.title
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(90, 35)
	toast.add_child(title)

	# Description
	var desc := Label.new()
	desc.text = data.message
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc.position = Vector2(90, 62)
	desc.size = Vector2(340, 25)
	toast.add_child(desc)

	# Timer bar
	var timer_bar := _create_timer_bar(TYPE_COLORS[ToastType.ACHIEVEMENT])
	toast.add_child(timer_bar)

	return toast


func _create_level_up_toast(data: Dictionary) -> Control:
	var toast := Control.new()
	toast.custom_minimum_size = Vector2(350, 120)
	toast.mouse_filter = Control.MOUSE_FILTER_STOP

	# Star burst shader background
	var shader_bg := ColorRect.new()
	shader_bg.name = "ShaderBG"
	shader_bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = STAR_BURST_SHADER
	mat.shader = shader
	mat.set_shader_parameter("color", TYPE_COLORS[ToastType.LEVEL_UP])
	shader_bg.material = mat
	toast.add_child(shader_bg)

	# Dark overlay for readability
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	toast.add_child(overlay)

	# "LEVEL UP!" header
	var header := Label.new()
	header.text = "LEVEL UP!"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", TYPE_COLORS[ToastType.LEVEL_UP])
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 20)
	header.size = Vector2(350, 25)
	toast.add_child(header)

	# Level number
	var level := Label.new()
	level.text = data.title
	level.add_theme_font_size_override("font_size", 48)
	level.add_theme_color_override("font_color", Color.WHITE)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.position = Vector2(0, 45)
	level.size = Vector2(350, 60)
	toast.add_child(level)

	# Timer bar
	var timer_bar := _create_timer_bar(TYPE_COLORS[ToastType.LEVEL_UP])
	toast.add_child(timer_bar)

	return toast


func _create_new_item_toast(data: Dictionary) -> Control:
	var toast := Control.new()
	toast.custom_minimum_size = Vector2(300, 150)
	toast.mouse_filter = Control.MOUSE_FILTER_STOP

	var item_color: Color = data.data.get("color", Color.WHITE)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.1, 0.15)
	toast.add_child(bg)

	# Item card (will be flipped)
	var card := Control.new()
	card.name = "ItemCard"
	card.custom_minimum_size = Vector2(80, 100)
	card.position = Vector2(110, 15)
	card.pivot_offset = Vector2(40, 50)
	toast.add_child(card)

	var card_bg := ColorRect.new()
	card_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_bg.color = item_color.darkened(0.3)
	card.add_child(card_bg)

	var card_border := ColorRect.new()
	card_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_border.offset_left = 2
	card_border.offset_top = 2
	card_border.offset_right = -2
	card_border.offset_bottom = -2
	card_border.color = item_color
	card.add_child(card_border)

	# "NEW ITEM" header
	var header := Label.new()
	header.text = "NEW ITEM"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", item_color)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 120)
	header.size = Vector2(300, 20)
	toast.add_child(header)

	# Item name
	var title := Label.new()
	title.text = data.title
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 135)
	title.size = Vector2(300, 20)
	toast.add_child(title)

	return toast


func _create_timer_bar(color: Color) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = "TimerBar"
	bar.size = Vector2(0, 4)  # Will be set to full width
	bar.position = Vector2(0, 0)  # Will be at bottom
	bar.color = color
	return bar


func _create_close_button() -> Button:
	var btn := Button.new()
	btn.text = "X"
	btn.custom_minimum_size = Vector2(24, 24)
	btn.position = Vector2(370, 5)
	btn.flat = true
	return btn


# ============================================================================
# ANIMATIONS
# ============================================================================

func _animate_toast_in(toast: Control, type: ToastType) -> void:
	var screen_width := get_viewport().get_visible_rect().size.x

	match type:
		ToastType.ACHIEVEMENT:
			# Slide from right with gold flash
			toast.position.x = screen_width + 50
			toast.modulate = Color(2, 1.5, 0.5)  # Golden flash

			var tween := create_tween()
			tween.set_parallel(true)
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_BACK)
			tween.tween_property(toast, "position:x", (screen_width - toast.custom_minimum_size.x) / 2, slide_duration * 1.5)
			tween.tween_property(toast, "modulate", Color.WHITE, 0.5)

			await tween.finished

		ToastType.LEVEL_UP:
			# Scale up from center with rotation
			toast.scale = Vector2(0.2, 0.2)
			toast.modulate.a = 0.0
			toast.pivot_offset = toast.custom_minimum_size / 2.0
			toast.rotation = deg_to_rad(-15)

			var tween := create_tween()
			tween.set_parallel(true)
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_ELASTIC)
			tween.tween_property(toast, "scale", Vector2(1.0, 1.0), 0.6)
			tween.tween_property(toast, "modulate:a", 1.0, 0.3)
			tween.tween_property(toast, "rotation", 0.0, 0.4)

			await tween.finished

		ToastType.NEW_ITEM:
			# Card flip reveal
			toast.modulate.a = 0.0
			var card: Control = toast.get_node_or_null("ItemCard")
			if card:
				card.scale.x = 0.0

			var tween := create_tween()
			tween.tween_property(toast, "modulate:a", 1.0, 0.2)

			await tween.finished

			if card:
				# Flip animation
				tween = create_tween()
				tween.set_ease(Tween.EASE_OUT)
				tween.set_trans(Tween.TRANS_BACK)
				tween.tween_property(card, "scale:x", 1.0, 0.4)

				await tween.finished

		_:
			# Standard slide from top
			toast.position.y -= 50
			toast.modulate.a = 0.0

			var tween := create_tween()
			tween.set_parallel(true)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(toast, "position:y", toast.position.y + 50, slide_duration)
			tween.tween_property(toast, "modulate:a", 1.0, slide_duration * 0.8)

			await tween.finished


func _animate_timer_bar(toast: Control, duration: float) -> void:
	var timer_bar: ColorRect = toast.get_node_or_null("TimerBar")
	if not timer_bar:
		return

	# Position at bottom
	timer_bar.position.y = toast.custom_minimum_size.y - 4
	timer_bar.size.x = toast.custom_minimum_size.x

	# Animate shrinking
	var tween := create_tween()
	tween.tween_property(timer_bar, "size:x", 0.0, duration)


func _dismiss_toast(toast: Control) -> void:
	if not is_instance_valid(toast):
		return

	var id: int = toast.get_meta("id", -1)

	# Animate out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "position:y", toast.position.y - 30, slide_duration)
	tween.tween_property(toast, "modulate:a", 0.0, slide_duration)

	await tween.finished

	_active_toasts.erase(toast)
	toast.queue_free()
	_reposition_toasts()

	notification_dismissed.emit(id)
