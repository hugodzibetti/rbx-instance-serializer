local RBXAPIDump = require("@packages/rbx_api_dump")
local Serde = require(script.Parent.Parent.Parent:FindFirstChild('modules'):FindFirstChild('Serde'))
local ClassTagsFilter = require(script.Parent.Parent.Parent:FindFirstChild('constants'):FindFirstChild('rbx-api-filters'):FindFirstChild('ClassTags'))
local MemberTagsFilter = require(script.Parent.Parent.Parent:FindFirstChild('constants'):FindFirstChild('rbx-api-filters'):FindFirstChild('MemberTags'))
local MemberSecuritiesFilter = require(script.Parent.Parent.Parent:FindFirstChild('constants'):FindFirstChild('rbx-api-filters'):FindFirstChild('MemberSecurities'))

local Types = require(script.Parent:FindFirstChild('Types'))

local ROBLOX_TYPE_TO_SERDE: { [string]: Types.SerdeConverter } = {
	["string"] = Serde.string,
	["bool"] = Serde.bool,
	["int"] = Serde.number,
	["int64"] = Serde.number,
	["float"] = Serde.number,
	["double"] = Serde.number,
	["Vector3"] = Serde.vector3,
	["Vector2"] = Serde.vector2,
	["Vector3int16"] = Serde.vector3,
	["Vector2int16"] = Serde.vector2,
	["CFrame"] = Serde.cframe,
	["Rect"] = Serde.rect,
	["Ray"] = Serde.ray,
	["Region3"] = Serde.region3,
	["Region3int16"] = Serde.region3,
	["Color3"] = Serde.color3,
	["BrickColor"] = Serde.brickColor,
	["ColorSequence"] = Serde.colorSequence,
	["NumberSequence"] = Serde.numberSequence,
	["UDim2"] = Serde.udim2,
	["UDim"] = Serde.udim,
	["Faces"] = Serde.faces,
	["Axes"] = Serde.axes,
	["Enum"] = Serde.enumItem,
	["PhysicalProperties"] = Serde.physicalProperties,
	["DateTime"] = Serde.dateTime,
	["BinaryString"] = Serde.buffer,
	["Content"] = Serde.content,
	["Font"] = Serde.font,
}

local PARENT_PROPERTY = "Parent"
local CLASS_CATEGORY = "Class"
local ENUM_CATEGORY = "Enum"

local ClassDatas = {}
local classesById: { [number]: Types.ClassData } = {}
local classesByName: { [string]: Types.ClassData } = {}
local allClasses: { Types.ClassData } = {}

local function GetConverterForRobloxType(valueType: Types.ApiValueType): Types.SerdeConverter?
	local converter = ROBLOX_TYPE_TO_SERDE[valueType.Name]
	if converter then
		return converter
	end
	if valueType.Category == ENUM_CATEGORY then
		return Serde.enumItem
	end
	return nil
end

local function SortedKeys(t: { [string]: any }): { string }
	local keys: { string } = {}
	for key in t do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function BuildClassMetadata(binaryClassId: number, className: string): Types.ClassData
	local properties: { Types.PropertyMember } = {}
	local instanceReferences: { Types.InstanceMember } = {}
	local nextPropertyBinaryId = 0
	local nextReferenceBinaryId = 0

	local apiProperties = RBXAPIDump.getProperties(className, MemberTagsFilter, MemberSecuritiesFilter)

	for _, propertyName in SortedKeys(apiProperties) do
		if propertyName == PARENT_PROPERTY then
			continue
		end

		local apiProperty = apiProperties[propertyName]
		local valueType = apiProperty.ValueType
		if not valueType then
			continue
		end

		if valueType.Category == CLASS_CATEGORY then
			instanceReferences[nextReferenceBinaryId + 1] = {
				binaryId = nextReferenceBinaryId,
				name = propertyName,
			}
			nextReferenceBinaryId += 1
			continue
		end

		local converter = GetConverterForRobloxType(valueType)
		if not converter then
			warn(`[ClassDatas] No converter for {propertyName} ({valueType.Name}) in {className}`)
			continue
		end

		properties[nextPropertyBinaryId + 1] = {
			binaryId = nextPropertyBinaryId,
			name = propertyName,
			converter = converter,
		}
		nextPropertyBinaryId += 1
	end

	local classData: Types.ClassData = {
		binaryId = binaryClassId,
		name = className,
		properties = properties,
		instanceReferences = instanceReferences,
	}

	classesById[binaryClassId] = classData
	classesByName[className] = classData
	table.insert(allClasses, classData)

	return classData
end

local function WaitForApiDump()
	if not RBXAPIDump.isReady() then
		RBXAPIDump.readyEvent:wait()
	end
end

function ClassDatas.GetClass(idOrName: number | string): Types.ClassData?
	if type(idOrName) == "number" then
		return classesById[idOrName]
	end
	return classesByName[idOrName :: string]
end

function ClassDatas.GetClasses(): { Types.ClassData }
	WaitForApiDump()
	return allClasses
end

function ClassDatas.ClassCount(): number
	return #allClasses
end

function ClassDatas._process()
	WaitForApiDump()
	local filteredClassNames = RBXAPIDump.getClasses(ClassTagsFilter)
	for index, className in ipairs(filteredClassNames) do
		local binaryClassId = index - 1
		BuildClassMetadata(binaryClassId, className)
	end
end

setmetatable(ClassDatas, {
	__index = function(_, key)
		if type(key) == "number" then
			return classesById[key]
		end
		return classesByName[key :: string]
	end,
})

return ClassDatas
