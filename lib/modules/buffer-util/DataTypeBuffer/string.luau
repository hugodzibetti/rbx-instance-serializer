--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: string)
		b:WriteString(v)
	end,
	read = function(b: Types.BufferReader)
		return b:ReadString()
	end,
}
