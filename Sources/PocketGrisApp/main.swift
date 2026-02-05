import AppKit
import PocketGrisCore

let app = NSApplication.shared

// Menu bar app - no dock icon
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

print("PocketGrisApp \(PocketGrisCore.version)")
print("Starting menu bar app...")

app.run()
