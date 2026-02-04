# Pocket-Gris Progress

## Session: 2026-02-04

### Completed Phases

#### Phase 0: Project Setup ✅
- Created folder structure (Sources, Tests, Resources, AGENTS)
- Initialized git repo
- Created README.md
- Pushed to aharbuz/pocket-gris (private)

#### Phase 1: Foundation ✅
- Package.swift with 3 targets (Core/CLI/App)
- Core value types: Position, ScreenRect, ScreenEdge, Animation, AnimationState
- Creature types: Creature, Personality, CreatureManifest
- Settings with JSON persistence
- Behavior system: BehaviorType, BehaviorPhase, BehaviorState, BehaviorEvent, BehaviorContext
- Behavior protocol with PeekBehavior implementation
- BehaviorRegistry for managing behaviors
- Protocol-based DI: TimeSource, RandomSource (with mock/seeded variants)
- IPCService for file-based CLI→GUI communication
- CLI with commands: version, status, trigger, creatures, simulate, control, behaviors
- 34 unit tests

#### Phase 2: Peek Behavior MVP ✅
- BehaviorScheduler with weighted behavior selection
- PositionCalculator for edge positions, paths, cursor fleeing
- SpriteLoader for loading creature assets from disk
- Additional unit tests (50 total)

#### Phase 3: GUI Shell ✅
- Menu bar app with NSStatusItem (pawprint icon)
- Floating transparent NSWindow (click-through, all spaces)
- SwiftUI SpriteView with animated placeholder sprite
- CreatureViewModel bridging Core→SwiftUI (@MainActor)
- CVDisplayLink-based animation loop
- IPC listener responding to CLI commands
- Menu: Trigger Now, Enabled toggle, Settings, Quit

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 50 tests passing
- CLI: ✅ Works (`swift run pocketgris version`)
- GUI: ✅ Builds, shows menu bar icon, displays placeholder sprite

### Remaining Phases

#### Phase 4: Full Animation
- Frame-by-frame animation timer improvements
- Window position animation (enter/exit sliding)
- Sprite caching
- Full scheduler integration
- Menu bar controls refinement

#### Phase 5: Traversal & Stationary Behaviors
- TraverseBehavior (walk across screen)
- StationaryBehavior (appear, do antics, disappear)
- Path animation system (waypoints, bezier curves)

#### Phase 6: Window Tracking
- AccessibilityWindowTracker
- ClimberBehavior
- Attach creatures to moving windows

#### Phase 7: Cursor Interaction
- Global NSEvent monitor
- CursorReactiveBehavior (flee, follow, hide)

#### Phase 8: Polish
- Settings UI
- Launch at login
- Multi-monitor support
- Performance optimization

---

## Continuation Prompt

```
Continue implementing pocket-gris from Phase 4.

Current state:
- Phases 0-3 complete (foundation, peek behavior, GUI shell)
- 50 unit tests passing
- Menu bar app builds and shows placeholder sprite
- No real sprite assets yet (uses placeholder)

Next steps:
1. Phase 4: Improve animation system - add sliding entrance/exit, sprite caching
2. Create a test creature with placeholder PNG frames to verify full pipeline
3. Phase 5: Add TraverseBehavior and StationaryBehavior
4. Continue through remaining phases

The plan is in the git history or can be referenced from the original planning session.

Key files:
- Sources/PocketGrisCore/ - Pure Swift library
- Sources/PocketGrisCLI/CLI.swift - Command line interface
- Sources/PocketGrisApp/ - Menu bar app (AppDelegate, CreatureWindow, CreatureViewModel, SpriteView)
- Tests/PocketGrisCoreTests/ - Unit tests

To test: swift build && swift test && swift run pocketgris version
```
