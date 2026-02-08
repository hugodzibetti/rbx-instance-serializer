--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: EnumItem)
		b:WriteUInt8(v.Value)
	end,
	read = function(b: Types.BufferReader)
		return b:ReadUInt8()
	end,
}
