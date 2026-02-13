import XCTest
@testable import PocketGrisCore

final class SceneTests: XCTestCase {

    // MARK: - Scene Types

    func testSceneSegmentDefaults() {
        let segment = SceneSegment(animationName: "walk-left")
        XCTAssertEqual(segment.animationName, "walk-left")
        XCTAssertEqual(segment.duration, 2.0)
        XCTAssertEqual(segment.snapMode, .none)
    }

    func testSceneTrackValidation() {
        // Empty track is structurally correct but not playable
        let empty = SceneTrack(creatureId: "gris")
        XCTAssertFalse(empty.isValid)

        // Single waypoint is structurally correct but not playable
        let single = SceneTrack(
            creatureId: "gris",
            waypoints: [Position(x: 0, y: 0)]
        )
        XCTAssertFalse(single.isValid)

        // Two waypoints, one segment = valid
        let valid = SceneTrack(
            creatureId: "gris",
            waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 100)],
            segments: [SceneSegment(animationName: "walk-left")]
        )
        XCTAssertTrue(valid.isValid)
    }

    // MARK: - SceneTrack Init Validation

    func testSceneTrackInitValidConstruction() {
        // 0 waypoints, 0 segments
        let empty = SceneTrack(creatureId: "gris")
        XCTAssertEqual(empty.waypoints.count, 0)
        XCTAssertEqual(empty.segments.count, 0)

        // 1 waypoint, 0 segments
        let single = SceneTrack(creatureId: "gris", waypoints: [Position(x: 0, y: 0)])
        XCTAssertEqual(single.waypoints.count, 1)
        XCTAssertEqual(single.segments.count, 0)

        // 2 waypoints, 1 segment
        let two = SceneTrack(
            creatureId: "gris",
            waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 100)],
            segments: [SceneSegment(animationName: "walk-left")]
        )
        XCTAssertEqual(two.waypoints.count, 2)
        XCTAssertEqual(two.segments.count, 1)

        // 3 waypoints, 2 segments
        let three = SceneTrack(
            creatureId: "gris",
            waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 100), Position(x: 200, y: 200)],
            segments: [
                SceneSegment(animationName: "walk-left"),
                SceneSegment(animationName: "walk-right")
            ]
        )
        XCTAssertEqual(three.waypoints.count, 3)
        XCTAssertEqual(three.segments.count, 2)
    }

    func testSceneTrackDecodingRejectsMismatchedCounts() throws {
        // 2 waypoints but 2 segments (should be 1)
        let json = """
        {
            "creatureId": "gris",
            "waypoints": [{"x": 0, "y": 0}, {"x": 100, "y": 100}],
            "segments": [
                {"animationName": "walk-left", "duration": 2.0, "snapMode": "none"},
                {"animationName": "idle", "duration": 1.0, "snapMode": "none"}
            ],
            "startDelay": 0
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(SceneTrack.self, from: data)) { error in
            guard case DecodingError.dataCorrupted(let context) = error else {
                XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
                return
            }
            XCTAssertTrue(context.debugDescription.contains("invariant violated"))
        }
    }

    func testSceneTrackDecodingRejectsTooFewSegments() throws {
        // 3 waypoints but 0 segments (should be 2)
        let json = """
        {
            "creatureId": "gris",
            "waypoints": [{"x": 0, "y": 0}, {"x": 100, "y": 100}, {"x": 200, "y": 200}],
            "segments": [],
            "startDelay": 0
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(SceneTrack.self, from: data)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
                return
            }
        }
    }

    func testSceneTrackDecodingRejectsSegmentsWithNoWaypoints() throws {
        // 0 waypoints but 1 segment (should be 0)
        let json = """
        {
            "creatureId": "gris",
            "waypoints": [],
            "segments": [{"animationName": "walk-left", "duration": 2.0, "snapMode": "none"}],
            "startDelay": 0
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(SceneTrack.self, from: data)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
                return
            }
        }
    }

    func testSceneTrackDecodingAcceptsValidData() throws {
        // Empty track
        let emptyJson = """
        {"creatureId": "gris", "waypoints": [], "segments": [], "startDelay": 0}
        """
        let empty = try JSONDecoder().decode(SceneTrack.self, from: emptyJson.data(using: .utf8)!)
        XCTAssertEqual(empty.creatureId, "gris")

        // Single waypoint
        let singleJson = """
        {"creatureId": "gris", "waypoints": [{"x": 0, "y": 0}], "segments": [], "startDelay": 0}
        """
        let single = try JSONDecoder().decode(SceneTrack.self, from: singleJson.data(using: .utf8)!)
        XCTAssertEqual(single.waypoints.count, 1)

        // Two waypoints, one segment
        let validJson = """
        {
            "creatureId": "gris",
            "waypoints": [{"x": 0, "y": 0}, {"x": 100, "y": 100}],
            "segments": [{"animationName": "walk-left", "duration": 2.0, "snapMode": "none"}],
            "startDelay": 0
        }
        """
        let valid = try JSONDecoder().decode(SceneTrack.self, from: validJson.data(using: .utf8)!)
        XCTAssertEqual(valid.waypoints.count, 2)
        XCTAssertEqual(valid.segments.count, 1)
    }

    func testSceneDecodingSkipsInvalidTracks() throws {
        // A Scene with one valid track and one invalid track in JSON
        // The Scene itself should fail to decode because the invalid track throws
        let json = """
        {
            "id": "test",
            "name": "Mixed Scene",
            "tracks": [
                {
                    "creatureId": "gris",
                    "waypoints": [{"x": 0, "y": 0}, {"x": 100, "y": 100}],
                    "segments": [{"animationName": "walk-left", "duration": 2.0, "snapMode": "none"}],
                    "startDelay": 0
                },
                {
                    "creatureId": "gris",
                    "waypoints": [{"x": 0, "y": 0}],
                    "segments": [{"animationName": "walk-left", "duration": 2.0, "snapMode": "none"}],
                    "startDelay": 0
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Scene.self, from: data))
    }

    func testScenePlayability() {
        // Empty scene is not playable
        let empty = Scene(name: "Empty")
        XCTAssertFalse(empty.isPlayable)

        // Scene with invalid track is not playable
        let invalidTrack = Scene(
            name: "Bad",
            tracks: [SceneTrack(creatureId: "gris")]
        )
        XCTAssertFalse(invalidTrack.isPlayable)

        // Scene with valid track is playable
        let scene = Scene(
            name: "Good",
            tracks: [
                SceneTrack(
                    creatureId: "gris",
                    waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 100)],
                    segments: [SceneSegment(animationName: "walk-left")]
                )
            ]
        )
        XCTAssertTrue(scene.isPlayable)
    }

    // MARK: - Serialization

    func testSceneSegmentRoundTrip() throws {
        let segment = SceneSegment(animationName: "walk-left", duration: 3.5, snapMode: .screenBottom)
        let data = try JSONEncoder().encode(segment)
        let decoded = try JSONDecoder().decode(SceneSegment.self, from: data)
        XCTAssertEqual(segment, decoded)
    }

    func testSceneTrackRoundTrip() throws {
        let track = SceneTrack(
            creatureId: "gris",
            waypoints: [
                Position(x: 10, y: 20),
                Position(x: 300, y: 400),
                Position(x: 500, y: 100)
            ],
            segments: [
                SceneSegment(animationName: "walk-left", duration: 2.0, snapMode: .none),
                SceneSegment(animationName: "idle", duration: 1.5, snapMode: .screenBottom)
            ],
            startDelay: 0.5
        )
        let data = try JSONEncoder().encode(track)
        let decoded = try JSONDecoder().decode(SceneTrack.self, from: data)
        XCTAssertEqual(track, decoded)
    }

    func testSceneRoundTrip() throws {
        let scene = Scene(
            id: "test-scene",
            name: "My Scene",
            tracks: [
                SceneTrack(
                    creatureId: "gris",
                    waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 100)],
                    segments: [SceneSegment(animationName: "walk-left", duration: 2.0)],
                    startDelay: 0
                ),
                SceneTrack(
                    creatureId: "pig-gnome",
                    waypoints: [Position(x: 500, y: 500), Position(x: 200, y: 300)],
                    segments: [SceneSegment(animationName: "walk-right", duration: 3.0, snapMode: .windowTop)],
                    startDelay: 1.0
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(scene)
        let decoded = try JSONDecoder().decode(Scene.self, from: data)
        XCTAssertEqual(scene, decoded)
    }

    func testSnapModeAllCases() throws {
        for mode in SnapMode.allCases {
            let segment = SceneSegment(animationName: "test", snapMode: mode)
            let data = try JSONEncoder().encode(segment)
            let decoded = try JSONDecoder().decode(SceneSegment.self, from: data)
            XCTAssertEqual(decoded.snapMode, mode)
        }
    }

    // MARK: - Scene Storage

    func testSceneStorageSaveAndLoad() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = SceneStorage(directory: tempDir)

        let scene = Scene(
            id: "test-1",
            name: "Test Scene",
            tracks: [
                SceneTrack(
                    creatureId: "gris",
                    waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 100)],
                    segments: [SceneSegment(animationName: "walk-left")]
                )
            ]
        )

        try storage.save(scene: scene)

        let loaded = storage.load(id: "test-1")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded, scene)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSceneStorageLoadAll() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = SceneStorage(directory: tempDir)

        let scene1 = Scene(id: "s1", name: "Alpha Scene", tracks: [])
        let scene2 = Scene(id: "s2", name: "Beta Scene", tracks: [])

        try storage.save(scene: scene1)
        try storage.save(scene: scene2)

        let all = storage.loadAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].name, "Alpha Scene")  // sorted by name
        XCTAssertEqual(all[1].name, "Beta Scene")

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSceneStorageDelete() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = SceneStorage(directory: tempDir)

        let scene = Scene(id: "to-delete", name: "Delete Me", tracks: [])
        try storage.save(scene: scene)

        XCTAssertNotNil(storage.load(id: "to-delete"))

        try storage.delete(id: "to-delete")
        XCTAssertNil(storage.load(id: "to-delete"))

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSceneStorageOverwrite() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = SceneStorage(directory: tempDir)

        var scene = Scene(id: "overwrite-test", name: "Original", tracks: [])
        try storage.save(scene: scene)

        scene.name = "Updated"
        try storage.save(scene: scene)

        let loaded = storage.load(id: "overwrite-test")
        XCTAssertEqual(loaded?.name, "Updated")

        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Validation

    func testSceneValidation() {
        let storage = SceneStorage()
        let creatures = [
            Creature(
                id: "gris",
                name: "Gris",
                personality: .curious,
                animations: [
                    "walk-left": Animation(name: "walk-left", frameCount: 10),
                    "idle": Animation(name: "idle", frameCount: 4, looping: true)
                ]
            )
        ]

        // Valid scene
        let valid = Scene(
            id: "v",
            name: "Valid",
            tracks: [
                SceneTrack(
                    creatureId: "gris",
                    waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 100)],
                    segments: [SceneSegment(animationName: "walk-left")]
                )
            ]
        )
        XCTAssertTrue(storage.validate(scene: valid, creatures: creatures).isEmpty)

        // Missing creature
        let missingCreature = Scene(
            id: "mc",
            name: "Missing Creature",
            tracks: [
                SceneTrack(
                    creatureId: "unknown",
                    waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 100)],
                    segments: [SceneSegment(animationName: "walk-left")]
                )
            ]
        )
        let issues1 = storage.validate(scene: missingCreature, creatures: creatures)
        XCTAssertFalse(issues1.isEmpty)
        XCTAssertTrue(issues1[0].contains("not found"))

        // Missing animation
        let missingAnim = Scene(
            id: "ma",
            name: "Missing Anim",
            tracks: [
                SceneTrack(
                    creatureId: "gris",
                    waypoints: [Position(x: 0, y: 0), Position(x: 100, y: 100)],
                    segments: [SceneSegment(animationName: "dance")]
                )
            ]
        )
        let issues2 = storage.validate(scene: missingAnim, creatures: creatures)
        XCTAssertFalse(issues2.isEmpty)
        XCTAssertTrue(issues2[0].contains("animation"))
    }

    // MARK: - Segment/Waypoint Invariant

    func testSegmentWaypointInvariant() {
        // Build a track incrementally and verify invariant
        var track = SceneTrack(creatureId: "gris")

        // Add waypoints and segments maintaining the invariant
        track.waypoints.append(Position(x: 0, y: 0))
        XCTAssertFalse(track.isValid)  // Need at least 2 waypoints

        track.waypoints.append(Position(x: 100, y: 100))
        track.segments.append(SceneSegment(animationName: "walk-left"))
        XCTAssertTrue(track.isValid)
        XCTAssertEqual(track.segments.count, track.waypoints.count - 1)

        track.waypoints.append(Position(x: 200, y: 50))
        track.segments.append(SceneSegment(animationName: "walk-right"))
        XCTAssertTrue(track.isValid)
        XCTAssertEqual(track.segments.count, track.waypoints.count - 1)
    }
}
