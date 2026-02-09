--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: string)
		b:WriteString(v)
	end,
	read = function(b: Types.BufferReader)
		return b:ReadString()
	end,
}
