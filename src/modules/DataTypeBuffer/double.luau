--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: number)
		b:WriteFloat64(v)
	end,
	read = function(b: Types.BufferReader)
		return b:ReadFloat64()
	end,
}
