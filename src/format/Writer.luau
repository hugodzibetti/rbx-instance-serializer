--!strict
--!native
--!optimize 2

local Types = require("@src/format/types")
local ArtifactTypes = require("@src/artifacts/types")
local BufferWriter = require("@src/buffer/Writer")

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

local function runLengthEncode(values: { any }): { { value: any, count: number } }
	local runs = {}
	if #values == 0 then
		return runs
	end
	local currentVal = values[1]
	local currentCount = 1
	for i = 2, #values do
		if values[i] == currentVal then
			currentCount += 1
		else
			table.insert(runs, { value = currentVal, count = currentCount })
			currentVal = values[i]
			currentCount = 1
		end
	end
	table.insert(runs, { value = currentVal, count = currentCount })
	return runs
end

local function write(data: Types.FormatData, artifact: ArtifactTypes.ArtifactData): buffer
	local w = BufferWriter.new()

	-- Magic: "LATF"
	w:u8(0x4C)
	w:u8(0x41)
	w:u8(0x54)
	w:u8(0x46)

	-- Version: u16
	w:u16(data.version)

	-- String table count
	w:varint(#data.stringTable)
	for _, str in data.stringTable do
		w:string(str)
	end

	-- Class blocks count
	w:varint(#data.classBlocks)
	for _, cb in data.classBlocks do
		w:varint(cb.classId)
		w:varint(cb.instanceCount)

		local effectiveCount = cb.instanceCount
		if cb.templateRefs then
			w:varint(1)
			-- ponytail: templateRefs stored as raw varints, upgrade: RLE if profiling shows it matters
			effectiveCount = 0
			for i = 1, cb.instanceCount do
				w:varint(cb.templateRefs[i])
				if cb.templateRefs[i] == 0 then
					effectiveCount += 1
				end
			end
		else
			w:varint(0)
		end

		w:varint(#cb.columns)

		for _, col in cb.columns do
			w:varint(col.propertyNameIndex)
			w:varint(col.encoding)

			local propName = data.stringTable[col.propertyNameIndex]
			assert(propName, "Property name index out of bounds in string table")

			local pm = getPropertyMetadata(artifact, cb.classId, propName)
			assert(pm, "Property metadata not found for property: " .. propName .. " in class ID: " .. tostring(cb.classId))
			local codec = pm.codec
			assert(codec, "Codec not found for property: " .. propName)

			if col.encoding == 3 then
				-- AllDefault: write 0 bytes of bitmask/values
			elseif col.encoding == 4 then
				-- AllNonDefault: write 0 bytes of bitmask, write raw values directly
				for _, val in col.values do
					codec.write(w, val)
				end
			else
				-- raw (0) or RLE (1)
				-- Pack bitmask
				local numBytes = math.ceil(effectiveCount / 8)
				local maskBytes = buffer.create(numBytes)
				for i = 1, effectiveCount do
					if col.bitmask[i] then
						local byteIdx = math.floor((i - 1) / 8)
						local bitIdx = (i - 1) % 8
						local current = buffer.readu8(maskBytes, byteIdx)
						buffer.writeu8(maskBytes, byteIdx, bit32.bor(current, bit32.lshift(1, bitIdx)))
					end
				end
				w:bytes(maskBytes)

				if col.encoding == 0 then
					-- Raw: write values
					for _, val in col.values do
						codec.write(w, val)
					end
				elseif col.encoding == 1 then
					-- RLE: compress and write
					local runs = runLengthEncode(col.values)
					w:varint(#runs)
					for _, run in runs do
						w:varint(run.count)
						codec.write(w, run.value)
					end
				end
			end
		end
	end

	return w:toBuffer()
end

return {
	write = write,
}
