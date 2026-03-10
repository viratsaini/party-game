## Projectile for Arena Blaster.
##
## Server-spawned Area3D that travels in a straight line, deals damage on
## contact with a PlayerCharacter, and self-destructs after its lifetime expires.
class_name ArenaBlasterProjectile
extends Area3D


# region — Exports

@export var speed: float = 30.0
@export var damage: float = 25.0
@export var lifetime: float = 3.0

# endregion


# region — State

## World-space travel direction (normalised).
var direction: Vector3 = Vector3.FORWARD

## Peer id of the player who fired this projectile (used to avoid self-hits
## and to credit the kill).
var owner_peer_id: int = 0

## Colour tint applied to the mesh — set by the game controller to match the
## firing player's colour.
var projectile_color: Color = Color(1.0, 0.3, 0.2, 1.0)

# endregion


# region — Node References

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var lifetime_timer: Timer = $LifetimeTimer

# endregion


# region — Lifecycle

func _ready() -> void:
	# Apply colour to the mesh material.
	_apply_color()

	# Wire up signals.
	body_entered.connect(_on_body_entered)
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_expired)

	if not lifetime_timer.is_inside_tree():
		await lifetime_timer.ready
	lifetime_timer.start()

	# Look in the travel direction.
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

# endregion


# region — Collision

func _on_body_entered(body: Node3D) -> void:
	# Only the server processes hit logic.
	if not _is_server():
		return

	if body is CharacterBody3D:
		var character: PlayerCharacter = body as PlayerCharacter
		if character and character.peer_id != owner_peer_id:
			character.take_damage(damage, owner_peer_id)

			# Notify the game controller to register the kill if the target died.
			var game: Node = get_tree().current_scene
			if game and game.has_method("register_kill") and not character.is_alive:
				game.register_kill(owner_peer_id, character.peer_id)

			queue_free()

	# Also destroy on hitting static geometry (walls, cover).
	elif body is StaticBody3D:
		queue_free()

# endregion


# region — Self-Destruction

func _on_lifetime_expired() -> void:
	queue_free()

# endregion


# region — Visuals

func _apply_color() -> void:
	if not mesh_instance:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = projectile_color
	mat.emission_enabled = true
	mat.emission = projectile_color
	mat.emission_energy_multiplier = 2.0
	mesh_instance.material_override = mat

# endregion


# region — Helpers

func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
