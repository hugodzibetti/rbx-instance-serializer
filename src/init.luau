local Classes = require(script.artifacts.Classes)
local Types = require(script.artifacts.Classes.Types)
local buff = require(script.modules.Serde.buff)
local Serde = require(script.modules.Serde)
local FileSchema = require(script.constants.schemas.File)
local InstanceSchema = require(script.constants.schemas.Instance)

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