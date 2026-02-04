import Foundation
import SwiftUI
import PocketGrisCore

/// Observable view model bridging Core behavior to SwiftUI
@MainActor
final class CreatureViewModel: ObservableObject {
    @Published var position: Position = .zero
    @Published var currentFramePath: String?
    @Published var isVisible: Bool = false
    @Published var flipHorizontal: Bool = false

    private let creature: Creature
    private let behavior: any Behavior
    private var state: BehaviorState
    private let spriteLoader: SpriteLoader
    private let screenBounds: ScreenRect
    private let random: RandomSource
    private var timeSource: TimeSource

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
        }

        updateFramePath()
    }

    func start() {
        isVisible = true
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

        // Update published properties
        position = state.position

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

            case .phaseChanged:
                // Animation might change on phase change
                updateFramePath()

            case .positionChanged(let pos):
                position = pos

            case .animationFrameChanged:
                // Handled separately
                break

            case .started:
                break
            }
        }
    }

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

    private func getCurrentCursorPosition() -> Position? {
        let mouseLocation = NSEvent.mouseLocation
        // Convert from bottom-left to top-left coordinate system
        guard let screen = NSScreen.main else { return nil }
        let y = screen.frame.height - mouseLocation.y
        return Position(x: mouseLocation.x, y: y)
    }
}
