local Classes = require("@src/artifacts/Classes")
local Types = require("@src/artifacts/Classes/Types")
local buff = require("@src/modules/serde/buff")
local Serde = require("@src/modules/serde")
local FileSchema = require("@src/constants/schemas/File")
local InstanceSchema = require("@src/constants/schemas/Instance")

local BrickPack = {}

function BrickPack.Serialize(instance: Instance)
	local data = {}
	local classData = Classes.GetClass(instance.ClassName)
	for i, property: Types.PropertyMember in classData.properties do
		local value = instance[property.name]
		property.converter.write(value)
	
		local b = buff.get()
		table.insert(data, {
			property.binaryId,
			b
		})
	end

	return data
end

function BrickPack.Deserialize(data: string, compressed: boolean?)
	
end

return BrickPack