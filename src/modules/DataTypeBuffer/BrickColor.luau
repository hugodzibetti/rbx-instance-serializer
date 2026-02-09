--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: BrickColor)
		b:WriteUInt8(v.Number)
	end,
	read = function(b: Types.BufferReader)
		return Color3.fromRGB(b:ReadUInt8(), b:ReadUInt8(), b:ReadUInt8())
	end,
}
