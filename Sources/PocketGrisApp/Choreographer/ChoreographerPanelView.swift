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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Scene Name
                sceneNameSection

                Divider()

                // Creatures (tracks with nested segments)
                creaturesSection

                Divider()

                // Controls
                controlsSection
            }
            .padding()
        }
        .frame(minWidth: 300, maxWidth: 400)
        .alert(
            "Delete Scene",
            isPresented: $viewModel.showDeleteConfirmation,
            presenting: viewModel.sceneToDelete
        ) { scene in
            Button("Cancel", role: .cancel) {
                viewModel.cancelDeleteScene()
            }
            Button("Delete", role: .destructive) {
                viewModel.confirmDeleteScene()
            }
        } message: { scene in
            Text("Are you sure you want to delete \"\(scene.name)\"? This action cannot be undone.")
        }
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

    private var creaturesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header with add button
            HStack {
                Text("Creatures")
                    .font(.headline)
                Spacer()
                Button(action: {
                    // Add new track with first available creature
                    let creatureId = viewModel.creatures.first?.id ?? "gris"
                    viewModel.addTrack(creatureId: creatureId)
                }) {
                    Image(systemName: "plus")
                }
                .disabled(!viewModel.canAddCreatureTrack)
                .help("Add creature track")
            }

            if viewModel.currentScene.tracks.isEmpty {
                Text("No creatures. Add one to start.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // Track list with nested segments
            ForEach(Array(viewModel.currentScene.tracks.enumerated()), id: \.offset) { index, track in
                trackRow(index: index, track: track)
            }
        }
    }

    @ViewBuilder
    private func trackRow(index: Int, track: SceneTrack) -> some View {
        let isSelected = viewModel.selectedTrackIndex == index

        VStack(alignment: .leading, spacing: 4) {
            // Track header: color dot + creature picker
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.colorForTrack(at: index))
                    .frame(width: 10, height: 10)

                // Creature picker (pill style)
                Picker("", selection: trackCreatureBinding(trackIndex: index)) {
                    ForEach(viewModel.creatures, id: \.id) { creature in
                        Text(creature.name).tag(creature.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 120)

                Spacer()

                if !isSelected {
                    // Summary for unselected tracks
                    Text("(\(track.segments.count) segments)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectTrack(at: index)
                viewModel.isPlacing = true
            }

            // Expanded content for selected track
            if isSelected {
                VStack(alignment: .leading, spacing: 6) {
                    // Delay slider
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
                    .padding(.leading, 16)

                    // Segment list
                    if track.segments.isEmpty {
                        pendingSegmentRow(trackIndex: index)
                    } else {
                        ForEach(Array(track.segments.enumerated()), id: \.offset) { segIdx, segment in
                            segmentRow(trackIndex: index, segmentIndex: segIdx, segment: segment)
                        }
                    }

                    // Add segment button
                    Button(action: {
                        viewModel.extendTrack()
                    }) {
                        Label("Add Segment", systemImage: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.canExtendTrack)
                    .padding(.leading, 16)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .contextMenu {
            Button(role: .destructive) {
                viewModel.removeTrack(at: index)
            } label: {
                Label("Delete Track", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func segmentRow(trackIndex: Int, segmentIndex: Int, segment: SceneSegment) -> some View {
        let isExpanded = viewModel.isSegmentExpanded(trackIndex: trackIndex, segmentIndex: segmentIndex)
        let isSelected = viewModel.selectedSegmentIndex == segmentIndex

        VStack(alignment: .leading, spacing: 4) {
            // Collapsed summary row with reorder buttons
            HStack(spacing: 4) {
                // Disclosure triangle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.toggleSegmentExpanded(trackIndex: trackIndex, segmentIndex: segmentIndex)
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)

                // Animation: show picker when expanded, text when collapsed
                if isExpanded {
                    if let creature = viewModel.creatures.first(where: { $0.id == viewModel.currentScene.tracks[trackIndex].creatureId }) {
                        Picker("", selection: stepAnimationBinding(trackIndex: trackIndex, segmentIndex: segmentIndex)) {
                            ForEach(creature.animations.keys.sorted(), id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 100)
                    }
                } else {
                    Text(segment.animationName)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                }

                // Snap mode indicator
                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(snapModeShortLabel(segment.snapMode))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                // Duration
                Text(String(format: "%.1fs", segment.duration))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                // Reorder buttons in collapsed state
                HStack(spacing: 2) {
                    Button(action: {
                        viewModel.moveSegmentUp(trackIndex: trackIndex, segmentIndex: segmentIndex)
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                            .foregroundColor(viewModel.canMoveSegmentUp(segmentIndex: segmentIndex) ? .secondary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canMoveSegmentUp(segmentIndex: segmentIndex))

                    Button(action: {
                        viewModel.moveSegmentDown(trackIndex: trackIndex, segmentIndex: segmentIndex)
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(viewModel.canMoveSegmentDown(trackIndex: trackIndex, segmentIndex: segmentIndex) ? .secondary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canMoveSegmentDown(trackIndex: trackIndex, segmentIndex: segmentIndex))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectedSegmentIndex = segmentIndex
            }

            // Expanded detail view
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Snap mode picker
                    HStack {
                        Text("Snap Mode:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Picker("", selection: stepSnapModeBinding(trackIndex: trackIndex, segmentIndex: segmentIndex)) {
                            ForEach(SnapMode.allCases, id: \.self) { mode in
                                Text(snapModeLabel(mode)).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

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

                    // Delete button
                    Button(role: .destructive, action: {
                        viewModel.deleteSegment(trackIndex: trackIndex, segmentIndex: segmentIndex)
                    }) {
                        Label("Delete Segment", systemImage: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .padding(.leading, 10)  // Indent under track
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

    @ViewBuilder
    private func pendingSegmentRow(trackIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header (always expanded style)
            HStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 12, height: 12)

                // Animation picker (editable)
                if let creature = viewModel.creatures.first(where: { $0.id == viewModel.currentScene.tracks[trackIndex].creatureId }) {
                    Picker("", selection: pendingAnimationBinding(trackIndex: trackIndex)) {
                        ForEach(creature.animations.keys.sorted(), id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 100)
                }

                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(snapModeShortLabel(viewModel.pendingSnapMode))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(String(format: "%.1fs", viewModel.pendingDuration))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                // Disabled reorder buttons
                HStack(spacing: 2) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.3))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.3))
                }
            }

            // Expanded details
            VStack(alignment: .leading, spacing: 6) {
                // Snap mode picker
                HStack {
                    Text("Snap Mode:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Picker("", selection: $viewModel.pendingSnapMode) {
                        ForEach(SnapMode.allCases, id: \.self) { mode in
                            Text(snapModeLabel(mode)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                // Duration slider
                HStack {
                    Text("Duration:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Slider(value: $viewModel.pendingDuration, in: 0.5...10.0, step: 0.5)
                    Text(String(format: "%.1fs", viewModel.pendingDuration))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }

                Text("Will be created when you place 2 waypoints")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding(.leading, 16)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .padding(.leading, 10)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.opacity(0.15))
        )
    }

    private func pendingAnimationBinding(trackIndex: Int) -> Binding<String> {
        Binding(
            get: {
                // Use viewModel's pending animation if set, otherwise derive from creature
                if !viewModel.pendingAnimation.isEmpty {
                    return viewModel.pendingAnimation
                }
                guard trackIndex < viewModel.currentScene.tracks.count else { return "idle" }
                let creatureId = viewModel.currentScene.tracks[trackIndex].creatureId
                return viewModel.creatures.first(where: { $0.id == creatureId })?.animations.keys.sorted().first ?? "idle"
            },
            set: { newValue in
                viewModel.pendingAnimation = newValue
            }
        )
    }

    private func trackCreatureBinding(trackIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard trackIndex < viewModel.currentScene.tracks.count else {
                    return viewModel.creatures.first?.id ?? "gris"
                }
                return viewModel.currentScene.tracks[trackIndex].creatureId
            },
            set: { newValue in
                // Ensure this track is selected, then change creature
                if viewModel.selectedTrackIndex != trackIndex {
                    viewModel.selectTrack(at: trackIndex)
                }
                viewModel.changeCreature(to: newValue)
            }
        )
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
            // Primary actions: Preview, Undo, New
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

                Button("New") {
                    viewModel.newScene()
                }
                .disabled(!viewModel.hasContent)
            }

            // File actions and close
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
                        Menu(scene.name) {
                            Button("Open") {
                                viewModel.loadScene(scene)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                viewModel.requestDeleteScene(scene)
                            }
                        }
                    }
                }

                Spacer()

                Button("Close") {
                    viewModel.onClose?()
                }
            }
        }
    }

    // MARK: - Bindings

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
