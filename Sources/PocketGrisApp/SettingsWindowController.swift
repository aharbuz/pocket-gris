import AppKit
import SwiftUI
import PocketGrisCore

/// Manages the settings window lifecycle
final class SettingsWindowController {
    private var window: NSWindow?

    func show(
        creatures: [Creature],
        onTestBehavior: @escaping (Creature?, BehaviorType?) -> Void,
        onSettingsChanged: @escaping (AppSettings) -> Void
    ) {
        // If window already exists, just bring it to front
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            creatures: creatures,
            onTestBehavior: onTestBehavior,
            onSettingsChanged: onSettingsChanged
        )

        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pocket Gris Settings"
        window.contentView = hostingView
        window.center()
        window.setFrameAutosaveName("PocketGrisSettings")
        window.isReleasedWhenClosed = false

        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
