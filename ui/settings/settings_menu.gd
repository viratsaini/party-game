## SettingsMenu - Master controller for premium AAA-quality settings interface.
##
## Provides Modern Warfare / Valorant style settings with smooth animations,
## tabbed navigation, and premium UI components. Features include:
## - Smooth tab switching with slide animations
## - Change tracking with apply/reset functionality
## - Section organization with decorative headers
## - Tooltip system with fade-in animations
## - Success/confirmation animations
class_name SettingsMenu
extends Control

# ============================================================================ #
#                                   SIGNALS                                     #
# ============================================================================ #

## Emitted when any setting value changes.
signal setting_changed(key: String, value: Variant)

## Emitted when settings are applied.
signal settings_applied

## Emitted when settings are reset to defaults.
signal settings_reset

## Emitted when the menu is closed.
signal menu_closed

# ============================================================================ #
#                                  CONSTANTS                                    #
# ============================================================================ #

const TAB_SLIDE_DURATION: float = 0.35
const TAB_INDICATOR_SLIDE_DURATION: float = 0.25
const PANEL_FADE_DURATION: float = 0.2
const TOOLTIP_FADE_DURATION: float = 0.15
const TOOLTIP_DELAY: float = 0.5
const SCROLL_MOMENTUM_FRICTION: float = 0.92
const SCROLL_SPEED_MULTIPLIER: float = 2.5

## Tab definitions with icons.
enum SettingsTab {
	CONTROLS,
	GRAPHICS,
	AUDIO,
	GAMEPLAY,
	ACCESSIBILITY
}

const TAB_DATA: Dictionary = {
	SettingsTab.CONTROLS: {"name": "Controls", "icon": "keyboard"},
	SettingsTab.GRAPHICS: {"name": "Graphics", "icon": "display"},
	SettingsTab.AUDIO: {"name": "Audio", "icon": "volume"},
	SettingsTab.GAMEPLAY: {"name": "Gameplay", "icon": "controller"},
	SettingsTab.ACCESSIBILITY: {"name": "Accessibility", "icon": "accessibility"},
}

# ============================================================================ #
#                               THEME CONSTANTS                                 #
# ============================================================================ #

const COLORS := {
	"background": Color(0.08, 0.08, 0.1, 0.98),
	"panel": Color(0.12, 0.12, 0.15, 1.0),
	"panel_hover": Color(0.15, 0.15, 0.18, 1.0),
	"accent": Color(0.2, 0.6, 1.0, 1.0),
	"accent_glow": Color(0.3, 0.7, 1.0, 0.5),
	"success": Color(0.2, 0.8, 0.3, 1.0),
	"warning": Color(1.0, 0.7, 0.2, 1.0),
	"error": Color(1.0, 0.3, 0.3, 1.0),
	"text_primary": Color(1.0, 1.0, 1.0, 1.0),
	"text_secondary": Color(0.7, 0.7, 0.75, 1.0),
	"text_disabled": Color(0.4, 0.4, 0.45, 1.0),
	"tab_inactive": Color(0.5, 0.5, 0.55, 1.0),
	"tab_active": Color(1.0, 1.0, 1.0, 1.0),
	"divider": Color(0.25, 0.25, 0.3, 1.0),
	"modified": Color(1.0, 0.8, 0.2, 1.0),
}

const FONTS := {
	"header_size": 28,
	"tab_size": 16,
	"label_size": 14,
	"value_size": 13,
	"tooltip_size": 12,
}

# ============================================================================ #
#                                  EXPORTS                                      #
# ============================================================================ #

## Enable sound effects for UI interactions.
@export var enable_sounds: bool = true

## Enable haptic feedback (for gamepads).
@export var enable_haptics: bool = true

## Show FPS counter in graphics settings.
@export var show_fps_counter: bool = true

# ============================================================================ #
#                                   STATE                                       #
# ============================================================================ #

## Current active tab.
var current_tab: SettingsTab = SettingsTab.CONTROLS

## Pending changes that haven't been applied yet.
var pending_changes: Dictionary = {}

## Original values before changes (for reset).
var original_values: Dictionary = {}

## Whether any changes are pending.
var has_pending_changes: bool = false:
	get:
		return not pending_changes.is_empty()

## Scroll momentum velocity.
var scroll_velocity: float = 0.0

## Tooltip timer.
var tooltip_timer: float = 0.0
var tooltip_target: Control = null
var tooltip_text: String = ""

## Currently focused keybind button (for rebinding).
var active_keybind: Control = null

# ============================================================================ #
#                                   NODES                                       #
# ============================================================================ #

## Main containers.
var background: ColorRect
var main_container: VBoxContainer
var header_container: HBoxContainer
var tab_container: HBoxContainer
var tab_indicator: ColorRect
var content_container: MarginContainer
var scroll_container: ScrollContainer
var content_panels: Dictionary = {}  # SettingsTab -> Control
var footer_container: HBoxContainer

## Tooltip overlay.
var tooltip_panel: PanelContainer
var tooltip_label: Label

## Confirmation dialog.
var confirmation_dialog: Control

## Buttons.
var apply_button: Button
var reset_button: Button
var back_button: Button

## Tab buttons.
var tab_buttons: Dictionary = {}  # SettingsTab -> Button

## Premium components.
var premium_sliders: Array[Control] = []
var animated_toggles: Array[Control] = []
var dropdown_selects: Array[Control] = []
var keybind_buttons: Array[Control] = []
var audio_visualizer: Control

# ============================================================================ #
#                                 LIFECYCLE                                     #
# ============================================================================ #

func _ready() -> void:
	_build_ui()
	_setup_tabs()
	_setup_content_panels()
	_setup_footer()
	_setup_tooltip()
	_connect_signals()
	_load_current_settings()
	_play_entrance_animation()


func _process(delta: float) -> void:
	_update_scroll_momentum(delta)
	_update_tooltip(delta)
	_update_fps_counter(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if active_keybind:
				_cancel_keybind()
			else:
				_on_back_pressed()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Handle keybind capture.
	if active_keybind and event.pressed:
		if event is InputEventKey or event is InputEventMouseButton:
			_complete_keybind(event)
			get_viewport().set_input_as_handled()

# ============================================================================ #
#                                 UI BUILDING                                   #
# ============================================================================ #

func _build_ui() -> void:
	# Main background with blur effect.
	background = ColorRect.new()
	background.name = "Background"
	background.color = COLORS["background"]
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Main container.
	main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 0)
	add_child(main_container)

	# Header with title and close button.
	_build_header()

	# Tab bar.
	_build_tab_bar()

	# Content area.
	_build_content_area()

	# Footer with apply/reset buttons.
	_build_footer()


func _build_header() -> void:
	header_container = HBoxContainer.new()
	header_container.name = "HeaderContainer"
	header_container.custom_minimum_size.y = 80
	header_container.add_theme_constant_override("separation", 20)
	main_container.add_child(header_container)

	# Left spacer.
	var left_margin := Control.new()
	left_margin.custom_minimum_size.x = 40
	header_container.add_child(left_margin)

	# Title.
	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "SETTINGS"
	title_label.add_theme_font_size_override("font_size", FONTS["header_size"])
	title_label.add_theme_color_override("font_color", COLORS["text_primary"])
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(title_label)

	# Close button.
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.flat = true
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(_on_back_pressed)
	header_container.add_child(close_button)

	# Right spacer.
	var right_margin := Control.new()
	right_margin.custom_minimum_size.x = 40
	header_container.add_child(right_margin)

	# Divider line.
	var divider := ColorRect.new()
	divider.name = "HeaderDivider"
	divider.color = COLORS["divider"]
	divider.custom_minimum_size.y = 2
	main_container.add_child(divider)


func _build_tab_bar() -> void:
	var tab_bar_container := MarginContainer.new()
	tab_bar_container.name = "TabBarContainer"
	tab_bar_container.add_theme_constant_override("margin_left", 40)
	tab_bar_container.add_theme_constant_override("margin_right", 40)
	tab_bar_container.add_theme_constant_override("margin_top", 15)
	tab_bar_container.add_theme_constant_override("margin_bottom", 15)
	main_container.add_child(tab_bar_container)

	var tab_wrapper := Control.new()
	tab_wrapper.name = "TabWrapper"
	tab_wrapper.custom_minimum_size.y = 50
	tab_bar_container.add_child(tab_wrapper)

	tab_container = HBoxContainer.new()
	tab_container.name = "TabContainer"
	tab_container.add_theme_constant_override("separation", 30)
	tab_container.set_anchors_preset(Control.PRESET_CENTER)
	tab_wrapper.add_child(tab_container)

	# Tab indicator line.
	tab_indicator = ColorRect.new()
	tab_indicator.name = "TabIndicator"
	tab_indicator.color = COLORS["accent"]
	tab_indicator.custom_minimum_size = Vector2(80, 3)
	tab_indicator.position.y = 45
	tab_wrapper.add_child(tab_indicator)

	# Add glow effect to indicator.
	_add_glow_effect(tab_indicator, COLORS["accent_glow"], 8.0)


func _build_content_area() -> void:
	content_container = MarginContainer.new()
	content_container.name = "ContentContainer"
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("margin_left", 60)
	content_container.add_theme_constant_override("margin_right", 60)
	content_container.add_theme_constant_override("margin_top", 20)
	content_container.add_theme_constant_override("margin_bottom", 20)
	main_container.add_child(content_container)

	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(scroll_container)


func _build_footer() -> void:
	# Divider line.
	var divider := ColorRect.new()
	divider.name = "FooterDivider"
	divider.color = COLORS["divider"]
	divider.custom_minimum_size.y = 2
	main_container.add_child(divider)

	footer_container = HBoxContainer.new()
	footer_container.name = "FooterContainer"
	footer_container.custom_minimum_size.y = 70
	footer_container.add_theme_constant_override("separation", 15)
	footer_container.alignment = BoxContainer.ALIGNMENT_END
	main_container.add_child(footer_container)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_container.add_child(spacer)


func _setup_tabs() -> void:
	for tab_id: int in TAB_DATA:
		var tab_data: Dictionary = TAB_DATA[tab_id]
		var tab_button := _create_tab_button(tab_id, tab_data["name"], tab_data["icon"])
		tab_container.add_child(tab_button)
		tab_buttons[tab_id] = tab_button

	# Position indicator under first tab.
	await get_tree().process_frame
	_update_tab_indicator(false)


func _create_tab_button(tab_id: int, tab_name: String, icon_name: String) -> Button:
	var button := Button.new()
	button.name = "Tab_%s" % tab_name
	button.text = tab_name.to_upper()
	button.flat = true
	button.custom_minimum_size = Vector2(100, 40)
	button.add_theme_font_size_override("font_size", FONTS["tab_size"])

	# Set initial state.
	var is_active := tab_id == current_tab
	button.add_theme_color_override("font_color", COLORS["tab_active"] if is_active else COLORS["tab_inactive"])

	# Connect signals.
	button.pressed.connect(_on_tab_pressed.bind(tab_id))
	button.mouse_entered.connect(_on_tab_hover.bind(button, true))
	button.mouse_exited.connect(_on_tab_hover.bind(button, false))

	return button


func _setup_content_panels() -> void:
	# Create content panel for each tab.
	for tab_id: int in TAB_DATA:
		var panel := _create_content_panel(tab_id)
		content_panels[tab_id] = panel
		scroll_container.add_child(panel)
		panel.visible = tab_id == current_tab


func _create_content_panel(tab_id: int) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.name = "Panel_%s" % TAB_DATA[tab_id]["name"]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 20)

	match tab_id:
		SettingsTab.CONTROLS:
			_populate_controls_panel(panel)
		SettingsTab.GRAPHICS:
			_populate_graphics_panel(panel)
		SettingsTab.AUDIO:
			_populate_audio_panel(panel)
		SettingsTab.GAMEPLAY:
			_populate_gameplay_panel(panel)
		SettingsTab.ACCESSIBILITY:
			_populate_accessibility_panel(panel)

	return panel


func _setup_footer() -> void:
	# Reset button.
	reset_button = _create_footer_button("RESET", COLORS["warning"])
	reset_button.pressed.connect(_on_reset_pressed)
	footer_container.add_child(reset_button)

	# Apply button.
	apply_button = _create_footer_button("APPLY", COLORS["success"])
	apply_button.pressed.connect(_on_apply_pressed)
	footer_container.add_child(apply_button)

	# Back button.
	back_button = _create_footer_button("BACK", COLORS["text_secondary"])
	back_button.pressed.connect(_on_back_pressed)
	footer_container.add_child(back_button)

	# Right margin.
	var margin := Control.new()
	margin.custom_minimum_size.x = 40
	footer_container.add_child(margin)


func _create_footer_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 45)
	button.add_theme_font_size_override("font_size", 14)

	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.6)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_bottom = 3
	style.border_color = color
	button.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = color.darkened(0.4)
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = color.darkened(0.2)
	button.add_theme_stylebox_override("pressed", pressed_style)

	# Hover effect.
	button.mouse_entered.connect(_on_button_hover.bind(button))
	button.mouse_exited.connect(_on_button_unhover.bind(button))

	return button


func _setup_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "TooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 100
	add_child(tooltip_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	tooltip_panel.add_theme_stylebox_override("panel", style)

	tooltip_label = Label.new()
	tooltip_label.add_theme_font_size_override("font_size", FONTS["tooltip_size"])
	tooltip_label.add_theme_color_override("font_color", COLORS["text_secondary"])
	tooltip_panel.add_child(tooltip_label)


func _connect_signals() -> void:
	# Scroll handling.
	scroll_container.gui_input.connect(_on_scroll_input)

# ============================================================================ #
#                              PANEL POPULATION                                 #
# ============================================================================ #

func _populate_controls_panel(panel: VBoxContainer) -> void:
	_add_section_header(panel, "KEYBINDINGS")

	var keybinds := [
		{"key": "move_forward", "label": "Move Forward", "default": "W"},
		{"key": "move_backward", "label": "Move Backward", "default": "S"},
		{"key": "move_left", "label": "Move Left", "default": "A"},
		{"key": "move_right", "label": "Move Right", "default": "D"},
		{"key": "jump", "label": "Jump", "default": "Space"},
		{"key": "crouch", "label": "Crouch", "default": "Ctrl"},
		{"key": "sprint", "label": "Sprint", "default": "Shift"},
		{"key": "fire", "label": "Fire", "default": "Mouse 1"},
		{"key": "aim", "label": "Aim", "default": "Mouse 2"},
		{"key": "reload", "label": "Reload", "default": "R"},
		{"key": "interact", "label": "Interact", "default": "E"},
		{"key": "melee", "label": "Melee", "default": "V"},
		{"key": "jetpack", "label": "Jetpack", "default": "Space (Hold)"},
	]

	for bind: Dictionary in keybinds:
		var keybind_row := _create_keybind_row(bind["key"], bind["label"], bind["default"])
		panel.add_child(keybind_row)

	_add_section_header(panel, "MOUSE")

	var sensitivity_slider := _create_premium_slider(
		"mouse_sensitivity", "Mouse Sensitivity", 0.1, 10.0, 2.5,
		"Adjust mouse look sensitivity", [0.5, 1.0, 2.5, 5.0, 10.0]
	)
	panel.add_child(sensitivity_slider)

	var aim_sens_slider := _create_premium_slider(
		"aim_sensitivity", "ADS Sensitivity", 0.1, 2.0, 0.8,
		"Sensitivity multiplier when aiming", [0.25, 0.5, 0.8, 1.0, 1.5]
	)
	panel.add_child(aim_sens_slider)

	var invert_y := _create_toggle_row("invert_y", "Invert Y-Axis", false, "Invert vertical mouse movement")
	panel.add_child(invert_y)

	var raw_input := _create_toggle_row("raw_input", "Raw Input", true, "Bypass OS mouse acceleration")
	panel.add_child(raw_input)


func _populate_graphics_panel(panel: VBoxContainer) -> void:
	_add_section_header(panel, "QUALITY PRESET")

	var presets := _create_graphics_presets()
	panel.add_child(presets)

	_add_section_header(panel, "DISPLAY")

	var resolution := _create_dropdown_row(
		"resolution", "Resolution",
		["1920x1080", "2560x1440", "3840x2160", "1280x720", "1600x900"],
		0, "Screen resolution"
	)
	panel.add_child(resolution)

	var display_mode := _create_dropdown_row(
		"display_mode", "Display Mode",
		["Fullscreen", "Windowed", "Borderless"],
		0, "Window display mode"
	)
	panel.add_child(display_mode)

	var vsync := _create_toggle_row("vsync", "V-Sync", true, "Sync framerate to monitor refresh rate")
	panel.add_child(vsync)

	var fps_limit := _create_dropdown_row(
		"fps_limit", "FPS Limit",
		["Unlimited", "240", "144", "120", "60", "30"],
		0, "Maximum frames per second"
	)
	panel.add_child(fps_limit)

	_add_section_header(panel, "RENDERING")

	var shadow_quality := _create_dropdown_row(
		"shadow_quality", "Shadow Quality",
		["Ultra", "High", "Medium", "Low", "Off"],
		1, "Shadow map resolution and filtering"
	)
	panel.add_child(shadow_quality)

	var texture_quality := _create_dropdown_row(
		"texture_quality", "Texture Quality",
		["Ultra", "High", "Medium", "Low"],
		0, "Texture resolution"
	)
	panel.add_child(texture_quality)

	var aa_mode := _create_dropdown_row(
		"anti_aliasing", "Anti-Aliasing",
		["TAA", "FXAA", "MSAA 4x", "MSAA 2x", "Off"],
		0, "Anti-aliasing method"
	)
	panel.add_child(aa_mode)

	_add_section_header(panel, "EFFECTS")

	var bloom := _create_toggle_row("bloom", "Bloom", true, "Glowing light effects")
	panel.add_child(bloom)

	var motion_blur := _create_toggle_row("motion_blur", "Motion Blur", false, "Blur effect during fast movement")
	panel.add_child(motion_blur)

	var ambient_occlusion := _create_toggle_row("ambient_occlusion", "Ambient Occlusion", true, "Contact shadows in corners")
	panel.add_child(ambient_occlusion)

	var depth_of_field := _create_toggle_row("depth_of_field", "Depth of Field", false, "Focus blur effect")
	panel.add_child(depth_of_field)

	var particles := _create_premium_slider(
		"particle_density", "Particle Density", 0.0, 1.0, 1.0,
		"Amount of particle effects", [0.0, 0.25, 0.5, 0.75, 1.0]
	)
	panel.add_child(particles)

	# FPS Counter display.
	if show_fps_counter:
		_add_fps_counter(panel)


func _populate_audio_panel(panel: VBoxContainer) -> void:
	_add_section_header(panel, "VOLUME")

	# Audio visualizer.
	audio_visualizer = _create_audio_visualizer()
	panel.add_child(audio_visualizer)

	var master := _create_premium_slider(
		"master_volume", "Master Volume", 0.0, 1.0, 1.0,
		"Overall game volume", [0.0, 0.25, 0.5, 0.75, 1.0]
	)
	panel.add_child(master)

	var music := _create_premium_slider(
		"music_volume", "Music Volume", 0.0, 1.0, 0.8,
		"Background music volume", [0.0, 0.25, 0.5, 0.75, 1.0]
	)
	panel.add_child(music)

	var sfx := _create_premium_slider(
		"sfx_volume", "SFX Volume", 0.0, 1.0, 1.0,
		"Sound effects volume", [0.0, 0.25, 0.5, 0.75, 1.0]
	)
	panel.add_child(sfx)

	var ambient := _create_premium_slider(
		"ambient_volume", "Ambient Volume", 0.0, 1.0, 0.7,
		"Environmental sounds", [0.0, 0.25, 0.5, 0.75, 1.0]
	)
	panel.add_child(ambient)

	var voice := _create_premium_slider(
		"voice_volume", "Voice Volume", 0.0, 1.0, 1.0,
		"Character voices and callouts", [0.0, 0.25, 0.5, 0.75, 1.0]
	)
	panel.add_child(voice)

	_add_section_header(panel, "SPATIAL AUDIO")

	var occlusion := _create_toggle_row("audio_occlusion", "Audio Occlusion", true, "Muffle sounds through walls")
	panel.add_child(occlusion)

	var doppler := _create_toggle_row("doppler_effect", "Doppler Effect", true, "Pitch shift for moving sounds")
	panel.add_child(doppler)

	var hrtf := _create_toggle_row("hrtf", "HRTF (3D Audio)", false, "Enhanced 3D audio positioning")
	panel.add_child(hrtf)

	_add_section_header(panel, "OUTPUT")

	var output_device := _create_dropdown_row(
		"audio_device", "Output Device",
		["System Default", "Speakers", "Headphones"],
		0, "Audio output device"
	)
	panel.add_child(output_device)

	# Test sound button.
	var test_button := _create_test_sound_button()
	panel.add_child(test_button)


func _populate_gameplay_panel(panel: VBoxContainer) -> void:
	_add_section_header(panel, "HUD")

	var crosshair_style := _create_dropdown_row(
		"crosshair_style", "Crosshair Style",
		["Default", "Dot", "Circle", "Cross", "Custom"],
		0, "Crosshair appearance"
	)
	panel.add_child(crosshair_style)

	var crosshair_color := _create_dropdown_row(
		"crosshair_color", "Crosshair Color",
		["White", "Green", "Red", "Cyan", "Yellow", "Pink"],
		1, "Crosshair color"
	)
	panel.add_child(crosshair_color)

	var crosshair_size := _create_premium_slider(
		"crosshair_size", "Crosshair Size", 0.5, 2.0, 1.0,
		"Crosshair scale", [0.5, 0.75, 1.0, 1.5, 2.0]
	)
	panel.add_child(crosshair_size)

	var hit_markers := _create_toggle_row("hit_markers", "Hit Markers", true, "Visual feedback on enemy hits")
	panel.add_child(hit_markers)

	var damage_numbers := _create_toggle_row("damage_numbers", "Damage Numbers", true, "Show damage dealt")
	panel.add_child(damage_numbers)

	var kill_feed := _create_toggle_row("kill_feed", "Kill Feed", true, "Show elimination notifications")
	panel.add_child(kill_feed)

	_add_section_header(panel, "CAMERA")

	var fov := _create_premium_slider(
		"field_of_view", "Field of View", 60.0, 120.0, 90.0,
		"Camera field of view", [60.0, 75.0, 90.0, 105.0, 120.0]
	)
	panel.add_child(fov)

	var camera_shake := _create_premium_slider(
		"camera_shake", "Camera Shake", 0.0, 1.0, 0.5,
		"Screen shake intensity", [0.0, 0.25, 0.5, 0.75, 1.0]
	)
	panel.add_child(camera_shake)

	_add_section_header(panel, "NETWORK")

	var show_ping := _create_toggle_row("show_ping", "Show Ping", true, "Display network latency")
	panel.add_child(show_ping)

	var show_fps := _create_toggle_row("show_fps", "Show FPS", false, "Display framerate counter")
	panel.add_child(show_fps)


func _populate_accessibility_panel(panel: VBoxContainer) -> void:
	_add_section_header(panel, "VISUAL")

	var colorblind := _create_dropdown_row(
		"colorblind_mode", "Colorblind Mode",
		["Off", "Protanopia", "Deuteranopia", "Tritanopia"],
		0, "Color correction for colorblindness"
	)
	panel.add_child(colorblind)

	var ui_scale := _create_premium_slider(
		"ui_scale", "UI Scale", 0.75, 1.5, 1.0,
		"Interface size", [0.75, 0.875, 1.0, 1.25, 1.5]
	)
	panel.add_child(ui_scale)

	var subtitles := _create_toggle_row("subtitles", "Subtitles", true, "Display text for audio")
	panel.add_child(subtitles)

	var subtitle_size := _create_dropdown_row(
		"subtitle_size", "Subtitle Size",
		["Small", "Medium", "Large", "Extra Large"],
		1, "Subtitle text size"
	)
	panel.add_child(subtitle_size)

	var high_contrast := _create_toggle_row("high_contrast", "High Contrast", false, "Increase visual contrast")
	panel.add_child(high_contrast)

	var flash_reduction := _create_toggle_row("flash_reduction", "Reduce Flashing", false, "Minimize screen flashes")
	panel.add_child(flash_reduction)

	_add_section_header(panel, "CONTROLS")

	var hold_to_aim := _create_toggle_row("hold_to_aim", "Hold to Aim", true, "Hold vs toggle for aiming")
	panel.add_child(hold_to_aim)

	var hold_to_crouch := _create_toggle_row("hold_to_crouch", "Hold to Crouch", true, "Hold vs toggle for crouching")
	panel.add_child(hold_to_crouch)

	var auto_sprint := _create_toggle_row("auto_sprint", "Auto Sprint", false, "Automatically sprint when moving")
	panel.add_child(auto_sprint)

# ============================================================================ #
#                            COMPONENT CREATION                                 #
# ============================================================================ #

func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 15)
	container.custom_minimum_size.y = 50
	parent.add_child(container)

	# Left line.
	var left_line := ColorRect.new()
	left_line.color = COLORS["divider"]
	left_line.custom_minimum_size = Vector2(30, 2)
	left_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.add_child(left_line)

	# Section title.
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COLORS["text_secondary"])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	# Right line.
	var right_line := ColorRect.new()
	right_line.color = COLORS["divider"]
	right_line.custom_minimum_size.y = 2
	right_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.add_child(right_line)


func _create_premium_slider(
	key: String, label_text: String, min_val: float, max_val: float,
	default_val: float, tooltip: String, tick_values: Array = []
) -> Control:
	var PremiumSlider := load("res://ui/settings/premium_slider.gd")

	var container := HBoxContainer.new()
	container.name = "SliderRow_%s" % key
	container.custom_minimum_size.y = 50

	# Label.
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 200
	label.add_theme_font_size_override("font_size", FONTS["label_size"])
	label.add_theme_color_override("font_color", COLORS["text_primary"])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

	# Premium slider.
	var slider: Control
	if PremiumSlider:
		slider = PremiumSlider.new()
		slider.setting_key = key
		slider.min_value = min_val
		slider.max_value = max_val
		slider.value = default_val
		slider.tick_values = tick_values
		slider.value_changed_signal.connect(_on_slider_changed.bind(key))
	else:
		# Fallback to standard slider.
		slider = HSlider.new()
		slider.min_value = min_val
		slider.max_value = max_val
		slider.value = default_val
		slider.step = 0.01
		slider.value_changed.connect(_on_slider_changed.bind(key))

	slider.custom_minimum_size = Vector2(300, 30)
	container.add_child(slider)

	premium_sliders.append(slider)

	# Setup tooltip.
	container.mouse_entered.connect(_show_tooltip.bind(container, tooltip))
	container.mouse_exited.connect(_hide_tooltip)

	return container


func _create_toggle_row(key: String, label_text: String, default_val: bool, tooltip: String) -> Control:
	var AnimatedToggle := load("res://ui/settings/animated_toggle.gd")

	var container := HBoxContainer.new()
	container.name = "ToggleRow_%s" % key
	container.custom_minimum_size.y = 50

	# Label.
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 200
	label.add_theme_font_size_override("font_size", FONTS["label_size"])
	label.add_theme_color_override("font_color", COLORS["text_primary"])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

	# Animated toggle.
	var toggle: Control
	if AnimatedToggle:
		toggle = AnimatedToggle.new()
		toggle.setting_key = key
		toggle.toggled_on = default_val
		toggle.toggled_signal.connect(_on_toggle_changed.bind(key))
	else:
		# Fallback to CheckButton.
		toggle = CheckButton.new()
		toggle.button_pressed = default_val
		toggle.toggled.connect(_on_toggle_changed.bind(key))

	toggle.custom_minimum_size = Vector2(60, 30)
	container.add_child(toggle)

	animated_toggles.append(toggle)

	# Setup tooltip.
	container.mouse_entered.connect(_show_tooltip.bind(container, tooltip))
	container.mouse_exited.connect(_hide_tooltip)

	return container


func _create_dropdown_row(
	key: String, label_text: String, options: Array, default_idx: int, tooltip: String
) -> Control:
	var DropdownSelect := load("res://ui/settings/dropdown_select.gd")

	var container := HBoxContainer.new()
	container.name = "DropdownRow_%s" % key
	container.custom_minimum_size.y = 50

	# Label.
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 200
	label.add_theme_font_size_override("font_size", FONTS["label_size"])
	label.add_theme_color_override("font_color", COLORS["text_primary"])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

	# Dropdown.
	var dropdown: Control
	if DropdownSelect:
		dropdown = DropdownSelect.new()
		dropdown.setting_key = key
		dropdown.options = options
		dropdown.selected_index = default_idx
		dropdown.option_selected_signal.connect(_on_dropdown_changed.bind(key))
	else:
		# Fallback to OptionButton.
		dropdown = OptionButton.new()
		for opt: String in options:
			dropdown.add_item(opt)
		dropdown.selected = default_idx
		dropdown.item_selected.connect(_on_dropdown_changed.bind(key))

	dropdown.custom_minimum_size = Vector2(200, 35)
	container.add_child(dropdown)

	dropdown_selects.append(dropdown)

	# Setup tooltip.
	container.mouse_entered.connect(_show_tooltip.bind(container, tooltip))
	container.mouse_exited.connect(_hide_tooltip)

	return container


func _create_keybind_row(key: String, label_text: String, current_bind: String) -> Control:
	var KeybindButton := load("res://ui/settings/keybind_button.gd")

	var container := HBoxContainer.new()
	container.name = "KeybindRow_%s" % key
	container.custom_minimum_size.y = 45

	# Label.
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 200
	label.add_theme_font_size_override("font_size", FONTS["label_size"])
	label.add_theme_color_override("font_color", COLORS["text_primary"])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

	# Keybind button.
	var keybind: Control
	if KeybindButton:
		keybind = KeybindButton.new()
		keybind.action_name = key
		keybind.current_binding = current_bind
		keybind.rebind_started.connect(_on_keybind_start.bind(keybind))
		keybind.rebind_completed.connect(_on_keybind_complete.bind(key))
		keybind.rebind_cancelled.connect(_on_keybind_cancel)
	else:
		# Fallback to Button.
		keybind = Button.new()
		keybind.text = "[%s]" % current_bind
		keybind.pressed.connect(_on_keybind_button_pressed.bind(keybind, key))

	keybind.custom_minimum_size = Vector2(150, 35)
	container.add_child(keybind)

	keybind_buttons.append(keybind)

	return container


func _create_graphics_presets() -> Control:
	var container := HBoxContainer.new()
	container.name = "GraphicsPresets"
	container.add_theme_constant_override("separation", 15)
	container.custom_minimum_size.y = 80

	var presets := ["LOW", "MEDIUM", "HIGH", "ULTRA", "CUSTOM"]
	var colors := [
		COLORS["text_secondary"],
		COLORS["warning"],
		COLORS["success"],
		COLORS["accent"],
		COLORS["text_primary"]
	]

	for i: int in presets.size():
		var preset_name: String = presets[i]
		var preset_color: Color = colors[i]

		var button := Button.new()
		button.text = preset_name
		button.custom_minimum_size = Vector2(100, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style := StyleBoxFlat.new()
		style.bg_color = COLORS["panel"]
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.border_width_bottom = 4
		style.border_color = preset_color.darkened(0.3)
		button.add_theme_stylebox_override("normal", style)

		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.bg_color = COLORS["panel_hover"]
		hover_style.border_color = preset_color
		button.add_theme_stylebox_override("hover", hover_style)

		button.pressed.connect(_on_preset_selected.bind(i))
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.mouse_exited.connect(_on_button_unhover.bind(button))

		container.add_child(button)

	return container


func _create_audio_visualizer() -> Control:
	var AudioVisualizer := load("res://ui/settings/audio_visualizer.gd")

	if AudioVisualizer:
		var visualizer: Control = AudioVisualizer.new()
		visualizer.custom_minimum_size = Vector2(0, 80)
		return visualizer
	else:
		# Fallback placeholder.
		var placeholder := ColorRect.new()
		placeholder.color = COLORS["panel"]
		placeholder.custom_minimum_size = Vector2(0, 80)
		return placeholder


func _create_test_sound_button() -> Control:
	var container := HBoxContainer.new()
	container.custom_minimum_size.y = 50

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

	var button := Button.new()
	button.text = "TEST SOUND"
	button.custom_minimum_size = Vector2(150, 40)

	var style := StyleBoxFlat.new()
	style.bg_color = COLORS["accent"].darkened(0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_bottom = 3
	style.border_color = COLORS["accent"]
	button.add_theme_stylebox_override("normal", style)

	button.pressed.connect(_on_test_sound_pressed)
	button.mouse_entered.connect(_on_button_hover.bind(button))
	button.mouse_exited.connect(_on_button_unhover.bind(button))

	container.add_child(button)

	return container


func _add_fps_counter(panel: VBoxContainer) -> void:
	var container := HBoxContainer.new()
	container.name = "FPSCounter"
	container.custom_minimum_size.y = 40

	var label := Label.new()
	label.name = "FPSLabel"
	label.text = "FPS: --"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLORS["success"])
	container.add_child(label)

	panel.add_child(container)


func _add_glow_effect(node: Control, color: Color, size: float) -> void:
	# Add a glow shader or duplicate node for glow effect.
	# This is a simplified version using modulate.
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.color = color
	glow.modulate.a = 0.5
	glow.custom_minimum_size = node.custom_minimum_size + Vector2(size * 2, size * 2)
	glow.position = Vector2(-size, -size)
	glow.z_index = -1
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(glow)

# ============================================================================ #
#                               EVENT HANDLERS                                  #
# ============================================================================ #

func _on_tab_pressed(tab_id: int) -> void:
	if tab_id == current_tab:
		return

	_play_ui_sound("tab_switch")

	var old_panel: Control = content_panels.get(current_tab)
	var new_panel: Control = content_panels.get(tab_id)

	# Update tab button states.
	if tab_buttons.has(current_tab):
		var old_button: Button = tab_buttons[current_tab]
		old_button.add_theme_color_override("font_color", COLORS["tab_inactive"])
		_animate_tab_button(old_button, false)

	if tab_buttons.has(tab_id):
		var new_button: Button = tab_buttons[tab_id]
		new_button.add_theme_color_override("font_color", COLORS["tab_active"])
		_animate_tab_button(new_button, true)

	current_tab = tab_id

	# Slide animation for panels.
	_animate_panel_transition(old_panel, new_panel)

	# Update tab indicator.
	_update_tab_indicator(true)


func _on_tab_hover(button: Button, hovering: bool) -> void:
	if hovering:
		_play_ui_sound("hover")

	if button.get_theme_color("font_color") != COLORS["tab_active"]:
		var target_color: Color = COLORS["text_primary"] if hovering else COLORS["tab_inactive"]
		var tween := create_tween()
		tween.tween_property(button, "theme_override_colors/font_color", target_color, 0.15)


func _on_button_hover(button: Button) -> void:
	_play_ui_sound("hover")
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.03, 1.03), 0.1)


func _on_button_unhover(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.1)


func _on_slider_changed(value: float, key: String) -> void:
	_register_change(key, value)
	_play_ui_sound("slider_tick")
	setting_changed.emit(key, value)


func _on_toggle_changed(enabled: bool, key: String) -> void:
	_register_change(key, enabled)
	_play_ui_sound("toggle_click")
	setting_changed.emit(key, enabled)


func _on_dropdown_changed(index: int, key: String) -> void:
	_register_change(key, index)
	_play_ui_sound("dropdown_select")
	setting_changed.emit(key, index)


func _on_keybind_start(keybind: Control) -> void:
	active_keybind = keybind
	_play_ui_sound("keybind_wait")


func _on_keybind_complete(binding: String, key: String) -> void:
	active_keybind = null
	_register_change(key, binding)
	_play_ui_sound("keybind_success")
	setting_changed.emit(key, binding)


func _on_keybind_cancel() -> void:
	active_keybind = null
	_play_ui_sound("keybind_cancel")


func _on_keybind_button_pressed(button: Button, key: String) -> void:
	# Fallback keybind handling.
	button.text = "Press a key..."
	active_keybind = button
	_play_ui_sound("keybind_wait")


func _cancel_keybind() -> void:
	if active_keybind:
		if active_keybind.has_method("cancel_rebind"):
			active_keybind.cancel_rebind()
		active_keybind = null


func _complete_keybind(event: InputEvent) -> void:
	if not active_keybind:
		return

	var key_name := ""
	if event is InputEventKey:
		key_name = OS.get_keycode_string(event.keycode)
	elif event is InputEventMouseButton:
		key_name = "Mouse %d" % event.button_index

	if active_keybind.has_method("complete_rebind"):
		active_keybind.complete_rebind(key_name)
	elif active_keybind is Button:
		active_keybind.text = "[%s]" % key_name

	_play_ui_sound("keybind_success")
	active_keybind = null


func _on_preset_selected(preset_idx: int) -> void:
	_play_ui_sound("preset_select")
	_apply_graphics_preset(preset_idx)


func _on_test_sound_pressed() -> void:
	_play_ui_sound("test_sound")
	if audio_visualizer and audio_visualizer.has_method("play_test_animation"):
		audio_visualizer.play_test_animation()


func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_velocity -= 50.0 * SCROLL_SPEED_MULTIPLIER
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_velocity += 50.0 * SCROLL_SPEED_MULTIPLIER


func _on_apply_pressed() -> void:
	_play_ui_sound("apply")
	_apply_pending_changes()
	_play_success_animation()
	settings_applied.emit()


func _on_reset_pressed() -> void:
	_play_ui_sound("reset")
	_show_confirmation("Reset all settings to default?", _reset_to_defaults)


func _on_back_pressed() -> void:
	if has_pending_changes:
		_show_confirmation("You have unsaved changes. Discard?", _close_menu)
	else:
		_close_menu()

# ============================================================================ #
#                                ANIMATIONS                                     #
# ============================================================================ #

func _play_entrance_animation() -> void:
	modulate.a = 0.0
	main_container.scale = Vector2(0.95, 0.95)
	main_container.position.y += 30

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(main_container, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(main_container, "position:y", main_container.position.y - 30, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _animate_tab_button(button: Button, active: bool) -> void:
	var target_scale := Vector2(1.05, 1.05) if active else Vector2.ONE
	var tween := create_tween()
	tween.tween_property(button, "scale", target_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_tab_indicator(animate: bool) -> void:
	if not tab_buttons.has(current_tab):
		return

	var button: Button = tab_buttons[current_tab]
	var target_pos := Vector2(button.global_position.x - tab_container.global_position.x, tab_indicator.position.y)
	var target_width := button.size.x

	if animate:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(tab_indicator, "position:x", target_pos.x, TAB_INDICATOR_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(tab_indicator, "custom_minimum_size:x", target_width, TAB_INDICATOR_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tab_indicator.position.x = target_pos.x
		tab_indicator.custom_minimum_size.x = target_width


func _animate_panel_transition(old_panel: Control, new_panel: Control) -> void:
	if not old_panel or not new_panel:
		return

	var direction := 1.0 if new_panel.get_index() > old_panel.get_index() else -1.0
	var offset := 100.0 * direction

	# Setup new panel.
	new_panel.visible = true
	new_panel.modulate.a = 0.0
	new_panel.position.x = offset

	# Animate old panel out.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(old_panel, "modulate:a", 0.0, PANEL_FADE_DURATION)
	tween.tween_property(old_panel, "position:x", -offset, TAB_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Animate new panel in.
	tween.tween_property(new_panel, "modulate:a", 1.0, PANEL_FADE_DURATION).set_delay(0.1)
	tween.tween_property(new_panel, "position:x", 0.0, TAB_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Hide old panel when done.
	tween.chain().tween_callback(func(): old_panel.visible = false; old_panel.position.x = 0.0)


func _play_success_animation() -> void:
	# Flash the apply button green.
	var original_modulate := apply_button.modulate
	var flash_color := Color(0.5, 1.0, 0.5, 1.0)

	var tween := create_tween()
	tween.tween_property(apply_button, "modulate", flash_color, 0.1)
	tween.tween_property(apply_button, "modulate", original_modulate, 0.3)

	# Scale pulse.
	tween.parallel().tween_property(apply_button, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(apply_button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

# ============================================================================ #
#                               HELPER METHODS                                  #
# ============================================================================ #

func _register_change(key: String, value: Variant) -> void:
	if not original_values.has(key):
		original_values[key] = _get_current_setting_value(key)
	pending_changes[key] = value
	_update_apply_button_state()


func _update_apply_button_state() -> void:
	var has_changes := not pending_changes.is_empty()
	apply_button.disabled = not has_changes
	apply_button.modulate.a = 1.0 if has_changes else 0.5


func _apply_pending_changes() -> void:
	for key: String in pending_changes:
		_apply_setting(key, pending_changes[key])

	pending_changes.clear()
	original_values.clear()
	_update_apply_button_state()

	# Save settings.
	_save_settings()


func _apply_setting(key: String, value: Variant) -> void:
	# Apply setting based on key.
	match key:
		"master_volume":
			if is_instance_valid(AudioManager):
				AudioManager.master_volume = value
		"music_volume":
			if is_instance_valid(AudioManager):
				AudioManager.music_volume = value
		"sfx_volume":
			if is_instance_valid(AudioManager):
				AudioManager.sfx_volume = value
		"ambient_volume":
			if is_instance_valid(AudioManager):
				AudioManager.ambient_volume = value
		"voice_volume":
			if is_instance_valid(AudioManager):
				AudioManager.voice_volume = value
		# Add more settings as needed.


func _apply_graphics_preset(preset_idx: int) -> void:
	# Apply preset values.
	var presets := {
		0: {"shadow_quality": 4, "texture_quality": 3, "anti_aliasing": 4, "bloom": false, "motion_blur": false, "ambient_occlusion": false},
		1: {"shadow_quality": 2, "texture_quality": 2, "anti_aliasing": 2, "bloom": true, "motion_blur": false, "ambient_occlusion": false},
		2: {"shadow_quality": 1, "texture_quality": 1, "anti_aliasing": 1, "bloom": true, "motion_blur": false, "ambient_occlusion": true},
		3: {"shadow_quality": 0, "texture_quality": 0, "anti_aliasing": 0, "bloom": true, "motion_blur": true, "ambient_occlusion": true},
	}

	if presets.has(preset_idx):
		for key: String in presets[preset_idx]:
			_register_change(key, presets[preset_idx][key])


func _reset_to_defaults() -> void:
	# Reset all settings to default values.
	pending_changes.clear()
	original_values.clear()
	_load_default_settings()
	_update_apply_button_state()
	settings_reset.emit()


func _close_menu() -> void:
	# Play exit animation.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(main_container, "scale", Vector2(0.95, 0.95), 0.2)
	tween.tween_callback(func(): queue_free()).set_delay(0.2)

	menu_closed.emit()


func _show_confirmation(message: String, on_confirm: Callable) -> void:
	# Create simple confirmation dialog.
	if confirmation_dialog:
		confirmation_dialog.queue_free()

	confirmation_dialog = _create_confirmation_dialog(message, on_confirm)
	add_child(confirmation_dialog)


func _create_confirmation_dialog(message: String, on_confirm: Callable) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 200)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.pivot_offset = panel.custom_minimum_size / 2
	overlay.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = COLORS["panel"]
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(label)

	var button_container := HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	vbox.add_child(button_container)

	var cancel_btn := _create_footer_button("CANCEL", COLORS["text_secondary"])
	cancel_btn.pressed.connect(func(): overlay.queue_free())
	button_container.add_child(cancel_btn)

	var confirm_btn := _create_footer_button("CONFIRM", COLORS["warning"])
	confirm_btn.pressed.connect(func(): overlay.queue_free(); on_confirm.call())
	button_container.add_child(confirm_btn)

	# Entrance animation.
	overlay.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)

	var tween := overlay.create_tween().set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	return overlay


func _show_tooltip(target: Control, text: String) -> void:
	tooltip_target = target
	tooltip_text = text
	tooltip_timer = 0.0


func _hide_tooltip() -> void:
	tooltip_target = null
	tooltip_timer = 0.0

	var tween := create_tween()
	tween.tween_property(tooltip_panel, "modulate:a", 0.0, TOOLTIP_FADE_DURATION)
	tween.tween_callback(func(): tooltip_panel.visible = false)


func _update_tooltip(delta: float) -> void:
	if tooltip_target:
		tooltip_timer += delta
		if tooltip_timer >= TOOLTIP_DELAY and not tooltip_panel.visible:
			_display_tooltip()


func _display_tooltip() -> void:
	tooltip_label.text = tooltip_text
	tooltip_panel.visible = true
	tooltip_panel.modulate.a = 0.0

	# Position tooltip above target.
	var target_rect := tooltip_target.get_global_rect()
	tooltip_panel.global_position = Vector2(
		target_rect.position.x + target_rect.size.x / 2 - tooltip_panel.size.x / 2,
		target_rect.position.y - tooltip_panel.size.y - 10
	)

	# Animate in.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(tooltip_panel, "modulate:a", 1.0, TOOLTIP_FADE_DURATION)
	tween.tween_property(tooltip_panel, "position:y", tooltip_panel.position.y - 5, TOOLTIP_FADE_DURATION)


func _update_scroll_momentum(delta: float) -> void:
	if abs(scroll_velocity) > 0.1:
		scroll_container.scroll_vertical += int(scroll_velocity * delta * 60)
		scroll_velocity *= SCROLL_MOMENTUM_FRICTION
	else:
		scroll_velocity = 0.0


func _update_fps_counter(delta: float) -> void:
	if not show_fps_counter:
		return

	var fps_label := content_panels.get(SettingsTab.GRAPHICS)
	if fps_label:
		var label := fps_label.find_child("FPSLabel", true, false) as Label
		if label:
			label.text = "FPS: %d" % Engine.get_frames_per_second()


func _play_ui_sound(sound_name: String) -> void:
	if not enable_sounds:
		return

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("ui_%s" % sound_name)


func _get_current_setting_value(key: String) -> Variant:
	# Get current value from appropriate manager.
	match key:
		"master_volume":
			return AudioManager.master_volume if is_instance_valid(AudioManager) else 1.0
		"music_volume":
			return AudioManager.music_volume if is_instance_valid(AudioManager) else 0.8
		"sfx_volume":
			return AudioManager.sfx_volume if is_instance_valid(AudioManager) else 1.0
		"ambient_volume":
			return AudioManager.ambient_volume if is_instance_valid(AudioManager) else 0.7
		"voice_volume":
			return AudioManager.voice_volume if is_instance_valid(AudioManager) else 1.0
	return null


func _load_current_settings() -> void:
	# Load current settings from managers.
	if is_instance_valid(AudioManager):
		# Update audio sliders with current values.
		pass


func _load_default_settings() -> void:
	# Load default settings.
	pass


func _save_settings() -> void:
	# Save settings to disk.
	if is_instance_valid(AudioManager):
		AudioManager.save_settings()
