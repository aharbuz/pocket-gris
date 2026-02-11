import AppKit
import Combine
import SwiftUI
import PocketGrisCore

/// Transparent borderless overlay window for waypoint placement
final class ChoreographerOverlayWindow: NSWindow {

    var viewModel: ChoreographerViewModel?
    private var placingCancellable: AnyCancellable?

    init(screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.main
        let screenFrame = targetScreen?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = NSColor.black.withAlphaComponent(0.15)
        self.hasShadow = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.ignoresMouseEvents = true
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
    }

    func setup(viewModel: ChoreographerViewModel) {
        self.viewModel = viewModel

        // Toggle mouse event handling based on placement mode
        placingCancellable = viewModel.$isPlacing.sink { [weak self] isPlacing in
            self?.ignoresMouseEvents = !isPlacing
        }

        let overlayView = ChoreographerOverlayView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = contentView?.bounds ?? frame

        contentView = hostingView
    }

    func teardown() {
        placingCancellable?.cancel()
        placingCancellable = nil
        contentView = nil
        viewModel = nil
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, viewModel?.isPlacing == true { // Escape stops placement
            viewModel?.isPlacing = false
        } else {
            super.keyDown(with: event)
        }
    }
}
