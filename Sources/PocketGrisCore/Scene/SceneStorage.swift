import Foundation
import Synchronization

/// Persistence layer for scenes (JSON files in Application Support)
public final class SceneStorage: Sendable {
    private let directory: URL
    private let mutex = Mutex(())

    public init(directory: URL? = nil) {
        if let dir = directory {
            self.directory = dir
        } else {
            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                fatalError("Application Support directory not found")
            }
            self.directory = appSupport
                .appendingPathComponent("PocketGris", isDirectory: true)
                .appendingPathComponent("Scenes", isDirectory: true)
        }
    }

    // MARK: - Public API

    /// Load all saved scenes
    public func loadAll() -> [Scene] {
        mutex.withLock { _ in
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
    }

    /// Save a scene to disk
    public func save(scene: Scene) throws {
        try mutex.withLock { _ in
            ensureDirectory()

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(scene)
            let url = fileURL(for: scene.id)
            try data.write(to: url)
        }
    }

    /// Delete a scene by ID
    public func delete(id: String) throws {
        try mutex.withLock { _ in
            let url = fileURL(for: id)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    /// Load a single scene by ID
    public func load(id: String) -> Scene? {
        mutex.withLock { _ in
            let url = fileURL(for: id)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Scene.self, from: data)
        }
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

    private static func sanitizeId(_ id: String) -> String? {
        // Only allow alphanumeric, hyphen, underscore, and period characters
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let filtered = id.unicodeScalars.filter { allowed.contains($0) }
        let sanitized = String(String.UnicodeScalarView(filtered))
        // Reject empty, dot-only, or path-traversal patterns
        guard !sanitized.isEmpty, sanitized != ".", sanitized != ".." else { return nil }
        return sanitized
    }

    private func fileURL(for id: String) -> URL {
        let safeId = Self.sanitizeId(id) ?? "invalid"
        return directory.appendingPathComponent("\(safeId).json")
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
