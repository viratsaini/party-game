## AnimationSequence - Professional timeline-based animation system.
##
## Features:
## - Timeline-based sequences with parallel tracks (Unity Timeline style)
## - Animation blending and crossfading between clips
## - Event markers for sound/effects synchronization
## - Loop variations with randomization
## - Conditional branching based on runtime conditions
## - Keyframe interpolation with per-property easing
##
## Usage:
##   var sequence := AnimationSequence.new()
##   sequence.add_track("position", Track.Type.TRANSFORM)
##   sequence.add_keyframe("position", 0.0, Vector2.ZERO)
##   sequence.add_keyframe("position", 1.0, Vector2(100, 0))
##   sequence.add_event(0.5, "play_sound", ["whoosh"])
##   sequence.play(my_node)
class_name AnimationSequence
extends RefCounted


# region - Signals

## Emitted when the sequence starts playing
signal started

## Emitted when the sequence completes
signal completed

## Emitted when the sequence is paused
signal paused

## Emitted when the sequence resumes
signal resumed

## Emitted when an event marker is reached
signal event_triggered(event_name: String, args: Array)

## Emitted when a loop iteration completes
signal loop_completed(iteration: int)

## Emitted when a branch condition is evaluated
signal branch_evaluated(branch_name: String, result: bool)

## Emitted every frame with current time
signal time_updated(current_time: float, total_duration: float)

# endregion


# region - Enums

## Types of tracks available
enum TrackType {
	PROPERTY,     ## Animates any property
	TRANSFORM,    ## Position, rotation, scale combined
	COLOR,        ## Modulate/color animations
	AUDIO,        ## Audio cue track
	EVENT,        ## Callback/event markers
	SUB_SEQUENCE, ## Nested sequence track
}

## Interpolation modes for keyframes
enum InterpolationMode {
	LINEAR,       ## Linear interpolation
	CONSTANT,     ## Hold value until next keyframe (stepped)
	CUBIC,        ## Cubic bezier interpolation
	SPRING,       ## Spring physics interpolation
	CUSTOM,       ## Custom easing function
}

## Blend modes for overlapping animations
enum BlendMode {
	REPLACE,      ## New animation replaces old
	ADDITIVE,     ## Values are added together
	MULTIPLY,     ## Values are multiplied
	BLEND,        ## Weighted blend based on weight
}

## Loop modes
enum LoopMode {
	NONE,         ## Play once
	LOOP,         ## Loop indefinitely
	PING_PONG,    ## Play forward then backward
	LOOP_COUNT,   ## Loop specific number of times
}

## Sequence state
enum State {
	STOPPED,
	PLAYING,
	PAUSED,
	BLENDING,
}

# endregion


# region - Inner Classes

## Represents a single keyframe in a track
class Keyframe extends RefCounted:
	var time: float = 0.0
	var value: Variant
	var interpolation: InterpolationMode = InterpolationMode.LINEAR
	var easing: String = "quad_out"
	var bezier_handles: Array[Vector2] = [Vector2(-0.25, 0.0), Vector2(0.25, 0.0)]
	var spring_damping: float = 0.4
	var spring_frequency: float = 6.0
	var custom_easing: Callable

	func _init(p_time: float = 0.0, p_value: Variant = null) -> void:
		time = p_time
		value = p_value

	func duplicate() -> Keyframe:
		var kf := Keyframe.new(time, value)
		kf.interpolation = interpolation
		kf.easing = easing
		kf.bezier_handles = bezier_handles.duplicate()
		kf.spring_damping = spring_damping
		kf.spring_frequency = spring_frequency
		kf.custom_easing = custom_easing
		return kf


## Represents an animation track
class Track extends RefCounted:
	var name: String
	var type: TrackType
	var property_path: String = ""
	var keyframes: Array[Keyframe] = []
	var blend_mode: BlendMode = BlendMode.REPLACE
	var weight: float = 1.0
	var enabled: bool = true
	var muted: bool = false

	func _init(p_name: String = "", p_type: TrackType = TrackType.PROPERTY) -> void:
		name = p_name
		type = p_type

	func add_keyframe(kf: Keyframe) -> void:
		keyframes.append(kf)
		_sort_keyframes()

	func remove_keyframe(index: int) -> void:
		if index >= 0 and index < keyframes.size():
			keyframes.remove_at(index)

	func get_keyframe_at(time: float) -> Keyframe:
		for kf in keyframes:
			if absf(kf.time - time) < 0.001:
				return kf
		return null

	func _sort_keyframes() -> void:
		keyframes.sort_custom(func(a: Keyframe, b: Keyframe) -> bool:
			return a.time < b.time
		)

	func get_duration() -> float:
		if keyframes.is_empty():
			return 0.0
		return keyframes[keyframes.size() - 1].time


## Represents an event marker
class EventMarker extends RefCounted:
	var time: float = 0.0
	var event_name: String = ""
	var args: Array = []
	var callback: Callable
	var triggered: bool = false

	func _init(p_time: float = 0.0, p_name: String = "", p_args: Array = []) -> void:
		time = p_time
		event_name = p_name
		args = p_args

	func reset() -> void:
		triggered = false


## Represents a conditional branch
class Branch extends RefCounted:
	var name: String
	var condition: Callable
	var true_sequence: AnimationSequence
	var false_sequence: AnimationSequence
	var evaluated: bool = false

	func _init(p_name: String = "") -> void:
		name = p_name

	func evaluate() -> bool:
		if condition.is_valid():
			return condition.call()
		return false


## Loop configuration with variations
class LoopConfig extends RefCounted:
	var mode: LoopMode = LoopMode.NONE
	var count: int = 1
	var current_iteration: int = 0
	var variation_enabled: bool = false
	var timing_variance: float = 0.0
	var value_variance: float = 0.0
	var random_seed: int = 0

	func reset() -> void:
		current_iteration = 0

	func should_continue() -> bool:
		match mode:
			LoopMode.NONE:
				return false
			LoopMode.LOOP:
				return true
			LoopMode.PING_PONG:
				return true
			LoopMode.LOOP_COUNT:
				return current_iteration < count
		return false

# endregion


# region - Properties

## Sequence name for identification
var sequence_name: String = "Unnamed"

## All animation tracks
var tracks: Dictionary = {}  ## name -> Track

## Event markers
var events: Array[EventMarker] = []

## Conditional branches
var branches: Array[Branch] = []

## Loop configuration
var loop_config: LoopConfig = LoopConfig.new()

## Current playback state
var state: State = State.STOPPED

## Current playback time
var current_time: float = 0.0

## Playback speed multiplier
var speed_scale: float = 1.0

## Whether to auto-reverse in ping-pong mode
var playing_forward: bool = true

## Target node being animated
var _target_node: Node = null

## Active tween for playback
var _playback_tween: Tween = null

## Blend data for crossfading
var _blend_from_sequence: AnimationSequence = null
var _blend_weight: float = 1.0
var _blend_duration: float = 0.0

## Original values for restoration
var _original_values: Dictionary = {}

## Cached duration
var _cached_duration: float = -1.0

# endregion


# region - Lifecycle

func _init(p_name: String = "Unnamed") -> void:
	sequence_name = p_name


## Creates a copy of this sequence
func duplicate() -> AnimationSequence:
	var seq := AnimationSequence.new(sequence_name + "_copy")

	for track_name: String in tracks:
		var track: Track = tracks[track_name]
		var new_track := Track.new(track.name, track.type)
		new_track.property_path = track.property_path
		new_track.blend_mode = track.blend_mode
		new_track.weight = track.weight
		new_track.enabled = track.enabled

		for kf: Keyframe in track.keyframes:
			new_track.add_keyframe(kf.duplicate())

		seq.tracks[track_name] = new_track

	for event: EventMarker in events:
		var new_event := EventMarker.new(event.time, event.event_name, event.args.duplicate())
		new_event.callback = event.callback
		seq.events.append(new_event)

	seq.loop_config.mode = loop_config.mode
	seq.loop_config.count = loop_config.count
	seq.speed_scale = speed_scale

	return seq

# endregion


# region - Track Management

## Adds a new track to the sequence
func add_track(name: String, type: TrackType = TrackType.PROPERTY, property_path: String = "") -> Track:
	var track := Track.new(name, type)
	track.property_path = property_path if property_path != "" else name
	tracks[name] = track
	_invalidate_cache()
	return track


## Gets a track by name
func get_track(name: String) -> Track:
	return tracks.get(name)


## Removes a track
func remove_track(name: String) -> bool:
	if tracks.has(name):
		tracks.erase(name)
		_invalidate_cache()
		return true
	return false


## Checks if a track exists
func has_track(name: String) -> bool:
	return tracks.has(name)


## Sets track weight for blending
func set_track_weight(name: String, weight: float) -> void:
	if tracks.has(name):
		(tracks[name] as Track).weight = clampf(weight, 0.0, 1.0)


## Enables or disables a track
func set_track_enabled(name: String, enabled: bool) -> void:
	if tracks.has(name):
		(tracks[name] as Track).enabled = enabled


## Mutes a track (still evaluates but doesn't apply)
func set_track_muted(name: String, muted: bool) -> void:
	if tracks.has(name):
		(tracks[name] as Track).muted = muted

# endregion


# region - Keyframe Management

## Adds a keyframe to a track
func add_keyframe(
	track_name: String,
	time: float,
	value: Variant,
	interpolation: InterpolationMode = InterpolationMode.LINEAR,
	easing: String = "quad_out"
) -> Keyframe:
	if not tracks.has(track_name):
		push_warning("AnimationSequence: Track '%s' not found" % track_name)
		return null

	var kf := Keyframe.new(time, value)
	kf.interpolation = interpolation
	kf.easing = easing

	(tracks[track_name] as Track).add_keyframe(kf)
	_invalidate_cache()

	return kf


## Adds a keyframe with spring physics
func add_spring_keyframe(
	track_name: String,
	time: float,
	value: Variant,
	damping: float = 0.4,
	frequency: float = 6.0
) -> Keyframe:
	var kf := add_keyframe(track_name, time, value, InterpolationMode.SPRING)
	if kf:
		kf.spring_damping = damping
		kf.spring_frequency = frequency
	return kf


## Adds a keyframe with bezier handles
func add_bezier_keyframe(
	track_name: String,
	time: float,
	value: Variant,
	in_handle: Vector2 = Vector2(-0.25, 0.0),
	out_handle: Vector2 = Vector2(0.25, 0.0)
) -> Keyframe:
	var kf := add_keyframe(track_name, time, value, InterpolationMode.CUBIC)
	if kf:
		kf.bezier_handles = [in_handle, out_handle]
	return kf


## Adds a keyframe with custom easing function
func add_custom_keyframe(
	track_name: String,
	time: float,
	value: Variant,
	easing_func: Callable
) -> Keyframe:
	var kf := add_keyframe(track_name, time, value, InterpolationMode.CUSTOM)
	if kf:
		kf.custom_easing = easing_func
	return kf


## Removes a keyframe at specific time
func remove_keyframe(track_name: String, time: float) -> bool:
	if not tracks.has(track_name):
		return false

	var track: Track = tracks[track_name]
	for i in range(track.keyframes.size()):
		if absf(track.keyframes[i].time - time) < 0.001:
			track.remove_keyframe(i)
			_invalidate_cache()
			return true

	return false


## Moves a keyframe to a new time
func move_keyframe(track_name: String, old_time: float, new_time: float) -> bool:
	if not tracks.has(track_name):
		return false

	var track: Track = tracks[track_name]
	var kf := track.get_keyframe_at(old_time)
	if kf:
		kf.time = new_time
		track._sort_keyframes()
		_invalidate_cache()
		return true

	return false

# endregion


# region - Event Management

## Adds an event marker
func add_event(time: float, event_name: String, args: Array = []) -> EventMarker:
	var marker := EventMarker.new(time, event_name, args)
	events.append(marker)
	_sort_events()
	return marker


## Adds an event with a callback
func add_event_callback(time: float, callback: Callable, args: Array = []) -> EventMarker:
	var marker := EventMarker.new(time, "callback", args)
	marker.callback = callback
	events.append(marker)
	_sort_events()
	return marker


## Removes an event marker
func remove_event(event_name: String) -> bool:
	for i in range(events.size() - 1, -1, -1):
		if events[i].event_name == event_name:
			events.remove_at(i)
			return true
	return false


## Gets all events at a specific time
func get_events_at(time: float, tolerance: float = 0.016) -> Array[EventMarker]:
	var result: Array[EventMarker] = []
	for event in events:
		if absf(event.time - time) <= tolerance:
			result.append(event)
	return result


func _sort_events() -> void:
	events.sort_custom(func(a: EventMarker, b: EventMarker) -> bool:
		return a.time < b.time
	)


func _reset_events() -> void:
	for event in events:
		event.reset()

# endregion


# region - Branch Management

## Adds a conditional branch
func add_branch(name: String, condition: Callable) -> Branch:
	var branch := Branch.new(name)
	branch.condition = condition
	branches.append(branch)
	return branch


## Sets the sequence to play when branch is true
func set_branch_true_sequence(branch_name: String, sequence: AnimationSequence) -> void:
	for branch in branches:
		if branch.name == branch_name:
			branch.true_sequence = sequence
			return


## Sets the sequence to play when branch is false
func set_branch_false_sequence(branch_name: String, sequence: AnimationSequence) -> void:
	for branch in branches:
		if branch.name == branch_name:
			branch.false_sequence = sequence
			return

# endregion


# region - Loop Configuration

## Sets the loop mode
func set_loop_mode(mode: LoopMode, count: int = 1) -> void:
	loop_config.mode = mode
	loop_config.count = count


## Enables loop variations
func enable_loop_variations(
	timing_variance: float = 0.1,
	value_variance: float = 0.05,
	seed_val: int = 0
) -> void:
	loop_config.variation_enabled = true
	loop_config.timing_variance = timing_variance
	loop_config.value_variance = value_variance
	loop_config.random_seed = seed_val

# endregion


# region - Playback Control

## Plays the sequence on a target node
func play(target: Node, from_time: float = 0.0) -> void:
	if not is_instance_valid(target):
		push_warning("AnimationSequence: Invalid target node")
		return

	_target_node = target
	current_time = from_time
	playing_forward = true
	state = State.PLAYING

	_store_original_values()
	_reset_events()
	loop_config.reset()

	_start_playback()
	started.emit()


## Plays with crossfade from another sequence
func play_with_blend(
	target: Node,
	from_sequence: AnimationSequence,
	blend_duration: float = 0.3
) -> void:
	_blend_from_sequence = from_sequence
	_blend_duration = blend_duration
	_blend_weight = 0.0
	state = State.BLENDING

	play(target)


## Stops playback
func stop(restore_original: bool = false) -> void:
	if _playback_tween and _playback_tween.is_valid():
		_playback_tween.kill()

	state = State.STOPPED
	current_time = 0.0

	if restore_original:
		_restore_original_values()

	_blend_from_sequence = null


## Pauses playback
func pause() -> void:
	if state == State.PLAYING:
		if _playback_tween and _playback_tween.is_valid():
			_playback_tween.pause()
		state = State.PAUSED
		paused.emit()


## Resumes playback
func resume() -> void:
	if state == State.PAUSED:
		if _playback_tween and _playback_tween.is_valid():
			_playback_tween.play()
		state = State.PLAYING
		resumed.emit()


## Seeks to a specific time
func seek(time: float) -> void:
	current_time = clampf(time, 0.0, get_duration())
	_evaluate_at_time(current_time)


## Sets playback speed
func set_speed_scale(scale: float) -> void:
	speed_scale = maxf(scale, 0.01)


## Gets total duration
func get_duration() -> float:
	if _cached_duration < 0.0:
		_cached_duration = 0.0
		for track_name: String in tracks:
			var track: Track = tracks[track_name]
			_cached_duration = maxf(_cached_duration, track.get_duration())
	return _cached_duration


## Checks if currently playing
func is_playing() -> bool:
	return state == State.PLAYING or state == State.BLENDING


## Gets current progress (0-1)
func get_progress() -> float:
	var duration := get_duration()
	if duration <= 0.0:
		return 0.0
	return current_time / duration

# endregion


# region - Internal Playback

func _start_playback() -> void:
	if not is_instance_valid(_target_node):
		return

	var duration := get_duration()
	if duration <= 0.0:
		_on_playback_complete()
		return

	_playback_tween = _target_node.create_tween()
	_playback_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

	# Use method tweening for frame-by-frame evaluation
	_playback_tween.tween_method(
		_on_playback_update,
		current_time,
		duration,
		duration / speed_scale
	)

	_playback_tween.finished.connect(_on_playback_complete)


func _on_playback_update(time: float) -> void:
	var old_time := current_time

	if playing_forward:
		current_time = time
	else:
		current_time = get_duration() - time

	# Check for events between old and current time
	_check_events(old_time, current_time)

	# Handle blending
	if state == State.BLENDING:
		_blend_weight = minf(_blend_weight + (1.0 / (_blend_duration * 60.0)), 1.0)
		if _blend_weight >= 1.0:
			state = State.PLAYING
			_blend_from_sequence = null

	# Evaluate all tracks
	_evaluate_at_time(current_time)

	time_updated.emit(current_time, get_duration())


func _on_playback_complete() -> void:
	loop_config.current_iteration += 1
	loop_completed.emit(loop_config.current_iteration)

	# Handle looping
	if loop_config.should_continue():
		match loop_config.mode:
			LoopMode.LOOP, LoopMode.LOOP_COUNT:
				_reset_events()
				current_time = 0.0
				_start_playback()
			LoopMode.PING_PONG:
				playing_forward = not playing_forward
				_reset_events()
				_start_playback()
	else:
		state = State.STOPPED
		completed.emit()


func _check_events(old_time: float, new_time: float) -> void:
	var min_time := minf(old_time, new_time)
	var max_time := maxf(old_time, new_time)

	for event in events:
		if event.triggered:
			continue

		if event.time >= min_time and event.time <= max_time:
			event.triggered = true

			if event.callback.is_valid():
				event.callback.callv(event.args)

			event_triggered.emit(event.event_name, event.args)


func _evaluate_at_time(time: float) -> void:
	if not is_instance_valid(_target_node):
		return

	for track_name: String in tracks:
		var track: Track = tracks[track_name]

		if not track.enabled or track.muted:
			continue

		var value := _evaluate_track(track, time)
		if value == null:
			continue

		# Handle blending with previous sequence
		if _blend_from_sequence and _blend_from_sequence.has_track(track_name):
			var blend_track: Track = _blend_from_sequence.get_track(track_name)
			var blend_value := _evaluate_track(blend_track, _blend_from_sequence.current_time)
			if blend_value != null:
				value = _blend_values(blend_value, value, _blend_weight)

		# Apply track weight
		if track.weight < 1.0 and _original_values.has(track.property_path):
			var original := _original_values[track.property_path]
			value = _blend_values(original, value, track.weight)

		# Apply to target
		_apply_value(track, value)


func _evaluate_track(track: Track, time: float) -> Variant:
	if track.keyframes.is_empty():
		return null

	# Find surrounding keyframes
	var prev_kf: Keyframe = null
	var next_kf: Keyframe = null

	for kf in track.keyframes:
		if kf.time <= time:
			prev_kf = kf
		elif next_kf == null:
			next_kf = kf
			break

	# Before first keyframe
	if prev_kf == null:
		return track.keyframes[0].value

	# After last keyframe or constant interpolation
	if next_kf == null or prev_kf.interpolation == InterpolationMode.CONSTANT:
		return prev_kf.value

	# Calculate interpolation factor
	var time_range: float = next_kf.time - prev_kf.time
	if time_range <= 0.0:
		return prev_kf.value

	var t: float = (time - prev_kf.time) / time_range

	# Apply easing based on interpolation mode
	var eased_t: float = _apply_interpolation(t, prev_kf)

	# Interpolate value
	return _interpolate_value(prev_kf.value, next_kf.value, eased_t)


func _apply_interpolation(t: float, kf: Keyframe) -> float:
	match kf.interpolation:
		InterpolationMode.LINEAR:
			return t
		InterpolationMode.CONSTANT:
			return 0.0
		InterpolationMode.CUBIC:
			return _bezier_interpolate(t, kf.bezier_handles)
		InterpolationMode.SPRING:
			return UIEasing.spring(t, kf.spring_damping, kf.spring_frequency)
		InterpolationMode.CUSTOM:
			if kf.custom_easing.is_valid():
				return kf.custom_easing.call(t)
			return t

	return t


func _bezier_interpolate(t: float, handles: Array[Vector2]) -> float:
	# Simplified cubic bezier Y-value calculation
	var p1 := handles[0] if handles.size() > 0 else Vector2(0.25, 0.0)
	var p2 := handles[1] if handles.size() > 1 else Vector2(0.75, 1.0)

	# Cubic bezier formula
	var u := 1.0 - t
	return 3.0 * u * u * t * p1.y + 3.0 * u * t * t * p2.y + t * t * t


func _interpolate_value(from: Variant, to: Variant, t: float) -> Variant:
	if from is float and to is float:
		return lerpf(from, to, t)
	elif from is int and to is int:
		return int(lerpf(from, to, t))
	elif from is Vector2 and to is Vector2:
		return from.lerp(to, t)
	elif from is Vector3 and to is Vector3:
		return from.lerp(to, t)
	elif from is Color and to is Color:
		return from.lerp(to, t)
	elif from is Quaternion and to is Quaternion:
		return from.slerp(to, t)
	else:
		# Non-interpolatable, return based on t
		return to if t > 0.5 else from


func _blend_values(from: Variant, to: Variant, weight: float) -> Variant:
	return _interpolate_value(from, to, weight)


func _apply_value(track: Track, value: Variant) -> void:
	if not is_instance_valid(_target_node):
		return

	match track.type:
		TrackType.PROPERTY, TrackType.TRANSFORM, TrackType.COLOR:
			if track.property_path.contains(":"):
				# Handle subproperty (e.g., "modulate:a")
				var parts := track.property_path.split(":")
				var obj: Variant = _target_node.get(parts[0])
				if obj is Color and parts.size() > 1:
					match parts[1]:
						"r": obj.r = value
						"g": obj.g = value
						"b": obj.b = value
						"a": obj.a = value
					_target_node.set(parts[0], obj)
				elif obj is Vector2 and parts.size() > 1:
					match parts[1]:
						"x": obj.x = value
						"y": obj.y = value
					_target_node.set(parts[0], obj)
			else:
				_target_node.set(track.property_path, value)

		TrackType.AUDIO:
			# Audio cues are handled via events
			pass

		TrackType.EVENT:
			# Events are handled separately
			pass

		TrackType.SUB_SEQUENCE:
			# Sub-sequences handle their own playback
			pass


func _store_original_values() -> void:
	if not is_instance_valid(_target_node):
		return

	_original_values.clear()

	for track_name: String in tracks:
		var track: Track = tracks[track_name]
		var prop_path: String = track.property_path

		if prop_path.contains(":"):
			var parts := prop_path.split(":")
			_original_values[prop_path] = _target_node.get(parts[0])
		else:
			_original_values[prop_path] = _target_node.get(prop_path)


func _restore_original_values() -> void:
	if not is_instance_valid(_target_node):
		return

	for prop: String in _original_values:
		if prop.contains(":"):
			var parts := prop.split(":")
			_target_node.set(parts[0], _original_values[prop])
		else:
			_target_node.set(prop, _original_values[prop])


func _invalidate_cache() -> void:
	_cached_duration = -1.0

# endregion


# region - Builder API

## Fluent API for building sequences
class SequenceBuilder extends RefCounted:
	var _sequence: AnimationSequence
	var _current_track: String = ""
	var _current_time: float = 0.0

	func _init(name: String = "Built Sequence") -> void:
		_sequence = AnimationSequence.new(name)

	## Adds a property track
	func property(name: String, property_path: String = "") -> SequenceBuilder:
		_sequence.add_track(name, TrackType.PROPERTY, property_path)
		_current_track = name
		_current_time = 0.0
		return self

	## Adds a transform track (for Control or Node2D)
	func transform(name: String = "transform") -> SequenceBuilder:
		_sequence.add_track(name, TrackType.TRANSFORM)
		_current_track = name
		_current_time = 0.0
		return self

	## Adds a color/modulate track
	func color(name: String = "color", property_path: String = "modulate") -> SequenceBuilder:
		_sequence.add_track(name, TrackType.COLOR, property_path)
		_current_track = name
		_current_time = 0.0
		return self

	## Selects an existing track
	func track(name: String) -> SequenceBuilder:
		_current_track = name
		return self

	## Sets the current time cursor
	func at(time: float) -> SequenceBuilder:
		_current_time = time
		return self

	## Advances the time cursor
	func then(duration: float) -> SequenceBuilder:
		_current_time += duration
		return self

	## Adds a keyframe at current time
	func key(value: Variant, easing: String = "quad_out") -> SequenceBuilder:
		_sequence.add_keyframe(_current_track, _current_time, value, InterpolationMode.LINEAR, easing)
		return self

	## Adds a spring keyframe
	func spring_key(value: Variant, damping: float = 0.4, frequency: float = 6.0) -> SequenceBuilder:
		_sequence.add_spring_keyframe(_current_track, _current_time, value, damping, frequency)
		return self

	## Adds a bezier keyframe
	func bezier_key(value: Variant, in_handle: Vector2, out_handle: Vector2) -> SequenceBuilder:
		_sequence.add_bezier_keyframe(_current_track, _current_time, value, in_handle, out_handle)
		return self

	## Adds an event at current time
	func event(name: String, args: Array = []) -> SequenceBuilder:
		_sequence.add_event(_current_time, name, args)
		return self

	## Adds a callback at current time
	func callback(callable: Callable) -> SequenceBuilder:
		_sequence.add_event_callback(_current_time, callable)
		return self

	## Sets loop mode
	func loop(mode: LoopMode = LoopMode.LOOP, count: int = 1) -> SequenceBuilder:
		_sequence.set_loop_mode(mode, count)
		return self

	## Enables variations
	func with_variations(timing: float = 0.1, value_var: float = 0.05) -> SequenceBuilder:
		_sequence.enable_loop_variations(timing, value_var)
		return self

	## Sets playback speed
	func speed(scale: float) -> SequenceBuilder:
		_sequence.speed_scale = scale
		return self

	## Returns the built sequence
	func build() -> AnimationSequence:
		return _sequence


## Creates a new builder
static func builder(name: String = "Built Sequence") -> SequenceBuilder:
	return SequenceBuilder.new(name)

# endregion


# region - Preset Sequences

## Creates a fade in sequence
static func create_fade_in(duration: float = 0.3, easing: String = "quad_out") -> AnimationSequence:
	return builder("FadeIn") \
		.property("alpha", "modulate:a") \
		.at(0.0).key(0.0) \
		.then(duration).key(1.0, easing) \
		.build()


## Creates a fade out sequence
static func create_fade_out(duration: float = 0.3, easing: String = "quad_in") -> AnimationSequence:
	return builder("FadeOut") \
		.property("alpha", "modulate:a") \
		.at(0.0).key(1.0) \
		.then(duration).key(0.0, easing) \
		.build()


## Creates a scale bounce sequence
static func create_scale_bounce(
	target_scale: Vector2 = Vector2.ONE,
	overshoot: float = 0.2,
	duration: float = 0.4
) -> AnimationSequence:
	var overshoot_scale := target_scale * (1.0 + overshoot)

	return builder("ScaleBounce") \
		.property("scale") \
		.at(0.0).key(Vector2.ZERO) \
		.then(duration * 0.6).spring_key(overshoot_scale, 0.3, 8.0) \
		.then(duration * 0.4).spring_key(target_scale, 0.5, 6.0) \
		.build()


## Creates a slide in sequence
static func create_slide_in(
	from_offset: Vector2 = Vector2(100, 0),
	duration: float = 0.4
) -> AnimationSequence:
	return builder("SlideIn") \
		.property("position_offset", "position") \
		.at(0.0).key(from_offset) \
		.then(duration).spring_key(Vector2.ZERO, 0.4, 6.0) \
		.color("fade", "modulate") \
		.at(0.0).key(Color(1, 1, 1, 0)) \
		.then(duration * 0.6).key(Color.WHITE) \
		.build()


## Creates a shake sequence
static func create_shake(
	intensity: float = 10.0,
	duration: float = 0.5,
	decay: bool = true
) -> AnimationSequence:
	var seq := builder("Shake") \
		.property("shake_offset", "position")

	var steps: int = int(duration * 30.0)
	var step_duration: float = duration / float(steps)

	for i in range(steps):
		var decay_factor: float = 1.0 if not decay else (1.0 - float(i) / float(steps))
		var offset := Vector2(
			randf_range(-intensity, intensity) * decay_factor,
			randf_range(-intensity * 0.5, intensity * 0.5) * decay_factor
		)
		seq.then(step_duration).key(offset)

	seq.then(step_duration).key(Vector2.ZERO)

	return seq.build()

# endregion
