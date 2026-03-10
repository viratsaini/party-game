## Base class for all pickups and power-ups in BattleZone Party.
##
## Provides server-authoritative pickup logic, visual effects (glow, rotation, bob),
## respawn timing, and network synchronization. Extend this class to create
## specific power-up types with custom effects.
class_name PickupBase
extends Area3D


# region -- Signals

## Emitted when a player collects this pickup (on server and clients).
signal collected(peer_id: int, pickup_type: String)

## Emitted when the pickup respawns (on server and clients).
signal respawned()

# endregion


# region -- Enums

## Rarity affects spawn rates and visual glow intensity.
enum Rarity {
	COMMON,     ## 50% spawn weight
	UNCOMMON,   ## 30% spawn weight
	RARE,       ## 15% spawn weight
	EPIC,       ## 4% spawn weight
	LEGENDARY,  ## 1% spawn weight
}

# endregion


# region -- Exports

## Unique identifier for this pickup type.
@export var pickup_id: String = "generic_pickup"

## Display name shown in UI and announcements.
@export var display_name: String = "Pickup"

## Description shown in UI tooltips.
@export var description: String = "A generic pickup."

## Icon for UI display.
@export var icon: Texture2D = null

## Rarity tier affecting spawn weight and visuals.
@export var rarity: Rarity = Rarity.COMMON

## Base color for the pickup glow and mesh.
@export var pickup_color: Color = Color(1.0, 1.0, 1.0)

## How long until this pickup respawns after being collected.
@export var respawn_time: float = 15.0

## Whether this pickup grants a timed effect.
@export var is_timed_effect: bool = false

## Duration of the effect if timed (seconds).
@export var effect_duration: float = 0.0

## Sound effect key to play on collection.
@export var collect_sound: String = "pickup_collect"

## Sound effect key for the announcement.
@export var announce_sound: String = "pickup_announce"

## Whether to show an announcement when collected.
@export var show_announcement: bool = true

## Particle effect scene to spawn on collection.
@export var collect_particle_scene: PackedScene = null

# endregion


# region -- Constants

## Rotation speed in radians per second.
const ROTATION_SPEED: float = 2.0

## Vertical bob amplitude in units.
const BOB_AMPLITUDE: float = 0.2

## Vertical bob speed.
const BOB_SPEED: float = 3.0

## Glow pulse speed.
const GLOW_PULSE_SPEED: float = 2.0

## Glow pulse intensity range.
const GLOW_PULSE_MIN: float = 1.0
const GLOW_PULSE_MAX: float = 2.5

## Rarity spawn weights.
const RARITY_WEIGHTS: Dictionary = {
	Rarity.COMMON: 50,
	Rarity.UNCOMMON: 30,
	Rarity.RARE: 15,
	Rarity.EPIC: 4,
	Rarity.LEGENDARY: 1,
}

## Rarity glow multipliers.
const RARITY_GLOW_MULT: Dictionary = {
	Rarity.COMMON: 1.0,
	Rarity.UNCOMMON: 1.3,
	Rarity.RARE: 1.6,
	Rarity.EPIC: 2.0,
	Rarity.LEGENDARY: 2.5,
}

# endregion


# region -- State

## Whether the pickup is currently active and collectible.
var is_active: bool = true

## Base Y position for bobbing animation.
var _base_y: float = 0.0

## Animation time accumulator.
var _anim_time: float = 0.0

## Current glow energy level.
var _current_glow: float = 1.5

## Reference to the material for glow updates.
var _material: StandardMaterial3D = null

# endregion


# region -- Node References

## The visual mesh instance (can be set in scene or created dynamically).
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null

## Collision shape for pickup detection.
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null

## Respawn timer.
@onready var respawn_timer: Timer = $RespawnTimer if has_node("RespawnTimer") else null

## Particle emitter for ambient effects.
@onready var ambient_particles: GPUParticles3D = $AmbientParticles if has_node("AmbientParticles") else null

## Point light for glow effect.
@onready var glow_light: OmniLight3D = $GlowLight if has_node("GlowLight") else null

# endregion


# region -- Lifecycle

func _ready() -> void:
	_base_y = position.y
	_anim_time = randf() * TAU  # Random start phase for variety

	# Setup collision detection.
	body_entered.connect(_on_body_entered)

	# Setup respawn timer if it exists.
	if respawn_timer:
		respawn_timer.wait_time = respawn_time
		respawn_timer.one_shot = true
		respawn_timer.timeout.connect(_on_respawn_timeout)
	else:
		# Create timer dynamically if not in scene.
		respawn_timer = Timer.new()
		respawn_timer.name = "RespawnTimer"
		respawn_timer.wait_time = respawn_time
		respawn_timer.one_shot = true
		respawn_timer.timeout.connect(_on_respawn_timeout)
		add_child(respawn_timer)

	# Apply visual styling.
	_setup_visuals()


func _process(delta: float) -> void:
	if not is_active:
		return

	_anim_time += delta

	# Rotate the pickup.
	if mesh_instance:
		mesh_instance.rotate_y(ROTATION_SPEED * delta)

	# Bob up and down.
	position.y = _base_y + sin(_anim_time * BOB_SPEED) * BOB_AMPLITUDE

	# Pulse the glow.
	_update_glow_pulse(delta)

# endregion


# region -- Visual Setup

## Configure the visual appearance based on color and rarity.
func _setup_visuals() -> void:
	if not mesh_instance:
		return

	# Create and apply material.
	_material = StandardMaterial3D.new()
	_material.albedo_color = pickup_color
	_material.emission_enabled = true
	_material.emission = pickup_color
	_material.emission_energy_multiplier = GLOW_PULSE_MIN * RARITY_GLOW_MULT.get(rarity, 1.0)
	mesh_instance.material_override = _material

	# Configure glow light if present.
	if glow_light:
		glow_light.light_color = pickup_color
		glow_light.light_energy = 0.5 * RARITY_GLOW_MULT.get(rarity, 1.0)

	# Configure ambient particles if present.
	if ambient_particles:
		_setup_ambient_particles()


## Setup ambient particle effect.
func _setup_ambient_particles() -> void:
	if not ambient_particles:
		return

	var particle_mat := ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 0.5
	particle_mat.direction = Vector3(0, 1, 0)
	particle_mat.spread = 45.0
	particle_mat.initial_velocity_min = 0.5
	particle_mat.initial_velocity_max = 1.0
	particle_mat.gravity = Vector3.ZERO
	particle_mat.scale_min = 0.05
	particle_mat.scale_max = 0.1
	particle_mat.color = pickup_color

	ambient_particles.process_material = particle_mat
	ambient_particles.amount = 8
	ambient_particles.lifetime = 1.5
	ambient_particles.emitting = true


## Update the glow pulse effect.
func _update_glow_pulse(delta: float) -> void:
	if not _material:
		return

	var pulse: float = (sin(_anim_time * GLOW_PULSE_SPEED) + 1.0) * 0.5
	var glow_mult: float = RARITY_GLOW_MULT.get(rarity, 1.0)
	_current_glow = lerpf(GLOW_PULSE_MIN, GLOW_PULSE_MAX, pulse) * glow_mult
	_material.emission_energy_multiplier = _current_glow

	if glow_light:
		glow_light.light_energy = 0.3 + pulse * 0.4 * glow_mult

# endregion


# region -- Pickup Logic (Server-Authoritative)

## Called when a body enters the pickup area.
func _on_body_entered(body: Node3D) -> void:
	if not _is_server():
		return
	if not is_active:
		return

	# Check if it's a player character.
	if body is CharacterBody3D and body.has_method("heal"):
		var character: Node = body
		if not character.get("is_alive"):
			return

		var peer_id: int = character.get("peer_id") if character.get("peer_id") != null else 0

		# Apply the effect.
		if _apply_effect(character):
			# Successful collection.
			_on_collected(peer_id)

			# Notify all clients.
			_rpc_on_collected.rpc(peer_id)


## Override this method in subclasses to apply the specific effect.
## Return true if the effect was successfully applied, false to reject collection.
func _apply_effect(character: Node) -> bool:
	# Base implementation does nothing - override in subclasses.
	return true


## Called when the pickup is collected (server-side).
func _on_collected(peer_id: int) -> void:
	# Play sound effect.
	if collect_sound and collect_sound != "":
		AudioManager.play_sfx(collect_sound)

	# Show announcement.
	if show_announcement:
		_announce_collection(peer_id)

	# Spawn collection particles.
	_spawn_collect_particles()

	# Deactivate and start respawn.
	_set_active(false)
	respawn_timer.start()

	# Emit signal.
	collected.emit(peer_id, pickup_id)


## Announce the pickup collection to all players.
func _announce_collection(peer_id: int) -> void:
	var player_name: String = _get_player_name(peer_id)
	var message: String = "%s picked up %s!" % [player_name, display_name]

	# Send to notification manager if available.
	if Engine.has_singleton("NotificationManager"):
		pass  # Would use notification manager

	# Could also use the game's HUD system.
	var game: Node = get_tree().current_scene
	if game and game.has_method("show_pickup_announcement"):
		game.show_pickup_announcement(message, pickup_color)


## Spawn collection particle effect.
func _spawn_collect_particles() -> void:
	if collect_particle_scene:
		var particles: Node3D = collect_particle_scene.instantiate()
		particles.global_position = global_position
		get_tree().current_scene.add_child(particles)

	# Create a quick burst effect.
	var burst := GPUParticles3D.new()
	burst.name = "CollectBurst"
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 16
	burst.lifetime = 0.5
	burst.emitting = true

	var burst_mat := ParticleProcessMaterial.new()
	burst_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	burst_mat.emission_sphere_radius = 0.3
	burst_mat.direction = Vector3(0, 0, 0)
	burst_mat.spread = 180.0
	burst_mat.initial_velocity_min = 3.0
	burst_mat.initial_velocity_max = 5.0
	burst_mat.gravity = Vector3(0, -5, 0)
	burst_mat.scale_min = 0.1
	burst_mat.scale_max = 0.2
	burst_mat.color = pickup_color

	burst.process_material = burst_mat

	# Simple quad mesh for particles.
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(0.15, 0.15)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.albedo_color = pickup_color
	quad_mat.emission_enabled = true
	quad_mat.emission = pickup_color
	quad_mat.emission_energy_multiplier = 2.0
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad_mesh.material = quad_mat
	burst.draw_pass_1 = quad_mesh

	burst.global_position = global_position
	get_tree().current_scene.add_child(burst)

	# Auto-cleanup.
	var cleanup_timer := Timer.new()
	cleanup_timer.wait_time = 2.0
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(burst.queue_free)
	burst.add_child(cleanup_timer)
	cleanup_timer.start()

# endregion


# region -- Respawn

## Called when the respawn timer finishes.
func _on_respawn_timeout() -> void:
	if not _is_server():
		return

	_set_active(true)
	_rpc_set_active.rpc(true)
	respawned.emit()


## Set the active state of the pickup.
func _set_active(active: bool) -> void:
	is_active = active
	visible = active

	if collision_shape:
		collision_shape.disabled = not active

	if ambient_particles:
		ambient_particles.emitting = active

	if glow_light:
		glow_light.visible = active

# endregion


# region -- Network RPCs

## Sync collected state to clients.
@rpc("authority", "call_remote", "reliable")
func _rpc_on_collected(peer_id: int) -> void:
	if collect_sound and collect_sound != "":
		AudioManager.play_sfx(collect_sound)

	_spawn_collect_particles()
	_set_active(false)
	collected.emit(peer_id, pickup_id)


## Sync active state to clients.
@rpc("authority", "call_remote", "reliable")
func _rpc_set_active(active: bool) -> void:
	_set_active(active)
	if active:
		respawned.emit()

# endregion


# region -- Helpers

## Check if we're the server.
func _is_server() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()


## Get player name from Lobby.
func _get_player_name(peer_id: int) -> String:
	if Engine.has_singleton("Lobby"):
		return "Player"

	# Try to get from Lobby autoload.
	var lobby: Node = get_node_or_null("/root/Lobby")
	if lobby and lobby.has_method("get") and lobby.get("players"):
		var players: Dictionary = lobby.players
		if players.has(peer_id):
			return players[peer_id].get("name", "Player")

	return "Player"


## Get the spawn weight for this pickup's rarity.
func get_spawn_weight() -> int:
	return RARITY_WEIGHTS.get(rarity, 50)


## Get a display string for the effect duration.
func get_duration_text() -> String:
	if not is_timed_effect or effect_duration <= 0:
		return ""
	return "%.1fs" % effect_duration

# endregion
