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

#### Phase 6: Window Tracking (In Progress)
- **WindowTracker protocol**: Interface for getting window frames
- **MockWindowTracker**: Test implementation for unit tests
- **ClimberBehavior**: Climb along window edges
  - Attaches to random window edge (top, left, right, bottom)
  - Climbs in random direction along the edge
  - Cursor proximity triggers flee
  - Falls back gracefully when no windows available
- **ScreenRect extensions**: randomPositionOnEdge, cornerPosition, isNearEdge
- **Climb animation**: Added to gris creature (8 frames, 10fps)
- **CreatureViewModel**: Now accepts optional WindowTracker, passes windowFrames to context
- **Unit tests**: ClimberBehavior tests, MockWindowTracker tests, ScreenRect edge tests

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ ~75 tests passing (Phase 6 tests added)
- CLI: ✅ Works (`swift run pocketgris behaviors list` shows all 4 behaviors)
- GUI: ✅ Runs, supports peek, traverse, stationary, climber

### Remaining Work

#### Phase 6: Window Tracking (TODO)
- [ ] AccessibilityWindowTracker (real implementation using Accessibility API)
- [ ] Wire up WindowTracker in AppDelegate/CreatureWindow
- [ ] Test with actual windows

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
Continue implementing pocket-gris - finish Phase 6 Window Tracking.

Current state:
- Phases 0-5 complete, Phase 6 partially done
- ~75 unit tests passing
- 4 behaviors: peek, traverse, stationary, climber
- ClimberBehavior implemented with MockWindowTracker for tests
- WindowTracker protocol defined, CreatureViewModel accepts it

Remaining Phase 6 work:
1. Implement AccessibilityWindowTracker using macOS Accessibility API
2. Wire up real WindowTracker in AppDelegate when creating CreatureWindow
3. Test climber behavior with actual application windows
4. Handle window movement (creature should follow its attached window)

Key files:
- Sources/PocketGrisCore/Behavior/ClimberBehavior.swift - Window climbing behavior
- Sources/PocketGrisCore/Services/WindowTracker.swift - Protocol + MockWindowTracker
- Sources/PocketGrisApp/CreatureViewModel.swift - Accepts WindowTracker
- Tests/PocketGrisCoreTests/BehaviorTests.swift - Climber tests

To test: swift build && swift test
To trigger climber: swift run pocketgris trigger --behavior climber --gui
```
