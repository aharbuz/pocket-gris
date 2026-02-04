import XCTest
@testable import PocketGrisCore

final class PositionTests: XCTestCase {

    func testPositionDistance() {
        let p1 = Position(x: 0, y: 0)
        let p2 = Position(x: 3, y: 4)
        XCTAssertEqual(p1.distance(to: p2), 5.0)
    }

    func testPositionOffset() {
        let p = Position(x: 10, y: 20)
        let offset = p.offset(dx: 5, dy: -10)
        XCTAssertEqual(offset.x, 15)
        XCTAssertEqual(offset.y, 10)
    }

    func testScreenRectContains() {
        let rect = ScreenRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(rect.contains(Position(x: 50, y: 50)))
        XCTAssertTrue(rect.contains(Position(x: 0, y: 0)))
        XCTAssertTrue(rect.contains(Position(x: 100, y: 100)))
        XCTAssertFalse(rect.contains(Position(x: 101, y: 50)))
        XCTAssertFalse(rect.contains(Position(x: -1, y: 50)))
    }

    func testScreenRectEdgeMidpoint() {
        let rect = ScreenRect(x: 0, y: 0, width: 100, height: 200)

        XCTAssertEqual(rect.edgeMidpoint(.top), Position(x: 50, y: 0))
        XCTAssertEqual(rect.edgeMidpoint(.bottom), Position(x: 50, y: 200))
        XCTAssertEqual(rect.edgeMidpoint(.left), Position(x: 0, y: 100))
        XCTAssertEqual(rect.edgeMidpoint(.right), Position(x: 100, y: 100))
    }

    func testScreenEdgeOpposite() {
        XCTAssertEqual(ScreenEdge.top.opposite, .bottom)
        XCTAssertEqual(ScreenEdge.bottom.opposite, .top)
        XCTAssertEqual(ScreenEdge.left.opposite, .right)
        XCTAssertEqual(ScreenEdge.right.opposite, .left)
    }
}
