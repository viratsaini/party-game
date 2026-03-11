## Premium player lobby display with animated player cards and ready states.
## Features smooth entrance animations, ready indicator animations, and live updates.
class_name LobbyDisplay
extends Control

signal player_clicked(peer_id: int)

# ---- State ----
var _player_cards: Dictionary = {}  # peer_id -> PlayerCard node
var _skins: Array[CharacterSkin] = []

# ---- Configuration ----
const CARD_HEIGHT: float = 70.0
const CARD_SPACING: float = 12.0
const ENTRANCE_DELAY: float = 0.08

# ---- Node References ----
var main_container: VBoxContainer
var title_label: Label
var player_container: VBoxContainer
var info_label: Label


func _ready() -> void:
	_skins = DefaultSkins.get_all()
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = Vector2(320, 400)

	# Main panel
	var panel := PanelContainer.new()
	panel.name = "MainPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_panel_style(panel)
	add_child(panel)

	main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.add_theme_constant_override("separation", 12)
	panel.add_child(main_container)

	# Title with animated underline
	var title_container := Control.new()
	title_container.custom_minimum_size = Vector2(0, 50)
	main_container.add_child(title_container)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "PLAYERS"
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title_label.add_theme_constant_override("outline_size", 2)
	title_container.add_child(title_label)

	# Animated underline
	var underline := ColorRect.new()
	underline.name = "Underline"
	underline.set_anchors_preset(Control.PRESET_CENTER_TOP)
	underline.offset_top = 38
	underline.offset_left = -60
	underline.offset_right = 60
	underline.offset_bottom = 40
	underline.color = Color(0.9, 0.75, 0.3, 0.8)
	title_container.add_child(underline)

	# Start underline shimmer
	_animate_underline_shimmer(underline)

	# Scrollable player list
	var scroll := ScrollContainer.new()
	scroll.name = "PlayerScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_container.add_child(scroll)

	player_container = VBoxContainer.new()
	player_container.name = "PlayerContainer"
	player_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_container.add_theme_constant_override("separation", int(CARD_SPACING))
	scroll.add_child(player_container)

	# Info label at bottom
	info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.text = "Waiting for players..."
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	main_container.add_child(info_label)


func _apply_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.06, 0.9)
	style.border_color = Color(0.2, 0.25, 0.35, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)


func _animate_underline_shimmer(underline: ColorRect) -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(underline, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(underline, "modulate:a", 0.5, 1.0).set_trans(Tween.TRANS_SINE)


## Update the entire player list
func update_players(players: Dictionary, skins: Array[CharacterSkin] = []) -> void:
	if skins.size() > 0:
		_skins = skins

	var existing_ids: Array = _player_cards.keys()
	var new_ids: Array = players.keys()

	# Remove players that left
	for peer_id: int in existing_ids:
		if peer_id not in new_ids:
			_remove_player_card(peer_id)

	# Add/update players
	var index: int = 0
	for peer_id: int in new_ids:
		var info: Dictionary = players[peer_id]

		if peer_id in _player_cards:
			_update_player_card(peer_id, info)
		else:
			_add_player_card(peer_id, info, index * ENTRANCE_DELAY)

		index += 1

	_update_info_label(players)


## Add a new player with animated entrance
func _add_player_card(peer_id: int, info: Dictionary, delay: float = 0.0) -> void:
	var card := _create_player_card(peer_id, info)
	player_container.add_child(card)
	_player_cards[peer_id] = card

	# Animate entrance
	card.modulate.a = 0.0
	card.position.x = -50

	await get_tree().create_timer(delay).timeout

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.3)
	tween.tween_property(card, "position:x", 0.0, 0.4)


## Remove a player with exit animation
func _remove_player_card(peer_id: int) -> void:
	if peer_id not in _player_cards:
		return

	var card: Control = _player_cards[peer_id]
	_player_cards.erase(peer_id)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "modulate:a", 0.0, 0.2)
	tween.tween_property(card, "position:x", 50.0, 0.2)
	tween.chain().tween_callback(card.queue_free)


## Update existing player card
func _update_player_card(peer_id: int, info: Dictionary) -> void:
	if peer_id not in _player_cards:
		return

	var card: Control = _player_cards[peer_id]

	# Update character
	var portrait: ColorRect = card.find_child("Portrait", true, false) as ColorRect
	var skin_id: int = info.get("character_id", 0)
	if portrait and skin_id >= 0 and skin_id < _skins.size():
		var target_color: Color = _skins[skin_id].mesh_color
		if portrait.color != target_color:
			var tween := create_tween()
			tween.tween_property(portrait, "color", target_color, 0.3)

	# Update skin label
	var skin_label: Label = card.find_child("SkinLabel", true, false) as Label
	if skin_label and skin_id >= 0 and skin_id < _skins.size():
		skin_label.text = _skins[skin_id].skin_name

	# Update ready state
	var ready_indicator: Control = card.find_child("ReadyIndicator", true, false) as Control
	var is_ready: bool = info.get("ready", false)

	if ready_indicator:
		_update_ready_indicator(ready_indicator, is_ready)

	# Update name glow if ready
	var name_label: Label = card.find_child("NameLabel", true, false) as Label
	if name_label:
		if is_ready:
			name_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
		else:
			name_label.add_theme_color_override("font_color", Color.WHITE)


## Create a player card control
func _create_player_card(peer_id: int, info: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "PlayerCard_%d" % peer_id
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.9)
	style.border_color = Color(0.15, 0.2, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Character portrait
	var portrait_container := Control.new()
	portrait_container.custom_minimum_size = Vector2(50, 50)
	hbox.add_child(portrait_container)

	var portrait := ColorRect.new()
	portrait.name = "Portrait"
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	var skin_id: int = info.get("character_id", 0)
	if skin_id >= 0 and skin_id < _skins.size():
		portrait.color = _skins[skin_id].mesh_color
	else:
		portrait.color = Color.GRAY
	portrait_container.add_child(portrait)

	# Portrait border
	var portrait_border := ColorRect.new()
	portrait_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_border.offset_left = -2
	portrait_border.offset_top = -2
	portrait_border.offset_right = 2
	portrait_border.offset_bottom = 2
	portrait_border.color = info.get("color", Color.WHITE)
	portrait_border.z_index = -1
	portrait_container.add_child(portrait_border)

	# Info column
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	# Player name
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = info.get("name", "Player")
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info_vbox.add_child(name_label)

	# Skin name
	var skin_label := Label.new()
	skin_label.name = "SkinLabel"
	if skin_id >= 0 and skin_id < _skins.size():
		skin_label.text = _skins[skin_id].skin_name
	else:
		skin_label.text = "???"
	skin_label.add_theme_font_size_override("font_size", 14)
	skin_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	info_vbox.add_child(skin_label)

	# Ready indicator
	var ready_indicator := _create_ready_indicator()
	ready_indicator.name = "ReadyIndicator"
	hbox.add_child(ready_indicator)

	# Set initial ready state
	var is_ready: bool = info.get("ready", false)
	_update_ready_indicator(ready_indicator, is_ready, false)

	# Hover effects
	card.mouse_entered.connect(func() -> void: _on_card_hover(card, true))
	card.mouse_exited.connect(func() -> void: _on_card_hover(card, false))
	card.gui_input.connect(func(event: InputEvent) -> void: _on_card_input(event, peer_id))

	return card


func _create_ready_indicator() -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(40, 40)

	# Background circle
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.set_anchors_preset(Control.PRESET_CENTER)
	bg.offset_left = -18
	bg.offset_top = -18
	bg.offset_right = 18
	bg.offset_bottom = 18
	bg.color = Color(0.1, 0.1, 0.15, 1)
	container.add_child(bg)

	# Check mark label (using text for simplicity)
	var check := Label.new()
	check.name = "Check"
	check.text = "?"
	check.set_anchors_preset(Control.PRESET_CENTER)
	check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check.add_theme_font_size_override("font_size", 22)
	check.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1))
	container.add_child(check)

	return container


func _update_ready_indicator(indicator: Control, is_ready: bool, animate: bool = true) -> void:
	var bg: ColorRect = indicator.find_child("BG", false, false) as ColorRect
	var check: Label = indicator.find_child("Check", false, false) as Label

	if is_ready:
		check.text = "V"

		if animate:
			# Animate checkmark drawing
			check.modulate.a = 0.0
			check.scale = Vector2(0.5, 0.5)

			var tween := create_tween().set_parallel(true)
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(check, "modulate:a", 1.0, 0.2)
			tween.tween_property(check, "scale", Vector2.ONE, 0.3)

			# Green pulse on bg
			bg.color = Color(0.2, 0.6, 0.3, 1)
			var bg_tween := create_tween()
			bg_tween.tween_property(bg, "color", Color(0.15, 0.4, 0.2, 1), 0.3)

			# Play sound
			if is_instance_valid(AudioManager):
				AudioManager.play_sfx("ready_check")
		else:
			check.modulate.a = 1.0
			check.scale = Vector2.ONE
			bg.color = Color(0.15, 0.4, 0.2, 1)

		check.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1))
	else:
		check.text = "?"
		check.modulate.a = 1.0
		check.scale = Vector2.ONE
		bg.color = Color(0.1, 0.1, 0.15, 1)
		check.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1))


func _on_card_hover(card: PanelContainer, hovered: bool) -> void:
	var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	if hovered:
		style.border_color = Color(0.3, 0.5, 0.8, 1)
		style.bg_color = Color(0.08, 0.08, 0.15, 0.95)

		var tween := create_tween()
		tween.tween_property(card, "scale", Vector2(1.02, 1.02), 0.1)

		if is_instance_valid(AudioManager):
			AudioManager.play_sfx("button_hover")
	else:
		style.border_color = Color(0.15, 0.2, 0.3, 0.8)
		style.bg_color = Color(0.06, 0.06, 0.1, 0.9)

		var tween := create_tween()
		tween.tween_property(card, "scale", Vector2.ONE, 0.1)

	card.add_theme_stylebox_override("panel", style)


func _on_card_input(event: InputEvent, peer_id: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			player_clicked.emit(peer_id)


func _update_info_label(players: Dictionary) -> void:
	var player_count: int = players.size()
	var ready_count: int = 0

	for peer_id: int in players:
		if players[peer_id].get("ready", false):
			ready_count += 1

	if player_count == 0:
		info_label.text = "Waiting for players..."
	elif ready_count == player_count:
		info_label.text = "All players ready!"
		info_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1))
	else:
		info_label.text = "%d of %d players ready" % [ready_count, player_count]
		info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))


## Play animation when all players are ready
func play_all_ready_animation() -> void:
	# Flash all cards green
	for peer_id: int in _player_cards:
		var card: Control = _player_cards[peer_id]
		var original_modulate: Color = card.modulate

		card.modulate = Color(0.8, 1.2, 0.8, 1)

		var tween := create_tween()
		tween.tween_property(card, "modulate", original_modulate, 0.5)

	# Pulse title
	if title_label:
		title_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))

		var tween := create_tween()
		tween.tween_property(title_label, "scale", Vector2(1.1, 1.1), 0.15)
		tween.tween_property(title_label, "scale", Vector2.ONE, 0.15)
		tween.tween_callback(func() -> void:
			title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1))
		)
