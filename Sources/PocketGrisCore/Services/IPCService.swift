import Foundation
import Synchronization

/// IPC commands from CLI to GUI
public enum IPCCommand: String, Codable, Sendable {
    case trigger
    case enable
    case disable
    case cancel
    case status
}

/// IPC message structure
public struct IPCMessage: Codable, Sendable {
    public let command: IPCCommand
    public let creature: String?
    public let behavior: String?
    public let edge: String?
    public let timestamp: TimeInterval

    public init(
        command: IPCCommand,
        creature: String? = nil,
        behavior: String? = nil,
        edge: String? = nil
    ) {
        self.command = command
        self.creature = creature
        self.behavior = behavior
        self.edge = edge
        self.timestamp = Date().timeIntervalSinceReferenceDate
    }
}

/// IPC response from GUI to CLI
public struct IPCResponse: Codable, Sendable {
    public let success: Bool
    public let message: String?
    public let data: [String: String]?

    public init(success: Bool, message: String? = nil, data: [String: String]? = nil) {
        self.success = success
        self.message = message
        self.data = data
    }
}

/// File-based IPC service
public final class IPCService: Sendable {
    // DispatchSourceFileSystemObject and closure are not Sendable but safe behind Mutex
    private struct State: @unchecked Sendable {
        var fileMonitor: DispatchSourceFileSystemObject?
        var messageHandler: (@Sendable (IPCMessage) -> IPCResponse)?
    }

    private let commandPath: URL
    private let responsePath: URL
    private let state: Mutex<State>

    public convenience init() {
        // Use a per-user subdirectory with restricted permissions instead of bare /tmp
        let tmpDir = FileManager.default.temporaryDirectory
        let ipcDir = tmpDir.appendingPathComponent("pocket-gris-ipc", isDirectory: true)
        self.init(directory: ipcDir)
    }

    /// Internal initializer for test isolation — accepts a custom IPC directory.
    init(directory: URL) {
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        self.commandPath = directory.appendingPathComponent("command.json")
        self.responsePath = directory.appendingPathComponent("response.json")
        self.state = Mutex(State())
    }

    // MARK: - CLI Side (Send)

    /// Synchronous send — blocks the calling thread while polling for a response.
    public func send(_ message: IPCMessage, timeout: TimeInterval = 5.0) -> IPCResponse? {
        state.withLock { _ in
            // Clean up old response
            try? FileManager.default.removeItem(at: self.responsePath)

            // Write command
            guard let data = try? JSONEncoder().encode(message) else {
                return IPCResponse(success: false, message: "Failed to encode message")
            }

            do {
                try data.write(to: self.commandPath)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: self.commandPath.path)
            } catch {
                return IPCResponse(success: false, message: "Failed to write command: \(error)")
            }

            // Wait for response
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if let responseData = try? Data(contentsOf: self.responsePath),
                   let response = try? JSONDecoder().decode(IPCResponse.self, from: responseData) {
                    try? FileManager.default.removeItem(at: self.responsePath)
                    return response
                }
                Thread.sleep(forTimeInterval: 0.1)
            }

            return IPCResponse(success: false, message: "Timeout waiting for response")
        }
    }

    /// Async send — suspends instead of blocking while polling for a response.
    public func send(_ message: IPCMessage, timeout: TimeInterval = 5.0) async -> IPCResponse? {
        // Perform file writes synchronously under the lock (avoids blocking in async context)
        if let earlyReturn = writeCommand(message) {
            return earlyReturn
        }

        // Poll for response asynchronously (no lock needed — only this call reads responsePath)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let responseData = try? Data(contentsOf: responsePath),
               let response = try? JSONDecoder().decode(IPCResponse.self, from: responseData) {
                try? FileManager.default.removeItem(at: responsePath)
                return response
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        return IPCResponse(success: false, message: "Timeout waiting for response")
    }

    /// Writes the command file under the lock. Returns an IPCResponse on failure, nil on success.
    private func writeCommand(_ message: IPCMessage) -> IPCResponse? {
        state.withLock { _ -> IPCResponse? in
            // Clean up old response
            try? FileManager.default.removeItem(at: self.responsePath)

            // Encode message
            guard let data = try? JSONEncoder().encode(message) else {
                return IPCResponse(success: false, message: "Failed to encode message")
            }

            // Write command
            do {
                try data.write(to: self.commandPath)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: self.commandPath.path)
            } catch {
                return IPCResponse(success: false, message: "Failed to write command: \(error)")
            }

            return nil // success — no early return needed
        }
    }

    // MARK: - GUI Side (Listen)

    public func startListening(handler: @escaping @Sendable (IPCMessage) -> IPCResponse) {
        // Clean up any existing monitor to avoid leaking file descriptors
        stopListening()

        state.withLock { s in
            s.messageHandler = handler
        }

        // Create command file if needed
        if !FileManager.default.fileExists(atPath: commandPath.path) {
            FileManager.default.createFile(atPath: commandPath.path, contents: nil)
        }

        // Monitor for changes
        let fd = open(commandPath.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.handleIncomingMessage()
        }

        source.setCancelHandler {
            close(fd)
        }

        state.withLock { s in
            s.fileMonitor = source
        }
        source.resume()
    }

    public func stopListening() {
        let monitor = state.withLock { s -> DispatchSourceFileSystemObject? in
            let m = s.fileMonitor
            s.fileMonitor = nil
            return m
        }
        monitor?.cancel()
    }

    private func handleIncomingMessage() {
        let handler = state.withLock { $0.messageHandler }

        guard let handler = handler,
              let data = try? Data(contentsOf: commandPath),
              !data.isEmpty,
              let message = try? JSONDecoder().decode(IPCMessage.self, from: data) else {
            return
        }

        // Clear command file
        try? "".write(to: commandPath, atomically: true, encoding: .utf8)

        // Process and respond
        let response = handler(message)

        if let responseData = try? JSONEncoder().encode(response) {
            try? responseData.write(to: responsePath)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: responsePath.path)
        }
    }

    // MARK: - Status Check

    public func isGUIRunning() -> Bool {
        // Check if GUI is listening by looking for recent response capability
        let marker = commandPath.deletingLastPathComponent()
            .appendingPathComponent("running")

        return FileManager.default.fileExists(atPath: marker.path)
    }

    public func markGUIRunning(_ running: Bool) {
        let marker = commandPath.deletingLastPathComponent()
            .appendingPathComponent("running")

        if running {
            FileManager.default.createFile(atPath: marker.path, contents: nil)
        } else {
            try? FileManager.default.removeItem(at: marker)
        }
    }
}
