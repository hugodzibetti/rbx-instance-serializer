--!strict

local roblox = require("@lune/roblox")

math.randomseed(0)

local function rf(min: number, max: number): number
	return min + math.random() * (max - min)
end

local function ri(min: number, max: number): number
	return math.floor(rf(min, max + 0.999))
end

local function escapeString(s: string): string
	return string.format("%q", s):gsub("\\\n", "\\n")
end

local function serializeV3(v: {X: number, Y: number, Z: number}): string
	return string.format("roblox.Vector3.new(%.17g, %.17g, %.17g)", v.X, v.Y, v.Z)
end

local function serializeV2(v: {X: number, Y: number}): string
	return string.format("roblox.Vector2.new(%.17g, %.17g)", v.X, v.Y)
end

local function serializeCFrame(cf: {GetComponents: () -> (number, number, number, number, number, number, number, number, number, number, number, number)}): string
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return string.format("roblox.CFrame.new(%.17g, %.17g, %.17g, %.17g, %.17g, %.17g, %.17g, %.17g, %.17g, %.17g, %.17g, %.17g)",
		x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

local function serializeColor3(c: {R: number, G: number, B: number}): string
	return string.format("roblox.Color3.new(%.17g, %.17g, %.17g)", c.R, c.G, c.B)
end

local function serializeEnumItem(item: {Value: number, Name: string, EnumType: Enum}): string
	local enumName = tostring(item.EnumType)
	return string.format("roblox.%s.%s", enumName, item.Name)
end

local function serializeBrickColor(bc: {Number: number}): string
	return string.format("roblox.BrickColor.new(%d)", bc.Number)
end

local function serializeUDim(u: {Scale: number, Offset: number}): string
	return string.format("roblox.UDim.new(%.17g, %d)", u.Scale, u.Offset)
end

local function serializeUDim2(u: {X: {Scale: number, Offset: number}, Y: {Scale: number, Offset: number}}): string
	return string.format("roblox.UDim2.new(%s, %s)", serializeUDim(u.X), serializeUDim(u.Y))
end

local function serializeRect(r: {Min: {X: number, Y: number}, Max: {X: number, Y: number}}): string
	return string.format("roblox.Rect.new(%d, %d, %d, %d)", r.Min.X, r.Min.Y, r.Max.X, r.Max.Y)
end

local function serializeNumberRange(nr: {Min: number, Max: number}): string
	return string.format("roblox.NumberRange.new(%.17g, %.17g)", nr.Min, nr.Max)
end

local function serializeNSK(kp: {Time: number, Value: number, Envelope: number}): string
	return string.format("roblox.NumberSequenceKeypoint.new(%.17g, %.17g, %.17g)", kp.Time, kp.Value, kp.Envelope)
end

local function serializeCSK(kp: {Time: number, Value: {R: number, G: number, B: number}}): string
	return string.format("roblox.ColorSequenceKeypoint.new(%.17g, %s)", kp.Time, serializeColor3(kp.Value))
end

local function serializeNumberSequence(ns: {Keypoints: {any}}): string
	local parts = {}
	for _, kp in ns.Keypoints do
		table.insert(parts, serializeNSK(kp))
	end
	return "roblox.NumberSequence.new({" .. table.concat(parts, ", ") .. "})"
end

local function serializeColorSequence(cs: {Keypoints: {any}}): string
	local parts = {}
	for _, kp in cs.Keypoints do
		table.insert(parts, serializeCSK(kp))
	end
	return "roblox.ColorSequence.new({" .. table.concat(parts, ", ") .. "})"
end

local function serializePhysicalProperties(pp: {Density: number, Friction: number, Elasticity: number, FrictionWeight: number, ElasticityWeight: number}): string
	return string.format("roblox.PhysicalProperties.new(%.17g, %.17g, %.17g, %.17g, %.17g)",
		pp.Density, pp.Friction, pp.Elasticity, pp.FrictionWeight, pp.ElasticityWeight)
end

local function serializeFont(f: {Family: string, Weight: {Name: string}, Style: {Name: string}}): string
	return string.format("roblox.Font.new(%q, roblox.Enum.FontWeight.%s, roblox.Enum.FontStyle.%s)",
		f.Family, f.Weight.Name, f.Style.Name)
end

local function serializeContent(c: {SourceType: {Name: string}, Uri: string?}): string
	if c.SourceType.Name == "None" then
		return "roblox.Content.none"
	end
	return string.format("roblox.Content.fromUri(%q)", c.Uri)
end

-- Generate values -----------------------------------------------------------

local VECTOR3_COUNT = 2000
local CFRAME_COUNT = 2000
local COLOR3_COUNT = 1000
local FLOAT_COUNT = 1500
local BOOL_COUNT = 800
local STRING_COUNT = 1000
local ENUM_COUNT = 600
local BRICK_COUNT = 600
local NS_COUNT = 200
local CS_COUNT = 200
local NR_COUNT = 300
local UDIM2_COUNT = 200
local VECTOR2_COUNT = 200
local PP_COUNT = 150
local FONT_COUNT = 100
local CONTENT_COUNT = 100
local RECT_COUNT = 100

-- Vector3
local vector3s = {}
for _ = 1, VECTOR3_COUNT do
	table.insert(vector3s, roblox.Vector3.new(rf(-1000, 1000), rf(-1000, 1000), rf(-1000, 1000)))
end

-- CFrame: mix of identity, axis-aligned, arbitrary
local cframes = {}
for i = 1, CFRAME_COUNT do
	local pos = roblox.Vector3.new(rf(-1000, 1000), rf(-1000, 1000), rf(-1000, 1000))
	local mod = i % 3
	if mod == 0 then
		table.insert(cframes, roblox.CFrame.new(pos))
	elseif mod == 1 then
		local angle = math.rad(ri(0, 3) * 90)
		local axis = ri(0, 2)
		local rx, ry, rz = if axis == 0 then angle else 0, if axis == 1 then angle else 0, if axis == 2 then angle else 0
		table.insert(cframes, roblox.CFrame.new(pos) * roblox.CFrame.Angles(rx, ry, rz))
	else
		table.insert(cframes, roblox.CFrame.new(pos) * roblox.CFrame.Angles(math.rad(rf(0, 360)), math.rad(rf(0, 360)), math.rad(rf(0, 360))))
	end
end

-- Color3
local color3s = {}
for _ = 1, COLOR3_COUNT do
	table.insert(color3s, roblox.Color3.new(rf(0, 1), rf(0, 1), rf(0, 1)))
end

-- f32/f64 (same numeric values)
local floats = {}
for _ = 1, FLOAT_COUNT do
	table.insert(floats, rf(-1000, 1000))
end

-- bool
local bools = {}
for i = 1, BOOL_COUNT do
	table.insert(bools, i % 2 == 0)
end

-- string
local strings = {}
local namePrefixes = { "Part", "Model", "Baseplate", "Spawn", "Light", "Effect", "Handle", "Root", "Tip", "Joint" }
for i = 1, STRING_COUNT do
	table.insert(strings, namePrefixes[ri(1, #namePrefixes)] .. "_" .. tostring(i))
end

-- EnumItem (Material)
local materials = {}
for _, item in roblox.Enum.Material:GetEnumItems() do
	table.insert(materials, item)
end
local enumItems = {}
for i = 1, ENUM_COUNT do
	table.insert(enumItems, materials[ri(1, #materials)])
end

-- BrickColor
local brickColors = {}
for i = 1, BRICK_COUNT do
	table.insert(brickColors, roblox.BrickColor.new(ri(1, 208)))
end

-- NumberSequence
local numberSequences = {}
for _ = 1, NS_COUNT do
	local kpCount = ri(2, 5)
	local kps = {}
	for j = 1, kpCount do
		table.insert(kps, roblox.NumberSequenceKeypoint.new((j - 1) / (kpCount - 1), rf(-10, 10), rf(0, 5)))
	end
	table.insert(numberSequences, roblox.NumberSequence.new(kps))
end

-- ColorSequence
local colorSequences = {}
for _ = 1, CS_COUNT do
	local kpCount = ri(2, 5)
	local kps = {}
	for j = 1, kpCount do
		table.insert(kps, roblox.ColorSequenceKeypoint.new((j - 1) / (kpCount - 1), roblox.Color3.new(rf(0, 1), rf(0, 1), rf(0, 1))))
	end
	table.insert(colorSequences, roblox.ColorSequence.new(kps))
end

-- NumberRange
local numberRanges = {}
for _ = 1, NR_COUNT do
	local a = rf(-100, 100)
	local b = rf(-100, 100)
	table.insert(numberRanges, roblox.NumberRange.new(math.min(a, b), math.max(a, b)))
end

-- UDim2
local udim2s = {}
for _ = 1, UDIM2_COUNT do
	table.insert(udim2s, roblox.UDim2.new(
		roblox.UDim.new(rf(0, 1), ri(-500, 500)),
		roblox.UDim.new(rf(0, 1), ri(-500, 500))
	))
end

-- Vector2
local vector2s = {}
for _ = 1, VECTOR2_COUNT do
	table.insert(vector2s, roblox.Vector2.new(rf(-1000, 1000), rf(-1000, 1000)))
end

-- PhysicalProperties
local physicalPropertiesList = {}
for _ = 1, PP_COUNT do
	table.insert(physicalPropertiesList, roblox.PhysicalProperties.new(rf(0.01, 10), rf(0, 1), rf(0, 1), rf(0, 100), rf(0, 100)))
end

-- Font
local fontWeights = {}
for _, item in roblox.Enum.FontWeight:GetEnumItems() do
	table.insert(fontWeights, item)
end
local fontStyles = {}
for _, item in roblox.Enum.FontStyle:GetEnumItems() do
	table.insert(fontStyles, item)
end
local fontFamilies = {
	"rbxasset://fonts/families/SourceSansPro.json",
	"rbxasset://fonts/families/Roboto.json",
	"rbxasset://fonts/families/Oswald.json",
}
local fonts = {}
for i = 1, FONT_COUNT do
	table.insert(fonts, roblox.Font.new(
		fontFamilies[ri(1, #fontFamilies)],
		fontWeights[ri(1, #fontWeights)],
		fontStyles[ri(1, #fontStyles)]
	))
end

-- Content
local contentUris = {
	"rbxassetid://123456",
	"rbxassetid://789012",
	"rbxassetid://345678",
	"rbxassetid://901234",
}
local contents = {}
for i = 1, CONTENT_COUNT do
	if i % 5 == 0 then
		table.insert(contents, roblox.Content.none)
	else
		table.insert(contents, roblox.Content.fromUri(contentUris[ri(1, #contentUris)]))
	end
end

-- Rect
local rects = {}
for _ = 1, RECT_COUNT do
	local x1 = ri(-1000, 1000)
	local y1 = ri(-1000, 1000)
	table.insert(rects, roblox.Rect.new(x1, y1, x1 + ri(10, 500), y1 + ri(10, 500)))
end

-- NumberSequenceKeypoint (extracted from numberSequences)
local nskps = {}
for _, ns in numberSequences do
	for _, kp in ns.Keypoints do
		table.insert(nskps, kp)
	end
end

-- ColorSequenceKeypoint (extracted from colorSequences)
local cskps = {}
for _, cs in colorSequences do
	for _, kp in cs.Keypoints do
		table.insert(cskps, kp)
	end
end

-- UDim (extracted from udim2s)
local udims = {}
for _, u2 in udim2s do
	table.insert(udims, u2.X)
	table.insert(udims, u2.Y)
end

-- Write to file -------------------------------------------------------------

local function writeArray(lines: {string}, name: string, values: {any}, serializeFn: (any) -> string)
	table.insert(lines, "\t" .. name .. " = {")
	for i, v in values do
		local sep = if i == #values then "" else ","
		table.insert(lines, "\t\t" .. serializeFn(v) .. sep)
	end
	table.insert(lines, "\t},")
end

local lines = {
	"local roblox = require(\"@lune/roblox\")",
	"return {",
}

writeArray(lines, "vector3", vector3s, serializeV3)
writeArray(lines, "cframe", cframes, serializeCFrame)
writeArray(lines, "color3", color3s, serializeColor3)
writeArray(lines, "f32", floats, function(v: number): string return string.format("%.17g", v) end)
writeArray(lines, "f64", floats, function(v: number): string return string.format("%.17g", v) end)
writeArray(lines, "bool", bools, function(v: boolean): string return if v then "true" else "false" end)
writeArray(lines, "string", strings, escapeString)
-- enumItem handled in Fixtures.luau (factory codec, hard to serialize)
writeArray(lines, "brickColor", brickColors, serializeBrickColor)
writeArray(lines, "numberSequence", numberSequences, serializeNumberSequence)
writeArray(lines, "colorSequence", colorSequences, serializeColorSequence)
writeArray(lines, "numberRange", numberRanges, serializeNumberRange)
writeArray(lines, "udim2", udim2s, serializeUDim2)
writeArray(lines, "vector2", vector2s, serializeV2)
writeArray(lines, "physicalProperties", physicalPropertiesList, serializePhysicalProperties)
writeArray(lines, "font", fonts, serializeFont)
writeArray(lines, "content", contents, serializeContent)
writeArray(lines, "numberSequenceKeypoint", nskps, serializeNSK)
writeArray(lines, "colorSequenceKeypoint", cskps, serializeCSK)
writeArray(lines, "udim", udims, serializeUDim)
writeArray(lines, "rect", rects, serializeRect)

table.insert(lines, "}")

local fs = require("@lune/fs")

local output = table.concat(lines, "\n") .. "\n"
fs.writeFile("bench/fixtures/large-samples.luau", output)

local totalCount = VECTOR3_COUNT + CFRAME_COUNT + COLOR3_COUNT + FLOAT_COUNT + FLOAT_COUNT + BOOL_COUNT + STRING_COUNT
	+ ENUM_COUNT + BRICK_COUNT + NS_COUNT + CS_COUNT + NR_COUNT + UDIM2_COUNT + VECTOR2_COUNT
	+ PP_COUNT + FONT_COUNT + CONTENT_COUNT + #nskps + #cskps + #udims + RECT_COUNT

print("Generated bench/fixtures/large-samples.luau with " .. tostring(totalCount) .. " values across 22 codec buckets")
