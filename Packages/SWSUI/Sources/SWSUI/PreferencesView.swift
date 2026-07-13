import SwiftUI
import SWSHotkey

public struct PreferencesView: View {
    public init() {}

    public var body: some View {
        Form {
            HotkeyRecorderView()
            Text("Press this while dragging a window to temporarily disable snapping for that drag. Press it again to re-enable.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 380, minHeight: 140)
    }
}
