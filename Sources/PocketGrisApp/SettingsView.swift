import SwiftUI
import PocketGrisCore

// Disambiguate from SwiftUI.Settings
typealias AppSettings = PocketGrisCore.Settings

/// SwiftUI settings window for configuring Pocket Gris
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(creatures: [Creature], onTestBehavior: @escaping (Creature?, BehaviorType?) -> Void, onSettingsChanged: @escaping (AppSettings) -> Void) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            creatures: creatures,
            onTestBehavior: onTestBehavior,
            onSettingsChanged: onSettingsChanged
        ))
    }

    var body: some View {
        Form {
            appearanceSection
            creaturesSection
            behaviorsSection
            generalSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, idealWidth: 450, minHeight: 500, idealHeight: 600)
        .navigationTitle("Pocket Gris Settings")
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
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

            Button("Test Random Behavior") {
                viewModel.testBehavior()
            }
            .padding(.top, 4)
        } header: {
            Text("Behaviors")
        } footer: {
            Text("Weight controls how likely each behavior is to be chosen. Higher = more frequent.")
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

    let creatures: [Creature]
    private let onTestBehavior: (Creature?, BehaviorType?) -> Void
    private let onSettingsChanged: (AppSettings) -> Void

    init(creatures: [Creature], onTestBehavior: @escaping (Creature?, BehaviorType?) -> Void, onSettingsChanged: @escaping (AppSettings) -> Void) {
        let settings = AppSettings.load()
        self.minInterval = settings.minInterval
        self.maxInterval = settings.maxInterval
        self.launchAtLogin = settings.launchAtLogin
        self.enabledCreatureIds = settings.enabledCreatures
        self.behaviorWeights = settings.behaviorWeights
        self.creatures = creatures
        self.onTestBehavior = onTestBehavior
        self.onSettingsChanged = onSettingsChanged
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

    func resetToDefaults() {
        let defaults = AppSettings.default
        minInterval = defaults.minInterval
        maxInterval = defaults.maxInterval
        launchAtLogin = defaults.launchAtLogin
        enabledCreatureIds = defaults.enabledCreatures
        behaviorWeights = defaults.behaviorWeights
        applySettings()
    }

    private func buildSettings() -> AppSettings {
        AppSettings(
            enabled: true,
            minInterval: minInterval,
            maxInterval: maxInterval,
            launchAtLogin: launchAtLogin,
            enabledCreatures: enabledCreatureIds,
            behaviorWeights: behaviorWeights
        )
    }
}
