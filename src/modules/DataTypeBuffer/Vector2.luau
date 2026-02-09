--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: Vector2)
		b:WriteFloat32(v.X)
		b:WriteFloat32(v.Y)
	end,
	read = function(b: Types.BufferReader)
		return Vector2.new(b:ReadFloat32(), b:ReadFloat32())
	end,
}
