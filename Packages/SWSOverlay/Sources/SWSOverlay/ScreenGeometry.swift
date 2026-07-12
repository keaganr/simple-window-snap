import CoreGraphics

/// Screen-space conversions needed to keep zones within the area windows
/// can actually occupy.
public enum ScreenGeometry {
    /// Converts a screen's `visibleFrame` (AppKit space, bottom-left origin,
    /// excludes the menu bar/Dock) into the equivalent AX/Quartz-space rect
    /// (top-left origin) - the space zone fractions and AX window
    /// positioning both use.
    ///
    /// Without this, a zone anchored to the top of the screen (y = 0 in AX
    /// space) targets a position under the menu bar, which no app can
    /// actually honor - each one clamps/adjusts the position differently
    /// when asked, which is what produced windows landing a few points
    /// short of filling their zone instead of a clean, predictable snap.
    public static func usableAXFrame(fullScreenFrame: CGRect, visibleScreenFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleScreenFrame.minX,
            y: fullScreenFrame.height - visibleScreenFrame.maxY,
            width: visibleScreenFrame.width,
            height: visibleScreenFrame.height
        )
    }
}
