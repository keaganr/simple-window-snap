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
    }
}
