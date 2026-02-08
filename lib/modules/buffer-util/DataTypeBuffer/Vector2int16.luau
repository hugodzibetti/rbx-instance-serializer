--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: Vector2int16)
		b:WriteInt16(v.X)
		b:WriteInt16(v.Y)
	end,
	read = function(b: Types.BufferReader)
		local x = b:ReadInt16()
		local y = b:ReadInt16()
		return Vector2int16.new(x, y)
	end,
}
