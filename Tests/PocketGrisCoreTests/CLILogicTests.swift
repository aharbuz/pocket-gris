import XCTest
@testable import PocketGrisCore

/// Tests for PocketGrisCore logic used by CLI commands.
/// These exercise the same code paths as the CLI without depending on ArgumentParser.
final class CLILogicTests: XCTestCase {

    // MARK: - Version

    func testVersionStringIsValid() {
        let version = PocketGrisCore.version
        XCTAssertFalse(version.isEmpty)
        // Semver-like: major.minor.patch
        let components = version.split(separator: ".")
        XCTAssertEqual(components.count, 3, "Version should be major.minor.patch")
        for component in components {
            XCTAssertNotNil(Int(component), "Each version component should be numeric")
        }
    }

    // MARK: - BehaviorRegistry (Behaviors List)

    func testBehaviorRegistryHasDefaultBehaviors() {
        let allBehaviors = BehaviorRegistry.shared.allBehaviors()
        XCTAssertGreaterThanOrEqual(allBehaviors.count, 5, "Should have at least 5 default behaviors")

        let types = Set(allBehaviors.map { $0.type })
        XCTAssertTrue(types.contains(.peek))
        XCTAssertTrue(types.contains(.traverse))
        XCTAssertTrue(types.contains(.stationary))
        XCTAssertTrue(types.contains(.climber))
        XCTAssertTrue(types.contains(.cursorReactive))
    }

    func testBehaviorRegistryLookup() {
        let peek = BehaviorRegistry.shared.behavior(for: .peek)
        XCTAssertNotNil(peek)
        XCTAssertEqual(peek?.type, .peek)

        let missing = BehaviorRegistry.shared.behavior(for: .scene)
        // Scene type may or may not be registered as a default behavior
        // but lookup should not crash
        _ = missing
    }

    func testAvailableBehaviorsFiltersByAnimations() {
        // Creature with only idle animation - should match stationary but not peek
        let limitedCreature = Creature(
            id: "limited",
            name: "Limited",
            personality: .shy,
            animations: ["idle": Animation(name: "idle", frameCount: 4, looping: true)]
        )

        let available = BehaviorRegistry.shared.availableBehaviors(for: limitedCreature)
        let types = Set(available.map { $0.type })
        XCTAssertTrue(types.contains(.stationary), "Stationary should be available with idle animation")
        XCTAssertFalse(types.contains(.peek), "Peek requires peek-left/retreat-left which are missing")
    }

    func testAllBehaviorsHaveRequiredAnimations() {
        let allBehaviors = BehaviorRegistry.shared.allBehaviors()
        for behavior in allBehaviors {
            XCTAssertFalse(behavior.requiredAnimations.isEmpty,
                           "\(behavior.type.rawValue) should list required animations")
        }
    }

    // MARK: - BehaviorType (CLI parsing)

    func testBehaviorTypeRawValues() {
        // CLI parses behavior type from raw string
        XCTAssertEqual(BehaviorType(rawValue: "peek"), .peek)
        XCTAssertEqual(BehaviorType(rawValue: "traverse"), .traverse)
        XCTAssertEqual(BehaviorType(rawValue: "stationary"), .stationary)
        XCTAssertEqual(BehaviorType(rawValue: "climber"), .climber)
        XCTAssertEqual(BehaviorType(rawValue: "cursorReactive"), .cursorReactive)
        XCTAssertEqual(BehaviorType(rawValue: "scene"), .scene)
        XCTAssertNil(BehaviorType(rawValue: "nonexistent"))
    }

    func testBehaviorTypeAllCases() {
        // CLI uses allCases for help text
        let allCases = BehaviorType.allCases
        XCTAssertGreaterThanOrEqual(allCases.count, 6)
        let rawValues = allCases.map(\.rawValue)
        XCTAssertTrue(rawValues.contains("peek"))
        XCTAssertTrue(rawValues.contains("scene"))
    }

    // MARK: - BehaviorMetadata Dictionary Representation (CLI output)

    func testMetadataDictionaryRepresentationNone() {
        let metadata: BehaviorMetadata = .none
        XCTAssertNil(metadata.dictionaryRepresentation)
    }

    func testMetadataDictionaryRepresentationPeek() {
        let metadata: BehaviorMetadata = .peek(PeekMetadata(peekDuration: 3.5))
        let dict = metadata.dictionaryRepresentation
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["peekDuration"], "3.5")
    }

    func testMetadataDictionaryRepresentationTraverse() {
        let metadata: BehaviorMetadata = .traverse(TraverseMetadata(startX: 0, endX: 100, y: 50, speed: 2.0))
        let dict = metadata.dictionaryRepresentation
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["startX"], "0.0")
        XCTAssertEqual(dict?["endX"], "100.0")
        XCTAssertEqual(dict?["y"], "50.0")
        XCTAssertEqual(dict?["speed"], "2.0")
    }

    func testMetadataDictionaryRepresentationClimberWithWindowID() {
        let metadata: BehaviorMetadata = .climber(ClimberMetadata(
            windowID: 42,
            startX: 0, startY: 0, endX: 100, endY: 200,
            speed: 1.5, windowX: 10, windowY: 20, windowWidth: 800, windowHeight: 600
        ))
        let dict = metadata.dictionaryRepresentation
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["windowID"], "42")
    }

    func testMetadataDictionaryRepresentationClimberWithoutWindowID() {
        let metadata: BehaviorMetadata = .climber(ClimberMetadata(
            windowID: nil,
            startX: 0, startY: 0, endX: 100, endY: 200,
            speed: 1.5, windowX: 10, windowY: 20, windowWidth: 800, windowHeight: 600
        ))
        let dict = metadata.dictionaryRepresentation
        XCTAssertNotNil(dict)
        XCTAssertNil(dict?["windowID"])
    }

    // MARK: - Scheduler Simulation (CLI simulate command)

    func testSchedulerSimulation() {
        let creature = Creature(
            id: "gris",
            name: "Gris",
            personality: .curious,
            animations: [
                "walk-left": Animation(name: "walk-left", frameCount: 10),
                "walk-right": Animation(name: "walk-right", frameCount: 10),
                "idle": Animation(name: "idle", frameCount: 4, looping: true),
                "peek-left": Animation(name: "peek-left", frameCount: 6),
                "retreat-left": Animation(name: "retreat-left", frameCount: 6)
            ]
        )

        let settings = Settings(minInterval: 10, maxInterval: 20)
        let random = SeededRandomSource(seed: 42)
        let scheduler = BehaviorScheduler(
            settings: settings,
            creatures: [creature],
            random: random
        )

        let results = scheduler.simulate(duration: 100)
        XCTAssertGreaterThan(results.count, 0, "Should generate at least one trigger in 100 seconds")

        for result in results {
            XCTAssertLessThan(result.time, 100)
            XCTAssertEqual(result.creature, "gris")
        }
    }
}
