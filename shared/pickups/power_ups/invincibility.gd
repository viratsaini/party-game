## Invincibility Power-Up
##
## Makes the player immune to all damage for 5 seconds.
## Player glows brightly and cannot be killed during this time.
class_name InvincibilityPickup
extends PickupBase


# region -- Constants

const INVINCIBILITY_DURATION: float = 5.0
const GLOW_COLOR: Color = Color(1.0, 0.85, 0.2)  # Gold
const GLOW_ENERGY: float = 3.0

# endregion


# region -- Lifecycle

func _init() -> void:
	pickup_id = "invincibility"
	display_name = "Invincibility"
	description = "Become immune to damage for 5 seconds."
	pickup_color = Color(1.0, 0.85, 0.2)  # Gold
	rarity = Rarity.EPIC
	respawn_time = 45.0
	is_timed_effect = true
	effect_duration = INVINCIBILITY_DURATION
	collect_sound = "pickup_invincibility"
	show_announcement = true

# endregion


# region -- Effect Implementation

func _apply_effect(character: Node) -> bool:
	var status_manager: Node = _get_status_manager(character)

	if status_manager and status_manager.has_method("apply_invincibility"):
		status_manager.apply_invincibility(character, INVINCIBILITY_DURATION)
		return true

	# Fallback: directly apply invincibility.
	_apply_invincibility_effect(character)
	return true


func _apply_invincibility_effect(character: Node) -> void:
	# Mark character as invincible.
	if character.get("is_invincible") != null:
		character.set("is_invincible", true)

	# Apply golden glow effect to meshes.
	_apply_glow_effect(character, true)

	# Create timer to end invincibility.
	var timer := Timer.new()
	timer.name = "InvincibilityTimer"
	timer.wait_time = INVINCIBILITY_DURATION
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(character):
			if character.get("is_invincible") != null:
				character.set("is_invincible", false)
			_apply_glow_effect(character, false)
		timer.queue_free()
	)
	add_child(timer)
	timer.start()

	# Create pulsing glow effect during invincibility.
	_start_glow_pulse(character, timer)


func _apply_glow_effect(character: Node, enable: bool) -> void:
	for child in character.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child
			if enable:
				var mat := StandardMaterial3D.new()
				# Try to preserve original color.
				var original_mat: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
				if original_mat:
					mat.albedo_color = original_mat.albedo_color
				else:
					mat.albedo_color = Color.WHITE
				mat.emission_enabled = true
				mat.emission = GLOW_COLOR
				mat.emission_energy_multiplier = GLOW_ENERGY
				mesh.set_meta("original_material", mesh.material_override)
				mesh.material_override = mat
			else:
				# Restore original material.
				var original = mesh.get_meta("original_material", null)
				mesh.material_override = original
				mesh.remove_meta("original_material")


func _start_glow_pulse(character: Node, timer: Timer) -> void:
	var pulse_tween := create_tween()
	pulse_tween.set_loops()

	for child in character.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child
			if mesh.material_override and mesh.material_override is StandardMaterial3D:
				var mat: StandardMaterial3D = mesh.material_override
				pulse_tween.parallel().tween_property(
					mat, "emission_energy_multiplier",
					GLOW_ENERGY * 0.5, 0.3
				).set_trans(Tween.TRANS_SINE)

	pulse_tween.chain()

	for child in character.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child
			if mesh.material_override and mesh.material_override is StandardMaterial3D:
				var mat: StandardMaterial3D = mesh.material_override
				pulse_tween.parallel().tween_property(
					mat, "emission_energy_multiplier",
					GLOW_ENERGY, 0.3
				).set_trans(Tween.TRANS_SINE)

	# Stop pulse when timer ends.
	timer.timeout.connect(pulse_tween.kill)


func _get_status_manager(character: Node) -> Node:
	if character.has_node("StatusEffects"):
		return character.get_node("StatusEffects")
	return get_node_or_null("/root/StatusEffects")

# endregion
