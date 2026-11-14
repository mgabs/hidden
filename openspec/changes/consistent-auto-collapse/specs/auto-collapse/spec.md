# auto-collapse Specification

## Purpose
Defines deterministic, idle-based auto-collapse scheduling, busy-state deferral, timer lifecycle cleanup, environment-change recovery, and `.unavailable` retry/notification behavior for `StatusBarController`.

## ADDED Requirements

### Requirement: REQ-AUTOHIDE-1 Idle-Based Auto-Collapse Deferral
When `Preferences.isAutoHide` is enabled and the menu bar is expanded, auto-collapse MUST defer while the user is interacting—specifically while `isMouseInMenuBar` is true, `isPreferencesWindowVisible` is true, or an in-app popup/menu is open—and MUST collapse `Preferences.numberOfSecondForAutoHide` seconds after interaction becomes idle rather than re-arming a full duration from an arbitrary poll boundary.

#### Scenario: Deferral while pointer is in menu bar or Preferences/popup is open
- **GIVEN** `Preferences.isAutoHide` is `true`, `numberOfSecondForAutoHide` is `10.0`, and the menu bar is expanded
- **WHEN** the auto-collapse deadline arrives while `isMouseInMenuBar`, `isPreferencesWindowVisible`, or an in-app popup/menu is active
- **THEN** auto-collapse does NOT collapse the menu bar and polls on a short deferral cadence until all busy predicates are `false`

#### Scenario: Collapse after interaction ends
- **GIVEN** auto-collapse was deferred because Preferences window or a popup menu was open
- **WHEN** the Preferences window or popup menu closes and the pointer is outside the menu bar
- **THEN** the idle countdown starts (or resumes) and collapses the menu bar `Preferences.numberOfSecondForAutoHide` seconds after interaction ended

### Requirement: REQ-AUTOHIDE-2 Timer Cancellation on Collapse and Disable
Every transition to collapsed (launch collapse, manual collapse, or auto-collapse) and every transition of `Preferences.isAutoHide` to `false` MUST cancel any pending auto-collapse timer and retry timer so no dangling timers fire while collapsed or disabled.

#### Scenario: Launch collapse cancels initial auto-collapse timer
- **GIVEN** `init()` schedules the initial launch collapse and `Preferences.isAutoHide` is `true`
- **WHEN** the launch collapse succeeds (`case .collapsed`)
- **THEN** no auto-collapse timer remains active while the menu bar is collapsed

#### Scenario: Manual collapse cancels pending timer
- **GIVEN** the menu bar is expanded with an active auto-collapse timer
- **WHEN** the user manually collapses the menu bar before the timer expires
- **THEN** the pending auto-collapse timer is invalidated immediately

#### Scenario: Disabling auto-collapse cancels pending timer
- **GIVEN** the menu bar is expanded with an active auto-collapse timer
- **WHEN** `Preferences.isAutoHide` is set to `false`
- **THEN** any pending auto-collapse or retry timer is invalidated immediately

### Requirement: REQ-AUTOHIDE-3 Environment Change Re-Arming
When `invalidateNativeLayoutAfterEnvironmentChange()` resets a collapsed menu bar to expanded (e.g., on `didWakeNotification`, `didLaunchApplicationNotification`, or `didChangeScreenParametersNotification`), `StatusBarController` MUST re-arm auto-collapse if `Preferences.isAutoHide` is `true`.

#### Scenario: Auto-collapse resumes after wake or display change
- **GIVEN** the menu bar is collapsed and `Preferences.isAutoHide` is `true`
- **WHEN** `invalidateNativeLayoutAfterEnvironmentChange()` runs and `menuBarEngine.invalidateLayout()` leaves the bar `.expanded`
- **THEN** `StatusBarController` updates the UI to expanded AND arms auto-collapse so the bar collapses again after `numberOfSecondForAutoHide` idle seconds

### Requirement: REQ-AUTOHIDE-4 Unavailable Collapse Single Retry and Accessibility Notification
When `collapseMenuBar()` resolves with `case .unavailable`, the auto-collapse coordinator MUST retry collapse once after a bounded backoff; if the retry also resolves with `case .unavailable` and Accessibility permission is missing (`!isAccessibilityAuthorized`), it MUST surface a user-facing notification prompting the user to check Accessibility permission and MUST NOT loop indefinitely.

#### Scenario: Transient unavailable recovers on single retry
- **GIVEN** an auto-collapse attempt fails with `case .unavailable`
- **WHEN** the single backoff retry runs and `collapseMenuBar()` returns `case .collapsed`
- **THEN** the menu bar transitions to collapsed without displaying an Accessibility notification

#### Scenario: Persistent unavailable without Accessibility triggers notification once
- **GIVEN** `collapseMenuBar()` returns `case .unavailable` on both the initial attempt and the single backoff retry, and Accessibility permission is not granted
- **WHEN** the retry fails
- **THEN** the coordinator stops retrying for this cycle and surfaces a notification/prompt to check Accessibility permission in System Settings

### Requirement: NFR-AUTOHIDE-1 Deferral Poll and Backoff Bounds
Deferral polling while busy MUST NOT exceed 1.0 second per check, and the `.unavailable` retry backoff MUST be bounded (<= 3.0 seconds) so recovery is prompt without spinning CPU.

#### Scenario: Bounded backoff and idle poll
- **GIVEN** deterministic unit tests using a fake clock/scheduler
- **WHEN** busy state clears or `.unavailable` triggers a retry
- **THEN** busy-to-idle detection occurs within `<= 1.0` second and the `.unavailable` retry fires within `<= 3.0` seconds
