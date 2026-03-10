## Premium Search Bar - Expandable search with suggestions, history, and smooth animations
## Features: expand animation, suggestions dropdown, recent searches, loading spinner, voice UI
extends Control
class_name SearchBarPremium

## Emitted when search query changes
signal search_changed(query: String)
## Emitted when search is submitted
signal search_submitted(query: String)
## Emitted when suggestion is selected
signal suggestion_selected(suggestion: String)
## Emitted when voice search is activated
signal voice_search_activated
## Emitted when clear is pressed
signal search_cleared

# Configuration
@export var placeholder_text: String = "Search..."
@export var max_recent_searches: int = 5
@export var max_suggestions: int = 8
@export var search_delay: float = 0.3  # Debounce delay
@export var show_voice_button: bool = true
@export var show_recent_searches: bool = true
@export var expand_on_focus: bool = true

# Visual
@export_group("Colors")
@export var background_color: Color = Color(0.12, 0.12, 0.16, 1.0)
@export var input_bg_color: Color = Color(0.18, 0.18, 0.22, 1.0)
@export var accent_color: Color = Color(0.3, 0.5, 1.0, 1.0)
@export var text_color: Color = Color.WHITE
@export var placeholder_color: Color = Color(0.5, 0.5, 0.55, 1.0)

# Animation
@export_group("Animation")
@export var expand_duration: float = 0.25
@export var dropdown_duration: float = 0.2
@export var collapsed_width: float = 200.0
@export var expanded_width: float = 350.0

# Data
var suggestions: Array[String] = []
var recent_searches: Array[String] = []

# Internal nodes
var _container: Control
var _search_bg: Panel
var _search_icon: Label
var _input_field: LineEdit
var _clear_btn: Button
var _voice_btn: Button
var _loading_spinner: Control
var _results_badge: Label
var _dropdown: Control
var _dropdown_bg: Panel
var _dropdown_content: VBoxContainer
var _recent_section: VBoxContainer
var _suggestions_section: VBoxContainer

# State
var _is_focused: bool = false
var _is_loading: bool = false
var _is_expanded: bool = false
var _showing_dropdown: bool = false
var _search_timer: Timer
var _results_count: int = -1
var _spinner_tween: Tween

# Tweens
var _expand_tween: Tween
var _clear_tween: Tween
var _dropdown_tween: Tween


func _ready() -> void:
	_setup_ui()
	_setup_search_timer()
	_connect_signals()
	_load_recent_searches()


func _setup_ui() -> void:
	custom_minimum_size = Vector2(collapsed_width, 50)

	# Main container
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_container)

	# Search bar background
	_search_bg = Panel.new()
	_search_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_search_bg.anchor_bottom = 0.9
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = input_bg_color
	bg_style.corner_radius_top_left = 25
	bg_style.corner_radius_top_right = 25
	bg_style.corner_radius_bottom_left = 25
	bg_style.corner_radius_bottom_right = 25
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.0)
	_search_bg.add_theme_stylebox_override("panel", bg_style)
	_container.add_child(_search_bg)

	# Search icon
	_search_icon = Label.new()
	_search_icon.text = "O"  # Placeholder for search icon
	_search_icon.anchor_left = 0.0
	_search_icon.anchor_top = 0.0
	_search_icon.anchor_bottom = 0.9
	_search_icon.offset_left = 15
	_search_icon.offset_right = 40
	_search_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_search_icon.add_theme_font_size_override("font_size", 18)
	_search_icon.add_theme_color_override("font_color", placeholder_color)
	_container.add_child(_search_icon)

	# Input field
	_input_field = LineEdit.new()
	_input_field.placeholder_text = placeholder_text
	_input_field.anchor_left = 0.0
	_input_field.anchor_right = 1.0
	_input_field.anchor_top = 0.0
	_input_field.anchor_bottom = 0.9
	_input_field.offset_left = 45
	_input_field.offset_right = -90
	var input_style := StyleBoxEmpty.new()
	_input_field.add_theme_stylebox_override("normal", input_style)
	_input_field.add_theme_stylebox_override("focus", input_style)
	_input_field.add_theme_color_override("font_color", text_color)
	_input_field.add_theme_color_override("font_placeholder_color", placeholder_color)
	_input_field.add_theme_font_size_override("font_size", 15)
	_container.add_child(_input_field)

	# Loading spinner (hidden by default)
	_loading_spinner = Control.new()
	_loading_spinner.anchor_left = 1.0
	_loading_spinner.anchor_right = 1.0
	_loading_spinner.anchor_top = 0.0
	_loading_spinner.anchor_bottom = 0.9
	_loading_spinner.offset_left = -85
	_loading_spinner.offset_right = -60
	_loading_spinner.visible = false
	_loading_spinner.draw.connect(_draw_spinner)
	_container.add_child(_loading_spinner)

	# Clear button (hidden by default)
	_clear_btn = Button.new()
	_clear_btn.text = "X"
	_clear_btn.flat = true
	_clear_btn.anchor_left = 1.0
	_clear_btn.anchor_right = 1.0
	_clear_btn.anchor_top = 0.15
	_clear_btn.anchor_bottom = 0.75
	_clear_btn.offset_left = -55
	_clear_btn.offset_right = -30
	_clear_btn.add_theme_font_size_override("font_size", 14)
	_clear_btn.add_theme_color_override("font_color", placeholder_color)
	_clear_btn.modulate.a = 0.0
	_container.add_child(_clear_btn)

	# Voice button
	if show_voice_button:
		_voice_btn = Button.new()
		_voice_btn.text = "((o))"  # Placeholder for mic icon
		_voice_btn.flat = true
		_voice_btn.anchor_left = 1.0
		_voice_btn.anchor_right = 1.0
		_voice_btn.anchor_top = 0.15
		_voice_btn.anchor_bottom = 0.75
		_voice_btn.offset_left = -28
		_voice_btn.offset_right = -5
		_voice_btn.add_theme_font_size_override("font_size", 12)
		_voice_btn.add_theme_color_override("font_color", accent_color)
		_container.add_child(_voice_btn)

	# Results count badge (hidden by default)
	_results_badge = Label.new()
	_results_badge.anchor_left = 1.0
	_results_badge.anchor_top = 0.9
	_results_badge.offset_left = -80
	_results_badge.offset_top = 2
	_results_badge.add_theme_font_size_override("font_size", 11)
	_results_badge.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.6))
	_results_badge.visible = false
	_container.add_child(_results_badge)

	# Dropdown
	_setup_dropdown()


func _setup_dropdown() -> void:
	_dropdown = Control.new()
	_dropdown.anchor_top = 1.0
	_dropdown.anchor_left = 0.0
	_dropdown.anchor_right = 1.0
	_dropdown.offset_top = 5
	_dropdown.custom_minimum_size = Vector2(0, 200)
	_dropdown.visible = false
	_dropdown.z_index = 100
	add_child(_dropdown)

	# Dropdown background
	_dropdown_bg = Panel.new()
	_dropdown_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dropdown_style := StyleBoxFlat.new()
	dropdown_style.bg_color = background_color
	dropdown_style.corner_radius_top_left = 12
	dropdown_style.corner_radius_top_right = 12
	dropdown_style.corner_radius_bottom_left = 12
	dropdown_style.corner_radius_bottom_right = 12
	dropdown_style.shadow_color = Color(0, 0, 0, 0.3)
	dropdown_style.shadow_size = 8
	_dropdown_bg.add_theme_stylebox_override("panel", dropdown_style)
	_dropdown.add_child(_dropdown_bg)

	# Scroll container
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 10
	scroll.offset_right = -10
	scroll.offset_top = 10
	scroll.offset_bottom = -10
	_dropdown.add_child(scroll)

	# Content
	_dropdown_content = VBoxContainer.new()
	_dropdown_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dropdown_content.add_theme_constant_override("separation", 5)
	scroll.add_child(_dropdown_content)

	# Recent searches section
	_recent_section = VBoxContainer.new()
	_recent_section.add_theme_constant_override("separation", 3)
	_dropdown_content.add_child(_recent_section)

	# Suggestions section
	_suggestions_section = VBoxContainer.new()
	_suggestions_section.add_theme_constant_override("separation", 3)
	_dropdown_content.add_child(_suggestions_section)


func _setup_search_timer() -> void:
	_search_timer = Timer.new()
	_search_timer.wait_time = search_delay
	_search_timer.one_shot = true
	_search_timer.timeout.connect(_on_search_timer_timeout)
	add_child(_search_timer)


func _connect_signals() -> void:
	_input_field.focus_entered.connect(_on_focus_entered)
	_input_field.focus_exited.connect(_on_focus_exited)
	_input_field.text_changed.connect(_on_text_changed)
	_input_field.text_submitted.connect(_on_text_submitted)
	_clear_btn.pressed.connect(_on_clear_pressed)

	if _voice_btn:
		_voice_btn.pressed.connect(func() -> void: voice_search_activated.emit())


func _on_focus_entered() -> void:
	_is_focused = true

	# Animate border
	_animate_border_focus(true)

	# Expand
	if expand_on_focus:
		_expand_search_bar()

	# Show dropdown if we have content
	if _input_field.text.length() > 0 or (show_recent_searches and recent_searches.size() > 0):
		_show_dropdown()

	# Animate search icon
	var icon_tween := create_tween()
	icon_tween.tween_property(_search_icon, "modulate", accent_color, 0.2)


func _on_focus_exited() -> void:
	_is_focused = false

	# Animate border
	_animate_border_focus(false)

	# Collapse if empty
	if _input_field.text.is_empty() and expand_on_focus:
		_collapse_search_bar()

	# Hide dropdown after a delay (allows clicking suggestions)
	await get_tree().create_timer(0.2).timeout
	if not _is_focused:
		_hide_dropdown()

	# Reset search icon color
	var icon_tween := create_tween()
	icon_tween.tween_property(_search_icon, "modulate", Color.WHITE, 0.2)


func _on_text_changed(new_text: String) -> void:
	# Show/hide clear button
	_animate_clear_button(new_text.length() > 0)

	# Reset timer for debounce
	_search_timer.stop()
	if new_text.length() > 0:
		_search_timer.start()
		_show_loading(true)
	else:
		_show_loading(false)
		_update_dropdown_content()

	search_changed.emit(new_text)


func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return

	# Add to recent searches
	_add_to_recent_searches(text)

	# Hide dropdown
	_hide_dropdown()

	search_submitted.emit(text)


func _on_search_timer_timeout() -> void:
	# Simulate search completed (in real use, this would be called after API response)
	_show_loading(false)
	_update_suggestions_from_query(_input_field.text)


func _on_clear_pressed() -> void:
	_input_field.text = ""
	_input_field.grab_focus()
	_animate_clear_button(false)
	_results_count = -1
	_results_badge.visible = false
	_update_dropdown_content()
	search_cleared.emit()


func _animate_border_focus(focused: bool) -> void:
	var style: StyleBoxFlat = _search_bg.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	if focused:
		tween.tween_method(func(alpha: float) -> void:
			style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, alpha)
			_search_bg.add_theme_stylebox_override("panel", style)
		, 0.0, 0.8, 0.2)
	else:
		tween.tween_method(func(alpha: float) -> void:
			style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, alpha)
			_search_bg.add_theme_stylebox_override("panel", style)
		, 0.8, 0.0, 0.2)


func _expand_search_bar() -> void:
	if _is_expanded:
		return

	_is_expanded = true

	if _expand_tween and _expand_tween.is_valid():
		_expand_tween.kill()

	_expand_tween = create_tween()
	_expand_tween.set_ease(Tween.EASE_OUT)
	_expand_tween.set_trans(Tween.TRANS_BACK)
	_expand_tween.tween_property(self, "custom_minimum_size:x", expanded_width, expand_duration)


func _collapse_search_bar() -> void:
	if not _is_expanded:
		return

	_is_expanded = false

	if _expand_tween and _expand_tween.is_valid():
		_expand_tween.kill()

	_expand_tween = create_tween()
	_expand_tween.set_ease(Tween.EASE_OUT)
	_expand_tween.set_trans(Tween.TRANS_CUBIC)
	_expand_tween.tween_property(self, "custom_minimum_size:x", collapsed_width, expand_duration)


func _animate_clear_button(show: bool) -> void:
	if _clear_tween and _clear_tween.is_valid():
		_clear_tween.kill()

	_clear_tween = create_tween()
	_clear_tween.set_ease(Tween.EASE_OUT)

	if show:
		_clear_tween.tween_property(_clear_btn, "modulate:a", 1.0, 0.15)
	else:
		_clear_tween.tween_property(_clear_btn, "modulate:a", 0.0, 0.15)


func _show_loading(loading: bool) -> void:
	_is_loading = loading
	_loading_spinner.visible = loading

	if loading:
		_start_spinner_animation()
	else:
		_stop_spinner_animation()


func _start_spinner_animation() -> void:
	if _spinner_tween and _spinner_tween.is_valid():
		_spinner_tween.kill()

	_spinner_tween = create_tween()
	_spinner_tween.set_loops()
	_spinner_tween.tween_property(_loading_spinner, "rotation", TAU, 1.0)


func _stop_spinner_animation() -> void:
	if _spinner_tween and _spinner_tween.is_valid():
		_spinner_tween.kill()


func _draw_spinner() -> void:
	var center := Vector2(12, 12)
	var radius := 8.0
	var arc_length := PI * 1.5

	_loading_spinner.draw_arc(center, radius, 0, arc_length, 16, accent_color, 2.5)


func _show_dropdown() -> void:
	if _showing_dropdown:
		return

	_showing_dropdown = true
	_update_dropdown_content()

	_dropdown.visible = true
	_dropdown.modulate.a = 0.0
	_dropdown.position.y = -10

	if _dropdown_tween and _dropdown_tween.is_valid():
		_dropdown_tween.kill()

	_dropdown_tween = create_tween()
	_dropdown_tween.set_parallel(true)
	_dropdown_tween.set_ease(Tween.EASE_OUT)
	_dropdown_tween.set_trans(Tween.TRANS_BACK)
	_dropdown_tween.tween_property(_dropdown, "modulate:a", 1.0, dropdown_duration)
	_dropdown_tween.tween_property(_dropdown, "position:y", 5, dropdown_duration)


func _hide_dropdown() -> void:
	if not _showing_dropdown:
		return

	_showing_dropdown = false

	if _dropdown_tween and _dropdown_tween.is_valid():
		_dropdown_tween.kill()

	_dropdown_tween = create_tween()
	_dropdown_tween.set_parallel(true)
	_dropdown_tween.set_ease(Tween.EASE_IN)
	_dropdown_tween.tween_property(_dropdown, "modulate:a", 0.0, dropdown_duration * 0.7)
	_dropdown_tween.tween_property(_dropdown, "position:y", -10, dropdown_duration * 0.7)
	_dropdown_tween.chain().tween_callback(func() -> void: _dropdown.visible = false)


func _update_dropdown_content() -> void:
	# Clear existing content
	for child in _recent_section.get_children():
		child.queue_free()
	for child in _suggestions_section.get_children():
		child.queue_free()

	var query := _input_field.text.strip_edges()

	# Show recent searches if no query
	if query.is_empty() and show_recent_searches and recent_searches.size() > 0:
		var header := Label.new()
		header.text = "Recent Searches"
		header.add_theme_font_size_override("font_size", 11)
		header.add_theme_color_override("font_color", placeholder_color)
		_recent_section.add_child(header)

		for i in range(mini(recent_searches.size(), max_recent_searches)):
			var item := _create_dropdown_item(recent_searches[i], true)
			_recent_section.add_child(item)

	# Show suggestions if we have query
	elif query.length() > 0 and suggestions.size() > 0:
		var header := Label.new()
		header.text = "Suggestions"
		header.add_theme_font_size_override("font_size", 11)
		header.add_theme_color_override("font_color", placeholder_color)
		_suggestions_section.add_child(header)

		for i in range(mini(suggestions.size(), max_suggestions)):
			var item := _create_dropdown_item(suggestions[i], false)
			_suggestions_section.add_child(item)


func _create_dropdown_item(text: String, is_recent: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 35)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", text_color)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.15)
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.pressed.connect(func() -> void:
		_input_field.text = text
		_input_field.caret_column = text.length()
		_on_text_submitted(text)
		suggestion_selected.emit(text)
	)

	return btn


func _update_suggestions_from_query(_query: String) -> void:
	# In real implementation, this would filter/fetch suggestions
	_update_dropdown_content()

	if _is_focused:
		_show_dropdown()


func _add_to_recent_searches(query: String) -> void:
	# Remove if exists
	var idx := recent_searches.find(query)
	if idx >= 0:
		recent_searches.remove_at(idx)

	# Add to front
	recent_searches.insert(0, query)

	# Trim to max
	while recent_searches.size() > max_recent_searches:
		recent_searches.pop_back()

	_save_recent_searches()


func _load_recent_searches() -> void:
	# Would load from persistent storage in real implementation
	pass


func _save_recent_searches() -> void:
	# Would save to persistent storage in real implementation
	pass


# Public API
func get_query() -> String:
	return _input_field.text


func set_query(query: String) -> void:
	_input_field.text = query
	_animate_clear_button(query.length() > 0)


func clear() -> void:
	_on_clear_pressed()


func set_suggestions(new_suggestions: Array[String]) -> void:
	suggestions = new_suggestions
	_update_dropdown_content()


func set_results_count(count: int) -> void:
	_results_count = count
	if count >= 0:
		_results_badge.text = "%d results" % count
		_results_badge.visible = true
	else:
		_results_badge.visible = false


func focus() -> void:
	_input_field.grab_focus()


func is_searching() -> bool:
	return _is_loading


func clear_recent_searches() -> void:
	recent_searches.clear()
	_save_recent_searches()
	_update_dropdown_content()
