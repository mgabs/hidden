<p align="center">
	<img width="160" height="160" src="img/icon_512@2x.png" alt="Hidden Bar">
</p>

# Hidden Bar

[![CI](https://github.com/mgabs/hidden/actions/workflows/build.yml/badge.svg)](https://github.com/mgabs/hidden/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/mgabs/hidden)](https://github.com/mgabs/hidden/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://github.com/mgabs/hidden/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Lightweight macOS menu bar manager to hide clutter, access notch-overflow items, and keep your menu bar clean.**

`Hidden Bar` (`com.mgabs.hiddenbar`) is a native AppKit utility for decluttering the macOS menu bar. It supports both classic separator-length hiding on macOS 13–26 and Accessibility-backed native visibility assertions on macOS 27+, along with a Notch Overflow menu for items hidden behind the camera housing.

<p align="center">
	<img width="400" src="img/screen1.png" alt="Hidden Bar expanded">
	<img width="400" src="img/screen2.png" alt="Hidden Bar collapsed">
</p>

---

## Quick Start

### Installation

```bash
# macOS (Homebrew)
brew install --cask mgabs/tap/hidden-bar
```

**Manual download:**
- Download `Hidden-Bar-*.zip` from [GitHub Releases](https://github.com/mgabs/hidden/releases/latest).
- Extract and move `Hidden Bar.app` to `/Applications`.
- Launch Hidden Bar and `⌘` + drag the separator icon in your menu bar between the icons you want hidden and visible.

### Usage

- `⌘` + drag to position Hidden Bar separator icons in the menu bar.
- Click the arrow icon to collapse or expand hidden menu bar items.
- Grant **Accessibility** permission when prompted so macOS 27+ native visibility and Notch Overflow can inspect menu bar items.

<p align="center">
	<img src="img/tutorial.gif" alt="Hidden Bar usage">
</p>

---

## Core Capabilities

- **Collapsible Menu Bar**: Hide less-used status items behind a single toggle with optional auto-collapse and hover-to-expand.
- **Notch Overflow Access**: Inspect and trigger menu bar items pushed behind the MacBook camera notch.
- **macOS 27+ Native Visibility**: Uses `MenuBarClientCore` visibility assertions (`NativeVisibilityEngine`) while suspending restrictions during mic/camera capture or Notification Center clock clicks.
- **Always-Hidden Section**: Separate icons that stay tucked away unless explicitly expanded.

---

## Documentation

- 📖 [**Manual**](docs/MANUAL.md) — Settings, hidden `defaults` options, and troubleshooting.
- 🏗️ [**Architecture**](docs/ARCHITECTURE.md) — Hiding mechanics, topology, and known limits.
- 🛠️ [**Maintainer Runbook**](docs/RUNBOOK.md) — Build, verification, and release workflow.

---

## Testing & Verification

```bash
# Run unit tests
make test

# Build Release-Direct app
make build

# Build and install to /Applications
make install
```

---

## Architecture Blueprint

### System Overview
Hidden Bar is a macOS menu-bar utility (`com.mgabs.hiddenbar`) built with AppKit. On macOS ≤ 26 (and App Store builds), `LegacyLengthEngine` hides menu-bar items by inflating an `NSStatusItem` separator's length; on macOS 27+ direct builds (`HIDDENBAR_NATIVE_VISIBILITY`), `NativeVisibilityEngine` reads item positions via Accessibility and acquires a `MenuBarClientCore` visibility assertion while suspending restrictions during mic/camera capture or Notification Center clock clicks.

### Subdirectories & System Boundaries
- **hidden**: [./hidden/README.md](./hidden/README.md) — Application entry point (`AppDelegate`), bridging header, and all feature/shared modules (`Common`, `Extensions`, `Features`, `Models`, `Views`).

### Global Invariants
- `MenuBarEngineFactory.make(items:)` selects `NativeVisibilityEngine` only when `HIDDENBAR_NATIVE_VISIBILITY` is compiled in and `ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27`; otherwise it falls back to `LegacyLengthEngine`.
- `NativeVisibilityEngine` and `NotchOverflowController` fail open (no hiding / no scan) when Accessibility permission (`AXIsProcessTrusted()`) is missing.
- Only one `Hidden Bar` instance per bundle runs at a time (`AppDelegate.ensureSingleInstance()`).

### Global Side Effects
- Creates and mutates `NSStatusBar.system` items, reads/writes `UserDefaults.standard`, and registers/unregisters login items via `SMAppService`.
- Queries running `.app` bundles via Accessibility IPC (`AXExtrasMenuBar`), acquires/invalidates `MBAssessmentModeAssertion` on macOS 27+ direct builds, and installs global `NSEvent` monitors for `hoverToExpand` and clock clicks.

---

## Requirements

- macOS 13.0 (Ventura) or later.

---

## Donating & Humanitarian Support

Hidden Bar is free and open-source. If you wish to express gratitude, please consider donating to humanitarian relief organizations providing food, water, medical aid, and shelter to families in Gaza and Palestine:

- **[UNRWA](https://www.unrwa.org)** — UN Relief and Works Agency for Palestine Refugees
- **[Palestine Children's Relief Fund (PCRF)](https://www.pcrf.net)**
- **[Palestine Red Crescent Society](https://www.palestinercs.org)**
- **[Medical Aid for Palestinians (MAP)](https://www.map.org.uk)**
- **[Anera](https://www.anera.org)**
- **[Médecins Sans Frontières (MSF)](https://www.msf.org)**
- **[International Committee of the Red Cross (ICRC)](https://www.icrc.org)**
- **[UNICEF](https://www.unicef.org)**
- **[World Food Programme (WFP)](https://www.wfp.org)**

---

## License

[MIT](LICENSE)
