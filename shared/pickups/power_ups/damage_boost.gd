## Damage Boost Power-Up
##
## Doubles all damage dealt for 10 seconds.
## Stacks duration with existing damage boost, not the multiplier.
class_name DamageBoostPickup
extends PickupBase


# region -- Constants

const DAMAGE_MULTIPLIER: float = 2.0
const BOOST_DURATION: float = 10.0

# endregion


# region -- Lifecycle

func _init() -> void:
	pickup_id = "damage_boost"
	display_name = "Damage Boost"
	description = "Deal 2x damage for 10 seconds."
	pickup_color = Color(1.0, 0.3, 0.15)  # Orange-red
	rarity = Rarity.RARE
	respawn_time = 25.0
	is_timed_effect = true
	effect_duration = BOOST_DURATION
	collect_sound = "pickup_damage"
	show_announcement = true

# endregion


# region -- Effect Implementation

func _apply_effect(character: Node) -> bool:
	var status_manager: Node = _get_status_manager(character)

	if status_manager and status_manager.has_method("apply_damage_boost"):
		status_manager.apply_damage_boost(character, DAMAGE_MULTIPLIER, BOOST_DURATION)
		return true

	# Fallback: set damage multiplier on character if it exists.
	if character.get("damage_multiplier") != null:
		character.set("damage_multiplier", DAMAGE_MULTIPLIER)
		_create_effect_timer(character, "damage_multiplier", 1.0)
		return true

	# Try game-level effect tracking.
	var game: Node = get_tree().current_scene
	if game:
		var peer_id: int = character.get("peer_id") if character.get("peer_id") != null else 0
		if game.has_method("apply_damage_boost"):
			game.apply_damage_boost(peer_id, DAMAGE_MULTIPLIER, BOOST_DURATION)
			return true

	return true  # Still consume the pickup


func _get_status_manager(character: Node) -> Node:
	if character.has_node("StatusEffects"):
		return character.get_node("StatusEffects")
	return get_node_or_null("/root/StatusEffects")


func _create_effect_timer(character: Node, property: String, original_value: float) -> void:
	var timer := Timer.new()
	timer.name = "DamageBoostTimer"
	timer.wait_time = BOOST_DURATION
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(character):
			character.set(property, original_value)
		timer.queue_free()
	)
	add_child(timer)
	timer.start()

# endregion
