--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: Color3)
		b:WriteUInt8(math.floor(v.R * 255))
		b:WriteUInt8(math.floor(v.G * 255))
		b:WriteUInt8(math.floor(v.B * 255))
	end,
	read = function(b: Types.BufferReader)
		return Color3.fromRGB(b:ReadUInt8(), b:ReadUInt8(), b:ReadUInt8())
	end,
}
