import Foundation

/// Screen position in points
public struct Position: Equatable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Position(x: 0, y: 0)

    public func distance(to other: Position) -> Double {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }

    public func offset(dx: Double = 0, dy: Double = 0) -> Position {
        Position(x: x + dx, y: y + dy)
    }
}

/// Screen edge enumeration
public enum ScreenEdge: String, CaseIterable, Codable, Sendable {
    case top
    case bottom
    case left
    case right

    /// Opposite edge
    public var opposite: ScreenEdge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .right
        case .right: return .left
        }
    }
}

/// Rectangle in screen coordinates
public struct ScreenRect: Equatable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }

    public var center: Position {
        Position(x: x + width / 2, y: y + height / 2)
    }

    public func contains(_ position: Position) -> Bool {
        position.x >= minX && position.x <= maxX &&
        position.y >= minY && position.y <= maxY
    }

    /// Position at edge midpoint
    public func edgeMidpoint(_ edge: ScreenEdge) -> Position {
        switch edge {
        case .top: return Position(x: x + width / 2, y: y)
        case .bottom: return Position(x: x + width / 2, y: y + height)
        case .left: return Position(x: x, y: y + height / 2)
        case .right: return Position(x: x + width, y: y + height / 2)
        }
    }
}
