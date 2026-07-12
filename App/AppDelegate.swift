import AppKit
import Combine
import SWSAccessibility
import SWSOverlay

/// Hardcoded snap zones for Phase 3's overlay demo. Replaced by
/// SWSModel-backed, user-configured zones in Phase 5.
private let placeholderZones: [NormalizedRect] = [
    NormalizedRect(x: 0, y: 0, width: 1.0 / 3, height: 1), // Left third
    NormalizedRect(x: 2.0 / 3, y: 0, width: 1.0 / 3, height: 1), // Right third
    NormalizedRect(x: 1.0 / 3, y: 0, width: 1.0 / 3, height: 0.5), // Top center
]

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let permissionManager = PermissionManager()
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
            .sink { [overlayController] phase in
                MainActor.assumeIsolated {
                    switch phase {
                    case .dragging:
                        overlayController.show(zones: placeholderZones)
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
        dragDetectionEngine.onDragEnded = { [dragDetectionEngine] in
            guard let screen = NSScreen.main else { return }
            // Zones are resolved against the *usable* area (excludes the
            // menu bar/Dock), matching what OverlayWindowController shows -
            // a zone touching the full screen's AX y=0 would ask apps to
            // place a window under the menu bar, which they can't actually
            // do and clamp/adjust unpredictably instead.
            let usableAXFrame = ScreenGeometry.usableAXFrame(fullScreenFrame: screen.frame, visibleScreenFrame: screen.visibleFrame)
            guard let targetZone = ZoneHitTesting.zone(
                containing: dragDetectionEngine.cursorLocation,
                screenFrame: usableAXFrame,
                in: placeholderZones
            ) else { return }
            dragDetectionEngine.snapCandidateWindow(toAXRect: targetZone.resolved(in: usableAXFrame))
        }
    }
}
