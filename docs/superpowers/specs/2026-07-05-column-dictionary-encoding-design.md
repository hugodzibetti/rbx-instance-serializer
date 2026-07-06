# Column Dictionary Encoding — Design

## Context

Lattice's format layer (`src/format/`) already encodes each property column
independently, picking the cheapest of 4 modes per column: `raw` (0), `RLE` (1),
`AllDefault` (3), `AllNonDefault` (4). Separately, the instance layer
(`src/instance/Serializer.luau`) does **whole-instance template dedup**: an
O(n²) scan per class bucket that collapses byte-identical instances into a
single template + a `templateRefs` varint array (one varint per instance,
"ponytail"-tagged in `Writer.luau:69` as unoptimized).

A live question came up: does dedup cover instances that are *similar but not
identical* (e.g. 100 Parts sharing Anchored/Size/Material but each at a unique
Position)? Answer, confirmed both by reading the code and by measurement: no.
Whole-instance dedup requires every property to match; if even one differs,
zero benefit. Per-column RLE also has a real gap: `runLengthEncode` in both
`Serializer.luau` and `Writer.luau` only merges **adjacent** equal values, so a
column with repeated-but-shuffled values (e.g. 3 reused Color variants applied
in no particular order) gets none of the benefit RLE gives to sorted/grouped
data.

Measured with the real codecs (`tests/_demo_dictionary_encoding.luau`,
scratch — not committed):

| Scenario | Current best | With Dictionary added | Delta |
|---|---|---|---|
| 100 identical Parts (Anchored+Position) | 16–27 bytes | 16–27 bytes | 0 (no regression) |
| 100 unique Positions | 1200 bytes | 1200 bytes | 0 (real entropy, nothing to compress) |
| 100 unique Transparency (monotonic) | 400 bytes | 400 bytes | 0 |
| 100 Transparency alternating 2 values | 400 bytes | **122 bytes** | **-278 (-69%)** |
| 100 Positions, 3 variants shuffled | 1200 bytes | **150 bytes** | **-1050 (-87.5%)** |

The pattern: Dictionary never loses (the cost-picker just won't choose it when
it's not cheaper), and it wins precisely in the case whole-instance dedup and
RLE both miss — a handful of distinct values reused across many instances,
in any order, while *other* properties on those same instances vary freely.
This is the realistic shape of Roblox place data (many Parts share a Material/
Color/Size palette; almost none share a Position).

## Goal

1. Add **Dictionary** as a 5th column encoding (id `2`, since `2` is already
   reserved for "delta (future)" in `format/types.luau` comments — reassign
   that reservation, delta gets a new id if it's ever built; see open
   decision below).
2. Wire it into the existing per-column cost-picker in both
   `src/instance/Serializer.luau` (the estimator) and `src/format/Writer.luau`
   / `Reader.luau` (the actual read/write).
3. Re-benchmark whole-instance dedup against Dictionary-equipped columnar
   encoding on realistic mixed fixtures. If dedup's marginal benefit is at or
   below its own overhead (O(n²) scan cost + per-instance templateRef varint
   tax — see `Writer.luau:69`), remove it.

## Non-goals

- Cross-property dictionaries (a single shared dictionary across multiple
  columns/classes). Each column gets its own — simpler, and cross-column
  sharing is unlikely to pay for the added bookkeeping given how differently
  properties vary.
- Delta/numeric-stride encoding (Position along a grid, stacked parts). Still
  future work per the existing reservation in `format-layer-design.md`.
- Sorting/reordering instances to improve adjacency for RLE. Changing
  instance order would need a permutation table to restore original order on
  read, adding complexity for a benefit Dictionary already captures more
  directly.

## Encoding: Dictionary (mode `2`)

Applies to the same "non-default values" set the Raw/RLE modes already
operate on (i.e., defaults are still elided via the existing bitmask — no
change there).

**Write:**
```
[bitmask]              -- unchanged, same as raw/RLE (1 bit per instance in this class block)
[varint] uniqueCount
for each unique value (first-occurrence order):
  [codec bytes]         -- codec.write(value)
for each non-default instance, in instance order:
  [varint] dictIndex     -- 0-based index into the unique-value list above
```

**Read:** mirror — read `uniqueCount` values into an array via `codec.read`,
then for each set bit in the bitmask read a varint index and look up the
array.

**Cost estimate** (mirrors the existing `sizeRaw`/`sizeRle` functions in
`Serializer.luau`, add `sizeDict` alongside them):
```
sizeDict = ceil(effectiveCount / 8)              -- bitmask, same as other modes
         + varintSize(#uniqueValues)
         + sum(getValueSize(codec, v) for v in uniqueValues)
         + sum(varintSize(dictIndexOf(v)) for v in nonDefaultValues)
```
Pick `min(sizeRaw, sizeRle, sizeDict)` (plus the existing AllDefault/
AllNonDefault special cases, which stay as cheap short-circuits since they
need no bitmask at all).

## Architecture

Changes are localized to the two files that already own encoding choice —
no new modules:

- `src/format/types.luau`: document encoding id `2` as Dictionary (bump any
  comment reserving `2` for delta; delta will take the next free id, e.g. `5`,
  when it's designed).
- `src/instance/Serializer.luau`: add `sizeDict` computation next to the
  existing `sizeRaw`/`sizeRle` block (~line 279-320), extend the
  min-picker, build the `values`/dictionary tables when Dictionary wins.
- `src/format/Writer.luau`: add the `elseif col.encoding == 2` branch next to
  the existing raw/RLE branches (~line 128-141).
- `src/format/Reader.luau`: add the matching `elseif encoding == 2` branch
  (~line 115-131).
- `PropertyColumn` type (`src/format/types.luau`) needs no new fields —
  Dictionary's "unique values" list and "indices" are just an alternate
  interpretation of the existing `values: { any }` field (store unique values
  there) plus the per-instance indices, which can reuse the same field
  ordering convention as RLE's runs (store indices as a parallel array, or
  encode them inline — pick whichever keeps `PropertyColumn` a single shape;
  recommend adding one optional field `dictIndices: { number }?` used only
  when `encoding == 2`, mirroring how `templateRefs` is an optional field on
  `ClassBlock` today).

## Whole-instance dedup: evaluation, not deletion-on-faith

Do not delete `templateRefs`/whole-instance dedup as part of the same PR that
adds Dictionary encoding. Sequence:

1. Ship Dictionary encoding.
2. Add a benchmark fixture mixing: (a) a block of fully-identical instances,
   (b) a block of instances sharing most-but-not-all properties, (c) fully
   unique instances — modeled on a realistic place (e.g. a floor grid of
   Parts: same Size/Material/Anchored, unique Position).
3. Compare total serialized size and serialize/deserialize time with
   whole-instance dedup **on** vs **off**, both with Dictionary encoding
   active.
4. If dedup's savings are within noise of its overhead (expected, based on
   the reasoning that Dictionary already collapses "all instances share this
   column's value" to near-zero at the column level, and the "fully identical
   instance" case is exactly a degenerate case of every column being a
   1-entry dictionary), remove `templateRefs` entirely: delete the O(n²) scan
   in `Serializer.luau` (~lines 200-250), the `templateRefs` field from
   `ClassBlock`, and the corresponding read/write branches in
   `Writer.luau`/`Reader.luau`. This is a net simplification, not just a
   perf tweak — less code, one fewer per-instance-varint tax, one fewer
   O(n²) scan.
5. If measurement instead shows dedup still wins meaningfully in some case
   Dictionary doesn't reach (e.g. classes with a `Referent`/Parent property,
   where dedup is currently skipped entirely per `hasReferent` check at
   `Serializer.luau:147-153` — that's a separate axis, not something
   Dictionary touches), keep it, but note precisely which case justified
   keeping it.

## Testing

- Round-trip tests for the new Dictionary encoding mode in whatever spec file
  covers `src/format/` (extend `tests/Format.spec.luau`): a column with
  repeated non-adjacent values encodes as Dictionary and decodes back
  correctly; a column with unique values does NOT pick Dictionary (picker
  falls back to raw/AllNonDefault).
- Extend `tests/Instance.spec.luau` with an instance-tree-level case:
  N instances sharing a small palette of values on one property while another
  property is fully unique per instance — assert round-trip correctness and
  (optionally) assert the resulting buffer is smaller than a hand-computed
  "no dictionary" baseline.
- The dedup keep/remove decision needs its own benchmark script addition
  (extend `bench/RunPipeline.luau` or add a dedicated fixture) — this is a
  measurement task, not a correctness test, and should be run and its output
  captured in the PR description before deciding whether to remove dedup.

## Open decisions for the implementer

1. **Encoding id for Dictionary**: this doc proposes `2`, reclaiming the slot
   `format-layer-design.md` reserved for "delta (future)". Confirm no other
   in-flight branch already assumes `2` means delta before merging.
2. **`PropertyColumn` shape**: this doc recommends adding one optional
   `dictIndices: { number }?` field rather than overloading `values`. If a
   cleaner shape emerges during implementation (e.g. a tagged union), prefer
   it — just keep read/write symmetric.
3. **Dedup removal is conditional on the benchmark in step 3 above**, not
   pre-approved. Do not delete dedup code until that measurement is in hand.
