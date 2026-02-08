--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: Faces)
		b:WriteBool(v.Right)
		b:WriteBool(v.Top)
		b:WriteBool(v.Back)
		b:WriteBool(v.Left)
		b:WriteBool(v.Bottom)
		b:WriteBool(v.Front)
	end,
	read = function(b: Types.BufferReader)
		return Faces.new(
			b:ReadBool(),
			b:ReadBool(),
			b:ReadBool(),
			b:ReadBool(),
			b:ReadBool(),
			b:ReadBool()
		)
	end,
}
