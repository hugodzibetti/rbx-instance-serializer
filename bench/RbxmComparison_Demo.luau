--!strict

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local Serializer = require("@src/instance/Serializer")
local ArtifactLoader = require("@src/artifacts/Artifact")

-- Generate same large-scene fixture as RealWorldBench
local function generateBuilding(name: string, floors: number): roblox.Instance
	local model = roblox.Instance.new("Model")
	model.Name = name

	for floor = 1, floors do
		local floorPart = roblox.Instance.new("Part")
		floorPart.Name = "Floor_" .. tostring(floor)
		floorPart.Shape = roblox.Enum.PartType.Block
		floorPart.Material = roblox.Enum.Material.Concrete
		floorPart.Size = roblox.Vector3.new(100, 1, 100)
		floorPart.Position = roblox.Vector3.new(0, floor * 10, 0)
		floorPart.CanCollide = true
		floorPart.TopSurface = roblox.Enum.SurfaceType.Smooth
		floorPart.BottomSurface = roblox.Enum.SurfaceType.Smooth
		floorPart.Parent = model

		for x = -40, 40, 20 do
			for z = -40, 40, 20 do
				local column = roblox.Instance.new("Part")
				column.Name = "Column_" .. tostring(x) .. "_" .. tostring(z)
				column.Shape = roblox.Enum.PartType.Block
				column.Material = roblox.Enum.Material.Brick
				column.Size = roblox.Vector3.new(2, 10, 2)
				column.Position = roblox.Vector3.new(x, floor * 10 - 5, z)
				column.CanCollide = true
				column.Parent = model
			end
		end
	end

	return model
end

local function generateLargeScene(): roblox.Instance
	local root = roblox.Instance.new("Folder")
	root.Name = "World"

	for building = 1, 5 do
		local b = generateBuilding("Building_" .. tostring(building), 3)
		b.Parent = root
	end

	return root
end

-- Generate the scene
print("Generating large-scene model...")
local root = generateLargeScene()

-- Load artifact for Lattice
print("Loading artifact...")
local artifactBuf = buffer.fromstring(fs.readFile("data/artifact.bin"))
local artifact = ArtifactLoader.load(artifactBuf)

-- Serialize with Lattice
print("Serializing with Lattice...")
local latticeBuffer = Serializer.serialize({ root }, artifact)
local latticeBytes = buffer.len(latticeBuffer)

-- Serialize as .rbxm
print("Serializing as .rbxm...")
local rbxmBinary = roblox.serializeModel({ root })
local rbxmBytes = #rbxmBinary

print("\n" .. string.rep("=", 70))
print("LATTICE vs .RBXM COMPARISON")
print(string.rep("=", 70))

print("\nFile Sizes:")
print("  .rbxm:    " .. tostring(rbxmBytes) .. " bytes (" .. string.format("%.1f KB", rbxmBytes / 1024) .. ")")
print("  Lattice:  " .. tostring(latticeBytes) .. " bytes (" .. string.format("%.1f KB", latticeBytes / 1024) .. ")")

local ratio = latticeBytes / rbxmBytes
local savings = ((rbxmBytes - latticeBytes) / rbxmBytes) * 100

print("\nComparison:")
if latticeBytes < rbxmBytes then
	print("  ✓ Lattice is " .. string.format("%.1f%%", savings) .. " smaller than .rbxm")
	print("  ✓ Compression ratio: " .. string.format("%.2f×", rbxmBytes / latticeBytes))
else
	print("  Lattice is " .. string.format("%.1f%%", (latticeBytes - rbxmBytes) / rbxmBytes * 100) .. " larger")
end

print("\nPer-Instance Efficiency:")
local function countInstances(inst: roblox.Instance): number
	local count = 1
	for _, child in inst:GetChildren() do
		count += countInstances(child)
	end
	return count
end
local instances = countInstances(root)
print("  Total instances: " .. tostring(instances))
print("  .rbxm:    " .. string.format("%.1f bytes/instance", rbxmBytes / instances))
print("  Lattice:  " .. string.format("%.1f bytes/instance", latticeBytes / instances))

print("\n" .. string.rep("=", 70))
