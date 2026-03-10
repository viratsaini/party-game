## Bigger elimination burst effect used when a player is knocked out.
## Call [method trigger] to fire the one-shot particle burst.
class_name EliminationEffect
extends CPUParticles3D


func _ready() -> void:
	# Burst configuration
	amount = 32
	one_shot = true
	explosiveness = 1.0
	lifetime = 1.0
	emitting = false
	visible = false

	# Emission shape — larger sphere
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 0.4

	# Velocity — strong outward + upward
	direction = Vector3(0.0, 1.0, 0.0)
	spread = 150.0
	initial_velocity_min = 3.0
	initial_velocity_max = 7.0

	# Size
	scale_amount_min = 0.08
	scale_amount_max = 0.2

	# Gravity pulls particles back down
	gravity = Vector3(0.0, -9.8, 0.0)

	# Slight damping for a more dramatic arc
	damping_min = 1.0
	damping_max = 2.0

	# Connect finished signal for auto-hide
	finished.connect(_on_finished)


## Triggers the elimination burst at [param pos] with the given [param color].
func trigger(pos: Vector3, color: Color) -> void:
	global_position = pos
	color_ramp = null  # Reset any gradient so flat color is used
	self.color = color
	visible = true
	emitting = true


func _on_finished() -> void:
	visible = false
