import Foundation

/// Types of behaviors creatures can perform
public enum BehaviorType: String, CaseIterable, Codable, Sendable {
    case peek           // Teleport to edge, peek, retreat
    case traverse       // Walk across screen
    case stationary     // Appear, do antics, disappear
    case climber        // Climb window edges
    case cursorReactive // React to mouse position
}

/// State machine phases for behavior execution
public enum BehaviorPhase: String, Equatable, Sendable {
    case idle           // Not active
    case enter          // Appearing/entering
    case perform        // Main action
    case exit           // Leaving/disappearing
    case complete       // Finished
}

/// Current state of a behavior instance
public struct BehaviorState: Equatable, Sendable {
    public var phase: BehaviorPhase
    public var position: Position
    public var animation: AnimationState?
    public var edge: ScreenEdge?
    public var startTime: TimeInterval
    public var duration: TimeInterval
    public var metadata: [String: String]

    public init(
        phase: BehaviorPhase = .idle,
        position: Position = .zero,
        animation: AnimationState? = nil,
        edge: ScreenEdge? = nil,
        startTime: TimeInterval = 0,
        duration: TimeInterval = 0,
        metadata: [String: String] = [:]
    ) {
        self.phase = phase
        self.position = position
        self.animation = animation
        self.edge = edge
        self.startTime = startTime
        self.duration = duration
        self.metadata = metadata
    }
}

/// Events that behaviors can emit
public enum BehaviorEvent: Equatable, Sendable {
    case started(BehaviorType)
    case phaseChanged(BehaviorPhase)
    case positionChanged(Position)
    case animationFrameChanged(Int)
    case completed
    case cancelled
}

/// Context provided to behaviors
public struct BehaviorContext: Sendable {
    public let creature: Creature
    public let screenBounds: ScreenRect
    public let currentTime: TimeInterval
    public let cursorPosition: Position?
    public let windowFrames: [ScreenRect]

    public init(
        creature: Creature,
        screenBounds: ScreenRect,
        currentTime: TimeInterval,
        cursorPosition: Position? = nil,
        windowFrames: [ScreenRect] = []
    ) {
        self.creature = creature
        self.screenBounds = screenBounds
        self.currentTime = currentTime
        self.cursorPosition = cursorPosition
        self.windowFrames = windowFrames
    }
}
