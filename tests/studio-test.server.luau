--!strict
-- Simple test script to verify Lattice works in Roblox Studio.
-- Sync this via Rojo or paste into a ServerScript in ServerScriptService.

local Lattice = require(game:GetService("ReplicatedStorage"):WaitForChild("Lattice"))

print("[Lattice Test] Starting...")

-- Test 1: Vector3
local original = Vector3.new(1.5, 2.5, 3.5)
local writer = Lattice.Writer.new()
Lattice.Serde.vector3.write(writer, original)
local data = writer:getBuffer()
local reader = Lattice.Reader.new(data)
local deserialized = Lattice.Serde.vector3.read(reader)
assert(original == deserialized, `Vector3 mismatch: {original} vs {deserialized}`)
print(`✓ Vector3: {original} -> {deserialized}`)

-- Test 2: Color3
local color = Color3.fromRGB(255, 128, 64)
local writer2 = Lattice.Writer.new()
Lattice.Serde.color3.write(writer2, color)
local data2 = writer2:getBuffer()
local reader2 = Lattice.Reader.new(data2)
local decolor = Lattice.Serde.color3.read(reader2)
assert(color == decolor, `Color3 mismatch: {color} vs {decolor}`)
print(`✓ Color3: {color} -> {decolor}`)

-- Test 3: CFrame
local cf = CFrame.new(1, 2, 3) * CFrame.Angles(0, math.pi / 4, 0)
local writer3 = Lattice.Writer.new()
Lattice.Serde.cframe.write(writer3, cf)
local data3 = writer3:getBuffer()
local reader3 = Lattice.Reader.new(data3)
local decf = Lattice.Serde.cframe.read(reader3)
-- CFrame comparison with tolerance for floating point
assert((cf.Position - decf.Position).Magnitude < 0.01, `CFrame position mismatch`)
print(`✓ CFrame: {cf} -> {decf}`)

print("[Lattice Test] All tests passed! ✓")
