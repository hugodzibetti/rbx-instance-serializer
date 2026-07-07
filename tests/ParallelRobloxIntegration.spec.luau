--!strict
-- Integration coverage for the Roblox-Actor-based parallel backend dispatch wired
-- into src/instance/Serializer.luau's serializeParallel and
-- src/instance/Deserializer.luau's deserializeParallel (see the task that added
-- the RobloxBackend.isActorParallelAvailable() / encodeClassBlocksParallel /
-- decodeClassBlocksParallel dispatch).
--
-- Under Lune, RobloxBackend.isActorParallelAvailable() is false, so
-- serializeParallel/deserializeParallel should fall through to the Lune
-- worker-process path (path b). That's the same code path the existing
-- ParallelIntegration.spec.luau already covers, but this spec exists to:
--   1. Hand-regression-guard the new dispatch (specifically that the
--      RobloxBackend require and isActorParallelAvailable() check don't break
--      the call path under Lune), and
--   2. Exercise the RobloxBackend module's no-Actor fallback
--      (encodeClassBlocksParallel / decodeClassBlocksParallel calling
--      Payload.encode / Payload.decode in a loop) directly, since that fallback
--      IS the actual code the Roblox engine would NOT run but that has to be
--      correct on its own merits for the contract.
--
-- The correctness bar (same as ParallelIntegration.spec.luau): parallel paths
-- must be a pure execution-strategy change, not a semantics change. So the
-- core assertion here is that serialize() and serializeParallel() produce
-- BYTE-IDENTICAL buffers for the same input scene.

local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local roblox = require("@lune/roblox")
local serde = require("@src/serde")
local instance = require("@src/instance")
local RobloxBackend = require("@src/parallel/RobloxBackend")
local Payload = require("@src/parallel/Payload")
local BufferWriter = require("@src/buffer/Writer")
local BufferReader = require("@src/buffer/Reader")

-- Same mock artifact shape as ParallelIntegration.spec.luau (kept duplicated
-- rather than shared to avoid coupling these specs together - either one should
-- be free to evolve independently).
local mockArtifact = {
	version = 1,
	classes = {},
	classByName = {},
	classById = {
		[1] = {
			id = 1,
			name = "Folder",
			properties = {
				{
					name = "Parent",
					codecId = 26,
					codec = serde.codecIdToModule[26],
					default = 0,
				},
			},
		},
		[2] = {
			id = 2,
			name = "Model",
			properties = {
				{
					name = "Parent",
					codecId = 26,
					codec = serde.codecIdToModule[26],
					default = 0,
				},
			},
		},
		[3] = {
			id = 3,
			name = "Part",
			properties = {
				{
					name = "Parent",
					codecId = 26,
					codec = serde.codecIdToModule[26],
					default = 0,
				},
				{
					name = "Anchored",
					codecId = 2,
					codec = serde.codecIdToModule[2],
					default = false,
				},
				{
					name = "Size",
					codecId = 17,
					codec = serde.codecIdToModule[17],
					default = roblox.Vector3.new(0, 0, 0),
				},
				{
					name = "Position",
					codecId = 17,
					codec = serde.codecIdToModule[17],
					default = roblox.Vector3.new(0, 0, 0),
				},
				{
					name = "Color",
					codecId = 7,
					codec = serde.codecIdToModule[7],
					default = roblox.Color3.new(0, 0, 0),
				},
			},
		},
	},
}
mockArtifact.classByName["Folder"] = mockArtifact.classById[1]
mockArtifact.classByName["Model"] = mockArtifact.classById[2]
mockArtifact.classByName["Part"] = mockArtifact.classById[3]

-- Same scene shape as ParallelIntegration.spec.luau: Folder -> Model -> 25 Parts
-- with shuffled Anchored/Size/Color (Dictionary/RLE bait) + unique Position
-- (Raw/AllNonDefault bait), plus 3 all-default Parts directly under the Folder
-- (AllDefault bait) and 1 fully non-default special Part directly under root.
local function buildScene(): { any }
	local root = roblox.Instance.new("Folder")
	local model = roblox.Instance.new("Model")
	model.Parent = root

	local sizes = { roblox.Vector3.new(4, 1, 4), roblox.Vector3.new(2, 1, 2), roblox.Vector3.new(6, 1, 6) }
	local colors = { roblox.Color3.new(1, 0, 0), roblox.Color3.new(0, 1, 0), roblox.Color3.new(0, 0, 1) }

	for i = 1, 25 do
		local part = roblox.Instance.new("Part")
		part.Parent = model
		part.Anchored = (i % 2 == 0)
		part.Size = sizes[((i * 7) % #sizes) + 1]
		part.Color = colors[((i * 3) % #colors) + 1]
		part.Position = roblox.Vector3.new(i, i * 2, i * 3)
	end

	for _ = 1, 3 do
		local part = roblox.Instance.new("Part")
		part.Anchored = false
		part.Size = roblox.Vector3.new(0, 0, 0)
		part.Position = roblox.Vector3.new(0, 0, 0)
		part.Color = roblox.Color3.new(0, 0, 0)
		part.Parent = root
	end

	local special = roblox.Instance.new("Part")
	special.Parent = root
	special.Anchored = true
	special.Size = roblox.Vector3.new(100, 100, 100)
	special.Color = roblox.Color3.fromRGB(128, 64, 191)
	special.Position = roblox.Vector3.new(-1, -2, -3)

	return { root }
end

return function()
	test.suite("parallel.roblox.integration", function()
		test.case("RobloxBackend.isActorParallelAvailable is false under Lune", function()
			-- Documents the dispatch path this spec exercises (path b: Lune worker
			-- processes, NOT Roblox Actors). If this ever becomes true under Lune,
			-- the rest of this suite no longer covers path b and would need a
			-- different environment to do so.
			check.equal(RobloxBackend.isActorParallelAvailable(), false)
		end)

		test.case("serializeParallel (Lune dispatch) produces a byte-identical buffer to serialize", function()
			local sceneA = buildScene()
			local sceneB = buildScene()

			local bufSeq = instance.serialize(sceneA, mockArtifact :: any)
			local bufPar = instance.serializeParallel(sceneB, mockArtifact :: any)

			check.equal(buffer.len(bufSeq), buffer.len(bufPar))
			check.equal(buffer.tostring(bufSeq), buffer.tostring(bufPar))
		end)

		test.case("full round trip through serializeParallel -> deserializeParallel matches sequential path", function()
			local sceneA = buildScene()
			local sceneB = buildScene()

			local bufSeq = instance.serialize(sceneA, mockArtifact :: any)
			local rootsSeq = instance.deserialize(bufSeq, mockArtifact :: any)

			local bufPar = instance.serializeParallel(sceneB, mockArtifact :: any)
			local rootsPar = instance.deserializeParallel(bufPar, mockArtifact :: any)

			-- Both buffers must be byte-identical (parallel is pure
			-- execution-strategy change, not a semantics change).
			check.equal(buffer.len(bufSeq), buffer.len(bufPar))
			check.equal(buffer.tostring(bufSeq), buffer.tostring(bufPar))

			-- Both reconstructed trees must have the same shape (one root, identical
			-- instance count) - a decoded-equivalence spot-check on top of the
			-- byte-identical buffer assertion above.
			check.equal(#rootsSeq, 1)
			check.equal(#rootsPar, 1)
			check.equal(rootsSeq[1].ClassName, "Folder")
			check.equal(rootsPar[1].ClassName, "Folder")

			local function countAll(root: any): number
				local n = 0
				local function dfs(inst: any)
					n += 1
					for _, child in inst:GetChildren() do
						dfs(child)
					end
				end
				dfs(root)
				return n
			end
			check.equal(countAll(rootsSeq[1]), countAll(rootsPar[1]))
		end)

		test.case("RobloxBackend.encodeClassBlocksParallel/decodeClassBlocksParallel round-trip a payload directly", function()
			-- Focused test of the backend's no-Actor fallback (which is the only
			-- path exercisable under Lune): hand-build a worker-protocol ENCODE
			-- payload via the same wire format src/parallel/Payload.luau documents,
			-- run it through RobloxBackend.encodeClassBlocksParallel, feed the
			-- result back as a decode payload through
			-- RobloxBackend.decodeClassBlocksParallel, and assert the decode output
			-- is parseable and consistent.
			--
			-- Encode payload shape (per src/parallel/Payload.luau ENCODE section):
			--   className: string
			--   classId: varint
			--   instanceCount: varint
			--   columnCount: varint
			--   per column:
			--     propertyName: string, propertyNameIndex: varint, codecId: varint,
			--     bitmask bytes, then each non-default value via codec.write

			local w = BufferWriter.new()
			local className = "Folder"
			local classId = 1
			local instanceCount = 2
			local columnCount = 1
			local propName = "Parent"
			local propertyNameIndex = 1
			local codecId = 26 -- Referent
			local referentCodec = serde.codecIdToModule[codecId]

			w:string(className)
			w:varint(classId)
			w:varint(instanceCount)
			w:varint(columnCount)

			w:string(propName)
			w:varint(propertyNameIndex)
			w:varint(codecId)

			-- Both instances are default (Parent == 0), so an all-zero bitmask.
			local numBytes = math.ceil(instanceCount / 8)
			local mask = buffer.create(numBytes)
			for i = 0, numBytes - 1 do
				buffer.writeu8(mask, i, 0)
			end
			w:bytes(mask)

			local payload = w:toBuffer()

			local encoded = RobloxBackend.encodeClassBlocksParallel({ payload })
			check.equal(#encoded, 1)
			check.equal(type(encoded[1]), "buffer")

			-- Build a decode payload that ships the encoded class block back through
			-- the backend's decode path. Decode payload shape (per
			-- src/parallel/Payload.luau DECODE section):
			--   classId, className, propertyCount, per property (name, codecId),
			--   stringTableCount, per string, blockLength, blockBody bytes
			local dw = BufferWriter.new()
			dw:varint(classId)
			dw:string(className)
			dw:varint(columnCount)
			dw:string(propName)
			dw:varint(codecId)
			-- string table with the single property name
			dw:varint(1)
			dw:string(propName)
			-- The encoded block from the previous step IS length-prefixed v4 block
			-- bytes, so its leading varint is the body length and the rest is the
			-- body. Mirror that here.
			local encReader = BufferReader.new(encoded[1])
			local blockBodyLen = encReader:varint()
			local blockBody = encReader:bytes(blockBodyLen)
			dw:varint(blockBodyLen)
			dw:bytes(blockBody)

			local decodePayload = dw:toBuffer()
			local decoded = RobloxBackend.decodeClassBlocksParallel({ decodePayload })
			check.equal(#decoded, 1)
			check.equal(type(decoded[1]), "buffer")

			-- The decode output starts with instanceCount varint, columnCount varint.
			local outReader = BufferReader.new(decoded[1])
			local outInstanceCount = outReader:varint()
			local outColumnCount = outReader:varint()
			check.equal(outInstanceCount, instanceCount)
			check.equal(outColumnCount, columnCount)

			-- Sanity: Payload.encode/decode in a loop should produce the same decode
			-- output bytes (this is exactly what the no-Actor fallback does).
			local directDecode = Payload.decode(decodePayload)
			check.equal(buffer.tostring(directDecode), buffer.tostring(decoded[1]))
		end)
	end)
end