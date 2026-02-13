import Foundation
import Synchronization

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
public final class GlobalCursorTracker: CursorTracker, Sendable {
    // Monitor tokens (Any?) are not Sendable but are safe behind Mutex
    private struct State: @unchecked Sendable {
        var currentPosition: Position?
        var lastUpdateTime: TimeInterval = 0
        var velocity: Position = .zero
        #if canImport(AppKit)
        var globalMonitor: Any?
        var localMonitor: Any?
        #endif
    }

    private let state: Mutex<State>

    /// Update rate for velocity calculation (seconds)
    private let velocitySmoothing: Double = 0.1

    public init() {
        self.state = Mutex(State())
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    public func getCurrentPosition() -> Position? {
        state.withLock { $0.currentPosition }
    }

    public func getCursorVelocity() -> Position? {
        state.withLock { $0.velocity }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        #if canImport(AppKit)
        // Initial position from NSEvent.mouseLocation
        updatePositionFromSystemCursor()

        // Global monitor for events outside our app
        let globalMon = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            self?.handleMouseEvent(event)
        }

        // Local monitor for events within our app
        let localMon = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }

        state.withLock { s in
            s.globalMonitor = globalMon
            s.localMonitor = localMon
        }
        #endif
    }

    private func stopMonitoring() {
        #if canImport(AppKit)
        let (globalMon, localMon) = state.withLock { s -> (Any?, Any?) in
            let g = s.globalMonitor
            let l = s.localMonitor
            s.globalMonitor = nil
            s.localMonitor = nil
            return (g, l)
        }
        if let monitor = globalMon {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMon {
            NSEvent.removeMonitor(monitor)
        }
        #endif
    }

    #if canImport(AppKit)
    private func handleMouseEvent(_ event: NSEvent) {
        updatePositionFromSystemCursor()
    }

    private func updatePositionFromSystemCursor() {
        let mouseLocation = NSEvent.mouseLocation

        // Convert from bottom-left (Cocoa) to top-left coordinate system.
        // Find the screen the cursor is actually on; fall back to main.
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        // Use screen.frame.maxY (not height) because NSEvent.mouseLocation returns
        // global coordinates measured from the bottom of the primary screen.
        let y = screen.frame.maxY - mouseLocation.y
        let newPosition = Position(x: mouseLocation.x, y: y)

        state.withLock { s in
            let now = CACurrentMediaTime()
            let deltaTime = now - s.lastUpdateTime

            // Calculate velocity if we have a previous position and reasonable time delta
            if let prevPos = s.currentPosition, deltaTime > 0 && deltaTime < 1.0 {
                let dx = newPosition.x - prevPos.x
                let dy = newPosition.y - prevPos.y

                // Smooth velocity calculation
                let newVelX = dx / deltaTime
                let newVelY = dy / deltaTime

                // Exponential smoothing
                let alpha = min(deltaTime / self.velocitySmoothing, 1.0)
                s.velocity = Position(
                    x: s.velocity.x * (1 - alpha) + newVelX * alpha,
                    y: s.velocity.y * (1 - alpha) + newVelY * alpha
                )
            }

            s.currentPosition = newPosition
            s.lastUpdateTime = now
        }
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
public final class MockCursorTracker: CursorTracker, Sendable {
    private struct State: Sendable {
        var position: Position?
        var velocity: Position?
    }

    private let state: Mutex<State>

    public var position: Position? {
        get {
            state.withLock { $0.position }
        }
        set {
            state.withLock { $0.position = newValue }
        }
    }

    public var cursorVelocity: Position? {
        get {
            state.withLock { $0.velocity }
        }
        set {
            state.withLock { $0.velocity = newValue }
        }
    }

    public init(position: Position? = nil, velocity: Position? = nil) {
        self.state = Mutex(State(position: position, velocity: velocity))
    }

    public func getCurrentPosition() -> Position? {
        state.withLock { $0.position }
    }

    public func getCursorVelocity() -> Position? {
        state.withLock { $0.velocity }
    }

    /// Move cursor to simulate user input
    public func moveTo(_ position: Position) {
        state.withLock { $0.position = position }
    }

    /// Set velocity to simulate cursor movement
    public func setVelocity(_ velocity: Position) {
        state.withLock { $0.velocity = velocity }
    }
}
