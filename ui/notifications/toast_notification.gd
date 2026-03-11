## Premium toast notification system.
## Displays temporary messages with smooth animations and queueing.
## Features: multiple styles, icons, progress bar, stacking, auto-dismiss.
class_name ToastNotification
extends CanvasLayer

## Notification style presets.
enum ToastStyle {
	INFO,       ## Informational message.
	SUCCESS,    ## Success/completion message.
	WARNING,    ## Warning message.
	ERROR,      ## Error message.
	CUSTOM,     ## Custom styled message.
}

## Notification position on screen.
enum ToastPosition {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT,
	CENTER,
}

## Maximum number of simultaneous notifications.
const MAX_TOASTS: int = 5

## Vertical spacing between stacked toasts.
const TOAST_SPACING: float = 80.0

## Default display duration.
const DEFAULT_DURATION: float = 3.0

## Notification position.
@export var toast_position: ToastPosition = ToastPosition.TOP_RIGHT

## Enable sound effects.
@export var enable_sound: bool = true

## Active toast instances.
var _active_toasts: Array[Dictionary] = []

## Toast container.
var _container: Control = null


func _ready() -> void:
	# Create container for toast notifications.
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)


## Show a notification toast.
## [param message] Text message to display.
## [param style] Visual style preset.
## [param duration] Display duration in seconds (0 = permanent).
## [param icon] Optional icon texture.
func show_toast(message: String, style: ToastStyle = ToastStyle.INFO, duration: float = DEFAULT_DURATION, icon: Texture2D = null) -> void:
	# Check if at capacity.
	if _active_toasts.size() >= MAX_TOASTS:
		# Remove oldest toast.
		_dismiss_toast(_active_toasts[0])

	# Create toast panel.
	var toast_panel: PanelContainer = _create_toast_panel(message, style, icon)

	# Calculate position based on toast_position.
	var target_pos: Vector2 = _calculate_toast_position(_active_toasts.size())

	# Initial position (off-screen).
	var start_pos: Vector2 = target_pos + Vector2(400, 0)

	toast_panel.position = start_pos

	_container.add_child(toast_panel)

	# Create toast data.
	var toast_data: Dictionary = {
		"panel": toast_panel,
		"duration": duration,
		"elapsed": 0.0,
		"style": style,
		"dismissing": false,
	}

	_active_toasts.append(toast_data)

	# Animate entrance.
	_animate_toast_in(toast_panel, start_pos, target_pos)

	# Play sound.
	if enable_sound:
		_play_notification_sound(style)

	# Auto-dismiss after duration.
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		if is_instance_valid(toast_panel) and toast_data in _active_toasts:
			_dismiss_toast(toast_data)


## Create the visual toast panel.
func _create_toast_panel(message: String, style: ToastStyle, icon: Texture2D = null) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()

	# Apply style.
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = _get_style_color(style)
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.border_width_left = 3
	style_box.border_color = _get_style_color(style).lightened(0.3)
	style_box.content_margin_bottom = 12
	style_box.content_margin_left = 16
	style_box.content_margin_right = 16
	style_box.content_margin_top = 12
	style_box.shadow_size = 8
	style_box.shadow_color = Color(0, 0, 0, 0.4)

	panel.add_theme_stylebox_override("panel", style_box)

	# Create content layout.
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# Add icon if provided.
	if icon:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon_rect)

	# Add message label.
	var label: Label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(200, 0)
	hbox.add_child(label)

	# Add close button.
	var close_btn: Button = Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(func(): _dismiss_toast_by_panel(panel))
	hbox.add_child(close_btn)

	panel.add_child(hbox)

	return panel


## Get color for notification style.
func _get_style_color(style: ToastStyle) -> Color:
	match style:
		ToastStyle.INFO:
			return Color(0.2, 0.5, 0.9, 0.95)
		ToastStyle.SUCCESS:
			return Color(0.2, 0.7, 0.3, 0.95)
		ToastStyle.WARNING:
			return Color(0.9, 0.7, 0.2, 0.95)
		ToastStyle.ERROR:
			return Color(0.9, 0.2, 0.2, 0.95)
		ToastStyle.CUSTOM:
			return Color(0.3, 0.3, 0.3, 0.95)
		_:
			return Color(0.2, 0.5, 0.9, 0.95)


## Calculate toast position based on screen position and stack index.
func _calculate_toast_position(stack_index: int) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var base_pos: Vector2 = Vector2.ZERO
	var offset: Vector2 = Vector2(0, stack_index * TOAST_SPACING)

	match toast_position:
		ToastPosition.TOP_LEFT:
			base_pos = Vector2(20, 20) + offset
		ToastPosition.TOP_CENTER:
			base_pos = Vector2(viewport_size.x * 0.5 - 150, 20) + offset
		ToastPosition.TOP_RIGHT:
			base_pos = Vector2(viewport_size.x - 320, 20) + offset
		ToastPosition.BOTTOM_LEFT:
			base_pos = Vector2(20, viewport_size.y - 80 - stack_index * TOAST_SPACING)
		ToastPosition.BOTTOM_CENTER:
			base_pos = Vector2(viewport_size.x * 0.5 - 150, viewport_size.y - 80 - stack_index * TOAST_SPACING)
		ToastPosition.BOTTOM_RIGHT:
			base_pos = Vector2(viewport_size.x - 320, viewport_size.y - 80 - stack_index * TOAST_SPACING)
		ToastPosition.CENTER:
			base_pos = Vector2(viewport_size.x * 0.5 - 150, viewport_size.y * 0.5 - 40) + offset

	return base_pos


## Animate toast entrance.
func _animate_toast_in(panel: PanelContainer, start_pos: Vector2, target_pos: Vector2) -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	panel.modulate.a = 0.0
	tween.tween_property(panel, "position", target_pos, 0.4)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.3)


## Animate toast exit.
func _animate_toast_out(panel: PanelContainer) -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)

	var exit_pos: Vector2 = panel.position + Vector2(400, 0)
	tween.tween_property(panel, "position", exit_pos, 0.3)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.3)

	await tween.finished
	panel.queue_free()


## Dismiss a toast notification.
func _dismiss_toast(toast_data: Dictionary) -> void:
	if toast_data.get("dismissing", false):
		return

	toast_data["dismissing"] = true

	var panel: PanelContainer = toast_data.get("panel") as PanelContainer
	if is_instance_valid(panel):
		await _animate_toast_out(panel)

	_active_toasts.erase(toast_data)

	# Reposition remaining toasts.
	_reposition_toasts()


## Dismiss toast by panel reference.
func _dismiss_toast_by_panel(panel: PanelContainer) -> void:
	for toast_data: Dictionary in _active_toasts:
		if toast_data.get("panel") == panel:
			_dismiss_toast(toast_data)
			break


## Reposition all active toasts after dismissal.
func _reposition_toasts() -> void:
	for i: int in _active_toasts.size():
		var toast_data: Dictionary = _active_toasts[i]
		var panel: PanelContainer = toast_data.get("panel") as PanelContainer

		if is_instance_valid(panel):
			var target_pos: Vector2 = _calculate_toast_position(i)

			var tween: Tween = create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_QUAD)
			tween.tween_property(panel, "position", target_pos, 0.3)


## Play notification sound.
func _play_notification_sound(style: ToastStyle) -> void:
	if not has_node("/root/AudioManager"):
		return

	var audio_manager: Node = get_node("/root/AudioManager")
	match style:
		ToastStyle.SUCCESS:
			audio_manager.call("play_sfx", "ui_success")
		ToastStyle.WARNING:
			audio_manager.call("play_sfx", "ui_warning")
		ToastStyle.ERROR:
			audio_manager.call("play_sfx", "ui_error")
		_:
			audio_manager.call("play_sfx", "ui_notification")


## === CONVENIENCE METHODS ===

## Show info notification.
func show_info(message: String, duration: float = DEFAULT_DURATION) -> void:
	show_toast(message, ToastStyle.INFO, duration)


## Show success notification.
func show_success(message: String, duration: float = DEFAULT_DURATION) -> void:
	show_toast(message, ToastStyle.SUCCESS, duration)


## Show warning notification.
func show_warning(message: String, duration: float = DEFAULT_DURATION) -> void:
	show_toast(message, ToastStyle.WARNING, duration)


## Show error notification.
func show_error(message: String, duration: float = DEFAULT_DURATION) -> void:
	show_toast(message, ToastStyle.ERROR, duration)


## Clear all active toasts.
func clear_all() -> void:
	for toast_data: Dictionary in _active_toasts.duplicate():
		_dismiss_toast(toast_data)
