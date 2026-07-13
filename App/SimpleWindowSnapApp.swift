import SwiftUI
import SWSUI

@main
struct SimpleWindowSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Simple Window Snap", systemImage: "rectangle.3.group") {
            MenuBarContentView(permissionManager: appDelegate.permissionManager, configurationStore: appDelegate.configurationStore)
        }
        .menuBarExtraStyle(.menu)

        Window("Edit Zones", id: zoneEditorWindowID) {
            ConfigurationEditorView(store: appDelegate.configurationStore)
        }
        .windowResizability(.contentSize)
    }
}
