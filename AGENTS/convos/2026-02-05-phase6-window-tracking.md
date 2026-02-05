# Phase 6: Window Tracking Implementation

**Date:** 2026-02-05
**Model:** Claude Opus 4.5

## Summary

Implemented Phase 6 of pocket-gris: Window Tracking and ClimberBehavior.

## What Was Built

### WindowTracker Service
- `WindowTracker` protocol for getting window frames
- `AccessibilityWindowTracker` - Real implementation using `CGWindowListCopyWindowInfo`
  - Excludes own app, Dock, Control Center, Notification Center
  - Filters tiny windows and desktop elements
- `MockWindowTracker` - Test implementation for unit tests

### ClimberBehavior
- Creatures climb along window edges (top, left, right, bottom)
- Speed based on personality (shy=40, curious=70, mischievous=100, chaotic=130 px/s)
- Cursor proximity triggers flee
- Falls back gracefully when no windows available
- **Window movement tracking** - creature follows dragged windows
- **Window close handling** - continues with last trajectory

### ScreenRect Extensions
- `randomPositionOnEdge` - Get random position along window edge
- `cornerPosition` - Get position at window corner
- `isNearEdge` - Check if position is near window edge

### Integration
- `AppDelegate` creates `AccessibilityWindowTracker`
- `CreatureWindow` passes tracker to `CreatureViewModel`
- `CreatureViewModel` passes live `windowFrames` to `BehaviorContext`

### Gris Creature
- Added `climb` animation (8 frames, 10fps)
- Updated sprite generator script

## Test Results

- **78 tests passing** (13 new for Phase 6)
- Tests cover:
  - ClimberBehavior start, phase transitions, cancel
  - Window movement tracking
  - Window close handling
  - Cursor flee behavior
  - MockWindowTracker
  - ScreenRect edge helpers

## Files Changed

### New Files
- `Sources/PocketGrisCore/Services/WindowTracker.swift`
- `Sources/PocketGrisCore/Behavior/ClimberBehavior.swift`
- `Resources/Sprites/gris/climb/frame-*.png` (8 frames)

### Modified Files
- `Sources/PocketGrisCore/Behavior/Behavior.swift` - Register ClimberBehavior
- `Sources/PocketGrisApp/AppDelegate.swift` - Create WindowTracker
- `Sources/PocketGrisApp/CreatureWindow.swift` - Pass WindowTracker
- `Sources/PocketGrisApp/CreatureViewModel.swift` - Accept WindowTracker, pass windowFrames
- `Resources/Sprites/gris/creature.json` - Add climb animation
- `Tests/PocketGrisCoreTests/BehaviorTests.swift` - 13 new tests
- `scripts/generate_sprites.py` - Climb animation support

## Commands

```bash
# Test
swift build && swift test

# List behaviors
swift run pocketgris behaviors list

# Trigger climber
swift run pocketgris trigger --behavior climber --gui

# Run app
swift run PocketGrisApp
```

## Next Steps

**Phase 7: Cursor Interaction**
- Global NSEvent monitor for cursor tracking
- CursorReactiveBehavior (flee, follow, hide)

**Phase 8: Polish**
- Settings UI
- Launch at login
- Multi-monitor support

## Commits

1. `00951d8` - Phase 6: Window Tracking and ClimberBehavior
2. `ec13a33` - Add window movement tracking to ClimberBehavior
