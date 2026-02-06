import Foundation

/// Persistence layer for scenes (JSON files in Application Support)
public final class SceneStorage: @unchecked Sendable {
    private let directory: URL
    private let lock = NSLock()

    public init(directory: URL? = nil) {
        if let dir = directory {
            self.directory = dir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directory = appSupport
                .appendingPathComponent("PocketGris", isDirectory: true)
                .appendingPathComponent("Scenes", isDirectory: true)
        }
    }

    // MARK: - Public API

    /// Load all saved scenes
    public func loadAll() -> [Scene] {
        lock.lock()
        defer { lock.unlock() }

        ensureDirectory()

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        let decoder = JSONDecoder()
        return contents
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Scene? in
                guard let data = try? Data(contentsOf: url),
                      let scene = try? decoder.decode(Scene.self, from: data) else {
                    return nil
                }
                return scene
            }
            .sorted { $0.name < $1.name }
    }

    /// Save a scene to disk
    public func save(scene: Scene) throws {
        lock.lock()
        defer { lock.unlock() }

        ensureDirectory()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(scene)
        let url = fileURL(for: scene.id)
        try data.write(to: url)
    }

    /// Delete a scene by ID
    public func delete(id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let url = fileURL(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Load a single scene by ID
    public func load(id: String) -> Scene? {
        lock.lock()
        defer { lock.unlock() }

        let url = fileURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Scene.self, from: data)
    }

    // MARK: - Validation

    /// Validate a scene against available creatures and animations
    public func validate(scene: Scene, creatures: [Creature]) -> [String] {
        var issues: [String] = []
        let creatureMap = Dictionary(uniqueKeysWithValues: creatures.map { ($0.id, $0) })

        for (trackIndex, track) in scene.tracks.enumerated() {
            guard let creature = creatureMap[track.creatureId] else {
                issues.append("Track \(trackIndex): creature '\(track.creatureId)' not found")
                continue
            }

            if !track.isValid {
                issues.append("Track \(trackIndex): invalid structure (waypoints: \(track.waypoints.count), segments: \(track.segments.count))")
            }

            for (segIndex, segment) in track.segments.enumerated() {
                if creature.animation(named: segment.animationName) == nil {
                    issues.append("Track \(trackIndex) segment \(segIndex): animation '\(segment.animationName)' not found for creature '\(track.creatureId)'")
                }
            }
        }

        return issues
    }

    // MARK: - Private

    private func fileURL(for id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
