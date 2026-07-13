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

        // CombineLatest rather than keying off `$phase` alone: releasing/
        // holding Control mid-drag (`$isSnapSuppressed` changing without
        // `$phase` changing) must hide/show the overlay immediately too, not
        // just affect the eventual snap decision. `$activeConfigurationID`
        // is included too so swapping profiles mid-drag (Option key, see
        // `onCycleConfigurationRequested` below) refreshes the shown zones
        // and switcher highlight without waiting for the next phase change.
        dragDetectionEngine.$phase
            .combineLatest(dragDetectionEngine.$isSnapSuppressed, configurationStore.$activeConfigurationID)
            .removeDuplicates { $0.0 == $1.0 && $0.1 == $1.1 && $0.2 == $1.2 }
            .sink { [overlayController, configurationStore] phase, isSuppressed, activeConfigurationID in
                MainActor.assumeIsolated {
                    if case .dragging = phase, !isSuppressed {
                        // Use the id `@Published` just emitted rather than
                        // re-reading `configurationStore.activeConfigurationID`:
                        // `@Published` publishes on `willSet`, before its
                        // backing storage is actually updated, so re-reading
                        // the property here - during the very call that's
                        // changing it - would still see the previous value
                        // and leave the overlay a step behind (e.g. the first
                        // Option press during a drag appearing to do nothing).
                        let configurations = configurationStore.configurations
                        let activeIndex = configurations.firstIndex { $0.id == activeConfigurationID }
                        let zones = activeIndex.map { configurations[$0].zones.map(\.rect) } ?? []
                        overlayController.show(
                            zones: zones,
                            configurationNames: configurations.map(\.name),
                            activeConfigurationIndex: activeIndex
                        )
                    } else {
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

        dragDetectionEngine.onCycleConfigurationRequested = { [configurationStore] in
            MainActor.assumeIsolated {
                configurationStore.activateNextConfiguration()
            }
        }

        // Deliberately independent of `overlayController`'s internal state
        // (rather than reading back its `highlightedZone`) since Combine's
        // `$phase` sink above - which hides the overlay - fires synchronously
        // *during* the `phase` assignment inside `apply(_:)`, before this
        // callback (a separate statement later in that same method) runs.
        // Recomputing from `cursorLocation` sidesteps that ordering entirely.
        // (`isSnapSuppressed` is also checked inside the engine itself before
        // this callback ever fires - see `apply(_:)`.)
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
