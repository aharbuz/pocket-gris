# Pocket-Gris Development Guide

## Project Overview

Pocket-Gris is a macOS menu bar app displaying animated sprite creatures that interact with the screen. Built with Swift Package Manager (no Xcode project).

## Quick Start

```bash
swift build && swift test                    # Build and test
swift run PocketGrisApp                      # Run the app (check menu bar)
swift run pocketgris trigger --gui           # Trigger creature (app must be running)
swift run pocketgris behaviors list          # List available behaviors
```

## Architecture

### Three Targets
- **PocketGrisCore** - Pure Swift library, no UI dependencies, fully testable
- **PocketGrisCLI** - Command-line interface using ArgumentParser
- **PocketGrisApp** - macOS menu bar app using AppKit + SwiftUI

### Behavior System
Behaviors follow a state machine pattern:
1. `start()` - Initialize state, pick position/animation
2. `update()` - Called each frame, emit events, update position
3. `cancel()` - Clean termination

Phases: `idle` → `enter` → `perform` → `exit` → `complete`

### Key Types
- `Creature` - Character definition with personality and animations
- `Animation` / `AnimationState` - Frame sequences and playback
- `BehaviorState` - Current state of a running behavior
- `BehaviorContext` - Environment info (screen bounds, cursor, time)
- `Position` / `ScreenRect` / `ScreenEdge` - Geometry primitives

## Testing

All behaviors should be testable using:
- `FixedRandomSource(ints:, doubles:, bools:)` - Deterministic random values
- `MockTimeSource` - Controllable time progression
- Direct state inspection via `BehaviorState`

```swift
let random = FixedRandomSource(ints: [0], doubles: [0.5], bools: [true])
var state = behavior.start(context: context, random: random)
let events = behavior.update(state: &state, context: context, deltaTime: 0.1)
XCTAssertEqual(state.phase, .perform)
```

## Adding a New Behavior

1. Create `Sources/PocketGrisCore/Behavior/NewBehavior.swift`
2. Implement `Behavior` protocol (type, requiredAnimations, start, update, cancel)
3. Register in `BehaviorRegistry` init in `Behavior.swift`
4. Add unit tests in `Tests/PocketGrisCoreTests/BehaviorTests.swift`
5. If needed, add personality extensions for behavior-specific parameters

## Sprite Structure

```
Resources/Sprites/<creature-id>/
├── creature.json           # Manifest
└── <animation-name>/       # One folder per animation
    ├── frame-001.png
    ├── frame-002.png
    └── ...
```

Generate test sprites: `python3 scripts/generate_sprites.py`

## Current State (Phase 8 Complete)

### Implemented
- PeekBehavior - Peek from edges, retreat on cursor proximity
- TraverseBehavior - Walk across screen edge to edge
- StationaryBehavior - Appear, idle, disappear
- ClimberBehavior - Climb along window edges, follows window movement
- FollowBehavior (cursorReactive) - Follow cursor at safe distance, flee if too close
- AccessibilityWindowTracker - Real window detection using CGWindowListCopyWindowInfo
- GlobalCursorTracker - System-wide cursor tracking using NSEvent monitors
- Settings UI - SwiftUI window with interval sliders, creature/behavior toggles, weights
- Launch at login - SMAppService (macOS 13+), graceful fallback for SPM builds
- Multi-monitor support - Random screen selection for creature appearances
- Menu bar app with IPC
- Smooth animation system with easing
- 87 unit tests

### Potential Future Work
- More creatures and animations
- Additional behaviors (e.g., dancing, sleeping, interacting with windows)
- Custom creature editor
- Drag-and-drop sprite import
- Notification-triggered appearances

## Conventions

- Use `@MainActor` for all UI-related code
- Behaviors must be `Sendable`
- Store ephemeral data in `BehaviorState.metadata` dictionary
- Emit `BehaviorEvent`s for state changes, don't mutate external state
- Personality traits should affect behavior parameters (duration, speed, sensitivity)

## Known Issues

- `Settings` type name conflicts with `SwiftUI.Settings` - use `AppSettings` typealias in PocketGrisApp files that import SwiftUI
- Launch at login requires a proper .app bundle; SPM builds will log a warning but continue

## Files to Know

- `Sources/PocketGrisCore/Behavior/Behavior.swift` - Protocol + Registry
- `Sources/PocketGrisCore/Behavior/PeekBehavior.swift` - Reference implementation
- `Sources/PocketGrisCore/Behavior/ClimberBehavior.swift` - Window-aware behavior
- `Sources/PocketGrisCore/Behavior/FollowBehavior.swift` - Cursor-following behavior
- `Sources/PocketGrisCore/Services/WindowTracker.swift` - Window detection
- `Sources/PocketGrisCore/Services/CursorTracker.swift` - Global cursor tracking
- `Sources/PocketGrisApp/SettingsView.swift` - SwiftUI settings UI + SettingsViewModel
- `Sources/PocketGrisApp/SettingsWindowController.swift` - NSWindow host for settings
- `Sources/PocketGrisApp/LaunchAtLoginManager.swift` - SMAppService wrapper
- `Sources/PocketGrisApp/CreatureViewModel.swift` - Core→SwiftUI bridge
- `Sources/PocketGrisApp/AppDelegate.swift` - App lifecycle, IPC handling
- `AGENTS/content-in/PROGRESS.md` - Detailed session history
