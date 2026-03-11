# BattleZone Party - API Reference

> Complete documentation for all public APIs, functions, signals, and properties.

---

## Table of Contents

1. [UIAnimator](#uianimator)
2. [UIEasing](#uieasing)
3. [TweenExtensions](#tweenextensions)
4. [AudioManager](#audiomanager)
5. [TransitionManager](#transitionmanager)
6. [PerformanceManager](#performancemanager)
7. [ParticleEffectsManager](#particleeffectsmanager)
8. [Shader APIs](#shader-apis)

---

## UIAnimator

The global animation system providing AAA-quality UI animations. Access via the `UIAnimator` autoload singleton.

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `animation_started` | `node: Node, animation_type: String` | Emitted when an animation begins |
| `animation_completed` | `node: Node, animation_type: String` | Emitted when an animation finishes |
| `animation_interrupted` | `node: Node, animation_type: String` | Emitted when an animation is cancelled |
| `performance_optimized` | `quality_level: float` | Emitted when quality is auto-adjusted |
| `queue_empty` | - | Emitted when animation queue is empty |

### Enums

#### Priority
```gdscript
enum Priority {
    LOW = 0,      # Can be interrupted by anything
    NORMAL = 1,   # Standard UI animations
    HIGH = 2,     # Important feedback animations
    CRITICAL = 3, # Must complete (error states, etc)
}
```

#### Direction
```gdscript
enum Direction {
    LEFT,
    RIGHT,
    UP,
    DOWN,
    CENTER,  # Scale from center
}
```

#### AnimationCategory
```gdscript
enum AnimationCategory {
    ENTRANCE,
    EXIT,
    FEEDBACK,
    TRANSITION,
    LOOP,
}
```

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `DURATION_INSTANT` | `0.08` | Ultra-fast animations |
| `DURATION_QUICK` | `0.15` | Quick response animations |
| `DURATION_NORMAL` | `0.25` | Standard animation duration |
| `DURATION_SMOOTH` | `0.4` | Smooth, deliberate animations |
| `DURATION_DRAMATIC` | `0.6` | Dramatic emphasis animations |
| `SCALE_NORMAL` | `Vector2.ONE` | Normal scale |
| `SCALE_HOVER` | `Vector2(1.08, 1.08)` | Hover state scale |
| `SCALE_PRESS` | `Vector2(0.92, 0.92)` | Pressed state scale |
| `MAX_CONCURRENT_ANIMATIONS` | `50` | Maximum simultaneous animations |

---

### Core Animation Functions

#### fade_in()

Fades a node in from transparent to opaque.

```gdscript
func fade_in(
    node: Node,
    duration: float = DURATION_NORMAL,
    delay: float = 0.0,
    easing: String = "quad_out"
) -> Tween
```

**Parameters:**
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `node` | `Node` | - | The node to animate (must be CanvasItem) |
| `duration` | `float` | `0.25` | Animation duration in seconds |
| `delay` | `float` | `0.0` | Delay before animation starts |
| `easing` | `String` | `"quad_out"` | Easing curve name |

**Returns:** `Tween` - The tween controlling the animation

**Example:**
```gdscript
# Basic fade in
UIAnimator.fade_in($Panel)

# Fade in with delay and custom duration
UIAnimator.fade_in($Panel, 0.5, 0.2, "expo_out")

# Chain with await
await UIAnimator.fade_in($Panel).finished
print("Fade complete!")
```

**Common Pitfalls:**
- Node must have a `modulate` property (Control or Node2D)
- Node is automatically set to `visible = true`
- Original alpha is stored and can be restored

**Performance Notes:**
- Low overhead, uses single property tween
- Duration is scaled by quality level for performance

---

#### fade_out()

Fades a node out from opaque to transparent.

```gdscript
func fade_out(
    node: Node,
    duration: float = DURATION_NORMAL,
    delay: float = 0.0,
    easing: String = "quad_in",
    hide_on_complete: bool = true
) -> Tween
```

**Parameters:**
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `node` | `Node` | - | The node to animate |
| `duration` | `float` | `0.25` | Animation duration |
| `delay` | `float` | `0.0` | Delay before animation |
| `easing` | `String` | `"quad_in"` | Easing curve |
| `hide_on_complete` | `bool` | `true` | Set visible=false when done |

**Returns:** `Tween`

**Example:**
```gdscript
# Fade out and hide
UIAnimator.fade_out($Panel)

# Fade out but keep visible (for re-animation)
UIAnimator.fade_out($Panel, 0.3, 0.0, "quad_in", false)
```

---

#### scale_bounce()

Scales a node with a bouncy elastic effect.

```gdscript
func scale_bounce(
    node: Node,
    target_scale: Vector2 = Vector2.ONE,
    duration: float = DURATION_NORMAL,
    easing: String = "elastic_out"
) -> Tween
```

**Parameters:**
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `node` | `Node` | - | Node to scale |
| `target_scale` | `Vector2` | `Vector2.ONE` | Final scale value |
| `duration` | `float` | `0.25` | Animation duration |
| `easing` | `String` | `"elastic_out"` | Easing curve |

**Example:**
```gdscript
# Bounce to normal scale
UIAnimator.scale_bounce($Button)

# Bounce to larger size
UIAnimator.scale_bounce($Button, Vector2(1.2, 1.2))

# Quick bounce with back easing
UIAnimator.scale_bounce($Icon, Vector2.ONE, 0.15, "back_out")
```

---

#### shake()

Shakes a node for error feedback or attention-grabbing.

```gdscript
func shake(
    node: Node,
    intensity: float = 10.0,
    duration: float = 0.5,
    frequency: float = 25.0
) -> Tween
```

**Parameters:**
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `node` | `Node` | - | Node to shake |
| `intensity` | `float` | `10.0` | Shake magnitude in pixels |
| `duration` | `float` | `0.5` | Total shake duration |
| `frequency` | `float` | `25.0` | Shakes per second |

**Example:**
```gdscript
# Error shake on invalid input
if not valid:
    UIAnimator.shake($InputField, 12.0, 0.4)

# Subtle attention shake
UIAnimator.shake($Notification, 5.0, 0.3, 15.0)
```

**Performance Notes:**
- Shake count is scaled by quality level
- Minimum 3 shakes guaranteed for visibility

---

#### pulse_glow()

Creates a pulsing glow effect on a node.

```gdscript
func pulse_glow(
    node: Node,
    glow_color: Color = Color.WHITE,
    speed: float = 1.0,
    intensity: float = 0.3,
    loops: int = -1
) -> Tween
```

**Parameters:**
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `node` | `Node` | - | Node to glow |
| `glow_color` | `Color` | `Color.WHITE` | Color to pulse toward |
| `speed` | `float` | `1.0` | Pulse speed multiplier |
| `intensity` | `float` | `0.3` | Glow blend intensity |
| `loops` | `int` | `-1` | Loop count (-1 = infinite) |

**Example:**
```gdscript
# Infinite golden pulse
UIAnimator.pulse_glow($Highlight, Color.GOLD, 1.5, 0.4)

# Three red warning pulses
UIAnimator.pulse_glow($Warning, Color.RED, 2.0, 0.5, 3)
```

---

#### slide_in()

Slides a node in from a specified direction.

```gdscript
func slide_in(
    node: Node,
    direction: Direction = Direction.LEFT,
    distance: float = 100.0,
    duration: float = DURATION_SMOOTH,
    easing: String = "expo_out"
) -> Tween
```

**Parameters:**
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `node` | `Node` | - | Node to slide |
| `direction` | `Direction` | `LEFT` | Direction to slide from |
| `distance` | `float` | `100.0` | Slide distance in pixels |
| `duration` | `float` | `0.4` | Animation duration |
| `easing` | `String` | `"expo_out"` | Easing curve |

**Example:**
```gdscript
# Slide menu in from left
UIAnimator.slide_in($SideMenu, UIAnimator.Direction.LEFT, 200)

# Slide notification from top
UIAnimator.slide_in($Toast, UIAnimator.Direction.UP, 80, 0.3)
```

---

#### slide_out()

Slides a node out in a specified direction.

```gdscript
func slide_out(
    node: Node,
    direction: Direction = Direction.LEFT,
    distance: float = 100.0,
    duration: float = DURATION_SMOOTH,
    easing: String = "expo_in",
    hide_on_complete: bool = true
) -> Tween
```

**Example:**
```gdscript
# Slide menu out to left
UIAnimator.slide_out($SideMenu, UIAnimator.Direction.LEFT, 200)
```

---

#### pop_in()

Pops a node in with a scale-from-zero effect.

```gdscript
func pop_in(
    node: Node,
    duration: float = DURATION_SMOOTH,
    easing: String = "elastic_out"
) -> Tween
```

**Example:**
```gdscript
# Pop in a modal dialog
UIAnimator.pop_in($Dialog)

# Quick pop for small elements
UIAnimator.pop_in($Icon, 0.2, "back_out")
```

---

#### pop_out()

Pops a node out by scaling to zero.

```gdscript
func pop_out(
    node: Node,
    duration: float = DURATION_NORMAL,
    easing: String = "back_in",
    hide_on_complete: bool = true
) -> Tween
```

---

#### bounce()

Applies a quick bounce effect.

```gdscript
func bounce(
    node: Node,
    scale_amount: float = 0.15,
    duration: float = DURATION_NORMAL
) -> Tween
```

**Example:**
```gdscript
# Bounce on click
UIAnimator.bounce($Button, 0.2, 0.3)
```

---

#### wiggle()

Applies a wiggle/jiggle rotation effect.

```gdscript
func wiggle(
    node: Node,
    angle: float = 5.0,
    duration: float = DURATION_SMOOTH,
    cycles: int = 3
) -> Tween
```

**Example:**
```gdscript
# Wiggle notification bell
UIAnimator.wiggle($BellIcon, 10.0, 0.5, 4)
```

---

#### typewriter()

Types text into a label character by character.

```gdscript
func typewriter(
    label: Label,
    text: String,
    duration: float = 2.0,
    sound_per_char: bool = true
) -> Tween
```

**Example:**
```gdscript
# Type dialog text
UIAnimator.typewriter($DialogLabel, "Hello, adventurer!", 1.5)
```

---

#### heartbeat()

Creates a heartbeat pulse animation.

```gdscript
func heartbeat(
    node: Node,
    scale_amount: float = 0.1,
    duration: float = 1.0,
    loops: int = -1
) -> Tween
```

**Example:**
```gdscript
# Heartbeat on health indicator
UIAnimator.heartbeat($HeartIcon, 0.15, 0.8)
```

---

#### idle_float()

Creates a gentle floating animation.

```gdscript
func idle_float(
    node: Node,
    amplitude: float = 5.0,
    duration: float = 3.0,
    loops: int = -1
) -> Tween
```

**Example:**
```gdscript
# Float a magical item
UIAnimator.idle_float($MagicOrb, 8.0, 2.5)
```

---

#### glitch()

Creates a digital glitch effect.

```gdscript
func glitch(
    node: Node,
    intensity: float = 10.0,
    duration: float = 0.5,
    color_shift: bool = true
) -> Tween
```

**Example:**
```gdscript
# Glitch effect on damage
UIAnimator.glitch($HUD, 15.0, 0.3, true)
```

---

### Button Animations

#### button_hover_enter()

```gdscript
func button_hover_enter(button: Control, duration: float = DURATION_QUICK) -> Tween
```

#### button_hover_exit()

```gdscript
func button_hover_exit(button: Control, duration: float = DURATION_QUICK) -> Tween
```

#### button_press()

```gdscript
func button_press(button: Control) -> Tween
```

**Example:**
```gdscript
# Connect to button signals
func _on_button_mouse_entered():
    UIAnimator.button_hover_enter($Button)

func _on_button_mouse_exited():
    UIAnimator.button_hover_exit($Button)

func _on_button_pressed():
    UIAnimator.button_press($Button)
```

---

### Panel Animations

#### panel_enter_3d()

```gdscript
func panel_enter_3d(panel: Control, from_direction: Vector2 = Vector2.RIGHT) -> Tween
```

#### panel_exit_zoom()

```gdscript
func panel_exit_zoom(panel: Control, zoom_direction: float = 1.15) -> Tween
```

#### panel_reveal_staggered()

```gdscript
func panel_reveal_staggered(panel: Control, stagger_delay: float = 0.05) -> void
```

**Example:**
```gdscript
# Reveal panel with staggered children
UIAnimator.panel_reveal_staggered($SettingsPanel, 0.08)
```

---

### Transition Animations

#### transition_zoom_out()

```gdscript
func transition_zoom_out(root: Control) -> Tween
```

#### transition_slide_out()

```gdscript
func transition_slide_out(root: Control, direction: Vector2 = Vector2.LEFT) -> Tween
```

#### crossfade()

```gdscript
func crossfade(from_control: Control, to_control: Control, duration: float = DURATION_SMOOTH) -> Tween
```

#### cascade_entrance()

```gdscript
func cascade_entrance(items: Array, delay_per_item: float = 0.05, parent: Node = null) -> void
```

**Example:**
```gdscript
# Cascade menu items
var buttons = [$Play, $Settings, $Quit]
UIAnimator.cascade_entrance(buttons, 0.08)
```

---

### Feedback Animations

#### success_pop()

```gdscript
func success_pop(control: Control) -> Tween
```

#### attention_pulse()

```gdscript
func attention_pulse(control: Control, pulse_color: Color = Color(1.0, 0.8, 0.2), loops: int = 3) -> Tween
```

#### error_indication()

```gdscript
func error_indication(control: Control, flash_color: Color = Color(1.0, 0.3, 0.3)) -> Tween
```

---

### Animation Management

#### stop_animations()

Stops all animations on a specific node.

```gdscript
func stop_animations(node: Node, restore_original: bool = false) -> void
```

#### stop_all_animations()

Stops all active animations globally.

```gdscript
func stop_all_animations(restore_original: bool = false) -> void
```

#### pause_animations()

```gdscript
func pause_animations(node: Node) -> void
```

#### resume_animations()

```gdscript
func resume_animations(node: Node) -> void
```

#### is_animating()

```gdscript
func is_animating(node: Node) -> bool
```

#### reset_state()

Resets a control to default state.

```gdscript
func reset_state(control: Control) -> void
```

---

### Animation Sequence Builder

Create complex animation sequences with the fluent builder API.

```gdscript
func sequence() -> AnimationSequence
```

**AnimationSequence Methods:**

| Method | Description |
|--------|-------------|
| `then_fade_in(node, duration, easing)` | Chain a fade in |
| `then_fade_out(node, duration, easing)` | Chain a fade out |
| `then_scale(node, target_scale, duration, easing)` | Chain a scale |
| `then_slide_in(node, direction, distance, duration)` | Chain a slide in |
| `then_slide_out(node, direction, distance, duration)` | Chain a slide out |
| `then_shake(node, intensity, duration)` | Chain a shake |
| `then_bounce(node, scale_amount, duration)` | Chain a bounce |
| `then_pop_in(node, duration)` | Chain a pop in |
| `then_pop_out(node, duration)` | Chain a pop out |
| `then_color(node, target_color, duration)` | Chain a color transition |
| `wait(duration)` | Add a delay |
| `parallel_fade_in(node, duration)` | Run in parallel |
| `parallel_scale(node, target_scale, duration)` | Run in parallel |
| `then_callback(callable)` | Execute callback |
| `on_complete(callable)` | Set completion callback |
| `play()` | Start the sequence |
| `stop()` | Stop the sequence |

**Example:**
```gdscript
# Complex entrance animation
UIAnimator.sequence() \
    .then_fade_in($Background, 0.3) \
    .wait(0.1) \
    .then_pop_in($Logo, 0.4) \
    .parallel_fade_in($Subtitle, 0.3) \
    .wait(0.2) \
    .then_slide_in($Menu, UIAnimator.Direction.DOWN, 50) \
    .then_callback(func(): print("Animation complete!")) \
    .play()
```

---

### Performance Functions

#### set_quality_level()

```gdscript
func set_quality_level(quality: float) -> void  # 0.0 to 1.0
```

#### get_quality_level()

```gdscript
func get_quality_level() -> float
```

#### get_performance_stats()

```gdscript
func get_performance_stats() -> Dictionary
# Returns: {
#     "active_animations": int,
#     "quality_level": float,
#     "average_frame_time_ms": float,
#     "estimated_fps": float
# }
```

#### enable_profiling()

```gdscript
func enable_profiling(enabled: bool = true) -> void
```

---

### Utility Functions

#### calculate_parallax_offset()

```gdscript
func calculate_parallax_offset(viewport_size: Vector2, mouse_pos: Vector2, depth: float = 1.0) -> Vector2
```

#### calculate_magnetic_offset()

```gdscript
func calculate_magnetic_offset(control: Control, cursor_pos: Vector2, radius: float = 100.0, strength: float = 0.3) -> Vector2
```

#### apply_parallax_layers()

```gdscript
func apply_parallax_layers(layers: Array, mouse_pos: Vector2, viewport_size: Vector2) -> void
```

---

## UIEasing

Static class providing comprehensive easing functions for animations.

### Basic Easing Functions

All easing functions take a `t: float` parameter (0.0 to 1.0) and return the eased value.

#### Linear
```gdscript
static func linear(t: float) -> float
```

#### Quadratic
```gdscript
static func quad_in(t: float) -> float
static func quad_out(t: float) -> float
static func quad_in_out(t: float) -> float
```

#### Cubic
```gdscript
static func cubic_in(t: float) -> float
static func cubic_out(t: float) -> float
static func cubic_in_out(t: float) -> float
```

#### Quartic
```gdscript
static func quart_in(t: float) -> float
static func quart_out(t: float) -> float
static func quart_in_out(t: float) -> float
```

#### Quintic
```gdscript
static func quint_in(t: float) -> float
static func quint_out(t: float) -> float
static func quint_in_out(t: float) -> float
```

#### Sine
```gdscript
static func sine_in(t: float) -> float
static func sine_out(t: float) -> float
static func sine_in_out(t: float) -> float
```

#### Exponential
```gdscript
static func expo_in(t: float) -> float
static func expo_out(t: float) -> float
static func expo_in_out(t: float) -> float
```

#### Circular
```gdscript
static func circ_in(t: float) -> float
static func circ_out(t: float) -> float
static func circ_in_out(t: float) -> float
```

#### Elastic
```gdscript
static func elastic_in(t: float) -> float
static func elastic_out(t: float) -> float
static func elastic_in_out(t: float) -> float
static func elastic_custom(t: float, amplitude: float = 1.0, period: float = 0.3) -> float
```

#### Back (Overshoot)
```gdscript
static func back_in(t: float) -> float
static func back_out(t: float) -> float
static func back_in_out(t: float) -> float
static func back_custom(t: float, overshoot: float = 1.70158) -> float
```

#### Bounce
```gdscript
static func bounce_in(t: float) -> float
static func bounce_out(t: float) -> float
static func bounce_in_out(t: float) -> float
```

### Spring Physics

```gdscript
static func spring(t: float, damping: float = 0.4, frequency: float = 6.0) -> float
static func spring_preset(t: float, preset_name: String) -> float
static func spring_with_velocity(t: float, damping: float = 0.4, frequency: float = 6.0) -> Dictionary
```

**Spring Presets:**
- `"gentle"` - Smooth, minimal overshoot
- `"bouncy"` - Playful bounce
- `"stiff"` - Quick, snappy response
- `"wobbly"` - Extended oscillation
- `"slow"` - Relaxed motion

**Example:**
```gdscript
var value = UIEasing.spring(progress, 0.3, 8.0)
var preset_value = UIEasing.spring_preset(progress, "bouncy")
```

### Bezier Curves

```gdscript
static func bezier(t: float, x1: float, y1: float, x2: float, y2: float) -> float
static func bezier_preset(t: float, preset_name: String) -> float
```

**Bezier Presets:**
- `"ease"` - Standard ease
- `"ease_in"` - Slow start
- `"ease_out"` - Slow end
- `"ease_in_out"` - Slow start and end
- `"material_standard"` - Material Design standard
- `"material_decelerate"` - Material deceleration
- `"material_accelerate"` - Material acceleration
- `"swift_out"` - iOS-style swift out
- `"anticipate"` - Pull back before action
- `"overshoot"` - Overshoot target

**Example:**
```gdscript
# CSS-style cubic bezier
var value = UIEasing.bezier(t, 0.25, 0.1, 0.25, 1.0)

# Using preset
var material_value = UIEasing.bezier_preset(t, "material_standard")
```

### Special Easing

```gdscript
static func smooth_step(t: float) -> float
static func smoother_step(t: float) -> float
static func step(t: float, threshold: float = 0.5) -> float
static func triangle(t: float) -> float
static func sine_wave(t: float, frequency: float = 1.0) -> float
```

### Utility Functions

```gdscript
static func blend(ease1: float, ease2: float, blend_factor: float) -> float
static func reverse(eased_value: float) -> float
static func mirror(t: float, ease_func: Callable) -> float
static func repeat_ease(t: float, repeats: int, ease_func: Callable) -> float
static func get_easing(name: String) -> Callable
static func ease_by_name(t: float, name: String) -> float
```

**Example:**
```gdscript
# Get easing function by name
var ease_func = UIEasing.get_easing("elastic_out")
var value = ease_func.call(0.5)

# Apply easing by name
var eased = UIEasing.ease_by_name(t, "back_out")
```

---

## TweenExtensions

Static utility class for advanced tween operations.

### Fade Animations

```gdscript
static func fade_in_out(
    node: CanvasItem,
    fade_in_duration: float = 0.3,
    hold_duration: float = 1.0,
    fade_out_duration: float = 0.3
) -> Tween

static func crossfade_nodes(
    from_node: CanvasItem,
    to_node: CanvasItem,
    duration: float = 0.5
) -> Tween

static func blink(
    node: CanvasItem,
    times: int = 3,
    on_duration: float = 0.1,
    off_duration: float = 0.1
) -> Tween
```

### Scale Animations

```gdscript
static func scale_pop(
    node: Node,
    peak_scale: Vector2 = Vector2(1.2, 1.2),
    duration: float = 0.3
) -> Tween

static func squash_stretch(
    node: Node,
    squash_amount: float = 0.2,
    duration: float = 0.4
) -> Tween

static func scale_breathe(
    node: Node,
    breath_amount: float = 0.05,
    duration: float = 2.0,
    loops: int = -1
) -> Tween
```

### Position Animations

```gdscript
static func slide_from(
    node: Node,
    direction: Vector2,
    distance: float = 100.0,
    duration: float = 0.4
) -> Tween

static func slide_to(
    node: Node,
    direction: Vector2,
    distance: float = 100.0,
    duration: float = 0.4
) -> Tween

static func bounce_position(
    node: Node,
    height: float = 20.0,
    duration: float = 0.5,
    bounces: int = 2
) -> Tween

static func orbit(
    node: Node,
    center: Vector2,
    radius: float = 50.0,
    duration: float = 2.0,
    loops: int = -1
) -> Tween
```

### Rotation Animations

```gdscript
static func spin(
    node: Node,
    rotations: float = 1.0,
    duration: float = 0.5,
    clockwise: bool = true
) -> Tween

static func wobble(
    node: Node,
    max_angle: float = 15.0,
    duration: float = 0.5,
    wobbles: int = 3
) -> Tween
```

### Color Animations

```gdscript
static func color_flash(
    node: CanvasItem,
    flash_color: Color,
    duration: float = 0.2
) -> Tween

static func color_rainbow(
    node: CanvasItem,
    duration: float = 2.0,
    saturation: float = 0.8,
    loops: int = -1
) -> Tween

static func color_gradient(
    node: CanvasItem,
    from_color: Color,
    to_color: Color,
    duration: float = 1.0,
    ping_pong: bool = false,
    loops: int = 1
) -> Tween
```

### Complex Animations

```gdscript
static func entrance_complex(
    node: CanvasItem,
    from_direction: Vector2 = Vector2.DOWN,
    distance: float = 50.0,
    duration: float = 0.5
) -> Tween

static func exit_complex(
    node: CanvasItem,
    to_direction: Vector2 = Vector2.DOWN,
    distance: float = 50.0,
    duration: float = 0.4
) -> Tween

static func grab_attention(
    node: CanvasItem,
    duration: float = 1.0
) -> Tween
```

### Composition Utilities

```gdscript
static func parallel_tweens(node: Node, configs: Array[AnimationConfig]) -> Tween
static func sequential_tweens(node: Node, configs: Array[AnimationConfig]) -> Tween
static func chain(node: Node, animations: Array[Callable], delays: Array[float] = []) -> void
```

---

## AudioManager

Global audio management singleton for music, SFX, and spatial audio.

### Signals

| Signal | Description |
|--------|-------------|
| `settings_changed` | Volume or mute settings changed |
| `spatial_sound_spawned(player, key, position)` | 3D sound created |
| `music_intensity_changed(new_intensity)` | Music intensity changed |

### Enums

#### SFXCategory
```gdscript
enum SFXCategory {
    UI,
    GAMEPLAY,
    IMPACT,
    AMBIENT,
    VOICE,
    FOOTSTEPS,
    WEAPON,
    EXPLOSION,
    MUSIC_STINGER
}
```

#### AudioPriority
```gdscript
enum AudioPriority {
    LOW = 0,       # Ambient sounds, particle effects
    NORMAL = 1,    # Footsteps, pickups
    HIGH = 2,      # Weapon fire, impacts
    CRITICAL = 3,  # Voice lines, explosions
    ESSENTIAL = 4  # UI feedback (never culled)
}
```

#### SurfaceType
```gdscript
enum SurfaceType {
    DEFAULT, CONCRETE, METAL, WOOD, GRASS,
    SAND, WATER, GRAVEL, CARPET
}
```

### Music Functions

```gdscript
func play_music(key: String, fade_duration: float = 1.0) -> void
func stop_music(fade_duration: float = 1.0) -> void
func set_music_intensity(intensity: float) -> void
```

### SFX Functions

```gdscript
func play_sfx(key: String, volume_db: float = 0.0) -> AudioStreamPlayer

func play_sfx_3d(
    key: String,
    position: Vector3,
    volume_db: float = 0.0,
    priority: AudioPriority = AudioPriority.NORMAL
) -> AudioStreamPlayer3D

func play_sfx_3d_advanced(
    key: String,
    position: Vector3,
    config: Dictionary = {}
) -> AudioStreamPlayer3D
```

**Config Dictionary Options:**
```gdscript
{
    "volume_db": 0.0,
    "priority": AudioPriority.NORMAL,
    "max_distance": 50.0,
    "unit_size": 2.0,
    "pitch_scale": 1.0,
    "pitch_variance": 0.0,
    "doppler": true,
    "attenuation_model": AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
}
```

### Specialized Sound Functions

```gdscript
func play_weapon_fire(weapon_key: String, position: Vector3, shooter_is_local: bool = false) -> AudioStreamPlayer3D
func play_footstep(position: Vector3, surface: SurfaceType = SurfaceType.DEFAULT) -> AudioStreamPlayer3D
func play_explosion(position: Vector3, size: float = 1.0) -> AudioStreamPlayer3D
func play_voice(key: String, position: Vector3) -> AudioStreamPlayer3D
func play_impact(position: Vector3, surface: SurfaceType = SurfaceType.DEFAULT, intensity: float = 1.0) -> AudioStreamPlayer3D
func play_ambient_3d(key: String, position: Vector3, volume_db: float = 0.0) -> AudioStreamPlayer3D
```

### Volume Control

```gdscript
func set_master_volume(value: float) -> void  # 0.0 - 1.0
func set_music_volume(value: float) -> void
func set_sfx_volume(value: float) -> void
func set_ambient_volume(value: float) -> void
func set_voice_volume(value: float) -> void
func set_category_volume_db(category: SFXCategory, db: float) -> void
func toggle_mute() -> void
```

### Registration

```gdscript
func register_music(key: String, stream: AudioStream) -> void
func register_sfx(key: String, stream: AudioStream, category: SFXCategory = SFXCategory.GAMEPLAY) -> void
func register_sfx_with_priority(key: String, stream: AudioStream, category: SFXCategory, priority: AudioPriority) -> void
func register_sfx_attenuation(key: String, max_distance: float, unit_size: float, attenuation_model: int = ...) -> void
func register_surface_sound(surface: SurfaceType, sound_type: String, stream: AudioStream) -> void
```

### Settings Persistence

```gdscript
func save_settings() -> void
func load_settings() -> void
```

### Performance Monitoring

```gdscript
func get_audio_thread_time_ms() -> float
func get_active_spatial_count() -> int
func get_pool_stats() -> Dictionary
```

---

## TransitionManager

Central manager for scene transitions and screen effects.

### Scene Transitions

```gdscript
func transition_to(scene_path: String, effect: int = Transition.FADE_VIGNETTE, duration: float = 0.8) -> void
func transition_with_callback(callback: Callable, effect: int = Transition.FADE_VIGNETTE, duration: float = 0.8) -> void
func fade_transition(scene_path: String, duration: float = 0.6) -> void
func wipe_transition(scene_path: String, duration: float = 0.8) -> void
func shatter_transition(scene_path: String, duration: float = 1.0) -> void
func flash_screen(color: Color = Color.WHITE, duration: float = 0.1) -> void
```

### Screen Effects

```gdscript
func shake(intensity: float = 10.0, duration: float = 0.3) -> void
func impact_shake() -> void
func explosion_shake() -> void
func slow_motion(time_scale: float = 0.3, transition_time: float = 0.1) -> void
func normal_speed(transition_time: float = 0.2) -> void
func slow_motion_pulse(time_scale: float = 0.2, hold: float = 0.3) -> void
func chromatic_pulse(intensity: float = 15.0, duration: float = 0.3) -> void
func impact_effect() -> void
func damage_effect() -> void
func critical_hit_effect() -> void
func death_effect() -> void
```

### Loading Screens

```gdscript
func load_scene(scene_path: String) -> void
func show_loading() -> void
func hide_loading() -> void
func set_loading_progress(percent: float) -> void
```

### Match Events

```gdscript
func start_countdown(team_red: String = "RED TEAM", team_blue: String = "BLUE TEAM", map_name: String = "") -> void
func start_countdown_ffa(map_name: String = "") -> void
func show_victory(players: Array[Dictionary], mvp: Dictionary = {}, subtitle: String = "Your team won!") -> void
func show_defeat(players: Array[Dictionary], subtitle: String = "Better luck next time!") -> void
func show_draw(players: Array[Dictionary], subtitle: String = "It's a tie!") -> void
func show_results(players: Array[Dictionary], stats: Dictionary = {}, awards: Array[Dictionary] = [], personal_bests: Array[String] = []) -> void
func hide_results() -> void
```

### Notifications

```gdscript
func notify(message: String, type: int = Toast.INFO, duration: float = 4.0) -> int
func notify_info(message: String) -> int
func notify_success(message: String) -> int
func notify_warning(message: String) -> int
func notify_error(message: String) -> int
func achievement_unlocked(title: String, description: String) -> int
func level_up(new_level: int) -> int
func new_item(item_name: String, rarity: String = "common") -> int
func challenge_complete(challenge_name: String, reward: String = "") -> int
func dismiss_notification(id: int) -> void
func dismiss_all_notifications() -> void
```

### Dialogs

```gdscript
func dialog_info(title: String, message: String, button: String = "OK") -> void
func dialog_confirm(title: String, message: String, confirm: String = "Confirm", cancel: String = "Cancel") -> void
func dialog_warning(title: String, message: String, button: String = "OK") -> void
func dialog_error(title: String, message: String, button: String = "OK") -> void
func dialog_input(title: String, message: String, placeholder: String = "", confirm: String = "Submit", cancel: String = "Cancel") -> void
func get_dialog_input() -> String
func close_dialog() -> void
func close_all_dialogs() -> void
func connect_dialog_confirmed(callback: Callable) -> void
func connect_dialog_cancelled(callback: Callable) -> void
```

---

## PerformanceManager

Core performance optimization system.

### Signals

| Signal | Description |
|--------|-------------|
| `quality_preset_changed(preset)` | Quality preset changed |
| `power_mode_changed(mode)` | Power mode changed |
| `performance_warning(warning, message)` | Performance issue detected |
| `fps_warning(current_fps, target_fps)` | FPS below target |
| `thermal_throttling_detected(severity)` | Thermal throttling detected |
| `memory_warning(used_mb, budget_mb)` | Memory usage high |
| `metrics_updated(metrics)` | Performance metrics updated |

### Enums

#### QualityPreset
```gdscript
enum QualityPreset {
    LOW,
    MEDIUM,
    HIGH,
    ULTRA,
    CUSTOM
}
```

#### PowerMode
```gdscript
enum PowerMode {
    PERFORMANCE,   # Max quality, 60 FPS
    BALANCED,      # Good quality, 45 FPS
    POWER_SAVER,   # Minimal effects, 30 FPS
    AUTO           # Automatic adjustment
}
```

### Quality Control

```gdscript
func set_quality_preset(preset: QualityPreset) -> void
func get_quality_preset() -> QualityPreset
func get_quality_settings() -> Dictionary
func set_custom_quality_setting(setting_name: String, value: Variant) -> void
func get_quality_setting(setting_name: String) -> Variant
```

### Power Mode

```gdscript
func set_power_mode(mode: PowerMode) -> void
func get_power_mode() -> PowerMode
```

### Performance Metrics

```gdscript
func get_performance_metrics() -> Dictionary
func get_current_fps() -> float
func is_performance_acceptable() -> bool
func get_particle_limit() -> int
func get_particle_quality() -> float
func get_draw_distance() -> float
func get_lod_bias() -> float
func is_effect_enabled(effect_name: String) -> bool
```

### Debug

```gdscript
func toggle_debug_overlay() -> void
func get_debug_text() -> String
```

### Profiling

```gdscript
func begin_profile(section_name: String) -> void
func end_profile(section_name: String) -> float
func record_metric(metric_name: String, value: float) -> void
```

### Settings

```gdscript
func save_settings() -> void
func load_settings() -> void
```

---

## ParticleEffectsManager

Creates and manages particle effects.

### Enums

#### ParticleType
```gdscript
enum ParticleType {
    SPARKLE,
    CONFETTI,
    SMOKE,
    EXPLOSION,
    STARS,
    HEARTS
}
```

### Functions

```gdscript
func create_particle_effect(type: ParticleType, position: Vector2, parent: Node = null) -> void
func create_button_click_effect(button: Control) -> void
func create_victory_effect(position: Vector2, parent: Node = null) -> void
```

**Example:**
```gdscript
# Create sparkle effect
ParticleEffectsManager.create_particle_effect(
    ParticleEffectsManager.ParticleType.SPARKLE,
    $Button.global_position
)

# Victory celebration
ParticleEffectsManager.create_victory_effect(get_viewport_rect().size / 2)
```

---

## Shader APIs

### Premium UI Effects Shader

Located at `ui/shaders/premium_ui_effects.gdshader`

**Effect Enable Flags:**
```glsl
uniform bool enable_glow = false;
uniform bool enable_wave = false;
uniform bool enable_ripple = false;
uniform bool enable_glitch = false;
uniform bool enable_hologram = false;
uniform bool enable_shimmer = false;
```

**Glow Parameters:**
```glsl
uniform vec4 glow_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float glow_size : hint_range(0.0, 0.3) = 0.05;
```

**Wave Parameters:**
```glsl
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float wave_frequency : hint_range(0.0, 20.0) = 5.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 2.0;
```

**Ripple Parameters:**
```glsl
uniform vec2 ripple_center = vec2(0.5, 0.5);
uniform float ripple_time : hint_range(0.0, 10.0) = 0.0;
uniform float ripple_amplitude : hint_range(0.0, 0.2) = 0.05;
uniform float ripple_frequency : hint_range(1.0, 20.0) = 10.0;
```

**Glitch Parameters:**
```glsl
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float glitch_speed : hint_range(0.0, 10.0) = 5.0;
uniform float glitch_block_size : hint_range(0.01, 0.2) = 0.05;
```

**Hologram Parameters:**
```glsl
uniform vec4 hologram_color : source_color = vec4(0.0, 0.8, 1.0, 0.5);
uniform float hologram_scanline_density : hint_range(10.0, 200.0) = 100.0;
uniform float hologram_scanline_speed : hint_range(0.0, 5.0) = 1.0;
uniform float hologram_flicker_speed : hint_range(0.0, 10.0) = 5.0;
uniform float hologram_flicker_intensity : hint_range(0.0, 1.0) = 0.3;
```

**Shimmer Parameters:**
```glsl
uniform vec4 shimmer_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float shimmer_speed : hint_range(0.0, 5.0) = 1.5;
uniform float shimmer_width : hint_range(0.05, 0.5) = 0.2;
uniform float shimmer_angle : hint_range(0.0, 6.28318) = 0.785398;
```

**Usage in GDScript:**
```gdscript
# Apply shader to a Control
var material = ShaderMaterial.new()
material.shader = preload("res://ui/shaders/premium_ui_effects.gdshader")
$Panel.material = material

# Enable glow effect
material.set_shader_parameter("enable_glow", true)
material.set_shader_parameter("glow_color", Color.CYAN)
material.set_shader_parameter("glow_intensity", 1.5)
```

### Cel Shading Shader

Located at `shared/shaders/cel_shading.gdshader`

**Base Color:**
```glsl
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color;
uniform bool use_albedo_texture = false;
```

**Cel Shading:**
```glsl
uniform int cel_levels : hint_range(2, 8, 1) = 4;
uniform float cel_sharpness : hint_range(0.0, 1.0) = 0.8;
uniform vec4 shadow_color : source_color = vec4(0.2, 0.15, 0.25, 1.0);
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.6;
```

**Rim Lighting:**
```glsl
uniform bool enable_rim_light = true;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.5;
```

**Specular:**
```glsl
uniform bool enable_specular = true;
uniform vec4 specular_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float specular_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float specular_size : hint_range(0.0, 1.0) = 0.2;
uniform float specular_smoothness : hint_range(0.0, 0.5) = 0.05;
```

**Emission:**
```glsl
uniform bool enable_emission = false;
uniform vec4 emission_color : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float emission_intensity : hint_range(0.0, 3.0) = 1.0;
```

**Fresnel:**
```glsl
uniform bool enable_fresnel = false;
uniform vec4 fresnel_color : source_color = vec4(0.5, 0.7, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.0;
uniform float fresnel_intensity : hint_range(0.0, 1.0) = 0.3;
```

**Team Color:**
```glsl
uniform bool use_team_color = false;
uniform vec4 team_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float team_color_blend : hint_range(0.0, 1.0) = 0.5;
```

---

## Thread Safety Notes

All UI animation and audio functions are designed to be called from the main thread. Do not call these functions from worker threads.

For performance-critical operations:
- Use `call_deferred()` when calling from signal callbacks
- Batch multiple animations using sequences
- Use `is_animating()` to avoid redundant animation calls

---

## Version History

| Version | Changes |
|---------|---------|
| 1.0.0 | Initial release with core animation system |
| 1.1.0 | Added spring physics and bezier curves |
| 1.2.0 | Added performance monitoring and auto-quality |
| 1.3.0 | Added spatial audio with occlusion |
| 2.0.0 | Premium UI effects and cel shading |
