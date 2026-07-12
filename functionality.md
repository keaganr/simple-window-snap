# simple-window-snap

## Overview

Simple Window Snap (SWS) is a tool which allows modular window configuration and snapping on MacOS.

Screen spaces are pre-configured by the user, then windows can be easily snapped to these spaces. Multiple configurations allow for different screen space boundaries.

## Requirements

- Runs only on MacOS
- Displays in the menu bar at the top of the window
- Areas are selected by user to be a snap space (think: left 1/3, top corner, etc).
- When dragging any window, all pre-configured spaces for the current configuration are highlighted (boxes drawn on screen) showing where the dragging can happen
- When user stops dragging, if the window is inside of a space, the window snaps to that space - resizing and relocating to fit the pre-defined area
- There is a hotkey to "deselect" the tool meaning user can disable snapping for that instance of drag and drop. Default hotkey is something infrequently used in macos, but can be updated.
- Different configurations exist which the user can swap between (controlled by clicking the app icon in the menu bar, in a sub-menu entry tehre).
- The different configurations allow for different layouts of preconfigured snap zones.

### Development

- Should be written as a native macos app
- Swift
- Use common best practices: README.md updated with dev instructions, tests written, compartmentalization of code for ease of development organization, etc
