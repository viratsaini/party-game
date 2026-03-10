## AudioVisualizer - Animated audio bars showing volume levels with smooth interpolation.
##
## Features:
## - Animated frequency bars
## - Master volume affects all bars
## - Test sound button with waveform animation
## - Smooth interpolation
## - Reactive to audio changes
## - Customizable appearance
class_name AudioVisualizer
extends Control

# ============================================================================ #
#                                   SIGNALS                                     #
# ============================================================================ #

## Emitted when test sound is triggered.
signal test_sound_requested

# ============================================================================ #
#                                  CONSTANTS                                    #
# ============================================================================ #

const BAR_COUNT: int = 16
const BAR_MIN_HEIGHT: float = 4.0
const BAR_MAX_HEIGHT: float = 60.0
const BAR_WIDTH: float = 8.0
const BAR_GAP: float = 4.0
const BAR_CORNER_RADIUS: float = 3.0

const ANIMATION_SPEED: float = 8.0
const IDLE_ANIMATION_SPEED: float = 1.5
const TEST_ANIMATION_DURATION: float = 1.5
const DECAY_RATE: float = 3.0

const COLORS := {
	"bar_low": Color(0.2, 0.6, 1.0, 1.0),
	"bar_mid": Color(0.3, 0.8, 0.5, 1.0),
	"bar_high": Color(1.0, 0.5, 0.3, 1.0),
	"bar_peak": Color(1.0, 0.3, 0.3, 1.0),

	"bar_bg": Color(0.12, 0.12, 0.15, 1.0),
	"bar_glow": Color(0.3, 0.7, 1.0, 0.3),

	"label": Color(0.7, 0.7, 0.75, 1.0),
	"value": Color(1.0, 1.0, 1.0, 1.0),
}

# Frequency distribution pattern (simulated).
const FREQUENCY_WEIGHTS: Array[float] = [
	0.6, 0.8, 1.0, 0.9, 0.85, 0.7, 0.6, 0.5,
	0.45, 0.4, 0.35, 0.3, 0.25, 0.2, 0.15, 0.1
]

# ============================================================================ #
#                                  EXPORTS                                      #
# ============================================================================ #

## Master volume (0-1) that scales all bars.
@export var master_volume: float = 1.0:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_update_target_heights()

## Whether to show idle animation when not playing.
@export var show_idle_animation: bool = true

## Whether to show peak hold indicators.
@export var show_peak_hold: bool = true

## Custom gradient for bars.
@export var custom_gradient: Gradient = null

## Enable glow effects.
@export var enable_glow: bool = true

# ============================================================================ #
#                                   STATE                                       #
# ============================================================================ #

## Current bar heights (0-1 normalized).
var bar_heights: Array[float] = []

## Target bar heights.
var target_heights: Array[float] = []

## Peak hold heights.
var peak_heights: Array[float] = []

## Peak hold decay timers.
var peak_timers: Array[float] = []

## Is test animation playing.
var is_test_playing: bool = false

## Test animation progress (0-1).
var test_progress: float = 0.0

## Idle animation phase.
var idle_phase: float = 0.0

## Per-bar animation phases (for variation).
var bar_phases: Array[float] = []

## Glow intensities per bar.
var glow_intensities: Array[float] = []

# ============================================================================ #
#                                 LIFECYCLE                                     #
# ============================================================================ #

func _ready() -> void:
	custom_minimum_size = Vector2(BAR_COUNT * (BAR_WIDTH + BAR_GAP) + 20, BAR_MAX_HEIGHT + 30)

	# Initialize arrays.
	for i: int in BAR_COUNT:
		bar_heights.append(0.0)
		target_heights.append(0.0)
		peak_heights.append(0.0)
		peak_timers.append(0.0)
		bar_phases.append(randf() * TAU)
		glow_intensities.append(0.0)

	_update_target_heights()


func _process(delta: float) -> void:
	# Update idle animation.
	idle_phase += delta * IDLE_ANIMATION_SPEED
	if idle_phase > TAU:
		idle_phase -= TAU

	# Update test animation.
	if is_test_playing:
		test_progress += delta / TEST_ANIMATION_DURATION
		if test_progress >= 1.0:
			test_progress = 0.0
			is_test_playing = false
		_update_test_animation()

	# Animate bars towards targets.
	for i: int in BAR_COUNT:
		# Interpolate height.
		var target := target_heights[i]
		if show_idle_animation and not is_test_playing:
			# Add subtle idle movement.
			var idle_offset := sin(idle_phase + bar_phases[i]) * 0.1
			target = clampf(target + idle_offset, 0.0, 1.0)

		bar_heights[i] = lerpf(bar_heights[i], target, ANIMATION_SPEED * delta)

		# Update peak hold.
		if bar_heights[i] > peak_heights[i]:
			peak_heights[i] = bar_heights[i]
			peak_timers[i] = 0.8  # Hold time.
		elif peak_timers[i] > 0:
			peak_timers[i] -= delta
		else:
			peak_heights[i] = lerpf(peak_heights[i], bar_heights[i], DECAY_RATE * delta)

		# Update glow intensity.
		var target_glow := bar_heights[i] if bar_heights[i] > 0.3 else 0.0
		glow_intensities[i] = lerpf(glow_intensities[i], target_glow, 6.0 * delta)

	queue_redraw()


func _draw() -> void:
	_draw_background()
	_draw_bars()
	_draw_labels()

# ============================================================================ #
#                                  DRAWING                                      #
# ============================================================================ #

func _draw_background() -> void:
	# Background panel.
	var bg_rect := Rect2(Vector2.ZERO, size)
	_draw_rounded_rect(bg_rect, 8.0, Color(0.08, 0.08, 0.1, 0.5))


func _draw_bars() -> void:
	var start_x := (size.x - (BAR_COUNT * (BAR_WIDTH + BAR_GAP) - BAR_GAP)) / 2
	var base_y := size.y - 25

	for i: int in BAR_COUNT:
		var x := start_x + i * (BAR_WIDTH + BAR_GAP)
		var height := BAR_MIN_HEIGHT + bar_heights[i] * (BAR_MAX_HEIGHT - BAR_MIN_HEIGHT)
		var bar_rect := Rect2(
			Vector2(x, base_y - height),
			Vector2(BAR_WIDTH, height)
		)

		# Draw bar background (track).
		var track_rect := Rect2(
			Vector2(x, base_y - BAR_MAX_HEIGHT),
			Vector2(BAR_WIDTH, BAR_MAX_HEIGHT)
		)
		_draw_rounded_rect(track_rect, BAR_CORNER_RADIUS, COLORS["bar_bg"])

		# Draw glow.
		if enable_glow and glow_intensities[i] > 0.1:
			var glow_color := _get_bar_color(bar_heights[i])
			glow_color.a = 0.3 * glow_intensities[i]
			var glow_rect := bar_rect.grow(3)
			_draw_rounded_rect(glow_rect, BAR_CORNER_RADIUS + 2, glow_color)

		# Draw filled bar.
		var bar_color := _get_bar_color(bar_heights[i])
		_draw_rounded_rect(bar_rect, BAR_CORNER_RADIUS, bar_color)

		# Draw peak hold indicator.
		if show_peak_hold and peak_heights[i] > bar_heights[i] + 0.05:
			var peak_y := base_y - BAR_MIN_HEIGHT - peak_heights[i] * (BAR_MAX_HEIGHT - BAR_MIN_HEIGHT)
			var peak_alpha := minf(peak_timers[i] / 0.3, 1.0)
			draw_line(
				Vector2(x, peak_y),
				Vector2(x + BAR_WIDTH, peak_y),
				Color(COLORS["bar_peak"], peak_alpha),
				2.0, true
			)

		# Draw highlight on bar.
		var highlight_rect := Rect2(
			bar_rect.position + Vector2(2, 2),
			Vector2(2, bar_rect.size.y * 0.3)
		)
		draw_rect(highlight_rect, Color(1, 1, 1, 0.2))


func _draw_labels() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 11

	# Volume percentage.
	var volume_text := "%d%%" % roundi(master_volume * 100)
	var text_size := font.get_string_size(volume_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := Vector2(size.x / 2 - text_size.x / 2, size.y - 5)

	draw_string(font, text_pos, volume_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLORS["value"])

	# Labels.
	var low_label := "LOW"
	var high_label := "HIGH"
	draw_string(font, Vector2(10, size.y - 5), low_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLORS["label"])
	draw_string(font, Vector2(size.x - 35, size.y - 5), high_label, HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, COLORS["label"])


func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	# Simplified rounded rect.
	radius = minf(radius, minf(rect.size.x, rect.size.y) / 2)

	var inner_rect := Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2, rect.size.y)
	draw_rect(inner_rect, color)
	draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius * 2), color)

	draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.end.y - radius), radius, color)


func _get_bar_color(normalized_height: float) -> Color:
	if custom_gradient:
		return custom_gradient.sample(normalized_height)

	# Color based on height.
	if normalized_height < 0.5:
		return COLORS["bar_low"].lerp(COLORS["bar_mid"], normalized_height * 2)
	elif normalized_height < 0.8:
		return COLORS["bar_mid"].lerp(COLORS["bar_high"], (normalized_height - 0.5) * 3.33)
	else:
		return COLORS["bar_high"].lerp(COLORS["bar_peak"], (normalized_height - 0.8) * 5)

# ============================================================================ #
#                                  ANIMATION                                    #
# ============================================================================ #

func _update_target_heights() -> void:
	for i: int in BAR_COUNT:
		# Base height from frequency weight and master volume.
		var base_height := FREQUENCY_WEIGHTS[i] * master_volume

		# Add some randomness.
		var variance := randf_range(-0.1, 0.1)
		target_heights[i] = clampf(base_height + variance, 0.0, 1.0)


func _update_test_animation() -> void:
	# Wave animation during test sound.
	var wave_position := test_progress * BAR_COUNT * 2

	for i: int in BAR_COUNT:
		var distance := abs(float(i) - wave_position)
		var wave_height := maxf(0.0, 1.0 - distance * 0.15)
		wave_height *= sin(test_progress * PI)  # Fade in/out.

		# Combine with base target.
		var base_target := FREQUENCY_WEIGHTS[i] * master_volume
		target_heights[i] = clampf(base_target + wave_height * 0.5, 0.0, 1.0)


func play_test_animation() -> void:
	is_test_playing = true
	test_progress = 0.0
	test_sound_requested.emit()


func simulate_audio_input(spectrum: Array[float]) -> void:
	# Receive external audio spectrum data.
	for i: int in mini(spectrum.size(), BAR_COUNT):
		target_heights[i] = clampf(spectrum[i] * master_volume, 0.0, 1.0)


func set_random_activity(intensity: float) -> void:
	# Set random bar activity for visualization.
	for i: int in BAR_COUNT:
		var base := FREQUENCY_WEIGHTS[i] * intensity * master_volume
		var variance := randf_range(-0.15, 0.15)
		target_heights[i] = clampf(base + variance, 0.0, 1.0)

# ============================================================================ #
#                                PUBLIC API                                     #
# ============================================================================ #

## Set master volume.
func set_master_volume(volume: float) -> void:
	master_volume = volume


## Trigger test sound visualization.
func trigger_test() -> void:
	play_test_animation()


## Reset all bars to zero.
func reset() -> void:
	for i: int in BAR_COUNT:
		target_heights[i] = 0.0
		peak_heights[i] = 0.0
		peak_timers[i] = 0.0


## Set activity level (0-1) for ambient visualization.
func set_activity_level(level: float) -> void:
	set_random_activity(level)
