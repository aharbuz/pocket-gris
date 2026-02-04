# Pocket-Gris

A macOS menu bar app that displays animated sprite characters peeking around windows.

## Features

- Animated creatures that peek around window edges and screen corners
- Characters traverse across the screen (walk/run from edge to edge)
- Stationary antics (sitting, eating, sleeping, waving)
- Cursor reactions (flee, follow, hide when approached)
- Climbing window edges, hanging from title bars
- Scheduled appearances (15-30 min) or manual trigger
- Varied personalities (shy → chaotic)

## Architecture

- **Pure SPM** - No xcodeproj, CLI-first design
- **Swift + AppKit** - Floating transparent windows
- **SwiftUI** - Sprite rendering inside windows

## Building

```bash
swift build
swift test
swift run pocketgris version
```

## Structure

```
Sources/
├── PocketGrisCore/      # Pure Swift library, zero UI deps
├── PocketGrisCLI/       # CLI for testing/control
└── PocketGrisApp/       # Menu bar app

Resources/
└── Sprites/             # PNG sequences organized by creature
```

## CLI Commands

```bash
pocketgris version
pocketgris status [--gui]
pocketgris trigger [--creature X] [--edge right] [--gui]
pocketgris creatures list
pocketgris simulate --seconds 3600
pocketgris control enable|disable|cancel
```

## License

Private project.
