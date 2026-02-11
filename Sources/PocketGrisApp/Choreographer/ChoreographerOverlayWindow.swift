import AppKit
import SwiftUI
import PocketGrisCore

/// Transparent borderless overlay window for waypoint placement
final class ChoreographerOverlayWindow: NSWindow {

    var viewModel: ChoreographerViewModel?

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
        // Always accept mouse events so waypoints can be edited
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
    }

    func setup(viewModel: ChoreographerViewModel) {
        self.viewModel = viewModel

        let overlayView = ChoreographerOverlayView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = contentView?.bounds ?? frame

        contentView = hostingView
    }

    func teardown() {
        contentView = nil
        viewModel = nil
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseMoved(with event: NSEvent) {
        guard let contentView = contentView else { return }
        let locationInWindow = event.locationInWindow
        // Flip Y for SwiftUI coordinates (origin top-left)
        let flippedY = contentView.bounds.height - locationInWindow.y
        viewModel?.updatePreviewPosition(CGPoint(x: locationInWindow.x, y: flippedY))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, viewModel?.isPlacing == true { // Escape stops placement
            viewModel?.isPlacing = false
        } else {
            super.keyDown(with: event)
        }
    }
}
