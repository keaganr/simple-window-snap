import SwiftUI
import KeyboardShortcuts

/// Thin wrapper around `KeyboardShortcuts.Recorder` so the rest of the app
/// never imports the third-party package directly.
public struct HotkeyRecorderView: View {
    public init() {}

    public var body: some View {
        KeyboardShortcuts.Recorder("Suppress Snap Hotkey:", name: .toggleSnapSuppression)
    }
}
