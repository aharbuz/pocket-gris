import XCTest
@testable import PocketGrisCore

final class BehaviorTests: XCTestCase {

    var testCreature: Creature!
    var testContext: BehaviorContext!

    override func setUp() {
        testCreature = Creature(
            id: "test",
            name: "Test Creature",
            personality: .curious,
            animations: [
                "peek-left": Animation(name: "peek-left", frameCount: 10, fps: 10),
                "peek-right": Animation(name: "peek-right", frameCount: 10, fps: 10),
                "retreat-left": Animation(name: "retreat-left", frameCount: 8, fps: 10),
                "retreat-right": Animation(name: "retreat-right", frameCount: 8, fps: 10)
            ]
        )

        testContext = BehaviorContext(
            creature: testCreature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0
        )
    }

    func testPeekBehaviorStart() {
        let behavior = PeekBehavior()
        let random = FixedRandomSource(ints: [0], doubles: [0.5])

        let state = behavior.start(context: testContext, random: random)

        XCTAssertEqual(state.phase, .enter)
        XCTAssertNotNil(state.edge)
        XCTAssertNotNil(state.animation)
    }

    func testPeekBehaviorPhaseTransitions() {
        let behavior = PeekBehavior()
        // Use 0.0 for doubles to get minimum peek duration (3.0s for curious)
        let random = FixedRandomSource(ints: [0], doubles: [0.0])

        var state = behavior.start(context: testContext, random: random)
        XCTAssertEqual(state.phase, .enter)

        // Advance through enter phase
        var context = BehaviorContext(
            creature: testCreature,
            screenBounds: testContext.screenBounds,
            currentTime: 0.6  // Past enter threshold
        )
        var events = behavior.update(state: &state, context: context, deltaTime: 0.6)

        XCTAssertEqual(state.phase, .perform)
        XCTAssertTrue(events.contains(.phaseChanged(.perform)))

        // Note: startTime was reset to 0.6 when entering perform phase
        // Curious personality min peek duration is 3.0s, so need currentTime >= 0.6 + 3.0 = 3.6
        context = BehaviorContext(
            creature: testCreature,
            screenBounds: testContext.screenBounds,
            currentTime: 4.0  // Past peek duration (0.6 + 3.0)
        )
        events = behavior.update(state: &state, context: context, deltaTime: 3.4)

        XCTAssertEqual(state.phase, .exit)

        // Complete exit - startTime was reset again, need elapsed > 1.0
        context = BehaviorContext(
            creature: testCreature,
            screenBounds: testContext.screenBounds,
            currentTime: 5.5
        )
        events = behavior.update(state: &state, context: context, deltaTime: 1.5)

        XCTAssertEqual(state.phase, .complete)
        XCTAssertTrue(events.contains(.completed))
    }

    func testPeekBehaviorCancel() {
        let behavior = PeekBehavior()
        let random = FixedRandomSource(ints: [0], doubles: [0.5])

        var state = behavior.start(context: testContext, random: random)
        let events = behavior.cancel(state: &state)

        XCTAssertEqual(state.phase, .complete)
        XCTAssertTrue(events.contains(.cancelled))
    }

    func testBehaviorRegistry() {
        let registry = BehaviorRegistry.shared

        // Peek should be registered by default
        let peek = registry.behavior(for: .peek)
        XCTAssertNotNil(peek)
        XCTAssertEqual(peek?.type, .peek)

        // Get available behaviors for creature
        let available = registry.availableBehaviors(for: testCreature)
        XCTAssertFalse(available.isEmpty)
    }

    func testBehaviorRegistryFiltersUnavailable() {
        // Creature without required animations
        let limitedCreature = Creature(
            id: "limited",
            name: "Limited",
            personality: .shy,
            animations: [:] // No animations
        )

        let registry = BehaviorRegistry.shared
        let available = registry.availableBehaviors(for: limitedCreature)

        XCTAssertTrue(available.isEmpty)
    }
}
