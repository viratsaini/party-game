## Menu FX Manager - Central Effects Controller for Round 2 Ultra-Premium UI
## Coordinates all visual effects, shaders, particles, and audio synchronization.
## Features:
## - Centralized effect orchestration
## - Haptic feedback patterns
## - Sound synchronization with animations
## - Smart adaptation based on player behavior
## - Performance-based effect scaling
## - Time-of-day color grading
## - Cursor trail management
## - Button magnetism control
class_name MenuFXManager
extends Node


# ==============================================================================
# SIGNALS
# ==============================================================================

signal effect_started(effect_name: String)
signal effect_completed(effect_name: String)
signal performance_warning(fps: float)
signal adaptation_triggered(adaptation_type: String)


# ==============================================================================
# ENUMS
# ==============================================================================

enum EffectIntensity {
	MINIMAL,
	LOW,
	MEDIUM,
	HIGH,
	ULTRA,
}

enum HapticPattern {
	NONE,
	LIGHT_TAP,
	MEDIUM_TAP,
	HEAVY_TAP,
	DOUBLE_TAP,
	TRIPLE_TAP,
	LONG_PRESS,
	SUCCESS,
	ERROR,
	WARNING,
	SCROLL,
	DRAG,
	RELEASE,
}

enum AdaptationType {
	BUTTON_GROWTH,         ## Frequently used buttons grow
	ANIMATION_SPEEDUP,     ## Seen animations play faster
	DIFFICULTY_INTENSITY,  ## Visual intensity based on difficulty
	PERFORMANCE_SCALE,     ## Auto-scale based on FPS
}


# ==============================================================================
# CONSTANTS
# ==============================================================================

## Haptic durations (seconds)
const HAPTIC_DURATIONS: Dictionary = {
	HapticPattern.LIGHT_TAP: 0.01,
	HapticPattern.MEDIUM_TAP: 0.02,
	HapticPattern.HEAVY_TAP: 0.04,
	HapticPattern.DOUBLE_TAP: 0.015,
	HapticPattern.TRIPLE_TAP: 0.012,
	HapticPattern.LONG_PRESS: 0.1,
	HapticPattern.SUCCESS: 0.03,
	HapticPattern.ERROR: 0.05,
	HapticPattern.WARNING: 0.025,
	HapticPattern.SCROLL: 0.005,
	HapticPattern.DRAG: 0.008,
	HapticPattern.RELEASE: 0.015,
}

## Magnetic snap configuration
const MAGNETIC_SNAP_BASE_RADIUS: float = 80.0
const MAGNETIC_SNAP_BASE_STRENGTH: float = 0.15
const MAGNETIC_SNAP_AGGRESSIVE_MULTIPLIER: float = 2.5

## Cursor trail configuration
const CURSOR_TRAIL_MIN_SPEED: float = 100.0
const CURSOR_TRAIL_MAX_PARTICLES: int = 20

## Performance thresholds
const FPS_EXCELLENT: float = 120.0
const FPS_GOOD: float = 60.0
const FPS_ACCEPTABLE: float = 45.0
const FPS_POOR: float = 30.0

## Adaptation thresholds
const BUTTON_USE_COUNT_FOR_GROWTH: int = 3
const ANIMATION_SEEN_COUNT_FOR_SPEEDUP: int = 2


# ==============================================================================
# STATE
# ==============================================================================

## Effect systems references
var _particles: Control = null
var _advanced_particles: Control = null
var _shader_effects: Node = null

## Current settings
var _effect_intensity: EffectIntensity = EffectIntensity.HIGH
var _haptic_enabled: bool = true
var _sound_sync_enabled: bool = true
var _adaptation_enabled: bool = true

## Cursor state
var _cursor_position: Vector2 = Vector2.ZERO
var _cursor_velocity: Vector2 = Vector2.ZERO
var _last_cursor_position: Vector2 = Vector2.ZERO
var _cursor_speed: float = 0.0
var _cursor_trail_particles: Array = []

## Time of day (0-24 hours)
var _time_of_day: float = 12.0
var _use_system_time: bool = true

## Button magnetism
var _magnetic_buttons: Dictionary = {}  # Button -> original_position
var _magnetic_snap_radius: float = MAGNETIC_SNAP_BASE_RADIUS
var _magnetic_snap_strength: float = MAGNETIC_SNAP_BASE_STRENGTH

## Performance monitoring
var _frame_times: Array[float] = []
var _current_fps: float = 60.0
var _performance_scale: float = 1.0

## Player behavior tracking (for adaptation)
var _button_use_counts: Dictionary = {}  # Button name -> use count
var _animation_seen_counts: Dictionary = {}  # Animation name -> seen count
var _session_start_time: float = 0.0

## Idle animation state
var _idle_animation_phases: Dictionary = {}  # Control -> phase offset

## Active effects tracking
var _active_effects: Dictionary = {}


# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_session_start_time = Time.get_unix_time_from_system()
	_update_time_of_day()

	# Create timer for periodic updates
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_periodic_update)
	add_child(timer)


func _process(delta: float) -> void:
	_update_cursor_state(delta)
	_update_magnetic_buttons(delta)
	_update_cursor_trail()
	_monitor_performance(delta)
	_update_time_of_day()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cursor_position = event.position


# ==============================================================================
# INITIALIZATION
# ==============================================================================

## Initialize with effect system references
func initialize(particles: Control, advanced_particles: Control = null, shader_effects: Node = null) -> void:
	_particles = particles
	_advanced_particles = advanced_particles
	_shader_effects = shader_effects

	print("[MenuFXManager] Initialized with particle systems")


## Set effect intensity level
func set_effect_intensity(intensity: EffectIntensity) -> void:
	_effect_intensity = intensity
	_apply_intensity_settings()


func _apply_intensity_settings() -> void:
	match _effect_intensity:
		EffectIntensity.MINIMAL:
			_magnetic_snap_radius = MAGNETIC_SNAP_BASE_RADIUS * 0.5
			_magnetic_snap_strength = MAGNETIC_SNAP_BASE_STRENGTH * 0.3
		EffectIntensity.LOW:
			_magnetic_snap_radius = MAGNETIC_SNAP_BASE_RADIUS * 0.75
			_magnetic_snap_strength = MAGNETIC_SNAP_BASE_STRENGTH * 0.5
		EffectIntensity.MEDIUM:
			_magnetic_snap_radius = MAGNETIC_SNAP_BASE_RADIUS
			_magnetic_snap_strength = MAGNETIC_SNAP_BASE_STRENGTH
		EffectIntensity.HIGH:
			_magnetic_snap_radius = MAGNETIC_SNAP_BASE_RADIUS * 1.25
			_magnetic_snap_strength = MAGNETIC_SNAP_BASE_STRENGTH * 1.5
		EffectIntensity.ULTRA:
			_magnetic_snap_radius = MAGNETIC_SNAP_BASE_RADIUS * MAGNETIC_SNAP_AGGRESSIVE_MULTIPLIER
			_magnetic_snap_strength = MAGNETIC_SNAP_BASE_STRENGTH * 2.0


# ==============================================================================
# CURSOR MANAGEMENT
# ==============================================================================

func _update_cursor_state(delta: float) -> void:
	_cursor_velocity = (_cursor_position - _last_cursor_position) / delta
	_cursor_speed = _cursor_velocity.length()
	_last_cursor_position = _cursor_position


func _update_cursor_trail() -> void:
	if _effect_intensity < EffectIntensity.MEDIUM:
		return

	if _cursor_speed < CURSOR_TRAIL_MIN_SPEED:
		return

	if _advanced_particles == null:
		return

	# Emit trail particle with color based on speed
	var speed_factor: float = clampf(_cursor_speed / 500.0, 0.0, 1.0)
	var trail_color: Color = Color(0.5, 0.8, 1.0).lerp(Color(1.0, 0.4, 0.2), speed_factor)
	trail_color.a = 0.6

	if _advanced_particles.has_method("emit_cursor_trail"):
		_advanced_particles.emit_cursor_trail(trail_color)


## Get cursor color based on current speed
func get_cursor_trail_color() -> Color:
	var speed_factor: float = clampf(_cursor_speed / 500.0, 0.0, 1.0)

	# Slow: Blue, Fast: Orange/Red
	if speed_factor < 0.3:
		return Color(0.4, 0.7, 1.0, 0.6)
	elif speed_factor < 0.6:
		return Color(0.8, 0.8, 0.3, 0.7)
	else:
		return Color(1.0, 0.4, 0.2, 0.8)


# ==============================================================================
# MAGNETIC BUTTON SYSTEM
# ==============================================================================

## Register a button for magnetic snap effect
func register_magnetic_button(button: Button) -> void:
	_magnetic_buttons[button] = button.position
	_idle_animation_phases[button] = randf() * TAU  # Random phase for breathing


## Unregister a button from magnetic snap
func unregister_magnetic_button(button: Button) -> void:
	_magnetic_buttons.erase(button)
	_idle_animation_phases.erase(button)


func _update_magnetic_buttons(delta: float) -> void:
	for button: Button in _magnetic_buttons.keys():
		if not is_instance_valid(button) or not button.visible:
			continue

		var original_pos: Vector2 = _magnetic_buttons[button]
		var button_center: Vector2 = button.global_position + button.size / 2.0
		var distance: float = button_center.distance_to(_cursor_position)

		if distance < _magnetic_snap_radius and distance > 1.0:
			# Apply magnetic attraction
			var direction: Vector2 = (_cursor_position - button_center).normalized()
			var factor: float = (1.0 - distance / _magnetic_snap_radius)
			factor = factor * factor  # Quadratic for more aggressive snap near cursor

			var offset: Vector2 = direction * factor * _magnetic_snap_strength * 30.0
			button.position = button.position.lerp(original_pos + offset, delta * 8.0)
		else:
			# Return to original position
			button.position = button.position.lerp(original_pos, delta * 5.0)


## Set aggressive snap mode (for Round 2 more aggressive magnetism)
func set_aggressive_snap(enabled: bool) -> void:
	if enabled:
		_magnetic_snap_radius = MAGNETIC_SNAP_BASE_RADIUS * MAGNETIC_SNAP_AGGRESSIVE_MULTIPLIER
		_magnetic_snap_strength = MAGNETIC_SNAP_BASE_STRENGTH * 2.0
	else:
		_apply_intensity_settings()


# ==============================================================================
# HAPTIC FEEDBACK
# ==============================================================================

## Trigger haptic feedback pattern
func trigger_haptic(pattern: HapticPattern) -> void:
	if not _haptic_enabled:
		return

	if pattern == HapticPattern.NONE:
		return

	var duration: float = HAPTIC_DURATIONS.get(pattern, 0.02)

	# Platform-specific haptic implementation
	match pattern:
		HapticPattern.DOUBLE_TAP:
			_play_haptic_sequence([duration, 0.03, duration])
		HapticPattern.TRIPLE_TAP:
			_play_haptic_sequence([duration, 0.02, duration, 0.02, duration])
		HapticPattern.SUCCESS:
			_play_haptic_sequence([duration * 0.5, 0.05, duration])
		HapticPattern.ERROR:
			_play_haptic_sequence([duration, 0.03, duration, 0.03, duration])
		_:
			_vibrate(duration)


func _vibrate(duration: float) -> void:
	# Godot 4 vibration (mobile)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(int(duration * 1000))


func _play_haptic_sequence(sequence: Array) -> void:
	var total_delay: float = 0.0

	for i in range(sequence.size()):
		if i % 2 == 0:
			# Vibration
			var timer := get_tree().create_timer(total_delay)
			var duration: float = sequence[i]
			timer.timeout.connect(func(): _vibrate(duration))
		total_delay += sequence[i]


## Enable/disable haptic feedback
func set_haptic_enabled(enabled: bool) -> void:
	_haptic_enabled = enabled


# ==============================================================================
# SOUND SYNCHRONIZATION
# ==============================================================================

## Play sound synchronized with animation frame
func play_sound_at_frame(sound_name: String, animation_progress: float, target_progress: float, tolerance: float = 0.05) -> void:
	if not _sound_sync_enabled:
		return

	if absf(animation_progress - target_progress) <= tolerance:
		_play_sound(sound_name)


## Play sound with intensity based on effect
func play_sound_with_intensity(sound_name: String, intensity: float = 1.0) -> void:
	if not _sound_sync_enabled:
		return

	# Scale volume based on intensity
	var volume_db: float = lerpf(-20.0, 0.0, intensity)
	_play_sound(sound_name, volume_db)


func _play_sound(sound_name: String, volume_db: float = 0.0) -> void:
	if Engine.has_singleton("AudioManager"):
		var audio_manager = Engine.get_singleton("AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx(sound_name)
	elif is_instance_valid(get_node_or_null("/root/AudioManager")):
		var audio_manager = get_node("/root/AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx(sound_name)


## Set sound synchronization enabled
func set_sound_sync_enabled(enabled: bool) -> void:
	_sound_sync_enabled = enabled


# ==============================================================================
# BUTTON EFFECTS
# ==============================================================================

## Create shockwave ripple from button press
func emit_button_shockwave(button: Button, color: Color = Color(1.0, 0.9, 0.5, 0.8)) -> void:
	if _effect_intensity < EffectIntensity.LOW:
		return

	var center: Vector2 = button.global_position + button.size / 2.0
	var radius: float = maxf(button.size.x, button.size.y) * 1.5

	if _advanced_particles != null and _advanced_particles.has_method("emit_shockwave"):
		_advanced_particles.emit_shockwave(center, color, radius)

	# Also trigger haptic
	trigger_haptic(HapticPattern.MEDIUM_TAP)

	effect_started.emit("button_shockwave")


## Create vortex effect pulling particles to button
func emit_button_vortex(button: Button, color: Color = Color.CYAN) -> void:
	if _effect_intensity < EffectIntensity.MEDIUM:
		return

	var target: Vector2 = button.global_position + button.size / 2.0
	var source_area: Rect2 = Rect2(
		button.global_position - Vector2(100, 100),
		button.size + Vector2(200, 200)
	)

	if _advanced_particles != null and _advanced_particles.has_method("emit_vortex"):
		_advanced_particles.emit_vortex(target, source_area, color)


## Start idle breathing animation for buttons (individual phases)
func start_button_breathing(buttons: Array[Button]) -> void:
	for button in buttons:
		if not _idle_animation_phases.has(button):
			_idle_animation_phases[button] = randf() * TAU

		_animate_button_breath(button)


func _animate_button_breath(button: Button) -> void:
	var phase: float = _idle_animation_phases.get(button, 0.0)
	var breath_speed: float = randf_range(0.8, 1.2)  # Slightly different speeds

	var tween: Tween = button.create_tween()
	tween.set_loops()

	# Inhale (expand)
	tween.tween_property(button, "scale", Vector2(1.02, 1.02), 1.5 / breath_speed)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_delay(phase * 0.5)

	# Exhale (contract)
	tween.tween_property(button, "scale", Vector2(0.98, 0.98), 1.5 / breath_speed)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# Return to normal
	tween.tween_property(button, "scale", Vector2.ONE, 0.5 / breath_speed)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


# ==============================================================================
# TRANSITION EFFECTS
# ==============================================================================

## Liquid morphing transition effect
func play_liquid_morph(from_control: Control, to_control: Control, duration: float = 0.6) -> void:
	effect_started.emit("liquid_morph")

	# Hide target initially
	to_control.modulate.a = 0.0
	to_control.visible = true

	var tween: Tween = from_control.create_tween()
	tween.set_parallel(true)

	# From control: stretch and fade
	tween.tween_property(from_control, "scale", Vector2(0.8, 1.2), duration * 0.4)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)

	tween.tween_property(from_control, "modulate:a", 0.0, duration * 0.4)

	# Wait then show target
	tween.chain()

	tween.tween_property(to_control, "scale", Vector2(1.2, 0.8), 0.0)
	tween.tween_property(to_control, "modulate:a", 1.0, duration * 0.4)

	tween.tween_property(to_control, "scale", Vector2.ONE, duration * 0.3)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)

	tween.chain()
	tween.tween_callback(func():
		from_control.visible = false
		from_control.scale = Vector2.ONE
		effect_completed.emit("liquid_morph")
	)


## Origami-style folding transition
func play_origami_fold(control: Control, fold_out: bool = true, duration: float = 0.5) -> void:
	effect_started.emit("origami_fold")

	control.pivot_offset = control.size / 2.0

	var tween: Tween = control.create_tween()
	tween.set_parallel(true)

	if fold_out:
		# Fold out (appear)
		control.scale = Vector2(0.0, 1.0)
		control.rotation = deg_to_rad(90)
		control.modulate.a = 0.0
		control.visible = true

		tween.tween_property(control, "scale:x", 1.0, duration)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		tween.tween_property(control, "rotation", 0.0, duration * 0.8)\
			.set_trans(Tween.TRANS_ELASTIC)\
			.set_ease(Tween.EASE_OUT)

		tween.tween_property(control, "modulate:a", 1.0, duration * 0.5)
	else:
		# Fold in (disappear)
		tween.tween_property(control, "scale:x", 0.0, duration)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_IN)

		tween.tween_property(control, "rotation", deg_to_rad(-90), duration * 0.8)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)

		tween.tween_property(control, "modulate:a", 0.0, duration * 0.5)

	tween.chain()
	tween.tween_callback(func():
		if not fold_out:
			control.visible = false
			control.scale = Vector2.ONE
			control.rotation = 0.0
		effect_completed.emit("origami_fold")
	)


## Portal effect for scene transitions
func play_portal_effect(center: Vector2, duration: float = 0.8) -> void:
	effect_started.emit("portal")

	# Emit vortex particles
	if _advanced_particles != null and _advanced_particles.has_method("emit_vortex"):
		var screen_rect: Rect2 = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		_advanced_particles.emit_vortex(center, screen_rect, Color(0.5, 0.3, 1.0, 0.8), 50)

	# Emit energy pulse
	if _advanced_particles != null and _advanced_particles.has_method("trigger_energy_pulse"):
		_advanced_particles.trigger_energy_pulse(center, 400.0)

	# Play sound
	play_sound_with_intensity("whoosh", 1.0)
	trigger_haptic(HapticPattern.HEAVY_TAP)

	# Signal completion after duration
	get_tree().create_timer(duration).timeout.connect(func():
		effect_completed.emit("portal")
	)


## Time dilation effect (slow motion feel)
func play_time_dilation(control: Control, duration: float = 0.5) -> void:
	effect_started.emit("time_dilation")

	var original_scale: Vector2 = control.scale

	var tween: Tween = control.create_tween()

	# Initial impact
	tween.tween_property(control, "scale", original_scale * 1.15, 0.05)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_OUT)

	# Slow return (time dilation feel)
	tween.tween_property(control, "scale", original_scale, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	trigger_haptic(HapticPattern.LONG_PRESS)

	tween.finished.connect(func():
		effect_completed.emit("time_dilation")
	)


## Camera shake with physics
func play_camera_shake(target: Control, intensity: float = 10.0, duration: float = 0.3, decay: bool = true) -> void:
	effect_started.emit("camera_shake")

	var original_pos: Vector2 = target.position
	var elapsed: float = 0.0

	var shake_tween: Tween = target.create_tween()

	var shake_count: int = int(duration / 0.03)
	for i in range(shake_count):
		var progress: float = float(i) / shake_count
		var current_intensity: float = intensity * (1.0 - progress if decay else 1.0)

		var offset: Vector2 = Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)

		shake_tween.tween_property(target, "position", original_pos + offset, 0.03)

	shake_tween.tween_property(target, "position", original_pos, 0.05)

	trigger_haptic(HapticPattern.HEAVY_TAP)

	shake_tween.finished.connect(func():
		target.position = original_pos
		effect_completed.emit("camera_shake")
	)


# ==============================================================================
# SMART ADAPTATION
# ==============================================================================

## Track button usage for adaptation
func track_button_use(button_name: String) -> void:
	if not _adaptation_enabled:
		return

	_button_use_counts[button_name] = _button_use_counts.get(button_name, 0) + 1

	# Check if should trigger growth adaptation
	if _button_use_counts[button_name] >= BUTTON_USE_COUNT_FOR_GROWTH:
		adaptation_triggered.emit("button_growth")


## Track animation views for speedup
func track_animation_seen(animation_name: String) -> void:
	if not _adaptation_enabled:
		return

	_animation_seen_counts[animation_name] = _animation_seen_counts.get(animation_name, 0) + 1


## Get animation duration multiplier (faster for seen animations)
func get_animation_speed_multiplier(animation_name: String) -> float:
	if not _adaptation_enabled:
		return 1.0

	var seen_count: int = _animation_seen_counts.get(animation_name, 0)

	if seen_count >= ANIMATION_SEEN_COUNT_FOR_SPEEDUP:
		# Speed up by 20% per viewing, max 2x speed
		return minf(1.0 + (seen_count - ANIMATION_SEEN_COUNT_FOR_SPEEDUP + 1) * 0.2, 2.0)

	return 1.0


## Get button scale multiplier (larger for frequently used)
func get_button_scale_multiplier(button_name: String) -> float:
	if not _adaptation_enabled:
		return 1.0

	var use_count: int = _button_use_counts.get(button_name, 0)

	if use_count >= BUTTON_USE_COUNT_FOR_GROWTH:
		# Grow by 2% per use after threshold, max 15% growth
		return minf(1.0 + (use_count - BUTTON_USE_COUNT_FOR_GROWTH + 1) * 0.02, 1.15)

	return 1.0


## Set adaptation enabled
func set_adaptation_enabled(enabled: bool) -> void:
	_adaptation_enabled = enabled


## Reset adaptation data (new session)
func reset_adaptation() -> void:
	_button_use_counts.clear()
	_animation_seen_counts.clear()


# ==============================================================================
# TIME OF DAY
# ==============================================================================

func _update_time_of_day() -> void:
	if _use_system_time:
		var time: Dictionary = Time.get_time_dict_from_system()
		_time_of_day = float(time["hour"]) + float(time["minute"]) / 60.0


## Get current time-of-day tint color
func get_time_of_day_tint() -> Color:
	# Dawn (5-8): Warm orange
	# Day (8-17): Neutral/bright
	# Dusk (17-20): Warm pink/orange
	# Night (20-5): Cool blue

	if _time_of_day < 5.0 or _time_of_day >= 20.0:
		# Night
		return Color(0.7, 0.8, 1.0, 1.0)
	elif _time_of_day < 8.0:
		# Dawn
		var t: float = (_time_of_day - 5.0) / 3.0
		return Color(0.7, 0.8, 1.0).lerp(Color(1.0, 0.9, 0.8), t)
	elif _time_of_day < 17.0:
		# Day
		return Color(1.0, 1.0, 1.0, 1.0)
	else:
		# Dusk
		var t: float = (_time_of_day - 17.0) / 3.0
		return Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.8, 0.7), t)


## Set manual time of day (0-24)
func set_time_of_day(hours: float) -> void:
	_use_system_time = false
	_time_of_day = fmod(hours, 24.0)


## Use system time
func use_system_time() -> void:
	_use_system_time = true


# ==============================================================================
# PERFORMANCE MONITORING
# ==============================================================================

func _monitor_performance(delta: float) -> void:
	var frame_time: float = delta * 1000.0  # Convert to ms
	_frame_times.append(frame_time)

	if _frame_times.size() > 60:
		_frame_times.pop_front()

	# Calculate average FPS
	var avg_frame_time: float = 0.0
	for t in _frame_times:
		avg_frame_time += t
	avg_frame_time /= _frame_times.size()

	_current_fps = 1000.0 / avg_frame_time if avg_frame_time > 0 else 60.0

	# Update performance scale
	_update_performance_scale()


func _update_performance_scale() -> void:
	if _current_fps >= FPS_EXCELLENT:
		_performance_scale = 1.0
	elif _current_fps >= FPS_GOOD:
		_performance_scale = 0.9
	elif _current_fps >= FPS_ACCEPTABLE:
		_performance_scale = 0.7
		performance_warning.emit(_current_fps)
	else:
		_performance_scale = 0.5
		performance_warning.emit(_current_fps)


## Get current performance scale (0.0 - 1.0)
func get_performance_scale() -> float:
	return _performance_scale


## Get current FPS
func get_current_fps() -> float:
	return _current_fps


# ==============================================================================
# PERIODIC UPDATE
# ==============================================================================

func _on_periodic_update() -> void:
	# Update time of day
	_update_time_of_day()

	# Clean up invalid button references
	var invalid_buttons: Array = []
	for button: Button in _magnetic_buttons.keys():
		if not is_instance_valid(button):
			invalid_buttons.append(button)

	for button in invalid_buttons:
		_magnetic_buttons.erase(button)
		_idle_animation_phases.erase(button)


# ==============================================================================
# UTILITY
# ==============================================================================

## Get cursor position
func get_cursor_position() -> Vector2:
	return _cursor_position


## Get cursor speed
func get_cursor_speed() -> float:
	return _cursor_speed


## Check if effect is currently active
func is_effect_active(effect_name: String) -> bool:
	return _active_effects.has(effect_name)


## Get session duration in seconds
func get_session_duration() -> float:
	return Time.get_unix_time_from_system() - _session_start_time
