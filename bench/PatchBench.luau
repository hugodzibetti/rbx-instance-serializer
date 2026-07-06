--!strict
--!native
--!optimize 2

-- Benchmark fixture: a realistic edit session over ~1000 instances (10
-- moved/property-changed, 5 added, 2 removed), comparing full-resnapshot
-- size/time against incremental patch size/time. See
-- docs/superpowers/specs/2026-07-05-incremental-delta-encoding-design.md's
-- "Size expectations" section, which calls for measuring this rather than
-- assuming the win.
--
-- Runs the session twice: once with UniqueId explicitly assigned to every
-- instance (simulating realistic Roblox Studio-authored content, where
-- UniqueId is auto-populated and src/patch/Identity.luau's UniqueId-based
-- matching applies), and once without (forcing the positional-path
-- fallback everywhere -- Lune's `roblox` binding does not auto-generate a
-- real UniqueId; see Identity.luau's ZERO_UNIQUE_ID_STRING note). Reporting
-- both honestly matters here: the fallback case is measurably worse (see
-- printed output), which is an expected, documented limitation of
-- positional matching under churn (removals/reorders shift sibling
-- indices for every later same-class sibling), not a bug.

local roblox = require("@lune/roblox")
local serde = require("@src/serde")
local instance = require("@src/instance")
local diffModule = require("@src/patch/diff")
local Timer = require("./Timer")

math.randomseed(0)

local mockArtifact = {
	version = 1,
	classes = {},
	classByName = {},
	classById = {
		[1] = {
			id = 1,
			name = "Folder",
			properties = {
				{ name = "Parent", codecId = 26, codec = serde.codecIdToModule[26], default = 0 },
				{ name = "Name", codecId = 3, codec = serde.codecIdToModule[3], default = "Folder" },
				{
					name = "UniqueId",
					codecId = 24,
					codec = serde.codecIdToModule[24],
					default = roblox.UniqueId.fromString(buffer.tostring(buffer.create(16))),
				},
			},
		},
		[2] = {
			id = 2,
			name = "Part",
			properties = {
				{ name = "Parent", codecId = 26, codec = serde.codecIdToModule[26], default = 0 },
				{ name = "Name", codecId = 3, codec = serde.codecIdToModule[3], default = "Part" },
				{ name = "Anchored", codecId = 2, codec = serde.codecIdToModule[2], default = false },
				{
					name = "Position",
					codecId = 17,
					codec = serde.codecIdToModule[17],
					default = roblox.Vector3.new(0, 0, 0),
				},
				{
					name = "UniqueId",
					codecId = 24,
					codec = serde.codecIdToModule[24],
					default = roblox.UniqueId.fromString(buffer.tostring(buffer.create(16))),
				},
			},
		},
	},
}
mockArtifact.classByName["Folder"] = mockArtifact.classById[1]
mockArtifact.classByName["Part"] = mockArtifact.classById[2]

local N = 1000
local MOVED = 10
local ADDED = 5
local REMOVED = 2
local ITERATIONS = 3

local function runSession(withUniqueId: boolean)
	local root = roblox.Instance.new("Folder")
	root.Name = "Root"
	if withUniqueId then
		pcall(function()
			root.UniqueId = roblox.UniqueId.new()
		end)
	end

	for i = 1, N do
		local p = roblox.Instance.new("Part")
		p.Name = "Part_" .. tostring(i)
		p.Parent = root
		p.Anchored = (i % 2 == 0)
		p.Position = roblox.Vector3.new(i, i * 2, i * 3)
		if withUniqueId then
			pcall(function()
				p.UniqueId = roblox.UniqueId.new()
			end)
		end
	end

	local baselineBuf = instance.serialize({ root }, mockArtifact :: any)

	-- Simulate an edit session against a fresh deserialize of the baseline
	-- (this is the "current live tree" a real caller would have).
	local currentRoots = instance.deserialize(baselineBuf, mockArtifact :: any)
	local currentRoot = currentRoots[1]

	local byName = {}
	for _, c in currentRoot:GetChildren() do
		byName[c.Name] = c
	end

	-- 10 moved/property-changed instances.
	for i = 1, MOVED do
		local p = byName["Part_" .. tostring(i * 37 % N + 1)]
		if p then
			p.Position = p.Position + roblox.Vector3.new(100, 100, 100)
		end
	end

	-- 2 removed instances.
	for i = 1, REMOVED do
		local p = byName["Part_" .. tostring(500 + i)]
		if p then
			p.Parent = nil
			p:Destroy()
		end
	end

	-- 5 added instances.
	for i = 1, ADDED do
		local p = roblox.Instance.new("Part")
		p.Name = "NewPart_" .. tostring(i)
		p.Parent = currentRoot
		p.Anchored = true
		p.Position = roblox.Vector3.new(-i, -i, -i)
		if withUniqueId then
			pcall(function()
				p.UniqueId = roblox.UniqueId.new()
			end)
		end
	end

	-- Full re-serialize cost (the status quo being compared against).
	local fullResult = Timer.run(ITERATIONS, function()
		instance.serialize({ currentRoot }, mockArtifact :: any)
	end)
	local fullBuf = instance.serialize({ currentRoot }, mockArtifact :: any)
	local fullBytes = buffer.len(fullBuf)

	-- Patch (diff) cost.
	local patchBuf: buffer
	local usedFallbackCount = 0
	local patchResult = Timer.run(ITERATIONS, function()
		local result = diffModule.diff(baselineBuf, mockArtifact :: any, { currentRoot })
		patchBuf = result.patch
		usedFallbackCount = result.usedFallbackCount
	end)
	local patchBytes = buffer.len(patchBuf :: buffer)
	local baselineBytes = buffer.len(baselineBuf)

	print(string.format(
		"\n=== %s ===",
		if withUniqueId then "WITH UniqueId (realistic Studio content)" else "WITHOUT UniqueId (positional fallback forced)"
	))
	print(string.format("Instances: %d baseline (+%d added, -%d removed, ~%d changed)", N, ADDED, REMOVED, MOVED))
	print(string.format("Fallback-matched instances: %d / %d", usedFallbackCount, N + 1))
	print(string.format("Baseline snapshot size:   %8d bytes", baselineBytes))
	print(string.format(
		"Full re-serialize size:   %8d bytes  (%.2f ops/sec, %.4f ms/op)",
		fullBytes,
		fullResult.opsPerSecond,
		1000 / fullResult.opsPerSecond
	))
	print(string.format(
		"Patch size:               %8d bytes  (%.2f ops/sec, %.4f ms/op)",
		patchBytes,
		patchResult.opsPerSecond,
		1000 / patchResult.opsPerSecond
	))
	print(string.format(
		"Size delta:               %.1f%% %s than full re-serialize",
		math.abs(1 - patchBytes / fullBytes) * 100,
		if patchBytes < fullBytes then "smaller" else "LARGER"
	))
end

runSession(true)
runSession(false)
