## WeaponBase - Abstract base class for all weapons in BattleZone Party.
##
## Provides common functionality for hitscan and projectile weapons including:
## - Server-authoritative fire validation
## - Recoil patterns and spread
## - Ammo management and reloading
## - Sound and particle effect integration points
## - Network-optimized state replication
class_name WeaponBase
extends Node3D


# region -- Signals

## Emitted when the weapon fires successfully.
signal fired(weapon: WeaponBase)

## Emitted when the weapon starts reloading.
signal reload_started(weapon: WeaponBase)

## Emitted when the weapon finishes reloading.
signal reload_finished(weapon: WeaponBase)

## Emitted when ammo count changes.
signal ammo_changed(current: int, reserve: int, max_magazine: int)

## Emitted when the weapon is picked up.
signal picked_up(weapon: WeaponBase, peer_id: int)

## Emitted when the weapon is dropped.
signal dropped(weapon: WeaponBase)

## Emitted when charge state changes (for charge weapons like Railgun).
signal charge_changed(charge_percent: float)

## Emitted when spinup state changes (for spinup weapons like Minigun).
signal spinup_changed(spinup_percent: float)

# endregion


# region -- Enums

## Type of projectile system the weapon uses.
enum WeaponType {
	HITSCAN,        ## Instant hit detection via raycast
	PROJECTILE,     ## Physical projectile with travel time
	HITSCAN_MULTI,  ## Multiple hitscan rays (shotgun)
}

## Fire mode of the weapon.
enum FireMode {
	SEMI_AUTO,      ## One shot per trigger pull
	AUTOMATIC,      ## Continuous fire while holding
	BURST,          ## Fixed number of shots per trigger
	CHARGE,         ## Hold to charge, release to fire
	SPINUP,         ## Requires spinup time before firing
}

## Slot type for weapon inventory.
enum WeaponSlot {
	PRIMARY,
	SECONDARY,
	SPECIAL,
}

# endregion


# region -- Exports

@export_group("Identity")
## Unique identifier for this weapon type.
@export var weapon_id: StringName = &"weapon_base"
## Display name shown in UI.
@export var weapon_name: String = "Base Weapon"
## Weapon slot category.
@export var weapon_slot: WeaponSlot = WeaponSlot.PRIMARY
## Icon for UI display.
@export var weapon_icon: Texture2D

@export_group("Damage")
## Base damage per hit/projectile.
@export var base_damage: float = 25.0
## Headshot damage multiplier.
@export var headshot_multiplier: float = 2.0
## Bodyshot damage multiplier.
@export var bodyshot_multiplier: float = 1.0
## Legshot damage multiplier.
@export var legshot_multiplier: float = 0.75
## Does this weapon deal area damage?
@export var has_area_damage: bool = false
## Area damage radius (if has_area_damage is true).
@export var area_damage_radius: float = 0.0
## Area damage falloff (1.0 = full damage at edge, 0.0 = no damage at edge).
@export var area_damage_falloff: float = 0.5

@export_group("Fire Rate")
## Weapon type (hitscan, projectile, etc.).
@export var weapon_type: WeaponType = WeaponType.HITSCAN
## Fire mode (semi, auto, burst, etc.).
@export var fire_mode: FireMode = FireMode.SEMI_AUTO
## Time between shots in seconds.
@export var fire_rate: float = 0.3
## Number of shots per burst (for BURST mode).
@export var burst_count: int = 3
## Delay between burst shots.
@export var burst_delay: float = 0.05
## Spinup time in seconds (for SPINUP mode).
@export var spinup_time: float = 0.0
## Charge time in seconds (for CHARGE mode).
@export var charge_time: float = 0.0
## Minimum charge percent required to fire (for CHARGE mode).
@export var min_charge_percent: float = 0.0

@export_group("Ammo")
## Magazine capacity.
@export var magazine_size: int = 30
## Maximum reserve ammo.
@export var max_reserve_ammo: int = 120
## Starting reserve ammo.
@export var starting_reserve_ammo: int = 60
## Reload time in seconds.
@export var reload_time: float = 2.0
## Does this weapon reload one round at a time (like shotgun)?
@export var reload_one_at_a_time: bool = false
## Time per round when reloading one at a time.
@export var per_round_reload_time: float = 0.5
## Can reload be cancelled by firing?
@export var can_cancel_reload: bool = true
## Ammo consumed per shot.
@export var ammo_per_shot: int = 1

@export_group("Range & Accuracy")
## Maximum effective range.
@export var max_range: float = 100.0
## Base spread in degrees (0 = perfectly accurate).
@export var base_spread: float = 0.0
## Maximum spread when moving/firing continuously.
@export var max_spread: float = 5.0
## Spread increase per shot.
@export var spread_increase_per_shot: float = 0.5
## Spread recovery rate (degrees per second).
@export var spread_recovery_rate: float = 10.0
## Movement spread multiplier.
@export var movement_spread_multiplier: float = 1.5
## Number of pellets (for shotgun-type weapons).
@export var pellet_count: int = 1

@export_group("Recoil")
## Vertical recoil per shot (degrees).
@export var vertical_recoil: float = 1.0
## Horizontal recoil range per shot (degrees, random within range).
@export var horizontal_recoil_range: float = 0.5
## Recoil recovery rate (degrees per second).
@export var recoil_recovery_rate: float = 8.0
## Recoil pattern (array of Vector2 offsets applied sequentially).
@export var recoil_pattern: Array[Vector2] = []

@export_group("Projectile Settings")
## Projectile scene to spawn (for PROJECTILE type).
@export var projectile_scene: PackedScene
## Projectile speed in units per second.
@export var projectile_speed: float = 50.0
## Does the projectile arc (affected by gravity)?
@export var projectile_arcs: bool = false
## Projectile gravity scale.
@export var projectile_gravity_scale: float = 1.0
## Does the projectile penetrate targets?
@export var projectile_penetrates: bool = false
## Maximum penetration count.
@export var max_penetrations: int = 1
## Damage reduction per penetration (multiplier).
@export var penetration_damage_falloff: float = 0.7

@export_group("Audio")
## Sound effect key for firing.
@export var fire_sound: StringName = &"weapon_fire"
## Sound effect key for dry fire (no ammo).
@export var dry_fire_sound: StringName = &"weapon_dry_fire"
## Sound effect key for reload start.
@export var reload_start_sound: StringName = &"weapon_reload_start"
## Sound effect key for reload end.
@export var reload_end_sound: StringName = &"weapon_reload_end"
## Sound effect key for equip.
@export var equip_sound: StringName = &"weapon_equip"

@export_group("Visual Effects")
## Muzzle flash particle scene.
@export var muzzle_flash_scene: PackedScene
## Shell casing particle scene.
@export var shell_casing_scene: PackedScene
## Tracer effect scene (for hitscan visualization).
@export var tracer_scene: PackedScene
## Impact effect scene.
@export var impact_effect_scene: PackedScene

# endregion


# region -- State

## Current ammo in magazine.
var current_ammo: int = 0

## Current reserve ammo.
var reserve_ammo: int = 0

## Current spread value (accumulates during fire).
var current_spread: float = 0.0

## Current recoil offset (visual/aim adjustment).
var current_recoil: Vector2 = Vector2.ZERO

## Recoil pattern index (which shot in the pattern we're on).
var recoil_pattern_index: int = 0

## Is the weapon currently reloading?
var is_reloading: bool = false

## Remaining reload time.
var reload_timer: float = 0.0

## Time until next shot is allowed.
var fire_cooldown: float = 0.0

## Current spinup progress (0.0 to 1.0).
var spinup_progress: float = 0.0

## Is the trigger currently held?
var trigger_held: bool = false

## Current charge progress (0.0 to 1.0).
var charge_progress: float = 0.0

## Is the weapon currently charging?
var is_charging: bool = false

## Burst shots remaining.
var burst_shots_remaining: int = 0

## Time until next burst shot.
var burst_timer: float = 0.0

## Owner peer ID.
var owner_peer_id: int = 0

## Is this weapon currently equipped (active)?
var is_equipped: bool = false

## Muzzle point reference (set by weapon manager).
var muzzle_point: Node3D = null

# endregion


# region -- Lifecycle

func _ready() -> void:
	current_ammo = magazine_size
	reserve_ammo = starting_reserve_ammo
	current_spread = base_spread
	_setup_weapon()


func _physics_process(delta: float) -> void:
	if not is_equipped:
		return

	_process_fire_cooldown(delta)
	_process_reload(delta)
	_process_spread_recovery(delta)
	_process_recoil_recovery(delta)
	_process_spinup(delta)
	_process_charge(delta)
	_process_burst(delta)


## Override in subclasses for weapon-specific setup.
func _setup_weapon() -> void:
	pass

# endregion


# region -- Fire System

## Attempt to fire the weapon. Returns true if successful.
func try_fire(aim_direction: Vector3) -> bool:
	if not _can_fire():
		if current_ammo <= 0 and fire_cooldown <= 0.0:
			_play_sound(dry_fire_sound)
		return false

	# Handle different fire modes
	match fire_mode:
		FireMode.SEMI_AUTO:
			_execute_fire(aim_direction)
		FireMode.AUTOMATIC:
			_execute_fire(aim_direction)
		FireMode.BURST:
			if burst_shots_remaining <= 0:
				burst_shots_remaining = burst_count
				_execute_fire(aim_direction)
		FireMode.CHARGE:
			# Charge weapons fire on release, not on press
			return false
		FireMode.SPINUP:
			if spinup_progress >= 1.0:
				_execute_fire(aim_direction)

	return true


## Start holding the trigger (for auto/charge/spinup weapons).
func start_trigger() -> void:
	trigger_held = true

	if fire_mode == FireMode.CHARGE:
		is_charging = true
		charge_progress = 0.0


## Release the trigger.
func release_trigger(aim_direction: Vector3) -> void:
	trigger_held = false

	if fire_mode == FireMode.CHARGE and is_charging:
		if charge_progress >= min_charge_percent:
			_execute_charged_fire(aim_direction)
		is_charging = false
		charge_progress = 0.0
		charge_changed.emit(0.0)

	if fire_mode == FireMode.SPINUP:
		spinup_progress = 0.0
		spinup_changed.emit(0.0)


## Check if the weapon can fire.
func _can_fire() -> bool:
	if is_reloading:
		if can_cancel_reload and current_ammo > 0:
			_cancel_reload()
		else:
			return false

	if fire_cooldown > 0.0:
		return false

	if current_ammo < ammo_per_shot:
		return false

	if fire_mode == FireMode.SPINUP and spinup_progress < 1.0:
		return false

	return true


## Execute the actual fire logic.
func _execute_fire(aim_direction: Vector3) -> void:
	current_ammo -= ammo_per_shot
	fire_cooldown = fire_rate

	# Apply spread
	var spread_direction := _apply_spread(aim_direction)

	# Fire based on weapon type
	match weapon_type:
		WeaponType.HITSCAN:
			_fire_hitscan(spread_direction)
		WeaponType.PROJECTILE:
			_fire_projectile(spread_direction)
		WeaponType.HITSCAN_MULTI:
			_fire_hitscan_multi(aim_direction)

	# Apply recoil
	_apply_recoil()

	# Increase spread
	current_spread = minf(current_spread + spread_increase_per_shot, max_spread)

	# Effects
	_spawn_muzzle_flash()
	_spawn_shell_casing()
	_play_sound(fire_sound)

	fired.emit(self)
	ammo_changed.emit(current_ammo, reserve_ammo, magazine_size)


## Execute charged fire (for CHARGE mode weapons).
func _execute_charged_fire(aim_direction: Vector3) -> void:
	# Damage scales with charge
	var charge_damage_mult := lerpf(0.5, 1.5, charge_progress)
	var original_damage := base_damage
	base_damage *= charge_damage_mult

	_execute_fire(aim_direction)

	base_damage = original_damage


## Fire a single hitscan ray.
func _fire_hitscan(direction: Vector3) -> void:
	if not muzzle_point:
		return

	var origin := muzzle_point.global_position
	var end := origin + direction * max_range

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 0b11  # Players and world
	query.exclude = [get_parent()] if get_parent() is CharacterBody3D else []

	var result := space_state.intersect_ray(query)

	if result:
		_process_hit(result.collider, result.position, result.normal, direction, base_damage)
		_spawn_tracer(origin, result.position)
		_spawn_impact_effect(result.position, result.normal)
	else:
		_spawn_tracer(origin, end)


## Fire multiple hitscan rays (shotgun pattern).
func _fire_hitscan_multi(base_direction: Vector3) -> void:
	for i in pellet_count:
		var pellet_direction := _apply_spread(base_direction)
		_fire_hitscan(pellet_direction)


## Fire a projectile.
func _fire_projectile(direction: Vector3) -> void:
	if not projectile_scene or not muzzle_point:
		return

	var origin := muzzle_point.global_position

	var projectile: Node3D = projectile_scene.instantiate()
	projectile.global_position = origin

	# Set projectile properties (these should be on the projectile script)
	if projectile.has_method("setup"):
		projectile.setup({
			"direction": direction,
			"speed": projectile_speed,
			"damage": base_damage,
			"owner_peer_id": owner_peer_id,
			"arcs": projectile_arcs,
			"gravity_scale": projectile_gravity_scale,
			"penetrates": projectile_penetrates,
			"max_penetrations": max_penetrations,
			"penetration_falloff": penetration_damage_falloff,
			"area_damage": has_area_damage,
			"area_radius": area_damage_radius,
			"area_falloff": area_damage_falloff,
		})
	else:
		# Fallback for simple projectiles
		if projectile.has_method("set"):
			projectile.set("direction", direction)
			projectile.set("speed", projectile_speed)
			projectile.set("damage", base_damage)
			projectile.set("owner_peer_id", owner_peer_id)

	# Add to scene tree
	var projectiles_node := _get_projectiles_node()
	if projectiles_node:
		projectiles_node.add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)


## Process a hit on a target.
func _process_hit(collider: Node3D, hit_position: Vector3, hit_normal: Vector3, direction: Vector3, damage: float) -> void:
	if collider is CharacterBody3D:
		var player := collider as CharacterBody3D

		# Determine hit zone multiplier
		var multiplier := bodyshot_multiplier
		var local_hit := hit_position - collider.global_position
		var hit_height_ratio := local_hit.y / 2.0  # Assuming ~2m character height

		if hit_height_ratio > 0.8:
			multiplier = headshot_multiplier
		elif hit_height_ratio < 0.3:
			multiplier = legshot_multiplier

		var final_damage := damage * multiplier

		# Deal damage via RPC if the target has the method
		if player.has_method("take_damage"):
			player.take_damage(final_damage, owner_peer_id)

# endregion


# region -- Spread System

## Apply spread to a direction vector.
func _apply_spread(direction: Vector3) -> Vector3:
	if current_spread <= 0.0:
		return direction

	var spread_rad := deg_to_rad(current_spread)
	var random_spread := Vector2(
		randf_range(-spread_rad, spread_rad),
		randf_range(-spread_rad, spread_rad)
	)

	# Build rotation from spread
	var right := direction.cross(Vector3.UP).normalized()
	var up := right.cross(direction).normalized()

	var spread_direction := direction.rotated(right, random_spread.x)
	spread_direction = spread_direction.rotated(up, random_spread.y)

	return spread_direction.normalized()


## Process spread recovery over time.
func _process_spread_recovery(delta: float) -> void:
	if not trigger_held or fire_mode == FireMode.SEMI_AUTO:
		current_spread = move_toward(current_spread, base_spread, spread_recovery_rate * delta)

# endregion


# region -- Recoil System

## Apply recoil from firing.
func _apply_recoil() -> void:
	var recoil_offset: Vector2

	if recoil_pattern.size() > 0:
		# Use pattern-based recoil
		recoil_offset = recoil_pattern[recoil_pattern_index]
		recoil_pattern_index = (recoil_pattern_index + 1) % recoil_pattern.size()
	else:
		# Use random recoil within range
		recoil_offset = Vector2(
			randf_range(-horizontal_recoil_range, horizontal_recoil_range),
			vertical_recoil
		)

	current_recoil += recoil_offset


## Process recoil recovery over time.
func _process_recoil_recovery(delta: float) -> void:
	current_recoil = current_recoil.move_toward(Vector2.ZERO, recoil_recovery_rate * delta)

	# Reset pattern index when recoil fully recovers
	if current_recoil == Vector2.ZERO:
		recoil_pattern_index = 0


## Get the current recoil offset for camera/aim adjustment.
func get_recoil_offset() -> Vector2:
	return current_recoil

# endregion


# region -- Reload System

## Attempt to start reloading.
func try_reload() -> bool:
	if is_reloading:
		return false
	if current_ammo >= magazine_size:
		return false
	if reserve_ammo <= 0:
		return false

	_start_reload()
	return true


## Start the reload process.
func _start_reload() -> void:
	is_reloading = true

	if reload_one_at_a_time:
		reload_timer = per_round_reload_time
	else:
		reload_timer = reload_time

	_play_sound(reload_start_sound)
	reload_started.emit(self)


## Process reload timer.
func _process_reload(delta: float) -> void:
	if not is_reloading:
		return

	reload_timer -= delta

	if reload_timer <= 0.0:
		if reload_one_at_a_time:
			_reload_one_round()
		else:
			_complete_reload()


## Reload one round (for shotgun-style reloads).
func _reload_one_round() -> void:
	if reserve_ammo > 0 and current_ammo < magazine_size:
		reserve_ammo -= 1
		current_ammo += 1
		ammo_changed.emit(current_ammo, reserve_ammo, magazine_size)

		if current_ammo < magazine_size and reserve_ammo > 0:
			reload_timer = per_round_reload_time
			return

	_complete_reload()


## Complete the reload process.
func _complete_reload() -> void:
	if not reload_one_at_a_time:
		var ammo_needed := magazine_size - current_ammo
		var ammo_to_add := mini(ammo_needed, reserve_ammo)
		current_ammo += ammo_to_add
		reserve_ammo -= ammo_to_add

	is_reloading = false
	reload_timer = 0.0

	_play_sound(reload_end_sound)
	reload_finished.emit(self)
	ammo_changed.emit(current_ammo, reserve_ammo, magazine_size)


## Cancel an in-progress reload.
func _cancel_reload() -> void:
	is_reloading = false
	reload_timer = 0.0

# endregion


# region -- Cooldowns & Timers

## Process fire cooldown.
func _process_fire_cooldown(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta


## Process spinup for spinup weapons.
func _process_spinup(delta: float) -> void:
	if fire_mode != FireMode.SPINUP:
		return

	if trigger_held:
		var old_progress := spinup_progress
		spinup_progress = minf(spinup_progress + delta / spinup_time, 1.0)
		if spinup_progress != old_progress:
			spinup_changed.emit(spinup_progress)
	else:
		if spinup_progress > 0.0:
			spinup_progress = maxf(spinup_progress - delta / (spinup_time * 0.5), 0.0)
			spinup_changed.emit(spinup_progress)


## Process charge for charge weapons.
func _process_charge(delta: float) -> void:
	if fire_mode != FireMode.CHARGE:
		return

	if is_charging:
		var old_progress := charge_progress
		charge_progress = minf(charge_progress + delta / charge_time, 1.0)
		if charge_progress != old_progress:
			charge_changed.emit(charge_progress)


## Process burst fire.
func _process_burst(delta: float) -> void:
	if fire_mode != FireMode.BURST:
		return

	if burst_shots_remaining > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			burst_shots_remaining -= 1
			if burst_shots_remaining > 0 and current_ammo >= ammo_per_shot:
				# Fire next burst shot
				# Note: Need aim direction passed in - this is a simplification
				burst_timer = burst_delay
				# _execute_fire(aim_direction) -- handled externally

# endregion


# region -- Ammo Management

## Add ammo to reserve.
func add_ammo(amount: int) -> int:
	var space_available := max_reserve_ammo - reserve_ammo
	var ammo_to_add := mini(amount, space_available)
	reserve_ammo += ammo_to_add
	ammo_changed.emit(current_ammo, reserve_ammo, magazine_size)
	return ammo_to_add


## Get current ammo info.
func get_ammo_info() -> Dictionary:
	return {
		"current": current_ammo,
		"magazine": magazine_size,
		"reserve": reserve_ammo,
		"max_reserve": max_reserve_ammo,
	}


## Check if ammo is needed.
func needs_ammo() -> bool:
	return reserve_ammo < max_reserve_ammo

# endregion


# region -- Equipment

## Equip the weapon.
func equip() -> void:
	is_equipped = true
	visible = true
	_play_sound(equip_sound)


## Unequip the weapon.
func unequip() -> void:
	is_equipped = false
	visible = false

	# Reset state
	trigger_held = false
	is_charging = false
	charge_progress = 0.0
	spinup_progress = 0.0
	is_reloading = false


## Set the owner of this weapon.
func set_owner_peer(peer_id: int) -> void:
	owner_peer_id = peer_id

# endregion


# region -- Effects

## Spawn muzzle flash effect.
func _spawn_muzzle_flash() -> void:
	if not muzzle_flash_scene or not muzzle_point:
		return

	var flash: Node3D = muzzle_flash_scene.instantiate()
	muzzle_point.add_child(flash)
	flash.position = Vector3.ZERO


## Spawn shell casing effect.
func _spawn_shell_casing() -> void:
	if not shell_casing_scene or not muzzle_point:
		return

	var casing: Node3D = shell_casing_scene.instantiate()
	get_tree().current_scene.add_child(casing)
	casing.global_position = muzzle_point.global_position


## Spawn tracer effect.
func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	if not tracer_scene:
		return

	var tracer: Node3D = tracer_scene.instantiate()
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = from

	if tracer.has_method("setup"):
		tracer.setup(from, to)


## Spawn impact effect.
func _spawn_impact_effect(position: Vector3, normal: Vector3) -> void:
	if not impact_effect_scene:
		return

	var impact: Node3D = impact_effect_scene.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.global_position = position

	# Orient to surface normal
	if normal != Vector3.UP:
		impact.look_at(position + normal, Vector3.UP)


## Play a sound effect.
func _play_sound(sound_key: StringName) -> void:
	if sound_key.is_empty():
		return

	if AudioManager:
		AudioManager.play_sfx(String(sound_key))

# endregion


# region -- Helpers

## Get the projectiles container node.
func _get_projectiles_node() -> Node:
	var scene := get_tree().current_scene
	if scene and scene.has_node("Projectiles"):
		return scene.get_node("Projectiles")
	return null


## Check if this is running on the server.
func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
