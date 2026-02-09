--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: number)
		b:WriteUInt32(v)
	end,
	read = function(b: Types.BufferReader)
		return b:ReadUInt32()
	end,
}
