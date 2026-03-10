## KartController — Arcade kart physics for the Turbo Karts mini-game.
##
## Uses CharacterBody3D for simplified, mobile-friendly kart movement.
## Position, rotation, and velocity are synced via MultiplayerSynchronizer
## (authority = owning player). Race state (laps, checkpoints) is managed
## by the TurboKarts game controller on the server and replicated via RPCs.
class_name KartController
extends CharacterBody3D


# region — Constants

const GRAVITY: float = 20.0
const BASE_MAX_SPEED: float = 18.0
const ACCELERATION: float = 12.0
const BRAKING: float = 20.0
const FRICTION: float = 8.0
const STEERING_SPEED: float = 3.0
const DRIFT_STEERING_MULT: float = 1.8
const DRIFT_FRICTION_MULT: float = 0.4
const DRIFT_STEER_THRESHOLD: float = 0.7
const DRIFT_SPEED_THRESHOLD: float = 0.6
const BOOST_SPEED_MULT: float = 1.5
const BOOST_DURATION: float = 2.0

## Power-up / item types.
enum ItemType { NONE = 0, BOOST = 1, SHIELD = 2, MISSILE = 3 }

# endregion


# region — State

## Network identity.
var peer_id: int = 0
var player_name: String = ""
var kart_color: Color = Color.WHITE

## Race progress (managed by server, synced via RPCs).
var current_lap: int = 0
var current_checkpoint: int = -1
var finished: bool = false
var finish_time: float = 0.0

## Kart physics state.
var forward_speed: float = 0.0
var steer_input: float = 0.0
var throttle_input: float = 0.0
var is_drifting: bool = false

## Boost state (managed locally by the owning player).
var boost_charges: int = 0
var _boost_timer: float = 0.0
var _is_boosting: bool = false

## Item state.
var held_item: int = ItemType.NONE
var shield_active: bool = false
var _shield_timer: float = 0.0

## Internal.
var _race_started: bool = false

# endregion


# region — Node References

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var name_label: Label3D = $NameLabel
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var _camera: Camera3D = $Camera3D

# endregion


# region — Setup

## Called before the kart enters the tree. Stores initial configuration.
## Visual setup is deferred to [method _ready] when child nodes are available.
func setup(p_peer_id: int, p_name: String, p_color: Color, p_position: Vector3, p_rotation_y: float) -> void:
	peer_id = p_peer_id
	player_name = p_name
	kart_color = p_color
	position = p_position
	rotation.y = p_rotation_y

# endregion


# region — Lifecycle

func _ready() -> void:
	# Set multiplayer authority to the owning peer.
	if peer_id > 0:
		set_multiplayer_authority(peer_id)

	# Apply visuals now that child nodes exist.
	if name_label:
		name_label.text = player_name
	_apply_color(kart_color)

	# Only the local player owns the camera.
	if _camera:
		_camera.current = _is_local_player()


func _physics_process(delta: float) -> void:
	if not _is_local_player():
		# Keep physics body integrated for Area3D detection on the server.
		move_and_slide()
		return

	if not _race_started:
		_apply_gravity(delta)
		move_and_slide()
		return

	_process_boost_timer(delta)
	_process_shield_timer(delta)
	_apply_gravity(delta)
	_process_kart_movement(delta)
	move_and_slide()

# endregion


# region — Input Setters (called by TurboKarts game controller)

## Set lateral steering input. Negative = left, positive = right.
func set_steering(value: float) -> void:
	steer_input = clampf(value, -1.0, 1.0)


## Set throttle / brake input. Positive = accelerate, negative = brake.
func set_throttle(value: float) -> void:
	throttle_input = clampf(value, -1.0, 1.0)

# endregion


# region — Kart Physics

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta


func _process_kart_movement(delta: float) -> void:
	var max_speed: float = BASE_MAX_SPEED
	if _is_boosting:
		max_speed *= BOOST_SPEED_MULT

	# Throttle / braking / coasting.
	if throttle_input > 0.0:
		forward_speed = move_toward(forward_speed, max_speed, ACCELERATION * throttle_input * delta)
	elif throttle_input < 0.0:
		forward_speed = move_toward(forward_speed, 0.0, BRAKING * absf(throttle_input) * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, FRICTION * delta)

	# Auto-drift when turning hard at speed.
	is_drifting = absf(steer_input) > DRIFT_STEER_THRESHOLD and forward_speed > BASE_MAX_SPEED * DRIFT_SPEED_THRESHOLD

	# Steering — only effective when the kart is moving.
	if absf(forward_speed) > 0.5:
		var steer_amount: float = STEERING_SPEED * steer_input * delta
		if is_drifting:
			steer_amount *= DRIFT_STEERING_MULT
		rotation.y -= steer_amount * signf(forward_speed)

	# Build velocity from the kart's forward direction.
	var forward_dir: Vector3 = -global_transform.basis.z.normalized()
	var lateral_velocity: Vector3 = velocity - forward_dir * velocity.dot(forward_dir)

	# Drift reduces lateral grip, making the kart slide outward.
	var grip: float = 1.0 if not is_drifting else DRIFT_FRICTION_MULT
	lateral_velocity = lateral_velocity.lerp(Vector3.ZERO, grip * delta * 5.0)

	velocity.x = forward_dir.x * forward_speed + lateral_velocity.x
	velocity.z = forward_dir.z * forward_speed + lateral_velocity.z

# endregion


# region — Boost

## Spend one boost charge for a temporary speed increase.
func activate_boost() -> void:
	if boost_charges <= 0 or _is_boosting:
		return
	boost_charges -= 1
	_is_boosting = true
	_boost_timer = BOOST_DURATION
	AudioManager.play_sfx("boost")


## Add a boost charge (from power-up). Max 3 charges.
func add_boost_charge() -> void:
	boost_charges = mini(boost_charges + 1, 3)


func _process_boost_timer(delta: float) -> void:
	if _is_boosting:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			_is_boosting = false
			_boost_timer = 0.0

# endregion


# region — Items

## Store a collected power-up item. Ignored if already holding one.
func collect_item(item_type: int) -> void:
	if held_item != ItemType.NONE:
		return
	held_item = item_type


## Activate the currently held item.
func use_item() -> void:
	if held_item == ItemType.NONE:
		return

	match held_item:
		ItemType.BOOST:
			add_boost_charge()
			AudioManager.play_sfx("item_boost")
		ItemType.SHIELD:
			_activate_shield()
			AudioManager.play_sfx("item_shield")
		ItemType.MISSILE:
			# Missile spawning is handled by TurboKarts game controller via RPC.
			AudioManager.play_sfx("item_missile")

	held_item = ItemType.NONE


func _activate_shield() -> void:
	shield_active = true
	_shield_timer = 5.0


func _process_shield_timer(delta: float) -> void:
	if shield_active:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			shield_active = false
			_shield_timer = 0.0

# endregion


# region — Race Control

## Called by the game controller to start / stop accepting input.
func set_race_started(started: bool) -> void:
	_race_started = started

# endregion


# region — Visuals

func _apply_color(color: Color) -> void:
	if body_mesh and body_mesh.mesh:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.6
		body_mesh.material_override = mat

# endregion


# region — Helpers

func _is_local_player() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.get_unique_id() == peer_id


## Return a human-readable name for the currently held item.
func get_item_name() -> String:
	match held_item:
		ItemType.BOOST:
			return "BOOST"
		ItemType.SHIELD:
			return "SHIELD"
		ItemType.MISSILE:
			return "MISSILE"
	return ""

# endregion
