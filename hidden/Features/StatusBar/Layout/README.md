# Layout

## Overview
Accessibility-based menu-bar inventory and multi-display section resolution. `AccessibilityMenuBarInventory` snapshots running `.app` bundles' `AXExtrasMenuBar` items and display geometries, and `MenuBarLayoutResolver` maps each third-party bundle to `.visible`, `.hidden`, or `.alwaysHidden` relative to Hidden Bar's separator frames.

## Interface
- [`MenuBarLayout.swift:MenuBarSection`](MenuBarLayout.swift): `Comparable` enum (`.visible < .hidden < .alwaysHidden`) representing menu-bar visibility sections.
- [`MenuBarLayout.swift:MenuBarInventoryItem`](MenuBarLayout.swift): Value type pairing an owning `bundleIdentifier: String?` with its Accessibility `frame: CGRect`.
- [`MenuBarLayout.swift:MenuBarDisplay`](MenuBarLayout.swift): Value type pairing display `identifier` with both `appKitFrame` (bottom-left origin) and `accessibilityFrame` (top-left origin).
- [`MenuBarLayout.swift:MenuBarInventoryProviding`](MenuBarLayout.swift): Protocol defining `isAuthorized`, `requestAuthorization()`, and async main-queue `snapshot(completion:)`.
- [`MenuBarLayout.swift:MenuBarLayout`](MenuBarLayout.swift): Resolved `[String: MenuBarSection]` map with `bundles(in:)` returning sorted bundle identifiers.
- [`MenuBarLayout.swift:MenuBarLayoutResolver`](MenuBarLayout.swift): Resolves `[MenuBarInventoryItem]` into `MenuBarLayout?` across displays (`resolve(...)`), projecting separator frames from the arrow-edge distance (`section(of:separatorFrame:alwaysHiddenSeparatorFrame:isLTR:)`), excluding `ownBundle` and `systemItemOwners` (`com.apple.MenuBarAgent`, `com.apple.controlcenter`).
- [`AccessibilityMenuBarInventory.swift:MenuBarDisplayInventory`](AccessibilityMenuBarInventory.swift): `current()` converts `NSScreen.screens` frames into `MenuBarDisplay`s using `desktopTop` for top-left Accessibility coordinates.
- [`AccessibilityMenuBarInventory.swift:AccessibilityMenuBarInventory`](AccessibilityMenuBarInventory.swift): `MenuBarInventoryProviding` implementation querying `AXIsProcessTrusted()`, prompting once via `AXIsProcessTrustedWithOptions`, and concurrently walking `.app` processes' `AXExtrasMenuBar` children (`messagingTimeout = 0.1`s), plus `frame(of:)`.

## Invariants
- `MenuBarLayoutResolver.resolve(...)` MUST return `nil` (fail open) if the separator or always-hidden separator display cannot be determined, if both separators are not on the same display, or if any third-party `MenuBarInventoryItem` cannot be matched to a `MenuBarDisplay`.
- When a bundle owns multiple status items, `MenuBarLayoutResolver` MUST assign the most visible section (`min(sections[bundle] ?? section, section)`).
- `MenuBarLayoutResolver` MUST exclude `systemItemOwners` (`com.apple.MenuBarAgent`, `com.apple.controlcenter`) and `ownBundle`, while keeping `SystemUIServer` items sectioned by position.
- `AccessibilityMenuBarInventory.requestAuthorization()` MUST prompt at most once per process launch (`hasRequestedAuthorization`), and `snapshot(completion:)` MUST filter to non-self `.app` bundles and deliver results on `DispatchQueue.main`.
- `AccessibilityMenuBarInventory` MUST NOT be used inside the App Sandbox (mach-lookup to `com.apple.axserver` is denied).

## Side Effects
- `AccessibilityMenuBarInventory.requestAuthorization()` triggers the macOS Accessibility trust prompt via `AXIsProcessTrustedWithOptions` once per launch.
- `AccessibilityMenuBarInventory.snapshot(completion:)` performs concurrent Accessibility IPC (`AXUIElementCopyAttributeValue`) across running `.app` processes on `DispatchQueue.global(qos: .userInitiated)` and logs timing via `NSLog`.

## Verification
- Run: `make test`
