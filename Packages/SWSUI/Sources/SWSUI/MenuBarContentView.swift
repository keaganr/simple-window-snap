import AppKit
import SwiftUI
import SWSAccessibility
import SWSModel

/// The contents of the menu bar dropdown: Accessibility permission state
/// (required for the app to function), the configuration switcher, and a
/// link to the zone editor.
public struct MenuBarContentView: View {
    @ObservedObject private var permissionManager: PermissionManager
    @ObservedObject private var configurationStore: ConfigurationStore
    @Environment(\.openWindow) private var openWindow

    public init(permissionManager: PermissionManager, configurationStore: ConfigurationStore) {
        self.permissionManager = permissionManager
        self.configurationStore = configurationStore
    }

    public var body: some View {
        if permissionManager.isTrusted {
            Text("Accessibility: Granted")
        } else {
            Text("Accessibility: Not Granted")
            Button("Grant Accessibility Permission…") {
                permissionManager.requestPermission()
            }
            Button("Open System Settings…") {
                PermissionManager.openAccessibilitySettings()
            }
        }

        Divider()

        Menu("Configurations") {
            ForEach(configurationStore.configurations) { configuration in
                Button {
                    configurationStore.setActiveConfiguration(configuration.id)
                } label: {
                    if configuration.id == configurationStore.activeConfigurationID {
                        Label(configuration.name, systemImage: "checkmark")
                    } else {
                        Text(configuration.name)
                    }
                }
            }
        }

        Button("Edit Zones…") {
            openAndActivate(zoneEditorWindowID)
        }

        Button("Preferences…") {
            openAndActivate(preferencesWindowID)
        }

        Divider()

        Button("Quit Simple Window Snap") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// `openWindow(id:)` alone leaves the new window wherever it lands in
    /// the global window stack - since this is a menu-bar-only ("accessory")
    /// app, it's never automatically made the frontmost app the way a
    /// normal app opening a window would be, so the window can appear
    /// behind whatever currently has focus. Activating first fixes that
    /// without changing the app's LSUIElement/accessory status (no Dock
    /// icon, no Cmd-Tab entry).
    private func openAndActivate(_ id: String) {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: id)
    }
}

/// Shared with `SimpleWindowSnapApp`'s `Window(id:)` declarations - both
/// sides must agree on these identifiers.
public let zoneEditorWindowID = "zone-editor"
public let preferencesWindowID = "preferences"
