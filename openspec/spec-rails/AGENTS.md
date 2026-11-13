# Spec-Rails (Spec-Driven, Testing-Railed Development) Rules

When working in a repository containing `openspec/spec-rails/WORKFLOW.md`:

**Precedence**: if these rules conflict with the repository's own rules (root `AGENTS.md`, `CLAUDE.md`, tool rules), the stricter rule wins. If it is unclear which is stricter, or following one breaks the other, stop and ask the human, who decides. Never resolve a conflict silently.

0. **Pre-Execution Invariant (Zero Direct Edits to main)**:
   - Before invoking `edit_file`, `write_file`, or running mutating commands, ALWAYS verify the active branch: `git branch --show-current`.
   - If on `main` or `master`, HALT immediately. Checkout a dedicated lane branch first. Direct edits on `main` are strictly forbidden.
1. **The Ponytail Mindset & Strict YAGNI**:
   - Strictly apply YAGNI (You Aren't Gonna Need It). Build strictly what the active capability and slice require.
   - Default answer is "No": push back on vague, unneeded, or speculative requirements before writing a line of code.
   - Boring > Clever: standard library over new dependencies, simple loops over metaprogramming acrobatics.
   - Code is a liability: smallest diff that passes all gates wins.
   - Zero unsolicited architecture: never introduce speculative abstractions, unused helper functions, premature plugin hooks, or hypothetical configuration flags.
   - **Contract Scaffolding Rail**: Before generating slice implementation, commit domain types, interface contracts, schemas, and empty function/method signatures. Agents generate logic strictly within scaffolded boundaries without inventing abstractions.
   - **Understand or Delete (Comprehension Invariant)**: Zero black-box code. If the human reviewer cannot explain every line of the diff, delete and revert it immediately. Working code without human comprehension is technical debt.
   - Out-of-Scope (YAGNI) boundaries in `proposal.md` are binding prohibitions; reject any requirement bleed.
   - Minimal blast radius: touch only files strictly necessary for the active task.
   - Ruthless deletion: delete dead code immediately upon mutation survival. Any code not provably required is dead code.
2. **Pick a Lane First**: Feature (`feat/<id>-<slug>` with dots normalized to hyphens, e.g. `W1.2` → `w1-2-<slug>`, Gates 0–4), Bugfix (`fix/<slug>`, Gates B1–B3), or Chore (`chore/<slug>`, zero behavior change, no gates).
3. **Strict Human Gates**: Stop and obtain explicit human approval at every gate. A gate passes only when its Review Gate checkbox is ticked by a human; NEVER self-tick human Review Gate boxes.
   - **Gated Planning & OpenSpec Commands**: Create changes with `openspec-propose` (CLI-free) as `<id>-<slug>`. Draft planning artifacts one at a time (instructions come from `openspec/schemas/spec-rails/schema.yaml`), pausing after each gate for explicit human review and checkbox approval before drafting the next artifact (never generate all planning artifacts in one unreviewed pass). Run `openspec-apply-change` and `openspec-archive-change` (archive under `openspec/changes/archive/`) only after Gate 3 is ticked by a human.
   - **Commit Cadence**: Commit at stage boundaries rather than per gate tick: once after planning (research through tasks), once after the code (one commit per slice is fine when there are several), and once after `openspec archive`. Exceptions: the contract scaffolding commit (task 3.0), green slice commits (Rule 4), rebases and stream merges, and the bugfix and chore lanes.
   - **Features**: Gate 0 (`research.md`) → Gate 1 (`proposal.md`) → Gate 2 (`design.md` + delta specs) → Gate 3 (`tasks.md`) → Gate 4 (Sync, Archive, Merge: your test, coverage and mutation commands, then archive).
   - **Bugs**: Spawn `.worktrees/fix-<slug>` off `main` first → Gate B1 (`docs/bug-reports/<date>-<slug>.md` inside worktree) → Gate B2 (Red regression test shown, uncommitted) → Gate B3 (Green fix + docs/spec sync + merge).
4. **Testing Rails**:
   - Red before Green. Red tests are never committed alone; commit them together with Green.
   - $\ge 95\%$ line and branch coverage; $\ge 95\%$ mutation kill score on core business logic (kill or delete dead code; justify every remaining survivor in the PR).
   - Never delete assertions, skip failing tests, or write vacuous tests.
5. **Commit & Merge Hygiene**:
   - Pre-commit hooks installed; run linters, formatters, and the full suite before every commit. Never `--no-verify`.
   - Inspect `git status` and `git diff` before every commit.
   - Before any merge: rebase onto target, re-verify rails, merge `--ff-only`.
   - After any worktree merge: immediately remove worktree (`git worktree remove`), delete branch (`git branch -d`), and prune metadata (`git worktree prune`).
