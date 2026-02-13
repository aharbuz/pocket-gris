import AppKit
import PocketGrisCore

/// Plays multi-track scenes by creating one CreatureWindow per track
final class ScenePlayer {

    private var activeWindows: [CreatureWindow] = []
    private var completedCount = 0
    private var totalTracks = 0
    private var onComplete: (() -> Void)?
    private var isPlaying = false

    var isActive: Bool { isPlaying }

    func play(
        scene: Scene,
        spriteLoader: SpriteLoader,
        windowTracker: WindowTracker?,
        cursorTracker: CursorTracker?,
        onComplete: @escaping () -> Void
    ) {
        cancel()

        let validTracks = scene.tracks.filter { $0.isValid }
        guard !validTracks.isEmpty else {
            onComplete()
            return
        }

        self.onComplete = onComplete
        self.totalTracks = validTracks.count
        self.completedCount = 0
        self.isPlaying = true

        for track in validTracks {
            guard let creature = spriteLoader.creature(id: track.creatureId) else {
                trackCompleted()
                continue
            }

            let behavior = ScriptedBehavior(track: track)
            let delay = track.startDelay

            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.launchTrack(creature: creature, behavior: behavior, track: track, spriteLoader: spriteLoader, windowTracker: windowTracker, cursorTracker: cursorTracker)
                }
            } else {
                launchTrack(creature: creature, behavior: behavior, track: track, spriteLoader: spriteLoader, windowTracker: windowTracker, cursorTracker: cursorTracker)
            }
        }
    }

    func cancel() {
        isPlaying = false
        for window in activeWindows {
            window.close()
        }
        activeWindows.removeAll()
        completedCount = 0
        totalTracks = 0
        onComplete = nil
    }

    // MARK: - Private

    private func launchTrack(
        creature: Creature,
        behavior: ScriptedBehavior,
        track: SceneTrack,
        spriteLoader: SpriteLoader,
        windowTracker: WindowTracker?,
        cursorTracker: CursorTracker?
    ) {
        guard isPlaying else { return }

        let targetScreen = screenForTrack(track) ?? NSScreen.main
        let window = CreatureWindow(screen: targetScreen)

        activeWindows.append(window)

        window.show(
            creature: creature,
            behavior: behavior,
            spriteLoader: spriteLoader,
            windowTracker: windowTracker,
            cursorTracker: cursorTracker
        ) { [weak self] in
            self?.trackCompleted()
        }
    }

    /// Find the NSScreen that contains the track's first waypoint.
    /// Waypoints are in top-left screen coordinates (Y=0 at top);
    /// NSScreen uses AppKit global coordinates (Y=0 at bottom of primary screen).
    private func screenForTrack(_ track: SceneTrack) -> NSScreen? {
        guard let firstWaypoint = track.waypoints.first,
              let primaryScreen = NSScreen.screens.first else {
            return nil
        }

        // Convert waypoint from top-left coords to AppKit global coords.
        // In AppKit globals, the top of the primary screen is at primaryScreen.frame.maxY.
        let appKitX = firstWaypoint.x
        let appKitY = primaryScreen.frame.maxY - firstWaypoint.y
        let point = NSPoint(x: appKitX, y: appKitY)

        return NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })
    }

    private func trackCompleted() {
        completedCount += 1
        if completedCount >= totalTracks {
            isPlaying = false
            activeWindows.removeAll()
            onComplete?()
            onComplete = nil
        }
    }
}
