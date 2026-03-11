## StatsDashboard - Premium statistics visualization with animated elements
##
## Features:
##   - Animated stat cards that count up from zero
##   - Smooth graph/chart animations with easing
##   - Friend comparison mode with side-by-side stats
##   - Time period selector (Today/Week/Month/All-time)
##   - Progress rings that fill smoothly with percentages
##   - Achievement showcase grid
##   - Activity heat maps showing play patterns
##
## Usage:
##   var dashboard = StatsDashboard.new()
##   add_child(dashboard)
##   dashboard.load_stats(player_stats_dictionary)
extends Control


# region -- Signals

## Emitted when time period changes
signal period_changed(period: String)

## Emitted when comparison mode toggled
signal comparison_toggled(enabled: bool, friend_id: int)

## Emitted when a stat card is clicked
signal stat_card_clicked(stat_name: String)

## Emitted when achievement is clicked in showcase
signal achievement_clicked(achievement_id: String)

# endregion


# region -- Enums

enum TimePeriod {
	TODAY,
	WEEK,
	MONTH,
	ALL_TIME,
}

# endregion


# region -- Constants

## Time period labels
const PERIOD_LABELS: Dictionary = {
	TimePeriod.TODAY: "Today",
	TimePeriod.WEEK: "This Week",
	TimePeriod.MONTH: "This Month",
	TimePeriod.ALL_TIME: "All Time",
}

## Animation timings
const COUNT_UP_DURATION: float = 1.2
const RING_FILL_DURATION: float = 1.5
const CHART_DRAW_DURATION: float = 1.0
const CARD_STAGGER_DELAY: float = 0.1
const TRANSITION_DURATION: float = 0.4

## Colors
const PRIMARY_COLOR: Color = Color(0.3, 0.6, 1.0)
const SECONDARY_COLOR: Color = Color(0.5, 0.8, 0.4)
const ACCENT_COLOR: Color = Color(1.0, 0.6, 0.2)
const DANGER_COLOR: Color = Color(1.0, 0.3, 0.3)
const CARD_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const CARD_BORDER: Color = Color(0.2, 0.25, 0.35, 0.8)

## Heat map colors (cool to hot)
const HEATMAP_COLORS: Array[Color] = [
	Color(0.15, 0.15, 0.2),      # None
	Color(0.2, 0.3, 0.5),        # Low
	Color(0.3, 0.5, 0.7),        # Medium-low
	Color(0.4, 0.7, 0.5),        # Medium
	Color(0.7, 0.7, 0.3),        # Medium-high
	Color(0.9, 0.5, 0.2),        # High
	Color(1.0, 0.3, 0.2),        # Very high
]

## Chart colors for multi-series
const CHART_COLORS: Array[Color] = [
	Color(0.3, 0.6, 1.0),
	Color(0.5, 0.8, 0.4),
	Color(1.0, 0.6, 0.2),
	Color(0.8, 0.4, 0.9),
	Color(0.3, 0.9, 0.9),
]

# endregion


# region -- State

## Current player stats
var _stats: Dictionary = {}

## Comparison stats (friend)
var _comparison_stats: Dictionary = {}

## Selected time period
var _current_period: TimePeriod = TimePeriod.ALL_TIME

## Comparison mode active
var _comparison_mode: bool = false

## UI references
var _header: Control
var _period_selector: HBoxContainer
var _main_content: ScrollContainer
var _stat_cards: Array[Control] = []
var _progress_rings: Array[Control] = []
var _charts: Array[Control] = []
var _heat_map: Control

## Animation tracking
var _count_up_tweens: Array[Tween] = []

# endregion


# region -- Lifecycle

func _ready() -> void:
	_setup_ui()
	_setup_header()
	_setup_main_content()


func _process(_delta: float) -> void:
	_update_chart_animations()

# endregion


# region -- UI Setup

func _setup_ui() -> void:
	name = "StatsDashboard"
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.05, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _setup_header() -> void:
	_header = PanelContainer.new()
	_header.name = "Header"
	_header.custom_minimum_size = Vector2(0, 100)
	_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header.offset_bottom = 100

	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	header_style.border_width_bottom = 2
	header_style.border_color = PRIMARY_COLOR.darkened(0.5)
	_header.add_theme_stylebox_override("panel", header_style)

	var header_vbox := VBoxContainer.new()
	header_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_vbox.add_theme_constant_override("separation", 10)

	# Title
	var title := Label.new()
	title.text = "STATISTICS DASHBOARD"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(title)

	# Period selector
	_period_selector = _create_period_selector()
	header_vbox.add_child(_period_selector)

	_header.add_child(header_vbox)
	add_child(_header)


func _create_period_selector() -> HBoxContainer:
	var container := HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 5)

	for period: int in TimePeriod.values():
		var btn := Button.new()
		btn.text = PERIOD_LABELS[period]
		btn.custom_minimum_size = Vector2(100, 35)
		btn.toggle_mode = true
		btn.button_pressed = period == _current_period

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.15, 0.2) if period != _current_period else PRIMARY_COLOR.darkened(0.3)
		btn_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", btn_style)

		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = PRIMARY_COLOR.darkened(0.3)
		pressed_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		btn.pressed.connect(_on_period_selected.bind(period))
		btn.set_meta("period", period)
		container.add_child(btn)

	return container


func _setup_main_content() -> void:
	_main_content = ScrollContainer.new()
	_main_content.name = "MainContent"
	_main_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_content.offset_top = 110
	_main_content.offset_bottom = -10
	_main_content.offset_left = 20
	_main_content.offset_right = -20
	_main_content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 25)

	# Stat cards grid
	var stat_cards_section := _create_stat_cards_section()
	content.add_child(stat_cards_section)

	# Progress rings section
	var rings_section := _create_progress_rings_section()
	content.add_child(rings_section)

	# Charts section
	var charts_section := _create_charts_section()
	content.add_child(charts_section)

	# Heat map section
	var heatmap_section := _create_heatmap_section()
	content.add_child(heatmap_section)

	# Achievement showcase
	var achievements_section := _create_achievements_section()
	content.add_child(achievements_section)

	_main_content.add_child(content)
	add_child(_main_content)

# endregion


# region -- Stat Cards

func _create_stat_cards_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "StatCardsSection"
	section.add_theme_constant_override("separation", 15)

	# Section header
	var header := Label.new()
	header.text = "QUICK STATS"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	section.add_child(header)

	# Cards grid (2 rows of 4)
	var grid := GridContainer.new()
	grid.name = "StatCardsGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)

	# Create stat cards
	var stat_configs: Array[Dictionary] = [
		{"key": "total_kills", "label": "Total Kills", "icon": "skull", "color": DANGER_COLOR},
		{"key": "total_deaths", "label": "Deaths", "icon": "cross", "color": Color(0.6, 0.6, 0.7)},
		{"key": "kd_ratio", "label": "K/D Ratio", "icon": "chart", "color": PRIMARY_COLOR, "decimals": 2},
		{"key": "matches_played", "label": "Matches", "icon": "games", "color": SECONDARY_COLOR},
		{"key": "wins", "label": "Wins", "icon": "trophy", "color": Color(1.0, 0.84, 0.0)},
		{"key": "win_rate", "label": "Win Rate", "icon": "percent", "color": ACCENT_COLOR, "suffix": "%"},
		{"key": "headshots", "label": "Headshots", "icon": "target", "color": Color(0.9, 0.3, 0.5)},
		{"key": "playtime_hours", "label": "Hours Played", "icon": "clock", "color": Color(0.5, 0.7, 0.9), "decimals": 1},
	]

	for config: Dictionary in stat_configs:
		var card := _create_stat_card(config)
		grid.add_child(card)
		_stat_cards.append(card)

	section.add_child(grid)
	return section


func _create_stat_card(config: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "StatCard_%s" % config["key"]
	card.custom_minimum_size = Vector2(180, 100)
	card.set_meta("config", config)

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = CARD_BORDER
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)

	# Label
	var label := Label.new()
	label.text = config["label"]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	# Value
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", 32)
	value_label.add_theme_color_override("font_color", config.get("color", Color.WHITE))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(value_label)

	# Comparison indicator (hidden by default)
	var comparison := HBoxContainer.new()
	comparison.name = "Comparison"
	comparison.visible = false
	comparison.alignment = BoxContainer.ALIGNMENT_CENTER

	var diff_label := Label.new()
	diff_label.name = "DiffLabel"
	diff_label.text = "+0"
	diff_label.add_theme_font_size_override("font_size", 14)
	comparison.add_child(diff_label)

	vbox.add_child(comparison)
	card.add_child(vbox)

	# Hover effect
	card.mouse_entered.connect(_on_stat_card_hover.bind(card, true))
	card.mouse_exited.connect(_on_stat_card_hover.bind(card, false))
	card.gui_input.connect(_on_stat_card_input.bind(card))

	return card


func _animate_stat_card(card: PanelContainer, target_value: float) -> void:
	var config: Dictionary = card.get_meta("config", {})
	var value_label: Label = card.get_node("VBoxContainer/Value")
	var decimals: int = config.get("decimals", 0)
	var suffix: String = config.get("suffix", "")

	# Count up animation
	var current: Dictionary = {"value": 0.0}

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(
		func(v: float) -> void:
			if decimals > 0:
				value_label.text = ("%." + str(decimals) + "f%s") % [v, suffix]
			else:
				value_label.text = "%d%s" % [int(v), suffix],
		0.0,
		target_value,
		COUNT_UP_DURATION
	)

	_count_up_tweens.append(tween)


func _on_stat_card_hover(card: PanelContainer, hovered: bool) -> void:
	var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()

	if hovered:
		style.bg_color = CARD_BG.lightened(0.1)
		style.border_color = PRIMARY_COLOR.lightened(0.2)
	else:
		style.bg_color = CARD_BG
		style.border_color = CARD_BORDER

	card.add_theme_stylebox_override("panel", style)

	# Scale animation
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "scale", Vector2(1.05, 1.05) if hovered else Vector2.ONE, 0.15)


func _on_stat_card_input(event: InputEvent, card: PanelContainer) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var config: Dictionary = card.get_meta("config", {})
			stat_card_clicked.emit(config.get("key", ""))

# endregion


# region -- Progress Rings

func _create_progress_rings_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "ProgressRingsSection"
	section.add_theme_constant_override("separation", 15)

	# Section header
	var header := Label.new()
	header.text = "PERFORMANCE METRICS"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	section.add_child(header)

	# Rings row
	var rings_row := HBoxContainer.new()
	rings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rings_row.add_theme_constant_override("separation", 40)

	var ring_configs: Array[Dictionary] = [
		{"key": "accuracy", "label": "Accuracy", "color": PRIMARY_COLOR},
		{"key": "headshot_rate", "label": "Headshot %", "color": DANGER_COLOR},
		{"key": "survival_rate", "label": "Survival", "color": SECONDARY_COLOR},
		{"key": "objective_rate", "label": "Objectives", "color": ACCENT_COLOR},
	]

	for config: Dictionary in ring_configs:
		var ring := _create_progress_ring(config)
		rings_row.add_child(ring)
		_progress_rings.append(ring)

	section.add_child(rings_row)
	return section


func _create_progress_ring(config: Dictionary) -> Control:
	var container := Control.new()
	container.name = "Ring_%s" % config["key"]
	container.custom_minimum_size = Vector2(140, 160)
	container.set_meta("config", config)
	container.set_meta("progress", 0.0)
	container.set_meta("target_progress", 0.0)

	# Custom drawing for ring
	container.draw.connect(_draw_progress_ring.bind(container))

	# Label below ring
	var label := Label.new()
	label.name = "Label"
	label.text = config["label"]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -25
	container.add_child(label)

	# Value label in center
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.text = "0%"
	value_label.add_theme_font_size_override("font_size", 24)
	value_label.add_theme_color_override("font_color", config.get("color", Color.WHITE))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.set_anchors_preset(Control.PRESET_CENTER)
	value_label.offset_top = -20
	value_label.offset_bottom = -20
	container.add_child(value_label)

	return container


func _draw_progress_ring(container: Control) -> void:
	var config: Dictionary = container.get_meta("config", {})
	var progress: float = container.get_meta("progress", 0.0)
	var color: Color = config.get("color", PRIMARY_COLOR)

	var center := Vector2(container.size.x / 2, 60)
	var radius: float = 50.0
	var ring_width: float = 8.0

	# Background ring
	var bg_color := Color(0.2, 0.2, 0.25)
	_draw_arc_ring(container, center, radius, ring_width, 0.0, TAU, bg_color)

	# Progress ring
	if progress > 0.0:
		var end_angle: float = TAU * progress - PI / 2
		_draw_arc_ring(container, center, radius, ring_width, -PI / 2, end_angle, color)


func _draw_arc_ring(container: Control, center: Vector2, radius: float, width: float, start: float, end: float, color: Color) -> void:
	var segments: int = 64
	var angle_step: float = (end - start) / segments

	for i: int in segments:
		var angle1: float = start + angle_step * i
		var angle2: float = start + angle_step * (i + 1)

		var inner1 := center + Vector2(cos(angle1), sin(angle1)) * (radius - width / 2)
		var outer1 := center + Vector2(cos(angle1), sin(angle1)) * (radius + width / 2)
		var inner2 := center + Vector2(cos(angle2), sin(angle2)) * (radius - width / 2)
		var outer2 := center + Vector2(cos(angle2), sin(angle2)) * (radius + width / 2)

		var points := PackedVector2Array([inner1, outer1, outer2, inner2])
		var colors := PackedColorArray([color, color, color, color])
		container.draw_polygon(points, colors)


func _animate_progress_ring(ring: Control, target_progress: float) -> void:
	ring.set_meta("target_progress", clampf(target_progress, 0.0, 1.0))

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(
		func(v: float) -> void:
			ring.set_meta("progress", v)
			ring.queue_redraw()

			# Update value label
			var value_label: Label = ring.get_node_or_null("Value")
			if value_label:
				value_label.text = "%d%%" % int(v * 100),
		ring.get_meta("progress", 0.0),
		target_progress,
		RING_FILL_DURATION
	)

# endregion


# region -- Charts

func _create_charts_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "ChartsSection"
	section.add_theme_constant_override("separation", 15)

	# Section header
	var header := Label.new()
	header.text = "PERFORMANCE OVER TIME"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	section.add_child(header)

	# Chart container
	var chart_row := HBoxContainer.new()
	chart_row.add_theme_constant_override("separation", 20)

	# Line chart for K/D over time
	var kd_chart := _create_line_chart("K/D Ratio", "kd_history")
	chart_row.add_child(kd_chart)
	_charts.append(kd_chart)

	# Bar chart for win/loss
	var winloss_chart := _create_bar_chart("Win/Loss", "winloss_history")
	chart_row.add_child(winloss_chart)
	_charts.append(winloss_chart)

	section.add_child(chart_row)
	return section


func _create_line_chart(title: String, data_key: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "LineChart_%s" % data_key
	panel.custom_minimum_size = Vector2(400, 250)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("data_key", data_key)
	panel.set_meta("chart_type", "line")
	panel.set_meta("data_points", [])
	panel.set_meta("animation_progress", 0.0)

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = CARD_BORDER
	panel.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	# Title
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	content.add_child(title_label)

	# Chart drawing area
	var chart_area := Control.new()
	chart_area.name = "ChartArea"
	chart_area.custom_minimum_size = Vector2(380, 180)
	chart_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_area.draw.connect(_draw_line_chart.bind(panel))
	content.add_child(chart_area)

	panel.add_child(content)
	return panel


func _create_bar_chart(title: String, data_key: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "BarChart_%s" % data_key
	panel.custom_minimum_size = Vector2(400, 250)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("data_key", data_key)
	panel.set_meta("chart_type", "bar")
	panel.set_meta("data_points", [])
	panel.set_meta("animation_progress", 0.0)

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = CARD_BORDER
	panel.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	# Title
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	content.add_child(title_label)

	# Chart drawing area
	var chart_area := Control.new()
	chart_area.name = "ChartArea"
	chart_area.custom_minimum_size = Vector2(380, 180)
	chart_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_area.draw.connect(_draw_bar_chart.bind(panel))
	content.add_child(chart_area)

	panel.add_child(content)
	return panel


func _draw_line_chart(panel: PanelContainer) -> void:
	var chart_area: Control = panel.get_node_or_null("VBoxContainer/ChartArea")
	if not chart_area:
		return

	var data: Array = panel.get_meta("data_points", [])
	var progress: float = panel.get_meta("animation_progress", 0.0)

	if data.is_empty():
		return

	var area_size := chart_area.size
	var padding := Vector2(40, 20)
	var chart_rect := Rect2(padding, area_size - padding * 2)

	# Find min/max
	var min_val: float = INF
	var max_val: float = -INF
	for point: float in data:
		min_val = minf(min_val, point)
		max_val = maxf(max_val, point)

	var value_range: float = max_val - min_val
	if value_range == 0:
		value_range = 1.0

	# Draw grid lines
	var grid_color := Color(0.3, 0.3, 0.35, 0.5)
	for i: int in 5:
		var y: float = chart_rect.position.y + chart_rect.size.y * (i / 4.0)
		chart_area.draw_line(
			Vector2(chart_rect.position.x, y),
			Vector2(chart_rect.end.x, y),
			grid_color,
			1.0
		)

	# Draw line with animation
	var points_to_draw: int = int(data.size() * progress)
	if points_to_draw < 2:
		return

	var line_points: PackedVector2Array = []
	for i: int in points_to_draw:
		var x: float = chart_rect.position.x + chart_rect.size.x * (float(i) / (data.size() - 1))
		var normalized: float = (data[i] - min_val) / value_range
		var y: float = chart_rect.end.y - chart_rect.size.y * normalized
		line_points.append(Vector2(x, y))

	# Draw line
	if line_points.size() >= 2:
		chart_area.draw_polyline(line_points, PRIMARY_COLOR, 3.0, true)

		# Draw points
		for point: Vector2 in line_points:
			chart_area.draw_circle(point, 5, PRIMARY_COLOR)
			chart_area.draw_circle(point, 3, Color.WHITE)


func _draw_bar_chart(panel: PanelContainer) -> void:
	var chart_area: Control = panel.get_node_or_null("VBoxContainer/ChartArea")
	if not chart_area:
		return

	var data: Array = panel.get_meta("data_points", [])
	var progress: float = panel.get_meta("animation_progress", 0.0)

	if data.is_empty():
		return

	var area_size := chart_area.size
	var padding := Vector2(40, 20)
	var chart_rect := Rect2(padding, area_size - padding * 2)

	# Find max
	var max_val: float = 1.0
	for point: Dictionary in data:
		max_val = maxf(max_val, point.get("wins", 0))
		max_val = maxf(max_val, point.get("losses", 0))

	# Draw bars
	var bar_width: float = (chart_rect.size.x / data.size()) * 0.4
	var gap: float = (chart_rect.size.x / data.size()) * 0.6 / 3

	for i: int in data.size():
		var entry: Dictionary = data[i]
		var center_x: float = chart_rect.position.x + chart_rect.size.x * ((i + 0.5) / data.size())

		# Win bar (green)
		var win_height: float = (entry.get("wins", 0) / max_val) * chart_rect.size.y * progress
		var win_rect := Rect2(
			center_x - bar_width - gap / 2,
			chart_rect.end.y - win_height,
			bar_width,
			win_height
		)
		chart_area.draw_rect(win_rect, SECONDARY_COLOR, true)

		# Loss bar (red)
		var loss_height: float = (entry.get("losses", 0) / max_val) * chart_rect.size.y * progress
		var loss_rect := Rect2(
			center_x + gap / 2,
			chart_rect.end.y - loss_height,
			bar_width,
			loss_height
		)
		chart_area.draw_rect(loss_rect, DANGER_COLOR, true)


func _animate_chart(chart: PanelContainer) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(
		func(v: float) -> void:
			chart.set_meta("animation_progress", v)
			var chart_area: Control = chart.get_node_or_null("VBoxContainer/ChartArea")
			if chart_area:
				chart_area.queue_redraw(),
		0.0,
		1.0,
		CHART_DRAW_DURATION
	)


func _update_chart_animations() -> void:
	pass  # Chart animations handled by tweens

# endregion


# region -- Heat Map

func _create_heatmap_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "HeatmapSection"
	section.add_theme_constant_override("separation", 15)

	# Section header
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 20)

	var header := Label.new()
	header.text = "ACTIVITY HEATMAP"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	header_row.add_child(header)

	# Legend
	var legend := _create_heatmap_legend()
	header_row.add_child(legend)

	section.add_child(header_row)

	# Heat map grid
	var heatmap_panel := PanelContainer.new()
	heatmap_panel.name = "HeatmapPanel"
	heatmap_panel.custom_minimum_size = Vector2(0, 180)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = CARD_BG
	panel_style.set_corner_radius_all(12)
	heatmap_panel.add_theme_stylebox_override("panel", panel_style)

	_heat_map = Control.new()
	_heat_map.name = "HeatmapGrid"
	_heat_map.custom_minimum_size = Vector2(700, 150)
	_heat_map.set_meta("data", {})
	_heat_map.draw.connect(_draw_heatmap)

	heatmap_panel.add_child(_heat_map)
	section.add_child(heatmap_panel)

	return section


func _create_heatmap_legend() -> HBoxContainer:
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 5)

	var less_label := Label.new()
	less_label.text = "Less"
	less_label.add_theme_font_size_override("font_size", 12)
	less_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	legend.add_child(less_label)

	for color: Color in HEATMAP_COLORS:
		var box := ColorRect.new()
		box.custom_minimum_size = Vector2(16, 16)
		box.color = color
		legend.add_child(box)

	var more_label := Label.new()
	more_label.text = "More"
	more_label.add_theme_font_size_override("font_size", 12)
	more_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	legend.add_child(more_label)

	return legend


func _draw_heatmap() -> void:
	if not _heat_map:
		return

	var data: Dictionary = _heat_map.get_meta("data", {})
	var cell_size := Vector2(12, 16)
	var gap: float = 3.0
	var weeks: int = 52
	var days: int = 7

	var day_labels := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	var offset_x: float = 30.0

	# Draw day labels
	for d: int in days:
		if d % 2 == 0:
			var label_pos := Vector2(5, d * (cell_size.y + gap) + cell_size.y / 2 + 5)
			_heat_map.draw_string(
				ThemeDB.fallback_font,
				label_pos,
				day_labels[d],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				10,
				Color(0.5, 0.5, 0.6)
			)

	# Draw cells
	for w: int in weeks:
		for d: int in days:
			var key: String = "%d_%d" % [w, d]
			var activity: int = data.get(key, 0)
			var color_idx: int = clampi(activity, 0, HEATMAP_COLORS.size() - 1)

			var rect := Rect2(
				offset_x + w * (cell_size.x + gap),
				d * (cell_size.y + gap),
				cell_size.x,
				cell_size.y
			)

			_heat_map.draw_rect(rect, HEATMAP_COLORS[color_idx], true)


func _set_heatmap_data(data: Dictionary) -> void:
	if _heat_map:
		_heat_map.set_meta("data", data)
		_heat_map.queue_redraw()

# endregion


# region -- Achievement Showcase

func _create_achievements_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "AchievementsSection"
	section.add_theme_constant_override("separation", 15)

	# Section header
	var header := Label.new()
	header.text = "ACHIEVEMENT SHOWCASE"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	section.add_child(header)

	# Achievement grid
	var grid := HBoxContainer.new()
	grid.name = "AchievementGrid"
	grid.add_theme_constant_override("separation", 15)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER

	section.add_child(grid)
	return section


func _add_achievement_to_showcase(achievement: Dictionary) -> void:
	var section: Control = _main_content.get_node_or_null("Content/AchievementsSection")
	if not section:
		return

	var grid: HBoxContainer = section.get_node_or_null("AchievementGrid")
	if not grid:
		return

	var card := _create_achievement_card(achievement)
	grid.add_child(card)


func _create_achievement_card(achievement: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Achievement_%s" % achievement.get("id", "unknown")
	card.custom_minimum_size = Vector2(120, 120)
	card.set_meta("achievement", achievement)

	var rarity: String = achievement.get("rarity", "common")
	var rarity_colors: Dictionary = {
		"common": Color(0.6, 0.6, 0.6),
		"uncommon": Color(0.3, 0.8, 0.3),
		"rare": Color(0.3, 0.5, 1.0),
		"epic": Color(0.7, 0.3, 0.9),
		"legendary": Color(1.0, 0.6, 0.1),
	}

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = rarity_colors.get(rarity, Color.GRAY)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)

	# Icon placeholder
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(50, 50)
	icon.color = rarity_colors.get(rarity, Color.GRAY).darkened(0.3)
	vbox.add_child(icon)

	# Name
	var name_label := Label.new()
	name_label.text = achievement.get("name", "Achievement")
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	card.add_child(vbox)

	# Click handler
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				achievement_clicked.emit(achievement.get("id", ""))
	)

	return card

# endregion


# region -- Data Loading

## Load stats and animate everything
func load_stats(stats: Dictionary) -> void:
	_stats = stats.duplicate(true)
	_animate_all_elements()


## Set comparison stats for friend comparison mode
func set_comparison_stats(friend_stats: Dictionary) -> void:
	_comparison_stats = friend_stats.duplicate(true)
	if _comparison_mode:
		_update_comparisons()


## Toggle comparison mode
func set_comparison_mode(enabled: bool, friend_id: int = -1) -> void:
	_comparison_mode = enabled
	comparison_toggled.emit(enabled, friend_id)

	if enabled and not _comparison_stats.is_empty():
		_update_comparisons()
	else:
		_hide_comparisons()


func _animate_all_elements() -> void:
	# Animate stat cards with stagger
	for i: int in _stat_cards.size():
		var card: Control = _stat_cards[i]
		var config: Dictionary = card.get_meta("config", {})
		var key: String = config.get("key", "")
		var value: float = _stats.get(key, 0.0)

		# Delay for stagger effect
		await get_tree().create_timer(CARD_STAGGER_DELAY * i).timeout
		_animate_stat_card(card, value)

	# Animate progress rings
	for ring: Control in _progress_rings:
		var config: Dictionary = ring.get_meta("config", {})
		var key: String = config.get("key", "")
		var value: float = _stats.get(key, 0.0) / 100.0  # Convert percentage to 0-1
		_animate_progress_ring(ring, value)

	# Animate charts
	for chart: PanelContainer in _charts:
		var data_key: String = chart.get_meta("data_key", "")
		var data: Array = _stats.get(data_key, [])
		chart.set_meta("data_points", data)
		_animate_chart(chart)

	# Set heatmap data
	var heatmap_data: Dictionary = _stats.get("activity_heatmap", {})
	_set_heatmap_data(heatmap_data)

	# Load achievements
	var achievements: Array = _stats.get("featured_achievements", [])
	for achievement: Dictionary in achievements:
		_add_achievement_to_showcase(achievement)


func _update_comparisons() -> void:
	for card: PanelContainer in _stat_cards:
		var config: Dictionary = card.get_meta("config", {})
		var key: String = config.get("key", "")

		var my_value: float = _stats.get(key, 0.0)
		var friend_value: float = _comparison_stats.get(key, 0.0)
		var diff: float = my_value - friend_value

		var comparison: HBoxContainer = card.get_node_or_null("VBoxContainer/Comparison")
		if comparison:
			comparison.visible = true
			var diff_label: Label = comparison.get_node_or_null("DiffLabel")
			if diff_label:
				if diff > 0:
					diff_label.text = "+%.1f" % diff
					diff_label.add_theme_color_override("font_color", SECONDARY_COLOR)
				elif diff < 0:
					diff_label.text = "%.1f" % diff
					diff_label.add_theme_color_override("font_color", DANGER_COLOR)
				else:
					diff_label.text = "="
					diff_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))


func _hide_comparisons() -> void:
	for card: PanelContainer in _stat_cards:
		var comparison: HBoxContainer = card.get_node_or_null("VBoxContainer/Comparison")
		if comparison:
			comparison.visible = false

# endregion


# region -- Period Selection

func _on_period_selected(period: TimePeriod) -> void:
	if period == _current_period:
		return

	_current_period = period

	# Update button states
	for child: Node in _period_selector.get_children():
		if child is Button:
			var btn: Button = child
			var btn_period: int = btn.get_meta("period", -1)
			btn.button_pressed = btn_period == period

			var style := StyleBoxFlat.new()
			style.bg_color = PRIMARY_COLOR.darkened(0.3) if btn_period == period else Color(0.15, 0.15, 0.2)
			style.set_corner_radius_all(6)
			btn.add_theme_stylebox_override("normal", style)

	period_changed.emit(PERIOD_LABELS[period])

	# Reload stats for new period
	# This would typically call a method to fetch period-specific stats


## Get current time period
func get_current_period() -> TimePeriod:
	return _current_period

# endregion


# region -- Public API

## Refresh all stats displays
func refresh() -> void:
	_animate_all_elements()


## Get current stats
func get_stats() -> Dictionary:
	return _stats.duplicate(true)


## Check if in comparison mode
func is_comparison_mode() -> bool:
	return _comparison_mode

# endregion
