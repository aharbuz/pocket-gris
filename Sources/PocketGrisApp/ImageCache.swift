import AppKit
import PocketGrisCore

/// Thread-safe image cache for sprite frames
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private var cache: [String: NSImage] = [:]
    private let lock = NSLock()
    private let maxCacheSize = 500  // Max images to keep

    private init() {}

    /// Get cached image or load from path
    func image(for path: String) -> NSImage? {
        lock.lock()
        if let cached = cache[path] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Load from disk (outside lock to avoid blocking other threads)
        guard let image = NSImage(contentsOfFile: path) else {
            return nil
        }

        lock.lock()
        // Double-check: another thread may have inserted while we were loading
        if let cached = cache[path] {
            lock.unlock()
            return cached
        }
        // Evict if needed
        if cache.count >= maxCacheSize {
            // Simple eviction: remove half
            let keysToRemove = Array(cache.keys.prefix(maxCacheSize / 2))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
        cache[path] = image
        lock.unlock()

        return image
    }

    /// Preload images for faster playback
    func preload(paths: [String]) {
        for path in paths {
            _ = image(for: path)
        }
    }

    /// Clear all cached images
    func clear() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
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
