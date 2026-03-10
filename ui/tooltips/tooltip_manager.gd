## TooltipManager - Unified manager for all tooltip, help, and hint systems
## Provides a single entry point for the entire UX interaction system
extends Node

class_name TooltipManager

## Singleton access (set in _ready)
static var instance: TooltipManager = null

# =====================================================================
# SUBSYSTEMS
# =====================================================================

var tooltip: PremiumTooltip
var context_menu: ContextMenu
var tutorial: TutorialOverlayPremium
var help: InteractiveHelp
var hints: HintSystem

# =====================================================================
# CONFIGURATION
# =====================================================================

## Auto-initialize all subsystems
@export var auto_initialize: bool = true

# =====================================================================
# LIFECYCLE
# =====================================================================

func _ready() -> void:
	instance = self

	if auto_initialize:
		initialize_all()


func _exit_tree() -> void:
	if instance == self:
		instance = null


# =====================================================================
# INITIALIZATION
# =====================================================================

## Initialize all subsystems
func initialize_all() -> void:
	_init_tooltip()
	_init_context_menu()
	_init_tutorial()
	_init_help()
	_init_hints()

	print("[TooltipManager] All UX systems initialized")


func _init_tooltip() -> void:
	tooltip = PremiumTooltip.new()
	tooltip.name = "PremiumTooltip"
	add_child(tooltip)


func _init_context_menu() -> void:
	context_menu = ContextMenu.new()
	context_menu.name = "ContextMenu"
	add_child(context_menu)


func _init_tutorial() -> void:
	tutorial = TutorialOverlayPremium.new()
	tutorial.name = "TutorialOverlay"
	add_child(tutorial)


func _init_help() -> void:
	help = InteractiveHelp.new()
	help.name = "InteractiveHelp"
	add_child(help)


func _init_hints() -> void:
	hints = HintSystem.new()
	hints.name = "HintSystem"
	add_child(hints)


# =====================================================================
# CONVENIENCE API - TOOLTIPS
# =====================================================================

## Register a simple tooltip for an element
func add_tooltip(element: Control, title: String, description: String = "", icon: String = "") -> void:
	if not tooltip:
		return

	var tooltip_id := "tt_" + str(element.get_instance_id())
	tooltip.register_tooltip(element, tooltip_id, {
		"title": title,
		"description": description,
		"icon": icon
	})


## Register a tooltip with stats
func add_tooltip_with_stats(element: Control, title: String, description: String, stats: Array) -> void:
	if not tooltip:
		return

	var tooltip_id := "tt_" + str(element.get_instance_id())
	tooltip.register_tooltip(element, tooltip_id, {
		"title": title,
		"description": description,
		"stats": stats
	})


## Remove tooltip from element
func remove_tooltip(element: Control) -> void:
	if not tooltip:
		return

	var tooltip_id := "tt_" + str(element.get_instance_id())
	tooltip.unregister_tooltip(tooltip_id)


# =====================================================================
# CONVENIENCE API - CONTEXT MENUS
# =====================================================================

## Show a context menu at cursor position
func show_context_menu(items: Array) -> void:
	if not context_menu:
		return

	context_menu.show_menu(items)


## Show a context menu at specific position
func show_context_menu_at(items: Array, position: Vector2) -> void:
	if not context_menu:
		return

	context_menu.show_menu(items, position)


## Close any open context menu
func close_context_menu() -> void:
	if not context_menu:
		return

	context_menu.close_menu()


# =====================================================================
# CONVENIENCE API - TUTORIALS
# =====================================================================

## Start a tutorial with steps
## Each step: { "title": String, "description": String, "target": Control (optional) }
func start_tutorial(tutorial_id: String, steps: Array) -> void:
	if not tutorial:
		return

	tutorial.start_tutorial(tutorial_id, steps)


## Advance to next tutorial step
func next_tutorial_step() -> void:
	if not tutorial:
		return

	tutorial.next_step()


## Skip current tutorial
func skip_tutorial() -> void:
	if not tutorial:
		return

	tutorial.skip_tutorial()


## End tutorial
func end_tutorial() -> void:
	if not tutorial:
		return

	tutorial.end_tutorial()


## Check if tutorial is active
func is_tutorial_active() -> bool:
	return tutorial != null and tutorial._is_active


# =====================================================================
# CONVENIENCE API - HELP
# =====================================================================

## Register a help topic
func register_help_topic(topic_id: String, data: Dictionary) -> void:
	if not help:
		return

	help.register_topic(topic_id, data)


## Register help for a UI element
func add_element_help(element: Control, topic_id: String, quick_tip: String = "") -> void:
	if not help:
		return

	help.register_element_help(element, topic_id, quick_tip)


## Open help panel
func open_help(topic_id: String = "") -> void:
	if not help:
		return

	help.open_help(topic_id)


## Close help panel
func close_help() -> void:
	if not help:
		return

	help.close_help()


## Toggle help mode (hover any element for help)
func toggle_help_mode() -> void:
	if not help:
		return

	help.toggle_help_mode()


# =====================================================================
# CONVENIENCE API - HINTS
# =====================================================================

## Register a hint
func register_hint(hint_id: String, data: Dictionary) -> void:
	if not hints:
		return

	hints.register_hint(hint_id, data)


## Trigger a registered hint
func trigger_hint(hint_id: String, force: bool = false) -> bool:
	if not hints:
		return false

	return hints.trigger_hint(hint_id, force)


## Show a quick one-off hint
func show_hint(message: String, title: String = "", type: int = 1) -> void:
	if not hints:
		return

	hints.show_quick_hint(message, type as HintSystem.HintType, title)


## Show a random pro tip
func show_pro_tip() -> bool:
	if not hints:
		return false

	return hints.trigger_pro_tip()


## Dismiss all active hints
func dismiss_all_hints() -> void:
	if not hints:
		return

	hints.dismiss_all_hints()


## Add a pro tip to the rotation
func add_pro_tip(tip: String) -> void:
	if not hints:
		return

	hints.add_pro_tip(tip)


# =====================================================================
# UTILITY METHODS
# =====================================================================

## Create a standard context menu for game objects
func create_game_object_menu(object_name: String, actions: Dictionary) -> Array:
	var items: Array = []

	items.append({
		"id": "inspect",
		"text": "Inspect " + object_name,
		"icon": "",
		"shortcut": "I"
	})

	if actions.get("can_use", false):
		items.append({
			"id": "use",
			"text": "Use",
			"icon": "",
			"shortcut": "E"
		})

	if actions.get("can_pickup", false):
		items.append({
			"id": "pickup",
			"text": "Pick Up",
			"icon": "",
			"shortcut": "F"
		})

	items.append({"separator": true})

	if actions.get("can_drop", false):
		items.append({
			"id": "drop",
			"text": "Drop",
			"icon": "",
			"shortcut": "G"
		})
	else:
		items.append({
			"id": "drop",
			"text": "Drop",
			"disabled": true,
			"disabled_reason": "Cannot drop this item"
		})

	return items


## Create a standard weapon tooltip
func create_weapon_tooltip(weapon_name: String, damage: int, fire_rate: float, ammo: int, max_ammo: int) -> Dictionary:
	return {
		"title": weapon_name,
		"description": "A reliable weapon for combat situations.",
		"stats": [
			{"icon": "", "value": str(damage) + " DMG", "color": Color(1.0, 0.4, 0.3)},
			{"icon": "", "value": str(fire_rate) + "/s", "color": Color(0.4, 0.8, 1.0)},
			{"icon": "", "value": str(ammo) + "/" + str(max_ammo), "color": Color(0.8, 0.8, 0.4)}
		]
	}


## Create first-time user tutorial
func create_welcome_tutorial() -> Array:
	return [
		{
			"title": "Welcome to BattleZone!",
			"description": "Let's get you up to speed with the basics. This quick tutorial will show you everything you need to dominate the battlefield.",
			"position": "center"
		},
		{
			"title": "Movement Controls",
			"description": "Use the [b]virtual joystick[/b] on the left to move your character. Swipe to look around!",
			"position": "bottom"
		},
		{
			"title": "Combat",
			"description": "Tap the [b]fire button[/b] to shoot. Hold for automatic fire. The crosshair shows your aim accuracy.",
			"position": "bottom"
		},
		{
			"title": "Jetpack",
			"description": "Your jetpack gives you vertical mobility! Use it to reach high ground or escape danger. Watch your fuel gauge!",
			"position": "right"
		},
		{
			"title": "You're Ready!",
			"description": "That's all you need to know to get started. Jump into a match and show them what you've got!",
			"position": "center"
		}
	]


# =====================================================================
# STATIC ACCESS
# =====================================================================

## Get singleton instance
static func get_instance() -> TooltipManager:
	return instance


## Quick access to show tooltip
static func quick_tooltip(element: Control, text: String) -> void:
	if instance:
		instance.add_tooltip(element, text)


## Quick access to show hint
static func quick_hint(message: String) -> void:
	if instance:
		instance.show_hint(message)


## Quick access to show context menu
static func quick_menu(items: Array) -> void:
	if instance:
		instance.show_context_menu(items)
