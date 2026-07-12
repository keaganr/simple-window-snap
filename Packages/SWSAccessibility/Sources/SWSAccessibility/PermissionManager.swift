import AppKit
// `kAXTrustedCheckOptionPrompt` is an immutable CFString constant, but the
// C header doesn't declare it `const`, so Swift 6 strict concurrency treats
// it as unsafe shared global state. `@preconcurrency` silences that for
// this legacy C API surface, which predates Swift concurrency entirely.
@preconcurrency import ApplicationServices

/// Tracks whether this process is trusted for Accessibility (`AXIsProcessTrusted`),
/// which is required before any window drag detection or repositioning can happen.
///
/// There is no OS push notification for "permission just granted," so this polls
/// while untrusted and also re-checks whenever the app becomes active again (the
/// common case: the user alt-tabs back after granting permission in System Settings).
@MainActor
public final class PermissionManager: ObservableObject {
    @Published public private(set) var isTrusted: Bool

    // `nonisolated(unsafe)` because `deinit` is always nonisolated even on a
    // @MainActor class; these are otherwise only ever touched on the main actor.
    private nonisolated(unsafe) var pollTimer: Timer?
    private nonisolated(unsafe) var activationObserver: NSObjectProtocol?
    private let pollInterval: TimeInterval

    public init(pollInterval: TimeInterval = 1.5) {
        self.pollInterval = pollInterval
        self.isTrusted = AXIsProcessTrusted()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        if !isTrusted {
            startPolling()
        }
    }

    deinit {
        pollTimer?.invalidate()
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    /// Re-reads the current trust state. Safe to call at any time.
    public func refresh() {
        let trusted = AXIsProcessTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        if trusted {
            stopPolling()
        }
    }

    /// Prompts the user for Accessibility permission via the system dialog.
    /// macOS only shows this dialog once per app launch/signature; the caller
    /// should also offer `openAccessibilitySettings()` as a fallback.
    public func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        isTrusted = trusted
        if !trusted {
            startPolling()
        }
    }

    public static let accessibilitySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    public static func openAccessibilitySettings() {
        NSWorkspace.shared.open(accessibilitySettingsURL)
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
