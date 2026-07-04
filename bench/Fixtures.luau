--!strict
--!native
--!optimize 2

local Types = require("@src/types")
local roblox = require("@lune/roblox")

local f32 = require("@src/serde/f32")
local f64 = require("@src/serde/f64")
local boolCodec = require("@src/serde/bool")
local stringCodec = require("@src/serde/string")
local cframe = require("@src/serde/cframe")
local color3 = require("@src/serde/color3")
local brickColor = require("@src/serde/brickColor")
local colorSequence = require("@src/serde/colorSequence")
local colorSequenceKeypoint = require("@src/serde/colorSequenceKeypoint")
local numberRange = require("@src/serde/numberRange")
local numberSequence = require("@src/serde/numberSequence")
local numberSequenceKeypoint = require("@src/serde/numberSequenceKeypoint")
local udim = require("@src/serde/udim")
local udim2 = require("@src/serde/udim2")
local vector2 = require("@src/serde/vector2")
local vector3 = require("@src/serde/vector3")
local rect = require("@src/serde/rect")
local axes = require("@src/serde/axes")
local faces = require("@src/serde/faces")
local physicalProperties = require("@src/serde/physicalProperties")
local font = require("@src/serde/font")
local content = require("@src/serde/content")
local uniqueId = require("@src/serde/uniqueId")
local enumItem = require("@src/serde/enumItem")
local array = require("@src/serde/array")
local option = require("@src/serde/option")

type Codec<T> = Types.Codec<T>

export type Entry = {
	name: string,
	codec: Codec<any>,
	samples: { any },
}

local samples = require("./fixtures/large-samples")

-- enumItem is a factory, instantiate with Material
local materialEnumItem = enumItem(roblox.Enum.Material)
local enumItemSamples = {}
for _, item in roblox.Enum.Material:GetEnumItems() do
	table.insert(enumItemSamples, item)
end

-- synthetic codecs: faces, axes, array, option
local syntheticFaces = {}
for i = 0, 63 do
	local normalIds = {}
	if bit32.band(i, 1) ~= 0 then table.insert(normalIds, roblox.Enum.NormalId.Top) end
	if bit32.band(i, 2) ~= 0 then table.insert(normalIds, roblox.Enum.NormalId.Bottom) end
	if bit32.band(i, 4) ~= 0 then table.insert(normalIds, roblox.Enum.NormalId.Left) end
	if bit32.band(i, 8) ~= 0 then table.insert(normalIds, roblox.Enum.NormalId.Right) end
	if bit32.band(i, 16) ~= 0 then table.insert(normalIds, roblox.Enum.NormalId.Front) end
	if bit32.band(i, 32) ~= 0 then table.insert(normalIds, roblox.Enum.NormalId.Back) end
	table.insert(syntheticFaces, roblox.Faces.new(table.unpack(normalIds)))
end

local syntheticAxes = {}
for x = 0, 1 do
	for y = 0, 1 do
		for z = 0, 1 do
			local axisList = {}
			if x == 1 then table.insert(axisList, roblox.Enum.Axis.X) end
			if y == 1 then table.insert(axisList, roblox.Enum.Axis.Y) end
			if z == 1 then table.insert(axisList, roblox.Enum.Axis.Z) end
			table.insert(syntheticAxes, roblox.Axes.new(table.unpack(axisList)))
		end
	end
end

local numberCodec: Codec<number> = {
	write = function(writer, value)
		writer:f64(value)
	end,
	read = function(reader)
		return reader:f64()
	end,
}

local numberArray = array(numberCodec)
local optionalNumber = option(numberCodec)

local syntheticArrays = {}
for _ = 1, 100 do
	local n = math.random(0, 20)
	local arr = {}
	for _ = 1, n do
		table.insert(arr, (math.random() - 0.5) * 2000)
	end
	table.insert(syntheticArrays, arr)
end

local syntheticOptions = {}
for _ = 1, 100 do
	table.insert(syntheticOptions, (math.random() - 0.5) * 2000)
end

local uniqueIds = {}
for _ = 1, 100 do
	table.insert(uniqueIds, roblox.UniqueId.new())
end
table.insert(uniqueIds, roblox.UniqueId.null)

local entries: { Entry } = {
	{ name = "f32", codec = f32 :: Codec<any>, samples = samples.f32 },
	{ name = "f64", codec = f64 :: Codec<any>, samples = samples.f64 },
	{ name = "bool", codec = boolCodec :: Codec<any>, samples = samples.bool },
	{ name = "string", codec = stringCodec :: Codec<any>, samples = samples.string },
	{ name = "cframe", codec = cframe :: Codec<any>, samples = samples.cframe },
	{ name = "color3", codec = color3 :: Codec<any>, samples = samples.color3 },
	{ name = "brickColor", codec = brickColor :: Codec<any>, samples = samples.brickColor },
	{ name = "colorSequence", codec = colorSequence :: Codec<any>, samples = samples.colorSequence },
	{ name = "colorSequenceKeypoint", codec = colorSequenceKeypoint :: Codec<any>, samples = samples.colorSequenceKeypoint },
	{ name = "numberRange", codec = numberRange :: Codec<any>, samples = samples.numberRange },
	{ name = "numberSequence", codec = numberSequence :: Codec<any>, samples = samples.numberSequence },
	{ name = "numberSequenceKeypoint", codec = numberSequenceKeypoint :: Codec<any>, samples = samples.numberSequenceKeypoint },
	{ name = "udim", codec = udim :: Codec<any>, samples = samples.udim },
	{ name = "udim2", codec = udim2 :: Codec<any>, samples = samples.udim2 },
	{ name = "vector2", codec = vector2 :: Codec<any>, samples = samples.vector2 },
	{ name = "vector3", codec = vector3 :: Codec<any>, samples = samples.vector3 },
	{ name = "rect", codec = rect :: Codec<any>, samples = samples.rect },
	{ name = "axes", codec = axes :: Codec<any>, samples = syntheticAxes },
	{ name = "faces", codec = faces :: Codec<any>, samples = syntheticFaces },
	{ name = "physicalProperties", codec = physicalProperties :: Codec<any>, samples = samples.physicalProperties },
	{ name = "font", codec = font :: Codec<any>, samples = samples.font },
	{ name = "content", codec = content :: Codec<any>, samples = samples.content },
	{ name = "uniqueId", codec = uniqueId :: Codec<any>, samples = uniqueIds },
	{ name = "enumItem", codec = materialEnumItem :: Codec<any>, samples = enumItemSamples },
	{ name = "array", codec = numberArray :: Codec<any>, samples = syntheticArrays },
	{ name = "option", codec = optionalNumber :: Codec<any>, samples = syntheticOptions },
}

return { entries = entries }
