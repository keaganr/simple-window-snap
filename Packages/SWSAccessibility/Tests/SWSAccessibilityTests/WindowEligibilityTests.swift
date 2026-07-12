import Testing
@testable import SWSAccessibility

@Test func eligibleWhenMovableResizableAndNotFullScreen() {
    #expect(WindowEligibility.isEligibleForSnapping(isFullScreen: false, isPositionSettable: true, isSizeSettable: true))
}

@Test func ineligibleWhenFullScreen() {
    #expect(!WindowEligibility.isEligibleForSnapping(isFullScreen: true, isPositionSettable: true, isSizeSettable: true))
}

@Test func ineligibleWhenPositionNotSettable() {
    #expect(!WindowEligibility.isEligibleForSnapping(isFullScreen: false, isPositionSettable: false, isSizeSettable: true))
}

@Test func ineligibleWhenSizeNotSettable() {
    #expect(!WindowEligibility.isEligibleForSnapping(isFullScreen: false, isPositionSettable: true, isSizeSettable: false))
}
