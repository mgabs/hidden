# Extensions

## Overview
Foundation, AppKit, and Cocoa extensions providing bundle version metadata lookup, date/time formatting, window focus activation, typed notification names, constraint-safe stack view cleanup, string localization, and `UserDefaults` key constants.

## Interface
- `Bundle+Extension.swift:Bundle.releaseVersionNumber` — `var releaseVersionNumber: String?` returning `CFBundleShortVersionString` from `infoDictionary`.
- `Bundle+Extension.swift:Bundle.buildVersionNumber` — `var buildVersionNumber: String?` returning `CFBundleVersion` from `infoDictionary`.
- `Date+Extension.swift:Date.dateString()` — `static func dateString() -> String` formatting `Date()` with `"EEE dd MMM"`.
- `Date+Extension.swift:Date.timeString()` — `static func timeString() -> String` formatting `Date()` with `"hh:mm a"`.
- `NSWindow+Extension.swift:NSWindow.bringToFront()` — `func bringToFront()` making the window key/front and activating `NSApp`.
- `Notification.Name+Extension.swift:Notification.Name.prefsChanged` — `static let prefsChanged` (`"prefsChanged"`).
- `Notification.Name+Extension.swift:Notification.Name.alwayHideToggle` — `static let alwayHideToggle` (`"alwayHideToggle"`).
- `Notification.Name+Extension.swift:Notification.Name.useFullStatusBarToggle` — `static let useFullStatusBarToggle` (`"useFullStatusBarToggle"`).
- `StackView+Extension.swift:NSStackView.removeAllSubViews()` — `func removeAllSubViews()` deactivating constraints and removing all subviews in `self.views`.
- `String+Extension.swift:String.localized` — `var localized: String` returning `NSLocalizedString(self, comment: self)`.
- `UserDefault+Extension.swift:UserDefaults.Key` — `enum Key` defining static preference keys: `globalKey`, `numberOfSecondForAutoHide`, `isAutoStart`, `isAutoHide`, `isShowPreference` (`"isShowPreferences"`), `areSeparatorsHidden`, `alwaysHiddenSectionEnabled`, `useFullStatusBarOnExpandEnabled`, `hoverToExpand`, `notchOverflowEnabled`.

## Invariants
- `StackView+Extension.swift:NSStackView.removeAllSubViews()` must call `NSLayoutConstraint.deactivate(view.constraints)` before `view.removeFromSuperview()` to prevent constraint leaks on view rebuilds.
- `UserDefault+Extension.swift:UserDefaults.Key` string raw values must remain stable across releases to preserve persisted preferences (note `isShowPreference` maps to `"isShowPreferences"`).
- `Notification.Name+Extension.swift` notification name string identifiers must match all `NotificationCenter` poster and observer registrations.
- `Date+Extension.swift` reuses `private static let` `DateFormatter` instances (`dateFormatter`, `timeFormatter`) with fixed formats `"EEE dd MMM"` and `"hh:mm a"`.

## Side Effects
- `NSWindow+Extension.swift:NSWindow.bringToFront()` mutates window ordering/key state (`makeKeyAndOrderFront(nil)`) and activates the application (`NSApp.activate(ignoringOtherApps: true)`).
- `StackView+Extension.swift:NSStackView.removeAllSubViews()` mutates the view hierarchy and active Auto Layout constraints for `self.views`.
- `Bundle+Extension.swift`, `Date+Extension.swift`, `Notification.Name+Extension.swift`, `String+Extension.swift`, `UserDefault+Extension.swift`: read-only or constant definitions with no external state mutations.

## Verification
- Run: `make test`
