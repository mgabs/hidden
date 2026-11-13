# hidden

## Overview
Main application target for Hidden Bar (`com.dwarvesv.minimalbar`), bootstrapping the app lifecycle, global hotkey, single-instance guard, login-item migration, and menu-bar status controller.

## Interface
- `AppDelegate.swift:AppDelegate` — `@NSApplicationMain` delegate owning `statusBarController: StatusBarController` and `hotKey: HotKey?`.
- `AppDelegate.swift:AppDelegate.defaultPreferenceValues` — Default `UserDefaults` dictionary (`isAutoStart: false`, `isShowPreference: true`, `isAutoHide: true`, `numberOfSecondForAutoHide: 10.0`, `areSeparatorsHidden: false`, `alwaysHiddenSectionEnabled: false`, `notchOverflowEnabled: true`).
- `AppDelegate.swift:AppDelegate.applicationDidFinishLaunching(_:)` — Runs `ensureSingleInstance()`, `setupAutoStartApp()`, `registerDefaultValues()`, `setupHotKey()`, `openPreferencesIfNeeded()`, and `detectLTRLang()`.
- `Hidden-Bridging-Header.h` — Imports `Features/StatusBar/Engine/Native/HBNativeVisibilityShim.h` for Swift access to the macOS 27+ native visibility shim.
- **Common**: [./Common/README.md](./Common/README.md) — Shared utilities, constants, icon assets, `SMAppService` login-item auto-start, and `UserDefaults`-backed preferences.
- **Extensions**: [./Extensions/README.md](./Extensions/README.md) — Foundation/AppKit/Cocoa extensions (`Bundle`, `Date`, `NSWindow`, `Notification.Name`, `NSStackView`, `String`, `UserDefaults`).
- **Features**: [./Features/README.md](./Features/README.md) — Feature modules (`About`, `NotchOverflow`, `Preferences`, `StatusBar`).
- **Models**: [./Models/README.md](./Models/README.md) — `GlobalKeybindPreferences` and `SelectedSecond` models.
- **Views**: [./Views/README.md](./Views/README.md) — `HyperlinkTextField` custom view.

## Invariants
- `AppDelegate.swift:ensureSingleInstance()`: In `RELEASE`, terminates duplicate instances matching `Bundle.main.bundleIdentifier`; in `DEBUG`, deduplicates only same `bundleURL`.
- `AppDelegate.swift:removeLegacyLauncherLoginItem()`: Deauthorizes legacy `com.dwarvesv.LauncherApplication` via `SMLoginItemSetEnabled(..., false)` once, gated by `"smAppServiceMigrated"`.

## Side Effects
- `AppDelegate.swift:applicationDidFinishLaunching(_:)`: Registers `UserDefaults` defaults, activates existing instance and calls `NSApp.terminate(nil)` on duplicate launch, opens Preferences window if `Preferences.isShowPreference` is true, and mutates `Constant.isUsingLTRLanguage`.

## Verification
- Run: `make test`
