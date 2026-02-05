import Foundation
import ServiceManagement

/// Manages launch at login using SMAppService (macOS 13+)
@MainActor
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return false
        }
        set {
            setEnabled(newValue)
        }
    }

    private func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // SMAppService requires a proper .app bundle with Info.plist
                // When running from SPM build, this will fail gracefully
                print("Launch at login not available: \(error.localizedDescription)")
                print("Note: Requires a proper .app bundle to function")
            }
        }
    }
}
