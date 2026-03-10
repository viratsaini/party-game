## InteractiveHelp - Comprehensive help system with search, bookmarks, and inline tutorials
## Features: hover help, video/GIF tutorials, search, bookmarking, bounce animations
extends CanvasLayer

class_name InteractiveHelp

## Emitted when help topic is opened
signal help_opened(topic_id: String)
## Emitted when help is closed
signal help_closed
## Emitted when topic is bookmarked
signal topic_bookmarked(topic_id: String, is_bookmarked: bool)

# =====================================================================
# CONFIGURATION
# =====================================================================

## Help panel width
@export var panel_width: float = 450.0
## Animation duration
@export var animation_duration: float = 0.3
## Bubble bounce height
@export var bubble_bounce_height: float = 8.0

# =====================================================================
# INTERNAL STATE
# =====================================================================

# UI Elements
var _help_panel: Panel
var _search_container: HBoxContainer
var _search_input: LineEdit
var _search_clear: Button
var _results_container: ScrollContainer
var _results_list: VBoxContainer
var _topic_view: VBoxContainer
var _topic_title: Label
var _topic_content: RichTextLabel
var _media_container: Control
var _related_topics: VBoxContainer
var _bookmark_button: Button
var _back_button: Button
var _close_button: Button

# Help bubbles on elements
var _help_bubbles: Dictionary = {}  # Control -> HelpBubble
var _active_bubble: Control = null

# Data
var _help_topics: Dictionary = {}  # topic_id -> topic_data
var _bookmarked_topics: Array[String] = []
var _search_index: Dictionary = {}  # word -> [topic_ids]
var _current_topic_id: String = ""
var _history: Array[String] = []

var _is_open: bool = false
var _help_mode: bool = false  # Hover over any element for help

# Tweens
var _panel_tween: Tween = null
var _bubble_tweens: Dictionary = {}

# =====================================================================
# LIFECYCLE
# =====================================================================

func _ready() -> void:
	layer = 98
	_create_help_ui()
	_hide_immediate()
	_load_bookmarks()


func _input(event: InputEvent) -> void:
	# F1 toggles help panel
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		if _is_open:
			close_help()
		else:
			open_help()
		get_viewport().set_input_as_handled()

	# Escape closes help
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _is_open:
			close_help()
			get_viewport().set_input_as_handled()


# =====================================================================
# UI CREATION
# =====================================================================

func _create_help_ui() -> void:
	# Main panel
	_help_panel = Panel.new()
	_help_panel.name = "HelpPanel"
	_help_panel.custom_minimum_size.x = panel_width
	_setup_panel_style(_help_panel)
	add_child(_help_panel)

	# Position on right side
	_help_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_help_panel.offset_left = -panel_width

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_help_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "MainLayout"
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	header.name = "Header"
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Help Center"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(32, 32)
	_close_button.pressed.connect(close_help)
	_setup_button_style(_close_button, Color(0.5, 0.3, 0.3, 0.9))
	header.add_child(_close_button)

	# Search area
	_search_container = HBoxContainer.new()
	_search_container.name = "SearchContainer"
	_search_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_search_container)

	_search_input = LineEdit.new()
	_search_input.name = "SearchInput"
	_search_input.placeholder_text = "Search help topics..."
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.text_changed.connect(_on_search_changed)
	_setup_line_edit_style(_search_input)
	_search_container.add_child(_search_input)

	_search_clear = Button.new()
	_search_clear.text = "Clear"
	_search_clear.visible = false
	_search_clear.pressed.connect(_clear_search)
	_setup_button_style(_search_clear, Color(0.4, 0.4, 0.45, 0.9))
	_search_container.add_child(_search_clear)

	# Navigation row (back button)
	var nav_row := HBoxContainer.new()
	nav_row.name = "NavRow"
	vbox.add_child(nav_row)

	_back_button = Button.new()
	_back_button.text = "< Back"
	_back_button.visible = false
	_back_button.pressed.connect(_go_back)
	_setup_button_style(_back_button, Color(0.3, 0.4, 0.5, 0.9))
	nav_row.add_child(_back_button)

	_bookmark_button = Button.new()
	_bookmark_button.text = "Bookmark"
	_bookmark_button.visible = false
	_bookmark_button.pressed.connect(_toggle_bookmark)
	_setup_button_style(_bookmark_button, Color(0.5, 0.4, 0.2, 0.9))
	nav_row.add_child(_bookmark_button)

	# Results/topic container
	_results_container = ScrollContainer.new()
	_results_container.name = "ResultsContainer"
	_results_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_results_container)

	_results_list = VBoxContainer.new()
	_results_list.name = "ResultsList"
	_results_list.add_theme_constant_override("separation", 8)
	_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_container.add_child(_results_list)

	# Topic view (hidden initially)
	_topic_view = VBoxContainer.new()
	_topic_view.name = "TopicView"
	_topic_view.visible = false
	_topic_view.add_theme_constant_override("separation", 16)
	_topic_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_container.add_child(_topic_view)

	_topic_title = Label.new()
	_topic_title.name = "TopicTitle"
	_topic_title.add_theme_font_size_override("font_size", 18)
	_topic_title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 1.0))
	_topic_view.add_child(_topic_title)

	# Media container for videos/GIFs
	_media_container = Control.new()
	_media_container.name = "MediaContainer"
	_media_container.custom_minimum_size.y = 200
	_media_container.visible = false
	_topic_view.add_child(_media_container)

	_topic_content = RichTextLabel.new()
	_topic_content.name = "TopicContent"
	_topic_content.bbcode_enabled = true
	_topic_content.fit_content = true
	_topic_content.scroll_active = false
	_topic_content.add_theme_font_size_override("normal_font_size", 14)
	_topic_content.add_theme_color_override("default_color", Color(0.8, 0.8, 0.85, 1.0))
	_topic_view.add_child(_topic_content)

	# Related topics section
	var related_label := Label.new()
	related_label.text = "Related Topics"
	related_label.add_theme_font_size_override("font_size", 16)
	related_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1.0))
	_topic_view.add_child(related_label)

	_related_topics = VBoxContainer.new()
	_related_topics.name = "RelatedTopics"
	_related_topics.add_theme_constant_override("separation", 4)
	_topic_view.add_child(_related_topics)


func _setup_panel_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.98)
	style.border_color = Color(0.25, 0.35, 0.5, 0.6)
	style.border_width_left = 2
	style.set_corner_radius_all(0)
	style.corner_radius_top_left = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 15
	style.shadow_offset = Vector2(-5, 0)
	panel.add_theme_stylebox_override("panel", style)


func _setup_button_style(button: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.1)
	button.add_theme_stylebox_override("pressed", pressed)


func _setup_line_edit_style(edit: LineEdit) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.17, 0.22, 1.0)
	style.border_color = Color(0.3, 0.35, 0.45, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	edit.add_theme_stylebox_override("normal", style)

	var focus := style.duplicate() as StyleBoxFlat
	focus.border_color = Color(0.4, 0.6, 0.9, 0.9)
	edit.add_theme_stylebox_override("focus", focus)


# =====================================================================
# PUBLIC API
# =====================================================================

## Register a help topic
## topic_data: { "title": String, "content": String (BBCode), "category": String,
##               "keywords": Array[String], "media_url": String (optional),
##               "related": Array[String] (topic_ids), "video_url": String (optional) }
func register_topic(topic_id: String, topic_data: Dictionary) -> void:
	_help_topics[topic_id] = topic_data

	# Build search index
	var keywords: Array = topic_data.get("keywords", [])
	keywords.append_array(topic_data.get("title", "").to_lower().split(" "))

	for keyword in keywords:
		var word: String = keyword.to_lower().strip_edges()
		if word.length() < 2:
			continue
		if not _search_index.has(word):
			_search_index[word] = []
		if topic_id not in _search_index[word]:
			_search_index[word].append(topic_id)


## Register help for a UI element
func register_element_help(element: Control, topic_id: String, quick_tip: String = "") -> void:
	if not _help_topics.has(topic_id) and quick_tip.is_empty():
		return

	# Create help bubble indicator
	var bubble := _create_help_bubble(element, topic_id, quick_tip)
	_help_bubbles[element] = bubble

	# Connect hover events
	element.mouse_entered.connect(_on_element_hover.bind(element))
	element.mouse_exited.connect(_on_element_unhover.bind(element))


## Open help panel
func open_help(topic_id: String = "") -> void:
	if _is_open:
		if not topic_id.is_empty():
			_show_topic(topic_id)
		return

	_is_open = true
	_help_panel.visible = true

	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()

	_help_panel.position.x = get_viewport().get_visible_rect().size.x

	_panel_tween = create_tween()
	_panel_tween.set_ease(Tween.EASE_OUT)
	_panel_tween.set_trans(Tween.TRANS_CUBIC)
	_panel_tween.tween_property(_help_panel, "position:x",
		get_viewport().get_visible_rect().size.x - panel_width, animation_duration)

	if not topic_id.is_empty():
		_show_topic(topic_id)
	else:
		_show_home()

	help_opened.emit(topic_id)


## Close help panel
func close_help() -> void:
	if not _is_open:
		return

	_is_open = false

	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()

	_panel_tween = create_tween()
	_panel_tween.set_ease(Tween.EASE_IN)
	_panel_tween.set_trans(Tween.TRANS_CUBIC)
	_panel_tween.tween_property(_help_panel, "position:x",
		get_viewport().get_visible_rect().size.x, animation_duration)
	_panel_tween.tween_callback(func() -> void: _help_panel.visible = false)

	help_closed.emit()


## Toggle help mode (hover any element for help)
func toggle_help_mode() -> void:
	_help_mode = not _help_mode

	# Show/hide all help bubbles
	for element in _help_bubbles:
		var bubble: Control = _help_bubbles[element]
		if is_instance_valid(bubble):
			bubble.visible = _help_mode
			if _help_mode:
				_animate_bubble_bounce(bubble)


## Search for topics
func search(query: String) -> Array:
	if query.strip_edges().is_empty():
		return _get_all_topics()

	var results: Dictionary = {}  # topic_id -> score
	var words := query.to_lower().split(" ")

	for word in words:
		word = word.strip_edges()
		if word.length() < 2:
			continue

		# Exact match
		if _search_index.has(word):
			for topic_id in _search_index[word]:
				results[topic_id] = results.get(topic_id, 0) + 10

		# Partial match
		for indexed_word in _search_index:
			if indexed_word.begins_with(word) or indexed_word.contains(word):
				for topic_id in _search_index[indexed_word]:
					results[topic_id] = results.get(topic_id, 0) + 3

	# Sort by score
	var sorted_results: Array = []
	for topic_id in results:
		sorted_results.append({"id": topic_id, "score": results[topic_id]})

	sorted_results.sort_custom(func(a, b): return a.score > b.score)

	var final_results: Array = []
	for item in sorted_results:
		final_results.append(item.id)

	return final_results


## Bookmark/unbookmark a topic
func toggle_topic_bookmark(topic_id: String) -> void:
	if topic_id in _bookmarked_topics:
		_bookmarked_topics.erase(topic_id)
		topic_bookmarked.emit(topic_id, false)
	else:
		_bookmarked_topics.append(topic_id)
		topic_bookmarked.emit(topic_id, true)

	_save_bookmarks()


## Get bookmarked topics
func get_bookmarks() -> Array[String]:
	return _bookmarked_topics


# =====================================================================
# INTERNAL METHODS
# =====================================================================

func _create_help_bubble(element: Control, topic_id: String, quick_tip: String) -> Control:
	var bubble := Panel.new()
	bubble.name = "HelpBubble_" + topic_id
	bubble.custom_minimum_size = Vector2(24, 24)
	bubble.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.9, 0.9)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.2, 0.5, 0.9, 0.4)
	style.shadow_size = 4
	bubble.add_theme_stylebox_override("panel", style)

	# Question mark icon
	var label := Label.new()
	label.text = "?"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble.add_child(label)

	# Store data
	bubble.set_meta("topic_id", topic_id)
	bubble.set_meta("quick_tip", quick_tip)

	# Position relative to element
	element.add_child(bubble)
	bubble.position = Vector2(element.size.x - 12, -12)

	# Click handler
	bubble.gui_input.connect(_on_bubble_input.bind(bubble, topic_id))

	return bubble


func _animate_bubble_bounce(bubble: Control) -> void:
	if _bubble_tweens.has(bubble):
		var old_tween: Tween = _bubble_tweens[bubble]
		if old_tween and old_tween.is_valid():
			old_tween.kill()

	var base_y := bubble.position.y

	var tween := create_tween()
	tween.set_loops()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(bubble, "position:y", base_y - bubble_bounce_height, 0.4)
	tween.tween_property(bubble, "position:y", base_y, 0.4)

	_bubble_tweens[bubble] = tween


func _show_home() -> void:
	_results_list.visible = true
	_topic_view.visible = false
	_back_button.visible = false
	_bookmark_button.visible = false
	_current_topic_id = ""

	# Clear and populate with categories/bookmarks
	_clear_results()

	# Bookmarks section
	if not _bookmarked_topics.is_empty():
		_add_section_header("Bookmarks")
		for topic_id in _bookmarked_topics:
			if _help_topics.has(topic_id):
				_add_topic_item(topic_id, _help_topics[topic_id])

	# All topics by category
	var categories: Dictionary = {}
	for topic_id in _help_topics:
		var topic: Dictionary = _help_topics[topic_id]
		var category: String = topic.get("category", "General")
		if not categories.has(category):
			categories[category] = []
		categories[category].append(topic_id)

	for category in categories:
		_add_section_header(category)
		for topic_id in categories[category]:
			_add_topic_item(topic_id, _help_topics[topic_id])


func _show_topic(topic_id: String) -> void:
	if not _help_topics.has(topic_id):
		return

	# Add to history
	if _current_topic_id and _current_topic_id != topic_id:
		_history.append(_current_topic_id)

	_current_topic_id = topic_id
	var topic: Dictionary = _help_topics[topic_id]

	_results_list.visible = false
	_topic_view.visible = true
	_back_button.visible = _history.size() > 0
	_bookmark_button.visible = true
	_bookmark_button.text = "Unbookmark" if topic_id in _bookmarked_topics else "Bookmark"

	_topic_title.text = topic.get("title", "Help Topic")
	_topic_content.text = topic.get("content", "")

	# Handle media
	var media_url: String = topic.get("media_url", "")
	var video_url: String = topic.get("video_url", "")

	if not media_url.is_empty() or not video_url.is_empty():
		_media_container.visible = true
		_setup_media_display(media_url, video_url)
	else:
		_media_container.visible = false

	# Related topics
	_populate_related_topics(topic.get("related", []))


func _setup_media_display(image_url: String, video_url: String) -> void:
	# Clear existing
	for child in _media_container.get_children():
		child.queue_free()

	if not image_url.is_empty() and ResourceLoader.exists(image_url):
		var texture_rect := TextureRect.new()
		texture_rect.texture = load(image_url)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_media_container.add_child(texture_rect)

	if not video_url.is_empty():
		# Video player placeholder (would need VideoStreamPlayer for actual video)
		var video_placeholder := ColorRect.new()
		video_placeholder.color = Color(0.1, 0.1, 0.12, 1.0)
		video_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_media_container.add_child(video_placeholder)

		var play_label := Label.new()
		play_label.text = "[Video: " + video_url.get_file() + "]"
		play_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		play_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		play_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		video_placeholder.add_child(play_label)


func _populate_related_topics(related_ids: Array) -> void:
	for child in _related_topics.get_children():
		child.queue_free()

	if related_ids.is_empty():
		_related_topics.visible = false
		return

	_related_topics.visible = true

	for topic_id in related_ids:
		if _help_topics.has(topic_id):
			var topic: Dictionary = _help_topics[topic_id]
			var button := Button.new()
			button.text = "> " + topic.get("title", topic_id)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_on_topic_clicked.bind(topic_id))
			_setup_link_button_style(button)
			_related_topics.add_child(button)


func _setup_link_button_style(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	button.add_theme_stylebox_override("normal", style)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.3, 0.5, 0.4)
	hover.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.7, 0.85, 1.0))


func _add_section_header(title: String) -> void:
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 1.0))
	_results_list.add_child(header)

	var separator := HSeparator.new()
	separator.modulate = Color(1, 1, 1, 0.3)
	_results_list.add_child(separator)


func _add_topic_item(topic_id: String, topic_data: Dictionary) -> void:
	var button := Button.new()
	button.text = topic_data.get("title", topic_id)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_on_topic_clicked.bind(topic_id))
	_setup_topic_button_style(button)

	# Bookmark indicator
	if topic_id in _bookmarked_topics:
		button.text = "[*] " + button.text

	_results_list.add_child(button)


func _setup_topic_button_style(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.17, 0.22, 0.8)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.3, 0.45, 0.9)
	hover.border_color = Color(0.3, 0.5, 0.8, 0.6)
	hover.set_border_width_all(1)
	button.add_theme_stylebox_override("hover", hover)


func _clear_results() -> void:
	for child in _results_list.get_children():
		child.queue_free()


func _get_all_topics() -> Array:
	var topics: Array = []
	for topic_id in _help_topics:
		topics.append(topic_id)
	return topics


func _go_back() -> void:
	if _history.is_empty():
		_show_home()
		return

	var prev_topic: String = _history.pop_back()
	_current_topic_id = ""  # Reset to prevent adding to history again
	_show_topic(prev_topic)


func _toggle_bookmark() -> void:
	if _current_topic_id.is_empty():
		return

	toggle_topic_bookmark(_current_topic_id)
	_bookmark_button.text = "Unbookmark" if _current_topic_id in _bookmarked_topics else "Bookmark"


func _hide_immediate() -> void:
	_help_panel.visible = false


func _save_bookmarks() -> void:
	# Would save to file/config in production
	pass


func _load_bookmarks() -> void:
	# Would load from file/config in production
	pass


# =====================================================================
# SIGNAL HANDLERS
# =====================================================================

func _on_search_changed(text: String) -> void:
	_search_clear.visible = not text.is_empty()

	if text.strip_edges().is_empty():
		_show_home()
		return

	var results := search(text)

	_results_list.visible = true
	_topic_view.visible = false
	_back_button.visible = false
	_bookmark_button.visible = false

	_clear_results()

	if results.is_empty():
		var no_results := Label.new()
		no_results.text = "No results found for '" + text + "'"
		no_results.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		_results_list.add_child(no_results)
	else:
		_add_section_header("Search Results")
		for topic_id in results:
			if _help_topics.has(topic_id):
				_add_topic_item(topic_id, _help_topics[topic_id])


func _clear_search() -> void:
	_search_input.text = ""
	_search_clear.visible = false
	_show_home()


func _on_topic_clicked(topic_id: String) -> void:
	_show_topic(topic_id)


func _on_element_hover(element: Control) -> void:
	if not _help_mode:
		return

	if _help_bubbles.has(element):
		_active_bubble = _help_bubbles[element]
		# Show quick tip tooltip or highlight


func _on_element_unhover(element: Control) -> void:
	if _active_bubble and _help_bubbles.get(element) == _active_bubble:
		_active_bubble = null


func _on_bubble_input(event: InputEvent, bubble: Control, topic_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_help(topic_id)
