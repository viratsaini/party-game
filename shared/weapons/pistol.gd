## Pistol - Reliable semi-automatic sidearm.
##
## The trusty backup weapon. Moderate damage with good accuracy
## and fast reload. Always available when primary is empty.
class_name Pistol
extends WeaponBase


## Bonus damage on consecutive hits (stacking).
var consecutive_hits: int = 0

## Time since last hit for combo tracking.
var combo_timer: float = 0.0

## Combo timeout in seconds.
const COMBO_TIMEOUT: float = 1.5

## Maximum combo stacks.
const MAX_COMBO: int = 3

## Damage bonus per combo stack.
const COMBO_DAMAGE_BONUS: float = 0.1


func _setup_weapon() -> void:
	WeaponData.apply_to_weapon(self, &"pistol")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Decay combo timer
	if consecutive_hits > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			consecutive_hits = 0


## Override hit processing to track combos.
func _process_hit(collider: Node3D, hit_position: Vector3, hit_normal: Vector3, direction: Vector3, damage: float) -> void:
	if collider is CharacterBody3D:
		# Apply combo bonus
		var combo_mult := 1.0 + (COMBO_DAMAGE_BONUS * consecutive_hits)
		var boosted_damage := damage * combo_mult

		# Increment combo
		consecutive_hits = mini(consecutive_hits + 1, MAX_COMBO)
		combo_timer = COMBO_TIMEOUT

		super._process_hit(collider, hit_position, hit_normal, direction, boosted_damage)
	else:
		super._process_hit(collider, hit_position, hit_normal, direction, damage)


## Pistol draws quickly.
func equip() -> void:
	super.equip()
	# Pistol has faster equip time (handled by animation speed if available)


## Reset combo on weapon switch.
func unequip() -> void:
	consecutive_hits = 0
	combo_timer = 0.0
	super.unequip()
