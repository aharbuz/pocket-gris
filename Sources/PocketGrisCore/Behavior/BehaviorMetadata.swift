import Foundation

/// Typed metadata for behavior state, replacing the stringly-typed [String: String] dictionary.
/// Each behavior stores only the data it needs in a strongly-typed struct.
public enum BehaviorMetadata: Equatable, Sendable {
    case none
    case peek(PeekMetadata)
    case traverse(TraverseMetadata)
    case stationary(StationaryMetadata)
    case climber(ClimberMetadata)
    case follow(FollowMetadata)
    case scripted(ScriptedMetadata)
}

// MARK: - Per-Behavior Metadata Structs

public struct PeekMetadata: Equatable, Sendable {
    public var peekDuration: Double

    public init(peekDuration: Double) {
        self.peekDuration = peekDuration
    }
}

public struct TraverseMetadata: Equatable, Sendable {
    public var startX: Double
    public var endX: Double
    public var y: Double
    public var speed: Double

    public init(startX: Double, endX: Double, y: Double, speed: Double) {
        self.startX = startX
        self.endX = endX
        self.y = y
        self.speed = speed
    }
}

public struct StationaryMetadata: Equatable, Sendable {
    public var stationaryDuration: Double

    public init(stationaryDuration: Double) {
        self.stationaryDuration = stationaryDuration
    }
}

public struct ClimberMetadata: Equatable, Sendable {
    public var windowID: Int?
    public var startX: Double
    public var startY: Double
    public var endX: Double
    public var endY: Double
    public var speed: Double
    public var windowX: Double
    public var windowY: Double
    public var windowWidth: Double
    public var windowHeight: Double

    public init(
        windowID: Int? = nil,
        startX: Double,
        startY: Double,
        endX: Double,
        endY: Double,
        speed: Double,
        windowX: Double,
        windowY: Double,
        windowWidth: Double,
        windowHeight: Double
    ) {
        self.windowID = windowID
        self.startX = startX
        self.startY = startY
        self.endX = endX
        self.endY = endY
        self.speed = speed
        self.windowX = windowX
        self.windowY = windowY
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
    }
}

public struct FollowMetadata: Equatable, Sendable {
    public var followDuration: Double
    public var followDistance: Double
    public var fleeDistance: Double
    public var moveSpeed: Double

    public init(
        followDuration: Double,
        followDistance: Double,
        fleeDistance: Double,
        moveSpeed: Double
    ) {
        self.followDuration = followDuration
        self.followDistance = followDistance
        self.fleeDistance = fleeDistance
        self.moveSpeed = moveSpeed
    }
}

public struct ScriptedMetadata: Equatable, Sendable {
    public var segmentIndex: Int
    public var segmentElapsed: Double
    public var enterElapsed: Double
    public var exitElapsed: Double

    public init(
        segmentIndex: Int = 0,
        segmentElapsed: Double = 0,
        enterElapsed: Double = 0,
        exitElapsed: Double = 0
    ) {
        self.segmentIndex = segmentIndex
        self.segmentElapsed = segmentElapsed
        self.enterElapsed = enterElapsed
        self.exitElapsed = exitElapsed
    }
}

// MARK: - Dictionary Representation (for CLI backward compatibility)

extension BehaviorMetadata {
    /// Returns a dictionary representation for JSON serialization, or nil for `.none`.
    public var dictionaryRepresentation: [String: String]? {
        switch self {
        case .none:
            return nil

        case .peek(let meta):
            return [
                "peekDuration": String(meta.peekDuration)
            ]

        case .traverse(let meta):
            return [
                "startX": String(meta.startX),
                "endX": String(meta.endX),
                "y": String(meta.y),
                "speed": String(meta.speed)
            ]

        case .stationary(let meta):
            return [
                "stationaryDuration": String(meta.stationaryDuration)
            ]

        case .climber(let meta):
            var dict: [String: String] = [
                "startX": String(meta.startX),
                "startY": String(meta.startY),
                "endX": String(meta.endX),
                "endY": String(meta.endY),
                "speed": String(meta.speed),
                "windowX": String(meta.windowX),
                "windowY": String(meta.windowY),
                "windowWidth": String(meta.windowWidth),
                "windowHeight": String(meta.windowHeight)
            ]
            if let windowID = meta.windowID {
                dict["windowID"] = String(windowID)
            }
            return dict

        case .follow(let meta):
            return [
                "followDuration": String(meta.followDuration),
                "followDistance": String(meta.followDistance),
                "fleeDistance": String(meta.fleeDistance),
                "moveSpeed": String(meta.moveSpeed)
            ]

        case .scripted(let meta):
            return [
                "segmentIndex": String(meta.segmentIndex),
                "segmentElapsed": String(meta.segmentElapsed),
                "enterElapsed": String(meta.enterElapsed),
                "exitElapsed": String(meta.exitElapsed)
            ]
        }
    }
}
