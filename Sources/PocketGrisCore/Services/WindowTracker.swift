import Foundation

#if canImport(AppKit)
import AppKit
#endif

/// Protocol for tracking window positions on screen
public protocol WindowTracker: Sendable {
    /// Get current window frames (excluding menubar, dock, and own windows)
    func getWindowFrames() -> [ScreenRect]
}

/// System window tracker using macOS Accessibility APIs
public final class AccessibilityWindowTracker: WindowTracker, @unchecked Sendable {
    private let excludedBundleIds: Set<String>
    private let lock = NSLock()

    public init(excludedBundleIds: Set<String> = []) {
        var excluded = excludedBundleIds
        // Always exclude our own app
        if let bundleId = Bundle.main.bundleIdentifier {
            excluded.insert(bundleId)
        }
        // Exclude system UI elements
        excluded.insert("com.apple.dock")
        excluded.insert("com.apple.controlcenter")
        excluded.insert("com.apple.notificationcenterui")
        self.excludedBundleIds = excluded
    }

    public func getWindowFrames() -> [ScreenRect] {
        #if canImport(AppKit)
        lock.lock()
        defer { lock.unlock() }

        var frames: [ScreenRect] = []

        // Get all windows using CGWindowListCopyWindowInfo
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return frames
        }

        for windowInfo in windowList {
            // Skip windows without bounds
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? Double,
                  let y = boundsDict["Y"] as? Double,
                  let width = boundsDict["Width"] as? Double,
                  let height = boundsDict["Height"] as? Double else {
                continue
            }

            // Skip tiny windows (likely system elements)
            guard width > 50 && height > 50 else {
                continue
            }

            // Skip excluded apps
            if let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32 {
                if let app = NSRunningApplication(processIdentifier: ownerPID),
                   let bundleId = app.bundleIdentifier,
                   excludedBundleIds.contains(bundleId) {
                    continue
                }
            }

            // Skip windows with low layer (desktop background)
            if let layer = windowInfo[kCGWindowLayer as String] as? Int, layer < 0 {
                continue
            }

            frames.append(ScreenRect(x: x, y: y, width: width, height: height))
        }

        return frames
        #else
        return []
        #endif
    }
}

/// Mock window tracker for testing
public final class MockWindowTracker: WindowTracker, @unchecked Sendable {
    private var _frames: [ScreenRect]
    private let lock = NSLock()

    public var frames: [ScreenRect] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _frames
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _frames = newValue
        }
    }

    public init(frames: [ScreenRect] = []) {
        self._frames = frames
    }

    public func getWindowFrames() -> [ScreenRect] {
        lock.lock()
        defer { lock.unlock() }
        return _frames
    }
}

// MARK: - ScreenRect Extensions for Window Edges

extension ScreenRect {
    /// Edges available for climbing (left, right, top, bottom of window)
    public enum WindowEdge: CaseIterable {
        case top, bottom, left, right
    }

    /// Get a random position along a window edge
    public func randomPositionOnEdge(_ edge: WindowEdge, random: RandomSource, margin: Double = 20) -> Position {
        switch edge {
        case .top:
            let x = random.double(in: (minX + margin)...(maxX - margin))
            return Position(x: x, y: minY)
        case .bottom:
            let x = random.double(in: (minX + margin)...(maxX - margin))
            return Position(x: x, y: maxY)
        case .left:
            let y = random.double(in: (minY + margin)...(maxY - margin))
            return Position(x: minX, y: y)
        case .right:
            let y = random.double(in: (minY + margin)...(maxY - margin))
            return Position(x: maxX, y: y)
        }
    }

    /// Position at the corner between two edges
    public func cornerPosition(primary: WindowEdge, secondary: WindowEdge) -> Position {
        switch (primary, secondary) {
        case (.top, .left), (.left, .top):
            return Position(x: minX, y: minY)
        case (.top, .right), (.right, .top):
            return Position(x: maxX, y: minY)
        case (.bottom, .left), (.left, .bottom):
            return Position(x: minX, y: maxY)
        case (.bottom, .right), (.right, .bottom):
            return Position(x: maxX, y: maxY)
        default:
            return center
        }
    }

    /// Check if a position is near this window's edge
    public func isNearEdge(_ position: Position, threshold: Double = 30) -> WindowEdge? {
        // Check if within bounds + threshold
        let expanded = ScreenRect(
            x: x - threshold,
            y: y - threshold,
            width: width + threshold * 2,
            height: height + threshold * 2
        )
        guard expanded.contains(position) else { return nil }

        // Find nearest edge
        let distTop = abs(position.y - minY)
        let distBottom = abs(position.y - maxY)
        let distLeft = abs(position.x - minX)
        let distRight = abs(position.x - maxX)

        let minDist = min(distTop, distBottom, distLeft, distRight)

        if minDist > threshold { return nil }

        if minDist == distTop { return .top }
        if minDist == distBottom { return .bottom }
        if minDist == distLeft { return .left }
        return .right
    }
}
