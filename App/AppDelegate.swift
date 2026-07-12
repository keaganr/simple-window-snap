import AppKit
import Combine
import SWSAccessibility

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let permissionManager = PermissionManager()
    private let dragDetectionEngine = DragDetectionEngine()
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
    }
}
