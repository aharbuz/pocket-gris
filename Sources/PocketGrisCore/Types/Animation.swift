import Foundation

/// Animation definition with frame sequence
public struct Animation: Equatable, Codable, Sendable {
    public let name: String
    public let frameCount: Int
    public let fps: Double
    public let looping: Bool

    public init(name: String, frameCount: Int, fps: Double = 12, looping: Bool = false) {
        precondition(frameCount > 0, "frameCount must be positive")
        precondition(fps > 0, "fps must be positive")
        self.name = name
        self.frameCount = frameCount
        self.fps = fps
        self.looping = looping
    }

    /// Duration in seconds
    public var duration: TimeInterval {
        Double(frameCount) / fps
    }

    /// Frame filename for given index (0-based)
    public func frameFilename(at index: Int) -> String {
        guard frameCount > 0 else { return "frame-001.png" }
        let safeIndex = looping ? index % frameCount : min(index, frameCount - 1)
        return String(format: "frame-%03d.png", safeIndex + 1)
    }
}

/// Animation playback state
public struct AnimationState: Equatable, Sendable {
    public var animation: Animation
    public var currentFrame: Int
    public var elapsedTime: TimeInterval
    public var isComplete: Bool

    public init(animation: Animation) {
        self.animation = animation
        self.currentFrame = 0
        self.elapsedTime = 0
        self.isComplete = false
    }

    /// Advance time, return true if frame changed
    public mutating func advance(by deltaTime: TimeInterval) -> Bool {
        guard !isComplete else { return false }

        elapsedTime += deltaTime
        let newFrame = Int(elapsedTime * animation.fps)

        if animation.looping {
            let frameChanged = (newFrame % animation.frameCount) != currentFrame
            currentFrame = newFrame % animation.frameCount
            return frameChanged
        } else {
            if newFrame >= animation.frameCount {
                currentFrame = animation.frameCount - 1
                isComplete = true
                return true
            }
            let frameChanged = newFrame != currentFrame
            currentFrame = newFrame
            return frameChanged
        }
    }

    public mutating func reset() {
        currentFrame = 0
        elapsedTime = 0
        isComplete = false
    }
}
