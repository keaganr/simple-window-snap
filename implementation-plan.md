# Simple Window Snap (SWS) — Implementation Plan

## Context

`functionality.md` describes a native macOS menu-bar utility that lets a user
pre-configure rectangular "snap zones" on screen (grouped into named
"configurations"), then drag any window from any app into one of those zones
to have it resize/reposition to fit. This is a from-scratch project (no code
exists yet, not even a git repo) and the user has never built a macOS app
before, so this plan also calls out the macOS-specific APIs by name and the
non-obvious constraints that shape the architecture.

Three decisions fix the shape of this project and are treated as fixed
constraints below:

1. **Direct distribution, unsandboxed** (not Mac App Store). Moving/resizing
   *other apps'* windows and observing system-wide drag gestures requires the
   Accessibility API, which doesn't work under the App Sandbox. This is the
   same approach used by Rectangle/Magnet/BetterSnapTool.
2. **macOS 13 Ventura+ minimum**, so the menu bar can use SwiftUI's
   `MenuBarExtra` (instead of manually wiring `NSStatusItem`) and modern
   Swift concurrency is available throughout.
3. **One small third-party SPM dependency is acceptable**:
   `sindresorhus/KeyboardShortcuts` for the global hotkey, rather than
   hand-rolling `CGEventTap`/Carbon hotkey registration.

Also fixed: zone creation uses a **grid picker** (à la Rectangle), and
**multi-monitor support is out of scope for v1** (single main display only,
architecture kept from painting itself into a corner but not built out).

## Project Structure

Standard Xcode App project (needed for a proper `.app` bundle, `Info.plist`
with `LSUIElement=YES`, code signing/notarization) containing local Swift
Packages for compartmentalized, independently-testable modules:

```
SimpleWindowSnap/
  SimpleWindowSnap.xcodeproj
  App/
    SimpleWindowSnapApp.swift     # @main, MenuBarExtra scene, editor Window scene
    AppDelegate.swift             # NSApplicationDelegateAdaptor
    Info.plist                    # LSUIElement = YES
    Assets.xcassets
  Packages/
    SWSModel/            # Codable data model + geometry + JSON persistence (pure Swift)
    SWSAccessibility/    # Drag-detection engine + AX window read/write (AppKit + ApplicationServices)
    SWSOverlay/           # Transparent click-through overlay window(s)
    SWSUI/                # SwiftUI views: menu bar content, grid picker, config editor
  README.md
  .gitignore
```

`KeyboardShortcuts` is added as an SPM dependency, wrapped by a thin
`SWSHotkey` layer so the rest of the app doesn't import it directly.

## Core Technical Design

**Drag detection (the crux):** combine `NSEvent.addGlobalMonitorForEvents`
(watching `.leftMouseDown/.leftMouseDragged/.leftMouseUp`) with per-app
`AXObserver` notifications (`kAXWindowMovedNotification`,
`kAXWindowResizedNotification`) in a small state machine
(`DragDetectionEngine`). On mouse-down, hit-test with
`AXUIElementCopyElementAtPosition` to find the window under the cursor; on
mouse-up, evaluate cursor position against the active configuration's zones.
The `AXObserver` must be torn down and recreated whenever the frontmost app
changes (`NSWorkspace.didActivateApplicationNotification`).

**Repositioning windows:** `AXUIElementSetAttributeValue` with
`kAXSizeAttribute` (set first) then `kAXPositionAttribute`, via
`AXUIElementCreateSystemWide()` / the target window's `AXUIElement`.

**Coordinate systems:** AppKit is bottom-left origin; the Accessibility API
and Quartz are top-left origin. All zone math is stored as
`NormalizedRect` (0.0–1.0 fractions, top-left origin) and every AX
read/write or overlay draw routes through one pure, unit-tested conversion
function — never inline math. This is the single most common bug source in
apps like this.

**Overlay:** borderless, transparent, click-through `NSWindow`
(`ignoresMouseEvents = true`, `level = .screenSaver`, `backgroundColor =
.clear`) sized to the main screen, drawing all zones of the active
configuration with the zone under the cursor highlighted.

**Permission:** `AXIsProcessTrustedWithOptions` to prompt; poll
`AXIsProcessTrusted()` (no OS push notification exists for "just granted")
and re-check on `NSApplication.didBecomeActiveNotification`; gate engine
startup on trust and re-register monitors after a fresh grant.

**Persistence:** `Codable` structs (`SnapZone`, `SnapConfiguration`) as JSON
at `~/Library/Application Support/SimpleWindowSnap/configurations.json`
(not `UserDefaults` — easier to inspect/back up, no plist-bridging quirks),
via an injectable `ConfigurationStore` so tests can point at a temp
directory.

**Grid picker:** SwiftUI `Canvas` + `DragGesture` over a fixed grid (e.g.
6×4); selecting a cell span maps to a `NormalizedRect` via one pure,
testable function.

**Global hotkey:** `KeyboardShortcuts.onKeyDown` fires a discrete toggle of a
`dragSnapSuppressed` flag for the remainder of the current drag gesture only
(reset on next mouse-down). Recommended default: **⌃⌥⌘D** — F13+ keys don't
exist on most modern Mac keyboards, so a quadruple-modifier combo is a safer
out-of-the-box default; configurable in Preferences via
`KeyboardShortcuts.Recorder`.

> **Superseded after Phase 7 shipped:** the discrete-toggle hotkey above was
> built as planned, but real usage showed it was cumbersome to hit reliably
> one-handed mid-drag, and toggling meant remembering whether suppression
> was currently on. It was replaced with a live modifier-hold instead:
> `DragDetectionEngine` monitors `.flagsChanged` directly and sets
> `isSnapSuppressed` to match the key's physical state in real time (hold
> to suppress, release to resume - nothing to remember). Option was tried
> first but conflicts with macOS's own native window tiling, which is
> already bound to holding Option while dragging; **Control** has no known
> native drag-time binding and was kept as the (currently hardcoded, no
> customization UI) modifier. This removed the `SWSHotkey` package, its
> `KeyboardShortcuts` dependency, and the Preferences window entirely -
> none of it is needed for passive modifier-flag monitoring.

## Workflow Notes

- A copy of this plan will be committed to the repo as
  `implementation-plan.md` at the start of Phase 0 (the repo has already
  been `git init`'d by the user).
- Each numbered phase below is a distinct git commit (or a small number of
  commits if a phase is large enough to benefit from splitting) — committed
  once that phase's demoable behavior works, so the user can review the
  history one stopping point at a time.

## Phased Build Order (each phase demoable)

0. **Scaffolding** — Xcode project, `LSUIElement=YES`, empty local packages, `KeyboardShortcuts` dependency, git init, README stub.
1. **Permission flow** — `AXIsProcessTrustedWithOptions` prompt/polling, menu status reflecting grant state.
2. **Drag detection (log-only)** — global mouse monitor + AX hit-test + observer attach/detach, logged via `os.Logger`.
3. **Overlay rendering (hardcoded zones)** — overlay window shown/hidden by drag state, cursor-hover highlight.
4. **Snap-on-release** — coordinate-flip functions, hit test at mouse-up, `AXUIElementSetAttributeValue` move/resize against hardcoded zones.
5. **Configuration model + grid editor** — `SWSModel` structs, `ConfigurationStore`, `GridPickerView`/editor window, wire real data in place of hardcoded zones.
6. **Multiple configurations + menu switching** — "Configurations ▸" submenu, live switch of active zone set.
7. **Global hotkey** — `KeyboardShortcuts` integration, Preferences recorder, per-gesture suppress flag.
8. **Polish/packaging/tests/docs** — launch-at-login, edge cases (full-screen/minimized windows, non-Cocoa apps), unit tests, Developer ID signing + notarization, final README.

## Testing Strategy

- **Unit-testable (XCTest, CI-safe):** `SWSModel` Codable round-trips,
  `NormalizedRect ↔ CGRect` conversion, grid-cell → `NormalizedRect`
  mapping, zone hit-testing, `ConfigurationStore` CRUD against an injected
  temp directory, and the AppKit↔AX coordinate-flip functions — all kept as
  pure functions specifically so they're testable without touching real AX
  APIs.
- **Manual/integration QA only:** anything requiring real Accessibility
  permission or real `AXObserver`/`AXUIElementSetAttributeValue` calls
  against other apps (can't run in CI). Maintain a manual QA checklist
  (README or `TESTING.md`): drag from Finder/Safari/a non-Cocoa app,
  multi-window apps, full-screen/minimized edge cases, permission revoked
  mid-session, hotkey suppress, config switch mid-drag.

## Known Sharp Edges (worth documenting in README as encountered)

- Accessibility grant is keyed to code signature + path — ad-hoc/debug
  signing churn across rebuilds can force re-approval; `tccutil reset
  Accessibility <bundle-id>` is the recovery command.
- `AXObserver` is per-pid; forgetting to tear down (`CFRunLoopRemoveSource`)
  on app-switch leaks/duplicates callbacks.
- Not all windows are fully AX-compliant (Electron/Chromium/Java apps) —
  `AXUIElementSetAttributeValue` may silently fail; degrade gracefully.
- Full-screen windows (`kAXFullScreenAttribute == true`) live on a dedicated
  Space and can't be frame-snapped normally — detect and skip.
- `LSUIElement` must be exactly `YES` or the app shows both a Dock icon and
  a menu bar icon.
- No sandbox means no entitlements-file complexity, but distributing to
  other Macs still needs a paid Developer ID cert + notarization (only
  needed at Phase 8, not for local `⌘R` development).

## Critical Files

- `App/SimpleWindowSnapApp.swift` — `@main` entry, `MenuBarExtra` scene
- `Packages/SWSAccessibility/Sources/SWSAccessibility/DragDetectionEngine.swift` — the crux drag state machine
- `Packages/SWSAccessibility/Sources/SWSAccessibility/CoordinateConversion.swift` — AppKit↔AX flip (pure, unit tested)
- `Packages/SWSOverlay/Sources/SWSOverlay/OverlayWindowController.swift` — transparent click-through zone overlay
- `Packages/SWSModel/Sources/SWSModel/ConfigurationStore.swift` — persistence + active-configuration state
- `Packages/SWSUI/Sources/SWSUI/GridPickerView.swift` — grid-to-`NormalizedRect` selection UI

## Verification

- Each phase above is individually demoable by running the app (`⌘R` in
  Xcode) and exercising that phase's behavior directly (e.g. Phase 2: drag a
  Finder window and watch console logs; Phase 4: drag into a hardcoded zone
  and confirm it snaps).
- Run `⌘U` / `xcodebuild test` for the `SWSModel` and pure-function test
  suites after each phase that touches them.
- Before declaring the app "done," walk the manual QA checklist above at
  least once against real third-party apps (not just Xcode/Finder), since
  the Accessibility-dependent behavior can't be verified any other way.
