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
        didSet { if isPlacing && !suppressPreviewRestart { startPreview() } }
    }
    @Published var activeAnimation: String? {
        didSet { if isPlacing && !suppressPreviewRestart { startPreview() } }
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

    // Smooth cursor tracking
    private var targetCursorPosition: CGPoint = .zero
    private var displayLink: CVDisplayLink?
    private let cursorSmoothingSpeed: CGFloat = 15.0  // Higher = faster catch-up
    private var undoStack: [PGScene] = []
    private let maxUndoLevels = 20
    private var suppressPreviewRestart = false
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

        // Determine default creature: prefer "gris", fall back to first available
        let allCreatures = spriteLoader.allCreatures()
        let defaultCreature = allCreatures.first(where: { $0.id == "gris" }) ?? allCreatures.first

        if let creature = defaultCreature {
            // Determine default animation: prefer "walk-left", fall back to first available
            let sortedAnimations = creature.animations.keys.sorted()
            let defaultAnimation = sortedAnimations.contains("walk-left") ? "walk-left" : sortedAnimations.first

            self.activeCreatureId = creature.id
            self.activeAnimation = defaultAnimation
            self.activeSnapMode = .none

            // If no scene was provided, create a default track so user can start placing waypoints immediately
            if scene == nil {
                let track = SceneTrack(
                    creatureId: creature.id,
                    waypoints: [],
                    segments: [],
                    startDelay: 0
                )
                self.currentScene.tracks.append(track)
                self.selectedTrackIndex = 0
                self.isPlacing = true
            }
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

        // Validate selectedTrackIndex against restored scene
        if let idx = selectedTrackIndex {
            if idx >= currentScene.tracks.count {
                selectedTrackIndex = nil
                selectedSegmentIndex = nil
                isPlacing = false
            } else {
                // Re-sync pickers from the restored track
                let track = currentScene.tracks[idx]
                suppressPreviewRestart = true
                activeCreatureId = track.creatureId
                activeAnimation = track.segments.first?.animationName
                    ?? spriteLoader.creature(id: track.creatureId)?.animations.keys.sorted().first
                suppressPreviewRestart = false
                if isPlacing { startPreview() }
            }
        }
        selectedSegmentIndex = nil
    }

    // MARK: - Helpers

    /// Removes the selected track if it has 0 waypoints.
    /// Adjusts selectedTrackIndex accordingly.
    @discardableResult
    func pruneEmptyTracks() -> Bool {
        guard let idx = selectedTrackIndex, idx < currentScene.tracks.count else { return false }
        guard currentScene.tracks[idx].waypoints.isEmpty else { return false }
        currentScene.tracks.remove(at: idx)
        if currentScene.tracks.isEmpty {
            selectedTrackIndex = nil
        } else {
            selectedTrackIndex = max(0, idx - 1)
        }
        selectedSegmentIndex = nil
        return true
    }

    /// Changes the active creature, updating the selected track if one exists.
    func changeCreature(to newCreatureId: String) {
        guard newCreatureId != activeCreatureId else { return }

        let newCreature = spriteLoader.creature(id: newCreatureId)
        let firstAnim = newCreature?.animations.keys.sorted().first

        guard let idx = selectedTrackIndex, idx < currentScene.tracks.count else {
            // No track selected — just update pickers for next addTrack
            suppressPreviewRestart = true
            activeCreatureId = newCreatureId
            activeAnimation = firstAnim
            suppressPreviewRestart = false
            if isPlacing { startPreview() }
            return
        }

        pushUndo()

        // Update the track's creature
        currentScene.tracks[idx].creatureId = newCreatureId

        // Fix segment animations that don't exist on the new creature
        let validAnims = Set(newCreature.map { Array($0.animations.keys) } ?? [])
        for segIdx in currentScene.tracks[idx].segments.indices {
            if !validAnims.contains(currentScene.tracks[idx].segments[segIdx].animationName) {
                currentScene.tracks[idx].segments[segIdx].animationName = firstAnim ?? "idle"
            }
        }

        // Update pickers (suppressed to avoid double preview restart)
        suppressPreviewRestart = true
        activeCreatureId = newCreatureId
        activeAnimation = firstAnim
        suppressPreviewRestart = false
        if isPlacing { startPreview() }
    }

    // MARK: - Track Management

    func addTrack(creatureId: String) {
        pruneEmptyTracks()
        pushUndo()
        let track = SceneTrack(creatureId: creatureId)
        currentScene.tracks.append(track)
        selectedTrackIndex = currentScene.tracks.count - 1
        isPlacing = true
    }

    func removeTrack(at index: Int) {
        guard index < currentScene.tracks.count else { return }
        pushUndo()
        let wasSelected = selectedTrackIndex == index
        currentScene.tracks.remove(at: index)
        if wasSelected {
            isPlacing = false
            selectedTrackIndex = currentScene.tracks.isEmpty ? nil : max(0, index - 1)
        } else if let sel = selectedTrackIndex, sel > index {
            selectedTrackIndex = sel - 1
        }
        selectedSegmentIndex = nil
    }

    func selectTrack(at index: Int) {
        guard index < currentScene.tracks.count else { return }
        var targetIndex = index
        // Prune the old track if it's empty before switching away
        if let oldIdx = selectedTrackIndex, oldIdx != index {
            if pruneEmptyTracks() && oldIdx < index {
                targetIndex -= 1
            }
        }
        guard targetIndex >= 0, targetIndex < currentScene.tracks.count else { return }
        selectedTrackIndex = targetIndex
        selectedSegmentIndex = nil
        let track = currentScene.tracks[targetIndex]
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

    /// Add a new waypoint (and segment) extending from the last waypoint
    /// The new waypoint is offset from the last one for visibility
    func extendTrack() {
        guard let trackIdx = selectedTrackIndex, trackIdx < currentScene.tracks.count else { return }
        let track = currentScene.tracks[trackIdx]
        guard let lastWaypoint = track.waypoints.last else { return }

        // Create new waypoint offset from the last one
        let offset: Double = 100
        let newPosition = Position(x: lastWaypoint.x + offset, y: lastWaypoint.y)

        addWaypoint(at: newPosition)
    }

    /// Check if the selected track can be extended
    var canExtendTrack: Bool {
        guard let trackIdx = selectedTrackIndex, trackIdx < currentScene.tracks.count else { return false }
        // Can extend if track has at least 1 waypoint
        return !currentScene.tracks[trackIdx].waypoints.isEmpty
    }

    /// Move a waypoint to a new position
    func moveWaypoint(trackIndex: Int, waypointIndex: Int, to newPosition: Position) {
        guard trackIndex < currentScene.tracks.count,
              waypointIndex < currentScene.tracks[trackIndex].waypoints.count else { return }
        currentScene.tracks[trackIndex].waypoints[waypointIndex] = newPosition
    }

    /// Push undo state for waypoint drag start
    func beginWaypointDrag() {
        pushUndo()
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

    func deleteSegment(trackIndex: Int, segmentIndex: Int) {
        guard trackIndex < currentScene.tracks.count,
              segmentIndex < currentScene.tracks[trackIndex].segments.count else { return }
        pushUndo()

        // Remove the segment
        currentScene.tracks[trackIndex].segments.remove(at: segmentIndex)

        // Remove the corresponding waypoint (segment N connects waypoints N and N+1)
        // When deleting segment N, remove waypoint N+1 to maintain the invariant
        let waypointIndexToRemove = segmentIndex + 1
        if waypointIndexToRemove < currentScene.tracks[trackIndex].waypoints.count {
            currentScene.tracks[trackIndex].waypoints.remove(at: waypointIndexToRemove)
        }

        // Update selection
        if selectedSegmentIndex == segmentIndex {
            selectedSegmentIndex = nil
        } else if let sel = selectedSegmentIndex, sel > segmentIndex {
            selectedSegmentIndex = sel - 1
        }
    }

    func moveSegmentUp(trackIndex: Int, segmentIndex: Int) {
        guard trackIndex < currentScene.tracks.count,
              segmentIndex > 0,
              segmentIndex < currentScene.tracks[trackIndex].segments.count else { return }
        pushUndo()

        // Swap segment properties only (animation, duration, snapMode)
        // The waypoints stay in place - segments are metadata between fixed waypoints
        currentScene.tracks[trackIndex].segments.swapAt(segmentIndex, segmentIndex - 1)

        // Update selection to follow the moved segment
        if selectedSegmentIndex == segmentIndex {
            selectedSegmentIndex = segmentIndex - 1
        } else if selectedSegmentIndex == segmentIndex - 1 {
            selectedSegmentIndex = segmentIndex
        }
    }

    func moveSegmentDown(trackIndex: Int, segmentIndex: Int) {
        guard trackIndex < currentScene.tracks.count,
              segmentIndex < currentScene.tracks[trackIndex].segments.count - 1 else { return }
        pushUndo()

        // Swap segment properties only (animation, duration, snapMode)
        // The waypoints stay in place - segments are metadata between fixed waypoints
        currentScene.tracks[trackIndex].segments.swapAt(segmentIndex, segmentIndex + 1)

        // Update selection to follow the moved segment
        if selectedSegmentIndex == segmentIndex {
            selectedSegmentIndex = segmentIndex + 1
        } else if selectedSegmentIndex == segmentIndex + 1 {
            selectedSegmentIndex = segmentIndex
        }
    }

    func canMoveSegmentUp(segmentIndex: Int) -> Bool {
        segmentIndex > 0
    }

    func canMoveSegmentDown(trackIndex: Int, segmentIndex: Int) -> Bool {
        guard trackIndex < currentScene.tracks.count else { return false }
        return segmentIndex < currentScene.tracks[trackIndex].segments.count - 1
    }

    // MARK: - Scene Actions

    func save() {
        pruneEmptyTracks()
        isPlacing = false
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
        targetCursorPosition = point
        // If display link isn't running, update immediately for responsiveness
        if displayLink == nil {
            previewPosition = point
        }
    }

    private func updateSmoothPosition() {
        let dx = targetCursorPosition.x - previewPosition.x
        let dy = targetCursorPosition.y - previewPosition.y

        // Only interpolate if there's a noticeable difference
        if abs(dx) > 0.5 || abs(dy) > 0.5 {
            // Assume ~60fps for display link, so deltaTime ≈ 1/60
            let deltaTime: CGFloat = 1.0 / 60.0
            let factor = min(cursorSmoothingSpeed * deltaTime, 1.0)
            previewPosition = CGPoint(
                x: previewPosition.x + dx * factor,
                y: previewPosition.y + dy * factor
            )
        } else {
            previewPosition = targetCursorPosition
        }
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }

        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let displayLink = link else { return }

        let displayLinkOutputCallback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            let viewModel = Unmanaged<ChoreographerViewModel>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async {
                viewModel.updateSmoothPosition()
            }
            return kCVReturnSuccess
        }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, displayLinkOutputCallback, pointer)
        CVDisplayLinkStart(displayLink)
        self.displayLink = displayLink
    }

    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
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

        // Start smooth cursor tracking
        startDisplayLink()

        let interval = 1.0 / animation.fps
        previewTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advancePreview()
        }
    }

    func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        stopDisplayLink()
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
        stopDisplayLink()
    }

    // MARK: - Track Colors

    static let trackColors: [Color] = [
        .red, .blue, .green, .orange, .purple, .cyan, .yellow, .pink
    ]

    func colorForTrack(at index: Int) -> Color {
        Self.trackColors[index % Self.trackColors.count]
    }
}
