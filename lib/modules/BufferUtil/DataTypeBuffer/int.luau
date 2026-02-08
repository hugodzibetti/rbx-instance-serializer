--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: number)
		b:WriteUInt16(v)
	end,
	read = function(b: Types.BufferReader)
		return b:ReadUInt16()
	end,
}
