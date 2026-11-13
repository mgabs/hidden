# StatusBar

## Overview
Orchestrates Hidden Bar's menu-bar UI, user interactions, auto-collapse timer, hover-to-expand monitor, and display/workspace change handling. `StatusBarController` owns the `NSStatusItem` instances (`btnExpandCollapse`, `btnSeparate`, optional `btnAlwaysHidden`) and delegates *how* items are hidden or revealed to a `MenuBarEngine`.

## Interface
- [`StatusBarController.swift:StatusBarController`](StatusBarController.swift): `MenuBarItemProvider` owning `toggleItem`, `separatorItem`, and `alwaysHiddenItem`; exposes `btnExpandCollapsePressed(sender:)`, `showHideSeparatorsAndAlwayHideArea()`, `expandCollapseIfNeeded()`, `updateAutoHide()`, `openPreferenceViewControllerIfNeeded()`, `showNotchOverflow()`, and `toggleAutoHide()`.
- [`ExpandCollapseAction.swift:ExpandCollapseAction`](ExpandCollapseAction.swift): Enum with cases `.toggle`, `.contextMenu`, and `.toggleSeparators`.
- [`ExpandCollapseAction.swift:ExpandCollapseActionResolver`](ExpandCollapseAction.swift): Pure resolver with `isOptionPressed(eventFlags:liveFlags:)` and `action(eventType:optionPressed:)` mapping `NSEvent` state (including `nil` for VoiceOver `AXPress` synthesis) to `ExpandCollapseAction`.
- Subdirectories:
  - [`./Engine/README.md`](./Engine/README.md) — `MenuBarEngine` protocol, `MenuBarEngineFactory`, `LegacyLengthEngine`, and `NativeVisibilityEngine`.
  - [`./Layout/README.md`](./Layout/README.md) — Accessibility menu-bar inventory and multi-display `MenuBarLayoutResolver`.

## Invariants
- `StatusBarController.restoreRemovedStatusItems()` MUST set `btnExpandCollapse.isVisible = true`, `btnSeparate.isVisible = true`, and force `menuBarEngine` lazy initialization at launch so engines that hide the separator remove it before it draws.
- `StatusBarController.expandCollapseIfNeeded()` MUST debounce rapid clicks with a 0.3s `isToggle` lock so repeated clicks do not flap `NSApp.setActivationPolicy(_:)`.
- `StatusBarController.showContextMenu(from:)` MUST build a fresh `NSMenu` on each presentation and call `menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button)` rather than `performClick(nil)` (which would recurse into `btnExpandCollapsePressed`) or `bounds.maxY` (which clips above the screen).
- `StatusBarController.startTimerToAutoHide()` MUST defer auto-collapse (re-arming the timer) while `isMouseInMenuBar` or `isPreferencesWindowVisible` is true.
- `ExpandCollapseActionResolver.isOptionPressed(eventFlags:liveFlags:)` MUST check both `eventFlags` and `liveFlags` because macOS 27 status-bar button mouse-up events carry empty modifier flags when Option is held.
- `ExpandCollapseActionResolver.action(eventType:optionPressed:)` MUST map `nil` `eventType` (VoiceOver `AXPress`) to `.toggle`, `optionPressed == true` to `.toggleSeparators`, `.leftMouseUp` to `.toggle`, and `.rightMouseUp` to `.contextMenu`.
- `StatusBarController.toggleStatusBarIfNeeded()` MUST call `menuBarEngine.updateAlwaysHiddenSection(enabled: true, separatorHidden: false)` *after* creating and showing `btnAlwaysHidden` so the engine decides whether it remains in the bar.

## Side Effects
- Creates and removes `NSStatusItem`s in `NSStatusBar.system` (`hiddenbar_expandcollapse`, `hiddenbar_separate`, and `btnAlwaysHidden`).
- Mutates `Preferences.areSeparatorsHidden` and `Preferences.isAutoHide`.
- Mutates `NSApp` activation policy (`.regular` / `.accessory`) and activates/deactivates the app when `Preferences.useFullStatusBarOnExpandEnabled` is enabled.
- Registers observers on `NotificationCenter.default` (`didChangeScreenParametersNotification`, `.prefsChanged`, `.useFullStatusBarToggle`, `.alwayHideToggle`) and `NSWorkspace.shared.notificationCenter` (`didLaunchApplicationNotification`, `didWakeNotification`).
- Optionally installs an `NSEvent` global `.mouseMoved` monitor when `Preferences.hoverToExpand` is true at launch, and schedules `Timer`s for auto-hide and hover dwell.

## Verification
- Run: `make test`
