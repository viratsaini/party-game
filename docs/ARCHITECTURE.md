# BattleZone Party - System Architecture

> Technical documentation of the UI system architecture, component relationships, and data flow.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Hierarchy](#component-hierarchy)
3. [Data Flow](#data-flow)
4. [State Management](#state-management)
5. [Event System](#event-system)
6. [Animation Pipeline](#animation-pipeline)
7. [Rendering Order](#rendering-order)
8. [Autoload Systems](#autoload-systems)

---

## Architecture Overview

```
+===============================================================================+
|                        BATTLEZONE PARTY UI ARCHITECTURE                        |
+===============================================================================+

                              +-------------------+
                              |    GAME SCENE     |
                              |  (Current Scene)  |
                              +--------+----------+
                                       |
           +---------------------------+---------------------------+
           |                           |                           |
           v                           v                           v
+----------+----------+    +-----------+-----------+    +----------+----------+
|     AUTOLOADS       |    |      UI LAYER        |    |    GAME SYSTEMS     |
|   (Always Active)   |    |   (Scene-Specific)   |    |    (Game Logic)     |
+---------------------+    +-----------------------+    +---------------------+
| - UIAnimator        |    | - Main Menu          |    | - GameState         |
| - AudioManager      |    | - HUD                |    | - NetworkManager    |
| - TransitionManager |    | - Settings           |    | - PlayerData        |
| - PerformanceManager|    | - Dialogs            |    | - MatchManager      |
| - ParticleEffects   |    | - Overlays           |    | - ScoreSystem       |
+----------+----------+    +-----------+-----------+    +----------+----------+
           |                           |                           |
           +---------------------------+---------------------------+
                                       |
                              +--------v----------+
                              |   RENDERING       |
                              | (CanvasLayers)    |
                              +-------------------+
                              | Layer -1: BG      |
                              | Layer  0: UI      |
                              | Layer 50: HUD     |
                              | Layer 99: Dialogs |
                              | Layer 100: Toast  |
                              +-------------------+
```

---

## Component Hierarchy

### Full System Diagram

```
SceneTree
│
├── /root
│   │
│   ├── [AUTOLOADS]
│   │   ├── UIAnimator
│   │   │   ├── AnimationSequence (pool)
│   │   │   ├── ActiveTweens (tracking)
│   │   │   └── PerformanceMonitor
│   │   │
│   │   ├── AudioManager
│   │   │   ├── MusicPlayer (AudioStreamPlayer)
│   │   │   ├── SFXPool (AudioStreamPlayer[])
│   │   │   └── SpatialPool (AudioStreamPlayer3D[])
│   │   │
│   │   ├── TransitionManager
│   │   │   ├── SceneTransition
│   │   │   │   ├── TransitionShader (ColorRect)
│   │   │   │   └── TransitionOverlay (CanvasLayer)
│   │   │   │
│   │   │   ├── TransitionEffects
│   │   │   │   ├── ShakeController
│   │   │   │   ├── SlowMotionController
│   │   │   │   └── ChromaticController
│   │   │   │
│   │   │   ├── CinematicLoading (CanvasLayer)
│   │   │   │   ├── Background (ColorRect)
│   │   │   │   ├── LoadingBar (ProgressBar)
│   │   │   │   └── Tips (Label)
│   │   │   │
│   │   │   ├── MatchCountdown (CanvasLayer)
│   │   │   │   ├── TeamDisplays
│   │   │   │   ├── CountdownNumber
│   │   │   │   └── ReadyText
│   │   │   │
│   │   │   ├── VictoryScreen (CanvasLayer)
│   │   │   ├── AnimatedResults (CanvasLayer)
│   │   │   ├── PremiumToast (CanvasLayer)
│   │   │   └── AnimatedDialog (CanvasLayer)
│   │   │
│   │   ├── PerformanceManager
│   │   │   ├── QualityController
│   │   │   ├── ThermalMonitor
│   │   │   └── MemoryMonitor
│   │   │
│   │   └── ParticleEffectsManager
│   │       └── ParticlePool (CPUParticles2D[])
│   │
│   └── [CURRENT SCENE]
│       │
│       ├── World (Node3D) [if gameplay]
│       │   ├── Level
│       │   ├── Players
│       │   └── Effects
│       │
│       └── UI (CanvasLayer)
│           │
│           ├── MainMenu [if menu]
│           │   ├── Background
│           │   ├── Logo
│           │   ├── MenuContainer
│           │   │   ├── PlayButton (PremiumButton)
│           │   │   ├── SettingsButton (PremiumButton)
│           │   │   └── QuitButton (PremiumButton)
│           │   └── VersionLabel
│           │
│           ├── GameHUD [if gameplay]
│           │   ├── HealthBar (HealthBarAdvanced)
│           │   ├── AmmoCounter
│           │   ├── Crosshair
│           │   ├── Minimap
│           │   ├── KillFeed
│           │   ├── ScoreDisplay
│           │   └── TimerDisplay
│           │
│           └── SettingsPanel (AnimatedPanel)
│               ├── TabContainer
│               ├── AudioSettings
│               │   └── VolumeSliders (PremiumSlider[])
│               ├── VideoSettings
│               │   └── QualityDropdowns
│               └── ControlSettings
│                   └── KeybindButtons
```

---

## Data Flow

### Input to Visual Feedback Flow

```
+------------+     +-------------+     +--------------+     +------------+
|   INPUT    | --> |   HANDLER   | --> |   ANIMATOR   | --> |   VISUAL   |
| (User/Game)|     |  (Script)   |     |  (UIAnimator)|     |  (Control) |
+------------+     +-------------+     +--------------+     +------------+

Example: Button Press

InputEventMouseButton
        |
        v
+----------------+
| PremiumButton  |
| _gui_input()   |
+-------+--------+
        |
        v (signals)
+-------+--------+      +----------------+
| button_down    | ---> | _on_button_down|
| button_up      |      | _target_scale  |
| pressed        |      | _ripple_active |
+----------------+      +-------+--------+
                                |
                        +-------v--------+
                        | _process(delta)|
                        | - scale lerp   |
                        | - glow lerp    |
                        | - ripple draw  |
                        +-------+--------+
                                |
                        +-------v--------+
                        |  queue_redraw  |
                        |  (visual)      |
                        +----------------+
```

### State Change Propagation

```
+---------------+
|  GameState    |
| (Autoload)    |
+-------+-------+
        |
        | signal: player_health_changed(new_value)
        v
+-------+-------+     +-----------------+     +------------------+
|   HUD Node    | --> | HealthBar       | --> | Visual Update    |
| (listener)    |     | set_health()    |     | - tween value    |
+---------------+     +-----------------+     | - flash effect   |
                                              | - shake on low   |
                                              +------------------+
```

### Animation Data Flow

```
+-------------------+
|  Animation Call   |
| UIAnimator.fade_in|
+--------+----------+
         |
         v
+--------+----------+
|  Validation       |
| - node exists     |
| - not animating   |
| - quality check   |
+--------+----------+
         |
         v
+--------+----------+
|  Store Original   |
| - position        |
| - scale           |
| - modulate        |
| - rotation        |
+--------+----------+
         |
         v
+--------+----------+
|  Create Tween     |
| - set_ease()      |
| - set_trans()     |
| - parallel mode   |
+--------+----------+
         |
         v
+--------+----------+
|  Track Animation  |
| _active_tweens[n] |
+--------+----------+
         |
         v
+--------+----------+
|  Connect Signals  |
| - finished        |
| - step            |
+--------+----------+
         |
         v
+--------+----------+
|  Emit Started     |
| animation_started |
+-------------------+
```

---

## State Management

### UI State Machine

```
+============================================================================+
|                           UI STATE MACHINE                                  |
+============================================================================+

                              +-------------+
                              |    IDLE     |
                              | (default)   |
                              +------+------+
                                     |
              +----------------------+----------------------+
              |                      |                      |
              v                      v                      v
       +------+------+        +------+------+        +------+------+
       |   HOVER     |        |  FOCUSED    |        |  DISABLED   |
       +------+------+        +------+------+        +-------------+
              |                      |
              v                      v
       +------+------+        +------+------+
       |   PRESSED   |        |   ACTIVE    |
       +------+------+        +------+------+
              |                      |
              v                      |
       +------+------+               |
       |  RELEASED   |<--------------+
       +------+------+
              |
              v
       +------+------+
       |    IDLE     |
       +-------------+

State Transitions:
- IDLE -> HOVER: mouse_entered
- HOVER -> IDLE: mouse_exited
- HOVER -> PRESSED: button_down
- PRESSED -> RELEASED: button_up
- IDLE -> FOCUSED: grab_focus()
- FOCUSED -> IDLE: release_focus()
- ANY -> DISABLED: disabled = true
```

### Animation State Tracking

```gdscript
# UIAnimator internal state
var _active_tweens: Dictionary = {}  # node_id -> Tween
var _original_states: Dictionary = {} # node_id -> state_dict
var _animation_queue: Array = []      # queued animations
var _paused_nodes: Array = []         # paused node IDs

# State structure
{
    "node_id": {
        "position": Vector2,
        "scale": Vector2,
        "rotation": float,
        "modulate": Color,
        "visible": bool,
        "pivot_offset": Vector2
    }
}
```

### Quality State Management

```
+------------------------------------------------------------------+
|                    PERFORMANCE STATE                              |
+------------------------------------------------------------------+

current_preset: QualityPreset = MEDIUM
current_power_mode: PowerMode = AUTO
quality_settings: Dictionary = {
    "shadow_quality": 1,
    "particle_limit": 150,
    "particle_quality": 0.6,
    "bloom_enabled": true,
    "resolution_scale": 0.75,
    ...
}

State Transitions:
+--------+    low fps    +--------+    thermal    +--------+
| HIGH   | ------------> | MEDIUM | ------------> | LOW    |
+--------+               +--------+               +--------+
    ^                        |                        |
    |     high fps stable    |    performance ok      |
    +------------------------+------------------------+
```

---

## Event System

### Signal Architecture

```
+============================================================================+
|                          SIGNAL FLOW DIAGRAM                                |
+============================================================================+

GAME EVENTS                    UI EVENTS                    SYSTEM EVENTS
-----------                    ---------                    -------------
player_damaged ─────────────> update_health_bar
player_killed ──────────────> show_death_screen
match_ended ────────────────> show_results_screen
                              │
                              │ (connects to)
                              v
                         +---------+
                         |Animator |──> animation_started
                         |Systems  |──> animation_completed
                         +---------+
                              │
                              v
                         +---------+
                         | Audio   |──> play sound
                         | Manager |
                         +---------+

INTERACTION EVENTS            ANIMATION EVENTS              PERFORMANCE EVENTS
------------------            ----------------              ------------------
button_pressed ─────────────> UIAnimator.bounce()
slider_changed ─────────────> value_changed_signal ────> save_settings()
panel_shown ────────────────> show_completed ──────────> play_sound()
                                                               │
                              animation_completed ◄────────────┘
                                     │
                              quality_preset_changed ◄── PerformanceManager
                              performance_warning ◄──────────────┘
```

### Signal Reference Table

| Source | Signal | Payload | Listeners |
|--------|--------|---------|-----------|
| `PremiumButton` | `pressed` | - | Scene scripts |
| `PremiumSlider` | `value_changed_signal` | `float` | Settings, Audio |
| `AnimatedPanel` | `show_completed` | - | Scene scripts |
| `AnimatedPanel` | `hide_completed` | - | Scene scripts |
| `UIAnimator` | `animation_started` | `node, type` | Debug, Analytics |
| `UIAnimator` | `animation_completed` | `node, type` | Scene scripts |
| `PerformanceManager` | `quality_preset_changed` | `preset` | All UI |
| `PerformanceManager` | `performance_warning` | `warning, msg` | Debug overlay |
| `PerformanceManager` | `fps_warning` | `current, target` | Auto-quality |
| `AudioManager` | `settings_changed` | - | Settings UI |
| `TransitionManager` | N/A (uses callbacks) | - | Scene scripts |

---

## Animation Pipeline

### Frame-by-Frame Pipeline

```
+============================================================================+
|                        ANIMATION FRAME PIPELINE                             |
+============================================================================+

Frame Start
     │
     v
+----+----+
| _process|  (UIAnimator._process)
+---------+
     │
     ├──> Update quality level (if auto-adjusting)
     │
     ├──> Process active tweens (automatic via Godot)
     │
     ├──> Update performance metrics
     │
     v
+----+----+
|Components|  (Each animated control's _process)
+---------+
     │
     ├──> PremiumButton: scale lerp, glow lerp
     │
     ├──> PremiumSlider: value lerp, spring physics
     │
     ├──> AnimatedPanel: (handled by tween)
     │
     v
+----+----+
| _draw   |  (Controls with custom drawing)
+---------+
     │
     ├──> PremiumButton: ripple effect
     │
     ├──> PremiumSlider: track, fill, thumb, tooltip
     │
     v
+----+----+
| Render  |  (Godot rendering)
+---------+
     │
     ├──> CanvasLayer -1: Backgrounds
     ├──> CanvasLayer  0: Main UI
     ├──> CanvasLayer 50: HUD
     ├──> CanvasLayer 99: Dialogs
     ├──> CanvasLayer 100: Toasts
     │
     v
Frame End
```

### Tween Execution Order

```
1. Tween Created
   └── set_parallel(true) - all properties animate together
   └── set_ease(EASE_OUT)
   └── set_trans(TRANS_BACK)

2. Properties Queued
   └── tween_property(scale, target, duration)
   └── tween_property(modulate, target, duration)
   └── tween_property(position, target, duration)

3. Callbacks Queued
   └── tween_callback(on_complete)

4. Tween Starts
   └── Godot processes each frame
   └── Interpolates values based on elapsed time

5. Tween Completes
   └── finished signal emitted
   └── Cleanup performed
```

### Easing Function Pipeline

```
Input: t (0.0 to 1.0, progress)
          │
          v
+--------------------+
| Easing Selection   |
| UIEasing.get_easing|
+--------------------+
          │
          v
+--------------------+
| Easing Calculation |
| e.g., elastic_out  |
+--------------------+
          │
    ┌─────┴─────┐
    │           │
    v           v
Standard    Custom
Easing      Spring
    │           │
    │     +-----+-----+
    │     | damping   |
    │     | frequency |
    │     | velocity  |
    │     +-----------+
    │           │
    └─────┬─────┘
          │
          v
Output: eased_t (0.0 to ~1.0+)
```

---

## Rendering Order

### Canvas Layer Stack

```
+============================================================================+
|                         CANVAS LAYER RENDERING                              |
+============================================================================+

Layer Index    Purpose              Contents
-----------    -------              --------
    100        Tooltips/Toasts      PremiumTooltip, PremiumToast
     99        Modal Dialogs        AnimatedDialog, Confirmation
     90        Overlays             Loading screens, Transitions
     50        HUD                  Health, Ammo, Minimap, KillFeed
     10        Floating UI          Damage numbers, Name tags
      0        Main UI              Menus, Panels, Buttons
    -10        Backgrounds          Parallax, Decorations

Rendering Order (back to front):
┌──────────────────────────────────────────────────────────────────┐
│ Layer -10: Background                                            │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Layer 0: Main UI (Menus, Settings)                           │ │
│ │ ┌──────────────────────────────────────────────────────────┐ │ │
│ │ │ Layer 50: HUD (Health, Ammo, Minimap)                    │ │ │
│ │ │ ┌──────────────────────────────────────────────────────┐ │ │ │
│ │ │ │ Layer 99: Dialogs (Modal windows)                    │ │ │ │
│ │ │ │ ┌──────────────────────────────────────────────────┐ │ │ │ │
│ │ │ │ │ Layer 100: Tooltips & Toasts (Always on top)     │ │ │ │ │
│ │ │ │ └──────────────────────────────────────────────────┘ │ │ │ │
│ │ │ └──────────────────────────────────────────────────────┘ │ │ │
│ │ └──────────────────────────────────────────────────────────┘ │ │
│ └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### Z-Index Within Layers

```gdscript
# Within a single CanvasLayer, use z_index for ordering

# Example: Panel with glow behind
panel_glow.z_index = -1      # Glow effect behind
panel_content.z_index = 0     # Main panel
panel_highlight.z_index = 1   # Highlight on top

# Example: Button states
button_shadow.z_index = -1
button_base.z_index = 0
button_ripple.z_index = 1
button_glow.z_index = 2
```

---

## Autoload Systems

### Initialization Order

```
1. PerformanceManager
   └── Detects device capabilities
   └── Sets initial quality preset
   └── Starts monitoring

2. AudioManager
   └── Loads saved settings
   └── Initializes audio pools
   └── Sets up spatial audio

3. UIAnimator
   └── Pre-warms animation pools
   └── Connects to performance signals
   └── Registers debug commands

4. TransitionManager
   └── Creates transition sub-systems
   └── Sets up canvas layers
   └── Initializes effect pools

5. ParticleEffectsManager
   └── Pre-creates particle pools
   └── Listens for quality changes
```

### Cross-System Communication

```
+------------------+          +------------------+
| PerformanceManager|          | UIAnimator       |
+------------------+          +------------------+
         |                            ^
         | quality_preset_changed     |
         v                            |
+------------------+                  |
| set_quality_level |                 |
| (0.0 - 1.0)       |─────────────────┘
+------------------+

+------------------+          +------------------+
| UIAnimator       |          | AudioManager     |
+------------------+          +------------------+
         |                            ^
         | animation_started          |
         | (with sound flag)          |
         v                            |
+------------------+                  |
| play_sfx()       |──────────────────┘
+------------------+

+------------------+          +------------------+
| TransitionManager|          | Game Scene       |
+------------------+          +------------------+
         |                            ^
         | transition_to_scene        |
         v                            |
+------------------+                  |
| - Play out anim  |                  |
| - Load scene     |                  |
| - Play in anim   |──────────────────┘
+------------------+
```

### Memory Layout

```
+============================================================================+
|                        AUTOLOAD MEMORY FOOTPRINT                            |
+============================================================================+

UIAnimator:
├── _active_tweens: Dictionary (dynamic, ~8 bytes per entry)
├── _original_states: Dictionary (dynamic, ~64 bytes per entry)
├── _sequence_pool: Array (pre-allocated, ~10 sequences)
└── Estimated base: ~2 KB, scales with active animations

AudioManager:
├── _sfx_registry: Dictionary (~500 entries max)
├── _music_registry: Dictionary (~50 entries max)
├── _sfx_pool: Array[AudioStreamPlayer] (16 players)
├── _spatial_pool: Array[AudioStreamPlayer3D] (32 players)
└── Estimated base: ~50 KB + loaded audio streams

TransitionManager:
├── Sub-systems: 8 nodes
├── Canvas layers: 5 layers
├── Shader materials: 3 materials
└── Estimated base: ~100 KB

PerformanceManager:
├── _frame_times: Array[float] (60 entries)
├── _thermal_frame_times: Array[float] (120 entries)
├── quality_settings: Dictionary (~20 entries)
└── Estimated base: ~5 KB

ParticleEffectsManager:
├── Particle pool: ~20 CPUParticles2D nodes
└── Estimated base: ~10 KB (no active particles)

Total Autoload Footprint: ~170 KB (base)
```

---

## Dependency Graph

```
+============================================================================+
|                         SYSTEM DEPENDENCIES                                 |
+============================================================================+

                    ┌───────────────────┐
                    │ PerformanceManager │  (No dependencies)
                    └─────────┬─────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              v               v               v
      ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
      │  UIAnimator   │ │ AudioManager  │ │ParticleEffects│
      │ (depends on   │ │ (independent) │ │  Manager      │
      │  Performance) │ └───────┬───────┘ │ (depends on   │
      └───────┬───────┘         │         │  Performance) │
              │                 │         └───────┬───────┘
              │                 │                 │
              └────────┬────────┴────────┬────────┘
                       │                 │
                       v                 v
              ┌────────────────────────────────┐
              │       TransitionManager         │
              │  (depends on all above)         │
              └────────────────────────────────┘
                               │
                               v
              ┌────────────────────────────────┐
              │         GAME SCENES            │
              │   (use all autoload systems)   │
              └────────────────────────────────┘
```

---

## Thread Safety

### Main Thread Operations

All UI operations MUST occur on the main thread:

```
Main Thread Only:
├── All Control node modifications
├── Tween creation and manipulation
├── Signal emissions
├── Scene tree modifications
├── Resource loading (synchronous)
└── Rendering operations

Safe for Background Threads:
├── Mathematical calculations
├── Data parsing
├── Network requests (with callbacks to main)
├── File I/O (with call_deferred for UI)
└── Heavy computations

Pattern for Thread Safety:
┌────────────────────────────────────────────────┐
│ func _on_data_loaded(data):                    │
│     # Called from background thread            │
│     call_deferred("_update_ui", data)          │
│                                                │
│ func _update_ui(data):                         │
│     # Now safe to modify UI                    │
│     label.text = data.name                     │
│     UIAnimator.fade_in(panel)                  │
└────────────────────────────────────────────────┘
```

---

## File Structure

```
project/
├── autoload/
│   ├── audio_manager.gd
│   ├── particle_effects_manager.gd
│   ├── performance_manager.gd
│   └── transition_manager.gd
│
├── ui/
│   ├── animations/
│   │   ├── easing.gd
│   │   ├── tween_extensions.gd
│   │   ├── ui_animator.gd
│   │   └── ui_easing.gd
│   │
│   ├── components/
│   │   ├── animated_panel.gd
│   │   └── premium_button.gd
│   │
│   ├── hud/
│   │   ├── ammo_counter.gd
│   │   ├── crosshair.gd
│   │   ├── damage_indicator.gd
│   │   ├── game_hud.gd
│   │   ├── health_bar_advanced.gd
│   │   ├── hit_marker.gd
│   │   ├── kill_feed.gd
│   │   └── minimap.gd
│   │
│   ├── loading/
│   │   ├── cinematic_loading.gd
│   │   └── loading_screen.gd
│   │
│   ├── modals/
│   │   └── animated_dialog.gd
│   │
│   ├── notifications/
│   │   ├── premium_toast.gd
│   │   └── toast_notification.gd
│   │
│   ├── settings/
│   │   ├── animated_toggle.gd
│   │   ├── dropdown_select.gd
│   │   ├── keybind_button.gd
│   │   ├── premium_slider.gd
│   │   └── settings_menu.gd
│   │
│   ├── shaders/
│   │   └── premium_ui_effects.gdshader
│   │
│   ├── tooltips/
│   │   ├── premium_tooltip.gd
│   │   └── tooltip_manager.gd
│   │
│   └── transitions/
│       ├── match_countdown.gd
│       ├── scene_transition.gd
│       └── transition_effects.gd
│
├── shared/
│   └── shaders/
│       └── cel_shading.gdshader
│
└── docs/
    ├── API_REFERENCE.md
    ├── ARCHITECTURE.md
    ├── COMPONENT_GUIDE.md
    ├── INTEGRATION_GUIDE.md
    ├── PERFORMANCE_GUIDE.md
    ├── STYLE_GUIDE.md
    └── TUTORIALS.md
```
