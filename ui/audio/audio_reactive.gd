## AudioReactive - Audio-reactive visual effects system for BattleZone Party.
##
## This system creates stunning visual effects that react to audio in real-time.
## Features include FFT spectrum analysis, beat detection with configurable
## sensitivity, BPM synchronization, audio-driven particles, glow effects,
## color pulses, and waveform visualization. Perfect for creating immersive
## audio-visual experiences in menus and gameplay.
class_name AudioReactive
extends Node


# -- Signals --

## Emitted on every detected beat.
signal beat_detected(beat_strength: float, beat_type: BeatType)

## Emitted when BPM is detected or changes.
signal bpm_detected(bpm: float, confidence: float)

## Emitted with spectrum data each frame.
signal spectrum_updated(spectrum: Array[float])

## Emitted when bass frequency energy spikes.
signal bass_hit(intensity: float)

## Emitted with waveform data each frame.
signal waveform_updated(waveform: Array[float])

## Emitted when audio intensity changes significantly.
signal intensity_changed(intensity: float)


# -- Enums --

## Types of beats for different reactions.
enum BeatType {
	KICK,       ## Low frequency beats (bass drum)
	SNARE,      ## Mid frequency beats
	HIHAT,      ## High frequency beats
	GENERAL,    ## Overall energy beat
}

## Frequency bands for analysis.
enum FrequencyBand {
	SUB_BASS,       ## 20-60 Hz
	BASS,           ## 60-250 Hz
	LOW_MID,        ## 250-500 Hz
	MID,            ## 500-2000 Hz
	HIGH_MID,       ## 2000-4000 Hz
	PRESENCE,       ## 4000-6000 Hz
	BRILLIANCE,     ## 6000-20000 Hz
}

## Visual effect types.
enum VisualEffect {
	PARTICLES,
	GLOW,
	COLOR_PULSE,
	SCALE_PULSE,
	SHAKE,
	WAVE_DISTORT,
	CHROMATIC,
}


# -- Constants --

## FFT buffer size (must be power of 2).
const FFT_SIZE: int = 1024

## Number of spectrum bands for visualization.
const SPECTRUM_BANDS: int = 32

## Beat detection history length.
const BEAT_HISTORY_SIZE: int = 43

## Minimum BPM for detection.
const MIN_BPM: float = 60.0

## Maximum BPM for detection.
const MAX_BPM: float = 200.0

## Default smoothing factor for spectrum.
const DEFAULT_SMOOTHING: float = 0.8


# -- Exports --

@export_group("Audio Analysis")

## Audio bus to analyze (must have AudioEffectSpectrumAnalyzer).
@export var audio_bus: StringName = &"Master"

## Spectrum analyzer effect index on the bus.
@export var analyzer_effect_index: int = 0

## Smoothing factor for spectrum data (0-1, higher = smoother).
@export_range(0.0, 0.99, 0.01) var spectrum_smoothing: float = DEFAULT_SMOOTHING

## Enable automatic BPM detection.
@export var auto_bpm_detection: bool = true

@export_group("Beat Detection")

## Beat detection sensitivity (lower = more sensitive).
@export_range(0.5, 3.0, 0.1) var beat_sensitivity: float = 1.4

## Minimum time between beats (prevents double-triggers).
@export_range(0.05, 0.5, 0.01) var min_beat_interval: float = 0.15

## Enable separate detection for kick/snare/hihat.
@export var multi_band_detection: bool = true

@export_group("Visual Reactions")

## Master intensity multiplier for all effects.
@export_range(0.0, 2.0, 0.1) var effect_intensity: float = 1.0

## Enable particle reactions to audio.
@export var particles_enabled: bool = true

## Enable glow reactions to audio.
@export var glow_enabled: bool = true

## Enable color pulse reactions.
@export var color_pulse_enabled: bool = true

## Enable shake effects on heavy beats.
@export var shake_enabled: bool = true


# -- State --

## Spectrum analyzer instance.
var _spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance = null

## Current smoothed spectrum data.
var _spectrum_data: Array[float] = []

## Raw spectrum data before smoothing.
var _spectrum_raw: Array[float] = []

## Peak values for each band (for normalization).
var _spectrum_peaks: Array[float] = []

## Beat detection history per frequency band.
var _beat_history: Dictionary = {}  # FrequencyBand -> Array[float]

## Time since last beat per band.
var _last_beat_time: Dictionary = {}  # FrequencyBand -> float

## Current overall audio intensity (0-1).
var _current_intensity: float = 0.0

## Smoothed intensity for visual effects.
var _smoothed_intensity: float = 0.0

## Detected BPM.
var _detected_bpm: float = 120.0

## BPM detection confidence (0-1).
var _bpm_confidence: float = 0.0

## Beat timestamps for BPM calculation.
var _beat_timestamps: Array[float] = []

## Current beat phase (0-1) for smooth animations.
var _beat_phase: float = 0.0

## Waveform data.
var _waveform_data: Array[float] = []

## Frequency band energy levels.
var _band_energies: Dictionary = {}  # FrequencyBand -> float

## Registered visual effect targets.
var _effect_targets: Array[EffectTarget] = []

## Bass accumulator for bass hits.
var _bass_accumulator: float = 0.0
var _bass_threshold: float = 0.7

## Time tracking.
var _time: float = 0.0


# -- Effect Target Class --

class EffectTarget extends RefCounted:
	var node: Node = null
	var effects: Array[int] = []  # Array of VisualEffect
	var intensity_mult: float = 1.0
	var frequency_band: int = FrequencyBand.BASS
	var property_overrides: Dictionary = {}

	## Original values for reset.
	var original_scale: Vector2 = Vector2.ONE
	var original_modulate: Color = Color.WHITE
	var original_position: Vector2 = Vector2.ZERO


# -- Lifecycle --

func _ready() -> void:
	_initialize_spectrum_arrays()
	_connect_to_analyzer()


func _process(delta: float) -> void:
	_time += delta

	if _spectrum_analyzer:
		_update_spectrum_data()
		_detect_beats(delta)
		_update_intensity(delta)
		_update_beat_phase(delta)

		if auto_bpm_detection:
			_detect_bpm()

	_apply_visual_effects(delta)


# -- Initialization --

func _initialize_spectrum_arrays() -> void:
	_spectrum_data.resize(SPECTRUM_BANDS)
	_spectrum_raw.resize(SPECTRUM_BANDS)
	_spectrum_peaks.resize(SPECTRUM_BANDS)
	_waveform_data.resize(FFT_SIZE)

	for i in SPECTRUM_BANDS:
		_spectrum_data[i] = 0.0
		_spectrum_raw[i] = 0.0
		_spectrum_peaks[i] = 0.001  # Avoid division by zero

	for band: int in FrequencyBand.values():
		_beat_history[band] = []
		_last_beat_time[band] = 0.0
		_band_energies[band] = 0.0

		for i in BEAT_HISTORY_SIZE:
			_beat_history[band].append(0.0)


func _connect_to_analyzer() -> void:
	var bus_idx := AudioServer.get_bus_index(audio_bus)
	if bus_idx == -1:
		push_warning("AudioReactive: Audio bus '%s' not found" % audio_bus)
		return

	if analyzer_effect_index >= AudioServer.get_bus_effect_count(bus_idx):
		push_warning("AudioReactive: No effect at index %d on bus '%s'" % [analyzer_effect_index, audio_bus])
		return

	var effect := AudioServer.get_bus_effect(bus_idx, analyzer_effect_index)
	if effect is AudioEffectSpectrumAnalyzer:
		_spectrum_analyzer = AudioServer.get_bus_effect_instance(bus_idx, analyzer_effect_index)
	else:
		push_warning("AudioReactive: Effect at index %d is not AudioEffectSpectrumAnalyzer" % analyzer_effect_index)


# -- Spectrum Analysis --

func _update_spectrum_data() -> void:
	if not _spectrum_analyzer:
		return

	var min_freq := 20.0
	var max_freq := 20000.0
	var freq_ratio := max_freq / min_freq

	for i in SPECTRUM_BANDS:
		# Logarithmic frequency distribution for better visualization
		var freq_low := min_freq * pow(freq_ratio, float(i) / SPECTRUM_BANDS)
		var freq_high := min_freq * pow(freq_ratio, float(i + 1) / SPECTRUM_BANDS)

		var magnitude := _spectrum_analyzer.get_magnitude_for_frequency_range(freq_low, freq_high)
		var energy := (magnitude.x + magnitude.y) / 2.0

		# Convert to dB and normalize
		var db := linear_to_db(energy)
		var normalized := clampf((db + 60.0) / 60.0, 0.0, 1.0)

		# Store raw value
		_spectrum_raw[i] = normalized

		# Apply smoothing
		_spectrum_data[i] = lerpf(_spectrum_data[i], normalized, 1.0 - spectrum_smoothing)

		# Update peak (slow decay for normalization)
		if normalized > _spectrum_peaks[i]:
			_spectrum_peaks[i] = normalized
		else:
			_spectrum_peaks[i] = lerpf(_spectrum_peaks[i], normalized, 0.01)

	# Calculate frequency band energies
	_calculate_band_energies()

	spectrum_updated.emit(_spectrum_data)


func _calculate_band_energies() -> void:
	# Map spectrum bands to frequency bands
	var bands_per_freq: Dictionary = {
		FrequencyBand.SUB_BASS: [0, 1],
		FrequencyBand.BASS: [2, 3, 4],
		FrequencyBand.LOW_MID: [5, 6, 7],
		FrequencyBand.MID: [8, 9, 10, 11, 12],
		FrequencyBand.HIGH_MID: [13, 14, 15, 16, 17],
		FrequencyBand.PRESENCE: [18, 19, 20, 21, 22, 23],
		FrequencyBand.BRILLIANCE: [24, 25, 26, 27, 28, 29, 30, 31],
	}

	for band: int in FrequencyBand.values():
		var indices: Array = bands_per_freq.get(band, [])
		var energy := 0.0
		for idx: int in indices:
			if idx < _spectrum_data.size():
				energy += _spectrum_data[idx]
		if indices.size() > 0:
			energy /= indices.size()
		_band_energies[band] = energy


# -- Beat Detection --

func _detect_beats(delta: float) -> void:
	for band: int in FrequencyBand.values():
		_last_beat_time[band] = (_last_beat_time[band] as float) + delta

	if multi_band_detection:
		_detect_band_beat(FrequencyBand.BASS, BeatType.KICK)
		_detect_band_beat(FrequencyBand.MID, BeatType.SNARE)
		_detect_band_beat(FrequencyBand.BRILLIANCE, BeatType.HIHAT)
	else:
		_detect_overall_beat()

	# Check bass hits
	var bass_energy: float = _band_energies[FrequencyBand.BASS]
	_bass_accumulator = lerpf(_bass_accumulator, bass_energy, 0.3)
	if bass_energy > _bass_threshold and bass_energy > _bass_accumulator * 1.3:
		bass_hit.emit(bass_energy)


func _detect_band_beat(band: FrequencyBand, beat_type: BeatType) -> void:
	var energy: float = _band_energies[band]
	var history: Array = _beat_history[band]

	# Shift history and add new value
	history.pop_front()
	history.append(energy)

	# Calculate average and variance
	var avg := 0.0
	for val: float in history:
		avg += val
	avg /= history.size()

	var variance := 0.0
	for val: float in history:
		variance += (val - avg) * (val - avg)
	variance /= history.size()

	# Beat detection threshold based on variance
	var threshold := avg + beat_sensitivity * sqrt(variance)

	# Check for beat
	var time_since_last: float = _last_beat_time[band]
	if energy > threshold and time_since_last >= min_beat_interval:
		var strength := clampf((energy - avg) / maxf(avg, 0.01), 0.0, 1.0)
		_on_beat_detected(beat_type, strength)
		_last_beat_time[band] = 0.0


func _detect_overall_beat() -> void:
	# Use overall intensity for simple beat detection
	var energy := _current_intensity
	var history: Array = _beat_history[FrequencyBand.MID]

	history.pop_front()
	history.append(energy)

	var avg := 0.0
	for val: float in history:
		avg += val
	avg /= history.size()

	var threshold := avg * beat_sensitivity

	var time_since_last: float = _last_beat_time[FrequencyBand.MID]
	if energy > threshold and time_since_last >= min_beat_interval:
		var strength := clampf((energy - avg) / maxf(avg, 0.01), 0.0, 1.0)
		_on_beat_detected(BeatType.GENERAL, strength)
		_last_beat_time[FrequencyBand.MID] = 0.0


func _on_beat_detected(beat_type: BeatType, strength: float) -> void:
	# Record timestamp for BPM detection
	_beat_timestamps.append(_time)

	# Keep only recent timestamps
	while _beat_timestamps.size() > 32:
		_beat_timestamps.remove_at(0)

	# Reset beat phase
	_beat_phase = 0.0

	beat_detected.emit(strength, beat_type)


# -- BPM Detection --

func _detect_bpm() -> void:
	if _beat_timestamps.size() < 4:
		return

	# Calculate intervals between beats
	var intervals: Array[float] = []
	for i in range(1, _beat_timestamps.size()):
		var interval := _beat_timestamps[i] - _beat_timestamps[i - 1]
		if interval > 0.2 and interval < 2.0:  # Filter out noise
			intervals.append(interval)

	if intervals.size() < 3:
		return

	# Find most common interval using histogram
	var histogram: Dictionary = {}
	var bin_size := 0.02  # 20ms bins

	for interval: float in intervals:
		var bin := int(interval / bin_size)
		if not histogram.has(bin):
			histogram[bin] = 0
		histogram[bin] = (histogram[bin] as int) + 1

	# Find most common bin
	var max_count := 0
	var best_bin := 0
	for bin: int in histogram:
		var count: int = histogram[bin]
		if count > max_count:
			max_count = count
			best_bin = bin

	# Calculate BPM from interval
	var avg_interval := best_bin * bin_size
	if avg_interval > 0:
		var detected := 60.0 / avg_interval

		# Clamp to reasonable range
		detected = clampf(detected, MIN_BPM, MAX_BPM)

		# Check for half/double time
		if detected < MIN_BPM and detected * 2 <= MAX_BPM:
			detected *= 2
		elif detected > MAX_BPM and detected / 2 >= MIN_BPM:
			detected /= 2

		# Smooth BPM updates
		var new_confidence := float(max_count) / intervals.size()
		if abs(detected - _detected_bpm) < 5.0:
			# Close to current BPM, increase confidence
			_bpm_confidence = lerpf(_bpm_confidence, new_confidence, 0.3)
			_detected_bpm = lerpf(_detected_bpm, detected, 0.2)
		elif new_confidence > _bpm_confidence * 1.5:
			# New BPM has much higher confidence
			_detected_bpm = detected
			_bpm_confidence = new_confidence
			bpm_detected.emit(_detected_bpm, _bpm_confidence)


# -- Intensity --

func _update_intensity(delta: float) -> void:
	# Calculate overall intensity from all bands
	var total := 0.0
	for band: int in FrequencyBand.values():
		total += _band_energies[band] as float
	total /= FrequencyBand.values().size()

	_current_intensity = total

	# Smooth intensity for visual effects
	var old_smoothed := _smoothed_intensity
	_smoothed_intensity = lerpf(_smoothed_intensity, _current_intensity, 5.0 * delta)

	# Emit if changed significantly
	if abs(_smoothed_intensity - old_smoothed) > 0.02:
		intensity_changed.emit(_smoothed_intensity)


func _update_beat_phase(delta: float) -> void:
	# Update beat phase based on detected BPM
	var beat_duration := 60.0 / _detected_bpm
	_beat_phase += delta / beat_duration
	_beat_phase = fmod(_beat_phase, 1.0)


# -- Visual Effects --

func _apply_visual_effects(delta: float) -> void:
	for target: EffectTarget in _effect_targets:
		if not is_instance_valid(target.node):
			continue

		for effect_type: int in target.effects:
			_apply_effect(target, effect_type, delta)


func _apply_effect(target: EffectTarget, effect_type: VisualEffect, delta: float) -> void:
	var intensity := _get_effect_intensity(target)

	match effect_type:
		VisualEffect.PARTICLES:
			_apply_particle_effect(target, intensity)
		VisualEffect.GLOW:
			_apply_glow_effect(target, intensity)
		VisualEffect.COLOR_PULSE:
			_apply_color_pulse(target, intensity, delta)
		VisualEffect.SCALE_PULSE:
			_apply_scale_pulse(target, intensity, delta)
		VisualEffect.SHAKE:
			_apply_shake_effect(target, intensity)
		VisualEffect.WAVE_DISTORT:
			_apply_wave_distort(target, intensity)
		VisualEffect.CHROMATIC:
			_apply_chromatic_effect(target, intensity)


func _get_effect_intensity(target: EffectTarget) -> float:
	var band_energy: float = _band_energies.get(target.frequency_band, 0.0)
	return band_energy * target.intensity_mult * effect_intensity


func _apply_particle_effect(target: EffectTarget, intensity: float) -> void:
	if not particles_enabled:
		return

	if target.node is GPUParticles2D:
		var particles := target.node as GPUParticles2D
		particles.amount_ratio = clampf(intensity, 0.0, 1.0)
	elif target.node is GPUParticles3D:
		var particles := target.node as GPUParticles3D
		particles.amount_ratio = clampf(intensity, 0.0, 1.0)
	elif target.node is CPUParticles2D:
		var particles := target.node as CPUParticles2D
		particles.amount = int(particles.amount * intensity)


func _apply_glow_effect(target: EffectTarget, intensity: float) -> void:
	if not glow_enabled:
		return

	if target.node is CanvasItem:
		var item := target.node as CanvasItem
		# Apply glow via modulate brightness
		var glow_amount := 1.0 + intensity * 0.5
		item.modulate = target.original_modulate * glow_amount


func _apply_color_pulse(target: EffectTarget, intensity: float, _delta: float) -> void:
	if not color_pulse_enabled:
		return

	if target.node is CanvasItem:
		var item := target.node as CanvasItem
		# Pulse between original color and highlight
		var highlight: Color = target.property_overrides.get("highlight_color", Color(1.2, 1.1, 1.0))
		var pulse_color := target.original_modulate.lerp(highlight, intensity * sin(_beat_phase * TAU))
		item.modulate = pulse_color


func _apply_scale_pulse(target: EffectTarget, intensity: float, _delta: float) -> void:
	if target.node is Control:
		var control := target.node as Control
		var scale_amount := 1.0 + intensity * 0.1 * (1.0 - _beat_phase)
		control.scale = target.original_scale * scale_amount
	elif target.node is Node2D:
		var node2d := target.node as Node2D
		var scale_amount := 1.0 + intensity * 0.1 * (1.0 - _beat_phase)
		node2d.scale = target.original_scale * scale_amount


func _apply_shake_effect(target: EffectTarget, intensity: float) -> void:
	if not shake_enabled:
		return

	if intensity < 0.5:
		# Reset position when not shaking
		if target.node is Control:
			(target.node as Control).position = target.original_position
		elif target.node is Node2D:
			(target.node as Node2D).position = target.original_position
		return

	var shake_amount := (intensity - 0.5) * 10.0 * effect_intensity
	var offset := Vector2(
		randf_range(-shake_amount, shake_amount),
		randf_range(-shake_amount, shake_amount)
	)

	if target.node is Control:
		(target.node as Control).position = target.original_position + offset
	elif target.node is Node2D:
		(target.node as Node2D).position = target.original_position + offset


func _apply_wave_distort(target: EffectTarget, intensity: float) -> void:
	# Wave distortion requires shader - set a shader parameter
	if target.node is CanvasItem:
		var item := target.node as CanvasItem
		if item.material is ShaderMaterial:
			var mat := item.material as ShaderMaterial
			mat.set_shader_parameter("wave_intensity", intensity)
			mat.set_shader_parameter("wave_time", _time)


func _apply_chromatic_effect(target: EffectTarget, intensity: float) -> void:
	# Chromatic aberration requires shader
	if target.node is CanvasItem:
		var item := target.node as CanvasItem
		if item.material is ShaderMaterial:
			var mat := item.material as ShaderMaterial
			mat.set_shader_parameter("chromatic_amount", intensity * 0.01)


# -- Public API: Registration --

## Register a node to receive audio-reactive effects.
func register_target(
	node: Node,
	effects: Array[VisualEffect],
	frequency_band: FrequencyBand = FrequencyBand.BASS,
	intensity_mult: float = 1.0
) -> void:
	var target := EffectTarget.new()
	target.node = node
	target.effects = []
	for e: int in effects:
		target.effects.append(e)
	target.frequency_band = frequency_band
	target.intensity_mult = intensity_mult

	# Store original values
	if node is Control:
		var control := node as Control
		target.original_scale = control.scale
		target.original_modulate = control.modulate
		target.original_position = control.position
	elif node is Node2D:
		var node2d := node as Node2D
		target.original_scale = node2d.scale
		target.original_modulate = node2d.modulate
		target.original_position = node2d.position
	elif node is CanvasItem:
		var item := node as CanvasItem
		target.original_modulate = item.modulate

	_effect_targets.append(target)


## Unregister a node from audio-reactive effects.
func unregister_target(node: Node) -> void:
	for i in range(_effect_targets.size() - 1, -1, -1):
		if _effect_targets[i].node == node:
			# Reset to original values
			var target := _effect_targets[i]
			if is_instance_valid(target.node):
				_reset_target(target)
			_effect_targets.remove_at(i)


func _reset_target(target: EffectTarget) -> void:
	if target.node is Control:
		var control := target.node as Control
		control.scale = target.original_scale
		control.modulate = target.original_modulate
		control.position = target.original_position
	elif target.node is Node2D:
		var node2d := target.node as Node2D
		node2d.scale = target.original_scale
		node2d.modulate = target.original_modulate
		node2d.position = target.original_position
	elif target.node is CanvasItem:
		(target.node as CanvasItem).modulate = target.original_modulate


## Clear all registered targets.
func clear_targets() -> void:
	for target: EffectTarget in _effect_targets:
		if is_instance_valid(target.node):
			_reset_target(target)
	_effect_targets.clear()


# -- Public API: Data Access --

## Get current spectrum data (array of band values 0-1).
func get_spectrum() -> Array[float]:
	return _spectrum_data


## Get spectrum value for a specific band index.
func get_spectrum_band(index: int) -> float:
	if index >= 0 and index < _spectrum_data.size():
		return _spectrum_data[index]
	return 0.0


## Get energy level for a frequency band.
func get_band_energy(band: FrequencyBand) -> float:
	return _band_energies.get(band, 0.0)


## Get current overall audio intensity (0-1).
func get_intensity() -> float:
	return _smoothed_intensity


## Get detected BPM.
func get_bpm() -> float:
	return _detected_bpm


## Get BPM detection confidence (0-1).
func get_bpm_confidence() -> float:
	return _bpm_confidence


## Get current beat phase (0-1, resets on beat).
func get_beat_phase() -> float:
	return _beat_phase


## Get time to next beat in seconds (based on detected BPM).
func get_time_to_next_beat() -> float:
	var beat_duration := 60.0 / _detected_bpm
	return beat_duration * (1.0 - _beat_phase)


## Get bass energy (shortcut for common use case).
func get_bass() -> float:
	return _band_energies.get(FrequencyBand.BASS, 0.0)


## Get mid energy.
func get_mid() -> float:
	return _band_energies.get(FrequencyBand.MID, 0.0)


## Get high/treble energy.
func get_high() -> float:
	return _band_energies.get(FrequencyBand.BRILLIANCE, 0.0)


# -- Public API: Manual Control --

## Manually set BPM (disables auto-detection temporarily).
func set_bpm(bpm: float) -> void:
	_detected_bpm = clampf(bpm, MIN_BPM, MAX_BPM)
	_bpm_confidence = 1.0
	bpm_detected.emit(_detected_bpm, _bpm_confidence)


## Reset beat phase (useful for syncing with known beats).
func reset_beat_phase() -> void:
	_beat_phase = 0.0
	_beat_timestamps.clear()


## Manually trigger a beat (for testing or external sync).
func trigger_beat(beat_type: BeatType = BeatType.GENERAL, strength: float = 1.0) -> void:
	_on_beat_detected(beat_type, strength)


## Set the bass hit threshold (0-1).
func set_bass_threshold(threshold: float) -> void:
	_bass_threshold = clampf(threshold, 0.1, 1.0)


# -- Public API: Visualization Helpers --

## Get normalized spectrum suitable for bar visualization.
func get_spectrum_normalized() -> Array[float]:
	var result: Array[float] = []
	result.resize(_spectrum_data.size())
	for i in _spectrum_data.size():
		var peak := _spectrum_peaks[i]
		result[i] = _spectrum_data[i] / maxf(peak, 0.001)
	return result


## Get spectrum interpolated to a specific number of bands.
func get_spectrum_resized(num_bands: int) -> Array[float]:
	var result: Array[float] = []
	result.resize(num_bands)

	var ratio := float(_spectrum_data.size()) / num_bands

	for i in num_bands:
		var src_idx := int(i * ratio)
		var next_idx := mini(src_idx + 1, _spectrum_data.size() - 1)
		var t := (i * ratio) - src_idx
		result[i] = lerpf(_spectrum_data[src_idx], _spectrum_data[next_idx], t)

	return result


## Get color based on current audio (useful for UI tinting).
func get_audio_color() -> Color:
	var bass := get_bass()
	var mid := get_mid()
	var high := get_high()

	# Map frequencies to RGB-like colors
	return Color(
		clampf(bass * 1.5, 0.0, 1.0),
		clampf(mid * 1.2, 0.0, 1.0),
		clampf(high * 1.0, 0.0, 1.0)
	)


## Get pulse value for smooth animations (sine wave based on beat).
func get_beat_pulse(frequency: float = 1.0) -> float:
	return (sin(_beat_phase * TAU * frequency) + 1.0) / 2.0


# -- Debug --

## Get debug information.
func get_debug_info() -> Dictionary:
	return {
		"has_analyzer": _spectrum_analyzer != null,
		"audio_bus": audio_bus,
		"bpm": _detected_bpm,
		"bpm_confidence": _bpm_confidence,
		"intensity": _smoothed_intensity,
		"beat_phase": _beat_phase,
		"bass": get_bass(),
		"mid": get_mid(),
		"high": get_high(),
		"registered_targets": _effect_targets.size(),
		"beat_count": _beat_timestamps.size(),
	}
