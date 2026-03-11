## ParticleLibrary - EXTENSIVE VFX particle system with 50+ spectacular effect presets.
##
## This is the definitive particle effects library for BattleZone Party featuring:
##
## EXPLOSIONS (12 types):
##   - Basic, Fiery, Nuclear, Plasma, Shockwave, Debris, Sparkle, Smoke burst
##   - Electric, Ice shatter, Poison cloud, Holy light
##
## MAGIC EFFECTS (10 types):
##   - Sparkles, Energy orb, Magic circle, Arcane burst, Healing aura
##   - Frost nova, Fire vortex, Lightning strike, Shadow burst, Divine light
##
## WEATHER (8 types):
##   - Rain, Snow, Leaves (autumn), Petals (cherry blossom), Dust storm
##   - Fireflies, Embers, Ash fall
##
## FIRE & SMOKE (8 types):
##   - Campfire, Inferno, Torch, Smoke plume, Steam, Mist, Fog, Volcanic
##
## ELECTRICITY (6 types):
##   - Spark, Lightning bolt, Electric arc, Tesla coil, Static, EMP pulse
##
## WATER (6 types):
##   - Splash, Ripple, Fountain, Waterfall mist, Bubble, Underwater caustics
##
## IMPACT (8 types):
##   - Dust poof, Metal spark, Wood splinter, Blood splatter, Energy hit
##   - Ground crack, Glass shatter, Force push
##
## TRAIL EFFECTS (8 types):
##   - Speed lines, Motion blur trail, Fire trail, Ice trail, Magic trail
##   - Rainbow trail, Ghost trail, Pixel trail
##
## Usage:
##   ParticleLibrary.spawn("nuclear_explosion", global_position)
##   ParticleLibrary.spawn_3d("fire_vortex", world_position, {scale = 2.0})
##   ParticleLibrary.spawn_continuous("campfire", position, duration)
##
class_name ParticleLibrary
extends Node


# region - Signals

## Emitted when a particle effect spawns
signal effect_spawned(effect_name: String, position: Variant)

## Emitted when a particle effect completes
signal effect_completed(effect_name: String)

## Emitted when particle budget is exceeded
signal budget_warning(active_count: int, max_count: int)

# endregion


# region - Enums

## Particle effect categories
enum Category {
	EXPLOSION,
	MAGIC,
	WEATHER,
	FIRE_SMOKE,
	ELECTRICITY,
	WATER,
	IMPACT,
	TRAIL,
	UI,
	CELEBRATION,
}

## Quality presets
enum Quality {
	LOW,      ## Mobile/low-end
	MEDIUM,   ## Standard
	HIGH,     ## High-end
	ULTRA,    ## Maximum quality
}

# endregion


# region - Constants

## Maximum simultaneous particle systems
const MAX_ACTIVE_PARTICLES: int = 500
const MAX_PARTICLES_PER_SYSTEM: int = 10000

## Quality multipliers for particle counts
const QUALITY_MULTIPLIERS: Dictionary = {
	Quality.LOW: 0.25,
	Quality.MEDIUM: 0.5,
	Quality.HIGH: 1.0,
	Quality.ULTRA: 1.5,
}

## Color palettes for various effects
const COLOR_PALETTES: Dictionary = {
	"fire": [Color(1.0, 0.9, 0.2), Color(1.0, 0.5, 0.0), Color(0.8, 0.2, 0.0), Color(0.3, 0.1, 0.0)],
	"ice": [Color(0.9, 0.95, 1.0), Color(0.5, 0.8, 1.0), Color(0.2, 0.5, 0.9), Color(0.1, 0.2, 0.5)],
	"electric": [Color(1.0, 1.0, 1.0), Color(0.7, 0.9, 1.0), Color(0.3, 0.6, 1.0), Color(0.1, 0.2, 0.8)],
	"poison": [Color(0.4, 1.0, 0.3), Color(0.2, 0.8, 0.1), Color(0.1, 0.5, 0.0), Color(0.05, 0.2, 0.0)],
	"holy": [Color(1.0, 1.0, 0.9), Color(1.0, 0.95, 0.7), Color(1.0, 0.9, 0.5), Color(0.9, 0.8, 0.3)],
	"shadow": [Color(0.3, 0.0, 0.4), Color(0.2, 0.0, 0.3), Color(0.1, 0.0, 0.2), Color(0.0, 0.0, 0.1)],
	"plasma": [Color(1.0, 0.3, 1.0), Color(0.8, 0.2, 1.0), Color(0.5, 0.1, 0.8), Color(0.2, 0.0, 0.4)],
	"rainbow": [Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.PURPLE],
	"gold": [Color(1.0, 0.84, 0.0), Color(1.0, 0.75, 0.0), Color(0.85, 0.65, 0.12), Color(0.72, 0.53, 0.04)],
	"blood": [Color(0.8, 0.0, 0.0), Color(0.6, 0.0, 0.0), Color(0.4, 0.0, 0.0), Color(0.2, 0.0, 0.0)],
}

# endregion


# region - Effect Presets Database

## Complete effect definitions with all parameters
const EFFECT_PRESETS: Dictionary = {
	# ===== EXPLOSIONS (12 types) =====
	"basic_explosion": {
		"category": Category.EXPLOSION,
		"particle_count": 50,
		"lifetime": 0.6,
		"explosiveness": 1.0,
		"emission_shape": "sphere",
		"emission_radius": 0.5,
		"direction": Vector3(0, 1, 0),
		"spread": 180.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 15.0,
		"gravity": Vector3(0, -5, 0),
		"scale_min": 0.2,
		"scale_max": 0.8,
		"color_palette": "fire",
		"glow": true,
		"light_color": Color(1.0, 0.6, 0.2),
		"light_energy": 3.0,
	},
	"fiery_explosion": {
		"category": Category.EXPLOSION,
		"particle_count": 80,
		"lifetime": 0.8,
		"explosiveness": 1.0,
		"emission_shape": "sphere",
		"emission_radius": 0.8,
		"direction": Vector3(0, 1, 0),
		"spread": 180.0,
		"initial_velocity_min": 8.0,
		"initial_velocity_max": 20.0,
		"gravity": Vector3(0, -3, 0),
		"scale_min": 0.3,
		"scale_max": 1.2,
		"color_palette": "fire",
		"glow": true,
		"light_color": Color(1.0, 0.4, 0.0),
		"light_energy": 5.0,
		"secondary_effect": "smoke_burst",
	},
	"nuclear_explosion": {
		"category": Category.EXPLOSION,
		"particle_count": 200,
		"lifetime": 2.0,
		"explosiveness": 0.8,
		"emission_shape": "sphere",
		"emission_radius": 2.0,
		"direction": Vector3(0, 1, 0),
		"spread": 180.0,
		"initial_velocity_min": 15.0,
		"initial_velocity_max": 40.0,
		"gravity": Vector3(0, 2, 0),
		"scale_min": 0.5,
		"scale_max": 3.0,
		"color_palette": "fire",
		"glow": true,
		"light_color": Color(1.0, 0.9, 0.5),
		"light_energy": 10.0,
		"screen_shake": 2.0,
		"secondary_effect": "shockwave",
	},
	"plasma_explosion": {
		"category": Category.EXPLOSION,
		"particle_count": 100,
		"lifetime": 0.7,
		"explosiveness": 1.0,
		"emission_shape": "sphere",
		"emission_radius": 0.6,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 10.0,
		"initial_velocity_max": 25.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.1,
		"scale_max": 0.5,
		"color_palette": "plasma",
		"glow": true,
		"light_color": Color(0.8, 0.2, 1.0),
		"light_energy": 4.0,
	},
	"shockwave": {
		"category": Category.EXPLOSION,
		"particle_count": 60,
		"lifetime": 0.5,
		"explosiveness": 1.0,
		"emission_shape": "ring",
		"emission_radius": 0.5,
		"direction": Vector3(0, 0, 0),
		"spread": 10.0,
		"initial_velocity_min": 20.0,
		"initial_velocity_max": 30.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.1,
		"scale_max": 0.3,
		"color_start": Color(1.0, 1.0, 1.0, 0.8),
		"color_end": Color(0.8, 0.9, 1.0, 0.0),
	},
	"debris_explosion": {
		"category": Category.EXPLOSION,
		"particle_count": 40,
		"lifetime": 1.5,
		"explosiveness": 0.9,
		"emission_shape": "sphere",
		"emission_radius": 0.3,
		"direction": Vector3(0, 1, 0),
		"spread": 120.0,
		"initial_velocity_min": 8.0,
		"initial_velocity_max": 18.0,
		"gravity": Vector3(0, -15, 0),
		"scale_min": 0.1,
		"scale_max": 0.4,
		"color_start": Color(0.4, 0.35, 0.3),
		"color_end": Color(0.3, 0.25, 0.2),
		"angular_velocity": true,
	},
	"sparkle_explosion": {
		"category": Category.EXPLOSION,
		"particle_count": 100,
		"lifetime": 1.0,
		"explosiveness": 1.0,
		"emission_shape": "sphere",
		"emission_radius": 0.2,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 15.0,
		"gravity": Vector3(0, -2, 0),
		"scale_min": 0.05,
		"scale_max": 0.2,
		"color_palette": "gold",
		"glow": true,
		"twinkle": true,
	},
	"smoke_burst": {
		"category": Category.EXPLOSION,
		"particle_count": 30,
		"lifetime": 2.0,
		"explosiveness": 0.6,
		"emission_shape": "sphere",
		"emission_radius": 0.5,
		"direction": Vector3(0, 1, 0),
		"spread": 60.0,
		"initial_velocity_min": 2.0,
		"initial_velocity_max": 5.0,
		"gravity": Vector3(0, 1, 0),
		"scale_min": 0.5,
		"scale_max": 2.0,
		"color_start": Color(0.4, 0.4, 0.4, 0.6),
		"color_end": Color(0.2, 0.2, 0.2, 0.0),
	},
	"electric_explosion": {
		"category": Category.EXPLOSION,
		"particle_count": 80,
		"lifetime": 0.4,
		"explosiveness": 1.0,
		"emission_shape": "sphere",
		"emission_radius": 0.4,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 15.0,
		"initial_velocity_max": 35.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.02,
		"scale_max": 0.1,
		"color_palette": "electric",
		"glow": true,
		"light_color": Color(0.5, 0.7, 1.0),
		"light_energy": 4.0,
		"branching": true,
	},
	"ice_shatter": {
		"category": Category.EXPLOSION,
		"particle_count": 60,
		"lifetime": 1.2,
		"explosiveness": 1.0,
		"emission_shape": "sphere",
		"emission_radius": 0.4,
		"direction": Vector3(0, 1, 0),
		"spread": 150.0,
		"initial_velocity_min": 6.0,
		"initial_velocity_max": 14.0,
		"gravity": Vector3(0, -12, 0),
		"scale_min": 0.05,
		"scale_max": 0.25,
		"color_palette": "ice",
		"glow": true,
		"angular_velocity": true,
	},
	"poison_cloud": {
		"category": Category.EXPLOSION,
		"particle_count": 50,
		"lifetime": 3.0,
		"explosiveness": 0.3,
		"emission_shape": "sphere",
		"emission_radius": 1.0,
		"direction": Vector3(0, 0.5, 0),
		"spread": 90.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, 0.5, 0),
		"scale_min": 0.5,
		"scale_max": 2.0,
		"color_palette": "poison",
		"glow": true,
	},
	"holy_explosion": {
		"category": Category.EXPLOSION,
		"particle_count": 80,
		"lifetime": 1.0,
		"explosiveness": 0.9,
		"emission_shape": "sphere",
		"emission_radius": 0.5,
		"direction": Vector3(0, 1, 0),
		"spread": 180.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 12.0,
		"gravity": Vector3(0, 2, 0),
		"scale_min": 0.1,
		"scale_max": 0.5,
		"color_palette": "holy",
		"glow": true,
		"light_color": Color(1.0, 0.95, 0.8),
		"light_energy": 5.0,
		"rays": true,
	},

	# ===== MAGIC EFFECTS (10 types) =====
	"magic_sparkles": {
		"category": Category.MAGIC,
		"particle_count": 40,
		"lifetime": 1.5,
		"explosiveness": 0.2,
		"emission_shape": "sphere",
		"emission_radius": 0.5,
		"direction": Vector3(0, 1, 0),
		"spread": 180.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, 0.5, 0),
		"scale_min": 0.02,
		"scale_max": 0.1,
		"color_palette": "gold",
		"glow": true,
		"twinkle": true,
	},
	"energy_orb": {
		"category": Category.MAGIC,
		"particle_count": 60,
		"lifetime": 0.8,
		"explosiveness": 0.0,
		"emission_shape": "sphere",
		"emission_radius": 0.3,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 0.5,
		"initial_velocity_max": 2.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.03,
		"scale_max": 0.1,
		"color_palette": "plasma",
		"glow": true,
		"orbit": true,
	},
	"magic_circle": {
		"category": Category.MAGIC,
		"particle_count": 80,
		"lifetime": 2.0,
		"explosiveness": 0.0,
		"emission_shape": "ring",
		"emission_radius": 1.5,
		"direction": Vector3(0, 0.1, 0),
		"spread": 5.0,
		"initial_velocity_min": 0.2,
		"initial_velocity_max": 0.5,
		"gravity": Vector3.ZERO,
		"scale_min": 0.02,
		"scale_max": 0.08,
		"color_palette": "plasma",
		"glow": true,
		"orbit": true,
	},
	"arcane_burst": {
		"category": Category.MAGIC,
		"particle_count": 100,
		"lifetime": 0.6,
		"explosiveness": 1.0,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 10.0,
		"initial_velocity_max": 20.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.05,
		"scale_max": 0.2,
		"color_palette": "plasma",
		"glow": true,
		"light_color": Color(0.6, 0.2, 1.0),
		"light_energy": 3.0,
	},
	"healing_aura": {
		"category": Category.MAGIC,
		"particle_count": 30,
		"lifetime": 1.5,
		"explosiveness": 0.0,
		"emission_shape": "sphere",
		"emission_radius": 0.8,
		"direction": Vector3(0, 1, 0),
		"spread": 30.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 2.5,
		"gravity": Vector3(0, 1, 0),
		"scale_min": 0.05,
		"scale_max": 0.15,
		"color_start": Color(0.3, 1.0, 0.4, 0.8),
		"color_end": Color(0.5, 1.0, 0.6, 0.0),
		"glow": true,
	},
	"frost_nova": {
		"category": Category.MAGIC,
		"particle_count": 80,
		"lifetime": 0.8,
		"explosiveness": 1.0,
		"emission_shape": "ring",
		"emission_radius": 0.3,
		"direction": Vector3(0, 0, 0),
		"spread": 30.0,
		"initial_velocity_min": 15.0,
		"initial_velocity_max": 25.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.05,
		"scale_max": 0.2,
		"color_palette": "ice",
		"glow": true,
		"light_color": Color(0.5, 0.8, 1.0),
		"light_energy": 3.0,
	},
	"fire_vortex": {
		"category": Category.MAGIC,
		"particle_count": 100,
		"lifetime": 1.5,
		"explosiveness": 0.0,
		"emission_shape": "ring",
		"emission_radius": 0.8,
		"direction": Vector3(0, 1, 0),
		"spread": 15.0,
		"initial_velocity_min": 3.0,
		"initial_velocity_max": 6.0,
		"gravity": Vector3(0, 5, 0),
		"scale_min": 0.1,
		"scale_max": 0.4,
		"color_palette": "fire",
		"glow": true,
		"vortex": true,
	},
	"lightning_strike": {
		"category": Category.MAGIC,
		"particle_count": 50,
		"lifetime": 0.3,
		"explosiveness": 1.0,
		"emission_shape": "box",
		"emission_extents": Vector3(0.1, 5.0, 0.1),
		"direction": Vector3(0, -1, 0),
		"spread": 10.0,
		"initial_velocity_min": 30.0,
		"initial_velocity_max": 50.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.02,
		"scale_max": 0.1,
		"color_palette": "electric",
		"glow": true,
		"light_color": Color(0.7, 0.8, 1.0),
		"light_energy": 8.0,
		"branching": true,
	},
	"shadow_burst": {
		"category": Category.MAGIC,
		"particle_count": 60,
		"lifetime": 1.0,
		"explosiveness": 0.8,
		"emission_shape": "sphere",
		"emission_radius": 0.5,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 12.0,
		"gravity": Vector3(0, -1, 0),
		"scale_min": 0.1,
		"scale_max": 0.5,
		"color_palette": "shadow",
		"glow": false,
	},
	"divine_light": {
		"category": Category.MAGIC,
		"particle_count": 50,
		"lifetime": 2.0,
		"explosiveness": 0.1,
		"emission_shape": "box",
		"emission_extents": Vector3(0.5, 0.1, 0.5),
		"direction": Vector3(0, -1, 0),
		"spread": 5.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 10.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.02,
		"scale_max": 0.08,
		"color_palette": "holy",
		"glow": true,
		"rays": true,
	},

	# ===== WEATHER (8 types) =====
	"rain": {
		"category": Category.WEATHER,
		"particle_count": 500,
		"lifetime": 1.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(20.0, 0.5, 20.0),
		"direction": Vector3(0, -1, 0),
		"spread": 5.0,
		"initial_velocity_min": 15.0,
		"initial_velocity_max": 20.0,
		"gravity": Vector3(0, -30, 0),
		"scale_min": 0.01,
		"scale_max": 0.02,
		"color_start": Color(0.6, 0.7, 0.9, 0.6),
		"color_end": Color(0.5, 0.6, 0.8, 0.3),
		"continuous": true,
	},
	"snow": {
		"category": Category.WEATHER,
		"particle_count": 300,
		"lifetime": 4.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(20.0, 0.5, 20.0),
		"direction": Vector3(0, -1, 0),
		"spread": 20.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, -2, 0),
		"scale_min": 0.02,
		"scale_max": 0.05,
		"color_start": Color(0.95, 0.95, 1.0, 0.9),
		"color_end": Color(0.9, 0.9, 0.95, 0.5),
		"continuous": true,
		"turbulence": true,
	},
	"autumn_leaves": {
		"category": Category.WEATHER,
		"particle_count": 50,
		"lifetime": 5.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(15.0, 0.5, 15.0),
		"direction": Vector3(0.3, -1, 0.2),
		"spread": 30.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, -1, 0),
		"scale_min": 0.05,
		"scale_max": 0.15,
		"color_options": [Color(0.9, 0.4, 0.1), Color(0.8, 0.6, 0.1), Color(0.7, 0.3, 0.0), Color(0.6, 0.2, 0.0)],
		"continuous": true,
		"angular_velocity": true,
		"turbulence": true,
	},
	"cherry_petals": {
		"category": Category.WEATHER,
		"particle_count": 80,
		"lifetime": 6.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(15.0, 0.5, 15.0),
		"direction": Vector3(0.2, -1, 0.1),
		"spread": 25.0,
		"initial_velocity_min": 0.5,
		"initial_velocity_max": 2.0,
		"gravity": Vector3(0, -0.5, 0),
		"scale_min": 0.03,
		"scale_max": 0.08,
		"color_start": Color(1.0, 0.7, 0.8, 0.9),
		"color_end": Color(1.0, 0.8, 0.85, 0.5),
		"continuous": true,
		"angular_velocity": true,
		"turbulence": true,
	},
	"dust_storm": {
		"category": Category.WEATHER,
		"particle_count": 400,
		"lifetime": 2.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(20.0, 5.0, 20.0),
		"direction": Vector3(1, 0, 0.3),
		"spread": 30.0,
		"initial_velocity_min": 8.0,
		"initial_velocity_max": 15.0,
		"gravity": Vector3(0, -1, 0),
		"scale_min": 0.02,
		"scale_max": 0.08,
		"color_start": Color(0.8, 0.7, 0.5, 0.5),
		"color_end": Color(0.6, 0.5, 0.4, 0.2),
		"continuous": true,
		"turbulence": true,
	},
	"fireflies": {
		"category": Category.WEATHER,
		"particle_count": 30,
		"lifetime": 3.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(10.0, 3.0, 10.0),
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 0.2,
		"initial_velocity_max": 0.8,
		"gravity": Vector3.ZERO,
		"scale_min": 0.02,
		"scale_max": 0.05,
		"color_start": Color(0.8, 1.0, 0.3, 1.0),
		"color_end": Color(0.6, 0.8, 0.2, 0.0),
		"continuous": true,
		"glow": true,
		"twinkle": true,
	},
	"embers": {
		"category": Category.WEATHER,
		"particle_count": 50,
		"lifetime": 4.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(5.0, 0.5, 5.0),
		"direction": Vector3(0.1, 1, 0.1),
		"spread": 20.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, 2, 0),
		"scale_min": 0.01,
		"scale_max": 0.04,
		"color_palette": "fire",
		"continuous": true,
		"glow": true,
		"twinkle": true,
	},
	"ash_fall": {
		"category": Category.WEATHER,
		"particle_count": 100,
		"lifetime": 5.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(15.0, 0.5, 15.0),
		"direction": Vector3(0, -1, 0),
		"spread": 15.0,
		"initial_velocity_min": 0.5,
		"initial_velocity_max": 1.5,
		"gravity": Vector3(0, -0.5, 0),
		"scale_min": 0.01,
		"scale_max": 0.04,
		"color_start": Color(0.3, 0.3, 0.3, 0.7),
		"color_end": Color(0.2, 0.2, 0.2, 0.3),
		"continuous": true,
		"turbulence": true,
	},

	# ===== FIRE & SMOKE (8 types) =====
	"campfire": {
		"category": Category.FIRE_SMOKE,
		"particle_count": 40,
		"lifetime": 1.0,
		"explosiveness": 0.0,
		"emission_shape": "sphere",
		"emission_radius": 0.3,
		"direction": Vector3(0, 1, 0),
		"spread": 15.0,
		"initial_velocity_min": 2.0,
		"initial_velocity_max": 4.0,
		"gravity": Vector3(0, 3, 0),
		"scale_min": 0.1,
		"scale_max": 0.4,
		"color_palette": "fire",
		"continuous": true,
		"glow": true,
		"light_color": Color(1.0, 0.6, 0.2),
		"light_energy": 2.0,
	},
	"inferno": {
		"category": Category.FIRE_SMOKE,
		"particle_count": 150,
		"lifetime": 1.2,
		"explosiveness": 0.0,
		"emission_shape": "sphere",
		"emission_radius": 1.5,
		"direction": Vector3(0, 1, 0),
		"spread": 20.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 12.0,
		"gravity": Vector3(0, 8, 0),
		"scale_min": 0.2,
		"scale_max": 1.0,
		"color_palette": "fire",
		"continuous": true,
		"glow": true,
		"light_color": Color(1.0, 0.5, 0.1),
		"light_energy": 5.0,
	},
	"torch": {
		"category": Category.FIRE_SMOKE,
		"particle_count": 25,
		"lifetime": 0.6,
		"explosiveness": 0.0,
		"emission_shape": "sphere",
		"emission_radius": 0.1,
		"direction": Vector3(0, 1, 0),
		"spread": 12.0,
		"initial_velocity_min": 1.5,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, 4, 0),
		"scale_min": 0.05,
		"scale_max": 0.2,
		"color_palette": "fire",
		"continuous": true,
		"glow": true,
		"light_color": Color(1.0, 0.7, 0.3),
		"light_energy": 1.5,
	},
	"smoke_plume": {
		"category": Category.FIRE_SMOKE,
		"particle_count": 30,
		"lifetime": 3.0,
		"explosiveness": 0.0,
		"emission_shape": "sphere",
		"emission_radius": 0.3,
		"direction": Vector3(0, 1, 0),
		"spread": 25.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 2.5,
		"gravity": Vector3(0, 2, 0),
		"scale_min": 0.3,
		"scale_max": 1.5,
		"color_start": Color(0.35, 0.35, 0.35, 0.5),
		"color_end": Color(0.15, 0.15, 0.15, 0.0),
		"continuous": true,
	},
	"steam": {
		"category": Category.FIRE_SMOKE,
		"particle_count": 25,
		"lifetime": 2.0,
		"explosiveness": 0.0,
		"emission_shape": "sphere",
		"emission_radius": 0.2,
		"direction": Vector3(0, 1, 0),
		"spread": 20.0,
		"initial_velocity_min": 1.5,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, 3, 0),
		"scale_min": 0.2,
		"scale_max": 0.8,
		"color_start": Color(0.9, 0.9, 0.95, 0.4),
		"color_end": Color(1.0, 1.0, 1.0, 0.0),
		"continuous": true,
	},
	"mist": {
		"category": Category.FIRE_SMOKE,
		"particle_count": 40,
		"lifetime": 4.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(5.0, 0.5, 5.0),
		"direction": Vector3(0.1, 0.2, 0.1),
		"spread": 60.0,
		"initial_velocity_min": 0.2,
		"initial_velocity_max": 0.8,
		"gravity": Vector3(0, 0.2, 0),
		"scale_min": 1.0,
		"scale_max": 3.0,
		"color_start": Color(0.85, 0.85, 0.9, 0.3),
		"color_end": Color(0.9, 0.9, 0.95, 0.0),
		"continuous": true,
	},
	"fog_rolling": {
		"category": Category.FIRE_SMOKE,
		"particle_count": 50,
		"lifetime": 6.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(10.0, 0.3, 10.0),
		"direction": Vector3(0.3, 0, 0.1),
		"spread": 30.0,
		"initial_velocity_min": 0.5,
		"initial_velocity_max": 1.5,
		"gravity": Vector3.ZERO,
		"scale_min": 2.0,
		"scale_max": 5.0,
		"color_start": Color(0.7, 0.7, 0.75, 0.25),
		"color_end": Color(0.8, 0.8, 0.85, 0.0),
		"continuous": true,
	},
	"volcanic_smoke": {
		"category": Category.FIRE_SMOKE,
		"particle_count": 80,
		"lifetime": 4.0,
		"explosiveness": 0.1,
		"emission_shape": "sphere",
		"emission_radius": 1.0,
		"direction": Vector3(0, 1, 0),
		"spread": 30.0,
		"initial_velocity_min": 3.0,
		"initial_velocity_max": 8.0,
		"gravity": Vector3(0, 3, 0),
		"scale_min": 0.5,
		"scale_max": 3.0,
		"color_start": Color(0.25, 0.2, 0.2, 0.6),
		"color_end": Color(0.1, 0.08, 0.08, 0.0),
		"continuous": true,
		"secondary_effect": "embers",
	},

	# ===== ELECTRICITY (6 types) =====
	"electric_spark": {
		"category": Category.ELECTRICITY,
		"particle_count": 20,
		"lifetime": 0.2,
		"explosiveness": 1.0,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 15.0,
		"gravity": Vector3(0, -5, 0),
		"scale_min": 0.01,
		"scale_max": 0.04,
		"color_palette": "electric",
		"glow": true,
	},
	"lightning_bolt": {
		"category": Category.ELECTRICITY,
		"particle_count": 100,
		"lifetime": 0.15,
		"explosiveness": 1.0,
		"emission_shape": "box",
		"emission_extents": Vector3(0.05, 8.0, 0.05),
		"direction": Vector3(0, -1, 0),
		"spread": 8.0,
		"initial_velocity_min": 50.0,
		"initial_velocity_max": 80.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.01,
		"scale_max": 0.05,
		"color_palette": "electric",
		"glow": true,
		"light_color": Color(0.8, 0.9, 1.0),
		"light_energy": 10.0,
		"branching": true,
	},
	"electric_arc": {
		"category": Category.ELECTRICITY,
		"particle_count": 30,
		"lifetime": 0.3,
		"explosiveness": 0.5,
		"emission_shape": "box",
		"emission_extents": Vector3(0.02, 0.02, 2.0),
		"direction": Vector3(0, 0, 1),
		"spread": 15.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 10.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.01,
		"scale_max": 0.03,
		"color_palette": "electric",
		"glow": true,
		"continuous": true,
	},
	"tesla_coil": {
		"category": Category.ELECTRICITY,
		"particle_count": 60,
		"lifetime": 0.4,
		"explosiveness": 0.8,
		"emission_shape": "sphere",
		"emission_radius": 0.2,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 8.0,
		"initial_velocity_max": 20.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.01,
		"scale_max": 0.04,
		"color_palette": "electric",
		"glow": true,
		"light_color": Color(0.6, 0.8, 1.0),
		"light_energy": 4.0,
		"branching": true,
		"continuous": true,
	},
	"static_discharge": {
		"category": Category.ELECTRICITY,
		"particle_count": 15,
		"lifetime": 0.1,
		"explosiveness": 1.0,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 10.0,
		"initial_velocity_max": 25.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.005,
		"scale_max": 0.02,
		"color_start": Color(1.0, 1.0, 1.0, 1.0),
		"color_end": Color(0.5, 0.7, 1.0, 0.0),
		"glow": true,
	},
	"emp_pulse": {
		"category": Category.ELECTRICITY,
		"particle_count": 80,
		"lifetime": 0.6,
		"explosiveness": 1.0,
		"emission_shape": "ring",
		"emission_radius": 0.5,
		"direction": Vector3(0, 0, 0),
		"spread": 10.0,
		"initial_velocity_min": 20.0,
		"initial_velocity_max": 35.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.02,
		"scale_max": 0.08,
		"color_palette": "electric",
		"glow": true,
		"light_color": Color(0.4, 0.6, 1.0),
		"light_energy": 5.0,
	},

	# ===== WATER (6 types) =====
	"water_splash": {
		"category": Category.WATER,
		"particle_count": 50,
		"lifetime": 0.8,
		"explosiveness": 1.0,
		"emission_shape": "point",
		"direction": Vector3(0, 1, 0),
		"spread": 120.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 12.0,
		"gravity": Vector3(0, -15, 0),
		"scale_min": 0.02,
		"scale_max": 0.08,
		"color_start": Color(0.6, 0.8, 1.0, 0.8),
		"color_end": Color(0.7, 0.85, 1.0, 0.0),
	},
	"water_ripple": {
		"category": Category.WATER,
		"particle_count": 30,
		"lifetime": 1.5,
		"explosiveness": 1.0,
		"emission_shape": "ring",
		"emission_radius": 0.1,
		"direction": Vector3(0, 0, 0),
		"spread": 5.0,
		"initial_velocity_min": 2.0,
		"initial_velocity_max": 5.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.01,
		"scale_max": 0.03,
		"color_start": Color(0.7, 0.85, 1.0, 0.6),
		"color_end": Color(0.8, 0.9, 1.0, 0.0),
	},
	"fountain": {
		"category": Category.WATER,
		"particle_count": 80,
		"lifetime": 2.0,
		"explosiveness": 0.0,
		"emission_shape": "sphere",
		"emission_radius": 0.1,
		"direction": Vector3(0, 1, 0),
		"spread": 15.0,
		"initial_velocity_min": 8.0,
		"initial_velocity_max": 12.0,
		"gravity": Vector3(0, -10, 0),
		"scale_min": 0.02,
		"scale_max": 0.06,
		"color_start": Color(0.5, 0.7, 1.0, 0.7),
		"color_end": Color(0.6, 0.8, 1.0, 0.3),
		"continuous": true,
	},
	"waterfall_mist": {
		"category": Category.WATER,
		"particle_count": 60,
		"lifetime": 2.5,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(2.0, 0.3, 0.5),
		"direction": Vector3(0, 0.5, 1),
		"spread": 40.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, 0.5, 0),
		"scale_min": 0.2,
		"scale_max": 0.8,
		"color_start": Color(0.85, 0.9, 1.0, 0.3),
		"color_end": Color(0.9, 0.95, 1.0, 0.0),
		"continuous": true,
	},
	"bubbles": {
		"category": Category.WATER,
		"particle_count": 30,
		"lifetime": 2.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(1.0, 0.2, 1.0),
		"direction": Vector3(0, 1, 0),
		"spread": 20.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 2.5,
		"gravity": Vector3(0, 2, 0),
		"scale_min": 0.02,
		"scale_max": 0.08,
		"color_start": Color(0.8, 0.9, 1.0, 0.5),
		"color_end": Color(0.9, 0.95, 1.0, 0.2),
		"continuous": true,
	},
	"underwater_caustics": {
		"category": Category.WATER,
		"particle_count": 40,
		"lifetime": 3.0,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(5.0, 0.1, 5.0),
		"direction": Vector3(0, -1, 0),
		"spread": 10.0,
		"initial_velocity_min": 0.5,
		"initial_velocity_max": 1.5,
		"gravity": Vector3.ZERO,
		"scale_min": 0.1,
		"scale_max": 0.5,
		"color_start": Color(0.5, 0.8, 1.0, 0.3),
		"color_end": Color(0.6, 0.85, 1.0, 0.0),
		"continuous": true,
	},

	# ===== IMPACT (8 types) =====
	"dust_poof": {
		"category": Category.IMPACT,
		"particle_count": 20,
		"lifetime": 0.6,
		"explosiveness": 1.0,
		"emission_shape": "point",
		"direction": Vector3(0, 1, 0),
		"spread": 150.0,
		"initial_velocity_min": 2.0,
		"initial_velocity_max": 5.0,
		"gravity": Vector3(0, 1, 0),
		"scale_min": 0.1,
		"scale_max": 0.4,
		"color_start": Color(0.6, 0.55, 0.5, 0.6),
		"color_end": Color(0.5, 0.45, 0.4, 0.0),
	},
	"metal_sparks": {
		"category": Category.IMPACT,
		"particle_count": 30,
		"lifetime": 0.4,
		"explosiveness": 1.0,
		"emission_shape": "point",
		"direction": Vector3(0, 1, 0),
		"spread": 120.0,
		"initial_velocity_min": 8.0,
		"initial_velocity_max": 18.0,
		"gravity": Vector3(0, -15, 0),
		"scale_min": 0.01,
		"scale_max": 0.04,
		"color_start": Color(1.0, 0.9, 0.5, 1.0),
		"color_end": Color(1.0, 0.5, 0.1, 0.0),
		"glow": true,
	},
	"wood_splinters": {
		"category": Category.IMPACT,
		"particle_count": 25,
		"lifetime": 0.8,
		"explosiveness": 1.0,
		"emission_shape": "point",
		"direction": Vector3(0, 1, 0),
		"spread": 130.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 12.0,
		"gravity": Vector3(0, -12, 0),
		"scale_min": 0.02,
		"scale_max": 0.08,
		"color_start": Color(0.6, 0.45, 0.25, 1.0),
		"color_end": Color(0.5, 0.35, 0.2, 0.5),
		"angular_velocity": true,
	},
	"blood_splatter": {
		"category": Category.IMPACT,
		"particle_count": 25,
		"lifetime": 0.5,
		"explosiveness": 1.0,
		"emission_shape": "point",
		"direction": Vector3(0, 1, 0),
		"spread": 140.0,
		"initial_velocity_min": 4.0,
		"initial_velocity_max": 10.0,
		"gravity": Vector3(0, -15, 0),
		"scale_min": 0.02,
		"scale_max": 0.1,
		"color_palette": "blood",
	},
	"energy_hit": {
		"category": Category.IMPACT,
		"particle_count": 40,
		"lifetime": 0.3,
		"explosiveness": 1.0,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 8.0,
		"initial_velocity_max": 16.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.02,
		"scale_max": 0.08,
		"color_palette": "plasma",
		"glow": true,
	},
	"ground_crack": {
		"category": Category.IMPACT,
		"particle_count": 35,
		"lifetime": 0.7,
		"explosiveness": 1.0,
		"emission_shape": "ring",
		"emission_radius": 0.3,
		"direction": Vector3(0, 1, 0),
		"spread": 60.0,
		"initial_velocity_min": 3.0,
		"initial_velocity_max": 8.0,
		"gravity": Vector3(0, -10, 0),
		"scale_min": 0.05,
		"scale_max": 0.2,
		"color_start": Color(0.45, 0.4, 0.35, 1.0),
		"color_end": Color(0.35, 0.3, 0.25, 0.5),
		"angular_velocity": true,
	},
	"glass_shatter": {
		"category": Category.IMPACT,
		"particle_count": 40,
		"lifetime": 1.0,
		"explosiveness": 1.0,
		"emission_shape": "sphere",
		"emission_radius": 0.2,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 12.0,
		"gravity": Vector3(0, -12, 0),
		"scale_min": 0.01,
		"scale_max": 0.06,
		"color_start": Color(0.9, 0.95, 1.0, 0.8),
		"color_end": Color(0.85, 0.9, 0.95, 0.3),
		"angular_velocity": true,
	},
	"force_push": {
		"category": Category.IMPACT,
		"particle_count": 50,
		"lifetime": 0.4,
		"explosiveness": 1.0,
		"emission_shape": "ring",
		"emission_radius": 0.2,
		"direction": Vector3(0, 0, 0),
		"spread": 15.0,
		"initial_velocity_min": 15.0,
		"initial_velocity_max": 25.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.03,
		"scale_max": 0.1,
		"color_start": Color(0.8, 0.9, 1.0, 0.7),
		"color_end": Color(0.9, 0.95, 1.0, 0.0),
	},

	# ===== TRAIL EFFECTS (8 types) =====
	"speed_lines": {
		"category": Category.TRAIL,
		"particle_count": 20,
		"lifetime": 0.2,
		"explosiveness": 0.0,
		"emission_shape": "box",
		"emission_extents": Vector3(0.1, 0.5, 0.1),
		"direction": Vector3(0, 0, -1),
		"spread": 5.0,
		"initial_velocity_min": 20.0,
		"initial_velocity_max": 30.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.005,
		"scale_max": 0.015,
		"color_start": Color(1.0, 1.0, 1.0, 0.5),
		"color_end": Color(1.0, 1.0, 1.0, 0.0),
		"continuous": true,
	},
	"motion_blur_trail": {
		"category": Category.TRAIL,
		"particle_count": 15,
		"lifetime": 0.15,
		"explosiveness": 0.0,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 0),
		"spread": 10.0,
		"initial_velocity_min": 0.5,
		"initial_velocity_max": 1.5,
		"gravity": Vector3.ZERO,
		"scale_min": 0.1,
		"scale_max": 0.3,
		"color_start": Color(0.8, 0.85, 1.0, 0.4),
		"color_end": Color(0.9, 0.92, 1.0, 0.0),
		"continuous": true,
	},
	"fire_trail": {
		"category": Category.TRAIL,
		"particle_count": 30,
		"lifetime": 0.5,
		"explosiveness": 0.0,
		"emission_shape": "point",
		"direction": Vector3(0, 1, 0),
		"spread": 20.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, 2, 0),
		"scale_min": 0.05,
		"scale_max": 0.2,
		"color_palette": "fire",
		"continuous": true,
		"glow": true,
	},
	"ice_trail": {
		"category": Category.TRAIL,
		"particle_count": 25,
		"lifetime": 0.8,
		"explosiveness": 0.0,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 0),
		"spread": 30.0,
		"initial_velocity_min": 0.5,
		"initial_velocity_max": 2.0,
		"gravity": Vector3(0, -1, 0),
		"scale_min": 0.02,
		"scale_max": 0.1,
		"color_palette": "ice",
		"continuous": true,
		"glow": true,
	},
	"magic_trail": {
		"category": Category.TRAIL,
		"particle_count": 30,
		"lifetime": 0.6,
		"explosiveness": 0.0,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 0),
		"spread": 45.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, 1, 0),
		"scale_min": 0.02,
		"scale_max": 0.08,
		"color_palette": "plasma",
		"continuous": true,
		"glow": true,
		"twinkle": true,
	},
	"rainbow_trail": {
		"category": Category.TRAIL,
		"particle_count": 40,
		"lifetime": 0.8,
		"explosiveness": 0.0,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 0),
		"spread": 20.0,
		"initial_velocity_min": 0.5,
		"initial_velocity_max": 2.0,
		"gravity": Vector3(0, 0.5, 0),
		"scale_min": 0.03,
		"scale_max": 0.1,
		"color_palette": "rainbow",
		"continuous": true,
		"glow": true,
	},
	"ghost_trail": {
		"category": Category.TRAIL,
		"particle_count": 20,
		"lifetime": 0.4,
		"explosiveness": 0.0,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 0),
		"spread": 15.0,
		"initial_velocity_min": 0.2,
		"initial_velocity_max": 0.8,
		"gravity": Vector3.ZERO,
		"scale_min": 0.15,
		"scale_max": 0.4,
		"color_start": Color(0.5, 0.6, 0.8, 0.3),
		"color_end": Color(0.6, 0.7, 0.9, 0.0),
		"continuous": true,
	},
	"pixel_trail": {
		"category": Category.TRAIL,
		"particle_count": 25,
		"lifetime": 0.5,
		"explosiveness": 0.0,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 0),
		"spread": 30.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, -2, 0),
		"scale_min": 0.03,
		"scale_max": 0.06,
		"color_palette": "rainbow",
		"continuous": true,
		"pixelated": true,
	},

	# ===== UI EFFECTS =====
	"ui_sparkle": {
		"category": Category.UI,
		"particle_count": 15,
		"lifetime": 0.8,
		"explosiveness": 0.5,
		"emission_shape": "point",
		"spread": 180.0,
		"initial_velocity_min": 50.0,
		"initial_velocity_max": 100.0,
		"gravity": Vector2(0, 50),
		"scale_min": 0.3,
		"scale_max": 0.8,
		"color_palette": "gold",
		"is_2d": true,
	},
	"ui_burst": {
		"category": Category.UI,
		"particle_count": 25,
		"lifetime": 0.5,
		"explosiveness": 1.0,
		"emission_shape": "point",
		"spread": 180.0,
		"initial_velocity_min": 100.0,
		"initial_velocity_max": 200.0,
		"gravity": Vector2(0, 200),
		"scale_min": 0.2,
		"scale_max": 0.6,
		"color_start": Color(1.0, 1.0, 1.0, 1.0),
		"color_end": Color(1.0, 1.0, 1.0, 0.0),
		"is_2d": true,
	},
	"ui_confetti": {
		"category": Category.UI,
		"particle_count": 50,
		"lifetime": 2.0,
		"explosiveness": 0.8,
		"emission_shape": "sphere",
		"emission_radius": 30.0,
		"spread": 180.0,
		"initial_velocity_min": 150.0,
		"initial_velocity_max": 300.0,
		"gravity": Vector2(0, 200),
		"scale_min": 0.4,
		"scale_max": 1.0,
		"color_palette": "rainbow",
		"angular_velocity": true,
		"is_2d": true,
	},
	"ui_coin_burst": {
		"category": Category.UI,
		"particle_count": 15,
		"lifetime": 1.0,
		"explosiveness": 0.9,
		"emission_shape": "point",
		"spread": 60.0,
		"initial_velocity_min": 200.0,
		"initial_velocity_max": 350.0,
		"gravity": Vector2(0, 400),
		"scale_min": 0.5,
		"scale_max": 1.0,
		"color_palette": "gold",
		"angular_velocity": true,
		"is_2d": true,
	},

	# ===== CELEBRATION =====
	"victory_confetti": {
		"category": Category.CELEBRATION,
		"particle_count": 200,
		"lifetime": 4.0,
		"explosiveness": 0.5,
		"emission_shape": "box",
		"emission_extents": Vector3(10.0, 0.5, 10.0),
		"direction": Vector3(0, -1, 0),
		"spread": 30.0,
		"initial_velocity_min": 2.0,
		"initial_velocity_max": 5.0,
		"gravity": Vector3(0, -3, 0),
		"scale_min": 0.03,
		"scale_max": 0.1,
		"color_palette": "rainbow",
		"angular_velocity": true,
		"turbulence": true,
		"continuous": true,
	},
	"firework_burst": {
		"category": Category.CELEBRATION,
		"particle_count": 150,
		"lifetime": 1.5,
		"explosiveness": 1.0,
		"emission_shape": "sphere",
		"emission_radius": 0.3,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 10.0,
		"initial_velocity_max": 20.0,
		"gravity": Vector3(0, -5, 0),
		"scale_min": 0.02,
		"scale_max": 0.08,
		"color_palette": "rainbow",
		"glow": true,
		"light_color": Color(1.0, 0.9, 0.8),
		"light_energy": 3.0,
	},
	"star_burst": {
		"category": Category.CELEBRATION,
		"particle_count": 80,
		"lifetime": 1.0,
		"explosiveness": 1.0,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 8.0,
		"initial_velocity_max": 15.0,
		"gravity": Vector3(0, 2, 0),
		"scale_min": 0.03,
		"scale_max": 0.12,
		"color_palette": "gold",
		"glow": true,
		"twinkle": true,
	},
	"level_up_burst": {
		"category": Category.CELEBRATION,
		"particle_count": 100,
		"lifetime": 1.2,
		"explosiveness": 0.9,
		"emission_shape": "ring",
		"emission_radius": 1.0,
		"direction": Vector3(0, 1, 0),
		"spread": 30.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 12.0,
		"gravity": Vector3(0, 5, 0),
		"scale_min": 0.03,
		"scale_max": 0.1,
		"color_start": Color(0.3, 1.0, 0.4, 1.0),
		"color_end": Color(1.0, 1.0, 0.5, 0.0),
		"glow": true,
		"light_color": Color(0.5, 1.0, 0.5),
		"light_energy": 4.0,
	},
}

# endregion


# region - State

## Current quality level
var _quality: Quality = Quality.HIGH

## Active particle systems
var _active_particles: Array[Dictionary] = []

## Object pools for each effect type
var _pools: Dictionary = {}

## Container nodes
var _container_2d: CanvasLayer = null
var _container_3d: Node3D = null

# endregion


# region - Lifecycle

func _ready() -> void:
	_setup_containers()
	_initialize_pools()
	print("[ParticleLibrary] Initialized with %d effect presets" % EFFECT_PRESETS.size())


func _process(delta: float) -> void:
	_cleanup_finished_effects(delta)


func _setup_containers() -> void:
	# 2D container for UI particles
	_container_2d = CanvasLayer.new()
	_container_2d.name = "ParticleLibrary2D"
	_container_2d.layer = 100
	add_child(_container_2d)

	# 3D container
	_container_3d = Node3D.new()
	_container_3d.name = "ParticleLibrary3D"
	add_child(_container_3d)


func _initialize_pools() -> void:
	# Pre-create pool entries for common effects
	for effect_name: String in EFFECT_PRESETS.keys():
		_pools[effect_name] = []

# endregion


# region - Public API

## Spawns a 2D particle effect at the given position
func spawn(effect_name: String, position: Vector2, options: Dictionary = {}) -> Node:
	if not EFFECT_PRESETS.has(effect_name):
		push_warning("ParticleLibrary: Unknown effect '%s'" % effect_name)
		return null

	var preset: Dictionary = EFFECT_PRESETS[effect_name]

	# Check if this is a 2D effect
	if not preset.get("is_2d", false):
		push_warning("ParticleLibrary: Effect '%s' is not a 2D effect. Use spawn_3d instead." % effect_name)
		return null

	return _spawn_2d_effect(effect_name, preset, position, options)


## Spawns a 3D particle effect at the given position
func spawn_3d(effect_name: String, position: Vector3, options: Dictionary = {}) -> Node:
	if not EFFECT_PRESETS.has(effect_name):
		push_warning("ParticleLibrary: Unknown effect '%s'" % effect_name)
		return null

	var preset: Dictionary = EFFECT_PRESETS[effect_name]

	# Check if this is a 3D effect
	if preset.get("is_2d", false):
		push_warning("ParticleLibrary: Effect '%s' is a 2D effect. Use spawn instead." % effect_name)
		return null

	return _spawn_3d_effect(effect_name, preset, position, options)


## Spawns a continuous effect that runs for the given duration
func spawn_continuous(effect_name: String, position: Variant, duration: float, options: Dictionary = {}) -> Node:
	if not EFFECT_PRESETS.has(effect_name):
		push_warning("ParticleLibrary: Unknown effect '%s'" % effect_name)
		return null

	var preset: Dictionary = EFFECT_PRESETS[effect_name]
	var effect: Node

	if preset.get("is_2d", false):
		effect = _spawn_2d_effect(effect_name, preset, position as Vector2, options)
	else:
		effect = _spawn_3d_effect(effect_name, preset, position as Vector3, options)

	if effect:
		# Set up auto-stop after duration
		var timer := get_tree().create_timer(duration)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(effect):
				if effect is GPUParticles2D:
					(effect as GPUParticles2D).emitting = false
				elif effect is GPUParticles3D:
					(effect as GPUParticles3D).emitting = false
		)

	return effect


## Spawns effect with direction (for trails, impacts, etc.)
func spawn_directional(effect_name: String, position: Variant, direction: Variant, options: Dictionary = {}) -> Node:
	options["direction"] = direction

	if EFFECT_PRESETS.has(effect_name):
		var preset: Dictionary = EFFECT_PRESETS[effect_name]
		if preset.get("is_2d", false):
			return spawn(effect_name, position as Vector2, options)
		else:
			return spawn_3d(effect_name, position as Vector3, options)

	return null


## Gets list of all available effect names
func get_effect_names() -> Array[String]:
	var names: Array[String] = []
	for key: String in EFFECT_PRESETS.keys():
		names.append(key)
	return names


## Gets effects by category
func get_effects_by_category(category: Category) -> Array[String]:
	var names: Array[String] = []
	for key: String in EFFECT_PRESETS.keys():
		if EFFECT_PRESETS[key].get("category") == category:
			names.append(key)
	return names


## Sets the quality level
func set_quality(quality: Quality) -> void:
	_quality = quality


## Gets the current quality level
func get_quality() -> Quality:
	return _quality


## Stops all active particle effects
func stop_all() -> void:
	for effect_data: Dictionary in _active_particles:
		var node: Node = effect_data.get("node")
		if is_instance_valid(node):
			if node is GPUParticles2D:
				(node as GPUParticles2D).emitting = false
			elif node is GPUParticles3D:
				(node as GPUParticles3D).emitting = false


## Gets the count of active effects
func get_active_count() -> int:
	return _active_particles.size()

# endregion


# region - 2D Effect Creation

func _spawn_2d_effect(effect_name: String, preset: Dictionary, position: Vector2, options: Dictionary) -> GPUParticles2D:
	# Check budget
	if _active_particles.size() >= MAX_ACTIVE_PARTICLES:
		budget_warning.emit(_active_particles.size(), MAX_ACTIVE_PARTICLES)
		_recycle_oldest_effect()

	# Get or create particles
	var particles: GPUParticles2D = _get_from_pool_2d(effect_name)
	if not particles:
		particles = _create_2d_particles(preset)
		_container_2d.add_child(particles)

	# Configure
	_configure_2d_particles(particles, preset, options)
	particles.position = position
	particles.emitting = true
	particles.visible = true

	# Track
	var lifetime: float = preset.get("lifetime", 1.0)
	if preset.get("continuous", false):
		lifetime = 999999.0  # Essentially infinite

	_active_particles.append({
		"node": particles,
		"name": effect_name,
		"spawn_time": Time.get_ticks_msec() / 1000.0,
		"lifetime": lifetime,
		"is_2d": true,
	})

	effect_spawned.emit(effect_name, position)

	return particles


func _create_2d_particles(preset: Dictionary) -> GPUParticles2D:
	var particles := GPUParticles2D.new()

	var base_count: int = preset.get("particle_count", 20)
	particles.amount = int(base_count * QUALITY_MULTIPLIERS[_quality])
	particles.lifetime = preset.get("lifetime", 1.0)
	particles.one_shot = not preset.get("continuous", false)
	particles.explosiveness = preset.get("explosiveness", 0.0)
	particles.randomness = 0.5

	# Create material
	var material := ParticleProcessMaterial.new()
	particles.process_material = material

	# Create mesh
	var quad := QuadMesh.new()
	quad.size = Vector2(8, 8)
	particles.draw_pass_1 = quad

	return particles


func _configure_2d_particles(particles: GPUParticles2D, preset: Dictionary, options: Dictionary) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	if not material:
		return

	# Direction and spread
	var spread: float = preset.get("spread", 45.0)
	material.spread = spread
	material.direction = Vector3(0, -1, 0)  # 2D uses vertical direction

	# Velocity
	material.initial_velocity_min = preset.get("initial_velocity_min", 50.0)
	material.initial_velocity_max = preset.get("initial_velocity_max", 100.0)

	# Gravity (convert to 3D for material)
	var gravity: Vector2 = preset.get("gravity", Vector2(0, 98))
	material.gravity = Vector3(gravity.x, gravity.y, 0)

	# Scale
	var scale_mult: float = options.get("scale", 1.0)
	material.scale_min = preset.get("scale_min", 0.5) * scale_mult
	material.scale_max = preset.get("scale_max", 1.0) * scale_mult

	# Angular velocity
	if preset.get("angular_velocity", false):
		material.angular_velocity_min = -720
		material.angular_velocity_max = 720

	# Colors
	_apply_colors(material, preset, options)

	# Update particle count based on quality
	var base_count: int = preset.get("particle_count", 20)
	particles.amount = int(base_count * QUALITY_MULTIPLIERS[_quality])
	particles.lifetime = preset.get("lifetime", 1.0)
	particles.one_shot = not preset.get("continuous", false)
	particles.explosiveness = preset.get("explosiveness", 0.0)

# endregion


# region - 3D Effect Creation

func _spawn_3d_effect(effect_name: String, preset: Dictionary, position: Vector3, options: Dictionary) -> GPUParticles3D:
	# Check budget
	if _active_particles.size() >= MAX_ACTIVE_PARTICLES:
		budget_warning.emit(_active_particles.size(), MAX_ACTIVE_PARTICLES)
		_recycle_oldest_effect()

	# Get or create particles
	var particles: GPUParticles3D = _get_from_pool_3d(effect_name)
	if not particles:
		particles = _create_3d_particles(preset)
		_container_3d.add_child(particles)

	# Configure
	_configure_3d_particles(particles, preset, options)
	particles.global_position = position
	particles.emitting = true
	particles.visible = true

	# Handle secondary effects
	if preset.has("secondary_effect"):
		var secondary_name: String = preset["secondary_effect"]
		if EFFECT_PRESETS.has(secondary_name):
			# Spawn secondary effect slightly delayed
			get_tree().create_timer(0.05).timeout.connect(func() -> void:
				spawn_3d(secondary_name, position, options)
			)

	# Handle light
	if preset.get("glow", false) and options.get("spawn_light", true):
		_spawn_effect_light(position, preset, options)

	# Track
	var lifetime: float = preset.get("lifetime", 1.0)
	if preset.get("continuous", false):
		lifetime = 999999.0

	_active_particles.append({
		"node": particles,
		"name": effect_name,
		"spawn_time": Time.get_ticks_msec() / 1000.0,
		"lifetime": lifetime,
		"is_2d": false,
	})

	effect_spawned.emit(effect_name, position)

	return particles


func _create_3d_particles(preset: Dictionary) -> GPUParticles3D:
	var particles := GPUParticles3D.new()

	var base_count: int = preset.get("particle_count", 20)
	particles.amount = int(base_count * QUALITY_MULTIPLIERS[_quality])
	particles.lifetime = preset.get("lifetime", 1.0)
	particles.one_shot = not preset.get("continuous", false)
	particles.explosiveness = preset.get("explosiveness", 0.0)
	particles.randomness = 0.5
	particles.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))

	# Create material
	var material := ParticleProcessMaterial.new()
	particles.process_material = material

	# Create mesh
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1

	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mesh_mat

	particles.draw_pass_1 = mesh

	return particles


func _configure_3d_particles(particles: GPUParticles3D, preset: Dictionary, options: Dictionary) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	if not material:
		return

	# Emission shape
	var emission_shape: String = preset.get("emission_shape", "point")
	match emission_shape:
		"point":
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		"sphere":
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			material.emission_sphere_radius = preset.get("emission_radius", 0.5)
		"box":
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			material.emission_box_extents = preset.get("emission_extents", Vector3(1, 1, 1))
		"ring":
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			material.emission_ring_radius = preset.get("emission_radius", 1.0)
			material.emission_ring_height = 0.1
			material.emission_ring_axis = Vector3.UP

	# Direction
	var direction: Vector3 = options.get("direction", preset.get("direction", Vector3(0, 1, 0)))
	material.direction = direction
	material.spread = preset.get("spread", 45.0)

	# Velocity
	material.initial_velocity_min = preset.get("initial_velocity_min", 5.0)
	material.initial_velocity_max = preset.get("initial_velocity_max", 10.0)

	# Gravity
	material.gravity = preset.get("gravity", Vector3(0, -10, 0))

	# Scale
	var scale_mult: float = options.get("scale", 1.0)
	material.scale_min = preset.get("scale_min", 0.1) * scale_mult
	material.scale_max = preset.get("scale_max", 0.5) * scale_mult

	# Angular velocity
	if preset.get("angular_velocity", false):
		material.angular_velocity_min = -360
		material.angular_velocity_max = 360

	# Turbulence
	if preset.get("turbulence", false):
		material.turbulence_enabled = true
		material.turbulence_noise_scale = 2.0
		material.turbulence_noise_strength = 1.0

	# Colors
	_apply_colors(material, preset, options)

	# Update particle count based on quality
	var base_count: int = preset.get("particle_count", 20)
	particles.amount = int(base_count * QUALITY_MULTIPLIERS[_quality])
	particles.lifetime = preset.get("lifetime", 1.0)
	particles.one_shot = not preset.get("continuous", false)
	particles.explosiveness = preset.get("explosiveness", 0.0)

# endregion


# region - Color System

func _apply_colors(material: ParticleProcessMaterial, preset: Dictionary, options: Dictionary) -> void:
	var gradient := Gradient.new()

	# Check for palette
	if preset.has("color_palette"):
		var palette_name: String = preset["color_palette"]
		if COLOR_PALETTES.has(palette_name):
			var colors: Array = COLOR_PALETTES[palette_name]
			var offsets: Array[float] = []
			var packed_colors: Array[Color] = []

			for i: int in range(colors.size()):
				offsets.append(float(i) / float(colors.size() - 1))
				packed_colors.append(colors[i])

			gradient.offsets = PackedFloat32Array(offsets)
			gradient.colors = PackedColorArray(packed_colors)
	elif preset.has("color_start") and preset.has("color_end"):
		var color_start: Color = options.get("color", preset["color_start"])
		var color_end: Color = preset["color_end"]
		gradient.colors = PackedColorArray([color_start, color_end])
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
	else:
		# Default white to transparent
		gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		gradient.offsets = PackedFloat32Array([0.0, 1.0])

	material.color_ramp = gradient

# endregion


# region - Light Effects

func _spawn_effect_light(position: Vector3, preset: Dictionary, _options: Dictionary) -> void:
	if not preset.get("light_color"):
		return

	var light := OmniLight3D.new()
	light.light_color = preset["light_color"]
	light.light_energy = preset.get("light_energy", 2.0)
	light.omni_range = preset.get("light_range", 5.0)
	light.omni_attenuation = 2.0
	light.position = position

	_container_3d.add_child(light)

	# Fade out light
	var tween := create_tween()
	var duration: float = preset.get("lifetime", 1.0) * 0.5
	tween.tween_property(light, "light_energy", 0.0, duration)
	tween.tween_callback(light.queue_free)

# endregion


# region - Pool Management

func _get_from_pool_2d(effect_name: String) -> GPUParticles2D:
	if not _pools.has(effect_name):
		return null

	var pool: Array = _pools[effect_name]
	for item: Variant in pool:
		if item is GPUParticles2D:
			var p: GPUParticles2D = item
			if not p.emitting:
				return p

	return null


func _get_from_pool_3d(effect_name: String) -> GPUParticles3D:
	if not _pools.has(effect_name):
		return null

	var pool: Array = _pools[effect_name]
	for item: Variant in pool:
		if item is GPUParticles3D:
			var p: GPUParticles3D = item
			if not p.emitting:
				return p

	return null


func _return_to_pool(effect_data: Dictionary) -> void:
	var node: Node = effect_data.get("node")
	var effect_name: String = effect_data.get("name", "")

	if not is_instance_valid(node):
		return

	if node is GPUParticles2D:
		(node as GPUParticles2D).emitting = false
		(node as GPUParticles2D).visible = false
	elif node is GPUParticles3D:
		(node as GPUParticles3D).emitting = false
		(node as GPUParticles3D).visible = false

	# Add to pool if not full
	if _pools.has(effect_name):
		var pool: Array = _pools[effect_name]
		if pool.size() < 10:  # Max pool size per effect
			pool.append(node)


func _recycle_oldest_effect() -> void:
	if _active_particles.is_empty():
		return

	var oldest := _active_particles[0]
	_return_to_pool(oldest)
	_active_particles.remove_at(0)


func _cleanup_finished_effects(_delta: float) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var to_remove: Array[int] = []

	for i: int in range(_active_particles.size()):
		var effect_data: Dictionary = _active_particles[i]
		var node: Node = effect_data.get("node")

		if not is_instance_valid(node):
			to_remove.append(i)
			continue

		var elapsed: float = current_time - effect_data.get("spawn_time", 0.0)
		var lifetime: float = effect_data.get("lifetime", 1.0)

		# Check if finished
		var is_emitting: bool = false
		if node is GPUParticles2D:
			is_emitting = (node as GPUParticles2D).emitting
		elif node is GPUParticles3D:
			is_emitting = (node as GPUParticles3D).emitting

		if elapsed > lifetime * 2.0 or (not is_emitting and elapsed > lifetime):
			_return_to_pool(effect_data)
			to_remove.append(i)
			effect_completed.emit(effect_data.get("name", ""))

	# Remove in reverse order
	for i: int in range(to_remove.size() - 1, -1, -1):
		_active_particles.remove_at(to_remove[i])

# endregion
