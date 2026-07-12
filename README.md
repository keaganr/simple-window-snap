# Simple Window Snap (SWS)

A native macOS menu-bar utility for snapping windows into user-defined
screen zones. See [functionality.md](functionality.md) for the product
spec and [implementation-plan.md](implementation-plan.md) for the
architecture and build plan.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later

## Status

Early scaffolding in progress — see `implementation-plan.md` for the
phased build order. Each phase is landed as its own commit.

## Building & Running

_(To be filled in once the Xcode project is scaffolded — Phase 0.)_

## Development Notes

This app requires Accessibility permission (System Settings → Privacy &
Security → Accessibility) to observe and reposition windows belonging to
other applications. It is distributed outside the Mac App Store and is
unsandboxed by necessity, since the App Sandbox blocks the Accessibility
APIs this app depends on.
