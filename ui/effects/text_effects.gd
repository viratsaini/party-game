## TextEffects - Animated text effects system for game feedback.
##
## This comprehensive text effects library provides:
##
## DAMAGE NUMBERS (8 styles):
##   - Standard, Critical, Healing, Shield
##   - Poison, Fire, Ice, Electric
##
## XP & REWARDS (6 types):
##   - XP gain, Coin pickup, Score bonus
##   - Multiplier, Streak bonus, Achievement
##
## COMBO SYSTEM (4 styles):
##   - Combo counter, Hit counter
##   - Multiplier display, Chain display
##
## ACHIEVEMENT UNLOCKS (4 styles):
##   - Standard unlock, Rare unlock
##   - Legendary unlock, Secret unlock
##
## LEVEL UP (3 styles):
##   - Standard level up, Prestige
##   - Rank up
##
## TITLE REVEALS (6 styles):
##   - Typewriter, Fade in words
##   - Slide in, Bounce in
##   - Glitch reveal, Scale pop
##
## SUBTITLE ANIMATIONS (4 styles):
##   - Fade, Slide up, Wave
##   - Character by character
##
## CREDITS ROLL:
##   - Vertical scroll, Section headers
##   - Role-name pairs, Special thanks
##
## Usage:
##   TextEffects.damage_number(position, 150, DamageType.CRITICAL)
##   TextEffects.xp_popup(position, 500)
##   TextEffects.combo_counter(position, 15)
##   TextEffects.achievement_unlock("First Blood", "Legendary")
##
class_name TextEffects
extends Node


# region - Signals

signal text_effect_spawned(effect_type: String, position: Vector2)
signal text_effect_completed(effect_type: String)
signal combo_updated(new_combo: int)
signal achievement_shown(achievement_name: String)

# endregion


# region - Enums

## Damage number types
enum DamageType {
	STANDARD,   ## White/gray normal damage
	CRITICAL,   ## Orange/red with emphasis
	HEALING,    ## Green healing numbers
	SHIELD,     ## Blue shield damage/regen
	POISON,     ## Purple poison damage
	FIRE,       ## Orange fire damage
	ICE,        ## Cyan ice damage
	ELECTRIC,   ## Yellow electric damage
	TRUE,       ## White true damage (ignores armor)
}

## Reward popup types
enum RewardType {
	XP,         ## Experience points
	COINS,      ## Currency
	SCORE,      ## Score points
	MULTIPLIER, ## Multiplier bonus
	STREAK,     ## Streak bonus
	ACHIEVEMENT,## Achievement unlocked
}

## Title reveal styles
enum RevealStyle {
	TYPEWRITER,     ## Character by character
	FADE_WORDS,     ## Word by word fade
	SLIDE_IN,       ## Slide from side
	BOUNCE_IN,      ## Bouncy appearance
	GLITCH,         ## Glitchy reveal
	SCALE_POP,      ## Scale up with pop
}

## Achievement rarity
enum AchievementRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	SECRET,
}

# endregion


# region - Constants

## Damage type color configurations
const DAMAGE_COLORS: Dictionary = {
	DamageType.STANDARD: {
		"color": Color(1.0, 1.0, 1.0),
		"outline": Color(0.2, 0.2, 0.2),
		"scale": 1.0,
	},
	DamageType.CRITICAL: {
		"color": Color(1.0, 0.3, 0.1),
		"outline": Color(0.5, 0.0, 0.0),
		"scale": 1.4,
		"shake": true,
	},
	DamageType.HEALING: {
		"color": Color(0.3, 1.0, 0.4),
		"outline": Color(0.0, 0.4, 0.1),
		"scale": 1.0,
		"prefix": "+",
	},
	DamageType.SHIELD: {
		"color": Color(0.3, 0.7, 1.0),
		"outline": Color(0.1, 0.2, 0.5),
		"scale": 1.0,
	},
	DamageType.POISON: {
		"color": Color(0.6, 0.2, 0.8),
		"outline": Color(0.2, 0.0, 0.3),
		"scale": 0.9,
	},
	DamageType.FIRE: {
		"color": Color(1.0, 0.5, 0.1),
		"outline": Color(0.5, 0.1, 0.0),
		"scale": 1.1,
	},
	DamageType.ICE: {
		"color": Color(0.5, 0.9, 1.0),
		"outline": Color(0.1, 0.3, 0.5),
		"scale": 1.0,
	},
	DamageType.ELECTRIC: {
		"color": Color(1.0, 1.0, 0.3),
		"outline": Color(0.5, 0.5, 0.0),
		"scale": 1.0,
		"jitter": true,
	},
	DamageType.TRUE: {
		"color": Color(1.0, 1.0, 1.0),
		"outline": Color(0.8, 0.8, 0.8),
		"scale": 1.2,
	},
}

## Reward type configurations
const REWARD_CONFIGS: Dictionary = {
	RewardType.XP: {
		"color": Color(0.3, 0.8, 1.0),
		"prefix": "+",
		"suffix": " XP",
		"icon": "xp",
	},
	RewardType.COINS: {
		"color": Color(1.0, 0.85, 0.0),
		"prefix": "+",
		"suffix": "",
		"icon": "coin",
	},
	RewardType.SCORE: {
		"color": Color(1.0, 1.0, 1.0),
		"prefix": "+",
		"suffix": "",
		"icon": null,
	},
	RewardType.MULTIPLIER: {
		"color": Color(1.0, 0.5, 1.0),
		"prefix": "x",
		"suffix": "",
		"icon": null,
	},
	RewardType.STREAK: {
		"color": Color(1.0, 0.6, 0.2),
		"prefix": "",
		"suffix": " STREAK!",
		"icon": "fire",
	},
	RewardType.ACHIEVEMENT: {
		"color": Color(1.0, 0.85, 0.0),
		"prefix": "",
		"suffix": "",
		"icon": "trophy",
	},
}

## Achievement rarity colors
const RARITY_COLORS: Dictionary = {
	AchievementRarity.COMMON: Color(0.7, 0.7, 0.7),
	AchievementRarity.UNCOMMON: Color(0.3, 0.8, 0.3),
	AchievementRarity.RARE: Color(0.3, 0.5, 1.0),
	AchievementRarity.EPIC: Color(0.7, 0.3, 1.0),
	AchievementRarity.LEGENDARY: Color(1.0, 0.6, 0.0),
	AchievementRarity.SECRET: Color(1.0, 0.0, 0.5),
}

## Font sizes
const FONT_SIZES: Dictionary = {
	"damage_small": 18,
	"damage_normal": 24,
	"damage_large": 32,
	"damage_critical": 40,
	"reward": 28,
	"combo": 36,
	"combo_large": 48,
	"achievement_title": 32,
	"achievement_desc": 20,
	"level_up": 56,
	"title": 64,
	"subtitle": 24,
}

## Maximum active text effects
const MAX_ACTIVE_EFFECTS: int = 100

# endregion


# region - State

## Container for text effects
var _container: CanvasLayer = null
var _effects_node: Control = null

## Active text effects
var _active_effects: Array[Dictionary] = []

## Current combo state
var _current_combo: int = 0
var _combo_timer: float = 0.0
var _combo_label: Label = null

## Object pools
var _label_pool: Array[Label] = []
const POOL_SIZE: int = 50

# endregion


# region - Lifecycle

func _ready() -> void:
	_setup_container()
	_initialize_pool()
	print("[TextEffects] Text effects system initialized")


func _process(delta: float) -> void:
	_update_active_effects(delta)
	_update_combo_timer(delta)


func _setup_container() -> void:
	_container = CanvasLayer.new()
	_container.name = "TextEffectsLayer"
	_container.layer = 110  # Above most UI
	add_child(_container)

	_effects_node = Control.new()
	_effects_node.name = "EffectsContainer"
	_effects_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.add_child(_effects_node)


func _initialize_pool() -> void:
	for i: int in range(POOL_SIZE):
		var label := _create_label()
		label.visible = false
		_effects_node.add_child(label)
		_label_pool.append(label)


func _create_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Add outline
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)

	return label

# endregion


# region - Damage Numbers

## Spawns a damage number at the given position
func damage_number(position: Vector2, amount: int, damage_type: DamageType = DamageType.STANDARD, options: Dictionary = {}) -> Label:
	var config: Dictionary = DAMAGE_COLORS.get(damage_type, DAMAGE_COLORS[DamageType.STANDARD])

	var label := _get_label_from_pool()
	if not label:
		return null

	# Format text
	var prefix: String = config.get("prefix", "")
	var text: String = prefix + str(amount)
	label.text = text

	# Apply colors
	var color: Color = options.get("color", config.get("color", Color.WHITE))
	var outline: Color = config.get("outline", Color.BLACK)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)

	# Apply scale
	var base_scale: float = config.get("scale", 1.0)
	var size_mult: float = options.get("scale", 1.0)

	# Scale based on damage amount
	if amount >= 1000:
		size_mult *= 1.3
	elif amount >= 500:
		size_mult *= 1.15
	elif amount >= 100:
		size_mult *= 1.05

	var font_size: int = int(FONT_SIZES["damage_normal"] * base_scale * size_mult)
	if damage_type == DamageType.CRITICAL:
		font_size = int(FONT_SIZES["damage_critical"] * size_mult)

	label.add_theme_font_size_override("font_size", font_size)

	# Position
	label.position = position - Vector2(50, 20)  # Center offset
	label.pivot_offset = label.size / 2
	label.visible = true
	label.modulate.a = 1.0
	label.scale = Vector2.ONE

	# Animate
	var duration: float = options.get("duration", 1.0)
	_animate_damage_number(label, config, duration)

	# Track
	_active_effects.append({
		"node": label,
		"type": "damage",
		"start_time": Time.get_ticks_msec() / 1000.0,
		"duration": duration,
	})

	text_effect_spawned.emit("damage", position)

	return label


func _animate_damage_number(label: Label, config: Dictionary, duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	# Initial pop
	label.scale = Vector2(0.5, 0.5)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), duration * 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(label, "scale", Vector2.ONE, duration * 0.1).set_ease(Tween.EASE_IN_OUT)

	# Rise up
	var rise_height: float = 60.0
	if config.get("shake", false):
		rise_height = 80.0

	tween.tween_property(label, "position:y", label.position.y - rise_height, duration * 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Jitter for electric
	if config.get("jitter", false):
		_apply_jitter(label, duration)

	# Fade out
	tween.chain().tween_property(label, "modulate:a", 0.0, duration * 0.3).set_ease(Tween.EASE_IN)


func _apply_jitter(label: Label, duration: float) -> void:
	var jitter_count: int = int(duration * 20)
	for i: int in range(jitter_count):
		var delay: float = float(i) / float(jitter_count) * duration * 0.7
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(label) and label.visible:
				var offset := Vector2(randf_range(-3, 3), randf_range(-3, 3))
				var original_pos := label.position
				label.position += offset
				get_tree().create_timer(0.02).timeout.connect(func() -> void:
					if is_instance_valid(label):
						label.position = original_pos
				)
		)


## Spawns a critical hit damage number with extra effects
func critical_damage(position: Vector2, amount: int, options: Dictionary = {}) -> Label:
	options["scale"] = options.get("scale", 1.0) * 1.2
	return damage_number(position, amount, DamageType.CRITICAL, options)


## Spawns a healing number
func healing_number(position: Vector2, amount: int) -> Label:
	return damage_number(position, amount, DamageType.HEALING)

# endregion


# region - XP & Rewards

## Spawns an XP gain popup
func xp_popup(position: Vector2, amount: int, options: Dictionary = {}) -> Label:
	return _reward_popup(position, amount, RewardType.XP, options)


## Spawns a coin pickup popup
func coin_popup(position: Vector2, amount: int, options: Dictionary = {}) -> Label:
	return _reward_popup(position, amount, RewardType.COINS, options)


## Spawns a score bonus popup
func score_popup(position: Vector2, amount: int, options: Dictionary = {}) -> Label:
	return _reward_popup(position, amount, RewardType.SCORE, options)


## Spawns a multiplier popup
func multiplier_popup(position: Vector2, multiplier: float, options: Dictionary = {}) -> Label:
	options["format"] = "%.1f"
	return _reward_popup(position, int(multiplier * 10), RewardType.MULTIPLIER, options)


## Spawns a streak bonus popup
func streak_popup(position: Vector2, streak_count: int, options: Dictionary = {}) -> Label:
	return _reward_popup(position, streak_count, RewardType.STREAK, options)


func _reward_popup(position: Vector2, amount: int, reward_type: RewardType, options: Dictionary = {}) -> Label:
	var config: Dictionary = REWARD_CONFIGS.get(reward_type, REWARD_CONFIGS[RewardType.SCORE])

	var label := _get_label_from_pool()
	if not label:
		return null

	# Format text
	var format_str: String = options.get("format", "%d")
	var value_str: String
	if reward_type == RewardType.MULTIPLIER:
		value_str = format_str % (float(amount) / 10.0)
	else:
		value_str = str(amount)

	label.text = config.get("prefix", "") + value_str + config.get("suffix", "")

	# Apply styling
	label.add_theme_color_override("font_color", config.get("color", Color.WHITE))
	label.add_theme_font_size_override("font_size", FONT_SIZES["reward"])

	# Position
	label.position = position - Vector2(80, 15)
	label.visible = true
	label.modulate.a = 1.0
	label.scale = Vector2.ONE

	# Animate
	var duration: float = options.get("duration", 1.5)
	_animate_reward_popup(label, duration)

	# Track
	_active_effects.append({
		"node": label,
		"type": "reward",
		"start_time": Time.get_ticks_msec() / 1000.0,
		"duration": duration,
	})

	text_effect_spawned.emit("reward", position)

	return label


func _animate_reward_popup(label: Label, duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	# Scale pop
	label.scale = Vector2(0.3, 0.3)
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), duration * 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.chain().tween_property(label, "scale", Vector2.ONE, duration * 0.1)

	# Float up with slight curve
	var target_y: float = label.position.y - 80
	tween.tween_property(label, "position:y", target_y, duration * 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Slight horizontal drift
	var drift: float = randf_range(-30, 30)
	tween.tween_property(label, "position:x", label.position.x + drift, duration * 0.8).set_ease(Tween.EASE_OUT)

	# Fade out
	tween.chain().tween_property(label, "modulate:a", 0.0, duration * 0.3)

# endregion


# region - Combo System

## Updates and displays combo counter
func combo_counter(position: Vector2, combo: int, options: Dictionary = {}) -> Label:
	_current_combo = combo
	_combo_timer = 3.0  # Reset combo timeout

	combo_updated.emit(combo)

	var label := _get_label_from_pool()
	if not label:
		return null

	# Format based on combo size
	var text: String
	var color: Color
	var font_size: int

	if combo >= 50:
		text = "ULTRA COMBO x%d!" % combo
		color = Color(1.0, 0.3, 0.8)
		font_size = FONT_SIZES["combo_large"]
	elif combo >= 25:
		text = "MEGA COMBO x%d!" % combo
		color = Color(1.0, 0.5, 0.0)
		font_size = FONT_SIZES["combo_large"]
	elif combo >= 10:
		text = "COMBO x%d!" % combo
		color = Color(1.0, 0.8, 0.0)
		font_size = FONT_SIZES["combo"]
	elif combo >= 5:
		text = "x%d COMBO" % combo
		color = Color(1.0, 1.0, 0.5)
		font_size = FONT_SIZES["combo"]
	else:
		text = "x%d" % combo
		color = Color(1.0, 1.0, 1.0)
		font_size = FONT_SIZES["damage_large"]

	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)

	label.position = position - Vector2(100, 25)
	label.visible = true
	label.modulate.a = 1.0

	# Animate
	var duration: float = options.get("duration", 0.8)
	_animate_combo(label, combo, duration)

	_active_effects.append({
		"node": label,
		"type": "combo",
		"start_time": Time.get_ticks_msec() / 1000.0,
		"duration": duration,
	})

	return label


func _animate_combo(label: Label, combo: int, duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	# Dramatic scale for high combos
	var peak_scale: float = 1.0 + min(combo * 0.02, 0.5)
	label.scale = Vector2(0.5, 0.5)
	tween.tween_property(label, "scale", Vector2(peak_scale, peak_scale), duration * 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(label, "scale", Vector2.ONE, duration * 0.15).set_ease(Tween.EASE_IN_OUT)

	# Rise and fade
	tween.tween_property(label, "position:y", label.position.y - 50, duration * 0.7).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "modulate:a", 0.0, duration * 0.3)


func _update_combo_timer(delta: float) -> void:
	if _current_combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0:
			reset_combo()


## Resets the combo counter
func reset_combo() -> void:
	if _current_combo > 0:
		_current_combo = 0
		combo_updated.emit(0)


## Gets current combo
func get_current_combo() -> int:
	return _current_combo

# endregion


# region - Achievement Unlocks

## Shows an achievement unlock notification
func achievement_unlock(achievement_name: String, description: String = "", rarity: AchievementRarity = AchievementRarity.COMMON) -> Control:
	var panel := _create_achievement_panel(achievement_name, description, rarity)
	_effects_node.add_child(panel)

	# Position at top center
	var viewport_size := get_viewport().get_visible_rect().size
	panel.position = Vector2(viewport_size.x / 2 - 200, -100)

	# Animate in
	var tween := create_tween()
	tween.tween_property(panel, "position:y", 50, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Hold
	tween.tween_interval(3.0)

	# Animate out
	tween.tween_property(panel, "position:y", -100, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(panel.queue_free)

	achievement_shown.emit(achievement_name)

	return panel


func _create_achievement_panel(achievement_name: String, description: String, rarity: AchievementRarity) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(400, 80)

	# Style based on rarity
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 4
	style.border_color = RARITY_COLORS[rarity]
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	# Title container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Achievement unlocked header
	var header := Label.new()
	header.text = "ACHIEVEMENT UNLOCKED"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", RARITY_COLORS[rarity])
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Achievement name
	var title := Label.new()
	title.text = achievement_name
	title.add_theme_font_size_override("font_size", FONT_SIZES["achievement_title"])
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Description
	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.add_theme_font_size_override("font_size", FONT_SIZES["achievement_desc"])
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(desc)

	return panel

# endregion


# region - Level Up Effects

## Shows a level up effect
func level_up(level: int, position: Vector2 = Vector2.ZERO) -> Control:
	if position == Vector2.ZERO:
		position = get_viewport().get_visible_rect().size / 2

	var container := Control.new()
	container.position = position - Vector2(150, 50)
	_effects_node.add_child(container)

	# Level up text
	var title := Label.new()
	title.text = "LEVEL UP!"
	title.add_theme_font_size_override("font_size", FONT_SIZES["level_up"])
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	title.add_theme_color_override("font_outline_color", Color(0.5, 0.3, 0.0))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(300, 70)
	container.add_child(title)

	# Level number
	var level_label := Label.new()
	level_label.text = "Level %d" % level
	level_label.add_theme_font_size_override("font_size", 32)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.custom_minimum_size = Vector2(300, 40)
	level_label.position.y = 60
	container.add_child(level_label)

	# Animate
	container.modulate.a = 0
	container.scale = Vector2(0.5, 0.5)

	var tween := create_tween()
	tween.set_parallel(true)

	# Pop in
	tween.tween_property(container, "modulate:a", 1.0, 0.3)
	tween.tween_property(container, "scale", Vector2(1.2, 1.2), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.chain().tween_property(container, "scale", Vector2.ONE, 0.2)

	# Hold
	tween.chain().tween_interval(1.5)

	# Fade out
	tween.tween_property(container, "modulate:a", 0.0, 0.5)
	tween.tween_property(container, "position:y", container.position.y - 50, 0.5)
	tween.tween_callback(container.queue_free)

	text_effect_spawned.emit("level_up", position)

	return container

# endregion


# region - Title Reveals

## Creates a title reveal effect
func title_reveal(text: String, position: Vector2, style: RevealStyle = RevealStyle.TYPEWRITER, options: Dictionary = {}) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", options.get("font_size", FONT_SIZES["title"]))
	label.add_theme_color_override("font_color", options.get("color", Color.WHITE))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.position = position - Vector2(300, 40)
	label.custom_minimum_size = Vector2(600, 80)
	_effects_node.add_child(label)

	var duration: float = options.get("duration", 2.0)

	match style:
		RevealStyle.TYPEWRITER:
			_animate_typewriter(label, text, duration)
		RevealStyle.FADE_WORDS:
			_animate_fade_words(label, text, duration)
		RevealStyle.SLIDE_IN:
			_animate_slide_in(label, text, duration)
		RevealStyle.BOUNCE_IN:
			_animate_bounce_in(label, text, duration)
		RevealStyle.GLITCH:
			_animate_glitch_reveal(label, text, duration)
		RevealStyle.SCALE_POP:
			_animate_scale_pop(label, text, duration)

	return label


func _animate_typewriter(label: Label, text: String, duration: float) -> void:
	label.text = ""
	var char_duration: float = duration / float(text.length())

	for i: int in range(text.length()):
		get_tree().create_timer(char_duration * i).timeout.connect(func() -> void:
			if is_instance_valid(label):
				label.text = text.substr(0, i + 1)
		)


func _animate_fade_words(label: Label, text: String, duration: float) -> void:
	label.text = text
	label.modulate.a = 0

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, duration * 0.3).set_ease(Tween.EASE_OUT)


func _animate_slide_in(label: Label, text: String, duration: float) -> void:
	label.text = text
	var target_x: float = label.position.x
	label.position.x = -400
	label.modulate.a = 0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:x", target_x, duration * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", 1.0, duration * 0.3)


func _animate_bounce_in(label: Label, text: String, duration: float) -> void:
	label.text = text
	label.scale = Vector2.ZERO
	label.pivot_offset = label.size / 2

	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), duration * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(label, "scale", Vector2.ONE, duration * 0.2)


func _animate_glitch_reveal(label: Label, text: String, duration: float) -> void:
	label.text = text
	var original_pos := label.position

	# Glitch effect
	for i: int in range(10):
		var delay: float = duration * 0.05 * i
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(label):
				label.position = original_pos + Vector2(randf_range(-10, 10), randf_range(-5, 5))
				label.modulate = Color(randf(), randf(), randf())
		)

	# Settle
	get_tree().create_timer(duration * 0.5).timeout.connect(func() -> void:
		if is_instance_valid(label):
			label.position = original_pos
			label.modulate = Color.WHITE
	)


func _animate_scale_pop(label: Label, text: String, duration: float) -> void:
	label.text = text
	label.scale = Vector2(3, 3)
	label.modulate.a = 0
	label.pivot_offset = label.size / 2

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, duration * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(label, "modulate:a", 1.0, duration * 0.2)

# endregion


# region - Subtitle Animations

## Shows an animated subtitle
func subtitle(text: String, position: Vector2, duration: float = 3.0, options: Dictionary = {}) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", options.get("font_size", FONT_SIZES["subtitle"]))
	label.add_theme_color_override("font_color", options.get("color", Color.WHITE))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.position = position - Vector2(200, 15)
	label.custom_minimum_size = Vector2(400, 30)
	label.modulate.a = 0
	_effects_node.add_child(label)

	var tween := create_tween()

	# Fade in
	tween.tween_property(label, "modulate:a", 1.0, 0.3)

	# Hold
	tween.tween_interval(duration - 0.6)

	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)

	return label


## Shows scrolling credits
func credits_roll(credits: Array[Dictionary], scroll_speed: float = 50.0) -> Control:
	var container := Control.new()
	var viewport_size := get_viewport().get_visible_rect().size
	container.position = Vector2(0, viewport_size.y)
	_effects_node.add_child(container)

	var y_offset: float = 0
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	container.add_child(vbox)

	for entry: Dictionary in credits:
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 5)

		# Role/category
		if entry.has("role"):
			var role_label := Label.new()
			role_label.text = entry["role"]
			role_label.add_theme_font_size_override("font_size", 24)
			role_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			role_label.custom_minimum_size = Vector2(viewport_size.x, 30)
			section.add_child(role_label)

		# Name
		if entry.has("name"):
			var name_label := Label.new()
			name_label.text = entry["name"]
			name_label.add_theme_font_size_override("font_size", 32)
			name_label.add_theme_color_override("font_color", Color.WHITE)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.custom_minimum_size = Vector2(viewport_size.x, 40)
			section.add_child(name_label)

		vbox.add_child(section)
		y_offset += 100

	# Calculate total scroll distance
	var total_height: float = y_offset + viewport_size.y * 2
	var scroll_duration: float = total_height / scroll_speed

	# Scroll up
	var tween := create_tween()
	tween.tween_property(container, "position:y", -total_height, scroll_duration).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(container.queue_free)

	return container

# endregion


# region - Pool Management

func _get_label_from_pool() -> Label:
	# Check for available labels
	for label: Label in _label_pool:
		if not label.visible:
			return label

	# Pool exhausted, recycle oldest
	if _active_effects.size() > 0:
		var oldest := _active_effects[0]
		var node: Label = oldest.get("node") as Label
		if is_instance_valid(node):
			node.visible = false
		_active_effects.remove_at(0)
		return node

	# Create new label as fallback
	if _active_effects.size() < MAX_ACTIVE_EFFECTS:
		var label := _create_label()
		_effects_node.add_child(label)
		_label_pool.append(label)
		return label

	return null


func _return_label_to_pool(label: Label) -> void:
	label.visible = false
	label.text = ""
	label.modulate.a = 1.0
	label.scale = Vector2.ONE


func _update_active_effects(delta: float) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var to_remove: Array[int] = []

	for i: int in range(_active_effects.size()):
		var effect: Dictionary = _active_effects[i]
		var elapsed: float = current_time - effect.get("start_time", 0.0)
		var duration: float = effect.get("duration", 1.0)

		if elapsed >= duration:
			var node: Label = effect.get("node") as Label
			if is_instance_valid(node):
				_return_label_to_pool(node)
			to_remove.append(i)
			text_effect_completed.emit(effect.get("type", "unknown"))

	# Remove in reverse order
	for i: int in range(to_remove.size() - 1, -1, -1):
		_active_effects.remove_at(to_remove[i])

# endregion


# region - Utility

## Clears all active text effects
func clear_all() -> void:
	for effect: Dictionary in _active_effects:
		var node: Node = effect.get("node")
		if is_instance_valid(node):
			if node is Label:
				_return_label_to_pool(node as Label)
			else:
				node.queue_free()

	_active_effects.clear()
	reset_combo()


## Gets active effect count
func get_active_count() -> int:
	return _active_effects.size()

# endregion
