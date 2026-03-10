## Power-up pickup for Arena Blaster.
##
## Server-authoritative Area3D that grants an effect to the first player who
## touches it, then hides and respawns after a configurable delay.
## Visually represented as a floating, rotating coloured mesh.
class_name ArenaBlasterPickup
extends Area3D


# region — Enums

enum PickupType {
	HEALTH,
	SPEED,
	SHIELD,
	RAPID_FIRE,
}

# endregion


# region — Exports

@export var pickup_type: PickupType = PickupType.HEALTH
@export var respawn_time: float = 10.0

# endregion


# region — Constants

## Colour per pickup type for the mesh and glow.
const TYPE_COLORS: Dictionary = {
	PickupType.HEALTH:     Color(0.2, 1.0, 0.3),
	PickupType.SPEED:      Color(0.3, 0.7, 1.0),
	PickupType.SHIELD:     Color(1.0, 0.85, 0.2),
	PickupType.RAPID_FIRE: Color(1.0, 0.3, 0.15),
}

const ROTATION_SPEED: float = 2.0  ## Radians per second.
const FLOAT_AMPLITUDE: float = 0.15
const FLOAT_SPEED: float = 3.0

# endregion


# region — State

var _active: bool = true
var _base_y: float = 0.0
var _time: float = 0.0

# endregion


# region — Node References

@onready var pickup_mesh: MeshInstance3D = $PickupMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var respawn_timer: Timer = $RespawnTimer

# endregion


# region — Lifecycle

func _ready() -> void:
	_base_y = position.y
	_apply_type_color()

	body_entered.connect(_on_body_entered)

	respawn_timer.wait_time = respawn_time
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_respawn_timeout)


func _process(delta: float) -> void:
	if not _active:
		return

	_time += delta

	# Rotate.
	if pickup_mesh:
		pickup_mesh.rotate_y(ROTATION_SPEED * delta)

	# Float bob.
	position.y = _base_y + sin(_time * FLOAT_SPEED) * FLOAT_AMPLITUDE

# endregion


# region — Pickup Logic (Server-Authoritative)

func _on_body_entered(body: Node3D) -> void:
	if not _is_server():
		return
	if not _active:
		return

	if body is CharacterBody3D:
		var character: PlayerCharacter = body as PlayerCharacter
		if not character or not character.is_alive:
			return

		# Apply the effect via the game controller.
		var game: Node = get_tree().current_scene
		if game and game.has_method("apply_pickup_effect"):
			game.apply_pickup_effect(character.peer_id, pickup_type as int)

		AudioManager.play_sfx("pickup")

		# Deactivate and start respawn.
		_set_active(false)
		_rpc_set_active.rpc(false)
		respawn_timer.start()


func _on_respawn_timeout() -> void:
	if not _is_server():
		return

	_set_active(true)
	_rpc_set_active.rpc(true)

# endregion


# region — Active State

func _set_active(active: bool) -> void:
	_active = active
	visible = active
	if collision_shape:
		collision_shape.disabled = not active


@rpc("authority", "call_remote", "reliable")
func _rpc_set_active(active: bool) -> void:
	_set_active(active)

# endregion


# region — Visuals

func _apply_type_color() -> void:
	if not pickup_mesh:
		return

	var color: Color = TYPE_COLORS.get(pickup_type, Color.WHITE) as Color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	pickup_mesh.material_override = mat

# endregion


# region — Helpers

func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
