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
/// This phase (log-only) does not yet show an overlay or snap anything; it
/// exists to prove the detection plumbing works before building on top of
/// it. Must only be started once Accessibility permission is granted -
/// `NSEvent.addGlobalMonitorForEvents` silently receives nothing otherwise.
@MainActor
public final class DragDetectionEngine {
    private var phase: DragPhase = .idle

    // `nonisolated(unsafe)` for the same reason as PermissionManager: `deinit`
    // is always nonisolated even on a @MainActor class, and these are
    // otherwise only ever touched on the main actor.
    private nonisolated(unsafe) var mouseMonitor: Any?
    private nonisolated(unsafe) var activationObserver: NSObjectProtocol?
    private nonisolated(unsafe) var axObserver: AXObserver?
    private nonisolated(unsafe) var observedPID: pid_t?

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
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
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

        if case .mouseDown = lifecycleEvent {
            logWindow(atMouseLocation: location)
        }

        apply(lifecycleEvent)
    }

    private func apply(_ event: DragLifecycleEvent) {
        let previous = phase
        phase = DragPhaseReducer.reduce(phase: phase, event: event)
        guard phase != previous else { return }
        logger.debug("Drag phase \(String(describing: previous), privacy: .public) -> \(String(describing: self.phase), privacy: .public)")
    }

    // MARK: - Hit-testing (log-only for now; used for real in Phase 4)

    private func logWindow(atMouseLocation location: CGPoint) {
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
        let movedOrResized = [kAXWindowMovedNotification as String, kAXWindowResizedNotification as String]
        if movedOrResized.contains(notification) {
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
