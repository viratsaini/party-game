## AdaptiveQuality - Intelligent quality scaling system for mobile devices
##
## Provides dynamic quality adjustment based on real-time performance:
##
## - FPS-based quality scaling with hysteresis
## - Resolution scaling with sharpening compensation
## - Effect quality levels (particles, shadows, post-processing)
## - Animation complexity reduction
## - Texture streaming and LOD management
## - GPU workload balancing
##
## The system maintains target FPS by intelligently adjusting quality
## settings, prioritizing visual impact and perceived smoothness.
##
## Usage:
##   AdaptiveQuality.set_target_fps(60)
##   AdaptiveQuality.enable_auto_scaling()
##   AdaptiveQuality.get_quality_level()
class_name AdaptiveQuality
extends Node


# =============================================================================
# region - Signals
# =============================================================================

## Emitted when quality level changes
signal quality_level_changed(level: QualityLevel, reason: String)

## Emitted when resolution scale changes
signal resolution_scale_changed(scale: float)

## Emitted when effect settings change
signal effect_settings_changed(settings: EffectSettings)

## Emitted when a quality adjustment is made
signal quality_adjusted(adjustment: String, direction: AdjustmentDirection)

## Emitted with quality metrics each update
signal metrics_updated(metrics: Dictionary)

# endregion


# =============================================================================
# region - Enums
# =============================================================================

## Discrete quality levels
enum QualityLevel {
	POTATO,     ## Absolute minimum - playable on anything
	LOW,        ## Reduced quality for budget devices
	MEDIUM,     ## Balanced quality
	HIGH,       ## Full quality for flagship devices
	ULTRA,      ## Maximum quality with all effects
	CUSTOM      ## User-defined settings
}

## Quality adjustment direction
enum AdjustmentDirection {
	DECREASE,
	INCREASE,
	NONE
}

## Individual effect categories
enum EffectCategory {
	RESOLUTION,
	SHADOWS,
	POST_PROCESSING,
	PARTICLES,
	ANIMATIONS,
	LOD,
	TEXTURES,
	REFLECTIONS
}

# endregion


# =============================================================================
# region - Inner Classes
# =============================================================================

## Effect settings configuration
class EffectSettings:
	var resolution_scale: float = 1.0
	var shadow_quality: int = 2          ## 0-3 (off, low, medium, high)
	var shadow_resolution: int = 2048
	var post_processing: bool = true
	var bloom: bool = true
	var ssao: bool = false
	var ssr: bool = false
	var dof: bool = false
	var motion_blur: bool = false
	var particle_quality: float = 1.0    ## 0.0-1.0 multiplier
	var particle_limit: int = 256
	var animation_quality: float = 1.0   ## LOD for animations
	var lod_bias: float = 1.0            ## Higher = more aggressive LOD
	var texture_quality: int = 2         ## 0-3
	var msaa: int = 0                    ## 0, 2, 4, 8
	var fxaa: bool = true
	var draw_distance: float = 200.0
	var reflection_quality: int = 1      ## 0-2

	func duplicate_settings() -> EffectSettings:
		var copy := EffectSettings.new()
		copy.resolution_scale = resolution_scale
		copy.shadow_quality = shadow_quality
		copy.shadow_resolution = shadow_resolution
		copy.post_processing = post_processing
		copy.bloom = bloom
		copy.ssao = ssao
		copy.ssr = ssr
		copy.dof = dof
		copy.motion_blur = motion_blur
		copy.particle_quality = particle_quality
		copy.particle_limit = particle_limit
		copy.animation_quality = animation_quality
		copy.lod_bias = lod_bias
		copy.texture_quality = texture_quality
		copy.msaa = msaa
		copy.fxaa = fxaa
		copy.draw_distance = draw_distance
		copy.reflection_quality = reflection_quality
		return copy


## Quality preset definition
class QualityPreset:
	var name: String
	var settings: EffectSettings
	var gpu_target_ms: float      ## Target GPU time per frame
	var memory_budget_mb: float   ## Memory budget for assets

	func _init(
		p_name: String,
		p_settings: EffectSettings,
		p_gpu_target: float = 16.0,
		p_memory: float = 512.0
	) -> void:
		name = p_name
		settings = p_settings
		gpu_target_ms = p_gpu_target
		memory_budget_mb = p_memory

# endregion


# =============================================================================
# region - Constants
# =============================================================================

## FPS thresholds for quality adjustment
const FPS_EXCELLENT_MARGIN: float = 1.15    ## 15% above target = can increase
const FPS_GOOD_MARGIN: float = 0.95         ## 95% of target = stable
const FPS_WARNING_MARGIN: float = 0.85      ## 85% of target = should decrease
const FPS_CRITICAL_MARGIN: float = 0.70     ## 70% of target = must decrease

## Frame count thresholds for adjustment decisions
const FRAMES_FOR_INCREASE: int = 300    ## 5 seconds at 60fps
const FRAMES_FOR_DECREASE: int = 60     ## 1 second at 60fps
const FRAMES_FOR_EMERGENCY: int = 15    ## 0.25 seconds - critical

## Adjustment cooldowns
const INCREASE_COOLDOWN: float = 10.0   ## Wait 10s before increasing
const DECREASE_COOLDOWN: float = 3.0    ## Wait 3s before decreasing again
const EMERGENCY_COOLDOWN: float = 0.5   ## Wait 0.5s for emergency decrease

## Resolution scale bounds
const MIN_RESOLUTION_SCALE: float = 0.4
const MAX_RESOLUTION_SCALE: float = 1.5   ## Allow supersampling on powerful devices
const RESOLUTION_STEP: float = 0.1

## Animation LOD distances
const ANIM_LOD_DISTANCES: Array[float] = [10.0, 25.0, 50.0, 100.0]

# endregion


# =============================================================================
# region - Quality Presets
# =============================================================================

var _presets: Dictionary = {}


func _create_quality_presets() -> void:
	## POTATO - Absolute minimum
	var potato := EffectSettings.new()
	potato.resolution_scale = 0.5
	potato.shadow_quality = 0
	potato.shadow_resolution = 256
	potato.post_processing = false
	potato.bloom = false
	potato.ssao = false
	potato.ssr = false
	potato.dof = false
	potato.motion_blur = false
	potato.particle_quality = 0.2
	potato.particle_limit = 16
	potato.animation_quality = 0.5
	potato.lod_bias = 3.0
	potato.texture_quality = 0
	potato.msaa = 0
	potato.fxaa = false
	potato.draw_distance = 50.0
	potato.reflection_quality = 0
	_presets[QualityLevel.POTATO] = QualityPreset.new("Potato", potato, 33.0, 256.0)

	## LOW - Budget devices
	var low := EffectSettings.new()
	low.resolution_scale = 0.6
	low.shadow_quality = 1
	low.shadow_resolution = 512
	low.post_processing = false
	low.bloom = false
	low.ssao = false
	low.ssr = false
	low.dof = false
	low.motion_blur = false
	low.particle_quality = 0.4
	low.particle_limit = 48
	low.animation_quality = 0.7
	low.lod_bias = 2.0
	low.texture_quality = 1
	low.msaa = 0
	low.fxaa = true
	low.draw_distance = 80.0
	low.reflection_quality = 0
	_presets[QualityLevel.LOW] = QualityPreset.new("Low", low, 33.0, 384.0)

	## MEDIUM - Mid-range devices
	var medium := EffectSettings.new()
	medium.resolution_scale = 0.8
	medium.shadow_quality = 2
	medium.shadow_resolution = 1024
	medium.post_processing = true
	medium.bloom = true
	medium.ssao = false
	medium.ssr = false
	medium.dof = false
	medium.motion_blur = false
	medium.particle_quality = 0.7
	medium.particle_limit = 128
	medium.animation_quality = 0.9
	medium.lod_bias = 1.5
	medium.texture_quality = 2
	medium.msaa = 0
	medium.fxaa = true
	medium.draw_distance = 120.0
	medium.reflection_quality = 1
	_presets[QualityLevel.MEDIUM] = QualityPreset.new("Medium", medium, 22.0, 768.0)

	## HIGH - Flagship devices
	var high := EffectSettings.new()
	high.resolution_scale = 1.0
	high.shadow_quality = 2
	high.shadow_resolution = 2048
	high.post_processing = true
	high.bloom = true
	high.ssao = true
	high.ssr = false
	high.dof = false
	high.motion_blur = false
	high.particle_quality = 0.9
	high.particle_limit = 256
	high.animation_quality = 1.0
	high.lod_bias = 1.0
	high.texture_quality = 2
	high.msaa = 2
	high.fxaa = true
	high.draw_distance = 180.0
	high.reflection_quality = 2
	_presets[QualityLevel.HIGH] = QualityPreset.new("High", high, 16.0, 1280.0)

	## ULTRA - Gaming devices / tablets
	var ultra := EffectSettings.new()
	ultra.resolution_scale = 1.0
	ultra.shadow_quality = 3
	ultra.shadow_resolution = 4096
	ultra.post_processing = true
	ultra.bloom = true
	ultra.ssao = true
	ultra.ssr = true
	ultra.dof = true
	ultra.motion_blur = true
	ultra.particle_quality = 1.0
	ultra.particle_limit = 512
	ultra.animation_quality = 1.0
	ultra.lod_bias = 0.5
	ultra.texture_quality = 3
	ultra.msaa = 4
	ultra.fxaa = true
	ultra.draw_distance = 300.0
	ultra.reflection_quality = 2
	_presets[QualityLevel.ULTRA] = QualityPreset.new("Ultra", ultra, 8.0, 2048.0)

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

## Current quality state
var current_level: QualityLevel = QualityLevel.MEDIUM
var current_settings: EffectSettings = null

## Target performance
var target_fps: float = 60.0
var target_frame_time_ms: float = 16.67

## Auto-scaling state
var auto_scaling_enabled: bool = true
var _adjustment_cooldown: float = 0.0
var _last_adjustment_direction: AdjustmentDirection = AdjustmentDirection.NONE

## Frame time tracking
var _frame_times: Array[float] = []
var _frame_time_index: int = 0
var _average_frame_time: float = 16.67
var _frame_time_variance: float = 0.0

## Adjustment tracking
var _good_frame_count: int = 0
var _bad_frame_count: int = 0
var _critical_frame_count: int = 0

## Quality adjustment queue (for gradual changes)
var _pending_adjustments: Array[Dictionary] = []

## Statistics
var _increases_this_session: int = 0
var _decreases_this_session: int = 0
var _time_at_current_level: float = 0.0

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	_create_quality_presets()
	_initialize_frame_buffer()

	## Start with medium settings
	current_settings = (_presets[QualityLevel.MEDIUM] as QualityPreset).settings.duplicate_settings()

	process_priority = -999  ## Process very early


func _process(delta: float) -> void:
	_track_frame_time(delta)
	_time_at_current_level += delta

	if _adjustment_cooldown > 0:
		_adjustment_cooldown -= delta

	if auto_scaling_enabled:
		_process_auto_scaling()

	_process_pending_adjustments(delta)
	_emit_metrics()


func _initialize_frame_buffer() -> void:
	_frame_times.resize(120)  ## 2 seconds at 60fps
	_frame_times.fill(target_frame_time_ms)

# endregion


# =============================================================================
# region - Frame Time Tracking
# =============================================================================

func _track_frame_time(delta: float) -> void:
	var frame_time_ms := delta * 1000.0

	## Update rolling buffer
	_frame_times[_frame_time_index] = frame_time_ms
	_frame_time_index = (_frame_time_index + 1) % _frame_times.size()

	## Calculate statistics
	var total: float = 0.0
	var min_ft: float = 1000.0
	var max_ft: float = 0.0

	for ft: float in _frame_times:
		total += ft
		min_ft = minf(min_ft, ft)
		max_ft = maxf(max_ft, ft)

	_average_frame_time = total / _frame_times.size()
	_frame_time_variance = (max_ft - min_ft) / _average_frame_time if _average_frame_time > 0 else 0.0


func get_current_fps() -> float:
	return 1000.0 / _average_frame_time if _average_frame_time > 0 else 0.0

# endregion


# =============================================================================
# region - Auto Scaling Logic
# =============================================================================

func _process_auto_scaling() -> void:
	if _adjustment_cooldown > 0:
		return

	var current_fps := get_current_fps()
	var fps_ratio := current_fps / target_fps

	## Track frame quality
	if fps_ratio >= FPS_EXCELLENT_MARGIN:
		_good_frame_count += 1
		_bad_frame_count = 0
		_critical_frame_count = 0
	elif fps_ratio < FPS_CRITICAL_MARGIN:
		_critical_frame_count += 1
		_bad_frame_count += 1
		_good_frame_count = 0
	elif fps_ratio < FPS_WARNING_MARGIN:
		_bad_frame_count += 1
		_good_frame_count = 0
		_critical_frame_count = 0
	else:
		## In acceptable range - slowly reset counters
		_good_frame_count = maxi(_good_frame_count - 1, 0)
		_bad_frame_count = maxi(_bad_frame_count - 1, 0)
		_critical_frame_count = 0

	## Emergency decrease
	if _critical_frame_count >= FRAMES_FOR_EMERGENCY:
		_emergency_decrease_quality()
		_critical_frame_count = 0
		_bad_frame_count = 0
		return

	## Normal decrease
	if _bad_frame_count >= FRAMES_FOR_DECREASE:
		_decrease_quality()
		_bad_frame_count = 0
		return

	## Increase quality
	if _good_frame_count >= FRAMES_FOR_INCREASE:
		_increase_quality()
		_good_frame_count = 0


func _emergency_decrease_quality() -> void:
	print("[AdaptiveQuality] EMERGENCY: FPS critical, aggressively reducing quality")

	## Multiple decreases at once
	for i in range(3):
		if not _decrease_single_setting():
			break

	_adjustment_cooldown = EMERGENCY_COOLDOWN
	_last_adjustment_direction = AdjustmentDirection.DECREASE
	_decreases_this_session += 1


func _decrease_quality() -> void:
	if _decrease_single_setting():
		_adjustment_cooldown = DECREASE_COOLDOWN
		_last_adjustment_direction = AdjustmentDirection.DECREASE
		_decreases_this_session += 1


func _increase_quality() -> void:
	if _increase_single_setting():
		_adjustment_cooldown = INCREASE_COOLDOWN
		_last_adjustment_direction = AdjustmentDirection.INCREASE
		_increases_this_session += 1

# endregion


# =============================================================================
# region - Setting Adjustments
# =============================================================================

## Priority order for decreasing quality (most expensive first)
const DECREASE_PRIORITY: Array[String] = [
	"ssr",           ## Very expensive
	"ssao",          ## Expensive
	"motion_blur",
	"dof",
	"shadow_quality",
	"msaa",
	"bloom",
	"particle_limit",
	"particle_quality",
	"resolution_scale",
	"draw_distance",
	"lod_bias",
	"texture_quality",
	"fxaa",
	"post_processing"
]


## Priority order for increasing quality (cheapest first)
const INCREASE_PRIORITY: Array[String] = [
	"fxaa",
	"post_processing",
	"texture_quality",
	"lod_bias",
	"draw_distance",
	"resolution_scale",
	"particle_quality",
	"particle_limit",
	"bloom",
	"shadow_quality",
	"msaa",
	"dof",
	"motion_blur",
	"ssao",
	"ssr"
]


func _decrease_single_setting() -> bool:
	for setting: String in DECREASE_PRIORITY:
		if _can_decrease_setting(setting):
			_apply_decrease(setting)
			quality_adjusted.emit(setting, AdjustmentDirection.DECREASE)
			return true
	return false


func _increase_single_setting() -> bool:
	## Don't increase beyond current quality level preset
	var preset: QualityPreset = _presets.get(current_level)
	if preset == null:
		return false

	for setting: String in INCREASE_PRIORITY:
		if _can_increase_setting(setting, preset.settings):
			_apply_increase(setting, preset.settings)
			quality_adjusted.emit(setting, AdjustmentDirection.INCREASE)
			return true
	return false


func _can_decrease_setting(setting: String) -> bool:
	match setting:
		"ssr": return current_settings.ssr
		"ssao": return current_settings.ssao
		"motion_blur": return current_settings.motion_blur
		"dof": return current_settings.dof
		"shadow_quality": return current_settings.shadow_quality > 0
		"msaa": return current_settings.msaa > 0
		"bloom": return current_settings.bloom
		"particle_limit": return current_settings.particle_limit > 16
		"particle_quality": return current_settings.particle_quality > 0.2
		"resolution_scale": return current_settings.resolution_scale > MIN_RESOLUTION_SCALE
		"draw_distance": return current_settings.draw_distance > 50.0
		"lod_bias": return current_settings.lod_bias < 3.0
		"texture_quality": return current_settings.texture_quality > 0
		"fxaa": return current_settings.fxaa
		"post_processing": return current_settings.post_processing
	return false


func _can_increase_setting(setting: String, target: EffectSettings) -> bool:
	match setting:
		"ssr": return not current_settings.ssr and target.ssr
		"ssao": return not current_settings.ssao and target.ssao
		"motion_blur": return not current_settings.motion_blur and target.motion_blur
		"dof": return not current_settings.dof and target.dof
		"shadow_quality": return current_settings.shadow_quality < target.shadow_quality
		"msaa": return current_settings.msaa < target.msaa
		"bloom": return not current_settings.bloom and target.bloom
		"particle_limit": return current_settings.particle_limit < target.particle_limit
		"particle_quality": return current_settings.particle_quality < target.particle_quality - 0.05
		"resolution_scale": return current_settings.resolution_scale < target.resolution_scale - 0.05
		"draw_distance": return current_settings.draw_distance < target.draw_distance - 10.0
		"lod_bias": return current_settings.lod_bias > target.lod_bias + 0.1
		"texture_quality": return current_settings.texture_quality < target.texture_quality
		"fxaa": return not current_settings.fxaa and target.fxaa
		"post_processing": return not current_settings.post_processing and target.post_processing
	return false


func _apply_decrease(setting: String) -> void:
	match setting:
		"ssr":
			current_settings.ssr = false
			_apply_ssr(false)
		"ssao":
			current_settings.ssao = false
			_apply_ssao(false)
		"motion_blur":
			current_settings.motion_blur = false
		"dof":
			current_settings.dof = false
		"shadow_quality":
			current_settings.shadow_quality = maxi(current_settings.shadow_quality - 1, 0)
			_apply_shadows(current_settings.shadow_quality)
		"msaa":
			current_settings.msaa = 0 if current_settings.msaa == 2 else current_settings.msaa / 2
			_apply_msaa(current_settings.msaa)
		"bloom":
			current_settings.bloom = false
		"particle_limit":
			current_settings.particle_limit = maxi(current_settings.particle_limit - 32, 16)
		"particle_quality":
			current_settings.particle_quality = maxf(current_settings.particle_quality - 0.2, 0.2)
		"resolution_scale":
			current_settings.resolution_scale = maxf(current_settings.resolution_scale - RESOLUTION_STEP, MIN_RESOLUTION_SCALE)
			_apply_resolution(current_settings.resolution_scale)
		"draw_distance":
			current_settings.draw_distance = maxf(current_settings.draw_distance - 30.0, 50.0)
		"lod_bias":
			current_settings.lod_bias = minf(current_settings.lod_bias + 0.5, 3.0)
			_apply_lod_bias(current_settings.lod_bias)
		"texture_quality":
			current_settings.texture_quality = maxi(current_settings.texture_quality - 1, 0)
		"fxaa":
			current_settings.fxaa = false
			_apply_fxaa(false)
		"post_processing":
			current_settings.post_processing = false

	effect_settings_changed.emit(current_settings)
	print("[AdaptiveQuality] Decreased: %s" % setting)


func _apply_increase(setting: String, target: EffectSettings) -> void:
	match setting:
		"ssr":
			current_settings.ssr = true
			_apply_ssr(true)
		"ssao":
			current_settings.ssao = true
			_apply_ssao(true)
		"motion_blur":
			current_settings.motion_blur = true
		"dof":
			current_settings.dof = true
		"shadow_quality":
			current_settings.shadow_quality = mini(current_settings.shadow_quality + 1, target.shadow_quality)
			_apply_shadows(current_settings.shadow_quality)
		"msaa":
			current_settings.msaa = 2 if current_settings.msaa == 0 else mini(current_settings.msaa * 2, target.msaa)
			_apply_msaa(current_settings.msaa)
		"bloom":
			current_settings.bloom = true
		"particle_limit":
			current_settings.particle_limit = mini(current_settings.particle_limit + 32, target.particle_limit)
		"particle_quality":
			current_settings.particle_quality = minf(current_settings.particle_quality + 0.2, target.particle_quality)
		"resolution_scale":
			current_settings.resolution_scale = minf(current_settings.resolution_scale + RESOLUTION_STEP, target.resolution_scale)
			_apply_resolution(current_settings.resolution_scale)
		"draw_distance":
			current_settings.draw_distance = minf(current_settings.draw_distance + 30.0, target.draw_distance)
		"lod_bias":
			current_settings.lod_bias = maxf(current_settings.lod_bias - 0.5, target.lod_bias)
			_apply_lod_bias(current_settings.lod_bias)
		"texture_quality":
			current_settings.texture_quality = mini(current_settings.texture_quality + 1, target.texture_quality)
		"fxaa":
			current_settings.fxaa = true
			_apply_fxaa(true)
		"post_processing":
			current_settings.post_processing = true

	effect_settings_changed.emit(current_settings)
	print("[AdaptiveQuality] Increased: %s" % setting)

# endregion


# =============================================================================
# region - Engine Setting Application
# =============================================================================

func _apply_resolution(scale: float) -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.scaling_3d_scale = clampf(scale, MIN_RESOLUTION_SCALE, MAX_RESOLUTION_SCALE)
	resolution_scale_changed.emit(scale)


func _apply_shadows(level: int) -> void:
	match level:
		0:
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_HARD
			)
		1:
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW
			)
		2:
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_LOW
			)
		3:
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
			)


func _apply_msaa(level: int) -> void:
	var viewport := get_viewport()
	if viewport:
		match level:
			0:
				viewport.msaa_3d = Viewport.MSAA_DISABLED
			2:
				viewport.msaa_3d = Viewport.MSAA_2X
			4:
				viewport.msaa_3d = Viewport.MSAA_4X
			8:
				viewport.msaa_3d = Viewport.MSAA_8X


func _apply_fxaa(enabled: bool) -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if enabled else Viewport.SCREEN_SPACE_AA_DISABLED


func _apply_ssao(enabled: bool) -> void:
	if enabled:
		RenderingServer.environment_set_ssao_quality(
			RenderingServer.ENV_SSAO_QUALITY_LOW,
			true,  ## half_size
			0.5,
			2,
			0.7
		)
	## Note: Disabling SSAO requires Environment resource modification


func _apply_ssr(_enabled: bool) -> void:
	## SSR requires Environment resource modification
	pass


func _apply_lod_bias(bias: float) -> void:
	RenderingServer.mesh_set_lod_threshold(0, bias * 1000.0)

# endregion


# =============================================================================
# region - Pending Adjustments
# =============================================================================

func _process_pending_adjustments(delta: float) -> void:
	## Process gradual adjustments (like resolution smoothing)
	if _pending_adjustments.is_empty():
		return

	var adjustment: Dictionary = _pending_adjustments[0]
	adjustment["timer"] = (adjustment["timer"] as float) + delta

	if (adjustment["timer"] as float) >= (adjustment["duration"] as float):
		_pending_adjustments.remove_at(0)

# endregion


# =============================================================================
# region - Public API
# =============================================================================

## Sets the target FPS for quality scaling
func set_target_fps(fps: float) -> void:
	target_fps = clampf(fps, 15.0, 144.0)
	target_frame_time_ms = 1000.0 / target_fps


## Enables or disables automatic quality scaling
func enable_auto_scaling() -> void:
	auto_scaling_enabled = true


func disable_auto_scaling() -> void:
	auto_scaling_enabled = false


func is_auto_scaling_enabled() -> bool:
	return auto_scaling_enabled


## Sets a specific quality level
func set_quality_level(level: QualityLevel) -> void:
	if level == QualityLevel.CUSTOM:
		push_warning("[AdaptiveQuality] Use set_custom_settings() for custom quality")
		return

	if not _presets.has(level):
		push_error("[AdaptiveQuality] Invalid quality level: %d" % level)
		return

	var preset: QualityPreset = _presets[level]
	current_level = level
	current_settings = preset.settings.duplicate_settings()
	_time_at_current_level = 0.0

	_apply_all_settings()
	quality_level_changed.emit(level, "user_set")


## Gets the current quality level
func get_quality_level() -> QualityLevel:
	return current_level


## Gets the current effect settings
func get_effect_settings() -> EffectSettings:
	return current_settings.duplicate_settings()


## Sets custom effect settings
func set_custom_settings(settings: EffectSettings) -> void:
	current_level = QualityLevel.CUSTOM
	current_settings = settings.duplicate_settings()
	_apply_all_settings()
	quality_level_changed.emit(QualityLevel.CUSTOM, "custom_set")


## Gets the particle limit for the current settings
func get_particle_limit() -> int:
	return current_settings.particle_limit


## Gets the particle quality multiplier
func get_particle_quality() -> float:
	return current_settings.particle_quality


## Gets the animation quality (for LOD)
func get_animation_quality() -> float:
	return current_settings.animation_quality


## Gets the draw distance
func get_draw_distance() -> float:
	return current_settings.draw_distance


## Checks if a specific effect is enabled
func is_effect_enabled(effect: String) -> bool:
	match effect:
		"shadows": return current_settings.shadow_quality > 0
		"bloom": return current_settings.bloom
		"ssao": return current_settings.ssao
		"ssr": return current_settings.ssr
		"dof": return current_settings.dof
		"motion_blur": return current_settings.motion_blur
		"post_processing": return current_settings.post_processing
		"fxaa": return current_settings.fxaa
	return false


## Gets quality adjustment statistics
func get_statistics() -> Dictionary:
	return {
		"current_level": QualityLevel.keys()[current_level],
		"increases_this_session": _increases_this_session,
		"decreases_this_session": _decreases_this_session,
		"time_at_current_level": _time_at_current_level,
		"average_fps": get_current_fps(),
		"target_fps": target_fps,
		"average_frame_time_ms": _average_frame_time,
		"frame_time_variance": _frame_time_variance,
		"auto_scaling_enabled": auto_scaling_enabled,
		"resolution_scale": current_settings.resolution_scale,
		"particle_limit": current_settings.particle_limit
	}


func _apply_all_settings() -> void:
	_apply_resolution(current_settings.resolution_scale)
	_apply_shadows(current_settings.shadow_quality)
	_apply_msaa(current_settings.msaa)
	_apply_fxaa(current_settings.fxaa)
	_apply_lod_bias(current_settings.lod_bias)
	_apply_ssao(current_settings.ssao)
	_apply_ssr(current_settings.ssr)

	effect_settings_changed.emit(current_settings)

# endregion


# =============================================================================
# region - Metrics
# =============================================================================

func _emit_metrics() -> void:
	var metrics := {
		"fps": get_current_fps(),
		"frame_time_ms": _average_frame_time,
		"frame_time_variance": _frame_time_variance,
		"target_fps": target_fps,
		"quality_level": QualityLevel.keys()[current_level],
		"resolution_scale": current_settings.resolution_scale,
		"particle_limit": current_settings.particle_limit,
		"good_frames": _good_frame_count,
		"bad_frames": _bad_frame_count,
		"cooldown": _adjustment_cooldown
	}

	metrics_updated.emit(metrics)

# endregion
