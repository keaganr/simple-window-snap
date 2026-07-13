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
            openWindow(id: zoneEditorWindowID)
        }

        Divider()

        Button("Quit Simple Window Snap") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

/// Shared with `SimpleWindowSnapApp`'s `Window(id:)` declaration for the
/// zone editor - both sides must agree on this identifier.
public let zoneEditorWindowID = "zone-editor"
