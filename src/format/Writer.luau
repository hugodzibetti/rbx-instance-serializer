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

local function writeClassBlock(
	w: BufferWriter.Writer,
	cb: Types.ClassBlock,
	artifact: ArtifactTypes.ArtifactData,
	stringTable: { string }
): ()
	w:varint(cb.classId)
	w:varint(cb.instanceCount)
	w:varint(0) -- no templateRefs

	w:varint(#cb.columns)

	for _, col in cb.columns do
		w:varint(col.propertyNameIndex)
		w:varint(col.encoding)

		local propName = stringTable[col.propertyNameIndex]
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
			local numBytes = math.ceil(#col.bitmask / 8)
			local maskBytes = buffer.create(numBytes)
			local bitmask = col.bitmask
			local byteIdx = 0
			local acc = 0
			local bitIdx = 0
			for i = 1, #col.bitmask do
				if bitmask[i] then
					acc = bit32.bor(acc, bit32.lshift(1, bitIdx))
				end
				bitIdx += 1
				if bitIdx == 8 then
					buffer.writeu8(maskBytes, byteIdx, acc)
					byteIdx += 1
					acc = 0
					bitIdx = 0
				end
			end
			if bitIdx > 0 then
				buffer.writeu8(maskBytes, byteIdx, acc)
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
			elseif col.encoding == 2 then
				-- Dictionary: unique values (first-occurrence order), then per-instance index
				w:varint(#col.values)
				for _, val in col.values do
					codec.write(w, val)
				end
				local dictIndices = col.dictIndices
				assert(dictIndices, "Dictionary-encoded column missing dictIndices")
				for _, idx in dictIndices do
					w:varint(idx)
				end
			end
		end
	end
end

local function write(data: Types.FormatData, artifact: ArtifactTypes.ArtifactData): buffer
	local w = BufferWriter.new()

	-- Magic: "LATF"
	w:u8(0x4C)
	w:u8(0x41)
	w:u8(0x54)
	w:u8(0x46)

	-- Version: u16 (schema v4: length-prefixed class blocks)
	w:u16(4)

	-- String table count
	w:varint(#data.stringTable)
	for _, str in data.stringTable do
		w:string(str)
	end

	-- Class blocks count
	w:varint(#data.classBlocks)
	for _, cb in data.classBlocks do
		local blockWriter = BufferWriter.new()
		writeClassBlock(blockWriter, cb, artifact, data.stringTable)

		w:varint(blockWriter:len())
		w:bytes(blockWriter:toBuffer())
	end

	return w:toBuffer()
end

return {
	write = write,
	writeClassBlock = writeClassBlock,
}
