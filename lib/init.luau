local ClassDatas = require(script.modules.ClassDatas)
local BufferUtil = require(script.modules["buffer-util"])
local Compression = require(script.modules.Compression)

type InstanceIdMap = {
	[Instance]: number
}

local function SerializeLoop(bufferWriter: BufferUtil.BufferWriter, instance: Instance, instanceIdMap: InstanceIdMap)
	local instanceClassData = ClassDatas[instance.ClassName]
	if not instanceClassData then return end

	bufferWriter:WriteUInt8(instanceClassData.id)

	-- Write members
	local wroteMemberCountBufferPosition = bufferWriter:GetCursor()
	bufferWriter:WriteUInt8(0)

	local wroteMemberCount = 0
	for memberId, member in instanceClassData.members do
		local memberValue = instance[member.name]
		if memberValue == member.defaultValue then
			continue
		end

		bufferWriter:WriteUInt8(memberId)
		member.write(bufferWriter, memberValue)
		wroteMemberCount += 1
	end

	local memberListEndPosition = bufferWriter:GetCursor()
	bufferWriter:SetCursor(wroteMemberCountBufferPosition)
    bufferWriter:WriteUInt8(wroteMemberCount)

	bufferWriter:SetCursor(memberListEndPosition)

	-- Now for instance valued members
	local wroteInstanceMemberCountBufferPosition = bufferWriter:GetCursor()
	bufferWriter:WriteUInt8(0)

	local wroteInstanceMemberCount = 0
	for memberId, member in instanceClassData.instanceMembers do
		local memberValue = instance[member.name]
		if not memberValue then
			continue
		end

		local respectiveInstanceId = instanceIdMap[memberValue]
		bufferWriter:WriteUInt16(respectiveInstanceId)

		wroteInstanceMemberCount += 1
	end

	local instanceMemberListEndPosition = bufferWriter:GetCursor()
	bufferWriter:SetCursor(wroteMemberCountBufferPosition)
    bufferWriter:WriteUInt8(wroteMemberCount)

	bufferWriter:SetCursor(instanceMemberListEndPosition)

	for _, child in instance:GetChildren() do
		SerializeLoop(bufferWriter, child, instanceIdMap)
	end
end

local rootInstanceId = 0
local function Serialize(rootInstance: Instance)
	local bufferWriter = BufferUtil.writer()
	
	local instanceIdMap: InstanceIdMap = {
		[rootInstance] = rootInstanceId
	}
	local descendants = rootInstance:GetDescendants()
	for instanceId, instance in descendants do
		instanceIdMap[instance] = instanceId
	end

	SerializeLoop(bufferWriter, rootInstance, instanceIdMap)

	return bufferWriter:ToString()
end

local function SerializeCompressed(rootInstance: Instance): string
	local buf = Serialize(rootInstance)
	buf = Compression.Zlib.Compress(buf)

	return buf
end

local function Deserialize(b: BufferUtil.BufferReader)
	
end

return {
	Serialize = Serialize,
	SerializeCompressed = SerializeCompressed
}
