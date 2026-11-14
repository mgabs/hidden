# Research & Technical Tradeoffs

## 1. Intent & Ground Truth
- **Problem**: Auto-collapse in `StatusBarController` (`hidden/Features/StatusBar/StatusBarController.swift`) behaves inconsistently across timer deferral, launch, manual collapse, environment changes, and `.unavailable` collapse failures.
- **Verified Codebase Facts**:
  1. **Instant-only deferral & full-duration re-arm** (`StatusBarController.swift:355-369`): `startTimerToAutoHide()` schedules a one-shot `Timer` for `Preferences.numberOfSecondForAutoHide`. Only at fire time does it check `isMouseInMenuBar || isPreferencesWindowVisible`; if true, it re-arms for a *full* `numberOfSecondForAutoHide` instead of tracking idle time after interaction ends. Clicking a menu-bar icon and moving down into its popup/menu exits the menubar strip (`visibleFrame.maxY .. frame.maxY`), so `isMouseInMenuBar` becomes `false` and the bar can collapse mid-menu.
  2. **Environment invalidation breaks auto-collapse** (`StatusBarController.swift:149-158`): `invalidateNativeLayoutAfterEnvironmentChange()` (called on `didChangeScreenParametersNotification`, `didLaunchApplicationNotification`, `didWakeNotification`) calls `menuBarEngine.invalidateLayout()`, which resets `NativeVisibilityEngine.state` to `.expanded`. `StatusBarController` calls `didFailToCollapseMenuBar()` but never calls `autoCollapseIfNeeded()`, leaving the bar expanded indefinitely.
  3. **`.unavailable` stops the cycle silently** (`StatusBarController.swift:285-293, 299-306`): On `case .unavailable`, `didFailToCollapseMenuBar()` updates the button image and activation policy without retrying or notifying the user when Accessibility permission is missing (`AXIsProcessTrusted() == false`).
  4. **Launch race** (`StatusBarController.swift:95-100`): `init()` calls `autoCollapseIfNeeded()` at `t = 0` AND schedules `collapseMenuBar()` via `DispatchQueue.main.asyncAfter(deadline: .now() + 1)`. `collapseMenuBar()` does not invalidate `timer`, leaving a dangling timer running after launch collapse.
  5. **Manual collapse leaves timer armed** (`StatusBarController.swift:279-294`): `collapseMenuBar()` never calls `timer?.invalidate()`, so the timer still fires while collapsed.
- **Constraints**:
  - `Hidden Bar` targets macOS 13.0+ (`MACOSX_DEPLOYMENT_TARGET = 13.0`) with AppKit (`NSStatusBar`, `NSEvent`, `NSWorkspace`, `UNUserNotificationCenter` / `NSAlert`).
  - No new third-party dependencies.
  - Logic in `StatusBarController` should be extracted or protocol-backed into a pure/testable coordinator or state machine so `HiddenBarTests` can deterministically test timer, deferral, retry, and invalidation behavior without live AppKit status bar dependencies.

## 2. Options Explored
- **Option A: Idle-based Auto-Collapse Coordinator (`AutoCollapseCoordinator`)**
  - Extract auto-collapse state & timer logic into a small, testable coordinator (in `hidden/Features/StatusBar/`) injected with clock/timer, busy predicates (`isMouseInMenuBar`, `isPreferencesWindowVisible`, `isPopupOrMenuOpen`), and callbacks (`collapse`, `onUnavailableFinal`).
  - Tracks interaction/busy state: defers while mouse is in menubar, Preferences window is visible, or a popup/menu is open (`NSEvent` menu tracking / `NSApp.windows` / `NSMenu` tracking notifications `NSMenu.didBeginTrackingNotification` & `didEndTrackingNotification` + global mouse/window checks), and collapses `numberOfSecondForAutoHide` seconds after interaction ends (polling on a short 0.5–1.0s cadence while deferred, or resetting idle deadline on interaction end).
  - Invalidates timer on every collapse (launch, manual, auto) and on `isAutoHide = false`.
  - Re-arms auto-collapse on `invalidateNativeLayoutAfterEnvironmentChange()` when `Preferences.isAutoHide` is enabled.
  - On `.unavailable`: retries **once** after a short backoff (e.g. 2.0s); if still `.unavailable` and Accessibility is not trusted (`!AXIsProcessTrusted()`), surfaces a non-blocking notification/prompt to check Accessibility permission.
  - *Pros*: Deterministic, unit-testable, eliminates all 5 inconsistency sources, matches user expectation ("collapse N seconds after I stop using it").
  - *Cons*: Slightly more state than a raw `Timer` in `StatusBarController`.
- **Option B: Minimal Patch in `StatusBarController`**
  - Keep raw `Timer` in `StatusBarController`, add `timer?.invalidate()` in `collapseMenuBar()`, add `autoCollapseIfNeeded()` in `invalidateNativeLayoutAfterEnvironmentChange()`, shorten deferral poll to 1s.
  - *Pros*: Minimal diff.
  - *Cons*: Hard to unit-test `StatusBarController` directly; doesn't cleanly model retry-once + Accessibility notification or popup/menu tracking.
- **Option C: Continuous Global Mouse Monitor Always Active**
  - Always install `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` even when `hoverToExpand` is off.
  - *Pros*: Instant detection of mouse leaving menubar.
  - *Cons*: Unnecessary background event overhead on every mouse movement; `hoverToExpand` intentionally avoids installing a global monitor unless opted in.

## 3. Tradeoff Matrix

| Criteria | Option A (Coordinator) | Option B (Minimal Patch) | Option C (Always-On Monitor) |
| :--- | :--- | :--- | :--- |
| **Complexity** | Low-Moderate | Low | Moderate |
| **New Dependencies** | None | None | None |
| **Performance & Latency** | Negligible (timer + AppKit menu notifications) | Negligible | Higher (global mouseMove wakeups) |
| **Maintenance Burden** | Low (isolated, unit-tested) | Medium (coupled to `StatusBarController`) | Medium |
| **Blast Radius** | Contained to `StatusBar` feature | Contained to `StatusBarController` | Global event monitor |

## 4. Recommendation
Adopt **Option A (Idle-based `AutoCollapseCoordinator`)**: extract auto-collapse scheduling, busy/popup deferral, launch/manual timer cancellation, environment-change re-arming, and single-retry + Accessibility notification into a testable coordinator used by `StatusBarController`.

## 5. Breaking Changes & Deprecations
None. Existing `REQ-NATIVE-*` requirements in `openspec/specs/native-visibility-collapse/spec.md` remain unchanged.

## Review Gate
- [x] **Gate 0 Decision**: Human decides Go (name the option) or No-Go before the proposal is drafted.
