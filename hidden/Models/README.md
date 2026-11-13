# Models

## Overview
Value-type data models representing global keyboard shortcut preferences and discrete auto-hide delay intervals.

## Interface
- `GlobalKeybindingPreferences.swift:GlobalKeybindPreferences` — `struct GlobalKeybindPreferences: Codable, CustomStringConvertible` storing modifier flags (`function`, `control`, `command`, `shift`, `option`, `capsLock`), `carbonFlags: UInt32`, `characters: String?`, `keyCode: UInt32`, and computed `description: String`.
- `SelectedSecond.swift:SelectedSecond` — `enum SelectedSecond: Int` (`fiveSeconds = 0`, `tenSeconds = 1`, `fifteenSeconds = 2`, `thirdtySeconds = 3`, `oneMinus = 4`) with `func toSeconds() -> Double` and `static func secondToPossition(seconds: Double) -> Int`.

## Invariants
- `GlobalKeybindingPreferences.swift:GlobalKeybindPreferences.description` suppresses the `"Fn"` prefix when `keyCode` maps to a known function key (`F1`–`F20` via `functionKeyName`), and maps special key codes `36` (`"⏎"`), `51` (`"⌫"`), and `49` (`"⎵"`) before falling back to uppercased `characters`.
- `GlobalKeybindingPreferences.swift:GlobalKeybindPreferences.description` orders modifier glyphs as `Fn`, `⌃`, `⌥`, `⌘`, `⇧`, `⇪`.
- `SelectedSecond.swift:SelectedSecond` raw `Int` cases (`0..4`) map to `5.0`, `10.0`, `15.0`, `30.0`, and `60.0` seconds; `secondToPossition(seconds:)` defaults to `0` (`fiveSeconds`) for unrecognized durations.

## Side Effects
- None. Both `GlobalKeybindingPreferences.swift:GlobalKeybindPreferences` and `SelectedSecond.swift:SelectedSecond` are pure value types with no disk, network, or global state mutations.

## Verification
- Run: `make test`
