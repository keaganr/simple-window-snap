import CoreGraphics

/// A rect expressed as fractions (0.0-1.0) of the screen's width/height,
/// making it resolution-independent. Origin is top-left, matching the
/// Accessibility API / Quartz convention used throughout this app.
///
/// This is a placeholder living in SWSOverlay for Phase 3's hardcoded
/// zones; Phase 5 introduces SWSModel with the real, persisted
/// configuration/zone types, at which point this moves there and
/// SWSOverlay depends on it instead of defining its own.
public struct NormalizedRect: Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func contains(fractionX: Double, fractionY: Double) -> Bool {
        fractionX >= x && fractionX <= x + width && fractionY >= y && fractionY <= y + height
    }
}

/// Finds which zone (if any) contains a given fractional point. Pure and
/// AX/AppKit-agnostic so it can be unit tested directly.
public enum ZoneHitTesting {
    public static func zone(containingFractionX fractionX: Double, fractionY: Double, in zones: [NormalizedRect]) -> NormalizedRect? {
        zones.first { $0.contains(fractionX: fractionX, fractionY: fractionY) }
    }
}
