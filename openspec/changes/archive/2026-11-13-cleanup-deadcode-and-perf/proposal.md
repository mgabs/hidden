# Proposal

## Intent
Remove verified dead code and eliminate main-thread/hot-path performance bottlenecks in `hidden/` while preserving existing user-facing behavior and testability.

## Problem Statement
1. Several unused files, `@IBOutlet`s, methods, and struct fields remain in `hidden/`, adding maintenance noise and dead Xcode project entries.
2. `NotchOverflowController.getAllMenuBarExtras()` runs synchronous Accessibility IPC across all running processes (including XPC/WebKit helpers) on the main thread with no timeout, risking multi-second UI freezes when opening the overflow menu.
3. Repeated allocations and screen queries occur on hot paths (`hoverToExpand` `.mouseMoved`, `Date+Extension`, `Assets`, `LegacyLengthEngine`).

## Capabilities

### New Capabilities
- `notch-overflow-async-scan`: Off-main, timeout-bounded, concurrent Accessibility enumeration for `NotchOverflowController` without blocking the UI thread.

### Modified Capabilities
- None (no existing specs under `openspec/specs/`).

## Scope

### In-Scope
- Remove dead files (`NSBarButtonItem+Extension.swift`, `NSView+Extension.swift`) and update `Hidden Bar.xcodeproj/project.pbxproj`.
- Remove unused symbols/outlets (`GlobalKeybindPreferences.save()`, `Constant.appName`, `PreferencesViewController` unconnected outlets `checkBoxKeepLastState`/`imageViewTop`/`checkBoxKeepInDock`, `HyperlinkTextField.awakeFromNib()`, `MenuBarExtraInfo.pid` and its test fixture arguments).
- Cache `DateFormatter` instances in `Date+Extension.swift` and status bar icons in `Assets.swift`.
- Replace `.map { ... }.max()` with `.max(by:)` in `LegacyLengthEngine.collapsedLength`.
- Cache menu-bar screen rects in `StatusBarController` for `hoverToExpand` and invalidate on `NSApplication.didChangeScreenParametersNotification`.
- Make `NotchOverflowController.getAllMenuBarExtras()` filter `.app` bundles, set `0.1s` `AXUIElementSetMessagingTimeout`, scan concurrently off the main thread, and present the menu on completion on the main thread.

### Out-of-Scope (YAGNI)
- Do NOT alter `MenuBarClock.swift` synchronous `.leftMouseDown` handling (avoids `.leftMouseDown`/`.leftMouseUp` race).
- Do NOT refactor `NotchOverflowController.buildOverflowMenu(extras:boundary:)` signature used by `HiddenTests`.
- Do NOT modify Preferences UI layout or `Main.storyboard` beyond leaving unconnected outlets removed.

## Assumptions
- **ASM-GEN-1**: `PreferencesViewController` outlets `checkBoxKeepLastState`, `imageViewTop`, and `checkBoxKeepInDock` have no runtime KVC or storyboard connections.
- **ASM-GEN-2**: `NotchOverflowController` only needs `bundleURL?.pathExtension == "app"` processes for menu bar extras, matching `AccessibilityMenuBarInventory`.

## Success Metrics
- `make test` passes all tests (`HiddenBarTests` + `HiddenTests`) with 0 failures.
- `make build` (`Release-Direct`) succeeds with 0 new warnings.
- `NotchOverflowController.showOverflowMenuFromSeparator` performs zero AX IPC on the main thread.

## Review Gate
- [x] **Gate 1 Approval**: Proposal reviewed and approved by human before drafting specs.
