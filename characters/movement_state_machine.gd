## MovementStateMachine - Advanced movement state management for responsive, fun gameplay.
## Inspired by Mini Militia's tight controls and modern platformer mechanics.
class_name MovementStateMachine
extends RefCounted

#region Signals
## Emitted when state changes, providing old and new state for effects/audio.
signal state_changed(from_state: MovementState, to_state: MovementState)
## Emitted when a special move is performed (for particles, sounds, etc.).
signal special_move_performed(move_type: SpecialMove)
## Emitted when landing from a fall (intensity 0-1 based on fall speed).
signal landed(intensity: float)
## Emitted when stamina changes.
signal stamina_changed(current: float, maximum: float)
## Emitted when wall contact state changes.
signal wall_contact_changed(is_touching: bool, wall_normal: Vector3)
#endregion

#region Enums
enum MovementState {
	IDLE,
	WALKING,
	RUNNING,
	SPRINTING,
	JUMPING,
	DOUBLE_JUMPING,
	FALLING,
	LANDING,
	WALL_SLIDING,
	WALL_JUMPING,
	CROUCHING,
	CROUCH_WALKING,
	PRONE,
	SLIDING,
	DIVING,
	ROLLING,
	STUNNED,
}

enum SpecialMove {
	DOUBLE_JUMP,
	WALL_JUMP,
	SLIDE,
	DIVE,
	ROLL,
	CROUCH,
	PRONE,
}
#endregion

#region Movement Parameters - Tuned for responsive Mini Militia-like feel
## Ground movement parameters
const GROUND_ACCELERATION: float = 100.0  # units/s^2 - instant response feel
const GROUND_DECELERATION: float = 80.0   # units/s^2 - quick stops
const GROUND_FRICTION: float = 12.0       # friction coefficient

## Air movement parameters
const AIR_ACCELERATION: float = 60.0      # Reduced for skill expression
const AIR_DECELERATION: float = 20.0      # Less friction in air
const AIR_CONTROL: float = 0.7            # 70% of ground control in air

## Speed limits
const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 8.0
const SPRINT_SPEED: float = 12.0
const CROUCH_SPEED: float = 3.0
const PRONE_SPEED: float = 1.5
const SLIDE_SPEED: float = 15.0
const DIVE_SPEED: float = 18.0
const WALL_SLIDE_SPEED: float = 2.0       # Downward velocity during wall slide

## Jump parameters
const JUMP_FORCE: float = 12.0
const DOUBLE_JUMP_FORCE: float = 10.0     # Slightly weaker than first jump
const WALL_JUMP_FORCE: float = 11.0
const WALL_JUMP_ANGLE: float = 50.0       # Degrees from wall normal
const JUMP_CUT_MULTIPLIER: float = 0.5    # Variable jump height
const MAX_FALL_SPEED: float = 25.0

## Timing windows (in seconds) - Critical for game feel
const COYOTE_TIME: float = 0.15           # Forgiveness window after leaving ground
const JUMP_BUFFER_TIME: float = 0.1       # Input buffering for jump
const WALL_JUMP_BUFFER: float = 0.12      # Wall jump buffer window
const CORNER_CORRECTION: float = 0.3      # Ledge grab/correction window
const LANDING_RECOVERY: float = 0.08      # Brief landing recovery time
const HARD_LANDING_THRESHOLD: float = 15.0 # Fall speed for hard landing
const HARD_LANDING_RECOVERY: float = 0.25

## Slide parameters
const SLIDE_DURATION: float = 0.5
const SLIDE_COOLDOWN: float = 0.3
const SLIDE_BOOST: float = 1.3            # Initial speed multiplier

## Dive/Roll parameters
const DIVE_DURATION: float = 0.4
const ROLL_DURATION: float = 0.5
const ROLL_COOLDOWN: float = 0.4
const ROLL_INVINCIBILITY_START: float = 0.05
const ROLL_INVINCIBILITY_END: float = 0.35

## Wall mechanics
const WALL_STICK_TIME: float = 0.2        # Time before sliding starts
const WALL_SLIDE_ACCELERATION: float = 8.0
const MIN_WALL_JUMP_HEIGHT: float = 0.5   # Min height needed for wall jump

## Stamina system
const MAX_STAMINA: float = 100.0
const STAMINA_SPRINT_DRAIN: float = 20.0  # per second
const STAMINA_SLIDE_COST: float = 15.0
const STAMINA_DIVE_COST: float = 20.0
const STAMINA_ROLL_COST: float = 15.0
const STAMINA_WALL_JUMP_COST: float = 10.0
const STAMINA_DOUBLE_JUMP_COST: float = 12.0
const STAMINA_REGEN_RATE: float = 25.0    # per second when not sprinting
const STAMINA_REGEN_DELAY: float = 0.5    # seconds before regen starts

## Crouch/Prone
const CROUCH_TRANSITION_TIME: float = 0.1
const PRONE_TRANSITION_TIME: float = 0.3
const CROUCH_HEIGHT_SCALE: float = 0.6
const PRONE_HEIGHT_SCALE: float = 0.3
#endregion

#region State Variables
var current_state: MovementState = MovementState.IDLE
var previous_state: MovementState = MovementState.IDLE

## Timers
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_stick_timer: float = 0.0
var slide_timer: float = 0.0
var slide_cooldown_timer: float = 0.0
var dive_timer: float = 0.0
var roll_timer: float = 0.0
var roll_cooldown_timer: float = 0.0
var landing_timer: float = 0.0
var stamina_regen_delay_timer: float = 0.0
var state_timer: float = 0.0  # Time in current state

## Movement state
var velocity: Vector3 = Vector3.ZERO
var input_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector3 = Vector3.FORWARD
var last_ground_velocity: Vector3 = Vector3.ZERO
var fall_start_height: float = 0.0
var peak_fall_speed: float = 0.0

## Wall contact
var is_touching_wall: bool = false
var wall_normal: Vector3 = Vector3.ZERO
var last_wall_normal: Vector3 = Vector3.ZERO
var wall_contact_point: Vector3 = Vector3.ZERO

## Jump tracking
var has_double_jump: bool = true
var jumps_remaining: int = 2
var max_jumps: int = 2  # Can be modified by power-ups
var jump_was_cut: bool = false

## Stamina
var stamina: float = MAX_STAMINA
var _stamina_locked: bool = false  # Used during certain moves

## Flags
var is_grounded: bool = false
var was_grounded: bool = false
var can_wall_jump: bool = false
var is_invincible: bool = false  # For roll i-frames
var input_locked: bool = false
var slide_direction: Vector3 = Vector3.ZERO
var dive_direction: Vector3 = Vector3.ZERO

## Speed modifiers (from power-ups, zones, etc.)
var speed_modifier: float = 1.0
var acceleration_modifier: float = 1.0
var gravity_modifier: float = 1.0
var jump_modifier: float = 1.0
#endregion

#region Capabilities (can be modified by power-ups, character abilities)
var can_sprint: bool = true
var can_slide: bool = true
var can_dive: bool = true
var can_roll: bool = true
var can_wall_jump: bool = true
var can_double_jump: bool = false  # Usually granted by power-up
var can_crouch: bool = true
var can_prone: bool = true
#endregion


func _init() -> void:
	pass


## Main update function - call every physics frame.
func update(delta: float, grounded: bool, touching_wall: bool, new_wall_normal: Vector3) -> void:
	was_grounded = is_grounded
	is_grounded = grounded

	# Update wall contact
	var had_wall_contact := is_touching_wall
	is_touching_wall = touching_wall
	if touching_wall:
		wall_normal = new_wall_normal
		if not had_wall_contact:
			last_wall_normal = wall_normal
			wall_contact_changed.emit(true, wall_normal)
	elif had_wall_contact:
		wall_contact_changed.emit(false, Vector3.ZERO)

	# Update timers
	_update_timers(delta)

	# Handle landing
	if is_grounded and not was_grounded:
		_on_landed()

	# Handle leaving ground
	if not is_grounded and was_grounded:
		_on_left_ground()

	# Update state timer
	state_timer += delta

	# Handle stamina regeneration
	_update_stamina(delta)


## Update all movement timers.
func _update_timers(delta: float) -> void:
	# Coyote time
	if is_grounded:
		coyote_timer = COYOTE_TIME
	elif coyote_timer > 0.0:
		coyote_timer -= delta

	# Jump buffer
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

	# Wall stick
	if is_touching_wall and not is_grounded:
		if wall_stick_timer < WALL_STICK_TIME:
			wall_stick_timer += delta
	else:
		wall_stick_timer = 0.0

	# Slide cooldown
	if slide_cooldown_timer > 0.0:
		slide_cooldown_timer -= delta

	# Roll cooldown
	if roll_cooldown_timer > 0.0:
		roll_cooldown_timer -= delta

	# Slide duration
	if current_state == MovementState.SLIDING:
		slide_timer -= delta
		if slide_timer <= 0.0:
			_end_slide()

	# Dive duration
	if current_state == MovementState.DIVING:
		dive_timer -= delta
		if dive_timer <= 0.0:
			_end_dive()

	# Roll duration
	if current_state == MovementState.ROLLING:
		roll_timer -= delta
		# Handle invincibility frames
		var elapsed := ROLL_DURATION - roll_timer
		is_invincible = elapsed >= ROLL_INVINCIBILITY_START and elapsed <= ROLL_INVINCIBILITY_END
		if roll_timer <= 0.0:
			_end_roll()

	# Landing recovery
	if current_state == MovementState.LANDING:
		landing_timer -= delta
		if landing_timer <= 0.0:
			_transition_to(MovementState.IDLE)

	# Stamina regen delay
	if stamina_regen_delay_timer > 0.0:
		stamina_regen_delay_timer -= delta


## Update stamina regeneration.
func _update_stamina(delta: float) -> void:
	if _stamina_locked:
		return

	var is_sprinting := current_state == MovementState.SPRINTING

	if is_sprinting:
		stamina -= STAMINA_SPRINT_DRAIN * delta
		stamina_regen_delay_timer = STAMINA_REGEN_DELAY
		if stamina <= 0.0:
			stamina = 0.0
			# Force out of sprint
			_transition_to(MovementState.RUNNING)
	elif stamina_regen_delay_timer <= 0.0:
		stamina = minf(stamina + STAMINA_REGEN_RATE * delta, MAX_STAMINA)

	stamina_changed.emit(stamina, MAX_STAMINA)


## Handle landing from air.
func _on_landed() -> void:
	# Calculate landing intensity
	var intensity := clampf(peak_fall_speed / HARD_LANDING_THRESHOLD, 0.0, 1.0)
	landed.emit(intensity)

	# Reset jump tracking
	jumps_remaining = max_jumps
	has_double_jump = can_double_jump
	jump_was_cut = false

	# Determine landing state
	if peak_fall_speed >= HARD_LANDING_THRESHOLD:
		landing_timer = HARD_LANDING_RECOVERY
		_transition_to(MovementState.LANDING)
	elif peak_fall_speed > 5.0:
		landing_timer = LANDING_RECOVERY
		_transition_to(MovementState.LANDING)
	else:
		# Quick landing - check for buffered inputs
		if jump_buffer_timer > 0.0:
			request_jump()
		elif input_direction.length_squared() > 0.01:
			_transition_to(MovementState.WALKING)
		else:
			_transition_to(MovementState.IDLE)

	peak_fall_speed = 0.0


## Handle leaving the ground (fall or jump).
func _on_left_ground() -> void:
	last_ground_velocity = velocity
	fall_start_height = 0.0  # Would be set by character controller

	# Start coyote time
	if current_state != MovementState.JUMPING and current_state != MovementState.WALL_JUMPING:
		coyote_timer = COYOTE_TIME


## Request a jump input - handles buffering.
func request_jump() -> void:
	if input_locked:
		return

	jump_buffer_timer = JUMP_BUFFER_TIME
	_try_jump()


## Attempt to perform a jump.
func _try_jump() -> bool:
	# Check for special states that prevent jumping
	match current_state:
		MovementState.STUNNED, MovementState.DIVING, MovementState.ROLLING:
			return false
		MovementState.PRONE:
			# Must crouch first
			return false

	# Wall jump check
	if can_wall_jump and is_touching_wall and not is_grounded:
		return _perform_wall_jump()

	# Ground or coyote jump
	if is_grounded or coyote_timer > 0.0:
		return _perform_ground_jump()

	# Double jump
	if can_double_jump and has_double_jump and jumps_remaining > 0:
		return _perform_double_jump()

	return false


## Perform a ground jump.
func _perform_ground_jump() -> bool:
	velocity.y = JUMP_FORCE * jump_modifier
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	jumps_remaining -= 1
	_transition_to(MovementState.JUMPING)
	return true


## Perform a double jump.
func _perform_double_jump() -> bool:
	if not _consume_stamina(STAMINA_DOUBLE_JUMP_COST):
		return false

	velocity.y = DOUBLE_JUMP_FORCE * jump_modifier
	has_double_jump = false
	jumps_remaining -= 1
	_transition_to(MovementState.DOUBLE_JUMPING)
	special_move_performed.emit(SpecialMove.DOUBLE_JUMP)
	return true


## Perform a wall jump.
func _perform_wall_jump() -> bool:
	if not _consume_stamina(STAMINA_WALL_JUMP_COST):
		return false

	# Calculate wall jump direction
	var angle_rad := deg_to_rad(WALL_JUMP_ANGLE)
	var horizontal_force := WALL_JUMP_FORCE * sin(angle_rad)
	var vertical_force := WALL_JUMP_FORCE * cos(angle_rad)

	velocity = wall_normal * horizontal_force
	velocity.y = vertical_force * jump_modifier

	# Reset wall contact
	wall_stick_timer = 0.0
	jump_buffer_timer = 0.0

	# Refresh double jump on wall jump
	if can_double_jump:
		has_double_jump = true
		jumps_remaining = max_jumps - 1

	_transition_to(MovementState.WALL_JUMPING)
	special_move_performed.emit(SpecialMove.WALL_JUMP)
	return true


## Release jump button - for variable jump height.
func release_jump() -> void:
	if current_state == MovementState.JUMPING or current_state == MovementState.DOUBLE_JUMPING:
		if velocity.y > 0.0 and not jump_was_cut:
			velocity.y *= JUMP_CUT_MULTIPLIER
			jump_was_cut = true


## Request a slide.
func request_slide() -> bool:
	if not can_slide:
		return false
	if slide_cooldown_timer > 0.0:
		return false
	if not is_grounded:
		return false
	if current_state == MovementState.SLIDING:
		return false
	if not _consume_stamina(STAMINA_SLIDE_COST):
		return false

	# Need some horizontal velocity to slide
	var horizontal_vel := Vector2(velocity.x, velocity.z)
	if horizontal_vel.length() < WALK_SPEED * 0.5:
		return false

	slide_direction = Vector3(velocity.x, 0.0, velocity.z).normalized()
	slide_timer = SLIDE_DURATION

	# Apply slide boost
	var slide_speed := maxf(horizontal_vel.length() * SLIDE_BOOST, SLIDE_SPEED)
	velocity.x = slide_direction.x * slide_speed
	velocity.z = slide_direction.z * slide_speed

	_transition_to(MovementState.SLIDING)
	special_move_performed.emit(SpecialMove.SLIDE)
	return true


## End the slide state.
func _end_slide() -> void:
	slide_cooldown_timer = SLIDE_COOLDOWN
	if is_grounded:
		if input_direction.length_squared() > 0.01:
			_transition_to(MovementState.WALKING)
		else:
			_transition_to(MovementState.CROUCHING)
	else:
		_transition_to(MovementState.FALLING)


## Request a dive (aerial dodge).
func request_dive() -> bool:
	if not can_dive:
		return false
	if is_grounded:
		return request_roll()  # On ground, do a roll instead
	if current_state == MovementState.DIVING:
		return false
	if not _consume_stamina(STAMINA_DIVE_COST):
		return false

	# Dive in input direction or facing direction
	if input_direction.length_squared() > 0.01:
		dive_direction = Vector3(input_direction.x, 0.0, input_direction.y).normalized()
	else:
		dive_direction = facing_direction

	dive_timer = DIVE_DURATION
	velocity = dive_direction * DIVE_SPEED
	velocity.y = 2.0  # Slight upward component

	_transition_to(MovementState.DIVING)
	special_move_performed.emit(SpecialMove.DIVE)
	return true


## End the dive state.
func _end_dive() -> void:
	if is_grounded:
		_transition_to(MovementState.LANDING)
		landing_timer = LANDING_RECOVERY
	else:
		_transition_to(MovementState.FALLING)


## Request a roll (ground dodge).
func request_roll() -> bool:
	if not can_roll:
		return false
	if roll_cooldown_timer > 0.0:
		return false
	if not is_grounded:
		return request_dive()  # In air, do a dive instead
	if current_state == MovementState.ROLLING:
		return false
	if not _consume_stamina(STAMINA_ROLL_COST):
		return false

	# Roll in input direction or facing direction
	var roll_direction: Vector3
	if input_direction.length_squared() > 0.01:
		roll_direction = Vector3(input_direction.x, 0.0, input_direction.y).normalized()
	else:
		roll_direction = facing_direction

	roll_timer = ROLL_DURATION
	var roll_speed := SLIDE_SPEED * 0.8
	velocity = roll_direction * roll_speed

	_transition_to(MovementState.ROLLING)
	special_move_performed.emit(SpecialMove.ROLL)
	return true


## End the roll state.
func _end_roll() -> void:
	is_invincible = false
	roll_cooldown_timer = ROLL_COOLDOWN
	if is_grounded:
		if input_direction.length_squared() > 0.01:
			_transition_to(MovementState.WALKING)
		else:
			_transition_to(MovementState.IDLE)
	else:
		_transition_to(MovementState.FALLING)


## Request crouch.
func request_crouch() -> bool:
	if not can_crouch:
		return false

	match current_state:
		MovementState.IDLE, MovementState.WALKING, MovementState.RUNNING:
			if is_grounded:
				_transition_to(MovementState.CROUCHING)
				special_move_performed.emit(SpecialMove.CROUCH)
				return true
		MovementState.SPRINTING:
			# Sprinting + crouch = slide
			return request_slide()

	return false


## Release crouch.
func release_crouch() -> void:
	if current_state == MovementState.CROUCHING or current_state == MovementState.CROUCH_WALKING:
		if input_direction.length_squared() > 0.01:
			_transition_to(MovementState.WALKING)
		else:
			_transition_to(MovementState.IDLE)
	elif current_state == MovementState.PRONE:
		_transition_to(MovementState.CROUCHING)


## Request prone.
func request_prone() -> bool:
	if not can_prone:
		return false
	if not is_grounded:
		return false

	match current_state:
		MovementState.CROUCHING, MovementState.CROUCH_WALKING:
			_transition_to(MovementState.PRONE)
			special_move_performed.emit(SpecialMove.PRONE)
			return true

	return false


## Request sprint.
func request_sprint() -> bool:
	if not can_sprint:
		return false
	if stamina <= 0.0:
		return false
	if not is_grounded:
		return false

	match current_state:
		MovementState.WALKING, MovementState.RUNNING:
			_transition_to(MovementState.SPRINTING)
			return true

	return false


## Release sprint.
func release_sprint() -> void:
	if current_state == MovementState.SPRINTING:
		if input_direction.length_squared() > 0.01:
			_transition_to(MovementState.RUNNING)
		else:
			_transition_to(MovementState.IDLE)


## Update movement state based on input and velocity.
func update_movement_state(horizontal_speed: float, has_input: bool) -> void:
	# Skip if in a locked state
	if _is_locked_state():
		return

	if is_grounded:
		_update_grounded_state(horizontal_speed, has_input)
	else:
		_update_airborne_state()


## Update state while grounded.
func _update_grounded_state(horizontal_speed: float, has_input: bool) -> void:
	match current_state:
		MovementState.IDLE, MovementState.WALKING, MovementState.RUNNING, MovementState.SPRINTING:
			if not has_input:
				if horizontal_speed < 0.1:
					if current_state != MovementState.IDLE:
						_transition_to(MovementState.IDLE)
			else:
				# Determine speed state
				if current_state == MovementState.SPRINTING:
					# Stay sprinting if button held
					pass
				elif horizontal_speed >= RUN_SPEED * 0.9:
					if current_state != MovementState.RUNNING:
						_transition_to(MovementState.RUNNING)
				elif horizontal_speed > 0.1:
					if current_state != MovementState.WALKING:
						_transition_to(MovementState.WALKING)

		MovementState.CROUCHING:
			if has_input:
				_transition_to(MovementState.CROUCH_WALKING)

		MovementState.CROUCH_WALKING:
			if not has_input:
				_transition_to(MovementState.CROUCHING)


## Update state while airborne.
func _update_airborne_state() -> void:
	match current_state:
		MovementState.IDLE, MovementState.WALKING, MovementState.RUNNING, MovementState.SPRINTING, \
		MovementState.CROUCHING, MovementState.CROUCH_WALKING:
			# Left the ground unexpectedly
			_transition_to(MovementState.FALLING)

		MovementState.JUMPING, MovementState.DOUBLE_JUMPING, MovementState.WALL_JUMPING:
			if velocity.y < 0.0:
				_transition_to(MovementState.FALLING)

		MovementState.FALLING:
			# Check for wall slide
			if is_touching_wall and wall_stick_timer >= WALL_STICK_TIME:
				_transition_to(MovementState.WALL_SLIDING)
			# Track peak fall speed
			peak_fall_speed = maxf(peak_fall_speed, -velocity.y)


## Transition to a new state.
func _transition_to(new_state: MovementState) -> void:
	if new_state == current_state:
		return

	previous_state = current_state
	current_state = new_state
	state_timer = 0.0

	state_changed.emit(previous_state, new_state)


## Check if current state is locked (no state transitions allowed).
func _is_locked_state() -> bool:
	match current_state:
		MovementState.SLIDING, MovementState.DIVING, MovementState.ROLLING, \
		MovementState.LANDING, MovementState.STUNNED:
			return true
	return false


## Get the maximum speed for the current state.
func get_max_speed() -> float:
	var base_speed: float

	match current_state:
		MovementState.IDLE:
			base_speed = 0.0
		MovementState.WALKING:
			base_speed = WALK_SPEED
		MovementState.RUNNING:
			base_speed = RUN_SPEED
		MovementState.SPRINTING:
			base_speed = SPRINT_SPEED
		MovementState.CROUCHING, MovementState.CROUCH_WALKING:
			base_speed = CROUCH_SPEED
		MovementState.PRONE:
			base_speed = PRONE_SPEED
		MovementState.SLIDING:
			base_speed = SLIDE_SPEED
		MovementState.DIVING:
			base_speed = DIVE_SPEED
		MovementState.WALL_SLIDING:
			base_speed = RUN_SPEED  # Horizontal control during wall slide
		MovementState.JUMPING, MovementState.DOUBLE_JUMPING, MovementState.WALL_JUMPING, \
		MovementState.FALLING:
			base_speed = RUN_SPEED * AIR_CONTROL
		_:
			base_speed = RUN_SPEED

	return base_speed * speed_modifier


## Get the acceleration for the current state.
func get_acceleration() -> float:
	var base_accel: float

	if is_grounded:
		base_accel = GROUND_ACCELERATION
	else:
		base_accel = AIR_ACCELERATION

	return base_accel * acceleration_modifier


## Get the deceleration for the current state.
func get_deceleration() -> float:
	if is_grounded:
		return GROUND_DECELERATION
	else:
		return AIR_DECELERATION


## Get height scale for crouch/prone.
func get_height_scale() -> float:
	match current_state:
		MovementState.CROUCHING, MovementState.CROUCH_WALKING, MovementState.SLIDING:
			return CROUCH_HEIGHT_SCALE
		MovementState.PRONE:
			return PRONE_HEIGHT_SCALE
		_:
			return 1.0


## Check if currently in a reduced-height state.
func is_height_reduced() -> bool:
	return get_height_scale() < 1.0


## Consume stamina, returns false if not enough.
func _consume_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	stamina_regen_delay_timer = STAMINA_REGEN_DELAY
	stamina_changed.emit(stamina, MAX_STAMINA)
	return true


## Apply a speed modifier (stacks multiplicatively).
func apply_speed_modifier(modifier: float, duration: float = -1.0) -> void:
	speed_modifier *= modifier
	# Duration handling would be done by caller or with a timer


## Remove a speed modifier.
func remove_speed_modifier(modifier: float) -> void:
	if modifier != 0.0:
		speed_modifier /= modifier


## Reset all modifiers to default.
func reset_modifiers() -> void:
	speed_modifier = 1.0
	acceleration_modifier = 1.0
	gravity_modifier = 1.0
	jump_modifier = 1.0


## Enable double jump ability.
func enable_double_jump() -> void:
	can_double_jump = true
	if is_grounded:
		has_double_jump = true
		jumps_remaining = max_jumps


## Disable double jump ability.
func disable_double_jump() -> void:
	can_double_jump = false
	has_double_jump = false


## Apply a stun effect.
func apply_stun(duration: float) -> void:
	_transition_to(MovementState.STUNNED)
	input_locked = true
	# Caller should handle timing and call remove_stun


## Remove stun effect.
func remove_stun() -> void:
	input_locked = false
	if is_grounded:
		_transition_to(MovementState.IDLE)
	else:
		_transition_to(MovementState.FALLING)


## Get state name for debugging/UI.
func get_state_name() -> String:
	return MovementState.keys()[current_state]


## Serialize state for network sync.
func serialize() -> Dictionary:
	return {
		"state": current_state,
		"velocity": velocity,
		"stamina": stamina,
		"jumps": jumps_remaining,
		"has_double": has_double_jump,
		"grounded": is_grounded,
		"wall": is_touching_wall,
		"invincible": is_invincible,
	}


## Deserialize state from network.
func deserialize(data: Dictionary) -> void:
	if data.has("state"):
		var new_state: int = data["state"]
		if new_state != current_state:
			_transition_to(new_state as MovementState)
	if data.has("velocity"):
		velocity = data["velocity"]
	if data.has("stamina"):
		stamina = data["stamina"]
	if data.has("jumps"):
		jumps_remaining = data["jumps"]
	if data.has("has_double"):
		has_double_jump = data["has_double"]
	if data.has("grounded"):
		is_grounded = data["grounded"]
	if data.has("wall"):
		is_touching_wall = data["wall"]
	if data.has("invincible"):
		is_invincible = data["invincible"]
