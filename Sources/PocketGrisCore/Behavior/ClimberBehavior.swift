import Foundation

/// Climber behavior: creature climbs along window edges
/// - Appears on a random window edge
/// - Walks along the edge (horizontally on top/bottom, vertically on left/right)
/// - May transition to adjacent edge at corners
/// - Disappears after completing a climb or on cursor proximity
public struct ClimberBehavior: Behavior {
    public let type = BehaviorType.climber
    public let requiredAnimations = ["climb", "idle"]

    public init() {}

    public func start(context: BehaviorContext, random: RandomSource) -> BehaviorState {
        // Need at least one window to climb
        guard !context.windowFrames.isEmpty else {
            // No windows available - use fallback idle at screen edge
            return createFallbackState(context: context, random: random)
        }

        // Pick a random window
        let windowIndex = random.int(in: 0..<context.windowFrames.count)
        let window = context.windowFrames[windowIndex]

        // Pick a random starting edge
        let edges: [ScreenRect.WindowEdge] = [.top, .bottom, .left, .right]
        let startEdge = edges[random.int(in: 0..<edges.count)]

        // Get starting position on the edge
        let startPosition = window.randomPositionOnEdge(startEdge, random: random)

        // Determine climb direction (along the edge)
        let climbDirection = random.bool() // true = positive direction (right/down), false = negative (left/up)

        // Calculate end position (corner or opposite corner of edge)
        let endPosition = calculateEndPosition(
            window: window,
            edge: startEdge,
            direction: climbDirection
        )

        // Duration based on distance and personality
        let distance = startPosition.distance(to: endPosition)
        let speed = context.creature.personality.climbSpeed
        let duration = distance / speed

        // Get climb animation
        let animation = climbAnimation(for: startEdge, creature: context.creature)

        var state = BehaviorState(
            phase: .enter,
            position: startPosition,
            animation: AnimationState(animation: animation),
            edge: nil,  // Not using screen edge, using window edge
            startTime: context.currentTime,
            duration: duration
        )

        // Store metadata
        state.metadata["windowIndex"] = String(windowIndex)
        state.metadata["windowEdge"] = String(describing: startEdge)
        state.metadata["climbDirection"] = climbDirection ? "positive" : "negative"
        state.metadata["startX"] = String(startPosition.x)
        state.metadata["startY"] = String(startPosition.y)
        state.metadata["endX"] = String(endPosition.x)
        state.metadata["endY"] = String(endPosition.y)
        state.metadata["speed"] = String(speed)

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
            // Short appearance phase
            if elapsed > 0.2 {
                state.phase = .perform
                events.append(.phaseChanged(.perform))
                state.startTime = context.currentTime
            }

        case .perform:
            // Climb along the edge
            guard let startX = Double(state.metadata["startX"] ?? ""),
                  let startY = Double(state.metadata["startY"] ?? ""),
                  let endX = Double(state.metadata["endX"] ?? ""),
                  let endY = Double(state.metadata["endY"] ?? ""),
                  let speed = Double(state.metadata["speed"] ?? "") else {
                state.phase = .complete
                events.append(.completed)
                return events
            }

            // Calculate progress based on time and speed
            let totalDistance = Position(x: startX, y: startY).distance(to: Position(x: endX, y: endY))
            let distanceTraveled = speed * elapsed
            let progress = min(distanceTraveled / totalDistance, 1.0)

            // Interpolate position
            let currentX = startX + (endX - startX) * progress
            let currentY = startY + (endY - startY) * progress
            let newPosition = Position(x: currentX, y: currentY)

            if newPosition != state.position {
                state.position = newPosition
                events.append(.positionChanged(newPosition))
            }

            // Check for cursor proximity - flee if too close
            if let cursor = context.cursorPosition {
                let distance = state.position.distance(to: cursor)
                let sensitivity = context.creature.personality.cursorSensitivity
                let fleeThreshold = 100.0 * sensitivity

                if distance < fleeThreshold && sensitivity > 0.3 {
                    state.phase = .exit
                    events.append(.phaseChanged(.exit))
                    state.startTime = context.currentTime
                    return events
                }
            }

            // Check if completed climb
            if progress >= 1.0 {
                state.position = Position(x: endX, y: endY)
                events.append(.positionChanged(state.position))
                state.phase = .exit
                events.append(.phaseChanged(.exit))
                state.startTime = context.currentTime
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

    private func createFallbackState(context: BehaviorContext, random: RandomSource) -> BehaviorState {
        // If no windows, fall back to simple stationary behavior at screen edge
        let bounds = context.screenBounds
        let position = Position(
            x: random.double(in: bounds.minX...bounds.maxX),
            y: bounds.maxY - 50  // Near bottom of screen
        )

        let animation = context.creature.animation(named: "idle")
            ?? Animation(name: "idle", frameCount: 1, fps: 1)

        return BehaviorState(
            phase: .enter,
            position: position,
            animation: AnimationState(animation: animation),
            startTime: context.currentTime,
            duration: 2.0
        )
    }

    private func calculateEndPosition(
        window: ScreenRect,
        edge: ScreenRect.WindowEdge,
        direction: Bool
    ) -> Position {
        let margin: Double = 20

        switch edge {
        case .top:
            // Move horizontally along top edge
            if direction {
                return Position(x: window.maxX - margin, y: window.minY)
            } else {
                return Position(x: window.minX + margin, y: window.minY)
            }

        case .bottom:
            // Move horizontally along bottom edge
            if direction {
                return Position(x: window.maxX - margin, y: window.maxY)
            } else {
                return Position(x: window.minX + margin, y: window.maxY)
            }

        case .left:
            // Move vertically along left edge
            if direction {
                return Position(x: window.minX, y: window.maxY - margin)
            } else {
                return Position(x: window.minX, y: window.minY + margin)
            }

        case .right:
            // Move vertically along right edge
            if direction {
                return Position(x: window.maxX, y: window.maxY - margin)
            } else {
                return Position(x: window.maxX, y: window.minY + margin)
            }
        }
    }

    private func climbAnimation(for edge: ScreenRect.WindowEdge, creature: Creature) -> Animation {
        // Try edge-specific climb animation first
        let edgeName: String
        switch edge {
        case .top: edgeName = "climb-top"
        case .bottom: edgeName = "climb-bottom"
        case .left: edgeName = "climb-left"
        case .right: edgeName = "climb-right"
        }

        if let anim = creature.animation(named: edgeName) {
            return anim
        }

        // Fall back to generic climb
        if let anim = creature.animation(named: "climb") {
            return anim
        }

        // Fall back to walk for horizontal, or idle
        if edge == .top || edge == .bottom {
            if let anim = creature.animation(named: "walk-right") {
                return anim
            }
        }

        // Final fallback to idle
        return creature.animation(named: "idle") ?? Animation(name: "idle", frameCount: 1, fps: 1)
    }
}

// MARK: - Personality Extension

extension Personality {
    /// Speed in pixels per second for climbing behavior
    var climbSpeed: Double {
        switch self {
        case .shy:
            return 40.0        // Very slow, cautious
        case .curious:
            return 70.0        // Moderate pace
        case .mischievous:
            return 100.0       // Quick
        case .chaotic:
            return 130.0       // Fast and erratic
        }
    }
}
