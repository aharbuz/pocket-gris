import SwiftUI
import PocketGrisCore

// Disambiguate from SwiftUI.Settings
typealias AppSettings = PocketGrisCore.Settings

/// SwiftUI settings window for configuring Pocket Gris
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(
        creatures: [Creature],
        sceneStorage: PGSceneStorage,
        onTestBehavior: @escaping (Creature?, BehaviorType?) -> Void,
        onPreviewScene: @escaping (PGScene) -> Void,
        onEditScene: @escaping (PGScene) -> Void,
        onSettingsChanged: @escaping (AppSettings) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            creatures: creatures,
            sceneStorage: sceneStorage,
            onTestBehavior: onTestBehavior,
            onPreviewScene: onPreviewScene,
            onEditScene: onEditScene,
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
                    EmptyView()
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
                    EmptyView()
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
            // Behaviors header row with chevron and master toggle
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.behaviorsExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(viewModel.behaviorsExpanded ? 90 : 0))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("Behaviors")
                    .fontWeight(.medium)

                Spacer()

                Toggle("", isOn: $viewModel.behaviorsEnabled)
                    .labelsHidden()
                    .onChange(of: viewModel.behaviorsEnabled) { enabled in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.handleBehaviorsToggle(enabled: enabled)
                        }
                        viewModel.applySettings()
                    }
            }

            // Individual behaviors (shown when expanded AND enabled)
            if viewModel.behaviorsExpanded && viewModel.behaviorsEnabled {
                ForEach(BehaviorType.allCases, id: \.self) { behaviorType in
                    // Skip .scene - scenes are managed separately in the Scenes submenu
                    if behaviorType != .scene {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Button {
                                    viewModel.previewBehavior(behaviorType)
                                } label: {
                                    Image(systemName: "play.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .help("Preview \(viewModel.behaviorDisplayName(behaviorType))")

                                Toggle(isOn: viewModel.behaviorEnabledBinding(for: behaviorType)) {
                                    Text(viewModel.behaviorDisplayName(behaviorType))
                                }
                                .onChange(of: viewModel.behaviorWeights[behaviorType.rawValue]) { _ in
                                    viewModel.applySettings()
                                }
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
                                        EmptyView()
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
                        .padding(.leading, 16)
                    }
                }
            }
        } footer: {
            Text("Weight controls how likely each behavior is to be chosen. Higher = more frequent. Click the play button to preview a behavior.")
        }
    }

    private var scenesSection: some View {
        Section {
            // Scenes header row with chevron and master toggle
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.scenesExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(viewModel.scenesExpanded ? 90 : 0))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Text("Scenes")
                        .fontWeight(.medium)

                    Spacer()

                    Toggle("", isOn: $viewModel.scenesEnabled)
                        .labelsHidden()
                        .onChange(of: viewModel.scenesEnabled) { enabled in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.handleScenesToggle(enabled: enabled)
                            }
                            viewModel.applySettings()
                        }
                }

                // Global weight slider (shown when expanded AND enabled)
                if viewModel.scenesExpanded && viewModel.scenesEnabled {
                    HStack {
                        Text("Weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: $viewModel.globalSceneWeight,
                            in: 0.1...3.0,
                            step: 0.1
                        ) {
                            EmptyView()
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

            // Individual scenes (shown when expanded AND enabled)
            if viewModel.scenesExpanded && viewModel.scenesEnabled {
                if viewModel.scenes.isEmpty {
                    Text("No saved scenes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)
                } else {
                    ForEach(viewModel.scenes, id: \.id) { scene in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Toggle(isOn: viewModel.sceneEnabledBinding(for: scene.id)) {
                                    Text(scene.name)
                                }
                                .onChange(of: viewModel.enabledScenes) { _ in
                                    viewModel.applySettings()
                                }

                                Spacer()

                                // Edit button
                                Button {
                                    viewModel.editScene(scene)
                                } label: {
                                    Image(systemName: "pencil.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .help("Edit \(scene.name)")

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

                            if viewModel.isSceneEnabled(scene.id) {
                                HStack {
                                    Text("Weight")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Slider(
                                        value: viewModel.sceneWeightBinding(for: scene.id),
                                        in: 0.1...3.0,
                                        step: 0.1
                                    ) {
                                        EmptyView()
                                    } onEditingChanged: { _ in
                                        viewModel.applySettings()
                                    }
                                    Text(String(format: "%.1f", viewModel.sceneWeights[scene.id] ?? 1.0))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                        .frame(width: 30)
                                }
                                .padding(.leading, 20)
                            }
                        }
                        .padding(.leading, 16)
                    }
                }
            }
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
    @Published var behaviorsEnabled: Bool
    @Published var behaviorsExpanded: Bool = true
    private var behaviorsExpandedBeforeDisable: Bool = true

    // Scene-related state
    @Published var scenesEnabled: Bool
    @Published var scenesExpanded: Bool = true
    private var scenesExpandedBeforeDisable: Bool = true
    @Published var sceneWeights: [String: Double]
    @Published var enabledScenes: Set<String>
    @Published var globalSceneWeight: Double = 1.0
    @Published var scenes: [PGScene] = []
    @Published var sceneToDelete: PGScene?
    @Published var showDeleteConfirmation: Bool = false

    let creatures: [Creature]
    private let sceneStorage: PGSceneStorage
    private let onTestBehavior: (Creature?, BehaviorType?) -> Void
    private let onPreviewScene: (PGScene) -> Void
    private let onEditScene: (PGScene) -> Void
    private let onSettingsChanged: (AppSettings) -> Void

    init(
        creatures: [Creature],
        sceneStorage: PGSceneStorage,
        onTestBehavior: @escaping (Creature?, BehaviorType?) -> Void,
        onPreviewScene: @escaping (PGScene) -> Void,
        onEditScene: @escaping (PGScene) -> Void,
        onSettingsChanged: @escaping (AppSettings) -> Void
    ) {
        let settings = AppSettings.load()
        self.minInterval = settings.minInterval
        self.maxInterval = settings.maxInterval
        self.launchAtLogin = settings.launchAtLogin
        self.enabledCreatureIds = settings.enabledCreatures
        self.behaviorWeights = settings.behaviorWeights
        self.behaviorsEnabled = settings.behaviorsEnabled
        self.scenesEnabled = settings.scenesEnabled
        self.sceneWeights = settings.sceneWeights
        self.enabledScenes = settings.enabledScenes
        self.creatures = creatures
        self.sceneStorage = sceneStorage
        self.onTestBehavior = onTestBehavior
        self.onPreviewScene = onPreviewScene
        self.onEditScene = onEditScene
        self.onSettingsChanged = onSettingsChanged

        // Load scenes from storage
        self.scenes = sceneStorage.loadAll()

        // Compute global scene weight from first enabled scene's weight or default to 1.0
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

    // MARK: - Scene Bindings

    func sceneEnabledBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: {
                // Empty set means all enabled
                self.enabledScenes.isEmpty || self.enabledScenes.contains(id)
            },
            set: { enabled in
                // If toggling off and set is empty, populate with all except this one
                if !enabled && self.enabledScenes.isEmpty {
                    self.enabledScenes = Set(self.scenes.map(\.id))
                    self.enabledScenes.remove(id)
                } else if enabled {
                    self.enabledScenes.insert(id)
                    // If all are now enabled, clear the set (empty = all)
                    if self.enabledScenes.count == self.scenes.count {
                        self.enabledScenes.removeAll()
                    }
                } else {
                    self.enabledScenes.remove(id)
                }
            }
        )
    }

    func sceneWeightBinding(for id: String) -> Binding<Double> {
        Binding(
            get: { self.sceneWeights[id] ?? 1.0 },
            set: { self.sceneWeights[id] = $0 }
        )
    }

    func isSceneEnabled(_ id: String) -> Bool {
        // Empty set means all enabled
        enabledScenes.isEmpty || enabledScenes.contains(id)
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

    func handleBehaviorsToggle(enabled: Bool) {
        if enabled {
            // Restore previous expanded state
            behaviorsExpanded = behaviorsExpandedBeforeDisable
        } else {
            // Remember current state and collapse
            behaviorsExpandedBeforeDisable = behaviorsExpanded
            behaviorsExpanded = false
        }
    }

    func handleScenesToggle(enabled: Bool) {
        if enabled {
            // Restore previous expanded state
            scenesExpanded = scenesExpandedBeforeDisable
        } else {
            // Remember current state and collapse
            scenesExpandedBeforeDisable = scenesExpanded
            scenesExpanded = false
        }
    }

    func applySettings() {
        let settings = buildSettings()
        try? settings.save()
        onSettingsChanged(settings)
        LaunchAtLoginManager.shared.isEnabled = settings.launchAtLogin
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
        behaviorsEnabled = defaults.behaviorsEnabled
        scenesEnabled = defaults.scenesEnabled
        sceneWeights = defaults.sceneWeights
        enabledScenes = defaults.enabledScenes
        globalSceneWeight = 1.0
        applySettings()
    }

    // MARK: - Scene Actions

    func previewScene(_ scene: PGScene) {
        onPreviewScene(scene)
    }

    func editScene(_ scene: PGScene) {
        onEditScene(scene)
    }

    func requestDeleteScene(_ scene: PGScene) {
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

    private func buildSettings() -> AppSettings {
        // Calculate effective scene weights: globalSceneWeight * individualSceneWeight
        // Only include enabled scenes
        var effectiveSceneWeights: [String: Double] = [:]
        if scenesEnabled {
            for scene in scenes {
                // Check if this scene is enabled (empty set means all enabled)
                let isEnabled = enabledScenes.isEmpty || enabledScenes.contains(scene.id)
                if isEnabled {
                    let individualWeight = sceneWeights[scene.id] ?? 1.0
                    effectiveSceneWeights[scene.id] = globalSceneWeight * individualWeight
                }
            }
        }

        // Preserve current enabled state from persisted settings
        // (enabled is managed by AppDelegate's menu bar toggle, not settings UI)
        let currentEnabled = AppSettings.load().enabled
        return AppSettings(
            enabled: currentEnabled,
            minInterval: minInterval,
            maxInterval: maxInterval,
            launchAtLogin: launchAtLogin,
            enabledCreatures: enabledCreatureIds,
            behaviorWeights: behaviorsEnabled ? behaviorWeights : [:],
            sceneWeights: effectiveSceneWeights,
            scenesEnabled: scenesEnabled,
            enabledScenes: enabledScenes,
            behaviorsEnabled: behaviorsEnabled
        )
    }
}
