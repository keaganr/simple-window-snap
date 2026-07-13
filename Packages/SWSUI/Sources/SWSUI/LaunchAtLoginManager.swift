import ServiceManagement
import os

private let logger = Logger(subsystem: "com.keaganr.SimpleWindowSnap", category: "LaunchAtLoginManager")

/// Registers/unregisters this app as a login item via `SMAppService`. Self-
/// contained (no dependency on app-specific state), so it's owned directly
/// by whatever view surfaces the toggle rather than threaded through
/// AppDelegate.
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled: Bool

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Failed to \(enabled ? "register" : "unregister", privacy: .public) launch-at-login: \(error.localizedDescription, privacy: .public)")
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
