# Implementation Plan: Repo Branch Cleanup & Master/Develop Reconciliation

## Current state (as of writing)

- **Local branches**: only `develop` (checked out, HEAD `89b8e55`) and `master` (`6ad69a8`) remain. All batch/feature/worktree local branches already deleted by a prior agent.
- **Remote branches still present** (need decisions below): `origin/batch/1-extended-codec-coverage`, `origin/batch/1-fix-cli-encoding-label`, `origin/batch/2-column-dictionary-encoding`, `origin/batch/2-fix-cli-stats-bug`, `origin/batch/3-replace-dedup-scan`, `origin/batch/3-schema-evolution`, `origin/batch/4-cli-tooling`, `origin/batch/5-incremental-delta-encoding`, `origin/feature/remove-dedup-v3`, plus `origin/develop`, `origin/master`.
- **Local `develop`** is 6 commits ahead / 3 behind `origin/develop` — diverged because some batch branches were merged locally with direct-merge commits while the same branches were *also* merged on GitHub via PR (different commit hashes, same underlying content). Local `develop` also contains a careful manual merge of `feature/remove-dedup-resolved` (commit `89b8e55`), which is **not yet on any remote** — this is real, valuable, non-trivial work (correctly reconciled schema-v3/dedup-removal against develop's CLI/patch/codec-coverage work) and must not be lost.
- **Local `master`** has 35 commits not on `origin/master`, never pushed, and is a mess: includes an accidental `.agents/AGENTS.md` + `.agents/skills/ponytail/SKILL.md` leak (unrelated Claude Code skill config, not project content), a `WIP: epitaxy pre-switch from master` commit, and a redundant independent rebuild of the same batch-branch history already on `origin/master` via PRs. **Nothing on local `master` is uniquely valuable** — everything of substance (the real dedup-removal work) reached `origin/master` already via PR #33.
- **`origin/master` (real production branch)** merged PR #33 (`feature/remove-dedup-v3`) which — likely **unintentionally** — deleted `cli/`, `src/patch/`, `src/serde/ray.luau`, and their docs/tests relative to `develop`. This is a real product regression sitting on production right now, independent of the branch-cleanup task, and should be flagged/fixed regardless of what's decided about branch hygiene.
- Stray untracked file `.batch.md` may exist in the working tree (a draft batch task list for a parallel-encoding design, unrelated to this cleanup) — don't let any `git clean` step nuke it accidentally; check with the user before deleting untracked files.

## Phase 1 — Reconcile local `develop` with `origin/develop`

These diverged only because equivalent batch-branch content landed via two different merge paths. Expect a clean or near-clean merge.

```bash
git checkout develop
git merge origin/develop --no-edit
```

- If conflicts appear, they should only be cosmetic (duplicate merge commits of identical content) — resolve by inspecting `git diff` per conflicted file; the underlying batch-branch changes are already identical on both sides.
- Run `pesde run test` after the merge to confirm all specs still pass (baseline: 134 tests / 24 specs green before this merge).
- **Checkpoint**: show the user the merge result / test output before pushing.

## Phase 2 — Push reconciled `develop`

```bash
git push origin develop
```

This carries `89b8e55` (the dedup-removal + CLI/patch reconciliation merge) to the remote for the first time. A plain push should work once Phase 1's merge makes local `develop` a strict descendant of `origin/develop`.

## Phase 3 — STOP: decide how to fix `origin/master`'s regression

**Requires explicit user sign-off — do not proceed silently.** Two options:

- **Option A (recommended)**: open a PR merging (reconciled) `develop` into `master`, since `develop` has the complete, correct state (dedup removed, v3 format, CLI tooling, patch encoding, codec coverage, docs all intact). This is the standard, reviewable way to bring production up to date.
- **Option B**: cherry-pick just the missing pieces (`cli/`, `src/patch/`, `src/serde/ray.luau`, associated tests/docs) onto `origin/master` without pulling in anything else from `develop`, if `master` is meant to diverge from `develop` in other ways.

Ask the user which before doing anything. If Option A: `git checkout -b fix/master-parity origin/master`, merge `origin/develop` in, resolve conflicts, push, open PR — do **not** push directly to `master`.

## Phase 4 — Reset local `master` to match `origin/master`

Local `master`'s 35 unpushed commits (including the `.agents/` leak) have no unique value — the real work already reached `origin/master` via PR #33. Confirm with the user, then:

```bash
git checkout master
git reset --hard origin/master
```

This is destructive to local-only history; only do it after the user confirms nothing on local `master` is wanted (verified: it's a redundant/messy rebuild, not unique work). If the user wants to keep the `.agents/` files themselves (just not in this repo's history), copy them out first (`git show master:.agents/AGENTS.md > /tmp/...`) before resetting.

## Phase 5 — Delete fully-merged remote branches

All of these are confirmed merged into both `develop` and `master` with zero unique unpushed commits (verify via `git log origin/<branch>..<branch>` before deleting, in case time has passed and something changed):

```bash
for b in batch/1-extended-codec-coverage batch/1-fix-cli-encoding-label \
         batch/2-column-dictionary-encoding batch/2-fix-cli-stats-bug \
         batch/3-replace-dedup-scan batch/3-schema-evolution \
         batch/4-cli-tooling batch/5-incremental-delta-encoding \
         feature/remove-dedup-v3; do
  git push origin --delete "$b"
done
```

(`feature/remove-dedup-v3` is included here since it merged into `origin/master` via PR #33 already — it's fully closed, just needs the ref removed.)

## Phase 6 — Verify final state

```bash
git branch -a
```

Expect only `master`, `develop`, and their `origin/*` counterparts. Then:

```bash
git fetch --prune origin
pesde run test
```

Confirm the test suite is green on both `master` (post-Phase-3-fix) and `develop`.

## Notes for whoever executes this

- Do **not** force-push `develop` — Phase 1's merge should make a force-push unnecessary.
- Phase 3 is the one decision that actually changes `master`'s content; everything else is bookkeeping (deleting refs that are already redundant). Get explicit confirmation before it.
- This plan assumes no one else has pushed new commits to any of these branches since the investigation that produced it — re-run the `git log origin/X..X` checks per branch if significant time has passed.
