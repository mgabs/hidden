# Spec-Rails Workflow Guide

## Lanes
- **Feature Lane (`feat/<id>-<slug>`)**: Gated feature progression (Gates 0 → 4).
- **Bugfix Lane (`fix/<slug>`)**: Zero-contamination bug isolation with red test reproduction (Gates B1 → B3).
- **Chore Lane (`chore/<slug>`)**: Zero behavior change tasks (docs, maintenance).

## Sequential Gate Enforcement
- **Gate 0**: Research & Options Matrix
- **Gate 1**: Proposal & Intent
- **Gate 2**: Architecture Design & Living Spec Delta
- **Gate 3**: Tasks DAG Breakdown & Red-Green-Refactor Plan
- **Gate 4**: Verification & Evidence Check
- **Gate 5 / 6**: Stream Merges & Final Delivery

Direct commits to `main` or `master` are strictly blocked by branch protection.
