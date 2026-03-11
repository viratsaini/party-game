## AudioFeedback - Automatic audio feedback attachment for UI Controls.
##
## This component can be attached to any Control node to provide automatic
## audio feedback for all standard UI interactions. It detects control types
## and applies appropriate sounds, supports animation-synchronized audio,
## and provides accessibility features like visual feedback captions.
class_name AudioFeedback
extends Node


# -- Signals --

## Emitted when audio feedback is triggered.
signal feedback_triggered(control: Control, feedback_type: String)

## Emitted when visual caption is displayed (for accessibility).
signal caption_displayed(caption_text: String, duration: float)


# -- Enums --

## Feedback behavior modes.
enum FeedbackMode {
	AUTOMATIC,      ## Detect control type and apply appropriate sounds
	MANUAL,         ## Only play sounds when explicitly called
	DISABLED,       ## No audio feedback
}

## Animation sync modes.
enum AnimationSyncMode {
	NONE,           ## Play sound immediately
	MATCH_DURATION, ## Stretch/compress sound to match animation
	TRIGGER_POINTS, ## Play at specific animation points
}


# -- Exports --

@export_group("Feedback Settings")

## How audio feedback is handled.
@export var feedback_mode: FeedbackMode = FeedbackMode.AUTOMATIC

## Volume offset for this control's sounds.
@export_range(-20.0, 10.0, 0.5) var volume_offset_db: float = 0.0

## Pitch multiplier for this control's sounds.
@export_range(0.5, 2.0, 0.05) var pitch_multiplier: float = 1.0

## Enable haptic feedback alongside audio.
@export var haptic_enabled: bool = true

@export_group("Animation Sync")

## How to synchronize audio with animations.
@export var animation_sync: AnimationSyncMode = AnimationSyncMode.NONE

## AnimationPlayer to sync with (auto-detected if not set).
@export var animation_player: AnimationPlayer = null

@export_group("Accessibility")

## Show visual captions for sounds.
@export var show_captions: bool = false

## Screen reader announcements for sounds.
@export var screen_reader_enabled: bool = false

## Custom caption text overrides.
@export var custom_captions: Dictionary = {}


# -- State --

## The parent control this feedback is attached to.
var _parent_control: Control = null

## Child controls being monitored.
var _monitored_children: Array[Control] = []

## Reference to UISoundManager singleton.
var _sound_manager: Node = null

## Reference to HapticController if available.
var _haptic_controller: Node = null

## Animation-to-sound mappings.
var _animation_sounds: Dictionary = {}

## Throttle tracking for rapid interactions.
var _last_feedback_times: Dictionary = {}
const MIN_FEEDBACK_INTERVAL: float = 0.05


# -- Lifecycle --

func _ready() -> void:
	# Find parent control
	_parent_control = get_parent() as Control
	if not _parent_control:
		push_warning("AudioFeedback: Must be child of a Control node")
		return

	# Get sound manager reference
	_sound_manager = get_node_or_null("/root/UISoundManager")

	# Get haptic controller reference
	_haptic_controller = get_node_or_null("/root/HapticController")

	# Find animation player if not set
	if not animation_player:
		animation_player = _find_animation_player(_parent_control)

	# Set up automatic feedback if enabled
	if feedback_mode == FeedbackMode.AUTOMATIC:
		_setup_automatic_feedback()

	# Monitor for new children
	_parent_control.child_entered_tree.connect(_on_child_added)


func _exit_tree() -> void:
	_disconnect_all_signals()


# -- Automatic Setup --

func _setup_automatic_feedback() -> void:
	# Connect signals on parent control
	_connect_control_signals(_parent_control)

	# Recursively connect to all existing children
	_monitor_children_recursive(_parent_control)


func _monitor_children_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			_connect_control_signals(child)
			_monitored_children.append(child)
		_monitor_children_recursive(child)


func _connect_control_signals(control: Control) -> void:
	# Common Control signals
	if not control.mouse_entered.is_connected(_on_control_mouse_entered):
		control.mouse_entered.connect(_on_control_mouse_entered.bind(control))
	if not control.mouse_exited.is_connected(_on_control_mouse_exited):
		control.mouse_exited.connect(_on_control_mouse_exited.bind(control))
	if not control.focus_entered.is_connected(_on_control_focus_entered):
		control.focus_entered.connect(_on_control_focus_entered.bind(control))
	if not control.focus_exited.is_connected(_on_control_focus_exited):
		control.focus_exited.connect(_on_control_focus_exited.bind(control))

	# Button-specific signals
	if control is BaseButton:
		var button := control as BaseButton
		if not button.pressed.is_connected(_on_button_pressed):
			button.pressed.connect(_on_button_pressed.bind(button))
		if not button.button_down.is_connected(_on_button_down):
			button.button_down.connect(_on_button_down.bind(button))
		if not button.button_up.is_connected(_on_button_up):
			button.button_up.connect(_on_button_up.bind(button))
		if button is CheckButton or button is CheckBox:
			if not button.toggled.is_connected(_on_toggle_changed):
				button.toggled.connect(_on_toggle_changed.bind(button))

	# Slider signals
	if control is Slider:
		var slider := control as Slider
		if not slider.value_changed.is_connected(_on_slider_changed):
			slider.value_changed.connect(_on_slider_changed.bind(slider))
		if not slider.drag_started.is_connected(_on_slider_drag_started):
			slider.drag_started.connect(_on_slider_drag_started.bind(slider))
		if not slider.drag_ended.is_connected(_on_slider_drag_ended):
			slider.drag_ended.connect(_on_slider_drag_ended.bind(slider))

	# LineEdit signals
	if control is LineEdit:
		var line_edit := control as LineEdit
		if not line_edit.text_changed.is_connected(_on_text_changed):
			line_edit.text_changed.connect(_on_text_changed.bind(line_edit))
		if not line_edit.text_submitted.is_connected(_on_text_submitted):
			line_edit.text_submitted.connect(_on_text_submitted.bind(line_edit))

	# TextEdit signals
	if control is TextEdit:
		var text_edit := control as TextEdit
		if not text_edit.text_changed.is_connected(_on_textedit_changed):
			text_edit.text_changed.connect(_on_textedit_changed.bind(text_edit))

	# ItemList signals
	if control is ItemList:
		var item_list := control as ItemList
		if not item_list.item_selected.is_connected(_on_item_selected):
			item_list.item_selected.connect(_on_item_selected.bind(item_list))
		if not item_list.item_activated.is_connected(_on_item_activated):
			item_list.item_activated.connect(_on_item_activated.bind(item_list))

	# OptionButton signals
	if control is OptionButton:
		var option := control as OptionButton
		if not option.item_selected.is_connected(_on_option_selected):
			option.item_selected.connect(_on_option_selected.bind(option))

	# TabContainer/TabBar signals
	if control is TabContainer:
		var tabs := control as TabContainer
		if not tabs.tab_changed.is_connected(_on_tab_changed):
			tabs.tab_changed.connect(_on_tab_changed.bind(tabs))

	if control is TabBar:
		var tab_bar := control as TabBar
		if not tab_bar.tab_changed.is_connected(_on_tab_changed):
			tab_bar.tab_changed.connect(_on_tab_changed.bind(tab_bar))

	# ScrollContainer signals
	if control is ScrollContainer:
		var scroll := control as ScrollContainer
		if not scroll.scroll_started.is_connected(_on_scroll_started):
			scroll.scroll_started.connect(_on_scroll_started.bind(scroll))
		if not scroll.scroll_ended.is_connected(_on_scroll_ended):
			scroll.scroll_ended.connect(_on_scroll_ended.bind(scroll))

	# SpinBox signals
	if control is SpinBox:
		var spin := control as SpinBox
		if not spin.value_changed.is_connected(_on_spinbox_changed):
			spin.value_changed.connect(_on_spinbox_changed.bind(spin))

	# Tree signals
	if control is Tree:
		var tree := control as Tree
		if not tree.item_selected.is_connected(_on_tree_item_selected):
			tree.item_selected.connect(_on_tree_item_selected.bind(tree))
		if not tree.item_activated.is_connected(_on_tree_item_activated):
			tree.item_activated.connect(_on_tree_item_activated.bind(tree))


func _disconnect_all_signals() -> void:
	# Disconnect all signals from monitored controls
	for control: Control in _monitored_children:
		if is_instance_valid(control):
			_disconnect_control_signals(control)


func _disconnect_control_signals(control: Control) -> void:
	# Safely disconnect signals
	if control.mouse_entered.is_connected(_on_control_mouse_entered):
		control.mouse_entered.disconnect(_on_control_mouse_entered)
	if control.mouse_exited.is_connected(_on_control_mouse_exited):
		control.mouse_exited.disconnect(_on_control_mouse_exited)
	# ... (similar for other signals)


# -- Signal Handlers --

func _on_child_added(node: Node) -> void:
	if node is Control and feedback_mode == FeedbackMode.AUTOMATIC:
		var control := node as Control
		_connect_control_signals(control)
		_monitored_children.append(control)


func _on_control_mouse_entered(control: Control) -> void:
	if _can_play_feedback("hover"):
		_play_hover_sound(control)


func _on_control_mouse_exited(_control: Control) -> void:
	# Optional: play exit sound
	pass


func _on_control_focus_entered(control: Control) -> void:
	if _can_play_feedback("focus"):
		_play_sound(UISoundManager.UISoundType.MENU_NAVIGATE, control)
		_trigger_haptic("light")
		_show_caption("Focused", 0.5)


func _on_control_focus_exited(_control: Control) -> void:
	pass


func _on_button_pressed(button: BaseButton) -> void:
	if _can_play_feedback("press"):
		if button.disabled:
			_play_sound(UISoundManager.UISoundType.BUTTON_DISABLED, button)
			_trigger_haptic("error")
			_show_caption("Button disabled", 0.5)
		else:
			_play_sound(UISoundManager.UISoundType.BUTTON_PRESS, button)
			_trigger_haptic("medium")
			_show_caption("Button pressed", 0.3)


func _on_button_down(button: BaseButton) -> void:
	if not button.disabled and _can_play_feedback("down"):
		# Slight pitch down on press
		_play_sound_options(UISoundManager.UISoundType.BUTTON_PRESS, button, {
			"pitch_multiplier": 0.95
		})


func _on_button_up(button: BaseButton) -> void:
	if not button.disabled and _can_play_feedback("up"):
		_play_sound(UISoundManager.UISoundType.BUTTON_RELEASE, button)


func _on_toggle_changed(toggled_on: bool, button: BaseButton) -> void:
	if _can_play_feedback("toggle"):
		if toggled_on:
			_play_sound(UISoundManager.UISoundType.TOGGLE_ON, button)
			_trigger_haptic("success")
			_show_caption("Enabled", 0.5)
		else:
			_play_sound(UISoundManager.UISoundType.TOGGLE_OFF, button)
			_trigger_haptic("light")
			_show_caption("Disabled", 0.5)


func _on_slider_changed(_value: float, slider: Slider) -> void:
	if _can_play_feedback("slider"):
		# Check if at min/max for snap sound
		if slider.value == slider.min_value or slider.value == slider.max_value:
			_play_sound(UISoundManager.UISoundType.SLIDER_SNAP, slider)
			_trigger_haptic("medium")
		else:
			_play_sound(UISoundManager.UISoundType.SLIDER_MOVE, slider)
			_trigger_haptic("tick")


func _on_slider_drag_started(slider: Slider) -> void:
	if _can_play_feedback("slider_start"):
		_play_sound(UISoundManager.UISoundType.ITEM_SELECT, slider)


func _on_slider_drag_ended(_value_changed: bool, slider: Slider) -> void:
	if _can_play_feedback("slider_end"):
		_play_sound(UISoundManager.UISoundType.SLIDER_SNAP, slider)
		_trigger_haptic("medium")


func _on_text_changed(_new_text: String, line_edit: LineEdit) -> void:
	if _can_play_feedback("type"):
		_play_sound(UISoundManager.UISoundType.TEXT_TYPE, line_edit)
		_trigger_haptic("tick")


func _on_text_submitted(_text: String, line_edit: LineEdit) -> void:
	if _can_play_feedback("submit"):
		_play_sound(UISoundManager.UISoundType.TEXT_SUBMIT, line_edit)
		_trigger_haptic("success")
		_show_caption("Submitted", 0.5)


func _on_textedit_changed(text_edit: TextEdit) -> void:
	if _can_play_feedback("type"):
		_play_sound(UISoundManager.UISoundType.TEXT_TYPE, text_edit)


func _on_item_selected(_index: int, item_list: ItemList) -> void:
	if _can_play_feedback("select"):
		_play_sound(UISoundManager.UISoundType.ITEM_SELECT, item_list)
		_trigger_haptic("light")


func _on_item_activated(_index: int, item_list: ItemList) -> void:
	if _can_play_feedback("activate"):
		_play_sound(UISoundManager.UISoundType.MENU_SELECT, item_list)
		_trigger_haptic("medium")


func _on_option_selected(_index: int, option: OptionButton) -> void:
	if _can_play_feedback("option"):
		_play_sound(UISoundManager.UISoundType.MENU_SELECT, option)
		_trigger_haptic("light")


func _on_tab_changed(_tab: int, tabs: Control) -> void:
	if _can_play_feedback("tab"):
		_play_sound(UISoundManager.UISoundType.TAB_SWITCH, tabs)
		_trigger_haptic("light")
		_show_caption("Tab changed", 0.3)


func _on_scroll_started(scroll: ScrollContainer) -> void:
	if _can_play_feedback("scroll"):
		_play_sound(UISoundManager.UISoundType.LIST_SCROLL, scroll)


func _on_scroll_ended(scroll: ScrollContainer) -> void:
	if _can_play_feedback("scroll_end"):
		_play_sound(UISoundManager.UISoundType.LIST_SCROLL_END, scroll)


func _on_spinbox_changed(_value: float, spin: SpinBox) -> void:
	if _can_play_feedback("spin"):
		_play_sound(UISoundManager.UISoundType.SLIDER_SNAP, spin)
		_trigger_haptic("tick")


func _on_tree_item_selected(tree: Tree) -> void:
	if _can_play_feedback("tree_select"):
		_play_sound(UISoundManager.UISoundType.ITEM_SELECT, tree)
		_trigger_haptic("light")


func _on_tree_item_activated(tree: Tree) -> void:
	if _can_play_feedback("tree_activate"):
		_play_sound(UISoundManager.UISoundType.MENU_SELECT, tree)
		_trigger_haptic("medium")


# -- Sound Playback --

func _play_hover_sound(control: Control) -> void:
	# Different hover sounds for different control types
	var sound_type: int = UISoundManager.UISoundType.BUTTON_HOVER

	if control is BaseButton:
		sound_type = UISoundManager.UISoundType.BUTTON_HOVER
	elif control is ItemList or control is Tree:
		sound_type = UISoundManager.UISoundType.ITEM_HOVER
	else:
		sound_type = UISoundManager.UISoundType.MENU_NAVIGATE

	_play_sound(sound_type, control)
	_trigger_haptic("tick")


func _play_sound(sound_type: int, control: Control) -> void:
	_play_sound_options(sound_type, control, {})


func _play_sound_options(sound_type: int, control: Control, options: Dictionary) -> void:
	if feedback_mode == FeedbackMode.DISABLED:
		return

	if not _sound_manager:
		# Fallback to AudioManager
		_play_via_audio_manager(sound_type, options)
		feedback_triggered.emit(control, _get_sound_type_name(sound_type))
		return

	# Apply control's position for spatial audio
	var screen_pos := control.get_global_rect().get_center()

	# Merge options with instance settings
	var final_options := options.duplicate()
	final_options["volume_offset_db"] = volume_offset_db + options.get("volume_offset_db", 0.0)
	final_options["pitch_multiplier"] = pitch_multiplier * options.get("pitch_multiplier", 1.0)

	# Handle animation sync
	if animation_sync != AnimationSyncMode.NONE and animation_player:
		final_options["animation_speed"] = _get_animation_speed()

	_sound_manager.play_at_position(sound_type, screen_pos, final_options)
	feedback_triggered.emit(control, _get_sound_type_name(sound_type))


func _play_via_audio_manager(sound_type: int, options: Dictionary) -> void:
	# Fallback when UISoundManager is not available
	var sfx_key := "ui_%s" % _get_sound_type_name(sound_type)
	var volume := options.get("volume_offset_db", 0.0) + volume_offset_db

	if AudioManager._sfx_registry.has(sfx_key):
		var player := AudioManager.play_sfx(sfx_key, volume)
		if player:
			player.pitch_scale = pitch_multiplier * options.get("pitch_multiplier", 1.0)


func _get_sound_type_name(sound_type: int) -> String:
	# Map integer to UISoundManager enum name
	match sound_type:
		UISoundManager.UISoundType.BUTTON_HOVER: return "button_hover"
		UISoundManager.UISoundType.BUTTON_PRESS: return "button_press"
		UISoundManager.UISoundType.BUTTON_RELEASE: return "button_release"
		UISoundManager.UISoundType.BUTTON_DISABLED: return "button_disabled"
		UISoundManager.UISoundType.MENU_NAVIGATE: return "menu_navigate"
		UISoundManager.UISoundType.MENU_SELECT: return "menu_select"
		UISoundManager.UISoundType.ITEM_SELECT: return "item_select"
		UISoundManager.UISoundType.ITEM_HOVER: return "item_hover"
		UISoundManager.UISoundType.TOGGLE_ON: return "toggle_on"
		UISoundManager.UISoundType.TOGGLE_OFF: return "toggle_off"
		UISoundManager.UISoundType.SLIDER_MOVE: return "slider_move"
		UISoundManager.UISoundType.SLIDER_SNAP: return "slider_snap"
		UISoundManager.UISoundType.TEXT_TYPE: return "text_type"
		UISoundManager.UISoundType.TEXT_SUBMIT: return "text_submit"
		UISoundManager.UISoundType.TAB_SWITCH: return "tab_switch"
		UISoundManager.UISoundType.LIST_SCROLL: return "list_scroll"
		UISoundManager.UISoundType.LIST_SCROLL_END: return "list_scroll_end"
		_: return "unknown"


# -- Animation Sync --

func _find_animation_player(node: Node) -> AnimationPlayer:
	# Search for AnimationPlayer in parent hierarchy
	var current := node
	while current:
		for child in current.get_children():
			if child is AnimationPlayer:
				return child
		current = current.get_parent()
	return null


func _get_animation_speed() -> float:
	if animation_player and animation_player.is_playing():
		return animation_player.speed_scale
	return 1.0


## Set up sound triggers for specific animation names.
func setup_animation_sounds(mappings: Dictionary) -> void:
	_animation_sounds = mappings

	if animation_player:
		if not animation_player.animation_started.is_connected(_on_animation_started):
			animation_player.animation_started.connect(_on_animation_started)
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)


func _on_animation_started(anim_name: StringName) -> void:
	if _animation_sounds.has(anim_name):
		var sound_data: Dictionary = _animation_sounds[anim_name]
		var start_sound: int = sound_data.get("start", -1)
		if start_sound >= 0:
			_play_sound(start_sound, _parent_control)


func _on_animation_finished(anim_name: StringName) -> void:
	if _animation_sounds.has(anim_name):
		var sound_data: Dictionary = _animation_sounds[anim_name]
		var end_sound: int = sound_data.get("end", -1)
		if end_sound >= 0:
			_play_sound(end_sound, _parent_control)


# -- Haptic Feedback --

func _trigger_haptic(pattern: String) -> void:
	if not haptic_enabled:
		return

	if _haptic_controller and _haptic_controller.has_method("vibrate"):
		_haptic_controller.call("vibrate", pattern)


# -- Accessibility --

func _show_caption(text: String, duration: float) -> void:
	if not show_captions:
		return

	# Check for custom caption override
	var caption_text := custom_captions.get(text, text) as String

	caption_displayed.emit(caption_text, duration)

	# Integrate with accessibility system if available
	if screen_reader_enabled:
		_announce_to_screen_reader(caption_text)


func _announce_to_screen_reader(text: String) -> void:
	# Platform-specific screen reader integration
	# On mobile: Use TTS
	# On desktop: Use accessibility API
	if OS.has_feature("mobile"):
		# Mobile TTS would go here
		pass
	else:
		# Desktop accessibility API
		DisplayServer.tts_speak(text, DisplayServer.TTS_UTTERANCE_RATE_NORMAL)


# -- Throttling --

func _can_play_feedback(feedback_type: String) -> bool:
	if feedback_mode == FeedbackMode.DISABLED:
		return false

	var current_time := Time.get_ticks_msec() / 1000.0
	var last_time: float = _last_feedback_times.get(feedback_type, 0.0)

	if current_time - last_time < MIN_FEEDBACK_INTERVAL:
		return false

	_last_feedback_times[feedback_type] = current_time
	return true


# -- Public API --

## Manually trigger a specific sound for this control.
func play_feedback(sound_type: int, options: Dictionary = {}) -> void:
	if _parent_control:
		_play_sound_options(sound_type, _parent_control, options)


## Play a success feedback.
func play_success() -> void:
	play_feedback(UISoundManager.UISoundType.SUCCESS)
	_trigger_haptic("success")
	_show_caption("Success", 1.0)


## Play an error feedback.
func play_error() -> void:
	play_feedback(UISoundManager.UISoundType.ERROR)
	_trigger_haptic("error")
	_show_caption("Error", 1.0)


## Play a warning feedback.
func play_warning() -> void:
	play_feedback(UISoundManager.UISoundType.WARNING)
	_trigger_haptic("warning")
	_show_caption("Warning", 1.0)


## Play a confirmation feedback.
func play_confirm() -> void:
	play_feedback(UISoundManager.UISoundType.CONFIRM)
	_trigger_haptic("medium")
	_show_caption("Confirmed", 0.5)


## Play a cancel feedback.
func play_cancel() -> void:
	play_feedback(UISoundManager.UISoundType.CANCEL)
	_trigger_haptic("light")
	_show_caption("Cancelled", 0.5)


## Enable or disable all feedback.
func set_feedback_enabled(enabled: bool) -> void:
	feedback_mode = FeedbackMode.AUTOMATIC if enabled else FeedbackMode.DISABLED


## Get current feedback state.
func is_feedback_enabled() -> bool:
	return feedback_mode != FeedbackMode.DISABLED
