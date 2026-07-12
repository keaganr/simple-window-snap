import AppKit
@preconcurrency import ApplicationServices
import os

private let logger = Logger(subsystem: "com.keaganr.SimpleWindowSnap", category: "WindowRepositioner")

/// Pure eligibility rule, factored out so it's testable without real AX
/// elements: a window can only be snapped if it isn't full-screen (which
/// occupies its own Space and can't be frame-snapped normally) and both
/// its position and size are reported as settable.
public enum WindowEligibility {
    public static func isEligibleForSnapping(isFullScreen: Bool, isPositionSettable: Bool, isSizeSettable: Bool) -> Bool {
        !isFullScreen && isPositionSettable && isSizeSettable
    }
}

/// Moves/resizes windows belonging to (possibly) other applications via the
/// Accessibility API.
public enum WindowRepositioner {
    public static func isEligibleForSnapping(_ window: AXUIElement) -> Bool {
        // "AXFullScreen" has no public Swift constant (SDK headers don't
        // declare kAXFullScreenAttribute); it's a well-known but private
        // attribute name, same as used by other AX-based window managers.
        var fullScreenValue: CFTypeRef?
        let fullScreenResult = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fullScreenValue)
        // Not every window/app exposes this attribute; treat "unsupported" as
        // not full-screen rather than blocking snapping unnecessarily.
        let isFullScreen = fullScreenResult == .success && (fullScreenValue as? Bool) == true

        var positionSettable: DarwinBoolean = false
        var sizeSettable: DarwinBoolean = false
        let positionResult = AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &positionSettable)
        let sizeResult = AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &sizeSettable)

        return WindowEligibility.isEligibleForSnapping(
            isFullScreen: isFullScreen,
            isPositionSettable: positionResult == .success && positionSettable.boolValue,
            isSizeSettable: sizeResult == .success && sizeSettable.boolValue
        )
    }

    /// Sets a window's frame via the Accessibility API. `rect` must already
    /// be in AX/Quartz space (top-left origin) - see `CoordinateConversion`.
    ///
    /// Position is set before size. Confirmed empirically (both Ghostty and
    /// Finder reproduced this): setting size first, while the window is
    /// still at its *old* position, can push the bottom edge of the
    /// requested (full-height) size past the screen's usable bottom - e.g.
    /// dragging a window from the middle of the screen into a full-height
    /// zone at the top. macOS/the app clamps the height right then, and it
    /// doesn't grow back once the subsequent position change moves the
    /// window to where the full height would actually have fit. Moving
    /// first avoids that intermediate off-screen state for the zones this
    /// app targets (all anchored at the top); a future zone anchored at the
    /// bottom could in principle hit the mirror-image problem with the old
    /// *size* at the *new* position, but that's not a shape we have yet.
    ///
    /// Not guaranteed atomic or exact even so - some apps clamp to a
    /// minimum size or silently reject changes, so this reads back and logs
    /// a mismatch rather than retrying (retry-looping against a possibly-
    /// uncooperative app isn't worth the complexity here).
    public static func setFrame(_ rect: CGRect, for window: AXUIElement) {
        var size = rect.size
        var origin = rect.origin
        guard
            let sizeValue = AXValueCreate(.cgSize, &size),
            let positionValue = AXValueCreate(.cgPoint, &origin)
        else {
            logger.debug("Failed to create AXValue for frame \(rect.debugDescription, privacy: .public)")
            return
        }

        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)

        if sizeResult != .success || positionResult != .success {
            logger.debug("""
            setFrame partially failed: size=\(sizeResult.rawValue) position=\(positionResult.rawValue) \
            target=\(rect.debugDescription, privacy: .public)
            """)
        }
    }
}
