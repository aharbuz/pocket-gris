import Foundation

/// How a creature's position should snap during a segment
public enum SnapMode: String, CaseIterable, Codable, Equatable, Sendable {
    case none
    case screenBottom
    case screenTop
    case windowTop
    case windowBottom
    case windowLeft
    case windowRight
    case onTopOfWindow
    case underneathWindow
}

/// A single segment connecting two adjacent waypoints
public struct SceneSegment: Codable, Equatable, Sendable {
    /// Animation to play during this segment
    public var animationName: String

    /// How long (seconds) to traverse this segment
    public var duration: TimeInterval

    /// Position snapping mode
    public var snapMode: SnapMode

    public init(animationName: String, duration: TimeInterval = 2.0, snapMode: SnapMode = .none) {
        self.animationName = animationName
        self.duration = duration
        self.snapMode = snapMode
    }
}

/// A single creature's path through a scene
public struct SceneTrack: Codable, Equatable, Sendable {
    /// Which creature plays this track
    public var creatureId: String

    /// Ordered waypoints the creature visits
    public var waypoints: [Position]

    /// Segments connecting consecutive waypoints (count == waypoints.count - 1)
    public var segments: [SceneSegment]

    /// Delay (seconds) before this track starts playing
    public var startDelay: TimeInterval

    public init(
        creatureId: String,
        waypoints: [Position] = [],
        segments: [SceneSegment] = [],
        startDelay: TimeInterval = 0
    ) {
        self.creatureId = creatureId
        self.waypoints = waypoints
        self.segments = segments
        self.startDelay = startDelay
    }

    /// Whether the track has valid structure (segments == waypoints - 1)
    public var isValid: Bool {
        waypoints.count >= 2 && segments.count == waypoints.count - 1
    }
}

/// A saved choreography containing one or more tracks
public struct Scene: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var tracks: [SceneTrack]

    public init(id: String = UUID().uuidString, name: String = "Untitled Scene", tracks: [SceneTrack] = []) {
        self.id = id
        self.name = name
        self.tracks = tracks
    }

    /// Whether the scene is playable (at least one valid track)
    public var isPlayable: Bool {
        tracks.contains(where: \.isValid)
    }
}
