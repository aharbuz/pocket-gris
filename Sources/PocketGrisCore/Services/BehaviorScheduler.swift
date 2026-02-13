import Foundation
import Synchronization

/// What the scheduler decided to trigger
public enum SchedulerTrigger: Sendable {
    case behavior(Creature, BehaviorType)
    case scene(Scene)
}

/// Schedules creature appearances at random intervals
public final class BehaviorScheduler: Sendable {
    public typealias TriggerHandler = @Sendable (Creature, BehaviorType) -> Void
    public typealias UnifiedTriggerHandler = @Sendable (SchedulerTrigger) -> Void

    // DispatchSourceTimer and closures need @unchecked Sendable; they are safe behind Mutex
    private struct State: @unchecked Sendable {
        var settings: Settings
        var creatures: [Creature]
        var scenes: [Scene]
        var timeSource: any TimeSource
        var random: any RandomSource
        var onTrigger: TriggerHandler?
        var onUnifiedTrigger: UnifiedTriggerHandler?
        var timer: DispatchSourceTimer?
        var nextTriggerTime: TimeInterval = 0
        var isRunning = false
    }

    private let state: Mutex<State>

    public init(
        settings: Settings = .default,
        creatures: [Creature] = [],
        scenes: [Scene] = [],
        timeSource: TimeSource = SystemTimeSource(),
        random: RandomSource = SystemRandomSource()
    ) {
        self.state = Mutex(State(
            settings: settings,
            creatures: creatures,
            scenes: scenes,
            timeSource: timeSource,
            random: random
        ))
    }

    // MARK: - Configuration

    public func updateSettings(_ settings: Settings) {
        state.withLock { $0.settings = settings }
    }

    public func updateCreatures(_ creatures: [Creature]) {
        state.withLock { $0.creatures = creatures }
    }

    public func updateScenes(_ scenes: [Scene]) {
        state.withLock { $0.scenes = scenes }
    }

    public func setTriggerHandler(_ handler: @escaping TriggerHandler) {
        state.withLock { $0.onTrigger = handler }
    }

    public func setUnifiedTriggerHandler(_ handler: @escaping UnifiedTriggerHandler) {
        state.withLock { $0.onUnifiedTrigger = handler }
    }

    // MARK: - Control

    public func start() {
        state.withLock { s in
            guard !s.isRunning else { return }
            s.isRunning = true
            Self.scheduleNextTriggerImpl(state: &s, scheduler: self)
        }
    }

    public func stop() {
        state.withLock { s in
            s.isRunning = false
            s.timer?.cancel()
            s.timer = nil
        }
    }

    public func triggerNow(creature: Creature? = nil, behavior: BehaviorType? = nil) {
        let (handler, unifiedHandler, selectedCreature, selectedBehavior) = state.withLock { s -> (TriggerHandler?, UnifiedTriggerHandler?, Creature?, BehaviorType?) in
            let c = creature ?? Self.selectRandomCreatureImpl(state: &s)
            let b: BehaviorType?
            if let c = c {
                b = behavior ?? Self.selectRandomBehaviorImpl(for: c, state: &s)
            } else {
                b = nil
            }
            return (s.onTrigger, s.onUnifiedTrigger, c, b)
        }

        guard let c = selectedCreature, let b = selectedBehavior else { return }
        unifiedHandler?(.behavior(c, b))
        handler?(c, b)
    }

    public func triggerScene(_ scene: Scene) {
        let unifiedHandler = state.withLock { $0.onUnifiedTrigger }
        unifiedHandler?(.scene(scene))
    }

    // MARK: - Simulation

    /// Simulate scheduling for testing/preview
    public func simulate(duration: TimeInterval) -> [(time: TimeInterval, creature: String, behavior: BehaviorType)] {
        state.withLock { s in
            var results: [(TimeInterval, String, BehaviorType)] = []
            var elapsed: TimeInterval = 0

            while elapsed < duration {
                let interval = s.settings.randomInterval(using: s.random)
                elapsed += interval

                if elapsed < duration {
                    if let creature = Self.selectRandomCreatureImpl(state: &s),
                       let behavior = Self.selectRandomBehaviorImpl(for: creature, state: &s) {
                        results.append((elapsed, creature.id, behavior))
                    }
                }
            }

            return results
        }
    }

    // MARK: - Private Impl Variants

    private static func scheduleNextTriggerImpl(state s: inout State, scheduler: BehaviorScheduler) {
        guard s.isRunning else { return }

        let interval = s.settings.randomInterval(using: s.random)
        s.nextTriggerTime = s.timeSource.now + interval

        s.timer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak scheduler] in
            scheduler?.handleTrigger()
        }
        s.timer = timer
        timer.resume()
    }

    private func handleTrigger() {
        // First lock: read state, select trigger, get handlers
        let (handler, unifiedHandler, trigger) = state.withLock { s -> (TriggerHandler?, UnifiedTriggerHandler?, SchedulerTrigger?) in
            guard s.isRunning, s.settings.enabled else {
                return (nil, nil, nil)
            }
            let h = s.onTrigger
            let uh = s.onUnifiedTrigger
            let t = Self.selectRandomTriggerImpl(state: &s)
            return (h, uh, t)
        }

        // Call handlers outside lock
        if let trigger = trigger {
            unifiedHandler?(trigger)
            if case .behavior(let c, let b) = trigger {
                handler?(c, b)
            }
        }

        // Second lock: schedule next trigger
        state.withLock { s in
            Self.scheduleNextTriggerImpl(state: &s, scheduler: self)
        }
    }

    private static func selectRandomTriggerImpl(state s: inout State) -> SchedulerTrigger? {
        // Build weighted pool of behaviors and scenes
        var pool: [(SchedulerTrigger, Double)] = []

        // Add behavior triggers (only if behaviors are enabled)
        if s.settings.behaviorsEnabled, let creature = selectRandomCreatureImpl(state: &s) {
            let available = BehaviorRegistry.shared.availableBehaviors(for: creature)
            for behavior in available {
                let weight = s.settings.behaviorWeights[behavior.type.rawValue] ?? 1.0
                if weight > 0 {
                    pool.append((.behavior(creature, behavior.type), weight))
                }
            }
        }

        // Add scene triggers (only if scenes are enabled)
        if s.settings.scenesEnabled {
            let playableScenes = s.scenes.filter { $0.isPlayable }
            for scene in playableScenes {
                let weight = s.settings.sceneWeights[scene.id] ?? 1.0
                if weight > 0 {
                    pool.append((.scene(scene), weight))
                }
            }
        }

        guard !pool.isEmpty else { return nil }

        let totalWeight = pool.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0 else { return pool.first?.0 }

        let roll = s.random.double(in: 0...totalWeight)
        var cumulative = 0.0
        for (trigger, weight) in pool {
            cumulative += weight
            if roll < cumulative {
                return trigger
            }
        }

        // roll == totalWeight edge case: return last element
        return pool.last?.0
    }

    private static func selectRandomCreatureImpl(state s: inout State) -> Creature? {
        var pool = s.creatures

        // Filter by enabled creatures if specified
        if !s.settings.enabledCreatures.isEmpty {
            pool = pool.filter { s.settings.enabledCreatures.contains($0.id) }
        }

        guard !pool.isEmpty else { return nil }

        let index = s.random.int(in: 0..<pool.count)
        return pool[index]
    }

    private static func selectRandomBehaviorImpl(for creature: Creature, state s: inout State) -> BehaviorType? {
        let available = BehaviorRegistry.shared.availableBehaviors(for: creature)
        guard !available.isEmpty else { return nil }

        // Apply behavior weights
        let weighted: [(BehaviorType, Double)] = available.map { behavior in
            let weight = s.settings.behaviorWeights[behavior.type.rawValue] ?? 1.0
            return (behavior.type, weight)
        }

        let totalWeight = weighted.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0 else { return available.first?.type }

        let roll = s.random.double(in: 0...totalWeight)
        var cumulative = 0.0
        for (type, weight) in weighted {
            cumulative += weight
            if roll < cumulative {
                return type
            }
        }

        // roll == totalWeight edge case: return last element
        return weighted.last?.0
    }
}
