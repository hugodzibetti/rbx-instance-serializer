--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: UDim)
		b:WriteFloat32(v.Scale)
		b:WriteInt32(v.Offset)
	end,
	read = function(b: Types.BufferReader)
		return UDim.new(b:ReadFloat32(), b:ReadInt32())
	end,
}
