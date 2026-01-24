local APIDump = require(script.Parent.APIDump)
local ValueTypeEnconding = require(script.Parent.ValueTypeEncoding)
local ClassFilters = require(script.Parent.Parent.constants.ClassFilters)
local MemberFilters = require(script.Parent.Parent.constants.MemberFilters)
local MemberTagBlacklist = require(script.Parent.Parent.constants.MemberTagBlacklist)

local function IsMemberTagsBlacklisted(member)
	local memberTags = member.Tags
	if memberTags then
		local blacklisted = false
		for _, tag in memberTags do
			if MemberTagBlacklist[tag] then
				blacklisted = true
				break
			end
		end

		return blacklisted
	end

	return false
end

local function IsMemberProtected(member)
	local memberSecurity = member.Security
	return memberSecurity and (memberSecurity.Read ~= "None" or memberSecurity.Write ~= "None")
end

local ClassDatas: {
	[string | number]: {
		id: number,
		members: {
			[number]: {
				id: number,
				name: string,
				defaultValue: any,
				write: ValueTypeEnconding.ValueTypeWrite,
				read: ValueTypeEnconding.ValueTypeRead,
			},
		},
		instanceMembers: {
			[number]: {
				id: number,
				name: string
			},
		},
	},
} =
	{}

local function ProcessClassData(classId: number, className: string, classMembers: { [string]: APIDump.Member })
	local serialMembers = {}
	local serialInstanceMembers = {}
	local serialData = {
		id = classId,
		members = serialMembers,
		instanceMembers = serialInstanceMembers
	}
	ClassDatas[className] = serialData
	ClassDatas[classId] = serialData

	local memberId = 0
	local ok, instance = pcall(Instance.new, className)
	if not ok then
		return
	end

	for memberName, member in classMembers do
		if memberName == "Parent" then continue end

		if IsMemberTagsBlacklisted(member) then
			continue
		end

		if IsMemberProtected(member) then
			continue
		end

		local memberValueType = member.ValueType
		if not memberValueType then
			continue
		end

		local memberValueTypeName = memberValueType.Name
		local memberValueTypeCategory = memberValueType.Category
		local memberValueTypeEnconding = ValueTypeEnconding[memberValueTypeName]
		if not memberValueTypeEnconding then
			memberValueTypeEnconding = ValueTypeEnconding[memberValueTypeCategory]
		end

		if not memberValueTypeEnconding then
			if memberValueTypeCategory == "Class" then
				serialInstanceMembers[memberId] = {
					id = memberId,
					name = memberName
				}
				continue
			end

			warn(memberName, "missing value type enconding.", member)
			continue
		end

		serialMembers[memberId] = {
			id = memberId,
			name = memberName,
			write = memberValueTypeEnconding.write,
			read = memberValueTypeEnconding.read,
			defaultValue = instance[memberName],
		}
		memberId += 1
	end

	instance:Destroy()
end

local classId = 0
for className, _ in APIDump:filterClasses(ClassFilters) do
	local class = APIDump:GetClass(className)
	local classMembers = class:filterMembers(MemberFilters)

	ProcessClassData(classId, className, classMembers)
	classId += 1
end

return ClassDatas
