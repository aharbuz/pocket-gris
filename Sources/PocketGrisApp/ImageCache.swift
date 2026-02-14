import AppKit
import PocketGrisCore

/// Wrapper to make NSImage usable in a Sendable Cache.
/// NSImage is thread-safe for reading once created, so this is safe.
private struct SendableImage: @unchecked Sendable {
    let image: NSImage
}

/// Thread-safe image cache for sprite frames.
/// Wraps the generic `Cache` from PocketGrisCore.
final class ImageCache: Sendable {
    static let shared = ImageCache()

    private let cache: Cache<String, SendableImage>

    private init() {
        self.cache = Cache(maxSize: 500)
    }

    /// Get cached image or load from path
    func image(for path: String) -> NSImage? {
        cache.getOrInsert(path) {
            NSImage(contentsOfFile: path).map { SendableImage(image: $0) }
        }?.image
    }

    /// Preload images for faster playback
    func preload(paths: [String]) {
        for path in paths {
            _ = image(for: path)
        }
    }

    /// Clear all cached images
    func clear() {
        cache.clear()
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
