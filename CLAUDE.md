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
- `pesde run test` loads all specs and runs them via frktest's lune reporter.
- Current `scripts/RunTests.luau` only loads `Buffer.spec`; integration step (post-batch) will wire all 14 new specs.

## Require Aliases

Defined in `.luaurc`:
```json
"aliases": {
  "src": "src",
  "packages": "lune_packages",
  "tests": "tests"
}
```

Use `@src/buffer/Writer`, `@packages/frktest`, `@tests/SomeName` everywhere. This works natively under Lune; publishing to Roblox uses darklua to convert `@src/...` to relative paths.

## Code Style

- `--!strict` at top of every module (type checking).
- `--!native --!optimize 2` on hot-path serde modules (codec implementations).
- No comments unless the **why** is non-obvious (hidden constraint, workaround, subtle invariant).
- Prefer explicit types in function signatures; use `local x: Type = ...` for clarity.

## Key Design Decisions

1. **Modularity**: each codec is a small (~20–50 line), independent file. Enables parallel development and clean merges.
2. **Varint for variable-length data**: ids, counts, indices use LEB128 (zigzag for signed). Huge win for small values.
3. **No runtime reflection**: all type information is resolved at artifact-build time or codecs are written with knowledge of their type.
4. **Columnar/SoA for class blocks**: (future) instances grouped by class, properties stored as columns, enables compression and delta encoding.
5. **Backward compat via versioned schema**: files include schemaVersion in header; translation maps in `compat/` will handle API-dump changes (not yet built).

## Next Steps After Phase 2 (Codecs)

1. **Artifact system** (`src/artifacts/`): pre-compute class metadata (properties, defaults, codec ids, bitmask layouts) from Roblox API dump.
2. **Format/Container** (`src/format/`): header, string table, tag table, columnar class blocks.
3. **Instance layer** (`src/instance/`): traverse → index, serialize/deserialize, optimize (default elision, dedup, template detection).
4. **Compat system** (`src/compat/`): versioned schema registry + translation maps for future-proofing.
5. **Integration**: wire all specs into `scripts/RunTests.luau`, create central serde registry in `src/serde/init.luau`.

## Notes

- **frktest**: the test framework; minimal but effective. Tests are plain Luau functions that call `test.case()` and `check.equal()`.
- **pesde**: Luau package manager; replaces wally for this project.
- **lune**: Lua/Luau runtime; runs tests and build scripts outside of Roblox Studio.
- **darklua**: AST processor; converts Luau `@alias/...` requires to relative paths for Roblox deployment (not yet applied).
