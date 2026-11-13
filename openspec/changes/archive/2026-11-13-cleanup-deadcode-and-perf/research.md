# Research & Technical Tradeoffs

## 1. Intent & Ground Truth
Eliminate verified dead code and main-thread/hot-path performance bottlenecks in `hidden/` without altering user-facing behavior.

Verified codebase facts:
- **Dead code (7 items)**:
  - `hidden/Views/NSBarButtonItem+Extension.swift` (`NSStatusBarButton.collapseBarButtonItem()`) — zero callers across `hidden/`, `HiddenBarTests/`, `HiddenTests/`, and `Main.storyboard`.
  - `hidden/Views/NSView+Extension.swift` (`NSView.getOrigin`) — zero callers across repo.
  - `hidden/Models/GlobalKeybindingPreferences.swift:98-102` (`GlobalKeybindPreferences.save()`) — empty body, zero callers.
  - `hidden/Common/Constant.swift:12` (`Constant.appName`) — zero references.
  - `hidden/Features/Preferences/PreferencesViewController.swift:17,19,29` (`checkBoxKeepLastState`, `imageViewTop`, `checkBoxKeepInDock`) — unconnected `@IBOutlet`s, zero references in Swift or `Main.storyboard`.
  - `hidden/Views/HyperlinkTextField.swift:22-26` (`awakeFromNib()`) — only calls `super.awakeFromNib()` with a `// TODO:` comment.
  - `hidden/Features/NotchOverflow/NotchOverflowController.swift:19,271` (`MenuBarExtraInfo.pid`) — assigned in `getAllMenuBarExtras()` and test fixtures, never read.
- **Hot-path micro-optimizations (4 items)**:
  - `hidden/Extensions/Date+Extension.swift:12-21` — `dateString()` and `timeString()` allocate a new `DateFormatter` on every call.
  - `hidden/Common/Assets.swift:12-25` — `expandImage` and `collapseImage` call `NSImage(named:)` on every toggle.
  - `hidden/Features/StatusBar/Engine/LegacyLengthEngine.swift:45` — `NSScreen.screens.map { $0.frame.width }.max()` allocates an intermediate array per collapse/layout invalidation.
  - `hidden/Features/StatusBar/StatusBarController.swift:53-59,106-122` — `hoverToExpand` `.mouseMoved` monitor iterates `NSScreen.screens` on every mouse move system-wide.
- **AX hot paths (2 items)**:
  - `hidden/Features/NotchOverflow/NotchOverflowController.swift:113-121,231-278` — `getAllMenuBarExtras()` iterates all `NSWorkspace.shared.runningApplications` (including XPC/WebKit helpers) synchronously on the main thread with no `AXUIElementSetMessagingTimeout` and fetches `app.icon` before filtering zero-sized items. `AccessibilityMenuBarInventory` already demonstrates the safe pattern (`bundleURL?.pathExtension == "app"`, `0.1s` AX timeout, `DispatchQueue.concurrentPerform`).
  - `hidden/Features/StatusBar/Engine/Native/MenuBarClock.swift:119-189` — global `.leftMouseDown` monitor already short-circuits via `Self.isInMenuBar(location)` and queries only `com.apple.MenuBarAgent`. Making `.leftMouseDown` async would race with `.leftMouseUp` on fast clicks.

## 2. Options Explored
- **Option A — Dead Code + Micro-Opts + `NotchOverflowController` Off-Main AX (Selected)**
  - Remove all 7 dead code items (including removing the 2 dead files from `project.pbxproj`).
  - Apply all 4 local micro-optimizations (static `DateFormatter`/`NSImage` caches, `max(by:)`, cached menu-bar rects invalidated on `didChangeScreenParametersNotification`).
  - Move `NotchOverflowController.getAllMenuBarExtras()` off the main thread using `.app` filtering, `0.1s` `AXUIElementSetMessagingTimeout`, and `DispatchQueue.concurrentPerform`, keeping `buildOverflowMenu(extras:boundary:)` synchronous for unit tests.
  - Leave `MenuBarClock.swift` synchronous to avoid `.leftMouseDown`/`.leftMouseUp` race.
  - *Pros*: Removes UI freeze risk on Notch Overflow menu open, eliminates dead code and hot-path allocations, preserves all testability.
  - *Cons*: Small async callback change in `showOverflowMenuFromSeparator`.
- **Option B — Dead Code + Micro-Opts Only**
  - Same as Option A without touching `NotchOverflowController.getAllMenuBarExtras()`.
  - *Pros*: Zero async UI changes.
  - *Cons*: Leaves the main-thread AX freeze bug in Notch Overflow unfixed.
- **Option C — Dead Code Removal Only**
  - Remove only the 7 dead code items.
  - *Pros*: Minimal diff.
  - *Cons*: Leaves all 5 real optimization wins on the table.

## 3. Tradeoff Matrix

| Criteria | Option A | Option B | Option C |
| :--- | :--- | :--- | :--- |
| **Complexity** | Low-Medium | Low | Minimal |
| **New Dependencies** | None | None | None |
| **Performance & Latency** | Eliminates Notch Overflow main-thread AX stall + hot-path allocs | Eliminates hot-path allocs only | None |
| **Maintenance Burden** | Reduces dead files/outlets/fields | Reduces dead files/outlets/fields | Reduces dead files/outlets/fields |
| **Blast Radius** | Low (isolated files + `showOverflowMenuFromSeparator`) | Very Low | Very Low |

## 4. Recommendation
Proceed with **Option A**: remove the 7 dead code items, apply the 4 zero-risk micro-optimizations, and move `NotchOverflowController.getAllMenuBarExtras()` off the main thread with `0.1s` AX timeouts while keeping `MenuBarClock` synchronous.

## 5. Breaking Changes & Deprecations
None (`openspec/specs/` is currently empty).

## Review Gate
- [x] **Gate 0 Decision**: Human decides Go (name the option) or No-Go before the proposal is drafted.
