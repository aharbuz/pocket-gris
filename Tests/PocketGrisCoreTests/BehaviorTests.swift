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

    func testPeekBehaviorNoDuplicatePhaseChangedEvents() {
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
        _ = behavior.update(state: &state, context: context, deltaTime: 0.6)
        XCTAssertEqual(state.phase, .perform)

        // Now set up the scenario that triggers the bug:
        // Peek duration expired AND cursor within flee threshold simultaneously.
        // Curious cursorSensitivity = 0.3, fleeThreshold = 80 * (1 - 0.3) = 56 pixels.
        // Place cursor within 56 pixels of creature position.
        // startTime was reset to 0.6, peek duration is 3.0, so need currentTime >= 3.6
        context = BehaviorContext(
            creature: testCreature,
            screenBounds: testContext.screenBounds,
            currentTime: 4.0,
            cursorPosition: Position(x: state.position.x + 30, y: state.position.y)
        )
        let events = behavior.update(state: &state, context: context, deltaTime: 3.4)

        XCTAssertEqual(state.phase, .exit)

        // Count .phaseChanged(.exit) events - should be exactly 1, not 2
        let exitPhaseEvents = events.filter { $0 == .phaseChanged(.exit) }
        XCTAssertEqual(exitPhaseEvents.count, 1, "Should emit exactly one .phaseChanged(.exit), not duplicate")
    }

    func testPeekBehaviorFullLifecycleNoDuplicatePhaseEvents() {
        let behavior = PeekBehavior()
        // Use 0.0 for doubles to get minimum peek duration (3.0s for curious)
        let random = FixedRandomSource(ints: [0], doubles: [0.0])

        var state = behavior.start(context: testContext, random: random)
        var allEvents: [BehaviorEvent] = []

        // Step through full lifecycle collecting all events
        // 1. Enter -> Perform
        var context = BehaviorContext(
            creature: testCreature,
            screenBounds: testContext.screenBounds,
            currentTime: 0.6
        )
        allEvents += behavior.update(state: &state, context: context, deltaTime: 0.6)

        // 2. Perform -> Exit (wait for peek duration)
        context = BehaviorContext(
            creature: testCreature,
            screenBounds: testContext.screenBounds,
            currentTime: 4.0
        )
        allEvents += behavior.update(state: &state, context: context, deltaTime: 3.4)

        // 3. Exit -> Complete
        context = BehaviorContext(
            creature: testCreature,
            screenBounds: testContext.screenBounds,
            currentTime: 5.5
        )
        allEvents += behavior.update(state: &state, context: context, deltaTime: 1.5)

        XCTAssertEqual(state.phase, .complete)

        // Verify exactly one .phaseChanged event per phase transition
        let phaseChangedEvents = allEvents.filter {
            if case .phaseChanged = $0 { return true }
            return false
        }

        // Should be exactly 3: .perform, .exit, .complete
        XCTAssertEqual(phaseChangedEvents.count, 3,
            "Expected exactly 3 phase transitions (perform, exit, complete), got \(phaseChangedEvents)")
        XCTAssertEqual(phaseChangedEvents[0], .phaseChanged(.perform))
        XCTAssertEqual(phaseChangedEvents[1], .phaseChanged(.exit))
        XCTAssertEqual(phaseChangedEvents[2], .phaseChanged(.complete))
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

    // MARK: - Traverse Behavior Tests

    func testTraverseBehaviorStart() {
        let behavior = TraverseBehavior()
        let creature = makeTraverseCreature()
        let context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0
        )
        // Random: bool=true (start left), double for Y position
        let random = FixedRandomSource(ints: [], doubles: [0.5], bools: [true])

        let state = behavior.start(context: context, random: random)

        XCTAssertEqual(state.phase, .enter)
        XCTAssertNotNil(state.edge)
        XCTAssertNotNil(state.animation)
        XCTAssertNotNil(state.metadata["startX"])
        XCTAssertNotNil(state.metadata["endX"])
    }

    func testTraverseBehaviorPhaseTransitions() {
        let behavior = TraverseBehavior()
        let creature = makeTraverseCreature()
        var context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0
        )
        let random = FixedRandomSource(ints: [], doubles: [0.5], bools: [true])

        var state = behavior.start(context: context, random: random)
        XCTAssertEqual(state.phase, .enter)

        // Move past enter phase
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.2
        )
        var events = behavior.update(state: &state, context: context, deltaTime: 0.2)

        XCTAssertEqual(state.phase, .perform)
        XCTAssertTrue(events.contains(.phaseChanged(.perform)))
    }

    func testTraverseBehaviorCancel() {
        let behavior = TraverseBehavior()
        let creature = makeTraverseCreature()
        let context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0
        )
        let random = FixedRandomSource(ints: [], doubles: [0.5], bools: [true])

        var state = behavior.start(context: context, random: random)
        let events = behavior.cancel(state: &state)

        XCTAssertEqual(state.phase, .complete)
        XCTAssertTrue(events.contains(.cancelled))
    }

    func testTraverseBehaviorMovement() {
        let behavior = TraverseBehavior()
        let creature = makeTraverseCreature()
        let bounds = ScreenRect(x: 0, y: 0, width: 1920, height: 1080)
        var context = BehaviorContext(
            creature: creature,
            screenBounds: bounds,
            currentTime: 0
        )
        // Start from left edge
        let random = FixedRandomSource(ints: [], doubles: [0.5], bools: [true])

        var state = behavior.start(context: context, random: random)
        let initialPosition = state.position

        // Move to perform phase
        context = BehaviorContext(creature: creature, screenBounds: bounds, currentTime: 0.2)
        _ = behavior.update(state: &state, context: context, deltaTime: 0.2)

        // Simulate movement over time
        context = BehaviorContext(creature: creature, screenBounds: bounds, currentTime: 1.2)
        let events = behavior.update(state: &state, context: context, deltaTime: 1.0)

        // Should have moved from initial position
        XCTAssertNotEqual(state.position, initialPosition)
        XCTAssertTrue(events.contains(where: {
            if case .positionChanged = $0 { return true }
            return false
        }))
    }

    // MARK: - Stationary Behavior Tests

    func testStationaryBehaviorStart() {
        let behavior = StationaryBehavior()
        let creature = makeStationaryCreature()
        let context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0
        )
        // Random: int for edge (0=left), double for position, double for duration
        let random = FixedRandomSource(ints: [0], doubles: [0.5, 0.0])

        let state = behavior.start(context: context, random: random)

        XCTAssertEqual(state.phase, .enter)
        XCTAssertNotNil(state.edge)
        XCTAssertNotNil(state.animation)
        XCTAssertEqual(state.edge, .left)
    }

    func testStationaryBehaviorPhaseTransitions() {
        let behavior = StationaryBehavior()
        let creature = makeStationaryCreature()
        var context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0
        )
        let random = FixedRandomSource(ints: [0], doubles: [0.5, 0.0])  // 0.0 = min duration (4.0s for curious)

        var state = behavior.start(context: context, random: random)
        XCTAssertEqual(state.phase, .enter)

        // Move past enter phase (0.5s)
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.6
        )
        var events = behavior.update(state: &state, context: context, deltaTime: 0.6)

        XCTAssertEqual(state.phase, .perform)
        XCTAssertTrue(events.contains(.phaseChanged(.perform)))

        // Wait for stationary duration (min 4.0s for curious)
        // startTime was reset to 0.6 when entering perform, need elapsed >= 4.0
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 5.0
        )
        events = behavior.update(state: &state, context: context, deltaTime: 4.4)

        XCTAssertEqual(state.phase, .exit)
        XCTAssertTrue(events.contains(.phaseChanged(.exit)))

        // Complete exit (0.6s)
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 5.7
        )
        events = behavior.update(state: &state, context: context, deltaTime: 0.7)

        XCTAssertEqual(state.phase, .complete)
        XCTAssertTrue(events.contains(.completed))
    }

    func testStationaryBehaviorCancel() {
        let behavior = StationaryBehavior()
        let creature = makeStationaryCreature()
        let context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0
        )
        let random = FixedRandomSource(ints: [0], doubles: [0.5, 0.5])

        var state = behavior.start(context: context, random: random)
        let events = behavior.cancel(state: &state)

        XCTAssertEqual(state.phase, .complete)
        XCTAssertTrue(events.contains(.cancelled))
    }

    func testStationaryBehaviorCursorFlee() {
        let behavior = StationaryBehavior()
        // Use curious personality - cursorSensitivity 0.3
        // fleeThreshold = 100 * (1 - 0.3) = 70 pixels
        let creature = Creature(
            id: "cursor-test",
            name: "Cursor Test",
            personality: .curious,
            animations: ["idle": Animation(name: "idle", frameCount: 8, fps: 6)]
        )
        var context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0
        )
        let random = FixedRandomSource(ints: [0], doubles: [0.5, 0.0])

        var state = behavior.start(context: context, random: random)

        // Move to perform phase
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.6
        )
        _ = behavior.update(state: &state, context: context, deltaTime: 0.6)
        XCTAssertEqual(state.phase, .perform)

        // Cursor approaches within flee threshold (< 70 pixels for curious)
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.7,
            cursorPosition: Position(x: state.position.x + 30, y: state.position.y)
        )
        let events = behavior.update(state: &state, context: context, deltaTime: 0.1)

        // Should flee to exit
        XCTAssertEqual(state.phase, .exit)
        XCTAssertTrue(events.contains(.phaseChanged(.exit)))
    }

    // MARK: - Registry Tests for New Behaviors

    func testBehaviorRegistryIncludesTraverse() {
        let registry = BehaviorRegistry.shared
        let traverse = registry.behavior(for: .traverse)
        XCTAssertNotNil(traverse)
        XCTAssertEqual(traverse?.type, .traverse)
    }

    func testBehaviorRegistryIncludesStationary() {
        let registry = BehaviorRegistry.shared
        let stationary = registry.behavior(for: .stationary)
        XCTAssertNotNil(stationary)
        XCTAssertEqual(stationary?.type, .stationary)
    }

    func testBehaviorRegistryIncludesClimber() {
        let registry = BehaviorRegistry.shared
        let climber = registry.behavior(for: .climber)
        XCTAssertNotNil(climber)
        XCTAssertEqual(climber?.type, .climber)
    }

    // MARK: - Climber Behavior Tests

    func testClimberBehaviorStart() {
        let behavior = ClimberBehavior()
        let creature = makeClimberCreature()
        let windowFrames = [ScreenRect(x: 100, y: 100, width: 800, height: 600, windowID: 42)]
        let context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            windowFrames: windowFrames
        )
        // Random: int for window (0), int for edge (0=top), bool for direction, double for position
        let random = FixedRandomSource(ints: [0, 0], doubles: [0.5], bools: [true])

        let state = behavior.start(context: context, random: random)

        XCTAssertEqual(state.phase, .enter)
        XCTAssertNotNil(state.animation)
        XCTAssertEqual(state.metadata["windowID"], "42")
        XCTAssertNotNil(state.metadata["windowEdge"])
    }

    func testClimberBehaviorFallbackWithNoWindows() {
        let behavior = ClimberBehavior()
        let creature = makeClimberCreature()
        // No windows in context
        let context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            windowFrames: []
        )
        let random = FixedRandomSource(ints: [0], doubles: [0.5], bools: [true])

        let state = behavior.start(context: context, random: random)

        // Should still start but with fallback position
        XCTAssertEqual(state.phase, .enter)
        XCTAssertNotNil(state.animation)
    }

    func testClimberBehaviorPhaseTransitions() {
        let behavior = ClimberBehavior()
        let creature = makeClimberCreature()
        let windowFrames = [ScreenRect(x: 100, y: 100, width: 800, height: 600, windowID: 10)]
        var context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            windowFrames: windowFrames
        )
        let random = FixedRandomSource(ints: [0, 0], doubles: [0.5], bools: [true])

        var state = behavior.start(context: context, random: random)
        XCTAssertEqual(state.phase, .enter)

        // Move past enter phase (0.2s)
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.3,
            windowFrames: windowFrames
        )
        let events = behavior.update(state: &state, context: context, deltaTime: 0.3)

        XCTAssertEqual(state.phase, .perform)
        XCTAssertTrue(events.contains(.phaseChanged(.perform)))
    }

    func testClimberBehaviorCancel() {
        let behavior = ClimberBehavior()
        let creature = makeClimberCreature()
        let windowFrames = [ScreenRect(x: 100, y: 100, width: 800, height: 600, windowID: 10)]
        let context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            windowFrames: windowFrames
        )
        let random = FixedRandomSource(ints: [0, 0], doubles: [0.5], bools: [true])

        var state = behavior.start(context: context, random: random)
        let events = behavior.cancel(state: &state)

        XCTAssertEqual(state.phase, .complete)
        XCTAssertTrue(events.contains(.cancelled))
    }

    func testClimberBehaviorFollowsWindowMovement() {
        let behavior = ClimberBehavior()
        let creature = makeClimberCreature()
        var windowFrames = [ScreenRect(x: 100, y: 100, width: 800, height: 600, windowID: 101)]
        var context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            windowFrames: windowFrames
        )
        // Random: int for window (0), int for edge (0=top), bool for direction, double for position
        let random = FixedRandomSource(ints: [0, 0], doubles: [0.5], bools: [true])

        var state = behavior.start(context: context, random: random)

        // Move to perform phase
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.3,
            windowFrames: windowFrames
        )
        _ = behavior.update(state: &state, context: context, deltaTime: 0.3)
        XCTAssertEqual(state.phase, .perform)

        let positionBeforeMove = state.position

        // Now move the window by 200px to the right and 50px down (same windowID)
        windowFrames = [ScreenRect(x: 300, y: 150, width: 800, height: 600, windowID: 101)]
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.4,
            windowFrames: windowFrames
        )
        _ = behavior.update(state: &state, context: context, deltaTime: 0.1)

        // Creature should have moved with the window
        let positionAfterMove = state.position
        let deltaX = positionAfterMove.x - positionBeforeMove.x
        let deltaY = positionAfterMove.y - positionBeforeMove.y

        // The delta should include window movement (200, 50) plus some progress along the edge
        XCTAssertGreaterThan(deltaX, 100, "Creature should follow window horizontally")
        XCTAssertGreaterThan(deltaY, 40, "Creature should follow window vertically")
    }

    func testClimberBehaviorHandlesWindowClose() {
        let behavior = ClimberBehavior()
        let creature = makeClimberCreature()
        var windowFrames = [ScreenRect(x: 100, y: 100, width: 800, height: 600, windowID: 55)]
        var context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            windowFrames: windowFrames
        )
        let random = FixedRandomSource(ints: [0, 0], doubles: [0.5], bools: [true])

        var state = behavior.start(context: context, random: random)

        // Move to perform phase
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.3,
            windowFrames: windowFrames
        )
        _ = behavior.update(state: &state, context: context, deltaTime: 0.3)
        XCTAssertEqual(state.phase, .perform)

        // Now close the window (empty window list)
        windowFrames = []
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.4,
            windowFrames: windowFrames
        )
        let events = behavior.update(state: &state, context: context, deltaTime: 0.1)

        // Should gracefully exit when tracked window disappears
        XCTAssertEqual(state.phase, .exit)
        XCTAssertTrue(events.contains(.phaseChanged(.exit)))
    }

    func testClimberBehaviorCursorFlee() {
        let behavior = ClimberBehavior()
        // Use shy personality for higher cursor sensitivity (0.9)
        // fleeThreshold = 100.0 * 0.9 = 90 pixels
        let creature = Creature(
            id: "shy-climber",
            name: "Shy Climber",
            personality: .shy,
            animations: [
                "climb": Animation(name: "climb", frameCount: 8, fps: 10),
                "idle": Animation(name: "idle", frameCount: 8, fps: 6)
            ]
        )
        let windowFrames = [ScreenRect(x: 100, y: 100, width: 800, height: 600, windowID: 20)]
        var context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            windowFrames: windowFrames
        )
        let random = FixedRandomSource(ints: [0, 0], doubles: [0.5], bools: [true])

        var state = behavior.start(context: context, random: random)

        // Move to perform phase
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.3,
            windowFrames: windowFrames
        )
        _ = behavior.update(state: &state, context: context, deltaTime: 0.3)
        XCTAssertEqual(state.phase, .perform)

        // Cursor approaches within flee threshold (90 pixels for shy)
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.4,
            cursorPosition: Position(x: state.position.x + 50, y: state.position.y),
            windowFrames: windowFrames
        )
        let events = behavior.update(state: &state, context: context, deltaTime: 0.1)

        // Should flee to exit
        XCTAssertEqual(state.phase, .exit)
        XCTAssertTrue(events.contains(.phaseChanged(.exit)))
    }

    func testClimberBehaviorWindowDisappearsMidClimb() {
        // When the tracked window disappears mid-climb, the behavior should gracefully exit
        let behavior = ClimberBehavior()
        let creature = makeClimberCreature()
        let targetWindow = ScreenRect(x: 100, y: 100, width: 800, height: 600, windowID: 77)
        let otherWindow = ScreenRect(x: 500, y: 200, width: 400, height: 300, windowID: 88)
        var windowFrames = [targetWindow, otherWindow]
        var context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            windowFrames: windowFrames
        )
        // Random: int 0 picks first window (ID 77), int 0 picks top edge
        let random = FixedRandomSource(ints: [0, 0], doubles: [0.5], bools: [true])

        var state = behavior.start(context: context, random: random)
        XCTAssertEqual(state.metadata["windowID"], "77")

        // Move to perform phase
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.3,
            windowFrames: windowFrames
        )
        _ = behavior.update(state: &state, context: context, deltaTime: 0.3)
        XCTAssertEqual(state.phase, .perform)

        // Remove the tracked window (ID 77) but keep the other one (ID 88)
        windowFrames = [otherWindow]
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.4,
            windowFrames: windowFrames
        )
        let events = behavior.update(state: &state, context: context, deltaTime: 0.1)

        // Should gracefully exit since tracked window (ID 77) is gone
        XCTAssertEqual(state.phase, .exit)
        XCTAssertTrue(events.contains(.phaseChanged(.exit)))
    }

    func testClimberBehaviorWindowListChangesButTargetPersists() {
        // When windows are added/removed but the target window remains, climbing should continue
        let behavior = ClimberBehavior()
        let creature = makeClimberCreature()
        let targetWindow = ScreenRect(x: 100, y: 100, width: 800, height: 600, windowID: 33)
        var windowFrames = [targetWindow]
        var context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            windowFrames: windowFrames
        )
        // Random: int 0 picks the window (ID 33), int 0 picks top edge
        let random = FixedRandomSource(ints: [0, 0], doubles: [0.5], bools: [true])

        var state = behavior.start(context: context, random: random)
        XCTAssertEqual(state.metadata["windowID"], "33")

        // Move to perform phase
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.3,
            windowFrames: windowFrames
        )
        _ = behavior.update(state: &state, context: context, deltaTime: 0.3)
        XCTAssertEqual(state.phase, .perform)

        // Add new windows before and after the target - target is now at a different index
        let newWindow1 = ScreenRect(x: 0, y: 0, width: 300, height: 200, windowID: 11)
        let newWindow2 = ScreenRect(x: 900, y: 100, width: 500, height: 400, windowID: 99)
        windowFrames = [newWindow1, newWindow2, targetWindow]  // target is now at index 2, was 0
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.5,
            windowFrames: windowFrames
        )
        let events = behavior.update(state: &state, context: context, deltaTime: 0.2)

        // Should still be performing (target window ID 33 is still present)
        XCTAssertEqual(state.phase, .perform)
        // Should have position updates from normal climbing progress
        XCTAssertTrue(events.contains(where: {
            if case .positionChanged = $0 { return true }
            return false
        }))
    }

    // MARK: - Mock Window Tracker Tests

    func testMockWindowTrackerReturnsConfiguredFrames() {
        let frames = [
            ScreenRect(x: 100, y: 100, width: 800, height: 600),
            ScreenRect(x: 500, y: 200, width: 400, height: 300)
        ]
        let tracker = MockWindowTracker(frames: frames)

        let result = tracker.getWindowFrames()

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].x, 100)
        XCTAssertEqual(result[1].width, 400)
    }

    func testMockWindowTrackerCanUpdateFrames() {
        let tracker = MockWindowTracker(frames: [])
        XCTAssertTrue(tracker.getWindowFrames().isEmpty)

        tracker.frames = [ScreenRect(x: 0, y: 0, width: 100, height: 100)]
        XCTAssertEqual(tracker.getWindowFrames().count, 1)
    }

    // MARK: - ScreenRect Window Edge Tests

    func testScreenRectRandomPositionOnEdge() {
        let rect = ScreenRect(x: 100, y: 100, width: 800, height: 600)
        let random = FixedRandomSource(ints: [], doubles: [0.5])

        let topPos = rect.randomPositionOnEdge(.top, random: random)
        XCTAssertEqual(topPos.y, rect.minY)
        XCTAssertGreaterThan(topPos.x, rect.minX)
        XCTAssertLessThan(topPos.x, rect.maxX)
    }

    func testScreenRectCornerPosition() {
        let rect = ScreenRect(x: 100, y: 100, width: 800, height: 600)

        let topLeft = rect.cornerPosition(primary: .top, secondary: .left)
        XCTAssertEqual(topLeft.x, rect.minX)
        XCTAssertEqual(topLeft.y, rect.minY)

        let bottomRight = rect.cornerPosition(primary: .bottom, secondary: .right)
        XCTAssertEqual(bottomRight.x, rect.maxX)
        XCTAssertEqual(bottomRight.y, rect.maxY)
    }

    func testScreenRectIsNearEdge() {
        let rect = ScreenRect(x: 100, y: 100, width: 800, height: 600)

        // Position near top edge
        let nearTop = Position(x: 500, y: 105)
        XCTAssertEqual(rect.isNearEdge(nearTop, threshold: 30), .top)

        // Position near left edge
        let nearLeft = Position(x: 105, y: 400)
        XCTAssertEqual(rect.isNearEdge(nearLeft, threshold: 30), .left)

        // Position far from any edge
        let center = rect.center
        XCTAssertNil(rect.isNearEdge(center, threshold: 30))
    }

    // MARK: - Follow Behavior Tests

    func testFollowBehaviorStart() {
        let behavior = FollowBehavior()
        let creature = makeFollowCreature()
        let context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            cursorPosition: Position(x: 500, y: 500)
        )
        // Random: double for angle, double for duration
        let random = FixedRandomSource(ints: [], doubles: [0.0, 0.0])

        let state = behavior.start(context: context, random: random)

        XCTAssertEqual(state.phase, .enter)
        XCTAssertNotNil(state.animation)
        XCTAssertNotNil(state.metadata["followDistance"])
        XCTAssertNotNil(state.metadata["followDuration"])
    }

    func testFollowBehaviorPhaseTransitions() {
        let behavior = FollowBehavior()
        let creature = makeFollowCreature()
        var context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            cursorPosition: Position(x: 500, y: 500)
        )
        let random = FixedRandomSource(ints: [], doubles: [0.0, 0.0])

        var state = behavior.start(context: context, random: random)
        XCTAssertEqual(state.phase, .enter)

        // Move past enter phase (0.3s)
        context = BehaviorContext(
            creature: creature,
            screenBounds: context.screenBounds,
            currentTime: 0.4,
            cursorPosition: Position(x: 500, y: 500)
        )
        let events = behavior.update(state: &state, context: context, deltaTime: 0.4)

        XCTAssertEqual(state.phase, .perform)
        XCTAssertTrue(events.contains(.phaseChanged(.perform)))
    }

    func testFollowBehaviorCancel() {
        let behavior = FollowBehavior()
        let creature = makeFollowCreature()
        let context = BehaviorContext(
            creature: creature,
            screenBounds: ScreenRect(x: 0, y: 0, width: 1920, height: 1080),
            currentTime: 0,
            cursorPosition: Position(x: 500, y: 500)
        )
        let random = FixedRandomSource(ints: [], doubles: [0.0, 0.0])

        var state = behavior.start(context: context, random: random)
        let events = behavior.cancel(state: &state)

        XCTAssertEqual(state.phase, .complete)
        XCTAssertTrue(events.contains(.cancelled))
    }

    func testFollowBehaviorMovesTowardCursor() {
        let behavior = FollowBehavior()
        let creature = makeFollowCreature()  // curious personality
        let bounds = ScreenRect(x: 0, y: 0, width: 1920, height: 1080)
        var context = BehaviorContext(
            creature: creature,
            screenBounds: bounds,
            currentTime: 0,
            cursorPosition: Position(x: 500, y: 500)
        )
        // Start angle 0 puts creature to the right of cursor at follow distance
        let random = FixedRandomSource(ints: [], doubles: [0.0, 0.5])

        var state = behavior.start(context: context, random: random)

        // Move to perform phase
        context = BehaviorContext(
            creature: creature,
            screenBounds: bounds,
            currentTime: 0.4,
            cursorPosition: Position(x: 500, y: 500)
        )
        _ = behavior.update(state: &state, context: context, deltaTime: 0.4)
        XCTAssertEqual(state.phase, .perform)

        let initialPosition = state.position

        // Move cursor away and simulate time passing
        context = BehaviorContext(
            creature: creature,
            screenBounds: bounds,
            currentTime: 1.5,
            cursorPosition: Position(x: 800, y: 800)  // Cursor moved far away
        )
        _ = behavior.update(state: &state, context: context, deltaTime: 1.1)

        // Creature should have moved toward the new cursor position
        let finalPosition = state.position
        let distanceToNewCursor = finalPosition.distance(to: Position(x: 800, y: 800))
        let distanceFromInitial = initialPosition.distance(to: Position(x: 800, y: 800))

        // Should be closer to cursor than before (or at follow distance)
        XCTAssertLessThanOrEqual(distanceToNewCursor, distanceFromInitial)
    }

    func testFollowBehaviorFleeWhenCursorTooClose() {
        let behavior = FollowBehavior()
        // Shy personality: followFleeDistance = 100
        let creature = Creature(
            id: "shy-follow",
            name: "Shy Follower",
            personality: .shy,
            animations: [
                "idle": Animation(name: "idle", frameCount: 8, fps: 6),
                "walk-left": Animation(name: "walk-left", frameCount: 8, fps: 10)
            ]
        )
        let bounds = ScreenRect(x: 0, y: 0, width: 1920, height: 1080)
        var context = BehaviorContext(
            creature: creature,
            screenBounds: bounds,
            currentTime: 0,
            cursorPosition: Position(x: 500, y: 500)
        )
        let random = FixedRandomSource(ints: [], doubles: [0.0, 0.5])

        var state = behavior.start(context: context, random: random)

        // Move to perform phase
        context = BehaviorContext(
            creature: creature,
            screenBounds: bounds,
            currentTime: 0.4,
            cursorPosition: Position(x: 500, y: 500)
        )
        _ = behavior.update(state: &state, context: context, deltaTime: 0.4)
        XCTAssertEqual(state.phase, .perform)

        // Move cursor very close to creature (within flee distance of 100)
        context = BehaviorContext(
            creature: creature,
            screenBounds: bounds,
            currentTime: 0.5,
            cursorPosition: Position(x: state.position.x + 30, y: state.position.y)
        )
        let events = behavior.update(state: &state, context: context, deltaTime: 0.1)

        // Should flee to exit
        XCTAssertEqual(state.phase, .exit)
        XCTAssertTrue(events.contains(.phaseChanged(.exit)))
    }

    func testBehaviorRegistryIncludesFollow() {
        let registry = BehaviorRegistry.shared
        let follow = registry.behavior(for: .cursorReactive)
        XCTAssertNotNil(follow)
        XCTAssertEqual(follow?.type, .cursorReactive)
    }

    // MARK: - Mock Cursor Tracker Tests

    func testMockCursorTrackerReturnsConfiguredPosition() {
        let position = Position(x: 500, y: 600)
        let tracker = MockCursorTracker(position: position)

        let result = tracker.getCurrentPosition()

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.x, 500)
        XCTAssertEqual(result?.y, 600)
    }

    func testMockCursorTrackerCanUpdatePosition() {
        let tracker = MockCursorTracker(position: nil)
        XCTAssertNil(tracker.getCurrentPosition())

        tracker.moveTo(Position(x: 100, y: 200))
        let result = tracker.getCurrentPosition()

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.x, 100)
        XCTAssertEqual(result?.y, 200)
    }

    func testMockCursorTrackerReturnsVelocity() {
        let velocity = Position(x: 150, y: -50)
        let tracker = MockCursorTracker(position: Position(x: 0, y: 0), velocity: velocity)

        let result = tracker.getCursorVelocity()

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.x, 150)
        XCTAssertEqual(result?.y, -50)
    }

    // MARK: - Helpers

    private func makeFollowCreature() -> Creature {
        Creature(
            id: "follow-test",
            name: "Follow Test",
            personality: .curious,
            animations: [
                "idle": Animation(name: "idle", frameCount: 8, fps: 6),
                "walk-left": Animation(name: "walk-left", frameCount: 8, fps: 10),
                "walk-right": Animation(name: "walk-right", frameCount: 8, fps: 10)
            ]
        )
    }

    private func makeTraverseCreature() -> Creature {
        Creature(
            id: "traverse-test",
            name: "Traverse Test",
            personality: .curious,
            animations: [
                "walk-left": Animation(name: "walk-left", frameCount: 8, fps: 10),
                "walk-right": Animation(name: "walk-right", frameCount: 8, fps: 10),
                "idle": Animation(name: "idle", frameCount: 8, fps: 6)
            ]
        )
    }

    private func makeStationaryCreature() -> Creature {
        Creature(
            id: "stationary-test",
            name: "Stationary Test",
            personality: .curious,
            animations: [
                "idle": Animation(name: "idle", frameCount: 8, fps: 6)
            ]
        )
    }

    private func makeClimberCreature() -> Creature {
        Creature(
            id: "climber-test",
            name: "Climber Test",
            personality: .curious,
            animations: [
                "climb": Animation(name: "climb", frameCount: 8, fps: 10),
                "idle": Animation(name: "idle", frameCount: 8, fps: 6)
            ]
        )
    }
}
