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

---

## Session: 2026-02-11

#### Choreographer Bug Fixes
- **Fixed app freeze on opening Choreographer**: Overlay window was at `.modalPanel` level (8) while the panel was at `.floating` level (3). The fullscreen overlay intercepted all mouse events, making the panel unreachable. Fixed by changing overlay to `.floating` level.
- **Fixed Escape closing choreographer accidentally**: Escape now only stops waypoint placement mode, never closes the choreographer. Close via the panel's "Close" button or red X instead.
- **Fixed overlay mouse event passthrough**: Added Combine subscription to toggle `ignoresMouseEvents` based on `isPlacing` state. Overlay only captures clicks during active waypoint placement; passes through to panel otherwise.
- **Fixed overlay not cleaning up on close**: Added `teardown()` method that cancels Combine subscription, clears contentView/viewModel, and calls `orderOut(nil)`.
- **Fixed red X close button not cleaning up overlay**: Made `ChoreographerPanelController` an `NSWindowDelegate`, implementing `windowWillClose` to trigger `viewModel.onClose?()` — ensuring the overlay is cleaned up regardless of how the panel is closed.

#### Choreographer UX Improvements
- **Panel stays interactive during placement**: Panel window level rises above overlay (`floating + 1`) when `isPlacing` is true, controlled via Combine subscription in `ChoreographerController`. Overlay retains key window status for Esc handling.
- **Animated sprite preview at cursor**: Ghost sprite follows mouse during waypoint placement, showing the active creature/animation. Timer-driven frame cycling with `AnimationState`, frames preloaded via `ImageCache`. Preview updates live when creature or animation selection changes in the panel.
- **Fixed preview timer not stopping on close**: `close()` now explicitly sets `isPlacing = false` before teardown, triggering `stopPreview()` to invalidate the timer — same cleanup pattern as previous waypoint fix.
- **New type conflict**: `AnimationState` in PocketGrisCore conflicts with `SwiftUI.AnimationState` — resolved with `PocketGrisCore.AnimationState` qualification in ViewModel.

#### Choreographer Mid-Placement Interaction Fixes
- **Creature picker updates track**: Switching creature mid-placement now updates the selected track's `creatureId` and fixes invalid segment animation names (pushes undo)
- **Empty track pruning**: Tracks with 0 waypoints are auto-removed on add track, select track, save, and preview — prevents accumulation of abandoned tracks
- **Delete selected track exits placement**: Deleting the track being placed sets `isPlacing = false`
- **Undo validates state**: After undo, `selectedTrackIndex` is validated against the restored scene; pickers re-sync from track data (creature + animation)
- **Save exits placement**: Prunes empty tracks and stops placement mode before saving
- **Preview exits placement**: Stops placement and prunes before playing scene preview
- **Suppressed double preview restarts**: `suppressPreviewRestart` flag prevents `didSet` observers on `activeCreatureId`/`activeAnimation` from each triggering `startPreview()` during batch updates

#### CLI Headless Behavior Testing
- **New `pocketgris test behavior` command**: Runs behaviors headlessly without GUI
  - Outputs structured JSON state for each frame
  - Uses `SeededRandomSource` for reproducible, deterministic output
  - Options: `--creature`, `--frames`, `--delta-time`, `--seed`, `--screen-width`, `--screen-height`
  - `--compact` flag outputs summary only (phase transitions, completion status)
- **Output includes**: frame number, time, phase, position, edge, animation state, events, metadata
- **Enables CI testing**: Behaviors can be validated without GUI app running

#### Choreographer UX Batch (UR-002)
Session continuing from above.

- **Smooth cursor preview animation**: Fixed jumpy cursor-following sprite preview by adding CVDisplayLink-based position smoothing with exponential interpolation. Preview now smoothly tracks cursor at 60fps instead of updating position directly from mouse events.
- **Segment reordering**: Added up/down chevron buttons and context menu options to reorder segments in the panel's segment list. Segments swap properties (animation, duration, snapMode) while waypoints remain in place.
- **Segment deletion**: Added context menu "Delete Segment" option that removes the segment and its corresponding waypoint while maintaining the segments.count == waypoints.count - 1 invariant.
- **Waypoint animation labels**: Each waypoint now displays its associated animation name below it. Waypoint 0 shows the first segment's animation; waypoint N shows segment N-1's animation.
- **Segment creation UX**: Added "+" button to Segments header that extends the track by adding a new waypoint/segment. Animation picker now shows "(editing segment)" hint when a segment is selected, and changing animation updates both the active animation AND the selected segment's animation.
- **Waypoint drag-to-move**: Waypoints can now be dragged to reposition them. Drag gesture captures undo state at start, updates position in real-time during drag.

#### Choreographer Cleanup (UR-003)
- **Removed duplicate snap modes**: Consolidated `onTopOfWindow`/`windowTop` and `underneathWindow`/`windowBottom` — kept the consistent `windowTop/windowBottom` naming to match `windowLeft/windowRight`

#### Choreographer Interaction Fixes (UR-004)
- **Fixed panel freezing on Escape**: Panel now always stays above overlay (`floating + 1` level) regardless of placement mode. Previously, panel level dropped when `isPlacing` became false, making it unreachable behind the event-capturing overlay.
- **Fixed background click-through**: Added `.allowsHitTesting(viewModel.isPlacing)` to the overlay's Color.clear background. Clicks only captured during placement mode; waypoints remain interactive always.
- **Fixed waypoint drag flying off screen**: Added `@State dragStartPosition` to capture the position when drag begins. Prevents issues where view re-renders during drag cause the starting position reference to change mid-gesture.

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
To test behaviors headlessly: swift run pocketgris test behavior peek --creature gris --frames 500 --compact
```
