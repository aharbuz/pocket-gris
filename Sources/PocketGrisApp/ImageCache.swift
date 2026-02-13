import AppKit
import PocketGrisCore
import Synchronization

/// Thread-safe image cache for sprite frames
final class ImageCache: Sendable {
    static let shared = ImageCache()

    // NSImage is not Sendable but is safe behind Mutex
    private struct State: @unchecked Sendable {
        var cache: [String: NSImage] = [:]
    }

    private let state: Mutex<State>
    private let maxCacheSize = 500  // Max images to keep

    private init() {
        self.state = Mutex(State())
    }

    /// Get cached image or load from path
    func image(for path: String) -> NSImage? {
        // First check: try cache
        if let cached = state.withLock({ $0.cache[path] }) {
            return cached
        }

        // Load from disk (outside lock to avoid blocking other threads)
        guard let image = NSImage(contentsOfFile: path) else {
            return nil
        }

        // Second check: double-check and store
        return state.withLock { s in
            if let cached = s.cache[path] {
                return cached
            }
            // Evict if needed
            if s.cache.count >= self.maxCacheSize {
                // Simple eviction: remove half
                let keysToRemove = Array(s.cache.keys.prefix(self.maxCacheSize / 2))
                for key in keysToRemove {
                    s.cache.removeValue(forKey: key)
                }
            }
            s.cache[path] = image
            return image
        }
    }

    /// Preload images for faster playback
    func preload(paths: [String]) {
        for path in paths {
            _ = image(for: path)
        }
    }

    /// Clear all cached images
    func clear() {
        state.withLock { $0.cache.removeAll() }
    }

    /// Preload all frames for a creature's animations
    func preloadCreature(id: String, animations: [String], spriteLoader: SpriteLoader) {
        for animName in animations {
            if let frames = spriteLoader.allFramePaths(creature: id, animation: animName) {
                preload(paths: frames)
            }
        }
    }
}
