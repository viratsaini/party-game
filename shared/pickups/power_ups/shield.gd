## Shield Power-Up
##
## Grants +50 temporary armor that absorbs damage before health.
## Shield depletes as damage is taken and does not regenerate.
class_name ShieldPickup
extends PickupBase


# region -- Constants

const SHIELD_AMOUNT: float = 50.0

# endregion


# region -- Lifecycle

func _init() -> void:
	pickup_id = "shield"
	display_name = "Shield"
	description = "Grants +50 temporary armor."
	pickup_color = Color(0.3, 0.6, 1.0)  # Blue
	rarity = Rarity.UNCOMMON
	respawn_time = 20.0
	is_timed_effect = false  # Shield is not timed, it depletes with damage
	collect_sound = "pickup_shield"
	show_announcement = true

# endregion


# region -- Effect Implementation

func _apply_effect(character: Node) -> bool:
	# Get status effects manager from the character or game.
	var status_manager: Node = _get_status_manager(character)

	if status_manager and status_manager.has_method("add_shield"):
		status_manager.add_shield(character, SHIELD_AMOUNT)
		return true

	# Fallback: directly modify character if it has shield property.
	if character.has_method("add_shield"):
		character.add_shield(SHIELD_AMOUNT)
		return true

	# Alternative: increase max_health temporarily (legacy behavior).
	var current_max: float = character.get("max_health") if character.get("max_health") != null else 100.0
	character.set("max_health", current_max + SHIELD_AMOUNT)

	var current_health: float = character.get("health") if character.get("health") != null else 100.0
	character.set("health", current_health + SHIELD_AMOUNT)

	if character.has_signal("health_changed"):
		character.health_changed.emit(character.health, character.max_health)

	return true


func _get_status_manager(character: Node) -> Node:
	# Try to get from character.
	if character.has_node("StatusEffects"):
		return character.get_node("StatusEffects")

	# Try to get from autoload.
	return get_node_or_null("/root/StatusEffects")

# endregion
