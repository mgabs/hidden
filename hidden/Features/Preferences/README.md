# Preferences

## Overview
Manages the Preferences window, segment switching between General Settings and About, global hotkey recording, user preference bindings, and the interactive status bar tutorial preview.

## Interface
- [PreferencesWindowController.swift:PreferencesWindowController](file:///Users/mmetawea/Workbench/hidden/hidden/Features/Preferences/PreferencesWindowController.swift#L11) — `NSWindowController` subclass:
  - `enum MenuSegment: Int { case general, about }`
  - `static let shared: PreferencesWindowController` — lazily instantiates `"MainWindow"` from `"Main"` storyboard.
  - `static var isVisible: Bool` — checks visibility without instantiating `shared` or loading the window.
  - `override func windowDidLoad()` — configures centered toolbar item and loads initial segment.
  - `override func keyDown(with event: NSEvent)` / `override func flagsChanged(with event: NSEvent)` — forwards events to `PreferencesViewController` while `listening == true`.
  - `override func performKeyEquivalent(with event: NSEvent) -> Bool` — closes the window on `Cmd+W` (with optional `Shift`) when not recording a shortcut.
  - `@IBAction func switchSegment(_ sender: NSSegmentedControl)` — switches between `.general` and `.about` view controllers while preserving window content size.
- [PreferencesViewController.swift:PreferencesViewController](file:///Users/mmetawea/Workbench/hidden/hidden/Features/Preferences/PreferencesViewController.swift#L13) — `NSViewController` subclass:
  - `public var listening: Bool` — tracks global shortcut recording state and highlights `btnShortcut` on the main queue.
  - `static func initWithStoryboard() -> PreferencesViewController` — instantiates `"prefVC"` from `"Main"` storyboard.
  - `func pinStatusBarBelowToolbar(of window: NSWindow)` — constrains `statusBarStackView` below `window.contentLayoutGuide`.
  - `public func updateGlobalShortcut(_ event: NSEvent)` / `public func updateModiferFlags(_ event: NSEvent)` — records and applies global hotkey combinations.
  - `@IBAction` handlers: `loginCheckChanged(_:)`, `autoHideCheckChanged(_:)`, `showPreferencesChanged(_:)`, `showAlwaysHiddenSectionChanged(_:)`, `useFullStatusBarOnExpandChanged(_:)`, `timePopupDidSelected(_:)`, `register(_:)`, `unregister(_:)`, `notchOverflowCheckChanged(_:)`, `btnAlwayHiddenHelpPressed(_:)`.
  - Tutorial helpers: `createTutorialView()`, `hideStatusBar()`, `alwayHideStatusBar()`.

## Invariants
- `PreferencesWindowController.isVisible` must not instantiate `shared` or load the storyboard if `sharedInstance` is `nil` or `isWindowLoaded` is `false`.
- `PreferencesWindowController.performKeyEquivalent(with:)` only intercepts `Cmd+W` when `PreferencesViewController.listening` is `false`, allowing users to bind `Cmd+W` as a global hotkey.
- `pinStatusBarBelowToolbar(of:)` is called in `updateVC()` before the first draw when switching to `.general` to prevent layout flicker.
- `PreferencesViewController.viewDidLoad()` hides `checkBoxNotchOverflow` when `!NotchOverflowController.hasNotch` and observes `.prefsChanged`, balanced by `NotificationCenter.default.removeObserver` in `deinit`.
- `unregister(_:)` and `updateGlobalShortcut(_:)` cast `NSApplication.shared.delegate` to `AppDelegate`.

## Side Effects
- Reads and mutates `Preferences` properties (`isAutoStart`, `isAutoHide`, `isShowPreference`, `alwaysHiddenSectionEnabled`, `useFullStatusBarOnExpandEnabled`, `numberOfSecondForAutoHide`, `globalKey`, `notchOverflowEnabled`).
- Mutates `(NSApplication.shared.delegate as! AppDelegate).hotKey` when registering or clearing global shortcuts.
- `loginCheckChanged(_:)` presents a modal `NSAlert` if `Preferences.isAutoStart` reverts after assignment.
- `btnAlwayHiddenHelpPressed(_:)` displays an `NSPopover` anchored to `sender`.

## Verification
- Run: `make test`
