## File Uploader - Drag & drop with previews, progress, and smooth animations
## Features: drag zone highlight, upload progress, thumbnails, multi-file, retry
extends Control
class_name FileUploader

## Emitted when files are selected
signal files_selected(files: Array[String])
## Emitted when upload starts
signal upload_started(file_path: String)
## Emitted when upload progresses
signal upload_progress(file_path: String, progress: float)
## Emitted when upload completes
signal upload_completed(file_path: String)
## Emitted when upload fails
signal upload_failed(file_path: String, error: String)
## Emitted when file is removed
signal file_removed(file_path: String)

# Configuration
@export var allowed_extensions: Array[String] = ["png", "jpg", "jpeg", "gif", "webp"]
@export var max_file_size_mb: float = 10.0
@export var max_files: int = 10
@export var show_thumbnails: bool = true
@export var thumbnail_size: Vector2 = Vector2(80, 80)

# Visual
@export_group("Colors")
@export var background_color: Color = Color(0.12, 0.12, 0.16, 1.0)
@export var drop_zone_color: Color = Color(0.15, 0.15, 0.2, 1.0)
@export var drop_zone_highlight: Color = Color(0.3, 0.5, 1.0, 0.3)
@export var accent_color: Color = Color(0.3, 0.5, 1.0, 1.0)
@export var success_color: Color = Color(0.2, 0.8, 0.4, 1.0)
@export var error_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var text_color: Color = Color.WHITE

# Internal nodes
var _container: VBoxContainer
var _drop_zone: Control
var _drop_zone_panel: Panel
var _drop_icon: Label
var _drop_text: Label
var _drop_subtext: Label
var _browse_btn: Button
var _file_list: VBoxContainer
var _file_dialog: FileDialog

# State
var _files: Array[Dictionary] = []  # {path, name, size, status, progress, thumbnail}
var _is_dragging_over: bool = false
var _drop_highlight_tween: Tween


func _ready() -> void:
	_setup_ui()
	_setup_file_dialog()


func _setup_ui() -> void:
	custom_minimum_size = Vector2(350, 300)

	# Main container
	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.add_theme_constant_override("separation", 15)
	add_child(_container)

	# Drop zone
	_setup_drop_zone()

	# File list
	_setup_file_list()


func _setup_drop_zone() -> void:
	_drop_zone = Control.new()
	_drop_zone.custom_minimum_size = Vector2(0, 150)
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_container.add_child(_drop_zone)

	# Panel background
	_drop_zone_panel = Panel.new()
	_drop_zone_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = drop_zone_color
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.3)
	panel_style.set_border_width_all(2)
	# Dashed border effect (using dots pattern concept)
	_drop_zone_panel.add_theme_stylebox_override("panel", panel_style)
	_drop_zone.add_child(_drop_zone_panel)

	# Content container
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.grow_horizontal = Control.GROW_DIRECTION_BOTH
	content.grow_vertical = Control.GROW_DIRECTION_BOTH
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	_drop_zone.add_child(content)

	# Upload icon
	_drop_icon = Label.new()
	_drop_icon.text = "[^]"
	_drop_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_icon.add_theme_font_size_override("font_size", 40)
	_drop_icon.add_theme_color_override("font_color", accent_color)
	content.add_child(_drop_icon)

	# Main text
	_drop_text = Label.new()
	_drop_text.text = "Drag & drop files here"
	_drop_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_text.add_theme_font_size_override("font_size", 16)
	_drop_text.add_theme_color_override("font_color", text_color)
	content.add_child(_drop_text)

	# Sub text
	_drop_subtext = Label.new()
	_drop_subtext.text = "or"
	_drop_subtext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_subtext.add_theme_font_size_override("font_size", 12)
	_drop_subtext.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.6))
	content.add_child(_drop_subtext)

	# Browse button
	_browse_btn = Button.new()
	_browse_btn.text = "Browse Files"
	_browse_btn.custom_minimum_size = Vector2(120, 36)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = accent_color
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	_browse_btn.add_theme_stylebox_override("normal", btn_style)
	_browse_btn.add_theme_color_override("font_color", Color.WHITE)
	_browse_btn.add_theme_font_size_override("font_size", 14)
	_browse_btn.pressed.connect(_on_browse_pressed)
	content.add_child(_browse_btn)

	# Extensions hint
	var ext_label := Label.new()
	ext_label.text = "Allowed: " + ", ".join(allowed_extensions)
	ext_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ext_label.add_theme_font_size_override("font_size", 10)
	ext_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.4))
	content.add_child(ext_label)

	# Connect drop zone events
	_drop_zone.gui_input.connect(_on_drop_zone_input)


func _setup_file_list() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 100)
	_container.add_child(scroll)

	_file_list = VBoxContainer.new()
	_file_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_file_list)


func _setup_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.title = "Select Files"

	var filters: PackedStringArray = []
	for ext in allowed_extensions:
		filters.append("*." + ext)
	_file_dialog.filters = filters

	_file_dialog.files_selected.connect(_on_files_selected)
	add_child(_file_dialog)


func _on_browse_pressed() -> void:
	_file_dialog.popup_centered(Vector2i(600, 400))


func _on_drop_zone_input(event: InputEvent) -> void:
	# Handle visual feedback for hovering
	if event is InputEventMouseMotion:
		if not _is_dragging_over:
			_is_dragging_over = true
			_animate_drop_zone_highlight(true)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_browse_pressed()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_animate_drop_zone_highlight(true)
		NOTIFICATION_DRAG_END:
			_animate_drop_zone_highlight(false)


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("files"):
		return true
	return false


func _drop_data(_pos: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("files"):
		var files: Array = data["files"]
		_process_dropped_files(files)
	_animate_drop_zone_highlight(false)


func _animate_drop_zone_highlight(highlight: bool) -> void:
	if _drop_highlight_tween and _drop_highlight_tween.is_valid():
		_drop_highlight_tween.kill()

	_drop_highlight_tween = create_tween()
	_drop_highlight_tween.set_ease(Tween.EASE_OUT)
	_drop_highlight_tween.set_trans(Tween.TRANS_CUBIC)

	var style: StyleBoxFlat = _drop_zone_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	if highlight:
		_drop_highlight_tween.tween_method(func(alpha: float) -> void:
			style.bg_color = drop_zone_color.lerp(drop_zone_highlight, alpha)
			style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.3 + alpha * 0.7)
			_drop_zone_panel.add_theme_stylebox_override("panel", style)
		, 0.0, 1.0, 0.2)

		# Pulse icon
		_drop_highlight_tween.parallel().tween_property(_drop_icon, "scale", Vector2(1.15, 1.15), 0.2)
	else:
		_drop_highlight_tween.tween_method(func(alpha: float) -> void:
			style.bg_color = drop_zone_color.lerp(drop_zone_highlight, alpha)
			style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.3 + alpha * 0.7)
			_drop_zone_panel.add_theme_stylebox_override("panel", style)
		, 1.0, 0.0, 0.2)

		_drop_highlight_tween.parallel().tween_property(_drop_icon, "scale", Vector2.ONE, 0.2)

	_is_dragging_over = highlight


func _on_files_selected(paths: PackedStringArray) -> void:
	_process_dropped_files(Array(paths))


func _process_dropped_files(paths: Array) -> void:
	var added_paths: Array[String] = []

	for path: Variant in paths:
		var path_str: String = str(path)

		# Check extension
		var ext := path_str.get_extension().to_lower()
		if ext not in allowed_extensions:
			_show_file_error(path_str, "File type not allowed: " + ext)
			continue

		# Check if already added
		var already_exists := false
		for file in _files:
			if file.path == path_str:
				already_exists = true
				break
		if already_exists:
			continue

		# Check max files
		if _files.size() >= max_files:
			_show_file_error(path_str, "Maximum files reached (%d)" % max_files)
			break

		# Add file
		var file_info := {
			"path": path_str,
			"name": path_str.get_file(),
			"size": 0,  # Would need FileAccess to get actual size
			"status": "pending",  # pending, uploading, completed, error
			"progress": 0.0,
			"error": "",
			"thumbnail": null
		}

		_files.append(file_info)
		_add_file_item(file_info)
		added_paths.append(path_str)

	if added_paths.size() > 0:
		files_selected.emit(added_paths)


func _show_file_error(path: String, error: String) -> void:
	upload_failed.emit(path, error)
	# Could show a toast/notification here


func _add_file_item(file_info: Dictionary) -> void:
	var item := Control.new()
	item.name = file_info.path.md5_text()
	item.custom_minimum_size = Vector2(0, 70)
	_file_list.add_child(item)

	# Background
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg.add_theme_stylebox_override("panel", bg_style)
	item.add_child(bg)

	# Content row
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 8
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 12)
	item.add_child(row)

	# Thumbnail
	if show_thumbnails:
		var thumb := TextureRect.new()
		thumb.custom_minimum_size = thumbnail_size
		thumb.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Would load actual thumbnail here
		var placeholder := ColorRect.new()
		placeholder.color = Color(0.2, 0.2, 0.25, 1.0)
		placeholder.custom_minimum_size = thumbnail_size
		row.add_child(placeholder)

	# File info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = file_info.name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", text_color)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)

	# Progress bar
	var progress_container := Control.new()
	progress_container.custom_minimum_size = Vector2(0, 8)
	info.add_child(progress_container)

	var progress_bg := ColorRect.new()
	progress_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	progress_bg.color = Color(0.1, 0.1, 0.12, 1.0)
	progress_container.add_child(progress_bg)

	var progress_bar := ColorRect.new()
	progress_bar.name = "ProgressBar"
	progress_bar.anchor_right = 0.0
	progress_bar.anchor_bottom = 1.0
	progress_bar.color = accent_color
	progress_container.add_child(progress_bar)

	# Status label
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Ready to upload"
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.6))
	info.add_child(status_label)

	# Action buttons
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 5)
	row.add_child(actions)

	# Remove button
	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.custom_minimum_size = Vector2(30, 30)
	remove_btn.flat = true
	remove_btn.add_theme_font_size_override("font_size", 16)
	remove_btn.add_theme_color_override("font_color", error_color)
	remove_btn.pressed.connect(func() -> void: _remove_file(file_info.path))
	actions.add_child(remove_btn)

	# Animate entry
	item.modulate.a = 0.0
	item.position.x = 30

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(item, "modulate:a", 1.0, 0.3)
	tween.tween_property(item, "position:x", 0.0, 0.3)


func _remove_file(path: String) -> void:
	# Find and remove from array
	for i in range(_files.size() - 1, -1, -1):
		if _files[i].path == path:
			_files.remove_at(i)
			break

	# Animate out and remove node
	var item_name := path.md5_text()
	var item := _file_list.get_node_or_null(item_name)
	if item:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(item, "modulate:a", 0.0, 0.2)
		tween.tween_property(item, "position:x", -30.0, 0.2)
		tween.chain().tween_callback(item.queue_free)

	file_removed.emit(path)


func _update_file_progress(path: String, progress: float, status: String = "") -> void:
	var item_name := path.md5_text()
	var item := _file_list.get_node_or_null(item_name)
	if not item:
		return

	var progress_bar: ColorRect = item.get_node_or_null("ProgressBar")
	if progress_bar:
		var tween := create_tween()
		tween.tween_property(progress_bar, "anchor_right", progress, 0.15)

	if status.length() > 0:
		var status_label: Label = item.get_node_or_null("StatusLabel")
		if status_label:
			status_label.text = status


func _update_file_status(path: String, status: String, is_error: bool = false) -> void:
	var item_name := path.md5_text()
	var item := _file_list.get_node_or_null(item_name)
	if not item:
		return

	# Update status label
	for child in item.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is VBoxContainer:
					for info_child in sub.get_children():
						if info_child.name == "StatusLabel":
							var label: Label = info_child as Label
							label.text = status
							label.add_theme_color_override("font_color",
								error_color if is_error else
								success_color if status.to_lower().contains("complete") else
								Color(text_color.r, text_color.g, text_color.b, 0.6))


# Simulated upload for demo
func simulate_upload(path: String) -> void:
	upload_started.emit(path)

	# Find file index
	var file_idx := -1
	for i in range(_files.size()):
		if _files[i].path == path:
			file_idx = i
			break

	if file_idx < 0:
		return

	_files[file_idx].status = "uploading"
	_update_file_status(path, "Uploading...")

	# Simulate progress
	var progress := 0.0
	while progress < 1.0:
		await get_tree().create_timer(0.05).timeout
		progress += randf_range(0.02, 0.08)
		progress = minf(progress, 1.0)
		_files[file_idx].progress = progress
		_update_file_progress(path, progress, "Uploading... %d%%" % int(progress * 100))
		upload_progress.emit(path, progress)

	# Complete
	_files[file_idx].status = "completed"
	_update_file_status(path, "Upload complete!")
	_animate_completion(path)
	upload_completed.emit(path)


func _animate_completion(path: String) -> void:
	var item_name := path.md5_text()
	var item := _file_list.get_node_or_null(item_name)
	if not item:
		return

	# Flash green
	var bg: Panel = item.get_child(0) as Panel
	if bg:
		var style: StyleBoxFlat = bg.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		var original_color := style.bg_color

		var tween := create_tween()
		tween.tween_method(func(t: float) -> void:
			style.bg_color = original_color.lerp(Color(success_color.r, success_color.g, success_color.b, 0.3), t)
			bg.add_theme_stylebox_override("panel", style)
		, 0.0, 1.0, 0.2)
		tween.tween_method(func(t: float) -> void:
			style.bg_color = original_color.lerp(Color(success_color.r, success_color.g, success_color.b, 0.3), t)
			bg.add_theme_stylebox_override("panel", style)
		, 1.0, 0.0, 0.3)


# Public API
func get_files() -> Array[Dictionary]:
	return _files


func get_file_paths() -> Array[String]:
	var paths: Array[String] = []
	for file in _files:
		paths.append(file.path)
	return paths


func clear_files() -> void:
	for file in _files:
		var item_name := file.path.md5_text()
		var item := _file_list.get_node_or_null(item_name)
		if item:
			item.queue_free()
	_files.clear()


func remove_file(path: String) -> void:
	_remove_file(path)


func upload_all() -> void:
	for file in _files:
		if file.status == "pending":
			simulate_upload(file.path)


func retry_failed() -> void:
	for file in _files:
		if file.status == "error":
			file.status = "pending"
			file.progress = 0.0
			simulate_upload(file.path)
