# Schema Evolution Tests — Design

## Context

`CLAUDE.md` lists "Schema Evolution Tests" as if the compat system just needs
test coverage added. Reading the actual read path shows the real gap is one
layer deeper: **the compat system is never called**.

- `src/compat/init.luau` implements `migrate(registry, data, fromVersion)`,
  correctly, with its own solid unit tests (`tests/Compat.spec.luau`) — but
  those tests only exercise `migrate` against synthetic mock registries and
  plain tables (`{ foo = "bar" }`). They never touch real `FormatData` or a
  real serialized buffer.
- `src/format/Reader.luau:34` does this and nothing else with the version
  field: `assert(version == 1, "Unsupported format version: " .. tostring(version))`.
  There is no dispatch, no migration call, nothing. A version-2 file, if one
  existed, would fail to load with a hard error — not a migration attempt.
- `src/format/Writer.luau` only ever writes `version = 1` (from
  `FormatData.version`, itself always constructed as `1` in
  `src/instance/Serializer.luau:339`). The project has never produced a
  version-2 file, so this gap has never been exercised even accidentally.

So "add tests" would currently be testing nothing real — there is no code
path that reads an old-version file and migrates it, because that code path
doesn't exist yet. This spec is really "wire compat into the real read path,
using an already-flagged real future change as the concrete first version
bump, then test that."

### The concrete version-2 candidate already sitting in the code

`src/format/Writer.luau:69` has a ponytail marker on the exact thing that will
force the first real version bump:

```
-- ponytail: templateRefs stored as raw varints, upgrade: RLE if profiling shows it matters
```

Today, `templateRefs` (whole-instance dedup references) are written as one
raw varint per instance regardless of how many duplicates exist. Switching
that to RLE (same run-length technique already used for property columns) is
a real, likely-to-happen optimization — and it changes the **byte layout**,
not just semantics, which makes it the right vehicle for this design: a
synthetic "add an unused field" version bump would prove nothing real.

## Goal

1. Establish the actual pattern for versioned reading: `Reader.read` dispatches
   on the version field to a per-version decode function, each of which
   produces today's `FormatData` Luau shape. Old versions are read by
   version-frozen code; only the current version is ever written.
2. Clarify the division of labor between this per-version dispatch and
   `src/compat/`'s `migrate` function (see Architecture below) — this is the
   part most likely to be built wrong if left ambiguous.
3. Implement the templateRefs-as-RLE change as format version 2, using the
   new machinery, as the first real (not synthetic) proof that old files
   still load correctly after a wire-format change.
4. Add integration tests that serialize-as-v1 (frozen snapshot), then read
   with current code and assert correct migration — not just unit tests of
   `compat.migrate` against mock data.

## Non-goals

- Migrating the **artifact** schema (`src/artifacts/`) — artifacts are
  rebuilt from a fresh API dump each time, not migrated forward; they carry
  their own `version` field already but nothing in this spec touches that.
- Automatic migration of on-disk files as a CLI operation (that's a natural
  fit for the CLI tooling spec's `lattice` command, once both exist — not
  required here).
- Building version 3, 4, etc. This spec only needs to prove the machinery
  with one real version bump (v1 → v2).

## Architecture

### Division of labor: versioned readers vs. `compat.migrate`

This is the one decision that matters most here, because the two mechanisms
look like they overlap but don't:

- **Per-version binary readers** (new, in `src/format/Reader.luau`) own
  **byte layout**. If version 2 changes how many bytes something takes or in
  what order fields appear, that can only be handled by a reader that knows
  the old layout — a generic "transform this table" function can't recover
  information from a byte stream it doesn't know how to walk. Each version's
  reader is frozen forever once shipped; only ever add new ones, never edit
  old ones.
- **`compat.migrate`** (existing, in `src/compat/`) owns **semantic
  transformation of already-parsed data** — e.g., if a future version adds a
  new optional field that should default to some computed value rather than
  a static default, or renames/restructures something at the `FormatData`
  level after byte-parsing is already done. It operates on plain tables, by
  design, and that's the right level for "shape" changes that don't require
  re-deriving anything from bytes.

Concretely: `Reader.read` becomes:

```luau
local function read(buf: buffer, artifact: ArtifactData): FormatData
    local r = BufferReader.new(buf)
    -- magic check unchanged
    local version = r:u16()

    local raw: FormatData
    if version == 1 then
        raw = readV1Body(r, artifact)   -- today's body, frozen as-is
    elseif version == 2 then
        raw = readV2Body(r, artifact)   -- templateRefs-as-RLE layout
    else
        error("Unsupported format version: " .. tostring(version))
    end

    return compat.migrate(compat.defaultRegistry, raw, version) :: FormatData
end
```

For the v1→v2 templateRefs change specifically, `compat.migrate` is actually
a no-op pass-through here (the byte-layout difference is fully resolved by
`readV1Body` vs `readV2Body` each producing the *same* final `templateRefs:
{number}` array shape — RLE-vs-raw is purely a wire-encoding detail, invisible
above the reader). This is expected and fine: it demonstrates that not every
version bump needs a real `compat.migrate` step, and the registry entry for
`migrations[1]` can legitimately be `function(data) return data end` when a
version bump is pure wire-format, not shape.  A future version bump that
*does* change `FormatData`'s shape (e.g. a new required field) is what would
give `migrations[1]` real work to do.

### Splitting `Reader.luau`

- `src/format/Reader.luau`: keep as the public entry point; add the version
  dispatch shown above.
- `src/format/readers/V1.luau` (new): today's entire body (lines ~36-157),
  moved verbatim, frozen.
- `src/format/readers/V2.luau` (new): copy of V1 with the `templateRefs`
  read loop changed from raw-varint-per-instance to RLE decode (mirroring the
  RLE decode already written for property columns at `Reader.luau:121-131`).
- `src/format/Writer.luau`: bump the version constant it writes from `1` to
  `2`, and change the `templateRefs` write loop (`Writer.luau:67-79`) to RLE
  (mirroring the existing RLE encode for columns at `Writer.luau:133-140`).
  Writer only ever writes current-version output — no writer-side version
  dispatch needed.

### `src/compat/init.luau`

No signature changes needed. Register the (no-op, per above) v1→v2 step:

```luau
local defaultRegistry: CompatRegistry = {
    currentVersion = 2,
    migrations = {
        [1] = function(data) return data end,
    },
}
```

## Testing

1. **Frozen v1 fixture**: capture a real serialized buffer produced by
   today's code (before this change lands) and commit it as a binary test
   fixture (e.g. `tests/fixtures/format_v1_sample.bin`) — generate it with a
   small script once, check in the bytes, never regenerate. This is the only
   way to prove old files still load after the format changes out from
   under them.
2. **New test file** `tests/SchemaEvolution.spec.luau`:
   - Load the frozen v1 fixture through the new `Reader.read` and assert the
     resulting `FormatData` matches expected values (round-trips the same
     instances the fixture was built from).
   - Serialize a fresh instance tree with the current (v2) writer, confirm
     the header reports version 2, and confirm it reads back correctly.
   - Assert that a buffer claiming an unknown version (e.g. hand-crafted
     header with version `99`) errors clearly rather than silently
     misreading.
3. Extend `tests/Compat.spec.luau`'s existing suite with one case that uses
   `compat.defaultRegistry` (not a mock) and asserts `migrate` on real
   `FormatData`-shaped input reaches `currentVersion` cleanly — bridges the
   existing unit tests to the real registry.
4. Regenerate `bench/RunPipeline.luau` numbers after the templateRefs RLE
   change — this is expected to shrink the dedup-heavy fixture, since the
   RLE change directly addresses the "raw varints" ponytail-tagged
   inefficiency. Not a correctness test, but worth capturing in the PR.

## Open decisions for the implementer

1. Confirm no in-flight branch is simultaneously changing `templateRefs`
   layout for other reasons (e.g. if the Dictionary Encoding spec's dedup
   removal lands first, `templateRefs` may no longer exist at all — in that
   case, pick a different, still-real version-2 driver, or simply skip the
   RLE optimization and use whatever the next genuine wire-format change is
   at merge time). The point of this spec is "wire up real migration
   machinery using a real change," not "the templateRefs RLE change
   specifically" — substitute freely if circumstances changed.
2. Decide where frozen binary fixtures live and how they're regenerated
   (this spec proposes `tests/fixtures/`, generated once by a throwaway
   script, never regenerated in place — confirm this matches how other
   fixtures in the repo are handled, e.g. `bench/fixtures/`).
