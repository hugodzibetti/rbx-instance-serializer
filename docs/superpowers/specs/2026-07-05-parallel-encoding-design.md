# Parallel Encoding (Multi-Process, Lune Prototype) — Design

## Context

Lattice's columnar format (`src/format/types.luau`) already groups instances by class into
independent `ClassBlock`s. Under Lune, there is no in-process thread or shared-memory
parallelism primitive available to Luau scripts — `task.desynchronize`/parallel Luau is a
Roblox-engine-only feature, not exposed by the standalone Lune runtime this project runs
under (`pesde.toml`: `engines.lune = "0.10.4"`). Real parallelism under Lune means separate
OS processes (`@lune/process`), communicating over stdin/stdout.

The goal here is to prove out a per-class-block parallel split using real Lune child
processes, in a shape that ports directly to Roblox Actors later: the same "pure data,
no Instance handles" stage that runs in a worker process now is what would run inside
`task.desynchronize` on an Actor in the future.

## Goal

1. Parallelize class-block **encoding** (serialize) and **decoding** (deserialize) across
   Lune child processes, one class block's work per worker.
2. Keep all `Instance`-touching work (property reads, `Instance.new`, property writes)
   sequential in the parent process — workers never see live Roblox instances.
3. Produce byte-identical `.lattice` output to today's sequential path (this is an
   execution-strategy change, not a format-semantics change, aside from the length-prefix
   addition below).
4. Bump format to **schema v4**: add a `varint` byte-length prefix per class block, so a
   block's byte range can be sliced without parsing it — required for parallel *read*,
   and useful in its own right (e.g. `cli/Diff.luau` could skip blocks it doesn't need).

## Non-goals

- Worker pool bounding/reuse. MVP spawns one child process per class block. Fine for the
  current bench fixtures (tens of classes, not hundreds); pooling is a follow-up if a
  scene has enough distinct classes for process-spawn overhead to dominate.
- Batch-file-level parallelism (parallelizing across independent roots/files). The
  per-class-block split is approved as the first case; file-level parallelism can reuse
  the same worker-spawn machinery later as a thin wrapper, not designed here.
- Any actual Roblox Actor / parallel Luau code. This design only proves the split is
  correct and maps cleanly onto that future port — it does not implement it.
- Compression, chunked/streaming IPC, or anything beyond a single request/response per
  worker.

## Architecture: three stages

1. **Stage A — sequential, parent only.** Everything that touches a live `Instance`:
   `collectAll`, class bucketing, global-id assignment, and
   `PropertyCompare.computeSerializedValue` (today's serialize Pass A) for serialize;
   `Instance.new` + property assignment for deserialize. Unchanged from today's code.
2. **Stage B — parallel, pure data.** For serialize: given a class's extracted values,
   decide encoding (raw / RLE / Dictionary / AllDefault / AllNonDefault) and write the
   class block's bytes. For deserialize: given a class block's raw bytes, parse it back
   into typed columns. No `Instance` handles required — Roblox datatypes (`Vector3`,
   `CFrame`, etc.) construct and compare fine via `@lune/roblox` with no live scene, so
   codecs (`src/serde/*.luau`) work unmodified inside a worker process.
3. **Stage C — sequential, parent only.** Stitch Stage B's per-class byte segments into
   the final buffer in `classId` order (serialize), or construct real `Instance`s from
   Stage B's decoded columns (deserialize).

Stage B is the only stage that moves to a worker process now, and the only stage that
would move to a Roblox Actor later — same boundary, different transport.

## Format change: v4 length-prefixed class blocks

`Writer.luau` currently writes class blocks back-to-back with no size header
(`Writer.luau:61-141`), so locating block N requires fully parsing blocks `1..N-1`.
Parallel deserialize needs to slice a block's bytes without parsing it first.

Fix: write a `varint` byte length immediately before each class block's contents.
Handled the same way as prior version bumps: `src/format/readers/V4.luau` is a frozen
reader for the new layout, `src/format/Reader.luau` dispatches on the version field, and
`compat.migrate` carries v1/v2/v3 files forward. `Writer.luau` only ever writes v4 going
forward, matching the existing "Writer only writes current version" convention.

## Worker protocol

### Serialize

1. Parent runs Stage A as today, producing `serializedByProp`/`isDefaultByProp` per class.
2. Parent precomputes the **full string table** by walking `classNames × propsWithCodec`
   once, before spawning any worker. (Today this happens lazily via `getStringIndex`
   during encoding — safe to hoist because the string table only ever holds *property
   names*, which are static per class in the artifact; it never holds property *values*.)
3. Parent extracts, from `src/instance/Serializer.luau:137–245`, the encoding-choice logic
   (raw vs RLE vs Dictionary vs AllDefault vs AllNonDefault, cost-estimated via
   `CostEstimator`) into a standalone module: `src/instance/ColumnEncoder.luau`. Pure
   function: `(codec, values, isDefaults, effectiveCount) -> PropertyColumn`. No behavior
   change — straight extraction so both the sequential path and the worker can call it.
4. Parent extracts the per-class-block byte-writing logic from `Writer.luau:62–141` into
   `writeClassBlock(w: Writer, cb: ClassBlock, artifact: ArtifactData)`, reusable by both
   the sequential writer (loops over all blocks) and a worker (writes exactly one).
5. Parent spawns one child process per class block:
   `process.create("lune", {"run", "src/parallel/Worker.luau"})`, and writes a
   self-contained payload to its stdin:
   - `classId`, `instanceCount` (varint)
   - per column: `propertyNameIndex`, `codecId` (varint), packed bitmask, then each
     non-default value written via `codec.write` — i.e. today's "raw" column encoding,
     used here purely as a transport format, not as the final on-disk choice.
6. Worker (`src/parallel/Worker.luau`) reads stdin to end, decodes each column's values
   via `codec.read` (looked up by `codecId` in `src/serde/init.luau` — **no artifact
   needed in the worker**, keeping the payload minimal), runs `ColumnEncoder` per column,
   writes the finished class block via `writeClassBlock` (now length-prefixed per v4),
   and writes the resulting bytes to stdout.
7. Parent reads each child's stdout to end, checks exit status, and concatenates the
   per-class byte segments after the header + string table, in `classId` order.

### Deserialize

Mirrors serialize: parent slices each class block's byte range using the v4 length
prefixes (no full parse needed), ships each slice to a worker, worker parses it into
typed columns and returns them, parent (Stage C) constructs `Instance`s from the decoded
columns sequentially, exactly as `src/instance/Deserializer.luau` does today.

## Error handling

If a worker exits non-zero, or writes to `stderr`, the parent aborts the entire
serialize/deserialize call with an error identifying which class failed
(`"parallel encode failed for class <ClassName>: <stderr>"`). No silent partial output —
a failed class block fails the whole operation, matching the project's existing
fail-loud conventions (e.g. `assert` on missing codec/metadata in `Writer.luau`).

## Testing

- `tests/ColumnEncoder.spec.luau` — unit tests for the extracted pure encoding-choice
  function, no process spawn involved (mirrors existing codec round-trip test style).
- `tests/ParallelIntegration.spec.luau` — round-trips a multi-class scene through the
  real worker-process path and asserts the output buffer is **byte-identical** to the
  existing sequential `Serializer.serialize` / `Deserializer.deserialize` path on the
  same input. This is the correctness bar: parallel execution must be a pure
  execution-strategy change, not a semantics change.
- Existing `tests/Format.spec.luau` gets a v4 round-trip case alongside the existing
  v1/v2/v3 migration cases.

## Rollout

This is additive: the sequential path stays as the default; parallel serialize/
deserialize are new entry points (e.g. `Serializer.serializeParallel`,
`Deserializer.deserializeParallel`) that existing callers don't have to adopt. Once
correctness and a real speedup are demonstrated on `bench/results/large-scene.lattice`,
follow-up work (not in this design) can consider making parallel the default and/or
porting Stage B to a Roblox Actor.
