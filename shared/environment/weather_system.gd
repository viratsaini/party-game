## WeatherSystem - Dynamic weather effects for BattleZone Party maps.
##
## Supports multiple weather types:
##   - CLEAR: No weather effects
##   - RAIN: Falling rain particles with puddle effects
##   - SNOW: Falling snow with accumulation
##   - FOG: Volumetric fog with visibility reduction
##   - SANDSTORM: Desert sand particles
##   - THUNDERSTORM: Rain + lightning + thunder
##
## Weather can affect gameplay (ice physics, visibility, etc.)
class_name WeatherSystem
extends Node3D


# region -- Enums

enum WeatherType {
	CLEAR,
	RAIN,
	SNOW,
	FOG,
	SANDSTORM,
	THUNDERSTORM,
}

enum TransitionType {
	INSTANT,
	GRADUAL,
}

# endregion


# region -- Signals

signal weather_changed(old_type: WeatherType, new_type: WeatherType)
signal lightning_strike(position: Vector3)
signal visibility_changed(new_visibility: float)

# endregion


# region -- Exports

## Current weather type
@export var current_weather: WeatherType = WeatherType.CLEAR

## Intensity of current weather (0.0 - 1.0)
@export var intensity: float = 1.0

## Should weather affect gameplay?
@export var gameplay_effects_enabled: bool = true

## Fog density when FOG weather is active
@export var fog_density: float = 0.05

## Fog color
@export var fog_color: Color = Color(0.7, 0.7, 0.8, 1.0)

## Rain particle count (per emission)
@export var rain_particle_count: int = 1000

## Snow particle count
@export var snow_particle_count: int = 500

## Sand particle count
@export var sand_particle_count: int = 800

## Lightning frequency (seconds between strikes)
@export var lightning_interval_min: float = 5.0
@export var lightning_interval_max: float = 15.0

## Thunder delay after lightning (simulating sound travel)
@export var thunder_delay_min: float = 0.5
@export var thunder_delay_max: float = 3.0

## Transition duration for weather changes
@export var transition_duration: float = 5.0

## World environment to modify
@export var world_environment: NodePath = ""

# endregion


# region -- State

var _particles_rain: GPUParticles3D = null
var _particles_snow: GPUParticles3D = null
var _particles_sand: GPUParticles3D = null
var _lightning_timer: float = 0.0
var _next_lightning: float = 10.0
var _transition_progress: float = 1.0
var _transitioning_from: WeatherType = WeatherType.CLEAR
var _transitioning_to: WeatherType = WeatherType.CLEAR
var _environment: Environment = null
var _original_fog_density: float = 0.0
var _original_sky_energy: float = 1.0

# endregion


# region -- Lifecycle

func _ready() -> void:
	# Get world environment
	if world_environment:
		var env_node := get_node_or_null(world_environment) as WorldEnvironment
		if env_node:
			_environment = env_node.environment
			if _environment:
				_original_fog_density = _environment.fog_density
				_original_sky_energy = _environment.sky.sky_material.get("sky_energy_multiplier") if _environment.sky and _environment.sky.sky_material else 1.0

	# Create particle systems
	_create_rain_particles()
	_create_snow_particles()
	_create_sand_particles()

	# Apply initial weather
	_apply_weather(current_weather, 1.0)


func _process(delta: float) -> void:
	# Handle weather transitions
	if _transition_progress < 1.0:
		_transition_progress += delta / transition_duration
		_transition_progress = minf(_transition_progress, 1.0)
		_update_transition()

	# Handle thunderstorm lightning
	if current_weather == WeatherType.THUNDERSTORM:
		_process_lightning(delta)

	# Update particle emitter positions to follow camera
	_update_particle_positions()

# endregion


# region -- Particle Systems

func _create_rain_particles() -> void:
	_particles_rain = GPUParticles3D.new()
	_particles_rain.name = "RainParticles"
	_particles_rain.amount = rain_particle_count
	_particles_rain.lifetime = 1.5
	_particles_rain.preprocess = 1.0
	_particles_rain.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 30, 60))
	_particles_rain.emitting = false

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 5.0
	material.initial_velocity_min = 15.0
	material.initial_velocity_max = 20.0
	material.gravity = Vector3(0, -30, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(25, 0.5, 25)
	_particles_rain.process_material = material

	# Rain drop mesh
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.02, 0.3, 0.02)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.6, 0.7, 0.9, 0.5)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mesh_mat
	_particles_rain.draw_pass_1 = mesh

	add_child(_particles_rain)


func _create_snow_particles() -> void:
	_particles_snow = GPUParticles3D.new()
	_particles_snow.name = "SnowParticles"
	_particles_snow.amount = snow_particle_count
	_particles_snow.lifetime = 4.0
	_particles_snow.preprocess = 2.0
	_particles_snow.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 30, 60))
	_particles_snow.emitting = false

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 15.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, -3, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(25, 0.5, 25)
	material.turbulence_enabled = true
	material.turbulence_noise_scale = 2.0
	material.turbulence_noise_strength = 1.5
	_particles_snow.process_material = material

	# Snowflake mesh
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.95, 0.95, 1.0, 0.9)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mesh_mat
	_particles_snow.draw_pass_1 = mesh

	add_child(_particles_snow)


func _create_sand_particles() -> void:
	_particles_sand = GPUParticles3D.new()
	_particles_sand.name = "SandParticles"
	_particles_sand.amount = sand_particle_count
	_particles_sand.lifetime = 2.5
	_particles_sand.preprocess = 1.5
	_particles_sand.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 20, 60))
	_particles_sand.emitting = false

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(1, 0, 0.3)  # Wind direction
	material.spread = 30.0
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3(0, -2, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(25, 5, 25)
	material.turbulence_enabled = true
	material.turbulence_noise_scale = 3.0
	material.turbulence_noise_strength = 3.0
	_particles_sand.process_material = material

	# Sand particle mesh
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.85, 0.75, 0.55, 0.7)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mesh_mat
	_particles_sand.draw_pass_1 = mesh

	add_child(_particles_sand)


func _update_particle_positions() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var camera_pos := camera.global_position
	camera_pos.y += 15.0  # Emit from above camera

	if _particles_rain:
		_particles_rain.global_position = camera_pos
	if _particles_snow:
		_particles_snow.global_position = camera_pos
	if _particles_sand:
		_particles_sand.global_position = camera_pos
		_particles_sand.position.y = 5.0  # Sand blows horizontally

# endregion


# region -- Weather Application

func _apply_weather(weather: WeatherType, progress: float) -> void:
	var adjusted_intensity := intensity * progress

	# Reset all particle systems
	if _particles_rain:
		_particles_rain.emitting = false
	if _particles_snow:
		_particles_snow.emitting = false
	if _particles_sand:
		_particles_sand.emitting = false

	# Reset environment
	if _environment:
		_environment.fog_enabled = false
		_environment.volumetric_fog_enabled = false

	# Apply specific weather
	match weather:
		WeatherType.CLEAR:
			_apply_clear_weather()
		WeatherType.RAIN:
			_apply_rain(adjusted_intensity)
		WeatherType.SNOW:
			_apply_snow(adjusted_intensity)
		WeatherType.FOG:
			_apply_fog(adjusted_intensity)
		WeatherType.SANDSTORM:
			_apply_sandstorm(adjusted_intensity)
		WeatherType.THUNDERSTORM:
			_apply_thunderstorm(adjusted_intensity)


func _apply_clear_weather() -> void:
	if _environment:
		_environment.fog_enabled = false
		# Restore original sky brightness
		if _environment.sky and _environment.sky.sky_material:
			_environment.sky.sky_material.set("sky_energy_multiplier", _original_sky_energy)


func _apply_rain(adjusted_intensity: float) -> void:
	if _particles_rain:
		_particles_rain.amount = int(rain_particle_count * adjusted_intensity)
		_particles_rain.emitting = true

	# Slightly darker sky
	if _environment:
		_environment.ambient_light_energy = lerpf(1.0, 0.6, adjusted_intensity)


func _apply_snow(adjusted_intensity: float) -> void:
	if _particles_snow:
		_particles_snow.amount = int(snow_particle_count * adjusted_intensity)
		_particles_snow.emitting = true

	# Light fog with snow
	if _environment:
		_environment.fog_enabled = true
		_environment.fog_density = fog_density * 0.5 * adjusted_intensity
		_environment.fog_light_color = Color(0.9, 0.9, 0.95)


func _apply_fog(adjusted_intensity: float) -> void:
	if _environment:
		_environment.fog_enabled = true
		_environment.fog_density = fog_density * adjusted_intensity
		_environment.fog_light_color = fog_color
		_environment.fog_aerial_perspective = 0.5 * adjusted_intensity

	visibility_changed.emit(1.0 - (adjusted_intensity * 0.7))


func _apply_sandstorm(adjusted_intensity: float) -> void:
	if _particles_sand:
		_particles_sand.amount = int(sand_particle_count * adjusted_intensity)
		_particles_sand.emitting = true

	# Orange tinted fog
	if _environment:
		_environment.fog_enabled = true
		_environment.fog_density = fog_density * 1.5 * adjusted_intensity
		_environment.fog_light_color = Color(0.9, 0.7, 0.4)

	visibility_changed.emit(1.0 - (adjusted_intensity * 0.5))


func _apply_thunderstorm(adjusted_intensity: float) -> void:
	# Rain particles
	if _particles_rain:
		_particles_rain.amount = int(rain_particle_count * 1.5 * adjusted_intensity)
		_particles_rain.emitting = true

	# Dark sky and fog
	if _environment:
		_environment.fog_enabled = true
		_environment.fog_density = fog_density * 0.3 * adjusted_intensity
		_environment.fog_light_color = Color(0.4, 0.4, 0.5)
		_environment.ambient_light_energy = lerpf(1.0, 0.4, adjusted_intensity)

	# Reset lightning timer
	_schedule_next_lightning()

# endregion


# region -- Lightning

func _process_lightning(delta: float) -> void:
	_lightning_timer += delta

	if _lightning_timer >= _next_lightning:
		_trigger_lightning()


func _schedule_next_lightning() -> void:
	_lightning_timer = 0.0
	_next_lightning = randf_range(lightning_interval_min, lightning_interval_max)


func _trigger_lightning() -> void:
	_schedule_next_lightning()

	# Random position for lightning
	var pos := Vector3(
		randf_range(-50, 50),
		20,
		randf_range(-50, 50)
	)

	lightning_strike.emit(pos)

	# Flash effect
	if _environment:
		var original_energy := _environment.ambient_light_energy
		_environment.ambient_light_energy = 3.0

		# Create flash tween
		var tween := create_tween()
		tween.tween_property(_environment, "ambient_light_energy", original_energy, 0.3)

	# Play lightning sound immediately
	AudioManager.play_sfx("lightning")

	# Schedule thunder with delay
	var thunder_delay := randf_range(thunder_delay_min, thunder_delay_max)
	var timer := Timer.new()
	timer.wait_time = thunder_delay
	timer.one_shot = true
	timer.timeout.connect(_play_thunder.bind(timer))
	add_child(timer)
	timer.start()


func _play_thunder(timer: Timer) -> void:
	timer.queue_free()
	AudioManager.play_sfx("thunder")

# endregion


# region -- Transitions

func _update_transition() -> void:
	if _transitioning_from == _transitioning_to:
		return

	# Blend between weather states
	var from_weight := 1.0 - _transition_progress
	var to_weight := _transition_progress

	# Fade out old weather
	if from_weight > 0.01:
		_apply_weather(_transitioning_from, from_weight)

	# Fade in new weather
	if to_weight > 0.01:
		_apply_weather(_transitioning_to, to_weight)

	# When complete, finalize
	if _transition_progress >= 1.0:
		current_weather = _transitioning_to
		_apply_weather(current_weather, 1.0)
		weather_changed.emit(_transitioning_from, current_weather)

# endregion


# region -- Public API

## Set weather type with optional transition
func set_weather(weather: WeatherType, transition: TransitionType = TransitionType.GRADUAL) -> void:
	if weather == current_weather:
		return

	_transitioning_from = current_weather
	_transitioning_to = weather

	if transition == TransitionType.INSTANT:
		_transition_progress = 1.0
		current_weather = weather
		_apply_weather(weather, 1.0)
		weather_changed.emit(_transitioning_from, current_weather)
	else:
		_transition_progress = 0.0


## Set weather intensity
func set_intensity(new_intensity: float) -> void:
	intensity = clampf(new_intensity, 0.0, 1.0)
	_apply_weather(current_weather, 1.0)


## Get visibility factor (1.0 = full, 0.0 = none)
func get_visibility() -> float:
	match current_weather:
		WeatherType.FOG:
			return 1.0 - (intensity * 0.7)
		WeatherType.SANDSTORM:
			return 1.0 - (intensity * 0.5)
		_:
			return 1.0


## Check if weather should cause slippery surfaces
func is_slippery() -> bool:
	return gameplay_effects_enabled and (current_weather == WeatherType.RAIN or current_weather == WeatherType.SNOW)


## Check if weather reduces visibility significantly
func is_low_visibility() -> bool:
	return gameplay_effects_enabled and (current_weather == WeatherType.FOG or current_weather == WeatherType.SANDSTORM)


## Get wind direction (for physics effects)
func get_wind_direction() -> Vector3:
	match current_weather:
		WeatherType.SANDSTORM:
			return Vector3(1, 0, 0.3).normalized() * intensity * 5.0
		WeatherType.THUNDERSTORM:
			return Vector3(0.5, 0, 0.5).normalized() * intensity * 2.0
		_:
			return Vector3.ZERO

# endregion
