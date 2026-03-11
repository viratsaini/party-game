## Health Pack Power-Up
##
## Instantly restores 50 HP to the collecting player.
## Common pickup that spawns frequently and provides reliable healing.
class_name HealthPackPickup
extends PickupBase


# region -- Constants

const HEAL_AMOUNT: float = 50.0

# endregion


# region -- Lifecycle

func _init() -> void:
	pickup_id = "health_pack"
	display_name = "Health Pack"
	description = "Restores 50 HP instantly."
	pickup_color = Color(0.2, 1.0, 0.3)  # Bright green
	rarity = Rarity.COMMON
	respawn_time = 12.0
	is_timed_effect = false
	collect_sound = "pickup_health"
	show_announcement = false  # Health is common, no need to announce

# endregion


# region -- Effect Implementation

func _apply_effect(character: Node) -> bool:
	# Check if player needs healing.
	var current_health: float = character.get("health") if character.get("health") != null else 100.0
	var max_health: float = character.get("max_health") if character.get("max_health") != null else 100.0

	# Don't pick up if at full health.
	if current_health >= max_health:
		return false

	# Apply healing.
	if character.has_method("heal"):
		character.heal(HEAL_AMOUNT)
		return true

	return false

# endregion
