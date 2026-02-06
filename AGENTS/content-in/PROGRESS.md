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

---

## Session: 2026-02-06

#### Sprite Pipeline & Real Gris Animations
- **Simplified extract_sprites.py**: Removed background removal (checkerboard/solid-color detection, flood-fill logic, `--bg`/`--bg-tolerance` args). ~260 lines removed. Bg removal now done manually on exported raw frames.
- **Kept**: ffmpeg extraction, time range, sample-rate, cycle detection, position normalization, auto-crop/resize, creature.json recommendation
- **Extracted real Gris animations** from `Gris traverse.mp4`:
  - Walk cycle (0.5–4s): 10-frame cycle detected at threshold 0.7
  - Idle (4–7s): 10-frame cycle detected
  - Manual background removal, then processed (normalize + auto-crop) into final sprites
- **walk-left**: 10 frames @ 508x536 — real pixel art replacing generated sprites
- **walk-right**: 10 frames @ 508x536 — horizontally flipped walk-left
- **idle**: 10 frames @ 496x546 — real pixel art replacing generated sprites
- **creature.json updated**: frame counts 8→10, fps adjusted to 8 for walk-left, walk-right, idle

#### Animation Choreographer (6 phases) ✅
- **Scene Data Model** (PocketGrisCore):
  - `Scene` > `SceneTrack` > `SceneSegment` with invariant: segments.count == waypoints.count - 1
  - `SnapMode` enum for waypoint snapping (none, screenEdge, windowEdge)
  - `SceneStorage` for JSON persistence to ~/Library/Application Support/PocketGris/scenes/
  - `ScriptedBehavior` - Behavior protocol implementation that plays back a track's waypoints
- **Scene Playback** (PocketGrisApp):
  - `ScenePlayer` - Multi-track coordinator, spawns one CreatureWindow per track
  - Integrates with `BehaviorScheduler` via `SchedulerTrigger` enum (.behavior or .scene)
  - `CreatureViewModel` second init for direct `any Behavior` injection
  - `CreatureWindow.show()` overload for direct behavior (no registry lookup)
- **Choreographer UI** (PocketGrisApp/Choreographer/):
  - `ChoreographerController` - Owns overlay + panel lifecycle, manages recording state
  - `ChoreographerViewModel` - Shared state (NOT @MainActor, AppDelegate pattern)
  - `ChoreographerOverlayWindow` - Fullscreen transparent overlay for waypoint placement
  - `ChoreographerOverlayView` - SwiftUI view rendering waypoints, paths, creature previews
  - `ChoreographerPanelController` - Floating tool panel (NSPanel)
  - `ChoreographerPanelView` - SwiftUI UI for track/creature selection, playback controls
- **Integration**:
  - `BehaviorTypes.swift` - Added `.scene` case
  - `Settings.swift` - Added `sceneWeights` dictionary
  - `BehaviorScheduler.swift` - `SchedulerTrigger` enum, `setUnifiedTriggerHandler`, scene-aware selection
  - `AppDelegate.swift` - ScenePlayer init, choreographer menu item (Cmd+Shift+C), multi-window support
  - `SettingsView.swift` - `.scene` case in behavior display name switch
  - `PGScene`/`PGSceneStorage` typealiases resolve SwiftUI.Scene/SceneStorage name conflicts
- **Tests**: 29 new tests (13 SceneTests + 16 ScriptedBehaviorTests) → **116 total**

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 116 tests passing
- CLI: ✅ Works (`swift run pocketgris behaviors list` shows all 6 behavior types)
- GUI: ✅ Runs, supports peek, traverse, stationary, climber, cursorReactive, scene
- Settings: ✅ Full SwiftUI settings window with live persistence
- Choreographer: ✅ Visual scene editor with multi-track playback

### All Phases Complete (0-8 + Choreographer)

The core feature set and choreographer are complete. Potential future work:
- More creatures and sprite art
- Additional behaviors (dancing, sleeping, window-interacting)
- Custom creature editor / drag-and-drop sprite import
- Notification-triggered appearances
- Proper .app bundle for distribution (enables launch at login, code signing)
- App Store submission

---

## Continuation Prompt

```
Continue working on pocket-gris. All 8 phases + Animation Choreographer are complete.

Current state:
- Phases 0-8 + Choreographer complete
- 116 unit tests passing
- 6 behavior types: peek, traverse, stationary, climber, cursorReactive (follow), scene
- Animation Choreographer with visual waypoint editor and multi-track playback
- Settings UI with interval/creature/behavior configuration
- Multi-monitor support, launch at login (SMAppService)
- Two creatures: "gris" (pixel art, 12 animations) and "pig-gnome" (pixel art, walk + idle)

Key choreographer files:
- Sources/PocketGrisCore/Scene/ - SceneTypes, SceneStorage
- Sources/PocketGrisCore/Behavior/ScriptedBehavior.swift - Track playback behavior
- Sources/PocketGrisApp/ScenePlayer.swift - Multi-track coordinator
- Sources/PocketGrisApp/Choreographer/ - 6 files (Controller, ViewModel, Overlay, Panel)
- Tests/PocketGrisCoreTests/SceneTests.swift - 13 tests
- Tests/PocketGrisCoreTests/ScriptedBehaviorTests.swift - 16 tests

To test: swift build && swift test
To run app: swift run PocketGrisApp
To open choreographer: Cmd+Shift+C (while app is running)
```
