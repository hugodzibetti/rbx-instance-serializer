--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: boolean)
		b:WriteUInt8(v and 1 or 0)
	end,
	read = function(b: Types.BufferReader)
		return b:ReadUInt8() == 1
	end,
}
