import Foundation
import Synchronization

/// Protocol for creature behaviors
public protocol Behavior: Sendable {
    /// The type of this behavior
    var type: BehaviorType { get }

    /// Required animations for this behavior
    var requiredAnimations: [String] { get }

    /// Initialize behavior state
    func start(context: BehaviorContext, random: RandomSource) -> BehaviorState

    /// Update behavior state, returns events generated
    func update(
        state: inout BehaviorState,
        context: BehaviorContext,
        deltaTime: TimeInterval
    ) -> [BehaviorEvent]

    /// Cancel behavior, transition to exit
    func cancel(state: inout BehaviorState) -> [BehaviorEvent]
}

// MARK: - Behavior Registry

/// Registry of available behaviors
public final class BehaviorRegistry: Sendable {
    public static let shared = BehaviorRegistry()

    private struct State: Sendable {
        var behaviors: [BehaviorType: any Behavior]
    }

    private let state: Mutex<State>

    private init() {
        // Build dictionary before initializing Mutex (can't call register before state is set)
        var dict: [BehaviorType: any Behavior] = [:]
        let defaults: [any Behavior] = [
            PeekBehavior(),
            TraverseBehavior(),
            StationaryBehavior(),
            ClimberBehavior(),
            FollowBehavior()
        ]
        for behavior in defaults {
            dict[behavior.type] = behavior
        }
        self.state = Mutex(State(behaviors: dict))
    }

    public func register(_ behavior: any Behavior) {
        state.withLock { $0.behaviors[behavior.type] = behavior }
    }

    public func behavior(for type: BehaviorType) -> (any Behavior)? {
        state.withLock { $0.behaviors[type] }
    }

    public func allBehaviors() -> [any Behavior] {
        state.withLock { Array($0.behaviors.values) }
    }

    public func availableBehaviors(for creature: Creature) -> [any Behavior] {
        allBehaviors().filter { behavior in
            behavior.requiredAnimations.allSatisfy { creature.animations[$0] != nil }
        }
    }
}
