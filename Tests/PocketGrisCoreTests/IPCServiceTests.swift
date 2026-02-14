import XCTest
@testable import PocketGrisCore

final class IPCServiceTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ipc-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testInitCreatesDirectory() {
        let ipcDir = tempDir.appendingPathComponent("ipc")
        _ = IPCService(directory: ipcDir)

        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: ipcDir.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testInitSetsRestrictedPermissions() {
        let ipcDir = tempDir.appendingPathComponent("ipc")
        _ = IPCService(directory: ipcDir)

        let attrs = try? FileManager.default.attributesOfItem(atPath: ipcDir.path)
        let permissions = attrs?[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o700)
    }

    // MARK: - IPCMessage

    func testIPCMessageEncoding() throws {
        let message = IPCMessage(command: .trigger, creature: "gris", behavior: "peek", edge: "left")
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(IPCMessage.self, from: data)

        XCTAssertEqual(decoded.command, .trigger)
        XCTAssertEqual(decoded.creature, "gris")
        XCTAssertEqual(decoded.behavior, "peek")
        XCTAssertEqual(decoded.edge, "left")
    }

    func testIPCMessageWithNilFields() throws {
        let message = IPCMessage(command: .status)
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(IPCMessage.self, from: data)

        XCTAssertEqual(decoded.command, .status)
        XCTAssertNil(decoded.creature)
        XCTAssertNil(decoded.behavior)
        XCTAssertNil(decoded.edge)
    }

    func testIPCMessageTimestamp() {
        let before = Date().timeIntervalSinceReferenceDate
        let message = IPCMessage(command: .trigger)
        let after = Date().timeIntervalSinceReferenceDate

        XCTAssertGreaterThanOrEqual(message.timestamp, before)
        XCTAssertLessThanOrEqual(message.timestamp, after)
    }

    // MARK: - IPCResponse

    func testIPCResponseEncoding() throws {
        let response = IPCResponse(success: true, message: "OK", data: ["status": "running"])
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(IPCResponse.self, from: data)

        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.message, "OK")
        XCTAssertEqual(decoded.data?["status"], "running")
    }

    func testIPCResponseFailure() throws {
        let response = IPCResponse(success: false, message: "Not running")
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(IPCResponse.self, from: data)

        XCTAssertFalse(decoded.success)
        XCTAssertEqual(decoded.message, "Not running")
        XCTAssertNil(decoded.data)
    }

    // MARK: - IPCCommand

    func testAllIPCCommandsCodable() throws {
        let commands: [IPCCommand] = [.trigger, .enable, .disable, .cancel, .status]
        for command in commands {
            let data = try JSONEncoder().encode(command)
            let decoded = try JSONDecoder().decode(IPCCommand.self, from: data)
            XCTAssertEqual(decoded, command)
        }
    }

    func testIPCCommandRawValues() {
        XCTAssertEqual(IPCCommand.trigger.rawValue, "trigger")
        XCTAssertEqual(IPCCommand.enable.rawValue, "enable")
        XCTAssertEqual(IPCCommand.disable.rawValue, "disable")
        XCTAssertEqual(IPCCommand.cancel.rawValue, "cancel")
        XCTAssertEqual(IPCCommand.status.rawValue, "status")
    }

    // MARK: - GUI Running Marker

    func testMarkGUIRunningCreatesMarker() {
        let ipcDir = tempDir.appendingPathComponent("ipc")
        let service = IPCService(directory: ipcDir)

        XCTAssertFalse(service.isGUIRunning())

        service.markGUIRunning(true)
        XCTAssertTrue(service.isGUIRunning())

        service.markGUIRunning(false)
        XCTAssertFalse(service.isGUIRunning())
    }

    func testMarkGUIRunningIdempotent() {
        let ipcDir = tempDir.appendingPathComponent("ipc")
        let service = IPCService(directory: ipcDir)

        service.markGUIRunning(true)
        service.markGUIRunning(true) // Should not fail
        XCTAssertTrue(service.isGUIRunning())

        service.markGUIRunning(false)
        service.markGUIRunning(false) // Should not fail
        XCTAssertFalse(service.isGUIRunning())
    }

    // MARK: - Send Without Listener

    func testSendWithoutListenerTimesOut() {
        let ipcDir = tempDir.appendingPathComponent("ipc")
        let service = IPCService(directory: ipcDir)
        let message = IPCMessage(command: .status)

        // Use a very short timeout to avoid blocking tests
        let response = service.send(message, timeout: 0.2)

        XCTAssertNotNil(response)
        XCTAssertFalse(response!.success)
        XCTAssertTrue(response!.message?.contains("Timeout") ?? false)
    }

    // MARK: - Async Send Without Listener

    func testAsyncSendWithoutListenerTimesOut() async {
        let ipcDir = tempDir.appendingPathComponent("ipc")
        let service = IPCService(directory: ipcDir)
        let message = IPCMessage(command: .status)

        let response = await service.send(message, timeout: 0.2)

        XCTAssertNotNil(response)
        XCTAssertFalse(response!.success)
        XCTAssertTrue(response!.message?.contains("Timeout") ?? false)
    }

    // MARK: - Start/Stop Listening

    func testStartListeningCreatesCommandFile() {
        let ipcDir = tempDir.appendingPathComponent("ipc")
        let service = IPCService(directory: ipcDir)
        let commandPath = ipcDir.appendingPathComponent("command.json")

        service.startListening { message in
            IPCResponse(success: true)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: commandPath.path))

        service.stopListening()
    }

    func testStopListeningDoesNotCrashWhenNotListening() {
        let ipcDir = tempDir.appendingPathComponent("ipc")
        let service = IPCService(directory: ipcDir)

        // Should not crash
        service.stopListening()
        service.stopListening()
    }

    func testStartListeningTwiceDoesNotLeak() {
        let ipcDir = tempDir.appendingPathComponent("ipc")
        let service = IPCService(directory: ipcDir)

        service.startListening { _ in IPCResponse(success: true) }
        service.startListening { _ in IPCResponse(success: false) }

        // Just verify no crash — second call should clean up first monitor
        service.stopListening()
    }

    // MARK: - Two-Service Communication

    func testSendAndReceive() {
        let ipcDir = tempDir.appendingPathComponent("ipc")
        let listener = IPCService(directory: ipcDir)
        let sender = IPCService(directory: ipcDir)

        let expectation = XCTestExpectation(description: "Listener receives message")

        listener.startListening { message in
            XCTAssertEqual(message.command, .trigger)
            XCTAssertEqual(message.creature, "gris")
            expectation.fulfill()
            return IPCResponse(success: true, message: "triggered")
        }

        // Give the file monitor a moment to start
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            let response = sender.send(
                IPCMessage(command: .trigger, creature: "gris"),
                timeout: 3.0
            )
            XCTAssertNotNil(response)
            XCTAssertTrue(response?.success ?? false)
            XCTAssertEqual(response?.message, "triggered")
        }

        wait(for: [expectation], timeout: 5.0)
        listener.stopListening()
    }
}
