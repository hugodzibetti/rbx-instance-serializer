local BufferUtil = require("@src/modules/BufferUtil")
local Compression = require("@src/modules/Compression")

local Deserialization = {}

function Deserialization.Deserialize(b: BufferUtil.BufferReader)
	
end

function Deserialization.DeserializeCompressed(b: BufferUtil.BufferReader)
	local buf = Compression.Zlib.Decompress(b)
	return Deserialization.Deserialize(buf)
end

return Deserialization