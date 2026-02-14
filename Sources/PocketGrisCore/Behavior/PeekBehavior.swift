import Foundation

/// Peek behavior: appear at edge, peek, retreat
public struct PeekBehavior: Behavior {
    public let type = BehaviorType.peek
    public let requiredAnimations = ["peek-left", "retreat-left"]

    public init() {}

    public func start(context: BehaviorContext, random: RandomSource) -> BehaviorState {
        // Pick a random edge
        let edges: [ScreenEdge] = [.left, .right, .top, .bottom]
        let edge = edges[random.int(in: 0..<edges.count)]

        // Calculate position at edge
        let position = calculateEdgePosition(edge: edge, bounds: context.screenBounds, random: random)

        // Get peek duration from personality
        let duration = random.double(in: context.creature.personality.peekDurationRange)

        // Get animation (try directional first)
        let animName = animationName(for: edge, action: "peek")
        let anim = context.creature.animation(named: animName)
            ?? context.creature.animation(named: "peek-left")

        var state = BehaviorState(
            phase: .enter,
            position: position,
            animation: anim.map { AnimationState(animation: $0) },
            edge: edge,
            startTime: context.currentTime,
            duration: duration
        )
        state.metadata = .peek(PeekMetadata(peekDuration: duration))

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
            // Enter phase complete when animation finishes or after brief delay
            if state.animation?.isComplete == true || elapsed > 0.5 {
                state.phase = .perform
                events.append(.phaseChanged(.perform))
                state.startTime = context.currentTime

                // Check for cursor proximity - might flee
                if let cursor = context.cursorPosition {
                    let distance = state.position.distance(to: cursor)
                    if distance < 100 && context.creature.personality.cursorSensitivity > 0.5 {
                        // Skip to exit
                        state.phase = .exit
                        events.append(.phaseChanged(.exit))
                        state.startTime = context.currentTime
                        transitionToRetreat(state: &state, context: context)
                    }
                }
            }

        case .perform:
            // Wait for peek duration
            let peekDuration: Double
            if case .peek(let meta) = state.metadata {
                peekDuration = meta.peekDuration
            } else {
                peekDuration = 3.0
            }
            if elapsed >= peekDuration {
                state.phase = .exit
                events.append(.phaseChanged(.exit))
                state.startTime = context.currentTime
                transitionToRetreat(state: &state, context: context)
            }

            // Check cursor - might flee early (only if still performing)
            if state.phase == .perform, let cursor = context.cursorPosition {
                let distance = state.position.distance(to: cursor)
                let fleeThreshold = 80.0 * (1.0 - context.creature.personality.cursorSensitivity)
                if distance < fleeThreshold {
                    state.phase = .exit
                    events.append(.phaseChanged(.exit))
                    state.startTime = context.currentTime
                    transitionToRetreat(state: &state, context: context)
                }
            }

        case .exit:
            // Exit complete when retreat animation finishes
            if state.animation?.isComplete == true || elapsed > 1.0 {
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

    private func calculateEdgePosition(edge: ScreenEdge, bounds: ScreenRect, random: RandomSource) -> Position {
        switch edge {
        case .left:
            let y = random.double(in: bounds.minY + 50...bounds.maxY - 50)
            return Position(x: bounds.minX, y: y)
        case .right:
            let y = random.double(in: bounds.minY + 50...bounds.maxY - 50)
            return Position(x: bounds.maxX, y: y)
        case .top:
            let x = random.double(in: bounds.minX + 50...bounds.maxX - 50)
            return Position(x: x, y: bounds.minY)
        case .bottom:
            let x = random.double(in: bounds.minX + 50...bounds.maxX - 50)
            return Position(x: x, y: bounds.maxY)
        }
    }

    private func animationName(for edge: ScreenEdge, action: String) -> String {
        switch edge {
        case .left: return "\(action)-left"
        case .right: return "\(action)-right"
        case .top: return "\(action)-top"
        case .bottom: return "\(action)-bottom"
        }
    }

    private func transitionToRetreat(state: inout BehaviorState, context: BehaviorContext) {
        guard let edge = state.edge else { return }
        let animName = animationName(for: edge, action: "retreat")
        if let anim = context.creature.animation(named: animName)
            ?? context.creature.animation(named: "retreat-left") {
            state.animation = AnimationState(animation: anim)
        }
    }
}
