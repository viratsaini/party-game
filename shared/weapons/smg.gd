## SMG - High fire rate submachine gun with low damage per bullet.
##
## Excels in close-quarters combat with its fast fire rate.
## High spread when sustained fire, but very mobile.
class_name SMG
extends WeaponBase


func _setup_weapon() -> void:
	WeaponData.apply_to_weapon(self, &"smg")


## SMG has faster spread recovery when not firing.
func _process_spread_recovery(delta: float) -> void:
	if not trigger_held:
		# SMG recovers spread 50% faster than normal
		current_spread = move_toward(current_spread, base_spread, spread_recovery_rate * 1.5 * delta)
	else:
		super._process_spread_recovery(delta)
