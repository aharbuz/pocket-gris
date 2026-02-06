import Foundation

/// Application settings
public struct Settings: Equatable, Codable, Sendable {
    /// Whether creatures are enabled
    public var enabled: Bool

    /// Minimum interval between appearances (seconds)
    public var minInterval: TimeInterval

    /// Maximum interval between appearances (seconds)
    public var maxInterval: TimeInterval

    /// Launch at login
    public var launchAtLogin: Bool

    /// Enabled creature IDs (empty = all enabled)
    public var enabledCreatures: Set<String>

    /// Behavior weights for scheduler
    public var behaviorWeights: [String: Double]

    /// Scene weights for scheduler (scene ID → weight)
    public var sceneWeights: [String: Double]

    public init(
        enabled: Bool = true,
        minInterval: TimeInterval = 15 * 60,  // 15 minutes
        maxInterval: TimeInterval = 30 * 60,  // 30 minutes
        launchAtLogin: Bool = false,
        enabledCreatures: Set<String> = [],
        behaviorWeights: [String: Double] = [:],
        sceneWeights: [String: Double] = [:]
    ) {
        self.enabled = enabled
        self.minInterval = minInterval
        self.maxInterval = maxInterval
        self.launchAtLogin = launchAtLogin
        self.enabledCreatures = enabledCreatures
        self.behaviorWeights = behaviorWeights
        self.sceneWeights = sceneWeights
    }

    /// Default settings
    public static let `default` = Settings()

    /// Random interval within configured range
    public func randomInterval(using random: RandomSource = SystemRandomSource()) -> TimeInterval {
        random.double(in: minInterval...maxInterval)
    }
}

// MARK: - Persistence

extension Settings {
    private static var settingsURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PocketGris", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    public static func load() -> Settings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            return .default
        }
        return settings
    }

    public func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: Self.settingsURL)
    }
}
