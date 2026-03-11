## Sniper Rifle - High-powered precision rifle for long-range engagements.
##
## One-shot headshot potential with perfect accuracy when stationary.
## Heavy movement penalty and slow fire rate balance its power.
class_name SniperRifle
extends WeaponBase


## Is the scope currently active?
var is_scoped: bool = false

## Scope zoom multiplier.
const SCOPE_ZOOM: float = 3.0

## Breath hold timer for perfect accuracy.
var breath_hold_timer: float = 0.0

## Maximum breath hold duration.
const MAX_BREATH_HOLD: float = 3.0


signal scope_toggled(is_scoped: bool)
signal breath_hold_changed(remaining: float, max_hold: float)


func _setup_weapon() -> void:
	WeaponData.apply_to_weapon(self, &"sniper_rifle")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if is_scoped:
		_process_breath_hold(delta)


## Toggle scope view.
func toggle_scope() -> void:
	is_scoped = not is_scoped
	scope_toggled.emit(is_scoped)

	if is_scoped:
		breath_hold_timer = MAX_BREATH_HOLD


## Process breath hold for steady aim.
func _process_breath_hold(delta: float) -> void:
	if Input.is_action_pressed("hold_breath"):
		breath_hold_timer -= delta
		if breath_hold_timer < 0.0:
			breath_hold_timer = 0.0
		breath_hold_changed.emit(breath_hold_timer, MAX_BREATH_HOLD)
	else:
		# Recover breath when not holding
		breath_hold_timer = minf(breath_hold_timer + delta * 0.5, MAX_BREATH_HOLD)
		breath_hold_changed.emit(breath_hold_timer, MAX_BREATH_HOLD)


## Override spread to account for scope and breath hold.
func _apply_spread(direction: Vector3) -> Vector3:
	var effective_spread := current_spread

	if is_scoped:
		# Reduce spread when scoped
		effective_spread *= 0.3

		# Perfect accuracy when holding breath
		if Input.is_action_pressed("hold_breath") and breath_hold_timer > 0.0:
			effective_spread = 0.0

	if effective_spread <= 0.0:
		return direction

	var spread_rad := deg_to_rad(effective_spread)
	var random_spread := Vector2(
		randf_range(-spread_rad, spread_rad),
		randf_range(-spread_rad, spread_rad)
	)

	var right := direction.cross(Vector3.UP).normalized()
	var up := right.cross(direction).normalized()

	var spread_direction := direction.rotated(right, random_spread.x)
	spread_direction = spread_direction.rotated(up, random_spread.y)

	return spread_direction.normalized()


## Sniper has heavy recoil that kicks out of scope.
func _apply_recoil() -> void:
	super._apply_recoil()

	# Kick out of scope on fire
	if is_scoped:
		is_scoped = false
		scope_toggled.emit(false)


## Unequip also exits scope.
func unequip() -> void:
	if is_scoped:
		is_scoped = false
		scope_toggled.emit(false)

	super.unequip()
