local BufferUtil = require(script.Parent.BufferUtil)
local Compression = require(script.Parent.Compression)

local Deserialization = {}

function Deserialization.Deserialize(b: BufferUtil.BufferReader)
	
end

function Deserialization.DeserializeCompressed(b: BufferUtil.BufferReader)
	local buf = Compression.Zlib.Decompress(b)
	return Deserialization.Deserialize(buf)
end

return Deserialization