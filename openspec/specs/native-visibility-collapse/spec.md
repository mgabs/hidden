# native-visibility-collapse Specification

## Purpose
Defines reliable native menu-bar visibility activation on macOS 27.2.1+ and fail-open recovery guarantees so `NativeVisibilityEngine` never deadlocks in `.calibrating`.

## Requirements

### Requirement: REQ-NATIVE-1 macOS 27.2.1 Assertion Activation Contract
`HBNativeVisibilityActivate` MUST invoke its completion handler with either a retained assertion or a descriptive `NSError` on macOS 27.2.1 (`26B131`) and newer supported macOS 27 builds when `HBNativeVisibilityIsAvailable()` is `YES`.

#### Scenario: Successful collapse on macOS 27.2.1
- **GIVEN** `NativeVisibilityEngine` is in `.expanded`, Accessibility permission is granted, and `HBNativeVisibilityIsAvailable()` is `YES`
- **WHEN** the user clicks the Hidden Bar arrow (`collapse(completion:)`)
- **THEN** `HBNativeVisibilityActivate` invokes its completion handler with a non-nil assertion, `state` transitions to `.collapsed`, hidden items are concealed, and the arrow flips to `<`

#### Scenario: Activation rejected by system daemon
- **GIVEN** `MenuBarClientCore` or `MenuBarAgent` rejects the assertion request (e.g., missing entitlement or signing requirement)
- **WHEN** `collapse(completion:)` runs
- **THEN** `NativeVisibilityEngine` fails open (`state` returns to `.expanded`), logs the failure reason, and invokes `completion(.unavailable)`

### Requirement: REQ-NATIVE-2 Bounded Activation Timeout Recovery
`NativeVisibilityEngine.activate(allowing:completion:)` MUST enforce a bounded timeout if `NativeVisibilityProviding.activate(...)` fails to invoke its completion handler, ensuring `state` never wedges in `.calibrating`.

#### Scenario: Provider completion handler never fires
- **GIVEN** `NativeVisibilityEngine` enters `.calibrating` and calls `visibility.activate(...)`
- **WHEN** the provider does not invoke its completion handler before the activation timeout elapses
- **THEN** `NativeVisibilityEngine` logs the timeout, resets `state` to `.expanded`, calls `completion(false)` (propagating `.unavailable` to `StatusBarController`), and ignores any late completion from that timed-out generation (invalidating any late assertion)

### Requirement: REQ-NATIVE-3 Generation Supersession State Cleanup
`NativeVisibilityEngine` MUST reset `state` cleanly when an in-flight `withLayout` or `activate` operation is superseded by a `generation` bump (e.g., `expand()` or `invalidateLayout()`).

#### Scenario: Expand or layout invalidation during calibrating
- **GIVEN** `NativeVisibilityEngine` is in `.calibrating` with an in-flight `withLayout` or `activate` callback for generation `G`
- **WHEN** `expand()` or `invalidateLayout()` bumps `generation` to `G + 1`
- **THEN** `state` is `.expanded`, any late callback for generation `G` invalidates its assertion without altering `state`, and subsequent `collapse(completion:)` calls execute normally

### Requirement: REQ-NATIVE-4 Repeatable Failure Diagnostics
`NativeVisibilityEngine` MUST log diagnostic context on every failed collapse attempt rather than suppressing subsequent failures after launch.

#### Scenario: Repeated collapse failures
- **GIVEN** `collapse(completion:)` fails due to unavailability, timeout, or activation error
- **WHEN** the user clicks the Hidden Bar arrow multiple times
- **THEN** each failed collapse logs the failure reason via `NSLog` so runtime diagnostics remain observable

### Requirement: NFR-NATIVE-1 Activation Timeout Budget
The bounded activation timeout in `NativeVisibilityEngine` MUST complete within 3 seconds so an unresponsive system XPC call does not leave the UI unclickable indefinitely.

#### Scenario: Timeout latency bound
- **GIVEN** a mock `NativeVisibilityProviding` whose `activate(...)` never invokes its completion handler
- **WHEN** `collapse(completion:)` is invoked in unit tests
- **THEN** `collapse(completion:)` resolves with `.unavailable` and resets `state` to `.expanded` within the configured timeout budget (<= 3.0 seconds)
