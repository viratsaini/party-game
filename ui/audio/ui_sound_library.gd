## UISoundLibrary - Complete UI sound library with 50+ procedural sounds for BattleZone Party.
##
## This system provides a comprehensive library of procedurally generated and real audio
## sounds for all UI interactions. Features include layered sound design (base + accent + tail),
## 5 variations per sound to avoid repetition, pitch randomization, priority system, and
## intelligent caching for optimal performance.
##
## The library supports both procedural generation (for fallbacks) and loading actual
## audio files for production quality sound design.
class_name UISoundLibrary
extends RefCounted


# -- Signals (for connecting to visual systems) --

## Emitted when any sound is prepared for playback.
signal sound_prepared(sound_id: String, layers: Array[AudioStream])

## Emitted when variation is selected.
signal variation_selected(sound_id: String, variation_index: int)


# -- Constants --

## Number of variations per sound type.
const VARIATIONS_PER_SOUND: int = 5

## Maximum cached sounds to prevent memory bloat.
const MAX_CACHED_SOUNDS: int = 200

## Procedural sound sample rate.
const SAMPLE_RATE: int = 44100

## Default sound duration in seconds.
const DEFAULT_DURATION: float = 0.15


# -- Enums --

## Sound layer types for layered sound design.
enum SoundLayer {
	BASE,       ## Foundation sound (always plays)
	ACCENT,     ## Highlight layer (plays on top)
	TAIL,       ## Decay/reverb layer (plays at end)
	IMPACT,     ## Percussive layer
	HARMONIC,   ## Tonal layer
}

## Waveform types for procedural generation.
enum WaveformType {
	SINE,
	SQUARE,
	TRIANGLE,
	SAWTOOTH,
	NOISE_WHITE,
	NOISE_PINK,
	PULSE,
}

## Sound categories for organizing the library.
enum SoundCategory {
	BUTTON,
	PANEL,
	NAVIGATION,
	ITEM,
	CONTROL,
	TEXT,
	FEEDBACK,
	TRANSITION,
	COUNTDOWN,
	PROGRESS,
	SOCIAL,
	SPECIAL,
}


# -- Sound Definition Class --

class SoundDefinition extends RefCounted:
	## Unique identifier for this sound.
	var id: String = ""
	## Category for organization.
	var category: int = SoundCategory.BUTTON
	## Layer configurations.
	var layers: Dictionary = {}  # SoundLayer -> LayerConfig
	## Pre-generated variations.
	var variations: Array[Array] = []  # Array of [AudioStream] per layer
	## Pitch variance range.
	var pitch_variance: float = 0.05
	## Volume in dB.
	var base_volume_db: float = 0.0
	## Duration in seconds.
	var duration: float = 0.15
	## Priority level (0-5).
	var priority: int = 2
	## Current variation index for round-robin.
	var _current_variation: int = 0

	func get_next_variation() -> int:
		var v := _current_variation
		_current_variation = (_current_variation + 1) % VARIATIONS_PER_SOUND
		return v


class LayerConfig extends RefCounted:
	## Waveform type for procedural generation.
	var waveform: int = WaveformType.SINE
	## Base frequency in Hz.
	var frequency: float = 440.0
	## Frequency envelope (start, end).
	var freq_envelope: Vector2 = Vector2(1.0, 1.0)
	## Volume envelope (attack, decay, sustain, release).
	var adsr: Vector4 = Vector4(0.01, 0.05, 0.5, 0.05)
	## Volume multiplier for this layer.
	var volume_mult: float = 1.0
	## Delay before this layer plays (seconds).
	var delay: float = 0.0
	## Filter cutoff (0 = none, Hz value for low-pass).
	var filter_cutoff: float = 0.0
	## Harmonic content (array of frequency multipliers).
	var harmonics: Array[float] = []
	## Distortion amount (0-1).
	var distortion: float = 0.0
	## Reverb amount (0-1).
	var reverb: float = 0.0
	## Stereo width (-1 to 1, 0 = center).
	var stereo_width: float = 0.0


# -- State --

## All registered sound definitions.
var _definitions: Dictionary = {}  # String -> SoundDefinition

## Cached audio streams.
var _stream_cache: Dictionary = {}  # String -> Array[AudioStream]

## Cache access order for LRU eviction.
var _cache_order: Array[String] = []

## Reference to actual audio files directory.
var _audio_base_path: String = "res://assets/sounds/ui/"

## Whether to use procedural fallbacks.
var _use_procedural: bool = true


# -- Initialization --

func _init() -> void:
	_register_all_sounds()


## Register all 50+ UI sounds in the library.
func _register_all_sounds() -> void:
	# ===== BUTTON SOUNDS (10) =====
	_register_button_sounds()

	# ===== PANEL SOUNDS (8) =====
	_register_panel_sounds()

	# ===== NAVIGATION SOUNDS (6) =====
	_register_navigation_sounds()

	# ===== ITEM SOUNDS (8) =====
	_register_item_sounds()

	# ===== CONTROL SOUNDS (8) =====
	_register_control_sounds()

	# ===== TEXT INPUT SOUNDS (4) =====
	_register_text_sounds()

	# ===== FEEDBACK SOUNDS (10) =====
	_register_feedback_sounds()

	# ===== TRANSITION SOUNDS (6) =====
	_register_transition_sounds()

	# ===== COUNTDOWN SOUNDS (4) =====
	_register_countdown_sounds()

	# ===== PROGRESS SOUNDS (4) =====
	_register_progress_sounds()

	# ===== SOCIAL SOUNDS (6) =====
	_register_social_sounds()

	# ===== SPECIAL SOUNDS (6) =====
	_register_special_sounds()


func _register_button_sounds() -> void:
	# Button Hover - Light, airy click
	var hover := _create_definition("button_hover", SoundCategory.BUTTON)
	hover.duration = 0.08
	hover.base_volume_db = -9.0
	hover.pitch_variance = 0.08
	hover.priority = 1
	var hover_base := LayerConfig.new()
	hover_base.waveform = WaveformType.SINE
	hover_base.frequency = 2000.0
	hover_base.freq_envelope = Vector2(1.2, 0.8)
	hover_base.adsr = Vector4(0.005, 0.04, 0.3, 0.03)
	hover.layers[SoundLayer.BASE] = hover_base
	var hover_accent := LayerConfig.new()
	hover_accent.waveform = WaveformType.TRIANGLE
	hover_accent.frequency = 4000.0
	hover_accent.adsr = Vector4(0.001, 0.02, 0.2, 0.02)
	hover_accent.volume_mult = 0.3
	hover.layers[SoundLayer.ACCENT] = hover_accent
	_register_definition(hover)

	# Button Press - Satisfying click
	var press := _create_definition("button_press", SoundCategory.BUTTON)
	press.duration = 0.12
	press.base_volume_db = -3.0
	press.pitch_variance = 0.05
	press.priority = 3
	var press_base := LayerConfig.new()
	press_base.waveform = WaveformType.SINE
	press_base.frequency = 800.0
	press_base.freq_envelope = Vector2(1.5, 0.7)
	press_base.adsr = Vector4(0.001, 0.06, 0.4, 0.04)
	press.layers[SoundLayer.BASE] = press_base
	var press_impact := LayerConfig.new()
	press_impact.waveform = WaveformType.NOISE_WHITE
	press_impact.frequency = 3000.0
	press_impact.adsr = Vector4(0.001, 0.03, 0.1, 0.02)
	press_impact.volume_mult = 0.4
	press_impact.filter_cutoff = 4000.0
	press.layers[SoundLayer.IMPACT] = press_impact
	_register_definition(press)

	# Button Release - Soft release
	var release := _create_definition("button_release", SoundCategory.BUTTON)
	release.duration = 0.1
	release.base_volume_db = -12.0
	release.pitch_variance = 0.06
	release.priority = 1
	var release_base := LayerConfig.new()
	release_base.waveform = WaveformType.SINE
	release_base.frequency = 1200.0
	release_base.freq_envelope = Vector2(0.8, 1.1)
	release_base.adsr = Vector4(0.002, 0.05, 0.3, 0.04)
	release.layers[SoundLayer.BASE] = release_base
	_register_definition(release)

	# Button Disabled - Muted thud
	var disabled := _create_definition("button_disabled", SoundCategory.BUTTON)
	disabled.duration = 0.15
	disabled.base_volume_db = -15.0
	disabled.pitch_variance = 0.03
	disabled.priority = 1
	var disabled_base := LayerConfig.new()
	disabled_base.waveform = WaveformType.SINE
	disabled_base.frequency = 200.0
	disabled_base.freq_envelope = Vector2(1.0, 0.6)
	disabled_base.adsr = Vector4(0.005, 0.08, 0.2, 0.06)
	disabled_base.filter_cutoff = 800.0
	disabled.layers[SoundLayer.BASE] = disabled_base
	_register_definition(disabled)

	# Button Focus - Highlight sound
	var focus := _create_definition("button_focus", SoundCategory.BUTTON)
	focus.duration = 0.1
	focus.base_volume_db = -9.0
	focus.pitch_variance = 0.05
	focus.priority = 1
	var focus_base := LayerConfig.new()
	focus_base.waveform = WaveformType.SINE
	focus_base.frequency = 1500.0
	focus_base.adsr = Vector4(0.01, 0.05, 0.4, 0.04)
	focus.layers[SoundLayer.BASE] = focus_base
	_register_definition(focus)

	# Button Toggle On - Rising confirmation
	var toggle_on := _create_definition("button_toggle_on", SoundCategory.BUTTON)
	toggle_on.duration = 0.15
	toggle_on.base_volume_db = -3.0
	toggle_on.pitch_variance = 0.04
	toggle_on.priority = 3
	var toggle_on_base := LayerConfig.new()
	toggle_on_base.waveform = WaveformType.SINE
	toggle_on_base.frequency = 600.0
	toggle_on_base.freq_envelope = Vector2(0.7, 1.3)
	toggle_on_base.adsr = Vector4(0.005, 0.08, 0.5, 0.05)
	toggle_on_base.harmonics = [2.0, 3.0]
	toggle_on.layers[SoundLayer.BASE] = toggle_on_base
	var toggle_on_accent := LayerConfig.new()
	toggle_on_accent.waveform = WaveformType.TRIANGLE
	toggle_on_accent.frequency = 1200.0
	toggle_on_accent.delay = 0.03
	toggle_on_accent.adsr = Vector4(0.01, 0.05, 0.3, 0.04)
	toggle_on_accent.volume_mult = 0.5
	toggle_on.layers[SoundLayer.ACCENT] = toggle_on_accent
	_register_definition(toggle_on)

	# Button Toggle Off - Falling confirmation
	var toggle_off := _create_definition("button_toggle_off", SoundCategory.BUTTON)
	toggle_off.duration = 0.15
	toggle_off.base_volume_db = -3.0
	toggle_off.pitch_variance = 0.04
	toggle_off.priority = 3
	var toggle_off_base := LayerConfig.new()
	toggle_off_base.waveform = WaveformType.SINE
	toggle_off_base.frequency = 800.0
	toggle_off_base.freq_envelope = Vector2(1.2, 0.6)
	toggle_off_base.adsr = Vector4(0.005, 0.08, 0.4, 0.05)
	toggle_off.layers[SoundLayer.BASE] = toggle_off_base
	_register_definition(toggle_off)

	# Checkbox Check
	var check := _create_definition("checkbox_check", SoundCategory.BUTTON)
	check.duration = 0.1
	check.base_volume_db = -6.0
	check.pitch_variance = 0.05
	check.priority = 2
	var check_base := LayerConfig.new()
	check_base.waveform = WaveformType.SINE
	check_base.frequency = 1000.0
	check_base.freq_envelope = Vector2(0.8, 1.2)
	check_base.adsr = Vector4(0.002, 0.04, 0.4, 0.03)
	check.layers[SoundLayer.BASE] = check_base
	_register_definition(check)

	# Checkbox Uncheck
	var uncheck := _create_definition("checkbox_uncheck", SoundCategory.BUTTON)
	uncheck.duration = 0.1
	uncheck.base_volume_db = -6.0
	uncheck.pitch_variance = 0.05
	uncheck.priority = 2
	var uncheck_base := LayerConfig.new()
	uncheck_base.waveform = WaveformType.SINE
	uncheck_base.frequency = 1000.0
	uncheck_base.freq_envelope = Vector2(1.1, 0.8)
	uncheck_base.adsr = Vector4(0.002, 0.04, 0.4, 0.03)
	uncheck.layers[SoundLayer.BASE] = uncheck_base
	_register_definition(uncheck)

	# Radio Button Select
	var radio := _create_definition("radio_select", SoundCategory.BUTTON)
	radio.duration = 0.12
	radio.base_volume_db = -6.0
	radio.pitch_variance = 0.05
	radio.priority = 2
	var radio_base := LayerConfig.new()
	radio_base.waveform = WaveformType.SINE
	radio_base.frequency = 1100.0
	radio_base.freq_envelope = Vector2(0.9, 1.1)
	radio_base.adsr = Vector4(0.003, 0.05, 0.4, 0.04)
	radio.layers[SoundLayer.BASE] = radio_base
	_register_definition(radio)


func _register_panel_sounds() -> void:
	# Panel Open - Expanding whoosh
	var open := _create_definition("panel_open", SoundCategory.PANEL)
	open.duration = 0.25
	open.base_volume_db = -3.0
	open.pitch_variance = 0.08
	open.priority = 3
	var open_base := LayerConfig.new()
	open_base.waveform = WaveformType.NOISE_PINK
	open_base.frequency = 400.0
	open_base.freq_envelope = Vector2(0.5, 1.5)
	open_base.adsr = Vector4(0.01, 0.15, 0.4, 0.08)
	open_base.filter_cutoff = 2000.0
	open.layers[SoundLayer.BASE] = open_base
	var open_harmonic := LayerConfig.new()
	open_harmonic.waveform = WaveformType.SINE
	open_harmonic.frequency = 300.0
	open_harmonic.freq_envelope = Vector2(0.6, 1.2)
	open_harmonic.adsr = Vector4(0.02, 0.1, 0.3, 0.08)
	open_harmonic.volume_mult = 0.6
	open.layers[SoundLayer.HARMONIC] = open_harmonic
	_register_definition(open)

	# Panel Close - Contracting swoosh
	var close := _create_definition("panel_close", SoundCategory.PANEL)
	close.duration = 0.2
	close.base_volume_db = -3.0
	close.pitch_variance = 0.08
	close.priority = 3
	var close_base := LayerConfig.new()
	close_base.waveform = WaveformType.NOISE_PINK
	close_base.frequency = 600.0
	close_base.freq_envelope = Vector2(1.3, 0.5)
	close_base.adsr = Vector4(0.01, 0.1, 0.3, 0.08)
	close_base.filter_cutoff = 1500.0
	close.layers[SoundLayer.BASE] = close_base
	_register_definition(close)

	# Panel Slide
	var slide := _create_definition("panel_slide", SoundCategory.PANEL)
	slide.duration = 0.15
	slide.base_volume_db = -9.0
	slide.pitch_variance = 0.1
	slide.priority = 1
	var slide_base := LayerConfig.new()
	slide_base.waveform = WaveformType.NOISE_PINK
	slide_base.frequency = 800.0
	slide_base.adsr = Vector4(0.01, 0.08, 0.4, 0.05)
	slide_base.filter_cutoff = 3000.0
	slide.layers[SoundLayer.BASE] = slide_base
	_register_definition(slide)

	# Panel Expand
	var expand := _create_definition("panel_expand", SoundCategory.PANEL)
	expand.duration = 0.2
	expand.base_volume_db = -6.0
	expand.pitch_variance = 0.08
	expand.priority = 2
	var expand_base := LayerConfig.new()
	expand_base.waveform = WaveformType.SINE
	expand_base.frequency = 250.0
	expand_base.freq_envelope = Vector2(0.7, 1.4)
	expand_base.adsr = Vector4(0.01, 0.12, 0.4, 0.06)
	expand.layers[SoundLayer.BASE] = expand_base
	_register_definition(expand)

	# Panel Collapse
	var collapse := _create_definition("panel_collapse", SoundCategory.PANEL)
	collapse.duration = 0.18
	collapse.base_volume_db = -6.0
	collapse.pitch_variance = 0.08
	collapse.priority = 2
	var collapse_base := LayerConfig.new()
	collapse_base.waveform = WaveformType.SINE
	collapse_base.frequency = 400.0
	collapse_base.freq_envelope = Vector2(1.3, 0.6)
	collapse_base.adsr = Vector4(0.01, 0.1, 0.4, 0.06)
	collapse.layers[SoundLayer.BASE] = collapse_base
	_register_definition(collapse)

	# Dialog Appear
	var dialog := _create_definition("dialog_appear", SoundCategory.PANEL)
	dialog.duration = 0.3
	dialog.base_volume_db = 0.0
	dialog.pitch_variance = 0.05
	dialog.priority = 4
	var dialog_base := LayerConfig.new()
	dialog_base.waveform = WaveformType.SINE
	dialog_base.frequency = 400.0
	dialog_base.freq_envelope = Vector2(0.6, 1.0)
	dialog_base.adsr = Vector4(0.02, 0.15, 0.5, 0.1)
	dialog_base.harmonics = [2.0, 3.0, 4.0]
	dialog.layers[SoundLayer.BASE] = dialog_base
	var dialog_accent := LayerConfig.new()
	dialog_accent.waveform = WaveformType.TRIANGLE
	dialog_accent.frequency = 800.0
	dialog_accent.delay = 0.05
	dialog_accent.adsr = Vector4(0.01, 0.1, 0.3, 0.08)
	dialog_accent.volume_mult = 0.4
	dialog.layers[SoundLayer.ACCENT] = dialog_accent
	_register_definition(dialog)

	# Tooltip Show
	var tooltip := _create_definition("tooltip_show", SoundCategory.PANEL)
	tooltip.duration = 0.08
	tooltip.base_volume_db = -12.0
	tooltip.pitch_variance = 0.08
	tooltip.priority = 0
	var tooltip_base := LayerConfig.new()
	tooltip_base.waveform = WaveformType.SINE
	tooltip_base.frequency = 2500.0
	tooltip_base.adsr = Vector4(0.002, 0.03, 0.2, 0.03)
	tooltip.layers[SoundLayer.BASE] = tooltip_base
	_register_definition(tooltip)

	# Dropdown Open
	var dropdown := _create_definition("dropdown_open", SoundCategory.PANEL)
	dropdown.duration = 0.12
	dropdown.base_volume_db = -6.0
	dropdown.pitch_variance = 0.06
	dropdown.priority = 2
	var dropdown_base := LayerConfig.new()
	dropdown_base.waveform = WaveformType.SINE
	dropdown_base.frequency = 600.0
	dropdown_base.freq_envelope = Vector2(0.8, 1.2)
	dropdown_base.adsr = Vector4(0.005, 0.06, 0.4, 0.04)
	dropdown.layers[SoundLayer.BASE] = dropdown_base
	_register_definition(dropdown)


func _register_navigation_sounds() -> void:
	# Menu Navigate
	var navigate := _create_definition("menu_navigate", SoundCategory.NAVIGATION)
	navigate.duration = 0.08
	navigate.base_volume_db = -9.0
	navigate.pitch_variance = 0.1
	navigate.priority = 1
	var navigate_base := LayerConfig.new()
	navigate_base.waveform = WaveformType.SINE
	navigate_base.frequency = 1800.0
	navigate_base.adsr = Vector4(0.002, 0.04, 0.3, 0.03)
	navigate.layers[SoundLayer.BASE] = navigate_base
	_register_definition(navigate)

	# Menu Select
	var select := _create_definition("menu_select", SoundCategory.NAVIGATION)
	select.duration = 0.12
	select.base_volume_db = -3.0
	select.pitch_variance = 0.05
	select.priority = 3
	var select_base := LayerConfig.new()
	select_base.waveform = WaveformType.SINE
	select_base.frequency = 800.0
	select_base.freq_envelope = Vector2(0.9, 1.1)
	select_base.adsr = Vector4(0.002, 0.06, 0.5, 0.04)
	select_base.harmonics = [2.0]
	select.layers[SoundLayer.BASE] = select_base
	_register_definition(select)

	# Menu Back
	var back := _create_definition("menu_back", SoundCategory.NAVIGATION)
	back.duration = 0.15
	back.base_volume_db = -6.0
	back.pitch_variance = 0.06
	back.priority = 2
	var back_base := LayerConfig.new()
	back_base.waveform = WaveformType.SINE
	back_base.frequency = 500.0
	back_base.freq_envelope = Vector2(1.2, 0.7)
	back_base.adsr = Vector4(0.005, 0.08, 0.4, 0.05)
	back.layers[SoundLayer.BASE] = back_base
	_register_definition(back)

	# Menu Forward
	var forward := _create_definition("menu_forward", SoundCategory.NAVIGATION)
	forward.duration = 0.12
	forward.base_volume_db = -6.0
	forward.pitch_variance = 0.06
	forward.priority = 2
	var forward_base := LayerConfig.new()
	forward_base.waveform = WaveformType.SINE
	forward_base.frequency = 600.0
	forward_base.freq_envelope = Vector2(0.8, 1.3)
	forward_base.adsr = Vector4(0.005, 0.06, 0.4, 0.04)
	forward.layers[SoundLayer.BASE] = forward_base
	_register_definition(forward)

	# Tab Switch
	var tab := _create_definition("tab_switch", SoundCategory.NAVIGATION)
	tab.duration = 0.1
	tab.base_volume_db = -6.0
	tab.pitch_variance = 0.08
	tab.priority = 2
	var tab_base := LayerConfig.new()
	tab_base.waveform = WaveformType.SINE
	tab_base.frequency = 1200.0
	tab_base.adsr = Vector4(0.003, 0.05, 0.4, 0.03)
	tab.layers[SoundLayer.BASE] = tab_base
	_register_definition(tab)

	# Breadcrumb Click
	var breadcrumb := _create_definition("breadcrumb_click", SoundCategory.NAVIGATION)
	breadcrumb.duration = 0.1
	breadcrumb.base_volume_db = -9.0
	breadcrumb.pitch_variance = 0.08
	breadcrumb.priority = 1
	var breadcrumb_base := LayerConfig.new()
	breadcrumb_base.waveform = WaveformType.SINE
	breadcrumb_base.frequency = 1400.0
	breadcrumb_base.adsr = Vector4(0.002, 0.05, 0.3, 0.03)
	breadcrumb.layers[SoundLayer.BASE] = breadcrumb_base
	_register_definition(breadcrumb)


func _register_item_sounds() -> void:
	# Item Select
	var item_select := _create_definition("item_select", SoundCategory.ITEM)
	item_select.duration = 0.1
	item_select.base_volume_db = -6.0
	item_select.pitch_variance = 0.06
	item_select.priority = 2
	var item_select_base := LayerConfig.new()
	item_select_base.waveform = WaveformType.SINE
	item_select_base.frequency = 900.0
	item_select_base.adsr = Vector4(0.002, 0.05, 0.4, 0.03)
	item_select.layers[SoundLayer.BASE] = item_select_base
	_register_definition(item_select)

	# Item Deselect
	var item_deselect := _create_definition("item_deselect", SoundCategory.ITEM)
	item_deselect.duration = 0.1
	item_deselect.base_volume_db = -9.0
	item_deselect.pitch_variance = 0.06
	item_deselect.priority = 1
	var item_deselect_base := LayerConfig.new()
	item_deselect_base.waveform = WaveformType.SINE
	item_deselect_base.frequency = 700.0
	item_deselect_base.adsr = Vector4(0.002, 0.05, 0.3, 0.03)
	item_deselect.layers[SoundLayer.BASE] = item_deselect_base
	_register_definition(item_deselect)

	# Item Hover
	var item_hover := _create_definition("item_hover", SoundCategory.ITEM)
	item_hover.duration = 0.06
	item_hover.base_volume_db = -15.0
	item_hover.pitch_variance = 0.1
	item_hover.priority = 0
	var item_hover_base := LayerConfig.new()
	item_hover_base.waveform = WaveformType.SINE
	item_hover_base.frequency = 2200.0
	item_hover_base.adsr = Vector4(0.002, 0.03, 0.2, 0.02)
	item_hover.layers[SoundLayer.BASE] = item_hover_base
	_register_definition(item_hover)

	# Item Pickup
	var pickup := _create_definition("item_pickup", SoundCategory.ITEM)
	pickup.duration = 0.2
	pickup.base_volume_db = 0.0
	pickup.pitch_variance = 0.08
	pickup.priority = 3
	var pickup_base := LayerConfig.new()
	pickup_base.waveform = WaveformType.SINE
	pickup_base.frequency = 500.0
	pickup_base.freq_envelope = Vector2(0.6, 1.4)
	pickup_base.adsr = Vector4(0.01, 0.1, 0.5, 0.08)
	pickup_base.harmonics = [2.0, 3.0]
	pickup.layers[SoundLayer.BASE] = pickup_base
	var pickup_accent := LayerConfig.new()
	pickup_accent.waveform = WaveformType.TRIANGLE
	pickup_accent.frequency = 1500.0
	pickup_accent.delay = 0.03
	pickup_accent.adsr = Vector4(0.005, 0.08, 0.3, 0.06)
	pickup_accent.volume_mult = 0.5
	pickup.layers[SoundLayer.ACCENT] = pickup_accent
	_register_definition(pickup)

	# Item Drop
	var drop := _create_definition("item_drop", SoundCategory.ITEM)
	drop.duration = 0.15
	drop.base_volume_db = -3.0
	drop.pitch_variance = 0.08
	drop.priority = 2
	var drop_base := LayerConfig.new()
	drop_base.waveform = WaveformType.SINE
	drop_base.frequency = 400.0
	drop_base.freq_envelope = Vector2(1.3, 0.6)
	drop_base.adsr = Vector4(0.01, 0.08, 0.4, 0.05)
	drop.layers[SoundLayer.BASE] = drop_base
	_register_definition(drop)

	# Item Equip
	var equip := _create_definition("item_equip", SoundCategory.ITEM)
	equip.duration = 0.2
	equip.base_volume_db = 0.0
	equip.pitch_variance = 0.06
	equip.priority = 3
	var equip_base := LayerConfig.new()
	equip_base.waveform = WaveformType.SINE
	equip_base.frequency = 600.0
	equip_base.freq_envelope = Vector2(0.7, 1.2)
	equip_base.adsr = Vector4(0.01, 0.1, 0.5, 0.08)
	equip_base.harmonics = [1.5, 2.0]
	equip.layers[SoundLayer.BASE] = equip_base
	var equip_impact := LayerConfig.new()
	equip_impact.waveform = WaveformType.NOISE_WHITE
	equip_impact.frequency = 2000.0
	equip_impact.adsr = Vector4(0.001, 0.04, 0.2, 0.03)
	equip_impact.volume_mult = 0.3
	equip_impact.filter_cutoff = 3000.0
	equip.layers[SoundLayer.IMPACT] = equip_impact
	_register_definition(equip)

	# Item Unequip
	var unequip := _create_definition("item_unequip", SoundCategory.ITEM)
	unequip.duration = 0.15
	unequip.base_volume_db = -3.0
	unequip.pitch_variance = 0.06
	unequip.priority = 2
	var unequip_base := LayerConfig.new()
	unequip_base.waveform = WaveformType.SINE
	unequip_base.frequency = 500.0
	unequip_base.freq_envelope = Vector2(1.2, 0.7)
	unequip_base.adsr = Vector4(0.01, 0.08, 0.4, 0.05)
	unequip.layers[SoundLayer.BASE] = unequip_base
	_register_definition(unequip)

	# Card Flip
	var flip := _create_definition("card_flip", SoundCategory.ITEM)
	flip.duration = 0.15
	flip.base_volume_db = -6.0
	flip.pitch_variance = 0.08
	flip.priority = 2
	var flip_base := LayerConfig.new()
	flip_base.waveform = WaveformType.NOISE_PINK
	flip_base.frequency = 1200.0
	flip_base.adsr = Vector4(0.005, 0.08, 0.3, 0.05)
	flip_base.filter_cutoff = 4000.0
	flip.layers[SoundLayer.BASE] = flip_base
	_register_definition(flip)


func _register_control_sounds() -> void:
	# Slider Move
	var slider := _create_definition("slider_move", SoundCategory.CONTROL)
	slider.duration = 0.04
	slider.base_volume_db = -15.0
	slider.pitch_variance = 0.15
	slider.priority = 0
	var slider_base := LayerConfig.new()
	slider_base.waveform = WaveformType.SINE
	slider_base.frequency = 1500.0
	slider_base.adsr = Vector4(0.001, 0.02, 0.3, 0.01)
	slider.layers[SoundLayer.BASE] = slider_base
	_register_definition(slider)

	# Slider Snap
	var snap := _create_definition("slider_snap", SoundCategory.CONTROL)
	snap.duration = 0.1
	snap.base_volume_db = -6.0
	snap.pitch_variance = 0.08
	snap.priority = 2
	var snap_base := LayerConfig.new()
	snap_base.waveform = WaveformType.SINE
	snap_base.frequency = 1000.0
	snap_base.adsr = Vector4(0.002, 0.05, 0.4, 0.03)
	snap.layers[SoundLayer.BASE] = snap_base
	var snap_accent := LayerConfig.new()
	snap_accent.waveform = WaveformType.NOISE_WHITE
	snap_accent.frequency = 3000.0
	snap_accent.adsr = Vector4(0.001, 0.02, 0.1, 0.02)
	snap_accent.volume_mult = 0.2
	snap_accent.filter_cutoff = 4000.0
	snap.layers[SoundLayer.ACCENT] = snap_accent
	_register_definition(snap)

	# Scroll Tick
	var scroll := _create_definition("list_scroll", SoundCategory.CONTROL)
	scroll.duration = 0.03
	scroll.base_volume_db = -18.0
	scroll.pitch_variance = 0.2
	scroll.priority = 0
	var scroll_base := LayerConfig.new()
	scroll_base.waveform = WaveformType.SINE
	scroll_base.frequency = 2000.0
	scroll_base.adsr = Vector4(0.001, 0.015, 0.2, 0.01)
	scroll.layers[SoundLayer.BASE] = scroll_base
	_register_definition(scroll)

	# Scroll End
	var scroll_end := _create_definition("list_scroll_end", SoundCategory.CONTROL)
	scroll_end.duration = 0.15
	scroll_end.base_volume_db = -9.0
	scroll_end.pitch_variance = 0.06
	scroll_end.priority = 1
	var scroll_end_base := LayerConfig.new()
	scroll_end_base.waveform = WaveformType.SINE
	scroll_end_base.frequency = 300.0
	scroll_end_base.freq_envelope = Vector2(1.3, 0.7)
	scroll_end_base.adsr = Vector4(0.005, 0.08, 0.4, 0.05)
	scroll_end.layers[SoundLayer.BASE] = scroll_end_base
	_register_definition(scroll_end)

	# Knob Rotate
	var knob := _create_definition("knob_rotate", SoundCategory.CONTROL)
	knob.duration = 0.05
	knob.base_volume_db = -12.0
	knob.pitch_variance = 0.15
	knob.priority = 0
	var knob_base := LayerConfig.new()
	knob_base.waveform = WaveformType.SINE
	knob_base.frequency = 1800.0
	knob_base.adsr = Vector4(0.001, 0.025, 0.3, 0.02)
	knob.layers[SoundLayer.BASE] = knob_base
	_register_definition(knob)

	# Spin Value
	var spin := _create_definition("spin_value", SoundCategory.CONTROL)
	spin.duration = 0.06
	spin.base_volume_db = -9.0
	spin.pitch_variance = 0.1
	spin.priority = 1
	var spin_base := LayerConfig.new()
	spin_base.waveform = WaveformType.SINE
	spin_base.frequency = 1600.0
	spin_base.adsr = Vector4(0.002, 0.03, 0.3, 0.02)
	spin.layers[SoundLayer.BASE] = spin_base
	_register_definition(spin)

	# Color Pick
	var color := _create_definition("color_pick", SoundCategory.CONTROL)
	color.duration = 0.1
	color.base_volume_db = -6.0
	color.pitch_variance = 0.1
	color.priority = 2
	var color_base := LayerConfig.new()
	color_base.waveform = WaveformType.SINE
	color_base.frequency = 1200.0
	color_base.adsr = Vector4(0.003, 0.05, 0.4, 0.03)
	color.layers[SoundLayer.BASE] = color_base
	_register_definition(color)

	# Date/Time Pick
	var datetime := _create_definition("datetime_pick", SoundCategory.CONTROL)
	datetime.duration = 0.08
	datetime.base_volume_db = -9.0
	datetime.pitch_variance = 0.08
	datetime.priority = 1
	var datetime_base := LayerConfig.new()
	datetime_base.waveform = WaveformType.SINE
	datetime_base.frequency = 1400.0
	datetime_base.adsr = Vector4(0.002, 0.04, 0.3, 0.03)
	datetime.layers[SoundLayer.BASE] = datetime_base
	_register_definition(datetime)


func _register_text_sounds() -> void:
	# Text Type
	var type := _create_definition("text_type", SoundCategory.TEXT)
	type.duration = 0.04
	type.base_volume_db = -15.0
	type.pitch_variance = 0.2
	type.priority = 0
	var type_base := LayerConfig.new()
	type_base.waveform = WaveformType.NOISE_WHITE
	type_base.frequency = 4000.0
	type_base.adsr = Vector4(0.001, 0.02, 0.2, 0.01)
	type_base.filter_cutoff = 6000.0
	type.layers[SoundLayer.BASE] = type_base
	_register_definition(type)

	# Text Delete
	var delete := _create_definition("text_delete", SoundCategory.TEXT)
	delete.duration = 0.05
	delete.base_volume_db = -12.0
	delete.pitch_variance = 0.15
	delete.priority = 0
	var delete_base := LayerConfig.new()
	delete_base.waveform = WaveformType.NOISE_WHITE
	delete_base.frequency = 2500.0
	delete_base.freq_envelope = Vector2(1.2, 0.6)
	delete_base.adsr = Vector4(0.001, 0.025, 0.2, 0.02)
	delete_base.filter_cutoff = 4000.0
	delete.layers[SoundLayer.BASE] = delete_base
	_register_definition(delete)

	# Text Submit
	var submit := _create_definition("text_submit", SoundCategory.TEXT)
	submit.duration = 0.12
	submit.base_volume_db = -3.0
	submit.pitch_variance = 0.05
	submit.priority = 3
	var submit_base := LayerConfig.new()
	submit_base.waveform = WaveformType.SINE
	submit_base.frequency = 700.0
	submit_base.freq_envelope = Vector2(0.8, 1.2)
	submit_base.adsr = Vector4(0.003, 0.06, 0.5, 0.04)
	submit_base.harmonics = [2.0]
	submit.layers[SoundLayer.BASE] = submit_base
	_register_definition(submit)

	# Text Error
	var text_error := _create_definition("text_error", SoundCategory.TEXT)
	text_error.duration = 0.15
	text_error.base_volume_db = -6.0
	text_error.pitch_variance = 0.03
	text_error.priority = 3
	var text_error_base := LayerConfig.new()
	text_error_base.waveform = WaveformType.SQUARE
	text_error_base.frequency = 200.0
	text_error_base.adsr = Vector4(0.002, 0.08, 0.3, 0.05)
	text_error_base.distortion = 0.3
	text_error.layers[SoundLayer.BASE] = text_error_base
	_register_definition(text_error)


func _register_feedback_sounds() -> void:
	# Success
	var success := _create_definition("success", SoundCategory.FEEDBACK)
	success.duration = 0.4
	success.base_volume_db = 0.0
	success.pitch_variance = 0.03
	success.priority = 4
	var success_base := LayerConfig.new()
	success_base.waveform = WaveformType.SINE
	success_base.frequency = 523.25  # C5
	success_base.adsr = Vector4(0.01, 0.15, 0.6, 0.2)
	success_base.harmonics = [2.0, 3.0]
	success.layers[SoundLayer.BASE] = success_base
	var success_accent := LayerConfig.new()
	success_accent.waveform = WaveformType.SINE
	success_accent.frequency = 659.25  # E5
	success_accent.delay = 0.1
	success_accent.adsr = Vector4(0.01, 0.15, 0.5, 0.15)
	success_accent.volume_mult = 0.8
	success.layers[SoundLayer.ACCENT] = success_accent
	var success_tail := LayerConfig.new()
	success_tail.waveform = WaveformType.SINE
	success_tail.frequency = 783.99  # G5
	success_tail.delay = 0.2
	success_tail.adsr = Vector4(0.01, 0.1, 0.4, 0.1)
	success_tail.volume_mult = 0.6
	success_tail.reverb = 0.4
	success.layers[SoundLayer.TAIL] = success_tail
	_register_definition(success)

	# Error
	var error := _create_definition("error", SoundCategory.FEEDBACK)
	error.duration = 0.35
	error.base_volume_db = 0.0
	error.pitch_variance = 0.02
	error.priority = 4
	var error_base := LayerConfig.new()
	error_base.waveform = WaveformType.SQUARE
	error_base.frequency = 180.0
	error_base.adsr = Vector4(0.005, 0.1, 0.4, 0.15)
	error_base.distortion = 0.2
	error.layers[SoundLayer.BASE] = error_base
	var error_impact := LayerConfig.new()
	error_impact.waveform = WaveformType.NOISE_WHITE
	error_impact.frequency = 500.0
	error_impact.adsr = Vector4(0.001, 0.05, 0.2, 0.05)
	error_impact.volume_mult = 0.4
	error_impact.filter_cutoff = 800.0
	error.layers[SoundLayer.IMPACT] = error_impact
	_register_definition(error)

	# Warning
	var warning := _create_definition("warning", SoundCategory.FEEDBACK)
	warning.duration = 0.3
	warning.base_volume_db = -3.0
	warning.pitch_variance = 0.03
	warning.priority = 4
	var warning_base := LayerConfig.new()
	warning_base.waveform = WaveformType.TRIANGLE
	warning_base.frequency = 400.0
	warning_base.freq_envelope = Vector2(1.0, 0.9)
	warning_base.adsr = Vector4(0.01, 0.12, 0.5, 0.15)
	warning.layers[SoundLayer.BASE] = warning_base
	var warning_accent := LayerConfig.new()
	warning_accent.waveform = WaveformType.TRIANGLE
	warning_accent.frequency = 600.0
	warning_accent.delay = 0.08
	warning_accent.adsr = Vector4(0.01, 0.1, 0.4, 0.1)
	warning_accent.volume_mult = 0.6
	warning.layers[SoundLayer.ACCENT] = warning_accent
	_register_definition(warning)

	# Info
	var info := _create_definition("info", SoundCategory.FEEDBACK)
	info.duration = 0.2
	info.base_volume_db = -6.0
	info.pitch_variance = 0.05
	info.priority = 3
	var info_base := LayerConfig.new()
	info_base.waveform = WaveformType.SINE
	info_base.frequency = 880.0
	info_base.adsr = Vector4(0.01, 0.08, 0.5, 0.1)
	info.layers[SoundLayer.BASE] = info_base
	_register_definition(info)

	# Notification
	var notif := _create_definition("notification", SoundCategory.FEEDBACK)
	notif.duration = 0.35
	notif.base_volume_db = -3.0
	notif.pitch_variance = 0.04
	notif.priority = 4
	var notif_base := LayerConfig.new()
	notif_base.waveform = WaveformType.SINE
	notif_base.frequency = 698.46  # F5
	notif_base.adsr = Vector4(0.01, 0.12, 0.5, 0.2)
	notif_base.harmonics = [2.0]
	notif.layers[SoundLayer.BASE] = notif_base
	var notif_accent := LayerConfig.new()
	notif_accent.waveform = WaveformType.SINE
	notif_accent.frequency = 880.0  # A5
	notif_accent.delay = 0.1
	notif_accent.adsr = Vector4(0.01, 0.1, 0.4, 0.15)
	notif_accent.volume_mult = 0.7
	notif.layers[SoundLayer.ACCENT] = notif_accent
	_register_definition(notif)

	# Achievement
	var achieve := _create_definition("achievement", SoundCategory.FEEDBACK)
	achieve.duration = 0.6
	achieve.base_volume_db = 3.0
	achieve.pitch_variance = 0.02
	achieve.priority = 5
	var achieve_base := LayerConfig.new()
	achieve_base.waveform = WaveformType.SINE
	achieve_base.frequency = 440.0  # A4
	achieve_base.adsr = Vector4(0.02, 0.2, 0.6, 0.25)
	achieve_base.harmonics = [2.0, 3.0, 4.0]
	achieve.layers[SoundLayer.BASE] = achieve_base
	var achieve_accent := LayerConfig.new()
	achieve_accent.waveform = WaveformType.SINE
	achieve_accent.frequency = 554.37  # C#5
	achieve_accent.delay = 0.12
	achieve_accent.adsr = Vector4(0.01, 0.15, 0.5, 0.2)
	achieve_accent.volume_mult = 0.8
	achieve.layers[SoundLayer.ACCENT] = achieve_accent
	var achieve_tail := LayerConfig.new()
	achieve_tail.waveform = WaveformType.SINE
	achieve_tail.frequency = 659.25  # E5
	achieve_tail.delay = 0.24
	achieve_tail.adsr = Vector4(0.01, 0.12, 0.5, 0.2)
	achieve_tail.volume_mult = 0.7
	achieve_tail.reverb = 0.5
	achieve.layers[SoundLayer.TAIL] = achieve_tail
	_register_definition(achieve)

	# Level Up
	var levelup := _create_definition("level_up", SoundCategory.FEEDBACK)
	levelup.duration = 0.7
	levelup.base_volume_db = 3.0
	levelup.pitch_variance = 0.02
	levelup.priority = 5
	var levelup_base := LayerConfig.new()
	levelup_base.waveform = WaveformType.SINE
	levelup_base.frequency = 349.23  # F4
	levelup_base.freq_envelope = Vector2(0.7, 1.5)
	levelup_base.adsr = Vector4(0.02, 0.25, 0.6, 0.3)
	levelup_base.harmonics = [2.0, 3.0]
	levelup.layers[SoundLayer.BASE] = levelup_base
	var levelup_accent := LayerConfig.new()
	levelup_accent.waveform = WaveformType.TRIANGLE
	levelup_accent.frequency = 698.46  # F5
	levelup_accent.delay = 0.15
	levelup_accent.adsr = Vector4(0.01, 0.2, 0.5, 0.25)
	levelup_accent.volume_mult = 0.6
	levelup.layers[SoundLayer.ACCENT] = levelup_accent
	_register_definition(levelup)

	# Unlock
	var unlock := _create_definition("unlock", SoundCategory.FEEDBACK)
	unlock.duration = 0.4
	unlock.base_volume_db = 0.0
	unlock.pitch_variance = 0.03
	unlock.priority = 4
	var unlock_base := LayerConfig.new()
	unlock_base.waveform = WaveformType.SINE
	unlock_base.frequency = 600.0
	unlock_base.freq_envelope = Vector2(0.6, 1.3)
	unlock_base.adsr = Vector4(0.01, 0.15, 0.5, 0.2)
	unlock_base.harmonics = [2.0, 2.5]
	unlock.layers[SoundLayer.BASE] = unlock_base
	var unlock_impact := LayerConfig.new()
	unlock_impact.waveform = WaveformType.NOISE_WHITE
	unlock_impact.frequency = 3000.0
	unlock_impact.adsr = Vector4(0.001, 0.04, 0.2, 0.04)
	unlock_impact.volume_mult = 0.3
	unlock_impact.filter_cutoff = 5000.0
	unlock.layers[SoundLayer.IMPACT] = unlock_impact
	_register_definition(unlock)

	# Confirm
	var confirm := _create_definition("confirm", SoundCategory.FEEDBACK)
	confirm.duration = 0.15
	confirm.base_volume_db = 0.0
	confirm.pitch_variance = 0.04
	confirm.priority = 3
	var confirm_base := LayerConfig.new()
	confirm_base.waveform = WaveformType.SINE
	confirm_base.frequency = 800.0
	confirm_base.freq_envelope = Vector2(0.9, 1.1)
	confirm_base.adsr = Vector4(0.005, 0.07, 0.5, 0.05)
	confirm_base.harmonics = [2.0]
	confirm.layers[SoundLayer.BASE] = confirm_base
	_register_definition(confirm)

	# Cancel
	var cancel := _create_definition("cancel", SoundCategory.FEEDBACK)
	cancel.duration = 0.15
	cancel.base_volume_db = -3.0
	cancel.pitch_variance = 0.04
	cancel.priority = 3
	var cancel_base := LayerConfig.new()
	cancel_base.waveform = WaveformType.SINE
	cancel_base.frequency = 500.0
	cancel_base.freq_envelope = Vector2(1.1, 0.8)
	cancel_base.adsr = Vector4(0.005, 0.07, 0.4, 0.05)
	cancel.layers[SoundLayer.BASE] = cancel_base
	_register_definition(cancel)


func _register_transition_sounds() -> void:
	# Transition In
	var trans_in := _create_definition("transition_in", SoundCategory.TRANSITION)
	trans_in.duration = 0.4
	trans_in.base_volume_db = -3.0
	trans_in.pitch_variance = 0.1
	trans_in.priority = 3
	var trans_in_base := LayerConfig.new()
	trans_in_base.waveform = WaveformType.NOISE_PINK
	trans_in_base.frequency = 400.0
	trans_in_base.freq_envelope = Vector2(0.3, 1.5)
	trans_in_base.adsr = Vector4(0.02, 0.25, 0.4, 0.12)
	trans_in_base.filter_cutoff = 3000.0
	trans_in.layers[SoundLayer.BASE] = trans_in_base
	var trans_in_harmonic := LayerConfig.new()
	trans_in_harmonic.waveform = WaveformType.SINE
	trans_in_harmonic.frequency = 200.0
	trans_in_harmonic.freq_envelope = Vector2(0.5, 1.2)
	trans_in_harmonic.adsr = Vector4(0.03, 0.2, 0.5, 0.15)
	trans_in_harmonic.volume_mult = 0.5
	trans_in.layers[SoundLayer.HARMONIC] = trans_in_harmonic
	_register_definition(trans_in)

	# Transition Out
	var trans_out := _create_definition("transition_out", SoundCategory.TRANSITION)
	trans_out.duration = 0.35
	trans_out.base_volume_db = -3.0
	trans_out.pitch_variance = 0.1
	trans_out.priority = 3
	var trans_out_base := LayerConfig.new()
	trans_out_base.waveform = WaveformType.NOISE_PINK
	trans_out_base.frequency = 600.0
	trans_out_base.freq_envelope = Vector2(1.3, 0.4)
	trans_out_base.adsr = Vector4(0.02, 0.2, 0.4, 0.12)
	trans_out_base.filter_cutoff = 2500.0
	trans_out.layers[SoundLayer.BASE] = trans_out_base
	_register_definition(trans_out)

	# Fade In
	var fade_in := _create_definition("fade_in", SoundCategory.TRANSITION)
	fade_in.duration = 0.3
	fade_in.base_volume_db = -6.0
	fade_in.pitch_variance = 0.08
	fade_in.priority = 2
	var fade_in_base := LayerConfig.new()
	fade_in_base.waveform = WaveformType.SINE
	fade_in_base.frequency = 300.0
	fade_in_base.freq_envelope = Vector2(0.6, 1.1)
	fade_in_base.adsr = Vector4(0.05, 0.15, 0.5, 0.1)
	fade_in.layers[SoundLayer.BASE] = fade_in_base
	_register_definition(fade_in)

	# Fade Out
	var fade_out := _create_definition("fade_out", SoundCategory.TRANSITION)
	fade_out.duration = 0.3
	fade_out.base_volume_db = -6.0
	fade_out.pitch_variance = 0.08
	fade_out.priority = 2
	var fade_out_base := LayerConfig.new()
	fade_out_base.waveform = WaveformType.SINE
	fade_out_base.frequency = 350.0
	fade_out_base.freq_envelope = Vector2(1.1, 0.6)
	fade_out_base.adsr = Vector4(0.01, 0.18, 0.4, 0.1)
	fade_out.layers[SoundLayer.BASE] = fade_out_base
	_register_definition(fade_out)

	# Whoosh
	var whoosh := _create_definition("whoosh", SoundCategory.TRANSITION)
	whoosh.duration = 0.25
	whoosh.base_volume_db = -6.0
	whoosh.pitch_variance = 0.15
	whoosh.priority = 2
	var whoosh_base := LayerConfig.new()
	whoosh_base.waveform = WaveformType.NOISE_PINK
	whoosh_base.frequency = 800.0
	whoosh_base.freq_envelope = Vector2(0.5, 1.5)
	whoosh_base.adsr = Vector4(0.02, 0.12, 0.4, 0.1)
	whoosh_base.filter_cutoff = 4000.0
	whoosh.layers[SoundLayer.BASE] = whoosh_base
	_register_definition(whoosh)

	# Swipe
	var swipe := _create_definition("swipe", SoundCategory.TRANSITION)
	swipe.duration = 0.2
	swipe.base_volume_db = -9.0
	swipe.pitch_variance = 0.12
	swipe.priority = 1
	var swipe_base := LayerConfig.new()
	swipe_base.waveform = WaveformType.NOISE_PINK
	swipe_base.frequency = 1200.0
	swipe_base.freq_envelope = Vector2(0.6, 1.4)
	swipe_base.adsr = Vector4(0.01, 0.1, 0.3, 0.08)
	swipe_base.filter_cutoff = 5000.0
	swipe.layers[SoundLayer.BASE] = swipe_base
	_register_definition(swipe)


func _register_countdown_sounds() -> void:
	# Countdown Tick
	var tick := _create_definition("countdown_tick", SoundCategory.COUNTDOWN)
	tick.duration = 0.15
	tick.base_volume_db = -3.0
	tick.pitch_variance = 0.02
	tick.priority = 4
	var tick_base := LayerConfig.new()
	tick_base.waveform = WaveformType.SINE
	tick_base.frequency = 880.0
	tick_base.adsr = Vector4(0.002, 0.06, 0.5, 0.08)
	tick.layers[SoundLayer.BASE] = tick_base
	var tick_impact := LayerConfig.new()
	tick_impact.waveform = WaveformType.NOISE_WHITE
	tick_impact.frequency = 4000.0
	tick_impact.adsr = Vector4(0.001, 0.03, 0.2, 0.03)
	tick_impact.volume_mult = 0.3
	tick_impact.filter_cutoff = 6000.0
	tick.layers[SoundLayer.IMPACT] = tick_impact
	_register_definition(tick)

	# Countdown Final
	var final := _create_definition("countdown_final", SoundCategory.COUNTDOWN)
	final.duration = 0.5
	final.base_volume_db = 3.0
	final.pitch_variance = 0.01
	final.priority = 5
	var final_base := LayerConfig.new()
	final_base.waveform = WaveformType.SINE
	final_base.frequency = 523.25  # C5
	final_base.adsr = Vector4(0.01, 0.2, 0.6, 0.25)
	final_base.harmonics = [2.0, 3.0, 4.0]
	final.layers[SoundLayer.BASE] = final_base
	var final_accent := LayerConfig.new()
	final_accent.waveform = WaveformType.SINE
	final_accent.frequency = 1046.5  # C6
	final_accent.delay = 0.05
	final_accent.adsr = Vector4(0.005, 0.15, 0.5, 0.2)
	final_accent.volume_mult = 0.5
	final.layers[SoundLayer.ACCENT] = final_accent
	var final_tail := LayerConfig.new()
	final_tail.waveform = WaveformType.NOISE_PINK
	final_tail.frequency = 2000.0
	final_tail.adsr = Vector4(0.001, 0.1, 0.3, 0.15)
	final_tail.volume_mult = 0.2
	final_tail.filter_cutoff = 4000.0
	final_tail.reverb = 0.4
	final.layers[SoundLayer.TAIL] = final_tail
	_register_definition(final)

	# Timer Warning
	var timer_warn := _create_definition("timer_warning", SoundCategory.COUNTDOWN)
	timer_warn.duration = 0.25
	timer_warn.base_volume_db = 0.0
	timer_warn.pitch_variance = 0.02
	timer_warn.priority = 4
	var timer_warn_base := LayerConfig.new()
	timer_warn_base.waveform = WaveformType.TRIANGLE
	timer_warn_base.frequency = 600.0
	timer_warn_base.adsr = Vector4(0.005, 0.1, 0.5, 0.12)
	timer_warn.layers[SoundLayer.BASE] = timer_warn_base
	var timer_warn_accent := LayerConfig.new()
	timer_warn_accent.waveform = WaveformType.TRIANGLE
	timer_warn_accent.frequency = 800.0
	timer_warn_accent.delay = 0.06
	timer_warn_accent.adsr = Vector4(0.005, 0.08, 0.4, 0.1)
	timer_warn_accent.volume_mult = 0.6
	timer_warn.layers[SoundLayer.ACCENT] = timer_warn_accent
	_register_definition(timer_warn)

	# Timer Critical
	var timer_crit := _create_definition("timer_critical", SoundCategory.COUNTDOWN)
	timer_crit.duration = 0.2
	timer_crit.base_volume_db = 3.0
	timer_crit.pitch_variance = 0.01
	timer_crit.priority = 5
	var timer_crit_base := LayerConfig.new()
	timer_crit_base.waveform = WaveformType.SQUARE
	timer_crit_base.frequency = 800.0
	timer_crit_base.adsr = Vector4(0.002, 0.08, 0.5, 0.1)
	timer_crit_base.distortion = 0.1
	timer_crit.layers[SoundLayer.BASE] = timer_crit_base
	_register_definition(timer_crit)


func _register_progress_sounds() -> void:
	# Progress Tick
	var prog_tick := _create_definition("progress_tick", SoundCategory.PROGRESS)
	prog_tick.duration = 0.03
	prog_tick.base_volume_db = -15.0
	prog_tick.pitch_variance = 0.15
	prog_tick.priority = 0
	var prog_tick_base := LayerConfig.new()
	prog_tick_base.waveform = WaveformType.SINE
	prog_tick_base.frequency = 1800.0
	prog_tick_base.adsr = Vector4(0.001, 0.015, 0.2, 0.01)
	prog_tick.layers[SoundLayer.BASE] = prog_tick_base
	_register_definition(prog_tick)

	# Progress Complete
	var prog_complete := _create_definition("progress_complete", SoundCategory.PROGRESS)
	prog_complete.duration = 0.35
	prog_complete.base_volume_db = 0.0
	prog_complete.pitch_variance = 0.03
	prog_complete.priority = 4
	var prog_complete_base := LayerConfig.new()
	prog_complete_base.waveform = WaveformType.SINE
	prog_complete_base.frequency = 587.33  # D5
	prog_complete_base.adsr = Vector4(0.01, 0.12, 0.5, 0.18)
	prog_complete_base.harmonics = [2.0, 3.0]
	prog_complete.layers[SoundLayer.BASE] = prog_complete_base
	var prog_complete_accent := LayerConfig.new()
	prog_complete_accent.waveform = WaveformType.SINE
	prog_complete_accent.frequency = 880.0  # A5
	prog_complete_accent.delay = 0.08
	prog_complete_accent.adsr = Vector4(0.01, 0.1, 0.4, 0.15)
	prog_complete_accent.volume_mult = 0.6
	prog_complete.layers[SoundLayer.ACCENT] = prog_complete_accent
	_register_definition(prog_complete)

	# Loading Loop (short beep for loop)
	var loading := _create_definition("loading_loop", SoundCategory.PROGRESS)
	loading.duration = 0.1
	loading.base_volume_db = -12.0
	loading.pitch_variance = 0.1
	loading.priority = 1
	var loading_base := LayerConfig.new()
	loading_base.waveform = WaveformType.SINE
	loading_base.frequency = 1000.0
	loading_base.adsr = Vector4(0.01, 0.04, 0.4, 0.04)
	loading.layers[SoundLayer.BASE] = loading_base
	_register_definition(loading)

	# Loading Complete
	var load_complete := _create_definition("loading_complete", SoundCategory.PROGRESS)
	load_complete.duration = 0.25
	load_complete.base_volume_db = -3.0
	load_complete.pitch_variance = 0.04
	load_complete.priority = 3
	var load_complete_base := LayerConfig.new()
	load_complete_base.waveform = WaveformType.SINE
	load_complete_base.frequency = 700.0
	load_complete_base.freq_envelope = Vector2(0.8, 1.2)
	load_complete_base.adsr = Vector4(0.01, 0.1, 0.5, 0.12)
	load_complete.layers[SoundLayer.BASE] = load_complete_base
	_register_definition(load_complete)


func _register_social_sounds() -> void:
	# Player Join
	var join := _create_definition("player_join", SoundCategory.SOCIAL)
	join.duration = 0.3
	join.base_volume_db = -3.0
	join.pitch_variance = 0.05
	join.priority = 4
	var join_base := LayerConfig.new()
	join_base.waveform = WaveformType.SINE
	join_base.frequency = 659.25  # E5
	join_base.freq_envelope = Vector2(0.7, 1.1)
	join_base.adsr = Vector4(0.01, 0.12, 0.5, 0.15)
	join_base.harmonics = [2.0]
	join.layers[SoundLayer.BASE] = join_base
	var join_accent := LayerConfig.new()
	join_accent.waveform = WaveformType.SINE
	join_accent.frequency = 987.77  # B5
	join_accent.delay = 0.08
	join_accent.adsr = Vector4(0.01, 0.1, 0.4, 0.12)
	join_accent.volume_mult = 0.5
	join.layers[SoundLayer.ACCENT] = join_accent
	_register_definition(join)

	# Player Leave
	var leave := _create_definition("player_leave", SoundCategory.SOCIAL)
	leave.duration = 0.25
	leave.base_volume_db = -6.0
	leave.pitch_variance = 0.05
	leave.priority = 3
	var leave_base := LayerConfig.new()
	leave_base.waveform = WaveformType.SINE
	leave_base.frequency = 523.25  # C5
	leave_base.freq_envelope = Vector2(1.1, 0.7)
	leave_base.adsr = Vector4(0.01, 0.1, 0.4, 0.12)
	leave.layers[SoundLayer.BASE] = leave_base
	_register_definition(leave)

	# Chat Message
	var chat := _create_definition("chat_message", SoundCategory.SOCIAL)
	chat.duration = 0.12
	chat.base_volume_db = -9.0
	chat.pitch_variance = 0.08
	chat.priority = 2
	var chat_base := LayerConfig.new()
	chat_base.waveform = WaveformType.SINE
	chat_base.frequency = 1400.0
	chat_base.adsr = Vector4(0.003, 0.05, 0.4, 0.04)
	chat.layers[SoundLayer.BASE] = chat_base
	_register_definition(chat)

	# Chat Mention
	var mention := _create_definition("chat_mention", SoundCategory.SOCIAL)
	mention.duration = 0.2
	mention.base_volume_db = 0.0
	mention.pitch_variance = 0.04
	mention.priority = 4
	var mention_base := LayerConfig.new()
	mention_base.waveform = WaveformType.SINE
	mention_base.frequency = 880.0
	mention_base.adsr = Vector4(0.005, 0.08, 0.5, 0.1)
	mention_base.harmonics = [2.0]
	mention.layers[SoundLayer.BASE] = mention_base
	var mention_accent := LayerConfig.new()
	mention_accent.waveform = WaveformType.SINE
	mention_accent.frequency = 1760.0
	mention_accent.delay = 0.05
	mention_accent.adsr = Vector4(0.003, 0.06, 0.4, 0.08)
	mention_accent.volume_mult = 0.4
	mention.layers[SoundLayer.ACCENT] = mention_accent
	_register_definition(mention)

	# Friend Online
	var friend := _create_definition("friend_online", SoundCategory.SOCIAL)
	friend.duration = 0.3
	friend.base_volume_db = -6.0
	friend.pitch_variance = 0.04
	friend.priority = 3
	var friend_base := LayerConfig.new()
	friend_base.waveform = WaveformType.SINE
	friend_base.frequency = 698.46  # F5
	friend_base.freq_envelope = Vector2(0.8, 1.1)
	friend_base.adsr = Vector4(0.01, 0.12, 0.5, 0.15)
	friend.layers[SoundLayer.BASE] = friend_base
	_register_definition(friend)

	# Party Invite
	var invite := _create_definition("party_invite", SoundCategory.SOCIAL)
	invite.duration = 0.4
	invite.base_volume_db = 0.0
	invite.pitch_variance = 0.03
	invite.priority = 4
	var invite_base := LayerConfig.new()
	invite_base.waveform = WaveformType.SINE
	invite_base.frequency = 523.25  # C5
	invite_base.adsr = Vector4(0.01, 0.15, 0.5, 0.2)
	invite_base.harmonics = [2.0, 3.0]
	invite.layers[SoundLayer.BASE] = invite_base
	var invite_accent := LayerConfig.new()
	invite_accent.waveform = WaveformType.SINE
	invite_accent.frequency = 783.99  # G5
	invite_accent.delay = 0.12
	invite_accent.adsr = Vector4(0.01, 0.12, 0.4, 0.15)
	invite_accent.volume_mult = 0.7
	invite.layers[SoundLayer.ACCENT] = invite_accent
	_register_definition(invite)


func _register_special_sounds() -> void:
	# Purchase
	var purchase := _create_definition("purchase", SoundCategory.SPECIAL)
	purchase.duration = 0.5
	purchase.base_volume_db = 0.0
	purchase.pitch_variance = 0.03
	purchase.priority = 4
	var purchase_base := LayerConfig.new()
	purchase_base.waveform = WaveformType.SINE
	purchase_base.frequency = 440.0
	purchase_base.adsr = Vector4(0.01, 0.2, 0.5, 0.25)
	purchase_base.harmonics = [2.0, 2.5, 3.0]
	purchase.layers[SoundLayer.BASE] = purchase_base
	var purchase_impact := LayerConfig.new()
	purchase_impact.waveform = WaveformType.NOISE_WHITE
	purchase_impact.frequency = 3000.0
	purchase_impact.adsr = Vector4(0.001, 0.05, 0.2, 0.04)
	purchase_impact.volume_mult = 0.25
	purchase_impact.filter_cutoff = 5000.0
	purchase.layers[SoundLayer.IMPACT] = purchase_impact
	_register_definition(purchase)

	# Reward
	var reward := _create_definition("reward", SoundCategory.SPECIAL)
	reward.duration = 0.6
	reward.base_volume_db = 3.0
	reward.pitch_variance = 0.02
	reward.priority = 5
	var reward_base := LayerConfig.new()
	reward_base.waveform = WaveformType.SINE
	reward_base.frequency = 392.0  # G4
	reward_base.adsr = Vector4(0.02, 0.2, 0.6, 0.25)
	reward_base.harmonics = [2.0, 3.0, 4.0]
	reward.layers[SoundLayer.BASE] = reward_base
	var reward_accent := LayerConfig.new()
	reward_accent.waveform = WaveformType.SINE
	reward_accent.frequency = 587.33  # D5
	reward_accent.delay = 0.12
	reward_accent.adsr = Vector4(0.01, 0.15, 0.5, 0.2)
	reward_accent.volume_mult = 0.7
	reward.layers[SoundLayer.ACCENT] = reward_accent
	var reward_tail := LayerConfig.new()
	reward_tail.waveform = WaveformType.SINE
	reward_tail.frequency = 783.99  # G5
	reward_tail.delay = 0.24
	reward_tail.adsr = Vector4(0.01, 0.12, 0.5, 0.2)
	reward_tail.volume_mult = 0.5
	reward_tail.reverb = 0.5
	reward.layers[SoundLayer.TAIL] = reward_tail
	_register_definition(reward)

	# Coins/Currency
	var coins := _create_definition("coins", SoundCategory.SPECIAL)
	coins.duration = 0.25
	coins.base_volume_db = -3.0
	coins.pitch_variance = 0.1
	coins.priority = 3
	var coins_base := LayerConfig.new()
	coins_base.waveform = WaveformType.SINE
	coins_base.frequency = 2000.0
	coins_base.adsr = Vector4(0.001, 0.08, 0.4, 0.15)
	coins.layers[SoundLayer.BASE] = coins_base
	var coins_accent := LayerConfig.new()
	coins_accent.waveform = WaveformType.SINE
	coins_accent.frequency = 3000.0
	coins_accent.delay = 0.03
	coins_accent.adsr = Vector4(0.001, 0.06, 0.3, 0.12)
	coins_accent.volume_mult = 0.5
	coins.layers[SoundLayer.ACCENT] = coins_accent
	_register_definition(coins)

	# Power Up
	var powerup := _create_definition("powerup", SoundCategory.SPECIAL)
	powerup.duration = 0.4
	powerup.base_volume_db = 0.0
	powerup.pitch_variance = 0.04
	powerup.priority = 4
	var powerup_base := LayerConfig.new()
	powerup_base.waveform = WaveformType.SINE
	powerup_base.frequency = 300.0
	powerup_base.freq_envelope = Vector2(0.5, 2.0)
	powerup_base.adsr = Vector4(0.01, 0.2, 0.5, 0.18)
	powerup_base.harmonics = [2.0, 3.0]
	powerup.layers[SoundLayer.BASE] = powerup_base
	_register_definition(powerup)

	# Star/Rating
	var star := _create_definition("star", SoundCategory.SPECIAL)
	star.duration = 0.2
	star.base_volume_db = -3.0
	star.pitch_variance = 0.1
	star.priority = 3
	var star_base := LayerConfig.new()
	star_base.waveform = WaveformType.SINE
	star_base.frequency = 1200.0
	star_base.freq_envelope = Vector2(0.8, 1.2)
	star_base.adsr = Vector4(0.005, 0.08, 0.5, 0.1)
	star_base.harmonics = [2.0]
	star.layers[SoundLayer.BASE] = star_base
	_register_definition(star)

	# Sparkle/Magic
	var sparkle := _create_definition("sparkle", SoundCategory.SPECIAL)
	sparkle.duration = 0.3
	sparkle.base_volume_db = -6.0
	sparkle.pitch_variance = 0.15
	sparkle.priority = 2
	var sparkle_base := LayerConfig.new()
	sparkle_base.waveform = WaveformType.SINE
	sparkle_base.frequency = 2500.0
	sparkle_base.freq_envelope = Vector2(0.6, 1.4)
	sparkle_base.adsr = Vector4(0.002, 0.1, 0.4, 0.18)
	sparkle.layers[SoundLayer.BASE] = sparkle_base
	var sparkle_accent := LayerConfig.new()
	sparkle_accent.waveform = WaveformType.TRIANGLE
	sparkle_accent.frequency = 4000.0
	sparkle_accent.delay = 0.05
	sparkle_accent.adsr = Vector4(0.002, 0.08, 0.3, 0.15)
	sparkle_accent.volume_mult = 0.3
	sparkle.layers[SoundLayer.ACCENT] = sparkle_accent
	_register_definition(sparkle)


# -- Definition Management --

func _create_definition(id: String, category: SoundCategory) -> SoundDefinition:
	var def := SoundDefinition.new()
	def.id = id
	def.category = category
	return def


func _register_definition(definition: SoundDefinition) -> void:
	_definitions[definition.id] = definition


# -- Public API --

## Get a sound definition by ID.
func get_definition(id: String) -> SoundDefinition:
	return _definitions.get(id)


## Get all sound IDs in a category.
func get_sounds_by_category(category: SoundCategory) -> Array[String]:
	var result: Array[String] = []
	for id: String in _definitions:
		var def: SoundDefinition = _definitions[id]
		if def.category == category:
			result.append(id)
	return result


## Get all registered sound IDs.
func get_all_sound_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_definitions.keys())
	return result


## Get total count of registered sounds.
func get_sound_count() -> int:
	return _definitions.size()


## Check if a sound is registered.
func has_sound(id: String) -> bool:
	return _definitions.has(id)


## Get the next variation index for a sound (round-robin).
func get_next_variation(id: String) -> int:
	if not _definitions.has(id):
		return 0
	var def: SoundDefinition = _definitions[id]
	var v := def.get_next_variation()
	variation_selected.emit(id, v)
	return v


## Get sound configuration for AudioManager integration.
func get_sound_config(id: String) -> Dictionary:
	if not _definitions.has(id):
		return {}

	var def: SoundDefinition = _definitions[id]
	return {
		"id": id,
		"volume_db": def.base_volume_db,
		"pitch_variance": def.pitch_variance,
		"priority": def.priority,
		"duration": def.duration,
		"category": def.category,
		"has_layers": def.layers.size() > 1,
	}


## Get pitch offset for variation (adds subtle uniqueness).
func get_variation_pitch_offset(id: String, variation: int) -> float:
	if not _definitions.has(id):
		return 0.0

	var def: SoundDefinition = _definitions[id]
	var variance := def.pitch_variance

	# Deterministic but varied pitch per variation
	var seed_value := hash(id) + variation
	var rand := sin(float(seed_value)) * 0.5 + 0.5  # 0-1 range
	return (rand - 0.5) * 2.0 * variance


## Get audio file path for a sound (for loading actual files).
func get_audio_path(id: String, variation: int = 0) -> String:
	return "%s%s_%d.ogg" % [_audio_base_path, id, variation]


## Check if actual audio file exists for a sound.
func has_audio_file(id: String, variation: int = 0) -> bool:
	var path := get_audio_path(id, variation)
	return ResourceLoader.exists(path)


# -- Statistics --

## Get library statistics.
func get_stats() -> Dictionary:
	var by_category: Dictionary = {}
	for cat: int in SoundCategory.values():
		by_category[cat] = 0

	for id: String in _definitions:
		var def: SoundDefinition = _definitions[id]
		by_category[def.category] = (by_category[def.category] as int) + 1

	return {
		"total_sounds": _definitions.size(),
		"variations_per_sound": VARIATIONS_PER_SOUND,
		"total_variations": _definitions.size() * VARIATIONS_PER_SOUND,
		"by_category": by_category,
		"cache_size": _stream_cache.size(),
	}
