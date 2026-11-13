# Engine/Native

## Overview
Platform-integration primitives for macOS 27's native menu-bar visibility restriction (`MenuBarClientCore` assessment mode) and its workarounds: runtime Objective-C/Swift bridging to the private framework, microphone/camera capture activity monitoring (so assessment mode does not hide recording-indicator capsules), and global menu-bar clock click interception/replay (so Notification Center remains reachable while a restriction is active).

## Interface
- [`CaptureActivityMonitor.swift:CaptureActivityMonitoring`](CaptureActivityMonitor.swift): Protocol exposing `isActive: Bool` and main-queue `onChange: (() -> Void)?`.
- [`CaptureActivityMonitor.swift:CaptureActivityMonitor`](CaptureActivityMonitor.swift): Monitors CoreAudio per-process input activity (`kAudioProcessPropertyIsRunningInput`, macOS 14.2+) and CoreMediaIO camera device activity (`kCMIODevicePropertyDeviceIsRunningSomewhere`) without microphone or camera permissions.
- [`HBNativeVisibilityShim.h:HBNativeVisibilityIsAvailable`](HBNativeVisibilityShim.h): C function returning whether `MenuBarClientCore.framework`, `MBAssessmentModeConfiguration`, `MBAssessmentModeAssertion`, and required selectors resolve at runtime (always `NO` when `HIDDENBAR_NATIVE_VISIBILITY` is unset).
- [`HBNativeVisibilityShim.h:HBNativeVisibilityActivate`](HBNativeVisibilityShim.h): C function activating an assessment-mode allow-list (`allowedSystemItems`, `allowedBundleIdentifiers`) and invoking `completion` on the main queue with an assertion object or `NSError`.
- [`HBNativeVisibilityShim.h:HBNativeVisibilityInvalidate`](HBNativeVisibilityShim.h): C function invalidating a held assertion inside an `@try/@catch` guard.
- [`NativeVisibilityBridge.swift:NativeVisibilityAssertion`](NativeVisibilityBridge.swift): Protocol for a held visibility restriction with `invalidate()`.
- [`NativeVisibilityBridge.swift:NativeVisibilityProviding`](NativeVisibilityBridge.swift): Protocol exposing `isAvailable: Bool` and `activate(allowedSystemItems:allowedBundleIdentifiers:completion:)`.
- [`NativeVisibilityBridge.swift:NativeVisibilityBridge`](NativeVisibilityBridge.swift): Swift wrapper over `HBNativeVisibilityShim` returning a `Handle` that invalidates on `invalidate()` or `deinit`.
- [`MenuBarClock.swift:MenuBarClockProviding`](MenuBarClock.swift): Protocol exposing `onClick: ((CGPoint) -> Void)?` and `press(at:completion:)`.
- [`MenuBarClock.swift:SystemMenuBarClock`](MenuBarClock.swift): Watches global left-mouse events on `com.apple.MenuBarAgent`'s `com.apple.menuextra.clock` via Accessibility (`AXExtrasMenuBar`) and replays synthetic `CGEvent` left clicks (`clickEvents(at:)`) after a lift delay, polling `CGWindowListCopyWindowInfo` until Notification Center opens or `openTimeout` (0.5s) elapses.

## Invariants
- `HBNativeVisibilityShim.m` MUST pass `NSArray` copies (not `NSSet`) to `initWithAllowedSystemItems:allowedBundleIdentifiers:error:` because `MenuBarClientCore` indexes into the arrays.
- `HBNativeVisibilityShim.m` MUST resolve `MenuBarClientCore.framework` via `dlopen` and wrap all `objc_msgSend` calls in `@try/@catch` so private API changes degrade to unavailable/error rather than crashing.
- `NativeVisibilityBridge.Handle` MUST clear its raw reference before calling `HBNativeVisibilityInvalidate` so `invalidate()` is idempotent across explicit calls and `deinit`.
- `CaptureActivityMonitor` MUST re-register per-process and per-camera property listeners in `devicesDidChange()` (`untrack()` then `track()`) on `.main` and remove all listeners in `deinit`.
- `SystemMenuBarClock.handle(_:)` MUST ignore `⌘`-drag and `⌃`-clicks, ignore clicks outside the menu bar or when Notification Center is already open, and fire `onClick` only when `leftMouseUp` lands inside the `leftMouseDown` clock frame.
- `SystemMenuBarClock.press(at:completion:)` MUST compute `minimumPanelHeight` from `NSScreen.screens` on the calling (main) thread before dispatching to the background queue, wait `liftDelay` (0.03s) before querying AX, and invoke `completion` on `DispatchQueue.main`.

## Side Effects
- `HBNativeVisibilityActivate` loads `/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore` via `dlopen` and activates a system-wide assessment-mode assertion that hides non-allow-listed menu-bar items until invalidated or process exit.
- `CaptureActivityMonitor` registers and removes CoreAudio (`AudioObjectAddPropertyListenerBlock`) and CoreMediaIO (`CMIOObjectAddPropertyListenerBlock`) property listeners on the main queue.
- `SystemMenuBarClock` installs/removes an `NSEvent` global monitor (`.leftMouseDown`, `.leftMouseUp`), queries Accessibility attributes on `com.apple.MenuBarAgent`, reads `CGWindowListCopyWindowInfo`, and posts synthetic `CGEvent` mouse clicks to `.cghidEventTap`.

## Verification
- Run: `make test`
