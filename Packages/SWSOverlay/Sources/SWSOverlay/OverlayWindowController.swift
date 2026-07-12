import AppKit
import SwiftUI

/// A transparent, click-through, always-on-top window covering the main
/// screen, used to highlight configured snap zones while the user drags a
/// window around. Single-display only for now, matching the app's v1 scope.
@MainActor
public final class OverlayWindowController {
    private let window: NSWindow
    private let state = OverlayState()

    public init() {
        let screenFrame = NSScreen.main?.frame ?? .zero
        window = NSWindow(
            contentRect: screenFrame,
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
    /// Call `updateCursor(atAXPoint:)` as the drag continues to update which
    /// zone is highlighted.
    public func show(zones: [NormalizedRect]) {
        guard let screenFrame = NSScreen.main?.frame else { return }
        window.setFrame(screenFrame, display: false)
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
        guard let screenFrame = NSScreen.main?.frame, screenFrame.width > 0, screenFrame.height > 0 else { return }
        let fractionX = axPoint.x / screenFrame.width
        let fractionY = axPoint.y / screenFrame.height
        state.highlightedZone = ZoneHitTesting.zone(containingFractionX: fractionX, fractionY: fractionY, in: state.zones)
    }
}
