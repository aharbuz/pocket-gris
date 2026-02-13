import ArgumentParser
import Foundation
import PocketGrisCore

@main
struct PocketGrisCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pocketgris",
        abstract: "Control pocket-gris creatures",
        version: PocketGrisCore.version,
        subcommands: [
            Version.self,
            Status.self,
            Trigger.self,
            Creatures.self,
            Simulate.self,
            Control.self,
            Behaviors.self,
            Test.self
        ],
        defaultSubcommand: Status.self
    )
}

// MARK: - Version

struct Version: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show version information"
    )

    func run() {
        print("pocket-gris \(PocketGrisCore.version)")
    }
}

// MARK: - Status

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show current status"
    )

    @Flag(name: .long, help: "Query GUI status via IPC")
    var gui = false

    func run() {
        let settings = Settings.load()

        if gui {
            let ipc = IPCService()
            if ipc.isGUIRunning() {
                if let response = ipc.send(IPCMessage(command: .status)) {
                    if response.success {
                        print("GUI: Running")
                        if let data = response.data {
                            for (key, value) in data.sorted(by: { $0.key < $1.key }) {
                                print("  \(key): \(value)")
                            }
                        }
                    } else {
                        print("GUI: Error - \(response.message ?? "unknown")")
                    }
                } else {
                    print("GUI: Not responding")
                }
            } else {
                print("GUI: Not running")
            }
        } else {
            print("pocket-gris status")
            print("  Enabled: \(settings.enabled)")
            print("  Interval: \(Int(settings.minInterval/60))-\(Int(settings.maxInterval/60)) minutes")
            print("  Launch at login: \(settings.launchAtLogin)")
        }
    }
}

// MARK: - Trigger

struct Trigger: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Trigger a creature appearance"
    )

    @Option(name: .long, help: "Creature ID")
    var creature: String?

    @Option(name: .long, help: "Behavior type")
    var behavior: String?

    @Option(name: .long, help: "Screen edge (left, right, top, bottom)")
    var edge: String?

    @Flag(name: .long, help: "Send to GUI via IPC")
    var gui = false

    func run() {
        if gui {
            let ipc = IPCService()
            guard ipc.isGUIRunning() else {
                print("Error: GUI is not running")
                return
            }

            let message = IPCMessage(
                command: .trigger,
                creature: creature,
                behavior: behavior,
                edge: edge
            )

            if let response = ipc.send(message) {
                if response.success {
                    print("Triggered: \(response.message ?? "ok")")
                } else {
                    print("Error: \(response.message ?? "unknown")")
                }
            } else {
                print("Error: No response from GUI")
            }
        } else {
            // CLI-only simulation
            print("Simulating trigger...")
            print("  Creature: \(creature ?? "random")")
            print("  Behavior: \(behavior ?? "peek")")
            print("  Edge: \(edge ?? "random")")
            print("(Use --gui to trigger in running app)")
        }
    }
}

// MARK: - Creatures

struct Creatures: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage creatures",
        subcommands: [CreaturesList.self],
        defaultSubcommand: CreaturesList.self
    )
}

struct CreaturesList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available creatures"
    )

    func run() {
        let spriteLoader = SpriteLoader()
        let creatures = spriteLoader.loadAllCreatures()

        if creatures.isEmpty {
            print("Available creatures:")
            print("  (No creatures loaded - add sprite folders to Resources/Sprites/)")
            print("")
            print("Expected structure:")
            print("  Resources/Sprites/<creature-id>/")
            print("    creature.json")
            print("    peek-left/frame-001.png, ...")
            print("    retreat-left/frame-001.png, ...")
        } else {
            print("Available creatures (\(creatures.count)):")
            for creature in creatures.sorted(by: { $0.id < $1.id }) {
                print("  \(creature.id): \(creature.name)")
                print("    Personality: \(creature.personality.rawValue)")
                print("    Animations: \(creature.animations.keys.sorted().joined(separator: ", "))")
            }
        }
    }
}

// MARK: - Simulate

struct Simulate: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Simulate behavior scheduling"
    )

    @Option(name: .long, help: "Simulation duration in seconds")
    var seconds: Int = 3600

    func run() {
        let settings = Settings.load()
        let random = SystemRandomSource()

        print("Simulating \(seconds) seconds of behavior scheduling...")
        print("Interval range: \(Int(settings.minInterval))-\(Int(settings.maxInterval))s")
        print("")

        var elapsed: TimeInterval = 0
        var triggers = 0

        while elapsed < TimeInterval(seconds) {
            let interval = settings.randomInterval(using: random)
            elapsed += interval
            if elapsed < TimeInterval(seconds) {
                triggers += 1
                let minutes = Int(elapsed / 60)
                let secs = Int(elapsed) % 60
                print("  [\(String(format: "%02d:%02d", minutes, secs))] Trigger #\(triggers)")
            }
        }

        print("")
        print("Total triggers in \(seconds/60) minutes: \(triggers)")
        let avgInterval = triggers > 0 ? Double(seconds) / Double(triggers) : 0
        print("Average interval: \(Int(avgInterval))s (\(String(format: "%.1f", avgInterval/60)) min)")
    }
}

// MARK: - Control

struct Control: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Control the running app"
    )

    @Argument(help: "Action: enable, disable, cancel")
    var action: String

    func run() {
        let command: IPCCommand
        switch action.lowercased() {
        case "enable":
            command = .enable
        case "disable":
            command = .disable
        case "cancel":
            command = .cancel
        default:
            print("Unknown action: \(action)")
            print("Valid actions: enable, disable, cancel")
            return
        }

        let ipc = IPCService()
        guard ipc.isGUIRunning() else {
            print("Error: GUI is not running")
            return
        }

        if let response = ipc.send(IPCMessage(command: command)) {
            if response.success {
                print("OK: \(response.message ?? action)")
            } else {
                print("Error: \(response.message ?? "unknown")")
            }
        } else {
            print("Error: No response from GUI")
        }
    }
}

// MARK: - Behaviors

struct Behaviors: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List available behaviors",
        subcommands: [BehaviorsList.self],
        defaultSubcommand: BehaviorsList.self
    )
}

struct BehaviorsList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available behavior types"
    )

    func run() {
        print("Available behaviors:")
        for behavior in BehaviorRegistry.shared.allBehaviors() {
            print("  \(behavior.type.rawValue)")
            print("    Required animations: \(behavior.requiredAnimations.joined(separator: ", "))")
        }
    }
}

// MARK: - Test

struct Test: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Test behaviors headlessly",
        subcommands: [TestBehavior.self],
        defaultSubcommand: TestBehavior.self
    )
}

struct TestBehavior: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "behavior",
        abstract: "Run a behavior headlessly and output JSON state"
    )

    @Argument(help: "Behavior type (peek, traverse, stationary, climber, cursorReactive)")
    var behaviorType: String

    @Option(name: .long, help: "Creature ID (default: first available)")
    var creature: String?

    @Option(name: .long, help: "Number of frames to simulate (default: 100)")
    var frames: Int = 100

    @Option(name: .long, help: "Frame delta time in seconds (default: 0.016667, ~60fps)")
    var deltaTime: Double = 1.0 / 60.0

    @Option(name: .long, help: "Random seed for reproducible output (default: 42)")
    var seed: UInt64 = 42

    @Option(name: .long, help: "Screen width (default: 1920)")
    var screenWidth: Double = 1920

    @Option(name: .long, help: "Screen height (default: 1080)")
    var screenHeight: Double = 1080

    @Flag(name: .long, help: "Output only frame summaries, not full state")
    var compact = false

    func run() throws {
        // Parse behavior type
        guard let type = BehaviorType(rawValue: behaviorType) else {
            print("Error: Unknown behavior type '\(behaviorType)'")
            print("Valid types: \(BehaviorType.allCases.map(\.rawValue).joined(separator: ", "))")
            throw ExitCode.failure
        }

        // Get behavior
        guard let behavior = BehaviorRegistry.shared.behavior(for: type) else {
            print("Error: Behavior '\(type.rawValue)' not registered")
            throw ExitCode.failure
        }

        // Load creature
        let spriteLoader = SpriteLoader()
        let creatures = spriteLoader.loadAllCreatures()

        guard !creatures.isEmpty else {
            print("Error: No creatures found in Resources/Sprites/")
            throw ExitCode.failure
        }

        let selectedCreature: Creature
        if let creatureId = creature {
            guard let found = creatures.first(where: { $0.id == creatureId }) else {
                print("Error: Creature '\(creatureId)' not found")
                print("Available: \(creatures.map(\.id).joined(separator: ", "))")
                throw ExitCode.failure
            }
            selectedCreature = found
        } else {
            selectedCreature = creatures[0]
        }

        // Verify creature has required animations
        let missing = behavior.requiredAnimations.filter { selectedCreature.animations[$0] == nil }
        if !missing.isEmpty {
            print("Warning: Creature '\(selectedCreature.id)' missing animations: \(missing.joined(separator: ", "))")
        }

        // Set up test environment
        let random = SeededRandomSource(seed: seed)
        let screenBounds = ScreenRect(x: 0, y: 0, width: screenWidth, height: screenHeight)
        var currentTime: TimeInterval = 0

        // Create initial context
        var context = BehaviorContext(
            creature: selectedCreature,
            screenBounds: screenBounds,
            currentTime: currentTime
        )

        // Start behavior
        var state = behavior.start(context: context, random: random)

        // Output structure
        var output = TestOutput(
            behaviorType: type.rawValue,
            creature: selectedCreature.id,
            seed: seed,
            deltaTime: deltaTime,
            screenBounds: BoundsOutput(width: screenWidth, height: screenHeight),
            frames: []
        )

        // Simulate frames
        for frameIndex in 0..<frames {
            let events = behavior.update(state: &state, context: context, deltaTime: deltaTime)

            let frameOutput = FrameOutput(
                frame: frameIndex,
                time: currentTime,
                phase: state.phase.rawValue,
                position: PositionOutput(x: state.position.x, y: state.position.y),
                edge: state.edge?.rawValue,
                animation: state.animation.map { AnimationOutput(
                    name: $0.animation.name,
                    frame: $0.currentFrame,
                    complete: $0.isComplete
                )},
                events: events.map { eventDescription($0) },
                metadata: state.metadata.dictionaryRepresentation
            )

            output.frames.append(frameOutput)

            // Stop if behavior completed
            if state.phase == .complete {
                break
            }

            // Advance time
            currentTime += deltaTime
            context = BehaviorContext(
                creature: selectedCreature,
                screenBounds: screenBounds,
                currentTime: currentTime
            )
        }

        // Output JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if compact {
            // Compact output: summary only
            let summary = TestSummary(
                behaviorType: output.behaviorType,
                creature: output.creature,
                totalFrames: output.frames.count,
                finalPhase: output.frames.last?.phase ?? "unknown",
                completed: state.phase == .complete,
                phases: extractPhaseTransitions(output.frames)
            )
            let data = try encoder.encode(summary)
            print(String(data: data, encoding: .utf8)!)
        } else {
            let data = try encoder.encode(output)
            print(String(data: data, encoding: .utf8)!)
        }
    }

    private func eventDescription(_ event: BehaviorEvent) -> String {
        switch event {
        case .started(let type): return "started:\(type.rawValue)"
        case .phaseChanged(let phase): return "phaseChanged:\(phase.rawValue)"
        case .positionChanged(let pos): return "positionChanged:\(pos.x),\(pos.y)"
        case .animationFrameChanged(let frame): return "animationFrameChanged:\(frame)"
        case .completed: return "completed"
        case .cancelled: return "cancelled"
        }
    }

    private func extractPhaseTransitions(_ frames: [FrameOutput]) -> [PhaseTransition] {
        var transitions: [PhaseTransition] = []
        var lastPhase = ""
        for frame in frames {
            if frame.phase != lastPhase {
                transitions.append(PhaseTransition(frame: frame.frame, time: frame.time, phase: frame.phase))
                lastPhase = frame.phase
            }
        }
        return transitions
    }
}

// MARK: - Test Output Types

private struct TestOutput: Encodable {
    let behaviorType: String
    let creature: String
    let seed: UInt64
    let deltaTime: Double
    let screenBounds: BoundsOutput
    var frames: [FrameOutput]
}

private struct BoundsOutput: Encodable {
    let width: Double
    let height: Double
}

private struct FrameOutput: Encodable {
    let frame: Int
    let time: Double
    let phase: String
    let position: PositionOutput
    let edge: String?
    let animation: AnimationOutput?
    let events: [String]
    let metadata: [String: String]?
}

private struct PositionOutput: Encodable {
    let x: Double
    let y: Double
}

private struct AnimationOutput: Encodable {
    let name: String
    let frame: Int
    let complete: Bool
}

private struct TestSummary: Encodable {
    let behaviorType: String
    let creature: String
    let totalFrames: Int
    let finalPhase: String
    let completed: Bool
    let phases: [PhaseTransition]
}

private struct PhaseTransition: Encodable {
    let frame: Int
    let time: Double
    let phase: String
}
