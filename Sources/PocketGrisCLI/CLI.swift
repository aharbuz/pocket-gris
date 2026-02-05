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
            Behaviors.self
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
