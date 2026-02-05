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

---

## Session: 2026-02-05

#### Phase 4: Animation Polish ✅
- **Test creature "gris"**: Created with Python script generating 64x64 PNG frames
  - 9 animations: peek-left/right/top/bottom, retreat-left/right/top/bottom, idle
  - creature.json manifest with personality and animation definitions
- **ImageCache**: Thread-safe NSImage caching for sprite frames
  - Singleton with max cache size (500 images)
  - Background preloading of creature animations
  - Prevents repeated disk reads during animation
- **Smooth sliding animations**: Creature slides in/out from screen edges
  - displayPosition (interpolated) vs position (from behavior)
  - Ease-out cubic interpolation for natural deceleration
  - Offscreen start/end positions based on edge
- **CLI creatures list**: Now actually loads and displays creatures
- **Fixed main.swift**: NSApplication initialization order
- **5 new unit tests** for SpriteLoader (55 total)

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 55 tests passing
- CLI: ✅ Works (`swift run pocketgris creatures list` shows gris)
- GUI: ✅ Runs, loads creatures, responds to triggers

### Remaining Phases

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
Continue implementing pocket-gris from Phase 5.

Current state:
- Phases 0-4 complete (foundation, peek behavior, GUI shell, animation polish)
- 55 unit tests passing
- Test creature "gris" with PNG animations
- Menu bar app with sliding entrance/exit animations
- ImageCache for efficient sprite rendering

Next steps:
1. Phase 5: Add TraverseBehavior (walk across screen) and StationaryBehavior
2. Path animation system for smooth movement
3. Continue through remaining phases

Key files:
- Sources/PocketGrisCore/ - Pure Swift library
- Sources/PocketGrisCLI/CLI.swift - Command line interface
- Sources/PocketGrisApp/ - Menu bar app (AppDelegate, CreatureWindow, CreatureViewModel, SpriteView, ImageCache)
- Tests/PocketGrisCoreTests/ - Unit tests
- Resources/Sprites/gris/ - Test creature with animations
- scripts/generate_sprites.py - Sprite generation script

To test: swift build && swift test && swift run pocketgris creatures list
To run: swift run PocketGrisApp (check menu bar for pawprint icon)
To trigger: swift run pocketgris trigger --gui
```
