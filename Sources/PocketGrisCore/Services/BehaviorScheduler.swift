import Foundation

/// What the scheduler decided to trigger
public enum SchedulerTrigger: Sendable {
    case behavior(Creature, BehaviorType)
    case scene(Scene)
}

/// Schedules creature appearances at random intervals
public final class BehaviorScheduler: @unchecked Sendable {
    public typealias TriggerHandler = (Creature, BehaviorType) -> Void
    public typealias UnifiedTriggerHandler = (SchedulerTrigger) -> Void

    private var settings: Settings
    private var creatures: [Creature]
    private var scenes: [Scene]
    private var timeSource: TimeSource
    private var random: RandomSource
    private var onTrigger: TriggerHandler?
    private var onUnifiedTrigger: UnifiedTriggerHandler?

    private var timer: DispatchSourceTimer?
    private var nextTriggerTime: TimeInterval = 0
    private var isRunning = false
    private let lock = NSLock()

    public init(
        settings: Settings = .default,
        creatures: [Creature] = [],
        scenes: [Scene] = [],
        timeSource: TimeSource = SystemTimeSource(),
        random: RandomSource = SystemRandomSource()
    ) {
        self.settings = settings
        self.creatures = creatures
        self.scenes = scenes
        self.timeSource = timeSource
        self.random = random
    }

    // MARK: - Configuration

    public func updateSettings(_ settings: Settings) {
        lock.lock()
        defer { lock.unlock() }
        self.settings = settings
    }

    public func updateCreatures(_ creatures: [Creature]) {
        lock.lock()
        defer { lock.unlock() }
        self.creatures = creatures
    }

    public func updateScenes(_ scenes: [Scene]) {
        lock.lock()
        defer { lock.unlock() }
        self.scenes = scenes
    }

    public func setTriggerHandler(_ handler: @escaping TriggerHandler) {
        lock.lock()
        defer { lock.unlock() }
        self.onTrigger = handler
    }

    public func setUnifiedTriggerHandler(_ handler: @escaping UnifiedTriggerHandler) {
        lock.lock()
        defer { lock.unlock() }
        self.onUnifiedTrigger = handler
    }

    // MARK: - Control

    public func start() {
        lock.lock()
        defer { lock.unlock() }

        guard !isRunning else { return }
        isRunning = true
        scheduleNextTrigger()
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        isRunning = false
        timer?.cancel()
        timer = nil
    }

    public func triggerNow(creature: Creature? = nil, behavior: BehaviorType? = nil) {
        lock.lock()
        let handler = onTrigger
        let unifiedHandler = onUnifiedTrigger
        let selectedCreature = creature ?? selectRandomCreature()
        let selectedBehavior: BehaviorType?
        if let c = selectedCreature {
            selectedBehavior = behavior ?? selectRandomBehavior(for: c)
        } else {
            selectedBehavior = nil
        }
        lock.unlock()

        guard let c = selectedCreature, let b = selectedBehavior else { return }
        unifiedHandler?(.behavior(c, b))
        handler?(c, b)
    }

    public func triggerScene(_ scene: Scene) {
        lock.lock()
        let unifiedHandler = onUnifiedTrigger
        lock.unlock()

        unifiedHandler?(.scene(scene))
    }

    // MARK: - Simulation

    /// Simulate scheduling for testing/preview
    public func simulate(duration: TimeInterval) -> [(time: TimeInterval, creature: String, behavior: BehaviorType)] {
        var results: [(TimeInterval, String, BehaviorType)] = []
        var elapsed: TimeInterval = 0

        while elapsed < duration {
            let interval = settings.randomInterval(using: random)
            elapsed += interval

            if elapsed < duration {
                if let creature = selectRandomCreature(),
                   let behavior = selectRandomBehavior(for: creature) {
                    results.append((elapsed, creature.id, behavior))
                }
            }
        }

        return results
    }

    // MARK: - Private

    private func scheduleNextTrigger() {
        guard isRunning else { return }

        let interval = settings.randomInterval(using: random)
        nextTriggerTime = timeSource.now + interval

        timer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            self?.handleTrigger()
        }
        self.timer = timer
        timer.resume()
    }

    private func handleTrigger() {
        lock.lock()
        guard isRunning, settings.enabled else {
            lock.unlock()
            return
        }

        let handler = onTrigger
        let unifiedHandler = onUnifiedTrigger
        let trigger = selectRandomTrigger()
        lock.unlock()

        if let trigger = trigger {
            unifiedHandler?(trigger)
            // Also call legacy handler for behavior triggers
            if case .behavior(let c, let b) = trigger {
                handler?(c, b)
            }
        }

        lock.lock()
        scheduleNextTrigger()
        lock.unlock()
    }

    private func selectRandomTrigger() -> SchedulerTrigger? {
        // Build weighted pool of behaviors and scenes
        var pool: [(SchedulerTrigger, Double)] = []

        // Add behavior triggers
        if let creature = selectRandomCreature() {
            let available = BehaviorRegistry.shared.availableBehaviors(for: creature)
            for behavior in available {
                let weight = settings.behaviorWeights[behavior.type.rawValue] ?? 1.0
                if weight > 0 {
                    pool.append((.behavior(creature, behavior.type), weight))
                }
            }
        }

        // Add scene triggers (only if scenes are enabled)
        if settings.scenesEnabled {
            let playableScenes = scenes.filter { $0.isPlayable }
            for scene in playableScenes {
                let weight = settings.sceneWeights[scene.id] ?? 1.0
                if weight > 0 {
                    pool.append((.scene(scene), weight))
                }
            }
        }

        guard !pool.isEmpty else { return nil }

        let totalWeight = pool.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0 else { return pool.first?.0 }

        var roll = random.double(in: 0...totalWeight)
        for (trigger, weight) in pool {
            roll -= weight
            if roll <= 0 {
                return trigger
            }
        }

        return pool.first?.0
    }

    private func selectRandomCreature() -> Creature? {
        var pool = creatures

        // Filter by enabled creatures if specified
        if !settings.enabledCreatures.isEmpty {
            pool = pool.filter { settings.enabledCreatures.contains($0.id) }
        }

        guard !pool.isEmpty else { return nil }

        let index = random.int(in: 0..<pool.count)
        return pool[index]
    }

    private func selectRandomBehavior(for creature: Creature) -> BehaviorType? {
        let available = BehaviorRegistry.shared.availableBehaviors(for: creature)
        guard !available.isEmpty else { return nil }

        // Apply behavior weights
        let weighted: [(BehaviorType, Double)] = available.map { behavior in
            let weight = settings.behaviorWeights[behavior.type.rawValue] ?? 1.0
            return (behavior.type, weight)
        }

        let totalWeight = weighted.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0 else { return available.first?.type }

        var roll = random.double(in: 0...totalWeight)
        for (type, weight) in weighted {
            roll -= weight
            if roll <= 0 {
                return type
            }
        }

        return available.first?.type
    }
}
