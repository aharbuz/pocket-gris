import Foundation

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
public final class BehaviorRegistry: @unchecked Sendable {
    public static let shared = BehaviorRegistry()

    private var behaviors: [BehaviorType: any Behavior] = [:]
    private let lock = NSLock()

    private init() {
        // Register default behaviors
        register(PeekBehavior())
        register(TraverseBehavior())
        register(StationaryBehavior())
        register(ClimberBehavior())
    }

    public func register(_ behavior: any Behavior) {
        lock.lock()
        defer { lock.unlock() }
        behaviors[behavior.type] = behavior
    }

    public func behavior(for type: BehaviorType) -> (any Behavior)? {
        lock.lock()
        defer { lock.unlock() }
        return behaviors[type]
    }

    public func allBehaviors() -> [any Behavior] {
        lock.lock()
        defer { lock.unlock() }
        return Array(behaviors.values)
    }

    public func availableBehaviors(for creature: Creature) -> [any Behavior] {
        allBehaviors().filter { behavior in
            behavior.requiredAnimations.allSatisfy { creature.animations[$0] != nil }
        }
    }
}
