--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: UDim2)
		b:WriteFloat32(v.X.Scale)
		b:WriteInt32(v.X.Offset)
		b:WriteFloat32(v.Y.Scale)
		b:WriteInt32(v.Y.Offset)
	end,
	read = function(b: Types.BufferReader)
		return UDim2.new(b:ReadFloat32(), b:ReadInt32(), b:ReadFloat32(), b:ReadInt32())
	end,
}
