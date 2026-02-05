# Pocket-Gris

A macOS menu bar app that displays animated sprite characters peeking around windows.

## Current Status

**Phase 5 Complete** - 65 unit tests passing

### Implemented Behaviors
- **Peek** - Creatures peek from screen edges, look around, retreat when cursor approaches
- **Traverse** - Walk across screen from one edge to the opposite
- **Stationary** - Appear at edge, perform idle antics, disappear

### Working Features
- Menu bar app with pawprint icon
- Floating transparent windows (click-through, visible on all spaces)
- Smooth sliding animations with easing
- Test creature "gris" with 11 animations
- CLI for triggering and controlling the app
- IPC communication between CLI and GUI

## Features (Planned)

- ✅ Animated creatures that peek around screen edges
- ✅ Characters traverse across the screen
- ✅ Stationary antics (idle animation)
- 🔲 Cursor reactions (flee, follow, hide when approached)
- 🔲 Climbing window edges, hanging from title bars
- ✅ Scheduled appearances or manual trigger
- ✅ Varied personalities (shy, curious, mischievous, chaotic)

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
```

## Structure

```
Sources/
├── PocketGrisCore/      # Pure Swift library, zero UI deps
│   ├── Behavior/        # Behavior protocol and implementations
│   ├── Types/           # Position, Creature, Animation, etc.
│   └── Services/        # Scheduler, SpriteLoader, IPC
├── PocketGrisCLI/       # CLI for testing/control
└── PocketGrisApp/       # Menu bar app
    ├── AppDelegate      # Menu bar setup, IPC handling
    ├── CreatureWindow   # Floating transparent window
    ├── CreatureViewModel # Bridges Core to SwiftUI
    └── SpriteView       # SwiftUI sprite rendering

Resources/
└── Sprites/
    └── gris/            # Test creature
        ├── creature.json
        ├── peek-*/      # Directional peek animations
        ├── retreat-*/   # Retreat animations
        ├── walk-*/      # Walking animations
        └── idle/        # Idle animation
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
