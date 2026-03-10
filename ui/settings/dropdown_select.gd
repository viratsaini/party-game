## DropdownSelect - Premium dropdown with smooth animations, search/filter, and polished feedback.
##
## Features:
## - Smooth expand/collapse animation
## - Hover highlight with glow
## - Selected item checkmark
## - Smooth scroll for long lists
## - Search/filter functionality
## - Keyboard navigation
## - Sound feedback
class_name DropdownSelect
extends Control

# ============================================================================ #
#                                   SIGNALS                                     #
# ============================================================================ #

## Emitted when an option is selected.
signal option_selected_signal(index: int)

## Emitted when dropdown opens.
signal opened

## Emitted when dropdown closes.
signal closed

# ============================================================================ #
#                                  CONSTANTS                                    #
# ============================================================================ #

const BUTTON_HEIGHT: float = 36.0
const ITEM_HEIGHT: float = 38.0
const MAX_VISIBLE_ITEMS: int = 7
const EXPAND_DURATION: float = 0.25
const ITEM_FADE_STAGGER: float = 0.03
const SEARCH_DEBOUNCE: float = 0.3
const SCROLL_SPEED: float = 40.0

const COLORS := {
	"button_bg": Color(0.15, 0.15, 0.18, 1.0),
	"button_border": Color(0.3, 0.3, 0.35, 1.0),
	"button_hover": Color(0.18, 0.18, 0.22, 1.0),
	"button_pressed": Color(0.12, 0.12, 0.15, 1.0),

	"dropdown_bg": Color(0.12, 0.12, 0.15, 0.98),
	"dropdown_border": Color(0.25, 0.25, 0.3, 1.0),

	"item_bg": Color(0.14, 0.14, 0.17, 1.0),
	"item_hover": Color(0.2, 0.5, 0.8, 0.3),
	"item_selected": Color(0.2, 0.6, 1.0, 0.2),
	"item_glow": Color(0.3, 0.7, 1.0, 0.4),

	"text_primary": Color(1.0, 1.0, 1.0, 1.0),
	"text_secondary": Color(0.7, 0.7, 0.75, 1.0),
	"text_disabled": Color(0.4, 0.4, 0.45, 1.0),

	"accent": Color(0.2, 0.6, 1.0, 1.0),
	"checkmark": Color(0.3, 0.9, 0.5, 1.0),
	"search_bg": Color(0.1, 0.1, 0.12, 1.0),
}

# ============================================================================ #
#                                  EXPORTS                                      #
# ============================================================================ #

## Setting key for change tracking.
@export var setting_key: String = ""

## Available options.
@export var options: Array = []:
	set(v):
		options = v
		_build_option_items()
		_update_display()

## Currently selected index.
@export var selected_index: int = 0:
	set(v):
		if v >= 0 and v < options.size():
			selected_index = v
			_update_display()
			option_selected_signal.emit(selected_index)

## Enable search/filter.
@export var enable_search: bool = true

## Placeholder text.
@export var placeholder_text: String = "Select..."

## Enable sound effects.
@export var enable_sounds: bool = true

## Disabled state.
@export var disabled: bool = false

# ============================================================================ #
#                                   STATE                                       #
# ============================================================================ #

## Whether dropdown is expanded.
var is_expanded: bool = false

## Current hover index (-1 = none).
var hover_index: int = -1

## Search filter string.
var search_filter: String = ""

## Filtered option indices.
var filtered_indices: Array[int] = []

## Scroll offset.
var scroll_offset: float = 0.0

## Target scroll offset.
var target_scroll_offset: float = 0.0

## Expand animation progress (0-1).
var expand_progress: float = 0.0

## Individual item fade progress.
var item_fade_progress: Array[float] = []

## Search debounce timer.
var search_debounce_timer: float = 0.0

# ============================================================================ #
#                                   NODES                                       #
# ============================================================================ #

var main_button: Control
var dropdown_panel: Control
var search_input: LineEdit
var items_container: Control
var scroll_bar: Control

# ============================================================================ #
#                                 LIFECYCLE                                     #
# ============================================================================ #

func _ready() -> void:
	custom_minimum_size = Vector2(180, BUTTON_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = false

	_build_ui()
	_build_option_items()
	_update_display()


func _process(delta: float) -> void:
	# Expand/collapse animation.
	var target_expand := 1.0 if is_expanded else 0.0
	expand_progress = lerpf(expand_progress, target_expand, 12.0 * delta)

	if abs(expand_progress - target_expand) < 0.01:
		expand_progress = target_expand
		if not is_expanded:
			dropdown_panel.visible = false

	# Item fade animation.
	if is_expanded:
		for i: int in item_fade_progress.size():
			var target_fade := 1.0 if i < filtered_indices.size() else 0.0
			var delay := float(i) * ITEM_FADE_STAGGER
			if expand_progress > delay:
				item_fade_progress[i] = lerpf(item_fade_progress[i], target_fade, 15.0 * delta)

	# Smooth scroll.
	scroll_offset = lerpf(scroll_offset, target_scroll_offset, 12.0 * delta)

	# Search debounce.
	if search_debounce_timer > 0:
		search_debounce_timer -= delta
		if search_debounce_timer <= 0:
			_apply_search_filter()

	queue_redraw()


func _draw() -> void:
	_draw_button()
	if expand_progress > 0.01:
		_draw_dropdown()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _is_point_in_button(event.position):
				_toggle_dropdown()
				get_viewport().set_input_as_handled()
			elif is_expanded:
				var item_index := _get_item_at_position(event.position)
				if item_index >= 0:
					_select_item(item_index)
					get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and is_expanded:
			target_scroll_offset = maxf(target_scroll_offset - SCROLL_SPEED, 0.0)
			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and is_expanded:
			var max_scroll := _get_max_scroll()
			target_scroll_offset = minf(target_scroll_offset + SCROLL_SPEED, max_scroll)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if is_expanded:
			hover_index = _get_item_at_position(event.position)

	elif event is InputEventKey and event.pressed:
		if has_focus() and not is_expanded:
			match event.keycode:
				KEY_SPACE, KEY_ENTER:
					_toggle_dropdown()
					get_viewport().set_input_as_handled()
				KEY_UP:
					_select_previous()
					get_viewport().set_input_as_handled()
				KEY_DOWN:
					_select_next()
					get_viewport().set_input_as_handled()
		elif is_expanded:
			match event.keycode:
				KEY_ESCAPE:
					_close_dropdown()
					get_viewport().set_input_as_handled()
				KEY_ENTER:
					if hover_index >= 0:
						_select_item(hover_index)
					get_viewport().set_input_as_handled()
				KEY_UP:
					_hover_previous()
					get_viewport().set_input_as_handled()
				KEY_DOWN:
					_hover_next()
					get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_EXIT:
			hover_index = -1
		NOTIFICATION_FOCUS_EXIT:
			if is_expanded:
				_close_dropdown()

# ============================================================================ #
#                                 UI BUILDING                                   #
# ============================================================================ #

func _build_ui() -> void:
	# Main button area is drawn, not a node.
	# Dropdown panel.
	dropdown_panel = Control.new()
	dropdown_panel.name = "DropdownPanel"
	dropdown_panel.visible = false
	dropdown_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dropdown_panel.z_index = 100
	add_child(dropdown_panel)


func _build_option_items() -> void:
	filtered_indices.clear()
	item_fade_progress.clear()

	for i: int in options.size():
		filtered_indices.append(i)
		item_fade_progress.append(0.0)

# ============================================================================ #
#                                  DRAWING                                      #
# ============================================================================ #

func _draw_button() -> void:
	var button_rect := Rect2(Vector2.ZERO, Vector2(size.x, BUTTON_HEIGHT))
	var corner_radius := 6.0

	# Background.
	var bg_color: Color
	if disabled:
		bg_color = COLORS["button_bg"].darkened(0.3)
	elif is_expanded:
		bg_color = COLORS["button_pressed"]
	else:
		bg_color = COLORS["button_bg"]

	_draw_rounded_rect(button_rect, corner_radius, bg_color)

	# Border.
	var border_color := COLORS["accent"] if is_expanded else COLORS["button_border"]
	if disabled:
		border_color = COLORS["text_disabled"]
	_draw_rounded_rect_outline(button_rect, corner_radius, border_color, 1.5)

	# Selected text.
	var font := ThemeDB.fallback_font
	var font_size := 13
	var text: String
	if selected_index >= 0 and selected_index < options.size():
		text = str(options[selected_index])
	else:
		text = placeholder_text

	var text_color := COLORS["text_primary"] if not disabled else COLORS["text_disabled"]
	var text_pos := Vector2(12, BUTTON_HEIGHT / 2 + font_size * 0.35)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, font_size, text_color)

	# Arrow icon.
	var arrow_x := size.x - 25
	var arrow_y := BUTTON_HEIGHT / 2
	var arrow_size := 6.0
	var arrow_rotation := expand_progress * PI

	var arrow_points: PackedVector2Array
	if arrow_rotation < 0.01:
		arrow_points = PackedVector2Array([
			Vector2(arrow_x - arrow_size, arrow_y - arrow_size / 2),
			Vector2(arrow_x, arrow_y + arrow_size / 2),
			Vector2(arrow_x + arrow_size, arrow_y - arrow_size / 2)
		])
	else:
		arrow_points = PackedVector2Array([
			Vector2(arrow_x - arrow_size, arrow_y + arrow_size / 2),
			Vector2(arrow_x, arrow_y - arrow_size / 2),
			Vector2(arrow_x + arrow_size, arrow_y + arrow_size / 2)
		])

	draw_polyline(arrow_points, text_color, 2.0, true)


func _draw_dropdown() -> void:
	var visible_count := mini(filtered_indices.size(), MAX_VISIBLE_ITEMS)
	var search_height := ITEM_HEIGHT if enable_search else 0.0
	var dropdown_height := search_height + visible_count * ITEM_HEIGHT
	var animated_height := dropdown_height * expand_progress

	var dropdown_rect := Rect2(
		Vector2(0, BUTTON_HEIGHT + 4),
		Vector2(size.x, animated_height)
	)
	var corner_radius := 6.0

	# Drop shadow.
	var shadow_rect := dropdown_rect.grow(2)
	shadow_rect.position.y += 3
	_draw_rounded_rect(shadow_rect, corner_radius + 2, Color(0, 0, 0, 0.3 * expand_progress))

	# Background.
	_draw_rounded_rect(dropdown_rect, corner_radius, COLORS["dropdown_bg"])
	_draw_rounded_rect_outline(dropdown_rect, corner_radius, COLORS["dropdown_border"], 1.0)

	# Clip content.
	if expand_progress < 0.99:
		return

	# Search bar.
	var content_y := dropdown_rect.position.y
	if enable_search:
		_draw_search_bar(Vector2(0, content_y), size.x)
		content_y += ITEM_HEIGHT

	# Items.
	var item_clip_rect := Rect2(
		Vector2(0, content_y),
		Vector2(size.x, visible_count * ITEM_HEIGHT)
	)

	for i: int in filtered_indices.size():
		var item_idx: int = filtered_indices[i]
		var item_y := content_y + i * ITEM_HEIGHT - scroll_offset

		# Skip if outside visible area.
		if item_y + ITEM_HEIGHT < content_y or item_y > item_clip_rect.end.y:
			continue

		var fade := item_fade_progress[i] if i < item_fade_progress.size() else 0.0
		_draw_item(item_idx, i, Vector2(0, item_y), fade)

	# Scroll indicators.
	if _get_max_scroll() > 0:
		_draw_scroll_indicators(item_clip_rect)


func _draw_search_bar(pos: Vector2, width: float) -> void:
	var search_rect := Rect2(pos + Vector2(8, 6), Vector2(width - 16, ITEM_HEIGHT - 12))

	# Background.
	_draw_rounded_rect(search_rect, 4.0, COLORS["search_bg"])

	# Search icon.
	var icon_x := search_rect.position.x + 10
	var icon_y := search_rect.position.y + search_rect.size.y / 2
	draw_circle(Vector2(icon_x, icon_y), 5, COLORS["text_secondary"])
	draw_line(
		Vector2(icon_x + 4, icon_y + 4),
		Vector2(icon_x + 8, icon_y + 8),
		COLORS["text_secondary"], 1.5, true
	)

	# Search text.
	var font := ThemeDB.fallback_font
	var font_size := 12
	var text := search_filter if not search_filter.is_empty() else "Search..."
	var text_color := COLORS["text_primary"] if not search_filter.is_empty() else COLORS["text_secondary"]

	draw_string(
		font,
		Vector2(icon_x + 16, icon_y + font_size * 0.35),
		text, HORIZONTAL_ALIGNMENT_LEFT, width - 50, font_size, text_color
	)


func _draw_item(option_index: int, visual_index: int, pos: Vector2, fade: float) -> void:
	if fade < 0.01:
		return

	var item_rect := Rect2(pos + Vector2(4, 2), Vector2(size.x - 8, ITEM_HEIGHT - 4))

	# Background.
	var bg_color := Color.TRANSPARENT
	if visual_index == hover_index:
		bg_color = COLORS["item_hover"]
		# Hover glow.
		var glow_rect := item_rect.grow(2)
		_draw_rounded_rect(glow_rect, 6.0, Color(COLORS["item_glow"], 0.2 * fade))
	elif option_index == selected_index:
		bg_color = COLORS["item_selected"]

	if bg_color.a > 0:
		_draw_rounded_rect(item_rect, 4.0, Color(bg_color, bg_color.a * fade))

	# Text.
	var font := ThemeDB.fallback_font
	var font_size := 13
	var text: String = str(options[option_index])
	var text_color := Color(COLORS["text_primary"], fade)

	var text_x := item_rect.position.x + 12
	if option_index == selected_index:
		text_x += 20  # Make room for checkmark.

	draw_string(
		font,
		Vector2(text_x, item_rect.position.y + ITEM_HEIGHT / 2 + font_size * 0.25),
		text, HORIZONTAL_ALIGNMENT_LEFT, item_rect.size.x - 30, font_size, text_color
	)

	# Checkmark for selected item.
	if option_index == selected_index:
		var check_x := item_rect.position.x + 8
		var check_y := item_rect.position.y + ITEM_HEIGHT / 2
		var check_color := Color(COLORS["checkmark"], fade)

		var check_points: PackedVector2Array = [
			Vector2(check_x, check_y),
			Vector2(check_x + 4, check_y + 4),
			Vector2(check_x + 10, check_y - 4)
		]
		draw_polyline(check_points, check_color, 2.0, true)


func _draw_scroll_indicators(clip_rect: Rect2) -> void:
	# Top fade if scrolled down.
	if scroll_offset > 0:
		var fade_rect := Rect2(clip_rect.position, Vector2(clip_rect.size.x, 20))
		var gradient_color := COLORS["dropdown_bg"]
		for i: int in 10:
			var y := clip_rect.position.y + i * 2
			var alpha := 1.0 - float(i) / 10.0
			draw_line(
				Vector2(0, y), Vector2(size.x, y),
				Color(gradient_color, alpha), 1.0
			)

	# Bottom fade if more content below.
	if scroll_offset < _get_max_scroll():
		for i: int in 10:
			var y := clip_rect.end.y - i * 2
			var alpha := 1.0 - float(i) / 10.0
			draw_line(
				Vector2(0, y), Vector2(size.x, y),
				Color(COLORS["dropdown_bg"], alpha), 1.0
			)


func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var inner_rect := Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2, rect.size.y)
	draw_rect(inner_rect, color)
	draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius * 2), color)

	draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.end.y - radius), radius, color)


func _draw_rounded_rect_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
	draw_line(Vector2(rect.position.x + radius, rect.position.y), Vector2(rect.end.x - radius, rect.position.y), color, width, true)
	draw_line(Vector2(rect.position.x + radius, rect.end.y), Vector2(rect.end.x - radius, rect.end.y), color, width, true)
	draw_line(Vector2(rect.position.x, rect.position.y + radius), Vector2(rect.position.x, rect.end.y - radius), color, width, true)
	draw_line(Vector2(rect.end.x, rect.position.y + radius), Vector2(rect.end.x, rect.end.y - radius), color, width, true)

	draw_arc(Vector2(rect.position.x + radius, rect.position.y + radius), radius, PI, PI * 1.5, 8, color, width, true)
	draw_arc(Vector2(rect.end.x - radius, rect.position.y + radius), radius, PI * 1.5, TAU, 8, color, width, true)
	draw_arc(Vector2(rect.position.x + radius, rect.end.y - radius), radius, PI * 0.5, PI, 8, color, width, true)
	draw_arc(Vector2(rect.end.x - radius, rect.end.y - radius), radius, 0, PI * 0.5, 8, color, width, true)

# ============================================================================ #
#                                  ACTIONS                                      #
# ============================================================================ #

func _toggle_dropdown() -> void:
	if is_expanded:
		_close_dropdown()
	else:
		_open_dropdown()


func _open_dropdown() -> void:
	is_expanded = true
	dropdown_panel.visible = true
	hover_index = selected_index
	search_filter = ""
	_build_option_items()
	scroll_offset = 0.0
	target_scroll_offset = 0.0

	# Ensure selected item is visible.
	_scroll_to_item(selected_index)

	_play_sound("dropdown_open")
	opened.emit()


func _close_dropdown() -> void:
	is_expanded = false
	hover_index = -1
	_play_sound("dropdown_close")
	closed.emit()


func _select_item(visual_index: int) -> void:
	if visual_index >= 0 and visual_index < filtered_indices.size():
		selected_index = filtered_indices[visual_index]
		_close_dropdown()
		_play_sound("dropdown_select")


func _select_previous() -> void:
	if options.size() > 0:
		selected_index = (selected_index - 1 + options.size()) % options.size()


func _select_next() -> void:
	if options.size() > 0:
		selected_index = (selected_index + 1) % options.size()


func _hover_previous() -> void:
	if filtered_indices.size() > 0:
		hover_index = (hover_index - 1 + filtered_indices.size()) % filtered_indices.size()
		_scroll_to_item(hover_index)
		_play_sound("hover")


func _hover_next() -> void:
	if filtered_indices.size() > 0:
		hover_index = (hover_index + 1) % filtered_indices.size()
		_scroll_to_item(hover_index)
		_play_sound("hover")


func _scroll_to_item(visual_index: int) -> void:
	if visual_index < 0:
		return

	var item_top := visual_index * ITEM_HEIGHT
	var item_bottom := item_top + ITEM_HEIGHT
	var visible_height := MAX_VISIBLE_ITEMS * ITEM_HEIGHT

	if item_top < target_scroll_offset:
		target_scroll_offset = item_top
	elif item_bottom > target_scroll_offset + visible_height:
		target_scroll_offset = item_bottom - visible_height


func _apply_search_filter() -> void:
	filtered_indices.clear()

	var filter_lower := search_filter.to_lower()

	for i: int in options.size():
		var option_text: String = str(options[i]).to_lower()
		if filter_lower.is_empty() or option_text.contains(filter_lower):
			filtered_indices.append(i)

	# Reset scroll.
	scroll_offset = 0.0
	target_scroll_offset = 0.0
	hover_index = 0 if filtered_indices.size() > 0 else -1

# ============================================================================ #
#                                  HELPERS                                      #
# ============================================================================ #

func _is_point_in_button(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, Vector2(size.x, BUTTON_HEIGHT)).has_point(point)


func _get_item_at_position(point: Vector2) -> int:
	if not is_expanded:
		return -1

	var content_y := BUTTON_HEIGHT + 4
	if enable_search:
		content_y += ITEM_HEIGHT

	for i: int in filtered_indices.size():
		var item_y := content_y + i * ITEM_HEIGHT - scroll_offset
		if point.y >= item_y and point.y < item_y + ITEM_HEIGHT:
			return i

	return -1


func _get_max_scroll() -> float:
	var total_height := filtered_indices.size() * ITEM_HEIGHT
	var visible_height := MAX_VISIBLE_ITEMS * ITEM_HEIGHT
	return maxf(0.0, total_height - visible_height)


func _update_display() -> void:
	queue_redraw()


func _play_sound(sound_name: String) -> void:
	if not enable_sounds:
		return

	if Engine.has_singleton("AudioManager"):
		var audio_manager := Engine.get_singleton("AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx("ui_%s" % sound_name)

# ============================================================================ #
#                                PUBLIC API                                     #
# ============================================================================ #

## Set options programmatically.
func set_options(new_options: Array) -> void:
	options = new_options


## Get selected option value.
func get_selected_value() -> Variant:
	if selected_index >= 0 and selected_index < options.size():
		return options[selected_index]
	return null


## Select by value.
func select_by_value(value: Variant) -> void:
	for i: int in options.size():
		if options[i] == value:
			selected_index = i
			return


## Set disabled state.
func set_disabled(is_disabled: bool) -> void:
	disabled = is_disabled
	if disabled and is_expanded:
		_close_dropdown()
	queue_redraw()
