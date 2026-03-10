## WeaponData - Resource containing all weapon statistics and configurations.
##
## This resource provides centralized weapon data that can be loaded and
## referenced by weapon instances. Supports all 10 weapon types with
## balanced stats based on the game design research document.
class_name WeaponData
extends Resource


# region -- Weapon Database

## Complete weapon database with balanced stats for all 10 weapons.
## Based on party game TTK targets (2.0-4.0 seconds for chaotic fun).
const WEAPONS: Dictionary = {
	# ═══════════════════════════════════════════════════════════════════════════
	# ASSAULT RIFLE - Balanced all-rounder, medium damage, automatic fire
	# ═══════════════════════════════════════════════════════════════════════════
	&"assault_rifle": {
		"weapon_id": &"assault_rifle",
		"weapon_name": "Assault Rifle",
		"weapon_slot": WeaponBase.WeaponSlot.PRIMARY,

		# Damage
		"base_damage": 18.0,
		"headshot_multiplier": 2.0,
		"bodyshot_multiplier": 1.0,
		"legshot_multiplier": 0.75,
		"has_area_damage": false,

		# Fire Rate
		"weapon_type": WeaponBase.WeaponType.HITSCAN,
		"fire_mode": WeaponBase.FireMode.AUTOMATIC,
		"fire_rate": 0.1,  # 10 rounds per second

		# Ammo
		"magazine_size": 30,
		"max_reserve_ammo": 150,
		"starting_reserve_ammo": 90,
		"reload_time": 2.2,
		"reload_one_at_a_time": false,
		"ammo_per_shot": 1,

		# Range & Accuracy
		"max_range": 80.0,
		"base_spread": 0.5,
		"max_spread": 4.0,
		"spread_increase_per_shot": 0.3,
		"spread_recovery_rate": 8.0,
		"movement_spread_multiplier": 1.3,
		"pellet_count": 1,

		# Recoil
		"vertical_recoil": 0.8,
		"horizontal_recoil_range": 0.4,
		"recoil_recovery_rate": 6.0,
		"recoil_pattern": [
			Vector2(0.0, 1.0),
			Vector2(0.2, 0.9),
			Vector2(-0.1, 1.1),
			Vector2(0.3, 0.8),
			Vector2(-0.2, 1.0),
			Vector2(0.1, 0.9),
			Vector2(-0.3, 1.0),
			Vector2(0.2, 0.8),
		],

		# Audio
		"fire_sound": &"ar_fire",
		"reload_start_sound": &"ar_reload_start",
		"reload_end_sound": &"ar_reload_end",
		"equip_sound": &"weapon_equip",
	},

	# ═══════════════════════════════════════════════════════════════════════════
	# SMG - Low damage, very high fire rate, close-mid range
	# ═══════════════════════════════════════════════════════════════════════════
	&"smg": {
		"weapon_id": &"smg",
		"weapon_name": "SMG",
		"weapon_slot": WeaponBase.WeaponSlot.PRIMARY,

		# Damage
		"base_damage": 12.0,
		"headshot_multiplier": 1.75,
		"bodyshot_multiplier": 1.0,
		"legshot_multiplier": 0.8,
		"has_area_damage": false,

		# Fire Rate
		"weapon_type": WeaponBase.WeaponType.HITSCAN,
		"fire_mode": WeaponBase.FireMode.AUTOMATIC,
		"fire_rate": 0.06,  # ~16 rounds per second

		# Ammo
		"magazine_size": 35,
		"max_reserve_ammo": 175,
		"starting_reserve_ammo": 105,
		"reload_time": 1.8,
		"reload_one_at_a_time": false,
		"ammo_per_shot": 1,

		# Range & Accuracy
		"max_range": 50.0,
		"base_spread": 1.0,
		"max_spread": 6.0,
		"spread_increase_per_shot": 0.4,
		"spread_recovery_rate": 12.0,
		"movement_spread_multiplier": 1.1,
		"pellet_count": 1,

		# Recoil
		"vertical_recoil": 0.5,
		"horizontal_recoil_range": 0.6,
		"recoil_recovery_rate": 10.0,
		"recoil_pattern": [
			Vector2(0.1, 0.6),
			Vector2(-0.2, 0.5),
			Vector2(0.15, 0.55),
			Vector2(-0.1, 0.6),
		],

		# Audio
		"fire_sound": &"smg_fire",
		"reload_start_sound": &"smg_reload_start",
		"reload_end_sound": &"smg_reload_end",
		"equip_sound": &"weapon_equip",
	},

	# ═══════════════════════════════════════════════════════════════════════════
	# SHOTGUN - High damage, spread pattern, pump action
	# ═══════════════════════════════════════════════════════════════════════════
	&"shotgun": {
		"weapon_id": &"shotgun",
		"weapon_name": "Shotgun",
		"weapon_slot": WeaponBase.WeaponSlot.PRIMARY,

		# Damage (per pellet)
		"base_damage": 12.0,
		"headshot_multiplier": 1.5,
		"bodyshot_multiplier": 1.0,
		"legshot_multiplier": 0.9,
		"has_area_damage": false,

		# Fire Rate
		"weapon_type": WeaponBase.WeaponType.HITSCAN_MULTI,
		"fire_mode": WeaponBase.FireMode.SEMI_AUTO,
		"fire_rate": 0.9,  # Pump action

		# Ammo
		"magazine_size": 8,
		"max_reserve_ammo": 40,
		"starting_reserve_ammo": 24,
		"reload_time": 3.0,  # Total for full reload
		"reload_one_at_a_time": true,
		"per_round_reload_time": 0.45,
		"can_cancel_reload": true,
		"ammo_per_shot": 1,

		# Range & Accuracy
		"max_range": 25.0,
		"base_spread": 4.0,  # Tight spread
		"max_spread": 8.0,
		"spread_increase_per_shot": 2.0,
		"spread_recovery_rate": 15.0,
		"movement_spread_multiplier": 1.2,
		"pellet_count": 8,

		# Recoil
		"vertical_recoil": 3.0,
		"horizontal_recoil_range": 1.5,
		"recoil_recovery_rate": 4.0,
		"recoil_pattern": [],

		# Audio
		"fire_sound": &"shotgun_fire",
		"reload_start_sound": &"shotgun_reload_shell",
		"reload_end_sound": &"shotgun_pump",
		"equip_sound": &"weapon_equip",
	},

	# ═══════════════════════════════════════════════════════════════════════════
	# SNIPER RIFLE - Very high damage, slow fire rate, hitscan, long range
	# ═══════════════════════════════════════════════════════════════════════════
	&"sniper_rifle": {
		"weapon_id": &"sniper_rifle",
		"weapon_name": "Sniper Rifle",
		"weapon_slot": WeaponBase.WeaponSlot.PRIMARY,

		# Damage
		"base_damage": 85.0,
		"headshot_multiplier": 2.5,  # One-shot headshot potential
		"bodyshot_multiplier": 1.0,
		"legshot_multiplier": 0.65,
		"has_area_damage": false,

		# Fire Rate
		"weapon_type": WeaponBase.WeaponType.HITSCAN,
		"fire_mode": WeaponBase.FireMode.SEMI_AUTO,
		"fire_rate": 1.5,  # Bolt action

		# Ammo
		"magazine_size": 5,
		"max_reserve_ammo": 25,
		"starting_reserve_ammo": 15,
		"reload_time": 3.5,
		"reload_one_at_a_time": false,
		"ammo_per_shot": 1,

		# Range & Accuracy
		"max_range": 150.0,
		"base_spread": 0.0,  # Perfect accuracy when still
		"max_spread": 8.0,
		"spread_increase_per_shot": 5.0,
		"spread_recovery_rate": 4.0,
		"movement_spread_multiplier": 4.0,  # Massive penalty when moving
		"pellet_count": 1,

		# Recoil
		"vertical_recoil": 5.0,
		"horizontal_recoil_range": 1.0,
		"recoil_recovery_rate": 3.0,
		"recoil_pattern": [],

		# Audio
		"fire_sound": &"sniper_fire",
		"reload_start_sound": &"sniper_reload_start",
		"reload_end_sound": &"sniper_bolt",
		"equip_sound": &"weapon_equip_heavy",
	},

	# ═══════════════════════════════════════════════════════════════════════════
	# PISTOL - Medium damage, semi-auto, reliable sidearm
	# ═══════════════════════════════════════════════════════════════════════════
	&"pistol": {
		"weapon_id": &"pistol",
		"weapon_name": "Pistol",
		"weapon_slot": WeaponBase.WeaponSlot.SECONDARY,

		# Damage
		"base_damage": 22.0,
		"headshot_multiplier": 2.0,
		"bodyshot_multiplier": 1.0,
		"legshot_multiplier": 0.8,
		"has_area_damage": false,

		# Fire Rate
		"weapon_type": WeaponBase.WeaponType.HITSCAN,
		"fire_mode": WeaponBase.FireMode.SEMI_AUTO,
		"fire_rate": 0.2,

		# Ammo
		"magazine_size": 12,
		"max_reserve_ammo": 60,
		"starting_reserve_ammo": 36,
		"reload_time": 1.5,
		"reload_one_at_a_time": false,
		"ammo_per_shot": 1,

		# Range & Accuracy
		"max_range": 60.0,
		"base_spread": 0.3,
		"max_spread": 3.0,
		"spread_increase_per_shot": 0.5,
		"spread_recovery_rate": 10.0,
		"movement_spread_multiplier": 1.2,
		"pellet_count": 1,

		# Recoil
		"vertical_recoil": 1.2,
		"horizontal_recoil_range": 0.3,
		"recoil_recovery_rate": 8.0,
		"recoil_pattern": [],

		# Audio
		"fire_sound": &"pistol_fire",
		"reload_start_sound": &"pistol_reload_start",
		"reload_end_sound": &"pistol_reload_end",
		"equip_sound": &"weapon_equip_light",
	},

	# ═══════════════════════════════════════════════════════════════════════════
	# ROCKET LAUNCHER - Explosive projectile, high area damage, slow
	# ═══════════════════════════════════════════════════════════════════════════
	&"rocket_launcher": {
		"weapon_id": &"rocket_launcher",
		"weapon_name": "Rocket Launcher",
		"weapon_slot": WeaponBase.WeaponSlot.SPECIAL,

		# Damage
		"base_damage": 100.0,
		"headshot_multiplier": 1.0,  # No headshots on explosives
		"bodyshot_multiplier": 1.0,
		"legshot_multiplier": 1.0,
		"has_area_damage": true,
		"area_damage_radius": 5.0,
		"area_damage_falloff": 0.4,

		# Fire Rate
		"weapon_type": WeaponBase.WeaponType.PROJECTILE,
		"fire_mode": WeaponBase.FireMode.SEMI_AUTO,
		"fire_rate": 1.2,

		# Ammo
		"magazine_size": 1,
		"max_reserve_ammo": 8,
		"starting_reserve_ammo": 4,
		"reload_time": 2.5,
		"reload_one_at_a_time": false,
		"ammo_per_shot": 1,

		# Range & Accuracy
		"max_range": 100.0,
		"base_spread": 0.0,
		"max_spread": 0.0,
		"spread_increase_per_shot": 0.0,
		"spread_recovery_rate": 0.0,
		"movement_spread_multiplier": 1.0,
		"pellet_count": 1,

		# Projectile
		"projectile_speed": 25.0,
		"projectile_arcs": false,
		"projectile_gravity_scale": 0.0,
		"projectile_penetrates": false,

		# Recoil
		"vertical_recoil": 4.0,
		"horizontal_recoil_range": 2.0,
		"recoil_recovery_rate": 3.0,
		"recoil_pattern": [],

		# Audio
		"fire_sound": &"rocket_fire",
		"reload_start_sound": &"rocket_reload",
		"reload_end_sound": &"rocket_ready",
		"equip_sound": &"weapon_equip_heavy",
	},

	# ═══════════════════════════════════════════════════════════════════════════
	# GRENADE LAUNCHER - Arcing explosive projectiles
	# ═══════════════════════════════════════════════════════════════════════════
	&"grenade_launcher": {
		"weapon_id": &"grenade_launcher",
		"weapon_name": "Grenade Launcher",
		"weapon_slot": WeaponBase.WeaponSlot.SPECIAL,

		# Damage
		"base_damage": 80.0,
		"headshot_multiplier": 1.0,
		"bodyshot_multiplier": 1.0,
		"legshot_multiplier": 1.0,
		"has_area_damage": true,
		"area_damage_radius": 4.0,
		"area_damage_falloff": 0.5,

		# Fire Rate
		"weapon_type": WeaponBase.WeaponType.PROJECTILE,
		"fire_mode": WeaponBase.FireMode.SEMI_AUTO,
		"fire_rate": 0.8,

		# Ammo
		"magazine_size": 6,
		"max_reserve_ammo": 24,
		"starting_reserve_ammo": 12,
		"reload_time": 2.8,
		"reload_one_at_a_time": true,
		"per_round_reload_time": 0.5,
		"can_cancel_reload": true,
		"ammo_per_shot": 1,

		# Range & Accuracy
		"max_range": 60.0,
		"base_spread": 0.0,
		"max_spread": 1.0,
		"spread_increase_per_shot": 0.2,
		"spread_recovery_rate": 5.0,
		"movement_spread_multiplier": 1.1,
		"pellet_count": 1,

		# Projectile
		"projectile_speed": 20.0,
		"projectile_arcs": true,
		"projectile_gravity_scale": 1.0,
		"projectile_penetrates": false,

		# Recoil
		"vertical_recoil": 2.5,
		"horizontal_recoil_range": 1.0,
		"recoil_recovery_rate": 4.0,
		"recoil_pattern": [],

		# Audio
		"fire_sound": &"grenade_fire",
		"reload_start_sound": &"grenade_reload_shell",
		"reload_end_sound": &"grenade_ready",
		"equip_sound": &"weapon_equip_heavy",
	},

	# ═══════════════════════════════════════════════════════════════════════════
	# LMG - Sustained fire, slow reload, large magazine
	# ═══════════════════════════════════════════════════════════════════════════
	&"lmg": {
		"weapon_id": &"lmg",
		"weapon_name": "LMG",
		"weapon_slot": WeaponBase.WeaponSlot.PRIMARY,

		# Damage
		"base_damage": 16.0,
		"headshot_multiplier": 1.75,
		"bodyshot_multiplier": 1.0,
		"legshot_multiplier": 0.8,
		"has_area_damage": false,

		# Fire Rate
		"weapon_type": WeaponBase.WeaponType.HITSCAN,
		"fire_mode": WeaponBase.FireMode.AUTOMATIC,
		"fire_rate": 0.08,  # ~12.5 rounds per second

		# Ammo
		"magazine_size": 100,
		"max_reserve_ammo": 300,
		"starting_reserve_ammo": 200,
		"reload_time": 5.0,  # Very slow reload
		"reload_one_at_a_time": false,
		"ammo_per_shot": 1,

		# Range & Accuracy
		"max_range": 70.0,
		"base_spread": 1.5,
		"max_spread": 5.0,
		"spread_increase_per_shot": 0.15,  # Slow spread buildup
		"spread_recovery_rate": 6.0,
		"movement_spread_multiplier": 1.8,  # Penalized when moving
		"pellet_count": 1,

		# Recoil
		"vertical_recoil": 0.6,
		"horizontal_recoil_range": 0.5,
		"recoil_recovery_rate": 5.0,
		"recoil_pattern": [
			Vector2(0.1, 0.7),
			Vector2(-0.15, 0.6),
			Vector2(0.2, 0.65),
			Vector2(-0.1, 0.7),
			Vector2(0.05, 0.6),
			Vector2(-0.2, 0.65),
		],

		# Audio
		"fire_sound": &"lmg_fire",
		"reload_start_sound": &"lmg_reload_start",
		"reload_end_sound": &"lmg_reload_end",
		"equip_sound": &"weapon_equip_heavy",
	},

	# ═══════════════════════════════════════════════════════════════════════════
	# MINIGUN - Very high fire rate with spinup time
	# ═══════════════════════════════════════════════════════════════════════════
	&"minigun": {
		"weapon_id": &"minigun",
		"weapon_name": "Minigun",
		"weapon_slot": WeaponBase.WeaponSlot.SPECIAL,

		# Damage
		"base_damage": 10.0,
		"headshot_multiplier": 1.5,
		"bodyshot_multiplier": 1.0,
		"legshot_multiplier": 0.85,
		"has_area_damage": false,

		# Fire Rate
		"weapon_type": WeaponBase.WeaponType.HITSCAN,
		"fire_mode": WeaponBase.FireMode.SPINUP,
		"fire_rate": 0.04,  # 25 rounds per second when spun up
		"spinup_time": 1.0,  # 1 second to reach full speed

		# Ammo
		"magazine_size": 200,
		"max_reserve_ammo": 400,
		"starting_reserve_ammo": 200,
		"reload_time": 6.0,  # Very slow reload
		"reload_one_at_a_time": false,
		"ammo_per_shot": 1,

		# Range & Accuracy
		"max_range": 60.0,
		"base_spread": 2.0,
		"max_spread": 6.0,
		"spread_increase_per_shot": 0.08,
		"spread_recovery_rate": 8.0,
		"movement_spread_multiplier": 2.0,  # Heavy movement penalty
		"pellet_count": 1,

		# Recoil
		"vertical_recoil": 0.3,
		"horizontal_recoil_range": 0.4,
		"recoil_recovery_rate": 8.0,
		"recoil_pattern": [],

		# Audio
		"fire_sound": &"minigun_fire",
		"reload_start_sound": &"minigun_reload_start",
		"reload_end_sound": &"minigun_reload_end",
		"equip_sound": &"weapon_equip_heavy",
	},

	# ═══════════════════════════════════════════════════════════════════════════
	# RAILGUN - Penetrating hitscan, charge-up weapon
	# ═══════════════════════════════════════════════════════════════════════════
	&"railgun": {
		"weapon_id": &"railgun",
		"weapon_name": "Railgun",
		"weapon_slot": WeaponBase.WeaponSlot.SPECIAL,

		# Damage (at full charge)
		"base_damage": 120.0,
		"headshot_multiplier": 1.5,
		"bodyshot_multiplier": 1.0,
		"legshot_multiplier": 0.7,
		"has_area_damage": false,

		# Fire Rate
		"weapon_type": WeaponBase.WeaponType.HITSCAN,
		"fire_mode": WeaponBase.FireMode.CHARGE,
		"fire_rate": 0.5,  # Cooldown after shot
		"charge_time": 1.5,  # Time to reach full charge
		"min_charge_percent": 0.3,  # Minimum 30% charge to fire

		# Ammo
		"magazine_size": 3,
		"max_reserve_ammo": 15,
		"starting_reserve_ammo": 9,
		"reload_time": 3.0,
		"reload_one_at_a_time": false,
		"ammo_per_shot": 1,

		# Range & Accuracy
		"max_range": 200.0,  # Very long range
		"base_spread": 0.0,
		"max_spread": 0.0,
		"spread_increase_per_shot": 0.0,
		"spread_recovery_rate": 0.0,
		"movement_spread_multiplier": 1.0,
		"pellet_count": 1,

		# Penetration
		"projectile_penetrates": true,
		"max_penetrations": 3,
		"penetration_damage_falloff": 0.7,

		# Recoil
		"vertical_recoil": 4.0,
		"horizontal_recoil_range": 1.0,
		"recoil_recovery_rate": 3.0,
		"recoil_pattern": [],

		# Audio
		"fire_sound": &"railgun_fire",
		"reload_start_sound": &"railgun_reload",
		"reload_end_sound": &"railgun_ready",
		"equip_sound": &"weapon_equip_heavy",
	},
}

# endregion


# region -- Ammo Types

## Ammo type identifiers for pickup system.
enum AmmoType {
	LIGHT,      ## Pistol, SMG
	MEDIUM,     ## Assault Rifle, LMG
	HEAVY,      ## Sniper, Shotgun
	EXPLOSIVE,  ## Rocket, Grenade Launcher
	ENERGY,     ## Railgun, Minigun
}

## Mapping of weapon IDs to ammo types.
const WEAPON_AMMO_TYPES: Dictionary = {
	&"assault_rifle": AmmoType.MEDIUM,
	&"smg": AmmoType.LIGHT,
	&"shotgun": AmmoType.HEAVY,
	&"sniper_rifle": AmmoType.HEAVY,
	&"pistol": AmmoType.LIGHT,
	&"rocket_launcher": AmmoType.EXPLOSIVE,
	&"grenade_launcher": AmmoType.EXPLOSIVE,
	&"lmg": AmmoType.MEDIUM,
	&"minigun": AmmoType.ENERGY,
	&"railgun": AmmoType.ENERGY,
}

## Amount of ammo per pickup by type.
const AMMO_PICKUP_AMOUNTS: Dictionary = {
	AmmoType.LIGHT: 30,
	AmmoType.MEDIUM: 20,
	AmmoType.HEAVY: 10,
	AmmoType.EXPLOSIVE: 4,
	AmmoType.ENERGY: 25,
}

# endregion


# region -- API Functions

## Get weapon data by ID.
static func get_weapon(weapon_id: StringName) -> Dictionary:
	if WEAPONS.has(weapon_id):
		return WEAPONS[weapon_id].duplicate(true)
	push_warning("WeaponData: Unknown weapon ID '%s'" % weapon_id)
	return {}


## Get all weapon IDs.
static func get_all_weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: StringName in WEAPONS:
		ids.append(key)
	return ids


## Get weapons by slot.
static func get_weapons_by_slot(slot: WeaponBase.WeaponSlot) -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: StringName in WEAPONS:
		if WEAPONS[key]["weapon_slot"] == slot:
			ids.append(key)
	return ids


## Get ammo type for a weapon.
static func get_ammo_type(weapon_id: StringName) -> AmmoType:
	if WEAPON_AMMO_TYPES.has(weapon_id):
		return WEAPON_AMMO_TYPES[weapon_id]
	return AmmoType.MEDIUM


## Get ammo pickup amount for a type.
static func get_ammo_pickup_amount(ammo_type: AmmoType) -> int:
	if AMMO_PICKUP_AMOUNTS.has(ammo_type):
		return AMMO_PICKUP_AMOUNTS[ammo_type]
	return 20


## Apply weapon data to a WeaponBase instance.
static func apply_to_weapon(weapon: WeaponBase, weapon_id: StringName) -> bool:
	var data := get_weapon(weapon_id)
	if data.is_empty():
		return false

	# Apply all properties from data to weapon
	for key: String in data:
		if weapon.get(key) != null:
			weapon.set(key, data[key])

	return true

# endregion
