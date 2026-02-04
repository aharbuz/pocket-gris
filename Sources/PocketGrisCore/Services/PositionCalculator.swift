import Foundation

/// Calculates positions for creature placement on screen/window edges
public struct PositionCalculator: Sendable {

    public init() {}

    // MARK: - Screen Edge Positions

    /// Calculate a position on a screen edge
    public func positionOnScreenEdge(
        edge: ScreenEdge,
        screenBounds: ScreenRect,
        offset: Double = 0,
        random: RandomSource
    ) -> Position {
        let margin: Double = 50  // Keep away from corners

        switch edge {
        case .left:
            let y = random.double(in: (screenBounds.minY + margin)...(screenBounds.maxY - margin))
            return Position(x: screenBounds.minX + offset, y: y)

        case .right:
            let y = random.double(in: (screenBounds.minY + margin)...(screenBounds.maxY - margin))
            return Position(x: screenBounds.maxX - offset, y: y)

        case .top:
            let x = random.double(in: (screenBounds.minX + margin)...(screenBounds.maxX - margin))
            return Position(x: x, y: screenBounds.minY + offset)

        case .bottom:
            let x = random.double(in: (screenBounds.minX + margin)...(screenBounds.maxX - margin))
            return Position(x: x, y: screenBounds.maxY - offset)
        }
    }

    // MARK: - Window Edge Positions

    /// Calculate a position on a window edge
    public func positionOnWindowEdge(
        edge: ScreenEdge,
        windowFrame: ScreenRect,
        offset: Double = 0,
        random: RandomSource
    ) -> Position {
        let margin: Double = 20  // Keep away from window corners

        switch edge {
        case .left:
            let y = random.double(in: (windowFrame.minY + margin)...(windowFrame.maxY - margin))
            return Position(x: windowFrame.minX + offset, y: y)

        case .right:
            let y = random.double(in: (windowFrame.minY + margin)...(windowFrame.maxY - margin))
            return Position(x: windowFrame.maxX - offset, y: y)

        case .top:
            let x = random.double(in: (windowFrame.minX + margin)...(windowFrame.maxX - margin))
            return Position(x: x, y: windowFrame.minY + offset)

        case .bottom:
            let x = random.double(in: (windowFrame.minX + margin)...(windowFrame.maxX - margin))
            return Position(x: x, y: windowFrame.maxY - offset)
        }
    }

    // MARK: - Corner Positions

    /// Calculate corner positions of a rectangle
    public func corners(of rect: ScreenRect) -> [Position] {
        [
            Position(x: rect.minX, y: rect.minY),  // Top-left
            Position(x: rect.maxX, y: rect.minY),  // Top-right
            Position(x: rect.minX, y: rect.maxY),  // Bottom-left
            Position(x: rect.maxX, y: rect.maxY)   // Bottom-right
        ]
    }

    /// Get a random corner
    public func randomCorner(of rect: ScreenRect, random: RandomSource) -> Position {
        let c = corners(of: rect)
        return c[random.int(in: 0..<c.count)]
    }

    // MARK: - Hiding Positions

    /// Calculate position just off-screen for a given edge
    public func hidingPosition(
        edge: ScreenEdge,
        visiblePosition: Position,
        spriteSize: Double
    ) -> Position {
        switch edge {
        case .left:
            return Position(x: visiblePosition.x - spriteSize, y: visiblePosition.y)
        case .right:
            return Position(x: visiblePosition.x + spriteSize, y: visiblePosition.y)
        case .top:
            return Position(x: visiblePosition.x, y: visiblePosition.y - spriteSize)
        case .bottom:
            return Position(x: visiblePosition.x, y: visiblePosition.y + spriteSize)
        }
    }

    /// Calculate sliding animation positions for peek behavior
    public func peekPositions(
        edge: ScreenEdge,
        bounds: ScreenRect,
        peekAmount: Double,
        spriteSize: Double,
        random: RandomSource
    ) -> (hidden: Position, peeking: Position) {
        let visible = positionOnScreenEdge(edge: edge, screenBounds: bounds, random: random)
        let hidden = hidingPosition(edge: edge, visiblePosition: visible, spriteSize: spriteSize)

        // Peeking position is partially visible
        let peekOffset = spriteSize - peekAmount
        let peeking: Position
        switch edge {
        case .left:
            peeking = Position(x: hidden.x + peekOffset, y: hidden.y)
        case .right:
            peeking = Position(x: hidden.x - peekOffset, y: hidden.y)
        case .top:
            peeking = Position(x: hidden.x, y: hidden.y + peekOffset)
        case .bottom:
            peeking = Position(x: hidden.x, y: hidden.y - peekOffset)
        }

        return (hidden, peeking)
    }

    // MARK: - Path Generation

    /// Generate a straight path between two positions
    public func straightPath(from start: Position, to end: Position, steps: Int) -> [Position] {
        guard steps > 1 else { return [start, end] }

        var path: [Position] = []
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            path.append(Position(x: x, y: y))
        }
        return path
    }

    /// Generate an eased path (slow-fast-slow)
    public func easedPath(from start: Position, to end: Position, steps: Int) -> [Position] {
        guard steps > 1 else { return [start, end] }

        var path: [Position] = []
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            // Ease in-out cubic
            let eased = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
            let x = start.x + (end.x - start.x) * eased
            let y = start.y + (end.y - start.y) * eased
            path.append(Position(x: x, y: y))
        }
        return path
    }

    // MARK: - Cursor Interaction

    /// Calculate flee direction from cursor
    public func fleeDirection(
        from position: Position,
        cursor: Position
    ) -> Position {
        let dx = position.x - cursor.x
        let dy = position.y - cursor.y
        let distance = position.distance(to: cursor)

        guard distance > 0 else {
            return Position(x: 1, y: 0)  // Default right if directly on cursor
        }

        // Normalized direction vector
        return Position(x: dx / distance, y: dy / distance)
    }

    /// Calculate position to flee to
    public func fleePosition(
        from position: Position,
        cursor: Position,
        distance: Double,
        bounds: ScreenRect
    ) -> Position {
        let direction = fleeDirection(from: position, cursor: cursor)
        var target = Position(
            x: position.x + direction.x * distance,
            y: position.y + direction.y * distance
        )

        // Clamp to bounds
        target.x = max(bounds.minX, min(bounds.maxX, target.x))
        target.y = max(bounds.minY, min(bounds.maxY, target.y))

        return target
    }
}
