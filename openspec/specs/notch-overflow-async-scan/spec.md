# notch-overflow-async-scan Specification

## Purpose
Off-main, timeout-bounded, concurrent Accessibility enumeration for `NotchOverflowController` so opening the notch overflow menu never blocks the UI thread.

## Requirements

### Requirement: REQ-NOTCH-1 Off-main concurrent Accessibility scan
`NotchOverflowController.showOverflowMenuFromSeparator(near:)` MUST perform Accessibility menu-bar enumeration off the main thread, filtering to `.app` bundles (`bundleURL?.pathExtension == "app"`) with a `0.1` second `AXUIElementSetMessagingTimeout` per application and concurrent per-app scanning, and MUST present the built `NSMenu` on the main thread.

#### Scenario: Opening overflow menu with multiple running apps
- **GIVEN** Accessibility permission is granted and multiple `.app` and helper processes are running
- **WHEN** `showOverflowMenuFromSeparator(near:)` is invoked
- **THEN** only `.app` bundles (excluding the current process) are queried concurrently off the main thread with a `0.1`s AX timeout, and the resulting menu is attached and clicked on the main thread

#### Scenario: Accessibility permission missing
- **GIVEN** Accessibility permission is not granted
- **WHEN** `showOverflowMenuFromSeparator(near:)` is invoked
- **THEN** no background AX scan is started

### Requirement: REQ-NOTCH-2 Synchronous testable menu builder preserved
`NotchOverflowController.buildOverflowMenu(extras:boundary:)` MUST remain synchronous when `extras` is injected so existing unit tests execute deterministically without live Accessibility IPC.

#### Scenario: Unit test injects synthetic extras
- **GIVEN** a caller passes a synthetic `[MenuBarExtraInfo]` array to `buildOverflowMenu(extras:boundary:)`
- **WHEN** the menu is built
- **THEN** it returns the classified `NSMenu` synchronously without querying `NSWorkspace` or Accessibility

### Requirement: NFR-NOTCH-1 Main-thread AX latency budget
`NotchOverflowController.showOverflowMenuFromSeparator(near:)` MUST execute zero `AXUIElementCopyAttributeValue` calls on the main thread.

#### Scenario: Main-thread non-blocking check
- **GIVEN** a slow or unresponsive `.app` process
- **WHEN** `showOverflowMenuFromSeparator(near:)` runs
- **THEN** the main thread returns immediately and the slow app's AX query times out at `0.1`s on a background queue
