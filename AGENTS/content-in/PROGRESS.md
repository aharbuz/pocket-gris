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

#### Phase 5: Traversal & Stationary Behaviors ✅
- **TraverseBehavior**: Walk across screen from one edge to the opposite
  - Horizontal traversal (left→right or right→left)
  - Position updates emitted during perform phase
  - Speed based on personality (shy=80, curious=120, mischievous=150, chaotic=180 px/s)
  - Cursor proximity causes speed boost
  - Uses walk-left/walk-right animations (falls back to idle)
- **StationaryBehavior**: Appear at edge, do antics, disappear
  - Appears at random edge (left, right, or bottom)
  - Plays idle animation during perform phase
  - Duration based on personality (shy=2-4s, curious=4-8s, etc.)
  - Cursor proximity triggers early flee
- **Walk animations**: Added walk-left/walk-right to gris creature
  - 8 frames at 10 fps, looping
  - Generated via updated Python sprite generator
- **CreatureViewModel enhancements**:
  - Smooth position following during perform phase
  - Flip direction based on movement direction (not just edge)
- **10 new unit tests** for TraverseBehavior and StationaryBehavior (65 total)

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 65 tests passing
- CLI: ✅ Works (`swift run pocketgris behaviors list` shows traverse, stationary, peek)
- GUI: ✅ Runs, supports all three behavior types

### Remaining Phases

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
Continue implementing pocket-gris from Phase 6.

Current state:
- Phases 0-5 complete (foundation, peek, GUI shell, animation polish, traverse/stationary)
- 65 unit tests passing
- 3 behaviors: peek, traverse, stationary
- Test creature "gris" with 11 animations (peek, retreat, idle, walk)
- Menu bar app with smooth position following for traverse behavior

Next steps:
1. Phase 6: Window Tracking - AccessibilityWindowTracker, ClimberBehavior
2. Attach creatures to moving windows
3. Continue through remaining phases

Key files:
- Sources/PocketGrisCore/Behavior/ - Behaviors (PeekBehavior, TraverseBehavior, StationaryBehavior)
- Sources/PocketGrisApp/CreatureViewModel.swift - View model with position following
- Tests/PocketGrisCoreTests/BehaviorTests.swift - Behavior unit tests

To test: swift build && swift test
To list behaviors: swift run pocketgris behaviors list
To trigger specific behavior: swift run pocketgris trigger --behavior traverse --gui
To run app: swift run PocketGrisApp
```
