--!strict

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local Lattice = require("@src/instance/Deserializer")
local Serializer = require("@src/instance/Serializer")
local ArtifactLoader = require("@src/artifacts/Loader")

local function readRbxm(path: string): any
	local buf = fs.readFile(path)
	return roblox.Instance.fromReplicaTree(roblox.deserializeModel(buf)[1])
end

local function runComparison(rbxmPath: string)
	print("\n" .. string.rep("=", 70))
	print("Lattice vs .rbxm Comparison")
	print(string.rep("=", 70))

	if not fs.isFile(rbxmPath) then
		error("File not found: " .. rbxmPath)
	end

	print("File: " .. rbxmPath)

	-- Load artifact
	print("Loading artifact...")
	local artifact = ArtifactLoader.load(roblox)

	-- Get .rbxm size
	local rbxmBytes = #fs.readFile(rbxmPath)
	print("RBXM size: " .. string.format("%,d bytes (%.1f KB)", rbxmBytes, rbxmBytes / 1024))

	-- Deserialize .rbxm
	print("Deserializing .rbxm...")
	local roots = { readRbxm(rbxmPath) }

	-- Serialize with Lattice
	print("Serializing with Lattice...")
	local latticeBuffer = Serializer.serialize(roots, artifact)
	local latticeBytes = #latticeBuffer

	print("Lattice size: " .. string.format("%,d bytes (%.1f KB)", latticeBytes, latticeBytes / 1024))

	local ratio = latticeBytes / rbxmBytes
	local savings = ((rbxmBytes - latticeBytes) / rbxmBytes) * 100

	print()
	if latticeBytes < rbxmBytes then
		print("✓ Lattice is " .. string.format("%.1f%%", savings) .. " smaller")
		print("  Ratio: " .. string.format("%.2f", ratio) .. "x")
	else
		print("✗ Lattice is " .. string.format("%.1f%%", (latticeBytes - rbxmBytes) / rbxmBytes * 100) .. " larger")
	end

	print()
	print("Instance breakdown:")
	local totalInstances = 0
	for classId, bucket in artifact.classById do
		if bucket then
			-- Count instances by walking the roots
			-- This is approximate - just show instance count from roots
		end
	end

	return {
		rbxmBytes = rbxmBytes,
		latticeBytes = latticeBytes,
		ratio = ratio,
		savings = savings,
	}
end

-- If run directly with an argument
local args = { ... }
if #args > 0 then
	local result = runComparison(args[1])
	os.exit(if result.latticeBytes < result.rbxmBytes then 0 else 1)
else
	return {
		runComparison = runComparison,
	}
end
