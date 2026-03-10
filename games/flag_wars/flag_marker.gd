## FlagMarker — Visual flag indicator for Flag Wars.
##
## Displays a coloured flag mesh that bobs/rotates when at base or on the ground,
## follows a carrier player when picked up, and manages the visual state
## transitions between at-base, carried, and dropped states.
class_name FlagMarker
extends Node3D


# region — Exports

## Team this flag belongs to: "red" or "blue".
@export var team: String = "red"

# endregion


# region — State

## Whether the flag is currently sitting at its home base.
var is_at_base: bool = true

## Peer id of the player carrying this flag (-1 = nobody).
var carrier_id: int = -1

## Elapsed time for bob/rotation animation.
var _anim_time: float = 0.0

## Cached base position for return reference.
var _base_position: Vector3 = Vector3.ZERO

# endregion


# region — Constants

const BOB_AMPLITUDE: float = 0.3      ## Vertical bob distance.
const BOB_SPEED: float = 2.0          ## Bob cycles per second.
const ROTATE_SPEED: float = 1.5       ## Radians per second.
const FLAG_HEIGHT: float = 2.0        ## Height of the flag pole mesh.
const FLAG_WIDTH: float = 0.15        ## Thickness of the pole.
const BANNER_WIDTH: float = 0.6       ## Width of the banner portion.
const BANNER_HEIGHT: float = 0.8      ## Height of the banner portion.

# endregion


# region — Node References

var _pole_mesh: MeshInstance3D = null
var _banner_mesh: MeshInstance3D = null

# endregion


# region — Lifecycle

func _ready() -> void:
	_base_position = global_position
	_create_flag_visual()


func _process(delta: float) -> void:
	if carrier_id > 0:
		# When carried, flag follows the carrier (position set externally).
		# Slight rotation to show it's active.
		_anim_time += delta
		if _pole_mesh:
			_pole_mesh.rotation.y = sin(_anim_time * ROTATE_SPEED * 2.0) * 0.15
		return

	# Bob and rotate when at base or on the ground.
	_anim_time += delta
	var bob_offset: float = sin(_anim_time * BOB_SPEED * TAU) * BOB_AMPLITUDE
	if _pole_mesh:
		_pole_mesh.position.y = (FLAG_HEIGHT * 0.5) + bob_offset
		_pole_mesh.rotation.y = _anim_time * ROTATE_SPEED

# endregion


# region — Visual Construction

func _create_flag_visual() -> void:
	var team_color: Color = Color(0.9, 0.15, 0.15) if team == "red" else Color(0.15, 0.3, 0.9)

	# Pole — tall thin box.
	_pole_mesh = MeshInstance3D.new()
	_pole_mesh.name = "Pole"
	var pole_box := BoxMesh.new()
	pole_box.size = Vector3(FLAG_WIDTH, FLAG_HEIGHT, FLAG_WIDTH)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.8, 0.8, 0.8)
	pole_mat.roughness = 0.6
	pole_box.material = pole_mat
	_pole_mesh.mesh = pole_box
	_pole_mesh.position = Vector3(0.0, FLAG_HEIGHT * 0.5, 0.0)
	add_child(_pole_mesh)

	# Banner — coloured rectangle attached to the top of the pole.
	_banner_mesh = MeshInstance3D.new()
	_banner_mesh.name = "Banner"
	var banner_box := BoxMesh.new()
	banner_box.size = Vector3(BANNER_WIDTH, BANNER_HEIGHT, 0.05)
	var banner_mat := StandardMaterial3D.new()
	banner_mat.albedo_color = team_color
	banner_mat.roughness = 0.5
	banner_mat.emission_enabled = true
	banner_mat.emission = team_color * 0.3
	banner_mat.emission_energy_multiplier = 0.5
	banner_box.material = banner_mat
	_banner_mesh.mesh = banner_box
	# Offset to the right of the pole top.
	_banner_mesh.position = Vector3(BANNER_WIDTH * 0.5 + FLAG_WIDTH * 0.5, FLAG_HEIGHT - BANNER_HEIGHT * 0.5, 0.0)
	_pole_mesh.add_child(_banner_mesh)

	# Small glow sphere at the base for visibility.
	var glow_mesh := MeshInstance3D.new()
	glow_mesh.name = "Glow"
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = team_color
	glow_mat.emission_enabled = true
	glow_mat.emission = team_color
	glow_mat.emission_energy_multiplier = 2.0
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color.a = 0.6
	sphere.material = glow_mat
	glow_mesh.mesh = sphere
	glow_mesh.position = Vector3(0.0, 0.3, 0.0)
	add_child(glow_mesh)

# endregion
