## Hazards - Comprehensive hazard system for BattleZone Party maps.
##
## Provides various environmental hazards that can damage or affect players:
##   - SPIKES: Damage on contact, instant or periodic
##   - LAVA: Continuous damage while standing in it
##   - CRUSHER: Moving platform that crushes players
##   - SAW_BLADE: Rotating blade that damages on contact
##   - LASER: Periodic laser beam that activates/deactivates
##   - POISON_GAS: Area that applies damage over time
##   - ELECTRIC_FIELD: Pulses of electric damage
##   - WIND_ZONE: Pushes players in a direction
##   - ICE_FLOOR: Reduces player friction
##   - TRAMPOLINE: Bounces players upward
class_name Hazard
extends Area3D


# region -- Enums

enum HazardType {
	SPIKES,
	LAVA,
	CRUSHER,
	SAW_BLADE,
	LASER,
	POISON_GAS,
	ELECTRIC_FIELD,
	WIND_ZONE,
	ICE_FLOOR,
	TRAMPOLINE,
}

# endregion


# region -- Exports

## The type of hazard behavior
@export var hazard_type: HazardType = HazardType.SPIKES

## Damage dealt per tick (or instant for some types)
@export var damage: float = 25.0

## Time between damage ticks (for continuous damage hazards)
@export var damage_interval: float = 0.5

## Whether this hazard is currently active
@export var is_active: bool = true

## For CRUSHER: movement distance
@export var crusher_distance: float = 3.0

## For CRUSHER: cycle time (up + down)
@export var crusher_cycle_time: float = 2.0

## For CRUSHER: time spent at bottom (crushing)
@export var crusher_crush_time: float = 0.3

## For SAW_BLADE: rotation speed (radians/sec)
@export var saw_rotation_speed: float = 10.0

## For LASER: on/off cycle times
@export var laser_on_time: float = 1.5
@export var laser_off_time: float = 2.0
@export var laser_warning_time: float = 0.5

## For WIND_ZONE: push force and direction
@export var wind_force: float = 15.0
@export var wind_direction: Vector3 = Vector3.UP

## For TRAMPOLINE: bounce force
@export var bounce_force: float = 20.0

## Visual mesh to animate
@export var animated_mesh: NodePath = ""

## Warning indicator (e.g., for laser)
@export var warning_indicator: NodePath = ""

## Sound effect name to play
@export var hazard_sound: String = ""

# endregion


# region -- State

var _damage_timers: Dictionary = {}  # peer_id -> time since last damage
var _crusher_state: int = 0  # 0=up, 1=moving down, 2=crushing, 3=moving up
var _crusher_timer: float = 0.0
var _crusher_origin: Vector3 = Vector3.ZERO
var _laser_timer: float = 0.0
var _laser_state: int = 0  # 0=off, 1=warning, 2=on
var _saw_angle: float = 0.0
var _electric_timer: float = 0.0
var _electric_active: bool = false

var _mesh_node: Node3D = null
var _warning_node: Node3D = null
var _players_in_zone: Array[CharacterBody3D] = []

# endregion


# region -- Lifecycle

func _ready() -> void:
	# Cache node references
	if animated_mesh:
		_mesh_node = get_node_or_null(animated_mesh) as Node3D
	if warning_indicator:
		_warning_node = get_node_or_null(warning_indicator) as Node3D
		if _warning_node:
			_warning_node.visible = false

	# Configure collision
	collision_layer = 0
	collision_mask = 1  # Players
	monitoring = true
	monitorable = false

	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Store origin for crusher
	if hazard_type == HazardType.CRUSHER:
		_crusher_origin = global_position

	# Initialize laser state
	if hazard_type == HazardType.LASER:
		_laser_state = 0
		_laser_timer = laser_off_time
		_set_laser_visuals(false)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	if not _is_server():
		return

	match hazard_type:
		HazardType.SPIKES:
			_process_spikes(delta)
		HazardType.LAVA:
			_process_lava(delta)
		HazardType.CRUSHER:
			_process_crusher(delta)
		HazardType.SAW_BLADE:
			_process_saw_blade(delta)
		HazardType.LASER:
			_process_laser(delta)
		HazardType.POISON_GAS:
			_process_poison_gas(delta)
		HazardType.ELECTRIC_FIELD:
			_process_electric_field(delta)
		HazardType.WIND_ZONE:
			_process_wind_zone(delta)
		HazardType.ICE_FLOOR:
			pass  # Handled by player physics
		HazardType.TRAMPOLINE:
			pass  # Handled on body_entered

# endregion


# region -- Signal Handlers

func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	var character := body as CharacterBody3D
	if not character in _players_in_zone:
		_players_in_zone.append(character)

	# Instant damage hazards
	match hazard_type:
		HazardType.SPIKES:
			if is_active:
				_apply_damage(character, damage)
				_play_sound("spike_hit")
		HazardType.TRAMPOLINE:
			if is_active:
				_apply_bounce(character)
				_play_sound("trampoline")


func _on_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	var character := body as CharacterBody3D
	_players_in_zone.erase(character)

	# Clean up damage timer
	var peer_id := _get_peer_id(character)
	if peer_id > 0:
		_damage_timers.erase(peer_id)

# endregion


# region -- Hazard Processors

func _process_spikes(_delta: float) -> void:
	# Spikes do instant damage on enter, no continuous processing needed
	pass


func _process_lava(delta: float) -> void:
	for player: CharacterBody3D in _players_in_zone:
		var peer_id := _get_peer_id(player)
		if peer_id <= 0:
			continue

		if not _damage_timers.has(peer_id):
			_damage_timers[peer_id] = 0.0

		_damage_timers[peer_id] = (_damage_timers[peer_id] as float) + delta

		if (_damage_timers[peer_id] as float) >= damage_interval:
			_damage_timers[peer_id] = 0.0
			_apply_damage(player, damage)
			_play_sound("lava_burn")


func _process_crusher(delta: float) -> void:
	_crusher_timer += delta

	match _crusher_state:
		0:  # Waiting up
			if _crusher_timer >= (crusher_cycle_time - crusher_crush_time) * 0.5:
				_crusher_state = 1
				_crusher_timer = 0.0
				_play_sound("crusher_move")

		1:  # Moving down
			var down_time := crusher_crush_time * 0.3
			var progress := minf(_crusher_timer / down_time, 1.0)
			var new_pos := _crusher_origin - Vector3.UP * crusher_distance * progress
			global_position = new_pos

			if progress >= 1.0:
				_crusher_state = 2
				_crusher_timer = 0.0
				# Damage all players in zone
				for player: CharacterBody3D in _players_in_zone:
					_apply_damage(player, damage)
				_play_sound("crusher_impact")

		2:  # Crushing
			if _crusher_timer >= crusher_crush_time:
				_crusher_state = 3
				_crusher_timer = 0.0

		3:  # Moving up
			var up_time := (crusher_cycle_time - crusher_crush_time) * 0.5
			var progress := minf(_crusher_timer / up_time, 1.0)
			var new_pos := _crusher_origin - Vector3.UP * crusher_distance * (1.0 - progress)
			global_position = new_pos

			if progress >= 1.0:
				_crusher_state = 0
				_crusher_timer = 0.0


func _process_saw_blade(delta: float) -> void:
	_saw_angle += saw_rotation_speed * delta

	if _mesh_node:
		_mesh_node.rotation.y = _saw_angle

	# Damage players on contact
	for player: CharacterBody3D in _players_in_zone:
		var peer_id := _get_peer_id(player)
		if peer_id <= 0:
			continue

		if not _damage_timers.has(peer_id):
			_damage_timers[peer_id] = 0.0

		_damage_timers[peer_id] = (_damage_timers[peer_id] as float) + delta

		if (_damage_timers[peer_id] as float) >= damage_interval:
			_damage_timers[peer_id] = 0.0
			_apply_damage(player, damage)
			_play_sound("saw_hit")


func _process_laser(delta: float) -> void:
	_laser_timer -= delta

	match _laser_state:
		0:  # Off
			if _laser_timer <= 0.0:
				_laser_state = 1
				_laser_timer = laser_warning_time
				_set_warning_visible(true)

		1:  # Warning
			if _laser_timer <= 0.0:
				_laser_state = 2
				_laser_timer = laser_on_time
				_set_laser_visuals(true)
				_set_warning_visible(false)
				_play_sound("laser_on")

		2:  # On - deal damage
			for player: CharacterBody3D in _players_in_zone:
				var peer_id := _get_peer_id(player)
				if peer_id <= 0:
					continue

				if not _damage_timers.has(peer_id):
					_damage_timers[peer_id] = 0.0

				_damage_timers[peer_id] = (_damage_timers[peer_id] as float) + delta

				if (_damage_timers[peer_id] as float) >= damage_interval:
					_damage_timers[peer_id] = 0.0
					_apply_damage(player, damage)

			if _laser_timer <= 0.0:
				_laser_state = 0
				_laser_timer = laser_off_time
				_set_laser_visuals(false)
				_play_sound("laser_off")


func _process_poison_gas(delta: float) -> void:
	for player: CharacterBody3D in _players_in_zone:
		var peer_id := _get_peer_id(player)
		if peer_id <= 0:
			continue

		if not _damage_timers.has(peer_id):
			_damage_timers[peer_id] = 0.0

		_damage_timers[peer_id] = (_damage_timers[peer_id] as float) + delta

		if (_damage_timers[peer_id] as float) >= damage_interval:
			_damage_timers[peer_id] = 0.0
			_apply_damage(player, damage)


func _process_electric_field(delta: float) -> void:
	_electric_timer += delta

	var pulse_interval := 1.5
	if _electric_timer >= pulse_interval:
		_electric_timer = 0.0
		_electric_active = true

		# Pulse damage to all players in zone
		for player: CharacterBody3D in _players_in_zone:
			_apply_damage(player, damage)
			_play_sound("electric_shock")

		# Visual pulse
		_rpc_electric_pulse.rpc()


func _process_wind_zone(_delta: float) -> void:
	for player: CharacterBody3D in _players_in_zone:
		# Apply wind force
		var force := wind_direction.normalized() * wind_force
		player.velocity += force * _delta

# endregion


# region -- Effects

func _apply_damage(player: CharacterBody3D, amount: float) -> void:
	if player.has_method("take_damage"):
		player.take_damage(amount)


func _apply_bounce(player: CharacterBody3D) -> void:
	player.velocity.y = bounce_force

	# Visual bounce effect
	if _mesh_node:
		var tween := create_tween()
		tween.tween_property(_mesh_node, "scale:y", 0.7, 0.1)
		tween.tween_property(_mesh_node, "scale:y", 1.0, 0.2).set_trans(Tween.TRANS_ELASTIC)


func _set_laser_visuals(active: bool) -> void:
	if _mesh_node:
		_mesh_node.visible = active

		# Update material for glow effect
		var mesh_instance := _mesh_node as MeshInstance3D
		if mesh_instance and mesh_instance.mesh:
			var mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
			if mat:
				mat.emission_enabled = active
				if active:
					mat.emission = Color(1.0, 0.2, 0.2)
					mat.emission_energy_multiplier = 3.0


func _set_warning_visible(visible: bool) -> void:
	if _warning_node:
		_warning_node.visible = visible


@rpc("authority", "call_remote", "reliable")
func _rpc_electric_pulse() -> void:
	# Client-side visual effect
	if _mesh_node:
		var tween := create_tween()
		tween.tween_property(_mesh_node, "modulate:a", 0.3, 0.05)
		tween.tween_property(_mesh_node, "modulate:a", 1.0, 0.2)

# endregion


# region -- Sound

func _play_sound(sound_name: String) -> void:
	var actual_name := hazard_sound if hazard_sound != "" else sound_name
	if actual_name != "":
		AudioManager.play_sfx(actual_name)

# endregion


# region -- State Control

## Activate or deactivate the hazard
func set_active(active: bool) -> void:
	is_active = active
	if not active:
		_players_in_zone.clear()
		_damage_timers.clear()

	_rpc_set_active.rpc(active)


@rpc("authority", "call_local", "reliable")
func _rpc_set_active(active: bool) -> void:
	is_active = active
	visible = active

# endregion


# region -- Helpers

func _get_peer_id(character: CharacterBody3D) -> int:
	if character.has_method("get_peer_id"):
		return character.get_peer_id()
	# Fallback: try to parse from name
	var name_str := character.name
	if name_str.is_valid_int():
		return name_str.to_int()
	return -1


func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# endregion
