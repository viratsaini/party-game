## Ragdoll Physics System for BattleZone Party
##
## Provides satisfying, exaggerated ragdoll effects for player deaths and
## spectacular moments. Handles smooth transitions from animated to ragdoll,
## force application, recovery animations, and network synchronization.
##
## Performance target: <1ms per ragdoll
## Mobile-optimized: Reduced joint count for performance
class_name RagdollSystem
extends Node


#region Constants

## Ragdoll state enumeration
enum RagdollState {
	INACTIVE,       ## Character is animated normally
	TRANSITIONING,  ## Blending from animation to ragdoll
	ACTIVE,         ## Full ragdoll physics active
	RECOVERING,     ## Playing get-up animation
}

## Physics layer for ragdoll bodies
const RAGDOLL_COLLISION_LAYER: int = 8

## Exaggeration multipliers for fun physics
const FORCE_MULTIPLIER: float = 2.5          ## Make hits feel powerful
const EXPLOSION_FORCE_MULT: float = 4.0       ## Explosions are spectacular
const BOUNCE_MULTIPLIER: float = 1.8          ## Bouncy ragdolls
const ANGULAR_FORCE_MULT: float = 3.0         ## Spin more dramatically
const GRAVITY_SCALE: float = 0.7              ## Floatier falls

## Timing constants
const TRANSITION_DURATION: float = 0.15       ## Animation to ragdoll blend
const MIN_RAGDOLL_TIME: float = 0.5           ## Minimum ragdoll duration
const MAX_RAGDOLL_TIME: float = 8.0           ## Auto-despawn after this
const VELOCITY_SETTLE_THRESHOLD: float = 0.3  ## Consider settled when below
const RECOVERY_ANIM_DURATION: float = 0.8     ## Get-up animation length

## Network sync
const SYNC_INTERVAL: float = 0.1              ## Sync every 100ms
const SYNC_POSITION_THRESHOLD: float = 0.5    ## Only sync if moved this much

## Joint limits for cartoon physics (more flexible = more fun)
const JOINT_TWIST_LIMIT: float = 120.0        ## Degrees
const JOINT_SWING_LIMIT: float = 90.0         ## Degrees
const JOINT_DAMPING: float = 0.2              ## Low damping = more floppy

## Mobile optimization
const MOBILE_JOINT_COUNT: int = 6             ## Simplified skeleton for mobile
const DESKTOP_JOINT_COUNT: int = 12           ## Full skeleton for desktop

#endregion


#region Signals

## Emitted when ragdoll state changes
signal state_changed(new_state: RagdollState)

## Emitted when ragdoll has settled (stopped moving significantly)
signal ragdoll_settled()

## Emitted when recovery animation completes
signal recovery_complete()

## Emitted for network sync (server broadcasts ragdoll events)
signal sync_ragdoll_event(event_type: String, data: Dictionary)

#endregion


#region Exports

## Reference to the character this ragdoll controls
@export var character: CharacterBody3D

## Whether to use mobile-optimized physics
@export var use_mobile_optimization: bool = false

## Enable/disable recovery (get-up) animations
@export var allow_recovery: bool = true

## Enable cartoon-style dismemberment (gibs)
@export var enable_gibs: bool = false

## Maximum force that can be applied (prevents extreme velocities)
@export var max_force_magnitude: float = 100.0

## Whether this ragdoll is controlled by server (for multiplayer)
@export var server_authoritative: bool = true

#endregion


#region State Variables

## Current ragdoll state
var current_state: RagdollState = RagdollState.INACTIVE

## Time spent in current ragdoll state
var state_time: float = 0.0

## Reference to ragdoll skeleton (populated on init)
var ragdoll_skeleton: Node3D = null

## Dictionary of physics bones: bone_name -> RigidBody3D
var physics_bones: Dictionary = {}

## Dictionary of joints: joint_name -> Generic6DOFJoint3D
var joints: Dictionary = {}

## Root physics body (usually pelvis/hips)
var root_body: RigidBody3D = null

## Stored velocities for transition blending
var _stored_velocity: Vector3 = Vector3.ZERO
var _stored_angular: Vector3 = Vector3.ZERO

## Network sync timer
var _sync_timer: float = 0.0
var _last_synced_positions: Dictionary = {}

## Accumulated forces to apply (processed in physics frame)
var _pending_forces: Array[Dictionary] = []

## Impact info for feedback systems
var _last_impact_point: Vector3 = Vector3.ZERO
var _last_impact_force: Vector3 = Vector3.ZERO
var _last_impact_bone: String = ""

## Recovery state
var _recovery_tween: Tween = null

#endregion


#region Lifecycle

func _ready() -> void:
	# Auto-detect mobile platform
	if OS.has_feature("mobile"):
		use_mobile_optimization = true

	# Will be initialized when activate_ragdoll() is called
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if current_state == RagdollState.INACTIVE:
		return

	state_time += delta

	match current_state:
		RagdollState.TRANSITIONING:
			_process_transition(delta)
		RagdollState.ACTIVE:
			_process_active(delta)
		RagdollState.RECOVERING:
			_process_recovery(delta)

	# Process pending forces
	_apply_pending_forces()

	# Network sync (server only)
	if server_authoritative and _is_server():
		_process_network_sync(delta)

#endregion


#region Public API

## Activate ragdoll physics with an initial force
## @param force: World-space force vector to apply
## @param hit_point: World position where force originates
## @param hit_bone: Name of bone that was hit (optional)
func activate_ragdoll(force: Vector3 = Vector3.ZERO, hit_point: Vector3 = Vector3.ZERO, hit_bone: String = "root") -> void:
	if current_state != RagdollState.INACTIVE:
		# Already ragdolling, just add more force
		apply_force(force, hit_point, hit_bone)
		return

	# Store character state for blending
	if character:
		_stored_velocity = character.velocity

	# Initialize ragdoll skeleton if needed
	if not ragdoll_skeleton:
		_initialize_ragdoll()

	# Transition to ragdoll
	_set_state(RagdollState.TRANSITIONING)

	# Store impact info
	_last_impact_force = force
	_last_impact_point = hit_point
	_last_impact_bone = hit_bone

	# Queue initial force
	if force.length_squared() > 0.001:
		apply_force(force * FORCE_MULTIPLIER, hit_point, hit_bone)

	# Broadcast to network
	if server_authoritative and _is_server():
		_broadcast_ragdoll_activation(force, hit_point, hit_bone)

	set_physics_process(true)


## Apply force to the ragdoll
## @param force: World-space force to apply
## @param world_position: Position where force is applied
## @param bone_name: Specific bone to apply force to (or "root" for all)
func apply_force(force: Vector3, world_position: Vector3 = Vector3.ZERO, bone_name: String = "root") -> void:
	# Clamp force magnitude
	if force.length() > max_force_magnitude:
		force = force.normalized() * max_force_magnitude

	_pending_forces.append({
		"force": force,
		"position": world_position,
		"bone": bone_name,
	})


## Apply explosion force (radial, affects all bones)
## @param explosion_center: World position of explosion
## @param explosion_force: Base force magnitude
## @param explosion_radius: Radius of effect
func apply_explosion_force(explosion_center: Vector3, explosion_force: float, explosion_radius: float) -> void:
	if current_state == RagdollState.INACTIVE:
		# Auto-activate ragdoll on explosion
		activate_ragdoll()

	for bone_name: String in physics_bones:
		var bone: RigidBody3D = physics_bones[bone_name] as RigidBody3D
		if not bone:
			continue

		var direction: Vector3 = bone.global_position - explosion_center
		var distance: float = direction.length()

		if distance < explosion_radius:
			var falloff: float = 1.0 - (distance / explosion_radius)
			falloff = falloff * falloff  # Quadratic falloff

			var force_magnitude: float = explosion_force * falloff * EXPLOSION_FORCE_MULT
			var force_direction: Vector3 = direction.normalized()

			# Add upward bias for spectacular launches
			force_direction += Vector3.UP * 0.5
			force_direction = force_direction.normalized()

			_pending_forces.append({
				"force": force_direction * force_magnitude,
				"position": bone.global_position,
				"bone": bone_name,
			})


## Apply knockback force (directional, primarily affects root)
## @param direction: Knockback direction (normalized)
## @param magnitude: Force strength
func apply_knockback(direction: Vector3, magnitude: float) -> void:
	var knockback_force: Vector3 = direction.normalized() * magnitude * FORCE_MULTIPLIER

	# Add slight upward component
	knockback_force += Vector3.UP * magnitude * 0.3

	if current_state == RagdollState.INACTIVE:
		activate_ragdoll(knockback_force, Vector3.ZERO, "spine")
	else:
		apply_force(knockback_force, Vector3.ZERO, "spine")


## Deactivate ragdoll and return to animated state
## @param with_recovery: Whether to play get-up animation
func deactivate_ragdoll(with_recovery: bool = true) -> void:
	if current_state == RagdollState.INACTIVE:
		return

	if with_recovery and allow_recovery:
		_set_state(RagdollState.RECOVERING)
		_play_recovery_animation()
	else:
		_finalize_deactivation()


## Get the current world position of the ragdoll (root body)
func get_ragdoll_position() -> Vector3:
	if root_body:
		return root_body.global_position
	elif character:
		return character.global_position
	return Vector3.ZERO


## Get average velocity of all ragdoll bodies
func get_ragdoll_velocity() -> Vector3:
	if physics_bones.is_empty():
		return Vector3.ZERO

	var total_vel: Vector3 = Vector3.ZERO
	for bone_name: String in physics_bones:
		var bone: RigidBody3D = physics_bones[bone_name] as RigidBody3D
		if bone:
			total_vel += bone.linear_velocity

	return total_vel / physics_bones.size()


## Check if ragdoll has settled (stopped moving)
func is_settled() -> bool:
	if current_state != RagdollState.ACTIVE:
		return false

	return get_ragdoll_velocity().length() < VELOCITY_SETTLE_THRESHOLD


## Enable/disable gibs mode
func set_gibs_enabled(enabled: bool) -> void:
	enable_gibs = enabled


## Spawn gibs (cartoon dismemberment) - call after death
func spawn_gibs(hit_point: Vector3, hit_force: Vector3) -> void:
	if not enable_gibs:
		return

	# This would spawn cartoon body parts
	# Implementation depends on art assets
	_spawn_cartoon_gibs(hit_point, hit_force)

#endregion


#region Internal - Initialization

func _initialize_ragdoll() -> void:
	if not character:
		push_error("RagdollSystem: No character assigned!")
		return

	# Create ragdoll skeleton structure
	ragdoll_skeleton = Node3D.new()
	ragdoll_skeleton.name = "RagdollSkeleton"
	character.add_child(ragdoll_skeleton)

	# Build physics bones based on optimization level
	var bone_count: int = MOBILE_JOINT_COUNT if use_mobile_optimization else DESKTOP_JOINT_COUNT
	_create_physics_skeleton(bone_count)


func _create_physics_skeleton(bone_count: int) -> void:
	# Simplified ragdoll structure for party game characters
	# Using capsules for fast collision detection

	var bone_configs: Array[Dictionary] = []

	if bone_count >= 12:
		# Full skeleton (desktop)
		bone_configs = [
			{"name": "pelvis", "size": Vector3(0.3, 0.2, 0.2), "offset": Vector3(0, 0.5, 0), "mass": 2.0},
			{"name": "spine", "size": Vector3(0.25, 0.25, 0.15), "offset": Vector3(0, 0.75, 0), "mass": 1.5, "parent": "pelvis"},
			{"name": "chest", "size": Vector3(0.3, 0.25, 0.18), "offset": Vector3(0, 1.0, 0), "mass": 1.5, "parent": "spine"},
			{"name": "head", "size": Vector3(0.2, 0.25, 0.2), "offset": Vector3(0, 1.35, 0), "mass": 1.0, "parent": "chest"},
			{"name": "upper_arm_l", "size": Vector3(0.08, 0.25, 0.08), "offset": Vector3(-0.35, 1.0, 0), "mass": 0.5, "parent": "chest"},
			{"name": "lower_arm_l", "size": Vector3(0.06, 0.22, 0.06), "offset": Vector3(-0.55, 0.8, 0), "mass": 0.3, "parent": "upper_arm_l"},
			{"name": "upper_arm_r", "size": Vector3(0.08, 0.25, 0.08), "offset": Vector3(0.35, 1.0, 0), "mass": 0.5, "parent": "chest"},
			{"name": "lower_arm_r", "size": Vector3(0.06, 0.22, 0.06), "offset": Vector3(0.55, 0.8, 0), "mass": 0.3, "parent": "upper_arm_r"},
			{"name": "upper_leg_l", "size": Vector3(0.1, 0.35, 0.1), "offset": Vector3(-0.12, 0.25, 0), "mass": 0.8, "parent": "pelvis"},
			{"name": "lower_leg_l", "size": Vector3(0.08, 0.35, 0.08), "offset": Vector3(-0.12, -0.15, 0), "mass": 0.5, "parent": "upper_leg_l"},
			{"name": "upper_leg_r", "size": Vector3(0.1, 0.35, 0.1), "offset": Vector3(0.12, 0.25, 0), "mass": 0.8, "parent": "pelvis"},
			{"name": "lower_leg_r", "size": Vector3(0.08, 0.35, 0.08), "offset": Vector3(0.12, -0.15, 0), "mass": 0.5, "parent": "upper_leg_r"},
		]
	else:
		# Simplified skeleton (mobile)
		bone_configs = [
			{"name": "pelvis", "size": Vector3(0.35, 0.4, 0.25), "offset": Vector3(0, 0.6, 0), "mass": 3.0},
			{"name": "torso", "size": Vector3(0.35, 0.5, 0.2), "offset": Vector3(0, 1.1, 0), "mass": 2.5, "parent": "pelvis"},
			{"name": "head", "size": Vector3(0.25, 0.3, 0.25), "offset": Vector3(0, 1.5, 0), "mass": 1.0, "parent": "torso"},
			{"name": "arm_l", "size": Vector3(0.12, 0.5, 0.1), "offset": Vector3(-0.4, 0.9, 0), "mass": 0.8, "parent": "torso"},
			{"name": "arm_r", "size": Vector3(0.12, 0.5, 0.1), "offset": Vector3(0.4, 0.9, 0), "mass": 0.8, "parent": "torso"},
			{"name": "leg_l", "size": Vector3(0.12, 0.6, 0.1), "offset": Vector3(-0.15, 0.1, 0), "mass": 1.2, "parent": "pelvis"},
			{"name": "leg_r", "size": Vector3(0.12, 0.6, 0.1), "offset": Vector3(0.15, 0.1, 0), "mass": 1.2, "parent": "pelvis"},
		]

	# Create physics bodies
	for config: Dictionary in bone_configs:
		var bone_body: RigidBody3D = _create_physics_bone(config)
		physics_bones[config["name"]] = bone_body
		ragdoll_skeleton.add_child(bone_body)

		# Set root body
		if config["name"] == "pelvis":
			root_body = bone_body

	# Create joints between bones
	for config: Dictionary in bone_configs:
		if config.has("parent"):
			var parent_name: String = config["parent"] as String
			_create_joint(config["name"], parent_name)

	# Start with ragdoll disabled
	_set_ragdoll_enabled(false)


func _create_physics_bone(config: Dictionary) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = config["name"] as String
	body.mass = config["mass"] as float
	body.gravity_scale = GRAVITY_SCALE
	body.linear_damp = 0.1
	body.angular_damp = 0.2
	body.physics_material_override = _create_bounce_material()

	# Set collision layers
	body.collision_layer = RAGDOLL_COLLISION_LAYER
	body.collision_mask = 1 | 2  # World + Players

	# Create collision shape (capsule for performance)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	var size: Vector3 = config["size"] as Vector3
	shape.radius = size.x
	shape.height = size.y
	collision.shape = shape
	body.add_child(collision)

	# Create visual mesh (matches character style)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = size.x
	mesh.height = size.y
	mesh_instance.mesh = mesh
	mesh_instance.name = "Mesh"
	body.add_child(mesh_instance)

	# Position
	body.position = config["offset"] as Vector3

	return body


func _create_joint(bone_name: String, parent_name: String) -> void:
	var bone: RigidBody3D = physics_bones.get(bone_name) as RigidBody3D
	var parent: RigidBody3D = physics_bones.get(parent_name) as RigidBody3D

	if not bone or not parent:
		return

	var joint := Generic6DOFJoint3D.new()
	joint.name = "%s_to_%s" % [parent_name, bone_name]

	# Configure for cartoon-style flexibility
	joint.node_a = parent.get_path()
	joint.node_b = bone.get_path()

	# Allow generous rotation (more floppy = more fun)
	# Angular limits (twist and swing)
	joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -deg_to_rad(JOINT_TWIST_LIMIT))
	joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(JOINT_TWIST_LIMIT))
	joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -deg_to_rad(JOINT_SWING_LIMIT))
	joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(JOINT_SWING_LIMIT))
	joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -deg_to_rad(JOINT_SWING_LIMIT))
	joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(JOINT_SWING_LIMIT))

	# Damping
	joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_DAMPING, JOINT_DAMPING)
	joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_DAMPING, JOINT_DAMPING)
	joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_DAMPING, JOINT_DAMPING)

	# Lock linear movement (bones don't separate)
	joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
	joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
	joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
	joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
	joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
	joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)

	joints[joint.name] = joint
	ragdoll_skeleton.add_child(joint)


func _create_bounce_material() -> PhysicsMaterial:
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.3 * BOUNCE_MULTIPLIER  # Bouncy ragdolls
	mat.friction = 0.5
	mat.rough = true
	return mat

#endregion


#region Internal - State Processing

func _set_state(new_state: RagdollState) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	state_time = 0.0
	state_changed.emit(new_state)


func _process_transition(delta: float) -> void:
	# Blend from animation pose to ragdoll
	var blend_progress: float = state_time / TRANSITION_DURATION

	if blend_progress >= 1.0:
		_set_state(RagdollState.ACTIVE)
		_set_ragdoll_enabled(true)

		# Apply initial velocity from character movement
		_apply_initial_velocity()
		return

	# During transition, lerp visual positions
	_blend_to_ragdoll(blend_progress)


func _process_active(delta: float) -> void:
	# Check for auto-despawn
	if state_time >= MAX_RAGDOLL_TIME:
		deactivate_ragdoll(false)
		return

	# Check for settling
	if state_time > MIN_RAGDOLL_TIME and is_settled():
		ragdoll_settled.emit()

		# Auto-recover if enabled
		if allow_recovery:
			deactivate_ragdoll(true)


func _process_recovery(_delta: float) -> void:
	# Recovery animation is handled by tween
	pass


func _set_ragdoll_enabled(enabled: bool) -> void:
	# Hide/show character mesh, enable/disable ragdoll
	if character:
		var body_mesh: MeshInstance3D = character.get_node_or_null("BodyMesh") as MeshInstance3D
		var head_mesh: MeshInstance3D = character.get_node_or_null("HeadMesh") as MeshInstance3D

		if body_mesh:
			body_mesh.visible = not enabled
		if head_mesh:
			head_mesh.visible = not enabled

	# Enable/disable physics bodies
	for bone_name: String in physics_bones:
		var bone: RigidBody3D = physics_bones[bone_name] as RigidBody3D
		if bone:
			bone.visible = enabled
			bone.freeze = not enabled
			if enabled:
				bone.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
				bone.freeze = false


func _apply_initial_velocity() -> void:
	if _stored_velocity.length_squared() < 0.01:
		return

	# Apply character's momentum to all bones
	for bone_name: String in physics_bones:
		var bone: RigidBody3D = physics_bones[bone_name] as RigidBody3D
		if bone:
			bone.linear_velocity = _stored_velocity


func _blend_to_ragdoll(progress: float) -> void:
	# Smooth visual transition (bones lerp to ragdoll positions)
	# In a full implementation, this would blend skeleton poses
	pass

#endregion


#region Internal - Force Application

func _apply_pending_forces() -> void:
	if _pending_forces.is_empty():
		return

	for force_data: Dictionary in _pending_forces:
		var force: Vector3 = force_data["force"] as Vector3
		var position: Vector3 = force_data["position"] as Vector3
		var bone_name: String = force_data["bone"] as String

		if bone_name == "root" or bone_name.is_empty():
			# Apply to all bones
			_apply_force_to_all(force)
		else:
			# Apply to specific bone
			_apply_force_to_bone(bone_name, force, position)

	_pending_forces.clear()


func _apply_force_to_bone(bone_name: String, force: Vector3, world_pos: Vector3) -> void:
	var bone: RigidBody3D = physics_bones.get(bone_name) as RigidBody3D
	if not bone:
		# Fall back to root
		bone = root_body

	if not bone:
		return

	# Apply central impulse
	bone.apply_central_impulse(force)

	# Add angular impulse for dramatic spinning
	var angular_impulse: Vector3 = force.cross(Vector3.UP) * ANGULAR_FORCE_MULT * 0.1
	bone.apply_torque_impulse(angular_impulse)


func _apply_force_to_all(force: Vector3) -> void:
	var per_bone_force: Vector3 = force / physics_bones.size()

	for bone_name: String in physics_bones:
		var bone: RigidBody3D = physics_bones[bone_name] as RigidBody3D
		if bone:
			# Vary force slightly per bone for natural look
			var variance: float = randf_range(0.8, 1.2)
			bone.apply_central_impulse(per_bone_force * variance)

#endregion


#region Internal - Recovery

func _play_recovery_animation() -> void:
	if _recovery_tween:
		_recovery_tween.kill()

	_recovery_tween = create_tween()
	_recovery_tween.set_parallel(false)

	# Get final ragdoll position
	var final_position: Vector3 = get_ragdoll_position()

	# Disable ragdoll physics
	_set_ragdoll_enabled(false)

	# Animate character getting up
	if character:
		character.global_position = final_position

		# Scale bounce for "getting up" effect
		character.scale = Vector3(1.2, 0.8, 1.2)
		_recovery_tween.tween_property(character, "scale", Vector3.ONE, RECOVERY_ANIM_DURATION)
		_recovery_tween.set_trans(Tween.TRANS_ELASTIC)
		_recovery_tween.set_ease(Tween.EASE_OUT)

	_recovery_tween.tween_callback(_finalize_deactivation)


func _finalize_deactivation() -> void:
	current_state = RagdollState.INACTIVE
	state_time = 0.0

	_set_ragdoll_enabled(false)

	# Clear forces
	_pending_forces.clear()

	# Restore character control
	if character and character is PlayerCharacter:
		(character as PlayerCharacter).is_alive = true

	set_physics_process(false)
	recovery_complete.emit()
	state_changed.emit(RagdollState.INACTIVE)

#endregion


#region Internal - Network Sync

func _process_network_sync(delta: float) -> void:
	_sync_timer += delta

	if _sync_timer < SYNC_INTERVAL:
		return

	_sync_timer = 0.0

	# Build sync data (only include bones that moved significantly)
	var sync_data: Dictionary = {}

	for bone_name: String in physics_bones:
		var bone: RigidBody3D = physics_bones[bone_name] as RigidBody3D
		if not bone:
			continue

		var last_pos: Vector3 = _last_synced_positions.get(bone_name, Vector3.INF) as Vector3
		var current_pos: Vector3 = bone.global_position

		if last_pos == Vector3.INF or current_pos.distance_to(last_pos) > SYNC_POSITION_THRESHOLD:
			sync_data[bone_name] = {
				"pos": current_pos,
				"vel": bone.linear_velocity,
			}
			_last_synced_positions[bone_name] = current_pos

	if not sync_data.is_empty():
		sync_ragdoll_event.emit("sync", sync_data)


func _broadcast_ragdoll_activation(force: Vector3, hit_point: Vector3, hit_bone: String) -> void:
	var data: Dictionary = {
		"force": force,
		"hit_point": hit_point,
		"hit_bone": hit_bone,
	}
	sync_ragdoll_event.emit("activate", data)


## Called on clients to apply server state
func apply_network_state(event_type: String, data: Dictionary) -> void:
	match event_type:
		"activate":
			activate_ragdoll(
				data.get("force", Vector3.ZERO) as Vector3,
				data.get("hit_point", Vector3.ZERO) as Vector3,
				data.get("hit_bone", "root") as String
			)
		"sync":
			_apply_sync_data(data)
		"deactivate":
			deactivate_ragdoll(data.get("with_recovery", true) as bool)


func _apply_sync_data(data: Dictionary) -> void:
	for bone_name: String in data:
		var bone: RigidBody3D = physics_bones.get(bone_name) as RigidBody3D
		if not bone:
			continue

		var bone_data: Dictionary = data[bone_name] as Dictionary
		bone.global_position = bone_data["pos"] as Vector3
		bone.linear_velocity = bone_data["vel"] as Vector3

#endregion


#region Internal - Gibs

func _spawn_cartoon_gibs(hit_point: Vector3, hit_force: Vector3) -> void:
	# Spawn cartoon-style body parts that fly off
	# These are simple geometric shapes with exaggerated physics

	var gib_count: int = 4 if use_mobile_optimization else 8
	var base_color: Color = Color.WHITE

	if character and character.has_method("get_player_color"):
		base_color = character.get_player_color()

	for i in range(gib_count):
		_spawn_single_gib(hit_point, hit_force, base_color)


func _spawn_single_gib(origin: Vector3, base_force: Vector3, color: Color) -> void:
	var gib := RigidBody3D.new()
	gib.name = "Gib_%d" % randi()
	gib.mass = 0.1
	gib.gravity_scale = 1.2
	gib.physics_material_override = _create_bounce_material()

	# Random shape
	var collision := CollisionShape3D.new()
	var shapes: Array[Shape3D] = [
		SphereShape3D.new(),
		BoxShape3D.new(),
		CapsuleShape3D.new(),
	]
	var shape: Shape3D = shapes[randi() % shapes.size()]
	collision.shape = shape
	gib.add_child(collision)

	# Mesh
	var mesh_instance := MeshInstance3D.new()
	var meshes: Array[Mesh] = [
		SphereMesh.new(),
		BoxMesh.new(),
		CapsuleMesh.new(),
	]
	var mesh: Mesh = meshes[randi() % meshes.size()]
	mesh_instance.mesh = mesh

	# Scale down
	var scale_factor: float = randf_range(0.05, 0.15)
	mesh_instance.scale = Vector3.ONE * scale_factor

	# Color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(randf_range(-0.2, 0.2))
	mesh_instance.material_override = mat

	gib.add_child(mesh_instance)
	gib.global_position = origin

	# Random velocity
	var random_dir := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(0.5, 1.5),
		randf_range(-1.0, 1.0)
	).normalized()

	var force_magnitude: float = base_force.length() * randf_range(0.5, 1.5)

	# Add to scene
	if character:
		character.get_parent().add_child(gib)
	else:
		get_tree().current_scene.add_child(gib)

	# Apply initial velocity
	gib.linear_velocity = random_dir * force_magnitude * 0.5
	gib.angular_velocity = Vector3(
		randf_range(-10, 10),
		randf_range(-10, 10),
		randf_range(-10, 10)
	)

	# Auto-destroy after delay
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(gib.queue_free)

#endregion


#region Helpers

func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

#endregion
