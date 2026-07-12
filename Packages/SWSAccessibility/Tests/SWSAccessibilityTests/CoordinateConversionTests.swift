import Testing
@testable import SWSAccessibility
import CoreGraphics

private let screenHeight: CGFloat = 1080

@Test func flipPointYIsSelfInverse() {
    let nsPoint = CGPoint(x: 50, y: 100)
    let axPoint = CoordinateConversion.flipPointY(nsPoint, primaryScreenHeight: screenHeight)
    #expect(axPoint == CGPoint(x: 50, y: 980))

    let roundTripped = CoordinateConversion.flipPointY(axPoint, primaryScreenHeight: screenHeight)
    #expect(roundTripped == nsPoint)
}

@Test func flipPointYAtOrigin() {
    // AppKit's (0, 0) is the bottom-left of the primary screen, which is
    // the top-left corner in AX/Quartz space at y == screenHeight.
    let axPoint = CoordinateConversion.flipPointY(.zero, primaryScreenHeight: screenHeight)
    #expect(axPoint == CGPoint(x: 0, y: screenHeight))
}

@Test func flipRectYConvertsBottomLeftOriginToTopLeftOrigin() {
    // A 200x100 window whose AppKit origin (bottom-left) is (10, 20) has its
    // top edge at y = 20 + 100 = 120 in AppKit space, which becomes the AX
    // rect's y origin (screenHeight - 120).
    let nsRect = CGRect(x: 10, y: 20, width: 200, height: 100)
    let axRect = CoordinateConversion.flipRectY(nsRect, primaryScreenHeight: screenHeight)
    #expect(axRect == CGRect(x: 10, y: screenHeight - 120, width: 200, height: 100))
}
