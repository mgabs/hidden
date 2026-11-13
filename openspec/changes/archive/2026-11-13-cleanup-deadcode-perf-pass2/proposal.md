# Proposal

## Intent
Eliminate remaining verified dead code, unused image assets, incomplete `StatusBarController.deinit` teardown, off-main `NSRunningApplication.icon` reads, and synchronous main-thread AX IPC in `SystemMenuBarClock`.

## Problem Statement
After `d35e92e`, `hidden/` still retains dead symbols (`textFieldTitle`, `getAllMenuBarExtras()`, `NotchGeometry.computeBoundary(screenFrame:)`, unused `Carbon`/`Foundation` imports), 4 unused `.imageset` assets, incomplete observer/timer cleanup in `StatusBarController.deinit`, off-main `NSRunningApplication.icon` reads + uncached resizing in `NotchOverflowController`, and synchronous 0.5s-timeout AX IPC in `SystemMenuBarClock.handle(_:)` on every menu-bar click.

## Capabilities

### New Capabilities
- `deadcode-perf-pass2`: Dead symbol/asset removal, `StatusBarController.deinit` completeness, main-thread `NSRunningApplication.icon` read + resize cache, and cached `SystemMenuBarClock` frames.

### Modified Capabilities
- None.

## Scope

### In-Scope
- Remove `@IBOutlet textFieldTitle` from `PreferencesViewController.swift` and `Main.storyboard`.
- Remove dead `getAllMenuBarExtras()` and make `extras` non-optional in `NotchOverflowController.buildOverflowMenu(extras:boundary:)`.
- Remove unused `screenFrame: CGRect` parameter from `NotchGeometry.computeBoundary` and its 5 call sites.
- Remove unused `import Carbon` (`PreferencesViewController.swift`) and redundant `import Foundation` (`HyperlinkTextField.swift`, `Util.swift`, `CaptureActivityMonitor.swift`).
- Delete 4 unused `.imageset` folders in `hidden/Assets.xcassets/` (`banner_alway_hide`, `banner`, `ic_dot`, `ico_fb`).
- In `StatusBarController.deinit`, add `timer?.invalidate()` and `NSWorkspace.shared.notificationCenter.removeObserver(self)`.
- In `NotchOverflowController`, read `NSRunningApplication.icon` on the main thread when building menu items and cache resized menu icons.
- In `SystemMenuBarClock`, cache clock frames (invalidating on `NSApplication.didChangeScreenParametersNotification` and re-populating off-main or lazily) so `.leftMouseDown` hit-testing does not run synchronous AX IPC on every click.

### Out-of-Scope (YAGNI)
- Modifying `Preferences.globalKey` `JSONDecoder`/`JSONEncoder` (low-frequency path).
- Changing `NotchOverflowController` async scan architecture already specified in `openspec/specs/notch-overflow-async-scan/spec.md`.

## Assumptions
- **ASM-GEN-1**: `NSRunningApplication` instances remain valid long enough between async AX scan and main-thread menu construction (`NSRunningApplication(processIdentifier:)` or captured `app` reference).
- **ASM-GEN-2**: Clock frames on a single display or unchanged display configuration remain stable until `didChangeScreenParametersNotification` fires.

## Success Metrics
- Zero references to deleted symbols/assets remain in the repository.
- `SystemMenuBarClock.handle(_:)` performs zero synchronous AX IPC when cached clock frames are warm.
- `NotchOverflowController` never accesses `NSRunningApplication.icon` off the main thread.
- `make test` and `make build` succeed.

## Review Gate
- [x] **Gate 1 Approval**: Proposal reviewed and approved by human before drafting specs.
