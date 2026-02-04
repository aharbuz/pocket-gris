import AppKit
import PocketGrisCore

// Menu bar app - no dock icon
NSApp.setActivationPolicy(.accessory)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

print("PocketGrisApp \(PocketGrisCore.version)")
print("Starting menu bar app...")

app.run()
