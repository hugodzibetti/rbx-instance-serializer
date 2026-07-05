--!strict
--!native
--!optimize 2

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Lattice = require("@src")
local Timer = require("./Timer")
local Report = require("./Report")

local function buildSmallScene(): ({ any }, number)
	local model = roblox.Instance.new("Model")
	model.Name = "SmallScene"

	local count = 1
	for i = 1, 10 do
		local part = roblox.Instance.new("Part")
		part.Name = "SmallPart_" .. tostring(i)
		part.Anchored = (i % 2 == 0)
		part.Size = roblox.Vector3.new(i, i * 2, i * 3)
		part.Position = roblox.Vector3.new(i * 10, i * 1.5, -i)
		part.Material = if i % 2 == 0 then roblox.Enum.Material.Wood else roblox.Enum.Material.Plastic
		part.Parent = model
		count += 1
	end

	return { model }, count
end

local function buildLargeScene(): ({ any }, number)
	local root = roblox.Instance.new("Folder")
	root.Name = "LargeScene"

	local materials = { roblox.Enum.Material.Wood, roblox.Enum.Material.Plastic, roblox.Enum.Material.Concrete, roblox.Enum.Material.Metal }
	local count = 1

	for g = 1, 50 do
		local group = roblox.Instance.new("Model")
		group.Name = "Group_" .. tostring(g)
		group.Parent = root
		count += 1

		for i = 1, 9 do
			local part = roblox.Instance.new("Part")
			part.Name = "Part_" .. tostring(g) .. "_" .. tostring(i)
			part.Anchored = ((g + i) % 2 == 0)
			part.Size = roblox.Vector3.new(i, g, i + g)
			part.Position = roblox.Vector3.new(g * 5, i * 3, g - i)
			part.Material = materials[((g + i) % #materials) + 1]
			part.Parent = group
			count += 1
		end
	end

	return { root }, count
end

local scenarios = {
	{ name = "small (11 instances)", build = buildSmallScene, iterations = 100 },
	{ name = "large (501 instances)", build = buildLargeScene, iterations = 10 },
}

local function run()
	print("Loading artifact...")
	local artifactBuf = buffer.fromstring(fs.readFile("data/artifact.bin"))
	local artifact = Lattice.loadArtifact(artifactBuf)
	print("Artifact loaded.\n")

	local results = {}

	for _, scenario in scenarios do
		local roots, instanceCount = scenario.build()

		local lastBuf: buffer? = nil
		local serializeFn = function()
			lastBuf = Lattice.serialize(roots, artifact)
		end
		local serializeResult = Timer.run(scenario.iterations, serializeFn)
		assert(lastBuf, "serialize produced no buffer for scenario: " .. scenario.name)
		local totalBytes = buffer.len(lastBuf :: buffer)

		local serializedBuf = lastBuf :: buffer
		local deserializeFn = function()
			Lattice.deserialize(serializedBuf, artifact)
		end
		local deserializeResult = Timer.run(scenario.iterations, deserializeFn)

		table.insert(results, {
			name = scenario.name,
			writeOpsPerSecond = serializeResult.opsPerSecond,
			readOpsPerSecond = deserializeResult.opsPerSecond,
			totalBytes = totalBytes,
			avgBytesPerValue = totalBytes / instanceCount,
			sampleCount = instanceCount,
		})
	end

	Report.printTable(results)
end

run()
