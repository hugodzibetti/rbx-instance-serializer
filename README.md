# Lattice

Blazing-fast, size-efficient, backward-compatible serializer for Roblox Instance property values to a compact binary format.

## Design Goals

- **Speed** — maximal optimizations: varint encoding, default-value elision, columnar layouts, no per-value type tags
- **Backward compatibility** — versioned schema registry with migration hooks for API-dump changes
- **Polished** — strict types, `--!native --!optimize 2` on hot paths, organized modules

## Architecture

| Layer     | Path             | Purpose                                                                                         |
| --------- | ---------------- | ------------------------------------------------------------------------------------------------ |
| Buffer I/O | `src/buffer/`   | `Writer` / `Reader` — growable binary buffer with varint, zigzag, float, string ops                |
| Codecs    | `src/serde/`     | 28+ leaf modules implementing `Codec<T>`, plus combinators (`array`, `option`)                     |
| Artifacts | `src/artifacts/` | Build-time metadata from the Roblox API dump: class hierarchy, property types, defaults            |
| Format    | `src/format/`    | Container: header, string table, columnar class blocks (5 column encodings), versioned readers     |
| Instance  | `src/instance/`  | Traverses an Instance tree ↔ format data, with default-value elision                              |
| Compat    | `src/compat/`    | Versioned schema registry; migrates older format versions forward on read                          |
| Patch     | `src/patch/`     | Incremental diff/apply between a baseline file and a live instance tree                            |
| CLI       | `cli/`           | `lattice stats/dump/diff` — inspect and compare `.lattice` files                                   |

### Codec interface

```luau
export type Codec<T> = {
    write: (writer: Writer.Writer, value: T) -> (),
    read: (reader: Reader.Reader) -> T,
}
```

Each codec is a small, independent leaf module (~20-50 lines) with no dependencies on other codecs. Combinators like `array(elemCodec)` and `option(codec)` are factories that wrap a codec.

### Key optimizations

- **Varint (LEB128)** for counts, ids, indices — small numbers compress to 1 byte; signed values use zigzag
- **No per-value type tags** — the artifact (build-time metadata) already knows types, so codecs run branchless
- **Default-value elision** — the instance layer compares `value == artifactDefault` directly; codecs never see defaults
- **Columnar class blocks** — instances are grouped by class; each property is a column, independently encoded as raw, RLE, Dictionary, AllDefault, or AllNonDefault, whichever is smallest
- **CFrame** — 24 axis-aligned rotations map to a 1-byte index (matching Roblox's `.rbxm` trick); arbitrary rotations use 9×f32
- **Color3** — channels → u8 each (matches Roblox's 8-bit internal storage, zero precision loss)
- **EnumItem** — serializes `.Value` (Roblox's backward-compat guarantee), not position or name

## Commands

```bash
# Requires rokit + PATH
export PATH="$HOME/.rokit/bin:$HOME/.local/bin:$PATH"

# Install dependencies
pesde install

# Run all tests
pesde run test
lune run scripts/RunTests.luau  # same thing, verbose

# Build the artifact (Roblox API dump → build-time metadata; gitignored)
pesde run artifact

# CLI tooling
pesde run lattice -- stats <file.lattice>
pesde run lattice -- dump <file.lattice>
pesde run lattice -- diff <a.lattice> <b.lattice>
```

## Require Aliases

Defined in `.luaurc`:

| Alias        | Path             |
| ------------ | ---------------- |
| `@src/`      | `src`            |
| `@packages/` | `lune_packages`  |
| `@tests/`    | `tests`          |
| `@cli/`      | `cli`            |

Publishing to Roblox uses darklua (`.darklua.json`) to convert `@src/...` requires to relative paths; the `cli/` tree is dev tooling only and isn't part of the published package.

## Testing

Unit tests are round-trip: serialize value → read back → assert equality. Uses [`frktest`](https://github.com/boatbomber/frktest) via Lune. Roblox types are tested with `@lune/roblox` (standalone, no place file needed). `pesde run test` wires up all specs: Buffer, Serde (per-type + Referent), Artifact, Format, Instance, Compat, Cli, SchemaEvolution, Patch.

## Format Versioning

Files carry a `schemaVersion` in their header. `src/format/Reader.luau` dispatches to a frozen per-version reader (`src/format/readers/V1.luau`...`V4.luau`) and pipes the result through the compat registry, so older files keep reading correctly as the format evolves. `Writer.luau` always writes the current version (currently v4).

## Parallel Encoding

For large scenes, `Serializer.serializeParallel`/`Deserializer.deserializeParallel` split work across `@lune/process` child worker (`src/parallel/Worker.luau`) instances, one per class block, running Stage B (per-column encoding decisions) concurrently instead of sequentially in-process. This requires format v4, which length-prefixes each class block so blocks can be produced/consumed independently and concatenated by the parent without rewriting offsets.

- `Serializer.serializeAuto(roots, artifact)` / `Deserializer.deserializeAuto(data, artifact)` pick the parallel or sequential path automatically based on scene size (≥6 distinct classes and ≥12,000 instances triggers parallel) — prefer these over calling `serializeParallel`/`deserializeParallel` directly.
- `deserializeParallel` only supports v4 buffers; `deserializeAuto` falls back to sequential `deserialize` for older versions or scenes below the threshold.
- Worker protocol (wire payloads for both encode and decode modes) is documented in `src/parallel/Worker.luau`'s header comment and `docs/superpowers/specs/2026-07-05-parallel-encoding-design.md`.

## Status

Feature-complete: extended codec coverage, columnar format with dictionary encoding, schema evolution, CLI tooling, incremental patch/apply, and parallel multi-process encoding (v4) are all implemented and tested. See [`CLAUDE.md`](CLAUDE.md) for current in-progress work (`.rbxm` size benchmarking) and detailed design decisions.

## Code Style

- `--!strict` at top of every module
- `--!native --!optimize 2` on hot-path serde modules
- No comments unless the _why_ is non-obvious
- Explicit type signatures; `local x: Type = ...`
