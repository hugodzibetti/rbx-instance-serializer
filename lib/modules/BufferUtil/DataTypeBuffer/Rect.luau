--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: Rect)
		b:WriteFloat32(v.Min.X)
		b:WriteFloat32(v.Min.Y)
		b:WriteFloat32(v.Max.X)
		b:WriteFloat32(v.Max.Y)
	end,
	read = function(b: Types.BufferReader)
		local minX, minY = b:ReadFloat32(), b:ReadFloat32()
		local maxX, maxY = b:ReadFloat32(), b:ReadFloat32()
		return Rect.new(minX, minY, maxX, maxY)
	end,
}
