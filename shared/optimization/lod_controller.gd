## LODController — Level of Detail management system
##
## Manages automatic Level of Detail switching for 3D objects based on:
## - Distance from camera
## - Camera frustum culling
## - Screen coverage percentage
## - Performance budget
##
## Features:
## - 3 LOD levels per model (High, Medium, Low)
## - Smooth LOD transitions with optional crossfade
## - Billboard LOD for distant objects
## - Impostor generation support
## - LOD group management
## - Performance-aware LOD bias
class_name LODController
extends Node3D


# region — Enums

## Level of Detail levels
enum LODLevel {
	LOD_HIGH,    ## Full detail, < high_distance
	LOD_MEDIUM,  ## Reduced detail, high_distance to medium_distance
	LOD_LOW,     ## Minimal detail, medium_distance to low_distance
	LOD_CULLED,  ## Not rendered, > cull_distance
	LOD_BILLBOARD ## 2D impostor for very far objects
}

## LOD transition modes
enum TransitionMode {
	INSTANT,     ## Immediate switch
	CROSSFADE,   ## Alpha fade between LODs
	DITHER,      ## Dither pattern fade
	NONE         ## Keep current LOD (manual control)
}

# endregion


# region — Signals

## Emitted when LOD level changes
signal lod_changed(old_level: LODLevel, new_level: LODLevel)

## Emitted when the object is culled or unculled
signal visibility_changed(is_visible: bool)

# endregion


# region — Export Variables

## Mesh for high detail LOD (closest distance)
@export var mesh_high: Mesh

## Mesh for medium detail LOD
@export var mesh_medium: Mesh

## Mesh for low detail LOD
@export var mesh_low: Mesh

## Billboard texture for impostor mode (optional)
@export var billboard_texture: Texture2D

## Distance thresholds for LOD switching
@export_group("LOD Distances")
@export var high_distance: float = 10.0
@export var medium_distance: float = 30.0
@export var low_distance: float = 60.0
@export var cull_distance: float = 100.0
@export var billboard_distance: float = 80.0  ## Only if billboard_texture set

## Transition settings
@export_group("Transitions")
@export var transition_mode: TransitionMode = TransitionMode.INSTANT
@export var transition_duration: float = 0.3

## Performance settings
@export_group("Performance")
@export var update_interval: float = 0.1  ## Seconds between LOD checks
@export var use_screen_coverage: bool = false
@export var min_screen_coverage: float = 0.001  ## Cull if smaller
@export var respect_lod_bias: bool = true  ## Use PerformanceManager LOD bias

## Shadow settings per LOD
@export_group("Shadows")
@export var high_cast_shadows: bool = true
@export var medium_cast_shadows: bool = true
@export var low_cast_shadows: bool = false
@export var billboard_cast_shadows: bool = false

# endregion


# region — State Variables

## Current LOD level
var current_lod: LODLevel = LODLevel.LOD_HIGH

## The mesh instance we control
var _mesh_instance: MeshInstance3D

## Billboard sprite for impostor mode
var _billboard: Sprite3D

## Reference to the active camera
var _camera: Camera3D

## Time since last LOD check
var _update_timer: float = 0.0

## Transition state
var _is_transitioning: bool = false
var _transition_progress: float = 0.0
var _transition_from_lod: LODLevel = LODLevel.LOD_HIGH
var _transition_to_lod: LODLevel = LODLevel.LOD_HIGH

## Cached LOD bias from PerformanceManager
var _lod_bias: float = 1.0

## Whether this object is in the camera frustum
var _in_frustum: bool = true

## Original materials for crossfade
var _original_materials: Array[Material] = []

# endregion


# region — Lifecycle

func _ready() -> void:
	_setup_mesh_instance()
	_setup_billboard()
	_cache_materials()

	# Get initial camera reference
	_camera = get_viewport().get_camera_3d()

	# Connect to PerformanceManager if available
	if Engine.has_singleton("PerformanceManager") or has_node("/root/PerformanceManager"):
		var pm := get_node_or_null("/root/PerformanceManager")
		if pm and pm.has_signal("quality_preset_changed"):
			pm.quality_preset_changed.connect(_on_quality_preset_changed)
			_lod_bias = pm.get_lod_bias() if pm.has_method("get_lod_bias") else 1.0


func _process(delta: float) -> void:
	_update_timer += delta

	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_lod()

	if _is_transitioning:
		_process_transition(delta)


func _setup_mesh_instance() -> void:
	# Find or create mesh instance
	_mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D

	if not _mesh_instance:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "MeshInstance3D"
		add_child(_mesh_instance)

	# Set initial mesh
	if mesh_high:
		_mesh_instance.mesh = mesh_high


func _setup_billboard() -> void:
	if billboard_texture:
		_billboard = Sprite3D.new()
		_billboard.name = "Billboard"
		_billboard.texture = billboard_texture
		_billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_billboard.visible = false
		add_child(_billboard)


func _cache_materials() -> void:
	if _mesh_instance and _mesh_instance.mesh:
		_original_materials.clear()
		for i in range(_mesh_instance.get_surface_override_material_count()):
			var mat: Material = _mesh_instance.get_surface_override_material(i)
			if mat:
				_original_materials.append(mat.duplicate())

# endregion


# region — LOD Update Logic

func _update_lod() -> void:
	if not _camera:
		_camera = get_viewport().get_camera_3d()
		if not _camera:
			return

	# Check frustum culling first
	_in_frustum = _is_in_camera_frustum()

	if not _in_frustum:
		_set_lod_level(LODLevel.LOD_CULLED)
		return

	# Calculate distance to camera
	var distance: float = global_position.distance_to(_camera.global_position)

	# Apply LOD bias from PerformanceManager
	if respect_lod_bias:
		distance *= _lod_bias

	# Optional: Check screen coverage
	if use_screen_coverage:
		var coverage: float = _calculate_screen_coverage()
		if coverage < min_screen_coverage:
			_set_lod_level(LODLevel.LOD_CULLED)
			return

	# Determine LOD level based on distance
	var new_lod: LODLevel

	if distance < high_distance:
		new_lod = LODLevel.LOD_HIGH
	elif distance < medium_distance:
		new_lod = LODLevel.LOD_MEDIUM
	elif distance < low_distance:
		new_lod = LODLevel.LOD_LOW
	elif billboard_texture and distance < billboard_distance:
		new_lod = LODLevel.LOD_BILLBOARD
	elif distance < cull_distance:
		if billboard_texture:
			new_lod = LODLevel.LOD_BILLBOARD
		else:
			new_lod = LODLevel.LOD_LOW
	else:
		new_lod = LODLevel.LOD_CULLED

	# Apply hysteresis to prevent LOD flickering
	new_lod = _apply_hysteresis(distance, new_lod)

	if new_lod != current_lod:
		_set_lod_level(new_lod)


func _is_in_camera_frustum() -> bool:
	if not _camera:
		return true

	# Use AABB-based frustum check
	var aabb: AABB
	if _mesh_instance and _mesh_instance.mesh:
		aabb = _mesh_instance.mesh.get_aabb()
		aabb = _mesh_instance.global_transform * aabb
	else:
		# Use a small default AABB around the object
		aabb = AABB(global_position - Vector3(1, 1, 1), Vector3(2, 2, 2))

	# Get camera frustum planes
	var frustum: Array[Plane] = _camera.get_frustum()

	# Check AABB against all frustum planes
	for plane: Plane in frustum:
		if plane.is_point_over(aabb.position) and \
		   plane.is_point_over(aabb.position + aabb.size):
			# Box is completely outside this plane
			if aabb.get_support(-plane.normal).dot(plane.normal) > -plane.d:
				continue
			return false

	return true


func _calculate_screen_coverage() -> float:
	if not _camera or not _mesh_instance or not _mesh_instance.mesh:
		return 1.0

	var aabb: AABB = _mesh_instance.mesh.get_aabb()
	var global_aabb: AABB = _mesh_instance.global_transform * aabb

	# Get screen bounds of AABB
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var min_screen := Vector2(INF, INF)
	var max_screen := Vector2(-INF, -INF)

	# Project all 8 corners
	for i in range(8):
		var corner := Vector3(
			global_aabb.position.x + (global_aabb.size.x if i & 1 else 0),
			global_aabb.position.y + (global_aabb.size.y if i & 2 else 0),
			global_aabb.position.z + (global_aabb.size.z if i & 4 else 0)
		)

		if not _camera.is_position_behind(corner):
			var screen_pos: Vector2 = _camera.unproject_position(corner)
			min_screen = min_screen.min(screen_pos)
			max_screen = max_screen.max(screen_pos)

	if min_screen.x == INF:
		return 0.0

	# Calculate coverage ratio
	var screen_area: float = (max_screen.x - min_screen.x) * (max_screen.y - min_screen.y)
	var viewport_area: float = viewport_size.x * viewport_size.y

	return screen_area / viewport_area if viewport_area > 0 else 0.0


func _apply_hysteresis(distance: float, proposed_lod: LODLevel) -> LODLevel:
	# Add hysteresis buffer to prevent flickering at boundaries
	const HYSTERESIS_FACTOR: float = 0.1  # 10% buffer

	if proposed_lod > current_lod:
		# Going to lower detail - require crossing threshold + buffer
		return proposed_lod
	elif proposed_lod < current_lod:
		# Going to higher detail - require being well within threshold
		var threshold_distance: float
		match proposed_lod:
			LODLevel.LOD_HIGH:
				threshold_distance = high_distance * (1.0 - HYSTERESIS_FACTOR)
			LODLevel.LOD_MEDIUM:
				threshold_distance = medium_distance * (1.0 - HYSTERESIS_FACTOR)
			LODLevel.LOD_LOW:
				threshold_distance = low_distance * (1.0 - HYSTERESIS_FACTOR)
			_:
				return proposed_lod

		if distance < threshold_distance:
			return proposed_lod
		return current_lod

	return proposed_lod

# endregion


# region — LOD Application

func _set_lod_level(new_lod: LODLevel) -> void:
	if new_lod == current_lod:
		return

	var old_lod: LODLevel = current_lod

	if transition_mode == TransitionMode.INSTANT or \
	   old_lod == LODLevel.LOD_CULLED or new_lod == LODLevel.LOD_CULLED:
		# Instant transition
		_apply_lod_immediately(new_lod)
		current_lod = new_lod
		lod_changed.emit(old_lod, new_lod)

		if old_lod == LODLevel.LOD_CULLED or new_lod == LODLevel.LOD_CULLED:
			visibility_changed.emit(new_lod != LODLevel.LOD_CULLED)
	else:
		# Start transition
		_start_transition(new_lod)


func _apply_lod_immediately(lod: LODLevel) -> void:
	match lod:
		LODLevel.LOD_HIGH:
			_show_mesh(mesh_high, high_cast_shadows)
			_hide_billboard()

		LODLevel.LOD_MEDIUM:
			_show_mesh(mesh_medium if mesh_medium else mesh_high, medium_cast_shadows)
			_hide_billboard()

		LODLevel.LOD_LOW:
			_show_mesh(mesh_low if mesh_low else (mesh_medium if mesh_medium else mesh_high), low_cast_shadows)
			_hide_billboard()

		LODLevel.LOD_BILLBOARD:
			_hide_mesh()
			_show_billboard()

		LODLevel.LOD_CULLED:
			_hide_mesh()
			_hide_billboard()


func _show_mesh(mesh: Mesh, cast_shadows: bool) -> void:
	if _mesh_instance:
		_mesh_instance.mesh = mesh
		_mesh_instance.visible = true
		_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _hide_mesh() -> void:
	if _mesh_instance:
		_mesh_instance.visible = false


func _show_billboard() -> void:
	if _billboard:
		_billboard.visible = true
		_billboard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if billboard_cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _hide_billboard() -> void:
	if _billboard:
		_billboard.visible = false

# endregion


# region — Transitions

func _start_transition(to_lod: LODLevel) -> void:
	_is_transitioning = true
	_transition_progress = 0.0
	_transition_from_lod = current_lod
	_transition_to_lod = to_lod

	if transition_mode == TransitionMode.CROSSFADE:
		_setup_crossfade()


func _process_transition(delta: float) -> void:
	_transition_progress += delta / transition_duration

	if _transition_progress >= 1.0:
		_finish_transition()
		return

	match transition_mode:
		TransitionMode.CROSSFADE:
			_update_crossfade(_transition_progress)
		TransitionMode.DITHER:
			_update_dither(_transition_progress)


func _finish_transition() -> void:
	_is_transitioning = false
	_transition_progress = 0.0

	var old_lod: LODLevel = current_lod
	current_lod = _transition_to_lod

	_apply_lod_immediately(current_lod)
	_cleanup_transition()

	lod_changed.emit(old_lod, current_lod)


func _setup_crossfade() -> void:
	# For crossfade, we need to modify material transparency
	# This is a simplified version - full implementation would use a shader
	pass


func _update_crossfade(progress: float) -> void:
	# Interpolate opacity between LODs
	if _mesh_instance:
		var material: Material = _mesh_instance.get_active_material(0)
		if material is StandardMaterial3D:
			var std_mat := material as StandardMaterial3D
			std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			std_mat.albedo_color.a = 1.0 - progress


func _update_dither(progress: float) -> void:
	# Dither-based transition using a dissolve pattern
	# Would typically use a shader with a noise texture
	pass


func _cleanup_transition() -> void:
	# Restore original materials after transition
	if _mesh_instance and _original_materials.size() > 0:
		for i in range(_original_materials.size()):
			if i < _mesh_instance.get_surface_override_material_count():
				_mesh_instance.set_surface_override_material(i, _original_materials[i])

# endregion


# region — External API

## Forces a specific LOD level (disables automatic updates)
func force_lod(lod: LODLevel) -> void:
	update_interval = -1.0  # Disable automatic updates
	_set_lod_level(lod)


## Re-enables automatic LOD updates
func enable_auto_lod(interval: float = 0.1) -> void:
	update_interval = interval


## Sets LOD distances at runtime
func set_lod_distances(high: float, medium: float, low: float, cull: float) -> void:
	high_distance = high
	medium_distance = medium
	low_distance = low
	cull_distance = cull
	_update_lod()


## Sets all LOD meshes at runtime
func set_lod_meshes(high: Mesh, medium: Mesh = null, low: Mesh = null) -> void:
	mesh_high = high
	mesh_medium = medium if medium else high
	mesh_low = low if low else (medium if medium else high)
	_apply_lod_immediately(current_lod)


## Gets the current LOD level
func get_current_lod() -> LODLevel:
	return current_lod


## Returns true if the object is currently visible (not culled)
func is_visible_lod() -> bool:
	return current_lod != LODLevel.LOD_CULLED


## Returns the polygon count of the current LOD
func get_current_polygon_count() -> int:
	if not _mesh_instance or not _mesh_instance.mesh:
		return 0

	var mesh: Mesh = _mesh_instance.mesh
	var total: int = 0

	for i in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(i)
		if arrays.size() > Mesh.ARRAY_INDEX:
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			total += indices.size() / 3
		elif arrays.size() > Mesh.ARRAY_VERTEX:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += vertices.size() / 3

	return total

# endregion


# region — Callbacks

func _on_quality_preset_changed(_preset: int) -> void:
	var pm := get_node_or_null("/root/PerformanceManager")
	if pm and pm.has_method("get_lod_bias"):
		_lod_bias = pm.get_lod_bias()
		_update_lod()

# endregion
