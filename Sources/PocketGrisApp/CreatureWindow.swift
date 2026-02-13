import AppKit
import SwiftUI
import PocketGrisCore

/// A transparent, floating, click-through window for displaying creatures
final class CreatureWindow: NSWindow {

    private var viewModel: CreatureViewModel?
    private var displayLink: CVDisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var onComplete: (() -> Void)?

    init(screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.main
        let screenFrame = targetScreen?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window for floating transparent overlay
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.ignoresMouseEvents = true
        self.isReleasedWhenClosed = false
    }

    func show(
        creature: Creature,
        behavior behaviorType: BehaviorType,
        spriteLoader: SpriteLoader,
        windowTracker: WindowTracker? = nil,
        cursorTracker: CursorTracker? = nil,
        onComplete: @escaping () -> Void
    ) {
        let screenBounds = ScreenRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.width,
            height: frame.height
        )

        let vm = CreatureViewModel(
            creature: creature,
            behaviorType: behaviorType,
            screenBounds: screenBounds,
            spriteLoader: spriteLoader,
            windowTracker: windowTracker,
            cursorTracker: cursorTracker
        )
        showWithViewModel(vm, onComplete: onComplete)
    }

    func show(
        creature: Creature,
        behavior: any Behavior,
        spriteLoader: SpriteLoader,
        windowTracker: WindowTracker? = nil,
        cursorTracker: CursorTracker? = nil,
        onComplete: @escaping () -> Void
    ) {
        let screenBounds = ScreenRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.width,
            height: frame.height
        )

        let vm = CreatureViewModel(
            creature: creature,
            behavior: behavior,
            screenBounds: screenBounds,
            spriteLoader: spriteLoader,
            windowTracker: windowTracker,
            cursorTracker: cursorTracker
        )
        showWithViewModel(vm, onComplete: onComplete)
    }

    private func showWithViewModel(_ vm: CreatureViewModel, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        self.viewModel = vm

        vm.onComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.close()
                self?.onComplete?()
            }
        }

        // Create SwiftUI view
        let spriteView = SpriteView(viewModel: vm)
        let hostingView = NSHostingView(rootView: spriteView)
        hostingView.frame = contentView?.bounds ?? frame

        contentView = hostingView

        // Show window
        makeKeyAndOrderFront(nil)

        // Start behavior
        vm.start()

        // Start animation loop
        startDisplayLink()
    }

    override func close() {
        stopDisplayLink()
        viewModel?.cancel()
        super.close()
    }

    // MARK: - Display Link

    deinit {
        stopDisplayLink()
    }

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let displayLink = link else { return }

        self.displayLink = displayLink
        lastFrameTime = CACurrentMediaTime()

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            let now = CACurrentMediaTime()
            let window = Unmanaged<CreatureWindow>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async { [weak window] in
                guard let window = window else { return }
                let deltaTime = now - window.lastFrameTime
                window.lastFrameTime = now
                window.viewModel?.update(deltaTime: deltaTime)
            }
            return kCVReturnSuccess
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, callback, userInfo)
        CVDisplayLinkStart(displayLink)
    }

    private func stopDisplayLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
        displayLink = nil
    }
}
