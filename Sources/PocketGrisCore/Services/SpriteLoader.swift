import Foundation
import Synchronization

/// Loads and manages sprite assets from disk
public final class SpriteLoader: Sendable {

    private struct State: Sendable {
        var loadedCreatures: [String: Creature] = [:]
        var frameCache: [String: [String]] = [:]  // animation name -> frame paths
    }

    private let resourcesPath: URL
    private let state: Mutex<State>

    public init(resourcesPath: URL? = nil) {
        if let path = resourcesPath {
            self.resourcesPath = path
        } else {
            // Default to Resources/Sprites in the app bundle or working directory
            let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("Sprites")
            let workingPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/Sprites")

            if let bundle = bundlePath, FileManager.default.fileExists(atPath: bundle.path) {
                self.resourcesPath = bundle
            } else {
                self.resourcesPath = workingPath
            }
        }
        self.state = Mutex(State())
    }

    // MARK: - Loading

    /// Load all creatures from the sprites directory
    public func loadAllCreatures() -> [Creature] {
        state.withLock { s in
            s.loadedCreatures.removeAll()

            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: resourcesPath,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) else {
                return []
            }

            for url in contents {
                guard url.hasDirectoryPath else { continue }

                if let creature = Self.loadCreatureImpl(at: url, state: &s) {
                    s.loadedCreatures[creature.id] = creature
                }
            }

            return Array(s.loadedCreatures.values)
        }
    }

    /// Load a specific creature by ID
    public func loadCreature(id: String) -> Creature? {
        state.withLock { s in
            if let cached = s.loadedCreatures[id] {
                return cached
            }

            let creaturePath = resourcesPath.appendingPathComponent(id, isDirectory: true)
            guard let creature = Self.loadCreatureImpl(at: creaturePath, state: &s) else {
                return nil
            }

            s.loadedCreatures[creature.id] = creature
            return creature
        }
    }

    private static func loadCreatureImpl(at url: URL, state: inout State) -> Creature? {
        let manifestPath = url.appendingPathComponent("creature.json")

        guard let data = try? Data(contentsOf: manifestPath),
              let manifest = try? JSONDecoder().decode(CreatureManifest.self, from: data),
              let creature = manifest.toCreature() else {
            return nil
        }

        // Cache frame paths for each animation
        for (name, _) in creature.animations {
            let animPath = url.appendingPathComponent(name, isDirectory: true)
            if let frames = loadFramePaths(at: animPath) {
                let cacheKey = "\(creature.id)/\(name)"
                state.frameCache[cacheKey] = frames
            }
        }

        return creature
    }

    private static func loadFramePaths(at url: URL) -> [String]? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        let pngs = contents
            .filter { $0.pathExtension.lowercased() == "png" }
            .map { $0.path }
            .sorted()

        return pngs.isEmpty ? nil : pngs
    }

    // MARK: - Frame Access

    /// Get frame path for a creature animation
    public func framePath(
        creature: String,
        animation: String,
        frame: Int
    ) -> String? {
        state.withLock { s in
            let cacheKey = "\(creature)/\(animation)"
            guard let frames = s.frameCache[cacheKey], frame < frames.count else {
                return nil
            }
            return frames[frame]
        }
    }

    /// Get all frame paths for an animation
    public func allFramePaths(
        creature: String,
        animation: String
    ) -> [String]? {
        state.withLock { s in
            let cacheKey = "\(creature)/\(animation)"
            return s.frameCache[cacheKey]
        }
    }

    // MARK: - Creature Access

    /// Get a loaded creature
    public func creature(id: String) -> Creature? {
        state.withLock { $0.loadedCreatures[id] }
    }

    /// Get all loaded creatures
    public func allCreatures() -> [Creature] {
        state.withLock { Array($0.loadedCreatures.values) }
    }

}

// MARK: - Placeholder Sprites

extension SpriteLoader {
    /// Create placeholder frames for testing when no real sprites exist
    public static func createPlaceholderManifest(
        id: String,
        name: String,
        personality: Personality = .curious
    ) -> CreatureManifest {
        CreatureManifest(
            id: id,
            name: name,
            personality: personality.rawValue,
            animations: [
                CreatureManifest.AnimationEntry(name: "peek-left", frameCount: 10, fps: 12, looping: false),
                CreatureManifest.AnimationEntry(name: "peek-right", frameCount: 10, fps: 12, looping: false),
                CreatureManifest.AnimationEntry(name: "retreat-left", frameCount: 8, fps: 12, looping: false),
                CreatureManifest.AnimationEntry(name: "retreat-right", frameCount: 8, fps: 12, looping: false),
                CreatureManifest.AnimationEntry(name: "idle", frameCount: 4, fps: 6, looping: true)
            ]
        )
    }
}
