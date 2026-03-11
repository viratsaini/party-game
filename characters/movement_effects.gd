## MovementEffects - Visual and audio feedback for player movement.
## Creates particles, sounds, and visual polish for responsive game feel.
class_name MovementEffects
extends Node3D

#region Signals
signal footstep_played(foot: int, surface_type: SurfaceType)
signal effect_spawned(effect_type: String, position: Vector3)
#endregion

#region Enums
enum SurfaceType {
	DEFAULT,
	GRASS,
	DIRT,
	STONE,
	METAL,
	WOOD,
	WATER,
	SAND,
}

enum FootstepFoot {
	LEFT,
	RIGHT,
}
#endregion

#region Exports
## Reference to the player character (parent).
@export var character: CharacterBody3D

## Particle emission settings.
@export_group("Particles")
@export var dust_particle_scene: PackedScene
@export var slide_particle_scene: PackedScene
@export var impact_particle_scene: PackedScene
@export var double_jump_particle_scene: PackedScene
@export var wall_jump_particle_scene: PackedScene
@export var speed_lines_scene: PackedScene

## Audio settings.
@export_group("Audio")
@export var footstep_sounds: Dictionary = {}  # SurfaceType -> Array[AudioStream]
@export var jump_sound: AudioStream
@export var double_jump_sound: AudioStream
@export var wall_jump_sound: AudioStream
@export var land_soft_sound: AudioStream
@export var land_hard_sound: AudioStream
@export var slide_sound: AudioStream
@export var roll_sound: AudioStream
@export var dive_sound: AudioStream
@export var crouch_sound: AudioStream
@export var sprint_loop: AudioStream

## Timing settings.
@export_group("Timing")
@export var footstep_walk_interval: float = 0.5
@export var footstep_run_interval: float = 0.35
@export var footstep_sprint_interval: float = 0.25
@export var footstep_crouch_interval: float = 0.7

## Visual polish.
@export_group("Visual Polish")
@export var enable_screen_shake: bool = true
@export var enable_speed_lines: bool = true
@export var landing_squash_amount: float = 0.15
@export var jump_stretch_amount: float = 0.1
#endregion

#region Internal State
var _movement_state_machine: MovementStateMachine
var _footstep_timer: float = 0.0
var _current_foot: FootstepFoot = FootstepFoot.LEFT
var _current_surface: SurfaceType = SurfaceType.DEFAULT
var _is_moving: bool = false
var _horizontal_speed: float = 0.0
var _slide_particles: GPUParticles3D
var _speed_lines: GPUParticles3D
var _sprint_audio_player: AudioStreamPlayer3D
var _squash_stretch_tween: Tween

## Foot positions relative to character.
const LEFT_FOOT_OFFSET: Vector3 = Vector3(-0.15, 0.0, 0.0)
const RIGHT_FOOT_OFFSET: Vector3 = Vector3(0.15, 0.0, 0.0)

## Particle colors.
const DUST_COLOR_DEFAULT: Color = Color(0.6, 0.55, 0.5, 0.7)
const DUST_COLOR_GRASS: Color = Color(0.3, 0.5, 0.2, 0.6)
const DUST_COLOR_DIRT: Color = Color(0.5, 0.35, 0.2, 0.8)
const DUST_COLOR_SAND: Color = Color(0.9, 0.8, 0.5, 0.7)
const DUST_COLOR_WATER: Color = Color(0.4, 0.6, 0.9, 0.8)
#endregion


func _ready() -> void:
	if not character:
		character = get_parent() as CharacterBody3D

	_setup_audio_players()
	_setup_continuous_particles()


func _setup_audio_players() -> void:
	# Create sprint loop audio player.
	_sprint_audio_player = AudioStreamPlayer3D.new()
	_sprint_audio_player.name = "SprintAudio"
	_sprint_audio_player.bus = &"SFX"
	_sprint_audio_player.max_distance = 20.0
	_sprint_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_sprint_audio_player)


func _setup_continuous_particles() -> void:
	# Setup slide particles (continuous while sliding).
	if slide_particle_scene:
		_slide_particles = slide_particle_scene.instantiate() as GPUParticles3D
		if _slide_particles:
			_slide_particles.emitting = false
			add_child(_slide_particles)
	else:
		_slide_particles = _create_default_slide_particles()

	# Setup speed lines (continuous while sprinting fast).
	if speed_lines_scene:
		_speed_lines = speed_lines_scene.instantiate() as GPUParticles3D
		if _speed_lines:
			_speed_lines.emitting = false
			add_child(_speed_lines)
	else:
		_speed_lines = _create_default_speed_lines()


## Connect to a movement state machine for automatic effects.
func connect_to_state_machine(state_machine: MovementStateMachine) -> void:
	_movement_state_machine = state_machine

	# Connect signals.
	state_machine.state_changed.connect(_on_state_changed)
	state_machine.special_move_performed.connect(_on_special_move)
	state_machine.landed.connect(_on_landed)
	state_machine.wall_contact_changed.connect(_on_wall_contact_changed)


## Update effects each physics frame.
func _physics_process(delta: float) -> void:
	if not character:
		return

	# Calculate horizontal speed.
	var horizontal_vel := Vector2(character.velocity.x, character.velocity.z)
	_horizontal_speed = horizontal_vel.length()
	_is_moving = _horizontal_speed > 0.5

	# Update footsteps.
	if character.is_on_floor() and _is_moving:
		_update_footsteps(delta)

	# Update continuous effects.
	_update_continuous_effects()

	# Update surface detection.
	_update_surface_detection()


## Update footstep timing and playback.
func _update_footsteps(delta: float) -> void:
	if not _movement_state_machine:
		return

	# Determine interval based on state.
	var interval: float
	match _movement_state_machine.current_state:
		MovementStateMachine.MovementState.WALKING:
			interval = footstep_walk_interval
		MovementStateMachine.MovementState.RUNNING:
			interval = footstep_run_interval
		MovementStateMachine.MovementState.SPRINTING:
			interval = footstep_sprint_interval
		MovementStateMachine.MovementState.CROUCH_WALKING:
			interval = footstep_crouch_interval
		_:
			return  # No footsteps in this state.

	_footstep_timer += delta
	if _footstep_timer >= interval:
		_footstep_timer = 0.0
		_play_footstep()


## Play a footstep sound and effect.
func _play_footstep() -> void:
	# Alternate feet.
	_current_foot = FootstepFoot.RIGHT if _current_foot == FootstepFoot.LEFT else FootstepFoot.LEFT

	# Get foot position.
	var foot_offset := LEFT_FOOT_OFFSET if _current_foot == FootstepFoot.LEFT else RIGHT_FOOT_OFFSET
	var foot_pos := character.global_position + character.global_transform.basis * foot_offset

	# Play sound.
	var sound := _get_footstep_sound(_current_surface)
	if sound:
		_play_sound_3d(sound, foot_pos, -5.0)

	# Spawn small dust puff.
	_spawn_footstep_dust(foot_pos)

	footstep_played.emit(_current_foot, _current_surface)


## Get the appropriate footstep sound for the surface.
func _get_footstep_sound(surface: SurfaceType) -> AudioStream:
	if footstep_sounds.has(surface):
		var sounds: Array = footstep_sounds[surface]
		if sounds.size() > 0:
			return sounds[randi() % sounds.size()]

	# Fallback to default.
	if footstep_sounds.has(SurfaceType.DEFAULT):
		var sounds: Array = footstep_sounds[SurfaceType.DEFAULT]
		if sounds.size() > 0:
			return sounds[randi() % sounds.size()]

	return null


## Spawn a small dust puff at foot position.
func _spawn_footstep_dust(pos: Vector3) -> void:
	var particles := _create_dust_burst(5, 0.3, 0.5)
	particles.global_position = pos
	particles.modulate = _get_surface_dust_color(_current_surface)
	get_tree().current_scene.add_child(particles)

	# Auto-cleanup.
	var timer := get_tree().create_timer(particles.lifetime * 2)
	timer.timeout.connect(particles.queue_free)


## Update continuous particle effects.
func _update_continuous_effects() -> void:
	if not _movement_state_machine:
		return

	# Slide particles.
	if _slide_particles:
		var should_emit := _movement_state_machine.current_state == MovementStateMachine.MovementState.SLIDING
		if _slide_particles.emitting != should_emit:
			_slide_particles.emitting = should_emit
		if should_emit:
			_slide_particles.global_position = character.global_position

	# Speed lines.
	if _speed_lines and enable_speed_lines:
		var should_emit := _horizontal_speed > MovementStateMachine.SPRINT_SPEED * 0.9
		if _speed_lines.emitting != should_emit:
			_speed_lines.emitting = should_emit


## Update surface type detection via raycast.
func _update_surface_detection() -> void:
	if not character.is_on_floor():
		return

	# Cast ray downward to detect surface.
	var space_state := character.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		character.global_position,
		character.global_position + Vector3.DOWN * 0.5
	)
	query.exclude = [character.get_rid()]

	var result := space_state.intersect_ray(query)
	if result:
		_current_surface = _detect_surface_type(result)


## Detect surface type from raycast result.
func _detect_surface_type(raycast_result: Dictionary) -> SurfaceType:
	var collider: Object = raycast_result.get("collider")
	if not collider:
		return SurfaceType.DEFAULT

	# Check for surface_type metadata.
	if collider.has_meta("surface_type"):
		var surface_name: String = collider.get_meta("surface_type")
		return _surface_name_to_type(surface_name)

	# Check for group-based detection.
	if collider is Node:
		var node := collider as Node
		if node.is_in_group("grass"):
			return SurfaceType.GRASS
		if node.is_in_group("dirt"):
			return SurfaceType.DIRT
		if node.is_in_group("stone"):
			return SurfaceType.STONE
		if node.is_in_group("metal"):
			return SurfaceType.METAL
		if node.is_in_group("wood"):
			return SurfaceType.WOOD
		if node.is_in_group("water"):
			return SurfaceType.WATER
		if node.is_in_group("sand"):
			return SurfaceType.SAND

	return SurfaceType.DEFAULT


## Convert surface name string to enum.
func _surface_name_to_type(name: String) -> SurfaceType:
	match name.to_lower():
		"grass":
			return SurfaceType.GRASS
		"dirt":
			return SurfaceType.DIRT
		"stone", "rock":
			return SurfaceType.STONE
		"metal":
			return SurfaceType.METAL
		"wood":
			return SurfaceType.WOOD
		"water":
			return SurfaceType.WATER
		"sand":
			return SurfaceType.SAND
		_:
			return SurfaceType.DEFAULT


## Get dust color for surface type.
func _get_surface_dust_color(surface: SurfaceType) -> Color:
	match surface:
		SurfaceType.GRASS:
			return DUST_COLOR_GRASS
		SurfaceType.DIRT:
			return DUST_COLOR_DIRT
		SurfaceType.SAND:
			return DUST_COLOR_SAND
		SurfaceType.WATER:
			return DUST_COLOR_WATER
		_:
			return DUST_COLOR_DEFAULT


#region State Change Handlers

func _on_state_changed(from_state: MovementStateMachine.MovementState, to_state: MovementStateMachine.MovementState) -> void:
	# Handle state transitions with effects.
	match to_state:
		MovementStateMachine.MovementState.JUMPING:
			_on_jump_start()
		MovementStateMachine.MovementState.SPRINTING:
			_start_sprint_effects()
		MovementStateMachine.MovementState.CROUCHING:
			if crouch_sound:
				_play_sound_3d(crouch_sound, character.global_position, -3.0)

	# Handle leaving states.
	match from_state:
		MovementStateMachine.MovementState.SPRINTING:
			_stop_sprint_effects()


func _on_special_move(move_type: MovementStateMachine.SpecialMove) -> void:
	match move_type:
		MovementStateMachine.SpecialMove.DOUBLE_JUMP:
			_on_double_jump()
		MovementStateMachine.SpecialMove.WALL_JUMP:
			_on_wall_jump()
		MovementStateMachine.SpecialMove.SLIDE:
			_on_slide_start()
		MovementStateMachine.SpecialMove.DIVE:
			_on_dive_start()
		MovementStateMachine.SpecialMove.ROLL:
			_on_roll_start()


func _on_landed(intensity: float) -> void:
	var pos := character.global_position

	# Play landing sound.
	var sound := land_hard_sound if intensity > 0.7 else land_soft_sound
	if sound:
		_play_sound_3d(sound, pos, lerp(-10.0, 0.0, intensity))

	# Spawn landing dust.
	var particle_count := int(lerp(8.0, 25.0, intensity))
	var dust := _create_dust_burst(particle_count, 0.4 + intensity * 0.3, 0.8 + intensity * 0.5)
	dust.global_position = pos
	dust.modulate = _get_surface_dust_color(_current_surface)
	get_tree().current_scene.add_child(dust)

	var timer := get_tree().create_timer(dust.lifetime * 2)
	timer.timeout.connect(dust.queue_free)

	# Apply squash effect.
	if landing_squash_amount > 0.0:
		_apply_squash_stretch(1.0 + intensity * landing_squash_amount, 1.0 - intensity * landing_squash_amount * 0.5)

	# Screen shake for hard landing.
	if enable_screen_shake and intensity > 0.5:
		_request_screen_shake(intensity * 5.0, 0.2)

	effect_spawned.emit("landing_dust", pos)


func _on_wall_contact_changed(is_touching: bool, wall_normal: Vector3) -> void:
	if is_touching:
		# Wall touch effect.
		var contact_pos := character.global_position + wall_normal * -0.3
		_spawn_wall_dust(contact_pos, wall_normal)

#endregion

#region Effect Implementations

func _on_jump_start() -> void:
	var pos := character.global_position

	# Play jump sound.
	if jump_sound:
		_play_sound_3d(jump_sound, pos, -5.0)

	# Spawn jump dust.
	var dust := _create_dust_burst(10, 0.3, 0.6)
	dust.global_position = pos
	dust.modulate = _get_surface_dust_color(_current_surface)
	get_tree().current_scene.add_child(dust)

	var timer := get_tree().create_timer(dust.lifetime * 2)
	timer.timeout.connect(dust.queue_free)

	# Apply stretch effect.
	if jump_stretch_amount > 0.0:
		_apply_squash_stretch(1.0 - jump_stretch_amount * 0.5, 1.0 + jump_stretch_amount)

	effect_spawned.emit("jump_dust", pos)


func _on_double_jump() -> void:
	var pos := character.global_position

	# Play double jump sound.
	if double_jump_sound:
		_play_sound_3d(double_jump_sound, pos, 0.0)

	# Spawn double jump effect (ring/burst).
	if double_jump_particle_scene:
		var particles := double_jump_particle_scene.instantiate() as Node3D
		particles.global_position = pos
		get_tree().current_scene.add_child(particles)
		# Auto-cleanup handled by particle scene.
	else:
		# Create default double jump effect.
		var ring := _create_double_jump_ring()
		ring.global_position = pos
		get_tree().current_scene.add_child(ring)

		var timer := get_tree().create_timer(0.5)
		timer.timeout.connect(ring.queue_free)

	# Screen shake.
	if enable_screen_shake:
		_request_screen_shake(2.0, 0.1)

	effect_spawned.emit("double_jump", pos)


func _on_wall_jump() -> void:
	var pos := character.global_position
	var wall_normal := _movement_state_machine.last_wall_normal if _movement_state_machine else Vector3.BACK

	# Play wall jump sound.
	if wall_jump_sound:
		_play_sound_3d(wall_jump_sound, pos, 0.0)

	# Spawn wall jump effect.
	if wall_jump_particle_scene:
		var particles := wall_jump_particle_scene.instantiate() as Node3D
		particles.global_position = pos
		particles.look_at(pos + wall_normal, Vector3.UP)
		get_tree().current_scene.add_child(particles)
	else:
		_spawn_wall_dust(pos, wall_normal, 15)

	effect_spawned.emit("wall_jump", pos)


func _on_slide_start() -> void:
	var pos := character.global_position

	# Play slide sound.
	if slide_sound:
		_play_sound_3d(slide_sound, pos, 0.0)

	# Spawn initial slide dust burst.
	var dust := _create_dust_burst(15, 0.4, 1.0)
	dust.global_position = pos
	dust.modulate = _get_surface_dust_color(_current_surface)
	get_tree().current_scene.add_child(dust)

	var timer := get_tree().create_timer(dust.lifetime * 2)
	timer.timeout.connect(dust.queue_free)

	# Screen shake.
	if enable_screen_shake:
		_request_screen_shake(3.0, 0.15)

	effect_spawned.emit("slide_start", pos)


func _on_dive_start() -> void:
	var pos := character.global_position

	# Play dive sound.
	if dive_sound:
		_play_sound_3d(dive_sound, pos, 0.0)

	# Spawn dive effect (air trail).
	var trail := _create_dive_trail()
	trail.global_position = pos
	get_tree().current_scene.add_child(trail)

	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(trail.queue_free)

	effect_spawned.emit("dive", pos)


func _on_roll_start() -> void:
	var pos := character.global_position

	# Play roll sound.
	if roll_sound:
		_play_sound_3d(roll_sound, pos, 0.0)

	# Spawn roll dust.
	var dust := _create_dust_burst(12, 0.35, 0.8)
	dust.global_position = pos
	dust.modulate = _get_surface_dust_color(_current_surface)
	get_tree().current_scene.add_child(dust)

	var timer := get_tree().create_timer(dust.lifetime * 2)
	timer.timeout.connect(dust.queue_free)

	effect_spawned.emit("roll", pos)


func _start_sprint_effects() -> void:
	# Start sprint audio loop.
	if sprint_loop and _sprint_audio_player:
		_sprint_audio_player.stream = sprint_loop
		_sprint_audio_player.play()


func _stop_sprint_effects() -> void:
	# Stop sprint audio loop.
	if _sprint_audio_player and _sprint_audio_player.playing:
		_sprint_audio_player.stop()

#endregion

#region Particle Creation

func _create_dust_burst(amount: int, lifetime: float, spread: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.initial_velocity_min = spread * 2.0
	material.initial_velocity_max = spread * 4.0
	material.gravity = Vector3(0, -5, 0)
	material.scale_min = 0.05
	material.scale_max = 0.15
	material.damping_min = 2.0
	material.damping_max = 4.0

	# Color fade.
	var color_curve := Gradient.new()
	color_curve.add_point(0.0, Color(1, 1, 1, 0.8))
	color_curve.add_point(1.0, Color(1, 1, 1, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = color_curve
	material.color_ramp = color_ramp

	particles.process_material = material

	# Simple sphere mesh for particles.
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

	return particles


func _create_double_jump_ring() -> Node3D:
	var container := Node3D.new()

	# Create expanding ring effect.
	var mesh_instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.4
	mesh_instance.mesh = torus
	mesh_instance.rotation_degrees.x = 90  # Lay flat.

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.8, 1.0, 0.8)
	material.emission_enabled = true
	material.emission = Color(0.3, 0.6, 1.0)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material

	container.add_child(mesh_instance)

	# Animate expansion and fade.
	var tween := container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_instance, "scale", Vector3(3, 3, 3), 0.4).from(Vector3.ONE)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.4)

	return container


func _create_dive_trail() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.emitting = true

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, -1)
	material.spread = 30.0
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3.ZERO
	material.scale_min = 0.03
	material.scale_max = 0.08

	var color_curve := Gradient.new()
	color_curve.add_point(0.0, Color(0.6, 0.8, 1.0, 0.6))
	color_curve.add_point(1.0, Color(0.6, 0.8, 1.0, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = color_curve
	material.color_ramp = color_ramp

	particles.process_material = material

	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	particles.draw_pass_1 = mesh

	return particles


func _create_default_slide_particles() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "SlideParticles"
	particles.amount = 15
	particles.lifetime = 0.4
	particles.emitting = false

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 1)  # Behind character.
	material.spread = 45.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0
	material.gravity = Vector3(0, -2, 0)
	material.scale_min = 0.04
	material.scale_max = 0.1

	var color_curve := Gradient.new()
	color_curve.add_point(0.0, Color(0.7, 0.65, 0.6, 0.7))
	color_curve.add_point(1.0, Color(0.7, 0.65, 0.6, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = color_curve
	material.color_ramp = color_ramp

	particles.process_material = material

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

	add_child(particles)
	return particles


func _create_default_speed_lines() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "SpeedLines"
	particles.amount = 30
	particles.lifetime = 0.3
	particles.emitting = false

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 1)
	material.spread = 15.0
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3.ZERO
	material.scale_min = 0.01
	material.scale_max = 0.02

	var color_curve := Gradient.new()
	color_curve.add_point(0.0, Color(1, 1, 1, 0.3))
	color_curve.add_point(1.0, Color(1, 1, 1, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = color_curve
	material.color_ramp = color_ramp

	particles.process_material = material

	# Use elongated shape for speed lines.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.01, 0.01, 0.2)
	particles.draw_pass_1 = mesh

	add_child(particles)
	return particles


func _spawn_wall_dust(pos: Vector3, wall_normal: Vector3, amount: int = 10) -> void:
	var dust := _create_dust_burst(amount, 0.3, 0.5)
	dust.global_position = pos

	# Orient dust away from wall.
	var material := dust.process_material as ParticleProcessMaterial
	if material:
		material.direction = wall_normal
		material.spread = 60.0

	dust.modulate = DUST_COLOR_DEFAULT
	get_tree().current_scene.add_child(dust)

	var timer := get_tree().create_timer(dust.lifetime * 2)
	timer.timeout.connect(dust.queue_free)

#endregion

#region Visual Polish

func _apply_squash_stretch(horizontal: float, vertical: float) -> void:
	if not character:
		return

	# Cancel any existing tween.
	if _squash_stretch_tween and _squash_stretch_tween.is_valid():
		_squash_stretch_tween.kill()

	# Apply squash/stretch then return to normal.
	_squash_stretch_tween = create_tween()
	_squash_stretch_tween.tween_property(character, "scale", Vector3(horizontal, vertical, horizontal), 0.05)
	_squash_stretch_tween.tween_property(character, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _request_screen_shake(intensity: float, duration: float) -> void:
	# Emit to be caught by camera system.
	# You can also call GameManager directly if available.
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		if gm.has_method("shake_camera"):
			gm.shake_camera(intensity, duration)

#endregion

#region Audio Helpers

func _play_sound_3d(stream: AudioStream, pos: Vector3, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	if not stream:
		return null

	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = &"SFX"
	player.max_distance = 30.0
	player.finished.connect(player.queue_free)

	get_tree().current_scene.add_child(player)
	player.global_position = pos
	player.play()

	return player

#endregion

#region Network Sync Support

## Get effects state for network sync.
func get_sync_state() -> Dictionary:
	return {
		"surface": _current_surface,
		"foot": _current_foot,
		"moving": _is_moving,
	}


## Apply effects state from network.
func apply_sync_state(state: Dictionary) -> void:
	if state.has("surface"):
		_current_surface = state["surface"] as SurfaceType
	if state.has("foot"):
		_current_foot = state["foot"] as FootstepFoot
	if state.has("moving"):
		_is_moving = state["moving"]

#endregion
