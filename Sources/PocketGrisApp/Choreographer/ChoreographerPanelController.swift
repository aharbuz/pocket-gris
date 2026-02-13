import AppKit
import SwiftUI
import PocketGrisCore

/// Manages the choreographer floating panel window
final class ChoreographerPanelController: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private let viewModel: ChoreographerViewModel
    private let sceneStorage: PGSceneStorage
    private let scenePlayer: ScenePlayer
    private let spriteLoader: SpriteLoader
    private let windowTracker: WindowTracker?
    private let cursorTracker: CursorTracker?

    init(
        viewModel: ChoreographerViewModel,
        sceneStorage: PGSceneStorage,
        scenePlayer: ScenePlayer,
        spriteLoader: SpriteLoader,
        windowTracker: WindowTracker?,
        cursorTracker: CursorTracker?
    ) {
        self.viewModel = viewModel
        self.sceneStorage = sceneStorage
        self.scenePlayer = scenePlayer
        self.spriteLoader = spriteLoader
        self.windowTracker = windowTracker
        self.cursorTracker = cursorTracker
    }

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let panelView = ChoreographerPanelView(
            viewModel: viewModel,
            sceneStorage: sceneStorage,
            scenePlayer: scenePlayer,
            spriteLoader: spriteLoader,
            windowTracker: windowTracker,
            cursorTracker: cursorTracker
        )

        let hostingView = NSHostingView(rootView: panelView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 500),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Choreographer"
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        // Position panel at right side of screen
        if let screen = NSScreen.main {
            let x = screen.frame.maxX - 340
            let y = screen.frame.midY - 250
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.delegate = self
        self.window = panel
        panel.makeKeyAndOrderFront(nil)
    }

    func setAboveOverlay(_ above: Bool) {
        // Panel is always above overlay to remain clickable
        // The 'above' parameter only affects whether overlay is key (for keyboard events)
        window?.level = NSWindow.Level(NSWindow.Level.floating.rawValue + 1)
    }

    func close() {
        window?.delegate = nil
        window?.close()
        window = nil
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if viewModel.hasUnsavedChanges {
            // Prevent the window from closing and show the SwiftUI alert instead
            viewModel.requestClose()
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        viewModel.onClose?()
    }
}
