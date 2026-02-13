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

### Scene / Choreographer System
Scenes define choreographed multi-creature animations:
- `Scene` > `SceneTrack` > `SceneSegment` (segments.count == waypoints.count - 1)
- `SceneStorage` persists scenes as JSON to ~/Library/Application Support/PocketGris/scenes/
- `ScriptedBehavior` implements `Behavior` to play back a track's waypoints
- `ScenePlayer` coordinates multi-track playback, one `CreatureWindow` per track
- `BehaviorScheduler` supports `SchedulerTrigger` enum (.behavior or .scene) via `setUnifiedTriggerHandler`
- Choreographer UI: fullscreen overlay for waypoint placement + floating tool panel
- `PGScene`/`PGSceneStorage` typealiases resolve SwiftUI name conflicts in PocketGrisApp

### Key Types
- `Creature` - Character definition with personality and animations
- `Animation` / `AnimationState` - Frame sequences and playback
- `BehaviorState` - Current state of a running behavior
- `BehaviorContext` - Environment info (screen bounds, cursor, time)
- `Position` / `ScreenRect` / `ScreenEdge` - Geometry primitives
- `Scene` / `SceneTrack` / `SceneSegment` - Choreographed animation data
- `SchedulerTrigger` - Enum distinguishing .behavior vs .scene triggers

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

### Sprite Pipeline (extract_sprites.py)
Extract frames from MP4 animations with cycle detection:
```bash
python3 scripts/extract_sprites.py \
    --input "video.mp4" --output output-dir/ \
    --start 0.5 --end 4 --detect-cycle --cycle-threshold 0.7 -v
```
Background removal is done manually on the exported raw frames, then processed
(position normalization, auto-crop) into final sprites.

## Current State (Choreographer Complete)

### Creatures
- **gris** - Pixel art pig with red scarf; real sprites for walk-left, walk-right, idle (10 frames each); generated sprites for peek, retreat, climb
- **pig-gnome** - Pixel art pig gnome with walk-left, walk-right, idle (supports traverse, stationary, cursorReactive)

### Implemented
- PeekBehavior - Peek from edges, retreat on cursor proximity
- TraverseBehavior - Walk across screen edge to edge
- StationaryBehavior - Appear, idle, disappear
- ClimberBehavior - Climb along window edges, follows window movement
- FollowBehavior (cursorReactive) - Follow cursor at safe distance, flee if too close
- ScriptedBehavior (.scene) - Plays back a track's waypoints for choreographed animations
- Animation Choreographer - Visual scene editor with multi-track waypoint placement and playback
- ScenePlayer - Multi-track coordinator, spawns one CreatureWindow per track
- AccessibilityWindowTracker - Real window detection using CGWindowListCopyWindowInfo
- GlobalCursorTracker - System-wide cursor tracking using NSEvent monitors
- Settings UI - SwiftUI window with interval sliders, creature/behavior toggles, weights
- Launch at login - SMAppService (macOS 13+), graceful fallback for SPM builds
- Multi-monitor support - Screen-aware placement (waypoint-based for scenes, random for behaviors)
- Menu bar app with IPC
- Smooth animation system with easing
- 128 unit tests
- Scene management: delete scenes, scenes list in menu bar
- Per-behavior/scene preview buttons (replaced random trigger)
- Unsaved changes confirmation dialog on choreographer close (Save/Discard/Cancel)
- Codebase audit remediation: CVDisplayLink safety, IPC security hardening, path sanitization, weighted random fix, dead code removal
- Typed behavior metadata: `BehaviorMetadata` enum replaces `[String: String]` dictionary
- IPC async: `IPCService.send()` async overload with `Task.sleep`
- Track deletion in choreographer: trash icon per track + confirmation dialog
- Synchronization.Mutex migration: NSLock + `@unchecked Sendable` → `Mutex<State>` across 12 types

### Potential Future Work
- More creatures and animations
- Additional behaviors (e.g., dancing, sleeping, interacting with windows)
- Custom creature editor
- Drag-and-drop sprite import
- Notification-triggered appearances
- Test coverage expansion (IPCService, ImageCache, CLI, Settings persistence)

## Conventions

- Use `@MainActor` for all UI-related code
- Behaviors must be `Sendable`
- Store ephemeral data in typed `BehaviorMetadata` structs (enum cases on `BehaviorState.metadata`)
- Emit `BehaviorEvent`s for state changes, don't mutate external state
- Personality traits should affect behavior parameters (duration, speed, sensitivity)
- Thread safety via `Synchronization.Mutex`: inner `State` struct + `Mutex<State>`, use `withLock { }` (not NSLock)

## Known Issues

- `Settings` type name conflicts with `SwiftUI.Settings` - use `AppSettings` typealias in PocketGrisApp files that import SwiftUI
- `Scene` and `SceneStorage` in PocketGrisCore conflict with SwiftUI types - use `PGScene`/`PGSceneStorage` typealiases (defined in `ChoreographerViewModel.swift`)
- AppDelegate is NOT `@MainActor` - classes instantiated as its properties (ScenePlayer, ChoreographerController) can't be `@MainActor` either
- Launch at login requires a proper .app bundle; SPM builds will log a warning but continue
- ~~`onChange(of:)` single-parameter form is deprecated~~ FIXED: Platform bumped to macOS 15, all onChange calls migrated to 2-param form, ObservableObject → @Observable
- Multi-monitor: ~~ScenePlayer places tracks on random screens~~ FIXED; ~~cursor Y-flip uses only NSScreen.main~~ FIXED

## Files to Know

- `Sources/PocketGrisCore/Behavior/Behavior.swift` - Protocol + Registry
- `Sources/PocketGrisCore/Behavior/BehaviorMetadata.swift` - Typed metadata structs + enum
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
- `Sources/PocketGrisCore/Scene/SceneTypes.swift` - Scene, SceneTrack, SceneSegment, SnapMode
- `Sources/PocketGrisCore/Scene/SceneStorage.swift` - JSON persistence for scenes
- `Sources/PocketGrisCore/Behavior/ScriptedBehavior.swift` - Behavior for track playback
- `Sources/PocketGrisApp/ScenePlayer.swift` - Multi-track scene coordinator
- `Sources/PocketGrisApp/Choreographer/ChoreographerController.swift` - Overlay + panel lifecycle
- `Sources/PocketGrisApp/Choreographer/ChoreographerViewModel.swift` - Shared state + typealiases
- `Sources/PocketGrisApp/Choreographer/ChoreographerOverlayWindow.swift` - Fullscreen overlay
- `Sources/PocketGrisApp/Choreographer/ChoreographerOverlayView.swift` - Waypoint/path rendering
- `Sources/PocketGrisApp/Choreographer/ChoreographerPanelController.swift` - Tool panel (NSPanel)
- `Sources/PocketGrisApp/Choreographer/ChoreographerPanelView.swift` - Panel UI controls
- `AGENTS/content-in/PROGRESS.md` - Detailed session history
