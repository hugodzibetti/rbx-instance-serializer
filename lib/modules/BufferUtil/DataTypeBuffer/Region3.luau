--!native

local Vector3 = require(script.Parent.Vector3)
local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, region3: Region3)
		local pos = region3.CFrame.Position
		local sizeHalf = region3.Size * 0.5
		local min = pos - sizeHalf
		local max = pos + sizeHalf
		Vector3.write(b, min)
		Vector3.write(b, max)
	end,
	read = function(b: Types.BufferReader)
		local min = Vector3.read(b)
		local max = Vector3.read(b)
		return Region3.new(min, max)
	end,
}
