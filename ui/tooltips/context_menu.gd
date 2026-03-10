## ContextMenu - Premium right-click context menu system
## Features: elastic animations, smooth sub-menus, keyboard shortcuts, disabled state tooltips
extends CanvasLayer

class_name ContextMenu

## Emitted when a menu item is selected
signal item_selected(item_id: String, item_data: Dictionary)
## Emitted when menu is closed
signal menu_closed

# =====================================================================
# CONFIGURATION
# =====================================================================

## Animation duration for menu appearance
@export var animation_duration: float = 0.25
## Sub-menu slide delay
@export var submenu_delay: float = 0.15
## Item height
@export var item_height: float = 36.0
## Menu padding
@export var menu_padding: Vector2 = Vector2(8, 8)
## Icon size
@export var icon_size: Vector2 = Vector2(20, 20)

# =====================================================================
# INTERNAL STATE
# =====================================================================

var _menu_container: Control
var _menu_stack: Array[Control] = []  # Stack of open menus
var _hover_item: Control = null
var _submenu_timer: float = 0.0
var _is_open: bool = false
var _close_tween: Tween = null

# Menu item colors
const COLOR_NORMAL := Color(0.15, 0.17, 0.22, 0.98)
const COLOR_HOVER := Color(0.25, 0.45, 0.75, 0.95)
const COLOR_DISABLED := Color(0.4, 0.4, 0.4, 0.6)
const COLOR_TEXT := Color(0.95, 0.95, 0.98, 1.0)
const COLOR_TEXT_DISABLED := Color(0.55, 0.55, 0.58, 0.8)
const COLOR_SHORTCUT := Color(0.6, 0.65, 0.75, 0.9)
const COLOR_SEPARATOR := Color(0.3, 0.35, 0.4, 0.6)

# =====================================================================
# LIFECYCLE
# =====================================================================

func _ready() -> void:
	layer = 101  # Above tooltips
	_menu_container = Control.new()
	_menu_container.name = "ContextMenuContainer"
	add_child(_menu_container)
	set_process(true)


func _process(delta: float) -> void:
	if not _is_open:
		return

	# Update submenu timer
	if _hover_item and _hover_item.has_meta("has_submenu") and _hover_item.get_meta("has_submenu"):
		_submenu_timer += delta
		if _submenu_timer >= submenu_delay:
			_open_submenu(_hover_item)
			_submenu_timer = 0.0


func _input(event: InputEvent) -> void:
	if not _is_open:
		return

	# Handle keyboard navigation
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				close_menu()
				get_viewport().set_input_as_handled()
			KEY_UP:
				_navigate_items(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_navigate_items(1)
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				_close_current_submenu()
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				if _hover_item and _hover_item.has_meta("has_submenu"):
					_open_submenu(_hover_item)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				if _hover_item:
					_select_item(_hover_item)
				get_viewport().set_input_as_handled()

	# Close on click outside
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _is_mouse_over_any_menu():
			close_menu()


# =====================================================================
# PUBLIC API
# =====================================================================

## Show context menu at position with items
## Item format: { "id": String, "text": String, "icon": String (optional),
##                "shortcut": String (optional), "disabled": bool (optional),
##                "disabled_reason": String (optional), "submenu": Array (optional) }
## Use { "separator": true } for separators
func show_menu(items: Array, position: Vector2 = Vector2.ZERO) -> void:
	close_menu()

	var menu_pos := position
	if position == Vector2.ZERO:
		menu_pos = get_viewport().get_mouse_position()

	var menu := _create_menu_panel(items)
	_menu_container.add_child(menu)
	_menu_stack.append(menu)

	# Position with screen bounds check
	_position_menu(menu, menu_pos)

	# Animate in
	_animate_menu_in(menu)

	_is_open = true


## Close all menus
func close_menu() -> void:
	if not _is_open:
		return

	_is_open = false

	# Animate out all menus
	for menu in _menu_stack:
		if is_instance_valid(menu):
			_animate_menu_out(menu)

	_menu_stack.clear()
	_hover_item = null

	menu_closed.emit()


## Create a reusable menu template
func create_menu_template(items: Array) -> Dictionary:
	return {
		"items": items,
		"created_at": Time.get_ticks_msec()
	}


# =====================================================================
# MENU CREATION
# =====================================================================

func _create_menu_panel(items: Array) -> Control:
	var panel := Panel.new()
	panel.name = "MenuPanel"
	_setup_menu_style(panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 2)
	panel.add_child(content)

	# Create items
	for item_data in items:
		if item_data.get("separator", false):
			content.add_child(_create_separator())
		else:
			content.add_child(_create_menu_item(item_data))

	# Calculate size
	await get_tree().process_frame
	var content_size := content.get_combined_minimum_size()
	panel.custom_minimum_size = content_size + menu_padding * 2
	panel.size = panel.custom_minimum_size

	content.position = menu_padding

	return panel


func _setup_menu_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_NORMAL
	style.border_color = Color(0.35, 0.4, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style.shadow_size = 12
	style.shadow_offset = Vector2(3, 6)
	panel.add_theme_stylebox_override("panel", style)


func _create_menu_item(item_data: Dictionary) -> Control:
	var item := Panel.new()
	item.name = "MenuItem_" + item_data.get("id", "unknown")
	item.custom_minimum_size.y = item_height
	item.mouse_filter = Control.MOUSE_FILTER_STOP

	# Store data
	item.set_meta("item_data", item_data)
	item.set_meta("has_submenu", item_data.has("submenu"))
	item.set_meta("is_disabled", item_data.get("disabled", false))

	# Setup style
	var is_disabled: bool = item_data.get("disabled", false)
	_setup_item_style(item, false, is_disabled)

	# Content layout
	var hbox := HBoxContainer.new()
	hbox.name = "Layout"
	hbox.add_theme_constant_override("separation", 10)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12
	hbox.offset_right = -12
	item.add_child(hbox)

	# Icon
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var icon_path: String = item_data.get("icon", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)

	if is_disabled:
		icon.modulate = COLOR_TEXT_DISABLED

	hbox.add_child(icon)

	# Text
	var label := Label.new()
	label.name = "Text"
	label.text = item_data.get("text", "Menu Item")
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_TEXT_DISABLED if is_disabled else COLOR_TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	# Shortcut or submenu arrow
	var right_content := Label.new()
	right_content.name = "RightContent"
	right_content.add_theme_font_size_override("font_size", 12)

	if item_data.has("submenu"):
		right_content.text = ">"
		right_content.add_theme_color_override("font_color", COLOR_TEXT)
	elif item_data.has("shortcut"):
		right_content.text = item_data.get("shortcut", "")
		right_content.add_theme_color_override("font_color", COLOR_SHORTCUT)

	hbox.add_child(right_content)

	# Hover highlight
	var highlight := ColorRect.new()
	highlight.name = "Highlight"
	highlight.color = Color(0, 0, 0, 0)
	highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.z_index = -1
	item.add_child(highlight)

	# Connect signals
	item.gui_input.connect(_on_item_input.bind(item))
	item.mouse_entered.connect(_on_item_hover.bind(item))
	item.mouse_exited.connect(_on_item_unhover.bind(item))

	return item


func _create_separator() -> Control:
	var separator := Control.new()
	separator.name = "Separator"
	separator.custom_minimum_size.y = 9

	var line := ColorRect.new()
	line.color = COLOR_SEPARATOR
	line.custom_minimum_size.y = 1
	line.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	line.anchor_top = 0.5
	line.anchor_bottom = 0.5
	line.offset_top = -0.5
	line.offset_bottom = 0.5
	line.offset_left = 8
	line.offset_right = -8
	separator.add_child(line)

	return separator


func _setup_item_style(item: Panel, hovered: bool, disabled: bool) -> void:
	var style := StyleBoxFlat.new()

	if disabled:
		style.bg_color = Color(0, 0, 0, 0)
	elif hovered:
		style.bg_color = COLOR_HOVER
	else:
		style.bg_color = Color(0, 0, 0, 0)

	style.set_corner_radius_all(4)
	item.add_theme_stylebox_override("panel", style)


# =====================================================================
# INTERACTION HANDLERS
# =====================================================================

func _on_item_input(event: InputEvent, item: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_item(item)


func _on_item_hover(item: Control) -> void:
	if item.get_meta("is_disabled", false):
		# Show disabled reason tooltip
		var reason: String = item.get_meta("item_data", {}).get("disabled_reason", "")
		if not reason.is_empty():
			_show_disabled_tooltip(item, reason)
		return

	_hover_item = item
	_submenu_timer = 0.0

	# Animate hover effect
	_animate_item_hover(item, true)

	# Close any submenus from other items
	_close_submenus_after_item(item)


func _on_item_unhover(item: Control) -> void:
	if _hover_item == item:
		_submenu_timer = 0.0

	if not item.get_meta("is_disabled", false):
		_animate_item_hover(item, false)


func _select_item(item: Control) -> void:
	if item.get_meta("is_disabled", false):
		return

	var item_data: Dictionary = item.get_meta("item_data", {})

	# If has submenu, open it
	if item_data.has("submenu"):
		_open_submenu(item)
		return

	# Emit selection and close
	item_selected.emit(item_data.get("id", ""), item_data)
	close_menu()


# =====================================================================
# SUBMENU HANDLING
# =====================================================================

func _open_submenu(parent_item: Control) -> void:
	var item_data: Dictionary = parent_item.get_meta("item_data", {})
	var submenu_items: Array = item_data.get("submenu", [])

	if submenu_items.is_empty():
		return

	# Find parent menu
	var parent_menu: Control = parent_item.get_parent().get_parent()
	var parent_index := _menu_stack.find(parent_menu)

	# Close any submenus after this one
	while _menu_stack.size() > parent_index + 1:
		var submenu: Control = _menu_stack.pop_back()
		if is_instance_valid(submenu):
			_animate_menu_out(submenu)

	# Create submenu
	var submenu := _create_menu_panel(submenu_items)
	_menu_container.add_child(submenu)
	_menu_stack.append(submenu)

	# Position to the right of parent item
	var pos := parent_item.global_position + Vector2(parent_menu.size.x - 4, -menu_padding.y)
	_position_menu(submenu, pos, true)

	# Animate in with slide
	_animate_submenu_in(submenu)


func _close_submenus_after_item(item: Control) -> void:
	var parent_menu: Control = item.get_parent().get_parent()
	var parent_index := _menu_stack.find(parent_menu)

	while _menu_stack.size() > parent_index + 1:
		var submenu: Control = _menu_stack.pop_back()
		if is_instance_valid(submenu):
			_animate_menu_out(submenu)


func _close_current_submenu() -> void:
	if _menu_stack.size() > 1:
		var submenu: Control = _menu_stack.pop_back()
		if is_instance_valid(submenu):
			_animate_menu_out(submenu)


# =====================================================================
# ANIMATIONS
# =====================================================================

func _animate_menu_in(menu: Control) -> void:
	menu.modulate.a = 0.0
	menu.scale = Vector2(0.9, 0.9)
	menu.pivot_offset = menu.size / 2

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(menu, "modulate:a", 1.0, animation_duration)
	tween.tween_property(menu, "scale", Vector2.ONE, animation_duration)


func _animate_submenu_in(menu: Control) -> void:
	menu.modulate.a = 0.0
	menu.position.x -= 20

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(menu, "modulate:a", 1.0, animation_duration * 0.8)
	tween.tween_property(menu, "position:x", menu.position.x + 20, animation_duration)


func _animate_menu_out(menu: Control) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(menu, "modulate:a", 0.0, animation_duration * 0.6)
	tween.tween_callback(menu.queue_free)


func _animate_item_hover(item: Control, entering: bool) -> void:
	var highlight: ColorRect = item.get_node_or_null("Highlight")
	if not highlight:
		return

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	if entering:
		# Slide-in highlight effect
		highlight.position.x = -10
		highlight.color = COLOR_HOVER
		highlight.color.a = 0.0

		tween.set_parallel(true)
		tween.tween_property(highlight, "position:x", 0.0, 0.15)
		tween.tween_property(highlight, "color:a", 1.0, 0.1)

		_setup_item_style(item, true, false)
	else:
		tween.tween_property(highlight, "color:a", 0.0, 0.1)
		_setup_item_style(item, false, false)


# =====================================================================
# UTILITY METHODS
# =====================================================================

func _position_menu(menu: Control, position: Vector2, is_submenu: bool = false) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var menu_size := menu.custom_minimum_size
	var margin := 10.0

	var final_pos := position

	# Check right edge
	if final_pos.x + menu_size.x > viewport_size.x - margin:
		if is_submenu:
			# Position to the left of parent instead
			final_pos.x = position.x - menu_size.x - menu_size.x + 8
		else:
			final_pos.x = viewport_size.x - menu_size.x - margin

	# Check bottom edge
	if final_pos.y + menu_size.y > viewport_size.y - margin:
		final_pos.y = viewport_size.y - menu_size.y - margin

	# Check left/top edges
	final_pos.x = maxf(final_pos.x, margin)
	final_pos.y = maxf(final_pos.y, margin)

	menu.position = final_pos


func _is_mouse_over_any_menu() -> bool:
	var mouse_pos := get_viewport().get_mouse_position()

	for menu in _menu_stack:
		if is_instance_valid(menu):
			var rect := Rect2(menu.global_position, menu.size)
			if rect.has_point(mouse_pos):
				return true

	return false


func _navigate_items(direction: int) -> void:
	if _menu_stack.is_empty():
		return

	var current_menu: Control = _menu_stack.back()
	var content: VBoxContainer = current_menu.get_node_or_null("Content")
	if not content:
		return

	var items: Array[Node] = []
	for child in content.get_children():
		if child.has_meta("item_data") and not child.get_meta("is_disabled", false):
			items.append(child)

	if items.is_empty():
		return

	var current_index := items.find(_hover_item)
	var new_index := wrapi(current_index + direction, 0, items.size())

	if _hover_item:
		_on_item_unhover(_hover_item)

	_hover_item = items[new_index] as Control
	_on_item_hover(_hover_item)


func _show_disabled_tooltip(item: Control, reason: String) -> void:
	# This would integrate with PremiumTooltip
	# For now, create a simple tooltip
	var tooltip := Label.new()
	tooltip.name = "DisabledTooltip"
	tooltip.text = reason
	tooltip.add_theme_font_size_override("font_size", 12)
	tooltip.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1.0))
	tooltip.position = item.global_position + Vector2(item.size.x + 10, 0)

	_menu_container.add_child(tooltip)

	# Auto-remove
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(tooltip, "modulate:a", 0.0, 0.3)
	tween.tween_callback(tooltip.queue_free)
