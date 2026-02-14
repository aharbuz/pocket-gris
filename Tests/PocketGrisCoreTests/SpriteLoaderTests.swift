import XCTest
@testable import PocketGrisCore

final class SpriteLoaderTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sprite-loader-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        super.tearDown()
    }

    func testSpriteLoaderInitWithCustomPath() {
        let path = URL(fileURLWithPath: "/tmp/test-sprites")
        let loader = SpriteLoader(resourcesPath: path)
        XCTAssertNotNil(loader)
    }

    func testLoadCreaturesFromEmptyDirectory() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let loader = SpriteLoader(resourcesPath: tempDir)
        let creatures = loader.loadAllCreatures()

        XCTAssertEqual(creatures.count, 0)
    }

    func testLoadCreatureWithManifest() throws {
        // Create temp directory with creature manifest
        let creatureDir = tempDir.appendingPathComponent("test-creature")
        let animDir = creatureDir.appendingPathComponent("peek-left")

        try FileManager.default.createDirectory(at: animDir, withIntermediateDirectories: true)

        // Create manifest
        let manifest = """
        {
          "id": "test-creature",
          "name": "Test Creature",
          "personality": "curious",
          "animations": [
            {"name": "peek-left", "frameCount": 3, "fps": 12, "looping": false}
          ]
        }
        """
        try manifest.write(to: creatureDir.appendingPathComponent("creature.json"), atomically: true, encoding: .utf8)

        // Create dummy frame files
        for i in 1...3 {
            let framePath = animDir.appendingPathComponent("frame-\(String(format: "%03d", i)).png")
            FileManager.default.createFile(atPath: framePath.path, contents: Data())
        }

        let loader = SpriteLoader(resourcesPath: tempDir)
        let creatures = loader.loadAllCreatures()

        XCTAssertEqual(creatures.count, 1)
        XCTAssertEqual(creatures.first?.id, "test-creature")
        XCTAssertEqual(creatures.first?.name, "Test Creature")

        // Verify frame paths are cached
        let framePath = loader.framePath(creature: "test-creature", animation: "peek-left", frame: 0)
        XCTAssertNotNil(framePath)
        XCTAssertTrue(framePath?.contains("frame-001.png") ?? false)
    }

    func testFramePathOutOfBounds() throws {
        let creatureDir = tempDir.appendingPathComponent("test-creature")
        let animDir = creatureDir.appendingPathComponent("peek-left")

        try FileManager.default.createDirectory(at: animDir, withIntermediateDirectories: true)

        let manifest = """
        {
          "id": "test-creature",
          "name": "Test",
          "personality": "curious",
          "animations": [{"name": "peek-left", "frameCount": 2, "fps": 12, "looping": false}]
        }
        """
        try manifest.write(to: creatureDir.appendingPathComponent("creature.json"), atomically: true, encoding: .utf8)

        for i in 1...2 {
            let framePath = animDir.appendingPathComponent("frame-\(String(format: "%03d", i)).png")
            FileManager.default.createFile(atPath: framePath.path, contents: Data())
        }

        let loader = SpriteLoader(resourcesPath: tempDir)
        _ = loader.loadAllCreatures()

        // Frame index out of bounds should return nil
        let framePath = loader.framePath(creature: "test-creature", animation: "peek-left", frame: 10)
        XCTAssertNil(framePath)
    }

    func testAllFramePaths() throws {
        let creatureDir = tempDir.appendingPathComponent("test-creature")
        let animDir = creatureDir.appendingPathComponent("idle")

        try FileManager.default.createDirectory(at: animDir, withIntermediateDirectories: true)

        let manifest = """
        {
          "id": "test-creature",
          "name": "Test",
          "personality": "shy",
          "animations": [{"name": "idle", "frameCount": 4, "fps": 6, "looping": true}]
        }
        """
        try manifest.write(to: creatureDir.appendingPathComponent("creature.json"), atomically: true, encoding: .utf8)

        for i in 1...4 {
            let framePath = animDir.appendingPathComponent("frame-\(String(format: "%03d", i)).png")
            FileManager.default.createFile(atPath: framePath.path, contents: Data())
        }

        let loader = SpriteLoader(resourcesPath: tempDir)
        _ = loader.loadAllCreatures()

        let allPaths = loader.allFramePaths(creature: "test-creature", animation: "idle")
        XCTAssertEqual(allPaths?.count, 4)
    }
}
