## Grenade Launcher - Fires arcing explosive grenades.
##
## Grenades arc through the air and explode on impact or after a fuse timer.
## Great for indirect fire over cover.
class_name GrenadeLauncher
extends WeaponBase


## Grenade fuse time (seconds until auto-detonate).
const GRENADE_FUSE_TIME: float = 2.5

## Bounce energy retention.
const BOUNCE_DAMPENING: float = 0.6


func _setup_weapon() -> void:
	WeaponData.apply_to_weapon(self, &"grenade_launcher")


## Override projectile spawn to use grenade-specific settings.
func _fire_projectile(direction: Vector3) -> void:
	if not projectile_scene or not muzzle_point:
		_spawn_grenade(direction)
		return

	super._fire_projectile(direction)


## Spawn a grenade projectile with arc and bounce behavior.
func _spawn_grenade(direction: Vector3) -> void:
	var origin := muzzle_point.global_position if muzzle_point else global_position

	# Create grenade node
	var grenade := _create_grenade_projectile()
	grenade.global_position = origin

	# Configure grenade - launch at an upward angle
	var launch_angle := direction
	if direction.y < 0.3:
		launch_angle.y += 0.3  # Add slight upward arc
		launch_angle = launch_angle.normalized()

	grenade.set_meta("direction", launch_angle)
	grenade.set_meta("speed", projectile_speed)
	grenade.set_meta("damage", base_damage)
	grenade.set_meta("owner_peer_id", owner_peer_id)
	grenade.set_meta("explosion_radius", area_damage_radius)
	grenade.set_meta("explosion_falloff", area_damage_falloff)
	grenade.set_meta("fuse_time", GRENADE_FUSE_TIME)
	grenade.set_meta("bounce_dampening", BOUNCE_DAMPENING)
	grenade.set_meta("gravity_scale", projectile_gravity_scale)

	# Add to scene
	var projectiles_node := _get_projectiles_node()
	if projectiles_node:
		projectiles_node.add_child(grenade)
	else:
		get_tree().current_scene.add_child(grenade)


## Create a basic grenade projectile node.
func _create_grenade_projectile() -> RigidBody3D:
	var grenade := RigidBody3D.new()
	grenade.name = "Grenade_%d" % Time.get_ticks_msec()

	# Configure physics
	grenade.gravity_scale = projectile_gravity_scale
	grenade.mass = 0.5
	grenade.physics_material_override = _create_bouncy_material()

	# Add collision shape
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	collision.shape = shape
	grenade.add_child(collision)

	# Add mesh for visibility
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	mesh_instance.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.4, 0.3)
	mat.metallic = 0.6
	mesh_instance.material_override = mat

	grenade.add_child(mesh_instance)

	# Add script for grenade behavior
	grenade.set_script(preload("res://shared/weapons/grenade_projectile.gd"))

	return grenade


## Create a physics material for bouncing.
func _create_bouncy_material() -> PhysicsMaterial:
	var mat := PhysicsMaterial.new()
	mat.bounce = BOUNCE_DAMPENING
	mat.friction = 0.5
	return mat
