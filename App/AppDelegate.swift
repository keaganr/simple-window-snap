import AppKit
import Combine
import SWSAccessibility
import SWSModel
import SWSOverlay

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let permissionManager = PermissionManager()
    let configurationStore = ConfigurationStore()
    private let dragDetectionEngine = DragDetectionEngine()
    private let overlayController = OverlayWindowController()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        permissionManager.$isTrusted
            .removeDuplicates()
            .sink { [dragDetectionEngine] isTrusted in
                MainActor.assumeIsolated {
                    if isTrusted {
                        dragDetectionEngine.start()
                    } else {
                        dragDetectionEngine.stop()
                    }
                }
            }
            .store(in: &cancellables)

        dragDetectionEngine.$phase
            .removeDuplicates()
            .sink { [overlayController, configurationStore] phase in
                MainActor.assumeIsolated {
                    switch phase {
                    case .dragging:
                        let zones = configurationStore.activeConfiguration?.zones.map(\.rect) ?? []
                        overlayController.show(zones: zones)
                    case .idle, .candidate:
                        overlayController.hide()
                    }
                }
            }
            .store(in: &cancellables)

        dragDetectionEngine.$cursorLocation
            .sink { [overlayController] location in
                MainActor.assumeIsolated {
                    overlayController.updateCursor(atAXPoint: location)
                }
            }
            .store(in: &cancellables)

        // Deliberately independent of `overlayController`'s internal state
        // (rather than reading back its `highlightedZone`) since Combine's
        // `$phase` sink above - which hides the overlay - fires synchronously
        // *during* the `phase` assignment inside `apply(_:)`, before this
        // callback (a separate statement later in that same method) runs.
        // Recomputing from `cursorLocation` sidesteps that ordering entirely.
        dragDetectionEngine.onDragEnded = { [dragDetectionEngine, configurationStore] in
            guard let screen = NSScreen.main else { return }
            let zones = configurationStore.activeConfiguration?.zones.map(\.rect) ?? []
            // Zones are resolved against the *usable* area (excludes the
            // menu bar/Dock), matching what OverlayWindowController shows -
            // a zone touching the full screen's AX y=0 would ask apps to
            // place a window under the menu bar, which they can't actually
            // do and clamp/adjust unpredictably instead.
            let usableAXFrame = ScreenGeometry.usableAXFrame(fullScreenFrame: screen.frame, visibleScreenFrame: screen.visibleFrame)
            guard let targetZone = ZoneHitTesting.zone(
                containing: dragDetectionEngine.cursorLocation,
                screenFrame: usableAXFrame,
                in: zones
            ) else { return }
            dragDetectionEngine.snapCandidateWindow(toAXRect: targetZone.resolved(in: usableAXFrame))
        }
    }
}
