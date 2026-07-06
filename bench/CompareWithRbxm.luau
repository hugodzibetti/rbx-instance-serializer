--!strict

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local Deserializer = require("@src/instance/Deserializer")
local Artifact = require("@src/artifacts/Artifact")

print("\n" .. string.rep("=", 70))
print("LATTICE vs .RBXM COMPARISON (Real Models)")
print(string.rep("=", 70))

-- Load artifact
print("\nLoading artifact...")
local artifactBuf = buffer.fromstring(fs.readFile("data/artifact.bin"))
local artifact = Artifact.load(artifactBuf)

-- Compare existing .lattice file
local latticeFile = "bench/results/large-scene.lattice"
print("\nTesting: " .. latticeFile)

-- Get Lattice file size
local latticeBytes = #fs.readFile(latticeFile)
print("  Lattice size: " .. tostring(latticeBytes) .. " bytes (" .. string.format("%.1f KB", latticeBytes / 1024) .. ")")

-- Deserialize and re-serialize as .rbxm
print("  Deserializing Lattice file...")
local latticeBuf = buffer.fromstring(fs.readFile(latticeFile))
local roots = Deserializer.deserialize(latticeBuf, artifact)

print("  Serializing as .rbxm...")
local rbxmBinary = roblox.serializeModel(roots)
local rbxmBytes = #rbxmBinary

-- Compare
print("\n" .. string.rep("-", 70))
print("RESULTS:")
print(string.rep("-", 70))
print("\nFile Sizes:")
print("  Lattice:  " .. tostring(latticeBytes) .. " bytes (" .. string.format("%.1f KB", latticeBytes / 1024) .. ")")
print("  .rbxm:    " .. tostring(rbxmBytes) .. " bytes (" .. string.format("%.1f KB", rbxmBytes / 1024) .. ")")

local savings = ((rbxmBytes - latticeBytes) / rbxmBytes) * 100
local ratio = rbxmBytes / latticeBytes

print("\n  Lattice is " .. string.format("%.1f%%", savings) .. " smaller than .rbxm")
print("  Compression ratio: " .. string.format("%.2f×", ratio))

-- Count instances
local function countInstances(inst: roblox.Instance): number
	local count = 1
	for _, child in inst:GetChildren() do
		count += countInstances(child)
	end
	return count
end

local totalInstances = 0
for _, root in roots do
	totalInstances += countInstances(root)
end

print("\nPer-Instance Metrics:")
print("  Total instances: " .. tostring(totalInstances))
print("  Lattice:  " .. string.format("%.1f bytes/instance", latticeBytes / totalInstances))
print("  .rbxm:    " .. string.format("%.1f bytes/instance", rbxmBytes / totalInstances))

print("\n" .. string.rep("=", 70))
