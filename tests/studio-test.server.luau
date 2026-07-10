--!strict
-- Codec round-trip smoke test to verify Lattice works in real Roblox Studio (not
-- just Lune's mocked @lune/roblox bindings). Sync via Rojo or run inline through
-- the Roblox_Studio MCP server's execute_luau tool (see .claude/skills/verify).

local Lattice = require(game:GetService("ReplicatedStorage"):WaitForChild("Lattice"))

-- Lattice.Serde is an id-keyed registry (codecIdToModule/codecNameToId), not a
-- flat name -> codec map, since that's what the artifact/instance layer needs
-- internally. This resolves a codec by name the same way getCodec.luau does.
local function getCodec(name: string): any
	local id = Lattice.Serde.codecNameToId[name]
	return Lattice.Serde.codecIdToModule[id]
end

local function roundTrip(name: string, codec: any, value: any, isEqual: (a: any, b: any) -> boolean)
	local writer = Lattice.Writer.new()
	codec.write(writer, value)
	local data = writer:toBuffer()
	local reader = Lattice.Reader.new(data)
	local result = codec.read(reader)
	assert(isEqual(value, result), `{name} mismatch: {tostring(value)} vs {tostring(result)}`)
	print(`✓ {name}: {tostring(value)} -> {tostring(result)}`)
end

local function eq(a: any, b: any): boolean
	return a == b
end

print("[Lattice Test] Starting...")

roundTrip("f32", getCodec("f32"), 3.5, eq)
roundTrip("f64", getCodec("f64"), 3.14159265358979, eq)
roundTrip("bool", getCodec("bool"), true, eq)
roundTrip("string", getCodec("string"), "hello lattice", eq)
roundTrip("vector2", getCodec("vector2"), Vector2.new(1.5, -2.25), eq)
roundTrip("vector3", getCodec("vector3"), Vector3.new(1.5, 2.5, 3.5), eq)
roundTrip("color3", getCodec("color3"), Color3.fromRGB(255, 128, 64), eq)
roundTrip("brickColor", getCodec("brickColor"), BrickColor.new("Bright red"), eq)
roundTrip("udim", getCodec("udim"), UDim.new(0.5, 10), eq)
roundTrip("udim2", getCodec("udim2"), UDim2.new(0.5, 10, 0.25, -5), eq)
roundTrip("rect", getCodec("rect"), Rect.new(0, 0, 100, 200), eq)
roundTrip("numberRange", getCodec("numberRange"), NumberRange.new(1, 5), eq)
roundTrip("ray", getCodec("ray"), Ray.new(Vector3.new(0, 0, 0), Vector3.new(1, 0, 0)), function(a, b)
	return a.Origin == b.Origin and a.Direction == b.Direction
end)
if UniqueId and UniqueId.new then
	roundTrip("uniqueId", getCodec("uniqueId"), UniqueId.new(), function(a, b)
		return tostring(a) == tostring(b)
	end)
else
	print("~ uniqueId: skipped (UniqueId.new not available in this Studio version)")
end
-- enumItem codec stores the stable .Value (Roblox's backward-compat guarantee), not the EnumItem itself.
roundTrip("enumItem", getCodec("enumItem"), Enum.Material.Wood.Value, eq)
roundTrip("numberSequence", getCodec("numberSequence"), NumberSequence.new(0, 1), function(a, b)
	return #a.Keypoints == #b.Keypoints
end)
roundTrip("colorSequence", getCodec("colorSequence"), ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)), function(a, b)
	return #a.Keypoints == #b.Keypoints
end)
roundTrip(
	"physicalProperties",
	getCodec("physicalProperties"),
	PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1),
	function(a, b)
		return a.Density == b.Density and a.Friction == b.Friction
	end
)

local cf = CFrame.new(1, 2, 3) * CFrame.Angles(0, math.pi / 4, 0)
roundTrip("cframe", getCodec("cframe"), cf, function(a, b)
	return (a.Position - b.Position).Magnitude < 0.01
end)

print("[Lattice Test] All tests passed! ✓")
