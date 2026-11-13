# Research & Technical Tradeoffs

## 1. Intent & Ground Truth
- **Problem:** A second-pass audit of `hidden/` after commit `d35e92e` identified remaining dead code, unused image assets, incomplete `deinit` cleanup, and two remaining main-thread / threading hot-path issues (`SystemMenuBarClock.handle(_:)` synchronous AX IPC on `.leftMouseDown`, and `NotchOverflowController` reading `NSRunningApplication.icon` off-main + uncached resizing).
- **Verified Codebase Facts:**
  - `PreferencesViewController.swift:17` declares `@IBOutlet weak var textFieldTitle: NSTextField!` (`Main.storyboard:883`, `id="v43-3R-PwU"`), unreferenced in code/tests; `PreferencesViewController.swift:10` imports unused `Carbon`.
  - `NotchOverflowController.swift:250-252` defines `getAllMenuBarExtras()` as a fallback when `extras == nil` in `buildOverflowMenu(extras:boundary:)`, but both production (`L116`) and `NotchOverflowMenuBuilderTests.swift` always pass `extras`.
  - `NotchGeometry.computeBoundary` (`NotchOverflowController.swift:47-57`) accepts unused `screenFrame: CGRect`.
  - `MenuBarClock.swift:119-131` calls `Self.clocks()` (AX IPC to `com.apple.MenuBarAgent`, `messagingTimeout = 0.5s`) and `Self.isNotificationCenterOpen` synchronously on `.leftMouseDown`.
  - `NotchOverflowController.swift:208-210` reads `entry.app.icon` inside `DispatchQueue.global` + `concurrentPerform`, and `makeMenuItem(for:hidden:)` calls `icon.resizedForMenu(tinted:)` on every menu open.
  - `StatusBarController.swift:103-109` (`deinit`) does not invalidate `timer` or remove `NSWorkspace.shared.notificationCenter` observer.
  - 4 `.imageset` folders in `hidden/Assets.xcassets/` (`banner_alway_hide`, `banner`, `ic_dot`, `ico_fb`) have zero references.

## 2. Options Explored
- **Option A — Targeted Cleanup + Clock Frame Cache + Main-Thread Icon Cache (Recommended):**
  - Remove all verified dead code/assets, fix `StatusBarController.deinit`, move `NSRunningApplication.icon` read + resize cache to main thread in `NotchOverflowController`, and cache `SystemMenuBarClock` frames (invalidated on `didChangeScreenParametersNotification` + display/assertion changes).
  - *Pros:* Zero new dependencies, eliminates main-thread AX stall on clock clicks and off-main `NSImage` access, removes dead code & unused assets.
  - *Cons:* Clock frame cache must invalidate reliably when screen geometry changes.
- **Option B — Dead Code & Asset Cleanup Only:**
  - Skip `MenuBarClock` caching and `NotchOverflowController` icon threading fixes.
  - *Pros:* Smaller diff.
  - *Cons:* Leaves 0.5s-timeout sync AX IPC on `.leftMouseDown` and off-main `NSRunningApplication.icon` access unfixed.

## 3. Tradeoff Matrix

| Criteria | Option A (Full Pass 2) | Option B (Dead Code Only) |
| :--- | :--- | :--- |
| **Complexity** | Low-Medium | Low |
| **New Dependencies** | None | None |
| **Performance & Latency** | Removes sync AX stall on click & off-main icon read | Unchanged |
| **Maintenance Burden** | Low; simpler signatures & clean `deinit` | Leaves threading/latency debt |
| **Blast Radius** | `NotchOverflow`, `MenuBarClock`, `StatusBarController`, `Preferences`, `Assets.xcassets` | `Preferences`, `NotchOverflow`, `Assets.xcassets` |

## 4. Recommendation
Adopt **Option A**: remove all verified dead code/assets, complete `StatusBarController.deinit` cleanup, move `NSRunningApplication.icon` reading/caching to main thread, and cache `SystemMenuBarClock` frames with screen-parameter invalidation.

## 5. Breaking Changes & Deprecations
None (`openspec/specs/notch-overflow-async-scan/spec.md` and `openspec/specs/native-visibility-collapse/spec.md` remain compatible).

## Review Gate
- [x] **Gate 0 Decision**: Human decides Go (name the option) or No-Go before the proposal is drafted.
