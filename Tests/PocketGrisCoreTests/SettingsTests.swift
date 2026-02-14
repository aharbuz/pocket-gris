import XCTest
@testable import PocketGrisCore

final class SettingsTests: XCTestCase {

    private var tempDir: URL!
    private var settingsURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("settings-tests-\(UUID().uuidString)")
        settingsURL = tempDir.appendingPathComponent("settings.json")
    }

    override func tearDown() {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        settingsURL = nil
        super.tearDown()
    }

    func testDefaultSettings() {
        let settings = Settings.default

        XCTAssertTrue(settings.enabled)
        XCTAssertEqual(settings.minInterval, 15 * 60)
        XCTAssertEqual(settings.maxInterval, 30 * 60)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertTrue(settings.enabledCreatures.isEmpty)
        XCTAssertTrue(settings.scenesEnabled)
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
            behaviorWeights: ["peek": 2.0, "traverse": 1.0],
            scenesEnabled: false
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
        XCTAssertEqual(decoded.scenesEnabled, settings.scenesEnabled)
    }

    // MARK: - Persistence

    func testSaveAndLoadRoundTrip() throws {
        let settings = Settings(
            enabled: false,
            minInterval: 120,
            maxInterval: 360,
            launchAtLogin: true,
            enabledCreatures: ["gris", "pig-gnome"],
            behaviorWeights: ["peek": 3.0, "traverse": 1.5],
            sceneWeights: ["dance": 2.0],
            scenesEnabled: false,
            enabledScenes: ["scene-1"],
            behaviorsEnabled: true
        )

        try settings.save(to: settingsURL)
        let loaded = Settings.load(from: settingsURL)

        XCTAssertEqual(loaded, settings)
    }

    func testLoadFromMissingFileReturnsDefault() {
        let nonexistent = tempDir.appendingPathComponent("nonexistent.json")
        let loaded = Settings.load(from: nonexistent)
        XCTAssertEqual(loaded, Settings.default)
    }

    func testLoadFromCorruptedFileReturnsDefault() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try "not valid json!!!".write(to: settingsURL, atomically: true, encoding: .utf8)

        let loaded = Settings.load(from: settingsURL)
        XCTAssertEqual(loaded, Settings.default)
    }

    func testLoadFromEmptyFileReturnsDefault() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try "".write(to: settingsURL, atomically: true, encoding: .utf8)

        let loaded = Settings.load(from: settingsURL)
        XCTAssertEqual(loaded, Settings.default)
    }

    func testSaveCreatesDirectoryIfNeeded() throws {
        // tempDir does not exist yet
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path))

        let settings = Settings(minInterval: 42, maxInterval: 84)
        try settings.save(to: settingsURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsURL.path))
        let loaded = Settings.load(from: settingsURL)
        XCTAssertEqual(loaded.minInterval, 42)
        XCTAssertEqual(loaded.maxInterval, 84)
    }

    func testSaveOverwritesPreviousSettings() throws {
        let first = Settings(enabled: true, minInterval: 100, maxInterval: 200)
        try first.save(to: settingsURL)

        let second = Settings(enabled: false, minInterval: 300, maxInterval: 600)
        try second.save(to: settingsURL)

        let loaded = Settings.load(from: settingsURL)
        XCTAssertEqual(loaded, second)
        XCTAssertFalse(loaded.enabled)
        XCTAssertEqual(loaded.minInterval, 300)
    }

    func testSaveProducesPrettyPrintedJSON() throws {
        let settings = Settings(minInterval: 10, maxInterval: 20)
        try settings.save(to: settingsURL)

        let data = try Data(contentsOf: settingsURL)
        let jsonString = String(data: data, encoding: .utf8)!

        // Pretty printed JSON has newlines and indentation
        XCTAssertTrue(jsonString.contains("\n"))
        XCTAssertTrue(jsonString.contains("  "))
    }

    func testAllFieldsPersisted() throws {
        let settings = Settings(
            enabled: false,
            minInterval: 1,
            maxInterval: 2,
            launchAtLogin: true,
            enabledCreatures: ["a", "b"],
            behaviorWeights: ["peek": 5.0],
            sceneWeights: ["s1": 3.0],
            scenesEnabled: false,
            enabledScenes: ["s1"],
            behaviorsEnabled: false
        )

        try settings.save(to: settingsURL)
        let loaded = Settings.load(from: settingsURL)

        XCTAssertEqual(loaded.enabled, false)
        XCTAssertEqual(loaded.minInterval, 1)
        XCTAssertEqual(loaded.maxInterval, 2)
        XCTAssertEqual(loaded.launchAtLogin, true)
        XCTAssertEqual(loaded.enabledCreatures, ["a", "b"])
        XCTAssertEqual(loaded.behaviorWeights, ["peek": 5.0])
        XCTAssertEqual(loaded.sceneWeights, ["s1": 3.0])
        XCTAssertEqual(loaded.scenesEnabled, false)
        XCTAssertEqual(loaded.enabledScenes, ["s1"])
        XCTAssertEqual(loaded.behaviorsEnabled, false)
    }
}
