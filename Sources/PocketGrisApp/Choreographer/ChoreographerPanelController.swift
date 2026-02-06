import AppKit
import SwiftUI
import PocketGrisCore

/// Manages the choreographer floating panel window
final class ChoreographerPanelController {
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

        self.window = panel
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
        window = nil
    }
}
