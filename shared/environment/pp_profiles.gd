## Post-Processing Profiles for BattleZone Party
##
## Provides different visual profiles for each game mode, plus special effects
## like hit feedback, low health, and victory sequences. Designed for mobile
## performance with GL Compatibility renderer support.
##
## Usage:
##   PPProfiles.apply_profile("arena_blaster")
##   PPProfiles.apply_hit_effect()
##   PPProfiles.apply_low_health_effect(0.2)  # 20% health
class_name PPProfiles
extends RefCounted


# region -- Profile Definitions

## Base profile with balanced settings for all game modes
const PROFILE_DEFAULT: Dictionary = {
	# Glow / Bloom
	"glow_enabled": true,
	"glow_intensity": 0.4,
	"glow_strength": 0.8,
	"glow_bloom": 0.1,
	"glow_hdr_threshold": 0.8,
	"glow_mix": 0.2,

	# Color Grading
	"adjustment_enabled": true,
	"adjustment_brightness": 1.02,
	"adjustment_contrast": 1.1,
	"adjustment_saturation": 1.15,

	# Tonemap
	"tonemap_mode": Environment.TONE_MAPPER_ACES,
	"tonemap_exposure": 1.0,

	# SSAO (disabled by default for mobile)
	"ssao_enabled": false,
	"ssao_radius": 0.5,
	"ssao_intensity": 1.0,

	# Fog
	"fog_enabled": false,
	"fog_density": 0.001,

	# Vignette (via shader - not native Godot)
	"vignette_intensity": 0.0,
	"vignette_color": Color(0.0, 0.0, 0.0, 1.0),

	# Motion blur (via shader)
	"motion_blur_enabled": false,
	"motion_blur_intensity": 0.0,

	# Chromatic aberration (via shader)
	"chromatic_aberration_enabled": false,
	"chromatic_aberration_intensity": 0.0,

	# Depth of field
	"dof_blur_far_enabled": false,
	"dof_blur_far_distance": 20.0,
	"dof_blur_far_transition": 5.0,
	"dof_blur_near_enabled": false,

	# Lens distortion (via shader)
	"lens_distortion_enabled": false,
	"lens_distortion_intensity": 0.0,
}

## Arena Blaster - Intense combat with high contrast
const PROFILE_ARENA_BLASTER: Dictionary = {
	"glow_enabled": true,
	"glow_intensity": 0.5,
	"glow_strength": 0.9,
	"glow_bloom": 0.15,
	"glow_hdr_threshold": 0.75,
	"glow_mix": 0.25,

	"adjustment_enabled": true,
	"adjustment_brightness": 1.0,
	"adjustment_contrast": 1.15,
	"adjustment_saturation": 1.2,

	"tonemap_mode": Environment.TONE_MAPPER_ACES,
	"tonemap_exposure": 1.05,

	"ssao_enabled": true,  # Enabled on high quality
	"ssao_radius": 0.6,
	"ssao_intensity": 1.2,

	"vignette_intensity": 0.15,
	"vignette_color": Color(0.0, 0.0, 0.0, 1.0),

	"chromatic_aberration_enabled": true,
	"chromatic_aberration_intensity": 0.002,
}

## Turbo Karts - Speed and motion with warm colors
const PROFILE_TURBO_KARTS: Dictionary = {
	"glow_enabled": true,
	"glow_intensity": 0.45,
	"glow_strength": 0.85,
	"glow_bloom": 0.2,
	"glow_hdr_threshold": 0.7,
	"glow_mix": 0.3,

	"adjustment_enabled": true,
	"adjustment_brightness": 1.05,
	"adjustment_contrast": 1.12,
	"adjustment_saturation": 1.25,

	"tonemap_mode": Environment.TONE_MAPPER_ACES,
	"tonemap_exposure": 1.1,

	"motion_blur_enabled": true,
	"motion_blur_intensity": 0.3,

	"vignette_intensity": 0.1,
	"vignette_color": Color(0.05, 0.02, 0.0, 1.0),  # Warm tint

	"chromatic_aberration_enabled": true,
	"chromatic_aberration_intensity": 0.003,

	"lens_distortion_enabled": true,
	"lens_distortion_intensity": 0.02,
}

## Obstacle Royale - Tense survival with cooler tones
const PROFILE_OBSTACLE_ROYALE: Dictionary = {
	"glow_enabled": true,
	"glow_intensity": 0.35,
	"glow_strength": 0.75,
	"glow_bloom": 0.08,
	"glow_hdr_threshold": 0.85,
	"glow_mix": 0.2,

	"adjustment_enabled": true,
	"adjustment_brightness": 0.98,
	"adjustment_contrast": 1.18,
	"adjustment_saturation": 1.1,

	"tonemap_mode": Environment.TONE_MAPPER_ACES,
	"tonemap_exposure": 0.95,

	"ssao_enabled": true,
	"ssao_radius": 0.7,
	"ssao_intensity": 1.3,

	"vignette_intensity": 0.2,
	"vignette_color": Color(0.0, 0.0, 0.05, 1.0),  # Cool tint

	"fog_enabled": true,
	"fog_density": 0.002,
}

## Flag Wars - Team-based tactical with balanced visibility
const PROFILE_FLAG_WARS: Dictionary = {
	"glow_enabled": true,
	"glow_intensity": 0.4,
	"glow_strength": 0.8,
	"glow_bloom": 0.12,
	"glow_hdr_threshold": 0.78,
	"glow_mix": 0.22,

	"adjustment_enabled": true,
	"adjustment_brightness": 1.02,
	"adjustment_contrast": 1.08,
	"adjustment_saturation": 1.18,

	"tonemap_mode": Environment.TONE_MAPPER_ACES,
	"tonemap_exposure": 1.0,

	"ssao_enabled": true,
	"ssao_radius": 0.5,
	"ssao_intensity": 1.0,

	"vignette_intensity": 0.12,
	"vignette_color": Color(0.0, 0.0, 0.0, 1.0),
}

## Crash Derby - Destructive chaos with warm explosive tones
const PROFILE_CRASH_DERBY: Dictionary = {
	"glow_enabled": true,
	"glow_intensity": 0.55,
	"glow_strength": 1.0,
	"glow_bloom": 0.25,
	"glow_hdr_threshold": 0.65,
	"glow_mix": 0.35,

	"adjustment_enabled": true,
	"adjustment_brightness": 1.0,
	"adjustment_contrast": 1.2,
	"adjustment_saturation": 1.3,

	"tonemap_mode": Environment.TONE_MAPPER_ACES,
	"tonemap_exposure": 1.08,

	"vignette_intensity": 0.18,
	"vignette_color": Color(0.08, 0.02, 0.0, 1.0),  # Warm/orange tint

	"chromatic_aberration_enabled": true,
	"chromatic_aberration_intensity": 0.004,

	"motion_blur_enabled": true,
	"motion_blur_intensity": 0.2,
}

## Menu - Clean and inviting
const PROFILE_MENU: Dictionary = {
	"glow_enabled": true,
	"glow_intensity": 0.3,
	"glow_strength": 0.7,
	"glow_bloom": 0.05,
	"glow_hdr_threshold": 0.9,
	"glow_mix": 0.15,

	"adjustment_enabled": true,
	"adjustment_brightness": 1.05,
	"adjustment_contrast": 1.05,
	"adjustment_saturation": 1.1,

	"tonemap_mode": Environment.TONE_MAPPER_ACES,
	"tonemap_exposure": 1.0,

	"vignette_intensity": 0.08,
	"vignette_color": Color(0.0, 0.0, 0.0, 1.0),

	"ssao_enabled": false,
	"fog_enabled": false,
}

## Cinematic - For victory screens and replays
const PROFILE_CINEMATIC: Dictionary = {
	"glow_enabled": true,
	"glow_intensity": 0.6,
	"glow_strength": 1.0,
	"glow_bloom": 0.3,
	"glow_hdr_threshold": 0.6,
	"glow_mix": 0.4,

	"adjustment_enabled": true,
	"adjustment_brightness": 0.98,
	"adjustment_contrast": 1.25,
	"adjustment_saturation": 1.0,  # Slightly desaturated for cinematic look

	"tonemap_mode": Environment.TONE_MAPPER_ACES,
	"tonemap_exposure": 0.95,

	"ssao_enabled": true,
	"ssao_radius": 0.8,
	"ssao_intensity": 1.5,

	"vignette_intensity": 0.25,
	"vignette_color": Color(0.0, 0.0, 0.0, 1.0),

	"dof_blur_far_enabled": true,
	"dof_blur_far_distance": 15.0,
	"dof_blur_far_transition": 8.0,

	"chromatic_aberration_enabled": true,
	"chromatic_aberration_intensity": 0.003,
}

# endregion


# region -- Profile Lookup

## Maps game IDs to their profiles
const GAME_PROFILES: Dictionary = {
	"arena_blaster": PROFILE_ARENA_BLASTER,
	"turbo_karts": PROFILE_TURBO_KARTS,
	"obstacle_royale": PROFILE_OBSTACLE_ROYALE,
	"flag_wars": PROFILE_FLAG_WARS,
	"crash_derby": PROFILE_CRASH_DERBY,
	"menu": PROFILE_MENU,
	"cinematic": PROFILE_CINEMATIC,
	"default": PROFILE_DEFAULT,
}


## Returns the profile dictionary for a given game ID
static func get_profile(game_id: String) -> Dictionary:
	if GAME_PROFILES.has(game_id):
		return GAME_PROFILES[game_id].duplicate()
	return PROFILE_DEFAULT.duplicate()


## Returns all available profile names
static func get_available_profiles() -> Array[String]:
	var profiles: Array[String] = []
	for key: String in GAME_PROFILES.keys():
		profiles.append(key)
	return profiles

# endregion


# region -- Effect Modifiers

## Returns a modified profile for low health effect (red vignette, desaturated)
static func get_low_health_modifier(health_percent: float) -> Dictionary:
	var intensity: float = clampf(1.0 - health_percent, 0.0, 1.0)
	var pulse_intensity: float = intensity * (0.8 + 0.2 * sin(Time.get_ticks_msec() / 200.0))

	return {
		"vignette_intensity": 0.15 + (0.35 * pulse_intensity),
		"vignette_color": Color(0.5, 0.0, 0.0, 1.0),  # Red tint
		"adjustment_saturation": 1.0 - (0.3 * intensity),
		"chromatic_aberration_enabled": intensity > 0.5,
		"chromatic_aberration_intensity": 0.005 * intensity,
	}


## Returns a modified profile for hit effect (screen flash)
static func get_hit_effect_modifier(intensity: float = 1.0) -> Dictionary:
	return {
		"adjustment_brightness": 1.0 + (0.3 * intensity),
		"vignette_intensity": 0.4 * intensity,
		"vignette_color": Color(0.8, 0.2, 0.0, 1.0),  # Orange-red flash
		"chromatic_aberration_enabled": true,
		"chromatic_aberration_intensity": 0.008 * intensity,
	}


## Returns a modified profile for speed boost effect
static func get_speed_boost_modifier(intensity: float = 1.0) -> Dictionary:
	return {
		"motion_blur_enabled": true,
		"motion_blur_intensity": 0.4 * intensity,
		"chromatic_aberration_enabled": true,
		"chromatic_aberration_intensity": 0.004 * intensity,
		"vignette_intensity": 0.1 * intensity,
		"vignette_color": Color(0.0, 0.3, 0.8, 1.0),  # Blue tint
		"glow_intensity": 0.5 + (0.2 * intensity),
	}


## Returns a modified profile for victory/celebration effect
static func get_victory_modifier() -> Dictionary:
	return {
		"glow_enabled": true,
		"glow_intensity": 0.7,
		"glow_bloom": 0.4,
		"adjustment_brightness": 1.1,
		"adjustment_saturation": 1.3,
		"vignette_intensity": 0.0,
		"chromatic_aberration_enabled": true,
		"chromatic_aberration_intensity": 0.002,
	}


## Returns a modified profile for death/elimination effect
static func get_death_modifier() -> Dictionary:
	return {
		"adjustment_saturation": 0.3,  # Heavy desaturation
		"adjustment_brightness": 0.8,
		"adjustment_contrast": 0.9,
		"vignette_intensity": 0.5,
		"vignette_color": Color(0.0, 0.0, 0.0, 1.0),
		"glow_intensity": 0.2,
	}


## Returns a modified profile for slow-motion effect
static func get_slow_motion_modifier() -> Dictionary:
	return {
		"adjustment_saturation": 0.85,
		"adjustment_contrast": 1.3,
		"vignette_intensity": 0.2,
		"chromatic_aberration_enabled": true,
		"chromatic_aberration_intensity": 0.006,
		"glow_intensity": 0.55,
		"glow_bloom": 0.2,
	}


## Returns a modified profile for underwater effect
static func get_underwater_modifier() -> Dictionary:
	return {
		"adjustment_saturation": 0.7,
		"vignette_intensity": 0.3,
		"vignette_color": Color(0.0, 0.1, 0.3, 1.0),  # Blue tint
		"fog_enabled": true,
		"fog_density": 0.01,
		"chromatic_aberration_enabled": true,
		"chromatic_aberration_intensity": 0.004,
		"lens_distortion_enabled": true,
		"lens_distortion_intensity": 0.03,
	}

# endregion


# region -- Quality Scaling

## Returns a quality-scaled version of a profile
## [param profile] The base profile to scale
## [param quality_level] 0 = Low, 1 = Medium, 2 = High, 3 = Ultra
static func get_quality_scaled_profile(profile: Dictionary, quality_level: int) -> Dictionary:
	var scaled: Dictionary = profile.duplicate()

	match quality_level:
		0:  # Low - Minimal effects for maximum performance
			scaled["glow_enabled"] = false
			scaled["ssao_enabled"] = false
			scaled["fog_enabled"] = false
			scaled["motion_blur_enabled"] = false
			scaled["chromatic_aberration_enabled"] = false
			scaled["dof_blur_far_enabled"] = false
			scaled["dof_blur_near_enabled"] = false
			scaled["lens_distortion_enabled"] = false
			scaled["vignette_intensity"] = 0.0

		1:  # Medium - Basic effects
			scaled["ssao_enabled"] = false
			scaled["fog_enabled"] = false
			scaled["motion_blur_enabled"] = false
			scaled["dof_blur_far_enabled"] = false
			scaled["dof_blur_near_enabled"] = false
			# Reduce glow
			if scaled.has("glow_intensity"):
				scaled["glow_intensity"] = (scaled["glow_intensity"] as float) * 0.7
			if scaled.has("glow_bloom"):
				scaled["glow_bloom"] = (scaled["glow_bloom"] as float) * 0.5
			# Reduce vignette
			if scaled.has("vignette_intensity"):
				scaled["vignette_intensity"] = (scaled["vignette_intensity"] as float) * 0.6

		2:  # High - Most effects enabled
			# Reduce SSAO quality
			if scaled.has("ssao_radius"):
				scaled["ssao_radius"] = (scaled["ssao_radius"] as float) * 0.7
			if scaled.has("ssao_intensity"):
				scaled["ssao_intensity"] = (scaled["ssao_intensity"] as float) * 0.8
			# Disable motion blur
			scaled["motion_blur_enabled"] = false
			# Disable DOF
			scaled["dof_blur_far_enabled"] = false
			scaled["dof_blur_near_enabled"] = false

		3:  # Ultra - All effects at full quality
			pass  # No changes needed

	return scaled

# endregion


# region -- Profile Blending

## Blends two profiles together with a given weight
## [param from_profile] The starting profile
## [param to_profile] The target profile
## [param weight] Blend weight (0.0 = from, 1.0 = to)
static func blend_profiles(from_profile: Dictionary, to_profile: Dictionary, weight: float) -> Dictionary:
	var result: Dictionary = {}
	weight = clampf(weight, 0.0, 1.0)

	# Get all keys from both profiles
	var all_keys: Array[String] = []
	for key: String in from_profile.keys():
		if key not in all_keys:
			all_keys.append(key)
	for key: String in to_profile.keys():
		if key not in all_keys:
			all_keys.append(key)

	for key: String in all_keys:
		var from_value: Variant = from_profile.get(key, null)
		var to_value: Variant = to_profile.get(key, null)

		# If only one profile has the key, use that value
		if from_value == null:
			result[key] = to_value
			continue
		if to_value == null:
			result[key] = from_value
			continue

		# Blend based on type
		if from_value is float and to_value is float:
			result[key] = lerpf(from_value as float, to_value as float, weight)
		elif from_value is Color and to_value is Color:
			result[key] = (from_value as Color).lerp(to_value as Color, weight)
		elif from_value is bool and to_value is bool:
			# For booleans, use the target value if weight > 0.5
			result[key] = to_value if weight > 0.5 else from_value
		elif from_value is int and to_value is int:
			result[key] = roundi(lerpf(float(from_value as int), float(to_value as int), weight))
		else:
			# For other types, use the target value if weight > 0.5
			result[key] = to_value if weight > 0.5 else from_value

	return result


## Merges a modifier on top of a base profile
## [param base_profile] The base profile
## [param modifier] The modifier dictionary to apply
static func apply_modifier(base_profile: Dictionary, modifier: Dictionary) -> Dictionary:
	var result: Dictionary = base_profile.duplicate()
	for key: String in modifier.keys():
		result[key] = modifier[key]
	return result

# endregion
