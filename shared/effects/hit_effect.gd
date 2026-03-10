## Reusable hit / impact particle burst.
## Add as a child node or instantiate from code, then call [method trigger].
class_name HitEffect
extends CPUParticles3D


func _ready() -> void:
	# Burst configuration
	amount = 16
	one_shot = true
	explosiveness = 1.0
	lifetime = 0.5
	emitting = false
	visible = false

	# Emission shape — small sphere
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 0.15

	# Velocity — outward burst
	direction = Vector3(0.0, 1.0, 0.0)
	spread = 180.0
	initial_velocity_min = 2.0
	initial_velocity_max = 4.0

	# Size fades out
	scale_amount_min = 0.05
	scale_amount_max = 0.12

	# Gravity pulls particles down slightly
	gravity = Vector3(0.0, -4.0, 0.0)

	# Connect finished signal for auto-hide
	finished.connect(_on_finished)


## Triggers the hit burst at [param pos] with the given [param color].
func trigger(pos: Vector3, color: Color) -> void:
	global_position = pos
	color = color
	color_ramp = null  # Reset any gradient so flat color is used
	self.color = color
	visible = true
	emitting = true


func _on_finished() -> void:
	visible = false
