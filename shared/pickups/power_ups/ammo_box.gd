## Ammo Box Power-Up
##
## Instantly refills all ammunition for the player's weapons.
## Common pickup that spawns frequently in combat zones.
class_name AmmoBoxPickup
extends PickupBase


# region -- Lifecycle

func _init() -> void:
	pickup_id = "ammo_box"
	display_name = "Ammo Box"
	description = "Refills all ammunition."
	pickup_color = Color(0.9, 0.7, 0.2)  # Amber/yellow
	rarity = Rarity.COMMON
	respawn_time = 10.0
	is_timed_effect = false
	collect_sound = "pickup_ammo"
	show_announcement = false  # Common pickup, no announcement needed

# endregion


# region -- Effect Implementation

func _apply_effect(character: Node) -> bool:
	var status_manager: Node = _get_status_manager(character)

	if status_manager and status_manager.has_method("refill_ammo"):
		status_manager.refill_ammo(character)
		return true

	# Fallback: try to refill ammo directly.
	if character.has_method("refill_ammo"):
		character.refill_ammo()
		return true

	# Try weapon-based ammo refill.
	if character.get("current_weapon") != null:
		var weapon: Node = character.get("current_weapon")
		if weapon and weapon.has_method("refill_ammo"):
			weapon.refill_ammo()
			return true

	# Try setting ammo properties directly.
	if character.get("ammo") != null and character.get("max_ammo") != null:
		character.set("ammo", character.get("max_ammo"))
		return true

	# For games that track ammo at the game level.
	var game: Node = get_tree().current_scene
	if game:
		var peer_id: int = character.get("peer_id") if character.get("peer_id") != null else 0
		if game.has_method("refill_player_ammo"):
			game.refill_player_ammo(peer_id)
			return true

	return true  # Still consume the pickup


func _get_status_manager(character: Node) -> Node:
	if character.has_node("StatusEffects"):
		return character.get_node("StatusEffects")
	return get_node_or_null("/root/StatusEffects")

# endregion
