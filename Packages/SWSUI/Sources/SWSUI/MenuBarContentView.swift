import AppKit
import SwiftUI
import SWSAccessibility

/// The contents of the menu bar dropdown. Shows the Accessibility permission
/// state (required for the app to function) and, once granted, will host the
/// configuration switcher added in a later phase.
public struct MenuBarContentView: View {
    @ObservedObject private var permissionManager: PermissionManager
    @Environment(\.openWindow) private var openWindow

    public init(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager
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
