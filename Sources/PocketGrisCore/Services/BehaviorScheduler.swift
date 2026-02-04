import Foundation

/// Schedules creature appearances at random intervals
public final class BehaviorScheduler: @unchecked Sendable {
    public typealias TriggerHandler = (Creature, BehaviorType) -> Void

    private var settings: Settings
    private var creatures: [Creature]
    private var timeSource: TimeSource
    private var random: RandomSource
    private var onTrigger: TriggerHandler?

    private var timer: DispatchSourceTimer?
    private var nextTriggerTime: TimeInterval = 0
    private var isRunning = false
    private let lock = NSLock()

    public init(
        settings: Settings = .default,
        creatures: [Creature] = [],
        timeSource: TimeSource = SystemTimeSource(),
        random: RandomSource = SystemRandomSource()
    ) {
        self.settings = settings
        self.creatures = creatures
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

    public func setTriggerHandler(_ handler: @escaping TriggerHandler) {
        lock.lock()
        defer { lock.unlock() }
        self.onTrigger = handler
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
        let selectedCreature = creature ?? selectRandomCreature()
        let selectedBehavior: BehaviorType?
        if let c = selectedCreature {
            selectedBehavior = behavior ?? selectRandomBehavior(for: c)
        } else {
            selectedBehavior = nil
        }
        lock.unlock()

        guard let c = selectedCreature, let b = selectedBehavior else { return }
        handler?(c, b)
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
        let creature = selectRandomCreature()
        let behavior = creature.flatMap { selectRandomBehavior(for: $0) }
        lock.unlock()

        if let c = creature, let b = behavior {
            handler?(c, b)
        }

        lock.lock()
        scheduleNextTrigger()
        lock.unlock()
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
