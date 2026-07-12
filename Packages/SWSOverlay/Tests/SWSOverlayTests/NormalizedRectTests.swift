import Testing
@testable import SWSOverlay

private let leftThird = NormalizedRect(x: 0, y: 0, width: 1.0 / 3, height: 1)
private let rightThird = NormalizedRect(x: 2.0 / 3, y: 0, width: 1.0 / 3, height: 1)
private let topCenter = NormalizedRect(x: 1.0 / 3, y: 0, width: 1.0 / 3, height: 0.5)
private let allZones = [leftThird, rightThird, topCenter]

@Test func containsFractionInsideBounds() {
    #expect(leftThird.contains(fractionX: 0.1, fractionY: 0.5))
}

@Test func containsFractionOnBoundaryIsInclusive() {
    #expect(leftThird.contains(fractionX: 1.0 / 3, fractionY: 0))
    #expect(leftThird.contains(fractionX: 0, fractionY: 1))
}

@Test func containsFractionOutsideBoundsIsFalse() {
    #expect(!leftThird.contains(fractionX: 0.5, fractionY: 0.5))
}

@Test func zoneHitTestingFindsCorrectZone() {
    #expect(ZoneHitTesting.zone(containingFractionX: 0.1, fractionY: 0.9, in: allZones) == leftThird)
    #expect(ZoneHitTesting.zone(containingFractionX: 0.9, fractionY: 0.1, in: allZones) == rightThird)
    #expect(ZoneHitTesting.zone(containingFractionX: 0.5, fractionY: 0.1, in: allZones) == topCenter)
}

@Test func zoneHitTestingReturnsNilOutsideAllZones() {
    // Bottom-center is outside all three zones (below topCenter, between the thirds).
    #expect(ZoneHitTesting.zone(containingFractionX: 0.5, fractionY: 0.9, in: allZones) == nil)
}

@Test func zoneHitTestingReturnsFirstMatchOnOverlap() {
    let overlapping = NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5)
    let zones = [leftThird, overlapping]
    // (0.1, 0.1) is inside both leftThird and overlapping; first in the list wins.
    #expect(ZoneHitTesting.zone(containingFractionX: 0.1, fractionY: 0.1, in: zones) == leftThird)
}
