import AppKit
import SwiftUI
import SWSModel

/// A transparent, click-through, always-on-top window covering the main
/// screen's usable area, used to highlight configured snap zones while the
/// user drags a window around. Single-display only for now, matching the
/// app's v1 scope.
@MainActor
public final class OverlayWindowController {
    private let window: NSWindow
    private let state = OverlayState()

    public init() {
        window = NSWindow(
            contentRect: NSScreen.main?.visibleFrame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: OverlayContentView(state: state))
    }

    /// Shows the overlay with the given zones highlighted as configured.
    /// Zones cover the screen's `visibleFrame` (excludes the menu bar/Dock),
    /// matching `snapCandidateWindow`'s target rects - see `ScreenGeometry`.
    /// Call `updateCursor(atAXPoint:)` as the drag continues to update which
    /// zone is highlighted.
    public func show(zones: [NormalizedRect]) {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
        window.setFrame(visibleFrame, display: false)
        state.zones = zones
        state.highlightedZone = nil
        window.orderFrontRegardless()
    }

    public func hide() {
        window.orderOut(nil)
        state.highlightedZone = nil
    }

    /// - Parameter axPoint: cursor location in AX/Quartz space (top-left
    ///   origin), matching the convention `DragDetectionEngine` publishes.
    public func updateCursor(atAXPoint axPoint: CGPoint) {
        guard let screen = NSScreen.main else { return }
        let usableAXFrame = ScreenGeometry.usableAXFrame(fullScreenFrame: screen.frame, visibleScreenFrame: screen.visibleFrame)
        state.highlightedZone = ZoneHitTesting.zone(containing: axPoint, screenFrame: usableAXFrame, in: state.zones)
    }
}
