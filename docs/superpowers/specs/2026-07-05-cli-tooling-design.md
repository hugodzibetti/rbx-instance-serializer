# CLI Tooling — Design

## Context

Lattice has no way to inspect a `.lattice` (or raw format buffer) file outside
of writing a throwaway Luau script each time — which is exactly what this
session did repeatedly (`tests/_demo_*.luau` scratch files) to answer basic
questions like "how big is this" or "did dedup kick in." `CLAUDE.md` already
names the target commands: `lattice dump`, `lattice diff`, `lattice stats`.

Key architectural fact that shapes this design: `src/format/Reader.luau`
reads into `FormatData` (`stringTable`, `classBlocks`, per-column
`encoding`/`bitmask`/`values`) **before** the instance layer resolves
anything into actual Roblox `Instance` objects. Per `format-layer-design.md`'s
own design note: *"property names reference the string table, not the
artifact... The artifact is an optimization, not a requirement."* Class
*names*, however, only exist in the artifact (`classById[classId].name`) —
the format layer's `classId` is opaque without it (there used to be a "tag
table" concept mapping classId→name in the original format design doc, but
current `FormatData` has no such table — confirm this at implementation time,
see Open Decisions).

This matters because it means `dump`/`stats` can mostly avoid pulling in
`@lune/roblox` and reconstructing full instance trees (`src/instance/
Deserializer.luau`) — they can read `FormatData` directly, which is lighter
and works even for buffers whose class metadata is incomplete. `diff` needs
resolved instance identity to be meaningful (see below), so it's the one
command that goes through the full deserialize path.

## Goal

A `cli/` Lune-script-based tool (no new dependency — `@lune/process` is
already used in `scripts/RoundTrip.luau` for `process.args`/`process.exit`),
exposing three subcommands:

1. **`lattice stats <file>`** — total size, class breakdown (instance count,
   byte size, dominant encoding per column), dedup ratio if `templateRefs`
   present. Reads only `FormatData` + artifact (for class/property names).
2. **`lattice dump <file>`** — human-readable tree view: every class block,
   every column, encoding mode used, bitmask summary (N/instanceCount
   non-default). Same data source as `stats`, more verbose.
3. **`lattice diff <before> <after>`** — which properties changed between two
   files. Requires resolved instances (not just raw columns) because
   "did this Part change" needs instance identity across two independently
   serialized trees, which only exists after `templateRefs`/dedup and
   instance-graph reconstruction are resolved. See Open Decisions for the
   identity-matching problem this creates.

## Non-goals

- A compiled/standalone binary. This ships as Lune scripts invoked via
  `lune run cli/Main.luau -- <subcommand> <args>`, consistent with every
  other tool in this repo (`scripts/RunTests.luau`, `scripts/RoundTrip.luau`).
  If standalone-binary distribution is wanted later, Lune supports compiling
  scripts to executables — that's a packaging decision for a future spec, not
  this one.
- A TUI or interactive mode. Plain stdout, scriptable/pipeable output.
- Editing `.lattice` files. Read-only inspection tools only.

## Architecture

```
cli/
  Main.luau       -- arg parsing (process.args), subcommand dispatch
  Dump.luau        -- lattice dump implementation
  Stats.luau       -- lattice stats implementation
  Diff.luau        -- lattice diff implementation
  format.luau      -- shared helpers: human-readable byte sizes, table printing
```

Wire into `pesde.toml`'s `[scripts]` block, matching the existing pattern:

```toml
[scripts]
lattice = "cli/Main.luau"
```

Invoked as `pesde run lattice -- stats data/myfile.lattice` (the `--`
separator is required by pesde/lune's arg passthrough — confirm exact
invocation syntax against the `lune`/`pesde` versions pinned in `pesde.toml`
at implementation time).

### `stats` and `dump`: format-layer only

Both take a file path, `fs.readFile` + `buffer.fromstring`, load the artifact
(`data/artifact.bin`, same as every other script), call `Format.read(buf,
artifact)` (today's `src/format/Reader.luau`, or the versioned dispatch from
the Schema Evolution design if that's landed first — either way the call
signature `read(buf, artifact) -> FormatData` is stable).

`stats` output shape (example):
```
File: data/myfile.lattice
Format version: 1
Total size: 41,204 bytes
String table: 312 entries

Class          Instances  Bytes   Avg/inst  Dedup
Part           1,204      18,340  15.2      612 unique / 1,204 (49%)
UnionOperation  40         6,120  153.0     none
...
```

`dump` output shape (example, more granular — per-column):
```
ClassBlock #3: Part (1,204 instances, 612 unique via templateRefs)
  Anchored          encoding=RLE     1 run,  bitmask: 1204/1204 non-default
  Position          encoding=Raw     bitmask: 1204/1204 non-default
  Material          encoding=RLE     3 runs, bitmask: 890/1204 non-default
  ...
```

Per-column byte size (for both `stats`' "Bytes" column and `dump`'s
per-column detail) needs to be computed by re-running the same
`getValueSize`/RLE-run-cost math already implemented in
`src/instance/Serializer.luau`'s cost estimator — the `FormatData` structure
coming out of `Reader.read` has `values`/`bitmask` but not a stored "this
column was N bytes on the wire" figure. Either: (a) have `Reader.read`
optionally track consumed-byte-ranges per column (a debug/instrumentation
mode), or (b) recompute cost analytically from the decoded values using the
existing estimator functions. Recommend (b) — no changes needed to the core
Reader/Writer, and it's already exactly the code `Serializer.luau` uses to
pick encodings, so it's guaranteed consistent.

### `diff`: needs resolved instances, and an identity problem to solve

Unlike `stats`/`dump`, diffing "what changed" requires matching instances
between two files — but Lattice currently has **no stable instance identity**
across separate serialize calls. `globalIdMap` (`Serializer.luau:105-114`) is
recomputed per-serialize from traversal order, and `UniqueId` (codec 24) is
the closest thing to a stable identifier Roblox itself provides, but it's
only present on instances that have one assigned (not guaranteed).

Two options:
1. **Position-based matching** (same root order, same tree shape assumed):
   walk both deserialized trees in parallel by traversal order and diff
   structurally-matched instances. Breaks if instances were added/removed/
   reordered — flags this as a limitation, not silently wrong.
2. **UniqueId-based matching**: build a map from `UniqueId → instance` for
   both files where present, diff matched pairs, list unmatched-on-either-side
   as added/removed. Falls back to option 1 for classes/instances lacking a
   UniqueId.

Recommend **option 2 with option 1 fallback**, and print which strategy was
used per class block so `diff` output is honest about its own confidence
rather than silently guessing.

`diff` output shape (example):
```
data/before.lattice vs data/after.lattice

~ Part[uid:8f3a2b1c] Position: (0,5,0) -> (0,5,12)
~ Part[uid:8f3a2b1c] Transparency: 0 -> 0.5
+ Part[uid:9c1d4e20] (new instance, Anchored=true, Position=(10,0,0))
- Decal[uid:2b7f001a] (removed)

3 properties changed, 1 instance added, 1 instance removed
(342 instances matched by UniqueId, 12 matched by tree position — no UniqueId present)
```

## Testing

- `cli/` scripts are thin glue over already-tested library code
  (`Format.read`, `Lattice.deserialize`) — no new correctness surface to
  unit-test beyond arg parsing and output formatting.
- Add a small smoke test (could live as a `tests/_scratch`-style script, or
  a real spec if frktest can capture stdout — check existing patterns before
  deciding) that runs `stats`/`dump` against a known fixture and asserts no
  error and non-empty output.
- `diff`'s identity-matching logic (UniqueId map + fallback) is the one part
  with real logic worth unit-testing directly, independent of CLI plumbing —
  put that matching function in `cli/Diff.luau` as a pure function taking two
  `{any}` instance lists and returning matched/added/removed, so it can be
  tested without going through file I/O or arg parsing.

## Open decisions for the implementer

1. **Confirm class-name resolution path**: this doc assumes `artifact.
   classById[classId].name` is sufficient (per current `src/artifacts/
   types.luau`). If the "tag table" concept mentioned in the original
   `format-layer-design.md` doc was never actually implemented (current
   `FormatData`/`ClassBlock` have no such field — confirmed by reading
   `src/format/types.luau` in this session), `dump`/`stats` correctly depend
   on the artifact being available and matching the file's schema version;
   document that as a real requirement (no artifact = no class names), not
   a bug.
2. **Byte-size attribution** (option (b) above, recompute analytically) needs
   the cost-estimation logic from `Serializer.luau` extracted somewhere
   `cli/Stats.luau` and `cli/Dump.luau` can both call without duplicating it
   — consider moving `getValueSize`/`sizeRaw`/`sizeRle` (and `sizeDict`, if
   the Dictionary Encoding spec has landed) into a shared, non-`--!native`
   module both the serializer and the CLI import, rather than copy-pasting.
3. **`diff` matching strategy** is a judgment call under uncertainty (see
   above) — flag confidence in the output rather than presenting a
   single, possibly-wrong answer as fact.
