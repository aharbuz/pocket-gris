import SwiftUI
import PocketGrisCore

// Disambiguate from SwiftUI.Settings and Scene
typealias AppSettings = PocketGrisCore.Settings
typealias PGSceneLocal = PocketGrisCore.Scene
typealias PGSceneStorageLocal = PocketGrisCore.SceneStorage

/// SwiftUI settings window for configuring Pocket Gris
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(
        creatures: [Creature],
        sceneStorage: PGSceneStorageLocal,
        onTestBehavior: @escaping (Creature?, BehaviorType?) -> Void,
        onPreviewScene: @escaping (PGSceneLocal) -> Void,
        onSettingsChanged: @escaping (AppSettings) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            creatures: creatures,
            sceneStorage: sceneStorage,
            onTestBehavior: onTestBehavior,
            onPreviewScene: onPreviewScene,
            onSettingsChanged: onSettingsChanged
        ))
    }

    var body: some View {
        Form {
            appearanceSection
            creaturesSection
            behaviorsSection
            scenesSection
            generalSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, idealWidth: 450, minHeight: 500, idealHeight: 600)
        .navigationTitle("Pocket Gris Settings")
        .alert("Delete Scene", isPresented: $viewModel.showDeleteConfirmation, presenting: viewModel.sceneToDelete) { scene in
            Button("Delete", role: .destructive) {
                viewModel.confirmDeleteScene()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDeleteScene()
            }
        } message: { scene in
            Text("Are you sure you want to delete \"\(scene.name)\"? This cannot be undone.")
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section("Appearance Timing") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Minimum interval")
                    Spacer()
                    Text(viewModel.formatInterval(viewModel.minInterval))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $viewModel.minInterval, in: 60...3600, step: 60) {
                    Text("Min")
                } onEditingChanged: { _ in
                    viewModel.clampIntervals()
                    viewModel.applySettings()
                }

                HStack {
                    Text("Maximum interval")
                    Spacer()
                    Text(viewModel.formatInterval(viewModel.maxInterval))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $viewModel.maxInterval, in: 60...7200, step: 60) {
                    Text("Max")
                } onEditingChanged: { _ in
                    viewModel.clampIntervals()
                    viewModel.applySettings()
                }
            }
        }
    }

    private var creaturesSection: some View {
        Section("Creatures") {
            if viewModel.creatures.isEmpty {
                Text("No creatures loaded")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.creatures, id: \.id) { creature in
                    Toggle(isOn: viewModel.creatureBinding(for: creature.id)) {
                        VStack(alignment: .leading) {
                            Text(creature.name)
                            Text(creature.personality.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: viewModel.enabledCreatureIds) { _ in
                        viewModel.applySettings()
                    }
                }
            }
        }
    }

    private var behaviorsSection: some View {
        Section {
            ForEach(BehaviorType.allCases, id: \.self) { behaviorType in
                // Skip .scene - scenes are managed separately in the Scenes submenu
                if behaviorType != .scene {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Toggle(isOn: viewModel.behaviorEnabledBinding(for: behaviorType)) {
                                Text(viewModel.behaviorDisplayName(behaviorType))
                            }
                            .onChange(of: viewModel.behaviorWeights[behaviorType.rawValue]) { _ in
                                viewModel.applySettings()
                            }

                            Spacer()

                            Button {
                                viewModel.previewBehavior(behaviorType)
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Preview \(viewModel.behaviorDisplayName(behaviorType))")
                        }

                        if viewModel.isBehaviorEnabled(behaviorType) {
                            HStack {
                                Text("Weight")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Slider(
                                    value: viewModel.behaviorWeightBinding(for: behaviorType),
                                    in: 0.1...3.0,
                                    step: 0.1
                                ) {
                                    Text("Weight")
                                } onEditingChanged: { _ in
                                    viewModel.applySettings()
                                }
                                Text(String(format: "%.1f", viewModel.behaviorWeights[behaviorType.rawValue] ?? 1.0))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 30)
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
            }
        } header: {
            Text("Behaviors")
        } footer: {
            Text("Weight controls how likely each behavior is to be chosen. Higher = more frequent. Click the play button to preview a behavior.")
        }
    }

    private var scenesSection: some View {
        Section {
            // Scenes header row with toggle and expand control
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.scenesExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.scenesExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)

                    Toggle(isOn: $viewModel.scenesEnabled) {
                        Text("Scenes")
                    }
                    .onChange(of: viewModel.scenesEnabled) { _ in
                        viewModel.applySettings()
                    }

                    Spacer()
                }

                if viewModel.scenesEnabled {
                    HStack {
                        Text("Weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: $viewModel.globalSceneWeight,
                            in: 0.1...3.0,
                            step: 0.1
                        ) {
                            Text("Weight")
                        } onEditingChanged: { _ in
                            viewModel.applySettings()
                        }
                        Text(String(format: "%.1f", viewModel.globalSceneWeight))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 30)
                    }
                    .padding(.leading, 20)
                }
            }

            // Expanded scene list
            if viewModel.scenesExpanded {
                if viewModel.scenes.isEmpty {
                    Text("No saved scenes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 32)
                } else {
                    ForEach(viewModel.scenes, id: \.id) { scene in
                        HStack {
                            Text(scene.name)
                                .padding(.leading, 32)

                            Spacer()

                            // Preview button
                            Button {
                                viewModel.previewScene(scene)
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Preview \(scene.name)")
                            .disabled(!scene.isPlayable)

                            // Delete button
                            Button {
                                viewModel.requestDeleteScene(scene)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Delete \(scene.name)")
                        }
                    }
                }
            }
        } header: {
            Text("Scenes")
        } footer: {
            Text("Scenes are choreographed multi-creature animations created with the Choreographer.")
        }
    }

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at login", isOn: $viewModel.launchAtLogin)
                .onChange(of: viewModel.launchAtLogin) { _ in
                    viewModel.applySettings()
                }

            Button("Reset to Defaults") {
                viewModel.resetToDefaults()
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var minInterval: TimeInterval
    @Published var maxInterval: TimeInterval
    @Published var launchAtLogin: Bool
    @Published var enabledCreatureIds: Set<String>
    @Published var behaviorWeights: [String: Double]

    // Scene-related state
    @Published var scenesEnabled: Bool
    @Published var sceneWeights: [String: Double]
    @Published var globalSceneWeight: Double = 1.0
    @Published var scenesExpanded: Bool = false
    @Published var scenes: [PGSceneLocal] = []
    @Published var sceneToDelete: PGSceneLocal?
    @Published var showDeleteConfirmation: Bool = false

    let creatures: [Creature]
    private let sceneStorage: PGSceneStorageLocal
    private let onTestBehavior: (Creature?, BehaviorType?) -> Void
    private let onPreviewScene: (PGSceneLocal) -> Void
    private let onSettingsChanged: (AppSettings) -> Void

    init(
        creatures: [Creature],
        sceneStorage: PGSceneStorageLocal,
        onTestBehavior: @escaping (Creature?, BehaviorType?) -> Void,
        onPreviewScene: @escaping (PGSceneLocal) -> Void,
        onSettingsChanged: @escaping (AppSettings) -> Void
    ) {
        let settings = AppSettings.load()
        self.minInterval = settings.minInterval
        self.maxInterval = settings.maxInterval
        self.launchAtLogin = settings.launchAtLogin
        self.enabledCreatureIds = settings.enabledCreatures
        self.behaviorWeights = settings.behaviorWeights
        self.scenesEnabled = settings.scenesEnabled
        self.sceneWeights = settings.sceneWeights
        self.creatures = creatures
        self.sceneStorage = sceneStorage
        self.onTestBehavior = onTestBehavior
        self.onPreviewScene = onPreviewScene
        self.onSettingsChanged = onSettingsChanged

        // Load scenes from storage
        self.scenes = sceneStorage.loadAll()

        // Compute global scene weight from first scene's weight or default to 1.0
        if let firstSceneId = scenes.first?.id,
           let weight = settings.sceneWeights[firstSceneId] {
            self.globalSceneWeight = weight
        }
    }

    // MARK: - Bindings

    func creatureBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: {
                // Empty set means all enabled
                self.enabledCreatureIds.isEmpty || self.enabledCreatureIds.contains(id)
            },
            set: { enabled in
                // If toggling off and set is empty, populate with all except this one
                if !enabled && self.enabledCreatureIds.isEmpty {
                    self.enabledCreatureIds = Set(self.creatures.map(\.id))
                    self.enabledCreatureIds.remove(id)
                } else if enabled {
                    self.enabledCreatureIds.insert(id)
                    // If all are now enabled, clear the set (empty = all)
                    if self.enabledCreatureIds.count == self.creatures.count {
                        self.enabledCreatureIds.removeAll()
                    }
                } else {
                    self.enabledCreatureIds.remove(id)
                }
            }
        )
    }

    func behaviorEnabledBinding(for type: BehaviorType) -> Binding<Bool> {
        Binding(
            get: { self.isBehaviorEnabled(type) },
            set: { enabled in
                if enabled {
                    self.behaviorWeights[type.rawValue] = 1.0
                } else {
                    self.behaviorWeights[type.rawValue] = 0.0
                }
                self.applySettings()
            }
        )
    }

    func behaviorWeightBinding(for type: BehaviorType) -> Binding<Double> {
        Binding(
            get: { self.behaviorWeights[type.rawValue] ?? 1.0 },
            set: { self.behaviorWeights[type.rawValue] = $0 }
        )
    }

    func isBehaviorEnabled(_ type: BehaviorType) -> Bool {
        let weight = behaviorWeights[type.rawValue] ?? 1.0
        return weight > 0
    }

    // MARK: - Display

    func behaviorDisplayName(_ type: BehaviorType) -> String {
        switch type {
        case .peek: return "Peek"
        case .traverse: return "Traverse"
        case .stationary: return "Stationary"
        case .climber: return "Climber"
        case .cursorReactive: return "Follow Cursor"
        case .scene: return "Scene"
        }
    }

    func formatInterval(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes == 1 {
            return "1 minute"
        }
        return "\(minutes) minutes"
    }

    // MARK: - Actions

    func clampIntervals() {
        if maxInterval < minInterval {
            maxInterval = minInterval
        }
    }

    func applySettings() {
        let settings = buildSettings()
        try? settings.save()
        onSettingsChanged(settings)
        LaunchAtLoginManager.shared.isEnabled = settings.launchAtLogin
    }

    func testBehavior() {
        onTestBehavior(nil, nil)
    }

    func previewBehavior(_ type: BehaviorType) {
        // Pick first enabled creature, or fallback to any available creature
        let creature: Creature?
        if enabledCreatureIds.isEmpty {
            // Empty set means all creatures are enabled, pick the first
            creature = creatures.first
        } else {
            // Pick first enabled creature
            creature = creatures.first { enabledCreatureIds.contains($0.id) } ?? creatures.first
        }
        onTestBehavior(creature, type)
    }

    func resetToDefaults() {
        let defaults = AppSettings.default
        minInterval = defaults.minInterval
        maxInterval = defaults.maxInterval
        launchAtLogin = defaults.launchAtLogin
        enabledCreatureIds = defaults.enabledCreatures
        behaviorWeights = defaults.behaviorWeights
        scenesEnabled = defaults.scenesEnabled
        sceneWeights = defaults.sceneWeights
        globalSceneWeight = 1.0
        applySettings()
    }

    // MARK: - Scene Actions

    func previewScene(_ scene: PGSceneLocal) {
        onPreviewScene(scene)
    }

    func requestDeleteScene(_ scene: PGSceneLocal) {
        sceneToDelete = scene
        showDeleteConfirmation = true
    }

    func confirmDeleteScene() {
        guard let scene = sceneToDelete else { return }

        do {
            try sceneStorage.delete(id: scene.id)
            // Remove from local list
            scenes.removeAll { $0.id == scene.id }
            // Remove from weights
            sceneWeights.removeValue(forKey: scene.id)
            applySettings()
        } catch {
            print("Failed to delete scene '\(scene.name)': \(error)")
        }

        sceneToDelete = nil
        showDeleteConfirmation = false
    }

    func cancelDeleteScene() {
        sceneToDelete = nil
        showDeleteConfirmation = false
    }

    func reloadScenes() {
        scenes = sceneStorage.loadAll()
    }

    private func buildSettings() -> AppSettings {
        // Apply global scene weight to all scenes
        var updatedSceneWeights: [String: Double] = [:]
        if scenesEnabled {
            for scene in scenes {
                updatedSceneWeights[scene.id] = globalSceneWeight
            }
        }

        return AppSettings(
            enabled: true,
            minInterval: minInterval,
            maxInterval: maxInterval,
            launchAtLogin: launchAtLogin,
            enabledCreatures: enabledCreatureIds,
            behaviorWeights: behaviorWeights,
            sceneWeights: updatedSceneWeights,
            scenesEnabled: scenesEnabled
        )
    }
}
