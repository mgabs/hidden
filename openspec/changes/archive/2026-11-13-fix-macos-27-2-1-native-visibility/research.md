# Research & Technical Tradeoffs

## 1. Intent & Ground Truth
- **Problem:** On macOS 27.2.1 (`26B131`), `/Applications/Hidden Bar.app` (`Release-Direct`, `HIDDENBAR_NATIVE_VISIBILITY=1`, `CODE_SIGNING_ALLOWED=NO`) fails to fold or flip its arrow (`>`) on left-click, while right-click opens Preferences normally.
- **Verified Runtime Ground Truth:** Running `"/Applications/Hidden Bar.app/Contents/MacOS/Hidden Bar"` outputs:
  - `NativeVisibility: inventory of 36 apps took 250 ms`
  - `NativeVisibility: arrow at x=1427.0; visible [...], hidden [...], always hidden [...]`
  - Nothing follows (no activation success, no activation error, no unavailability log).
- **Verified Codebase Facts:**
  - `MenuBarEngineFactory.make(items:)` (`hidden/Features/StatusBar/Engine/MenuBarEngineFactory.swift:16-20`) selects `NativeVisibilityEngine` on macOS `majorVersion >= 27`.
  - `NativeVisibilityEngine.collapse(completion:)` (`hidden/Features/StatusBar/Engine/NativeVisibilityEngine.swift:142-158`) sets `state = .calibrating`, resolves `withLayout`, and calls `activate(allowing:completion:)`.
  - `HBNativeVisibilityShim.m:68-71` calls `MBAssessmentModeAssertion` (`activateWithConfiguration:completionHandler:`). Because its completion handler never fires on `26B131` (or is dropped/rejected by `MenuBarAgent` without callback), `NativeVisibilityEngine.state` remains `.calibrating` permanently (`L119-121`), turning every subsequent click into a silent no-op.
  - Additionally, if `generation` bumps while `withLayout` or `activate` is in flight (`L269-272`), the `guard generation == self.generation` exits without resetting `state` from `.calibrating`.

## 2. Options Explored
- **Option A — Diagnose `MenuBarClientCore` on `26B131` + Harden `.calibrating` Timeout & `generation` Recovery (Recommended):**
  - Isolate why `activateWithConfiguration:completionHandler:` hangs on macOS 27.2.1 (`MenuBarAgent` logs, signed `make install SIGNING=""` vs ad-hoc `CODE_SIGNING_ALLOWED=NO`, selector/lifetime changes in `MenuBarClientCore`), fix the shim/signing requirement, AND add a bounded activation timeout + `generation`-mismatch state cleanup in `NativeVisibilityEngine` so `.calibrating` can never deadlock.
  - *Pros:* Fixes the actual macOS 27.2.1 failure while eliminating the `.calibrating` wedge bug permanently.
  - *Cons:* Requires checking `MenuBarAgent` behavior on `26B131` before finalizing the shim adjustment.
- **Option B — Signing/Entitlement Change Only (`SIGNING=""` in `Makefile`):**
  - Change `Makefile` default from `CODE_SIGNING_ALLOWED=NO` to signed builds without touching `NativeVisibilityEngine` or `HBNativeVisibilityShim.m`.
  - *Pros:* Minimal diff if ad-hoc signing is the sole trigger.
  - *Cons:* Fails completely for CI/unsigned local builds (`CODE_SIGNING_ALLOWED=NO` in `.github/workflows/build.yml`) if `MenuBarClientCore` also drifted on `27.2.1`, and leaves the `.calibrating` deadlock unfixed.
- **Option C — Fallback to `LegacyLengthEngine` on macOS 27.2.1:**
  - *Pros:* No `MenuBarClientCore` dependency.
  - *Cons:* Already known broken on macOS 27 (#360 — macOS 27 ejects inflated separators from the menu bar).

## 3. Tradeoff Matrix

| Criteria | Option A (Shim/Signing Fix + Timeout Hardening) | Option B (Signing Only) | Option C (Legacy Fallback) |
| :--- | :--- | :--- | :--- |
| **Complexity** | Low-Medium | Low | Low |
| **New Dependencies** | None | Local cert required | None |
| **Performance & Latency** | Same (<300ms); bounded timeout (2-3s) | Same if it works | Broken (#360) |
| **Maintenance Burden** | Low; self-healing state machine | Fragile on OS updates | High (broken on OS 27) |
| **Blast Radius** | `NativeVisibilityEngine`, `HBNativeVisibilityShim.m`, `Makefile` (optional) | `Makefile` only | Menu bar layout broken |

## 4. Recommendation
Adopt **Option A**: isolate why `MBAssessmentModeAssertion.activateWithConfiguration:completionHandler:` stalls on macOS 27.2.1 (`26B131`), apply the targeted shim/signing fix, and add a bounded activation timeout plus `generation`-drop cleanup in `NativeVisibilityEngine` so `.calibrating` can never permanently wedge clicks.

## 5. Breaking Changes & Deprecations
None. (`openspec/specs/notch-overflow-async-scan/spec.md` is unaffected.)

## Review Gate
- [x] **Gate 0 Decision**: Human decides Go (name the option) or No-Go before the proposal is drafted.
