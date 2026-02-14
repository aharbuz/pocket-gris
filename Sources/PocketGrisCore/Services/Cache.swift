import Foundation
import Synchronization

/// Thread-safe generic LRU-style cache with configurable max size and half-eviction policy.
///
/// When the cache reaches `maxSize`, the oldest half of entries (by insertion order) are evicted.
/// This matches the eviction strategy used by `ImageCache` in PocketGrisApp.
public final class Cache<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    private struct State: Sendable {
        var storage: [Key: Value] = [:]
    }

    private let state: Mutex<State>

    /// Maximum number of entries before eviction kicks in.
    public let maxSize: Int

    public init(maxSize: Int = 500) {
        self.maxSize = maxSize
        self.state = Mutex(State())
    }

    /// Retrieve a value for the given key, or nil if not cached.
    public func get(_ key: Key) -> Value? {
        state.withLock { $0.storage[key] }
    }

    /// Insert or update a value for the given key.
    /// If the cache is at capacity, evicts the first half of entries.
    public func set(_ key: Key, value: Value) {
        state.withLock { s in
            if s.storage.count >= self.maxSize && s.storage[key] == nil {
                let keysToRemove = Array(s.storage.keys.prefix(self.maxSize / 2))
                for k in keysToRemove {
                    s.storage.removeValue(forKey: k)
                }
            }
            s.storage[key] = value
        }
    }

    /// Retrieve an existing value or compute and cache a new one.
    /// The `compute` closure is called outside the lock if the key is not found,
    /// and the result is cached. If another thread inserted the same key concurrently,
    /// the existing value is returned instead.
    public func getOrInsert(_ key: Key, compute: () -> Value?) -> Value? {
        // First check: try cache
        if let cached = get(key) {
            return cached
        }

        // Compute outside lock
        guard let value = compute() else {
            return nil
        }

        // Double-check and store
        return state.withLock { s in
            if let existing = s.storage[key] {
                return existing
            }
            if s.storage.count >= self.maxSize {
                let keysToRemove = Array(s.storage.keys.prefix(self.maxSize / 2))
                for k in keysToRemove {
                    s.storage.removeValue(forKey: k)
                }
            }
            s.storage[key] = value
            return value
        }
    }

    /// Remove a specific key from the cache.
    @discardableResult
    public func remove(_ key: Key) -> Value? {
        state.withLock { $0.storage.removeValue(forKey: key) }
    }

    /// Remove all cached entries.
    public func clear() {
        state.withLock { $0.storage.removeAll() }
    }

    /// Current number of cached entries.
    public var count: Int {
        state.withLock { $0.storage.count }
    }
}
