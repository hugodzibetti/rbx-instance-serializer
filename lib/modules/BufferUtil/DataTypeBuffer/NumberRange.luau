--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: NumberRange)
		b:WriteFloat32(v.Min)
		b:WriteFloat32(v.Max)
	end,
	read = function(b: Types.BufferReader)
		return NumberRange.new(b:ReadFloat32(), b:ReadFloat32())
	end,
}
