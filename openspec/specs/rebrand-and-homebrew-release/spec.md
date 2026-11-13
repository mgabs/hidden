# rebrand-and-homebrew-release Specification

## Purpose
Defines the `com.mgabs.hiddenbar` bundle identifier rebrand, automated GitHub Release + `homebrew-tap` cask update workflow, and `Casks/hidden-bar.rb` compliance requirements.

## Requirements

### Requirement: REQ-REL-1 Bundle Identifier Rebrand
All build configurations of the Hidden Bar app target MUST use `PRODUCT_BUNDLE_IDENTIFIER = com.mgabs.hiddenbar` (and test target `com.mgabs.hiddenbar.HiddenTests`), with no `UserDefaults` migration from `com.dwarvesv.minimalbar`.

#### Scenario: Built app carries new bundle identifier
- **GIVEN** `make build` builds `Release-Direct`
- **WHEN** `CFBundleIdentifier` of `Hidden Bar.app/Contents/Info.plist` is inspected
- **THEN** it equals `com.mgabs.hiddenbar` and all unit tests in `make test` pass

### Requirement: REQ-REL-2 Automated GitHub Release & Homebrew Tap Update
`.github/workflows/build.yml` MUST test, build `Release-Direct`, package `Hidden-Bar-<version>.zip`, publish a GitHub Release on `main` / `v*` release triggers, and update `version` and `sha256` in `mgabs/homebrew-tap` `Casks/hidden-bar.rb` when `HOMEBREW_TAP_TOKEN` is present.

#### Scenario: Release tag or main release updates tap cask
- **GIVEN** a release build runs on `main` with `secrets.HOMEBREW_TAP_TOKEN` configured
- **WHEN** `Hidden-Bar-<version>.zip` is published to GitHub Releases
- **THEN** `Casks/hidden-bar.rb` in `mgabs/homebrew-tap` is updated with the new `version` and matching `sha256`

### Requirement: REQ-REL-3 Homebrew Tap Cask Compliance
`Casks/hidden-bar.rb` in `/Users/mmetawea/Workbench/homebrew-tap` MUST follow `homebrew-tap` DSL rules (`postflight_steps` with `run "xattr"` and `{{appdir}}/Hidden Bar.app`, `uninstall quit: "com.mgabs.hiddenbar"`, `zap trash`, `livecheck :github_latest`) and pass tap validation.

#### Scenario: Homebrew tap audit and style pass
- **GIVEN** `Casks/hidden-bar.rb` exists in `homebrew-tap`
- **WHEN** `ruby test/test_tap.rb`, `brew audit --cask`, and `brew style` run
- **THEN** all checks pass with zero errors

### Requirement: NFR-REL-1 Release Workflow Idempotency
Updating `Casks/hidden-bar.rb` in CI MUST be idempotent (no-op if `version` and `sha256` are already current) and MUST NOT fail CI builds on forks/PRs where `HOMEBREW_TAP_TOKEN` is absent.

#### Scenario: Build without tap token
- **GIVEN** a workflow run without `secrets.HOMEBREW_TAP_TOKEN`
- **WHEN** `build.yml` runs
- **THEN** tests, build, and artifact upload still succeed and the tap-bump step is skipped cleanly
