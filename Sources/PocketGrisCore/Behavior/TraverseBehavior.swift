import Foundation

/// Traverse behavior: walk across screen from one edge to the opposite
public struct TraverseBehavior: Behavior {
    public let type = BehaviorType.traverse
    public let requiredAnimations = ["walk-left", "idle"]

    public init() {}

    public func start(context: BehaviorContext, random: RandomSource) -> BehaviorState {
        // Pick random horizontal direction (left-to-right or right-to-left)
        let startEdge: ScreenEdge = random.bool() ? .left : .right
        let endEdge: ScreenEdge = startEdge == .left ? .right : .left

        // Calculate Y position (consistent across the traverse)
        let bounds = context.screenBounds
        let margin: Double = 100
        let y = random.double(in: (bounds.minY + margin)...(bounds.maxY - margin))

        // Calculate positions
        let startX = startEdge == .left ? bounds.minX - 50 : bounds.maxX + 50
        let endX = endEdge == .left ? bounds.minX - 50 : bounds.maxX + 50

        let startPosition = Position(x: startX, y: y)

        // Get walk animation (fall back to idle if no directional walk)
        let walkAnim = walkAnimation(direction: endEdge, creature: context.creature)

        // Calculate traverse speed and duration from personality
        let speed = context.creature.personality.traverseSpeed
        let distance = abs(endX - startX)
        let duration = distance / speed

        var state = BehaviorState(
            phase: .enter,
            position: startPosition,
            animation: AnimationState(animation: walkAnim),
            edge: startEdge,
            startTime: context.currentTime,
            duration: duration
        )

        // Store path info in typed metadata
        state.metadata = .traverse(TraverseMetadata(
            startX: startX,
            endX: endX,
            y: y,
            speed: speed
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
            // Short enter phase - just start moving
            if elapsed > 0.1 {
                state.phase = .perform
                events.append(.phaseChanged(.perform))
                state.startTime = context.currentTime
            }

        case .perform:
            // Move across screen
            guard case .traverse(let meta) = state.metadata else {
                state.phase = .complete
                events.append(.completed)
                return events
            }
            let startX = meta.startX
            let endX = meta.endX
            let y = meta.y
            let speed = meta.speed

            // Calculate current position based on elapsed time and speed
            let distance = speed * elapsed
            let direction: Double = endX > startX ? 1.0 : -1.0
            let currentX = startX + (distance * direction)

            // Check if reached destination
            let reachedEnd = (direction > 0 && currentX >= endX) || (direction < 0 && currentX <= endX)

            if reachedEnd {
                state.position = Position(x: endX, y: y)
                events.append(.positionChanged(state.position))
                state.phase = .exit
                events.append(.phaseChanged(.exit))
                state.startTime = context.currentTime
            } else {
                let newPosition = Position(x: currentX, y: y)
                if newPosition != state.position {
                    state.position = newPosition
                    events.append(.positionChanged(newPosition))
                }
            }

            // Check for cursor proximity - apply temporary speed boost
            // (boost is calculated per-frame, not accumulated into stored speed)
            if let cursor = context.cursorPosition {
                let cursorDist = state.position.distance(to: cursor)
                let sensitivity = context.creature.personality.cursorSensitivity
                if cursorDist < 150 && sensitivity > 0.3 {
                    let boost = 1.0 + (1.0 - cursorDist / 150) * sensitivity
                    let boostedSpeed = speed * boost
                    // Recalculate position with boosted speed for this frame
                    let boostedDistance = boostedSpeed * elapsed
                    let boostedX = startX + (boostedDistance * direction)
                    let boostedReachedEnd = (direction > 0 && boostedX >= endX) || (direction < 0 && boostedX <= endX)
                    if !reachedEnd && !boostedReachedEnd {
                        let boostedPosition = Position(x: boostedX, y: y)
                        if boostedPosition != state.position {
                            state.position = boostedPosition
                        }
                    }
                }
            }

        case .exit:
            // Brief exit phase
            if elapsed > 0.3 {
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

    private func walkAnimation(direction: ScreenEdge, creature: Creature) -> Animation {
        // Try directional walk first, then generic walk, then idle
        let directionName = direction == .left ? "walk-left" : "walk-right"

        if let anim = creature.animation(named: directionName) {
            return anim
        }
        if let anim = creature.animation(named: "walk") {
            return anim
        }
        // Fall back to idle
        return creature.animation(named: "idle") ?? Animation(name: "idle", frameCount: 1, fps: 1)
    }
}

// MARK: - Personality Extension

extension Personality {
    /// Speed in pixels per second for traverse behavior
    var traverseSpeed: Double {
        switch self {
        case .shy:
            return 80.0        // Slow, cautious
        case .curious:
            return 120.0       // Moderate pace
        case .mischievous:
            return 150.0       // Quick, unpredictable
        case .chaotic:
            return 180.0       // Fast, erratic
        }
    }
}
