import Foundation
import Synchronization

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
public final class MockTimeSource: TimeSource, Sendable {
    private let state: Mutex<TimeInterval>

    public init(now: TimeInterval = 0) {
        self.state = Mutex(now)
    }

    public var now: TimeInterval {
        state.withLock { $0 }
    }

    public func advance(by interval: TimeInterval) {
        state.withLock { $0 += interval }
    }

    public func set(_ time: TimeInterval) {
        state.withLock { $0 = time }
    }
}
