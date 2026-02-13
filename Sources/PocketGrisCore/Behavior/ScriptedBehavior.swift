import Foundation

/// Behavior that plays back a single SceneTrack along waypoints
public struct ScriptedBehavior: Behavior {
    public let type = BehaviorType.scene
    public let requiredAnimations: [String]

    private let track: SceneTrack

    public init(track: SceneTrack) {
        self.track = track
        self.requiredAnimations = Array(Set(track.segments.map(\.animationName)))
    }

    public func start(context: BehaviorContext, random: RandomSource) -> BehaviorState {
        guard track.isValid else {
            return BehaviorState(phase: .complete)
        }

        let firstAnim = context.creature.animation(named: track.segments[0].animationName)

        let state = BehaviorState(
            phase: .enter,
            position: track.waypoints[0],
            animation: firstAnim.map { AnimationState(animation: $0) },
            startTime: context.currentTime,
            duration: totalDuration(),
            metadata: .scripted(ScriptedMetadata())
        )

        return state
    }

    public func update(
        state: inout BehaviorState,
        context: BehaviorContext,
        deltaTime: TimeInterval
    ) -> [BehaviorEvent] {
        var events: [BehaviorEvent] = []

        // Advance animation frames
        if state.animation?.advance(by: deltaTime) == true {
            events.append(.animationFrameChanged(state.animation!.currentFrame))
        }

        // Extract mutable metadata
        guard case .scripted(var meta) = state.metadata else {
            state.phase = .complete
            events.append(.completed)
            return events
        }

        switch state.phase {
        case .idle:
            break

        case .enter:
            meta.enterElapsed += deltaTime
            state.metadata = .scripted(meta)

            if meta.enterElapsed >= 0.2 {
                meta.segmentIndex = 0
                meta.segmentElapsed = 0
                state.metadata = .scripted(meta)
                state.phase = .perform
                events.append(.phaseChanged(.perform))
            }

        case .perform:
            let segmentIndex = meta.segmentIndex
            meta.segmentElapsed += deltaTime

            guard segmentIndex < track.segments.count else {
                // All segments done
                meta.exitElapsed = 0
                state.metadata = .scripted(meta)
                state.phase = .exit
                events.append(.phaseChanged(.exit))
                return events
            }

            let segment = track.segments[segmentIndex]

            // Check if current segment is done
            if meta.segmentElapsed >= segment.duration {
                let nextIndex = segmentIndex + 1
                if nextIndex < track.segments.count {
                    // Move to next segment
                    meta.segmentElapsed -= segment.duration
                    meta.segmentIndex = nextIndex
                    state.metadata = .scripted(meta)

                    // Switch animation if different
                    let nextSegment = track.segments[nextIndex]
                    if nextSegment.animationName != segment.animationName {
                        if let anim = context.creature.animation(named: nextSegment.animationName) {
                            state.animation = AnimationState(animation: anim)
                            events.append(.animationFrameChanged(0))
                        }
                    }

                    // Interpolate position in the new segment
                    let pos = interpolatePosition(
                        segmentIndex: nextIndex,
                        progress: min(meta.segmentElapsed / nextSegment.duration, 1.0),
                        context: context
                    )
                    state.position = pos
                    events.append(.positionChanged(pos))
                } else {
                    // Final waypoint reached
                    state.position = track.waypoints[track.waypoints.count - 1]
                    events.append(.positionChanged(state.position))
                    meta.exitElapsed = 0
                    state.metadata = .scripted(meta)
                    state.phase = .exit
                    events.append(.phaseChanged(.exit))
                }
            } else {
                state.metadata = .scripted(meta)

                // Interpolate position along current segment
                let progress = meta.segmentElapsed / segment.duration
                let pos = interpolatePosition(
                    segmentIndex: segmentIndex,
                    progress: min(progress, 1.0),
                    context: context
                )
                state.position = pos
                events.append(.positionChanged(pos))
            }

        case .exit:
            meta.exitElapsed += deltaTime
            state.metadata = .scripted(meta)

            if meta.exitElapsed >= 0.2 {
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

    // MARK: - Private

    private func totalDuration() -> TimeInterval {
        track.segments.reduce(0) { $0 + $1.duration } + 0.4  // + enter/exit
    }

    private func interpolatePosition(segmentIndex: Int, progress: Double, context: BehaviorContext) -> Position {
        let from = track.waypoints[segmentIndex]
        let to = track.waypoints[segmentIndex + 1]
        let t = max(0, min(1, progress))

        var pos = Position(
            x: from.x + (to.x - from.x) * t,
            y: from.y + (to.y - from.y) * t
        )

        // Apply snap mode
        let segment = track.segments[segmentIndex]
        pos = applySnapMode(segment.snapMode, to: pos, context: context)

        return pos
    }

    private func applySnapMode(_ mode: SnapMode, to position: Position, context: BehaviorContext) -> Position {
        switch mode {
        case .none:
            return position

        case .screenBottom:
            return Position(x: position.x, y: context.screenBounds.maxY)

        case .screenTop:
            return Position(x: position.x, y: context.screenBounds.minY)

        case .windowTop:
            if let window = nearestWindow(to: position, context: context) {
                return Position(x: position.x, y: window.minY)
            }
            return position

        case .windowBottom:
            if let window = nearestWindow(to: position, context: context) {
                return Position(x: position.x, y: window.maxY)
            }
            return position

        case .windowLeft:
            if let window = nearestWindow(to: position, context: context) {
                return Position(x: window.minX, y: position.y)
            }
            return position

        case .windowRight:
            if let window = nearestWindow(to: position, context: context) {
                return Position(x: window.maxX, y: position.y)
            }
            return position
        }
    }

    private func nearestWindow(to position: Position, context: BehaviorContext) -> ScreenRect? {
        context.windowFrames.min(by: {
            position.distance(to: $0.center) < position.distance(to: $1.center)
        })
    }
}
