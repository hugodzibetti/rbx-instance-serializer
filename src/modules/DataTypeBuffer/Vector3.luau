--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: Vector3)
		b:WriteFloat32(v.X)
		b:WriteFloat32(v.Y)
		b:WriteFloat32(v.Z)
	end,
	read = function(b: Types.BufferReader)
		return Vector3.new(b:ReadFloat32(), b:ReadFloat32(), b:ReadFloat32())
	end,
}
