## Adrenaline Power-Up
##
## Boosts ALL stats (speed, damage, defense) for 5 seconds.
## The ultimate power-up that makes the player temporarily overpowered.
class_name AdrenalinePickup
extends PickupBase


# region -- Constants

const ADRENALINE_DURATION: float = 5.0
const SPEED_MULTIPLIER: float = 1.3
const DAMAGE_MULTIPLIER: float = 1.5
const DEFENSE_MULTIPLIER: float = 0.5  # Take 50% less damage
const COOLDOWN_MULTIPLIER: float = 0.7  # 30% faster fire rate

# Visual effect colors
const ADRENALINE_COLOR: Color = Color(1.0, 0.1, 0.1)  # Intense red

# endregion


# region -- Lifecycle

func _init() -> void:
	pickup_id = "adrenaline"
	display_name = "Adrenaline Rush"
	description = "ALL stats boosted for 5 seconds!"
	pickup_color = Color(1.0, 0.1, 0.1)  # Red
	rarity = Rarity.LEGENDARY
	respawn_time = 60.0  # Very rare spawn
	is_timed_effect = true
	effect_duration = ADRENALINE_DURATION
	collect_sound = "pickup_adrenaline"
	show_announcement = true

# endregion


# region -- Effect Implementation

func _apply_effect(character: Node) -> bool:
	var status_manager: Node = _get_status_manager(character)

	if status_manager and status_manager.has_method("apply_adrenaline"):
		status_manager.apply_adrenaline(
			character,
			ADRENALINE_DURATION,
			SPEED_MULTIPLIER,
			DAMAGE_MULTIPLIER,
			DEFENSE_MULTIPLIER
		)
		return true

	# Fallback: apply all effects manually.
	_apply_adrenaline_effect(character)
	return true


func _apply_adrenaline_effect(character: Node) -> void:
	var peer_id: int = character.get("peer_id") if character.get("peer_id") != null else 0

	# Store original values for restoration.
	var original_speed: float = character.get("speed") if character.get("speed") != null else 8.0

	# Apply speed boost.
	character.set("speed", original_speed * SPEED_MULTIPLIER)

	# Apply visual effect (red glow).
	_apply_adrenaline_visual(character, true)

	# Apply game-level effects (damage, cooldown).
	var game: Node = get_tree().current_scene
	if game:
		# Track damage multiplier at game level.
		if not game.get("_damage_multipliers"):
			if game.has_method("set"):
				pass  # Would set up damage tracking
		if game.has_method("set_damage_multiplier"):
			game.set_damage_multiplier(peer_id, DAMAGE_MULTIPLIER)

		# Reduce shoot cooldown.
		if game.get("_shoot_cooldown_timers") != null:
			var cooldowns: Dictionary = game.get("_shoot_cooldown_timers")
			cooldowns[peer_id] = -999.0  # Effectively no cooldown

	# Create timer to restore everything.
	var timer := Timer.new()
	timer.name = "AdrenalineTimer_%d" % peer_id
	timer.wait_time = ADRENALINE_DURATION
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(character):
			# Restore speed.
			character.set("speed", original_speed)

			# Remove visual effect.
			_apply_adrenaline_visual(character, false)

			# Restore game-level effects.
			if is_instance_valid(game):
				if game.has_method("set_damage_multiplier"):
					game.set_damage_multiplier(peer_id, 1.0)
				if game.get("_shoot_cooldown_timers") != null:
					var cd: Dictionary = game.get("_shoot_cooldown_timers")
					if cd.has(peer_id):
						cd[peer_id] = 0.0

		timer.queue_free()
	)
	add_child(timer)
	timer.start()

	# Add screen shake / camera effects for the local player.
	if _is_local_player(peer_id):
		_add_screen_effects()


func _apply_adrenaline_visual(character: Node, enable: bool) -> void:
	for child in character.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child
			if enable:
				var mat := StandardMaterial3D.new()
				var original_mat: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
				if original_mat:
					mat.albedo_color = original_mat.albedo_color.lerp(ADRENALINE_COLOR, 0.3)
				else:
					mat.albedo_color = ADRENALINE_COLOR
				mat.emission_enabled = true
				mat.emission = ADRENALINE_COLOR
				mat.emission_energy_multiplier = 2.0
				mesh.set_meta("pre_adrenaline_material", mesh.material_override)
				mesh.material_override = mat
			else:
				var original = mesh.get_meta("pre_adrenaline_material", null)
				mesh.material_override = original
				mesh.remove_meta("pre_adrenaline_material")


func _add_screen_effects() -> void:
	# Add a brief screen pulse effect.
	# This would integrate with a screen effects system.
	pass


func _is_local_player(peer_id: int) -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return peer_id == multiplayer.get_unique_id()


func _get_status_manager(character: Node) -> Node:
	if character.has_node("StatusEffects"):
		return character.get_node("StatusEffects")
	return get_node_or_null("/root/StatusEffects")

# endregion
