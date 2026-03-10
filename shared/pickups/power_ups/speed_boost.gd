## Speed Boost Power-Up
##
## Increases movement speed by 1.5x for 8 seconds.
## Stacks duration with existing speed boost, not the multiplier.
class_name SpeedBoostPickup
extends PickupBase


# region -- Constants

const SPEED_MULTIPLIER: float = 1.5
const BOOST_DURATION: float = 8.0

# endregion


# region -- Lifecycle

func _init() -> void:
	pickup_id = "speed_boost"
	display_name = "Speed Boost"
	description = "Move 50% faster for 8 seconds."
	pickup_color = Color(0.3, 0.9, 1.0)  # Cyan
	rarity = Rarity.UNCOMMON
	respawn_time = 18.0
	is_timed_effect = true
	effect_duration = BOOST_DURATION
	collect_sound = "pickup_speed"
	show_announcement = true

# endregion


# region -- Effect Implementation

func _apply_effect(character: Node) -> bool:
	var status_manager: Node = _get_status_manager(character)

	if status_manager and status_manager.has_method("apply_speed_boost"):
		status_manager.apply_speed_boost(character, SPEED_MULTIPLIER, BOOST_DURATION)
		return true

	# Fallback: direct speed modification.
	var base_speed: float = character.get("speed") if character.get("speed") != null else 8.0
	character.set("speed", base_speed * SPEED_MULTIPLIER)

	# Schedule reset via the game scene.
	var game: Node = get_tree().current_scene
	if game and game.has_method("_create_timed_reset"):
		var peer_id: int = character.get("peer_id") if character.get("peer_id") != null else 0
		game._create_timed_reset(peer_id, "speed", base_speed, BOOST_DURATION)
	else:
		# Create our own timer for reset.
		_create_effect_timer(character, "speed", base_speed)

	return true


func _get_status_manager(character: Node) -> Node:
	if character.has_node("StatusEffects"):
		return character.get_node("StatusEffects")
	return get_node_or_null("/root/StatusEffects")


func _create_effect_timer(character: Node, property: String, original_value: float) -> void:
	var timer := Timer.new()
	timer.name = "SpeedBoostTimer"
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
