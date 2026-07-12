import CoreGraphics

/// Conversions between AppKit's screen space (origin at the bottom-left of
/// the primary display, Y increases upward) and the Accessibility API /
/// Quartz screen space (origin at the top-left of the primary display, Y
/// increases downward). Every AX read/write and overlay draw should route
/// through these rather than doing the math inline - mixing up the two
/// coordinate spaces is one of the most common bugs in apps like this.
public enum CoordinateConversion {
    /// Flips a point between AppKit and AX/Quartz space. The transform is
    /// its own inverse, so this works in both directions.
    public static func flipPointY(_ point: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    /// Converts a rect's origin between the two spaces. Unlike a point, a
    /// rect's AppKit origin is its bottom-left corner while its AX/Quartz
    /// origin is its top-left corner, so this flips on `maxY` rather than `y`.
    public static func flipRectY(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}
