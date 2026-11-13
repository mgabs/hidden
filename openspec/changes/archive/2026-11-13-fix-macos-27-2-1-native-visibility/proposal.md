# Proposal

## Intent
Fix Hidden Bar's menu-bar collapse failure on macOS 27.2.1 (`26B131`) by resolving why `MenuBarClientCore` assertion activation stalls without invoking its completion handler and hardening `NativeVisibilityEngine` so in-flight `.calibrating` states recover cleanly on timeout or cancellation.

## Problem Statement
On macOS 27.2.1 (`26B131`), `/Applications/Hidden Bar.app` (`Release-Direct`) reads Accessibility inventory and resolves sections (`NativeVisibility: arrow at x=1427.0...`), then calls `MBAssessmentModeAssertion.activateWithConfiguration:completionHandler:` in `HBNativeVisibilityShim.m`, which never invokes its completion handler. As a result, `NativeVisibilityEngine.state` stays `.calibrating` permanently, turning every subsequent left-click on the arrow into a silent no-op while leaving the bar expanded.

## Capabilities

### New Capabilities
- `native-visibility-collapse`: Reliable macOS 27.2.1 `MenuBarClientCore` assertion activation, bounded `.calibrating` timeout recovery, `generation`-supersession state cleanup, and per-failure diagnostic logging.

### Modified Capabilities
- None.

## Scope

### In-Scope
- Diagnose `MenuBarAgent` / `MenuBarClientCore` behavior on macOS 27.2.1 (`26B131`) across ad-hoc (`CODE_SIGNING_ALLOWED=NO`) and signed (`SIGNING=""`) builds, and apply the required fix in `HBNativeVisibilityShim.m` / build configuration.
- Add a bounded activation timeout in `NativeVisibilityEngine` so an unanswered `visibility.activate(...)` callback resets `state` to `.expanded`, logs the timeout, and completes with `.unavailable`.
- Reset `state` cleanly when a `generation` bump supersedes an in-flight `withLayout` or `activate` call so `.calibrating` cannot deadlock.
- Ensure repeated user-initiated collapse failures log diagnostics rather than being silently swallowed after a one-shot launch log.

### Out-of-Scope (YAGNI)
- Rewriting or replacing `NativeVisibilityEngine` with `LegacyLengthEngine` on macOS 27+ (already broken per #360).
- Adding new onboarding windows, alert dialogs, or diagnostic UI panels beyond existing `NSLog` diagnostics (and optional single disabled line in `getContextMenu()` if needed).
- Refactoring `NotchOverflowController`, `MenuBarClock`, or `CaptureActivityMonitor`.

## Assumptions
- **ASM-GEN-1**: `MenuBarClientCore.framework` on macOS 27.2.1 (`26B131`) still supports allow-list menu-bar assertions when invoked with the expected signing/entitlement/selector contract.
- **ASM-GEN-2**: If `MenuBarAgent` rejects ad-hoc binaries (`CODE_SIGNING_ALLOWED=NO`), local/CI distribution can either sign with a valid identity or fail open cleanly with diagnostic output without wedging `.calibrating`.

## Success Metrics
- Left-clicking `>` on macOS 27.2.1 (`26B131`) folds hidden and always-hidden items and flips the arrow to `<`; clicking `<` expands them and flips back to `>`.
- `NativeVisibilityEngine` never remains stuck in `.calibrating` if `visibility.activate(...)` hangs or is superseded by `expand()` / `invalidateLayout()`.
- `make test` (`HiddenBarTests` and `HiddenTests`) passes with new regression tests covering activation timeout and `generation` supersession.

## Review Gate
- [x] **Gate 1 Approval**: Proposal reviewed and approved by human before drafting specs.
