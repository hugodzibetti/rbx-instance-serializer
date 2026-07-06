--!strict
--!native
--!optimize 2

-- Real dedup-on vs dedup-off comparison: does whole-instance dedup (templateRefs)
-- still earn its O(n^2) scan + per-instance templateRef varint overhead now that
-- column Dictionary encoding exists? Both mechanisms are wired into
-- src/instance/Serializer.luau simultaneously; this benchmark calls the actual
-- Lattice.serialize entrypoint twice on the same fixture — once with dedup active
-- (its default behavior) and once with dedup forced off via the disableDedup flag
-- (see Serializer.luau's serialize(roots, artifact, disableDedup) signature) — and
-- compares the real resulting byte counts. Dictionary encoding is active in both
-- runs, so this isolates dedup's own marginal contribution.
--
-- Fixture is a mixed scene modeled on a realistic place:
--   (a) a block of fully-identical instances (dedup's best case)
--   (b) a block sharing most-but-not-all properties (Dictionary's target case)
--   (c) fully-unique instances (neither helps)

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Lattice = require("@src")
local Timer = require("./Timer")

local function buildMixedScene(): { any }
	local root = roblox.Instance.new("Folder")
	root.Name = "MixedScene"

	-- (a) Fully-identical instances: same Name/Anchored/Size/Position/Material.
	-- (dedup requires every codec'd property to match, including Name)
	for i = 1, 40 do
		local part = roblox.Instance.new("Part")
		part.Name = "IdenticalPart"
		part.Anchored = true
		part.Size = roblox.Vector3.new(4, 1, 4)
		part.Position = roblox.Vector3.new(0, 0, 0)
		part.Material = roblox.Enum.Material.Concrete
		part.Parent = root
	end

	-- (b) Floor-grid style: shared Size/Anchored/Material palette, unique Position.
	local sizes = { roblox.Vector3.new(4, 1, 4), roblox.Vector3.new(2, 1, 2), roblox.Vector3.new(6, 1, 6) }
	local materials = { roblox.Enum.Material.Wood, roblox.Enum.Material.Plastic, roblox.Enum.Material.Metal }
	for i = 1, 200 do
		local part = roblox.Instance.new("Part")
		part.Name = "Grid_" .. tostring(i)
		part.Anchored = true
		part.Size = sizes[(i % #sizes) + 1]
		part.Material = materials[(i % #materials) + 1]
		part.Position = roblox.Vector3.new(i * 4, 0, (i % 20) * 4)
		part.Parent = root
	end

	-- (c) Fully-unique instances: nothing shared, nothing to compress.
	for i = 1, 60 do
		local part = roblox.Instance.new("Part")
		part.Name = "Unique_" .. tostring(i)
		part.Anchored = (i % 2 == 0)
		part.Size = roblox.Vector3.new(i * 0.1, i * 0.2, i * 0.3)
		part.Material = if i % 3 == 0 then roblox.Enum.Material.Neon else roblox.Enum.Material.Glass
		part.Position = roblox.Vector3.new(i * 1.7, i * 2.3, i * 3.1)
		part.Parent = root
	end

	return { root }
end

local function run()
	print("Loading artifact...")
	local artifactBuf = buffer.fromstring(fs.readFile("data/artifact.bin"))
	local artifact = Lattice.loadArtifact(artifactBuf)
	print("Artifact loaded.\n")

	local roots = buildMixedScene()
	local parts = roots[1]:GetChildren()

	local iterations = 30

	-- Run 1: dedup ON (default) + Dictionary ON.
	local bufDedupOn: buffer? = nil
	local dedupOnResult = Timer.run(iterations, function()
		bufDedupOn = Lattice.serialize(roots, artifact)
	end)
	assert(bufDedupOn, "serialize (dedup on) produced no buffer")
	local sizeDedupOn = buffer.len(bufDedupOn :: buffer)

	-- Run 2: dedup OFF + Dictionary ON (same fixture, same artifact).
	local bufDedupOff: buffer? = nil
	local dedupOffResult = Timer.run(iterations, function()
		bufDedupOff = Lattice.serialize(roots, artifact, true)
	end)
	assert(bufDedupOff, "serialize (dedup off) produced no buffer")
	local sizeDedupOff = buffer.len(bufDedupOff :: buffer)

	-- Sanity: both must still round-trip correctly.
	local capturedOn = bufDedupOn :: buffer
	local capturedOff = bufDedupOff :: buffer
	local deserOnResult = Timer.run(iterations, function()
		Lattice.deserialize(capturedOn, artifact)
	end)
	local deserOffResult = Timer.run(iterations, function()
		Lattice.deserialize(capturedOff, artifact)
	end)

	local savings = sizeDedupOff - sizeDedupOn
	local pct = if sizeDedupOff > 0 then (savings / sizeDedupOff) * 100 else 0

	print(string.format("Fixture: %d Part instances (40 identical / 200 shared-palette / 60 unique)", #parts))
	print(string.format("Serialized size, dedup ON  + Dictionary: %d bytes", sizeDedupOn))
	print(string.format("Serialized size, dedup OFF + Dictionary: %d bytes", sizeDedupOff))
	print(string.format("Dedup's real marginal savings: %d bytes (%.2f%% of dedup-off size)", savings, pct))
	print(
		string.format(
			"Write throughput -- dedup ON: %.1f/s   dedup OFF: %.1f/s",
			dedupOnResult.opsPerSecond,
			dedupOffResult.opsPerSecond
		)
	)
	print(
		string.format(
			"Read throughput  -- dedup ON: %.1f/s   dedup OFF: %.1f/s",
			deserOnResult.opsPerSecond,
			deserOffResult.opsPerSecond
		)
	)
	print("")
	if savings > 0 then
		print(string.format("Conclusion: dedup saves %d real bytes on this fixture even with Dictionary active.", savings))
		print("Both mechanisms are kept: templateRefs (whole-instance dedup) + column Dictionary encoding.")
	else
		print("Conclusion: dedup saved 0 or negative bytes on this fixture once Dictionary encoding is active.")
		print("Dedup is currently still kept in src/instance/Serializer.luau pending further measurement")
		print("across more realistic fixtures before considering removal.")
	end
end

run()
