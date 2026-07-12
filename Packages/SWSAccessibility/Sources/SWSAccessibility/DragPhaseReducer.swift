import CoreGraphics

/// Raw drag-lifecycle signals, abstracted away from their real sources
/// (`NSEvent` global monitors and `AXObserver` notifications) so the phase
/// transition logic below can be tested without touching either.
public enum DragLifecycleEvent: Equatable, Sendable {
    case mouseDown(location: CGPoint)
    case mouseDragged(location: CGPoint)
    case mouseUp(location: CGPoint)
    /// An AX notification (window moved/resized) arrived for the candidate
    /// window. Some apps move their window on the first `AXWindowMoved`
    /// notification before `NSEvent` reports a `.leftMouseDragged`, so this
    /// is treated as an equally valid drag-start signal.
    case windowMoved
}

public enum DragPhase: Equatable, Sendable {
    case idle
    /// Mouse went down on a window, but the drag threshold hasn't been
    /// crossed yet - could still turn out to be a plain click.
    case candidate(startLocation: CGPoint)
    case dragging(startLocation: CGPoint)
}

/// Pure state machine for drag detection. Kept free of AppKit/Accessibility
/// so it can be driven by synthetic event sequences in tests.
public enum DragPhaseReducer {
    public static func reduce(phase: DragPhase, event: DragLifecycleEvent) -> DragPhase {
        switch phase {
        case .idle:
            if case .mouseDown(let location) = event {
                return .candidate(startLocation: location)
            }
            return .idle

        case .candidate(let start):
            switch event {
            case .mouseDragged, .windowMoved:
                return .dragging(startLocation: start)
            case .mouseUp:
                return .idle
            case .mouseDown:
                return phase
            }

        case .dragging(let start):
            switch event {
            case .mouseUp:
                return .idle
            case .mouseDown, .mouseDragged, .windowMoved:
                return .dragging(startLocation: start)
            }
        }
    }
}
