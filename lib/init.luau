local ClassDatas = require(script.modules.ClassDatas)
local FastBufferStream = require(script.modules.FastBufferStream)

type InstanceIdMap = {
	[Instance]: number
}

local function SerializeLoop(b: FastBufferStream.BufferWriter, instance: Instance, instanceIdMap: InstanceIdMap)
	local instanceClassData = ClassDatas[instance.ClassName]
	if not instanceClassData then return end

	b.writeu16(instanceClassData.id)

	-- Write members
	local wroteMemberCountBufferPosition = b.GetPos()
	b.Skip(1)

	local wroteMemberCount = 0
	for memberId, member in instanceClassData.members do
		local instanceMemberValue = instance[member.name]
		if instanceMemberValue == member.defaultValue then
			continue
		end

		b.writeu8(memberId)
		member.write(b, instanceMemberValue)
		wroteMemberCount += 1
	end

    buffer.writeu8(b.buf, wroteMemberCountBufferPosition, wroteMemberCount)

	-- Now for instance valued members
	local wroteInstanceMemberCountBufferPosition = b.GetPos()
	b.Skip(1)

	local wroteInstanceMemberCount = 0
	for memberId, member in instanceClassData.instanceMembers do
		local instanceMemberValue = instance[member.name]
		if not instanceMemberValue then
			continue
		end

		local respectiveInstanceId = instanceIdMap[instanceMemberValue]
		b.writeu16(respectiveInstanceId)

		wroteInstanceMemberCount += 1
	end

	buffer.writeu8(b.buf, wroteInstanceMemberCountBufferPosition, wroteInstanceMemberCount)

	for _, child in instance:GetChildren() do
		SerializeLoop(b, child, instanceIdMap)
	end
end

local rootInstanceId = 0
local function Serialize(rootInstance: Instance)
	local descendants = rootInstance:GetDescendants()
	local preAllocatedSize = (#descendants + 1) * 200
	local bufferWriter = FastBufferStream.newWriter(preAllocatedSize)

	local instanceIdMap: InstanceIdMap = {
		[rootInstance] = rootInstanceId
	}
	for instanceId, instance in descendants do
		instanceIdMap[instance] = instanceId
	end

	SerializeLoop(bufferWriter, rootInstance, instanceIdMap)

	return bufferWriter.buf
end

local function Deserialize(b: FastBufferStream.BufferReader)
	
end

return {
	Serialize = Serialize,
}
