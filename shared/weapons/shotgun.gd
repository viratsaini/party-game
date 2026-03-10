## Shotgun - Pump-action shotgun with multiple pellets and high close-range damage.
##
## Devastating at close range with its 8-pellet spread pattern.
## Reload one shell at a time, allowing tactical reload canceling.
class_name Shotgun
extends WeaponBase


# Track shells loaded for reload animation
var shells_loaded_this_reload: int = 0


func _setup_weapon() -> void:
	WeaponData.apply_to_weapon(self, &"shotgun")


## Shotgun fires multiple pellets in a spread pattern.
func _fire_hitscan_multi(base_direction: Vector3) -> void:
	# Create a more realistic spread pattern for shotgun
	var pellet_angles: Array[Vector2] = _generate_pellet_pattern()

	for angle_offset: Vector2 in pellet_angles:
		var spread_rad := deg_to_rad(current_spread)
		var right := base_direction.cross(Vector3.UP).normalized()
		var up := right.cross(base_direction).normalized()

		var pellet_direction := base_direction.rotated(right, angle_offset.x * spread_rad)
		pellet_direction = pellet_direction.rotated(up, angle_offset.y * spread_rad)

		_fire_hitscan(pellet_direction.normalized())


## Generate a circular spread pattern for pellets.
func _generate_pellet_pattern() -> Array[Vector2]:
	var pattern: Array[Vector2] = []

	# Center pellet
	pattern.append(Vector2.ZERO)

	# Ring of pellets around center
	var ring_count := pellet_count - 1
	for i in ring_count:
		var angle := (TAU / ring_count) * i + randf_range(-0.1, 0.1)
		var distance := randf_range(0.6, 1.0)
		pattern.append(Vector2(cos(angle), sin(angle)) * distance)

	return pattern


## Reset shell count on reload start.
func _start_reload() -> void:
	shells_loaded_this_reload = 0
	super._start_reload()


## Track shells loaded.
func _reload_one_round() -> void:
	if reserve_ammo > 0 and current_ammo < magazine_size:
		shells_loaded_this_reload += 1

	super._reload_one_round()


## Pump sound after reload.
func _complete_reload() -> void:
	if shells_loaded_this_reload > 0:
		_play_sound(&"shotgun_pump")

	is_reloading = false
	reload_timer = 0.0
	reload_finished.emit(self)
	ammo_changed.emit(current_ammo, reserve_ammo, magazine_size)
