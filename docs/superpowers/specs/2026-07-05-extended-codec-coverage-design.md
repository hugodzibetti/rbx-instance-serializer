# Extended Codec Coverage — Design

## Context

`CLAUDE.md`'s "Current Work" section guessed the codec gap as "~20 missing
types" (Ray, Region3, FloatCurveKey, TweenInfo, Variant, CatalogSearchParams).
That guess was never checked against the real Roblox API dump already
vendored at `data/api-dump.json`. It was wrong.

Running the actual artifact build (`lune run src/artifacts/build/Run.luau`)
and collecting its `WARNING: ... — no codec, skipping` lines
(`src/artifacts/build/buildArtifact.luau:218`) against the real dump gives the
true, complete list of unresolved property value types:

| Type | Warning count | Where it appears |
|---|---|---|
| `SecurityCapabilities` | 866 | `Capabilities` property, inherited by **every** class (base `Instance` property, Category "Permissions") |
| `ContentId` | 86 | Legacy icon/texture id properties across ~66 distinct (class, property) pairs (e.g. `ScrollingFrame.TopImage`, `Sky.MoonTextureId`) |
| `QDir` | 5 | `Studio.*` only (editor preference paths — not place-file content) |
| `Ray` | 4 | `Mouse`/`PlayerMouse`/`PluginMouse.UnitRay` (runtime services, not serializable) + `RayValue.Value` (real, serializable) |
| `QFont` | 3 | `Studio.*` only |
| `ProtectedString` | 3 | `Script.Source`, `LocalScript.Source`, `ModuleScript.Source` |
| `DateTime` | 3 | `Capture`/`ScreenshotCapture`/`VideoCapture.CaptureTime` |
| `AuroraScript` | 1 | `AuroraScriptObject.BehaviorWeak` (obscure internal) |

None of Region3, FloatCurveKey, TweenInfo, Variant, or CatalogSearchParams
appear as an unresolved (or any) property value type in the dump — they're
either not serializable Instance properties at all (TweenInfo/Region3 are
almost always method parameters, not properties) or don't exist in this API
dump revision. **Drop them from scope entirely** rather than build codecs for
types that don't occur.

### The one blocker: SecurityCapabilities can't be fixed here

`SecurityCapabilities` is 89% of the gap by count, but verified directly
against Lune (`roblox.Instance.new("Part").Capabilities`):

```
Failed to convert from 'SecurityCapabilities' into 'userdata' - Type not supported
```

Lune's `roblox` binding cannot surface this value to Luau at all — this is an
upstream Lune limitation, not a missing codec. **No amount of work in this
repo fixes it.** Writing a codec would be dead code with nothing to feed it.
Scope: document this as a known limitation (in this file and in
`CLAUDE.md`'s Implementation Notes), and optionally file an issue against
Lune. Do not attempt a codec.

### What's actually left to build

After removing SecurityCapabilities (blocked) and QDir/QFont/AuroraScript
(Studio-editor-only or single-occurrence internal, never present in a real
place file's serializable content), the real scope is 3 items:

1. **`ProtectedString` → alias to existing `string` codec.** Verified via
   Lune: `Script.new().Source` reads/writes as a plain Lua string
   (`typeof(s.Source) == "string"`). This is the single highest real-world
   value item in this list — it's how actual game code gets serialized —
   despite the lowest warning count. Zero new codec code: one entry in
   `resolveType.luau`'s `LEAF_MAP`.
2. **`ContentId` → alias to existing `string` codec.** Verified via Lune:
   `ScrollingFrame.new().TopImage` reads/writes as a plain string
   (`rbxassetid://...` form). Same fix: one `LEAF_MAP` entry. Covers 86
   properties in one line.
3. **`Ray` → new codec.** Verified via Lune: `RayValue.new().Value` is a real
   `Ray` userdata (`Origin: Vector3`, `Direction: Vector3`). `Mouse`/
   `PlayerMouse`/`PluginMouse.UnitRay` are on runtime-only service singletons
   that are never part of a serialized instance tree, so the only real
   target is `RayValue.Value` — still worth a codec since `RayValue` is a
   legitimate value-object instance users can place in a tree.

`DateTime` (3 occurrences, Capture-related) is optional/stretch — low value,
simple to add if time allows, skip without concern if not.

## Goal

1. Add `ProtectedString = 3` and `ContentId = 3` to `LEAF_MAP` in
   `src/artifacts/build/resolveType.luau` (both alias to the existing string
   codec id).
2. Add a new `src/serde/ray.luau` codec (12 bytes: 2×Vector3, same pattern as
   `rect.luau`/`udim2.luau` — two compound sub-values written field-by-field).
3. Register it in `src/serde/init.luau` (`codecIdToModule[27] = ray`,
   `codecNameToId.ray = 27` — next free id; `26` is `referent`) and in
   `resolveType.luau`'s `LEAF_MAP` (`Ray = 27`).
4. Rebuild the artifact (`pesde run artifact`) and confirm the warning count
   drops from 971 to ~10 (only `QDir`/`QFont`/`AuroraScript`/`DateTime`/
   `SecurityCapabilities` remain, all explicitly out of scope).
5. Document the `SecurityCapabilities` limitation in `CLAUDE.md`'s
   Implementation Notes.

## Non-goals

- `SecurityCapabilities` (blocked upstream, see above).
- `QDir`, `QFont`, `AuroraScript` (Studio-editor-only or single-occurrence
  internal — never appear in a place file worth serializing).
- `DateTime` (optional stretch, not required for this spec to be "done").
- Any type not present in the real `data/api-dump.json` (Region3,
  FloatCurveKey, TweenInfo, Variant, CatalogSearchParams) — if a future API
  dump revision introduces properties using these, re-run the same
  measurement process (`lune run src/artifacts/build/Run.luau 2>&1 | grep
  WARNING`) rather than guessing.

## Architecture

```
src/serde/ray.luau          -- new: Codec<Ray>, mirrors rect.luau's shape
src/serde/init.luau         -- register ray at id 27
src/artifacts/build/resolveType.luau  -- LEAF_MAP: +ProtectedString=3, +ContentId=3, +Ray=27
```

### `src/serde/ray.luau`

```luau
--!strict
--!native
--!optimize 2

local roblox = require("@lune/roblox")
local types = require("@src/types")

export type Ray = typeof(roblox.Ray.new(roblox.Vector3.new(0, 0, 0), roblox.Vector3.new(0, 0, 0)))

local ray = {} :: types.Codec<Ray>

function ray.write(writer, value: Ray)
	writer:f32(value.Origin.X)
	writer:f32(value.Origin.Y)
	writer:f32(value.Origin.Z)
	writer:f32(value.Direction.X)
	writer:f32(value.Direction.Y)
	writer:f32(value.Direction.Z)
end

function ray.read(reader): Ray
	local ox, oy, oz = reader:f32(), reader:f32(), reader:f32()
	local dx, dy, dz = reader:f32(), reader:f32(), reader:f32()
	return roblox.Ray.new(roblox.Vector3.new(ox, oy, oz), roblox.Vector3.new(dx, dy, dz))
end

return ray
```

(Confirm exact `roblox.Ray.new` signature against the Lune version pinned in
`pesde.toml` — `engines.lune = "0.10.4"` — before implementing; verified
`typeof(rayValue.Value) == "Ray"` in this session but did not enumerate the
constructor signature.)

## Testing

- New `tests/SerdeRay.spec.luau` (follow the pattern in `tests/SerdeUDim.spec.luau`
  or `tests/SerdeVector.spec.luau`): round-trip a handful of Ray values
  including zero-vector origin/direction and negative components.
- Extend whichever test currently exercises `resolveType`/artifact build (if
  one exists — check `tests/Artifact.spec.luau`) to assert `ProtectedString`
  and `ContentId` resolve to the string codec id.
- Manual verification step (not an automated test, but call out in the PR):
  re-run `lune run src/artifacts/build/Run.luau 2>&1 | grep WARNING | wc -l`
  before/after and paste the count delta in the PR description — this is the
  actual acceptance criterion for "coverage improved."
- Wire the new codec into `bench/Fixtures.luau` alongside the others (per the
  existing convention noted in `docs/examples/end-to-end.md`'s benchmarking
  section).

## Open decisions for the implementer

1. Confirm `roblox.Ray.new(origin, direction)` is the correct Lune
   constructor signature (this doc assumes it based on Roblox's own `Ray.new`
   API; verify against Lune 0.10.4's actual binding before writing the codec).
2. Decide whether `DateTime` is worth doing in the same PR (optional,
   3 occurrences, all on capture-metadata classes) or deferred indefinitely.
   Recommendation: skip unless it's essentially free once Ray is done.
