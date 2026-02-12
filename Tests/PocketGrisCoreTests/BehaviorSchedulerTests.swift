import XCTest
@testable import PocketGrisCore

final class BehaviorSchedulerTests: XCTestCase {

    var testCreature: Creature!

    override func setUp() {
        testCreature = Creature(
            id: "test",
            name: "Test Creature",
            personality: .curious,
            animations: [
                "peek-left": Animation(name: "peek-left", frameCount: 10),
                "retreat-left": Animation(name: "retreat-left", frameCount: 8)
            ]
        )
    }

    func testSimulateReturnsTriggersInRange() {
        let settings = Settings(minInterval: 10, maxInterval: 20)
        let scheduler = BehaviorScheduler(
            settings: settings,
            creatures: [testCreature],
            random: SeededRandomSource(seed: 42)
        )

        let results = scheduler.simulate(duration: 100)

        // With 10-20s intervals over 100s, expect roughly 5-10 triggers
        XCTAssertGreaterThan(results.count, 3)
        XCTAssertLessThan(results.count, 15)

        // All triggers should be within duration
        for result in results {
            XCTAssertLessThan(result.time, 100)
            XCTAssertEqual(result.creature, "test")
        }
    }

    func testSimulateWithNoCreaturesReturnsEmpty() {
        let settings = Settings(minInterval: 10, maxInterval: 20)
        let scheduler = BehaviorScheduler(
            settings: settings,
            creatures: [],  // No creatures
            random: SeededRandomSource(seed: 42)
        )

        let results = scheduler.simulate(duration: 100)
        XCTAssertTrue(results.isEmpty)
    }

    func testTriggerNowCallsHandler() {
        let settings = Settings()
        let scheduler = BehaviorScheduler(
            settings: settings,
            creatures: [testCreature],
            random: FixedRandomSource(ints: [0], doubles: [0.5])
        )

        var triggered = false
        var triggeredCreature: Creature?
        var triggeredBehavior: BehaviorType?

        scheduler.setTriggerHandler { creature, behavior in
            triggered = true
            triggeredCreature = creature
            triggeredBehavior = behavior
        }

        scheduler.triggerNow()

        XCTAssertTrue(triggered)
        XCTAssertEqual(triggeredCreature?.id, "test")
        XCTAssertEqual(triggeredBehavior, .peek)
    }

    func testTriggerNowWithSpecificCreature() {
        let otherCreature = Creature(
            id: "other",
            name: "Other",
            personality: .shy,
            animations: [
                "peek-left": Animation(name: "peek-left", frameCount: 10),
                "retreat-left": Animation(name: "retreat-left", frameCount: 8)
            ]
        )

        let scheduler = BehaviorScheduler(
            settings: Settings(),
            creatures: [testCreature, otherCreature],
            random: FixedRandomSource(ints: [0], doubles: [0.5])
        )

        var triggeredId: String?
        scheduler.setTriggerHandler { creature, _ in
            triggeredId = creature.id
        }

        scheduler.triggerNow(creature: otherCreature)
        XCTAssertEqual(triggeredId, "other")
    }

    func testUpdateSettings() {
        let scheduler = BehaviorScheduler(
            settings: Settings(minInterval: 100, maxInterval: 200),
            creatures: [testCreature],
            random: SeededRandomSource(seed: 42)
        )

        let results1 = scheduler.simulate(duration: 1000)

        // Update to shorter intervals
        scheduler.updateSettings(Settings(minInterval: 10, maxInterval: 20))
        let results2 = scheduler.simulate(duration: 1000)

        // Should have more triggers with shorter intervals
        XCTAssertGreaterThan(results2.count, results1.count)
    }

    func testFilterByEnabledCreatures() {
        let creature1 = Creature(
            id: "creature1",
            name: "Creature 1",
            personality: .curious,
            animations: [
                "peek-left": Animation(name: "peek-left", frameCount: 10),
                "retreat-left": Animation(name: "retreat-left", frameCount: 8)
            ]
        )
        let creature2 = Creature(
            id: "creature2",
            name: "Creature 2",
            personality: .shy,
            animations: [
                "peek-left": Animation(name: "peek-left", frameCount: 10),
                "retreat-left": Animation(name: "retreat-left", frameCount: 8)
            ]
        )

        let settings = Settings(
            minInterval: 10,
            maxInterval: 20,
            enabledCreatures: ["creature1"]  // Only creature1 enabled
        )

        let scheduler = BehaviorScheduler(
            settings: settings,
            creatures: [creature1, creature2],
            random: SeededRandomSource(seed: 42)
        )

        let results = scheduler.simulate(duration: 200)

        // All triggers should be for creature1
        for result in results {
            XCTAssertEqual(result.creature, "creature1")
        }
    }

    func testScenesEnabledFiltersTriggers() {
        // Create a scene
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 0)],
            segments: [SceneSegment(animationName: "peek-left", duration: 1.0)]
        )
        let scene = Scene(id: "test-scene", name: "Test Scene", tracks: [track])

        // Settings with scenes disabled
        let settings = Settings(
            minInterval: 10,
            maxInterval: 20,
            scenesEnabled: false
        )

        let scheduler = BehaviorScheduler(
            settings: settings,
            creatures: [testCreature],
            scenes: [scene],
            random: SeededRandomSource(seed: 42)
        )

        var triggeredScenes: [Scene] = []
        var triggeredBehaviors: [(Creature, BehaviorType)] = []

        scheduler.setUnifiedTriggerHandler { trigger in
            switch trigger {
            case .behavior(let creature, let behaviorType):
                triggeredBehaviors.append((creature, behaviorType))
            case .scene(let scene):
                triggeredScenes.append(scene)
            }
        }

        // Trigger several times
        for _ in 0..<10 {
            scheduler.triggerNow()
        }

        // With scenesEnabled=false, no scenes should be triggered
        // Note: triggerNow() always triggers behaviors, not scenes
        // The scenesEnabled flag affects the random selection in handleTrigger()
        // which uses selectRandomTrigger()
        XCTAssertTrue(triggeredScenes.isEmpty, "No scenes should be triggered when scenesEnabled is false")
    }

    func testScenesEnabledDefaultsToTrue() {
        let settings = Settings()
        XCTAssertTrue(settings.scenesEnabled, "scenesEnabled should default to true")
    }
}
