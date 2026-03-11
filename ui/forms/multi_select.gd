## Multi-Select - Checkbox list with animated selections, tags, and search
## Features: animated checkmarks, select all cascade, tag display, search filtering
extends Control
class_name MultiSelect

## Emitted when selection changes
signal selection_changed(selected_items: Array[String])
## Emitted when item is selected
signal item_selected(item: String)
## Emitted when item is deselected
signal item_deselected(item: String)

# Configuration
@export var items: Array[String] = []
@export var selected_items: Array[String] = []
@export var show_select_all: bool = true
@export var show_search: bool = true
@export var show_tags: bool = true
@export var max_visible_items: int = 6
@export var max_tags_shown: int = 3

# Visual
@export_group("Colors")
@export var background_color: Color = Color(0.12, 0.12, 0.16, 1.0)
@export var item_bg_color: Color = Color(0.15, 0.15, 0.2, 1.0)
@export var item_hover_color: Color = Color(0.2, 0.2, 0.25, 1.0)
@export var accent_color: Color = Color(0.3, 0.5, 1.0, 1.0)
@export var checkmark_color: Color = Color.WHITE
@export var text_color: Color = Color.WHITE
@export var tag_color: Color = Color(0.25, 0.35, 0.55, 1.0)

# Animation
@export_group("Animation")
@export var check_animation_duration: float = 0.25
@export var cascade_delay: float = 0.03
@export var tag_animation_duration: float = 0.2

# Internal nodes
var _container: VBoxContainer
var _search_container: Control
var _search_input: LineEdit
var _tags_container: HFlowContainer
var _select_all_btn: Button
var _items_scroll: ScrollContainer
var _items_list: VBoxContainer
var _count_label: Label

# State
var _filtered_items: Array[String] = []
var _item_controls: Dictionary = {}  # item -> Control
var _check_tweens: Dictionary = {}
var _is_all_selected: bool = false


func _ready() -> void:
	_filtered_items = items.duplicate()
	_setup_ui()
	_populate_items()
	_update_tags()
	_update_count_label()


func _setup_ui() -> void:
	custom_minimum_size = Vector2(300, 350)

	# Background
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = background_color
	bg_style.corner_radius_top_left = 12
	bg_style.corner_radius_top_right = 12
	bg_style.corner_radius_bottom_left = 12
	bg_style.corner_radius_bottom_right = 12
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	# Main container
	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.offset_left = 12
	_container.offset_right = -12
	_container.offset_top = 12
	_container.offset_bottom = -12
	_container.add_theme_constant_override("separation", 10)
	add_child(_container)

	# Tags display
	if show_tags:
		_setup_tags_section()

	# Search input
	if show_search:
		_setup_search_section()

	# Select all button
	if show_select_all:
		_setup_select_all()

	# Items list
	_setup_items_list()

	# Count label
	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.add_theme_font_size_override("font_size", 12)
	_count_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.6))
	_container.add_child(_count_label)


func _setup_tags_section() -> void:
	var tags_section := VBoxContainer.new()
	tags_section.add_theme_constant_override("separation", 5)
	_container.add_child(tags_section)

	var tags_label := Label.new()
	tags_label.text = "Selected"
	tags_label.add_theme_font_size_override("font_size", 11)
	tags_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.6))
	tags_section.add_child(tags_label)

	_tags_container = HFlowContainer.new()
	_tags_container.custom_minimum_size = Vector2(0, 35)
	_tags_container.add_theme_constant_override("h_separation", 6)
	_tags_container.add_theme_constant_override("v_separation", 6)
	tags_section.add_child(_tags_container)


func _setup_search_section() -> void:
	_search_container = Control.new()
	_search_container.custom_minimum_size = Vector2(0, 40)
	_container.add_child(_search_container)

	var search_bg := Panel.new()
	search_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = item_bg_color
	search_style.corner_radius_top_left = 8
	search_style.corner_radius_top_right = 8
	search_style.corner_radius_bottom_left = 8
	search_style.corner_radius_bottom_right = 8
	search_bg.add_theme_stylebox_override("panel", search_style)
	_search_container.add_child(search_bg)

	var search_icon := Label.new()
	search_icon.text = "O"
	search_icon.anchor_top = 0.0
	search_icon.anchor_bottom = 1.0
	search_icon.offset_left = 12
	search_icon.offset_right = 35
	search_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_icon.add_theme_font_size_override("font_size", 14)
	search_icon.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.5))
	_search_container.add_child(search_icon)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search items..."
	_search_input.anchor_left = 0.0
	_search_input.anchor_right = 1.0
	_search_input.anchor_top = 0.0
	_search_input.anchor_bottom = 1.0
	_search_input.offset_left = 35
	_search_input.offset_right = -10

	var input_style := StyleBoxEmpty.new()
	_search_input.add_theme_stylebox_override("normal", input_style)
	_search_input.add_theme_stylebox_override("focus", input_style)
	_search_input.add_theme_color_override("font_color", text_color)
	_search_input.add_theme_font_size_override("font_size", 14)
	_search_input.text_changed.connect(_on_search_changed)
	_search_container.add_child(_search_input)


func _setup_select_all() -> void:
	_select_all_btn = Button.new()
	_select_all_btn.text = "Select All"
	_select_all_btn.flat = true
	_select_all_btn.custom_minimum_size = Vector2(0, 30)
	_select_all_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_select_all_btn.add_theme_font_size_override("font_size", 13)
	_select_all_btn.add_theme_color_override("font_color", accent_color)
	_select_all_btn.pressed.connect(_toggle_select_all)
	_container.add_child(_select_all_btn)


func _setup_items_list() -> void:
	_items_scroll = ScrollContainer.new()
	_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items_scroll.custom_minimum_size = Vector2(0, 150)
	_container.add_child(_items_scroll)

	_items_list = VBoxContainer.new()
	_items_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_list.add_theme_constant_override("separation", 4)
	_items_scroll.add_child(_items_list)


func _populate_items() -> void:
	# Clear existing
	for child in _items_list.get_children():
		child.queue_free()
	_item_controls.clear()

	# Add items
	for item in _filtered_items:
		var item_control := _create_item_row(item)
		_items_list.add_child(item_control)
		_item_controls[item] = item_control


func _create_item_row(item: String) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, 40)
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	# Background
	var bg := Panel.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = item_bg_color
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg.add_theme_stylebox_override("panel", bg_style)
	row.add_child(bg)

	# Checkbox container
	var checkbox := Control.new()
	checkbox.name = "Checkbox"
	checkbox.anchor_top = 0.2
	checkbox.anchor_bottom = 0.8
	checkbox.offset_left = 10
	checkbox.offset_right = 34
	row.add_child(checkbox)

	# Checkbox background
	var check_bg := Panel.new()
	check_bg.name = "CheckBg"
	check_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var check_style := StyleBoxFlat.new()
	check_style.bg_color = Color(0.1, 0.1, 0.12, 1.0)
	check_style.corner_radius_top_left = 4
	check_style.corner_radius_top_right = 4
	check_style.corner_radius_bottom_left = 4
	check_style.corner_radius_bottom_right = 4
	check_style.border_width_left = 2
	check_style.border_width_right = 2
	check_style.border_width_top = 2
	check_style.border_width_bottom = 2
	check_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	check_bg.add_theme_stylebox_override("panel", check_style)
	checkbox.add_child(check_bg)

	# Checkmark (drawn)
	var checkmark := Control.new()
	checkmark.name = "Checkmark"
	checkmark.set_anchors_preset(Control.PRESET_FULL_RECT)
	checkmark.set_meta("progress", 0.0)
	checkmark.draw.connect(func() -> void: _draw_checkmark(checkmark))
	checkbox.add_child(checkmark)

	# Label
	var label := Label.new()
	label.name = "Label"
	label.text = item
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.0
	label.anchor_bottom = 1.0
	label.offset_left = 45
	label.offset_right = -10
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", text_color)
	row.add_child(label)

	# Set initial state
	var is_selected: bool = item in selected_items
	if is_selected:
		_update_checkbox_visual(row, true, false)

	# Connect input
	row.gui_input.connect(func(event: InputEvent) -> void: _on_item_input(item, row, event))
	row.mouse_entered.connect(func() -> void: _on_item_hover(row, true))
	row.mouse_exited.connect(func() -> void: _on_item_hover(row, false))

	return row


func _draw_checkmark(checkmark: Control) -> void:
	var progress: float = checkmark.get_meta("progress")
	if progress <= 0:
		return

	var size: Vector2 = checkmark.size
	var padding: float = 5.0

	# Checkmark path: two lines forming a check
	var start := Vector2(padding, size.y * 0.5)
	var mid := Vector2(size.x * 0.4, size.y - padding)
	var end_point := Vector2(size.x - padding, padding)

	# Calculate how much of each segment to draw
	var first_segment_length: float = start.distance_to(mid)
	var second_segment_length: float = mid.distance_to(end_point)
	var total_length: float = first_segment_length + second_segment_length

	var draw_length: float = total_length * progress

	if draw_length <= first_segment_length:
		# Only draw part of first segment
		var t: float = draw_length / first_segment_length
		var draw_end: Vector2 = start.lerp(mid, t)
		checkmark.draw_line(start, draw_end, checkmark_color, 2.5, true)
	else:
		# Draw full first segment and part of second
		checkmark.draw_line(start, mid, checkmark_color, 2.5, true)
		var remaining: float = draw_length - first_segment_length
		var t: float = remaining / second_segment_length
		var draw_end: Vector2 = mid.lerp(end_point, t)
		checkmark.draw_line(mid, draw_end, checkmark_color, 2.5, true)


func _on_item_input(item: String, row: Control, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_toggle_item(item, row)


func _on_item_hover(row: Control, hovering: bool) -> void:
	var bg: Panel = row.get_node("Background")
	var style: StyleBoxFlat = bg.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)

	if hovering:
		tween.tween_method(func(c: Color) -> void:
			style.bg_color = c
			bg.add_theme_stylebox_override("panel", style)
		, style.bg_color, item_hover_color, 0.15)
	else:
		tween.tween_method(func(c: Color) -> void:
			style.bg_color = c
			bg.add_theme_stylebox_override("panel", style)
		, style.bg_color, item_bg_color, 0.15)


func _toggle_item(item: String, row: Control) -> void:
	var is_selected: bool = item in selected_items

	if is_selected:
		selected_items.erase(item)
		_animate_checkbox(row, false)
		item_deselected.emit(item)
	else:
		selected_items.append(item)
		_animate_checkbox(row, true)
		item_selected.emit(item)

	_update_tags()
	_update_count_label()
	_update_select_all_state()
	selection_changed.emit(selected_items)


func _animate_checkbox(row: Control, checking: bool) -> void:
	var checkbox: Control = row.get_node("Checkbox")
	var check_bg: Panel = checkbox.get_node("CheckBg")
	var checkmark: Control = checkbox.get_node("Checkmark")

	var item_name: String = row.get_node("Label").text
	if _check_tweens.has(item_name):
		var old_tween: Tween = _check_tweens[item_name]
		if old_tween and old_tween.is_valid():
			old_tween.kill()

	var tween := create_tween()
	_check_tweens[item_name] = tween
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK if checking else Tween.TRANS_CUBIC)

	var style: StyleBoxFlat = check_bg.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	if checking:
		# Animate background color
		tween.tween_method(func(c: Color) -> void:
			style.bg_color = c
			style.border_color = accent_color
			check_bg.add_theme_stylebox_override("panel", style)
		, style.bg_color, accent_color, check_animation_duration)

		# Animate checkmark drawing
		tween.tween_method(func(p: float) -> void:
			checkmark.set_meta("progress", p)
			checkmark.queue_redraw()
		, 0.0, 1.0, check_animation_duration)

		# Scale pop
		checkbox.pivot_offset = checkbox.size * 0.5
		tween.tween_property(checkbox, "scale", Vector2(1.2, 1.2), check_animation_duration * 0.5)
		tween.chain().tween_property(checkbox, "scale", Vector2.ONE, check_animation_duration * 0.3)
	else:
		# Reverse animations
		tween.tween_method(func(c: Color) -> void:
			style.bg_color = c
			style.border_color = Color(0.3, 0.3, 0.35, 1.0)
			check_bg.add_theme_stylebox_override("panel", style)
		, style.bg_color, Color(0.1, 0.1, 0.12, 1.0), check_animation_duration * 0.7)

		tween.tween_method(func(p: float) -> void:
			checkmark.set_meta("progress", p)
			checkmark.queue_redraw()
		, 1.0, 0.0, check_animation_duration * 0.5)


func _update_checkbox_visual(row: Control, checked: bool, _animate: bool) -> void:
	var checkbox: Control = row.get_node("Checkbox")
	var check_bg: Panel = checkbox.get_node("CheckBg")
	var checkmark: Control = checkbox.get_node("Checkmark")

	var style: StyleBoxFlat = check_bg.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	if checked:
		style.bg_color = accent_color
		style.border_color = accent_color
		checkmark.set_meta("progress", 1.0)
	else:
		style.bg_color = Color(0.1, 0.1, 0.12, 1.0)
		style.border_color = Color(0.3, 0.3, 0.35, 1.0)
		checkmark.set_meta("progress", 0.0)

	check_bg.add_theme_stylebox_override("panel", style)
	checkmark.queue_redraw()


func _toggle_select_all() -> void:
	_is_all_selected = not _is_all_selected

	if _is_all_selected:
		# Select all with cascade animation
		var delay: float = 0.0
		for item in _filtered_items:
			if item not in selected_items:
				selected_items.append(item)

				var row: Control = _item_controls.get(item)
				if row:
					var tween := create_tween()
					tween.tween_interval(delay)
					tween.tween_callback(func() -> void: _animate_checkbox(row, true))
					delay += cascade_delay
	else:
		# Deselect all with cascade
		var delay: float = 0.0
		var to_deselect := selected_items.duplicate()
		selected_items.clear()

		for item in to_deselect:
			var row: Control = _item_controls.get(item)
			if row:
				var tween := create_tween()
				tween.tween_interval(delay)
				tween.tween_callback(func() -> void: _animate_checkbox(row, false))
				delay += cascade_delay

	_update_tags()
	_update_count_label()
	_update_select_all_state()
	selection_changed.emit(selected_items)


func _update_select_all_state() -> void:
	if not _select_all_btn:
		return

	_is_all_selected = selected_items.size() == _filtered_items.size() and selected_items.size() > 0
	_select_all_btn.text = "Deselect All" if _is_all_selected else "Select All"


func _on_search_changed(query: String) -> void:
	query = query.strip_edges().to_lower()

	if query.is_empty():
		_filtered_items = items.duplicate()
	else:
		_filtered_items.clear()
		for item in items:
			if item.to_lower().contains(query):
				_filtered_items.append(item)

	_populate_items()
	_update_select_all_state()


func _update_tags() -> void:
	if not _tags_container:
		return

	# Clear existing tags
	for child in _tags_container.get_children():
		child.queue_free()

	if selected_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "None selected"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.5))
		_tags_container.add_child(empty_label)
		return

	# Add tags
	var shown_count: int = mini(selected_items.size(), max_tags_shown)
	for i in range(shown_count):
		var tag := _create_tag(selected_items[i])
		_tags_container.add_child(tag)
		_animate_tag_in(tag, i * 0.05)

	# Show "+X more" if needed
	if selected_items.size() > max_tags_shown:
		var more_label := Label.new()
		more_label.text = "+%d more" % (selected_items.size() - max_tags_shown)
		more_label.add_theme_font_size_override("font_size", 12)
		more_label.add_theme_color_override("font_color", accent_color)
		_tags_container.add_child(more_label)


func _create_tag(item: String) -> Control:
	var tag := Control.new()
	tag.custom_minimum_size = Vector2(0, 28)

	# Background
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = tag_color
	bg_style.corner_radius_top_left = 14
	bg_style.corner_radius_top_right = 14
	bg_style.corner_radius_bottom_left = 14
	bg_style.corner_radius_bottom_right = 14
	bg.add_theme_stylebox_override("panel", bg_style)
	tag.add_child(bg)

	# Content row
	var content := HBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10
	content.offset_right = -5
	content.add_theme_constant_override("separation", 5)
	tag.add_child(content)

	# Label
	var label := Label.new()
	label.text = item
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", text_color)
	content.add_child(label)

	# Remove button
	var remove_btn := Button.new()
	remove_btn.text = "x"
	remove_btn.flat = true
	remove_btn.custom_minimum_size = Vector2(20, 20)
	remove_btn.add_theme_font_size_override("font_size", 10)
	remove_btn.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.7))
	remove_btn.pressed.connect(func() -> void: _remove_item(item, tag))
	content.add_child(remove_btn)

	# Calculate width
	tag.custom_minimum_size.x = label.get_minimum_size().x + 45

	return tag


func _animate_tag_in(tag: Control, delay: float) -> void:
	tag.modulate.a = 0.0
	tag.scale = Vector2(0.8, 0.8)
	tag.pivot_offset = tag.size * 0.5

	var tween := create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(tag, "modulate:a", 1.0, tag_animation_duration)
	tween.tween_property(tag, "scale", Vector2.ONE, tag_animation_duration)


func _remove_item(item: String, tag: Control) -> void:
	# Animate tag out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tag.pivot_offset = tag.size * 0.5
	tween.tween_property(tag, "modulate:a", 0.0, tag_animation_duration * 0.7)
	tween.tween_property(tag, "scale", Vector2(0.8, 0.8), tag_animation_duration * 0.7)
	tween.chain().tween_callback(tag.queue_free)

	# Update selection
	selected_items.erase(item)

	# Update checkbox
	var row: Control = _item_controls.get(item)
	if row:
		_animate_checkbox(row, false)

	# Delay tag update to let animation finish
	await get_tree().create_timer(tag_animation_duration).timeout
	_update_tags()
	_update_count_label()
	_update_select_all_state()

	item_deselected.emit(item)
	selection_changed.emit(selected_items)


func _update_count_label() -> void:
	if _count_label:
		_count_label.text = "%d of %d selected" % [selected_items.size(), items.size()]


# Public API
func get_selected_items() -> Array[String]:
	return selected_items.duplicate()


func set_selected_items(new_selection: Array[String]) -> void:
	selected_items = new_selection.duplicate()

	for item in items:
		var row: Control = _item_controls.get(item)
		if row:
			_update_checkbox_visual(row, item in selected_items, false)

	_update_tags()
	_update_count_label()
	_update_select_all_state()


func set_items(new_items: Array[String]) -> void:
	items = new_items.duplicate()
	_filtered_items = items.duplicate()
	selected_items.clear()
	_populate_items()
	_update_tags()
	_update_count_label()


func select_item(item: String) -> void:
	if item in items and item not in selected_items:
		selected_items.append(item)
		var row: Control = _item_controls.get(item)
		if row:
			_animate_checkbox(row, true)
		_update_tags()
		_update_count_label()
		_update_select_all_state()
		selection_changed.emit(selected_items)


func deselect_item(item: String) -> void:
	if item in selected_items:
		selected_items.erase(item)
		var row: Control = _item_controls.get(item)
		if row:
			_animate_checkbox(row, false)
		_update_tags()
		_update_count_label()
		_update_select_all_state()
		selection_changed.emit(selected_items)


func clear_selection() -> void:
	selected_items.clear()
	for item in items:
		var row: Control = _item_controls.get(item)
		if row:
			_update_checkbox_visual(row, false, false)
	_update_tags()
	_update_count_label()
	_update_select_all_state()
	selection_changed.emit(selected_items)


func select_all() -> void:
	if not _is_all_selected:
		_toggle_select_all()


func deselect_all() -> void:
	if _is_all_selected:
		_toggle_select_all()
