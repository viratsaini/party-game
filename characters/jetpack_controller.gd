## JetpackController -- Mini Militia-style jetpack physics system.
##
## This is THE signature mechanic for BattleZone Party, providing responsive
## aerial movement with fuel management, thrust physics, air control, and
## boost mechanics. Network-synchronized for multiplayer gameplay.
##
## Usage:
##   Attach to a PlayerCharacter node. The controller manages:
##   - Fuel consumption and regeneration
##   - Thrust force application
##   - Boost mechanic (double-tap for quick burst)
##   - Network state synchronization
##
## Based on research specs:
##   - 5 seconds max fuel
##   - 3 seconds full recharge (grounded)
##   - 0.5s delay before regen after depletion
class_name JetpackController
extends Node

# =============================================================================
# region -- Signals
# =============================================================================

## Emitted when fuel level changes. Provides normalized value (0.0 - 1.0).
signal fuel_changed(fuel_normalized: float)

## Emitted when jetpack thrust state changes.
signal thrust_state_changed(is_thrusting: bool)

## Emitted when boost is triggered.
signal boost_triggered()

## Emitted when fuel is depleted.
signal fuel_depleted()

## Emitted when fuel is fully recharged.
signal fuel_recharged()

## Emitted when unlimited fuel power-up activates/deactivates.
signal unlimited_fuel_changed(is_unlimited: bool)

# endregion

# =============================================================================
# region -- Constants
# =============================================================================

## Maximum fuel capacity in seconds of continuous thrust.
const MAX_FUEL_SECONDS: float = 5.0

## Time to fully regenerate fuel when grounded (seconds).
const FULL_RECHARGE_TIME: float = 3.0

## Delay before fuel starts regenerating after depletion (seconds).
const REGEN_DELAY_AFTER_DEPLETION: float = 0.5

## Delay before fuel starts regenerating after any use (seconds).
const REGEN_DELAY_AFTER_USE: float = 0.2

## Base thrust force (units/second) opposing gravity.
const BASE_THRUST: float = 15.0

## Boost thrust multiplier for quick burst.
const BOOST_THRUST_MULTIPLIER: float = 2.5

## Boost duration in seconds.
const BOOST_DURATION: float = 0.25

## Boost fuel cost (normalized 0.0 - 1.0).
const BOOST_FUEL_COST: float = 0.15

## Cooldown between boosts (seconds).
const BOOST_COOLDOWN: float = 0.8

## Maximum time between taps for double-tap boost detection (seconds).
const DOUBLE_TAP_WINDOW: float = 0.3

## Air control multiplier (how much you can steer while flying).
const AIR_CONTROL_MULTIPLIER: float = 0.85

## Fuel consumption rate (per second of continuous thrust).
const FUEL_CONSUMPTION_RATE: float = 1.0 / MAX_FUEL_SECONDS  # Deplete in 5s

## Fuel regeneration rate (per second when grounded).
const FUEL_REGEN_RATE: float = 1.0 / FULL_RECHARGE_TIME  # Full in 3s

## Minimum fuel required to activate thrust.
const MIN_FUEL_TO_THRUST: float = 0.05

## Unlimited fuel duration from power-up (seconds).
const UNLIMITED_FUEL_DURATION: float = 10.0

# endregion

# =============================================================================
# region -- State
# =============================================================================

## Current fuel level normalized (0.0 - 1.0).
var fuel: float = 1.0:
	set(value):
		var old_fuel := fuel
		fuel = clampf(value, 0.0, 1.0)
		if not is_equal_approx(old_fuel, fuel):
			fuel_changed.emit(fuel)
		# Check for depletion/recharge events
		if old_fuel > 0.0 and fuel <= 0.0:
			fuel_depleted.emit()
		elif old_fuel < 1.0 and fuel >= 1.0:
			fuel_recharged.emit()

## Whether jetpack thrust is currently active.
var is_thrusting: bool = false:
	set(value):
		if is_thrusting != value:
			is_thrusting = value
			thrust_state_changed.emit(is_thrusting)

## Whether player is requesting thrust input.
var thrust_input: bool = false

## Whether boost is currently active.
var is_boosting: bool = false

## Remaining boost time.
var _boost_timer: float = 0.0

## Cooldown remaining before next boost.
var _boost_cooldown_timer: float = 0.0

## Time remaining before fuel can regenerate.
var _regen_delay_timer: float = 0.0

## Track last thrust press time for double-tap detection.
var _last_thrust_press_time: float = -1.0

## Whether fuel was depleted (triggers longer regen delay).
var _was_depleted: bool = false

## Unlimited fuel power-up active.
var has_unlimited_fuel: bool = false:
	set(value):
		if has_unlimited_fuel != value:
			has_unlimited_fuel = value
			unlimited_fuel_changed.emit(has_unlimited_fuel)

## Timer for unlimited fuel power-up.
var _unlimited_fuel_timer: float = 0.0

## Reference to parent character for physics queries.
var _character: CharacterBody3D = null

## Cached gravity value.
var _gravity: float = 9.8

# endregion

# =============================================================================
# region -- Network Sync State
# =============================================================================

## State for network synchronization.
var _sync_fuel: float = 1.0
var _sync_is_thrusting: bool = false
var _sync_is_boosting: bool = false

# endregion

# =============================================================================
# region -- Lifecycle
# =============================================================================

func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

	# Find parent character
	var parent := get_parent()
	if parent is CharacterBody3D:
		_character = parent as CharacterBody3D
	else:
		push_warning("JetpackController: Parent is not CharacterBody3D. Jetpack may not function correctly.")


func _physics_process(delta: float) -> void:
	_process_boost_timers(delta)
	_process_thrust(delta)
	_process_fuel_regeneration(delta)
	_process_unlimited_fuel_timer(delta)

# endregion

# =============================================================================
# region -- Input API
# =============================================================================

## Set thrust input state (from touch/keyboard).
func set_thrust_input(pressed: bool) -> void:
	var was_pressed := thrust_input
	thrust_input = pressed

	# Detect double-tap for boost
	if pressed and not was_pressed:
		var current_time := Time.get_ticks_msec() / 1000.0
		if _last_thrust_press_time > 0.0:
			var time_since_last := current_time - _last_thrust_press_time
			if time_since_last <= DOUBLE_TAP_WINDOW:
				trigger_boost()
		_last_thrust_press_time = current_time


## Manually trigger a boost (bypasses double-tap detection).
func trigger_boost() -> void:
	if not _can_boost():
		return

	is_boosting = true
	_boost_timer = BOOST_DURATION
	_boost_cooldown_timer = BOOST_COOLDOWN

	# Consume fuel for boost
	if not has_unlimited_fuel:
		fuel -= BOOST_FUEL_COST

	# Reset regen delay
	_regen_delay_timer = REGEN_DELAY_AFTER_USE

	boost_triggered.emit()

	# Play boost sound
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		AudioManager.play_sfx("jetpack_boost")

# endregion

# =============================================================================
# region -- Physics API
# =============================================================================

## Calculate and return the thrust force vector for this frame.
## Should be called in _physics_process and added to velocity.
func get_thrust_force(delta: float) -> Vector3:
	if not _can_thrust():
		is_thrusting = false
		return Vector3.ZERO

	is_thrusting = thrust_input or is_boosting

	if not is_thrusting:
		return Vector3.ZERO

	# Consume fuel
	if not has_unlimited_fuel:
		fuel -= FUEL_CONSUMPTION_RATE * delta
		_regen_delay_timer = REGEN_DELAY_AFTER_USE
		if fuel <= 0.0:
			_was_depleted = true

	# Calculate thrust
	var thrust_multiplier := 1.0
	if is_boosting:
		thrust_multiplier = BOOST_THRUST_MULTIPLIER

	return Vector3.UP * BASE_THRUST * thrust_multiplier * delta


## Get air control multiplier for aerial maneuvering.
func get_air_control() -> float:
	if is_thrusting or (is_grounded() == false):
		return AIR_CONTROL_MULTIPLIER
	return 1.0


## Check if character is grounded (for fuel regen).
func is_grounded() -> bool:
	if _character:
		return _character.is_on_floor()
	return false


## Get current fuel percentage (0-100).
func get_fuel_percentage() -> float:
	return fuel * 100.0

# endregion

# =============================================================================
# region -- Power-Up API
# =============================================================================

## Activate unlimited fuel power-up.
func activate_unlimited_fuel(duration: float = UNLIMITED_FUEL_DURATION) -> void:
	has_unlimited_fuel = true
	_unlimited_fuel_timer = duration


## Refill fuel to maximum.
func refill_fuel() -> void:
	fuel = 1.0
	_was_depleted = false
	_regen_delay_timer = 0.0

# endregion

# =============================================================================
# region -- Network Sync
# =============================================================================

## Get state for network synchronization.
func get_sync_state() -> Dictionary:
	return {
		"fuel": fuel,
		"is_thrusting": is_thrusting,
		"is_boosting": is_boosting,
		"has_unlimited_fuel": has_unlimited_fuel,
	}


## Apply state from network synchronization.
func apply_sync_state(state: Dictionary) -> void:
	if state.has("fuel"):
		fuel = state["fuel"]
	if state.has("is_thrusting"):
		is_thrusting = state["is_thrusting"]
	if state.has("is_boosting"):
		is_boosting = state["is_boosting"]
	if state.has("has_unlimited_fuel"):
		has_unlimited_fuel = state["has_unlimited_fuel"]


## RPC to sync jetpack state from server to clients.
@rpc("authority", "unreliable")
func _rpc_sync_jetpack_state(state: Dictionary) -> void:
	apply_sync_state(state)


## Call from server to broadcast jetpack state.
func broadcast_state() -> void:
	if multiplayer and multiplayer.is_server():
		_rpc_sync_jetpack_state.rpc(get_sync_state())


## RPC for client to request thrust state change.
@rpc("any_peer", "reliable")
func _rpc_request_thrust(is_pressed: bool) -> void:
	if not multiplayer or not multiplayer.is_server():
		return
	set_thrust_input(is_pressed)


## RPC for client to request boost.
@rpc("any_peer", "reliable")
func _rpc_request_boost() -> void:
	if not multiplayer or not multiplayer.is_server():
		return
	trigger_boost()

# endregion

# =============================================================================
# region -- Internal Processing
# =============================================================================

func _process_boost_timers(delta: float) -> void:
	# Process boost duration
	if is_boosting:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			is_boosting = false
			_boost_timer = 0.0

	# Process boost cooldown
	if _boost_cooldown_timer > 0.0:
		_boost_cooldown_timer -= delta


func _process_thrust(delta: float) -> void:
	# Handled in get_thrust_force() to allow proper integration with character physics
	pass


func _process_fuel_regeneration(delta: float) -> void:
	# No regen while thrusting or with unlimited fuel
	if is_thrusting or has_unlimited_fuel:
		return

	# Process regen delay
	if _regen_delay_timer > 0.0:
		_regen_delay_timer -= delta
		return

	# Only regen when grounded
	if not is_grounded():
		return

	# Apply extra delay if fuel was depleted
	if _was_depleted:
		_regen_delay_timer = REGEN_DELAY_AFTER_DEPLETION
		_was_depleted = false
		return

	# Regenerate fuel
	if fuel < 1.0:
		fuel += FUEL_REGEN_RATE * delta


func _process_unlimited_fuel_timer(delta: float) -> void:
	if not has_unlimited_fuel:
		return

	_unlimited_fuel_timer -= delta
	if _unlimited_fuel_timer <= 0.0:
		has_unlimited_fuel = false
		_unlimited_fuel_timer = 0.0


func _can_thrust() -> bool:
	# Can thrust if have fuel or unlimited fuel
	if has_unlimited_fuel:
		return true
	return fuel > MIN_FUEL_TO_THRUST and thrust_input


func _can_boost() -> bool:
	# Cannot boost during cooldown
	if _boost_cooldown_timer > 0.0:
		return false

	# Cannot boost without fuel (unless unlimited)
	if not has_unlimited_fuel and fuel < BOOST_FUEL_COST:
		return false

	return true

# endregion
