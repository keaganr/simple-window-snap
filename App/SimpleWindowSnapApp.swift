import SwiftUI

@main
struct SimpleWindowSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Simple Window Snap", systemImage: "rectangle.3.group") {
            Button("Quit Simple Window Snap") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
