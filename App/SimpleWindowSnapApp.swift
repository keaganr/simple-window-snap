import SwiftUI
import SWSAccessibility
import SWSUI

@main
struct SimpleWindowSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var permissionManager = PermissionManager()

    var body: some Scene {
        MenuBarExtra("Simple Window Snap", systemImage: "rectangle.3.group") {
            MenuBarContentView(permissionManager: permissionManager)
        }
        .menuBarExtraStyle(.menu)
    }
}
