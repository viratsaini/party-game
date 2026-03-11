## HUDEditor - Drag-and-drop HUD layout customization system.
##
## Allows players to customize their HUD layout by dragging, resizing, and
## configuring individual HUD elements. Supports saving/loading layouts,
## preset configurations, and per-game-mode layouts.
extends CanvasLayer

# -- Signals --

## Emitted when a HUD element is selected.
signal element_selected(element_id: String)
## Emitted when a HUD element is moved.
signal element_moved(element_id: String, new_position: Vector2)
## Emitted when a HUD element is resized.
signal element_resized(element_id: String, new_size: Vector2)
## Emitted when element opacity changes.
signal element_opacity_changed(element_id: String, opacity: float)
## Emitted when element visibility changes.
signal element_visibility_changed(element_id: String, visible: bool)
## Emitted when layout is saved.
signal layout_saved(layout_name: String)
## Emitted when layout is loaded.
signal layout_loaded(layout_name: String)
## Emitted when edit mode changes.
signal edit_mode_changed(enabled: bool)

# -- Constants --

const LAYOUTS_PATH: String = "user://hud_layouts/"
const DEFAULT_LAYOUT_PATH: String = "user://hud_default_layout.cfg"
const GRID_SNAP_SIZE: int = 8
const MIN_ELEMENT_SIZE: Vector2 = Vector2(32, 32)
const MAX_ELEMENT_SIZE: Vector2 = Vector2(512, 512)

## Default HUD element configurations.
const DEFAULT_ELEMENTS: Dictionary = {
	"health_bar": {
		"name": "Health Bar",
		"position": Vector2(20, 20),
		"size": Vector2(200, 30),
		"anchor": "top_left",
		"opacity": 1.0,
		"visible": true,
		"locked": false,
	},
	"ammo_counter": {
		"name": "Ammo Counter",
		"position": Vector2(-120, -60),
		"size": Vector2(100, 50),
		"anchor": "bottom_right",
		"opacity": 1.0,
		"visible": true,
		"locked": false,
	},
	"minimap": {
		"name": "Minimap",
		"position": Vector2(-170, 20),
		"size": Vector2(150, 150),
		"anchor": "top_right",
		"opacity": 0.9,
		"visible": true,
		"locked": false,
	},
	"kill_feed": {
		"name": "Kill Feed",
		"position": Vector2(-250, 80),
		"size": Vector2(230, 150),
		"anchor": "top_right",
		"opacity": 0.85,
		"visible": true,
		"locked": false,
	},
	"timer": {
		"name": "Timer",
		"position": Vector2(0, 20),
		"size": Vector2(120, 40),
		"anchor": "top_center",
		"opacity": 1.0,
		"visible": true,
		"locked": false,
	},
	"score": {
		"name": "Score",
		"position": Vector2(0, 70),
		"size": Vector2(150, 35),
		"anchor": "top_center",
		"opacity": 1.0,
		"visible": true,
		"locked": false,
	},
	"crosshair": {
		"name": "Crosshair",
		"position": Vector2(0, 0),
		"size": Vector2(32, 32),
		"anchor": "center",
		"opacity": 1.0,
		"visible": true,
		"locked": true,  # Crosshair is locked to center
	},
	"damage_indicator": {
		"name": "Damage Indicator",
		"position": Vector2(0, 0),
		"size": Vector2(200, 200),
		"anchor": "center",
		"opacity": 0.8,
		"visible": true,
		"locked": true,
	},
	"jetpack_gauge": {
		"name": "Jetpack Gauge",
		"position": Vector2(20, -80),
		"size": Vector2(80, 60),
		"anchor": "bottom_left",
		"opacity": 1.0,
		"visible": true,
		"locked": false,
	},
	"weapon_display": {
		"name": "Weapon Display",
		"position": Vector2(-200, -120),
		"size": Vector2(180, 100),
		"anchor": "bottom_right",
		"opacity": 1.0,
		"visible": true,
		"locked": false,
	},
	"power_ups": {
		"name": "Active Power-Ups",
		"position": Vector2(20, 70),
		"size": Vector2(180, 40),
		"anchor": "top_left",
		"opacity": 0.9,
		"visible": true,
		"locked": false,
	},
	"teammate_status": {
		"name": "Team Status",
		"position": Vector2(20, 120),
		"size": Vector2(160, 100),
		"anchor": "top_left",
		"opacity": 0.85,
		"visible": true,
		"locked": false,
	},
	"chat_panel": {
		"name": "Chat",
		"position": Vector2(20, -200),
		"size": Vector2(300, 180),
		"anchor": "bottom_left",
		"opacity": 0.7,
		"visible": true,
		"locked": false,
	},
}

## Preset layouts.
const PRESET_LAYOUTS: Dictionary = {
	"Default": {},  # Uses DEFAULT_ELEMENTS as-is
	"Competitive": {
		"health_bar": {"size": Vector2(150, 25), "opacity": 0.95},
		"minimap": {"visible": false},
		"kill_feed": {"visible": false},
		"teammate_status": {"visible": false},
		"chat_panel": {"visible": false},
		"power_ups": {"size": Vector2(140, 30), "opacity": 0.8},
	},
	"Casual": {
		"health_bar": {"size": Vector2(220, 35)},
		"minimap": {"size": Vector2(180, 180)},
		"kill_feed": {"size": Vector2(260, 180)},
	},
	"Streaming": {
		"health_bar": {"position": Vector2(50, 50)},
		"minimap": {"position": Vector2(-200, 50), "size": Vector2(180, 180)},
		"chat_panel": {"visible": false},
		"kill_feed": {"position": Vector2(-280, 250)},
	},
	"Minimal": {
		"health_bar": {"size": Vector2(150, 20), "opacity": 0.7},
		"ammo_counter": {"size": Vector2(80, 40), "opacity": 0.7},
		"minimap": {"visible": false},
		"kill_feed": {"visible": false},
		"score": {"visible": false},
		"teammate_status": {"visible": false},
		"chat_panel": {"visible": false},
		"power_ups": {"opacity": 0.6},
		"jetpack_gauge": {"size": Vector2(60, 45), "opacity": 0.6},
	},
}

# -- Enums --

## Anchor positions for elements.
enum AnchorPoint {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	CENTER_LEFT,
	CENTER,
	CENTER_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT
}

## Resize handle positions.
enum ResizeHandle {
	NONE,
	TOP_LEFT,
	TOP,
	TOP_RIGHT,
	LEFT,
	RIGHT,
	BOTTOM_LEFT,
	BOTTOM,
	BOTTOM_RIGHT
}

# -- Exported Properties --

## Enable grid snapping.
@export var snap_to_grid: bool = true

## Grid snap size in pixels.
@export var grid_size: int = GRID_SNAP_SIZE

## Show grid overlay when editing.
@export var show_grid: bool = true

## Show element guides when dragging.
@export var show_guides: bool = true

## Allow resizing elements.
@export var allow_resize: bool = true

## Resize handle size.
@export var handle_size: int = 12

# -- State --

## Whether HUD editing is currently active.
var edit_mode: bool = false:
	set(value):
		edit_mode = value
		_update_edit_mode()
		edit_mode_changed.emit(value)

## Currently selected element ID.
var selected_element: String = "":
	set(value):
		selected_element = value
		_update_selection()
		element_selected.emit(value)

## Current element configurations.
var element_configs: Dictionary = {}

## Custom layouts saved by the user.
var custom_layouts: Dictionary = {}

## Current layout name.
var current_layout: String = "Default"

## Per-game-mode layouts.
var mode_layouts: Dictionary = {}

# -- Internal State --

var _editor_container: Control = null
var _grid_overlay: Control = null
var _element_overlays: Dictionary = {}  # element_id -> Control
var _guides_overlay: Control = null
var _properties_panel: Control = null

var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_element_start_pos: Vector2 = Vector2.ZERO
var _resize_handle: ResizeHandle = ResizeHandle.NONE
var _resize_start_size: Vector2 = Vector2.ZERO

var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
const MAX_UNDO_STEPS: int = 50


# -- Lifecycle --

func _ready() -> void:
	layer = 98  # Below screen reader, above HUD
	_ensure_layouts_directory()
	_load_element_configs()
	_load_custom_layouts()
	_create_editor_ui()


func _input(event: InputEvent) -> void:
	if not edit_mode:
		return

	if event is InputEventKey:
		_handle_keyboard_input(event as InputEventKey)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _ensure_layouts_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("hud_layouts"):
		dir.make_dir("hud_layouts")


# -- Public API: Edit Mode --

## Enter HUD edit mode.
func enter_edit_mode() -> void:
	edit_mode = true


## Exit HUD edit mode.
func exit_edit_mode() -> void:
	edit_mode = false
	selected_element = ""


## Toggle HUD edit mode.
func toggle_edit_mode() -> void:
	edit_mode = not edit_mode


# -- Public API: Element Management --

## Get element configuration.
func get_element_config(element_id: String) -> Dictionary:
	if element_configs.has(element_id):
		return element_configs[element_id].duplicate()
	elif DEFAULT_ELEMENTS.has(element_id):
		return DEFAULT_ELEMENTS[element_id].duplicate()
	return {}


## Set element position.
func set_element_position(element_id: String, position: Vector2) -> void:
	_save_undo_state()

	if not element_configs.has(element_id):
		element_configs[element_id] = DEFAULT_ELEMENTS.get(element_id, {}).duplicate()

	element_configs[element_id]["position"] = position
	_update_element_overlay(element_id)
	element_moved.emit(element_id, position)


## Set element size.
func set_element_size(element_id: String, size: Vector2) -> void:
	_save_undo_state()

	size = size.clamp(MIN_ELEMENT_SIZE, MAX_ELEMENT_SIZE)

	if not element_configs.has(element_id):
		element_configs[element_id] = DEFAULT_ELEMENTS.get(element_id, {}).duplicate()

	element_configs[element_id]["size"] = size
	_update_element_overlay(element_id)
	element_resized.emit(element_id, size)


## Set element opacity.
func set_element_opacity(element_id: String, opacity: float) -> void:
	opacity = clampf(opacity, 0.0, 1.0)

	if not element_configs.has(element_id):
		element_configs[element_id] = DEFAULT_ELEMENTS.get(element_id, {}).duplicate()

	element_configs[element_id]["opacity"] = opacity
	element_opacity_changed.emit(element_id, opacity)


## Set element visibility.
func set_element_visible(element_id: String, visible_flag: bool) -> void:
	if not element_configs.has(element_id):
		element_configs[element_id] = DEFAULT_ELEMENTS.get(element_id, {}).duplicate()

	element_configs[element_id]["visible"] = visible_flag
	_update_element_overlay(element_id)
	element_visibility_changed.emit(element_id, visible_flag)


## Toggle element visibility.
func toggle_element_visible(element_id: String) -> void:
	var config := get_element_config(element_id)
	set_element_visible(element_id, not config.get("visible", true))


## Set element anchor point.
func set_element_anchor(element_id: String, anchor: String) -> void:
	if not element_configs.has(element_id):
		element_configs[element_id] = DEFAULT_ELEMENTS.get(element_id, {}).duplicate()

	element_configs[element_id]["anchor"] = anchor
	_update_element_overlay(element_id)


## Lock/unlock element.
func set_element_locked(element_id: String, locked: bool) -> void:
	if not element_configs.has(element_id):
		element_configs[element_id] = DEFAULT_ELEMENTS.get(element_id, {}).duplicate()

	element_configs[element_id]["locked"] = locked


## Get all element IDs.
func get_all_element_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in DEFAULT_ELEMENTS.keys():
		ids.append(id)
	return ids


## Get element screen position (after anchor calculation).
func get_element_screen_position(element_id: String) -> Vector2:
	var config := get_element_config(element_id)
	if config.is_empty():
		return Vector2.ZERO

	var viewport_size := get_viewport().get_visible_rect().size
	var position: Vector2 = config.get("position", Vector2.ZERO)
	var anchor: String = config.get("anchor", "top_left")

	return _calculate_screen_position(position, anchor, viewport_size)


# -- Public API: Layout Management --

## Get available layout names.
func get_available_layouts() -> Array[String]:
	var layouts: Array[String] = []

	for name: String in PRESET_LAYOUTS.keys():
		layouts.append(name)

	for name: String in custom_layouts.keys():
		if name not in layouts:
			layouts.append(name)

	return layouts


## Get preset layout names.
func get_preset_layouts() -> Array[String]:
	var layouts: Array[String] = []
	for name: String in PRESET_LAYOUTS.keys():
		layouts.append(name)
	return layouts


## Get custom layout names.
func get_custom_layouts() -> Array[String]:
	var layouts: Array[String] = []
	for name: String in custom_layouts.keys():
		layouts.append(name)
	return layouts


## Apply a layout by name.
func apply_layout(layout_name: String) -> bool:
	var layout_data: Dictionary

	if layout_name in PRESET_LAYOUTS:
		layout_data = PRESET_LAYOUTS[layout_name]
	elif layout_name in custom_layouts:
		layout_data = custom_layouts[layout_name]
	else:
		push_warning("HUDEditor: Layout '%s' not found" % layout_name)
		return false

	_save_undo_state()

	# Start with default elements
	element_configs = {}
	for element_id: String in DEFAULT_ELEMENTS.keys():
		element_configs[element_id] = DEFAULT_ELEMENTS[element_id].duplicate()

	# Apply layout modifications
	for element_id: String in layout_data.keys():
		if element_configs.has(element_id):
			var mods: Dictionary = layout_data[element_id]
			for key: String in mods.keys():
				element_configs[element_id][key] = mods[key]

	current_layout = layout_name
	_update_all_overlays()
	layout_loaded.emit(layout_name)
	return true


## Save current configuration as a custom layout.
func save_layout(layout_name: String) -> bool:
	if layout_name in PRESET_LAYOUTS:
		push_warning("HUDEditor: Cannot overwrite preset layout '%s'" % layout_name)
		return false

	# Calculate differences from default
	var layout_data := {}
	for element_id: String in element_configs.keys():
		var config: Dictionary = element_configs[element_id]
		var default: Dictionary = DEFAULT_ELEMENTS.get(element_id, {})
		var diff := {}

		for key: String in config.keys():
			if not default.has(key) or config[key] != default[key]:
				diff[key] = config[key]

		if not diff.is_empty():
			layout_data[element_id] = diff

	custom_layouts[layout_name] = layout_data

	# Save to file
	var path := LAYOUTS_PATH + layout_name.to_lower().replace(" ", "_") + ".layout"
	var cfg := ConfigFile.new()

	for element_id: String in layout_data.keys():
		for key: String in (layout_data[element_id] as Dictionary).keys():
			cfg.set_value(element_id, key, (layout_data[element_id] as Dictionary)[key])

	var err := cfg.save(path)
	if err != OK:
		push_warning("HUDEditor: Failed to save layout '%s'" % layout_name)
		return false

	current_layout = layout_name
	layout_saved.emit(layout_name)
	return true


## Delete a custom layout.
func delete_layout(layout_name: String) -> bool:
	if layout_name not in custom_layouts:
		return false

	custom_layouts.erase(layout_name)

	var path := LAYOUTS_PATH + layout_name.to_lower().replace(" ", "_") + ".layout"
	var dir := DirAccess.open(LAYOUTS_PATH)
	if dir:
		dir.remove(path)

	if current_layout == layout_name:
		apply_layout("Default")

	return true


## Reset to default layout.
func reset_to_default() -> void:
	apply_layout("Default")


## Export layout to JSON.
func export_layout_json(layout_name: String = "") -> String:
	var data: Dictionary

	if layout_name.is_empty():
		data = element_configs.duplicate(true)
	elif layout_name in custom_layouts:
		data = custom_layouts[layout_name].duplicate(true)
	elif layout_name in PRESET_LAYOUTS:
		data = PRESET_LAYOUTS[layout_name].duplicate(true)
	else:
		return ""

	return JSON.stringify(_serialize_layout(data), "  ")


## Import layout from JSON.
func import_layout_json(json_string: String, layout_name: String) -> bool:
	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		return false

	var data: Variant = json.data
	if not data is Dictionary:
		return false

	custom_layouts[layout_name] = _deserialize_layout(data as Dictionary)
	return save_layout(layout_name)


# -- Public API: Game Mode Layouts --

## Set layout for a specific game mode.
func set_mode_layout(game_mode: String, layout_name: String) -> void:
	mode_layouts[game_mode] = layout_name
	_save_mode_layouts()


## Get layout for a game mode.
func get_mode_layout(game_mode: String) -> String:
	return mode_layouts.get(game_mode, "Default")


## Apply layout for current game mode.
func apply_mode_layout(game_mode: String) -> void:
	var layout_name := get_mode_layout(game_mode)
	apply_layout(layout_name)


# -- Public API: Undo/Redo --

## Undo last change.
func undo() -> void:
	if _undo_stack.is_empty():
		return

	_redo_stack.append(_get_current_state())
	var state: Dictionary = _undo_stack.pop_back()
	_restore_state(state)


## Redo last undone change.
func redo() -> void:
	if _redo_stack.is_empty():
		return

	_undo_stack.append(_get_current_state())
	var state: Dictionary = _redo_stack.pop_back()
	_restore_state(state)


## Check if undo is available.
func can_undo() -> bool:
	return not _undo_stack.is_empty()


## Check if redo is available.
func can_redo() -> bool:
	return not _redo_stack.is_empty()


# -- Internal Methods: Editor UI --

func _create_editor_ui() -> void:
	_editor_container = Control.new()
	_editor_container.name = "EditorContainer"
	_editor_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_editor_container.visible = false
	add_child(_editor_container)

	_create_grid_overlay()
	_create_guides_overlay()
	_create_element_overlays()


func _create_grid_overlay() -> void:
	_grid_overlay = Control.new()
	_grid_overlay.name = "GridOverlay"
	_grid_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_overlay.draw.connect(_draw_grid)
	_editor_container.add_child(_grid_overlay)


func _create_guides_overlay() -> void:
	_guides_overlay = Control.new()
	_guides_overlay.name = "GuidesOverlay"
	_guides_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guides_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guides_overlay.draw.connect(_draw_guides)
	_editor_container.add_child(_guides_overlay)


func _create_element_overlays() -> void:
	for element_id: String in DEFAULT_ELEMENTS.keys():
		_create_element_overlay(element_id)


func _create_element_overlay(element_id: String) -> void:
	var overlay := Control.new()
	overlay.name = "Overlay_" + element_id
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Store element ID in metadata
	overlay.set_meta("element_id", element_id)

	# Connect input handling
	overlay.gui_input.connect(_on_element_input.bind(element_id))

	_element_overlays[element_id] = overlay
	_editor_container.add_child(overlay)

	_update_element_overlay(element_id)


func _update_element_overlay(element_id: String) -> void:
	if not _element_overlays.has(element_id):
		return

	var overlay: Control = _element_overlays[element_id]
	var config := get_element_config(element_id)

	if config.is_empty():
		overlay.visible = false
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var position: Vector2 = config.get("position", Vector2.ZERO)
	var size: Vector2 = config.get("size", Vector2(100, 50))
	var anchor: String = config.get("anchor", "top_left")
	var visible_flag: bool = config.get("visible", true)

	var screen_pos := _calculate_screen_position(position, anchor, viewport_size)

	overlay.position = screen_pos - size / 2.0
	overlay.size = size
	overlay.visible = visible_flag

	overlay.queue_redraw()


func _update_all_overlays() -> void:
	for element_id: String in _element_overlays.keys():
		_update_element_overlay(element_id)


func _update_edit_mode() -> void:
	if _editor_container:
		_editor_container.visible = edit_mode

	if edit_mode:
		_update_all_overlays()
		if _grid_overlay:
			_grid_overlay.queue_redraw()


func _update_selection() -> void:
	for element_id: String in _element_overlays.keys():
		var overlay: Control = _element_overlays[element_id]
		overlay.queue_redraw()


# -- Internal Methods: Drawing --

func _draw_grid() -> void:
	if not show_grid or not _grid_overlay:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var grid_color := Color(1.0, 1.0, 1.0, 0.1)

	# Vertical lines
	var x := 0.0
	while x < viewport_size.x:
		_grid_overlay.draw_line(Vector2(x, 0), Vector2(x, viewport_size.y), grid_color)
		x += grid_size

	# Horizontal lines
	var y := 0.0
	while y < viewport_size.y:
		_grid_overlay.draw_line(Vector2(0, y), Vector2(viewport_size.x, y), grid_color)
		y += grid_size

	# Center lines (more visible)
	var center := viewport_size / 2.0
	var center_color := Color(1.0, 1.0, 1.0, 0.3)
	_grid_overlay.draw_line(Vector2(center.x, 0), Vector2(center.x, viewport_size.y), center_color)
	_grid_overlay.draw_line(Vector2(0, center.y), Vector2(viewport_size.x, center.y), center_color)


func _draw_guides() -> void:
	if not show_guides or not _is_dragging or selected_element.is_empty():
		return

	# Draw alignment guides when dragging
	# This would show lines when elements align with each other


func _on_element_overlay_draw(element_id: String) -> void:
	var overlay: Control = _element_overlays.get(element_id)
	if not overlay:
		return

	var config := get_element_config(element_id)
	var is_selected := element_id == selected_element
	var is_locked := config.get("locked", false)
	var is_visible := config.get("visible", true)

	# Background
	var bg_color := Color(0.2, 0.6, 1.0, 0.3) if is_selected else Color(0.5, 0.5, 0.5, 0.2)
	if not is_visible:
		bg_color = Color(0.5, 0.5, 0.5, 0.1)
	if is_locked:
		bg_color = Color(1.0, 0.3, 0.3, 0.2)

	overlay.draw_rect(Rect2(Vector2.ZERO, overlay.size), bg_color)

	# Border
	var border_color := Color(0.2, 0.8, 1.0, 1.0) if is_selected else Color(0.7, 0.7, 0.7, 0.5)
	if is_locked:
		border_color = Color(1.0, 0.5, 0.5, 0.8)

	overlay.draw_rect(Rect2(Vector2.ZERO, overlay.size), border_color, false, 2.0)

	# Element name label
	var name_str: String = config.get("name", element_id)
	# Note: Would need a font to draw text properly
	# overlay.draw_string(font, Vector2(5, 15), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	# Resize handles (if selected and not locked)
	if is_selected and not is_locked and allow_resize:
		_draw_resize_handles(overlay)


func _draw_resize_handles(overlay: Control) -> void:
	var size := overlay.size
	var handle_color := Color(1.0, 1.0, 1.0, 0.9)
	var hs := float(handle_size)

	# Corner handles
	overlay.draw_rect(Rect2(0, 0, hs, hs), handle_color)  # Top-left
	overlay.draw_rect(Rect2(size.x - hs, 0, hs, hs), handle_color)  # Top-right
	overlay.draw_rect(Rect2(0, size.y - hs, hs, hs), handle_color)  # Bottom-left
	overlay.draw_rect(Rect2(size.x - hs, size.y - hs, hs, hs), handle_color)  # Bottom-right

	# Edge handles
	var mid_x := (size.x - hs) / 2.0
	var mid_y := (size.y - hs) / 2.0
	overlay.draw_rect(Rect2(mid_x, 0, hs, hs), handle_color)  # Top
	overlay.draw_rect(Rect2(mid_x, size.y - hs, hs, hs), handle_color)  # Bottom
	overlay.draw_rect(Rect2(0, mid_y, hs, hs), handle_color)  # Left
	overlay.draw_rect(Rect2(size.x - hs, mid_y, hs, hs), handle_color)  # Right


# -- Internal Methods: Input Handling --

func _handle_keyboard_input(event: InputEventKey) -> void:
	if not event.pressed:
		return

	match event.keycode:
		KEY_ESCAPE:
			if selected_element.is_empty():
				exit_edit_mode()
			else:
				selected_element = ""
		KEY_DELETE:
			if not selected_element.is_empty():
				toggle_element_visible(selected_element)
		KEY_Z:
			if event.ctrl_pressed:
				if event.shift_pressed:
					redo()
				else:
					undo()
		KEY_Y:
			if event.ctrl_pressed:
				redo()
		KEY_S:
			if event.ctrl_pressed:
				save_layout(current_layout)
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			if not selected_element.is_empty():
				_nudge_element(selected_element, event.keycode, event.shift_pressed)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_interaction(event.position)
		else:
			_end_interaction()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_dragging and not selected_element.is_empty():
		_update_drag(event.position)


func _on_element_input(event: InputEvent, element_id: String) -> void:
	if not edit_mode:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var config := get_element_config(element_id)
			if not config.get("locked", false):
				selected_element = element_id
				_start_element_drag(element_id, mb.position)
				get_viewport().set_input_as_handled()


func _start_interaction(mouse_pos: Vector2) -> void:
	# Check if clicking on an element
	for element_id: String in _element_overlays.keys():
		var overlay: Control = _element_overlays[element_id]
		if overlay.visible and overlay.get_rect().has_point(mouse_pos):
			var config := get_element_config(element_id)
			if not config.get("locked", false):
				selected_element = element_id
				_start_element_drag(element_id, mouse_pos - overlay.position)
				return

	# Clicked empty space
	selected_element = ""


func _start_element_drag(element_id: String, local_pos: Vector2) -> void:
	var overlay: Control = _element_overlays[element_id]
	var config := get_element_config(element_id)

	_is_dragging = true
	_drag_start_pos = get_viewport().get_mouse_position()
	_drag_element_start_pos = config.get("position", Vector2.ZERO)

	# Check for resize handle
	_resize_handle = _get_resize_handle(local_pos, overlay.size)
	if _resize_handle != ResizeHandle.NONE:
		_resize_start_size = config.get("size", Vector2(100, 50))


func _update_drag(mouse_pos: Vector2) -> void:
	if selected_element.is_empty():
		return

	var delta := mouse_pos - _drag_start_pos

	if _resize_handle != ResizeHandle.NONE:
		_update_resize(delta)
	else:
		_update_position(delta)


func _update_position(delta: Vector2) -> void:
	var new_pos := _drag_element_start_pos + delta

	if snap_to_grid:
		new_pos.x = roundf(new_pos.x / grid_size) * grid_size
		new_pos.y = roundf(new_pos.y / grid_size) * grid_size

	set_element_position(selected_element, new_pos)


func _update_resize(delta: Vector2) -> void:
	var new_size := _resize_start_size

	match _resize_handle:
		ResizeHandle.RIGHT, ResizeHandle.TOP_RIGHT, ResizeHandle.BOTTOM_RIGHT:
			new_size.x += delta.x
		ResizeHandle.LEFT, ResizeHandle.TOP_LEFT, ResizeHandle.BOTTOM_LEFT:
			new_size.x -= delta.x

	match _resize_handle:
		ResizeHandle.BOTTOM, ResizeHandle.BOTTOM_LEFT, ResizeHandle.BOTTOM_RIGHT:
			new_size.y += delta.y
		ResizeHandle.TOP, ResizeHandle.TOP_LEFT, ResizeHandle.TOP_RIGHT:
			new_size.y -= delta.y

	if snap_to_grid:
		new_size.x = roundf(new_size.x / grid_size) * grid_size
		new_size.y = roundf(new_size.y / grid_size) * grid_size

	set_element_size(selected_element, new_size)


func _end_interaction() -> void:
	_is_dragging = false
	_resize_handle = ResizeHandle.NONE


func _get_resize_handle(local_pos: Vector2, size: Vector2) -> ResizeHandle:
	if not allow_resize:
		return ResizeHandle.NONE

	var hs := float(handle_size)

	# Check corners first
	if local_pos.x < hs and local_pos.y < hs:
		return ResizeHandle.TOP_LEFT
	if local_pos.x > size.x - hs and local_pos.y < hs:
		return ResizeHandle.TOP_RIGHT
	if local_pos.x < hs and local_pos.y > size.y - hs:
		return ResizeHandle.BOTTOM_LEFT
	if local_pos.x > size.x - hs and local_pos.y > size.y - hs:
		return ResizeHandle.BOTTOM_RIGHT

	# Check edges
	if local_pos.y < hs:
		return ResizeHandle.TOP
	if local_pos.y > size.y - hs:
		return ResizeHandle.BOTTOM
	if local_pos.x < hs:
		return ResizeHandle.LEFT
	if local_pos.x > size.x - hs:
		return ResizeHandle.RIGHT

	return ResizeHandle.NONE


func _nudge_element(element_id: String, keycode: int, large_step: bool) -> void:
	var config := get_element_config(element_id)
	var position: Vector2 = config.get("position", Vector2.ZERO)
	var step := 10.0 if large_step else 1.0

	match keycode:
		KEY_UP: position.y -= step
		KEY_DOWN: position.y += step
		KEY_LEFT: position.x -= step
		KEY_RIGHT: position.x += step

	set_element_position(element_id, position)


# -- Internal Methods: Position Calculation --

func _calculate_screen_position(position: Vector2, anchor: String, viewport_size: Vector2) -> Vector2:
	var base_pos := Vector2.ZERO

	match anchor:
		"top_left":
			base_pos = Vector2.ZERO
		"top_center":
			base_pos = Vector2(viewport_size.x / 2.0, 0)
		"top_right":
			base_pos = Vector2(viewport_size.x, 0)
		"center_left":
			base_pos = Vector2(0, viewport_size.y / 2.0)
		"center":
			base_pos = viewport_size / 2.0
		"center_right":
			base_pos = Vector2(viewport_size.x, viewport_size.y / 2.0)
		"bottom_left":
			base_pos = Vector2(0, viewport_size.y)
		"bottom_center":
			base_pos = Vector2(viewport_size.x / 2.0, viewport_size.y)
		"bottom_right":
			base_pos = viewport_size

	return base_pos + position


# -- Internal Methods: State Management --

func _save_undo_state() -> void:
	_undo_stack.append(_get_current_state())

	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.remove_at(0)

	_redo_stack.clear()


func _get_current_state() -> Dictionary:
	return element_configs.duplicate(true)


func _restore_state(state: Dictionary) -> void:
	element_configs = state.duplicate(true)
	_update_all_overlays()


# -- Internal Methods: Persistence --

func _load_element_configs() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(DEFAULT_LAYOUT_PATH)

	if err != OK:
		# Use defaults
		for element_id: String in DEFAULT_ELEMENTS.keys():
			element_configs[element_id] = DEFAULT_ELEMENTS[element_id].duplicate()
		return

	for element_id: String in cfg.get_sections():
		element_configs[element_id] = {}
		for key: String in cfg.get_section_keys(element_id):
			element_configs[element_id][key] = cfg.get_value(element_id, key)


func _load_custom_layouts() -> void:
	var dir := DirAccess.open(LAYOUTS_PATH)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".layout"):
			_load_layout_file(LAYOUTS_PATH + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()


func _load_layout_file(path: String) -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return

	var layout_data := {}
	for element_id: String in cfg.get_sections():
		layout_data[element_id] = {}
		for key: String in cfg.get_section_keys(element_id):
			layout_data[element_id][key] = cfg.get_value(element_id, key)

	var file_name := path.get_file().get_basename()
	var layout_name := file_name.replace("_", " ").capitalize()
	custom_layouts[layout_name] = layout_data


func _save_mode_layouts() -> void:
	var cfg := ConfigFile.new()
	for mode: String in mode_layouts.keys():
		cfg.set_value("modes", mode, mode_layouts[mode])
	cfg.save("user://hud_mode_layouts.cfg")


func _serialize_layout(data: Dictionary) -> Dictionary:
	var result := {}
	for element_id: String in data.keys():
		result[element_id] = {}
		for key: String in (data[element_id] as Dictionary).keys():
			var value: Variant = (data[element_id] as Dictionary)[key]
			if value is Vector2:
				result[element_id][key] = {"x": (value as Vector2).x, "y": (value as Vector2).y}
			else:
				result[element_id][key] = value
	return result


func _deserialize_layout(data: Dictionary) -> Dictionary:
	var result := {}
	for element_id: String in data.keys():
		result[element_id] = {}
		for key: String in (data[element_id] as Dictionary).keys():
			var value: Variant = (data[element_id] as Dictionary)[key]
			if value is Dictionary:
				var dict_val := value as Dictionary
				if dict_val.has("x") and dict_val.has("y"):
					result[element_id][key] = Vector2(dict_val["x"], dict_val["y"])
				else:
					result[element_id][key] = value
			else:
				result[element_id][key] = value
	return result
