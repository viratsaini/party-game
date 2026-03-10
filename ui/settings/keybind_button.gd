## KeybindButton - Premium keybind rebinding UI with animations and conflict handling.
##
## Features:
## - Click to rebind animation
## - Pulsing waiting state
## - Conflict warning with shake
## - Success animation with particle burst
## - Visual feedback for all keys
## - Gamepad support
class_name KeybindButton
extends Control

# ============================================================================ #
#                                   SIGNALS                                     #
# ============================================================================ #

## Emitted when rebind mode is started.
signal rebind_started

## Emitted when rebind is completed.
signal rebind_completed(binding: String)

## Emitted when rebind is cancelled.
signal rebind_cancelled

## Emitted when a conflict is detected.
signal conflict_detected(conflicting_action: String)

# ============================================================================ #
#                                  CONSTANTS                                    #
# ============================================================================ #

const BUTTON_HEIGHT: float = 36.0
const BUTTON_MIN_WIDTH: float = 140.0
const PULSE_SPEED: float = 3.0
const SHAKE_DURATION: float = 0.4
const SHAKE_INTENSITY: float = 8.0
const PARTICLE_COUNT: int = 12
const PARTICLE_LIFETIME: float = 0.6

const COLORS := {
	"bg_normal": Color(0.15, 0.15, 0.18, 1.0),
	"bg_hover": Color(0.18, 0.18, 0.22, 1.0),
	"bg_waiting": Color(0.2, 0.4, 0.6, 1.0),
	"bg_conflict": Color(0.6, 0.2, 0.2, 1.0),
	"bg_success": Color(0.2, 0.6, 0.3, 1.0),

	"border_normal": Color(0.3, 0.3, 0.35, 1.0),
	"border_hover": Color(0.4, 0.6, 0.9, 1.0),
	"border_waiting": Color(0.3, 0.7, 1.0, 1.0),
	"border_conflict": Color(1.0, 0.4, 0.4, 1.0),
	"border_success": Color(0.4, 1.0, 0.6, 1.0),

	"text_normal": Color(1.0, 1.0, 1.0, 1.0),
	"text_secondary": Color(0.7, 0.7, 0.75, 1.0),
	"text_waiting": Color(0.8, 0.9, 1.0, 1.0),

	"glow_waiting": Color(0.3, 0.7, 1.0, 0.4),
	"glow_success": Color(0.3, 1.0, 0.5, 0.6),

	"particle": Color(0.4, 0.8, 1.0, 1.0),
}

# Key name display mapping.
const KEY_DISPLAY_NAMES := {
	KEY_SPACE: "Space",
	KEY_ENTER: "Enter",
	KEY_ESCAPE: "Esc",
	KEY_TAB: "Tab",
	KEY_BACKSPACE: "Backspace",
	KEY_SHIFT: "Shift",
	KEY_CTRL: "Ctrl",
	KEY_ALT: "Alt",
	KEY_CAPSLOCK: "Caps",
	KEY_UP: "Up",
	KEY_DOWN: "Down",
	KEY_LEFT: "Left",
	KEY_RIGHT: "Right",
}

# ============================================================================ #
#                                  EXPORTS                                      #
# ============================================================================ #

## Action name in InputMap.
@export var action_name: String = ""

## Current binding display text.
@export var current_binding: String = "":
	set(v):
		current_binding = v
		_update_display()

## Whether to allow mouse buttons.
@export var allow_mouse: bool = true

## Whether to allow gamepad buttons.
@export var allow_gamepad: bool = true

## Known actions for conflict detection.
@export var known_actions: Array[String] = []

## Enable sound effects.
@export var enable_sounds: bool = true

## Disabled state.
@export var disabled: bool = false

# ============================================================================ #
#                                   STATE                                       #
# ============================================================================ #

## Current button state.
enum State { NORMAL, HOVER, WAITING, CONFLICT, SUCCESS }
var current_state: State = State.NORMAL

## Is waiting for key input.
var is_waiting: bool = false

## Pulse animation phase.
var pulse_phase: float = 0.0

## Shake animation progress (0-1).
var shake_progress: float = 0.0

## Success animation progress.
var success_progress: float = 0.0

## Particle data for success animation.
var particles: Array[Dictionary] = []

## Shake offset.
var shake_offset: Vector2 = Vector2.ZERO

## Conflict action name.
var conflict_action: String = ""

## Original binding before rebind attempt.
var original_binding: String = ""

## Glow intensity.
var glow_intensity: float = 0.0

# ============================================================================ #
#                                 LIFECYCLE                                     #
# ============================================================================ #

func _ready() -> void:
	custom_minimum_size = Vector2(BUTTON_MIN_WIDTH, BUTTON_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

	# Initialize binding from InputMap if action exists.
	if not action_name.is_empty() and InputMap.has_action(action_name):
		_load_binding_from_input_map()


func _process(delta: float) -> void:
	# Pulse animation for waiting state.
	if is_waiting:
		pulse_phase += delta * PULSE_SPEED
		if pulse_phase > TAU:
			pulse_phase -= TAU

	# Glow intensity.
	var target_glow := 1.0 if (is_waiting or current_state == State.SUCCESS) else 0.0
	glow_intensity = lerpf(glow_intensity, target_glow, 8.0 * delta)

	# Shake animation.
	if shake_progress > 0:
		shake_progress -= delta / SHAKE_DURATION
		if shake_progress <= 0:
			shake_progress = 0
			shake_offset = Vector2.ZERO
		else:
			var shake_amount := shake_progress * SHAKE_INTENSITY
			shake_offset = Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount * 0.3, shake_amount * 0.3)
			)

	# Success animation.
	if success_progress > 0:
		success_progress -= delta / 0.8
		if success_progress <= 0:
			success_progress = 0
			current_state = State.NORMAL
			particles.clear()

	# Update particles.
	_update_particles(delta)

	queue_redraw()


func _draw() -> void:
	var draw_pos := shake_offset
	_draw_button(draw_pos)
	_draw_particles()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return

	if is_waiting:
		_handle_rebind_input(event)
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_rebind()
			get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed:
		if has_focus():
			match event.keycode:
				KEY_SPACE, KEY_ENTER:
					_start_rebind()
					get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			if not is_waiting and current_state == State.NORMAL:
				current_state = State.HOVER
				_play_sound("hover")
		NOTIFICATION_MOUSE_EXIT:
			if current_state == State.HOVER:
				current_state = State.NORMAL
		NOTIFICATION_FOCUS_EXIT:
			if is_waiting:
				cancel_rebind()

# ============================================================================ #
#                                  DRAWING                                      #
# ============================================================================ #

func _draw_button(offset: Vector2) -> void:
	var button_rect := Rect2(offset, Vector2(size.x, BUTTON_HEIGHT))
	var corner_radius := 6.0

	# Get colors based on state.
	var bg_color: Color
	var border_color: Color
	var text_color: Color

	match current_state:
		State.NORMAL:
			bg_color = COLORS["bg_normal"]
			border_color = COLORS["border_normal"]
			text_color = COLORS["text_normal"]
		State.HOVER:
			bg_color = COLORS["bg_hover"]
			border_color = COLORS["border_hover"]
			text_color = COLORS["text_normal"]
		State.WAITING:
			var pulse := (sin(pulse_phase) + 1.0) * 0.5
			bg_color = COLORS["bg_waiting"].lerp(COLORS["bg_waiting"].lightened(0.1), pulse)
			border_color = COLORS["border_waiting"]
			text_color = COLORS["text_waiting"]
		State.CONFLICT:
			bg_color = COLORS["bg_conflict"]
			border_color = COLORS["border_conflict"]
			text_color = COLORS["text_normal"]
		State.SUCCESS:
			bg_color = COLORS["bg_success"].lerp(COLORS["bg_normal"], 1.0 - success_progress)
			border_color = COLORS["border_success"].lerp(COLORS["border_normal"], 1.0 - success_progress)
			text_color = COLORS["text_normal"]

	if disabled:
		bg_color = bg_color.darkened(0.4)
		border_color = border_color.darkened(0.4)
		text_color = text_color.darkened(0.4)

	# Draw glow.
	if glow_intensity > 0.01:
		var glow_color := COLORS["glow_success"] if current_state == State.SUCCESS else COLORS["glow_waiting"]
		glow_color.a *= glow_intensity

		for i: int in range(4, 0, -1):
			var glow_rect := button_rect.grow(float(i) * 3 * glow_intensity)
			_draw_rounded_rect(glow_rect, corner_radius + float(i) * 2, Color(glow_color, glow_color.a * (1.0 - float(i) / 5.0)))

	# Draw background.
	_draw_rounded_rect(button_rect, corner_radius, bg_color)

	# Draw border.
	var border_width := 2.0 if is_waiting else 1.5
	_draw_rounded_rect_outline(button_rect, corner_radius, border_color, border_width)

	# Draw text.
	var font := ThemeDB.fallback_font
	var font_size := 13
	var text: String

	if is_waiting:
		text = "Press a key..."
	elif current_state == State.CONFLICT:
		text = "Conflict!"
	else:
		text = "[%s]" % current_binding if not current_binding.is_empty() else "[None]"

	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := offset + Vector2(
		(size.x - text_size.x) / 2,
		BUTTON_HEIGHT / 2 + font_size * 0.35
	)

	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)

	# Draw key icon hint for waiting state.
	if is_waiting:
		_draw_waiting_indicator(button_rect)


func _draw_waiting_indicator(rect: Rect2) -> void:
	# Draw pulsing dots.
	var center := rect.get_center()
	var dot_spacing := 8.0
	var dot_radius := 3.0

	for i: int in 3:
		var dot_phase := pulse_phase + float(i) * 0.5
		var dot_alpha := (sin(dot_phase) + 1.0) * 0.5 * 0.7 + 0.3
		var dot_x := rect.end.x - 20 - float(2 - i) * dot_spacing

		draw_circle(
			Vector2(dot_x, center.y),
			dot_radius,
			Color(COLORS["text_waiting"], dot_alpha)
		)


func _draw_particles() -> void:
	for particle: Dictionary in particles:
		var pos: Vector2 = particle["position"]
		var life: float = particle["life"]
		var color: Color = particle["color"]
		var particle_size: float = particle["size"] * life

		color.a *= life
		draw_circle(pos, particle_size, color)


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
#                                  REBINDING                                    #
# ============================================================================ #

func _start_rebind() -> void:
	if disabled or is_waiting:
		return

	is_waiting = true
	current_state = State.WAITING
	original_binding = current_binding
	pulse_phase = 0.0

	grab_focus()
	_play_sound("keybind_start")
	rebind_started.emit()


func _handle_rebind_input(event: InputEvent) -> void:
	var new_binding := ""

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			cancel_rebind()
			return

		new_binding = _get_key_display_name(event)

	elif event is InputEventMouseButton and event.pressed and allow_mouse:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Ignore left click during rebind (it's used to start rebind).
			return
		new_binding = _get_mouse_button_name(event.button_index)

	elif event is InputEventJoypadButton and event.pressed and allow_gamepad:
		new_binding = _get_gamepad_button_name(event.button_index)

	if not new_binding.is_empty():
		_check_and_apply_binding(new_binding, event)
		get_viewport().set_input_as_handled()


func _check_and_apply_binding(new_binding: String, event: InputEvent) -> void:
	# Check for conflicts.
	var conflicting := _check_conflict(event)

	if not conflicting.is_empty():
		conflict_action = conflicting
		_show_conflict()
		conflict_detected.emit(conflicting)
		return

	# Apply the new binding.
	complete_rebind(new_binding)


func _check_conflict(event: InputEvent) -> String:
	# Check if this input is already bound to another action.
	for known_action: String in known_actions:
		if known_action == action_name:
			continue

		if InputMap.has_action(known_action):
			for existing_event: InputEvent in InputMap.action_get_events(known_action):
				if existing_event.is_match(event, true):
					return known_action

	return ""


func _show_conflict() -> void:
	current_state = State.CONFLICT
	shake_progress = 1.0
	_play_sound("keybind_conflict")

	# Return to waiting after shake.
	await get_tree().create_timer(SHAKE_DURATION + 0.2).timeout
	if is_waiting:
		current_state = State.WAITING


func complete_rebind(new_binding: String) -> void:
	is_waiting = false
	current_state = State.SUCCESS
	success_progress = 1.0
	current_binding = new_binding

	# Spawn particles.
	_spawn_success_particles()

	# Update InputMap if action exists.
	if not action_name.is_empty() and InputMap.has_action(action_name):
		_save_binding_to_input_map()

	_play_sound("keybind_success")
	rebind_completed.emit(new_binding)


func cancel_rebind() -> void:
	is_waiting = false
	current_state = State.NORMAL
	current_binding = original_binding

	_play_sound("keybind_cancel")
	rebind_cancelled.emit()

# ============================================================================ #
#                                  PARTICLES                                    #
# ============================================================================ #

func _spawn_success_particles() -> void:
	particles.clear()

	var center := Vector2(size.x / 2, BUTTON_HEIGHT / 2)

	for i: int in PARTICLE_COUNT:
		var angle := float(i) / float(PARTICLE_COUNT) * TAU + randf_range(-0.2, 0.2)
		var speed := randf_range(80.0, 150.0)
		var particle_size := randf_range(3.0, 6.0)

		particles.append({
			"position": center,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": 1.0,
			"color": COLORS["particle"].lerp(COLORS["glow_success"], randf()),
			"size": particle_size,
		})


func _update_particles(delta: float) -> void:
	var to_remove: Array[int] = []

	for i: int in particles.size():
		var particle: Dictionary = particles[i]
		particle["life"] -= delta / PARTICLE_LIFETIME
		particle["position"] += particle["velocity"] * delta
		particle["velocity"] *= 0.95  # Drag.
		particle["velocity"].y += 100 * delta  # Gravity.

		if particle["life"] <= 0:
			to_remove.append(i)

	# Remove dead particles (in reverse order).
	to_remove.reverse()
	for idx: int in to_remove:
		particles.remove_at(idx)

# ============================================================================ #
#                                  HELPERS                                      #
# ============================================================================ #

func _get_key_display_name(event: InputEventKey) -> String:
	var keycode := event.keycode

	if KEY_DISPLAY_NAMES.has(keycode):
		return KEY_DISPLAY_NAMES[keycode]

	return OS.get_keycode_string(keycode)


func _get_mouse_button_name(button_index: int) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT: return "Mouse 1"
		MOUSE_BUTTON_RIGHT: return "Mouse 2"
		MOUSE_BUTTON_MIDDLE: return "Mouse 3"
		MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
		MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
		MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
		_: return "Mouse %d" % button_index


func _get_gamepad_button_name(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A: return "A / X"
		JOY_BUTTON_B: return "B / Circle"
		JOY_BUTTON_X: return "X / Square"
		JOY_BUTTON_Y: return "Y / Triangle"
		JOY_BUTTON_LEFT_SHOULDER: return "LB / L1"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB / R1"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_BACK: return "Back"
		JOY_BUTTON_DPAD_UP: return "D-Pad Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Pad Down"
		JOY_BUTTON_DPAD_LEFT: return "D-Pad Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Pad Right"
		_: return "Button %d" % button_index


func _load_binding_from_input_map() -> void:
	if not InputMap.has_action(action_name):
		return

	var events := InputMap.action_get_events(action_name)
	if events.size() > 0:
		var event := events[0]
		if event is InputEventKey:
			current_binding = _get_key_display_name(event)
		elif event is InputEventMouseButton:
			current_binding = _get_mouse_button_name(event.button_index)
		elif event is InputEventJoypadButton:
			current_binding = _get_gamepad_button_name(event.button_index)


func _save_binding_to_input_map() -> void:
	# This would save the new binding to InputMap.
	# Implementation depends on how bindings are stored.
	pass


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

## Set binding without triggering rebind flow.
func set_binding(binding: String) -> void:
	current_binding = binding


## Get current binding.
func get_binding() -> String:
	return current_binding


## Set disabled state.
func set_disabled(is_disabled: bool) -> void:
	disabled = is_disabled
	if disabled and is_waiting:
		cancel_rebind()
	queue_redraw()


## Check if currently waiting for input.
func is_rebinding() -> bool:
	return is_waiting
