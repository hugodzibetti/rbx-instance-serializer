type Dictionary<T> = { [string]: T }
type Array<T> = { [number]: T }

local BAD_MEMBER_TYPE_MESSAGE = "Unexpected member type `%s` (expected `Property`, `Function`, `Event`, or `Callback`)"

-- selene: allow(unused_variable)
local ApiTypes = require("./ApiTypes")

local Util = {}

function Util.filterSecurity(security:{ Read: string, Write: string } | string, filter: Dictionary<boolean>): boolean
	if type(security) == "string" then
		return filter[security]
	else
		return (filter[security.Read] or filter[security.Write])
	end
end

function Util.filterTags(tags: Array<string>?, filter: Dictionary<boolean>): boolean
	if tags then
		for _, tag in ipairs(tags) do
			if filter[tag] then
				return true
			end
		end
	end
	return false
end

function Util.lookupify(tbl: Array<string>?): Dictionary<boolean>
	local newTbl: Dictionary<boolean> = {}
	if tbl then
		for _, v in ipairs(tbl) do
			newTbl[v] = true
		end
	end
	return newTbl
end

function Util.cloneMember(
	member: ApiTypes.Member
): ApiTypes.Member
	if member.MemberType == "Property" then
		local newMember: ApiTypes.Property = {
			Category = member.Category,
			MemberType = member.MemberType,
			Name = member.Name,
			Security = member.Security,
			Serialization = member.Serialization,
			ValueType = member.ValueType,
			Tags = member.Tags,
		}
		return newMember
	elseif member.MemberType == "Function" then
		local newMember: ApiTypes.Function = {
			MemberType = member.MemberType,
			Name = member.Name,
			Parameters = member.Parameters,
			ReturnType = member.ReturnType,
			Security = member.Security,
			Tags = member.Tags,
		}
		return newMember
	elseif member.MemberType == "Event" then
		local newMember: ApiTypes.Event = {
			MemberType = member.MemberType,
			Name = member.Name,
			Parameters = member.Parameters,
			Security = member.Security,
			Tags = member.Tags,
		}
		return newMember
	elseif member.MemberType == "Callback" then
		local newMember: ApiTypes.Callback = {
			MemberType = member.MemberType,
			Name = member.Name,
			Parameters = member.Parameters,
			ReturnType = member.ReturnType,
			Security = member.Security,
			Tags = member.Tags,
		}
		return newMember
	else
		error(string.format(BAD_MEMBER_TYPE_MESSAGE, member.MemberType), 2)
	end
end

return Util
