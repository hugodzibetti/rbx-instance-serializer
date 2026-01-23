local ClassDatas = require(script.modules.ClassDatas)
local FastBufferStream = require(script.modules.FastBufferStream)

local function Serialize(b: FastBufferStream.BufferWriter, instance: Instance)
	local instanceClassData = ClassDatas[instance.ClassName]
	if not instanceClassData then return end

	b.writeu16(instanceClassData.id)

	local instanceMemberCountPosition = b.GetPos()
	b.Skip(1)

	local instanceMemberCount = 0
	for memberId, member in instanceClassData.members do
		local instanceMemberValue = instance[member.name]
		if instanceMemberValue == member.defaultValue then
			continue
		end

		b.writeu8(memberId)
		member.write(b, instanceMemberValue)
		instanceMemberCount += 1
	end

    b.writeu8(instanceMemberCountPosition)

	for _, child in instance:GetChildren() do
		Serialize(b, child)
	end
end

local function SerializeRecursive(rootInstance: Instance)
	local descendants = rootInstance:GetDescendants()
	local preAllocatedSize = (#descendants + 1) * 200
	local bufferWriter = FastBufferStream.newWriter(preAllocatedSize)
	Serialize(bufferWriter, rootInstance)

	return bufferWriter.buf
end

return {
	Serialize = Serialize,
	SerializeRecursive = SerializeRecursive,
}
