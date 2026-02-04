import Foundation

/// Protocol for time abstraction (testability)
public protocol TimeSource: Sendable {
    var now: TimeInterval { get }
}

/// System time source
public struct SystemTimeSource: TimeSource {
    public init() {}

    public var now: TimeInterval {
        Date().timeIntervalSinceReferenceDate
    }
}

/// Mock time source for testing
public final class MockTimeSource: TimeSource, @unchecked Sendable {
    private var _now: TimeInterval
    private let lock = NSLock()

    public init(now: TimeInterval = 0) {
        self._now = now
    }

    public var now: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return _now
    }

    public func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        _now += interval
    }

    public func set(_ time: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        _now = time
    }
}
