## BumperCar — Physics-based bumper car for the Crash Derby mini-game.
##
## Uses RigidBody3D for realistic pushing and collision physics.
## Server-authoritative: all forces are applied on the server only.
## Clients freeze the body and receive position/rotation updates via
## MultiplayerSynchronizer.  Camera is activated for the local player only.
class_name BumperCar
extends RigidBody3D


# region — Constants

## Forward / reverse driving force (Newtons).
const MOVE_FORCE: float = 40.0

## Turning torque (N·m) applied around the Y axis.
const TURN_TORQUE: float = 15.0

## Maximum linear speed (m/s).  Driving force is suppressed above this.
const MAX_LINEAR_SPEED: float = 12.0

## Forward impulse applied when boosting.
const BOOST_IMPULSE: float = 30.0

## Cooldown between boost uses (seconds).
const BOOST_COOLDOWN: float = 6.0

## Linear damp applied while the brake is held.
const BRAKE_DAMP: float = 5.0

## Default linear damp (light friction).
const DEFAULT_DAMP: float = 0.5

## Knockback multiplier applied on collision with another bumper car.
const KNOCKBACK_MULTIPLIER: float = 1.5

## Minimum knockback impulse so even light taps register.
const MIN_KNOCKBACK: float = 5.0

## Shield power-up duration (seconds).
const SHIELD_DURATION: float = 5.0

## Size-Up power-up duration, scale factor, and mass while active.
const SIZE_UP_DURATION: float = 5.0
const SIZE_UP_SCALE: float = 1.5
const SIZE_UP_MASS: float = 4.0

## Magnet power-up duration (seconds) and centre-pull strength.
const MAGNET_DURATION: float = 5.0
const MAGNET_FORCE: float = 8.0

# endregion


# region — State

## Owning player's multiplayer peer id.
var peer_id: int = 0

## Display name shown above the car.
var player_name: String = ""

## Body colour assigned by the lobby.
var car_color: Color = Color.WHITE

## True once the player has fallen off the platform.
var is_eliminated: bool = false

## Active power-up flags.
var shield_active: bool = false
var magnet_active: bool = false

## Internal timers (server-only).
var _shield_timer: float = 0.0
var _size_up_timer: float = 0.0
var _magnet_timer: float = 0.0
var _is_sized_up: bool = false
var _original_mass: float = 2.0

## Boost cooldown tracker (server-side).
var _boost_cooldown_remaining: float = 0.0

## Input state — written by [CrashDerby] each physics frame.
var _move_input: Vector2 = Vector2.ZERO
var _braking: bool = false

# endregion


# region — Node References

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var bumper_mesh: MeshInstance3D = $BumperMesh
@onready var name_label: Label3D = $NameLabel
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var _camera: Camera3D = $Camera3D

# endregion


# region — Setup

## Pre-tree configuration.  Stores values that are applied in [method _ready].
func setup(p_peer_id: int, p_name: String, p_color: Color, p_position: Vector3, p_rotation_y: float) -> void:
	peer_id = p_peer_id
	player_name = p_name
	car_color = p_color
	position = p_position
	rotation.y = p_rotation_y

# endregion


# region — Lifecycle

func _ready() -> void:
	# Server is the authority for all bumper-car physics.
	set_multiplayer_authority(1)

	_original_mass = mass

	# Apply visuals.
	if name_label:
		name_label.text = player_name
	_apply_color(car_color)

	# Camera active only for the local player.
	if _camera:
		_camera.current = _is_local_player()

	# Freeze physics on clients — the server runs the simulation.
	if not _is_server():
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true

	# Server listens for body collisions to apply knockback.
	if _is_server():
		body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if is_eliminated:
		return
	if not _is_server():
		return

	_process_boost_cooldown(delta)
	_process_power_up_timers(delta)
	_apply_movement()

# endregion


# region — Input Setters

## Store movement + brake input.  Called by [CrashDerby] every physics frame.
func set_input(move: Vector2, braking: bool) -> void:
	_move_input = move
	_braking = braking


## Fire a forward boost impulse if off cooldown.  Returns [code]true[/code] on success.
func apply_boost() -> bool:
	if _boost_cooldown_remaining > 0.0 or is_eliminated:
		return false
	_boost_cooldown_remaining = BOOST_COOLDOWN
	var forward: Vector3 = -global_transform.basis.z.normalized()
	apply_central_impulse(forward * BOOST_IMPULSE)
	AudioManager.play_sfx("boost")
	return true

# endregion


# region — Movement (Server Only)

func _apply_movement() -> void:
	# Braking increases linear damp to slow the car quickly.
	linear_damp = BRAKE_DAMP if _braking else DEFAULT_DAMP

	# Forward / reverse force.
	if absf(_move_input.y) > 0.1:
		var forward: Vector3 = -global_transform.basis.z.normalized()
		var force: Vector3 = forward * _move_input.y * MOVE_FORCE
		# Only apply when below max speed or when decelerating.
		if linear_velocity.length() < MAX_LINEAR_SPEED or linear_velocity.dot(force) < 0.0:
			apply_central_force(force)

	# Turning torque — only effective when the car is moving.
	if absf(_move_input.x) > 0.1 and linear_velocity.length() > 0.5:
		apply_torque(Vector3.UP * -_move_input.x * TURN_TORQUE)

	# Magnet: constant pull toward the arena centre.
	if magnet_active:
		var to_center: Vector3 = -global_position
		to_center.y = 0.0
		if to_center.length() > 0.5:
			apply_central_force(to_center.normalized() * MAGNET_FORCE)

# endregion


# region — Collision Knockback

func _on_body_entered(body: Node) -> void:
	if not _is_server():
		return
	if not body is BumperCar:
		return

	var other: BumperCar = body as BumperCar
	if shield_active:
		return  # Shield absorbs knockback.

	var direction: Vector3 = (global_position - other.global_position).normalized()
	direction.y = 0.2  # Slight upward pop.
	var knockback: float = other.linear_velocity.length() * KNOCKBACK_MULTIPLIER
	knockback = maxf(knockback, MIN_KNOCKBACK)
	var mass_ratio: float = other.mass / mass
	apply_central_impulse(direction * knockback * mass_ratio)

# endregion


# region — Power-Ups

## Activate the shield — ignore knockback for [constant SHIELD_DURATION] seconds.
func activate_shield() -> void:
	shield_active = true
	_shield_timer = SHIELD_DURATION
	AudioManager.play_sfx("shield")


## Double scale and mass for [constant SIZE_UP_DURATION] seconds.
func activate_size_up() -> void:
	_is_sized_up = true
	_size_up_timer = SIZE_UP_DURATION
	scale = Vector3.ONE * SIZE_UP_SCALE
	mass = SIZE_UP_MASS
	AudioManager.play_sfx("size_up")


## Instant super boost — resets cooldown and applies a stronger impulse.
func activate_super_boost() -> void:
	_boost_cooldown_remaining = 0.0
	var forward: Vector3 = -global_transform.basis.z.normalized()
	apply_central_impulse(forward * BOOST_IMPULSE * 1.5)
	AudioManager.play_sfx("super_boost")


## Pull toward the arena centre for [constant MAGNET_DURATION] seconds.
func activate_magnet() -> void:
	magnet_active = true
	_magnet_timer = MAGNET_DURATION
	AudioManager.play_sfx("magnet")


func _process_power_up_timers(delta: float) -> void:
	if shield_active:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			shield_active = false

	if _is_sized_up:
		_size_up_timer -= delta
		if _size_up_timer <= 0.0:
			_is_sized_up = false
			scale = Vector3.ONE
			mass = _original_mass

	if magnet_active:
		_magnet_timer -= delta
		if _magnet_timer <= 0.0:
			magnet_active = false


func _process_boost_cooldown(delta: float) -> void:
	if _boost_cooldown_remaining > 0.0:
		_boost_cooldown_remaining = maxf(_boost_cooldown_remaining - delta, 0.0)

# endregion


# region — Elimination

## Mark the car as eliminated — disable physics and dim the visuals.
func eliminate() -> void:
	is_eliminated = true
	collision_layer = 0
	collision_mask = 0
	gravity_scale = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	_dim_visuals()


## Make this car's camera the active one (used for spectator mode).
func activate_camera() -> void:
	if _camera:
		_camera.current = true

# endregion


# region — Visuals

func _apply_color(color: Color) -> void:
	if body_mesh and body_mesh.mesh:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.6
		body_mesh.material_override = mat

	if bumper_mesh and bumper_mesh.mesh:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color.lightened(0.3)
		mat.roughness = 0.5
		mat.metallic = 0.3
		bumper_mesh.material_override = mat


## Make the car semi-transparent when eliminated.
func _dim_visuals() -> void:
	for child: Node in [body_mesh, bumper_mesh]:
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var mat: StandardMaterial3D = null
			if mi.material_override is StandardMaterial3D:
				mat = (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.5, 0.5, 0.5)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.3
			mi.material_override = mat

# endregion


# region — Helpers

func _is_local_player() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.get_unique_id() == peer_id


func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()


## Horizontal distance from the car to the arena centre (Y ignored).
func get_distance_to_center() -> float:
	return Vector2(global_position.x, global_position.z).length()

# endregion
