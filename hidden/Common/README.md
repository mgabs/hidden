# Common

## Overview
Shared utilities, app-wide constants, icon asset accessors, login-item auto-start management, and `UserDefaults`-backed user preferences for Hidden Bar.

## Interface
- `Assets.swift`:
  - `struct Assets`:
    - `static var expandImage: NSImage?` — returns `"ic_expand"` when `Constant.isUsingLTRLanguage` is `true`, otherwise `"ic_collapse"`.
    - `static var collapseImage: NSImage?` — returns `"ic_collapse"` when `Constant.isUsingLTRLanguage` is `true`, otherwise `"ic_expand"`.
- `AutoStart.swift`:
  - `protocol LoginItemServing` — testable abstraction over `SMAppService` (`status: SMAppService.Status`, `register() throws`, `unregister() throws`).
  - `extension SMAppService: LoginItemServing`
  - `enum AutoStart`:
    - `@discardableResult static func apply(enabled: Bool, service: LoginItemServing = SMAppService.mainApp) -> Bool`
- `Constant.swift`:
  - `enum Constant`:
    - `static var isUsingLTRLanguage: Bool` (default `false`).
- `Preferences.swift`:
  - `enum Preferences`:
    - `static var globalKey: GlobalKeybindPreferences?`
    - `static var isAutoStart: Bool`
    - `static var numberOfSecondForAutoHide: Double`
    - `static var isAutoHide: Bool`
    - `static var isShowPreference: Bool`
    - `static var areSeparatorsHidden: Bool`
    - `static var alwaysHiddenSectionEnabled: Bool`
    - `static var hoverToExpand: Bool`
    - `static var useFullStatusBarOnExpandEnabled: Bool`
    - `static var notchOverflowEnabled: Bool`
- `Util.swift`:
  - `class Util`:
    - `@discardableResult static func setUpAutoStart(isAutoStart: Bool) -> Bool` — delegates to `AutoStart.apply(enabled: isAutoStart)`.
    - `static func showPrefWindow()` — calls `PreferencesWindowController.shared.window?.bringToFront()`.

## Invariants
- `[AutoStart.swift:AutoStart.apply]`: Only invokes `service.register()` when `enabled == true && service.status != .enabled`, and `service.unregister()` when `enabled == false && service.status != .notRegistered`.
- `[AutoStart.swift:AutoStart.apply]`: Success is determined strictly by the post-call `service.status == (enabled ? .enabled : .notRegistered)`, not by the absence of a thrown error (e.g., `.requiresApproval` returns `false`).
- `[Preferences.swift:Preferences.isAutoStart]`: Setter invokes `Util.setUpAutoStart(isAutoStart: newValue)` before writing to `UserDefaults.standard`; if `false`, the existing `isAutoStart` value is re-stored so preferences reflect actual system state.
- `[Preferences.swift:Preferences.globalKey]`: Setter aborts without mutating `UserDefaults.standard` or posting `.prefsChanged` if `JSONEncoder().encode(newValue)` fails.
- `[Assets.swift:Assets.expandImage]`, `[Assets.swift:Assets.collapseImage]`: Icon selection flips based on `Constant.isUsingLTRLanguage`.

## Side Effects
- `[AutoStart.swift:AutoStart.apply]`: Mutates macOS `ServiceManagement` login-item registration via `SMAppService.mainApp.register()` / `unregister()` and logs status/errors via `NSLog`.
- `[Preferences.swift:Preferences]`: Reads/writes `UserDefaults.standard` keys (`UserDefaults.Key.globalKey`, `isAutoStart`, `numberOfSecondForAutoHide`, `isAutoHide`, `isShowPreference`, `areSeparatorsHidden`, `alwaysHiddenSectionEnabled`, `hoverToExpand`, `useFullStatusBarOnExpandEnabled`, `notchOverflowEnabled`).
- `[Preferences.swift:Preferences]`: Posts `NotificationCenter.default` notifications: `.prefsChanged` (`globalKey`, `isAutoStart`, `numberOfSecondForAutoHide`, `isAutoHide`, `isShowPreference`), `.alwayHideToggle` (`alwaysHiddenSectionEnabled`), and `.useFullStatusBarToggle` (`useFullStatusBarOnExpandEnabled`).
- `[Util.swift:Util.showPrefWindow]`: Presents and focuses `PreferencesWindowController.shared.window` via `bringToFront()`.

## Verification
- Run: `make test`
