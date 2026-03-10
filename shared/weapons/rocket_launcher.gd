## Rocket Launcher - Explosive projectile weapon with area damage.
##
## Fires slow-moving rockets that explode on impact.
## High risk/reward - watch out for self-damage!
class_name RocketLauncher
extends WeaponBase


## Minimum safe distance from explosion.
const SELF_DAMAGE_RADIUS: float = 3.0

## Self-damage multiplier.
const SELF_DAMAGE_MULT: float = 0.5


func _setup_weapon() -> void:
	WeaponData.apply_to_weapon(self, &"rocket_launcher")


## Override projectile spawn to use rocket-specific settings.
func _fire_projectile(direction: Vector3) -> void:
	if not projectile_scene or not muzzle_point:
		# Use fallback projectile creation
		_spawn_rocket(direction)
		return

	super._fire_projectile(direction)


## Spawn a rocket projectile with explosion behavior.
func _spawn_rocket(direction: Vector3) -> void:
	var origin := muzzle_point.global_position if muzzle_point else global_position

	# Create rocket node
	var rocket := _create_rocket_projectile()
	rocket.global_position = origin

	# Configure rocket
	rocket.set_meta("direction", direction)
	rocket.set_meta("speed", projectile_speed)
	rocket.set_meta("damage", base_damage)
	rocket.set_meta("owner_peer_id", owner_peer_id)
	rocket.set_meta("explosion_radius", area_damage_radius)
	rocket.set_meta("explosion_falloff", area_damage_falloff)
	rocket.set_meta("self_damage_mult", SELF_DAMAGE_MULT)

	# Add to scene
	var projectiles_node := _get_projectiles_node()
	if projectiles_node:
		projectiles_node.add_child(rocket)
	else:
		get_tree().current_scene.add_child(rocket)


## Create a basic rocket projectile node.
func _create_rocket_projectile() -> Area3D:
	var rocket := Area3D.new()
	rocket.name = "Rocket_%d" % Time.get_ticks_msec()

	# Add collision shape
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	collision.shape = shape
	rocket.add_child(collision)

	# Add mesh for visibility
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.6
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees.x = 90  # Point forward

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mat.emission_energy_multiplier = 2.0
	mesh_instance.material_override = mat

	rocket.add_child(mesh_instance)

	# Add script for rocket behavior
	rocket.set_script(preload("res://shared/weapons/rocket_projectile.gd"))

	return rocket


## Check if we can safely fire (not pointing at close wall).
func _can_fire() -> bool:
	if not super._can_fire():
		return false

	# Optional: Check for close walls to prevent accidental self-damage
	# This could be enabled via a safety setting
	return true
