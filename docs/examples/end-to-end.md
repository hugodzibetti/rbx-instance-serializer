# End-to-End Example

A minimal walkthrough of building an instance tree, serializing it, reading
it back, and verifying the round-trip — following the pattern used in
`scripts/RoundTrip.luau` and the codec benchmarks in `bench/Fixtures.luau`.

See [`docs/guide.md`](../guide.md) for the full API reference (`Artifact.load`,
`Lattice.serialize`, `Lattice.deserialize`, and how to add codecs). This page
just walks the pieces together.

## 1. Load an artifact

```luau
local fs = require("@lune/fs")
local Lattice = require("@src")

local artifactBuf = buffer.fromstring(fs.readFile("data/artifact.bin"))
local artifact = Lattice.loadArtifact(artifactBuf)
```

The artifact tells Lattice which codec and default value apply to each
property of each Roblox class. `scripts/RoundTrip.luau` inspects this
directly, e.g. printing `codecId` and `default` for `Part.Anchored`.

## 2. Build a synthetic instance tree

Lune's `@lune/roblox` binding lets you build a place-like tree without
opening Studio, exactly as `scripts/RoundTrip.luau` does:

```luau
local roblox = require("@lune/roblox")

local model = roblox.Instance.new("Model")
model.Name = "LatticeTestModel"

local parts = {}
for i = 1, 5 do
	local part = roblox.Instance.new("Part")
	part.Name = "Part_" .. tostring(i)
	part.Anchored = (i % 2 == 0)
	part.Size = roblox.Vector3.new(i, i * 2, i * 3)
	part.Position = roblox.Vector3.new(i * 10, 1.5, 0)
	part.Material = if i % 2 == 0 then roblox.Enum.Material.Wood else roblox.Enum.Material.Plastic
	part.Parent = model
	table.insert(parts, part)
end

local roots = { model }
```

## 3. Serialize

```luau
local buf = Lattice.serialize(roots, artifact)
```

Internally this walks the tree, buckets instances by `ClassName`, and emits
one columnar class block per bucket (raw/RLE/AllDefault/AllNonDefault column
encoding, chosen per-property by whichever is smallest). For the on-wire
byte layout, see:

- [`columnar-vs-row.md`](./columnar-vs-row.md) — why properties are stored as columns per class, not per instance
- [`format-binary.md`](./format-binary.md) — the container/header/string-table/class-block byte layout
- [`bitmask.md`](./bitmask.md) — how default-value elision is tracked per column
- [`rle.md`](./rle.md) — run-length encoding for repeated column values
- [`varint.md`](./varint.md) — the LEB128 encoding used for all counts/ids/indices

## 4. Deserialize and verify

```luau
local decodedRoots = Lattice.deserialize(buf, artifact)

assert(#decodedRoots == 1)
local decodedModel = decodedRoots[1]
assert(decodedModel.ClassName == "Model")
assert(decodedModel.Name == "LatticeTestModel")

local decodedChildren = decodedModel:GetChildren()
assert(#decodedChildren == 5)
```

`scripts/RoundTrip.luau` sorts children by name (instance order isn't
guaranteed to match) then asserts each property (`Anchored`, `Size`,
`Position`, `Material`, `Parent`) matches the original. Run it directly with:

```bash
lune run scripts/RoundTrip.luau
```

(requires `data/artifact.bin` to already exist — see the artifact build
tooling under `src/artifacts/build`).

## Benchmarking individual codecs

For measuring a single codec's write/read cost in isolation rather than a
full tree round-trip, see `bench/Fixtures.luau`: it builds a table of
`{ name, codec, samples }` entries (one per codec in `src/serde/init.luau`,
plus synthetic samples for combinators like `array`/`option` and enum-like
types such as `faces`/`axes`) and feeds them to the benchmark runner in
`bench/Run.luau`. Useful as a template if you've added a new codec (see
[`docs/guide.md`](../guide.md#3-extending-the-codec-registry)) and want to
benchmark it alongside the existing ones.
