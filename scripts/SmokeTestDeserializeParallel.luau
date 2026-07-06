--!strict
-- Standalone smoke test for Deserializer.deserializeParallel (src/instance/Deserializer.luau).
-- Not wired into scripts/RunTests.luau/frktest: it spawns real `lune` child processes
-- per class block (via process.exec inside task.spawn), which doesn't fit frktest's
-- synchronous in-process unit-test model - same reasoning as
-- scripts/SmokeTestSerializeParallel.luau and scripts/SmokeTestWorker.luau. Run
-- directly instead:
--   lune run scripts/SmokeTestDeserializeParallel.luau
--
-- (The real frktest coverage for both serializeParallel and deserializeParallel
-- together, tests/ParallelIntegration.spec.luau, is a separate follow-up task.)

local process = require("@lune/process")
local roblox = require("@lune/roblox")

local serde = require("@src/serde")
local instance = require("@src/instance")

local function fail(msg: string): never
	print("SMOKE TEST FAILED: " .. msg)
	process.exit(1)
end

-- Mock ArtifactData with two classes, mirroring SmokeTestSerializeParallel.luau's
-- mockArtifact so a buffer produced by either serialize() or serializeParallel() can
-- be fed through deserializeParallel() with the same class shapes.
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
					name = "Position",
					codecId = 17,
					codec = serde.codecIdToModule[17],
					default = roblox.Vector3.new(0, 0, 0),
				},
			},
		},
	},
}
mockArtifact.classByName["Folder"] = mockArtifact.classById[1]
mockArtifact.classByName["Part"] = mockArtifact.classById[2]

-- Build a small scene: one Folder with three Part children, two classes total.
local folder = roblox.Instance.new("Folder")

local part1 = roblox.Instance.new("Part")
part1.Parent = folder
part1.Anchored = true
part1.Position = roblox.Vector3.new(1, 2, 3)

local part2 = roblox.Instance.new("Part")
part2.Parent = folder
part2.Anchored = false
part2.Position = roblox.Vector3.new(4, 5, 6)

local part3 = roblox.Instance.new("Part")
part3.Parent = folder
part3.Anchored = true
part3.Position = roblox.Vector3.new(0, 0, 0) -- default position, should be elided

print("Running serializeParallel to produce a v4 buffer...")
local buf = instance.serializeParallel({ folder }, mockArtifact :: any)
print("serializeParallel returned a buffer of length " .. tostring(buffer.len(buf)))

-- Correctness check: deserializeParallel's reconstructed instances should match
-- deserialize()'s (the sequential path) exactly, property-for-property.
print("Running deserialize (sequential, reference) ...")
local sequentialRoots = instance.deserialize(buf, mockArtifact :: any)

print("Running deserializeParallel...")
local parallelRoots = instance.deserializeParallel(buf, mockArtifact :: any)

assert(#sequentialRoots == 1, "expected 1 sequential root, got " .. tostring(#sequentialRoots))
assert(#parallelRoots == 1, "expected 1 parallel root, got " .. tostring(#parallelRoots))

local seqFolder = sequentialRoots[1]
local parFolder = parallelRoots[1]

assert(seqFolder.ClassName == "Folder", "expected sequential root ClassName Folder")
assert(parFolder.ClassName == "Folder", "expected parallel root ClassName Folder")

local seqChildren = seqFolder:GetChildren()
local parChildren = parFolder:GetChildren()

assert(#seqChildren == 3, "expected 3 sequential children, got " .. tostring(#seqChildren))
assert(#parChildren == 3, "expected 3 parallel children, got " .. tostring(#parChildren))

local function findPartByPosition(children: { any }, pos: any): any?
	for _, child in children do
		if child.Position == pos then
			return child
		end
	end
	return nil
end

local expectedPositions = {
	roblox.Vector3.new(1, 2, 3),
	roblox.Vector3.new(4, 5, 6),
	roblox.Vector3.new(0, 0, 0),
}
local expectedAnchored = {
	[tostring(roblox.Vector3.new(1, 2, 3))] = true,
	[tostring(roblox.Vector3.new(4, 5, 6))] = false,
	[tostring(roblox.Vector3.new(0, 0, 0))] = true,
}

for _, pos in expectedPositions do
	local parPart = findPartByPosition(parChildren, pos)
	if not parPart then
		fail("deserializeParallel: could not find decoded Part with Position " .. tostring(pos))
	end

	local expectedAnchor = expectedAnchored[tostring(pos)]
	assert(
		parPart.Anchored == expectedAnchor,
		"deserializeParallel: expected Anchored == " .. tostring(expectedAnchor) .. " for Position " .. tostring(pos)
	)
	assert(
		parPart.Parent == parFolder,
		"deserializeParallel: expected Part.Parent == parFolder for Position " .. tostring(pos)
	)

	-- Cross-check against the sequential reference decode too.
	local seqPart = findPartByPosition(seqChildren, pos)
	if not seqPart then
		fail("deserialize (reference): could not find decoded Part with Position " .. tostring(pos))
	end
	assert(
		seqPart.Anchored == parPart.Anchored,
		"deserializeParallel and deserialize disagree on Anchored for Position " .. tostring(pos)
	)
end

print(
	"SMOKE TEST PASSED: deserializeParallel reconstructed instances matching deserialize() (sequential reference) for classes/properties/parenting"
)
process.exit(0)
