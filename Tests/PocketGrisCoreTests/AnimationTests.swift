import XCTest
@testable import PocketGrisCore

final class AnimationTests: XCTestCase {

    func testAnimationDuration() {
        let anim = Animation(name: "test", frameCount: 24, fps: 12)
        XCTAssertEqual(anim.duration, 2.0)
    }

    func testAnimationFrameFilename() {
        let anim = Animation(name: "test", frameCount: 10)
        XCTAssertEqual(anim.frameFilename(at: 0), "frame-001.png")
        XCTAssertEqual(anim.frameFilename(at: 5), "frame-006.png")
        XCTAssertEqual(anim.frameFilename(at: 9), "frame-010.png")
    }

    func testNonLoopingAnimationClampsFrame() {
        let anim = Animation(name: "test", frameCount: 5, looping: false)
        XCTAssertEqual(anim.frameFilename(at: 10), "frame-005.png")
    }

    func testLoopingAnimationWrapsFrame() {
        let anim = Animation(name: "test", frameCount: 5, looping: true)
        XCTAssertEqual(anim.frameFilename(at: 5), "frame-001.png")
        XCTAssertEqual(anim.frameFilename(at: 7), "frame-003.png")
    }

    func testAnimationStateAdvance() {
        let anim = Animation(name: "test", frameCount: 4, fps: 2)
        var state = AnimationState(animation: anim)

        XCTAssertEqual(state.currentFrame, 0)
        XCTAssertFalse(state.isComplete)

        // Advance half a frame
        _ = state.advance(by: 0.25)
        XCTAssertEqual(state.currentFrame, 0)

        // Advance to frame 1
        let changed = state.advance(by: 0.3)
        XCTAssertTrue(changed)
        XCTAssertEqual(state.currentFrame, 1)

        // Complete the animation
        _ = state.advance(by: 2.0)
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(state.currentFrame, 3)
    }

    func testAnimationStateReset() {
        let anim = Animation(name: "test", frameCount: 4, fps: 2)
        var state = AnimationState(animation: anim)

        _ = state.advance(by: 1.0)
        XCTAssertEqual(state.currentFrame, 2)

        state.reset()
        XCTAssertEqual(state.currentFrame, 0)
        XCTAssertEqual(state.elapsedTime, 0)
        XCTAssertFalse(state.isComplete)
    }

    func testLoopingAnimationNeverCompletes() {
        let anim = Animation(name: "test", frameCount: 4, fps: 2, looping: true)
        var state = AnimationState(animation: anim)

        _ = state.advance(by: 10.0)
        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.currentFrame, 0) // 20 frames = 5 loops, back to 0
    }
}
