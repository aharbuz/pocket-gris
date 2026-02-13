import Foundation
import SwiftUI
import Observation
import PocketGrisCore

// Disambiguate from SwiftUI types
typealias PGScene = PocketGrisCore.Scene
typealias PGSceneStorage = PocketGrisCore.SceneStorage

/// State for the choreographer editor
@Observable
final class ChoreographerViewModel {
    var currentScene: PGScene
    var selectedTrackIndex: Int? {
        didSet {
            // Reset expanded segments when track changes
            if selectedTrackIndex != oldValue {
                expandedSegmentIndices.removeAll()
            }
        }
    }
    var selectedSegmentIndex: Int?
    var isPlacing: Bool = false {
        didSet {
            if isPlacing { startPreview() } else { stopPreview() }
        }
    }

    /// Tracks which segments are expanded per track (key: track index, value: set of segment indices)
    var expandedSegmentIndices: [Int: Set<Int>] = [:]

    /// Pending segment settings (used when first segment will be created)
    var pendingAnimation: String = "" {
        didSet {
            // Refresh preview when pending animation changes and no segments exist yet
            if pendingAnimation != oldValue && isPlacing {
                if let idx = selectedTrackIndex, idx < currentScene.tracks.count,
                   currentScene.tracks[idx].segments.isEmpty {
                    startPreview()
                }
            }
        }
    }
    var pendingSnapMode: SnapMode = .none
    var pendingDuration: TimeInterval = 2.0

    // Scene delete confirmation state
    var sceneToDelete: PGScene?
    var showDeleteConfirmation: Bool = false

    // Track delete confirmation state
    var trackIndexToDelete: Int?
    var showTrackDeleteConfirmation: Bool = false

    // Unsaved changes confirmation state
    var showUnsavedChangesAlert: Bool = false

    // Preview state
    var previewPosition: CGPoint = .zero
    var previewFramePath: String?

    private let spriteLoader: SpriteLoader
    private let sceneStorage: PGSceneStorage?
    private var previewAnimationState: PocketGrisCore.AnimationState?
    private var previewTimer: Timer?

    // Smooth cursor tracking
    private var targetCursorPosition: CGPoint = .zero
    private var displayLink: CVDisplayLink?
    private let cursorSmoothingSpeed: CGFloat = 60.0  // Higher = faster catch-up (60 gives near-instant tracking)
    private var undoStack: [PGScene] = []
    private let maxUndoLevels = 20

    /// Snapshot of the scene at last save/load point, used for dirty state detection
    private var savedSnapshot: PGScene?

    var onSave: ((PGScene) -> Void)?
    var onClose: (() -> Void)?
    var onSceneDeleted: (() -> Void)?

    var canUndo: Bool { !undoStack.isEmpty }

    /// Whether the scene has been modified since last save/load
    var hasUnsavedChanges: Bool {
        guard let snapshot = savedSnapshot else {
            // No snapshot means new scene — dirty if it has any content
            return hasContent
        }
        return currentScene != snapshot
    }

    /// Derive activeCreatureId from selected track
    var activeCreatureId: String? {
        guard let idx = selectedTrackIndex, idx < currentScene.tracks.count else { return nil }
        return currentScene.tracks[idx].creatureId
    }

    /// Derive activeAnimation from selected track's last segment, pending animation, or first available
    var activeAnimation: String? {
        guard let creatureId = activeCreatureId else { return nil }
        guard let idx = selectedTrackIndex, idx < currentScene.tracks.count else { return nil }
        let track = currentScene.tracks[idx]
        if let lastSegment = track.segments.last {
            return lastSegment.animationName
        }
        // Use pending animation if set
        if !pendingAnimation.isEmpty {
            return pendingAnimation
        }
        // Fall back to first available animation
        return spriteLoader.creature(id: creatureId)?.animations.keys.sorted().first
    }

    /// Derive activeSnapMode from selected track's last segment
    var activeSnapMode: SnapMode {
        guard let idx = selectedTrackIndex, idx < currentScene.tracks.count else { return .none }
        return currentScene.tracks[idx].segments.last?.snapMode ?? .none
    }

    /// Whether the scene can be saved (has at least one waypoint in any track)
    var canSave: Bool {
        currentScene.tracks.contains { !$0.waypoints.isEmpty }
    }

    /// Whether the scene has any content (tracks with waypoints)
    var hasContent: Bool {
        canSave
    }

    /// Whether a new creature track can be added (current track must have at least one segment)
    var canAddCreatureTrack: Bool {
        // Can always add first track
        if currentScene.tracks.isEmpty { return true }
        // Otherwise, selected track must have at least one segment
        guard let idx = selectedTrackIndex, idx < currentScene.tracks.count else { return true }
        return !currentScene.tracks[idx].segments.isEmpty
    }

    var creatures: [Creature] {
        spriteLoader.allCreatures()
    }

    var selectedTrack: SceneTrack? {
        guard let idx = selectedTrackIndex, idx < currentScene.tracks.count else { return nil }
        return currentScene.tracks[idx]
    }

    init(scene: PGScene? = nil, spriteLoader: SpriteLoader, sceneStorage: PGSceneStorage? = nil) {
        self.spriteLoader = spriteLoader
        self.sceneStorage = sceneStorage
        self.currentScene = scene ?? PGScene(name: Self.generateUniqueSceneName(storage: sceneStorage, existingScene: nil))

        // Snapshot the loaded scene for dirty state tracking
        self.savedSnapshot = scene

        // Determine default creature: prefer "gris", fall back to first available
        let allCreatures = spriteLoader.allCreatures()
        let defaultCreature = allCreatures.first(where: { $0.id == "gris" }) ?? allCreatures.first

        if let creature = defaultCreature {
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
                // Preview is derived from selected track, restart if placing
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

    /// Changes the creature for the selected track
    func changeCreature(to newCreatureId: String) {
        guard newCreatureId != activeCreatureId else { return }
        guard let idx = selectedTrackIndex, idx < currentScene.tracks.count else { return }

        let newCreature = spriteLoader.creature(id: newCreatureId)
        let firstAnim = newCreature?.animations.keys.sorted().first

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
        // Preview will use the new track's creature/animation automatically
        if isPlacing { startPreview() }
    }

    // MARK: - Waypoint Management

    func addWaypoint(at position: Position) {
        guard let trackIdx = selectedTrackIndex, trackIdx < currentScene.tracks.count else { return }
        pushUndo()

        currentScene.tracks[trackIdx].waypoints.append(position)

        // Auto-create segment when we have at least 2 waypoints
        let waypointCount = currentScene.tracks[trackIdx].waypoints.count
        if waypointCount >= 2 {
            // For first segment, use pending values; otherwise use active values from last segment
            let isFirstSegment = currentScene.tracks[trackIdx].segments.isEmpty
            let animName: String
            let snapMode: SnapMode
            let duration: TimeInterval

            if isFirstSegment {
                // Use pending values (from pending segment UI)
                animName = pendingAnimation.isEmpty ? (activeAnimation ?? "idle") : pendingAnimation
                snapMode = pendingSnapMode
                duration = pendingDuration
            } else {
                // Use values from last segment (continuity)
                animName = activeAnimation ?? "idle"
                snapMode = activeSnapMode
                duration = 2.0
            }

            let segment = SceneSegment(
                animationName: animName,
                duration: duration,
                snapMode: snapMode
            )
            currentScene.tracks[trackIdx].segments.append(segment)

            // Auto-expand the first segment when created
            if isFirstSegment {
                var expanded = expandedSegmentIndices[trackIdx] ?? []
                expanded.insert(0)
                expandedSegmentIndices[trackIdx] = expanded
            }
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
    /// Only collapses existing segments when there are already 2+ segments
    func extendTrack() {
        guard let trackIdx = selectedTrackIndex, trackIdx < currentScene.tracks.count else { return }
        let track = currentScene.tracks[trackIdx]
        guard let lastWaypoint = track.waypoints.last else { return }

        // Track segment count before adding
        let segmentCountBefore = track.segments.count

        // Create new waypoint offset from the last one
        let offset: Double = 100
        let newPosition = Position(x: lastWaypoint.x + offset, y: lastWaypoint.y)

        addWaypoint(at: newPosition)

        // Handle expansion/collapse based on segment count
        let newSegmentIndex = currentScene.tracks[trackIdx].segments.count - 1
        if newSegmentIndex >= 0 {
            if segmentCountBefore >= 2 {
                // Collapse all and expand only the new one
                expandedSegmentIndices[trackIdx] = [newSegmentIndex]
            } else {
                // Just expand the new one, keep existing expanded
                var expanded = expandedSegmentIndices[trackIdx] ?? []
                expanded.insert(newSegmentIndex)
                expandedSegmentIndices[trackIdx] = expanded
            }
        }
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

        let isLastSegment = segmentIndex == currentScene.tracks[trackIndex].segments.count - 1

        if let anim = animationName {
            currentScene.tracks[trackIndex].segments[segmentIndex].animationName = anim
        }
        if let dur = duration {
            currentScene.tracks[trackIndex].segments[segmentIndex].duration = dur
        }
        if let snap = snapMode {
            currentScene.tracks[trackIndex].segments[segmentIndex].snapMode = snap
        }

        // Refresh preview if animation changed on the last segment (affects activeAnimation)
        if animationName != nil && isLastSegment && isPlacing {
            startPreview()
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

    // MARK: - Expanded Segment Management

    func isSegmentExpanded(trackIndex: Int, segmentIndex: Int) -> Bool {
        expandedSegmentIndices[trackIndex]?.contains(segmentIndex) ?? false
    }

    func toggleSegmentExpanded(trackIndex: Int, segmentIndex: Int) {
        var expanded = expandedSegmentIndices[trackIndex] ?? []
        if expanded.contains(segmentIndex) {
            expanded.remove(segmentIndex)
        } else {
            expanded.insert(segmentIndex)
        }
        expandedSegmentIndices[trackIndex] = expanded
    }

    func setSegmentExpanded(trackIndex: Int, segmentIndex: Int, expanded: Bool) {
        var set = expandedSegmentIndices[trackIndex] ?? []
        if expanded {
            set.insert(segmentIndex)
        } else {
            set.remove(segmentIndex)
        }
        expandedSegmentIndices[trackIndex] = set
    }

    // MARK: - Scene Actions

    /// Check for unsaved changes before closing; shows alert if dirty, otherwise closes directly.
    func requestClose() {
        if hasUnsavedChanges {
            showUnsavedChangesAlert = true
        } else {
            onClose?()
        }
    }

    /// Save and then close (used by the unsaved changes alert "Save" action).
    func saveAndClose() {
        save()
        onClose?()
    }

    /// Discard changes and close (used by the unsaved changes alert "Discard" action).
    func discardAndClose() {
        onClose?()
    }

    func save() {
        pruneEmptyTracks()
        isPlacing = false
        onSave?(currentScene)
        savedSnapshot = currentScene
    }

    func newScene() {
        let name = Self.generateUniqueSceneName(storage: sceneStorage, existingScene: currentScene)
        currentScene = PGScene(name: name)
        savedSnapshot = nil
        selectedTrackIndex = nil
        selectedSegmentIndex = nil
        expandedSegmentIndices.removeAll()
        pendingAnimation = ""
        pendingSnapMode = .none
        pendingDuration = 2.0

        // Create default track like init() does
        let allCreatures = spriteLoader.allCreatures()
        let defaultCreature = allCreatures.first(where: { $0.id == "gris" }) ?? allCreatures.first

        if let creature = defaultCreature {
            let track = SceneTrack(
                creatureId: creature.id,
                waypoints: [],
                segments: [],
                startDelay: 0
            )
            currentScene.tracks.append(track)
            selectedTrackIndex = 0
            isPlacing = true
        } else {
            isPlacing = false
        }
    }

    // MARK: - Scene Name Generation

    /// Generates a unique "Untitled Scene" name by checking existing scenes
    /// Returns "Untitled Scene" for the first one, then "Untitled Scene 2", "Untitled Scene 3", etc.
    private static func generateUniqueSceneName(storage: PGSceneStorage?, existingScene: PGScene?) -> String {
        let basePrefix = "Untitled Scene"

        // Collect all existing scene names
        var existingNames = Set<String>()
        if let storage = storage {
            for scene in storage.loadAll() {
                existingNames.insert(scene.name)
            }
        }
        // Also include the current scene's name if it exists
        if let existing = existingScene {
            existingNames.insert(existing.name)
        }

        // If no untitled scenes exist, use the base name
        if !existingNames.contains(basePrefix) {
            return basePrefix
        }

        // Find the next available number
        // Check for "Untitled Scene N" where N >= 2
        var usedNumbers = Set<Int>()
        usedNumbers.insert(1) // "Untitled Scene" counts as 1

        for name in existingNames {
            if name == basePrefix {
                continue
            }
            // Check for "Untitled Scene N" pattern
            if name.hasPrefix(basePrefix + " ") {
                let suffix = name.dropFirst(basePrefix.count + 1)
                if let number = Int(suffix) {
                    usedNumbers.insert(number)
                }
            }
        }

        // Find the smallest unused number >= 2
        var nextNumber = 2
        while usedNumbers.contains(nextNumber) {
            nextNumber += 1
        }

        return "\(basePrefix) \(nextNumber)"
    }

    func loadScene(_ scene: PGScene) {
        currentScene = scene
        savedSnapshot = scene
        selectedTrackIndex = scene.tracks.isEmpty ? nil : 0
        selectedSegmentIndex = nil
        isPlacing = false
    }

    /// Request deletion confirmation for a scene
    func requestDeleteScene(_ scene: PGScene) {
        sceneToDelete = scene
        showDeleteConfirmation = true
    }

    /// Confirm and execute scene deletion
    func confirmDeleteScene() {
        guard let scene = sceneToDelete else { return }

        do {
            try sceneStorage?.delete(id: scene.id)

            // If we deleted the currently loaded scene, create a new one
            if currentScene.id == scene.id {
                newScene()
            }

            onSceneDeleted?()
        } catch {
            // Log error but don't crash - the scene may have already been deleted
            print("Failed to delete scene '\(scene.name)': \(error)")
        }

        sceneToDelete = nil
        showDeleteConfirmation = false
    }

    /// Cancel scene deletion
    func cancelDeleteScene() {
        sceneToDelete = nil
        showDeleteConfirmation = false
    }

    // MARK: - Track Deletion Confirmation

    /// Request deletion confirmation for a track
    func requestDeleteTrack(at index: Int) {
        trackIndexToDelete = index
        showTrackDeleteConfirmation = true
    }

    /// Confirm and execute track deletion
    func confirmDeleteTrack() {
        guard let index = trackIndexToDelete else { return }
        removeTrack(at: index)
        trackIndexToDelete = nil
        showTrackDeleteConfirmation = false
    }

    /// Cancel track deletion
    func cancelDeleteTrack() {
        trackIndexToDelete = nil
        showTrackDeleteConfirmation = false
    }

    /// The creature name for the track pending deletion, used in the confirmation message
    var trackToDeleteCreatureName: String? {
        guard let index = trackIndexToDelete, index < currentScene.tracks.count else { return nil }
        let creatureId = currentScene.tracks[index].creatureId
        return creatures.first(where: { $0.id == creatureId })?.name ?? creatureId
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
            DispatchQueue.main.async { [weak viewModel] in
                viewModel?.updateSmoothPosition()
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
        // Stop existing timer/display link first (but don't clear previewFramePath yet)
        previewTimer?.invalidate()
        previewTimer = nil
        stopDisplayLink()

        guard let creatureId = activeCreatureId,
              let animName = activeAnimation,
              let creature = spriteLoader.creature(id: creatureId),
              let animation = creature.animation(named: animName) else {
            // Only clear preview state if we can't set up a new preview
            previewAnimationState = nil
            previewFramePath = nil
            return
        }

        // Preload frames in background
        if let paths = spriteLoader.allFramePaths(creature: creatureId, animation: animName) {
            ImageCache.shared.preload(paths: paths)
        }

        let animState = PocketGrisCore.AnimationState(animation: animation)
        previewAnimationState = animState

        // Set initial frame immediately (without going through nil first)
        // This ensures the preview updates instantly when switching creatures
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
