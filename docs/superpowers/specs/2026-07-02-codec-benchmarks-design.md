# Codec Benchmarks — Design

## Context

Lattice's non-negotiables include **speed**. Right now there is no way to measure
it: `src/serde/` has 26+ leaf codecs and round-trip correctness tests, but no
performance signal. The instance/artifact layer (`src/artifacts/`, `src/instance/`)
described in CLAUDE.md's "Next Steps" doesn't exist yet, so a full end-to-end
serialize-a-place benchmark isn't possible today. This design adds a benchmark
harness that measures the codecs that *do* exist now, structured so it extends
cleanly once the instance layer lands.

## Goal

A clean, organized `bench/` suite that:
1. Sources realistic property values from a large, complex Roblox instance tree
   (not hand-picked trivial values).
2. Reports per-codec write/read throughput and encoded size.
3. Is trivial to extend as new codecs (and eventually instance-level
   serialization) are added.

## Non-goals

- Downloading real `.rbxm` assets from the Roblox marketplace. Attempted this;
  `assetdelivery.roblox.com` returns `401 Unauthorized` for all modern
  marketplace assets without an authenticated session. Using scraped/shared
  credentials to bypass this is out of scope. Instead, a synthetic model
  generated via `@lune/roblox` stands in for "a large, complex Roblox model."
- Benchmarking the artifact/instance/compat layers — they don't exist yet.
- CI wiring or regression-gating on benchmark numbers — this is a manual,
  on-demand tool for now (`lune run bench/Run.luau`), not part of `pesde run test`.

## Architecture

```
bench/
  fixtures/
    Generate.luau      -- builds bench/fixtures/large.rbxm (gitignored)
  Fixtures.luau         -- loads large.rbxm, buckets real property values by codec
  Timer.luau            -- iteration/timing utility, no codec knowledge
  Run.luau              -- orchestrates: for each codec, time write + read
  Report.luau           -- formats results into an aligned console table
```

### 1. Fixture generation — `bench/fixtures/Generate.luau`

Uses `@lune/roblox` (same binding the test suite already uses) to procedurally
build one large, deeply-nested `Instance` tree: thousands of instances across
varied classes (`Part`, `Model`, `Folder`, `Attachment`, `ParticleEmitter`,
`Frame`/`TextLabel` for UI properties, etc.), with properties spanning every
type the current codecs cover. Saves the tree to `bench/fixtures/large.rbxm`
via `game:GetService("DataModel")`-style save API exposed by `@lune/roblox`.

- `bench/fixtures/large.rbxm` is **gitignored**. It's regenerated on demand:
  `lune run bench/fixtures/Generate.luau`.
- Deterministic seed (fixed `Random.new(seed)`) so repeated generations are
  reproducible and diffable in spirit, even though the binary itself isn't
  committed.
- Target scale: on the order of 10k+ instances, deep enough nesting (10+
  levels) to be a meaningfully "large, complex" tree, not a flat list.

### 2. Sampling — `bench/Fixtures.luau`

Loads `large.rbxm` once, walks it with `GetDescendants`, and buckets real
property values into per-codec sample arrays, e.g.:

| Codec | Sampled from |
|---|---|
| `cframe` | every `BasePart.CFrame` |
| `vector3` | `BasePart.Size` |
| `color3` | `BasePart.Color` |
| `f32` | `BasePart.Transparency` |
| `bool` | `BasePart.Anchored` |
| `enumItem` | `BasePart.Material` |
| `brickColor` | `BasePart.BrickColor` |
| `string` | `Instance.Name` |
| `udim2` | `Frame.Size` (UI instances) |
| `numberSequence` / `colorSequence` / `numberRange` | `ParticleEmitter.Transparency` / `.Color` / `.Lifetime` |
| `physicalProperties` | `BasePart.CustomPhysicalProperties` |
| `font` | `TextLabel.FontFace` |
| `uniqueId` | `Instance.UniqueId` |

A handful of codecs have no common single-instance property to sample from
(`faces`, `axes` — rare struct types; `array`, `option` — generic combinators).
For these, `bench/Fixtures.luau` synthesizes representative values directly,
following the same inline-dummy-data convention the existing specs
(`SerdeFacesAxes.spec.luau`, `SerdeArray.spec.luau`, `SerdeOption.spec.luau`)
already use. These are clearly separated in the file (a `synthetic` section)
so it's obvious which codecs get real vs. synthetic samples.

Output shape: `{ [codecName]: { codec: Codec<T>, samples: {T} } }`.

### 3. Timing core — `bench/Timer.luau`

A small, codec-agnostic utility:

```luau
export type Result = { iterations: number, seconds: number, opsPerSecond: number }
local function run(iterations: number, fn: () -> ()): Result
```

Uses `os.clock()`. No dependency on Writer/Reader/codecs — reusable later for
instance-level or format-level benchmarks.

### 4. Runner — `bench/Run.luau`

For each entry from `bench/Fixtures.luau`:
1. Benchmark **write**: for each sample, `codec.write(writer, sample)` into a
   fresh growable `Writer`, repeated across all samples, timed via
   `bench/Timer.luau`. Record total encoded bytes.
2. Benchmark **read**: using the bytes produced above, `codec.read(reader)`
   for each value, timed the same way.
3. Collect `{ name, writeOpsPerSecond, readOpsPerSecond, totalBytes, avgBytesPerValue }`.

Entries are a plain array of `{ name: string, codec: Codec<any>, samples: {any} }`
— adding a new codec to the benchmark is a one-line addition to
`bench/Fixtures.luau`'s table, no changes to `Run.luau` needed.

If `bench/fixtures/large.rbxm` is missing, `Run.luau` fails fast with a clear
message: `"bench/fixtures/large.rbxm not found — run: lune run bench/fixtures/Generate.luau"`.

### 5. Reporting — `bench/Report.luau`

Pure formatting function: takes the result array from `Run.luau`, prints an
aligned console table:

```
codec              write ops/s    read ops/s   avg bytes   total bytes
cframe                  1.2M          980K            13        124,800
vector3                 3.4M          3.1M             6         57,600
...
```

Kept separate from `Run.luau` so the table format can change without touching
orchestration logic.

### Invocation

```bash
lune run bench/fixtures/Generate.luau   # once, or whenever fixture needs regenerating
lune run bench/Run.luau                 # runs benchmarks, prints table
```

Mirrors the existing `lune run scripts/RunTests.luau` pattern.

## Testing

Benchmarks are not correctness tests (those already exist as round-trip specs
in `tests/`). No new test specs are added for `bench/` itself; `Generate.luau`
and `Fixtures.luau` are exercised implicitly by running the benchmark. If a
sampling bug produces empty sample arrays for a codec, `Run.luau` should
surface that clearly (zero samples → explicit warning row, not a silent skip).

## Open questions resolved during brainstorming

- **Real vs. synthetic data**: real `.rbxm` downloads are blocked by Roblox
  auth; using a deterministic synthetic tree via `@lune/roblox` instead.
- **Scope**: codec-level only, since the instance/artifact layer isn't built.
- **Metrics**: throughput (ops/sec) + size, not just raw timing.
- **Location**: top-level `bench/`, mirroring `src/serde/`'s flat-module style.
- **Fixture composition**: one large tree with realistic nesting, not tiered
  small/medium/large variants (may be revisited later if scaling curves become
  interesting).
