import Foundation

/// Follow behavior: creature follows cursor at a safe distance
/// - Appears near cursor position
/// - Maintains safe distance (personality-based)
/// - Moves smoothly toward cursor
/// - Flees if cursor comes too close
/// - Ends after set duration or when cursor leaves interaction area
public struct FollowBehavior: Behavior {
    public let type = BehaviorType.cursorReactive
    public let requiredAnimations = ["idle", "walk-left"]

    public init() {}

    public func start(context: BehaviorContext, random: RandomSource) -> BehaviorState {
        // Get initial cursor position or use center of screen
        let cursorPos = context.cursorPosition ?? context.screenBounds.center

        // Calculate starting position - appear at a safe distance from cursor
        let followDistance = context.creature.personality.followDistance
        let angle = random.double(in: 0...(2 * Double.pi))
        let startPosition = Position(
            x: cursorPos.x + cos(angle) * followDistance,
            y: cursorPos.y + sin(angle) * followDistance
        ).clamped(to: context.screenBounds)

        // Get idle animation initially
        let idleAnim = context.creature.animation(named: "idle")
            ?? Animation(name: "idle", frameCount: 1, fps: 1)

        // Duration based on personality
        let duration = random.double(in: context.creature.personality.followDurationRange)

        var state = BehaviorState(
            phase: .enter,
            position: startPosition,
            animation: AnimationState(animation: idleAnim),
            edge: nil,
            startTime: context.currentTime,
            duration: duration
        )

        // Store behavior parameters in typed metadata
        state.metadata = .follow(FollowMetadata(
            followDuration: duration,
            followDistance: followDistance,
            fleeDistance: context.creature.personality.followFleeDistance,
            moveSpeed: context.creature.personality.followSpeed
        ))

        return state
    }

    public func update(
        state: inout BehaviorState,
        context: BehaviorContext,
        deltaTime: TimeInterval
    ) -> [BehaviorEvent] {
        var events: [BehaviorEvent] = []

        // Update animation
        if state.animation?.advance(by: deltaTime) == true {
            events.append(.animationFrameChanged(state.animation!.currentFrame))
        }

        let elapsed = context.currentTime - state.startTime

        switch state.phase {
        case .idle:
            break

        case .enter:
            // Brief enter phase
            if elapsed > 0.3 {
                state.phase = .perform
                events.append(.phaseChanged(.perform))
                state.startTime = context.currentTime
            }

        case .perform:
            // Get behavior parameters
            guard case .follow(let meta) = state.metadata else {
                state.phase = .complete
                events.append(.completed)
                return events
            }
            let followDuration = meta.followDuration
            let followDistance = meta.followDistance
            let fleeDistance = meta.fleeDistance
            let moveSpeed = meta.moveSpeed

            // Check duration
            if elapsed >= followDuration {
                state.phase = .exit
                events.append(.phaseChanged(.exit))
                state.startTime = context.currentTime
                return events
            }

            // Get current cursor position
            guard let cursorPos = context.cursorPosition else {
                // No cursor - wait, but don't flee
                updateIdleAnimation(state: &state, creature: context.creature)
                return events
            }

            let currentDistance = state.position.distance(to: cursorPos)

            // Flee if cursor gets too close
            if currentDistance < fleeDistance {
                state.phase = .exit
                events.append(.phaseChanged(.exit))
                state.startTime = context.currentTime
                return events
            }

            // Move toward maintaining follow distance
            let targetDistance = followDistance
            var targetPosition: Position

            if currentDistance > targetDistance + 10 {
                // Too far - move closer
                let dx = cursorPos.x - state.position.x
                let dy = cursorPos.y - state.position.y
                let moveAmount = min(moveSpeed * deltaTime, currentDistance - targetDistance)
                let angle = atan2(dy, dx)
                targetPosition = Position(
                    x: state.position.x + cos(angle) * moveAmount,
                    y: state.position.y + sin(angle) * moveAmount
                )
                updateWalkAnimation(state: &state, direction: dx, creature: context.creature)
            } else if currentDistance < targetDistance - 10 {
                // Too close - move away slightly
                let dx = state.position.x - cursorPos.x
                let dy = state.position.y - cursorPos.y
                let moveAmount = min(moveSpeed * deltaTime * 0.5, targetDistance - currentDistance)
                let angle = atan2(dy, dx)
                targetPosition = Position(
                    x: state.position.x + cos(angle) * moveAmount,
                    y: state.position.y + sin(angle) * moveAmount
                )
                updateWalkAnimation(state: &state, direction: dx, creature: context.creature)
            } else {
                // At good distance - just idle and follow lazily
                targetPosition = state.position
                updateIdleAnimation(state: &state, creature: context.creature)
            }

            // Clamp to screen bounds
            let newPosition = targetPosition.clamped(to: context.screenBounds)
            if newPosition != state.position {
                state.position = newPosition
                events.append(.positionChanged(newPosition))
            }

        case .exit:
            // Brief exit phase
            if elapsed > 0.4 {
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

    private func updateWalkAnimation(state: inout BehaviorState, direction: Double, creature: Creature) {
        let walkName = direction < 0 ? "walk-left" : "walk-right"
        if state.animation?.animation.name != walkName {
            if let anim = creature.animation(named: walkName) {
                state.animation = AnimationState(animation: anim)
            }
        }
    }

    private func updateIdleAnimation(state: inout BehaviorState, creature: Creature) {
        if state.animation?.animation.name != "idle" {
            if let anim = creature.animation(named: "idle") {
                state.animation = AnimationState(animation: anim)
            }
        }
    }
}

// MARK: - Personality Extension

extension Personality {
    /// Distance to maintain from cursor when following
    var followDistance: Double {
        switch self {
        case .shy:
            return 200.0       // Keep far away
        case .curious:
            return 120.0       // Moderate distance
        case .mischievous:
            return 80.0        // Closer, playful
        case .chaotic:
            return 60.0        // Very close, unpredictable
        }
    }

    /// Distance at which to flee from cursor
    var followFleeDistance: Double {
        switch self {
        case .shy:
            return 100.0       // Flee early
        case .curious:
            return 60.0        // Moderate threshold
        case .mischievous:
            return 40.0        // Waits longer
        case .chaotic:
            return 30.0        // Almost never flees
        }
    }

    /// Movement speed when following cursor
    var followSpeed: Double {
        switch self {
        case .shy:
            return 60.0        // Slow, cautious
        case .curious:
            return 100.0       // Moderate
        case .mischievous:
            return 140.0       // Quick
        case .chaotic:
            return 180.0       // Very fast
        }
    }

    /// Duration range for follow behavior
    var followDurationRange: ClosedRange<Double> {
        switch self {
        case .shy:
            return 3.0...6.0        // Short, nervous
        case .curious:
            return 6.0...12.0       // Moderate engagement
        case .mischievous:
            return 4.0...10.0       // Variable
        case .chaotic:
            return 2.0...15.0       // Highly unpredictable
        }
    }
}

// MARK: - Position Extension

extension Position {
    /// Clamp position to screen bounds
    func clamped(to bounds: ScreenRect) -> Position {
        Position(
            x: max(bounds.minX, min(bounds.maxX, x)),
            y: max(bounds.minY, min(bounds.maxY, y))
        )
    }
}
