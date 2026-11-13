# About

## Overview
Displays application version and build information in the About tab of the Preferences window.

## Interface
- [AboutViewController.swift:AboutViewController](file:///Users/mmetawea/Workbench/hidden/hidden/Features/About/AboutViewController.swift#L11) — `NSViewController` subclass managing the About view.
  - `lblVersion: NSTextField!` — `@IBOutlet` label displaying the formatted version string.
  - `static func initWithStoryboard() -> AboutViewController` — instantiates `"aboutVC"` from the `"Main"` storyboard.
  - `override func viewDidLoad()` — calls `setupUI()`.

## Invariants
- The `"Main"` storyboard must define a view controller with identifier `"aboutVC"` backed by `AboutViewController` and a connected `lblVersion` outlet.
- `setupUI()` appends `" \(version) (\(buildNumber))"` to the existing `lblVersion.stringValue` once during `viewDidLoad()`; if `Bundle.main.releaseVersionNumber` or `Bundle.main.buildVersionNumber` is `nil`, `lblVersion.stringValue` is left unchanged.

## Side Effects
- Mutates `lblVersion.stringValue` in `viewDidLoad()`.

## Verification
- Run: `make test`
