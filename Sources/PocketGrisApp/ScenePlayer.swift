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
                    self?.launchTrack(creature: creature, behavior: behavior, spriteLoader: spriteLoader, windowTracker: windowTracker, cursorTracker: cursorTracker)
                }
            } else {
                launchTrack(creature: creature, behavior: behavior, spriteLoader: spriteLoader, windowTracker: windowTracker, cursorTracker: cursorTracker)
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
        spriteLoader: SpriteLoader,
        windowTracker: WindowTracker?,
        cursorTracker: CursorTracker?
    ) {
        guard isPlaying else { return }

        let screens = NSScreen.screens
        let targetScreen = screens.isEmpty ? nil : screens[Int.random(in: 0..<screens.count)]
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
