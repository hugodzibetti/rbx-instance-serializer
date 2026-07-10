--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local types = require("@src/types")

local Font = roblox.Font
local FontWeight = roblox.Enum.FontWeight
local FontStyle = roblox.Enum.FontStyle

local weightsByValue: { [number]: EnumItem } = {}
for _, item in FontWeight:GetEnumItems() do
	weightsByValue[item.Value] = item
end

local stylesByValue: { [number]: EnumItem } = {}
for _, item in FontStyle:GetEnumItems() do
	stylesByValue[item.Value] = item
end

local font: types.Codec<Font> = {
	write = function(writer: Writer.Writer, value: Font)
		writer:string(value.Family)
		writer:varint(value.Weight.Value)
		writer:u8(value.Style.Value)
	end,

	read = function(reader: Reader.Reader): Font
		local family = reader:string()
		local wVal = reader:varint()
		local weight = weightsByValue[wVal]
		assert(weight, `no enum item on FontWeight with value {wVal}`)
		local sVal = reader:u8()
		local style = stylesByValue[sVal]
		assert(style, `no enum item on FontStyle with value {sVal}`)
		return Font.new(family, weight :: any, style :: any)
	end,
}

return font
