# Pocket-Gris

A macOS menu bar app that displays animated sprite creatures that peek around screen edges, walk across your desktop, climb windows, and follow your cursor.

## Install

Download the latest `.dmg` from [Releases](https://github.com/aharbuz/pocket-gris/releases), open it, and drag **Pocket Gris** to Applications.

The app is ad-hoc signed (no Apple Developer ID). On first launch, macOS Gatekeeper will block it. To open:
1. Right-click the app in Applications
2. Select **Open**
3. Click **Open** in the dialog

You only need to do this once.

**Requirements:** macOS 15.0+ (Sequoia), Apple Silicon (arm64)

## Creatures

Two placeholder creatures ship with the app (real sprite art coming soon):

- **Sprout** (blob-green) — curious personality, 12 animations
- **Jinx** (blob-purple) — mischievous personality, 12 animations

Both support all five behaviors.

## Behaviors

- **Peek** — Creatures peek from screen edges, look around, retreat when cursor approaches
- **Traverse** — Walk across screen from one edge to the opposite
- **Stationary** — Appear at edge, idle, disappear
- **Climber** — Climb along window edges, follows window if dragged
- **Cursor Reactive** — Follow cursor at a safe distance, flee if too close
- **Scene** — Choreographed multi-creature animations with waypoint paths

## Features

- Menu bar app (no dock icon)
- Animation Choreographer — visual scene editor with multi-track waypoint placement (Cmd+Shift+C)
- Settings UI with interval sliders, creature/behavior toggles, weight controls
- Per-behavior and per-scene enable/disable with weight sliders
- Scene management — create, edit, delete, preview choreographed animations
- Multi-monitor support — creatures appear on correct screen
- Launch at login (SMAppService)
- Graceful sleep/wake and display change handling
- Floating transparent windows (click-through, visible on all spaces)
- Global cursor and window tracking
- CLI companion for triggering and controlling the app
- 176 unit tests

## Architecture

- **Pure SPM** — No Xcode project, Swift 6.0 toolchain, Swift 5 language mode
- **Swift + AppKit** — Floating transparent windows, NSStatusItem menu bar
- **SwiftUI** — Sprite rendering, settings UI, choreographer panel
- **Behavior system** — Extensible state machine pattern with typed metadata
- **Thread safety** — `Synchronization.Mutex` throughout (no NSLock)

## Building from Source

```bash
swift build
swift test
swift run PocketGrisApp          # Run the menu bar app
```

### Building a Release .dmg

```bash
./scripts/build-release.sh           # Build + test + create .dmg
./scripts/build-release.sh --skip-tests
```

Output: `.build/release-bundle/PocketGris-<version>.dmg`

## CLI

```bash
swift run pocketgris version
swift run pocketgris trigger --gui                          # Random behavior
swift run pocketgris trigger --behavior traverse --gui      # Specific behavior
swift run pocketgris trigger --behavior cursorReactive --gui
swift run pocketgris creatures list
swift run pocketgris behaviors list
swift run pocketgris simulate --seconds 3600
swift run pocketgris control enable|disable|cancel
```

## Project Structure

```
Sources/
├── PocketGrisCore/      # Pure Swift library, zero UI deps
│   ├── Behavior/        # Behavior protocol + 6 implementations
│   ├── Scene/           # Scene types, storage, choreography data
│   ├── Types/           # Position, Creature, Animation, etc.
│   └── Services/        # Scheduler, SpriteLoader, IPC, Cache, trackers
├── PocketGrisCLI/       # CLI (ArgumentParser)
└── PocketGrisApp/       # Menu bar app
    └── Choreographer/   # Animation scene editor (overlay + panel)

Resources/
└── Sprites/
    ├── blob-green/      # "Sprout" — 12 animations (placeholder art)
    ├── blob-purple/     # "Jinx" — 12 animations (placeholder art)
    └── _archive/        # Retired creatures (gris, pig-gnome)
```

## Adding Creatures

Create a folder in `Resources/Sprites/<creature-id>/` with a `creature.json` manifest and one subfolder per animation containing numbered PNG frames.

### Folder Structure

```
my-creature/
├── creature.json
├── idle/
│   ├── frame-001.png
│   ├── frame-002.png
│   └── ...
├── walk-left/
├── walk-right/
├── climb/
├── peek-left/
├── peek-right/
├── peek-top/
├── peek-bottom/
├── retreat-left/
├── retreat-right/
├── retreat-top/
└── retreat-bottom/
```

### Manifest (creature.json)

```json
{
  "id": "my-creature",
  "name": "Display Name",
  "personality": "curious",
  "animations": [
    { "name": "idle", "frameCount": 8, "fps": 6, "looping": true },
    { "name": "walk-left", "frameCount": 8, "fps": 10, "looping": true },
    { "name": "walk-right", "frameCount": 8, "fps": 10, "looping": true },
    { "name": "climb", "frameCount": 8, "fps": 10, "looping": true },
    { "name": "peek-left", "frameCount": 10, "fps": 12, "looping": false },
    { "name": "retreat-left", "frameCount": 8, "fps": 12, "looping": false }
  ]
}
```

**Personality** affects behavior parameters (speed, duration, sensitivity): `shy`, `curious`, `mischievous`, or `chaotic`.

### Animations per Behavior

| Behavior | Required animations |
|----------|-------------------|
| Peek | `peek-left/right/top/bottom`, `retreat-left/right/top/bottom` |
| Traverse | `walk-left`, `walk-right` |
| Stationary | `idle` |
| Climber | `climb` |
| Cursor Reactive | `idle`, `walk-left`, `walk-right` |

A creature only needs the animations for the behaviors you want it to support. At minimum, provide `idle`.

### Generating Placeholder Sprites

```bash
python3 scripts/generate_sprites.py
```

### Extracting Sprites from Video

```bash
python3 scripts/extract_sprites.py \
    --input "animation.mp4" --output output-dir/ \
    --start 0.5 --end 4 --detect-cycle --cycle-threshold 0.7
```

## Future Work

- Real sprite art to replace placeholder creatures
- App icon (.icns)
- Apple Developer ID code signing and notarization (removes Gatekeeper workaround)
- Universal binary (arm64 + x86_64) for Intel Mac support
- More behaviors (dancing, sleeping, window interaction)
- Creature sharing — exportable creature packages, online content library
- Custom creature editor with drag-and-drop sprite import
- Notification-triggered appearances
- CI/CD with GitHub Actions

## License

Private project.
