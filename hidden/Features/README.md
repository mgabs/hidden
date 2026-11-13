# Features

## Overview
Feature modules for Hidden Bar's macOS menu-bar UI, preferences window, about pane, and notch overflow menu.

## Subdirectories & Boundaries
- **About**: [./About/README.md](./About/README.md) - Displays app version, build number, and external project links (`AboutViewController`).
- **NotchOverflow**: [./NotchOverflow/README.md](./NotchOverflow/README.md) - Detects notch-occluded menu-bar extras off-main via Accessibility and presents an interactive overflow `NSMenu` (`NotchOverflowController`, `NotchGeometry`, `MenuBarExtraClassifier`).
- **Preferences**: [./Preferences/README.md](./Preferences/README.md) - Manages the Preferences window, General/About tab switching, global shortcut recording, and preference bindings (`PreferencesWindowController`, `PreferencesViewController`).
- **StatusBar**: [./StatusBar/README.md](./StatusBar/README.md) - Coordinates status-bar items, expand/collapse/always-hidden state, auto-hide timer, hover-to-expand, and the macOS ≤ 26 / 27+ hiding engines (`StatusBarController`, `ExpandCollapseActionResolver`).
