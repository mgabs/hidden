# Proposal

## Intent
Make Hidden Bar's auto-collapse behavior predictable and consistent across user interaction, launch, manual toggle, environment changes, and `.unavailable` collapse failures by introducing an idle-based `AutoCollapseCoordinator`.

## Problem Statement
Auto-collapse currently suffers from five inconsistencies in `StatusBarController`:
1. Deferral only checks `isMouseInMenuBar || isPreferencesWindowVisible` at timer fire time, re-arming for a full `numberOfSecondForAutoHide` instead of collapsing `N` seconds after interaction ends, and collapses mid-interaction when the user moves down into an open popup/menu.
2. Environment changes (`didWakeNotification`, `didLaunchApplicationNotification`, `didChangeScreenParametersNotification`) reset `NativeVisibilityEngine` to `.expanded` without re-arming auto-collapse.
3. `.unavailable` collapse results stop the auto-collapse cycle silently with no retry or Accessibility guidance.
4. `init()` both arms the auto-collapse timer at `t = 0` and schedules `collapseMenuBar()` at `t + 1s` without cancelling the timer on collapse.
5. Manual `collapseMenuBar()` leaves the pending auto-collapse timer armed.

## Capabilities

### New Capabilities
- `auto-collapse`: Idle-based auto-collapse scheduling, busy-state deferral (menubar pointer, Preferences window, open popup/menu), timer lifecycle cleanup on collapse/disable, environment-change re-arming, and single-retry + Accessibility notification on `.unavailable`.

### Modified Capabilities
None.

## Scope

### In-Scope
- Idle-based `AutoCollapseCoordinator` (or equivalent isolated state machine) wired into `StatusBarController`.
- Defer auto-collapse while pointer is in the menubar, Preferences window is visible, or a popup/menu (`NSMenu` tracking / app popup) is active; collapse `numberOfSecondForAutoHide` seconds after interaction becomes idle.
- Cancel pending auto-collapse timer on every collapse (launch, manual, auto) and when `Preferences.isAutoHide` is disabled.
- Re-arm auto-collapse in `invalidateNativeLayoutAfterEnvironmentChange()` when `Preferences.isAutoHide` is enabled.
- On `case .unavailable`: retry collapse once after a bounded backoff; if the retry also returns `.unavailable`, surface a user notification/prompt to check Accessibility permission (without spamming on repeated cycles).
- Unit tests in `HiddenBarTests` covering idle deferral, launch/manual timer cancellation, environment-change re-arming, and `.unavailable` retry-once + notification behavior.

### Out-of-Scope (YAGNI)
- Changing `NativeVisibilityEngine` or `LegacyLengthEngine` internal state machines.
- Adding new user-facing Preferences UI controls for backoff or idle polling intervals.
- Continuous always-on global `.mouseMoved` monitoring when `hoverToExpand` is disabled.
- Detecting third-party app popovers via private/undocumented Accessibility polling on external processes.

## Assumptions
- **ASM-GEN-1**: `NSMenu.didBeginTrackingNotification` / `NSMenu.didEndTrackingNotification` and `PreferencesWindowController.isVisible` / `NSApp.windows` reliably reflect Hidden Bar's own popup/menu and Preferences window activity, while `isMouseInMenuBar` covers pointer presence in the menubar band.
- **ASM-GEN-2**: User notification (`UNUserNotificationCenter` or non-blocking `NSAlert` fallback if notification authorization is denied/unavailable) is sufficient to prompt the user to check Accessibility permission after `.unavailable` retry failure.

## Success Metrics
- Zero dangling timers after launch collapse, manual collapse, or disabling auto-collapse.
- Auto-collapse consistently fires `numberOfSecondForAutoHide` seconds after interaction ends (Preferences window closed, menu/popup closed, pointer out of menubar).
- After wake, app launch, or display change, the bar re-arms auto-collapse when `isAutoHide` is enabled.
- `.unavailable` triggers exactly 1 retry after backoff, followed by an Accessibility check notification on second failure, with all paths covered by deterministic unit tests in `HiddenBarTests`.

## Review Gate
- [x] **Gate 1 Approval**: Proposal reviewed and approved by human before drafting specs.
