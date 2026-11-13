# Research & Technical Tradeoffs

## 1. Intent & Ground Truth
- **Problem:** Fork `mgabs/hidden` still uses upstream bundle identifier `com.dwarvesv.minimalbar`, `.github/workflows/build.yml` only uploads workflow artifacts (not GitHub Releases), and `mgabs/homebrew-tap` has no `hidden-bar` cask.
- **Verified Codebase Facts:**
  - `Hidden Bar.xcodeproj/project.pbxproj` sets `PRODUCT_BUNDLE_IDENTIFIER = com.dwarvesv.minimalbar` (`L836, 862, 951, 1037`) and `com.dwarvesv.minimalbar.HiddenTests` (`L655, 673, 691, 1125`).
  - `HiddenBarTests/MenuBarEngineTests.swift`, `HiddenTests/MenuBarLayoutResolverTests.swift`, `StatusBarController.swift:113`, `README.md`, `hidden/README.md`, `docs/MANUAL.md`, `docs/RUNBOOK.md`, `docs/BACKLOG.md`, and `CHANGELOG.md` reference `com.dwarvesv.minimalbar`.
  - `.github/workflows/build.yml` runs `make test` + `make build` on `push: [main]` and `workflow_dispatch`, uploading `build/Hidden-Bar-Direct.app.zip` via `actions/upload-artifact@v4`.
  - `origin` is `git@github.com:mgabs/hidden.git`.
  - `/Users/mmetawea/Workbench/homebrew-tap` (`mgabs/homebrew-tap`) uses `Casks/<name>.rb` with `postflight_steps` (`run "xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/..."], must_succeed: false`), `uninstall quit:`, `zap trash:`, and `.github/workflows/ci.yml` running `ruby test/test_tap.rb`, `brew audit --cask`, and `brew style`.

## 2. Options Explored
- **Option A — Clean Bundle ID Rename + Tag/Release CI + Direct `homebrew-tap` Cask Bump (Recommended):**
  - Rename `com.dwarvesv.minimalbar` -> `com.mgabs.hiddenbar` (clean break, no defaults migration).
  - On `push` to `main` (or `v*` tag / `release` event), `build.yml` builds `Hidden-Bar-<version>.zip`, publishes a GitHub Release asset, computes `sha256`, and updates `Casks/hidden-bar.rb` in `mgabs/homebrew-tap` using `HOMEBREW_TAP_TOKEN`.
  - Add `Casks/hidden-bar.rb` in `homebrew-tap` following `tab-flow.rb` conventions.
  - *Pros:* End-to-end automated release pipeline; clean TCC/UserDefaults separation from upstream; passes `brew audit --cask` & `brew style`.
  - *Cons:* Requires `HOMEBREW_TAP_TOKEN` PAT configured in `mgabs/hidden` repository secrets.
- **Option B — Manual Homebrew Bump on Release:**
  - Publish GitHub Release from `build.yml`, bump `Casks/hidden-bar.rb` manually.
  - *Pros:* No cross-repo PAT secret needed.
  - *Cons:* Does not satisfy automated Homebrew cask updates on new release.

## 3. Tradeoff Matrix

| Criteria | Option A (Automated Release + Tap Bump) | Option B (Manual Tap Bump) |
| :--- | :--- | :--- |
| **Complexity** | Low-Medium | Low |
| **New Dependencies** | `softprops/action-gh-release@v2` + `HOMEBREW_TAP_TOKEN` secret | None |
| **Performance & Latency** | ~2-3 min macOS runner build | Manual step |
| **Maintenance Burden** | Zero-touch releases | Manual SHA/version edits |
| **Blast Radius** | `project.pbxproj`, tests, docs, `.github/workflows/build.yml`, `homebrew-tap/Casks/hidden-bar.rb` | Same minus CI bump step |

## 4. Recommendation
Adopt **Option A**: clean-break rename to `com.mgabs.hiddenbar`, publish versioned GitHub Release zips in `.github/workflows/build.yml`, automatically update `Casks/hidden-bar.rb` in `mgabs/homebrew-tap` via `HOMEBREW_TAP_TOKEN`, and author `Casks/hidden-bar.rb` compliant with `homebrew-tap` audit rules.

## 5. Breaking Changes & Deprecations
None. (`openspec/specs/` existing specs remain valid.)

## Review Gate
- [x] **Gate 0 Decision**: Human decides Go (name the option) or No-Go before the proposal is drafted.
