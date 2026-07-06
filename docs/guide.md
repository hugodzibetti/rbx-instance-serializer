# User Guide

This guide covers the three things most users of Lattice need: loading an
artifact, serializing/deserializing Roblox instances, and adding a new codec
to the registry.

All examples require the top-level module (`src/init.luau`, aliased `@src`),
which re-exports the public API:

```luau
local Lattice = require("@src")
```

## 1. Loading an artifact

An artifact is build-time metadata describing every Roblox class and
property Lattice knows how to serialize (codec assignments, default values,
class/property IDs). It's produced by the artifact build step (`src/artifacts/build`)
and consumed at runtime as a `buffer`.

`src/artifacts/Artifact.luau` exposes one function:

```luau
local Artifact = require("@src/artifacts/Artifact")

-- load(artifactBuffer: buffer): ArtifactData
local artifact = Artifact.load(artifactBuffer)
```

This is also exported from the top level as `Lattice.loadArtifact`:

```luau
local fs = require("@lune/fs")
local Lattice = require("@src")

local artifactBuf = buffer.fromstring(fs.readFile("data/artifact.bin"))
local artifact = Lattice.loadArtifact(artifactBuf)
```

`load` validates the magic bytes (`"LATA"`) and schema version, then returns
an `ArtifactData` table (defined in `src/artifacts/types.luau`):

```luau
export type ArtifactData = {
	version: number,
	classes: { ClassMetadata },
	classByName: { [string]: ClassMetadata },
	classById: { [number]: ClassMetadata },
}

export type ClassMetadata = {
	id: number,
	name: string,
	properties: { PropertyMetadata },
}

export type PropertyMetadata = {
	name: string,
	codecId: number,
	codecParams: { number }?,
	default: any?,
	codec: any?, -- resolved Codec<T>, or nil if codecId is unknown
}
```

Look up class metadata by name or ID:

```luau
local partMeta = artifact.classByName["Part"]
for _, prop in partMeta.properties do
	print(prop.name, prop.codecId, prop.default)
end
```

You'll pass this `ArtifactData` value into every `serialize`/`deserialize`
call — it's what tells the instance layer which codec to run for each
property and what the default value is (so defaults can be elided from the
wire format).

## 2. Serializing and deserializing instances

The instance layer lives in `src/instance/` and is re-exported at the top
level as `Lattice.serialize` / `Lattice.deserialize`.

### Serialize

`src/instance/Serializer.luau`:

```luau
-- serialize(roots: { any }, artifact: ArtifactData): buffer
local buf = Lattice.serialize(roots, artifact)
```

`roots` is an array of Roblox instances (e.g. `roblox.Instance.new(...)`
trees built via Lune's `@lune/roblox`). Serialization walks each root's
full descendant tree, buckets instances by `ClassName`, and encodes them as
columnar class blocks (see `docs/examples/columnar-vs-row.md` and
`docs/examples/format-binary.md` for the on-wire layout). The result is a
single `buffer`.

### Deserialize

`src/instance/Deserializer.luau`:

```luau
-- deserialize(buf: buffer, artifact: ArtifactData): { any }
local roots = Lattice.deserialize(buf, artifact)
```

Returns an array of the reconstructed root instances (any instance whose
`Parent` ended up `nil` after the parenting pass). Note that `artifact` must
be the *same* artifact (or a compatible schema version) used to serialize —
codec IDs and defaults are resolved from it, not from the buffer.

### Minimal round-trip

```luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Lattice = require("@src")

local artifact = Lattice.loadArtifact(buffer.fromstring(fs.readFile("data/artifact.bin")))

local model = roblox.Instance.new("Model")
model.Name = "MyModel"

local part = roblox.Instance.new("Part")
part.Parent = model

local buf = Lattice.serialize({ model }, artifact)
local roots = Lattice.deserialize(buf, artifact)

print(roots[1].Name) -- "MyModel"
```

See `scripts/RoundTrip.luau` for a fuller worked example with assertions,
and `docs/examples/end-to-end.md` for a walkthrough.

## 3. Extending the codec registry

Every codec is a small, dependency-free module implementing the `Codec<T>`
interface (`src/types.luau`):

```luau
export type Codec<T> = {
	write: (writer: Writer.Writer, value: T) -> (),
	read: (reader: Reader.Reader) -> T,
}
```

For example, `src/serde/f32.luau` in full:

```luau
--!strict
--!native
--!optimize 2

local Types = require("@src/types")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")

local codec: Types.Codec<number> = {
	write = function(writer: Writer.Writer, value: number)
		writer:f32(value)
	end,
	read = function(reader: Reader.Reader): number
		return reader:f32()
	end,
}

return codec
```

### Adding a new codec

1. **Write the module** under `src/serde/yourType.luau`, following the
   pattern above. Use `Writer`/`Reader` primitives (`u8`, `varint`, `f32`,
   `bytes`, etc. — see `src/buffer/Writer.luau`) to encode/decode. Add
   `--!strict --!native --!optimize 2` to match the other hot-path codecs.

2. **Register it** in `src/serde/init.luau`:
   - `require` your module at the top.
   - Add it to `codecIdToModule` under the next unused numeric ID (IDs
     0–3 and 6–26 are taken; `4` and `5` are reserved for the `array`/`option`
     factories in `codecIdToFactory`).
   - Add the same ID to `codecNameToId` under your codec's string name (this
     is what the artifact build step uses to assign `codecId` to properties).

   ```luau
   local yourType = require("@src/serde/yourType")

   codecIdToModule[27] = yourType :: Codec<any>
   codecNameToId.yourType = 27
   ```

3. **Combinators** (`array`, `option`) are factories rather than static
   codecs — `array(elemCodec) -> Codec<{T}>` — and are looked up via
   `codecIdToFactory` plus a `codecParams` list pointing at the inner codec's
   ID (see `src/artifacts/getCodec.luau` for how `codecId`s 4/5 are resolved
   at artifact-load time). A new combinator follows the same factory shape.

4. **Test it**: add a round-trip spec (write → read → `check.equal`)
   alongside the existing serde tests, following the pattern in the other
   `tests/*.spec.luau` files for serde types.

No other layer needs to change — the format and instance layers only ever
see `Codec<T>` and never branch on concrete types.
