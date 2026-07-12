import Testing
@testable import SWSAccessibility
import ApplicationServices

@Test @MainActor func accessibilitySettingsURLIsWellFormed() {
    let url = PermissionManager.accessibilitySettingsURL
    #expect(url.scheme == "x-apple.systempreferences")
    #expect(url.query == "Privacy_Accessibility")
}

// The real grant/deny flow can't be exercised in CI (it's an interactive TCC
// prompt), so this only checks that PermissionManager stays consistent with
// the OS-reported trust state rather than asserting a hardcoded true/false.
@Test @MainActor func permissionManagerTracksActualTrustState() {
    let manager = PermissionManager(pollInterval: 60)
    manager.refresh()
    #expect(manager.isTrusted == AXIsProcessTrusted())
}
