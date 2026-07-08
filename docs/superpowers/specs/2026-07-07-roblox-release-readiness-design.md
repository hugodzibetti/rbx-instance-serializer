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

### 0. Validation spike (must pass before proceeding with the rest of this design)

Everything in section 1 — the nested `sources` mapping (`@src` → `./src` and `@lune` → `./src/env/shims`, one nested inside the other), `path`-mode parsing of `"@lune/roblox"` as package `@lune` + subpath `roblox`, and darklua's Roblox-target relative-require generation — is inferred from darklua's documentation, not verified against this repo. Before writing `RobloxTypes.luau`/`LuneTask.luau`/the shim files for real: build one throwaway codec-sized example (a single file requiring `@lune/roblox` via a `@src/env/...`-style indirection) with the proposed `.darklua.json` config, run `darklua process`, and inspect the actual output. If the nested-sources approach doesn't work as expected, fall back to a flat `@lune` → top-level `release-shims/` mapping (the earlier version of this design) rather than debugging darklua's path resolution mid-implementation.

### 1. `@lune/roblox` and `@lune/task` shim via darklua, behind one named seam

The darklua rewrite (below) is invisible if it's scattered across 20+ raw `require("@lune/roblox")` call sites — nothing in `src/serde/color3.luau` would tell a reader that this require gets swapped at build time. Instead, confine it to two small, clearly-named modules that everything else depends on, grouped under `src/env/` rather than sitting loose at the top of `src/` (consistent with every other concern in `src/` being folder-per-topic):

```
src/
├── env/
│   ├── RobloxTypes.luau      -- the ONE file that says require("@lune/roblox")
│   ├── LuneTask.luau          -- the ONE file that says require("@lune/task")
│   └── shims/                 -- darklua-only; Lune never touches this; lives right next to what it shims
│       ├── roblox.luau        -- return { Color3 = Color3, Vector3 = Vector3, Instance = Instance, Enum = Enum, ... }
│       └── task.luau          -- return task
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
-- the real binding. For the Roblox build, darklua's @lune -> ./src/env/shims
-- source mapping (.darklua.json) rewrites the require below to src/env/shims/roblox.luau,
-- a table of the real engine globals — see that file for the swap.
return require("@lune/roblox")
```

`src/env/LuneTask.luau` follows the same pattern for `require("@lune/task")`.

Every codec and instance-layer file requires `@src/env/RobloxTypes` / `@src/env/LuneTask` like any other internal module — no build-magic string in sight. The magic itself still exists, but it now lives in exactly one place per binding, with a comment explaining it.

This is a deliberate, narrow exception to CLAUDE.md's stated rule that "each codec is leaf: no dependencies on other codecs" — `RobloxTypes`/`LuneTask` are shared foundational dependencies in the same category `Writer`/`Reader` already are, not a codec-to-codec dependency. CLAUDE.md's "Key Design Decisions" section should be updated to say so explicitly once this lands, so it doesn't read as an unexplained rule violation later.

`src/env/shims/roblox.luau` is a hand-maintained list of engine globals (`Color3`, `Vector3`, `Instance`, `Enum`, ...). Nothing under `pesde run test` exercises it, since Lune always resolves the real `@lune/roblox` binding instead — a codec added later that reaches for a datatype missing from the shim table will pass every Lune test and CI check, and only fail at Studio load time. There's no automated check tying "fields the shim table exports" to "datatypes the codecs actually use"; the closest thing is the manual `tests/studio-test.server.luau` smoke test in section 5, which doesn't necessarily exercise every codec. Treat the shim table as something to re-check by hand whenever a new codec is added that touches a Roblox datatype not already in the list.

The darklua side, unchanged from the original proposal: `.darklua.json`'s existing `convert_require` rule already maps `@src` to a real directory (`sources: { "@src": "./src" }`); the same mechanism accepts another prefix, this time pointing at the nested `shims/` folder instead of a new top-level one:

```json
sources: { "@src": "./src", "@lune": "./src/env/shims" }
```

No separate copy step is needed to get the shims into the release build: `BuildPackage.luau` already runs `darklua process src dist/lattice` over all of `src/`, so `src/env/shims/` is carried into `dist/lattice/env/shims/` for free, landing exactly where the rewritten require expects it.

`pesde run test` and the CLI are unaffected — Lune resolves `@lune/roblox`/`@lune/task` through its own builtin binding inside `src/env/RobloxTypes.luau`/`LuneTask.luau`, never through `.darklua.json`; `src/env/shims/` sits unused (but harmless) under Lune since nothing there ever requires it directly.

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

This move has one non-obvious call site: `src/instance/Serializer.luau`'s Lune-process fallback path does `process.exec("lune", { "run", "src/parallel/Worker.luau" })` — a bare string literal, not a `@src/...` require, easy to miss when grepping for requires. It must be updated to `"cli/parallel/Worker.luau"` alongside the move, or the fallback (used for local Lune-only parallel testing, not the Roblox Actor path) silently breaks.

### 3. Two release channels from one build

- **Manual / Rojo**: `dist/lattice/` as built above; already wired into `default.project.json` (`ReplicatedStorage.Lattice`). No further work needed once (1) and (2) land.
- **pesde publish**: pesde has no build/prepare hook — `pesde publish` packages whatever matches `includes` verbatim from the working directory. Raw `src/` (with `@src/...` / `@lune/...` requires) can't be published as-is. `BuildPackage.luau` additionally writes a minimal `pesde.toml` into `dist/lattice/` (name/version/license/description copied from the root manifest, `target = { environment = "roblox", lib = "init.luau" }`, `includes` covering the built files), and `pesde publish` is run with `dist/lattice/` as the working directory, not the repo root.

### 4. Master reconciliation

Before cutting any release from `master`: reconcile `develop` → `master` per `docs/branch-cleanup-plan.md` Phase 3, Option A (PR merging reconciled `develop` into `master`), so `master` regains `cli/`, `src/patch/`, and `src/serde/ray.luau`. This is a prerequisite, not part of the build-pipeline work itself.

**Sequencing**: sections 1–2 (the `src/env/` restructuring and dev-tooling moves) land on `develop` first, as their own reviewable commits, before the master reconciliation PR — not bundled into it and not after it. This keeps the reconciliation PR to exactly what its name says (bringing master back in parity with develop's existing state) rather than mixing in a structural refactor, and means master picks up the release-readiness work automatically once it's reconciled.

### 5. Verification

Rebuild `dist/lattice/` with the above changes, sync via the existing Rojo project into a real Roblox Studio session, and confirm `tests/studio-test.server.luau` prints all three `✓` lines with no errors. This is the concrete pass/fail signal for the whole design — static analysis (grepping for `@lune` in `dist/`) is a useful intermediate check but Studio execution is what actually proves it.

## Testing

- Existing `pesde run test` suite must stay green (proves `src/` is untouched and still correct under Lune).
- New: a lightweight check (script or manual step) that `dist/lattice/` contains zero `@lune` references after build, catching future regressions if a new codec/module bypasses `src/env/RobloxTypes`/`LuneTask` and requires `@lune/*` directly.
- `tests/studio-test.server.luau` passing in actual Studio is the release-readiness acceptance criterion.
