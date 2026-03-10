## ParticleEffectsManager — Manages particle effects and visual polish
extends Node

# Particle effect presets
enum ParticleType {
	SPARKLE,
	CONFETTI,
	SMOKE,
	EXPLOSION,
	STARS,
	HEARTS
}

func create_particle_effect(type: ParticleType, position: Vector2, parent: Node = null) -> void:
	if parent == null:
		parent = get_tree().root

	var particles: CPUParticles2D = _create_particles_for_type(type)
	particles.position = position
	particles.emitting = true
	particles.one_shot = true

	parent.add_child(particles)

	# Auto-remove after lifetime
	await get_tree().create_timer(particles.lifetime * 2).timeout
	particles.queue_free()

func _create_particles_for_type(type: ParticleType) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = 30
	particles.lifetime = 1.5
	particles.explosiveness = 0.8

	match type:
		ParticleType.SPARKLE:
			particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = 20.0
			particles.direction = Vector2(0, -1)
			particles.spread = 45.0
			particles.gravity = Vector2(0, 50)
			particles.initial_velocity_min = 100.0
			particles.initial_velocity_max = 200.0
			particles.scale_amount_min = 0.5
			particles.scale_amount_max = 1.5
			particles.color = Color(1, 1, 0.5, 1)

		ParticleType.CONFETTI:
			particles.amount = 50
			particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = 30.0
			particles.direction = Vector2(0, -1)
			particles.spread = 180.0
			particles.gravity = Vector2(0, 200)
			particles.initial_velocity_min = 150.0
			particles.initial_velocity_max = 300.0
			particles.angular_velocity_min = -720.0
			particles.angular_velocity_max = 720.0
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 4.0
			particles.color_ramp = _create_rainbow_gradient()

		ParticleType.SMOKE:
			particles.amount = 20
			particles.lifetime = 2.0
			particles.direction = Vector2(0, -1)
			particles.spread = 30.0
			particles.gravity = Vector2(0, -30)
			particles.initial_velocity_min = 30.0
			particles.initial_velocity_max = 60.0
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 4.0
			particles.color = Color(0.5, 0.5, 0.5, 0.5)

		ParticleType.EXPLOSION:
			particles.amount = 40
			particles.lifetime = 1.0
			particles.explosiveness = 1.0
			particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = 10.0
			particles.direction = Vector2(0, 0)
			particles.spread = 180.0
			particles.gravity = Vector2(0, 100)
			particles.initial_velocity_min = 200.0
			particles.initial_velocity_max = 400.0
			particles.scale_amount_min = 1.0
			particles.scale_amount_max = 3.0
			particles.color_ramp = _create_fire_gradient()

		ParticleType.STARS:
			particles.amount = 25
			particles.direction = Vector2(0, -1)
			particles.spread = 60.0
			particles.gravity = Vector2(0, 30)
			particles.initial_velocity_min = 120.0
			particles.initial_velocity_max = 180.0
			particles.scale_amount_min = 1.0
			particles.scale_amount_max = 2.0
			particles.color = Color(1, 1, 0.8, 1)

		ParticleType.HEARTS:
			particles.amount = 15
			particles.lifetime = 2.0
			particles.direction = Vector2(0, -1)
			particles.spread = 40.0
			particles.gravity = Vector2(0, -20)
			particles.initial_velocity_min = 80.0
			particles.initial_velocity_max = 120.0
			particles.scale_amount_min = 1.5
			particles.scale_amount_max = 2.5
			particles.color = Color(1, 0.3, 0.4, 1)

	return particles

func _create_rainbow_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.RED)
	gradient.add_point(0.2, Color.ORANGE)
	gradient.add_point(0.4, Color.YELLOW)
	gradient.add_point(0.6, Color.GREEN)
	gradient.add_point(0.8, Color.BLUE)
	gradient.add_point(1.0, Color.PURPLE)
	return gradient

func _create_fire_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 0.5, 1))
	gradient.add_point(0.5, Color(1, 0.5, 0, 1))
	gradient.add_point(1.0, Color(0.5, 0, 0, 0))
	return gradient

func create_button_click_effect(button: Control) -> void:
	if not button:
		return

	var global_pos: Vector2 = button.global_position + button.size / 2
	create_particle_effect(ParticleType.SPARKLE, global_pos, button.get_parent())

func create_victory_effect(position: Vector2, parent: Node = null) -> void:
	create_particle_effect(ParticleType.CONFETTI, position, parent)
	create_particle_effect(ParticleType.STARS, position, parent)
