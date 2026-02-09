--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: CFrame)
		local components = { v:GetComponents() }
		for i = 1, 12 do
			b:WriteFloat32(components[i])
		end
	end,
	read = function(b: Types.BufferReader)
		local components = {}
		for i = 1, 12 do
			table.insert(components, b:ReadFloat32())
		end
		return CFrame.fromMatrix(
			Vector3.new(components[1], components[2], components[3]),
			Vector3.new(components[4], components[5], components[6]),
			Vector3.new(components[7], components[8], components[9]),
			Vector3.new(components[10], components[11], components[12])
		)
	end,
}
