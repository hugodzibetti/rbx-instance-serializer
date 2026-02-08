--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: Ray)
		local origin = v.Origin
		b:WriteFloat32(origin.X)
		b:WriteFloat32(origin.Y)
		b:WriteFloat32(origin.Z)
		local direction = v.Direction
		b:WriteFloat32(direction.X)
		b:WriteFloat32(direction.Y)
		b:WriteFloat32(direction.Z)
	end,
	read = function(b: Types.BufferReader)
		local originX, originY, originZ = b:ReadFloat32(), b:ReadFloat32(), b:ReadFloat32()
		local dirX, dirY, dirZ = b:ReadFloat32(), b:ReadFloat32(), b:ReadFloat32()
		return Ray.new(Vector3.new(originX, originY, originZ), Vector3.new(dirX, dirY, dirZ))
	end,
}
