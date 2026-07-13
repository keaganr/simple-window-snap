import AppKit
// Several AX*.h constants (kAXWindowMovedNotification, kAXWindowRole, etc.)
// are declared as non-const `extern CFStringRef` globals, which strict
// concurrency checking flags as unsafe shared state. `@preconcurrency`
// silences that for this legacy C API surface, which predates Swift
// concurrency entirely - see the same note in PermissionManager.swift.
@preconcurrency import ApplicationServices
import os

private let logger = Logger(subsystem: "com.keaganr.SimpleWindowSnap", category: "DragDetectionEngine")

/// Combines a global mouse-event monitor with per-app `AXObserver`
/// notifications to detect when the user starts/continues/ends dragging a
/// window - any window, belonging to any app, not just this one.
///
/// Publishes `phase` and `cursorLocation` so other layers (e.g. the
/// overlay) can react without depending on AppKit/Accessibility types
/// directly. Must only be started once Accessibility permission is
/// granted - `NSEvent.addGlobalMonitorForEvents` silently receives
/// nothing otherwise.
@MainActor
public final class DragDetectionEngine: ObservableObject {
    @Published public private(set) var phase: DragPhase = .idle
    /// Cursor location in AX/Quartz space (top-left origin), updated on
    /// every mouse-down/dragged event while a drag is in progress.
    @Published public private(set) var cursorLocation: CGPoint = .zero
    /// Whether Control has been pressed at any point since the current drag
    /// started: a single tap latches this `true` for the rest of the drag,
    /// even after Control is released - it never goes back to `false` until
    /// the next mouse-down. Releasing Control at the same instant as the
    /// mouse button (a common way to end a drag) used to race the live
    /// modifier state and could leave snapping enabled by accident; latching
    /// removes that race, at the cost of no longer being able to change your
    /// mind mid-drag once you've tapped Control. (Not Option: macOS's own
    /// native window tiling is already bound to holding Option while
    /// dragging, so that would conflict.)
    @Published public private(set) var isSnapSuppressed = false

    /// Called each time Option transitions from up to down while `.dragging`
    /// - i.e. once per keypress, not continuously while held. Intended for
    /// swapping to the next snap configuration mid-drag; not latched like
    /// `isSnapSuppressed` since the user should be able to press it multiple
    /// times to cycle through more than two configurations.
    public var onCycleConfigurationRequested: (() -> Void)?

    /// Whether Option was down as of the last `.flagsChanged` event, used to
    /// detect the up-to-down transition above rather than firing repeatedly
    /// while held.
    private var wasOptionKeyDown = false

    /// Called synchronously when a drag ends (mouse-up while `.dragging`),
    /// *before* the candidate window reference is cleared - the handler
    /// can call `snapCandidateWindow(toAXRect:)` from within this callback
    /// to act on the drag that just ended.
    public var onDragEnded: (() -> Void)?

    // `nonisolated(unsafe)` for the same reason as PermissionManager: `deinit`
    // is always nonisolated even on a @MainActor class, and these are
    // otherwise only ever touched on the main actor.
    private nonisolated(unsafe) var mouseMonitor: Any?
    private nonisolated(unsafe) var activationObserver: NSObjectProtocol?
    private nonisolated(unsafe) var axObserver: AXObserver?
    private nonisolated(unsafe) var observedPID: pid_t?

    /// The window found under the cursor at the most recent mouse-down,
    /// if any and if eligible for snapping. Retained until the *next*
    /// mouse-down (not cleared when the drag ends) so `onDragEnded`
    /// handlers can still read it via `snapCandidateWindow(toAXRect:)`.
    private var candidateWindow: AXUIElement?

    /// Whether a genuine `AXWindowMovedNotification` was observed since the
    /// last mouse-down. Resizing a window (e.g. dragging a corner/edge) also
    /// satisfies the `.leftMouseDown`/`.leftMouseDragged`/`.leftMouseUp`
    /// pattern that promotes `.candidate` to `.dragging`, but only produces
    /// `AXWindowResizedNotification`, never `AXWindowMovedNotification` - so
    /// this distinguishes an actual move (snap-eligible) from a resize
    /// (should be left alone) at the point `onDragEnded` decides whether to
    /// fire.
    private var sawGenuineWindowMove = false

    public init() {}

    deinit {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        if let axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .defaultMode)
        }
    }

    public func start() {
        guard mouseMonitor == nil else { return }
        logger.info("Starting drag detection")

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .flagsChanged]
        ) { [weak self] event in
            self?.handle(event)
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            MainActor.assumeIsolated {
                self?.attachAXObserver(toPID: app.processIdentifier)
            }
        }

        if let frontmost = NSWorkspace.shared.frontmostApplication {
            attachAXObserver(toPID: frontmost.processIdentifier)
        }
    }

    public func stop() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        mouseMonitor = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
        detachAXObserver()
        phase = .idle
        logger.info("Stopped drag detection")
    }

    // MARK: - Mouse events

    private func handle(_ event: NSEvent) {
        if event.type == .flagsChanged {
            if event.modifierFlags.contains(.control) {
                isSnapSuppressed = true
            }

            let isOptionKeyDown = event.modifierFlags.contains(.option)
            if isOptionKeyDown, !wasOptionKeyDown, case .dragging = phase {
                onCycleConfigurationRequested?()
            }
            wasOptionKeyDown = isOptionKeyDown
            return
        }

        let location = NSEvent.mouseLocation // AppKit space: bottom-left origin
        let lifecycleEvent: DragLifecycleEvent
        switch event.type {
        case .leftMouseDown:
            lifecycleEvent = .mouseDown(location: location)
        case .leftMouseDragged:
            lifecycleEvent = .mouseDragged(location: location)
        case .leftMouseUp:
            lifecycleEvent = .mouseUp(location: location)
        default:
            return
        }

        if let primaryScreenHeight = NSScreen.screens.first?.frame.height {
            cursorLocation = CoordinateConversion.flipPointY(location, primaryScreenHeight: primaryScreenHeight)
        }

        if case .mouseDown = lifecycleEvent {
            logWindow(atMouseLocation: location)
        }

        // `.mouseDragged` deliberately isn't applied to the phase reducer:
        // resizing a window (dragging an edge/corner) produces these same
        // raw mouse events as moving it does, and NSEvent alone can't tell
        // the two apart. cursorLocation is still tracked above for when a
        // real drag *is* confirmed. Promotion out of `.candidate` instead
        // waits for AXWindowMovedNotification specifically (never fired by
        // a resize - see handleAXNotification), so a resize never shows the
        // overlay or engages the tool at all.
        if case .mouseDragged = lifecycleEvent {
            return
        }

        apply(lifecycleEvent)
    }

    private func apply(_ event: DragLifecycleEvent) {
        let previous = phase
        phase = DragPhaseReducer.reduce(phase: phase, event: event)
        guard phase != previous else { return }
        logger.debug("Drag phase \(String(describing: previous), privacy: .public) -> \(String(describing: self.phase), privacy: .public)")

        if case .dragging = previous, case .idle = phase, sawGenuineWindowMove, !isSnapSuppressed {
            onDragEnded?()
        }
    }

    /// Repositions the window captured at the most recent eligible
    /// mouse-down to `rect` (AX/Quartz space). No-op if there is no
    /// candidate window (e.g. the drag started on the desktop, or the
    /// window under the cursor wasn't eligible for snapping).
    public func snapCandidateWindow(toAXRect rect: CGRect) {
        guard let candidateWindow else {
            logger.debug("snapCandidateWindow called with no candidate window")
            return
        }
        WindowRepositioner.setFrame(rect, for: candidateWindow)
    }

    // MARK: - Hit-testing

    private func logWindow(atMouseLocation location: CGPoint) {
        candidateWindow = nil
        sawGenuineWindowMove = false
        // Not unconditionally false: if Control was already held down before
        // this drag started, no further .flagsChanged event will fire
        // during the drag to tell us that, so read the live state directly.
        isSnapSuppressed = NSEvent.modifierFlags.contains(.control)
        // Mirrors the line above: if Option is already held when the drag
        // starts, this isn't a fresh keypress, so seed the edge-detector
        // with the live state rather than defaulting to false.
        wasOptionKeyDown = NSEvent.modifierFlags.contains(.option)

        guard let primaryScreenHeight = NSScreen.screens.first?.frame.height else { return }
        let axPoint = CoordinateConversion.flipPointY(location, primaryScreenHeight: primaryScreenHeight)

        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(axPoint.x), Float(axPoint.y), &element)
        guard result == .success, let element else {
            logger.debug("Hit-test at (\(axPoint.x), \(axPoint.y)) found nothing (AXError \(result.rawValue))")
            return
        }

        guard let window = containingWindow(of: element) else {
            logger.debug("Hit-test element at (\(axPoint.x), \(axPoint.y)) has no containing window")
            return
        }

        guard WindowRepositioner.isEligibleForSnapping(window) else {
            logger.debug("Candidate window is not eligible for snapping (full-screen or not movable/resizable)")
            return
        }

        candidateWindow = window
        logFrame(of: window)
    }

    private func containingWindow(of element: AXUIElement) -> AXUIElement? {
        var roleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success,
           (roleValue as? String) == (kAXWindowRole as String) {
            return element
        }

        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &windowValue) == .success,
              let windowValue else {
            return nil
        }
        return (windowValue as! AXUIElement)
    }

    private func logFrame(of window: AXUIElement) {
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
        let title = (titleValue as? String) ?? "<untitled>"

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)

        var origin = CGPoint.zero
        var size = CGSize.zero
        if let positionValue {
            _ = AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
        }
        if let sizeValue {
            _ = AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }

        logger.info("Candidate window \"\(title, privacy: .public)\" frame=(\(origin.x), \(origin.y), \(size.width), \(size.height))")
    }

    // MARK: - AXObserver lifecycle

    private func attachAXObserver(toPID pid: pid_t) {
        guard pid != observedPID else { return }
        detachAXObserver()

        var observer: AXObserver?
        let creationResult = AXObserverCreate(pid, axObserverCallback, &observer)
        guard creationResult == .success, let observer else {
            logger.debug("Failed to create AXObserver for pid \(pid) (AXError \(creationResult.rawValue))")
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in [kAXWindowMovedNotification, kAXWindowResizedNotification, kAXFocusedWindowChangedNotification] {
            AXObserverAddNotification(observer, appElement, notification as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

        axObserver = observer
        observedPID = pid
        logger.debug("Attached AXObserver to pid \(pid)")
    }

    private func detachAXObserver() {
        guard let axObserver else { return }
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .defaultMode)
        self.axObserver = nil
        observedPID = nil
    }

    fileprivate func handleAXNotification(_ notification: String) {
        logger.debug("AX notification: \(notification, privacy: .public)")
        // Only a genuine move promotes the phase (and, via `apply`, can show
        // the overlay) - a resize (dragging an edge/corner) only ever
        // produces AXWindowResizedNotification, never AXWindowMoved, so it's
        // deliberately left alone here rather than treated the same way.
        if notification == kAXWindowMovedNotification as String {
            sawGenuineWindowMove = true
            apply(.windowMoved)
        }
    }
}

/// `AXObserverCallback` is a C function pointer and can't capture context,
/// so the engine instance is threaded through via the `refcon` parameter
/// (set to an unretained pointer to `self` in `attachAXObserver`).
private func axObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let engine = Unmanaged<DragDetectionEngine>.fromOpaque(refcon).takeUnretainedValue()
    // Bridge to a Sendable `String` before crossing into the MainActor
    // closure below - `notification` (CFString) isn't provably Sendable.
    let notificationName = notification as String
    MainActor.assumeIsolated {
        engine.handleAXNotification(notificationName)
    }
}
