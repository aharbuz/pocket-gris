import XCTest
@testable import PocketGrisCore

final class ScriptedBehaviorTests: XCTestCase {

    var testCreature: Creature!
    var screenBounds: ScreenRect!

    override func setUp() {
        testCreature = Creature(
            id: "test",
            name: "Test Creature",
            personality: .curious,
            animations: [
                "walk-left": Animation(name: "walk-left", frameCount: 10, fps: 10, looping: true),
                "walk-right": Animation(name: "walk-right", frameCount: 10, fps: 10, looping: true),
                "idle": Animation(name: "idle", frameCount: 4, fps: 6, looping: true)
            ]
        )
        screenBounds = ScreenRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    private func makeContext(currentTime: TimeInterval = 0, windowFrames: [ScreenRect] = []) -> BehaviorContext {
        BehaviorContext(
            creature: testCreature,
            screenBounds: screenBounds,
            currentTime: currentTime,
            windowFrames: windowFrames
        )
    }

    // MARK: - Start

    func testStartPositionsAtFirstWaypoint() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [Position(x: 100, y: 200), Position(x: 500, y: 600)],
            segments: [SceneSegment(animationName: "walk-left", duration: 2.0)]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        let state = behavior.start(context: makeContext(), random: random)

        XCTAssertEqual(state.phase, .enter)
        XCTAssertEqual(state.position.x, 100, accuracy: 0.01)
        XCTAssertEqual(state.position.y, 200, accuracy: 0.01)
        XCTAssertNotNil(state.animation)
    }

    func testStartWithInvalidTrackCompletesImmediately() {
        let track = SceneTrack(creatureId: "test")  // no waypoints
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        let state = behavior.start(context: makeContext(), random: random)

        XCTAssertEqual(state.phase, .complete)
    }

    func testRequiredAnimations() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [
                Position(x: 0, y: 0),
                Position(x: 100, y: 100),
                Position(x: 200, y: 200)
            ],
            segments: [
                SceneSegment(animationName: "walk-left"),
                SceneSegment(animationName: "idle")
            ]
        )
        let behavior = ScriptedBehavior(track: track)
        let required = Set(behavior.requiredAnimations)
        XCTAssertTrue(required.contains("walk-left"))
        XCTAssertTrue(required.contains("idle"))
    }

    // MARK: - Single Segment Position

    func testSingleSegmentPositionAtStart() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 200)],
            segments: [SceneSegment(animationName: "walk-left", duration: 2.0)]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        // Advance past enter phase
        _ = behavior.update(state: &state, context: makeContext(currentTime: 0.3), deltaTime: 0.3)
        XCTAssertEqual(state.phase, .perform)

        // At t=0 of perform, should be at first waypoint
        XCTAssertEqual(state.position.x, 0, accuracy: 1.0)
        XCTAssertEqual(state.position.y, 0, accuracy: 1.0)
    }

    func testSingleSegmentPositionAtMidpoint() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 200)],
            segments: [SceneSegment(animationName: "walk-left", duration: 2.0)]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        // Advance past enter phase
        _ = behavior.update(state: &state, context: makeContext(currentTime: 0.3), deltaTime: 0.3)
        XCTAssertEqual(state.phase, .perform)

        // Advance to midpoint of segment (1.0s of 2.0s)
        _ = behavior.update(state: &state, context: makeContext(currentTime: 1.3), deltaTime: 1.0)

        XCTAssertEqual(state.position.x, 50, accuracy: 1.0)
        XCTAssertEqual(state.position.y, 100, accuracy: 1.0)
    }

    func testSingleSegmentPositionAtEnd() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 200)],
            segments: [SceneSegment(animationName: "walk-left", duration: 2.0)]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        // Advance past enter
        _ = behavior.update(state: &state, context: makeContext(currentTime: 0.3), deltaTime: 0.3)

        // Advance to end of segment
        _ = behavior.update(state: &state, context: makeContext(currentTime: 2.5), deltaTime: 2.2)

        // Should transition to exit after segment completes
        XCTAssertEqual(state.phase, .exit)
        XCTAssertEqual(state.position.x, 100, accuracy: 1.0)
        XCTAssertEqual(state.position.y, 200, accuracy: 1.0)
    }

    // MARK: - Multi-Segment Transitions

    func testMultiSegmentTransition() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [
                Position(x: 0, y: 0),
                Position(x: 100, y: 0),
                Position(x: 100, y: 200)
            ],
            segments: [
                SceneSegment(animationName: "walk-left", duration: 1.0),
                SceneSegment(animationName: "walk-right", duration: 1.0)
            ]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        // Pass enter phase
        _ = behavior.update(state: &state, context: makeContext(currentTime: 0.3), deltaTime: 0.3)
        XCTAssertEqual(state.phase, .perform)

        // Advance through first segment completely
        _ = behavior.update(state: &state, context: makeContext(currentTime: 1.4), deltaTime: 1.1)

        // Should now be in second segment
        XCTAssertEqual(state.phase, .perform)
        XCTAssertEqual(state.metadata["segmentIndex"], "1")
    }

    func testMultiSegmentAnimationSwitching() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [
                Position(x: 0, y: 0),
                Position(x: 100, y: 0),
                Position(x: 200, y: 0)
            ],
            segments: [
                SceneSegment(animationName: "walk-left", duration: 1.0),
                SceneSegment(animationName: "idle", duration: 1.0)
            ]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        // First animation should be walk-left
        XCTAssertEqual(state.animation?.animation.name, "walk-left")

        // Pass enter
        _ = behavior.update(state: &state, context: makeContext(currentTime: 0.3), deltaTime: 0.3)

        // Complete first segment, trigger animation switch
        let events = behavior.update(state: &state, context: makeContext(currentTime: 1.4), deltaTime: 1.1)

        XCTAssertEqual(state.animation?.animation.name, "idle")
        XCTAssertTrue(events.contains(.animationFrameChanged(0)))
    }

    func testMultiSegmentCompletes() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [
                Position(x: 0, y: 0),
                Position(x: 100, y: 0),
                Position(x: 200, y: 0)
            ],
            segments: [
                SceneSegment(animationName: "walk-left", duration: 1.0),
                SceneSegment(animationName: "walk-right", duration: 1.0)
            ]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        // Pass enter
        _ = behavior.update(state: &state, context: makeContext(currentTime: 0.3), deltaTime: 0.3)

        // Complete first segment (transitions to second)
        _ = behavior.update(state: &state, context: makeContext(currentTime: 1.4), deltaTime: 1.1)
        XCTAssertEqual(state.phase, .perform)
        XCTAssertEqual(state.metadata["segmentIndex"], "1")

        // Complete second segment → exit
        _ = behavior.update(state: &state, context: makeContext(currentTime: 2.5), deltaTime: 1.1)
        XCTAssertEqual(state.phase, .exit)

        // Complete exit
        _ = behavior.update(state: &state, context: makeContext(currentTime: 2.8), deltaTime: 0.3)
        XCTAssertEqual(state.phase, .complete)
    }

    // MARK: - Snap Modes

    func testSnapModeScreenBottom() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [Position(x: 0, y: 500), Position(x: 100, y: 500)],
            segments: [SceneSegment(animationName: "walk-left", duration: 2.0, snapMode: .screenBottom)]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        // Pass enter
        _ = behavior.update(state: &state, context: makeContext(currentTime: 0.3), deltaTime: 0.3)

        // Update with perform
        _ = behavior.update(state: &state, context: makeContext(currentTime: 1.3), deltaTime: 1.0)

        // Y should be snapped to screen bottom
        XCTAssertEqual(state.position.y, 1080, accuracy: 0.01)
        // X should still interpolate normally
        XCTAssertEqual(state.position.x, 50, accuracy: 1.0)
    }

    func testSnapModeScreenTop() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [Position(x: 0, y: 500), Position(x: 100, y: 500)],
            segments: [SceneSegment(animationName: "walk-left", duration: 2.0, snapMode: .screenTop)]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        // Pass enter
        _ = behavior.update(state: &state, context: makeContext(currentTime: 0.3), deltaTime: 0.3)

        _ = behavior.update(state: &state, context: makeContext(currentTime: 1.3), deltaTime: 1.0)

        XCTAssertEqual(state.position.y, 0, accuracy: 0.01)
    }

    func testSnapModeWindowTop() {
        let windowFrame = ScreenRect(x: 200, y: 300, width: 800, height: 600)
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [Position(x: 300, y: 500), Position(x: 600, y: 500)],
            segments: [SceneSegment(animationName: "walk-left", duration: 2.0, snapMode: .windowTop)]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(windowFrames: [windowFrame]), random: random)

        // Pass enter
        _ = behavior.update(state: &state, context: makeContext(currentTime: 0.3, windowFrames: [windowFrame]), deltaTime: 0.3)

        _ = behavior.update(state: &state, context: makeContext(currentTime: 1.3, windowFrames: [windowFrame]), deltaTime: 1.0)

        // Y should snap to top of nearest window
        XCTAssertEqual(state.position.y, 300, accuracy: 0.01)
    }

    func testSnapModeNoneDoesNotConstrain() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [Position(x: 0, y: 100), Position(x: 200, y: 300)],
            segments: [SceneSegment(animationName: "walk-left", duration: 2.0, snapMode: .none)]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        // Pass enter
        _ = behavior.update(state: &state, context: makeContext(currentTime: 0.3), deltaTime: 0.3)

        _ = behavior.update(state: &state, context: makeContext(currentTime: 1.3), deltaTime: 1.0)

        // Position should be linearly interpolated without snapping
        XCTAssertEqual(state.position.x, 100, accuracy: 1.0)
        XCTAssertEqual(state.position.y, 200, accuracy: 1.0)
    }

    // MARK: - Cancel

    func testCancel() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 100)],
            segments: [SceneSegment(animationName: "walk-left", duration: 2.0)]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        let events = behavior.cancel(state: &state)
        XCTAssertEqual(state.phase, .complete)
        XCTAssertTrue(events.contains(.cancelled))
    }

    func testCancelAlreadyComplete() {
        let track = SceneTrack(creatureId: "test")
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        // Already complete (invalid track)
        let events = behavior.cancel(state: &state)
        XCTAssertTrue(events.isEmpty)
    }

    // MARK: - Phase Transitions

    func testFullLifecycle() {
        let track = SceneTrack(
            creatureId: "test",
            waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 100)],
            segments: [SceneSegment(animationName: "walk-left", duration: 1.0)]
        )
        let behavior = ScriptedBehavior(track: track)
        let random = FixedRandomSource()
        var state = behavior.start(context: makeContext(), random: random)

        XCTAssertEqual(state.phase, .enter)

        // Enter → Perform
        _ = behavior.update(state: &state, context: makeContext(currentTime: 0.3), deltaTime: 0.3)
        XCTAssertEqual(state.phase, .perform)

        // Perform → Exit (segment completes)
        _ = behavior.update(state: &state, context: makeContext(currentTime: 1.4), deltaTime: 1.1)
        XCTAssertEqual(state.phase, .exit)

        // Exit → Complete
        _ = behavior.update(state: &state, context: makeContext(currentTime: 1.7), deltaTime: 0.3)
        XCTAssertEqual(state.phase, .complete)
    }
}
