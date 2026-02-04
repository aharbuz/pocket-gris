import XCTest
@testable import PocketGrisCore

final class CreatureTests: XCTestCase {

    func testPersonalityPeekDuration() {
        // Each personality has different peek duration ranges
        XCTAssertEqual(Personality.shy.peekDurationRange, 1.5...3.0)
        XCTAssertEqual(Personality.curious.peekDurationRange, 3.0...6.0)
        XCTAssertEqual(Personality.mischievous.peekDurationRange, 2.0...5.0)
        XCTAssertEqual(Personality.chaotic.peekDurationRange, 0.5...8.0)
    }

    func testPersonalityRetreatSpeed() {
        XCTAssertEqual(Personality.shy.retreatSpeedMultiplier, 1.5)
        XCTAssertEqual(Personality.curious.retreatSpeedMultiplier, 1.0)
        XCTAssertEqual(Personality.mischievous.retreatSpeedMultiplier, 1.0)
        // Chaotic is random, just verify it's in range
        let chaotic = Personality.chaotic.retreatSpeedMultiplier
        XCTAssertTrue(chaotic >= 0.5 && chaotic <= 2.0)
    }

    func testCreatureAnimationLookup() {
        let creature = Creature(
            id: "test",
            name: "Test Creature",
            personality: .curious,
            animations: [
                "peek-left": Animation(name: "peek-left", frameCount: 10),
                "retreat-left": Animation(name: "retreat-left", frameCount: 8)
            ]
        )

        XCTAssertNotNil(creature.animation(named: "peek-left"))
        XCTAssertNotNil(creature.animation(named: "retreat-left"))
        XCTAssertNil(creature.animation(named: "nonexistent"))
    }

    func testCreatureManifestParsing() {
        let json = """
        {
            "id": "gremlin",
            "name": "Gremlin",
            "personality": "mischievous",
            "animations": [
                {"name": "peek-left", "frameCount": 12, "fps": 12},
                {"name": "retreat-left", "frameCount": 8, "looping": false}
            ]
        }
        """

        let manifest = try! JSONDecoder().decode(CreatureManifest.self, from: json.data(using: .utf8)!)
        let creature = manifest.toCreature()

        XCTAssertNotNil(creature)
        XCTAssertEqual(creature?.id, "gremlin")
        XCTAssertEqual(creature?.personality, .mischievous)
        XCTAssertEqual(creature?.animations.count, 2)
    }

    func testInvalidPersonalityReturnsNil() {
        let json = """
        {
            "id": "test",
            "name": "Test",
            "personality": "invalid",
            "animations": []
        }
        """

        let manifest = try! JSONDecoder().decode(CreatureManifest.self, from: json.data(using: .utf8)!)
        XCTAssertNil(manifest.toCreature())
    }
}
