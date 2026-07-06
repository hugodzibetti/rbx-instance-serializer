--!strict
--!native
--!optimize 2

-- v2 body: templateRefs stored as RLE runs (mirroring property column RLE)
-- instead of one raw varint per instance.

local Types = require("@src/format/types")
local ArtifactTypes = require("@src/artifacts/types")
local BufferReader = require("@src/buffer/Reader")

local function getPropertyMetadata(artifact: ArtifactTypes.ArtifactData, classId: number, propName: string)
	local classMeta = artifact.classById[classId]
	if not classMeta then
		return nil
	end
	for _, pm in classMeta.properties do
		if pm.name == propName then
			return pm
		end
	end
	return nil
end

local function readV2Body(r: BufferReader.Reader, artifact: ArtifactTypes.ArtifactData): Types.FormatData
	-- String table
	local stringTableCount = r:varint()
	local stringTable = table.create(stringTableCount)
	for i = 1, stringTableCount do
		stringTable[i] = r:string()
	end

	-- Class blocks
	local classBlockCount = r:varint()
	local classBlocks = table.create(classBlockCount)

	for i = 1, classBlockCount do
		local classId = r:varint()
		local instanceCount = r:varint()

		local hasTemplateRefs = r:varint() == 1
		local templateRefs: { number }? = nil
		local effectiveCount = instanceCount
		if hasTemplateRefs then
			local refs = table.create(instanceCount)
			effectiveCount = 0
			local k = 1
			local runCount = r:varint()
			for _ = 1, runCount do
				local repeatCount = r:varint()
				local value = r:varint()
				for _ = 1, repeatCount do
					refs[k] = value
					if value == 0 then
						effectiveCount += 1
					end
					k += 1
				end
			end
			templateRefs = refs
		end

		local propertyCount = r:varint()

		local columns = table.create(propertyCount)

		for j = 1, propertyCount do
			local propertyNameIndex = r:varint()
			local encoding = r:varint()

			local propName = stringTable[propertyNameIndex]
			assert(propName, "Property name index out of bounds in string table")

			local pm = getPropertyMetadata(artifact, classId, propName)
			assert(pm, "Property metadata not found for property: " .. propName .. " in class ID: " .. tostring(classId))
			local codec = pm.codec
			assert(codec, "Codec not found for property: " .. propName)

			local bitmask: { boolean } = {}
			local values: { any } = {}
			local dictIndices: { number }? = nil

			if encoding == 3 then
				-- AllDefault: no bitmask, no values.
				bitmask = table.create(effectiveCount, false)
			elseif encoding == 4 then
				-- AllNonDefault: no bitmask, read all values directly.
				bitmask = table.create(effectiveCount, true)
				values = table.create(effectiveCount)
				for k = 1, effectiveCount do
					values[k] = codec.read(r)
				end
			elseif encoding == 0 or encoding == 1 or encoding == 2 then
				-- Unpack bitmask
				bitmask = table.create(effectiveCount)
				local numBytes = math.ceil(effectiveCount / 8)
				local maskBytes = r:bytes(numBytes)
				local nonDefaultCount = 0
				local k = 1
				for byteIdx = 0, numBytes - 1 do
					local byteVal = buffer.readu8(maskBytes, byteIdx)
					local limit = math.min(8, effectiveCount - k + 1)
					for bitIdx = 0, limit - 1 do
						local isNonDefault = bit32.band(byteVal, bit32.lshift(1, bitIdx)) ~= 0
						bitmask[k] = isNonDefault
						if isNonDefault then
							nonDefaultCount += 1
						end
						k += 1
					end
				end

				if encoding == 0 then
					-- Raw: read values for each set bit
					values = table.create(nonDefaultCount)
					for k = 1, nonDefaultCount do
						values[k] = codec.read(r)
					end
				elseif encoding == 1 then
					-- RLE: read runs
					local runCount2 = r:varint()
					for _ = 1, runCount2 do
						local repeatCount = r:varint()
						local value = codec.read(r)
						for _ = 1, repeatCount do
							table.insert(values, value)
						end
					end
				elseif encoding == 2 then
					-- Dictionary: read unique values, then per-instance dict index
					local uniqueCount = r:varint()
					values = table.create(uniqueCount)
					for k = 1, uniqueCount do
						values[k] = codec.read(r)
					end
					local indices = table.create(nonDefaultCount)
					for k = 1, nonDefaultCount do
						indices[k] = r:varint()
					end
					dictIndices = indices
				end
			else
				error("Unsupported encoding type: " .. tostring(encoding))
			end

			columns[j] = {
				propertyNameIndex = propertyNameIndex,
				encoding = encoding,
				bitmask = bitmask,
				values = values,
				dictIndices = dictIndices,
			}
		end

		classBlocks[i] = {
			classId = classId,
			instanceCount = instanceCount,
			columns = columns,
			templateRefs = templateRefs,
		}
	end

	return {
		version = 2,
		stringTable = stringTable,
		classBlocks = classBlocks,
	}
end

return {
	readV2Body = readV2Body,
}
