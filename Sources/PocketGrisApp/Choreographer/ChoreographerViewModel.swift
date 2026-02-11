import Foundation
import SwiftUI
import PocketGrisCore

// Disambiguate from SwiftUI types
typealias PGScene = PocketGrisCore.Scene
typealias PGSceneStorage = PocketGrisCore.SceneStorage

/// State for the choreographer editor
final class ChoreographerViewModel: ObservableObject {
    @Published var currentScene: PGScene
    @Published var selectedTrackIndex: Int?
    @Published var selectedSegmentIndex: Int?
    @Published var activeCreatureId: String? {
        didSet { if isPlacing { startPreview() } }
    }
    @Published var activeAnimation: String? {
        didSet { if isPlacing { startPreview() } }
    }
    @Published var activeSnapMode: SnapMode = .none
    @Published var isPlacing: Bool = false {
        didSet {
            if isPlacing { startPreview() } else { stopPreview() }
        }
    }

    // Preview state
    @Published var previewPosition: CGPoint = .zero
    @Published var previewFramePath: String?

    private let spriteLoader: SpriteLoader
    private var previewAnimationState: PocketGrisCore.AnimationState?
    private var previewTimer: Timer?
    private var undoStack: [PGScene] = []
    private let maxUndoLevels = 20
    var onSave: ((PGScene) -> Void)?
    var onClose: (() -> Void)?

    var canUndo: Bool { !undoStack.isEmpty }

    var creatures: [Creature] {
        spriteLoader.allCreatures()
    }

    var selectedTrack: SceneTrack? {
        guard let idx = selectedTrackIndex, idx < currentScene.tracks.count else { return nil }
        return currentScene.tracks[idx]
    }

    init(scene: PGScene? = nil, spriteLoader: SpriteLoader) {
        self.currentScene = scene ?? PGScene()
        self.spriteLoader = spriteLoader

        if let first = spriteLoader.allCreatures().first {
            self.activeCreatureId = first.id
            self.activeAnimation = first.animations.keys.sorted().first
        }
    }

    // MARK: - Undo

    private func pushUndo() {
        undoStack.append(currentScene)
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        currentScene = previous
    }

    // MARK: - Track Management

    func addTrack(creatureId: String) {
        pushUndo()
        let track = SceneTrack(creatureId: creatureId)
        currentScene.tracks.append(track)
        selectedTrackIndex = currentScene.tracks.count - 1
        isPlacing = true
    }

    func removeTrack(at index: Int) {
        guard index < currentScene.tracks.count else { return }
        pushUndo()
        currentScene.tracks.remove(at: index)
        if selectedTrackIndex == index {
            selectedTrackIndex = currentScene.tracks.isEmpty ? nil : max(0, index - 1)
        } else if let sel = selectedTrackIndex, sel > index {
            selectedTrackIndex = sel - 1
        }
        selectedSegmentIndex = nil
    }

    func selectTrack(at index: Int) {
        guard index < currentScene.tracks.count else { return }
        selectedTrackIndex = index
        selectedSegmentIndex = nil
        let track = currentScene.tracks[index]
        activeCreatureId = track.creatureId
    }

    // MARK: - Waypoint Management

    func addWaypoint(at position: Position) {
        guard let trackIdx = selectedTrackIndex, trackIdx < currentScene.tracks.count else { return }
        pushUndo()

        currentScene.tracks[trackIdx].waypoints.append(position)

        // Auto-create segment when we have at least 2 waypoints
        let waypointCount = currentScene.tracks[trackIdx].waypoints.count
        if waypointCount >= 2 {
            let animName = activeAnimation ?? "idle"
            let segment = SceneSegment(
                animationName: animName,
                duration: 2.0,
                snapMode: activeSnapMode
            )
            currentScene.tracks[trackIdx].segments.append(segment)
        }
    }

    func removeWaypoint(trackIndex: Int, waypointIndex: Int) {
        guard trackIndex < currentScene.tracks.count else { return }
        let track = currentScene.tracks[trackIndex]
        guard waypointIndex < track.waypoints.count else { return }
        pushUndo()

        currentScene.tracks[trackIndex].waypoints.remove(at: waypointIndex)

        // Remove associated segment(s)
        if waypointIndex > 0 && waypointIndex - 1 < currentScene.tracks[trackIndex].segments.count {
            currentScene.tracks[trackIndex].segments.remove(at: waypointIndex - 1)
        } else if waypointIndex == 0 && !currentScene.tracks[trackIndex].segments.isEmpty {
            currentScene.tracks[trackIndex].segments.remove(at: 0)
        }
    }

    // MARK: - Segment Editing

    func updateSegment(trackIndex: Int, segmentIndex: Int, animationName: String? = nil, duration: TimeInterval? = nil, snapMode: SnapMode? = nil) {
        guard trackIndex < currentScene.tracks.count,
              segmentIndex < currentScene.tracks[trackIndex].segments.count else { return }

        if let anim = animationName {
            currentScene.tracks[trackIndex].segments[segmentIndex].animationName = anim
        }
        if let dur = duration {
            currentScene.tracks[trackIndex].segments[segmentIndex].duration = dur
        }
        if let snap = snapMode {
            currentScene.tracks[trackIndex].segments[segmentIndex].snapMode = snap
        }
    }

    // MARK: - Scene Actions

    func save() {
        onSave?(currentScene)
    }

    func newScene() {
        currentScene = PGScene()
        selectedTrackIndex = nil
        selectedSegmentIndex = nil
        isPlacing = false
    }

    func loadScene(_ scene: PGScene) {
        currentScene = scene
        selectedTrackIndex = scene.tracks.isEmpty ? nil : 0
        selectedSegmentIndex = nil
        isPlacing = false
    }

    // MARK: - Preview

    func updatePreviewPosition(_ point: CGPoint) {
        previewPosition = point
    }

    func startPreview() {
        stopPreview()
        guard let creatureId = activeCreatureId,
              let animName = activeAnimation,
              let creature = spriteLoader.creature(id: creatureId),
              let animation = creature.animation(named: animName) else {
            return
        }

        // Preload frames in background
        if let paths = spriteLoader.allFramePaths(creature: creatureId, animation: animName) {
            ImageCache.shared.preload(paths: paths)
        }

        let animState = PocketGrisCore.AnimationState(animation: animation)
        previewAnimationState = animState

        // Set initial frame
        previewFramePath = spriteLoader.framePath(
            creature: creatureId, animation: animName, frame: animState.currentFrame
        )

        let interval = 1.0 / animation.fps
        previewTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advancePreview()
        }
    }

    func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        previewAnimationState = nil
        previewFramePath = nil
    }

    private func advancePreview() {
        guard var animState = previewAnimationState,
              let creatureId = activeCreatureId,
              let animName = activeAnimation else { return }

        let interval = 1.0 / animState.animation.fps
        _ = animState.advance(by: interval)

        // Loop non-looping animations for continuous preview
        if animState.isComplete {
            animState.reset()
        }

        previewAnimationState = animState
        previewFramePath = spriteLoader.framePath(
            creature: creatureId, animation: animName, frame: animState.currentFrame
        )
    }

    deinit {
        previewTimer?.invalidate()
    }

    // MARK: - Track Colors

    static let trackColors: [Color] = [
        .red, .blue, .green, .orange, .purple, .cyan, .yellow, .pink
    ]

    func colorForTrack(at index: Int) -> Color {
        Self.trackColors[index % Self.trackColors.count]
    }
}
