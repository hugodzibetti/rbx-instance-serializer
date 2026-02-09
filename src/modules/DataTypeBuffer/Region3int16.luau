--!native

local Vector3int16 = require("@src/modules/DataTypeBuffer/Vector3int16")
local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, region3int16: Region3int16)
		Vector3int16.write(b, region3int16.Min)
		Vector3int16.write(b, region3int16.Max)
	end,
	read = function(b: Types.BufferReader)
		local min = Vector3int16.read(b)
		local max = Vector3int16.read(b)
		return Region3int16.new(min, max)
	end,
}
