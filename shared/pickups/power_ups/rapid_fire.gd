## Rapid Fire Power-Up
##
## Reduces weapon cooldown to 0.5x (doubles fire rate) for 8 seconds.
## Great for aggressive players who want sustained damage output.
class_name RapidFirePickup
extends PickupBase


# region -- Constants

const COOLDOWN_MULTIPLIER: float = 0.5  # Half cooldown = double fire rate
const RAPID_FIRE_DURATION: float = 8.0

# endregion


# region -- Lifecycle

func _init() -> void:
	pickup_id = "rapid_fire"
	display_name = "Rapid Fire"
	description = "Double fire rate for 8 seconds."
	pickup_color = Color(1.0, 0.4, 0.1)  # Deep orange
	rarity = Rarity.RARE
	respawn_time = 22.0
	is_timed_effect = true
	effect_duration = RAPID_FIRE_DURATION
	collect_sound = "pickup_rapid_fire"
	show_announcement = true

# endregion


# region -- Effect Implementation

func _apply_effect(character: Node) -> bool:
	var status_manager: Node = _get_status_manager(character)

	if status_manager and status_manager.has_method("apply_rapid_fire"):
		status_manager.apply_rapid_fire(character, COOLDOWN_MULTIPLIER, RAPID_FIRE_DURATION)
		return true

	# Fallback: try game-level rapid fire.
	var game: Node = get_tree().current_scene
	if game:
		var peer_id: int = character.get("peer_id") if character.get("peer_id") != null else 0

		# Check for shoot cooldown tracking in game.
		if game.get("_shoot_cooldown_timers") != null:
			# Set cooldown to a very negative number to effectively disable it.
			var cooldowns: Dictionary = game.get("_shoot_cooldown_timers")
			cooldowns[peer_id] = -999.0

			# Create timer to restore normal cooldown.
			var timer := Timer.new()
			timer.name = "RapidFireTimer_%d" % peer_id
			timer.wait_time = RAPID_FIRE_DURATION
			timer.one_shot = true
			timer.timeout.connect(func() -> void:
				if is_instance_valid(game):
					var cd: Dictionary = game.get("_shoot_cooldown_timers")
					if cd.has(peer_id):
						cd[peer_id] = 0.0
				timer.queue_free()
			)
			add_child(timer)
			timer.start()
			return true

		if game.has_method("apply_rapid_fire"):
			game.apply_rapid_fire(peer_id, COOLDOWN_MULTIPLIER, RAPID_FIRE_DURATION)
			return true

	# Try weapon-level fire rate modification.
	if character.get("fire_rate_multiplier") != null:
		character.set("fire_rate_multiplier", COOLDOWN_MULTIPLIER)

		var timer := Timer.new()
		timer.name = "RapidFireTimer"
		timer.wait_time = RAPID_FIRE_DURATION
		timer.one_shot = true
		timer.timeout.connect(func() -> void:
			if is_instance_valid(character):
				character.set("fire_rate_multiplier", 1.0)
			timer.queue_free()
		)
		add_child(timer)
		timer.start()
		return true

	return true


func _get_status_manager(character: Node) -> Node:
	if character.has_node("StatusEffects"):
		return character.get_node("StatusEffects")
	return get_node_or_null("/root/StatusEffects")

# endregion
