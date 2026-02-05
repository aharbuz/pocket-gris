import Foundation

#if canImport(AppKit)
import AppKit
#endif

/// Protocol for tracking cursor position system-wide
public protocol CursorTracker: Sendable {
    /// Get current cursor position (in screen coordinates, top-left origin)
    func getCurrentPosition() -> Position?

    /// Get cursor velocity (pixels per second, for reactive behaviors)
    func getCursorVelocity() -> Position?
}

/// Global cursor tracker using NSEvent monitors
/// Tracks cursor position system-wide, not just within our app's windows
public final class GlobalCursorTracker: CursorTracker, @unchecked Sendable {
    private let lock = NSLock()
    private var currentPosition: Position?
    private var previousPosition: Position?
    private var lastUpdateTime: TimeInterval = 0
    private var velocity: Position = .zero

    #if canImport(AppKit)
    private var globalMonitor: Any?
    private var localMonitor: Any?
    #endif

    /// Update rate for velocity calculation (seconds)
    private let velocitySmoothing: Double = 0.1

    public init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    public func getCurrentPosition() -> Position? {
        lock.lock()
        defer { lock.unlock() }
        return currentPosition
    }

    public func getCursorVelocity() -> Position? {
        lock.lock()
        defer { lock.unlock() }
        return velocity
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        #if canImport(AppKit)
        // Initial position from NSEvent.mouseLocation
        updatePositionFromSystemCursor()

        // Global monitor for events outside our app
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            self?.handleMouseEvent(event)
        }

        // Local monitor for events within our app
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }
        #endif
    }

    private func stopMonitoring() {
        #if canImport(AppKit)
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        #endif
    }

    #if canImport(AppKit)
    private func handleMouseEvent(_ event: NSEvent) {
        updatePositionFromSystemCursor()
    }

    private func updatePositionFromSystemCursor() {
        let mouseLocation = NSEvent.mouseLocation

        // Convert from bottom-left (Cocoa) to top-left coordinate system
        guard let screen = NSScreen.main else { return }
        let y = screen.frame.height - mouseLocation.y
        let newPosition = Position(x: mouseLocation.x, y: y)

        lock.lock()
        defer { lock.unlock() }

        let now = CACurrentMediaTime()
        let deltaTime = now - lastUpdateTime

        // Calculate velocity if we have a previous position and reasonable time delta
        if let prevPos = currentPosition, deltaTime > 0 && deltaTime < 1.0 {
            let dx = newPosition.x - prevPos.x
            let dy = newPosition.y - prevPos.y

            // Smooth velocity calculation
            let newVelX = dx / deltaTime
            let newVelY = dy / deltaTime

            // Exponential smoothing
            let alpha = min(deltaTime / velocitySmoothing, 1.0)
            velocity = Position(
                x: velocity.x * (1 - alpha) + newVelX * alpha,
                y: velocity.y * (1 - alpha) + newVelY * alpha
            )
        }

        previousPosition = currentPosition
        currentPosition = newPosition
        lastUpdateTime = now
    }
    #endif

    /// Force a position update (useful for polling fallback)
    public func poll() {
        #if canImport(AppKit)
        updatePositionFromSystemCursor()
        #endif
    }
}

/// Mock cursor tracker for testing
public final class MockCursorTracker: CursorTracker, @unchecked Sendable {
    private var _position: Position?
    private var _velocity: Position?
    private let lock = NSLock()

    public var position: Position? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _position
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _position = newValue
        }
    }

    public var cursorVelocity: Position? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _velocity
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _velocity = newValue
        }
    }

    public init(position: Position? = nil, velocity: Position? = nil) {
        self._position = position
        self._velocity = velocity
    }

    public func getCurrentPosition() -> Position? {
        lock.lock()
        defer { lock.unlock() }
        return _position
    }

    public func getCursorVelocity() -> Position? {
        lock.lock()
        defer { lock.unlock() }
        return _velocity
    }

    /// Move cursor to simulate user input
    public func moveTo(_ position: Position) {
        lock.lock()
        defer { lock.unlock() }
        _position = position
    }

    /// Set velocity to simulate cursor movement
    public func setVelocity(_ velocity: Position) {
        lock.lock()
        defer { lock.unlock() }
        _velocity = velocity
    }
}
