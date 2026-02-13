import Foundation

/// Creature personality affecting behavior timing and patterns
public enum Personality: String, CaseIterable, Codable, Sendable {
    case shy
    case curious
    case mischievous
    case chaotic

    /// Peek duration range in seconds
    public var peekDurationRange: ClosedRange<Double> {
        switch self {
        case .shy: return 1.5...3.0
        case .curious: return 3.0...6.0
        case .mischievous: return 2.0...5.0
        case .chaotic: return 0.5...8.0
        }
    }

    /// Retreat speed multiplier (1.0 = normal)
    public var retreatSpeedMultiplier: Double {
        switch self {
        case .shy: return 1.5      // Fast
        case .curious: return 1.0  // Medium
        case .mischievous: return 1.0
        case .chaotic: return 1.2  // Slightly erratic
        }
    }

    /// Likelihood to flee from cursor (0-1)
    public var cursorSensitivity: Double {
        switch self {
        case .shy: return 0.9
        case .curious: return 0.3
        case .mischievous: return 0.5
        case .chaotic: return 0.6
        }
    }
}

/// A creature definition loaded from disk
public struct Creature: Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let personality: Personality
    public let animations: [String: Animation]

    public init(id: String, name: String, personality: Personality, animations: [String: Animation]) {
        self.id = id
        self.name = name
        self.personality = personality
        self.animations = animations
    }

    /// Get animation by name
    public func animation(named name: String) -> Animation? {
        animations[name]
    }
}

/// Creature manifest for loading from JSON
public struct CreatureManifest: Codable, Sendable {
    public let id: String
    public let name: String
    public let personality: String
    public let animations: [AnimationEntry]

    public struct AnimationEntry: Codable, Sendable {
        public let name: String
        public let frameCount: Int
        public let fps: Double?
        public let looping: Bool?
    }

    public func toCreature() -> Creature? {
        guard let personality = Personality(rawValue: personality) else { return nil }

        var anims: [String: Animation] = [:]
        for entry in animations {
            anims[entry.name] = Animation(
                name: entry.name,
                frameCount: entry.frameCount,
                fps: entry.fps ?? 12,
                looping: entry.looping ?? false
            )
        }

        return Creature(id: id, name: name, personality: personality, animations: anims)
    }
}
