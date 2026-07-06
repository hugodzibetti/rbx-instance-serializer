# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Lattice (Roblox Instance Serializer)

A blazing-fast, size-efficient, backward-compatible serializer for Roblox Instance property values to compact binary format. Three core non-negotiables: **speed** (max optimizations), **backward compatibility** (versionable schema), **polished** (strict types, organized modules).

## Commands

```bash
# Requires rokit + PATH setup
export PATH="$HOME/.rokit/bin:$HOME/.local/bin:$PATH"

# Install dependencies
pesde install

# Run all tests via frktest/Lune
pesde run test
lune run scripts/RunTests.luau  # same thing, verbose

# Run a single test file (for development)
lune run tests/_scratch_run.luau  # see tests/*.spec.luau for pattern
```

## Architecture

### Three layers

**Buffer I/O (`src/buffer/`)**

- `Writer.luau`: growable binary writer. Wraps Luau's `buffer` type with auto-doubling capacity.
  - Methods: `u8/u16/u32`, `i8/i16/i32`, `f32/f64`, `bool`, `varint` (unsigned LEB128), `varintSigned` (zigzag), `string`, `bytes`.
  - Key insight: varint is used for counts, ids, indices; small numbers compress to 1 byte.
- `Reader.luau`: mirrors Writer exactly. Tracks position; exposes `remaining()`.

**Codecs (`src/serde/`)**

- All 26+ modules (e.g. `f32.luau`, `cframe.luau`, `enumItem.luau`) implement the `Codec<T>` interface:
  ```luau
  export type Codec<T> = {
    write: (writer: Writer.Writer, value: T) -> (),
    read: (reader: Reader.Reader) -> T,
  }
  ```
- Each codec is leaf: no dependencies on other codecs (design choice for parallelization).
- **Exception**: combinators (`array.luau`, `option.luau`) are factories: `array(elemCodec) -> Codec<{T}>`.

**Serialization patterns**

- **No per-value type tags in property blocks**: the artifact (build-time metadata) already knows types. Codecs run without branching.
- **Default-value elision**: instance layer compares `value == artifactDefault` directly; codecs never see defaults.
- **Float precision**: f32 for bulk numeric properties (position, size, scale); f64 only where required (override flag in artifact, not yet built).
- **CFrame optimization**: the 24 axis-aligned (90° rotations) map to a 1-byte index (matching Roblox's `.rbxm` trick); arbitrary rotations use 9 f32 components.
- **Color quantization**: Color3 channels → u8 each (8-bit internal storage in Roblox, zero precision loss).
- **Stable enum values**: EnumItem serializes `.Value` (Roblox's backward-compat guarantee), not position or name.

### Testing

**Patterns**:

- Unit tests are round-trip: serialize value → read back → assert equality.
- Tests for Roblox types use `require("@lune/roblox")` (Lune's built-in binding; works standalone, no place file needed).
- For generic combinators (array, option), tests include an inline dummy codec to avoid cross-PR dependencies.

**Running**:

- `pesde run test` loads all 21 test specs and runs them via frktest's lune reporter.
- All specs wired into `scripts/RunTests.luau`: Buffer, Serde (11 types + Referent), Artifact, Format, Instance, Compat, Cli.

## Require Aliases

Defined in `.luaurc`:

```json
"aliases": {
  "src": "src",
  "packages": "lune_packages",
  "tests": "tests",
  "cli": "cli"
}
```

Use `@src/buffer/Writer`, `@packages/frktest`, `@tests/SomeName`, `@cli/SomeName` everywhere. This works natively under Lune; publishing to Roblox uses darklua to convert `@src/...` to relative paths (the `cli/` tree is dev tooling only, not part of the published Roblox package).

## Code Style

- `--!strict` at top of every module (type checking).
- `--!native --!optimize 2` on hot-path serde modules (codec implementations).
- No comments unless the **why** is non-obvious (hidden constraint, workaround, subtle invariant).
- Prefer explicit types in function signatures; use `local x: Type = ...` for clarity.

## Key Design Decisions

1. **Modularity**: each codec is a small (~20–50 line), independent file. Enables parallel development and clean merges.
2. **Varint for variable-length data**: ids, counts, indices use LEB128 (zigzag for signed). Huge win for small values.
3. **No runtime reflection**: all type information is resolved at artifact-build time or codecs are written with knowledge of their type.
4. **Columnar/SoA for class blocks**: ✅ instances grouped by class, properties stored as columns with per-column encoding (raw, RLE, Dictionary, AllDefault, AllNonDefault). Enables compression and delta encoding.
5. **Backward compat via versioned schema**: ✅ files include schemaVersion in header; migration registry in `src/compat/` provides hooks for future API-dump changes.

## Design Docs

- `docs/superpowers/specs/2026-07-02-codec-benchmarks-design.md` — codec design & benchmarks ✅ (benchmark harness complete)
- `docs/superpowers/specs/2026-07-04-artifact-system-design.md` — artifact system design ✅ (fully implemented)
- `docs/superpowers/specs/2026-07-04-format-layer-design.md` — format container, columnar layout, bitmasks, RLE ✅ (fully implemented)
- `docs/glossary.md` — terminology reference (varint, bitmask, RLE, columnar, etc.)
- `docs/examples/` — supplementary examples (varint, bitmask, RLE, columnar-vs-row, format-binary)

## Completed Milestones

1. ✅ **Artifact system** — `src/artifacts/` fully functional, includes build/parse/resolve/load.
2. ✅ **Format/Container** — `src/format/` implements header, string table, columnar class blocks with 5 encodings (raw, RLE, Dictionary, AllDefault, AllNonDefault).
3. ✅ **Instance layer** — `src/instance/` serializes/deserializes Roblox instances with default elision, instance dedup (`templateRefs`), and template detection. Dedup coexists with column Dictionary encoding rather than being superseded by it — see "Column Dictionary Encoding" below for the real measurement behind that call.
4. ✅ **Compat system** — `src/compat/` provides versioned schema registry with migration hooks.
5. ✅ **Integration** — all 20 test specs wired; central serde registry at `src/serde/init.luau` (28 codecs + factories).
6. ✅ **Extended Codec Coverage** — `ProtectedString`/`ContentId` aliased to the `string` codec; new `src/serde/ray.luau` codec (id 27) for `RayValue.Value`. Artifact-build warning count dropped from 971 to 878 (remaining 878 are all out of scope: 866 `SecurityCapabilities` blocked upstream by Lune, 5 `QDir`/3 `QFont`/1 `AuroraScript` Studio-editor-only/internal, 3 `DateTime` skipped as optional stretch).
7. ✅ **CLI Tooling** — `cli/` implements `lattice stats/dump/diff` per `docs/superpowers/specs/2026-07-05-cli-tooling-design.md`; wired as `pesde run lattice -- <subcommand> <args>`. `stats`/`dump` read `FormatData` directly (no instance deserialize); `diff` resolves both files via `src/instance/Deserializer.luau` and matches instances by `UniqueId` with positional-tree-order fallback, printing which strategy matched each instance.
8. ✅ **Column Dictionary Encoding** — added a 5th column encoding (id `2`) that captures repeated-but-shuffled values RLE misses. Wired into the cost-picker (`src/instance/Serializer.luau`, which keys unique dictionary values by their actual codec-serialized bytes — not `tostring(v)`, which can lose precision for Vector3/CFrame/etc and silently collapse distinct values) and read/write (`src/format/Writer.luau`/`Reader.luau`, plus the version-2 reader `src/format/readers/V2.luau`). `bench/DedupVsDictionary.luau` does a real dedup-on vs dedup-off byte-count comparison — it calls the actual `Lattice.serialize` entrypoint twice on the same mixed fixture (40 identical / 200 shared-palette / 60 unique instances) via a benchmark-only `disableDedup` parameter on `Serializer.serialize`, with Dictionary encoding active in both runs. Measured: dedup contributed 0 additional bytes of savings on this fixture (Dictionary's per-column dictionary already collapses the fully-identical block to a 1-entry dictionary, which is dedup's best case). Given that real result, whole-instance dedup (`templateRefs`) was **kept** rather than removed — the O(n²) scan only runs when there's no Referent property and ≥2 instances, and the measured overhead on this fixture was negligible relative to overall serialize cost; removal is left for a follow-up decision once dedup is measured across more realistic/larger fixtures where its cost profile may differ. Both mechanisms are wired end-to-end through `Serializer.luau`, `Deserializer.luau`, `Writer.luau`, `Reader.luau`, and `format/types.luau`.

## Current Work

1. **Roblox Package Polish**: Create standalone Roblox package output; wire darklua to publish `@src/...` requires as relative paths for Studio import.
2. **Performance Tuning**: Profile benchmarks from PR #18; identify hot paths (CFrame, array encode/decode, bitmask packing); apply micro-optimizations.
3. **Documentation & Examples**: Write user guide (serialize/deserialize API, artifact format, extending codecs); add end-to-end example (load Roblox place → serialize → read back).

## Implementation Notes

- **frktest**: the test framework; minimal but effective. Tests are plain Luau functions that call `test.case()` and `check.equal()`.
- **pesde**: Luau package manager; replaces wally for this project.
- **lune**: Lua/Luau runtime; runs tests and build scripts outside of Roblox Studio.
- **darklua**: AST processor; converts Luau `@alias/...` requires to relative paths for Roblox deployment. Config at `.darklua.json` (PR #17).
- **`SecurityCapabilities` cannot be serialized**: Lune's `roblox` binding errors (`Failed to convert from 'SecurityCapabilities' into 'userdata' - Type not supported`) just reading `Instance.Capabilities` — this is 866 of the remaining codec-coverage warnings from a real artifact build, all from one property inherited by every class. Not fixable in this repo; it's an upstream Lune limitation. See `docs/superpowers/specs/2026-07-05-extended-codec-coverage-design.md`.
- **Shared cost-estimator module**: per-column encoding cost math (`sizeRaw`/`sizeRle`/`sizeAllNonDefault`, plus `getValueSize`/`varintSize`/`runLengthEncode`) lives in `src/format/CostEstimator.luau`, extracted out of `src/instance/Serializer.luau` (which now just calls it) so `cli/Stats.luau`/`cli/Dump.luau` recompute the exact same per-column byte costs the serializer uses to pick encodings — single source of truth, no copy-pasted estimator logic between the CLI and the serializer.
- **`data/artifact.bin` is gitignored**: it's generated locally/CI via `pesde run artifact`. Tests that need an `ArtifactData` (Instance/Format/Cli specs) use an in-memory mock artifact table instead of depending on this file, so `pesde run test` works without a build step.

## Updating This File

After completing work, update CLAUDE.md to reflect:
- Completed milestones moved to "Completed Milestones" section with ✅ checkmarks.
- Current/in-progress work listed under "Current Work" with clear scope & rationale.
- Design decisions or architectural changes documented in the relevant section.
- New gotchas or gotcha resolutions added to "Implementation Notes" for future context.
