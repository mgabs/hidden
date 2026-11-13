# Proposal

## Intent
Rebrand Hidden Bar's bundle identifier from `com.dwarvesv.minimalbar` to `com.mgabs.hiddenbar` (clean break), extend `.github/workflows/build.yml` to publish versioned GitHub Releases and automatically update `mgabs/homebrew-tap`, and add `Casks/hidden-bar.rb` to `homebrew-tap`.

## Problem Statement
`mgabs/hidden` still carries upstream bundle ID `com.dwarvesv.minimalbar` (colliding with upstream TCC/UserDefaults), `.github/workflows/build.yml` only produces ephemeral workflow artifacts rather than downloadable GitHub Release zips, and `mgabs/homebrew-tap` has no cask for `hidden-bar`.

## Capabilities

### New Capabilities
- `rebrand-and-homebrew-release`: Bundle identifier rebrand (`com.mgabs.hiddenbar`), automated GitHub Release zip + SHA256 publishing, automated `homebrew-tap` cask bump, and `Casks/hidden-bar.rb` formula/cask definition.

### Modified Capabilities
- None.

## Scope

### In-Scope
- Rename `com.dwarvesv.minimalbar` -> `com.mgabs.hiddenbar` in `Hidden Bar.xcodeproj/project.pbxproj`, test fixtures, comments, and active docs (`README.md`, `hidden/README.md`, `docs/MANUAL.md`, `docs/RUNBOOK.md`, `StatusBarController.swift`).
- Update `.github/workflows/build.yml` to build & test on `push` to `main` / `v*` tags, package `Hidden-Bar-<version>.zip`, publish a GitHub Release, compute `sha256`, and update `Casks/hidden-bar.rb` in `mgabs/homebrew-tap` (using `secrets.HOMEBREW_TAP_TOKEN`).
- Create `/Users/mmetawea/Workbench/homebrew-tap/Casks/hidden-bar.rb` following `homebrew-tap` conventions (`postflight_steps`, `uninstall quit: "com.mgabs.hiddenbar"`, `zap trash`, `livecheck :github_latest`) and verify with `brew audit --cask`, `brew style`, and `ruby test/test_tap.rb`.

### Out-of-Scope (YAGNI)
- Migrating `UserDefaults` or TCC grants from `com.dwarvesv.minimalbar` (confirmed clean break).
- Rewriting historical `CHANGELOG.md` / archived OpenSpec entries.
- Code signing / notarization with Apple Developer ID certificates in CI (unsigned `Release-Direct` handled via `postflight_steps` quarantine removal).

## Assumptions
- **ASM-GEN-1**: Repository secret `HOMEBREW_TAP_TOKEN` (PAT with `contents: write` on `mgabs/homebrew-tap`) will be configured in `mgabs/hidden` GitHub settings before automated cask bumps run in CI.
- **ASM-GEN-2**: Release tags follow `vX.Y.Z` (e.g., `v1.11.1`) or `main` release workflow derives `<version>` from `MARKETING_VERSION` / `CFBundleShortVersionString` when not tagged.

## Success Metrics
- `rg "com\.dwarvesv\.minimalbar"` returns 0 in code, project settings, tests, and active user docs.
- `make test` and `make build` pass with bundle ID `com.mgabs.hiddenbar`.
- `brew audit --cask hidden-bar`, `brew style Casks/hidden-bar.rb`, and `ruby test/test_tap.rb` pass in `/Users/mmetawea/Workbench/homebrew-tap`.

## Review Gate
- [x] **Gate 1 Approval**: Proposal reviewed and approved by human before drafting specs.
