import Testing
@testable import SWSOverlay
import CoreGraphics

@Test func usableAXFrameExcludesMenuBarFromTop() {
    // A 1800x1169 screen with a ~38pt menu bar and no Dock: visibleFrame's
    // top edge sits 38pt below the full screen's top edge.
    let fullScreenFrame = CGRect(x: 0, y: 0, width: 1800, height: 1169)
    let visibleScreenFrame = CGRect(x: 0, y: 0, width: 1800, height: 1131)

    let usable = ScreenGeometry.usableAXFrame(fullScreenFrame: fullScreenFrame, visibleScreenFrame: visibleScreenFrame)

    // In AX space (top-left origin), the usable area should start 38pt down
    // from the true top, not at y=0 - a zone anchored to y=0 in AX space
    // would otherwise target a position under the menu bar.
    #expect(usable == CGRect(x: 0, y: 38, width: 1800, height: 1131))
}

@Test func usableAXFrameAccountsForDockAtBottom() {
    // Dock at the bottom eats into visibleFrame from AppKit's y=0 upward.
    let fullScreenFrame = CGRect(x: 0, y: 0, width: 1800, height: 1169)
    let visibleScreenFrame = CGRect(x: 0, y: 80, width: 1800, height: 1051)

    let usable = ScreenGeometry.usableAXFrame(fullScreenFrame: fullScreenFrame, visibleScreenFrame: visibleScreenFrame)

    // Top inset is still 38 (1169 - (80 + 1051)), height matches visibleFrame.
    #expect(usable == CGRect(x: 0, y: 38, width: 1800, height: 1051))
}

@Test func usableAXFrameMatchesFullFrameWhenNoInsets() {
    let fullScreenFrame = CGRect(x: 0, y: 0, width: 1800, height: 1169)
    let usable = ScreenGeometry.usableAXFrame(fullScreenFrame: fullScreenFrame, visibleScreenFrame: fullScreenFrame)
    #expect(usable == CGRect(x: 0, y: 0, width: 1800, height: 1169))
}
