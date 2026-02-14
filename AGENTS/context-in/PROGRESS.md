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

#### Choreographer Cleanup (UR-003) ✅
- **Removed duplicate snap modes**: Consolidated `onTopOfWindow`/`windowTop` and `underneathWindow`/`windowBottom` — kept the consistent `windowTop/windowBottom` naming to match `windowLeft/windowRight`

#### Choreographer Interaction Fixes (UR-004) ✅
- **Fixed panel freezing on Escape**: Panel now always stays above overlay (`floating + 1` level) regardless of placement mode. Previously, panel level dropped when `isPlacing` became false, making it unreachable behind the event-capturing overlay.
- **Fixed background click-through**: Added `.allowsHitTesting(viewModel.isPlacing)` to the overlay's Color.clear background. Clicks only captured during placement mode; waypoints remain interactive always.
- **Fixed waypoint drag flying off screen**: Added `@State dragStartPosition` to capture the position when drag begins. Prevents issues where view re-renders during drag cause the starting position reference to change mid-gesture.
- **Verified working**: All fixes tested and confirmed functional.

#### Choreographer UI Polish (UR-005) ✅
Completed 5 REQs for UI improvements:
- REQ-010: Pre-load default track on open (gris, walk-left, snap none, delay 0, duration 2s) → 9aa3716
- REQ-011: Conditional button states (grey out until ready) → d338d54
- REQ-012: Hide "segment" terminology - nested bullet/disclosure UI with collapsible path steps → d572460
- REQ-013: Segment selection with visual highlighting (per-segment path thickness, endpoint glow, click to deselect) → d5f31d6
- REQ-014: Segment opacity gradient (100% → 30% fade for temporal order) → 3e9f28e

---

## Session: 2026-02-12

#### Choreographer Panel UI Rework
Restructured the panel to move creature/snap controls from top-level into the track/segment hierarchy:

**ViewModel Changes (ChoreographerViewModel.swift):**
- Removed stored `activeCreatureId`, `activeAnimation`, `activeSnapMode` properties
- Made `activeCreatureId` a computed property deriving from selected track
- Made `activeAnimation` derive from selected track's last segment or first available
- Made `activeSnapMode` derive from selected track's last segment
- Added `expandedSegmentIndices: [Int: Set<Int>]` for per-track expanded segment tracking
- Added helper methods: `isSegmentExpanded`, `toggleSegmentExpanded`, `setSegmentExpanded`
- Updated `extendTrack()` to collapse all segments and expand the new one
- Removed `suppressPreviewRestart` flag (no longer needed with derived state)

**Panel View Changes (ChoreographerPanelView.swift):**
- Removed global "Creature" dropdown section
- Removed global "Snap Mode" picker section
- Removed separate "Path" section header
- Renamed "Tracks" to "Creatures"
- Added creature picker dropdown inside each track header
- Track selection expands to show delay slider + nested segment list
- Unselected tracks show summary "(N segments)"
- Segment collapsed state now shows: chevron + animation + snap mode + duration + reorder buttons (↑↓)
- Segment expanded state shows: animation picker, snap mode picker, duration slider, delete button
- "Add Segment" button at end of segment list
- Collapse-on-add: adding segment collapses siblings and expands new one

**New Panel Layout:**
```
┌─────────────────────────────────────┐
│ [Scene Name]                        │
├─────────────────────────────────────┤
│ Creatures                       [+] │
│                                     │
│ 🔵 [gris ▼]                         │  ← Track header with creature picker
│   Delay: [====] 0.0s                │
│   ▸ walk-right • none • 2.0s  [↑↓]  │  ← Collapsed segment
│   ▾ walk-left • none • 1.5s   [↑↓]  │  ← Expanded segment header
│     Animation: [walk-left ▼]        │
│     Snap Mode: [none ▼]             │
│     Duration:  [====] 1.5s          │
│     [Delete Segment]                │
│   [+ Add Segment]                   │
│                                     │
│ 🟢 [pig-gnome ▼]                    │  ← Unselected track
│   (2 segments)                      │
├─────────────────────────────────────┤
│ [Preview] [Save] [Load] [New]       │
│ [Close]                             │
└─────────────────────────────────────┘
```

#### Choreographer Panel UI Refinements
Follow-on polish based on user feedback:

**Animation Picker in Header (expanded state):**
- When segment is expanded, animation picker now appears in header row instead of text
- Removed duplicate "Animation:" row from expanded details section
- Collapsed state still shows animation name as text

**Pending Segment for Empty Tracks:**
- New tracks now show a "pending segment" row instead of placeholder text
- Pending row is always expanded with highlighted background
- Shows editable defaults: animation picker, snap mode, duration slider
- Caption: "Will be created when you place 2 waypoints"
- Added `pendingAnimation`, `pendingSnapMode`, `pendingDuration` properties to ViewModel
- First segment created uses pending values

**Button Layout Rework:**
- Changed from 3 rows to 2 rows for cleaner appearance
- Row 1: `[Preview] [Undo] [New]`
- Row 2: `[Save] [Load] ... [Close]`

**Removed Line Opacity Gradient:**
- REQ-014's opacity fade (100% → 30%) removed per user feedback
- All segment lines now use consistent opacity

**Add Creature Button Gating:**
- "+" button next to "Creatures" now disabled until current track has ≥1 segment
- Prevents creating multiple empty tracks
- Added `canAddCreatureTrack` computed property

**Segment Expansion Behavior:**
- First segment auto-expands when created (after placing 2 waypoints)
- Adding 2nd segment keeps both expanded (no collapse)
- Adding 3rd+ segment collapses existing and expands only the new one
- Supports single-segment scenes (e.g., idling creature) without auto-collapse

#### Choreographer Preview Fixes (UR-008)
- **REQ-016**: Fixed creature preview not updating on switch (Route B)
  - Modified `startPreview()` to set initial frame immediately without going through nil
  - Prevents preview flicker/stale frame when switching creatures
- **REQ-017**: Fixed animation preview not updating on switch (Route B)
  - `updateSegment()` now calls `startPreview()` when animation changes on the last segment
  - `pendingAnimation` didSet observer refreshes preview when pending animation changes
  - `activeAnimation` computed property now checks `pendingAnimation` before falling back to first available

**Untitled Scene Numbering (REQ-015):**
- New scenes now increment: "Untitled Scene", "Untitled Scene 2", "Untitled Scene 3"
- Scans existing scenes in storage to find next available number
- Preserves existing scene's name when calling New Scene (only affects newly created scene)

#### Choreographer Polish (UR-009)
- **REQ-018**: Smoother mouse preview cursor following
  - Increased `cursorSmoothingSpeed` from 15.0 to 30.0 (~50% catch-up per frame vs ~25%)
  - Preview now stays much closer to cursor while remaining smooth
- **REQ-019**: Fix menu bar hover events not firing
  - Added `menu.autoenablesItems = false` to prevent hover lag from automatic enable checks
- **REQ-020**: New Scene creates default track like initial open
  - `newScene()` now mirrors `init()` logic: creates default track with gris creature
  - Resets pending segment state, sets `isPlacing = true`
- **REQ-021**: Open last scene when reopening choreographer
  - Persists last scene ID to UserDefaults on save/load/edit
  - Choreographer opens to last worked-on scene instead of blank

### All Phases Complete (0-8 + Choreographer + UI Polish)

The core feature set, choreographer, and UI polish are complete. Potential future work:
- More creatures and sprite art
- Additional behaviors (dancing, sleeping, window-interacting)
- Custom creature editor / drag-and-drop sprite import
- Notification-triggered appearances
- Proper .app bundle for distribution (enables launch at login, code signing)
- App Store submission

---

## Session: 2026-02-12 (continued)

#### Scene Management & Preview System (UR-010)

**REQ-022: Scene Deletion** (Route B) → 9e4d5f6
- Added `deleteScene(id:)` methods to ChoreographerViewModel
- Added confirmation dialog via `.alert()` modifier in ChoreographerPanelView
- Modified Load menu to show scenes as submenus with "Open" and "Delete" options
- Connected `onSceneDeleted` callback in ChoreographerController to refresh scheduler

**REQ-023: Scenes List in Settings Menu** (Route B) → abcbf2b
- Added `scenesEnabled: Bool` property to Settings (persisted)
- Added "Scenes" submenu to menu bar with:
  - Global "Enabled" toggle
  - Per-scene submenus with Preview/Delete options
  - Dynamic refresh on scene changes
- Modified BehaviorScheduler to respect `settings.scenesEnabled`
- Added 2 new tests for scenes filtering

**REQ-024: Per-Behavior Preview Buttons** (Route B) → b3e9c75
- Added play button (play.fill icon) per behavior in SettingsView
- Added "Behaviors" submenu to menu bar with per-behavior preview items
- Renamed "Trigger Now" to "Trigger Random" and moved below Enabled toggle
- Removed "Test Random Behavior" button (replaced by per-item preview)
- Hidden `.scene` type from behaviors list (managed in Scenes submenu)
- Added `previewBehavior(_:)` method to SettingsViewModel

**REQ-025: Menu Bar & Cursor Performance** (Route B) → 0440948
- **Investigation findings:**
  - Menu bar: statusItem creation timing, deep submenu nesting
  - Cursor: smoothing at 30.0 (~50% catch-up), async dispatch latency
  - Compared with Bluesnooze (XIB-connected menu pattern)
- **Implemented fixes:**
  - Changed `statusItem` from implicitly unwrapped optional to lazy property
  - Increased `cursorSmoothingSpeed` from 30.0 to 60.0 (near-instant tracking)
- **Documented recommendations for future:**
  - NSMenuDelegate for `menuWillOpen(_:)` refresh
  - CADisplayLink instead of CVDisplayLink
  - Unify animation/position timing

**New Menu Structure:**
```
[x] Enabled (Cmd+E)
Trigger Random (Cmd+T)
---
Behaviors > Peek, Traverse, Stationary, Climber, Follow Cursor
Scenes > [x] Enabled, Scene1 > Preview/Delete, ...
---
Settings... (Cmd+,)
Choreographer... (Cmd+Shift+C)
---
Quit (Cmd+Q)
```

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 118 tests passing (2 new)
- Features: Scene deletion, scenes menu, per-behavior preview, performance improvements

#### UI Reorganization (UR-011)

**REQ-027: Add Scenes to Settings with Preview/Delete** (Route B) → 269eeb8
- Added "Scene" section to Settings window behaviors list
- Expandable disclosure control with animated chevron
- Global scenes enabled toggle and weight slider (0.1-3.0)
- Per-scene preview (play.fill icon) and delete (trash icon) buttons
- Delete confirmation dialog before removal
- "No saved scenes" placeholder when list is empty
- Updated SettingsWindowController to pass sceneStorage
- Updated AppDelegate to provide scene callbacks

**REQ-026: Simplify Tray Menu** (Route A) → fb660cf
- Removed Behaviors and Scenes submenus from tray menu
- Removed 7 related methods: rebuildBehaviorsSubmenu, rebuildScenesSubmenu, previewBehavior, previewScene, deleteScene, toggleScenesEnabled, behaviorDisplayName
- Menu now contains only essentials:
  - Enabled toggle (Cmd+E)
  - Trigger Random (Cmd+T)
  - Settings... (Cmd+,)
  - Choreographer... (Cmd+Shift+C)
  - Quit (Cmd+Q)

**New Menu Structure:**
```
[x] Enabled (Cmd+E)
Trigger Random (Cmd+T)
---
Settings... (Cmd+,)
Choreographer... (Cmd+Shift+C)
---
Quit (Cmd+Q)
```

#### Bug Fix: Scenes Section Chevron → 6bf15d0
- Fixed chevron button not responding to clicks (enlarged frame 12→16px, added contentShape)
- Changed default `scenesExpanded` from false to true (expanded by default)
- Changed button style from .plain to .borderless

#### Scene & Behavior Toggle System (UR-012) → fe8a608

**REQ-028: Add disable toggles and weights to scenes** (Route B)

Restructured Behaviors and Scenes sections with unified toggle/expand pattern:

- **Master toggles with chevrons**: Both sections now have:
  - Chevron button for expand/collapse (UI visibility)
  - Toggle for enable/disable (scheduler behavior)
  - These are independent: section can be collapsed but still enabled

- **Individual scene controls**:
  - Enable/disable toggle per scene
  - Weight slider (0.1-3.0) per scene when enabled
  - Edit button (pencil.circle) opens scene in choreographer
  - Preview and delete buttons retained

- **Behavior row refinement**:
  - Swapped play button to come before toggle
  - Consistent with scene row pattern

- **Settings persistence**:
  - Added `enabledScenes: Set<String>` to Settings
  - Added `behaviorsEnabled: Bool` to Settings
  - `buildSettings()` respects individual scene weights and enabled states

#### Auto-Collapse Toggle Behavior → 7572e58
- When master toggle (Behaviors/Scenes) turns OFF: section auto-collapses, remembers previous expanded state
- When toggle turns ON: restores previous expanded state
- Content only shows when both expanded AND enabled

#### Settings Spacing Cleanup (UR-013) → 8e0885d

**REQ-029: Fix duplicate slider labels** (Route A)
- Fixed "Weight Weight" appearing twice on each row
- Slider labels changed from `Text("Weight"/"Min"/"Max")` to `EmptyView()`
- Applied to: behavior weights, global scene weight, per-scene weights, appearance timing sliders

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 118 tests passing
- Features: Full toggle system with auto-collapse, cleaned up slider labels

---

## Session: 2026-02-13

#### Scene Cleanup on System Events (UR-014)

**REQ-030: Settings menu visual polish** - REVERTED
- Attempted to unify behavior/scene item appearance with inline weight sliders
- Changes made: heading colors changed to quaternary, unified layouts, removed global scene weight
- Reverted after user feedback - layout looked cramped/strange
- Commits: 8ca65e3 (implemented) → 4ed803f (reverted)

**REQ-031: Scene cleanup on sleep/login** (Route B) → 22d74b0
- Added NSWorkspace notification observers in AppDelegate:
  - `screensDidSleepNotification` - triggered on laptop lid close, display sleep
  - `sessionDidResignActiveNotification` - triggered on screen lock
- Handler calls `scenePlayer.cancel()` and closes any active `creatureWindow`
- Proper observer cleanup in `applicationWillTerminate()`
- Prevents creature windows from getting stuck on screen after sleep/lock events

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 118 tests passing
- Features: Scene cleanup on sleep/login events

---

## Session: 2026-02-13 (continued)

#### Unsaved Changes Confirmation (UR-015)

**REQ-032: Prompt to save unsaved changes when closing choreographer** (Route B) → 7baee7f
- Added dirty state tracking via `savedSnapshot` property in ChoreographerViewModel
- `hasUnsavedChanges` computed property compares `currentScene` to `savedSnapshot`
- Snapshot set on init (with existing scene), save, load, and newScene
- New scenes with no content are not considered dirty
- `requestClose()` checks dirty state: shows alert if unsaved, closes directly if clean
- SwiftUI `.alert()` with Save/Discard/Cancel buttons in ChoreographerPanelView
- Red window close button intercepted via `windowShouldClose(_:)` delegate in ChoreographerPanelController
- Save: saves then closes. Discard: closes without saving. Cancel: dismisses alert.
- Manually tested and confirmed working

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 118 tests passing
- Features: Unsaved changes confirmation on choreographer close

---

## Session: 2026-02-13 (audit)

#### Codebase Audit & Remediation (UR-016)

Full audit of PocketGrisCore (23 files), PocketGrisApp (18 files), PocketGrisCLI, tests, and scripts.
Checked Swift/SwiftUI patterns via Context7. Findings: 5 Critical, 11 High, 21 Medium, 20 Low.

**Commit:** 68cd09c

**Wave 1 — Critical & High-Impact Bug Fixes:**
- CVDisplayLink use-after-free: added deinit, dispatch to main before state access, [weak] refs
- Nondeterministic retreatSpeedMultiplier: .chaotic changed from Double.random to fixed 1.2
- behaviorsEnabled setting now checked in selectRandomTrigger()
- Weighted random bias: cumulative comparison pattern replaces subtract-and-check
- TraverseBehavior: cursor boost no longer compounds into stored speed
- buildSettings() preserves persisted enabled state instead of hardcoding true
- Double-close lifecycle: isClosing guard in windowWillClose
- setAboveOverlay now uses its above parameter
- Force unwrap removed from CreatureWindow.showWithViewModel
- ImageCache: double-check pattern after lock acquisition

**Wave 2 — Security Hardening:**
- SceneStorage path injection: sanitizeId() filters to alphanumeric + -_.
- IPC TOCTOU: per-user pocket-gris-ipc/ directory with 0700 permissions
- IPC fd leak: startListening() calls stopListening() first

**Wave 3 — Dead Code Cleanup:**
- Removed: _-prefixed typealiases, testBehavior(), reloadScenes(), previousPosition,
  unused PositionCalculator instances, scenesEnabled in AppDelegate
- Consolidated PGSceneLocal/PGSceneStorageLocal → PGScene/PGSceneStorage
- Renamed ImageCacheTests.swift → SpriteLoaderTests.swift

**Wave 4 — Defensive Fixes:**
- ClimberBehavior: guard totalDistance > 0 prevents division by zero
- Animation.frameFilename: guard frameCount > 0
- onChange deprecation: deferred (requires macOS 14+ platform bump)

**Deferred (out of scope):**
- M1: @unchecked Sendable → actors (Swift 6 migration)
- M2: Stringly-typed metadata → typed state
- M3: PeekBehavior duplicate phase events
- M5: ClimberBehavior window index staleness
- M6: Deprecated onChange(of:) (needs macOS 14+)
- M7-M8: IPC async, ChoreographerController bypass
- M17: SceneTrack.init allows invalid state
- M18/M19: Multi-monitor coordinate issues
- M20: Test coverage expansion
- M21: Test temp dir cleanup
- All 20 Low-severity items

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 118 tests passing
- All Critical and High findings resolved

---

## Session: 2026-02-13 (do-work queue processing)

#### Deferred Audit Remediation — Non-Large Items

Processed 3 requests from the do-work queue (UR-016 deferred audit items):

**REQ-034: Typed behavior metadata** (Route C) → ddd5f3e
- Replaced `BehaviorState.metadata: [String: String]` with typed `BehaviorMetadata` enum
- Created `BehaviorMetadata.swift` with 6 per-behavior structs: PeekMetadata, TraverseMetadata, StationaryMetadata, ClimberMetadata, FollowMetadata, ScriptedMetadata
- Enum cases: `.none`, `.peek(...)`, `.traverse(...)`, etc. — naturally Equatable + Sendable
- Removed unused metadata keys: startEdge/endEdge (Traverse), hiddenOffset (Stationary), windowEdge/climbDirection (Climber), lastCursorX/Y (Follow)
- Updated CLI with `dictionaryRepresentation` for backward-compatible JSON output
- Updated 4 test assertions from string-based to typed pattern matching

**REQ-038: IPC async + ChoreographerController unification** (Route B) → 0f8b7fc
- Added async `send(_:timeout:)` overload to IPCService using `Task.sleep`
- Extracted `writeCommand(_:)` helper to isolate NSLock from async context
- Unified `openChoreographer()` and `openChoreographerWithScene(_:)` into single method

**REQ-040: Multi-monitor coordinate fixes** (Route B) → c330825
- ScenePlayer: Added `screenForTrack(_:)` — places tracks on screen matching first waypoint
- CursorTracker: Y-flip now uses `NSMouseInRect` to find actual cursor screen + `screen.frame.maxY`
- CreatureViewModel: Same fix in fallback cursor path

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 128 tests passing
- Queue: 3 LARGE items remaining (REQ-033 Swift 6 actors, REQ-037 macOS 14 bump, REQ-041 test coverage)

---

## Session: 2026-02-13 (macOS 14 migration)

#### macOS 14 Platform Bump (REQ-037) → dbdd5de

Processed REQ-037 from do-work queue via Route B (explore → implement):

- **Package.swift**: Bumped platform `.macOS(.v13)` → `.macOS(.v14)`
- **SettingsView.swift**: Migrated 6× `onChange(of:)` to 2-parameter form; `@StateObject` → `@State`
- **SettingsViewModel**: `ObservableObject` + 17× `@Published` → `@Observable` macro
- **CreatureViewModel**: `ObservableObject` + 6× `@Published` → `@MainActor @Observable`
- **ChoreographerViewModel**: `ObservableObject` + 14× `@Published` → `@Observable` (NOT @MainActor, intentional)
- **SpriteView**: `@ObservedObject` → plain property
- **ChoreographerOverlayView**: `@ObservedObject` → plain property
- **ChoreographerPanelView**: `@ObservedObject` → `@Bindable` (needs `$viewModel` bindings)
- **ChoreographerController**: Replaced Combine `$property.sink` with `withObservationTracking`

#### New Request Captured (REQ-043)
- Delete creatures (tracks) in choreographer with confirmation modal — queued as REQ-043 (UR-018)

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 128 tests passing
- Queue: REQ-033 (Swift 6 actors), REQ-041 (test coverage), REQ-043 (delete creatures in choreographer)

---

## Session: 2026-02-14

#### Track Deletion in Choreographer (REQ-043) → a094eae

Processed REQ-043 from do-work queue via Route B (explore → implement):

- **ChoreographerViewModel.swift**: Added `trackIndexToDelete`/`showTrackDeleteConfirmation` state, `requestDeleteTrack(at:)`/`confirmDeleteTrack()`/`cancelDeleteTrack()` methods, `trackToDeleteCreatureName` computed property
- **ChoreographerPanelView.swift**: Added `.alert()` for track deletion confirmation (follows existing scene deletion pattern), visible trash icon button per track row header, updated context menu to route through confirmation

### Current State
- Build: Compiles cleanly
- Tests: 128 tests passing
- Queue: REQ-033 (Swift 6 actors), REQ-041 (test coverage) — both LARGE items requiring user confirmation

---

## Session: 2026-02-14 (Synchronization.Mutex migration)

#### Swift 6 Concurrency Migration (REQ-033) → 66ed2b2

Processed REQ-033 from do-work queue via Route C (plan → explore → implement):

- **Package.swift**: Bumped swift-tools-version 5.9 → 6.0, macOS .v14 → .v15 (required for `Synchronization.Mutex`), added `swiftLanguageModes: [.v5]`
- **10 source files migrated** (12 types), replacing NSLock + `@unchecked Sendable` with `Synchronization.Mutex`:
  - TimeSource.swift (MockTimeSource) — `Mutex<TimeInterval>`
  - RandomSource.swift (SeededRandomSource, FixedRandomSource) — inner State structs
  - WindowTracker.swift (AccessibilityWindowTracker, MockWindowTracker) — `Mutex<Void>` / State
  - CursorTracker.swift (GlobalCursorTracker, MockCursorTracker) — State with `#if canImport(AppKit)`
  - SceneStorage.swift (SceneStorage) — `Mutex<Void>` for I/O serialization
  - Behavior.swift (BehaviorRegistry) — init builds dict before Mutex init
  - SpriteLoader.swift (SpriteLoader) — private helper refactored to `static loadCreatureImpl(at:state:)`
  - ImageCache.swift (ImageCache) — double-checked locking preserved with two `withLock` calls
  - IPCService.swift (IPCService) — `@Sendable` handler annotations
  - BehaviorScheduler.swift (BehaviorScheduler) — 4 private helpers → static Impl with `inout State`
- **0 NSLock usages remain**, 0 class-level `@unchecked Sendable` remain
- No public API changes, no test file changes

### Current State
- Build: Compiles cleanly
- Tests: 128 tests passing
- Queue: REQ-041 (test coverage) — on backburner per user request

---

## Session: 2026-02-14 (test coverage expansion)

#### Test Coverage Expansion + Cleanup (REQ-041) → 5378431

Processed REQ-041 from do-work queue via Route C (plan → explore → implement):

**Phase 1 — M21 temp dir cleanup:**
- Refactored `SceneTests.swift` and `SpriteLoaderTests.swift` to use `setUp()/tearDown()` pattern
- Temp dirs now always cleaned up even if test throws early

**Phase 2 — Settings persistence tests (+8):**
- Added internal `load(from:)` and `save(to:)` overloads to `Settings.swift` for test isolation
- Tests: save/load round-trip, missing file default, corrupted file default, empty file, directory creation, overwrite, pretty JSON, all fields

**Phase 3 — IPCService tests (+17):**
- Added internal `init(directory:)` designated init to `IPCService.swift`
- Tests: init, directory permissions, IPCMessage/IPCResponse/IPCCommand Codable, GUI running marker, send timeout (sync + async), listener start/stop, two-service communication

**Phase 4 — CLI logic tests (+13):**
- Created `CLILogicTests.swift` testing PocketGrisCore logic used by CLI
- Tests: version string, BehaviorRegistry defaults/lookup/animations, BehaviorType rawValues/allCases, BehaviorMetadata dictionaryRepresentation (none, peek, traverse, climber with/without windowID), scheduler simulation

**Phase 5 — Generic Cache extraction + tests (+14):**
- Created `Sources/PocketGrisCore/Services/Cache.swift` — generic `Cache<Key, Value>` with Mutex, configurable maxSize, half-eviction policy
- Refactored `ImageCache.swift` to wrap `Cache<String, SendableImage>`
- Tests: get/set, overwrite, remove, clear, count, eviction at max, eviction preserves recent, getOrInsert, concurrent access

**UR-016 fully archived** — all 9 deferred audit REQs (033-041) complete.

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 180 tests passing (128 → 180, +52 new)
- Queue: Empty — all work requests processed

---

## Session: 2026-02-14 (codebase review & remediation)

#### Codebase Review & Remediation (Audit #2)

Three-pronged audit covering dead code, security/safety, and logic/quality across all three targets.

**H1: Animation preconditions** → Animation.swift
- Added `precondition(frameCount > 0)` and `precondition(fps > 0)` to `Animation.init`
- Prevents divide-by-zero in `duration` and modulo-by-zero in `advance()`

**H2: Safe unwrap in all 6 behaviors** → PeekBehavior, TraverseBehavior, StationaryBehavior, ClimberBehavior, FollowBehavior, ScriptedBehavior
- Replaced `state.animation!.currentFrame` with safe `if let currentFrame = state.animation?.currentFrame` pattern

**M3: TraverseBehavior cursor boost fix** → TraverseBehavior.swift
- Changed boost from full-path recalculation (`boostedSpeed * elapsed`) to per-frame additive delta (`speed * boostFactor * deltaTime`)
- Eliminates position teleport when cursor enters proximity zone

**M4: ScriptedBehavior bounds guard** → ScriptedBehavior.swift
- Added `guard segmentIndex >= 0, segmentIndex + 1 < track.waypoints.count` to `interpolatePosition`
- Falls back to last waypoint on out-of-bounds instead of crashing

**M1+M2: CVDisplayLink lifetime documentation** → CreatureWindow.swift, ChoreographerViewModel.swift
- Added safety comments explaining `CVDisplayLinkStop` blocking guarantees

**M5: SceneStorage force-unwrap** → SceneStorage.swift
- Replaced `.first!` with `guard let` + `fatalError` for clear diagnostic

**M6: IPC file permissions** → IPCService.swift
- Set explicit 0o600 permissions on command.json and response.json after writing
- Directory already had 0o700 permissions

**M7: CursorTracker monitor cleanup** → Verified correct
- `stopMonitoring()` already nils monitors atomically within `withLock` and checks nil before `removeMonitor`

**L1: Removed PositionCalculator** → Deleted PositionCalculator.swift + PositionCalculatorTests.swift (204 + test lines)
- Confirmed unused in production via grep

**L2: Removed unused method** → SpriteLoader.swift
- Removed `validateBehaviorSupport()` (only referenced in its own file)

**New edge-case tests (+4):**
- AnimationTests: boundary value tests for preconditions
- BehaviorTests: traverse cursor boost no-teleport, follow screen-edge clamping, climber window-gone full lifecycle
- ScriptedBehaviorTests: out-of-bounds segment index safety

### Current State
- Build: ✅ Compiles cleanly
- Tests: ✅ 176 tests passing (180 → 176: -8 PositionCalculator, +4 new edge-case)
- No critical security issues found
- All HIGH and MEDIUM findings addressed

---

## Continuation Prompt

See `AGENTS/.convos/continue/` for the latest continuation prompt.
