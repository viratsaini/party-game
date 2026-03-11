## Double Jump Power-Up
##
## Grants the temporary ability to jump again while in the air.
## Effect lasts for 12 seconds, allowing multiple double jumps.
class_name DoubleJumpPickup
extends PickupBase


# region -- Constants

const DOUBLE_JUMP_DURATION: float = 12.0
const JUMP_COUNT: int = 2  # Total jumps allowed (1 ground + 1 air)

# endregion


# region -- Lifecycle

func _init() -> void:
	pickup_id = "double_jump"
	display_name = "Double Jump"
	description = "Jump again in mid-air for 12 seconds."
	pickup_color = Color(1.0, 0.5, 1.0)  # Pink/magenta
	rarity = Rarity.UNCOMMON
	respawn_time = 20.0
	is_timed_effect = true
	effect_duration = DOUBLE_JUMP_DURATION
	collect_sound = "pickup_double_jump"
	show_announcement = true

# endregion


# region -- Effect Implementation

func _apply_effect(character: Node) -> bool:
	var status_manager: Node = _get_status_manager(character)

	if status_manager and status_manager.has_method("apply_double_jump"):
		status_manager.apply_double_jump(character, DOUBLE_JUMP_DURATION)
		return true

	# Fallback: set double jump property on character.
	_apply_double_jump_effect(character)
	return true


func _apply_double_jump_effect(character: Node) -> void:
	# Enable double jump on character.
	if character.get("max_jumps") != null:
		var original_jumps: int = character.get("max_jumps")
		character.set("max_jumps", JUMP_COUNT)

		# Create timer to restore original jump count.
		var timer := Timer.new()
		timer.name = "DoubleJumpTimer"
		timer.wait_time = DOUBLE_JUMP_DURATION
		timer.one_shot = true
		timer.timeout.connect(func() -> void:
			if is_instance_valid(character):
				character.set("max_jumps", original_jumps)
			timer.queue_free()
		)
		add_child(timer)
		timer.start()
		return

	# Alternative: set has_double_jump flag.
	if character.get("has_double_jump") != null:
		character.set("has_double_jump", true)

		var timer := Timer.new()
		timer.name = "DoubleJumpTimer"
		timer.wait_time = DOUBLE_JUMP_DURATION
		timer.one_shot = true
		timer.timeout.connect(func() -> void:
			if is_instance_valid(character):
				character.set("has_double_jump", false)
			timer.queue_free()
		)
		add_child(timer)
		timer.start()
		return

	# Notify game scene to track double jump.
	var game: Node = get_tree().current_scene
	if game:
		var peer_id: int = character.get("peer_id") if character.get("peer_id") != null else 0
		if game.has_method("apply_double_jump"):
			game.apply_double_jump(peer_id, DOUBLE_JUMP_DURATION)


func _get_status_manager(character: Node) -> Node:
	if character.has_node("StatusEffects"):
		return character.get_node("StatusEffects")
	return get_node_or_null("/root/StatusEffects")

# endregion
