## Invisibility Power-Up
##
## Makes the player invisible to enemies for 6 seconds.
## Player becomes semi-visible when attacking or taking damage.
class_name InvisibilityPickup
extends PickupBase


# region -- Constants

const INVISIBILITY_DURATION: float = 6.0
const INVISIBLE_ALPHA: float = 0.1
const ATTACKING_ALPHA: float = 0.4

# endregion


# region -- Lifecycle

func _init() -> void:
	pickup_id = "invisibility"
	display_name = "Invisibility"
	description = "Become invisible for 6 seconds."
	pickup_color = Color(0.7, 0.5, 1.0)  # Purple
	rarity = Rarity.RARE
	respawn_time = 30.0
	is_timed_effect = true
	effect_duration = INVISIBILITY_DURATION
	collect_sound = "pickup_invisibility"
	show_announcement = true

# endregion


# region -- Effect Implementation

func _apply_effect(character: Node) -> bool:
	var status_manager: Node = _get_status_manager(character)

	if status_manager and status_manager.has_method("apply_invisibility"):
		status_manager.apply_invisibility(character, INVISIBILITY_DURATION)
		return true

	# Fallback: directly modify character visibility.
	_apply_invisibility_effect(character)
	return true


func _apply_invisibility_effect(character: Node) -> void:
	# Get the peer_id to check if this is the local player.
	var peer_id: int = character.get("peer_id") if character.get("peer_id") != null else 0
	var is_local: bool = _is_local_player(peer_id)

	# Set visibility based on whether this is the local player.
	var target_alpha: float = 0.3 if is_local else INVISIBLE_ALPHA

	# Apply to all mesh children.
	_set_character_alpha(character, target_alpha)

	# Mark character as invisible for gameplay purposes.
	if character.get("is_invisible") != null:
		character.set("is_invisible", true)

	# Create timer to restore visibility.
	var timer := Timer.new()
	timer.name = "InvisibilityTimer"
	timer.wait_time = INVISIBILITY_DURATION
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(character):
			_set_character_alpha(character, 1.0)
			if character.get("is_invisible") != null:
				character.set("is_invisible", false)
		timer.queue_free()
	)
	add_child(timer)
	timer.start()


func _set_character_alpha(character: Node, alpha: float) -> void:
	# Find all mesh instances in the character.
	for child in character.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child
			var mat: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
			if mat:
				var new_mat := mat.duplicate() as StandardMaterial3D
				new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				new_mat.albedo_color.a = alpha
				mesh.material_override = new_mat
			else:
				# Create a new transparent material.
				var new_mat := StandardMaterial3D.new()
				new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				new_mat.albedo_color = Color(1, 1, 1, alpha)
				mesh.material_override = new_mat


func _is_local_player(peer_id: int) -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return peer_id == multiplayer.get_unique_id()


func _get_status_manager(character: Node) -> Node:
	if character.has_node("StatusEffects"):
		return character.get_node("StatusEffects")
	return get_node_or_null("/root/StatusEffects")

# endregion
