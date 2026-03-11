## CosmeticItem - Resource class for all cosmetic items in BattleZone Party.
## Defines visual customization pieces: helmets, bodies, legs, accessories, weapon skins.
## Each item has a rarity tier, unlock requirements, and visual properties.
class_name CosmeticItem
extends Resource


# region -- Enums

## Rarity tiers affect drop rates, visual effects, and pricing.
enum Rarity {
	COMMON,      ## 50% drop rate, basic items
	RARE,        ## 30% drop rate, enhanced visuals
	EPIC,        ## 15% drop rate, unique designs
	LEGENDARY,   ## 5% drop rate, special effects + animations
}

## Categories for organizing and equipping cosmetics.
enum Category {
	HEAD,        ## Helmets, hats, hair styles
	BODY,        ## Torso armor, shirts, costumes
	LEGS,        ## Pants, leg armor, boots
	ACCESSORY,   ## Backpacks, wings, capes, glasses
	WEAPON,      ## Weapon skins (per weapon type)
	EMOTE,       ## Victory poses and emotes
	TRAIL,       ## Movement trail effects
}

## Unlock methods for acquiring cosmetics.
enum UnlockMethod {
	DEFAULT,         ## Available from start
	LEVEL,           ## Unlocked at specific player level
	ACHIEVEMENT,     ## Unlocked via achievement
	SHOP_COINS,      ## Purchasable with earned coins
	SHOP_PREMIUM,    ## Purchasable with premium currency
	BATTLE_PASS,     ## Battle pass reward
	EVENT,           ## Limited-time event reward
	SPECIAL,         ## Special unlock (codes, promotions)
}

# endregion


# region -- Core Properties

## Unique identifier for this cosmetic item.
@export var item_id: String = ""

## Display name shown in UI.
@export var display_name: String = ""

## Description shown in inventory/shop.
@export_multiline var description: String = ""

## Category this item belongs to.
@export var category: Category = Category.HEAD

## Rarity tier of this item.
@export var rarity: Rarity = Rarity.COMMON

## Icon texture for UI display (optional).
@export var icon: Texture2D = null

# endregion


# region -- Visual Properties

## Primary color applied to the cosmetic mesh.
@export var primary_color: Color = Color.WHITE

## Secondary/accent color for details.
@export var secondary_color: Color = Color.GRAY

## Emissive/glow color (for epic/legendary items).
@export var glow_color: Color = Color.TRANSPARENT

## Glow intensity (0.0 = no glow, 1.0+ = strong glow).
@export_range(0.0, 3.0) var glow_intensity: float = 0.0

## Path to custom mesh resource (optional, empty = use default).
@export_file("*.tres", "*.res") var mesh_path: String = ""

## Path to custom material resource (optional).
@export_file("*.tres", "*.res") var material_path: String = ""

## Scale modifier for the cosmetic mesh.
@export var scale_modifier: Vector3 = Vector3.ONE

## Position offset from attach point.
@export var position_offset: Vector3 = Vector3.ZERO

## Rotation offset in degrees.
@export var rotation_offset: Vector3 = Vector3.ZERO

# endregion


# region -- Weapon Skin Properties (Category.WEAPON only)

## Which weapon type this skin applies to (e.g., "blaster", "rapid_fire").
@export var weapon_type: String = ""

## Projectile color override for weapon skins.
@export var projectile_color: Color = Color.WHITE

## Muzzle flash color override.
@export var muzzle_flash_color: Color = Color.WHITE

## Custom projectile trail (empty = default).
@export_file("*.tres", "*.res") var projectile_trail_path: String = ""

# endregion


# region -- Emote Properties (Category.EMOTE only)

## Duration of the emote animation in seconds.
@export var emote_duration: float = 2.0

## Whether this is a victory pose (shown at match end).
@export var is_victory_pose: bool = false

## Whether the emote can be interrupted.
@export var can_interrupt: bool = true

## Animation name to play (must exist in AnimationPlayer).
@export var animation_name: String = ""

# endregion


# region -- Unlock Properties

## How this item is unlocked.
@export var unlock_method: UnlockMethod = UnlockMethod.DEFAULT

## Level required (if unlock_method == LEVEL).
@export var required_level: int = 0

## Achievement ID required (if unlock_method == ACHIEVEMENT).
@export var required_achievement: String = ""

## Coin price (if unlock_method == SHOP_COINS).
@export var price_coins: int = 0

## Premium currency price (if unlock_method == SHOP_PREMIUM).
@export var price_premium: int = 0

## Battle pass tier (if unlock_method == BATTLE_PASS).
@export var battle_pass_tier: int = 0

## Whether this is a premium battle pass reward.
@export var battle_pass_premium: bool = false

## Event ID (if unlock_method == EVENT).
@export var event_id: String = ""

# endregion


# region -- Metadata

## Set/collection this item belongs to (for matching bonuses).
@export var set_id: String = ""

## Tags for filtering/searching (e.g., "robot", "space", "halloween").
@export var tags: Array[String] = []

## Sort order within category (lower = appears first).
@export var sort_order: int = 0

## Whether this item is currently available in the game.
@export var is_available: bool = true

## Release date for time-limited items (ISO format string).
@export var release_date: String = ""

## Expiry date for limited items (empty = never expires).
@export var expiry_date: String = ""

# endregion


# region -- Helper Methods

## Returns the color associated with this item's rarity.
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.7, 0.7, 0.7, 1.0)      # Gray
		Rarity.RARE:
			return Color(0.2, 0.5, 0.9, 1.0)      # Blue
		Rarity.EPIC:
			return Color(0.6, 0.2, 0.8, 1.0)      # Purple
		Rarity.LEGENDARY:
			return Color(0.95, 0.7, 0.1, 1.0)     # Gold
		_:
			return Color.WHITE


## Returns human-readable rarity name.
func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Unknown"


## Returns the category name as a string.
func get_category_name() -> String:
	match category:
		Category.HEAD:
			return "Head"
		Category.BODY:
			return "Body"
		Category.LEGS:
			return "Legs"
		Category.ACCESSORY:
			return "Accessory"
		Category.WEAPON:
			return "Weapon"
		Category.EMOTE:
			return "Emote"
		Category.TRAIL:
			return "Trail"
		_:
			return "Unknown"


## Returns true if this item has special visual effects (epic+).
func has_special_effects() -> bool:
	return rarity >= Rarity.EPIC and glow_intensity > 0.0


## Creates a StandardMaterial3D based on this item's visual properties.
func create_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = primary_color

	if glow_intensity > 0.0 and glow_color.a > 0.0:
		mat.emission_enabled = true
		mat.emission = glow_color
		mat.emission_energy_multiplier = glow_intensity

	return mat


## Returns dictionary representation for network sync.
func to_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"category": category,
		"rarity": rarity,
	}


## Checks if the item can be unlocked by a player at the given level.
func can_unlock(player_level: int, player_achievements: Array[String], player_coins: int) -> bool:
	match unlock_method:
		UnlockMethod.DEFAULT:
			return true
		UnlockMethod.LEVEL:
			return player_level >= required_level
		UnlockMethod.ACHIEVEMENT:
			return required_achievement in player_achievements
		UnlockMethod.SHOP_COINS:
			return player_coins >= price_coins
		_:
			return false


## Returns a formatted price string for shop display.
func get_price_string() -> String:
	match unlock_method:
		UnlockMethod.DEFAULT:
			return "Free"
		UnlockMethod.LEVEL:
			return "Level %d" % required_level
		UnlockMethod.ACHIEVEMENT:
			return "Achievement"
		UnlockMethod.SHOP_COINS:
			return "%d Coins" % price_coins
		UnlockMethod.SHOP_PREMIUM:
			return "%d Gems" % price_premium
		UnlockMethod.BATTLE_PASS:
			var premium_text := " (Premium)" if battle_pass_premium else ""
			return "Tier %d%s" % [battle_pass_tier, premium_text]
		UnlockMethod.EVENT:
			return "Event Reward"
		UnlockMethod.SPECIAL:
			return "Special"
		_:
			return ""

# endregion
