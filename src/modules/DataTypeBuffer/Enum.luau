--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: EnumItem)
		b:WriteUInt8(v.Value)
	end,
	read = function(b: Types.BufferReader)
		return b:ReadUInt8()
	end,
}
