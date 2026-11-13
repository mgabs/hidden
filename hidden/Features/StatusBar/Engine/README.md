# Engine

## Overview
Abstraction and OS-specific implementations for hiding and revealing menu-bar status items. `StatusBarController` delegates *how* items are hidden to a `MenuBarEngine` selected by `MenuBarEngineFactory`: `LegacyLengthEngine` inflates separator `NSStatusItem.length` on macOS <= 26 (and App Store builds), whereas `NativeVisibilityEngine` (in `HIDDENBAR_NATIVE_VISIBILITY` builds on macOS 27+) uses `MenuBarClientCore` allow-list assertions.

## Interface
- [`MenuBarEngine.swift:MenuBarEngine`](MenuBarEngine.swift): Protocol defining `state`, `collapse(completion:)`, `expand()`, `updateAlwaysHiddenSection(enabled:separatorHidden:)`, `isArrangementValid`, `isAlwaysHiddenSeparatorPlaced`, and `invalidateLayout()`.
- [`MenuBarEngine.swift:MenuBarEngineState`](MenuBarEngine.swift): Enum with cases `.expanded`, `.calibrating`, `.collapsed`, `.unavailable`.
- [`MenuBarEngine.swift:CollapseResult`](MenuBarEngine.swift): Enum with cases `.collapsed`, `.unavailable`.
- [`MenuBarEngine.swift:MenuBarOrder`](MenuBarEngine.swift): Namespace with `isItem(_:onHiddenSideOf:)` comparing window `frame.origin.x` respecting `Constant.isUsingLTRLanguage`.
- [`MenuBarEngine.swift:MenuBarItemProvider`](MenuBarEngine.swift): Protocol providing borrowed `toggleItem`, `separatorItem`, and `alwaysHiddenItem`.
- [`MenuBarEngineFactory.swift:MenuBarEngineFactory`](MenuBarEngineFactory.swift): Factory `make(items:)` returning `NativeVisibilityEngine` when compiled with `HIDDENBAR_NATIVE_VISIBILITY` on macOS `majorVersion >= 27`, otherwise `LegacyLengthEngine`.
- [`LegacyLengthEngine.swift:LegacyLengthEngine`](LegacyLengthEngine.swift): `MenuBarEngine` implementation that hides items by setting `separatorItem.length` to `max(500, min(screenWidth * 2, 10_000))` using the widest `NSScreen.screens` frame width.
- [`NativeVisibilityEngine.swift:NativeVisibilityEngine`](NativeVisibilityEngine.swift): `MenuBarEngine` implementation for macOS 27+ that resolves section bundles via `MenuBarInventoryProviding`, activates `NativeVisibilityProviding` assertions with `systemItemsToKeep` (`0..<64`), suspends restrictions during `CaptureActivityMonitoring` activity, and lifts restrictions briefly on `MenuBarClockProviding` clicks.
- Subdirectories: [`./Native/README.md`](./Native/README.md) — Native macOS 27 visibility shim, capture activity monitor, and clock click-replay bridge.

## Invariants
- `LegacyLengthEngine.state` MUST be derived live from `separatorItem.length > expandedLength` (20pt), never stored, so recomputing `collapsedLength` in `invalidateLayout()` preserves `.collapsed`.
- `LegacyLengthEngine.collapsedLength` MUST use `NSScreen.screens` max `frame.width` (not `NSScreen.main` or `visibleFrame`) and stay clamped to `[500, 10_000]`.
- `NativeVisibilityEngine` MUST read sections via `withLayout(_:)` only when `assertion == nil` (an unrestricted bar), because hidden items report stale Accessibility positions.
- `NativeVisibilityEngine` MUST increment `generation` on every new activation, layout read, or `releaseAssertion()`, and immediately invalidate any stale in-flight assertion whose `generation != self.generation` or when `captureActivity.isActive` is true.
- `NativeVisibilityEngine.activate(allowing:completion:)` MUST activate the new assertion before invalidating the old one to prevent flashing hidden items, and MUST fail open (release assertion, report `false`) on activation error.
- `NativeVisibilityEngine.invalidateLayout()` MUST clear cached `layout` and release any held assertion, resetting `state = .expanded` and restoring separators.
- `NativeVisibilityEngine` MUST always include `ownBundleIdentifier` and `systemItemsToKeep` (`Array(0..<64)`) in `allowedBundleIdentifiers` / `allowedSystemItems`, and keep `separatorItem.isVisible = false`.

## Side Effects
- `LegacyLengthEngine` mutates `separatorItem.length` and `alwaysHiddenItem?.length`, and logs one-shot `HideMechanism:` geometry diagnostics via `NSLog` on the first collapse with a backing window.
- `NativeVisibilityEngine` mutates `separatorItem.isVisible`, `alwaysHiddenItem?.length`, and `alwaysHiddenItem?.isVisible`, requests Accessibility authorization when unauthorized, activates/invalidates system-wide `NativeVisibilityAssertion`s, and registers `captureActivity.onChange` and `clock.onClick` callbacks.

## Verification
- Run: `make test`
