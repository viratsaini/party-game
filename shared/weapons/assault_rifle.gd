## Assault Rifle - Balanced automatic weapon with medium damage and controllable recoil.
##
## The all-rounder of the weapon arsenal. Effective at medium range with
## a manageable recoil pattern that rewards trigger discipline.
class_name AssaultRifle
extends WeaponBase


func _setup_weapon() -> void:
	WeaponData.apply_to_weapon(self, &"assault_rifle")


## Override to provide assault rifle-specific behavior.
func _execute_fire(aim_direction: Vector3) -> void:
	super._execute_fire(aim_direction)

	# Assault rifle has slight accuracy recovery between bursts
	if not trigger_held:
		current_spread = maxf(current_spread - 0.5, base_spread)
