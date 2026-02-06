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

                // Creature & Animation Pickers
                creatureSection

                Divider()

                // Snap Mode
                snapModeSection

                Divider()

                // Track List
                trackListSection

                Divider()

                // Segment List (for selected track)
                segmentListSection

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

    private var segmentListSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Segments")
                .font(.headline)

            if let trackIdx = viewModel.selectedTrackIndex,
               trackIdx < viewModel.currentScene.tracks.count {
                let track = viewModel.currentScene.tracks[trackIdx]

                if track.segments.isEmpty {
                    Text("Place at least 2 waypoints to create a segment.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                ForEach(Array(track.segments.enumerated()), id: \.offset) { segIdx, segment in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(segIdx + 1).")
                                .font(.system(size: 11, weight: .bold))
                            Text(segment.animationName)
                                .font(.system(size: 12))
                            Spacer()
                            Text(String(format: "%.1fs", segment.duration))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Slider(
                                value: segmentDurationBinding(trackIndex: trackIdx, segmentIndex: segIdx),
                                in: 0.5...10.0,
                                step: 0.5
                            )
                            .frame(height: 16)

                            if segment.snapMode != .none {
                                Text(snapModeLabel(segment.snapMode))
                                    .font(.system(size: 9))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.accentColor.opacity(0.2))
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewModel.selectedSegmentIndex == segIdx ? Color.accentColor.opacity(0.1) : Color.clear)
                    )
                    .onTapGesture {
                        viewModel.selectedSegmentIndex = segIdx
                    }
                }
            } else {
                Text("Select a track first.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("Preview") {
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
                .disabled(viewModel.currentScene.tracks.isEmpty)

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
            set: { viewModel.activeCreatureId = $0 }
        )
    }

    private var animationBinding: Binding<String?> {
        Binding(
            get: { viewModel.activeAnimation },
            set: { viewModel.activeAnimation = $0 }
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
        case .onTopOfWindow: return "On Top of Window"
        case .underneathWindow: return "Underneath Window"
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
