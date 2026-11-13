# deadcode-perf-pass2 Specification

## Purpose
Specifies dead-code/asset removal, complete `StatusBarController` teardown, main-thread icon caching in `NotchOverflowController`, and cached clock-frame hit-testing in `SystemMenuBarClock`.

## Requirements

### Requirement: REQ-CLEAN-1 Dead Symbol & Asset Removal
The codebase MUST NOT retain `@IBOutlet textFieldTitle`, `NotchOverflowController.getAllMenuBarExtras()`, `NotchGeometry.computeBoundary` `screenFrame:` parameter, unused `import Carbon` in `PreferencesViewController.swift`, or the 4 unused `.imageset`s (`banner_alway_hide`, `banner`, `ic_dot`, `ico_fb`).

#### Scenario: Clean build without dead symbols or assets
- **GIVEN** the dead outlets, fallback methods, unused imports/parameters, and 4 `.imageset` folders are removed
- **WHEN** `make test` and `make build` run
- **THEN** all targets compile and pass without missing outlet or asset references

### Requirement: REQ-CLEAN-2 Complete StatusBarController Teardown
`StatusBarController.deinit` MUST invalidate `timer` and remove `self` from `NSWorkspace.shared.notificationCenter` in addition to existing `hoverDwellTimer` and `NotificationCenter.default` cleanup.

#### Scenario: Deallocation cleans timers and workspace observers
- **GIVEN** a `StatusBarController` with an active auto-hide `timer` and `NSWorkspace.shared.notificationCenter` observers
- **WHEN** `StatusBarController` is deallocated
- **THEN** `timer` is invalidated and `NSWorkspace.shared.notificationCenter` observers for `self` are removed

### Requirement: REQ-PERF-1 Main-Thread Icon Access & Resize Caching
`NotchOverflowController` MUST read `NSRunningApplication.icon` on the main thread when constructing menu items rather than inside background AX worker threads, and cache resized menu icons per application/tint key.

#### Scenario: Menu icon reading and caching
- **GIVEN** `fetchMenuBarExtras` scans running apps concurrently off the main thread
- **WHEN** `buildOverflowMenu(extras:boundary:)` constructs `NSMenuItem`s on the main thread
- **THEN** `app.icon` is accessed only on the main thread and `resizedForMenu(tinted:)` results are reused from cache on subsequent menu opens

### Requirement: REQ-PERF-2 Cached SystemMenuBarClock Hit-Testing
`SystemMenuBarClock` MUST cache resolved clock frames and invalidate the cache on `NSApplication.didChangeScreenParametersNotification`, avoiding synchronous AX IPC on repeated menu-bar `.leftMouseDown` checks when the cache is warm.

#### Scenario: Repeated menu-bar click with warm clock cache
- **GIVEN** `SystemMenuBarClock` has populated its clock-frame cache
- **WHEN** the user clicks in the menu-bar band multiple times without screen parameter changes
- **THEN** `SystemMenuBarClock` hit-tests against cached clock frames without repeating synchronous `AXUIElementCopyAttributeValue` IPC, and invalidates the cache when `didChangeScreenParametersNotification` posts

### Requirement: NFR-PERF-1 Main-Thread Clock Hit-Test Latency
Warm hit-testing in `SystemMenuBarClock.handle(_:)` MUST complete in O(k) memory comparisons (where k is the number of cached clock rects, typically 1-2) with zero AX IPC.

#### Scenario: Warm cache hit-test
- **GIVEN** cached clock frames exist
- **WHEN** `handle(_:)` evaluates a `.leftMouseDown` outside or inside a clock frame
- **THEN** no AX IPC is executed during the hit-test
