# BattleZone Party - Component Guide

> Complete guide to using UI components with configuration, styling, and best practices.

---

## Table of Contents

1. [PremiumButton](#premiumbutton)
2. [AnimatedPanel](#animatedpanel)
3. [PremiumSlider](#premiumslider)
4. [PremiumTooltip](#premiumtooltip)
5. [PremiumToast](#premiumtoast)
6. [AnimatedDialog](#animateddialog)
7. [HUD Components](#hud-components)
8. [Form Components](#form-components)
9. [Best Practices](#best-practices)

---

## PremiumButton

A premium animated button with advanced visual effects including elastic hover, press feedback, particles, glow, and ripple effects.

### Basic Usage

```gdscript
# In your scene script
@onready var my_button: PremiumButton = $PremiumButton

func _ready():
    my_button.pressed.connect(_on_button_pressed)

func _on_button_pressed():
    print("Button clicked!")
```

### Configuration Options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `button_style` | `ButtonStyle` | `DEFAULT` | Visual style preset |
| `enable_hover_animation` | `bool` | `true` | Scale on hover |
| `enable_press_feedback` | `bool` | `true` | Squash on press |
| `enable_glow` | `bool` | `true` | Glow effect on hover |
| `enable_particles` | `bool` | `true` | Particle burst on press |
| `enable_ripple` | `bool` | `true` | Material-style ripple |
| `enable_sound` | `bool` | `true` | Sound feedback |
| `hover_scale` | `float` | `1.05` | Scale multiplier on hover |
| `press_scale` | `float` | `0.95` | Scale multiplier on press |
| `animation_duration` | `float` | `0.3` | Animation duration |
| `glow_intensity` | `float` | `1.5` | Glow brightness |

### Button Styles

```gdscript
enum ButtonStyle {
    DEFAULT,    # Neutral gray
    PRIMARY,    # Blue - main actions
    SECONDARY,  # Gray - secondary actions
    SUCCESS,    # Green - confirm/success
    DANGER,     # Red - destructive actions
    GHOST,      # Transparent with border
}
```

### Style Color Reference

| Style | Background Color | Use Case |
|-------|-----------------|----------|
| `DEFAULT` | `#3F4D59` | General purpose |
| `PRIMARY` | `#3380E6` | Primary actions (Play, Submit) |
| `SECONDARY` | `#666B73` | Secondary actions (Back, Cancel) |
| `SUCCESS` | `#33B34D` | Confirmations (Save, Accept) |
| `DANGER` | `#E63333` | Destructive (Delete, Quit) |
| `GHOST` | Transparent | Subtle actions |

### Styling Customization

```gdscript
# Create custom button programmatically
var button = PremiumButton.new()
button.text = "Custom Button"
button.button_style = PremiumButton.ButtonStyle.PRIMARY
button.hover_scale = 1.1
button.glow_intensity = 2.0
button.enable_particles = true
add_child(button)
```

### Visual Example

```
+---------------------------+
|                           |
|    [ Primary Button ]     |  <- Blue background, white text
|                           |
+---------------------------+

On Hover: Scale to 1.05x, glow appears
On Press: Scale to 0.95x, ripple effect, particles burst
```

### Best Practices

1. **Use appropriate styles** - PRIMARY for main actions, DANGER for destructive
2. **Disable effects on mobile** - Set `enable_particles = false` for performance
3. **Keep text concise** - Short, action-oriented text works best
4. **Add icons** - Use icon fonts or TextureRect children for clarity

---

## AnimatedPanel

A premium panel container with smooth entrance/exit animations. Perfect for menus, dialogs, and overlays.

### Basic Usage

```gdscript
@onready var panel: AnimatedPanel = $AnimatedPanel

func _ready():
    panel.show_completed.connect(_on_panel_shown)
    panel.hide_completed.connect(_on_panel_hidden)

func _show_menu():
    panel.show_panel()

func _hide_menu():
    panel.hide_panel()
```

### Configuration Options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `entrance_animation` | `AnimationType` | `SCALE` | How panel enters |
| `exit_animation` | `AnimationType` | `FADE` | How panel exits |
| `animation_duration` | `float` | `0.4` | Animation duration |
| `enable_blur_background` | `bool` | `true` | Dark overlay behind |
| `blur_background_alpha` | `float` | `0.7` | Overlay opacity |
| `auto_show` | `bool` | `false` | Show on ready |
| `show_delay` | `float` | `0.0` | Delay before auto-show |

### Animation Types

```gdscript
enum AnimationType {
    FADE,           # Simple fade in/out
    SCALE,          # Scale from center
    SLIDE_UP,       # Slide from bottom
    SLIDE_DOWN,     # Slide from top
    SLIDE_LEFT,     # Slide from right
    SLIDE_RIGHT,    # Slide from left
    BLUR_FADE,      # Fade with blur effect
    BOUNCE,         # Bounce entrance
    ELASTIC,        # Elastic easing
    ROTATE_SCALE,   # Rotate + scale combo
}
```

### Animation Combinations

| Entrance | Exit | Best For |
|----------|------|----------|
| `SCALE` | `FADE` | Dialogs, popups |
| `SLIDE_UP` | `SLIDE_DOWN` | Bottom sheets |
| `ELASTIC` | `SCALE` | Playful menus |
| `BLUR_FADE` | `BLUR_FADE` | Settings panels |
| `BOUNCE` | `FADE` | Achievements |

### Signals

| Signal | Description |
|--------|-------------|
| `show_completed` | Emitted when entrance animation finishes |
| `hide_completed` | Emitted when exit animation finishes |

### Methods

| Method | Description |
|--------|-------------|
| `show_panel()` | Show with entrance animation |
| `hide_panel()` | Hide with exit animation |
| `toggle()` | Toggle visibility |
| `is_panel_visible()` | Get visibility state |

### Code Example: Settings Menu

```gdscript
extends Control

@onready var settings_panel: AnimatedPanel = $SettingsPanel
@onready var settings_button: PremiumButton = $SettingsButton
@onready var close_button: PremiumButton = $SettingsPanel/CloseButton

func _ready():
    settings_button.pressed.connect(_on_settings_pressed)
    close_button.pressed.connect(_on_close_pressed)
    settings_panel.hide_completed.connect(_on_panel_closed)

    # Configure panel
    settings_panel.entrance_animation = AnimatedPanel.AnimationType.SLIDE_LEFT
    settings_panel.exit_animation = AnimatedPanel.AnimationType.SLIDE_RIGHT
    settings_panel.animation_duration = 0.3

func _on_settings_pressed():
    settings_panel.show_panel()

func _on_close_pressed():
    settings_panel.hide_panel()

func _on_panel_closed():
    print("Settings closed")
```

---

## PremiumSlider

AAA-quality slider with glow effects, value tooltip, spring physics, and smooth animations.

### Basic Usage

```gdscript
@onready var volume_slider: PremiumSlider = $VolumeSlider

func _ready():
    volume_slider.value = 0.8
    volume_slider.value_changed_signal.connect(_on_volume_changed)

func _on_volume_changed(new_value: float):
    AudioManager.set_master_volume(new_value)
```

### Configuration Options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `setting_key` | `String` | `""` | Key for change tracking |
| `min_value` | `float` | `0.0` | Minimum value |
| `max_value` | `float` | `1.0` | Maximum value |
| `value` | `float` | `0.5` | Current value |
| `step` | `float` | `0.0` | Snap step (0 = continuous) |
| `tick_values` | `Array` | `[]` | Values to show tick marks |
| `value_format` | `String` | `"%.2f"` | Printf format string |
| `show_percentage` | `bool` | `false` | Show as percentage |
| `enable_sounds` | `bool` | `true` | Sound feedback |
| `custom_gradient` | `Gradient` | `null` | Custom fill gradient |

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `value_changed_signal` | `new_value: float` | Value changed |
| `drag_started` | - | User started dragging |
| `drag_ended` | - | User stopped dragging |

### Methods

| Method | Parameters | Description |
|--------|------------|-------------|
| `set_value_animated(value, duration)` | `float, float` | Animate to value |
| `reset_to_default(default)` | `float` | Reset with animation |
| `set_tick_values(ticks)` | `Array` | Set tick mark positions |
| `get_normalized_value()` | - | Get 0-1 value |
| `set_normalized_value(value)` | `float` | Set from 0-1 value |

### Visual Features

```
                    [0.75]           <- Value tooltip (follows thumb)
    +------------------------------------------+
    |############------------|     O          |  <- Track with gradient fill
    +------------------------------------------+
                              ^                   <- Glowing thumb with spring physics
         |         |         |         |
        0.0       0.25      0.5       0.75   <- Tick marks
```

### Code Example: Audio Settings

```gdscript
func _setup_audio_sliders():
    # Master volume slider
    var master_slider = PremiumSlider.new()
    master_slider.min_value = 0.0
    master_slider.max_value = 1.0
    master_slider.value = AudioManager.master_volume
    master_slider.show_percentage = true
    master_slider.tick_values = [0.0, 0.25, 0.5, 0.75, 1.0]
    master_slider.value_changed_signal.connect(_on_master_changed)

    # Music volume with custom gradient
    var music_slider = PremiumSlider.new()
    var gradient = Gradient.new()
    gradient.add_point(0.0, Color.DARK_BLUE)
    gradient.add_point(1.0, Color.CYAN)
    music_slider.custom_gradient = gradient

    # SFX volume with steps
    var sfx_slider = PremiumSlider.new()
    sfx_slider.step = 0.1  # Snap to 10% increments
    sfx_slider.show_percentage = true
```

### Keyboard Support

| Key | Action |
|-----|--------|
| `Left/Down` | Decrease by step |
| `Right/Up` | Increase by step |
| `Home` | Jump to minimum |
| `End` | Jump to maximum |

---

## PremiumTooltip

Smart tooltip system with smooth cursor following, rich content, and adaptive positioning.

### Basic Usage

```gdscript
@onready var tooltip: PremiumTooltip = $PremiumTooltip
@onready var item_button: Button = $ItemButton

func _ready():
    tooltip.register_tooltip(item_button, "sword_item", {
        "title": "Legendary Sword",
        "description": "A powerful blade forged in [color=orange]dragon fire[/color].",
        "icon": "res://icons/sword.png",
        "stats": [
            {"icon": "res://icons/damage.png", "value": "+50 Damage", "color": Color.RED},
            {"icon": "res://icons/speed.png", "value": "+10% Speed", "color": Color.GREEN}
        ]
    })
```

### Configuration Options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `show_delay` | `float` | `0.3` | Delay before appearing |
| `follow_smoothness` | `float` | `8.0` | Cursor follow smoothness |
| `cursor_offset` | `Vector2` | `(20, 20)` | Distance from cursor |
| `max_width` | `float` | `400.0` | Max width before wrap |
| `padding` | `Vector2` | `(16, 12)` | Internal padding |

### Tooltip Data Structure

```gdscript
{
    "title": String,           # Bold header text
    "description": String,     # BBCode-enabled body text
    "icon": String,            # Path to icon texture
    "stats": [                 # Array of stat widgets
        {
            "icon": String,    # Stat icon path
            "value": String,   # Stat text
            "color": Color     # Text color
        }
    ],
    "custom_content": Callable # Returns Control node
}
```

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `tooltip_shown` | `tooltip_id: String` | Tooltip became visible |
| `tooltip_hidden` | `tooltip_id: String` | Tooltip was hidden |

### Methods

| Method | Description |
|--------|-------------|
| `register_tooltip(target, id, data)` | Register tooltip for control |
| `unregister_tooltip(id)` | Remove tooltip registration |
| `show_custom_tooltip(data, position)` | Show tooltip immediately |
| `hide_tooltip()` | Hide current tooltip |
| `create_stat_widget(icon, value, color)` | Create stat display |

### Rich Content Example

```gdscript
# BBCode formatting in description
tooltip.register_tooltip(ability_button, "fireball", {
    "title": "Fireball",
    "description": """
        Launch a ball of fire dealing [color=orange]50 damage[/color].

        [b]Cooldown:[/b] 3 seconds
        [b]Mana Cost:[/b] 25

        [i]"The flames of destruction!"[/i]
    """,
    "stats": [
        {"value": "50 DMG", "color": Color.ORANGE},
        {"value": "3s CD", "color": Color.LIGHT_BLUE}
    ]
})
```

### Custom Content Callback

```gdscript
tooltip.register_tooltip(weapon_slot, "custom_weapon", {
    "title": "Weapon Stats",
    "custom_content": func():
        var container = VBoxContainer.new()

        # Add custom progress bar
        var damage_bar = ProgressBar.new()
        damage_bar.value = 75
        damage_bar.custom_minimum_size = Vector2(200, 20)
        container.add_child(damage_bar)

        return container
})
```

---

## PremiumToast

Premium notification toast system. Access via `TransitionManager.notify_*()`.

### Basic Usage

```gdscript
# Show notifications via TransitionManager autoload
TransitionManager.notify_info("Game saved successfully")
TransitionManager.notify_success("Achievement unlocked!")
TransitionManager.notify_warning("Low health!")
TransitionManager.notify_error("Connection lost")
```

### Notification Types

```gdscript
enum ToastType {
    INFO,       # Blue - general information
    SUCCESS,    # Green - success messages
    WARNING,    # Yellow - warnings
    ERROR,      # Red - errors
    ACHIEVEMENT,# Gold - achievements
    LEVEL_UP,   # Purple - level ups
    ITEM,       # Cyan - new items
    CHALLENGE   # Orange - challenges
}
```

### Specialized Methods

```gdscript
# Achievement notification with special styling
TransitionManager.achievement_unlocked("First Blood", "Eliminate your first opponent")

# Level up with animation
TransitionManager.level_up(25)

# New item with rarity
TransitionManager.new_item("Legendary Sword", "legendary")

# Challenge complete with reward
TransitionManager.challenge_complete("Win 10 matches", "+500 XP")
```

### Notification Management

```gdscript
# Store notification ID for later dismissal
var toast_id = TransitionManager.notify_info("Processing...")

# Later, dismiss specific notification
TransitionManager.dismiss_notification(toast_id)

# Dismiss all notifications
TransitionManager.dismiss_all_notifications()
```

### Custom Duration

```gdscript
# Show for custom duration (seconds)
TransitionManager.notify("Long message", TransitionManager.Toast.INFO, 10.0)
```

---

## AnimatedDialog

Premium modal dialog system with animations. Access via `TransitionManager.dialog_*()`.

### Basic Usage

```gdscript
# Info dialog
TransitionManager.dialog_info("Welcome!", "Thanks for playing!")

# Confirmation dialog
TransitionManager.dialog_confirm(
    "Quit Game?",
    "Are you sure you want to quit?",
    "Quit",
    "Cancel"
)

# Connect to dialog signals
TransitionManager.connect_dialog_confirmed(func():
    get_tree().quit()
)

TransitionManager.connect_dialog_cancelled(func():
    print("Cancelled")
)
```

### Dialog Types

| Method | Use Case |
|--------|----------|
| `dialog_info(title, message, button)` | Information only |
| `dialog_confirm(title, message, confirm, cancel)` | Yes/No choices |
| `dialog_warning(title, message, button)` | Warning messages |
| `dialog_error(title, message, button)` | Error messages |
| `dialog_input(title, message, placeholder, confirm, cancel)` | Text input |

### Input Dialog

```gdscript
# Show input dialog
TransitionManager.dialog_input(
    "Enter Name",
    "Please enter your player name:",
    "Player1",
    "Save",
    "Cancel"
)

# Get input after confirmation
TransitionManager.connect_dialog_confirmed(func():
    var player_name = TransitionManager.get_dialog_input()
    print("Name: ", player_name)
)
```

### Dialog Management

```gdscript
# Close current dialog
TransitionManager.close_dialog()

# Close all open dialogs
TransitionManager.close_all_dialogs()
```

---

## HUD Components

### HealthBar Advanced

Premium health bar with smooth animations, damage flash, and regeneration effects.

```gdscript
@onready var health_bar: HealthBarAdvanced = $HealthBar

func take_damage(amount: float):
    health_bar.set_health(health_bar.current_health - amount)
    # Automatically shows damage flash and smooth animation

func heal(amount: float):
    health_bar.set_health(health_bar.current_health + amount)
    # Shows healing pulse effect
```

### Ammo Counter

```gdscript
@onready var ammo_counter: AmmoCounter = $AmmoCounter

func _on_shoot():
    ammo_counter.use_ammo(1)
    # Shows bullet fly-out animation

func _on_reload():
    ammo_counter.reload()
    # Shows reload animation
```

### Hit Marker

```gdscript
@onready var hit_marker: HitMarker = $HitMarker

func _on_enemy_hit(is_headshot: bool, is_kill: bool):
    if is_kill:
        hit_marker.show_kill_marker()
    elif is_headshot:
        hit_marker.show_headshot_marker()
    else:
        hit_marker.show_hit_marker()
```

### Damage Indicator

```gdscript
@onready var damage_indicator: DamageIndicator = $DamageIndicator

func _on_player_damaged(damage: float, direction: Vector3):
    damage_indicator.show_damage(damage, direction)
```

### Kill Feed

```gdscript
@onready var kill_feed: KillFeed = $KillFeed

func _on_player_killed(killer: String, victim: String, weapon: String):
    kill_feed.add_kill(killer, victim, weapon)
```

### Minimap

```gdscript
@onready var minimap: Minimap = $Minimap

func _process(delta):
    minimap.update_player_position(player.global_position)
    minimap.update_player_rotation(player.rotation.y)
```

---

## Form Components

### PremiumTextInput

```gdscript
@onready var name_input: PremiumTextInput = $NameInput

func _ready():
    name_input.placeholder = "Enter your name..."
    name_input.max_length = 20
    name_input.text_submitted.connect(_on_name_submitted)
```

### NumberSpinner

```gdscript
@onready var count_spinner: NumberSpinner = $CountSpinner

func _ready():
    count_spinner.min_value = 1
    count_spinner.max_value = 10
    count_spinner.step = 1
    count_spinner.value = 4
```

### RatingStars

```gdscript
@onready var rating: RatingStars = $Rating

func _ready():
    rating.max_stars = 5
    rating.allow_half = true
    rating.rating_changed.connect(_on_rating_changed)
```

### SearchBar

```gdscript
@onready var search: SearchBarPremium = $SearchBar

func _ready():
    search.placeholder = "Search players..."
    search.search_submitted.connect(_on_search)
    search.text_changed.connect(_on_search_preview)
```

### MultiSelect

```gdscript
@onready var mode_select: MultiSelect = $ModeSelect

func _ready():
    mode_select.options = ["Deathmatch", "Team Battle", "Capture Flag"]
    mode_select.max_selections = 2
    mode_select.selection_changed.connect(_on_modes_selected)
```

### DateTimePicker

```gdscript
@onready var schedule: DateTimePicker = $SchedulePicker

func _ready():
    schedule.min_date = Time.get_datetime_dict_from_system()
    schedule.datetime_selected.connect(_on_schedule_set)
```

---

## Best Practices

### 1. Performance Optimization

```gdscript
# Disable expensive effects on mobile
func _configure_for_mobile():
    for button in get_tree().get_nodes_in_group("premium_buttons"):
        button.enable_particles = false
        button.enable_glow = false
        button.enable_ripple = false
```

### 2. Consistent Styling

```gdscript
# Create a style helper function
func apply_primary_style(button: PremiumButton):
    button.button_style = PremiumButton.ButtonStyle.PRIMARY
    button.hover_scale = 1.08
    button.animation_duration = 0.25
```

### 3. Accessibility

```gdscript
# Ensure keyboard navigation
func _ready():
    # Set up focus chain
    play_button.focus_neighbor_bottom = settings_button
    settings_button.focus_neighbor_top = play_button

    # Initial focus
    play_button.grab_focus()
```

### 4. Responsive Layout

```gdscript
func _on_viewport_size_changed():
    var viewport_size = get_viewport().get_visible_rect().size

    if viewport_size.x < 600:
        # Mobile layout
        panel.entrance_animation = AnimatedPanel.AnimationType.SLIDE_UP
    else:
        # Desktop layout
        panel.entrance_animation = AnimatedPanel.AnimationType.SCALE
```

### 5. Sound Feedback

```gdscript
# Ensure all interactive elements have sound
func _setup_sounds():
    for button in get_tree().get_nodes_in_group("buttons"):
        if button is PremiumButton:
            button.enable_sound = true
```

### 6. Loading States

```gdscript
# Show loading state during async operations
async func load_data():
    loading_panel.show_panel()
    submit_button.disabled = true

    var result = await fetch_data()

    loading_panel.hide_panel()
    submit_button.disabled = false
```

### 7. Error Handling

```gdscript
# Always provide feedback for errors
func _on_submit_failed(error: String):
    submit_button.button_style = PremiumButton.ButtonStyle.DANGER
    UIAnimator.shake(submit_button, 10.0, 0.3)
    TransitionManager.notify_error(error)

    await get_tree().create_timer(1.0).timeout
    submit_button.button_style = PremiumButton.ButtonStyle.PRIMARY
```

### 8. Animation Coordination

```gdscript
# Coordinate multiple animations
func show_results_screen():
    # Stagger element entrances
    await UIAnimator.fade_in(background).finished
    await get_tree().create_timer(0.1).timeout

    UIAnimator.cascade_entrance([title, score, buttons], 0.1)
```

---

## Component Compatibility

| Component | Control | Node2D | Works with UIAnimator |
|-----------|---------|--------|----------------------|
| PremiumButton | Yes | No | Yes |
| AnimatedPanel | Yes | No | Limited |
| PremiumSlider | Yes | No | No (self-animated) |
| PremiumTooltip | CanvasLayer | - | No |
| PremiumToast | CanvasLayer | - | No |

---

## Theme Integration

All components support Godot's theme system:

```gdscript
# Apply custom theme
var theme = preload("res://themes/custom_theme.tres")
panel.theme = theme

# Override specific colors
button.add_theme_color_override("font_color", Color.WHITE)
button.add_theme_font_override("font", custom_font)
```

---

## Version Compatibility

| Component | Godot 4.2+ | Godot 4.1 | Godot 4.0 |
|-----------|------------|-----------|-----------|
| PremiumButton | Full | Full | Limited |
| AnimatedPanel | Full | Full | Full |
| PremiumSlider | Full | Full | Limited |
| PremiumTooltip | Full | Full | Full |
