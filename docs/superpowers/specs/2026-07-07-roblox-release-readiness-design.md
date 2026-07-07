# Roblox Release Readiness Design

## Problem

Lattice is feature-complete on `develop`, but nothing has verified that the published output actually runs inside real Roblox (Studio or a live server/client) rather than just under Lune. Two categories of bugs currently make that untrue:

1. **`@lune/*` requires leak into shipped code.** `src/serde/*.luau` codecs, `src/instance/Serializer.luau`, `src/instance/Deserializer.luau`, and `src/patch/apply.luau` do `require("@lune/roblox")` (and `Serializer`/`Deserializer` also `require("@lune/task")`) to get `Color3`/`Vector3`/`Instance`/`Enum`/`task`, because Lune has no game engine underneath and needs an explicit binding for these. Real Roblox has no `@lune/*` require namespace at all — these are ambient globals there instead. Confirmed live in `dist/lattice/` today (27 files still reference `@lune`); `tests/studio-test.server.luau` (added by the new Rojo/Studio test setup) would fail immediately on `Lattice.Serde.vector3.write(...)`.
2. **Dev-only tooling ships in the package.** `scripts/BuildPackage.luau` runs darklua over all of `src/`, which sweeps in `src/artifacts/build/` (artifact-generation tooling: `@lune/process`, `@lune/fs`, `@lune/serde`) and `src/parallel/Worker.luau` (the superseded Lune-child-process parallel backend: `@lune/process`, `@lune/stdio`). Neither is library code; neither should be in `dist/lattice/`.

Additionally, `origin/master` is currently missing `cli/`, `src/patch/`, and `src/serde/ray.luau` relative to `develop` (an unintentional regression from PR #33, flagged in `docs/branch-cleanup-plan.md`). Releasing from `master` today would ship an incomplete package.

## Goals

- The exact same `src/` source continues to run correctly under Lune (`pesde run test`, CLI) with zero edits.
- The built package (`dist/lattice/`) loads and runs correctly inside real Roblox, verified concretely via the Rojo project + `tests/studio-test.server.luau` in Studio.
- The package is releasable via two channels: a manual/Rojo-syncable folder, and a `pesde publish`-able package.
- `master` is brought back in parity with `develop` before any release is cut from it.

## Non-goals

- No changes to parallel-encoding behavior — the Roblox Actor backend (`src/parallel/RobloxBackend.luau`) and its Lune-fallback path are already correct and out of scope here; this design only concerns build/packaging around them (excluding the now-superseded `Worker.luau`).
- No new CI/automation for cutting releases — this design covers making a release buildable and correct, not automating when/how often one is cut.

## Design

### 1. `@lune/roblox` and `@lune/task` shim via darklua, behind one named seam

The darklua rewrite (below) is invisible if it's scattered across 20+ raw `require("@lune/roblox")` call sites — nothing in `src/serde/color3.luau` would tell a reader that this require gets swapped at build time. Instead, confine it to two small, clearly-named modules that everything else depends on, grouped under `src/env/` rather than sitting loose at the top of `src/` (consistent with every other concern in `src/` being folder-per-topic):

```
src/
├── env/
│   ├── RobloxTypes.luau      -- the ONE file that says require("@lune/roblox")
│   └── LuneTask.luau          -- the ONE file that says require("@lune/task")
├── serde/
│   └── color3.luau            -- require("@src/env/RobloxTypes"), never "@lune/roblox" directly
└── instance/
    ├── Serializer.luau         -- require("@src/env/RobloxTypes"), require("@src/env/LuneTask")
    └── Deserializer.luau
```

`src/env/RobloxTypes.luau`:
```luau
-- Lune has no game engine, so it needs an explicit binding for Roblox datatypes;
-- real Roblox has these as ambient globals instead. Under Lune this just forwards
-- the real binding. For the Roblox build, darklua's @lune -> ./release-shims
-- source mapping (.darklua.json) rewrites the require below to release-shims/roblox.luau,
-- a table of the real engine globals — see that file for the swap.
return require("@lune/roblox")
```

`src/env/LuneTask.luau` follows the same pattern for `require("@lune/task")`.

Every codec and instance-layer file requires `@src/env/RobloxTypes` / `@src/env/LuneTask` like any other internal module — no build-magic string in sight. The magic itself still exists, but it now lives in exactly one place per binding, with a comment explaining it.

The darklua side, unchanged from the original proposal: `.darklua.json`'s existing `convert_require` rule already maps `@src` to a real directory (`sources: { "@src": "./src" }`); the same mechanism accepts another prefix:

```json
sources: { "@src": "./src", "@lune": "./release-shims" }
```

```
release-shims/            -- only exists for the darklua build; Lune never touches this; mirrors src/env/ 1:1 by filename
├── roblox.luau            -- return { Color3 = Color3, Vector3 = Vector3, Instance = Instance, Enum = Enum, ... }
└── task.luau              -- return task
```

`pesde run test` and the CLI are unaffected — Lune resolves `@lune/roblox`/`@lune/task` through its own builtin binding inside `src/env/RobloxTypes.luau`/`LuneTask.luau`, never through `.darklua.json`.

### 2. Dev-only tooling moves into the existing Lune-only homes (`scripts/`, `cli/`), not a new top-level folder

Relying on `scripts/BuildPackage.luau` to remember an exclude-list (`src/artifacts/build/`, `src/parallel/Worker.luau`) is tribal knowledge that silently breaks the moment someone adds a new Lune-only file under `src/` and forgets to exclude it. Instead, make "everything under `src/` ships to Roblox" a structural fact by relocating the two Lune-only trees into the two folders that already mean "Lune dev tooling, never ships" — `scripts/` and `cli/` — rather than inventing a third top-level category:

```
lattice/
├── src/                      -- everything here ships to Roblox, no exceptions, no exclude-list
├── scripts/
│   ├── artifacts/             -- moved from src/artifacts/build/; @lune/process, @lune/fs, @lune/serde stay raw (fine, never ships)
│   │   ├── Run.luau
│   │   └── buildArtifact.luau
│   └── BuildPackage.luau
├── cli/
│   └── parallel/
│       └── Worker.luau        -- moved from src/parallel/Worker.luau (superseded Lune-process backend), nested to mirror src/parallel/'s naming
```

`scripts/BuildPackage.luau` then simply runs `darklua process src dist/lattice` unmodified — no exclude-list to maintain, because there's nothing under `src/` left to exclude. `pesde.toml`'s script entries and any `@src/artifacts/build/...` / `@src/parallel/Worker` requires need updating to their new `scripts/artifacts/` / `cli/parallel/` locations.

### 3. Two release channels from one build

- **Manual / Rojo**: `dist/lattice/` as built above; already wired into `default.project.json` (`ReplicatedStorage.Lattice`). No further work needed once (1) and (2) land.
- **pesde publish**: pesde has no build/prepare hook — `pesde publish` packages whatever matches `includes` verbatim from the working directory. Raw `src/` (with `@src/...` / `@lune/...` requires) can't be published as-is. `BuildPackage.luau` additionally writes a minimal `pesde.toml` into `dist/lattice/` (name/version/license/description copied from the root manifest, `target = { environment = "roblox", lib = "init.luau" }`, `includes` covering the built files), and `pesde publish` is run with `dist/lattice/` as the working directory, not the repo root.

### 4. Master reconciliation

Before cutting any release from `master`: reconcile `develop` → `master` per `docs/branch-cleanup-plan.md` Phase 3, Option A (PR merging reconciled `develop` into `master`), so `master` regains `cli/`, `src/patch/`, and `src/serde/ray.luau`. This is a prerequisite, not part of the build-pipeline work itself.

### 5. Verification

Rebuild `dist/lattice/` with the above changes, sync via the existing Rojo project into a real Roblox Studio session, and confirm `tests/studio-test.server.luau` prints all three `✓` lines with no errors. This is the concrete pass/fail signal for the whole design — static analysis (grepping for `@lune` in `dist/`) is a useful intermediate check but Studio execution is what actually proves it.

## Testing

- Existing `pesde run test` suite must stay green (proves `src/` is untouched and still correct under Lune).
- New: a lightweight check (script or manual step) that `dist/lattice/` contains zero `@lune` references after build, catching future regressions if a new codec/module bypasses `src/env/RobloxTypes`/`LuneTask` and requires `@lune/*` directly.
- `tests/studio-test.server.luau` passing in actual Studio is the release-readiness acceptance criterion.
