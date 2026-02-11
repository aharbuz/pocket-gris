import SwiftUI
import PocketGrisCore

/// Floating panel UI for the choreographer
struct ChoreographerPanelView: View {
    @ObservedObject var viewModel: ChoreographerViewModel
    let sceneStorage: PGSceneStorage
    let scenePlayer: ScenePlayer
    let spriteLoader: SpriteLoader
    let windowTracker: WindowTracker?
    let cursorTracker: CursorTracker?

    // Track which path steps are expanded (key: segmentIndex)
    @State private var expandedSteps: Set<Int> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Scene Name
                sceneNameSection

                Divider()

                // Creature & Animation Pickers
                creatureSection

                Divider()

                // Snap Mode
                snapModeSection

                Divider()

                // Track List
                trackListSection

                Divider()

                // Path steps (for selected track)
                pathStepsSection

                Divider()

                // Controls
                controlsSection
            }
            .padding()
        }
        .frame(minWidth: 300, maxWidth: 400)
    }

    // MARK: - Sections

    private var sceneNameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Scene Name")
                .font(.headline)
            TextField("Scene name", text: $viewModel.currentScene.name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var creatureSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Creature")
                .font(.headline)

            Picker("Creature", selection: creatureIdBinding) {
                ForEach(viewModel.creatures, id: \.id) { creature in
                    Text(creature.name).tag(creature.id as String?)
                }
            }
            .labelsHidden()

            if let creatureId = viewModel.activeCreatureId,
               let creature = viewModel.creatures.first(where: { $0.id == creatureId }) {
                Text("Animation")
                    .font(.subheadline)
                Picker("Animation", selection: animationBinding) {
                    ForEach(creature.animations.keys.sorted(), id: \.self) { name in
                        Text(name).tag(name as String?)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var snapModeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Snap Mode")
                .font(.headline)
            Picker("Snap", selection: $viewModel.activeSnapMode) {
                ForEach(SnapMode.allCases, id: \.self) { mode in
                    Text(snapModeLabel(mode)).tag(mode)
                }
            }
            .labelsHidden()
        }
    }

    private var trackListSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Tracks")
                    .font(.headline)
                Spacer()
                Button(action: {
                    if let creatureId = viewModel.activeCreatureId {
                        viewModel.addTrack(creatureId: creatureId)
                    }
                }) {
                    Image(systemName: "plus")
                }
                .disabled(viewModel.activeCreatureId == nil)
            }

            if viewModel.currentScene.tracks.isEmpty {
                Text("No tracks. Add one to start.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            ForEach(Array(viewModel.currentScene.tracks.enumerated()), id: \.offset) { index, track in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Circle()
                            .fill(viewModel.colorForTrack(at: index))
                            .frame(width: 10, height: 10)
                        Text(track.creatureId)
                            .font(.system(size: 12))
                        Text("(\(track.waypoints.count) pts)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        if viewModel.selectedTrackIndex == index {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }

                    if viewModel.selectedTrackIndex == index {
                        HStack {
                            Text("Delay:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Slider(
                                value: trackDelayBinding(trackIndex: index),
                                in: 0...10,
                                step: 0.5
                            )
                            .frame(height: 14)
                            Text(String(format: "%.1fs", track.startDelay))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectTrack(at: index)
                    viewModel.isPlacing = true
                }
                .contextMenu {
                    Button("Delete Track") {
                        viewModel.removeTrack(at: index)
                    }
                }
            }
        }
    }

    private var pathStepsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Add step button (no header, steps are nested under track)
            HStack {
                Text("Path")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    viewModel.extendTrack()
                }) {
                    Image(systemName: "plus")
                }
                .disabled(!viewModel.canExtendTrack)
                .help("Add waypoint")
            }

            if let trackIdx = viewModel.selectedTrackIndex,
               trackIdx < viewModel.currentScene.tracks.count {
                let track = viewModel.currentScene.tracks[trackIdx]

                if track.segments.isEmpty {
                    Text("Place at least 2 waypoints to create a path.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(Array(track.segments.enumerated()), id: \.offset) { segIdx, segment in
                        pathStepRow(trackIndex: trackIdx, segmentIndex: segIdx, segment: segment)
                    }
                }
            } else {
                Text("Select a track first.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private func pathStepRow(trackIndex: Int, segmentIndex: Int, segment: SceneSegment) -> some View {
        let isExpanded = expandedSteps.contains(segmentIndex)
        let isSelected = viewModel.selectedSegmentIndex == segmentIndex

        VStack(alignment: .leading, spacing: 4) {
            // Collapsed summary row
            HStack(spacing: 4) {
                // Disclosure triangle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isExpanded {
                            expandedSteps.remove(segmentIndex)
                        } else {
                            expandedSteps.insert(segmentIndex)
                        }
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)

                // Animation name with arrow
                Text(segment.animationName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                Text("→")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                // Snap and duration info
                Text("(\(snapModeShortLabel(segment.snapMode)), \(String(format: "%.1fs", segment.duration)))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectedSegmentIndex = segmentIndex
            }

            // Expanded detail view
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Animation picker
                    if let creatureId = viewModel.activeCreatureId,
                       let creature = viewModel.creatures.first(where: { $0.id == creatureId }) {
                        Picker("Animation", selection: stepAnimationBinding(trackIndex: trackIndex, segmentIndex: segmentIndex)) {
                            ForEach(creature.animations.keys.sorted(), id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }

                    // Snap mode picker
                    Picker("Snap", selection: stepSnapModeBinding(trackIndex: trackIndex, segmentIndex: segmentIndex)) {
                        ForEach(SnapMode.allCases, id: \.self) { mode in
                            Text(snapModeLabel(mode)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    // Duration slider
                    HStack {
                        Text("Duration:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Slider(
                            value: segmentDurationBinding(trackIndex: trackIndex, segmentIndex: segmentIndex),
                            in: 0.5...10.0,
                            step: 0.5
                        )
                        Text(String(format: "%.1fs", segment.duration))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 32, alignment: .trailing)
                    }

                    // Reorder buttons
                    HStack {
                        Button(action: {
                            viewModel.moveSegmentUp(trackIndex: trackIndex, segmentIndex: segmentIndex)
                        }) {
                            Label("Move Up", systemImage: "chevron.up")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .disabled(!viewModel.canMoveSegmentUp(segmentIndex: segmentIndex))

                        Button(action: {
                            viewModel.moveSegmentDown(trackIndex: trackIndex, segmentIndex: segmentIndex)
                        }) {
                            Label("Move Down", systemImage: "chevron.down")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .disabled(!viewModel.canMoveSegmentDown(trackIndex: trackIndex, segmentIndex: segmentIndex))

                        Spacer()
                    }
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contextMenu {
            Button(action: {
                viewModel.moveSegmentUp(trackIndex: trackIndex, segmentIndex: segmentIndex)
            }) {
                Label("Move Up", systemImage: "chevron.up")
            }
            .disabled(!viewModel.canMoveSegmentUp(segmentIndex: segmentIndex))

            Button(action: {
                viewModel.moveSegmentDown(trackIndex: trackIndex, segmentIndex: segmentIndex)
            }) {
                Label("Move Down", systemImage: "chevron.down")
            }
            .disabled(!viewModel.canMoveSegmentDown(trackIndex: trackIndex, segmentIndex: segmentIndex))

            Divider()

            Button(role: .destructive, action: {
                viewModel.deleteSegment(trackIndex: trackIndex, segmentIndex: segmentIndex)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func snapModeShortLabel(_ mode: SnapMode) -> String {
        switch mode {
        case .none: return "none"
        case .screenBottom: return "btm"
        case .screenTop: return "top"
        case .windowTop: return "win-top"
        case .windowBottom: return "win-btm"
        case .windowLeft: return "win-L"
        case .windowRight: return "win-R"
        }
    }

    private func stepAnimationBinding(trackIndex: Int, segmentIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard trackIndex < viewModel.currentScene.tracks.count,
                      segmentIndex < viewModel.currentScene.tracks[trackIndex].segments.count else {
                    return "idle"
                }
                return viewModel.currentScene.tracks[trackIndex].segments[segmentIndex].animationName
            },
            set: { newValue in
                viewModel.updateSegment(trackIndex: trackIndex, segmentIndex: segmentIndex, animationName: newValue)
            }
        )
    }

    private func stepSnapModeBinding(trackIndex: Int, segmentIndex: Int) -> Binding<SnapMode> {
        Binding(
            get: {
                guard trackIndex < viewModel.currentScene.tracks.count,
                      segmentIndex < viewModel.currentScene.tracks[trackIndex].segments.count else {
                    return .none
                }
                return viewModel.currentScene.tracks[trackIndex].segments[segmentIndex].snapMode
            },
            set: { newValue in
                viewModel.updateSegment(trackIndex: trackIndex, segmentIndex: segmentIndex, snapMode: newValue)
            }
        )
    }

    private var controlsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("Preview") {
                    viewModel.isPlacing = false
                    viewModel.pruneEmptyTracks()
                    previewScene()
                }
                .disabled(!viewModel.currentScene.isPlayable)

                Button("Undo") {
                    viewModel.undo()
                }
                .disabled(!viewModel.canUndo)
            }

            HStack(spacing: 8) {
                Button("Save") {
                    viewModel.save()
                }
                .disabled(!viewModel.canSave)

                Menu("Load") {
                    let scenes = sceneStorage.loadAll()
                    if scenes.isEmpty {
                        Text("No saved scenes")
                    }
                    ForEach(scenes, id: \.id) { scene in
                        Button(scene.name) {
                            viewModel.loadScene(scene)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button("New") {
                    viewModel.newScene()
                }
                .disabled(!viewModel.hasContent)

                Button("Close") {
                    viewModel.onClose?()
                }
            }
        }
    }

    // MARK: - Bindings

    private var creatureIdBinding: Binding<String?> {
        Binding(
            get: { viewModel.activeCreatureId },
            set: { newValue in
                if let id = newValue {
                    viewModel.changeCreature(to: id)
                }
            }
        )
    }

    private var animationBinding: Binding<String?> {
        Binding(
            get: {
                // If a segment is selected, show its animation
                if let trackIdx = viewModel.selectedTrackIndex,
                   let segIdx = viewModel.selectedSegmentIndex,
                   trackIdx < viewModel.currentScene.tracks.count,
                   segIdx < viewModel.currentScene.tracks[trackIdx].segments.count {
                    return viewModel.currentScene.tracks[trackIdx].segments[segIdx].animationName
                }
                return viewModel.activeAnimation
            },
            set: { newValue in
                viewModel.activeAnimation = newValue
                // Also update selected segment's animation if one is selected
                if let trackIdx = viewModel.selectedTrackIndex,
                   let segIdx = viewModel.selectedSegmentIndex,
                   let anim = newValue {
                    viewModel.updateSegment(trackIndex: trackIdx, segmentIndex: segIdx, animationName: anim)
                }
            }
        )
    }

    private func trackDelayBinding(trackIndex: Int) -> Binding<Double> {
        Binding(
            get: {
                guard trackIndex < viewModel.currentScene.tracks.count else { return 0 }
                return viewModel.currentScene.tracks[trackIndex].startDelay
            },
            set: { newValue in
                guard trackIndex < viewModel.currentScene.tracks.count else { return }
                viewModel.currentScene.tracks[trackIndex].startDelay = newValue
            }
        )
    }

    private func segmentDurationBinding(trackIndex: Int, segmentIndex: Int) -> Binding<Double> {
        Binding(
            get: {
                guard trackIndex < viewModel.currentScene.tracks.count,
                      segmentIndex < viewModel.currentScene.tracks[trackIndex].segments.count else {
                    return 2.0
                }
                return viewModel.currentScene.tracks[trackIndex].segments[segmentIndex].duration
            },
            set: { newValue in
                viewModel.updateSegment(trackIndex: trackIndex, segmentIndex: segmentIndex, duration: newValue)
            }
        )
    }

    // MARK: - Helpers

    private func snapModeLabel(_ mode: SnapMode) -> String {
        switch mode {
        case .none: return "None"
        case .screenBottom: return "Screen Bottom"
        case .screenTop: return "Screen Top"
        case .windowTop: return "Window Top"
        case .windowBottom: return "Window Bottom"
        case .windowLeft: return "Window Left"
        case .windowRight: return "Window Right"
        }
    }

    private func previewScene() {
        scenePlayer.play(
            scene: viewModel.currentScene,
            spriteLoader: spriteLoader,
            windowTracker: windowTracker,
            cursorTracker: cursorTracker
        ) {
            // Preview complete
        }
    }
}
