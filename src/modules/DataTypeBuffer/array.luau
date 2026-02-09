--!native

local Types = require("@src/modules/BufferUtil/Types")

return function(innerSerializer)
	return {
		write = function(b: Types.BufferWriter, v: { any })
			b:WriteUInt32(#v)
			for _, item in ipairs(v) do
				innerSerializer.write(b, item)
			end
		end,
		read = function(b: Types.BufferReader)
			local count = b:ReadUInt32()
			local result = {}
			for i = 1, count do
				table.insert(result, innerSerializer.read(b))
			end
			return result
		end,
	}
end
