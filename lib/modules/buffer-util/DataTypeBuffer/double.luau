--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: number)
		b:WriteFloat64(v)
	end,
	read = function(b: Types.BufferReader)
		return b:ReadFloat64()
	end,
}
