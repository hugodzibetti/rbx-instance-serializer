local DataTypeBuffer = require("@src/modules/DataTypeBuffer")
local BufferUtil = require("@src/modules/BufferUtil")

local Schema = {}

type SchemaStruct = { string | SchemaStruct }

function Schema.CreateSchema(struct: SchemaStruct)
	return struct
end

function Schema.Serialize(data: {}, schemaStruct: SchemaStruct)
	local bufferWriter = BufferUtil.writer()
	for keyIndex, keyType in schemaStruct do
		local keyValue = data[keyIndex]
		local keySerializer = DataTypeBuffer.ReadWrite[keyType].write
		keySerializer(bufferWriter, keyValue)
	end

	return bufferWriter:GetBuffer()
end

return Schema
