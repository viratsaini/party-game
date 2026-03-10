## NotificationManager — Shows toast notifications and alerts
extends Node

signal notification_shown(message: String, type: String)

enum NotificationType {
	INFO,
	SUCCESS,
	WARNING,
	ERROR
}

const NOTIFICATION_SCENE: String = "res://ui/notifications/notification_toast.tscn"

var _active_notifications: Array[Control] = []

func show_notification(message: String, type: NotificationType = NotificationType.INFO, duration: float = 3.0) -> void:
	notification_shown.emit(message, NotificationType.keys()[type])
	_create_toast(message, type, duration)

func show_info(message: String, duration: float = 3.0) -> void:
	show_notification(message, NotificationType.INFO, duration)

func show_success(message: String, duration: float = 3.0) -> void:
	show_notification(message, NotificationType.SUCCESS, duration)

func show_warning(message: String, duration: float = 3.0) -> void:
	show_notification(message, NotificationType.WARNING, duration)

func show_error(message: String, duration: float = 4.0) -> void:
	show_notification(message, NotificationType.ERROR, duration)

func _create_toast(message: String, type: NotificationType, duration: float) -> void:
	# Create notification programmatically
	var toast := PanelContainer.new()
	toast.custom_minimum_size = Vector2(400, 80)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)

	# Set colors based on type
	var bg_color: Color
	var text_color: Color = Color.WHITE
	match type:
		NotificationType.INFO:
			bg_color = Color(0.2, 0.4, 0.8, 0.95)
		NotificationType.SUCCESS:
			bg_color = Color(0.2, 0.8, 0.4, 0.95)
		NotificationType.WARNING:
			bg_color = Color(0.9, 0.7, 0.2, 0.95)
		NotificationType.ERROR:
			bg_color = Color(0.8, 0.2, 0.2, 0.95)

	label.add_theme_color_override("font_color", text_color)

	# Create styled background
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	toast.add_theme_stylebox_override("panel", style)

	toast.add_child(label)

	# Add to scene tree
	var root: Window = get_tree().root
	root.add_child(toast)

	# Position at top center
	var screen_size: Vector2i = DisplayServer.window_get_size()
	var y_offset: float = 100.0 + (_active_notifications.size() * 90.0)
	toast.position = Vector2(
		(screen_size.x - toast.custom_minimum_size.x) / 2,
		y_offset
	)

	_active_notifications.append(toast)

	# Fade in animation
	toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.3)

	# Auto-remove after duration
	await get_tree().create_timer(duration).timeout

	# Fade out
	tween = create_tween()
	tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	await tween.finished

	_active_notifications.erase(toast)
	toast.queue_free()

	# Reposition remaining notifications
	_reposition_notifications()

func _reposition_notifications() -> void:
	for i in range(_active_notifications.size()):
		var toast: Control = _active_notifications[i]
		var screen_size: Vector2i = DisplayServer.window_get_size()
		var target_y: float = 100.0 + (i * 90.0)
		var tween := create_tween()
		tween.tween_property(toast, "position:y", target_y, 0.2)
