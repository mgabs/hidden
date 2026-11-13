---
name: spec-rails
description: >-
  Spec-Driven, Testing-Railed Development (Spec-Rails) workflow for gated feature
  delivery, multi-agent Git worktree streams, Red-Green-Mutation testing rails,
  and zero-contamination bugfix isolation. Activate when installing Spec-Rails on an OpenSpec project,
  proposing features, triaging bugs, or executing gated vertical slices.
---

# Spec-Rails Skill

Follow `openspec/spec-rails/WORKFLOW.md`. Normalize work item IDs to lowercase hyphens (`W1.2` → `w1-2-<slug>`) and create a change with the propose workflow (`openspec-propose`). For gated planning, generate one artifact at a time with `openspec instructions <artifact> --change <id>-<slug>`, pausing for a human to review and tick its `## Review Gate` checkbox before generating the next file (never generate all planning artifacts in one unreviewed pass). Run `openspec-apply-change` and `openspec-archive-change` only after Gate 3 is ticked by a human. Commit at stage boundaries rather than per gate tick: once after planning (research through tasks), once after the code (one commit per slice is fine when there are several), and once after `openspec archive`. Exceptions: green slice commits (Rule 4), rebases and stream merges, and the bugfix and chore lanes. This is guidance and is not mechanically enforced.

## 0. The Ponytail Mindset & Strict YAGNI

- **Default answer is "No"**: Push back on vague or unneeded requirements before building.
- **Boring > Clever**: Standard library over new dependencies. Simple logic over complex acrobatics.
- **Code is a liability**: Smallest diff that satisfies specifications and passes gates wins.
- **Zero speculative architecture**: No unused abstractions, premature plugin frameworks, or hypothetical configuration flags.
- **Minimal blast radius**: Touch only files strictly required for the slice.
- **Ruthless deletion**: Kill mutants or delete dead code. Any surviving mutant triggers deletion of unneeded code.

## 1. Pick a Lane First

- **Feature** (`feat/<id>-<slug>`): Follow Gates 0–4.
- **Bugfix** (`fix/<slug>`): Follow Gates B1–B3.
- **Chore** (`chore/<slug>`): Zero behavior change; run pre-commit & tests; no gates.

## 2. Gate Execution Checklist

1. **Gate 0 (Research & Tradeoffs)**: Generate `research.md` in `openspec/changes/<id>-<slug>/`. Present 2–3 options, tradeoffs, and breaking changes. Stop for human developer decision (Go or No-Go).
2. **Gate 1 (Proposal)**: Generate `proposal.md` for the chosen option. Stop for human review.
3. **Gate 2 (Architecture, Specs & Test Strategy)**: Generate OpenSpec delta specs (`### Requirement: REQ-X-N name`, MUST/SHALL, at least one scenario; MODIFIED/REMOVED repeat existing header verbatim) and `design.md` (architecture, boundary rules, and concrete test strategy). Stop for human review.
4. **Gate 3 (Tasks)**: Generate `tasks.md` with DAG and worktree streams. Stop for human review before running `openspec-apply-change` or spawning slice worktrees.
5. **Apply (Vertical Slices)**: Only after Gate 3 is ticked by a human, execute per vertical slice:
   - **Contract Scaffolding**: Commit domain interfaces, types, schemas, and empty signatures before generating logic.
   - **Red-Green-Refactor**: Write failing unit tests (`Red`) tested locally, then implement minimal code (`Green`). Commit tests + code together. Line & branch coverage $\ge 95\%$.
   - **Mutation Testing**: Run mutation testing $\rightarrow$ achieve $\ge 95\%$ kill score on core logic (kill, delete dead code, or restructure equivalent mutants).
6. **Gate 4 (Sync, Archive & Merge)**: Ensure all stream worktrees are merged, removed, and pruned (`git worktree prune`). Reviewer verifies line-by-line understanding of all code (delete ununderstood code). Tick completed slice items and the final integration task in `tasks.md` (with `Evidence:` on Red/Green/Coverage/Mutation tasks), rebase onto `main`, run your test, coverage and mutation commands, run `openspec validate <change>`, then run `openspec archive <change> --yes` (or `openspec-archive-change`; syncs deltas into `openspec/specs/` and archives the change), and merge `--ff-only`.

## 3. Multi-Agent Worktree Rails & Subagent Hygiene

- **Declarative Command Shapes**:
  - Always use declarative target flags instead of compound `cd <dir> && <cmd>` chains:
    - `git -C .worktrees/<id>-<stream> <cmd>`
    - `npm --prefix .worktrees/<id>-<stream> <cmd>`
    - `cargo --manifest-path .worktrees/<id>-<stream>/Cargo.toml <cmd>`
- **Commit Policy**: never use `--no-verify`, including in stream worktrees. Pre-commit hooks and testing rails are enforced on every commit and merge.
- **Subagent Zero-Polling Invariant**:
  - Never run status checks, log polls, or transcript checks in a loop while waiting for background tasks or subagents.
  - Dispatch tasks with fire-and-halt: end your turn immediately and wait for reactive wakeup notifications to strictly preserve conversation context economy below 200,000 tokens.

Never tick a Gate 0–3 Review Gate box yourself. Re-read the change's delta specs against the schema after stream rebases (run `openspec validate <change>`; if the OpenSpec CLI is unavailable, do the schema re-read by hand), and run your test suite before committing. See `openspec/spec-rails/WORKFLOW.md` §7.
