## AnimationStateMachine - Visual state graph animation system.
##
## Features:
## - State graph with visual representation
## - State transitions with blending
## - Entry/exit animations per state
## - Transition conditions (predicates)
## - State layers with override system
## - Debug visualization for state flow
## - Parameter-driven transitions
## - Sub-state machines
##
## Usage:
##   var sm := AnimationStateMachine.new()
##   sm.add_state("idle", idle_sequence)
##   sm.add_state("hover", hover_sequence)
##   sm.add_transition("idle", "hover", "is_hovered")
##   sm.set_initial_state("idle")
##   sm.start(my_node)
class_name AnimationStateMachine
extends RefCounted


# region - Signals

## Emitted when entering a state
signal state_entered(state_name: String)

## Emitted when exiting a state
signal state_exited(state_name: String)

## Emitted when a transition starts
signal transition_started(from_state: String, to_state: String)

## Emitted when a transition completes
signal transition_completed(from_state: String, to_state: String)

## Emitted when a parameter changes
signal parameter_changed(param_name: String, old_value: Variant, new_value: Variant)

## Emitted when the state machine starts
signal started

## Emitted when the state machine stops
signal stopped

## Emitted each update with current state
signal updated(current_state: String, delta: float)

# endregion


# region - Enums

## State machine modes
enum Mode {
	SINGLE,        ## Single active state
	LAYERED,       ## Multiple layers with override
	BLEND_TREE,    ## Blend between states based on weights
}

## Transition types
enum TransitionType {
	IMMEDIATE,     ## Instant transition
	CROSSFADE,     ## Blend between states
	FADE_OUT_IN,   ## Fade out current, fade in next
	CUSTOM,        ## Custom transition animation
}

## Condition types
enum ConditionType {
	EQUALS,        ## Parameter equals value
	NOT_EQUALS,    ## Parameter not equals value
	GREATER,       ## Parameter greater than value
	LESS,          ## Parameter less than value
	GREATER_EQUAL, ## Parameter greater or equal
	LESS_EQUAL,    ## Parameter less or equal
	TRIGGER,       ## One-shot trigger (auto-resets)
	CUSTOM,        ## Custom predicate function
}

## State update modes
enum UpdateMode {
	PROCESS,       ## Update in _process
	PHYSICS,       ## Update in _physics_process
	MANUAL,        ## Manual update calls
}

# endregion


# region - Inner Classes

## Represents a single state
class State extends RefCounted:
	## State name
	var name: String = ""

	## Animation sequence for this state
	var animation: AnimationSequence

	## Entry animation (played once when entering)
	var entry_animation: AnimationSequence

	## Exit animation (played once when exiting)
	var exit_animation: AnimationSequence

	## Whether this state loops
	var loops: bool = true

	## Speed multiplier
	var speed: float = 1.0

	## State tags for grouping
	var tags: Array[String] = []

	## Callbacks
	var on_enter: Callable
	var on_exit: Callable
	var on_update: Callable

	## State machine reference (for sub-states)
	var sub_state_machine: AnimationStateMachine

	## Custom data
	var metadata: Dictionary = {}

	## Position for visual editor
	var editor_position: Vector2 = Vector2.ZERO


	func _init(p_name: String = "", p_animation: AnimationSequence = null) -> void:
		name = p_name
		animation = p_animation


	func duplicate() -> State:
		var s := State.new(name)
		if animation:
			s.animation = animation.duplicate()
		if entry_animation:
			s.entry_animation = entry_animation.duplicate()
		if exit_animation:
			s.exit_animation = exit_animation.duplicate()
		s.loops = loops
		s.speed = speed
		s.tags = tags.duplicate()
		s.on_enter = on_enter
		s.on_exit = on_exit
		s.on_update = on_update
		s.metadata = metadata.duplicate()
		s.editor_position = editor_position
		return s


## Represents a transition condition
class Condition extends RefCounted:
	## Parameter name
	var parameter: String = ""

	## Condition type
	var type: ConditionType = ConditionType.EQUALS

	## Value to compare against
	var value: Variant = null

	## Custom predicate function
	var predicate: Callable

	## Inverse the result
	var inverted: bool = false


	func _init(
		p_parameter: String = "",
		p_type: ConditionType = ConditionType.EQUALS,
		p_value: Variant = null
	) -> void:
		parameter = p_parameter
		type = p_type
		value = p_value


	func evaluate(params: Dictionary) -> bool:
		var result: bool = false

		if type == ConditionType.TRIGGER:
			result = params.get(parameter, false) == true
		elif type == ConditionType.CUSTOM:
			if predicate.is_valid():
				result = predicate.call()
		else:
			var param_value: Variant = params.get(parameter)
			if param_value == null:
				result = false
			else:
				match type:
					ConditionType.EQUALS:
						result = param_value == value
					ConditionType.NOT_EQUALS:
						result = param_value != value
					ConditionType.GREATER:
						result = param_value > value
					ConditionType.LESS:
						result = param_value < value
					ConditionType.GREATER_EQUAL:
						result = param_value >= value
					ConditionType.LESS_EQUAL:
						result = param_value <= value

		return not result if inverted else result


## Represents a transition between states
class Transition extends RefCounted:
	## Source state name
	var from_state: String = ""

	## Target state name
	var to_state: String = ""

	## Transition type
	var type: TransitionType = TransitionType.CROSSFADE

	## Transition duration
	var duration: float = 0.2

	## All conditions that must be true
	var conditions: Array[Condition] = []

	## Priority (higher = checked first)
	var priority: int = 0

	## Whether transition can interrupt current state
	var can_interrupt: bool = true

	## Exit time (0-1, when in animation to allow transition)
	var exit_time: float = 0.0

	## Has exit time requirement
	var has_exit_time: bool = false

	## Custom transition animation
	var custom_animation: Callable

	## Position for visual editor
	var editor_curve: Array[Vector2] = []


	func _init(p_from: String = "", p_to: String = "") -> void:
		from_state = p_from
		to_state = p_to


	func evaluate(params: Dictionary) -> bool:
		for condition in conditions:
			if not condition.evaluate(params):
				return false
		return true


	func add_condition(
		parameter: String,
		type_cond: ConditionType = ConditionType.EQUALS,
		value: Variant = true
	) -> Condition:
		var condition := Condition.new(parameter, type_cond, value)
		conditions.append(condition)
		return condition


## Represents a layer in layered mode
class Layer extends RefCounted:
	## Layer name
	var name: String = ""

	## Layer weight for blending
	var weight: float = 1.0

	## Whether this layer overrides lower layers
	var override_mode: bool = false

	## Mask of properties affected by this layer
	var property_mask: Array[String] = []

	## Current state in this layer
	var current_state: String = ""

	## Layer's own states (subset or separate)
	var states: Dictionary = {}  ## name -> State

	## Layer's own transitions
	var transitions: Array[Transition] = []

	## Active
	var enabled: bool = true


	func _init(p_name: String = "") -> void:
		name = p_name


## Debug visualization data
class DebugInfo extends RefCounted:
	## Current state name
	var current_state: String = ""

	## Previous state name
	var previous_state: String = ""

	## Active transitions
	var active_transitions: Array[String] = []

	## Parameter values
	var parameters: Dictionary = {}

	## State durations
	var state_times: Dictionary = {}  ## state_name -> time_in_state

	## Transition history
	var transition_history: Array[Dictionary] = []

	## Max history size
	var max_history: int = 20


	func add_transition(from_state: String, to_state: String) -> void:
		var entry := {
			"from": from_state,
			"to": to_state,
			"time": Time.get_ticks_msec() / 1000.0,
		}
		transition_history.push_front(entry)
		if transition_history.size() > max_history:
			transition_history.pop_back()

# endregion


# region - State

## State machine mode
var mode: Mode = Mode.SINGLE

## Update mode
var update_mode: UpdateMode = UpdateMode.PROCESS

## All states
var states: Dictionary = {}  ## name -> State

## All transitions
var transitions: Array[Transition] = []

## Global transitions (can trigger from any state)
var any_state_transitions: Array[Transition] = []

## Layers (for layered mode)
var layers: Array[Layer] = []

## Parameters for conditions
var parameters: Dictionary = {}

## Current state name
var current_state: String = ""

## Initial state name
var initial_state: String = ""

## Target node being animated
var target_node: Node

## Running state
var is_running: bool = false

## Time in current state
var state_time: float = 0.0

## Active transition
var _active_transition: Transition = null
var _transition_progress: float = 0.0

## Blend weights (for blend tree mode)
var _blend_weights: Dictionary = {}  ## state_name -> weight

## Debug info
var debug_info: DebugInfo = DebugInfo.new()
var debug_enabled: bool = false

## Tween for transitions
var _transition_tween: Tween

# endregion


# region - Initialization

func _init(p_mode: Mode = Mode.SINGLE) -> void:
	mode = p_mode


## Sets the target node
func set_target(node: Node) -> void:
	target_node = node


## Duplicates the state machine
func duplicate_sm() -> AnimationStateMachine:
	var sm := AnimationStateMachine.new(mode)
	sm.update_mode = update_mode

	for state_name: String in states:
		sm.states[state_name] = (states[state_name] as State).duplicate()

	for transition in transitions:
		var t := Transition.new(transition.from_state, transition.to_state)
		t.type = transition.type
		t.duration = transition.duration
		t.priority = transition.priority
		t.can_interrupt = transition.can_interrupt
		t.exit_time = transition.exit_time
		t.has_exit_time = transition.has_exit_time
		for condition in transition.conditions:
			t.conditions.append(Condition.new(condition.parameter, condition.type, condition.value))
		sm.transitions.append(t)

	sm.parameters = parameters.duplicate()
	sm.initial_state = initial_state

	return sm

# endregion


# region - State Management

## Adds a state
func add_state(
	name: String,
	animation: AnimationSequence = null,
	loops: bool = true
) -> State:
	var state := State.new(name, animation)
	state.loops = loops
	states[name] = state

	if initial_state.is_empty():
		initial_state = name

	return state


## Gets a state
func get_state(name: String) -> State:
	return states.get(name)


## Removes a state
func remove_state(name: String) -> void:
	states.erase(name)

	# Remove transitions involving this state
	for i in range(transitions.size() - 1, -1, -1):
		if transitions[i].from_state == name or transitions[i].to_state == name:
			transitions.remove_at(i)


## Checks if state exists
func has_state(name: String) -> bool:
	return states.has(name)


## Sets entry animation for a state
func set_entry_animation(state_name: String, animation: AnimationSequence) -> void:
	if states.has(state_name):
		(states[state_name] as State).entry_animation = animation


## Sets exit animation for a state
func set_exit_animation(state_name: String, animation: AnimationSequence) -> void:
	if states.has(state_name):
		(states[state_name] as State).exit_animation = animation


## Sets state callbacks
func set_state_callbacks(
	state_name: String,
	on_enter: Callable = Callable(),
	on_exit: Callable = Callable(),
	on_update: Callable = Callable()
) -> void:
	if states.has(state_name):
		var state: State = states[state_name]
		state.on_enter = on_enter
		state.on_exit = on_exit
		state.on_update = on_update


## Sets initial state
func set_initial_state(name: String) -> void:
	initial_state = name

# endregion


# region - Transition Management

## Adds a transition
func add_transition(
	from_state: String,
	to_state: String,
	condition_param: String = "",
	condition_type: ConditionType = ConditionType.TRIGGER,
	condition_value: Variant = true
) -> Transition:
	var transition := Transition.new(from_state, to_state)

	if not condition_param.is_empty():
		transition.add_condition(condition_param, condition_type, condition_value)

	transitions.append(transition)
	_sort_transitions()

	return transition


## Adds an any-state transition
func add_any_state_transition(
	to_state: String,
	condition_param: String = "",
	condition_type: ConditionType = ConditionType.TRIGGER,
	condition_value: Variant = true
) -> Transition:
	var transition := Transition.new("*", to_state)

	if not condition_param.is_empty():
		transition.add_condition(condition_param, condition_type, condition_value)

	any_state_transitions.append(transition)
	_sort_transitions()

	return transition


## Configures a transition
func configure_transition(
	from_state: String,
	to_state: String,
	type: TransitionType = TransitionType.CROSSFADE,
	duration: float = 0.2
) -> Transition:
	for transition in transitions:
		if transition.from_state == from_state and transition.to_state == to_state:
			transition.type = type
			transition.duration = duration
			return transition
	return null


## Removes a transition
func remove_transition(from_state: String, to_state: String) -> void:
	for i in range(transitions.size() - 1, -1, -1):
		if transitions[i].from_state == from_state and transitions[i].to_state == to_state:
			transitions.remove_at(i)


## Gets transitions from a state
func get_transitions_from(state_name: String) -> Array[Transition]:
	var result: Array[Transition] = []
	for transition in transitions:
		if transition.from_state == state_name:
			result.append(transition)
	return result


func _sort_transitions() -> void:
	transitions.sort_custom(func(a: Transition, b: Transition) -> bool:
		return a.priority > b.priority
	)
	any_state_transitions.sort_custom(func(a: Transition, b: Transition) -> bool:
		return a.priority > b.priority
	)

# endregion


# region - Parameter Management

## Sets a parameter value
func set_parameter(name: String, value: Variant) -> void:
	var old_value: Variant = parameters.get(name)
	parameters[name] = value
	parameter_changed.emit(name, old_value, value)

	if debug_enabled:
		debug_info.parameters = parameters.duplicate()


## Gets a parameter value
func get_parameter(name: String, default: Variant = null) -> Variant:
	return parameters.get(name, default)


## Sets a trigger parameter (auto-resets after use)
func set_trigger(name: String) -> void:
	set_parameter(name, true)


## Resets a trigger parameter
func reset_trigger(name: String) -> void:
	set_parameter(name, false)


## Sets a boolean parameter
func set_bool(name: String, value: bool) -> void:
	set_parameter(name, value)


## Sets a float parameter
func set_float(name: String, value: float) -> void:
	set_parameter(name, value)


## Sets an integer parameter
func set_int(name: String, value: int) -> void:
	set_parameter(name, value)

# endregion


# region - Layer Management (Layered Mode)

## Adds a layer
func add_layer(name: String, weight: float = 1.0, override: bool = false) -> Layer:
	var layer := Layer.new(name)
	layer.weight = weight
	layer.override_mode = override
	layers.append(layer)
	return layer


## Gets a layer
func get_layer(name: String) -> Layer:
	for layer in layers:
		if layer.name == name:
			return layer
	return null


## Sets layer weight
func set_layer_weight(layer_name: String, weight: float) -> void:
	var layer := get_layer(layer_name)
	if layer:
		layer.weight = clampf(weight, 0.0, 1.0)


## Enables/disables a layer
func set_layer_enabled(layer_name: String, enabled: bool) -> void:
	var layer := get_layer(layer_name)
	if layer:
		layer.enabled = enabled

# endregion


# region - Blend Tree Mode

## Sets blend weight for a state (blend tree mode)
func set_blend_weight(state_name: String, weight: float) -> void:
	if mode == Mode.BLEND_TREE:
		_blend_weights[state_name] = clampf(weight, 0.0, 1.0)


## Gets blend weight for a state
func get_blend_weight(state_name: String) -> float:
	return _blend_weights.get(state_name, 0.0)


## Sets 2D blend position (for 2D blend spaces)
func set_blend_position(x: float, y: float) -> void:
	set_parameter("blend_x", x)
	set_parameter("blend_y", y)

# endregion


# region - Playback Control

## Starts the state machine
func start(node: Node = null) -> void:
	if node:
		target_node = node

	if not target_node:
		push_warning("AnimationStateMachine: No target node set")
		return

	if initial_state.is_empty() and not states.is_empty():
		initial_state = states.keys()[0]

	is_running = true
	_enter_state(initial_state)

	started.emit()


## Stops the state machine
func stop() -> void:
	is_running = false

	if not current_state.is_empty():
		_exit_state(current_state)

	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	stopped.emit()


## Updates the state machine (call each frame if using MANUAL update mode)
func update(delta: float) -> void:
	if not is_running:
		return

	state_time += delta

	if debug_enabled:
		debug_info.state_times[current_state] = state_time

	# Check for transitions
	if not _active_transition:
		_check_transitions()

	# Update current state
	_update_current_state(delta)

	updated.emit(current_state, delta)


## Forces a transition to a specific state
func force_transition(to_state: String, immediate: bool = false) -> void:
	if not states.has(to_state):
		push_warning("AnimationStateMachine: State '%s' not found" % to_state)
		return

	if immediate:
		_exit_state(current_state)
		_enter_state(to_state)
	else:
		_start_transition(Transition.new(current_state, to_state))


## Gets current state name
func get_current_state() -> String:
	return current_state


## Gets time in current state
func get_state_time() -> float:
	return state_time


## Checks if in a specific state
func is_in_state(state_name: String) -> bool:
	return current_state == state_name


## Checks if transitioning
func is_transitioning() -> bool:
	return _active_transition != null

# endregion


# region - Internal State Logic

func _check_transitions() -> void:
	# Check any-state transitions first (highest priority)
	for transition in any_state_transitions:
		if transition.to_state == current_state:
			continue  # Don't transition to self from any-state

		if _can_take_transition(transition):
			_start_transition(transition)
			return

	# Check normal transitions
	for transition in transitions:
		if transition.from_state != current_state:
			continue

		if _can_take_transition(transition):
			_start_transition(transition)
			return


func _can_take_transition(transition: Transition) -> bool:
	# Check exit time requirement
	if transition.has_exit_time:
		var state: State = states.get(current_state)
		if state and state.animation:
			var progress := state.animation.get_progress()
			if progress < transition.exit_time:
				return false

	# Check all conditions
	return transition.evaluate(parameters)


func _start_transition(transition: Transition) -> void:
	_active_transition = transition
	_transition_progress = 0.0

	transition_started.emit(transition.from_state, transition.to_state)

	if debug_enabled:
		debug_info.active_transitions = ["%s -> %s" % [transition.from_state, transition.to_state]]
		debug_info.add_transition(transition.from_state, transition.to_state)

	# Reset any triggers used in this transition
	for condition in transition.conditions:
		if condition.type == ConditionType.TRIGGER:
			reset_trigger(condition.parameter)

	match transition.type:
		TransitionType.IMMEDIATE:
			_complete_transition()

		TransitionType.CROSSFADE:
			_do_crossfade_transition(transition)

		TransitionType.FADE_OUT_IN:
			_do_fade_out_in_transition(transition)

		TransitionType.CUSTOM:
			if transition.custom_animation.is_valid():
				transition.custom_animation.call(transition.from_state, transition.to_state)
				# Expect custom animation to call _complete_transition()


func _do_crossfade_transition(transition: Transition) -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		_transition_tween = tree.create_tween()

		_transition_tween.tween_method(
			_update_crossfade,
			0.0,
			1.0,
			transition.duration
		)

		_transition_tween.finished.connect(_complete_transition)


func _update_crossfade(blend: float) -> void:
	_transition_progress = blend
	# Blend between states happens in _update_current_state


func _do_fade_out_in_transition(transition: Transition) -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		_transition_tween = tree.create_tween()

		# Fade out
		_transition_tween.tween_method(
			func(v: float) -> void: _transition_progress = v,
			0.0,
			0.5,
			transition.duration * 0.5
		)

		# Switch state at midpoint
		_transition_tween.tween_callback(func() -> void:
			_exit_state(current_state)
			_enter_state(transition.to_state)
		)

		# Fade in
		_transition_tween.tween_method(
			func(v: float) -> void: _transition_progress = v,
			0.5,
			1.0,
			transition.duration * 0.5
		)

		_transition_tween.finished.connect(_complete_transition)


func _complete_transition() -> void:
	if not _active_transition:
		return

	var from_state := _active_transition.from_state
	var to_state := _active_transition.to_state

	# Only exit/enter if not already done (fade_out_in does it at midpoint)
	if current_state == from_state:
		_exit_state(from_state)
		_enter_state(to_state)

	transition_completed.emit(from_state, to_state)

	_active_transition = null
	_transition_progress = 0.0

	if debug_enabled:
		debug_info.active_transitions.clear()


func _enter_state(state_name: String) -> void:
	if not states.has(state_name):
		return

	var previous := current_state
	current_state = state_name
	state_time = 0.0

	var state: State = states[state_name]

	if debug_enabled:
		debug_info.previous_state = previous
		debug_info.current_state = state_name

	# Play entry animation
	if state.entry_animation and target_node:
		state.entry_animation.play(target_node)
		# Wait for entry animation to complete before main animation
		# For now, we'll just start both

	# Start main animation
	if state.animation and target_node:
		state.animation.play(target_node)

	# Call enter callback
	if state.on_enter.is_valid():
		state.on_enter.call()

	# Start sub-state machine
	if state.sub_state_machine:
		state.sub_state_machine.start(target_node)

	state_entered.emit(state_name)


func _exit_state(state_name: String) -> void:
	if not states.has(state_name):
		return

	var state: State = states[state_name]

	# Stop current animation
	if state.animation:
		state.animation.stop()

	# Play exit animation
	if state.exit_animation and target_node:
		state.exit_animation.play(target_node)

	# Call exit callback
	if state.on_exit.is_valid():
		state.on_exit.call()

	# Stop sub-state machine
	if state.sub_state_machine:
		state.sub_state_machine.stop()

	state_exited.emit(state_name)


func _update_current_state(delta: float) -> void:
	if not states.has(current_state):
		return

	var state: State = states[current_state]

	# Handle blending during transition
	if _active_transition and _active_transition.type == TransitionType.CROSSFADE:
		# Blend between from and to state animations
		# This is simplified - full implementation would blend animation values
		pass

	# Call update callback
	if state.on_update.is_valid():
		state.on_update.call(delta)

	# Update sub-state machine
	if state.sub_state_machine:
		state.sub_state_machine.update(delta)

# endregion


# region - Debug Visualization

## Enables debug mode
func enable_debug(enabled: bool = true) -> void:
	debug_enabled = enabled


## Gets debug visualization data
func get_debug_info() -> DebugInfo:
	return debug_info


## Gets state graph as dictionary for visualization
func get_state_graph() -> Dictionary:
	var graph := {
		"states": [],
		"transitions": [],
	}

	for state_name: String in states:
		var state: State = states[state_name]
		graph.states.append({
			"name": state_name,
			"position": state.editor_position,
			"is_current": state_name == current_state,
			"is_initial": state_name == initial_state,
			"has_animation": state.animation != null,
			"loops": state.loops,
			"tags": state.tags,
		})

	for transition in transitions:
		graph.transitions.append({
			"from": transition.from_state,
			"to": transition.to_state,
			"type": transition.type,
			"duration": transition.duration,
			"priority": transition.priority,
			"conditions": transition.conditions.size(),
			"is_active": _active_transition == transition,
		})

	for transition in any_state_transitions:
		graph.transitions.append({
			"from": "*",
			"to": transition.to_state,
			"type": transition.type,
			"duration": transition.duration,
			"priority": transition.priority,
			"conditions": transition.conditions.size(),
			"is_active": _active_transition == transition,
		})

	return graph

# endregion


# region - Preset State Machines

## Creates a simple two-state toggle machine
static func create_toggle(
	state_a: String,
	state_b: String,
	trigger: String = "toggle"
) -> AnimationStateMachine:
	var sm := AnimationStateMachine.new()

	sm.add_state(state_a)
	sm.add_state(state_b)

	sm.add_transition(state_a, state_b, trigger, ConditionType.TRIGGER)
	sm.add_transition(state_b, state_a, trigger, ConditionType.TRIGGER)

	sm.set_initial_state(state_a)

	return sm


## Creates a button state machine (idle, hover, pressed, disabled)
static func create_button_states() -> AnimationStateMachine:
	var sm := AnimationStateMachine.new()

	sm.add_state("idle")
	sm.add_state("hover")
	sm.add_state("pressed")
	sm.add_state("disabled")

	# Transitions from idle
	sm.add_transition("idle", "hover", "is_hovered", ConditionType.EQUALS, true)
	sm.add_transition("idle", "disabled", "is_disabled", ConditionType.EQUALS, true)

	# Transitions from hover
	sm.add_transition("hover", "idle", "is_hovered", ConditionType.EQUALS, false)
	sm.add_transition("hover", "pressed", "is_pressed", ConditionType.EQUALS, true)
	sm.add_transition("hover", "disabled", "is_disabled", ConditionType.EQUALS, true)

	# Transitions from pressed
	sm.add_transition("pressed", "hover", "is_pressed", ConditionType.EQUALS, false)
	sm.add_transition("pressed", "disabled", "is_disabled", ConditionType.EQUALS, true)

	# Transitions from disabled
	sm.add_transition("disabled", "idle", "is_disabled", ConditionType.EQUALS, false)

	sm.set_initial_state("idle")
	sm.set_bool("is_hovered", false)
	sm.set_bool("is_pressed", false)
	sm.set_bool("is_disabled", false)

	return sm


## Creates a simple animation loop state machine
static func create_loop_states(
	states_list: Array[String],
	auto_advance: bool = false
) -> AnimationStateMachine:
	var sm := AnimationStateMachine.new()

	for state_name in states_list:
		sm.add_state(state_name)

	# Create transitions between consecutive states
	for i in range(states_list.size()):
		var next_index: int = (i + 1) % states_list.size()
		var trigger := "next" if not auto_advance else ""
		sm.add_transition(states_list[i], states_list[next_index], trigger, ConditionType.TRIGGER)

	if not states_list.is_empty():
		sm.set_initial_state(states_list[0])

	return sm

# endregion
