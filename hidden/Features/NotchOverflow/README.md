# NotchOverflow

## Overview
Detects notched displays, enumerates running apps' menu bar extras via Accessibility (`AXUIElement`) APIs, classifies items hidden behind the notch vs. visible, and presents an overflow `NSMenu` anchored to a status item.

## Interface
- [NotchOverflowController.swift:MenuBarExtraInfo](file:///Users/mmetawea/Workbench/hidden/hidden/Features/NotchOverflow/NotchOverflowController.swift#L14) — value type holding `element: AXUIElement`, `appName: String`, `appIcon: NSImage?`, `title: String?`, `position: CGPoint`, and `size: CGSize`.
- [NotchOverflowController.swift:NotchBoundary](file:///Users/mmetawea/Workbench/hidden/hidden/Features/NotchOverflow/NotchOverflowController.swift#L28) — `Equatable` struct with `hasNotch: Bool` and `overflowThresholdX: CGFloat`.
- [NotchOverflowController.swift:NotchGeometry](file:///Users/mmetawea/Workbench/hidden/hidden/Features/NotchOverflow/NotchOverflowController.swift#L36) — pure geometry helper:
  - `static let fallbackThresholdX: CGFloat = 972`
  - `static func computeBoundary(screenFrame: CGRect, safeAreaInsetsTop: CGFloat, auxiliaryTopRightAreaMinX: CGFloat?) -> NotchBoundary`
- [NotchOverflowController.swift:MenuBarExtraClassifier](file:///Users/mmetawea/Workbench/hidden/hidden/Features/NotchOverflow/NotchOverflowController.swift#L65) — pure classifier:
  - `static func classify(_ extras: [MenuBarExtraInfo], boundary: CGFloat) -> (hidden: [MenuBarExtraInfo], visible: [MenuBarExtraInfo])`
- [NotchOverflowController.swift:NotchOverflowController](file:///Users/mmetawea/Workbench/hidden/hidden/Features/NotchOverflow/NotchOverflowController.swift#L83) — `NSObject` subclass:
  - `static var hasNotch: Bool` — reports whether `NSScreen.main` has a notch (`safeAreaInsets.top > 0` on macOS 12.0+).
  - `func showOverflowMenuFromSeparator(near item: NSStatusItem)` — checks Accessibility trust, fetches extras asynchronously, builds the overflow menu, and pops it open from `item`.
  - `func buildOverflowMenu(extras: [MenuBarExtraInfo]? = nil, boundary: CGFloat? = nil) -> NSMenu` — builds the categorized `NSMenu` (injectable `extras` and `boundary` for testing).

## Invariants
- `NotchGeometry.computeBoundary` sets `hasNotch = safeAreaInsetsTop > 0` and falls back to `fallbackThresholdX` (`972`) when `!hasNotch` or `auxiliaryTopRightAreaMinX == nil`.
- `MenuBarExtraClassifier.classify` filters out items with `size.width <= 0` or `size.height <= 0`, partitions on `position.x < boundary` (`hidden`) vs. `>= boundary` (`visible`), and sorts both arrays descending by `position.x`.
- `NotchOverflowController.currentBoundary()` returns `hasNotch = false` and `fallbackThresholdX` when `NSScreen.main` is `nil` or on macOS versions prior to 12.0.
- `showOverflowMenuFromSeparator(near:)` requires `AXIsProcessTrusted() == true`; otherwise it prompts and returns without building or displaying a menu.
- AX enumeration excludes the current process PID and non-`.app` bundle URLs, and sets `axMessagingTimeout` (`0.1`s) on each application `AXUIElement`.

## Side Effects
- `ensureAccessibility()` calls `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt: true`, triggering the system Accessibility permission prompt if untrusted.
- `fetchMenuBarExtras` queries `NSWorkspace.shared.runningApplications` and runs concurrent AX IPC via `DispatchQueue.concurrentPerform` on `.userInitiated`.
- `showOverflowMenuFromSeparator(near:)` temporarily sets `item.menu`, triggers `item.button?.performClick(nil)`, and clears `item.menu = nil` on `DispatchQueue.main.async`.
- Selecting a menu item invokes `AXUIElementPerformAction(info.element, kAXPressAction as CFString)` on the target application's status item.

## Verification
- Run: `make test`
