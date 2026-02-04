import XCTest
@testable import PocketGrisCore

final class PositionCalculatorTests: XCTestCase {

    let calculator = PositionCalculator()
    let screenBounds = ScreenRect(x: 0, y: 0, width: 1920, height: 1080)

    func testPositionOnScreenEdgeLeft() {
        let random = FixedRandomSource(doubles: [0.5])
        let pos = calculator.positionOnScreenEdge(edge: .left, screenBounds: screenBounds, random: random)

        XCTAssertEqual(pos.x, 0)
        // y should be in middle of safe range (50 to 1030)
        XCTAssertEqual(pos.y, (50 + 1030) / 2)
    }

    func testPositionOnScreenEdgeRight() {
        let random = FixedRandomSource(doubles: [0.5])
        let pos = calculator.positionOnScreenEdge(edge: .right, screenBounds: screenBounds, random: random)

        XCTAssertEqual(pos.x, 1920)
    }

    func testPositionOnScreenEdgeTop() {
        let random = FixedRandomSource(doubles: [0.5])
        let pos = calculator.positionOnScreenEdge(edge: .top, screenBounds: screenBounds, random: random)

        XCTAssertEqual(pos.y, 0)
    }

    func testPositionOnScreenEdgeBottom() {
        let random = FixedRandomSource(doubles: [0.5])
        let pos = calculator.positionOnScreenEdge(edge: .bottom, screenBounds: screenBounds, random: random)

        XCTAssertEqual(pos.y, 1080)
    }

    func testCorners() {
        let rect = ScreenRect(x: 10, y: 20, width: 100, height: 50)
        let corners = calculator.corners(of: rect)

        XCTAssertEqual(corners.count, 4)
        XCTAssertEqual(corners[0], Position(x: 10, y: 20))  // Top-left
        XCTAssertEqual(corners[1], Position(x: 110, y: 20)) // Top-right
        XCTAssertEqual(corners[2], Position(x: 10, y: 70))  // Bottom-left
        XCTAssertEqual(corners[3], Position(x: 110, y: 70)) // Bottom-right
    }

    func testHidingPosition() {
        let visible = Position(x: 100, y: 200)

        let hiddenLeft = calculator.hidingPosition(edge: .left, visiblePosition: visible, spriteSize: 50)
        XCTAssertEqual(hiddenLeft, Position(x: 50, y: 200))

        let hiddenRight = calculator.hidingPosition(edge: .right, visiblePosition: visible, spriteSize: 50)
        XCTAssertEqual(hiddenRight, Position(x: 150, y: 200))

        let hiddenTop = calculator.hidingPosition(edge: .top, visiblePosition: visible, spriteSize: 50)
        XCTAssertEqual(hiddenTop, Position(x: 100, y: 150))

        let hiddenBottom = calculator.hidingPosition(edge: .bottom, visiblePosition: visible, spriteSize: 50)
        XCTAssertEqual(hiddenBottom, Position(x: 100, y: 250))
    }

    func testStraightPath() {
        let start = Position(x: 0, y: 0)
        let end = Position(x: 100, y: 100)
        let path = calculator.straightPath(from: start, to: end, steps: 4)

        XCTAssertEqual(path.count, 5)  // 0, 1, 2, 3, 4
        XCTAssertEqual(path[0], start)
        XCTAssertEqual(path[2], Position(x: 50, y: 50))
        XCTAssertEqual(path[4], end)
    }

    func testEasedPathEndsMatch() {
        let start = Position(x: 0, y: 0)
        let end = Position(x: 100, y: 100)
        let path = calculator.easedPath(from: start, to: end, steps: 10)

        XCTAssertEqual(path.first, start)
        // End might have tiny floating point differences
        XCTAssertEqual(path.last?.x ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(path.last?.y ?? 0, 100, accuracy: 0.001)
    }

    func testFleeDirection() {
        let creature = Position(x: 100, y: 100)
        let cursor = Position(x: 50, y: 100)  // Cursor to the left

        let direction = calculator.fleeDirection(from: creature, cursor: cursor)

        // Should flee to the right (positive x)
        XCTAssertGreaterThan(direction.x, 0)
        XCTAssertEqual(direction.y, 0, accuracy: 0.001)
    }

    func testFleePositionClamped() {
        let creature = Position(x: 1900, y: 540)  // Near right edge
        let cursor = Position(x: 1800, y: 540)

        let fleePos = calculator.fleePosition(
            from: creature,
            cursor: cursor,
            distance: 200,
            bounds: screenBounds
        )

        // Should be clamped to screen edge
        XCTAssertEqual(fleePos.x, 1920)
    }
}
