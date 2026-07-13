import KeyboardShortcuts

/// Watches the global `toggleSnapSuppression` hotkey and calls `onTrigger`
/// each time it's pressed, regardless of which app is focused - that's the
/// whole point of a *global* hotkey. Callers are expected to toggle their
/// own suppression state from `onTrigger`.
@MainActor
public final class SnapHotkeyObserver {
    public var onTrigger: (() -> Void)?

    public init() {
        KeyboardShortcuts.onKeyDown(for: .toggleSnapSuppression) { [weak self] in
            MainActor.assumeIsolated {
                self?.onTrigger?()
            }
        }
    }
}
