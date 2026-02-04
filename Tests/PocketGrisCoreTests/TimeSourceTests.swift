import XCTest
@testable import PocketGrisCore

final class TimeSourceTests: XCTestCase {

    func testMockTimeSourceInitialValue() {
        let time = MockTimeSource(now: 100)
        XCTAssertEqual(time.now, 100)
    }

    func testMockTimeSourceAdvance() {
        let time = MockTimeSource(now: 0)

        time.advance(by: 5)
        XCTAssertEqual(time.now, 5)

        time.advance(by: 3.5)
        XCTAssertEqual(time.now, 8.5)
    }

    func testMockTimeSourceSet() {
        let time = MockTimeSource(now: 0)

        time.set(42)
        XCTAssertEqual(time.now, 42)

        time.advance(by: 8)
        XCTAssertEqual(time.now, 50)
    }

    func testSystemTimeSourceIncreases() {
        let time = SystemTimeSource()

        let t1 = time.now
        Thread.sleep(forTimeInterval: 0.01)
        let t2 = time.now

        XCTAssertGreaterThan(t2, t1)
    }
}
