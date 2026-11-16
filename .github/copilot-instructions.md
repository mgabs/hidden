# Copilot Instructions

Hidden Bar: a sandboxed AppKit (Swift) macOS menubar utility. One SwiftPM dependency (HotKey), no network/daemon/helper app.

## Build & test

Use the Makefile (unsigned by default, derived data in `build/`):

- `make build`: Release-Direct app → `build/Build/Products/Release-Direct/Hidden Bar.app`
- `make test`: full unit tests (Debug-Direct, scheme `Hidden Bar`). Same command runs in CI and the pre-commit hook.
- Single test (two test targets: `HiddenBarTests/` and `HiddenTests/`):
  ```
  xcodebuild -project HiddenBar.xcodeproj -scheme "Hidden Bar" -configuration Debug-Direct \
    -derivedDataPath build -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO \
    test -only-testing:HiddenBarTests/MenuBarEngineTests/testName
  ```
- No linter configured. `pre-commit` runs whitespace/EOF/yaml checks, `make test`, and blocks commits on `main`/`master`.

Two build flavors: **Direct** (`Hidden Bar` scheme, `*-Direct` configs) and **App Store** (`Hidden Bar App Store` scheme, sandbox-restricted).

## Architecture

Read `docs/ARCHITECTURE.md` for the full picture (note: it predates the native engine and notch overflow described below). Essentials:

- Hiding is faked by geometry: a separator `NSStatusItem` whose length is inflated (bounded by the widest screen, max 10,000pt) pushes icons off-screen. `isCollapsed` is derived (`separator.length > 20`), never an equality check.
- `AppDelegate` owns `StatusBarController` (`hidden/Features/StatusBar/`), which decides *when* to collapse/expand (auto-hide timer, hover-to-expand, always-hidden section). It must never write a status-item length itself; it calls `MenuBarEngine` (`Engine/`).
- `MenuBarEngineFactory` is the single place that picks the engine: `LegacyLengthEngine` (length trick) by default; `NativeVisibilityEngine` (Accessibility-based) only on macOS 27+ and only when compiled with `HIDDENBAR_NATIVE_VISIBILITY` (Direct build; the App Store sandbox blocks the Accessibility reads).
- `Preferences` (`hidden/Common/`) is a facade enum over `UserDefaults`; setters post `NotificationCenter` names (`Notification.Name+Extension.swift`) that the controller and prefs window observe. No other state store.
- `Features/NotchOverflow/` handles hidden icons that end up under the notch; layout classification lives in `Features/StatusBar/Layout/`.
- Preferences UI is storyboard-based; it is the only window.

## Conventions

- Keep the security posture: sandboxed, no network entitlement, no subprocess/shell use, no new dependencies without strong reason.
- Logic is kept in small pure types (e.g. `AutoCollapseCoordinator`, `ExpandCollapseAction`, `MenuBarLayout`, notch geometry) so it is unit-testable without AppKit; follow that pattern and add tests in the existing test targets.
- Self-restore: our status items are forced `isVisible = true` at launch since they are the app's only UI; preserve this.
- Workflow is OpenSpec + Spec-Rails (`openspec/`, `docs/spec-rails/`, skills in `.github/skills/`, prompts `opsx-*`). Feature branches `feat/<id>-<slug>`, bugfix `fix/<slug>`, chore `chore/<slug>` (CONTRIBUTING.md also mentions `feature/`/`bugfix/`); never commit to `main`. Specs for in-flight/archived changes live in `openspec/changes` and `openspec/specs`.
- Version lives in `Version.xcconfig`; update `CHANGELOG.md` for user-facing changes.
