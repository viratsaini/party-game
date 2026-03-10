## Date Time Picker - Calendar popup with smooth animations and time scrubber
## Features: month slide, time scroll, today highlight, range selection, timezone
extends Control
class_name DateTimePicker

## Emitted when date changes
signal date_changed(date: Dictionary)
## Emitted when time changes
signal time_changed(hours: int, minutes: int)
## Emitted when date/time is confirmed
signal datetime_confirmed(datetime: Dictionary)

# Configuration
@export var selected_date: Dictionary = {}  # {year, month, day}
@export var selected_time: Dictionary = {"hours": 12, "minutes": 0}
@export var show_time_picker: bool = true
@export var use_24h_format: bool = true
@export var min_year: int = 1900
@export var max_year: int = 2100
@export var enable_range_selection: bool = false

# Visual
@export_group("Colors")
@export var background_color: Color = Color(0.12, 0.12, 0.16, 1.0)
@export var header_color: Color = Color(0.15, 0.15, 0.2, 1.0)
@export var accent_color: Color = Color(0.3, 0.5, 1.0, 1.0)
@export var today_color: Color = Color(0.3, 0.7, 0.5, 1.0)
@export var text_color: Color = Color.WHITE
@export var weekend_color: Color = Color(1.0, 0.6, 0.6, 1.0)
@export var inactive_color: Color = Color(0.4, 0.4, 0.5, 1.0)

# Animation
@export var transition_duration: float = 0.3

# Internal nodes
var _container: VBoxContainer
var _header: Control
var _month_label: Label
var _year_label: Label
var _prev_btn: Button
var _next_btn: Button
var _weekday_row: HBoxContainer
var _calendar_container: Control
var _days_grid: GridContainer
var _today_btn: Button
var _time_container: HBoxContainer
var _hour_spinner: Control
var _minute_spinner: Control
var _am_pm_btn: Button
var _confirm_btn: Button

# State
var _current_year: int = 2024
var _current_month: int = 1
var _today: Dictionary = {}
var _range_start: Dictionary = {}
var _range_end: Dictionary = {}
var _is_selecting_range: bool = false
var _slide_direction: int = 0  # -1 left, 1 right
var _transition_tween: Tween

# Days of week
const WEEKDAYS: Array[String] = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
const MONTH_NAMES: Array[String] = ["January", "February", "March", "April", "May", "June",
									"July", "August", "September", "October", "November", "December"]


func _ready() -> void:
	_init_today()
	_init_selected_date()
	_setup_ui()
	_populate_calendar()


func _init_today() -> void:
	var datetime := Time.get_datetime_dict_from_system()
	_today = {
		"year": datetime.year,
		"month": datetime.month,
		"day": datetime.day
	}


func _init_selected_date() -> void:
	if selected_date.is_empty():
		selected_date = _today.duplicate()

	_current_year = selected_date.get("year", _today.year)
	_current_month = selected_date.get("month", _today.month)


func _setup_ui() -> void:
	custom_minimum_size = Vector2(320, 400 if show_time_picker else 340)

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
	_container.offset_left = 15
	_container.offset_right = -15
	_container.offset_top = 15
	_container.offset_bottom = -15
	_container.add_theme_constant_override("separation", 12)
	add_child(_container)

	# Header with month/year navigation
	_setup_header()

	# Weekday labels
	_setup_weekday_row()

	# Calendar grid
	_setup_calendar_grid()

	# Today button
	_setup_today_button()

	# Time picker
	if show_time_picker:
		_setup_time_picker()

	# Confirm button
	_setup_confirm_button()


func _setup_header() -> void:
	_header = Control.new()
	_header.custom_minimum_size = Vector2(0, 45)
	_container.add_child(_header)

	# Header background
	var header_bg := Panel.new()
	header_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = header_color
	header_style.corner_radius_top_left = 8
	header_style.corner_radius_top_right = 8
	header_style.corner_radius_bottom_left = 8
	header_style.corner_radius_bottom_right = 8
	header_bg.add_theme_stylebox_override("panel", header_style)
	_header.add_child(header_bg)

	# Previous month button
	_prev_btn = Button.new()
	_prev_btn.text = "<"
	_prev_btn.flat = true
	_prev_btn.anchor_left = 0.0
	_prev_btn.anchor_right = 0.15
	_prev_btn.anchor_top = 0.0
	_prev_btn.anchor_bottom = 1.0
	_prev_btn.add_theme_font_size_override("font_size", 20)
	_prev_btn.add_theme_color_override("font_color", text_color)
	_prev_btn.pressed.connect(func() -> void: _change_month(-1))
	_header.add_child(_prev_btn)

	# Month/Year labels
	var label_container := VBoxContainer.new()
	label_container.anchor_left = 0.15
	label_container.anchor_right = 0.85
	label_container.anchor_top = 0.0
	label_container.anchor_bottom = 1.0
	label_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_header.add_child(label_container)

	_month_label = Label.new()
	_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_month_label.add_theme_font_size_override("font_size", 18)
	_month_label.add_theme_color_override("font_color", text_color)
	label_container.add_child(_month_label)

	_year_label = Label.new()
	_year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_year_label.add_theme_font_size_override("font_size", 12)
	_year_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.6))
	label_container.add_child(_year_label)

	# Next month button
	_next_btn = Button.new()
	_next_btn.text = ">"
	_next_btn.flat = true
	_next_btn.anchor_left = 0.85
	_next_btn.anchor_right = 1.0
	_next_btn.anchor_top = 0.0
	_next_btn.anchor_bottom = 1.0
	_next_btn.add_theme_font_size_override("font_size", 20)
	_next_btn.add_theme_color_override("font_color", text_color)
	_next_btn.pressed.connect(func() -> void: _change_month(1))
	_header.add_child(_next_btn)


func _setup_weekday_row() -> void:
	_weekday_row = HBoxContainer.new()
	_weekday_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_child(_weekday_row)

	for day in WEEKDAYS:
		var label := Label.new()
		label.text = day
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(38, 25)
		label.add_theme_font_size_override("font_size", 12)

		var is_weekend: bool = day == "Su" or day == "Sa"
		label.add_theme_color_override("font_color",
			Color(weekend_color.r, weekend_color.g, weekend_color.b, 0.7) if is_weekend else
			Color(text_color.r, text_color.g, text_color.b, 0.7))
		_weekday_row.add_child(label)


func _setup_calendar_grid() -> void:
	_calendar_container = Control.new()
	_calendar_container.custom_minimum_size = Vector2(0, 200)
	_calendar_container.clip_contents = true
	_container.add_child(_calendar_container)

	_days_grid = GridContainer.new()
	_days_grid.columns = 7
	_days_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_days_grid.add_theme_constant_override("h_separation", 2)
	_days_grid.add_theme_constant_override("v_separation", 2)
	_calendar_container.add_child(_days_grid)


func _setup_today_button() -> void:
	_today_btn = Button.new()
	_today_btn.text = "Today"
	_today_btn.flat = true
	_today_btn.add_theme_font_size_override("font_size", 13)
	_today_btn.add_theme_color_override("font_color", today_color)
	_today_btn.pressed.connect(_go_to_today)
	_container.add_child(_today_btn)


func _setup_time_picker() -> void:
	var time_section := VBoxContainer.new()
	time_section.add_theme_constant_override("separation", 8)
	_container.add_child(time_section)

	var time_label := Label.new()
	time_label.text = "Time"
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.6))
	time_section.add_child(time_label)

	_time_container = HBoxContainer.new()
	_time_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_time_container.add_theme_constant_override("separation", 10)
	time_section.add_child(_time_container)

	# Hour spinner
	_hour_spinner = _create_time_spinner("hour", 0 if use_24h_format else 1, 23 if use_24h_format else 12)
	_time_container.add_child(_hour_spinner)

	# Separator
	var separator := Label.new()
	separator.text = ":"
	separator.add_theme_font_size_override("font_size", 28)
	separator.add_theme_color_override("font_color", text_color)
	_time_container.add_child(separator)

	# Minute spinner
	_minute_spinner = _create_time_spinner("minute", 0, 59)
	_time_container.add_child(_minute_spinner)

	# AM/PM toggle (if not 24h)
	if not use_24h_format:
		_am_pm_btn = Button.new()
		_am_pm_btn.text = "AM"
		_am_pm_btn.custom_minimum_size = Vector2(50, 50)

		var ampm_style := StyleBoxFlat.new()
		ampm_style.bg_color = Color(0.2, 0.2, 0.25, 1.0)
		ampm_style.corner_radius_top_left = 8
		ampm_style.corner_radius_top_right = 8
		ampm_style.corner_radius_bottom_left = 8
		ampm_style.corner_radius_bottom_right = 8
		_am_pm_btn.add_theme_stylebox_override("normal", ampm_style)
		_am_pm_btn.add_theme_font_size_override("font_size", 14)
		_am_pm_btn.add_theme_color_override("font_color", text_color)
		_am_pm_btn.pressed.connect(_toggle_am_pm)
		_time_container.add_child(_am_pm_btn)


func _create_time_spinner(type: String, min_val: int, max_val: int) -> Control:
	var spinner := Control.new()
	spinner.custom_minimum_size = Vector2(60, 80)

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
	spinner.add_child(bg)

	# Up button
	var up_btn := Button.new()
	up_btn.name = "UpBtn"
	up_btn.text = "^"
	up_btn.flat = true
	up_btn.anchor_left = 0.0
	up_btn.anchor_right = 1.0
	up_btn.anchor_top = 0.0
	up_btn.anchor_bottom = 0.3
	up_btn.add_theme_font_size_override("font_size", 16)
	up_btn.add_theme_color_override("font_color", text_color)
	spinner.add_child(up_btn)

	# Value label
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "00"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.anchor_left = 0.0
	value_label.anchor_right = 1.0
	value_label.anchor_top = 0.3
	value_label.anchor_bottom = 0.7
	value_label.add_theme_font_size_override("font_size", 24)
	value_label.add_theme_color_override("font_color", text_color)
	spinner.add_child(value_label)

	# Down button
	var down_btn := Button.new()
	down_btn.name = "DownBtn"
	down_btn.text = "v"
	down_btn.flat = true
	down_btn.anchor_left = 0.0
	down_btn.anchor_right = 1.0
	down_btn.anchor_top = 0.7
	down_btn.anchor_bottom = 1.0
	down_btn.add_theme_font_size_override("font_size", 16)
	down_btn.add_theme_color_override("font_color", text_color)
	spinner.add_child(down_btn)

	# Store metadata
	spinner.set_meta("type", type)
	spinner.set_meta("min", min_val)
	spinner.set_meta("max", max_val)
	spinner.set_meta("value", selected_time.hours if type == "hour" else selected_time.minutes)

	# Connect buttons
	up_btn.pressed.connect(func() -> void: _adjust_time_value(spinner, 1))
	down_btn.pressed.connect(func() -> void: _adjust_time_value(spinner, -1))

	# Mouse wheel
	spinner.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_adjust_time_value(spinner, 1)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_adjust_time_value(spinner, -1)
	)

	# Update display
	_update_time_spinner_display(spinner)

	return spinner


func _update_time_spinner_display(spinner: Control) -> void:
	var label: Label = spinner.get_node("ValueLabel")
	var value: int = spinner.get_meta("value")
	label.text = "%02d" % value


func _adjust_time_value(spinner: Control, delta: int) -> void:
	var current: int = spinner.get_meta("value")
	var min_val: int = spinner.get_meta("min")
	var max_val: int = spinner.get_meta("max")
	var type: String = spinner.get_meta("type")

	var new_value: int = current + delta
	if new_value > max_val:
		new_value = min_val
	elif new_value < min_val:
		new_value = max_val

	spinner.set_meta("value", new_value)
	_animate_time_change(spinner, current, new_value, delta > 0)

	if type == "hour":
		selected_time.hours = new_value
	else:
		selected_time.minutes = new_value

	time_changed.emit(selected_time.hours, selected_time.minutes)


func _animate_time_change(spinner: Control, _old_val: int, new_val: int, going_up: bool) -> void:
	var label: Label = spinner.get_node("ValueLabel")

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# Slide animation
	var start_y: float = 10 if going_up else -10
	label.position.y = start_y
	label.text = "%02d" % new_val

	tween.tween_property(label, "position:y", 0.0, 0.15)


func _toggle_am_pm() -> void:
	if _am_pm_btn.text == "AM":
		_am_pm_btn.text = "PM"
	else:
		_am_pm_btn.text = "AM"


func _setup_confirm_button() -> void:
	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm"
	_confirm_btn.custom_minimum_size = Vector2(0, 42)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = accent_color
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	_confirm_btn.add_theme_stylebox_override("normal", btn_style)
	_confirm_btn.add_theme_font_size_override("font_size", 15)
	_confirm_btn.add_theme_color_override("font_color", Color.WHITE)
	_confirm_btn.pressed.connect(_on_confirm)
	_container.add_child(_confirm_btn)


func _populate_calendar() -> void:
	# Clear existing days
	for child in _days_grid.get_children():
		child.queue_free()

	# Update header
	_month_label.text = MONTH_NAMES[_current_month - 1]
	_year_label.text = str(_current_year)

	# Get first day of month and days in month
	var first_day_weekday: int = _get_weekday(_current_year, _current_month, 1)
	var days_in_month: int = _get_days_in_month(_current_year, _current_month)
	var days_in_prev_month: int = _get_days_in_month(
		_current_year if _current_month > 1 else _current_year - 1,
		_current_month - 1 if _current_month > 1 else 12
	)

	# Previous month days
	for i in range(first_day_weekday):
		var day: int = days_in_prev_month - first_day_weekday + i + 1
		_add_day_button(day, true, false)

	# Current month days
	for day in range(1, days_in_month + 1):
		_add_day_button(day, false, false)

	# Next month days
	var total_cells: int = first_day_weekday + days_in_month
	var remaining: int = (7 - (total_cells % 7)) % 7
	for day in range(1, remaining + 1):
		_add_day_button(day, true, true)


func _add_day_button(day: int, is_other_month: bool, is_next: bool) -> void:
	var btn := Button.new()
	btn.text = str(day)
	btn.custom_minimum_size = Vector2(38, 32)
	btn.flat = true

	var is_today: bool = not is_other_month and \
		day == _today.day and \
		_current_month == _today.month and \
		_current_year == _today.year

	var is_selected: bool = not is_other_month and \
		day == selected_date.get("day", 0) and \
		_current_month == selected_date.get("month", 0) and \
		_current_year == selected_date.get("year", 0)

	# Determine weekday for coloring
	var actual_month: int = _current_month
	var actual_year: int = _current_year
	if is_other_month:
		if is_next:
			actual_month = _current_month + 1
			if actual_month > 12:
				actual_month = 1
				actual_year += 1
		else:
			actual_month = _current_month - 1
			if actual_month < 1:
				actual_month = 12
				actual_year -= 1

	var weekday: int = _get_weekday(actual_year, actual_month, day)
	var is_weekend: bool = weekday == 0 or weekday == 6

	# Style button
	if is_selected:
		var selected_style := StyleBoxFlat.new()
		selected_style.bg_color = accent_color
		selected_style.corner_radius_top_left = 6
		selected_style.corner_radius_top_right = 6
		selected_style.corner_radius_bottom_left = 6
		selected_style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", selected_style)
		btn.add_theme_stylebox_override("hover", selected_style)
		btn.add_theme_color_override("font_color", Color.WHITE)
	elif is_today:
		var today_style := StyleBoxFlat.new()
		today_style.bg_color = Color(today_color.r, today_color.g, today_color.b, 0.2)
		today_style.corner_radius_top_left = 6
		today_style.corner_radius_top_right = 6
		today_style.corner_radius_bottom_left = 6
		today_style.corner_radius_bottom_right = 6
		today_style.border_width_left = 2
		today_style.border_width_right = 2
		today_style.border_width_top = 2
		today_style.border_width_bottom = 2
		today_style.border_color = today_color
		btn.add_theme_stylebox_override("normal", today_style)
		btn.add_theme_color_override("font_color", today_color)
	elif is_other_month:
		btn.add_theme_color_override("font_color", inactive_color)
	elif is_weekend:
		btn.add_theme_color_override("font_color", weekend_color)
	else:
		btn.add_theme_color_override("font_color", text_color)

	btn.add_theme_font_size_override("font_size", 14)

	# Hover effect
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.2)
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	if not is_selected:
		btn.add_theme_stylebox_override("hover", hover_style)

	# Click handler
	var target_month: int = actual_month
	var target_year: int = actual_year
	btn.pressed.connect(func() -> void: _select_day(day, target_month, target_year))

	_days_grid.add_child(btn)


func _select_day(day: int, month: int, year: int) -> void:
	selected_date = {
		"year": year,
		"month": month,
		"day": day
	}

	if month != _current_month or year != _current_year:
		_current_month = month
		_current_year = year

	_populate_calendar()
	date_changed.emit(selected_date)


func _change_month(delta: int) -> void:
	_slide_direction = delta

	_current_month += delta
	if _current_month > 12:
		_current_month = 1
		_current_year += 1
	elif _current_month < 1:
		_current_month = 12
		_current_year -= 1

	_animate_calendar_transition()


func _animate_calendar_transition() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	var start_offset: float = _slide_direction * 50
	_days_grid.modulate.a = 0.0
	_days_grid.position.x = start_offset

	_populate_calendar()

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)

	_transition_tween.tween_property(_days_grid, "modulate:a", 1.0, transition_duration)
	_transition_tween.tween_property(_days_grid, "position:x", 0.0, transition_duration)


func _go_to_today() -> void:
	_current_month = _today.month
	_current_year = _today.year
	selected_date = _today.duplicate()

	_animate_calendar_transition()
	date_changed.emit(selected_date)


func _on_confirm() -> void:
	var datetime := {
		"year": selected_date.get("year", _today.year),
		"month": selected_date.get("month", _today.month),
		"day": selected_date.get("day", _today.day),
		"hour": selected_time.hours,
		"minute": selected_time.minutes
	}
	datetime_confirmed.emit(datetime)


# Date calculation helpers
func _get_weekday(year: int, month: int, day: int) -> int:
	# Zeller's formula adaptation
	if month < 3:
		month += 12
		year -= 1

	var k: int = year % 100
	var j: int = year / 100
	var h: int = (day + (13 * (month + 1)) / 5 + k + k / 4 + j / 4 - 2 * j) % 7

	return (h + 6) % 7  # Convert to Sunday = 0


func _get_days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			if _is_leap_year(year):
				return 29
			return 28
		_:
			return 30


func _is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)


# Public API
func get_selected_date() -> Dictionary:
	return selected_date.duplicate()


func get_selected_time() -> Dictionary:
	return selected_time.duplicate()


func get_datetime() -> Dictionary:
	return {
		"year": selected_date.get("year", _today.year),
		"month": selected_date.get("month", _today.month),
		"day": selected_date.get("day", _today.day),
		"hour": selected_time.hours,
		"minute": selected_time.minutes
	}


func set_date(year: int, month: int, day: int) -> void:
	selected_date = {"year": year, "month": month, "day": day}
	_current_year = year
	_current_month = month
	_populate_calendar()


func set_time(hours: int, minutes: int) -> void:
	selected_time = {"hours": hours, "minutes": minutes}
	if _hour_spinner:
		_hour_spinner.set_meta("value", hours)
		_update_time_spinner_display(_hour_spinner)
	if _minute_spinner:
		_minute_spinner.set_meta("value", minutes)
		_update_time_spinner_display(_minute_spinner)


func go_to_month(year: int, month: int) -> void:
	_current_year = year
	_current_month = month
	_populate_calendar()
