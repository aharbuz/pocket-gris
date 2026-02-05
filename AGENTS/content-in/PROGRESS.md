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

#### Phase 6: Window Tracking ✅
- **WindowTracker protocol**: Interface for getting window frames
- **AccessibilityWindowTracker**: Real implementation using CGWindowListCopyWindowInfo
  - Excludes own app, Dock, Control Center, Notification Center
  - Filters out tiny windows and desktop elements
  - Returns ScreenRect frames for all visible windows
- **MockWindowTracker**: Test implementation for unit tests
- **ClimberBehavior**: Climb along window edges
  - Attaches to random window edge (top, left, right, bottom)
  - Climbs in random direction along the edge
  - Speed based on personality (shy=40, curious=70, mischievous=100, chaotic=130 px/s)
  - Cursor proximity triggers flee
  - Falls back gracefully when no windows available
  - **Window movement tracking**: Creature follows if window is dragged/resized
  - Handles window close gracefully (continues with last trajectory)
- **ScreenRect extensions**: randomPositionOnEdge, cornerPosition, isNearEdge
- **Climb animation**: Added to gris creature (8 frames, 10fps)
- **CreatureViewModel**: Now accepts optional WindowTracker, passes windowFrames to context
- **AppDelegate/CreatureWindow**: Wired up AccessibilityWindowTracker
- **13 unit tests** for ClimberBehavior, MockWindowTracker, ScreenRect edges, window movement (78 total)

#### Phase 7: Cursor Interaction ✅
- **CursorTracker protocol**: Interface for system-wide cursor tracking
- **GlobalCursorTracker**: Real implementation using NSEvent.addGlobalMonitorForEvents
  - Tracks cursor position across all apps and spaces
  - Calculates cursor velocity with exponential smoothing
  - Uses both global and local event monitors
- **MockCursorTracker**: Test implementation for unit tests
- **FollowBehavior**: Creature follows cursor at a safe distance
  - Maintains personality-based follow distance (shy=200px, chaotic=60px)
  - Moves toward cursor position smoothly
  - Flees if cursor gets too close (personality-based threshold)
  - Switches between idle and walk animations based on movement
  - Duration-based, ends after set time
- **CreatureViewModel**: Updated to accept optional CursorTracker dependency
- **AppDelegate/CreatureWindow**: Wired up GlobalCursorTracker
- **9 new unit tests** for FollowBehavior, MockCursorTracker (87 total)

#### Phase 8: Polish ✅
- **Settings UI**: SwiftUI window accessible from menu bar (Cmd+,)
  - Appearance interval sliders (min 1-60 min, max 1-120 min)
  - Creature enable/disable toggles with personality labels
  - Behavior enable/disable toggles with weight sliders (0.1-3.0)
  - "Test Random Behavior" button for instant trigger
  - Launch at login toggle
  - Reset to Defaults button
  - Live persistence to ~/Library/Application Support/PocketGris/settings.json
  - Uses `AppSettings` typealias to disambiguate from `SwiftUI.Settings`
- **SettingsWindowController**: NSWindow host with frame autosave, single-instance
- **LaunchAtLoginManager**: SMAppService (macOS 13+) with graceful SPM fallback
- **Multi-monitor support**: Creatures appear on random screen via `NSScreen.screens`
  - CreatureWindow accepts target screen parameter
  - AppDelegate picks random screen on each trigger
- **Performance**: Already well-optimized (event-driven cursor, display link only when visible, bounded image cache)

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 87 tests passing
- CLI: ✅ Works (`swift run pocketgris behaviors list` shows all 5 behaviors)
- GUI: ✅ Runs, supports peek, traverse, stationary, climber, cursorReactive
- Settings: ✅ Full SwiftUI settings window with live persistence

### All Phases Complete (0-8)

The core feature set is complete. Potential future work:
- More creatures and sprite art
- Additional behaviors (dancing, sleeping, window-interacting)
- Custom creature editor / drag-and-drop sprite import
- Notification-triggered appearances
- Proper .app bundle for distribution (enables launch at login, code signing)
- App Store submission

---

## Continuation Prompt

```
Continue working on pocket-gris. All 8 phases are complete.

Current state:
- Phases 0-8 complete (foundation through polish)
- 87 unit tests passing
- 5 behaviors: peek, traverse, stationary, climber, cursorReactive (follow)
- Settings UI with interval/creature/behavior configuration
- Multi-monitor support, launch at login (SMAppService)
- Test creature "gris" with 12 animations

Potential next steps:
- Create additional creatures with unique personalities and animations
- Add new behaviors (e.g., dancing, sleeping on window title bars)
- Build a proper .app bundle with Xcode for distribution
- Add a creature editor or drag-and-drop sprite import
- Notification-triggered or event-triggered appearances
- Menu bar icon that changes based on creature activity

Key files:
- Sources/PocketGrisCore/Behavior/ - All behavior implementations
- Sources/PocketGrisCore/Services/ - CursorTracker, WindowTracker
- Sources/PocketGrisApp/ - App delegate, settings, creature window
- Tests/PocketGrisCoreTests/BehaviorTests.swift - All behavior tests

To test: swift build && swift test
To run app: swift run PocketGrisApp
To trigger: swift run pocketgris trigger --behavior cursorReactive --gui
```
