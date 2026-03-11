## PathFollower - Advanced path-based animation system for UI elements.
##
## Features:
## - Bezier curve following (quadratic, cubic, complex splines)
## - Speed curves (easing along path)
## - Path orientation (face direction of travel)
## - Multiple objects on same path with offsets
## - Path deformation and morphing
## - Looping paths with seamless transitions
## - Path editing tools and visualization
##
## Usage:
##   var path := AnimationPath.new()
##   path.add_point(Vector2.ZERO)
##   path.add_point(Vector2(200, 100), Vector2(-50, 0), Vector2(50, 0))
##   path.add_point(Vector2(400, 0))
##
##   var follower := PathFollower.new(my_node, path)
##   follower.follow(2.0)  # Follow path over 2 seconds
class_name PathFollower
extends RefCounted


# region - Signals

## Emitted when following starts
signal started

## Emitted when following completes
signal completed

## Emitted when a waypoint is reached
signal waypoint_reached(index: int, position: Vector2)

## Emitted when path loops
signal loop_completed(iteration: int)

## Emitted each frame with progress
signal progress_updated(progress: float, position: Vector2, direction: Vector2)

# endregion


# region - Enums

## Path interpolation types
enum PathType {
	LINEAR,        ## Straight lines between points
	QUADRATIC,     ## Quadratic bezier curves
	CUBIC,         ## Cubic bezier curves
	CATMULL_ROM,   ## Catmull-Rom spline (smooth through points)
	B_SPLINE,      ## B-Spline (smooth, doesn't pass through control points)
}

## Orientation modes
enum OrientationMode {
	NONE,          ## No rotation applied
	FACE_FORWARD,  ## Rotate to face direction of travel
	FACE_BACKWARD, ## Rotate to face opposite of travel
	CUSTOM,        ## Custom rotation per point
	CONSTANT,      ## Constant rotation value
}

## Loop modes
enum LoopMode {
	NONE,          ## Stop at end
	LOOP,          ## Jump back to start
	PING_PONG,     ## Reverse direction at ends
	CLOSED,        ## Treat path as closed loop
}

## Easing along path
enum SpeedMode {
	CONSTANT,      ## Constant speed along path
	EASE_IN,       ## Accelerate at start
	EASE_OUT,      ## Decelerate at end
	EASE_IN_OUT,   ## Accelerate and decelerate
	CUSTOM,        ## Custom speed curve
}

# endregion


# region - Inner Classes

## A single point on the path
class PathPoint extends RefCounted:
	## Position of the point
	var position: Vector2 = Vector2.ZERO

	## Tangent handles for bezier curves
	var handle_in: Vector2 = Vector2.ZERO
	var handle_out: Vector2 = Vector2.ZERO

	## Custom properties at this point
	var rotation: float = 0.0
	var scale: Vector2 = Vector2.ONE
	var speed_multiplier: float = 1.0
	var color: Color = Color.WHITE

	## Easing to next point
	var easing: String = "linear"

	## Whether handles are mirrored
	var handles_mirrored: bool = true

	## User data
	var user_data: Dictionary = {}


	func _init(pos: Vector2 = Vector2.ZERO, h_in: Vector2 = Vector2.ZERO, h_out: Vector2 = Vector2.ZERO) -> void:
		position = pos
		handle_in = h_in
		handle_out = h_out


	func duplicate() -> PathPoint:
		var p := PathPoint.new(position, handle_in, handle_out)
		p.rotation = rotation
		p.scale = scale
		p.speed_multiplier = speed_multiplier
		p.color = color
		p.easing = easing
		p.handles_mirrored = handles_mirrored
		p.user_data = user_data.duplicate()
		return p


	func set_handle_out(handle: Vector2) -> void:
		handle_out = handle
		if handles_mirrored:
			handle_in = -handle


	func set_handle_in(handle: Vector2) -> void:
		handle_in = handle
		if handles_mirrored:
			handle_out = -handle


## The animation path containing multiple points
class AnimationPath extends RefCounted:
	## All path points
	var points: Array[PathPoint] = []

	## Path type
	var type: PathType = PathType.CUBIC

	## Whether path is closed
	var closed: bool = false

	## Cached length
	var _cached_length: float = -1.0

	## Cached segment lengths
	var _segment_lengths: Array[float] = []

	## LUT for arc-length parameterization
	var _arc_length_lut: Array[float] = []
	var _lut_resolution: int = 100


	func _init(p_type: PathType = PathType.CUBIC) -> void:
		type = p_type


	## Adds a point to the path
	func add_point(
		position: Vector2,
		handle_in: Vector2 = Vector2.ZERO,
		handle_out: Vector2 = Vector2.ZERO
	) -> PathPoint:
		var point := PathPoint.new(position, handle_in, handle_out)
		points.append(point)
		_invalidate_cache()
		return point


	## Inserts a point at a specific index
	func insert_point(index: int, point: PathPoint) -> void:
		if index >= 0 and index <= points.size():
			points.insert(index, point)
			_invalidate_cache()


	## Removes a point
	func remove_point(index: int) -> void:
		if index >= 0 and index < points.size():
			points.remove_at(index)
			_invalidate_cache()


	## Gets point at index
	func get_point(index: int) -> PathPoint:
		if index >= 0 and index < points.size():
			return points[index]
		return null


	## Gets point count
	func get_point_count() -> int:
		return points.size()


	## Clears all points
	func clear() -> void:
		points.clear()
		_invalidate_cache()


	## Gets position at normalized parameter t (0-1)
	func sample(t: float) -> Vector2:
		if points.size() < 2:
			return points[0].position if not points.is_empty() else Vector2.ZERO

		t = clampf(t, 0.0, 1.0)

		# Handle closed path
		var num_segments: int = points.size() - 1 if not closed else points.size()
		var segment_t: float = t * float(num_segments)
		var segment_index: int = mini(int(segment_t), num_segments - 1)
		var local_t: float = segment_t - float(segment_index)

		return _sample_segment(segment_index, local_t)


	## Gets position at arc-length parameter (constant speed)
	func sample_arc_length(t: float) -> Vector2:
		_ensure_arc_length_lut()

		if _arc_length_lut.is_empty():
			return sample(t)

		t = clampf(t, 0.0, 1.0)
		var target_length: float = t * _cached_length

		# Binary search in LUT
		var low: int = 0
		var high: int = _arc_length_lut.size() - 1

		while low < high:
			var mid: int = (low + high) / 2
			if _arc_length_lut[mid] < target_length:
				low = mid + 1
			else:
				high = mid

		# Interpolate
		if low == 0:
			return sample(0.0)

		var prev_length: float = _arc_length_lut[low - 1]
		var curr_length: float = _arc_length_lut[low]
		var segment_t: float = (target_length - prev_length) / (curr_length - prev_length)
		var param: float = (float(low - 1) + segment_t) / float(_lut_resolution)

		return sample(param)


	## Gets tangent direction at t
	func sample_tangent(t: float) -> Vector2:
		var delta: float = 0.001
		var p1 := sample(maxf(t - delta, 0.0))
		var p2 := sample(minf(t + delta, 1.0))
		return (p2 - p1).normalized()


	## Gets tangent at arc-length parameter
	func sample_tangent_arc_length(t: float) -> Vector2:
		var delta: float = 0.001
		var p1 := sample_arc_length(maxf(t - delta, 0.0))
		var p2 := sample_arc_length(minf(t + delta, 1.0))
		return (p2 - p1).normalized()


	## Gets rotation angle at t (radians)
	func sample_rotation(t: float) -> float:
		var tangent := sample_tangent(t)
		return atan2(tangent.y, tangent.x)


	## Gets total path length
	func get_length() -> float:
		if _cached_length < 0.0:
			_calculate_length()
		return _cached_length


	## Gets length of a specific segment
	func get_segment_length(index: int) -> float:
		if _segment_lengths.is_empty():
			_calculate_length()
		if index >= 0 and index < _segment_lengths.size():
			return _segment_lengths[index]
		return 0.0


	## Gets closest point on path to a position
	func get_closest_point(pos: Vector2, resolution: int = 100) -> Dictionary:
		var closest_t: float = 0.0
		var closest_dist: float = INF
		var closest_pos := Vector2.ZERO

		for i in range(resolution + 1):
			var t: float = float(i) / float(resolution)
			var sample_pos := sample(t)
			var dist := pos.distance_squared_to(sample_pos)

			if dist < closest_dist:
				closest_dist = dist
				closest_t = t
				closest_pos = sample_pos

		return {
			"t": closest_t,
			"position": closest_pos,
			"distance": sqrt(closest_dist),
		}


	## Duplicates the path
	func duplicate() -> AnimationPath:
		var path := AnimationPath.new(type)
		path.closed = closed
		for point in points:
			path.points.append(point.duplicate())
		return path


	func _sample_segment(index: int, t: float) -> Vector2:
		var p0 := points[index]
		var p1_index: int = (index + 1) % points.size() if closed else mini(index + 1, points.size() - 1)
		var p1 := points[p1_index]

		match type:
			PathType.LINEAR:
				return p0.position.lerp(p1.position, t)

			PathType.QUADRATIC:
				# Use average of handles as control point
				var control := (p0.position + p0.handle_out + p1.position + p1.handle_in) * 0.5
				return _quadratic_bezier(p0.position, control, p1.position, t)

			PathType.CUBIC:
				return _cubic_bezier(
					p0.position,
					p0.position + p0.handle_out,
					p1.position + p1.handle_in,
					p1.position,
					t
				)

			PathType.CATMULL_ROM:
				var pm1_index: int = (index - 1 + points.size()) % points.size() if closed else maxi(index - 1, 0)
				var p2_index: int = (index + 2) % points.size() if closed else mini(index + 2, points.size() - 1)
				return _catmull_rom(
					points[pm1_index].position,
					p0.position,
					p1.position,
					points[p2_index].position,
					t
				)

			PathType.B_SPLINE:
				# Simplified B-Spline (cubic uniform)
				var pm1_index: int = (index - 1 + points.size()) % points.size() if closed else maxi(index - 1, 0)
				var p2_index: int = (index + 2) % points.size() if closed else mini(index + 2, points.size() - 1)
				return _b_spline(
					points[pm1_index].position,
					p0.position,
					p1.position,
					points[p2_index].position,
					t
				)

		return p0.position.lerp(p1.position, t)


	func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
		var u := 1.0 - t
		return u * u * p0 + 2.0 * u * t * p1 + t * t * p2


	func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
		var u := 1.0 - t
		var u2 := u * u
		var t2 := t * t
		return u2 * u * p0 + 3.0 * u2 * t * p1 + 3.0 * u * t2 * p2 + t2 * t * p3


	func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
		var t2 := t * t
		var t3 := t2 * t

		return 0.5 * (
			(2.0 * p1) +
			(-p0 + p2) * t +
			(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
			(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
		)


	func _b_spline(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
		var t2 := t * t
		var t3 := t2 * t

		var b0 := (1.0 - t) * (1.0 - t) * (1.0 - t) / 6.0
		var b1 := (3.0 * t3 - 6.0 * t2 + 4.0) / 6.0
		var b2 := (-3.0 * t3 + 3.0 * t2 + 3.0 * t + 1.0) / 6.0
		var b3 := t3 / 6.0

		return b0 * p0 + b1 * p1 + b2 * p2 + b3 * p3


	func _calculate_length() -> void:
		_cached_length = 0.0
		_segment_lengths.clear()

		if points.size() < 2:
			return

		var num_segments: int = points.size() - 1 if not closed else points.size()
		var samples_per_segment: int = 20

		for i in range(num_segments):
			var segment_length: float = 0.0
			var prev_pos := _sample_segment(i, 0.0)

			for j in range(1, samples_per_segment + 1):
				var t: float = float(j) / float(samples_per_segment)
				var pos := _sample_segment(i, t)
				segment_length += prev_pos.distance_to(pos)
				prev_pos = pos

			_segment_lengths.append(segment_length)
			_cached_length += segment_length


	func _ensure_arc_length_lut() -> void:
		if not _arc_length_lut.is_empty():
			return

		if _cached_length < 0.0:
			_calculate_length()

		_arc_length_lut.clear()
		_arc_length_lut.append(0.0)

		var cumulative: float = 0.0
		var prev_pos := sample(0.0)

		for i in range(1, _lut_resolution + 1):
			var t: float = float(i) / float(_lut_resolution)
			var pos := sample(t)
			cumulative += prev_pos.distance_to(pos)
			_arc_length_lut.append(cumulative)
			prev_pos = pos


	func _invalidate_cache() -> void:
		_cached_length = -1.0
		_segment_lengths.clear()
		_arc_length_lut.clear()


## A follower that animates along the path
class Follower extends RefCounted:
	## The node being animated
	var node: Node

	## Current progress (0-1)
	var progress: float = 0.0

	## Offset from path
	var offset: Vector2 = Vector2.ZERO

	## Progress offset for multiple followers on same path
	var progress_offset: float = 0.0

	## Whether to use arc-length parameterization
	var use_arc_length: bool = true

	## Orientation mode
	var orientation: OrientationMode = OrientationMode.NONE

	## Rotation offset
	var rotation_offset: float = 0.0

	## Custom rotation (when using CUSTOM orientation)
	var custom_rotation: float = 0.0

	## Speed multiplier
	var speed_scale: float = 1.0

	## Active state
	var active: bool = true


	func _init(p_node: Node = null) -> void:
		node = p_node


## Path deformation data
class PathDeformation extends RefCounted:
	var target_path: AnimationPath
	var blend_factor: float = 0.0
	var duration: float = 1.0


# endregion


# region - State

## The path being followed
var path: AnimationPath

## All followers
var followers: Array[Follower] = []

## Deformation state
var _deformation: PathDeformation = null

## Loop mode
var loop_mode: LoopMode = LoopMode.NONE

## Speed mode (easing along path)
var speed_mode: SpeedMode = SpeedMode.CONSTANT

## Custom speed curve (when using CUSTOM speed mode)
var speed_curve: Callable

## Playback state
var _is_playing: bool = false
var _current_time: float = 0.0
var _total_duration: float = 1.0
var _playing_forward: bool = true
var _loop_count: int = 0

## Active tween
var _tween: Tween

# endregion


# region - Initialization

func _init(node: Node = null, p_path: AnimationPath = null) -> void:
	if p_path:
		path = p_path
	else:
		path = AnimationPath.new()

	if node:
		add_follower(node)


## Sets the path
func set_path(p_path: AnimationPath) -> void:
	path = p_path


## Gets the path
func get_path() -> AnimationPath:
	return path

# endregion


# region - Follower Management

## Adds a follower node
func add_follower(
	node: Node,
	progress_offset: float = 0.0,
	orientation: OrientationMode = OrientationMode.FACE_FORWARD
) -> Follower:
	var follower := Follower.new(node)
	follower.progress_offset = progress_offset
	follower.orientation = orientation
	followers.append(follower)
	return follower


## Removes a follower
func remove_follower(node: Node) -> void:
	for i in range(followers.size() - 1, -1, -1):
		if followers[i].node == node:
			followers.remove_at(i)


## Gets a follower by node
func get_follower(node: Node) -> Follower:
	for follower in followers:
		if follower.node == node:
			return follower
	return null


## Clears all followers
func clear_followers() -> void:
	followers.clear()


## Gets follower count
func get_follower_count() -> int:
	return followers.size()

# endregion


# region - Playback Control

## Starts following the path
func follow(duration: float = 1.0, from_progress: float = 0.0) -> void:
	if followers.is_empty() or path.points.size() < 2:
		return

	_total_duration = duration
	_current_time = from_progress * duration
	_playing_forward = true
	_is_playing = true
	_loop_count = 0

	started.emit()

	# Create tween for animation
	if _tween and _tween.is_valid():
		_tween.kill()

	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		_tween = tree.create_tween()
		_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

		_tween.tween_method(
			_update_progress,
			from_progress,
			1.0,
			duration * (1.0 - from_progress)
		)

		_tween.finished.connect(_on_tween_finished)


## Stops following
func stop() -> void:
	_is_playing = false
	if _tween and _tween.is_valid():
		_tween.kill()


## Pauses following
func pause() -> void:
	if _tween and _tween.is_valid():
		_tween.pause()


## Resumes following
func resume() -> void:
	if _tween and _tween.is_valid():
		_tween.play()


## Seeks to a specific progress
func seek(progress: float) -> void:
	_update_progress(clampf(progress, 0.0, 1.0))


## Sets loop mode
func set_loop_mode(mode: LoopMode) -> void:
	loop_mode = mode


## Sets speed mode
func set_speed_mode(mode: SpeedMode, curve: Callable = Callable()) -> void:
	speed_mode = mode
	speed_curve = curve


## Checks if currently following
func is_following() -> bool:
	return _is_playing


## Gets current progress
func get_progress() -> float:
	if not followers.is_empty():
		return followers[0].progress
	return 0.0

# endregion


# region - Path Building

## Adds a point to the path
func add_point(
	position: Vector2,
	handle_in: Vector2 = Vector2.ZERO,
	handle_out: Vector2 = Vector2.ZERO
) -> PathPoint:
	return path.add_point(position, handle_in, handle_out)


## Creates a circular path
func create_circle(center: Vector2, radius: float, segments: int = 8) -> void:
	path.clear()
	path.type = PathType.CUBIC
	path.closed = true

	var handle_length: float = radius * 0.5522847498  # Magic number for circular bezier

	for i in range(segments):
		var angle: float = float(i) / float(segments) * TAU
		var pos := center + Vector2(cos(angle), sin(angle)) * radius

		var tangent := Vector2(-sin(angle), cos(angle))
		var handle := tangent * handle_length

		path.add_point(pos, -handle, handle)


## Creates a spiral path
func create_spiral(
	center: Vector2,
	start_radius: float,
	end_radius: float,
	turns: float = 2.0,
	segments_per_turn: int = 16
) -> void:
	path.clear()
	path.type = PathType.CUBIC

	var total_segments: int = int(turns * float(segments_per_turn))

	for i in range(total_segments + 1):
		var t: float = float(i) / float(total_segments)
		var angle: float = t * turns * TAU
		var radius: float = lerpf(start_radius, end_radius, t)

		var pos := center + Vector2(cos(angle), sin(angle)) * radius

		var tangent := Vector2(-sin(angle), cos(angle))
		var handle_length: float = radius * 0.3

		path.add_point(pos, -tangent * handle_length, tangent * handle_length)


## Creates a figure-8 path
func create_figure_eight(center: Vector2, width: float, height: float, segments: int = 16) -> void:
	path.clear()
	path.type = PathType.CUBIC
	path.closed = true

	for i in range(segments):
		var t: float = float(i) / float(segments) * TAU
		var x: float = sin(t) * width * 0.5
		var y: float = sin(2.0 * t) * height * 0.25

		var pos := center + Vector2(x, y)

		# Calculate tangent
		var dx := cos(t) * width * 0.5
		var dy := cos(2.0 * t) * height * 0.5
		var tangent := Vector2(dx, dy).normalized() * 20.0

		path.add_point(pos, -tangent, tangent)


## Creates a wave path
func create_wave(
	start: Vector2,
	end: Vector2,
	amplitude: float,
	wavelength: float
) -> void:
	path.clear()
	path.type = PathType.CUBIC

	var length: float = start.distance_to(end)
	var direction := (end - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)

	var num_waves: int = int(length / wavelength)
	var segments_per_wave: int = 4
	var total_segments: int = num_waves * segments_per_wave

	for i in range(total_segments + 1):
		var t: float = float(i) / float(total_segments)
		var wave_pos: float = sin(t * TAU * float(num_waves))

		var pos := start.lerp(end, t) + perpendicular * wave_pos * amplitude

		var handle_length: float = wavelength * 0.1
		var handle := direction * handle_length

		path.add_point(pos, -handle, handle)

# endregion


# region - Path Deformation

## Starts morphing to another path
func morph_to(target: AnimationPath, duration: float = 1.0) -> void:
	if path.points.size() != target.points.size():
		push_warning("PathFollower: Paths must have same point count for morphing")
		return

	_deformation = PathDeformation.new()
	_deformation.target_path = target
	_deformation.duration = duration
	_deformation.blend_factor = 0.0

	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var tween := tree.create_tween()
		tween.tween_method(_update_morph, 0.0, 1.0, duration)
		tween.finished.connect(_on_morph_complete)


func _update_morph(blend: float) -> void:
	if not _deformation:
		return

	_deformation.blend_factor = blend

	for i in range(path.points.size()):
		var source := path.points[i]
		var target := _deformation.target_path.points[i]

		source.position = source.position.lerp(target.position, blend)
		source.handle_in = source.handle_in.lerp(target.handle_in, blend)
		source.handle_out = source.handle_out.lerp(target.handle_out, blend)

	path._invalidate_cache()


func _on_morph_complete() -> void:
	_deformation = null

# endregion


# region - Internal

func _update_progress(raw_progress: float) -> void:
	# Apply speed curve
	var adjusted_progress := _apply_speed_curve(raw_progress)

	for follower in followers:
		if not follower.active:
			continue

		# Calculate follower's actual progress with offset
		var follower_progress := fmod(adjusted_progress + follower.progress_offset, 1.0)
		if follower_progress < 0.0:
			follower_progress += 1.0

		follower.progress = follower_progress

		# Get position and direction from path
		var position: Vector2
		var direction: Vector2

		if follower.use_arc_length:
			position = path.sample_arc_length(follower_progress)
			direction = path.sample_tangent_arc_length(follower_progress)
		else:
			position = path.sample(follower_progress)
			direction = path.sample_tangent(follower_progress)

		# Apply offset
		position += follower.offset

		# Apply to node
		_apply_to_follower(follower, position, direction)

		progress_updated.emit(follower_progress, position, direction)

	# Check for waypoints
	_check_waypoints(raw_progress)


func _apply_speed_curve(t: float) -> float:
	match speed_mode:
		SpeedMode.CONSTANT:
			return t
		SpeedMode.EASE_IN:
			return t * t
		SpeedMode.EASE_OUT:
			return 1.0 - (1.0 - t) * (1.0 - t)
		SpeedMode.EASE_IN_OUT:
			if t < 0.5:
				return 2.0 * t * t
			else:
				return 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
		SpeedMode.CUSTOM:
			if speed_curve.is_valid():
				return speed_curve.call(t)
			return t

	return t


func _apply_to_follower(follower: Follower, position: Vector2, direction: Vector2) -> void:
	if not is_instance_valid(follower.node):
		return

	var rotation: float = 0.0

	match follower.orientation:
		OrientationMode.NONE:
			rotation = 0.0
		OrientationMode.FACE_FORWARD:
			rotation = atan2(direction.y, direction.x) + follower.rotation_offset
		OrientationMode.FACE_BACKWARD:
			rotation = atan2(-direction.y, -direction.x) + follower.rotation_offset
		OrientationMode.CUSTOM:
			rotation = follower.custom_rotation
		OrientationMode.CONSTANT:
			rotation = follower.rotation_offset

	if follower.node is Control:
		var ctrl := follower.node as Control
		ctrl.position = position - ctrl.size / 2.0
		ctrl.rotation = rotation
	elif follower.node is Node2D:
		var n2d := follower.node as Node2D
		n2d.position = position
		n2d.rotation = rotation


func _check_waypoints(progress: float) -> void:
	if path.points.is_empty():
		return

	var segment_count: int = path.points.size() - 1 if not path.closed else path.points.size()
	var current_segment: int = int(progress * float(segment_count))

	# Emit waypoint signal for each point passed
	waypoint_reached.emit(current_segment, path.points[current_segment].position)


func _on_tween_finished() -> void:
	_loop_count += 1
	loop_completed.emit(_loop_count)

	match loop_mode:
		LoopMode.NONE:
			_is_playing = false
			completed.emit()

		LoopMode.LOOP:
			follow(_total_duration)

		LoopMode.PING_PONG:
			_playing_forward = not _playing_forward
			if _playing_forward:
				follow(_total_duration)
			else:
				_reverse_follow()

		LoopMode.CLOSED:
			follow(_total_duration)


func _reverse_follow() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		_tween = tree.create_tween()

		_tween.tween_method(
			_update_progress,
			1.0,
			0.0,
			_total_duration
		)

		_tween.finished.connect(_on_tween_finished)

# endregion


# region - Static Builders

## Creates a path follower with a simple linear path
static func create_linear(node: Node, start: Vector2, end: Vector2) -> PathFollower:
	var follower := PathFollower.new()
	follower.path.type = PathType.LINEAR
	follower.path.add_point(start)
	follower.path.add_point(end)
	follower.add_follower(node)
	return follower


## Creates a path follower with a smooth curve
static func create_curve(
	node: Node,
	start: Vector2,
	control1: Vector2,
	control2: Vector2,
	end: Vector2
) -> PathFollower:
	var follower := PathFollower.new()
	follower.path.type = PathType.CUBIC

	var p1 := follower.path.add_point(start)
	p1.handle_out = (control1 - start)

	var p2 := follower.path.add_point(end)
	p2.handle_in = (control2 - end)

	follower.add_follower(node)
	return follower


## Creates a circular path follower
static func create_circular(node: Node, center: Vector2, radius: float) -> PathFollower:
	var follower := PathFollower.new()
	follower.create_circle(center, radius)
	follower.add_follower(node)
	follower.set_loop_mode(LoopMode.LOOP)
	return follower

# endregion
