import Testing
@testable import SWSAccessibility
import CoreGraphics

private let p1 = CGPoint(x: 100, y: 200)

@Test func idlePhaseIgnoresEverythingButMouseDown() {
    #expect(DragPhaseReducer.reduce(phase: .idle, event: .mouseDragged(location: p1)) == .idle)
    #expect(DragPhaseReducer.reduce(phase: .idle, event: .mouseUp(location: p1)) == .idle)
    #expect(DragPhaseReducer.reduce(phase: .idle, event: .windowMoved) == .idle)
}

@Test func mouseDownFromIdleBecomesCandidate() {
    let result = DragPhaseReducer.reduce(phase: .idle, event: .mouseDown(location: p1))
    #expect(result == .candidate(startLocation: p1))
}

@Test func candidatePromotesToDraggingOnMouseDragged() {
    let candidate = DragPhase.candidate(startLocation: p1)
    let result = DragPhaseReducer.reduce(phase: candidate, event: .mouseDragged(location: CGPoint(x: 110, y: 205)))
    #expect(result == .dragging(startLocation: p1))
}

@Test func candidatePromotesToDraggingOnWindowMoved() {
    let candidate = DragPhase.candidate(startLocation: p1)
    let result = DragPhaseReducer.reduce(phase: candidate, event: .windowMoved)
    #expect(result == .dragging(startLocation: p1))
}

@Test func candidateReturnsToIdleOnMouseUpWithoutDragging() {
    let candidate = DragPhase.candidate(startLocation: p1)
    let result = DragPhaseReducer.reduce(phase: candidate, event: .mouseUp(location: p1))
    #expect(result == .idle)
}

@Test func draggingReturnsToIdleOnMouseUp() {
    let dragging = DragPhase.dragging(startLocation: p1)
    let result = DragPhaseReducer.reduce(phase: dragging, event: .mouseUp(location: CGPoint(x: 300, y: 400)))
    #expect(result == .idle)
}

@Test func draggingStaysDraggingThroughFurtherMovement() {
    let dragging = DragPhase.dragging(startLocation: p1)
    let result = DragPhaseReducer.reduce(phase: dragging, event: .mouseDragged(location: CGPoint(x: 300, y: 400)))
    #expect(result == .dragging(startLocation: p1))
}
