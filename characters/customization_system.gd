## CustomizationSystem - Autoload singleton managing character customization.
## Handles cosmetic inventory, loadouts, equipped items, network sync, and shop.
## Integrates with the progression system for unlocks and purchases.
class_name CustomizationSystem
extends Node


# region -- Signals

## Emitted when a cosmetic item is unlocked.
signal item_unlocked(item: CosmeticItem)

## Emitted when a cosmetic item is equipped.
signal item_equipped(category: CosmeticItem.Category, item: CosmeticItem)

## Emitted when a loadout is saved.
signal loadout_saved(slot: int)

## Emitted when a loadout is loaded.
signal loadout_loaded(slot: int)

## Emitted when inventory changes (item added/removed).
signal inventory_changed()

## Emitted when shop purchase succeeds.
signal purchase_completed(item: CosmeticItem)

## Emitted when shop purchase fails.
signal purchase_failed(item: CosmeticItem, reason: String)

## Emitted when emote is triggered.
signal emote_triggered(emote: CosmeticItem)

## Emitted when cosmetics are synced from network.
signal cosmetics_synced(peer_id: int)

# endregion


# region -- Constants

## Maximum number of loadout slots.
const MAX_LOADOUTS: int = 3

## Save file path for cosmetic data.
const SAVE_PATH: String = "user://customization_data.save"

## Default equipped items per category.
const DEFAULT_EQUIPPED: Dictionary = {
	CosmeticItem.Category.HEAD: "head_default",
	CosmeticItem.Category.BODY: "body_default",
	CosmeticItem.Category.LEGS: "legs_default",
	CosmeticItem.Category.ACCESSORY: "",
	CosmeticItem.Category.WEAPON: "weapon_blaster_default",
	CosmeticItem.Category.EMOTE: "emote_wave",
	CosmeticItem.Category.TRAIL: "",
}

# endregion


# region -- State

## Master registry of all cosmetic items. Key = item_id, Value = CosmeticItem.
var _item_registry: Dictionary = {}

## Set of item IDs the player has unlocked.
var _unlocked_items: Dictionary = {}

## Currently equipped items. Key = Category, Value = item_id.
var _equipped_items: Dictionary = {}

## Saved loadouts. Array of dictionaries matching _equipped_items structure.
var _loadouts: Array[Dictionary] = []

## Currently selected loadout slot (0-2).
var _current_loadout_slot: int = 0

## Player currency (coins).
var _coins: int = 0

## Premium currency (gems).
var _gems: int = 0

## Player level (for level-locked items).
var _player_level: int = 1

## Unlocked achievements (for achievement-locked items).
var _achievements: Array[String] = []

## Network cache of other players' cosmetics. Key = peer_id.
var _remote_cosmetics: Dictionary = {}

## Current emote being played (null if none).
var _active_emote: CosmeticItem = null

## Selected victory pose item_id.
var _victory_pose_id: String = "emote_victory_wave"

# endregion


# region -- Lifecycle

func _ready() -> void:
	_register_all_cosmetics()
	_initialize_loadouts()
	_load_save_data()
	_equip_defaults()

	# Connect to multiplayer signals for cosmetic sync.
	if multiplayer:
		multiplayer.peer_connected.connect(_on_peer_connected)


func _exit_tree() -> void:
	_save_data()

# endregion


# region -- Item Registry

## Registers all built-in cosmetic items.
func _register_all_cosmetics() -> void:
	_register_head_items()
	_register_body_items()
	_register_legs_items()
	_register_accessory_items()
	_register_weapon_skins()
	_register_emotes()
	_register_trails()


## Registers a cosmetic item in the registry.
func register_item(item: CosmeticItem) -> void:
	if item.item_id.is_empty():
		push_error("CustomizationSystem: Cannot register item with empty ID.")
		return

	if _item_registry.has(item.item_id):
		push_warning("CustomizationSystem: Overwriting item '%s'." % item.item_id)

	_item_registry[item.item_id] = item


## Returns an item by ID, or null if not found.
func get_item(item_id: String) -> CosmeticItem:
	return _item_registry.get(item_id, null)


## Returns all items in a specific category.
func get_items_by_category(category: CosmeticItem.Category) -> Array[CosmeticItem]:
	var result: Array[CosmeticItem] = []
	for item_id: String in _item_registry:
		var item: CosmeticItem = _item_registry[item_id]
		if item.category == category:
			result.append(item)

	# Sort by rarity then sort_order.
	result.sort_custom(func(a: CosmeticItem, b: CosmeticItem) -> bool:
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return a.sort_order < b.sort_order
	)
	return result


## Returns all items matching a rarity.
func get_items_by_rarity(rarity: CosmeticItem.Rarity) -> Array[CosmeticItem]:
	var result: Array[CosmeticItem] = []
	for item_id: String in _item_registry:
		var item: CosmeticItem = _item_registry[item_id]
		if item.rarity == rarity:
			result.append(item)
	return result


## Returns all items available in the shop.
func get_shop_items() -> Array[CosmeticItem]:
	var result: Array[CosmeticItem] = []
	for item_id: String in _item_registry:
		var item: CosmeticItem = _item_registry[item_id]
		if not _unlocked_items.has(item_id):
			if item.unlock_method == CosmeticItem.UnlockMethod.SHOP_COINS \
				or item.unlock_method == CosmeticItem.UnlockMethod.SHOP_PREMIUM:
				if item.is_available:
					result.append(item)
	return result

# endregion


# region -- Inventory & Unlocks

## Returns true if the player owns the item.
func is_unlocked(item_id: String) -> bool:
	return _unlocked_items.has(item_id)


## Unlocks an item for the player.
func unlock_item(item_id: String) -> bool:
	var item: CosmeticItem = get_item(item_id)
	if not item:
		push_error("CustomizationSystem: Cannot unlock unknown item '%s'." % item_id)
		return false

	if _unlocked_items.has(item_id):
		return false  # Already unlocked.

	_unlocked_items[item_id] = true
	item_unlocked.emit(item)
	inventory_changed.emit()
	_save_data()
	return true


## Returns all unlocked items.
func get_unlocked_items() -> Array[CosmeticItem]:
	var result: Array[CosmeticItem] = []
	for item_id: String in _unlocked_items:
		var item: CosmeticItem = get_item(item_id)
		if item:
			result.append(item)
	return result


## Returns all unlocked items in a category.
func get_unlocked_by_category(category: CosmeticItem.Category) -> Array[CosmeticItem]:
	var result: Array[CosmeticItem] = []
	for item_id: String in _unlocked_items:
		var item: CosmeticItem = get_item(item_id)
		if item and item.category == category:
			result.append(item)
	return result

# endregion


# region -- Equipment

## Equips an item in its category slot.
func equip_item(item_id: String) -> bool:
	var item: CosmeticItem = get_item(item_id)
	if not item:
		push_error("CustomizationSystem: Cannot equip unknown item '%s'." % item_id)
		return false

	if not _unlocked_items.has(item_id) and item.unlock_method != CosmeticItem.UnlockMethod.DEFAULT:
		push_warning("CustomizationSystem: Item '%s' not unlocked." % item_id)
		return false

	_equipped_items[item.category] = item_id
	item_equipped.emit(item.category, item)

	# Broadcast to other players.
	_sync_equipped_to_peers()
	_save_data()
	return true


## Unequips the item in a category (sets to empty or default).
func unequip_category(category: CosmeticItem.Category) -> void:
	var default_id: String = DEFAULT_EQUIPPED.get(category, "")
	_equipped_items[category] = default_id

	var item: CosmeticItem = get_item(default_id) if not default_id.is_empty() else null
	item_equipped.emit(category, item)
	_sync_equipped_to_peers()
	_save_data()


## Returns the currently equipped item ID for a category.
func get_equipped_id(category: CosmeticItem.Category) -> String:
	return _equipped_items.get(category, "")


## Returns the currently equipped item for a category, or null.
func get_equipped_item(category: CosmeticItem.Category) -> CosmeticItem:
	var item_id: String = get_equipped_id(category)
	return get_item(item_id) if not item_id.is_empty() else null


## Returns all currently equipped items as a dictionary.
func get_all_equipped() -> Dictionary:
	return _equipped_items.duplicate()

# endregion


# region -- Loadouts

## Initializes empty loadout slots.
func _initialize_loadouts() -> void:
	_loadouts.clear()
	for i in range(MAX_LOADOUTS):
		_loadouts.append({})


## Saves current equipment to a loadout slot.
func save_loadout(slot: int) -> bool:
	if slot < 0 or slot >= MAX_LOADOUTS:
		push_error("CustomizationSystem: Invalid loadout slot %d." % slot)
		return false

	_loadouts[slot] = _equipped_items.duplicate()
	_current_loadout_slot = slot
	loadout_saved.emit(slot)
	_save_data()
	return true


## Loads a loadout slot to current equipment.
func load_loadout(slot: int) -> bool:
	if slot < 0 or slot >= MAX_LOADOUTS:
		push_error("CustomizationSystem: Invalid loadout slot %d." % slot)
		return false

	if _loadouts[slot].is_empty():
		push_warning("CustomizationSystem: Loadout slot %d is empty." % slot)
		return false

	_equipped_items = _loadouts[slot].duplicate()
	_current_loadout_slot = slot
	loadout_loaded.emit(slot)

	# Emit equipped signals for each category.
	for category: int in _equipped_items:
		var item: CosmeticItem = get_item(_equipped_items[category])
		item_equipped.emit(category, item)

	_sync_equipped_to_peers()
	return true


## Returns the current loadout slot.
func get_current_loadout_slot() -> int:
	return _current_loadout_slot


## Returns whether a loadout slot has saved data.
func has_loadout(slot: int) -> bool:
	if slot < 0 or slot >= MAX_LOADOUTS:
		return false
	return not _loadouts[slot].is_empty()

# endregion


# region -- Currency & Shop

## Returns current coin balance.
func get_coins() -> int:
	return _coins


## Returns current gem balance.
func get_gems() -> int:
	return _gems


## Adds coins to the player's balance.
func add_coins(amount: int) -> void:
	_coins = max(0, _coins + amount)
	_save_data()


## Adds gems to the player's balance.
func add_gems(amount: int) -> void:
	_gems = max(0, _gems + amount)
	_save_data()


## Attempts to purchase an item with coins.
func purchase_with_coins(item_id: String) -> bool:
	var item: CosmeticItem = get_item(item_id)
	if not item:
		purchase_failed.emit(null, "Item not found.")
		return false

	if _unlocked_items.has(item_id):
		purchase_failed.emit(item, "Already owned.")
		return false

	if item.unlock_method != CosmeticItem.UnlockMethod.SHOP_COINS:
		purchase_failed.emit(item, "Not purchasable with coins.")
		return false

	if _coins < item.price_coins:
		purchase_failed.emit(item, "Not enough coins.")
		return false

	_coins -= item.price_coins
	unlock_item(item_id)
	purchase_completed.emit(item)
	return true


## Attempts to purchase an item with gems.
func purchase_with_gems(item_id: String) -> bool:
	var item: CosmeticItem = get_item(item_id)
	if not item:
		purchase_failed.emit(null, "Item not found.")
		return false

	if _unlocked_items.has(item_id):
		purchase_failed.emit(item, "Already owned.")
		return false

	if item.unlock_method != CosmeticItem.UnlockMethod.SHOP_PREMIUM:
		purchase_failed.emit(item, "Not purchasable with gems.")
		return false

	if _gems < item.price_premium:
		purchase_failed.emit(item, "Not enough gems.")
		return false

	_gems -= item.price_premium
	unlock_item(item_id)
	purchase_completed.emit(item)
	return true


## Sets the player level for unlock checks.
func set_player_level(level: int) -> void:
	_player_level = level
	_check_level_unlocks()


## Adds an achievement and checks for unlocks.
func add_achievement(achievement_id: String) -> void:
	if achievement_id not in _achievements:
		_achievements.append(achievement_id)
		_check_achievement_unlocks(achievement_id)

# endregion


# region -- Emotes & Victory Poses

## Triggers an emote for the local player.
func trigger_emote(emote_id: String) -> void:
	var emote: CosmeticItem = get_item(emote_id)
	if not emote:
		push_error("CustomizationSystem: Unknown emote '%s'." % emote_id)
		return

	if emote.category != CosmeticItem.Category.EMOTE:
		push_error("CustomizationSystem: Item '%s' is not an emote." % emote_id)
		return

	if not _unlocked_items.has(emote_id) and emote.unlock_method != CosmeticItem.UnlockMethod.DEFAULT:
		push_warning("CustomizationSystem: Emote '%s' not unlocked." % emote_id)
		return

	_active_emote = emote
	emote_triggered.emit(emote)
	_broadcast_emote.rpc(emote_id)

	# Auto-clear after duration if interruptible.
	if emote.can_interrupt:
		get_tree().create_timer(emote.emote_duration).timeout.connect(_clear_active_emote)


## Cancels the current emote.
func cancel_emote() -> void:
	if _active_emote and _active_emote.can_interrupt:
		_clear_active_emote()


func _clear_active_emote() -> void:
	_active_emote = null


## Returns the current active emote, or null.
func get_active_emote() -> CosmeticItem:
	return _active_emote


## Sets the victory pose to use at match end.
func set_victory_pose(emote_id: String) -> void:
	var emote: CosmeticItem = get_item(emote_id)
	if emote and emote.category == CosmeticItem.Category.EMOTE and emote.is_victory_pose:
		_victory_pose_id = emote_id
		_save_data()


## Returns the selected victory pose item.
func get_victory_pose() -> CosmeticItem:
	return get_item(_victory_pose_id)


## Returns all unlocked victory poses.
func get_unlocked_victory_poses() -> Array[CosmeticItem]:
	var result: Array[CosmeticItem] = []
	for item_id: String in _unlocked_items:
		var item: CosmeticItem = get_item(item_id)
		if item and item.category == CosmeticItem.Category.EMOTE and item.is_victory_pose:
			result.append(item)
	return result

# endregion


# region -- Network Synchronization

## Called when a new peer connects - send our cosmetics.
func _on_peer_connected(peer_id: int) -> void:
	_sync_equipped_to_peer(peer_id)


## Syncs equipped items to all peers.
func _sync_equipped_to_peers() -> void:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return

	var data: Dictionary = _serialize_equipped()
	_rpc_receive_cosmetics.rpc(multiplayer.get_unique_id(), data)


## Syncs equipped items to a specific peer.
func _sync_equipped_to_peer(peer_id: int) -> void:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return

	var data: Dictionary = _serialize_equipped()
	_rpc_receive_cosmetics.rpc_id(peer_id, multiplayer.get_unique_id(), data)


## Serializes equipped items for network transfer.
func _serialize_equipped() -> Dictionary:
	var data: Dictionary = {}
	for category: int in _equipped_items:
		data[category] = _equipped_items[category]
	return data


## RPC to receive cosmetic data from a peer.
@rpc("any_peer", "reliable")
func _rpc_receive_cosmetics(sender_peer_id: int, equipped_data: Dictionary) -> void:
	_remote_cosmetics[sender_peer_id] = equipped_data
	cosmetics_synced.emit(sender_peer_id)


## RPC to broadcast emote to other players.
@rpc("any_peer", "reliable")
func _broadcast_emote(emote_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	# Emit signal so game can play the emote animation on that player.
	var emote: CosmeticItem = get_item(emote_id)
	if emote:
		emote_triggered.emit(emote)


## Returns the equipped cosmetics for a remote player.
func get_remote_equipped(peer_id: int) -> Dictionary:
	return _remote_cosmetics.get(peer_id, {})


## Returns a specific equipped item ID for a remote player.
func get_remote_equipped_id(peer_id: int, category: CosmeticItem.Category) -> String:
	var remote: Dictionary = get_remote_equipped(peer_id)
	return remote.get(category, "")

# endregion


# region -- Save/Load

## Saves customization data to disk.
func _save_data() -> void:
	var data: Dictionary = {
		"version": 1,
		"unlocked_items": _unlocked_items.keys(),
		"equipped_items": _equipped_items.duplicate(),
		"loadouts": _loadouts.duplicate(true),
		"current_loadout": _current_loadout_slot,
		"coins": _coins,
		"gems": _gems,
		"victory_pose": _victory_pose_id,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()
	else:
		push_error("CustomizationSystem: Failed to save data.")


## Loads customization data from disk.
func _load_save_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("CustomizationSystem: Failed to load save data.")
		return

	var data: Variant = file.get_var()
	file.close()

	if not data is Dictionary:
		push_warning("CustomizationSystem: Invalid save data format.")
		return

	# Restore unlocked items.
	var unlocked_list: Array = data.get("unlocked_items", [])
	for item_id: String in unlocked_list:
		_unlocked_items[item_id] = true

	# Restore equipped items.
	var equipped: Dictionary = data.get("equipped_items", {})
	for category_key: Variant in equipped:
		var category: int = int(category_key) if category_key is String else category_key
		_equipped_items[category] = equipped[category_key]

	# Restore loadouts.
	var saved_loadouts: Array = data.get("loadouts", [])
	for i in range(min(saved_loadouts.size(), MAX_LOADOUTS)):
		_loadouts[i] = saved_loadouts[i]

	_current_loadout_slot = data.get("current_loadout", 0)
	_coins = data.get("coins", 0)
	_gems = data.get("gems", 0)
	_victory_pose_id = data.get("victory_pose", "emote_victory_wave")


## Equips default items for any empty slots.
func _equip_defaults() -> void:
	for category: int in DEFAULT_EQUIPPED:
		if not _equipped_items.has(category) or _equipped_items[category].is_empty():
			var default_id: String = DEFAULT_EQUIPPED[category]
			if not default_id.is_empty():
				_equipped_items[category] = default_id
				# Auto-unlock default items.
				if not _unlocked_items.has(default_id):
					_unlocked_items[default_id] = true

# endregion


# region -- Unlock Checks

## Checks and unlocks items based on player level.
func _check_level_unlocks() -> void:
	for item_id: String in _item_registry:
		if _unlocked_items.has(item_id):
			continue

		var item: CosmeticItem = _item_registry[item_id]
		if item.unlock_method == CosmeticItem.UnlockMethod.LEVEL:
			if _player_level >= item.required_level:
				unlock_item(item_id)


## Checks and unlocks items based on a newly earned achievement.
func _check_achievement_unlocks(achievement_id: String) -> void:
	for item_id: String in _item_registry:
		if _unlocked_items.has(item_id):
			continue

		var item: CosmeticItem = _item_registry[item_id]
		if item.unlock_method == CosmeticItem.UnlockMethod.ACHIEVEMENT:
			if item.required_achievement == achievement_id:
				unlock_item(item_id)

# endregion


# region -- Item Registration (30+ Items)

func _register_head_items() -> void:
	# Default head.
	var head_default := CosmeticItem.new()
	head_default.item_id = "head_default"
	head_default.display_name = "Standard Helmet"
	head_default.description = "A reliable, no-frills helmet."
	head_default.category = CosmeticItem.Category.HEAD
	head_default.rarity = CosmeticItem.Rarity.COMMON
	head_default.unlock_method = CosmeticItem.UnlockMethod.DEFAULT
	head_default.primary_color = Color(0.6, 0.6, 0.6)
	register_item(head_default)

	# Robot Visor (Common).
	var head_robot := CosmeticItem.new()
	head_robot.item_id = "head_robot_visor"
	head_robot.display_name = "Robot Visor"
	head_robot.description = "Sleek visor for the tech-savvy warrior."
	head_robot.category = CosmeticItem.Category.HEAD
	head_robot.rarity = CosmeticItem.Rarity.COMMON
	head_robot.unlock_method = CosmeticItem.UnlockMethod.LEVEL
	head_robot.required_level = 3
	head_robot.primary_color = Color(0.3, 0.3, 0.35)
	head_robot.secondary_color = Color(0.2, 0.5, 0.9)
	register_item(head_robot)

	# Ninja Hood (Common).
	var head_ninja := CosmeticItem.new()
	head_ninja.item_id = "head_ninja_hood"
	head_ninja.display_name = "Ninja Hood"
	head_ninja.description = "Silent and mysterious."
	head_ninja.category = CosmeticItem.Category.HEAD
	head_ninja.rarity = CosmeticItem.Rarity.COMMON
	head_ninja.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	head_ninja.price_coins = 200
	head_ninja.primary_color = Color(0.1, 0.1, 0.1)
	register_item(head_ninja)

	# Space Helmet (Rare).
	var head_space := CosmeticItem.new()
	head_space.item_id = "head_space_helmet"
	head_space.display_name = "Space Helmet"
	head_space.description = "Ready for zero-gravity combat."
	head_space.category = CosmeticItem.Category.HEAD
	head_space.rarity = CosmeticItem.Rarity.RARE
	head_space.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	head_space.price_coins = 500
	head_space.primary_color = Color(0.95, 0.95, 0.95)
	head_space.secondary_color = Color(0.4, 0.7, 1.0)
	register_item(head_space)

	# Pirate Bandana (Rare).
	var head_pirate := CosmeticItem.new()
	head_pirate.item_id = "head_pirate_bandana"
	head_pirate.display_name = "Pirate Bandana"
	head_pirate.description = "Arr! Ready to plunder victory!"
	head_pirate.category = CosmeticItem.Category.HEAD
	head_pirate.rarity = CosmeticItem.Rarity.RARE
	head_pirate.unlock_method = CosmeticItem.UnlockMethod.ACHIEVEMENT
	head_pirate.required_achievement = "first_win"
	head_pirate.primary_color = Color(0.8, 0.1, 0.1)
	register_item(head_pirate)

	# Knight Helm (Rare).
	var head_knight := CosmeticItem.new()
	head_knight.item_id = "head_knight_helm"
	head_knight.display_name = "Knight Helm"
	head_knight.description = "For honorable combat."
	head_knight.category = CosmeticItem.Category.HEAD
	head_knight.rarity = CosmeticItem.Rarity.RARE
	head_knight.unlock_method = CosmeticItem.UnlockMethod.LEVEL
	head_knight.required_level = 10
	head_knight.primary_color = Color(0.75, 0.75, 0.8)
	head_knight.secondary_color = Color(0.5, 0.2, 0.7)
	register_item(head_knight)

	# Cyber Crown (Epic).
	var head_cyber := CosmeticItem.new()
	head_cyber.item_id = "head_cyber_crown"
	head_cyber.display_name = "Cyber Crown"
	head_cyber.description = "Rule the digital battlefield."
	head_cyber.category = CosmeticItem.Category.HEAD
	head_cyber.rarity = CosmeticItem.Rarity.EPIC
	head_cyber.unlock_method = CosmeticItem.UnlockMethod.SHOP_PREMIUM
	head_cyber.price_premium = 150
	head_cyber.primary_color = Color(0.1, 0.9, 0.9)
	head_cyber.glow_color = Color(0.0, 1.0, 1.0)
	head_cyber.glow_intensity = 0.8
	register_item(head_cyber)

	# Dragon Helm (Epic).
	var head_dragon := CosmeticItem.new()
	head_dragon.item_id = "head_dragon_helm"
	head_dragon.display_name = "Dragon Helm"
	head_dragon.description = "Forged in dragonfire."
	head_dragon.category = CosmeticItem.Category.HEAD
	head_dragon.rarity = CosmeticItem.Rarity.EPIC
	head_dragon.unlock_method = CosmeticItem.UnlockMethod.ACHIEVEMENT
	head_dragon.required_achievement = "kill_streak_10"
	head_dragon.primary_color = Color(0.8, 0.2, 0.1)
	head_dragon.secondary_color = Color(0.95, 0.7, 0.1)
	head_dragon.glow_color = Color(1.0, 0.4, 0.0)
	head_dragon.glow_intensity = 0.5
	register_item(head_dragon)

	# Galaxy Crown (Legendary).
	var head_galaxy := CosmeticItem.new()
	head_galaxy.item_id = "head_galaxy_crown"
	head_galaxy.display_name = "Galaxy Crown"
	head_galaxy.description = "Contains the power of a thousand stars."
	head_galaxy.category = CosmeticItem.Category.HEAD
	head_galaxy.rarity = CosmeticItem.Rarity.LEGENDARY
	head_galaxy.unlock_method = CosmeticItem.UnlockMethod.BATTLE_PASS
	head_galaxy.battle_pass_tier = 50
	head_galaxy.battle_pass_premium = true
	head_galaxy.primary_color = Color(0.1, 0.0, 0.3)
	head_galaxy.secondary_color = Color(0.9, 0.1, 0.9)
	head_galaxy.glow_color = Color(0.5, 0.0, 1.0)
	head_galaxy.glow_intensity = 1.5
	register_item(head_galaxy)

	# Void Mask (Legendary).
	var head_void := CosmeticItem.new()
	head_void.item_id = "head_void_mask"
	head_void.display_name = "Void Mask"
	head_void.description = "Peer into the abyss."
	head_void.category = CosmeticItem.Category.HEAD
	head_void.rarity = CosmeticItem.Rarity.LEGENDARY
	head_void.unlock_method = CosmeticItem.UnlockMethod.SHOP_PREMIUM
	head_void.price_premium = 500
	head_void.primary_color = Color(0.05, 0.0, 0.1)
	head_void.glow_color = Color(0.3, 0.0, 0.5)
	head_void.glow_intensity = 2.0
	register_item(head_void)


func _register_body_items() -> void:
	# Default body.
	var body_default := CosmeticItem.new()
	body_default.item_id = "body_default"
	body_default.display_name = "Standard Armor"
	body_default.description = "Reliable protection."
	body_default.category = CosmeticItem.Category.BODY
	body_default.rarity = CosmeticItem.Rarity.COMMON
	body_default.unlock_method = CosmeticItem.UnlockMethod.DEFAULT
	body_default.primary_color = Color(0.55, 0.55, 0.6)
	register_item(body_default)

	# Combat Vest (Common).
	var body_vest := CosmeticItem.new()
	body_vest.item_id = "body_combat_vest"
	body_vest.display_name = "Combat Vest"
	body_vest.description = "Tactical and practical."
	body_vest.category = CosmeticItem.Category.BODY
	body_vest.rarity = CosmeticItem.Rarity.COMMON
	body_vest.unlock_method = CosmeticItem.UnlockMethod.LEVEL
	body_vest.required_level = 2
	body_vest.primary_color = Color(0.3, 0.35, 0.25)
	register_item(body_vest)

	# Ninja Gi (Common).
	var body_ninja := CosmeticItem.new()
	body_ninja.item_id = "body_ninja_gi"
	body_ninja.display_name = "Ninja Gi"
	body_ninja.description = "Light and agile."
	body_ninja.category = CosmeticItem.Category.BODY
	body_ninja.rarity = CosmeticItem.Rarity.COMMON
	body_ninja.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	body_ninja.price_coins = 200
	body_ninja.primary_color = Color(0.1, 0.1, 0.1)
	register_item(body_ninja)

	# Space Suit (Rare).
	var body_space := CosmeticItem.new()
	body_space.item_id = "body_space_suit"
	body_space.display_name = "Space Suit"
	body_space.description = "Ready for orbital combat."
	body_space.category = CosmeticItem.Category.BODY
	body_space.rarity = CosmeticItem.Rarity.RARE
	body_space.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	body_space.price_coins = 500
	body_space.primary_color = Color(0.95, 0.95, 0.95)
	body_space.secondary_color = Color(1.0, 0.55, 0.1)
	register_item(body_space)

	# Pirate Coat (Rare).
	var body_pirate := CosmeticItem.new()
	body_pirate.item_id = "body_pirate_coat"
	body_pirate.display_name = "Pirate Coat"
	body_pirate.description = "Captain-level swagger."
	body_pirate.category = CosmeticItem.Category.BODY
	body_pirate.rarity = CosmeticItem.Rarity.RARE
	body_pirate.unlock_method = CosmeticItem.UnlockMethod.LEVEL
	body_pirate.required_level = 8
	body_pirate.primary_color = Color(0.45, 0.25, 0.1)
	body_pirate.secondary_color = Color(0.9, 0.75, 0.2)
	register_item(body_pirate)

	# Knight Armor (Rare).
	var body_knight := CosmeticItem.new()
	body_knight.item_id = "body_knight_armor"
	body_knight.display_name = "Knight Armor"
	body_knight.description = "Gleaming plate armor."
	body_knight.category = CosmeticItem.Category.BODY
	body_knight.rarity = CosmeticItem.Rarity.RARE
	body_knight.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	body_knight.price_coins = 600
	body_knight.primary_color = Color(0.75, 0.75, 0.8)
	register_item(body_knight)

	# Cyber Jacket (Epic).
	var body_cyber := CosmeticItem.new()
	body_cyber.item_id = "body_cyber_jacket"
	body_cyber.display_name = "Cyber Jacket"
	body_cyber.description = "Neon-infused street tech."
	body_cyber.category = CosmeticItem.Category.BODY
	body_cyber.rarity = CosmeticItem.Rarity.EPIC
	body_cyber.unlock_method = CosmeticItem.UnlockMethod.SHOP_PREMIUM
	body_cyber.price_premium = 150
	body_cyber.primary_color = Color(0.15, 0.15, 0.2)
	body_cyber.glow_color = Color(1.0, 0.0, 0.5)
	body_cyber.glow_intensity = 0.6
	register_item(body_cyber)

	# Phoenix Robes (Epic).
	var body_phoenix := CosmeticItem.new()
	body_phoenix.item_id = "body_phoenix_robes"
	body_phoenix.display_name = "Phoenix Robes"
	body_phoenix.description = "Rise from the ashes."
	body_phoenix.category = CosmeticItem.Category.BODY
	body_phoenix.rarity = CosmeticItem.Rarity.EPIC
	body_phoenix.unlock_method = CosmeticItem.UnlockMethod.ACHIEVEMENT
	body_phoenix.required_achievement = "comeback_win"
	body_phoenix.primary_color = Color(0.9, 0.3, 0.0)
	body_phoenix.secondary_color = Color(1.0, 0.8, 0.0)
	body_phoenix.glow_color = Color(1.0, 0.5, 0.0)
	body_phoenix.glow_intensity = 0.7
	register_item(body_phoenix)

	# Starforged Plate (Legendary).
	var body_star := CosmeticItem.new()
	body_star.item_id = "body_starforged_plate"
	body_star.display_name = "Starforged Plate"
	body_star.description = "Armor of celestial origin."
	body_star.category = CosmeticItem.Category.BODY
	body_star.rarity = CosmeticItem.Rarity.LEGENDARY
	body_star.unlock_method = CosmeticItem.UnlockMethod.BATTLE_PASS
	body_star.battle_pass_tier = 75
	body_star.battle_pass_premium = true
	body_star.primary_color = Color(0.2, 0.1, 0.4)
	body_star.glow_color = Color(0.8, 0.6, 1.0)
	body_star.glow_intensity = 1.2
	register_item(body_star)

	# Void Cloak (Legendary).
	var body_void := CosmeticItem.new()
	body_void.item_id = "body_void_cloak"
	body_void.display_name = "Void Cloak"
	body_void.description = "Woven from shadow itself."
	body_void.category = CosmeticItem.Category.BODY
	body_void.rarity = CosmeticItem.Rarity.LEGENDARY
	body_void.unlock_method = CosmeticItem.UnlockMethod.SHOP_PREMIUM
	body_void.price_premium = 500
	body_void.primary_color = Color(0.02, 0.0, 0.05)
	body_void.glow_color = Color(0.2, 0.0, 0.4)
	body_void.glow_intensity = 1.8
	register_item(body_void)


func _register_legs_items() -> void:
	# Default legs.
	var legs_default := CosmeticItem.new()
	legs_default.item_id = "legs_default"
	legs_default.display_name = "Standard Pants"
	legs_default.description = "Basic but dependable."
	legs_default.category = CosmeticItem.Category.LEGS
	legs_default.rarity = CosmeticItem.Rarity.COMMON
	legs_default.unlock_method = CosmeticItem.UnlockMethod.DEFAULT
	legs_default.primary_color = Color(0.45, 0.45, 0.5)
	register_item(legs_default)

	# Cargo Pants (Common).
	var legs_cargo := CosmeticItem.new()
	legs_cargo.item_id = "legs_cargo_pants"
	legs_cargo.display_name = "Cargo Pants"
	legs_cargo.description = "Extra pockets for extra gear."
	legs_cargo.category = CosmeticItem.Category.LEGS
	legs_cargo.rarity = CosmeticItem.Rarity.COMMON
	legs_cargo.unlock_method = CosmeticItem.UnlockMethod.LEVEL
	legs_cargo.required_level = 2
	legs_cargo.primary_color = Color(0.3, 0.35, 0.25)
	register_item(legs_cargo)

	# Ninja Pants (Common).
	var legs_ninja := CosmeticItem.new()
	legs_ninja.item_id = "legs_ninja_pants"
	legs_ninja.display_name = "Ninja Pants"
	legs_ninja.description = "For silent movement."
	legs_ninja.category = CosmeticItem.Category.LEGS
	legs_ninja.rarity = CosmeticItem.Rarity.COMMON
	legs_ninja.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	legs_ninja.price_coins = 150
	legs_ninja.primary_color = Color(0.1, 0.1, 0.1)
	register_item(legs_ninja)

	# Space Boots (Rare).
	var legs_space := CosmeticItem.new()
	legs_space.item_id = "legs_space_boots"
	legs_space.display_name = "Space Boots"
	legs_space.description = "Magnetic grip for any surface."
	legs_space.category = CosmeticItem.Category.LEGS
	legs_space.rarity = CosmeticItem.Rarity.RARE
	legs_space.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	legs_space.price_coins = 400
	legs_space.primary_color = Color(0.85, 0.85, 0.85)
	legs_space.secondary_color = Color(1.0, 0.55, 0.1)
	register_item(legs_space)

	# Pirate Boots (Rare).
	var legs_pirate := CosmeticItem.new()
	legs_pirate.item_id = "legs_pirate_boots"
	legs_pirate.display_name = "Pirate Boots"
	legs_pirate.description = "Sturdy sea legs."
	legs_pirate.category = CosmeticItem.Category.LEGS
	legs_pirate.rarity = CosmeticItem.Rarity.RARE
	legs_pirate.unlock_method = CosmeticItem.UnlockMethod.LEVEL
	legs_pirate.required_level = 6
	legs_pirate.primary_color = Color(0.35, 0.2, 0.1)
	register_item(legs_pirate)

	# Knight Greaves (Rare).
	var legs_knight := CosmeticItem.new()
	legs_knight.item_id = "legs_knight_greaves"
	legs_knight.display_name = "Knight Greaves"
	legs_knight.description = "Heavy but protective."
	legs_knight.category = CosmeticItem.Category.LEGS
	legs_knight.rarity = CosmeticItem.Rarity.RARE
	legs_knight.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	legs_knight.price_coins = 500
	legs_knight.primary_color = Color(0.7, 0.7, 0.75)
	register_item(legs_knight)

	# Cyber Legs (Epic).
	var legs_cyber := CosmeticItem.new()
	legs_cyber.item_id = "legs_cyber_legs"
	legs_cyber.display_name = "Cyber Legs"
	legs_cyber.description = "Enhanced mobility systems."
	legs_cyber.category = CosmeticItem.Category.LEGS
	legs_cyber.rarity = CosmeticItem.Rarity.EPIC
	legs_cyber.unlock_method = CosmeticItem.UnlockMethod.SHOP_PREMIUM
	legs_cyber.price_premium = 120
	legs_cyber.primary_color = Color(0.2, 0.2, 0.25)
	legs_cyber.glow_color = Color(0.0, 1.0, 0.5)
	legs_cyber.glow_intensity = 0.5
	register_item(legs_cyber)

	# Dragon Greaves (Epic).
	var legs_dragon := CosmeticItem.new()
	legs_dragon.item_id = "legs_dragon_greaves"
	legs_dragon.display_name = "Dragon Greaves"
	legs_dragon.description = "Scaled for battle."
	legs_dragon.category = CosmeticItem.Category.LEGS
	legs_dragon.rarity = CosmeticItem.Rarity.EPIC
	legs_dragon.unlock_method = CosmeticItem.UnlockMethod.ACHIEVEMENT
	legs_dragon.required_achievement = "matches_50"
	legs_dragon.primary_color = Color(0.6, 0.15, 0.05)
	legs_dragon.glow_color = Color(1.0, 0.3, 0.0)
	legs_dragon.glow_intensity = 0.4
	register_item(legs_dragon)

	# Starstrider Boots (Legendary).
	var legs_star := CosmeticItem.new()
	legs_star.item_id = "legs_starstrider_boots"
	legs_star.display_name = "Starstrider Boots"
	legs_star.description = "Walk among the cosmos."
	legs_star.category = CosmeticItem.Category.LEGS
	legs_star.rarity = CosmeticItem.Rarity.LEGENDARY
	legs_star.unlock_method = CosmeticItem.UnlockMethod.BATTLE_PASS
	legs_star.battle_pass_tier = 100
	legs_star.battle_pass_premium = true
	legs_star.primary_color = Color(0.15, 0.05, 0.3)
	legs_star.glow_color = Color(0.6, 0.4, 1.0)
	legs_star.glow_intensity = 1.0
	register_item(legs_star)

	# Shadow Stride (Legendary).
	var legs_shadow := CosmeticItem.new()
	legs_shadow.item_id = "legs_shadow_stride"
	legs_shadow.display_name = "Shadow Stride"
	legs_shadow.description = "Leave no trace."
	legs_shadow.category = CosmeticItem.Category.LEGS
	legs_shadow.rarity = CosmeticItem.Rarity.LEGENDARY
	legs_shadow.unlock_method = CosmeticItem.UnlockMethod.SHOP_PREMIUM
	legs_shadow.price_premium = 400
	legs_shadow.primary_color = Color(0.05, 0.0, 0.08)
	legs_shadow.glow_color = Color(0.15, 0.0, 0.25)
	legs_shadow.glow_intensity = 1.5
	register_item(legs_shadow)


func _register_accessory_items() -> void:
	# Aviator Glasses (Common).
	var acc_aviator := CosmeticItem.new()
	acc_aviator.item_id = "acc_aviator_glasses"
	acc_aviator.display_name = "Aviator Glasses"
	acc_aviator.description = "Classic cool."
	acc_aviator.category = CosmeticItem.Category.ACCESSORY
	acc_aviator.rarity = CosmeticItem.Rarity.COMMON
	acc_aviator.unlock_method = CosmeticItem.UnlockMethod.LEVEL
	acc_aviator.required_level = 4
	acc_aviator.primary_color = Color(0.1, 0.1, 0.1)
	register_item(acc_aviator)

	# Basic Backpack (Common).
	var acc_backpack := CosmeticItem.new()
	acc_backpack.item_id = "acc_basic_backpack"
	acc_backpack.display_name = "Basic Backpack"
	acc_backpack.description = "Carry your essentials."
	acc_backpack.category = CosmeticItem.Category.ACCESSORY
	acc_backpack.rarity = CosmeticItem.Rarity.COMMON
	acc_backpack.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	acc_backpack.price_coins = 100
	acc_backpack.primary_color = Color(0.4, 0.3, 0.2)
	register_item(acc_backpack)

	# Jetpack (Rare).
	var acc_jetpack := CosmeticItem.new()
	acc_jetpack.item_id = "acc_jetpack"
	acc_jetpack.display_name = "Jetpack"
	acc_jetpack.description = "Ready for takeoff!"
	acc_jetpack.category = CosmeticItem.Category.ACCESSORY
	acc_jetpack.rarity = CosmeticItem.Rarity.RARE
	acc_jetpack.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	acc_jetpack.price_coins = 600
	acc_jetpack.primary_color = Color(0.6, 0.6, 0.65)
	acc_jetpack.secondary_color = Color(1.0, 0.4, 0.0)
	register_item(acc_jetpack)

	# Tech Goggles (Rare).
	var acc_goggles := CosmeticItem.new()
	acc_goggles.item_id = "acc_tech_goggles"
	acc_goggles.display_name = "Tech Goggles"
	acc_goggles.description = "Enhanced vision systems."
	acc_goggles.category = CosmeticItem.Category.ACCESSORY
	acc_goggles.rarity = CosmeticItem.Rarity.RARE
	acc_goggles.unlock_method = CosmeticItem.UnlockMethod.ACHIEVEMENT
	acc_goggles.required_achievement = "headshots_50"
	acc_goggles.primary_color = Color(0.2, 0.25, 0.3)
	acc_goggles.secondary_color = Color(0.0, 0.8, 0.4)
	register_item(acc_goggles)

	# Halo (Epic).
	var acc_halo := CosmeticItem.new()
	acc_halo.item_id = "acc_halo"
	acc_halo.display_name = "Halo"
	acc_halo.description = "Divine presence."
	acc_halo.category = CosmeticItem.Category.ACCESSORY
	acc_halo.rarity = CosmeticItem.Rarity.EPIC
	acc_halo.unlock_method = CosmeticItem.UnlockMethod.SHOP_PREMIUM
	acc_halo.price_premium = 200
	acc_halo.primary_color = Color(1.0, 0.9, 0.5)
	acc_halo.glow_color = Color(1.0, 0.95, 0.6)
	acc_halo.glow_intensity = 1.0
	register_item(acc_halo)

	# Demon Wings (Epic).
	var acc_wings_demon := CosmeticItem.new()
	acc_wings_demon.item_id = "acc_demon_wings"
	acc_wings_demon.display_name = "Demon Wings"
	acc_wings_demon.description = "Embrace the darkness."
	acc_wings_demon.category = CosmeticItem.Category.ACCESSORY
	acc_wings_demon.rarity = CosmeticItem.Rarity.EPIC
	acc_wings_demon.unlock_method = CosmeticItem.UnlockMethod.ACHIEVEMENT
	acc_wings_demon.required_achievement = "kills_500"
	acc_wings_demon.primary_color = Color(0.4, 0.0, 0.0)
	acc_wings_demon.glow_color = Color(0.8, 0.1, 0.0)
	acc_wings_demon.glow_intensity = 0.6
	register_item(acc_wings_demon)

	# Angel Wings (Legendary).
	var acc_wings_angel := CosmeticItem.new()
	acc_wings_angel.item_id = "acc_angel_wings"
	acc_wings_angel.display_name = "Angel Wings"
	acc_wings_angel.description = "Ascend to glory."
	acc_wings_angel.category = CosmeticItem.Category.ACCESSORY
	acc_wings_angel.rarity = CosmeticItem.Rarity.LEGENDARY
	acc_wings_angel.unlock_method = CosmeticItem.UnlockMethod.BATTLE_PASS
	acc_wings_angel.battle_pass_tier = 90
	acc_wings_angel.battle_pass_premium = true
	acc_wings_angel.primary_color = Color(1.0, 1.0, 1.0)
	acc_wings_angel.glow_color = Color(1.0, 0.95, 0.8)
	acc_wings_angel.glow_intensity = 1.5
	register_item(acc_wings_angel)

	# Void Aura (Legendary).
	var acc_void_aura := CosmeticItem.new()
	acc_void_aura.item_id = "acc_void_aura"
	acc_void_aura.display_name = "Void Aura"
	acc_void_aura.description = "The emptiness surrounds you."
	acc_void_aura.category = CosmeticItem.Category.ACCESSORY
	acc_void_aura.rarity = CosmeticItem.Rarity.LEGENDARY
	acc_void_aura.unlock_method = CosmeticItem.UnlockMethod.SHOP_PREMIUM
	acc_void_aura.price_premium = 600
	acc_void_aura.primary_color = Color(0.1, 0.0, 0.15)
	acc_void_aura.glow_color = Color(0.3, 0.0, 0.5)
	acc_void_aura.glow_intensity = 2.0
	register_item(acc_void_aura)


func _register_weapon_skins() -> void:
	# Default Blaster.
	var wpn_default := CosmeticItem.new()
	wpn_default.item_id = "weapon_blaster_default"
	wpn_default.display_name = "Standard Blaster"
	wpn_default.description = "Reliable sidearm."
	wpn_default.category = CosmeticItem.Category.WEAPON
	wpn_default.rarity = CosmeticItem.Rarity.COMMON
	wpn_default.unlock_method = CosmeticItem.UnlockMethod.DEFAULT
	wpn_default.weapon_type = "blaster"
	wpn_default.primary_color = Color(0.5, 0.5, 0.55)
	wpn_default.projectile_color = Color(1.0, 0.8, 0.2)
	register_item(wpn_default)

	# Tech Blaster (Rare).
	var wpn_tech := CosmeticItem.new()
	wpn_tech.item_id = "weapon_blaster_tech"
	wpn_tech.display_name = "Tech Blaster"
	wpn_tech.description = "Advanced targeting systems."
	wpn_tech.category = CosmeticItem.Category.WEAPON
	wpn_tech.rarity = CosmeticItem.Rarity.RARE
	wpn_tech.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	wpn_tech.price_coins = 400
	wpn_tech.weapon_type = "blaster"
	wpn_tech.primary_color = Color(0.2, 0.25, 0.3)
	wpn_tech.secondary_color = Color(0.0, 0.8, 1.0)
	wpn_tech.projectile_color = Color(0.0, 0.9, 1.0)
	register_item(wpn_tech)

	# Dragon Blaster (Epic).
	var wpn_dragon := CosmeticItem.new()
	wpn_dragon.item_id = "weapon_blaster_dragon"
	wpn_dragon.display_name = "Dragon Blaster"
	wpn_dragon.description = "Shoots dragonfire."
	wpn_dragon.category = CosmeticItem.Category.WEAPON
	wpn_dragon.rarity = CosmeticItem.Rarity.EPIC
	wpn_dragon.unlock_method = CosmeticItem.UnlockMethod.ACHIEVEMENT
	wpn_dragon.required_achievement = "wins_25"
	wpn_dragon.weapon_type = "blaster"
	wpn_dragon.primary_color = Color(0.5, 0.1, 0.0)
	wpn_dragon.projectile_color = Color(1.0, 0.4, 0.0)
	wpn_dragon.glow_color = Color(1.0, 0.3, 0.0)
	wpn_dragon.glow_intensity = 0.5
	register_item(wpn_dragon)

	# Void Blaster (Legendary).
	var wpn_void := CosmeticItem.new()
	wpn_void.item_id = "weapon_blaster_void"
	wpn_void.display_name = "Void Blaster"
	wpn_void.description = "Fires pure darkness."
	wpn_void.category = CosmeticItem.Category.WEAPON
	wpn_void.rarity = CosmeticItem.Rarity.LEGENDARY
	wpn_void.unlock_method = CosmeticItem.UnlockMethod.SHOP_PREMIUM
	wpn_void.price_premium = 350
	wpn_void.weapon_type = "blaster"
	wpn_void.primary_color = Color(0.05, 0.0, 0.1)
	wpn_void.projectile_color = Color(0.3, 0.0, 0.5)
	wpn_void.glow_color = Color(0.2, 0.0, 0.4)
	wpn_void.glow_intensity = 1.2
	register_item(wpn_void)


func _register_emotes() -> void:
	# Wave emote (Default).
	var emote_wave := CosmeticItem.new()
	emote_wave.item_id = "emote_wave"
	emote_wave.display_name = "Wave"
	emote_wave.description = "A friendly greeting."
	emote_wave.category = CosmeticItem.Category.EMOTE
	emote_wave.rarity = CosmeticItem.Rarity.COMMON
	emote_wave.unlock_method = CosmeticItem.UnlockMethod.DEFAULT
	emote_wave.emote_duration = 1.5
	emote_wave.animation_name = "emote_wave"
	register_item(emote_wave)

	# Thumbs Up (Common).
	var emote_thumbsup := CosmeticItem.new()
	emote_thumbsup.item_id = "emote_thumbsup"
	emote_thumbsup.display_name = "Thumbs Up"
	emote_thumbsup.description = "Good job!"
	emote_thumbsup.category = CosmeticItem.Category.EMOTE
	emote_thumbsup.rarity = CosmeticItem.Rarity.COMMON
	emote_thumbsup.unlock_method = CosmeticItem.UnlockMethod.LEVEL
	emote_thumbsup.required_level = 5
	emote_thumbsup.emote_duration = 1.0
	emote_thumbsup.animation_name = "emote_thumbsup"
	register_item(emote_thumbsup)

	# Dance (Rare).
	var emote_dance := CosmeticItem.new()
	emote_dance.item_id = "emote_dance"
	emote_dance.display_name = "Victory Dance"
	emote_dance.description = "Show your moves!"
	emote_dance.category = CosmeticItem.Category.EMOTE
	emote_dance.rarity = CosmeticItem.Rarity.RARE
	emote_dance.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	emote_dance.price_coins = 300
	emote_dance.emote_duration = 3.0
	emote_dance.animation_name = "emote_dance"
	register_item(emote_dance)

	# Victory Wave (Default victory pose).
	var pose_wave := CosmeticItem.new()
	pose_wave.item_id = "emote_victory_wave"
	pose_wave.display_name = "Victory Wave"
	pose_wave.description = "Classic winner wave."
	pose_wave.category = CosmeticItem.Category.EMOTE
	pose_wave.rarity = CosmeticItem.Rarity.COMMON
	pose_wave.unlock_method = CosmeticItem.UnlockMethod.DEFAULT
	pose_wave.is_victory_pose = true
	pose_wave.emote_duration = 3.0
	pose_wave.animation_name = "victory_wave"
	pose_wave.can_interrupt = false
	register_item(pose_wave)

	# Champion Flex (Rare victory pose).
	var pose_flex := CosmeticItem.new()
	pose_flex.item_id = "emote_victory_flex"
	pose_flex.display_name = "Champion Flex"
	pose_flex.description = "Show off those muscles."
	pose_flex.category = CosmeticItem.Category.EMOTE
	pose_flex.rarity = CosmeticItem.Rarity.RARE
	pose_flex.unlock_method = CosmeticItem.UnlockMethod.ACHIEVEMENT
	pose_flex.required_achievement = "wins_10"
	pose_flex.is_victory_pose = true
	pose_flex.emote_duration = 3.5
	pose_flex.animation_name = "victory_flex"
	pose_flex.can_interrupt = false
	register_item(pose_flex)

	# Legendary Dance (Epic victory pose).
	var pose_legend := CosmeticItem.new()
	pose_legend.item_id = "emote_victory_legend"
	pose_legend.display_name = "Legend Dance"
	pose_legend.description = "Only the best deserve this."
	pose_legend.category = CosmeticItem.Category.EMOTE
	pose_legend.rarity = CosmeticItem.Rarity.EPIC
	pose_legend.unlock_method = CosmeticItem.UnlockMethod.BATTLE_PASS
	pose_legend.battle_pass_tier = 40
	pose_legend.is_victory_pose = true
	pose_legend.emote_duration = 4.0
	pose_legend.animation_name = "victory_legend"
	pose_legend.can_interrupt = false
	register_item(pose_legend)

	# Supreme Victory (Legendary victory pose).
	var pose_supreme := CosmeticItem.new()
	pose_supreme.item_id = "emote_victory_supreme"
	pose_supreme.display_name = "Supreme Victory"
	pose_supreme.description = "The ultimate celebration."
	pose_supreme.category = CosmeticItem.Category.EMOTE
	pose_supreme.rarity = CosmeticItem.Rarity.LEGENDARY
	pose_supreme.unlock_method = CosmeticItem.UnlockMethod.BATTLE_PASS
	pose_supreme.battle_pass_tier = 100
	pose_supreme.battle_pass_premium = true
	pose_supreme.is_victory_pose = true
	pose_supreme.emote_duration = 5.0
	pose_supreme.animation_name = "victory_supreme"
	pose_supreme.can_interrupt = false
	register_item(pose_supreme)


func _register_trails() -> void:
	# Rainbow Trail (Rare).
	var trail_rainbow := CosmeticItem.new()
	trail_rainbow.item_id = "trail_rainbow"
	trail_rainbow.display_name = "Rainbow Trail"
	trail_rainbow.description = "Leave a colorful path."
	trail_rainbow.category = CosmeticItem.Category.TRAIL
	trail_rainbow.rarity = CosmeticItem.Rarity.RARE
	trail_rainbow.unlock_method = CosmeticItem.UnlockMethod.SHOP_COINS
	trail_rainbow.price_coins = 500
	trail_rainbow.primary_color = Color(1.0, 0.0, 0.0)
	register_item(trail_rainbow)

	# Fire Trail (Epic).
	var trail_fire := CosmeticItem.new()
	trail_fire.item_id = "trail_fire"
	trail_fire.display_name = "Fire Trail"
	trail_fire.description = "Blazing footsteps."
	trail_fire.category = CosmeticItem.Category.TRAIL
	trail_fire.rarity = CosmeticItem.Rarity.EPIC
	trail_fire.unlock_method = CosmeticItem.UnlockMethod.SHOP_PREMIUM
	trail_fire.price_premium = 180
	trail_fire.primary_color = Color(1.0, 0.4, 0.0)
	trail_fire.glow_color = Color(1.0, 0.5, 0.0)
	trail_fire.glow_intensity = 0.8
	register_item(trail_fire)

	# Void Trail (Legendary).
	var trail_void := CosmeticItem.new()
	trail_void.item_id = "trail_void"
	trail_void.display_name = "Void Trail"
	trail_void.description = "Leave a path of darkness."
	trail_void.category = CosmeticItem.Category.TRAIL
	trail_void.rarity = CosmeticItem.Rarity.LEGENDARY
	trail_void.unlock_method = CosmeticItem.UnlockMethod.BATTLE_PASS
	trail_void.battle_pass_tier = 85
	trail_void.battle_pass_premium = true
	trail_void.primary_color = Color(0.1, 0.0, 0.15)
	trail_void.glow_color = Color(0.25, 0.0, 0.4)
	trail_void.glow_intensity = 1.5
	register_item(trail_void)

# endregion
