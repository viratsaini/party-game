## Premium status effects display system.
## Features circular buff/debuff icons with progress rings, stacking indicators,
## glow effects, tooltips, and smooth fade animations.
## Designed for competitive mobile game quality (PUBG/CoD/Apex style).
class_name StatusEffectsDisplay
extends Control

## Effect types for different visual styles.
enum EffectType {
	BUFF,        ## Positive effect (green/blue).
	DEBUFF,      ## Negative effect (red/orange).
	NEUTRAL,     ## Neutral effect (white/gray).
	WARNING,     ## Warning state (yellow).
	SPECIAL,     ## Special/ultimate effects (purple/gold).
}

## Signal emitted when an effect expires.
signal effect_expired(effect_id: String)

## Signal emitted when an effect is applied.
signal effect_applied(effect_id: String)

## Active effects dictionary: {id: effect_data}
var _active_effects: Dictionary = {}

## Effect display nodes.
var _effect_nodes: Dictionary = {}

## Tooltip state.
var _hovered_effect: String = ""
var _tooltip_visible: bool = false
var _tooltip_alpha: float = 0.0
var _tooltip_target_alpha: float = 0.0

## Layout state.
var _layout_dirty: bool = false

# ── Layout Constants ─────────────────────────────────────────────────────────

const ICON_SIZE: float = 48.0
const ICON_SPACING: float = 8.0
const PROGRESS_RING_WIDTH: float = 3.0
const GLOW_SIZE: float = 4.0
const STACK_BADGE_SIZE: float = 18.0
const MAX_VISIBLE_EFFECTS: int = 8
const TOOLTIP_WIDTH: float = 180.0
const TOOLTIP_PADDING: float = 10.0

# ── Color Palette ────────────────────────────────────────────────────────────

## Effect type colors.
const BUFF_COLOR: Color = Color(0.2, 0.85, 0.4, 1.0)
const BUFF_GLOW: Color = Color(0.3, 1.0, 0.5, 0.5)
const DEBUFF_COLOR: Color = Color(0.95, 0.3, 0.2, 1.0)
const DEBUFF_GLOW: Color = Color(1.0, 0.4, 0.3, 0.5)
const NEUTRAL_COLOR: Color = Color(0.8, 0.8, 0.85, 1.0)
const NEUTRAL_GLOW: Color = Color(0.9, 0.9, 0.95, 0.4)
const WARNING_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)
const WARNING_GLOW: Color = Color(1.0, 0.9, 0.3, 0.5)
const SPECIAL_COLOR: Color = Color(0.7, 0.4, 1.0, 1.0)
const SPECIAL_GLOW: Color = Color(0.8, 0.5, 1.0, 0.6)

## Background colors.
const ICON_BG_COLOR: Color = Color(0.08, 0.08, 0.12, 0.85)
const ICON_BORDER_COLOR: Color = Color(0.25, 0.25, 0.3, 0.9)
const PROGRESS_BG_COLOR: Color = Color(0.15, 0.15, 0.2, 0.6)
const STACK_BG_COLOR: Color = Color(0.1, 0.1, 0.15, 0.95)
const STACK_TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

## Tooltip colors.
const TOOLTIP_BG_COLOR: Color = Color(0.05, 0.05, 0.08, 0.95)
const TOOLTIP_BORDER_COLOR: Color = Color(0.3, 0.3, 0.35, 0.9)
const TOOLTIP_TEXT_COLOR: Color = Color(0.9, 0.9, 0.95, 1.0)
const TOOLTIP_DESC_COLOR: Color = Color(0.7, 0.7, 0.75, 0.9)

## Animation timing.
const FADE_IN_DURATION: float = 0.2
const FADE_OUT_DURATION: float = 0.3
const PULSE_SPEED: float = 3.0
const TOOLTIP_FADE_SPEED: float = 8.0
const EXPIRY_WARNING_THRESHOLD: float = 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(ICON_SIZE * 4 + ICON_SPACING * 3, ICON_SIZE + 20)


func _process(delta: float) -> void:
	var needs_redraw: bool = false
	var effects_to_remove: Array[String] = []

	# Update all active effects.
	for effect_id: String in _active_effects:
		var effect: Dictionary = _active_effects[effect_id]

		# Update duration.
		if effect.has("duration") and (effect["duration"] as float) > 0.0:
			effect["remaining"] = maxf((effect["remaining"] as float) - delta, 0.0)

			if (effect["remaining"] as float) <= 0.0:
				effects_to_remove.append(effect_id)
				continue

		# Update animation state.
		if effect.has("fade_in") and (effect["fade_in"] as float) < 1.0:
			effect["fade_in"] = minf((effect["fade_in"] as float) + delta / FADE_IN_DURATION, 1.0)
			needs_redraw = true

		if effect.has("fade_out") and (effect["fade_out"] as float) > 0.0:
			effect["fade_out"] = maxf((effect["fade_out"] as float) - delta / FADE_OUT_DURATION, 0.0)
			needs_redraw = true

		# Update pulse for expiring effects.
		if effect.has("remaining") and (effect["remaining"] as float) <= EXPIRY_WARNING_THRESHOLD:
			effect["pulse_phase"] = fmod((effect.get("pulse_phase", 0.0) as float) + PULSE_SPEED * delta, TAU)
			needs_redraw = true

		# Update glow animation.
		effect["glow_phase"] = fmod((effect.get("glow_phase", 0.0) as float) + delta * 2.0, TAU)
		needs_redraw = true

	# Remove expired effects.
	for effect_id: String in effects_to_remove:
		_remove_effect_internal(effect_id)
		effect_expired.emit(effect_id)

	# Update tooltip fade.
	if absf(_tooltip_alpha - _tooltip_target_alpha) > 0.01:
		_tooltip_alpha = lerpf(_tooltip_alpha, _tooltip_target_alpha, TOOLTIP_FADE_SPEED * delta)
		needs_redraw = true

	if needs_redraw or not _active_effects.is_empty():
		queue_redraw()


func _draw() -> void:
	if _active_effects.is_empty():
		return

	var x_offset: float = 0.0
	var y_offset: float = 0.0
	var drawn_count: int = 0

	# Sort effects by type and remaining time.
	var sorted_ids: Array = _active_effects.keys()
	sorted_ids.sort_custom(_sort_effects)

	for effect_id in sorted_ids:
		if drawn_count >= MAX_VISIBLE_EFFECTS:
			break

		var effect: Dictionary = _active_effects[effect_id]
		var pos: Vector2 = Vector2(x_offset, y_offset)

		_draw_effect_icon(effect_id, effect, pos)

		x_offset += ICON_SIZE + ICON_SPACING
		drawn_count += 1

		# Wrap to next row if needed.
		if x_offset + ICON_SIZE > size.x:
			x_offset = 0.0
			y_offset += ICON_SIZE + ICON_SPACING

	# Draw tooltip if visible.
	if _tooltip_alpha > 0.01 and _hovered_effect != "":
		_draw_tooltip()


## Sort effects by priority.
func _sort_effects(a: String, b: String) -> bool:
	var effect_a: Dictionary = _active_effects.get(a, {})
	var effect_b: Dictionary = _active_effects.get(b, {})

	# Sort by type (debuffs first).
	var type_a: int = effect_a.get("type", EffectType.NEUTRAL) as int
	var type_b: int = effect_b.get("type", EffectType.NEUTRAL) as int

	if type_a != type_b:
		return type_a == EffectType.DEBUFF

	# Then by remaining time (expiring soon first).
	var remaining_a: float = effect_a.get("remaining", 999.0) as float
	var remaining_b: float = effect_b.get("remaining", 999.0) as float

	return remaining_a < remaining_b


## Draw a single effect icon.
func _draw_effect_icon(effect_id: String, effect: Dictionary, pos: Vector2) -> void:
	var center: Vector2 = pos + Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
	var radius: float = ICON_SIZE * 0.5

	var effect_type: EffectType = effect.get("type", EffectType.NEUTRAL) as EffectType
	var fade_alpha: float = (effect.get("fade_in", 1.0) as float) * (effect.get("fade_out", 1.0) as float)

	var colors: Dictionary = _get_colors_for_type(effect_type)
	var main_color: Color = colors["main"] as Color
	var glow_color: Color = colors["glow"] as Color

	main_color.a *= fade_alpha
	glow_color.a *= fade_alpha

	# Draw glow effect.
	var glow_phase: float = effect.get("glow_phase", 0.0) as float
	var glow_intensity: float = 0.5 + sin(glow_phase) * 0.3
	var glow_col: Color = glow_color
	glow_col.a *= glow_intensity
	draw_circle(center, radius + GLOW_SIZE, glow_col)

	# Draw background.
	draw_circle(center, radius, ICON_BG_COLOR)

	# Draw progress ring if has duration.
	if effect.has("duration") and (effect["duration"] as float) > 0.0:
		var progress: float = (effect["remaining"] as float) / (effect["duration"] as float)
		_draw_progress_ring(center, radius - 2, progress, main_color, effect)

	# Draw icon or letter.
	var icon_text: String = effect.get("icon", "?") as String
	_draw_icon_content(center, icon_text, main_color, fade_alpha)

	# Draw border.
	var border_color: Color = ICON_BORDER_COLOR
	border_color.a *= fade_alpha
	draw_arc(center, radius, 0.0, TAU, 32, border_color, 1.5)

	# Draw stack count if applicable.
	var stacks: int = effect.get("stacks", 1) as int
	if stacks > 1:
		_draw_stack_badge(pos + Vector2(ICON_SIZE - STACK_BADGE_SIZE * 0.5, -STACK_BADGE_SIZE * 0.3), stacks, fade_alpha)

	# Draw expiry warning pulse.
	if effect.has("remaining") and (effect["remaining"] as float) <= EXPIRY_WARNING_THRESHOLD:
		var pulse_phase: float = effect.get("pulse_phase", 0.0) as float
		var pulse: float = (sin(pulse_phase) + 1.0) * 0.5
		var warning_col: Color = WARNING_COLOR
		warning_col.a = pulse * 0.4 * fade_alpha
		draw_circle(center, radius, warning_col)


## Draw progress ring around icon.
func _draw_progress_ring(center: Vector2, radius: float, progress: float, color: Color, effect: Dictionary) -> void:
	# Background ring.
	draw_arc(center, radius, 0.0, TAU, 32, PROGRESS_BG_COLOR, PROGRESS_RING_WIDTH)

	# Progress fill (starts from top, goes clockwise).
	if progress > 0.001:
		var start_angle: float = -PI * 0.5
		var end_angle: float = start_angle + progress * TAU
		draw_arc(center, radius, start_angle, end_angle, 32, color, PROGRESS_RING_WIDTH)

		# Bright tip.
		var tip_pos: Vector2 = center + Vector2(cos(end_angle), sin(end_angle)) * radius
		var tip_color: Color = color.lightened(0.3)
		draw_circle(tip_pos, PROGRESS_RING_WIDTH * 0.8, tip_color)


## Draw icon content (text or symbol).
func _draw_icon_content(center: Vector2, icon_text: String, color: Color, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var display_text: String = icon_text.substr(0, 2).to_upper()

	var font_size: int = 18 if display_text.length() == 1 else 14
	var text_size: Vector2 = font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)

	var text_color: Color = color
	text_color.a = alpha

	# Shadow.
	draw_string(font, text_pos + Vector2(1, 1), display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.6 * alpha))
	# Main text.
	draw_string(font, text_pos, display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)


## Draw stack count badge.
func _draw_stack_badge(pos: Vector2, count: int, alpha: float) -> void:
	var badge_center: Vector2 = pos + Vector2(STACK_BADGE_SIZE * 0.5, STACK_BADGE_SIZE * 0.5)

	# Background.
	var bg_color: Color = STACK_BG_COLOR
	bg_color.a *= alpha
	draw_circle(badge_center, STACK_BADGE_SIZE * 0.5, bg_color)

	# Border.
	var border_color: Color = ICON_BORDER_COLOR
	border_color.a *= alpha
	draw_arc(badge_center, STACK_BADGE_SIZE * 0.5, 0.0, TAU, 16, border_color, 1.0)

	# Text.
	var font: Font = ThemeDB.fallback_font
	var count_text: String = str(count) if count < 100 else "99+"
	var font_size: int = 10 if count < 10 else 8
	var text_size: Vector2 = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = Vector2(badge_center.x - text_size.x * 0.5, badge_center.y + text_size.y * 0.35)

	var text_color: Color = STACK_TEXT_COLOR
	text_color.a = alpha
	draw_string(font, text_pos, count_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)


## Draw tooltip for hovered effect.
func _draw_tooltip() -> void:
	if not _active_effects.has(_hovered_effect):
		return

	var effect: Dictionary = _active_effects[_hovered_effect]
	var font: Font = ThemeDB.fallback_font

	var name_text: String = effect.get("name", "Unknown Effect") as String
	var desc_text: String = effect.get("description", "") as String

	# Calculate tooltip size.
	var name_size: Vector2 = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var desc_lines: Array[String] = _wrap_text(desc_text, TOOLTIP_WIDTH - TOOLTIP_PADDING * 2, font, 11)

	var tooltip_height: float = TOOLTIP_PADDING * 2 + name_size.y + 4
	if not desc_lines.is_empty():
		tooltip_height += desc_lines.size() * 14 + 4

	# Add duration info if applicable.
	if effect.has("remaining") and (effect["remaining"] as float) > 0.0:
		tooltip_height += 18

	# Position tooltip (below effect icons).
	var tooltip_pos: Vector2 = Vector2(0, ICON_SIZE + 10)

	# Background.
	var bg_color: Color = TOOLTIP_BG_COLOR
	bg_color.a *= _tooltip_alpha
	var tooltip_rect: Rect2 = Rect2(tooltip_pos, Vector2(TOOLTIP_WIDTH, tooltip_height))
	draw_rect(tooltip_rect, bg_color)

	# Border.
	var border_color: Color = TOOLTIP_BORDER_COLOR
	border_color.a *= _tooltip_alpha
	draw_rect(tooltip_rect, border_color, false, 1.0)

	# Content.
	var content_y: float = tooltip_pos.y + TOOLTIP_PADDING

	# Name.
	var name_color: Color = _get_colors_for_type(effect.get("type", EffectType.NEUTRAL) as EffectType)["main"] as Color
	name_color.a *= _tooltip_alpha
	draw_string(font, Vector2(tooltip_pos.x + TOOLTIP_PADDING, content_y + name_size.y), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, name_color)
	content_y += name_size.y + 8

	# Description.
	var desc_color: Color = TOOLTIP_DESC_COLOR
	desc_color.a *= _tooltip_alpha
	for line: String in desc_lines:
		draw_string(font, Vector2(tooltip_pos.x + TOOLTIP_PADDING, content_y + 11), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, desc_color)
		content_y += 14

	# Duration.
	if effect.has("remaining") and (effect["remaining"] as float) > 0.0:
		content_y += 4
		var remaining: float = effect["remaining"] as float
		var duration_text: String = "%.1fs remaining" % remaining
		var time_color: Color = WARNING_COLOR if remaining <= EXPIRY_WARNING_THRESHOLD else NEUTRAL_COLOR
		time_color.a *= _tooltip_alpha
		draw_string(font, Vector2(tooltip_pos.x + TOOLTIP_PADDING, content_y + 11), duration_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, time_color)


## Wrap text to fit width.
func _wrap_text(text: String, max_width: float, font: Font, font_size: int) -> Array[String]:
	var lines: Array[String] = []
	if text.is_empty():
		return lines

	var words: PackedStringArray = text.split(" ")
	var current_line: String = ""

	for word: String in words:
		var test_line: String = current_line + (" " if current_line != "" else "") + word
		var line_width: float = font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		if line_width <= max_width:
			current_line = test_line
		else:
			if current_line != "":
				lines.append(current_line)
			current_line = word

	if current_line != "":
		lines.append(current_line)

	return lines


## Get colors for effect type.
func _get_colors_for_type(effect_type: EffectType) -> Dictionary:
	match effect_type:
		EffectType.BUFF:
			return {"main": BUFF_COLOR, "glow": BUFF_GLOW}
		EffectType.DEBUFF:
			return {"main": DEBUFF_COLOR, "glow": DEBUFF_GLOW}
		EffectType.WARNING:
			return {"main": WARNING_COLOR, "glow": WARNING_GLOW}
		EffectType.SPECIAL:
			return {"main": SPECIAL_COLOR, "glow": SPECIAL_GLOW}
		_:
			return {"main": NEUTRAL_COLOR, "glow": NEUTRAL_GLOW}


## Remove effect internally.
func _remove_effect_internal(effect_id: String) -> void:
	_active_effects.erase(effect_id)
	if _hovered_effect == effect_id:
		_hovered_effect = ""
		_tooltip_target_alpha = 0.0


# ── Input Handling ───────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = (event as InputEventMouseMotion).position
		_update_hover_state(mouse_pos)


func _update_hover_state(mouse_pos: Vector2) -> void:
	var x_offset: float = 0.0
	var found_hover: String = ""

	var sorted_ids: Array = _active_effects.keys()
	sorted_ids.sort_custom(_sort_effects)

	var count: int = 0
	for effect_id in sorted_ids:
		if count >= MAX_VISIBLE_EFFECTS:
			break

		var icon_rect: Rect2 = Rect2(Vector2(x_offset, 0), Vector2(ICON_SIZE, ICON_SIZE))
		if icon_rect.has_point(mouse_pos):
			found_hover = effect_id as String
			break

		x_offset += ICON_SIZE + ICON_SPACING
		count += 1

	if found_hover != _hovered_effect:
		_hovered_effect = found_hover
		_tooltip_target_alpha = 1.0 if _hovered_effect != "" else 0.0


# ── Public API ───────────────────────────────────────────────────────────────

## Add or update a status effect.
func add_effect(
	effect_id: String,
	name: String,
	effect_type: EffectType = EffectType.NEUTRAL,
	duration: float = 0.0,
	icon: String = "?",
	description: String = "",
	stacks: int = 1
) -> void:
	var is_new: bool = not _active_effects.has(effect_id)

	var effect_data: Dictionary = {
		"name": name,
		"type": effect_type,
		"duration": duration,
		"remaining": duration,
		"icon": icon,
		"description": description,
		"stacks": stacks,
		"fade_in": 0.0 if is_new else 1.0,
		"fade_out": 1.0,
		"glow_phase": 0.0,
		"pulse_phase": 0.0,
	}

	# If effect exists, preserve animation state but update values.
	if not is_new:
		var existing: Dictionary = _active_effects[effect_id]
		effect_data["fade_in"] = existing.get("fade_in", 1.0) as float
		effect_data["glow_phase"] = existing.get("glow_phase", 0.0) as float

	_active_effects[effect_id] = effect_data

	if is_new:
		effect_applied.emit(effect_id)

	queue_redraw()


## Remove a status effect.
func remove_effect(effect_id: String) -> void:
	if _active_effects.has(effect_id):
		# Start fade out animation.
		_active_effects[effect_id]["fade_out"] = 1.0
		# Actually remove after fade.
		var timer: SceneTreeTimer = get_tree().create_timer(FADE_OUT_DURATION)
		timer.timeout.connect(_remove_effect_internal.bind(effect_id))


## Update effect stacks.
func set_effect_stacks(effect_id: String, stacks: int) -> void:
	if _active_effects.has(effect_id):
		_active_effects[effect_id]["stacks"] = maxi(stacks, 1)
		queue_redraw()


## Add stacks to an effect.
func add_effect_stacks(effect_id: String, additional_stacks: int = 1) -> void:
	if _active_effects.has(effect_id):
		var current: int = _active_effects[effect_id].get("stacks", 1) as int
		_active_effects[effect_id]["stacks"] = current + additional_stacks
		queue_redraw()


## Refresh effect duration.
func refresh_effect_duration(effect_id: String, new_duration: float = -1.0) -> void:
	if _active_effects.has(effect_id):
		var effect: Dictionary = _active_effects[effect_id]
		if new_duration > 0.0:
			effect["duration"] = new_duration
			effect["remaining"] = new_duration
		else:
			effect["remaining"] = effect["duration"] as float
		queue_redraw()


## Check if an effect is active.
func has_effect(effect_id: String) -> bool:
	return _active_effects.has(effect_id)


## Get remaining duration of an effect.
func get_effect_remaining(effect_id: String) -> float:
	if _active_effects.has(effect_id):
		return _active_effects[effect_id].get("remaining", 0.0) as float
	return 0.0


## Get stack count of an effect.
func get_effect_stacks(effect_id: String) -> int:
	if _active_effects.has(effect_id):
		return _active_effects[effect_id].get("stacks", 1) as int
	return 0


## Clear all effects.
func clear_all_effects() -> void:
	_active_effects.clear()
	_hovered_effect = ""
	_tooltip_alpha = 0.0
	_tooltip_target_alpha = 0.0
	queue_redraw()


## Get all active effect IDs.
func get_active_effect_ids() -> Array:
	return _active_effects.keys()
