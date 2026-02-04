import XCTest
@testable import PocketGrisCore

final class SettingsTests: XCTestCase {

    func testDefaultSettings() {
        let settings = Settings.default

        XCTAssertTrue(settings.enabled)
        XCTAssertEqual(settings.minInterval, 15 * 60)
        XCTAssertEqual(settings.maxInterval, 30 * 60)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertTrue(settings.enabledCreatures.isEmpty)
    }

    func testRandomIntervalInRange() {
        let settings = Settings(minInterval: 10, maxInterval: 20)
        let random = FixedRandomSource(doubles: [0.0, 0.5, 1.0])

        // 0.0 -> min
        XCTAssertEqual(settings.randomInterval(using: random), 10)
        // 0.5 -> middle
        XCTAssertEqual(settings.randomInterval(using: random), 15)
        // 1.0 -> max
        XCTAssertEqual(settings.randomInterval(using: random), 20)
    }

    func testSettingsCodable() {
        let settings = Settings(
            enabled: false,
            minInterval: 100,
            maxInterval: 200,
            launchAtLogin: true,
            enabledCreatures: ["gremlin", "fairy"],
            behaviorWeights: ["peek": 2.0, "traverse": 1.0]
        )

        let encoder = JSONEncoder()
        let data = try! encoder.encode(settings)

        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(Settings.self, from: data)

        XCTAssertEqual(decoded.enabled, settings.enabled)
        XCTAssertEqual(decoded.minInterval, settings.minInterval)
        XCTAssertEqual(decoded.maxInterval, settings.maxInterval)
        XCTAssertEqual(decoded.launchAtLogin, settings.launchAtLogin)
        XCTAssertEqual(decoded.enabledCreatures, settings.enabledCreatures)
        XCTAssertEqual(decoded.behaviorWeights, settings.behaviorWeights)
    }
}
