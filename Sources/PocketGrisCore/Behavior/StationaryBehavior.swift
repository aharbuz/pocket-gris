import Foundation

/// Stationary behavior: appear at edge, perform antics, disappear
public struct StationaryBehavior: Behavior {
    public let type = BehaviorType.stationary
    public let requiredAnimations = ["idle"]

    public init() {}

    public func start(context: BehaviorContext, random: RandomSource) -> BehaviorState {
        // Pick a random edge
        let edges: [ScreenEdge] = [.left, .right, .bottom]  // Top less common for stationary
        let edge = edges[random.int(in: 0..<edges.count)]

        // Calculate position at edge (slightly inside screen)
        let position = calculateStationaryPosition(edge: edge, bounds: context.screenBounds, random: random)

        // Get duration from personality
        let duration = random.double(in: context.creature.personality.stationaryDurationRange)

        // Get idle animation
        let idleAnim = context.creature.animation(named: "idle")
            ?? Animation(name: "idle", frameCount: 1, fps: 1)

        var state = BehaviorState(
            phase: .enter,
            position: position,
            animation: AnimationState(animation: idleAnim),
            edge: edge,
            startTime: context.currentTime,
            duration: duration
        )

        state.metadata = .stationary(StationaryMetadata(stationaryDuration: duration))

        return state
    }

    public func update(
        state: inout BehaviorState,
        context: BehaviorContext,
        deltaTime: TimeInterval
    ) -> [BehaviorEvent] {
        var events: [BehaviorEvent] = []

        // Update animation
        if state.animation?.advance(by: deltaTime) == true,
           let currentFrame = state.animation?.currentFrame {
            events.append(.animationFrameChanged(currentFrame))
        }

        let elapsed = context.currentTime - state.startTime

        switch state.phase {
        case .idle:
            break

        case .enter:
            // Enter phase - slide in from edge
            if elapsed > 0.5 {
                state.phase = .perform
                events.append(.phaseChanged(.perform))
                state.startTime = context.currentTime

                // Check cursor on entry
                if let cursor = context.cursorPosition {
                    let distance = state.position.distance(to: cursor)
                    if distance < 80 && context.creature.personality.cursorSensitivity > 0.5 {
                        // Too close, skip to exit
                        state.phase = .exit
                        events.append(.phaseChanged(.exit))
                        state.startTime = context.currentTime
                    }
                }
            }

        case .perform:
            // Wait for duration while playing idle animation
            let stationaryDuration: Double
            if case .stationary(let meta) = state.metadata {
                stationaryDuration = meta.stationaryDuration
            } else {
                stationaryDuration = 5.0
            }

            if elapsed >= stationaryDuration {
                state.phase = .exit
                events.append(.phaseChanged(.exit))
                state.startTime = context.currentTime
            }

            // Check cursor - might flee early
            if let cursor = context.cursorPosition {
                let distance = state.position.distance(to: cursor)
                let fleeThreshold = 100.0 * (1.0 - context.creature.personality.cursorSensitivity)
                if distance < fleeThreshold {
                    state.phase = .exit
                    events.append(.phaseChanged(.exit))
                    state.startTime = context.currentTime
                }
            }

        case .exit:
            // Exit phase - slide back to edge
            if elapsed > 0.6 {
                state.phase = .complete
                events.append(.phaseChanged(.complete))
                events.append(.completed)
            }

        case .complete:
            break
        }

        return events
    }

    public func cancel(state: inout BehaviorState) -> [BehaviorEvent] {
        if state.phase != .complete {
            state.phase = .complete
            return [.cancelled]
        }
        return []
    }

    // MARK: - Helpers

    private func calculateStationaryPosition(
        edge: ScreenEdge,
        bounds: ScreenRect,
        random: RandomSource
    ) -> Position {
        let inset: Double = 40  // How far inside the edge
        let margin: Double = 80  // Keep away from corners

        switch edge {
        case .left:
            let y = random.double(in: (bounds.minY + margin)...(bounds.maxY - margin))
            return Position(x: bounds.minX + inset, y: y)
        case .right:
            let y = random.double(in: (bounds.minY + margin)...(bounds.maxY - margin))
            return Position(x: bounds.maxX - inset, y: y)
        case .top:
            let x = random.double(in: (bounds.minX + margin)...(bounds.maxX - margin))
            return Position(x: x, y: bounds.minY + inset)
        case .bottom:
            let x = random.double(in: (bounds.minX + margin)...(bounds.maxX - margin))
            return Position(x: x, y: bounds.maxY - inset)
        }
    }
}

// MARK: - Personality Extension

extension Personality {
    /// Duration range for stationary behavior
    var stationaryDurationRange: ClosedRange<Double> {
        switch self {
        case .shy:
            return 2.0...4.0        // Short, nervous
        case .curious:
            return 4.0...8.0        // Moderate
        case .mischievous:
            return 3.0...6.0        // Variable, playful
        case .chaotic:
            return 1.0...10.0       // Highly unpredictable
        }
    }
}
