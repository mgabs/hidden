# Spec-Rails CLI Commands

## Commands

### `spec-rails init`
Initialize Spec-Rails in an OpenSpec repository. Fails fast if `openspec/` is absent.
```bash
npx --no-install spec-rails init [--stack ts|python|go|rust] [--force]
```

### `spec-rails check`
Verify OpenSpec change gates, lane conventions, and task lists.
```bash
npx --no-install spec-rails check [--audit]
```

### `spec-rails verify`
Run test suite and verify coverage and mutation score thresholds.
```bash
npx --no-install spec-rails verify
```
