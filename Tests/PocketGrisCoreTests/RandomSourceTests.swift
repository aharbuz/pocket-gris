import XCTest
@testable import PocketGrisCore

final class RandomSourceTests: XCTestCase {

    func testSeededRandomSourceReproducible() {
        let random1 = SeededRandomSource(seed: 12345)
        let random2 = SeededRandomSource(seed: 12345)

        for _ in 0..<10 {
            XCTAssertEqual(
                random1.int(in: 0..<100),
                random2.int(in: 0..<100)
            )
        }
    }

    func testFixedRandomSourceInts() {
        let random = FixedRandomSource(ints: [5, 10, 15])

        XCTAssertEqual(random.int(in: 0..<100), 5)
        XCTAssertEqual(random.int(in: 0..<100), 10)
        XCTAssertEqual(random.int(in: 0..<100), 15)
        // Wraps around
        XCTAssertEqual(random.int(in: 0..<100), 5)
    }

    func testFixedRandomSourceDoubles() {
        let random = FixedRandomSource(doubles: [0.0, 0.5, 1.0])

        // 0.0 maps to lower bound
        XCTAssertEqual(random.double(in: 10.0...20.0), 10.0)
        // 0.5 maps to middle
        XCTAssertEqual(random.double(in: 10.0...20.0), 15.0)
        // 1.0 maps to upper bound
        XCTAssertEqual(random.double(in: 10.0...20.0), 20.0)
    }

    func testFixedRandomSourceBools() {
        let random = FixedRandomSource(bools: [true, false, true])

        XCTAssertTrue(random.bool())
        XCTAssertFalse(random.bool())
        XCTAssertTrue(random.bool())
        // Wraps
        XCTAssertTrue(random.bool())
    }

    func testFixedRandomSourceClampsToRange() {
        let random = FixedRandomSource(ints: [1000])

        // Should clamp to valid range
        let result = random.int(in: 0..<10)
        XCTAssertTrue(result >= 0 && result < 10)
    }
}
