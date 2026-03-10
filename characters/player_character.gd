## Main player controller for BattleZone Party.
## Shared across all mini-games. Handles movement, combat interface,
## input from touch/keyboard, and multiplayer synchronization.
class_name PlayerCharacter
extends CharacterBody3D

#region Signals
## Emitted when health changes. Provides current and max values.
signal health_changed(new_health: float, max_health: float)
## Emitted when the player dies. Provides the peer_id of the dead player.
signal died(peer_id: int)
## Emitted after a respawn. Provides the peer_id of the respawned player.
signal respawned(peer_id: int)
## Emitted when the player triggers their primary action (shoot, grab, etc.).
signal action_triggered()
#endregion

#region Exports
@export var speed: float = 8.0
@export var sprint_speed: float = 12.0
@export var jump_force: float = 8.0
@export var gravity_multiplier: float = 1.0
@export var rotation_speed: float = 10.0

## Cel-shading configuration
@export_group("Cel Shading")
@export var use_cel_shading: bool = true
@export var cel_quality: CelShadedMaterials.CelQuality = CelShadedMaterials.CelQuality.MEDIUM
@export var show_outline: bool = true
@export var base_body_color: Color = Color(0.6, 0.6, 0.6, 1.0)
@export var base_head_color: Color = Color(0.7, 0.7, 0.7, 1.0)
#endregion

#region State
var health: float = 100.0
var max_health: float = 100.0
var is_alive: bool = true
var peer_id: int = 0
var player_name: String = ""

## Movement input vector — set by touch joystick or keyboard.
var input_vector: Vector2 = Vector2.ZERO
## Look/aim direction — set by right joystick or mouse.
var look_direction: Vector2 = Vector2.ZERO
#endregion

#region Internal
var _coyote_timer: float = 0.0
const COYOTE_TIME: float = 0.15
var _was_on_floor: bool = false
var _jump_requested: bool = false
var _gravity: float = 0.0

# Node references (populated in _ready)
var _body_mesh: MeshInstance3D
var _head_mesh: MeshInstance3D
var _name_label: Label3D
var _camera_mount: Node3D
var _camera: Camera3D

# Outline mesh instances for cel-shading
var _body_outline: MeshInstance3D
var _head_outline: MeshInstance3D

# Current team color (for cel-shading)
var _current_team_color: Color = Color(-1, -1, -1)
#endregion


func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

	# Cache node references from the scene tree.
	_body_mesh = get_node_or_null("BodyMesh") as MeshInstance3D
	_head_mesh = get_node_or_null("HeadMesh") as MeshInstance3D
	_name_label = get_node_or_null("NameLabel") as Label3D
	_camera_mount = get_node_or_null("CameraMount") as Node3D
	_camera = get_node_or_null("CameraMount/Camera3D") as Camera3D

	# Only the local player owns its camera.
	if _camera:
		_camera.current = _is_local_player()

	# Initialize cel-shading system
	if use_cel_shading:
		_setup_cel_shading()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_apply_gravity(delta)
	_handle_coyote_time(delta)

	if _is_local_player():
		_gather_keyboard_input()
		_process_movement(delta)
		_process_jump()

	move_and_slide()


#region Movement ---------------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta


func _handle_coyote_time(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
		_was_on_floor = true
	else:
		if _was_on_floor:
			_coyote_timer -= delta
			if _coyote_timer <= 0.0:
				_was_on_floor = false
				_coyote_timer = 0.0


func _gather_keyboard_input() -> void:
	# Keyboard / gamepad fallback — touch controls override via set_movement_input.
	var kb := Vector2.ZERO
	kb.x = Input.get_axis("move_left", "move_right")
	kb.y = Input.get_axis("move_forward", "move_back")
	if kb.length_squared() > 0.01:
		input_vector = kb.normalized()


func _process_movement(delta: float) -> void:
	if input_vector.length_squared() < 0.01:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 8.0)
		return

	# Build direction relative to camera (third-person).
	var cam_basis: Basis = _get_camera_basis()
	var forward: Vector3 = -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var direction: Vector3 = (right * input_vector.x + forward * -input_vector.y).normalized()

	var is_sprinting: bool = Input.is_action_pressed("sprint") if _is_local_player() else false
	var current_speed: float = sprint_speed if is_sprinting else speed

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	# Smooth rotation toward movement direction.
	if direction.length_squared() > 0.01:
		var target_angle: float = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)


func _process_jump() -> void:
	if _jump_requested:
		_jump_requested = false
		if is_on_floor() or _coyote_timer > 0.0:
			velocity.y = jump_force
			_coyote_timer = 0.0
			_was_on_floor = false


func _get_camera_basis() -> Basis:
	if _camera:
		return _camera.global_transform.basis
	# Fallback: use global identity.
	return Basis.IDENTITY

#endregion

#region Combat Interface -------------------------------------------------------

## Deal damage to this player. Authority-only RPC.
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float, from_peer: int) -> void:
	if not is_multiplayer_authority():
		return
	if not is_alive:
		return
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		die()


## Heal the player, clamped to max_health.
func heal(amount: float) -> void:
	if not is_alive:
		return
	health = clampf(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)


## Kill the player immediately.
func die() -> void:
	is_alive = false
	died.emit(peer_id)


## Respawn at the given world position with full health.
func respawn(pos: Vector3) -> void:
	health = max_health
	is_alive = true
	global_position = pos
	velocity = Vector3.ZERO
	health_changed.emit(health, max_health)
	respawned.emit(peer_id)


## Apply an impulse-like knockback force to velocity.
func apply_knockback(force: Vector3) -> void:
	velocity += force

#endregion

#region Input from Touch Controls / External -----------------------------------

## Set normalized movement input (e.g. from virtual joystick).
func set_movement_input(vec: Vector2) -> void:
	input_vector = vec


## Set look/aim direction (e.g. from right joystick).
func set_look_input(vec: Vector2) -> void:
	look_direction = vec


## Request a jump on the next physics frame.
func trigger_jump() -> void:
	_jump_requested = true


## Fire the primary action for the current mini-game.
func trigger_action() -> void:
	action_triggered.emit()

#endregion

#region Setup / Visuals --------------------------------------------------------

## Configure multiplayer authority and peer_id.
func setup_for_authority(id: int) -> void:
	peer_id = id
	set_multiplayer_authority(id)
	if _camera:
		_camera.current = _is_local_player()


## Apply the primary body color to the mesh material.
func set_player_color(color: Color) -> void:
	_current_team_color = color

	if use_cel_shading:
		# Use cel-shaded materials with team color
		_apply_cel_shaded_color(color)
	else:
		# Fallback to standard materials
		if _body_mesh and _body_mesh.mesh:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			_body_mesh.material_override = mat
		if _head_mesh and _head_mesh.mesh:
			var head_mat := StandardMaterial3D.new()
			head_mat.albedo_color = color
			_head_mesh.material_override = head_mat


## Set the floating name label text.
func set_player_name_label(name: String) -> void:
	player_name = name
	if _name_label:
		_name_label.text = name

#endregion

#region Helpers ----------------------------------------------------------------

func _is_local_player() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true  # Single-player / editor preview.
	return peer_id == multiplayer.get_unique_id()

#endregion

#region Cel-Shading System -----------------------------------------------------

## Initialize the cel-shading system with outline meshes
func _setup_cel_shading() -> void:
	# Apply cel-shaded materials to body
	if _body_mesh and _body_mesh.mesh:
		var body_mat := CelShadedMaterials.create_cel_material_for_quality(
			base_body_color, cel_quality, "character"
		)
		_body_mesh.material_override = body_mat

		# Create outline mesh for body
		if show_outline:
			_body_outline = _create_outline_mesh(_body_mesh, "character")

	# Apply cel-shaded materials to head
	if _head_mesh and _head_mesh.mesh:
		var head_mat := CelShadedMaterials.create_cel_material_for_quality(
			base_head_color, cel_quality, "character"
		)
		_head_mesh.material_override = head_mat

		# Create outline mesh for head
		if show_outline:
			_head_outline = _create_outline_mesh(_head_mesh, "character")


## Create an outline mesh for the given source mesh
func _create_outline_mesh(source: MeshInstance3D, preset: String) -> MeshInstance3D:
	var outline := MeshInstance3D.new()
	outline.name = source.name + "_Outline"
	outline.mesh = source.mesh
	outline.transform = source.transform

	# Apply outline material
	var outline_mat := CelShadedMaterials.create_outline_material(preset)
	outline.material_override = outline_mat

	# Add as sibling (not child, to avoid transform issues)
	source.add_sibling(outline)

	return outline


## Apply cel-shaded color with team color support
func _apply_cel_shaded_color(team_color: Color) -> void:
	if _body_mesh:
		var body_mat := CelShadedMaterials.create_team_cel_material(
			base_body_color, team_color, 0.6
		)
		# Adjust for quality
		_adjust_material_quality(body_mat)
		_body_mesh.material_override = body_mat

		# Update outline with team tint
		if _body_outline:
			var outline_mat := CelShadedMaterials.create_team_outline_material(
				team_color, "character"
			)
			_body_outline.material_override = outline_mat

	if _head_mesh:
		var head_mat := CelShadedMaterials.create_team_cel_material(
			base_head_color, team_color, 0.5
		)
		_adjust_material_quality(head_mat)
		_head_mesh.material_override = head_mat

		# Update outline with team tint
		if _head_outline:
			var outline_mat := CelShadedMaterials.create_team_outline_material(
				team_color, "character"
			)
			_head_outline.material_override = outline_mat


## Adjust material settings based on quality level
func _adjust_material_quality(mat: ShaderMaterial) -> void:
	match cel_quality:
		CelShadedMaterials.CelQuality.LOW:
			mat.set_shader_parameter("cel_levels", 3)
			mat.set_shader_parameter("enable_rim_light", false)
			mat.set_shader_parameter("enable_specular", false)
		CelShadedMaterials.CelQuality.MEDIUM:
			mat.set_shader_parameter("cel_levels", 4)
			mat.set_shader_parameter("enable_rim_light", true)
			mat.set_shader_parameter("enable_specular", false)
		CelShadedMaterials.CelQuality.HIGH:
			mat.set_shader_parameter("cel_levels", 5)
			mat.set_shader_parameter("enable_rim_light", true)
			mat.set_shader_parameter("enable_specular", true)


## Toggle cel-shading on/off at runtime
func set_cel_shading_enabled(enabled: bool) -> void:
	use_cel_shading = enabled
	if enabled:
		_setup_cel_shading()
		if _current_team_color.r >= 0:
			_apply_cel_shaded_color(_current_team_color)
	else:
		# Remove outline meshes
		if _body_outline:
			_body_outline.queue_free()
			_body_outline = null
		if _head_outline:
			_head_outline.queue_free()
			_head_outline = null

		# Revert to standard materials
		if _current_team_color.r >= 0:
			if _body_mesh:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = _current_team_color
				_body_mesh.material_override = mat
			if _head_mesh:
				var head_mat := StandardMaterial3D.new()
				head_mat.albedo_color = _current_team_color
				_head_mesh.material_override = head_mat


## Toggle outline visibility
func set_outline_visible(visible: bool) -> void:
	show_outline = visible
	if _body_outline:
		_body_outline.visible = visible
	if _head_outline:
		_head_outline.visible = visible


## Set cel-shading quality at runtime
func set_cel_quality(quality: CelShadedMaterials.CelQuality) -> void:
	cel_quality = quality
	if use_cel_shading:
		_setup_cel_shading()
		if _current_team_color.r >= 0:
			_apply_cel_shaded_color(_current_team_color)


## Get the current outline material for body (for external modification)
func get_body_outline_material() -> ShaderMaterial:
	if _body_outline:
		return _body_outline.material_override as ShaderMaterial
	return null


## Get the current body material (for external modification)
func get_body_material() -> ShaderMaterial:
	if _body_mesh:
		return _body_mesh.material_override as ShaderMaterial
	return null

#endregion
