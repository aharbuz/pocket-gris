# Pocket-Gris

A macOS menu bar app that displays animated sprite characters peeking around windows.

## Current Status

**Choreographer Complete** - 180 unit tests passing

### Behaviors
- **Peek** - Creatures peek from screen edges, look around, retreat when cursor approaches
- **Traverse** - Walk across screen from one edge to the opposite
- **Stationary** - Appear at edge, perform idle antics, disappear
- **Climber** - Climb along window edges, follows window if dragged
- **CursorReactive** - Follow cursor at a safe distance, flee if too close
- **Scene** - Choreographed multi-creature animations with waypoint paths

### Features
- Menu bar app with pawprint icon
- Animation Choreographer - visual scene editor with multi-track waypoint placement (Cmd+Shift+C)
- ScenePlayer - multi-track playback, one creature window per track
- Settings UI with interval sliders, creature/behavior toggles, weight controls
- Launch at login support (SMAppService)
- Multi-monitor support (creatures appear on random screen)
- Floating transparent windows (click-through, visible on all spaces)
- Smooth sliding animations with easing
- Global cursor tracking (works across all apps and spaces)
- Window tracking (creatures can climb window edges)
- Two creatures: "gris" (pixel art, 12 animations) and "pig-gnome" (pixel art, walk + idle)
- CLI for triggering and controlling the app
- IPC communication between CLI and GUI
- Configurable appearance intervals and behavior weights
- Per-creature and per-behavior enable/disable

## Architecture

- **Pure SPM** - No xcodeproj, CLI-first design
- **Swift + AppKit** - Floating transparent windows
- **SwiftUI** - Sprite rendering inside windows
- **Behavior System** - Extensible state machine for creature actions

## Building

```bash
swift build
swift test
swift run pocketgris version
```

## Running

```bash
# Start the menu bar app
swift run PocketGrisApp

# Trigger a creature (while app is running)
swift run pocketgris trigger --gui
swift run pocketgris trigger --behavior traverse --gui
swift run pocketgris trigger --behavior stationary --gui
swift run pocketgris trigger --behavior climber --gui
swift run pocketgris trigger --behavior cursorReactive --gui
```

## Structure

```
Sources/
├── PocketGrisCore/      # Pure Swift library, zero UI deps
│   ├── Behavior/        # Behavior protocol and implementations
│   ├── Scene/           # Scene types, storage, choreography data model
│   ├── Types/           # Position, Creature, Animation, etc.
│   └── Services/        # Scheduler, SpriteLoader, IPC, WindowTracker
├── PocketGrisCLI/       # CLI for testing/control
└── PocketGrisApp/       # Menu bar app
    ├── AppDelegate      # Menu bar setup, IPC handling
    ├── CreatureWindow   # Floating transparent window
    ├── CreatureViewModel # Bridges Core to SwiftUI
    ├── SpriteView       # SwiftUI sprite rendering
    ├── ScenePlayer      # Multi-track scene coordinator
    ├── SettingsView     # SwiftUI settings UI
    ├── SettingsWindowController # Settings window management
    ├── LaunchAtLoginManager    # SMAppService wrapper
    └── Choreographer/   # Animation scene editor
        ├── ChoreographerController    # Overlay + panel lifecycle
        ├── ChoreographerViewModel     # Shared state
        ├── ChoreographerOverlayWindow # Fullscreen overlay
        ├── ChoreographerOverlayView   # Waypoint/path rendering
        ├── ChoreographerPanelController # Tool panel
        └── ChoreographerPanelView     # Panel UI controls

Resources/
└── Sprites/
    ├── gris/            # Test creature (generated)
    │   ├── creature.json
    │   ├── peek-*/      # Directional peek animations
    │   ├── retreat-*/   # Retreat animations
    │   ├── walk-*/      # Walking animations
    │   ├── climb/       # Climbing animation
    │   └── idle/        # Idle animation
    └── pig-gnome/       # Pixel art creature
        ├── creature.json
        ├── walk-left/   # Walking left (4 frames)
        ├── walk-right/  # Walking right (4 frames)
        └── idle/        # Idle animation (2 frames)
```

## CLI Commands

```bash
pocketgris version                              # Show version
pocketgris status [--gui]                       # Show status
pocketgris trigger [--creature X] [--behavior Y] [--gui]  # Trigger appearance
pocketgris creatures list                       # List available creatures
pocketgris behaviors list                       # List available behaviors
pocketgris simulate --seconds 3600              # Simulate scheduling
pocketgris control enable|disable|cancel        # Control the app
```

## Adding Creatures

Create a folder in `Resources/Sprites/` with:

```
my-creature/
├── creature.json        # Manifest with personality and animations
├── idle/               # Required: idle animation frames
│   ├── frame-001.png
│   └── ...
├── peek-left/          # Required for peek behavior
├── retreat-left/       # Required for peek behavior
├── walk-left/          # Required for traverse behavior
└── walk-right/         # Required for traverse behavior
```

See `scripts/generate_sprites.py` for generating placeholder sprites.

## License

Private project.
