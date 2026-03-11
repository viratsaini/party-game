## Premium character card with 3D flip animation, holographic shimmer, and rarity effects.
## Inspired by Valorant/Apex Legends agent select aesthetics.
class_name CharacterCard
extends Control

signal card_selected(skin_id: int)
signal card_hovered(skin_id: int)
signal card_info_requested(skin_id: int)

# ---- Exported Configuration ----
@export var skin: CharacterSkin = null
@export var is_locked: bool = false
@export var rarity: int = 0  # 0=Common, 1=Rare, 2=Epic, 3=Legendary

# ---- Node References ----
@onready var card_container: Control = $CardContainer
@onready var card_front: PanelContainer = $CardContainer/CardFront
@onready var card_back: PanelContainer = $CardContainer/CardBack
@onready var character_portrait: ColorRect = $CardContainer/CardFront/VBox/Portrait
@onready var name_label: Label = $CardContainer/CardFront/VBox/NameLabel
@onready var rarity_glow: ColorRect = $CardContainer/RarityGlow
@onready var shimmer_overlay: ColorRect = $CardContainer/ShimmerOverlay
@onready var lock_icon: Control = $CardContainer/LockIcon
@onready var selection_indicator: ColorRect = $CardContainer/SelectionIndicator

# ---- State ----
var _is_selected: bool = false
var _is_hovered: bool = false
var _is_flipped: bool = false
var _original_position: Vector2 = Vector2.ZERO
var _hover_tween: Tween = null
var _shimmer_tween: Tween = null
var _glow_tween: Tween = null

# ---- Rarity Colors ----
const RARITY_COLORS: Dictionary = {
	0: Color(0.6, 0.6, 0.6, 0.8),      # Common - Gray
	1: Color(0.2, 0.6, 1.0, 0.9),      # Rare - Blue
	2: Color(0.7, 0.2, 0.9, 0.95),     # Epic - Purple
	3: Color(1.0, 0.8, 0.2, 1.0),      # Legendary - Gold
}

const RARITY_NAMES: Dictionary = {
	0: "COMMON",
	1: "RARE",
	2: "EPIC",
	3: "LEGENDARY",
}


func _ready() -> void:
	_build_card_ui()
	_setup_interactions()
	_start_idle_animations()

	if skin:
		setup(skin, rarity, is_locked)


func _build_card_ui() -> void:
	# Main container
	card_container = Control.new()
	card_container.name = "CardContainer"
	card_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_container.pivot_offset = size / 2
	add_child(card_container)

	# Rarity glow (behind card)
	rarity_glow = ColorRect.new()
	rarity_glow.name = "RarityGlow"
	rarity_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	rarity_glow.color = RARITY_COLORS[0]
	rarity_glow.modulate.a = 0.0
	card_container.add_child(rarity_glow)

	# Card front
	card_front = PanelContainer.new()
	card_front.name = "CardFront"
	card_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_card_style(card_front)
	card_container.add_child(card_front)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	card_front.add_child(vbox)

	# Character portrait
	character_portrait = ColorRect.new()
	character_portrait.name = "Portrait"
	character_portrait.custom_minimum_size = Vector2(100, 100)
	character_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(character_portrait)

	# Character name
	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	# Rarity label
	var rarity_label := Label.new()
	rarity_label.name = "RarityLabel"
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(rarity_label)

	# Card back (for flip animation)
	card_back = PanelContainer.new()
	card_back.name = "CardBack"
	card_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_back.visible = false
	_apply_card_back_style(card_back)
	card_container.add_child(card_back)

	# Holographic shimmer overlay
	shimmer_overlay = ColorRect.new()
	shimmer_overlay.name = "ShimmerOverlay"
	shimmer_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	shimmer_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shimmer_overlay.color = Color(1, 1, 1, 0)
	card_container.add_child(shimmer_overlay)

	# Selection indicator
	selection_indicator = ColorRect.new()
	selection_indicator.name = "SelectionIndicator"
	selection_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_indicator.color = Color(0.3, 0.8, 1.0, 0)
	card_container.add_child(selection_indicator)

	# Lock icon
	lock_icon = Control.new()
	lock_icon.name = "LockIcon"
	lock_icon.set_anchors_preset(Control.PRESET_CENTER)
	lock_icon.visible = false
	var lock_label := Label.new()
	lock_label.text = "LOCKED"
	lock_label.add_theme_font_size_override("font_size", 18)
	lock_label.add_theme_color_override("font_color", Color.RED)
	lock_icon.add_child(lock_label)
	card_container.add_child(lock_icon)


func _apply_card_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)


func _apply_card_back_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.98)
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var pattern := Label.new()
	pattern.text = "?"
	pattern.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pattern.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pattern.add_theme_font_size_override("font_size", 48)
	pattern.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4, 1))
	panel.add_child(pattern)


func _setup_interactions() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)


## Configure the card with skin data
func setup(character_skin: CharacterSkin, card_rarity: int = 0, locked: bool = false) -> void:
	skin = character_skin
	rarity = card_rarity
	is_locked = locked

	if character_portrait:
		character_portrait.color = skin.mesh_color
		# Add accent ring
		_add_portrait_accent()

	if name_label:
		name_label.text = skin.skin_name

	# Update rarity label
	var rarity_label: Label = card_front.find_child("RarityLabel", true, false) as Label
	if rarity_label:
		rarity_label.text = RARITY_NAMES.get(rarity, "COMMON")
		rarity_label.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, RARITY_COLORS[0]))

	if rarity_glow:
		rarity_glow.color = RARITY_COLORS.get(rarity, RARITY_COLORS[0])

	if lock_icon:
		lock_icon.visible = is_locked

	_update_card_border()


func _add_portrait_accent() -> void:
	if not skin or not character_portrait:
		return

	# Create accent border around portrait
	var accent := ColorRect.new()
	accent.set_anchors_preset(Control.PRESET_FULL_RECT)
	accent.color = skin.accent_color
	accent.modulate.a = 0.3
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_portrait.add_child(accent)


func _update_card_border() -> void:
	if not card_front:
		return

	var style: StyleBoxFlat = card_front.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = RARITY_COLORS.get(rarity, RARITY_COLORS[0])
	style.set_border_width_all(rarity + 2)
	card_front.add_theme_stylebox_override("panel", style)


# ---- Interaction Handlers ----

func _on_mouse_entered() -> void:
	if is_locked:
		_animate_locked_shake()
		return

	_is_hovered = true
	card_hovered.emit(skin.skin_id if skin else -1)
	_animate_hover_in()
	_play_hover_sound()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_animate_hover_out()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if is_locked:
				_animate_locked_shake()
				return

			_animate_press()
			card_selected.emit(skin.skin_id if skin else -1)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			card_info_requested.emit(skin.skin_id if skin else -1)


# ---- Selection State ----

func set_selected(selected: bool) -> void:
	if _is_selected == selected:
		return

	_is_selected = selected

	if selected:
		_animate_selection()
	else:
		_animate_deselection()


func is_card_selected() -> bool:
	return _is_selected


# ---- Animations ----

func _start_idle_animations() -> void:
	# Start subtle shimmer animation for legendary cards
	if rarity >= 3:
		_start_legendary_shimmer()

	# Start rarity glow pulse
	_start_glow_pulse()


func _start_legendary_shimmer() -> void:
	if not shimmer_overlay:
		return

	if _shimmer_tween:
		_shimmer_tween.kill()

	_shimmer_tween = create_tween().set_loops()
	_shimmer_tween.tween_method(_update_shimmer, 0.0, 1.0, 3.0)


func _update_shimmer(progress: float) -> void:
	if not shimmer_overlay:
		return

	# Create holographic rainbow effect
	var hue: float = fmod(progress * 2.0, 1.0)
	var shimmer_color := Color.from_hsv(hue, 0.5, 1.0, 0.15)
	shimmer_overlay.color = shimmer_color


func _start_glow_pulse() -> void:
	if not rarity_glow or rarity < 1:
		return

	if _glow_tween:
		_glow_tween.kill()

	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(rarity_glow, "modulate:a", 0.4, 1.5).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(rarity_glow, "modulate:a", 0.1, 1.5).set_trans(Tween.TRANS_SINE)


func _animate_hover_in() -> void:
	if _hover_tween:
		_hover_tween.kill()

	_original_position = position

	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Lift up and scale
	_hover_tween.tween_property(card_container, "scale", Vector2(1.08, 1.08), 0.2)
	_hover_tween.tween_property(self, "position:y", position.y - 12, 0.2)

	# Intensify glow
	if rarity_glow:
		_hover_tween.tween_property(rarity_glow, "modulate:a", 0.7, 0.2)

	# Brighten card
	_hover_tween.tween_property(card_container, "modulate", Color(1.15, 1.15, 1.2, 1.0), 0.2)


func _animate_hover_out() -> void:
	if _hover_tween:
		_hover_tween.kill()

	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Return to original
	_hover_tween.tween_property(card_container, "scale", Vector2.ONE, 0.15)
	_hover_tween.tween_property(self, "position:y", _original_position.y, 0.15)

	# Restore glow
	var target_alpha: float = 0.1 if rarity >= 1 else 0.0
	if rarity_glow and not _is_selected:
		_hover_tween.tween_property(rarity_glow, "modulate:a", target_alpha, 0.15)

	# Restore color
	_hover_tween.tween_property(card_container, "modulate", Color.WHITE, 0.15)


func _animate_press() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Quick squeeze
	tween.tween_property(card_container, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(card_container, "scale", Vector2(1.05, 1.05), 0.15)


func _animate_selection() -> void:
	var tween := create_tween().set_parallel(true)

	# Flash effect
	if selection_indicator:
		selection_indicator.color.a = 0.5
		tween.tween_property(selection_indicator, "color:a", 0.15, 0.3)

	# Border glow intensify
	if rarity_glow:
		rarity_glow.color = Color(0.3, 0.9, 1.0, 1.0)
		tween.tween_property(rarity_glow, "modulate:a", 0.8, 0.2)

	# Scale pop
	tween.tween_property(card_container, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(card_container, "scale", Vector2(1.05, 1.05), 0.1)

	# Update border to selection color
	_update_selected_border()


func _animate_deselection() -> void:
	var tween := create_tween().set_parallel(true)

	# Fade selection indicator
	if selection_indicator:
		tween.tween_property(selection_indicator, "color:a", 0.0, 0.2)

	# Restore glow color
	if rarity_glow:
		rarity_glow.color = RARITY_COLORS.get(rarity, RARITY_COLORS[0])
		var target_alpha: float = 0.1 if rarity >= 1 else 0.0
		tween.tween_property(rarity_glow, "modulate:a", target_alpha, 0.2)

	# Return to normal scale
	tween.tween_property(card_container, "scale", Vector2.ONE, 0.15)

	_update_card_border()


func _update_selected_border() -> void:
	if not card_front:
		return

	var style: StyleBoxFlat = card_front.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = Color(0.3, 0.9, 1.0, 1.0)
	style.set_border_width_all(4)
	card_front.add_theme_stylebox_override("panel", style)


func _animate_locked_shake() -> void:
	var tween := create_tween()
	var orig_x: float = position.x

	tween.tween_property(self, "position:x", orig_x - 5, 0.05)
	tween.tween_property(self, "position:x", orig_x + 5, 0.05)
	tween.tween_property(self, "position:x", orig_x - 3, 0.05)
	tween.tween_property(self, "position:x", orig_x + 3, 0.05)
	tween.tween_property(self, "position:x", orig_x, 0.05)

	# Flash red
	card_container.modulate = Color(1, 0.5, 0.5, 1)
	tween.tween_property(card_container, "modulate", Color.WHITE, 0.2)


## 3D flip animation to reveal card
func flip_reveal(delay: float = 0.0) -> void:
	if not card_back or not card_front:
		return

	card_back.visible = true
	card_front.visible = false
	card_container.scale.x = -1.0

	await get_tree().create_timer(delay).timeout

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# First half - flip to edge
	tween.tween_property(card_container, "scale:x", 0.0, 0.15)
	tween.tween_callback(func() -> void:
		card_back.visible = false
		card_front.visible = true
	)
	# Second half - flip to front
	tween.tween_property(card_container, "scale:x", 1.0, 0.15)

	# Add a little bounce
	tween.tween_property(card_container, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(card_container, "scale", Vector2.ONE, 0.1)


## Cascade entrance animation
func animate_entrance(delay: float = 0.0) -> void:
	modulate.a = 0.0
	position.y += 50

	await get_tree().create_timer(delay).timeout

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "position:y", position.y - 50, 0.4)


func _play_hover_sound() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("button_hover")
