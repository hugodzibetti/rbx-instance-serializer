--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: Vector3int16)
		b:WriteInt16(v.X)
		b:WriteInt16(v.Y)
		b:WriteInt16(v.Z)
	end,
	read = function(b: Types.BufferReader)
		local x = b:ReadInt16()
		local y = b:ReadInt16()
		local z = b:ReadInt16()
		return Vector3int16.new(x, y, z)
	end,
}
