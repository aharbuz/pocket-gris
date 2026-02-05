import Foundation
import SwiftUI
import PocketGrisCore

/// Observable view model bridging Core behavior to SwiftUI
@MainActor
final class CreatureViewModel: ObservableObject {
    // Position from behavior (target position)
    @Published var position: Position = .zero

    // Smoothly interpolated display position for rendering
    @Published var displayPosition: Position = .zero

    @Published var currentFramePath: String?
    @Published var isVisible: Bool = false
    @Published var flipHorizontal: Bool = false
    @Published var opacity: Double = 1.0

    private let creature: Creature
    private let behavior: any Behavior
    private var state: BehaviorState
    private let spriteLoader: SpriteLoader
    private let screenBounds: ScreenRect
    private let random: RandomSource
    private var timeSource: TimeSource

    // Animation state for sliding
    private var slideStartPosition: Position = .zero
    private var slideTargetPosition: Position = .zero
    private var slideProgress: Double = 1.0  // 1.0 = complete
    private var slideDuration: TimeInterval = 0.3
    private let slideSpeed: Double = 200.0  // pixels per second for normal movement

    // Offscreen offset for hiding sprite at edge
    private let hideOffset: Double = 80

    var onComplete: (() -> Void)?

    init(
        creature: Creature,
        behaviorType: BehaviorType,
        screenBounds: ScreenRect,
        spriteLoader: SpriteLoader,
        timeSource: TimeSource = SystemTimeSource(),
        random: RandomSource = SystemRandomSource()
    ) {
        self.creature = creature
        self.behavior = BehaviorRegistry.shared.behavior(for: behaviorType) ?? PeekBehavior()
        self.screenBounds = screenBounds
        self.spriteLoader = spriteLoader
        self.timeSource = timeSource
        self.random = random

        // Initialize state
        let context = BehaviorContext(
            creature: creature,
            screenBounds: screenBounds,
            currentTime: timeSource.now
        )
        self.state = behavior.start(context: context, random: random)

        // Initial position and flip based on edge
        position = state.position
        if let edge = state.edge {
            flipHorizontal = (edge == .right)
            // Start offscreen for sliding entrance
            displayPosition = offscreenPosition(for: edge, target: state.position)
        } else {
            displayPosition = state.position
        }

        updateFramePath()
        preloadSprites()
    }

    func start() {
        isVisible = true
        opacity = 1.0

        // Start sliding in from edge
        if let edge = state.edge {
            startSlide(
                from: offscreenPosition(for: edge, target: position),
                to: position,
                duration: 0.4
            )
        }
    }

    func cancel() {
        let events = behavior.cancel(state: &state)
        handleEvents(events)
    }

    func update(deltaTime: TimeInterval) {
        let context = BehaviorContext(
            creature: creature,
            screenBounds: screenBounds,
            currentTime: timeSource.now,
            cursorPosition: getCurrentCursorPosition()
        )

        let events = behavior.update(state: &state, context: context, deltaTime: deltaTime)
        handleEvents(events)

        // Update target position from behavior
        let newPosition = state.position
        if newPosition != position {
            // Update flip direction based on movement
            if newPosition.x > position.x {
                flipHorizontal = false  // Moving right, face right
            } else if newPosition.x < position.x {
                flipHorizontal = true   // Moving left, face left
            }
            position = newPosition
        }

        // Update slide animation
        updateSlide(deltaTime: deltaTime)

        // Update animation frame
        if events.contains(where: {
            if case .animationFrameChanged = $0 { return true }
            return false
        }) {
            updateFramePath()
        }
    }

    private func handleEvents(_ events: [BehaviorEvent]) {
        for event in events {
            switch event {
            case .completed, .cancelled:
                isVisible = false
                onComplete?()

            case .phaseChanged(let phase):
                handlePhaseChange(phase)
                updateFramePath()

            case .positionChanged(let pos):
                position = pos

            case .animationFrameChanged:
                break

            case .started:
                break
            }
        }
    }

    private func handlePhaseChange(_ phase: BehaviorPhase) {
        switch phase {
        case .exit:
            // Start sliding back offscreen
            if let edge = state.edge {
                let target = offscreenPosition(for: edge, target: displayPosition)
                startSlide(from: displayPosition, to: target, duration: 0.5)
            }

        case .perform:
            // Ensure we're at the target position
            if slideProgress >= 1.0 {
                displayPosition = position
            }

        default:
            break
        }
    }

    // MARK: - Sliding Animation

    private func startSlide(from: Position, to: Position, duration: TimeInterval) {
        slideStartPosition = from
        slideTargetPosition = to
        slideProgress = 0.0
        slideDuration = duration
    }

    private func updateSlide(deltaTime: TimeInterval) {
        // If in perform phase and behavior updates position continuously, follow it
        if state.phase == .perform && slideProgress >= 1.0 {
            // Smoothly follow the behavior's position
            let followSpeed = 8.0  // How fast to catch up
            let dx = position.x - displayPosition.x
            let dy = position.y - displayPosition.y

            // Only interpolate if there's a significant difference
            if abs(dx) > 0.5 || abs(dy) > 0.5 {
                displayPosition = Position(
                    x: displayPosition.x + dx * min(followSpeed * deltaTime, 1.0),
                    y: displayPosition.y + dy * min(followSpeed * deltaTime, 1.0)
                )
            } else {
                displayPosition = position
            }
            return
        }

        guard slideProgress < 1.0 else {
            displayPosition = slideTargetPosition
            return
        }

        slideProgress += deltaTime / slideDuration
        slideProgress = min(slideProgress, 1.0)

        // Ease out cubic for smooth deceleration
        let t = slideProgress
        let eased = 1.0 - pow(1.0 - t, 3)

        displayPosition = Position(
            x: slideStartPosition.x + (slideTargetPosition.x - slideStartPosition.x) * eased,
            y: slideStartPosition.y + (slideTargetPosition.y - slideStartPosition.y) * eased
        )
    }

    private func offscreenPosition(for edge: ScreenEdge, target: Position) -> Position {
        switch edge {
        case .left:
            return Position(x: target.x - hideOffset, y: target.y)
        case .right:
            return Position(x: target.x + hideOffset, y: target.y)
        case .top:
            return Position(x: target.x, y: target.y - hideOffset)
        case .bottom:
            return Position(x: target.x, y: target.y + hideOffset)
        }
    }

    // MARK: - Sprites

    private func updateFramePath() {
        guard let anim = state.animation else {
            currentFramePath = nil
            return
        }

        currentFramePath = spriteLoader.framePath(
            creature: creature.id,
            animation: anim.animation.name,
            frame: anim.currentFrame
        )
    }

    private func preloadSprites() {
        // Preload all animation frames for this creature in background
        let creatureId = creature.id
        let animations = Array(creature.animations.keys)
        let loader = spriteLoader

        DispatchQueue.global(qos: .userInitiated).async {
            ImageCache.shared.preloadCreature(
                id: creatureId,
                animations: animations,
                spriteLoader: loader
            )
        }
    }

    // MARK: - Input

    private func getCurrentCursorPosition() -> Position? {
        let mouseLocation = NSEvent.mouseLocation
        // Convert from bottom-left to top-left coordinate system
        guard let screen = NSScreen.main else { return nil }
        let y = screen.frame.height - mouseLocation.y
        return Position(x: mouseLocation.x, y: y)
    }
}
