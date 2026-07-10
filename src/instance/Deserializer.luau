--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")
local task = require("@lune/task")
local RobloxBackend = require("@src/parallel/RobloxBackend")
local Types = require("@src/types")
local ArtifactTypes = require("@src/artifacts/types")
local FormatTypes = require("@src/format/types")
local FormatReader = require("@src/format/Reader")
local BufferReader = require("@src/buffer/Reader")
local BufferWriter = require("@src/buffer/Writer")

type ArtifactData = ArtifactTypes.ArtifactData
type FormatData = FormatTypes.FormatData

local function fromValue(enumObj: any, val: number): any?
	local hasFromValue = false
	local fromValueFunc = nil
	pcall(function()
		fromValueFunc = enumObj.fromValue
		if type(fromValueFunc) == "function" then
			hasFromValue = true
		end
	end)
	if hasFromValue and fromValueFunc then
		local ok, item = pcall(function()
			return fromValueFunc(enumObj, val)
		end)
		if ok and item then
			return item
		end
	end
	for _, item in enumObj:GetEnumItems() do
		if item.Value == val then
			return item
		end
	end
	return nil
end

-- Stage C (sequential, parent-only): builds real Instances from an already-parsed
-- FormatData. Shared by the sequential deserialize() and the parallel
-- deserializeParallel() (which only differs in how it produces the FormatData -
-- via workers instead of an in-process parse) so this construction logic is defined
-- exactly once.
local function buildInstancesFromFormatData(formatData: FormatData, artifact: ArtifactData): { any }
	local instances = {}

	-- Pass 1: Instantiation
	for _, cb in formatData.classBlocks do
		local classMeta = artifact.classById[cb.classId]
		assert(classMeta, "Class metadata not found in artifact for class ID: " .. tostring(cb.classId))
		local className = classMeta.name

		for _ = 1, cb.instanceCount do
			local inst = roblox.Instance.new(className)
			table.insert(instances, inst)
		end
	end

	-- Pass 2: Property & Reference Sweep
	local currentInstanceIdx = 1
	local parentTasks = {}

	for _, cb in formatData.classBlocks do
		local classMeta = artifact.classById[cb.classId]
		assert(classMeta, "Class metadata not found in artifact for class ID: " .. tostring(cb.classId))

		local classInstances = {}
		for i = 1, cb.instanceCount do
			table.insert(classInstances, instances[currentInstanceIdx])
			currentInstanceIdx += 1
		end

		local effectiveIndices: { number }? = nil
		local effectiveCount = cb.instanceCount
		if cb.templateRefs then
			local indices = {}
			for i = 1, cb.instanceCount do
				if cb.templateRefs[i] == 0 then
					table.insert(indices, i)
				end
			end
			effectiveIndices = indices
			effectiveCount = #indices
		end

		for _, col in cb.columns do
			local propName = formatData.stringTable[col.propertyNameIndex]
			assert(propName, "Property name index out of bounds in string table")

			-- Find property metadata
			local pm = nil
			for _, p in classMeta.properties do
				if p.name == propName then
					pm = p
					break
				end
			end
			assert(pm, "Property metadata not found for property: " .. propName .. " in class ID: " .. tostring(cb.classId))

			-- Reconstruct values array (over effective/leader positions only)
			local values = table.create(effectiveCount)
			if col.encoding == 3 then -- AllDefault
				for k = 1, effectiveCount do
					values[k] = pm.default
				end
			elseif col.encoding == 4 then -- AllNonDefault
				for k = 1, effectiveCount do
					values[k] = col.values[k]
				end
			elseif col.encoding == 0 or col.encoding == 1 then
				local nonDefaultIdx = 1
				for k = 1, effectiveCount do
					if col.bitmask[k] then
						values[k] = col.values[nonDefaultIdx]
						nonDefaultIdx += 1
					else
						values[k] = pm.default
					end
				end
			elseif col.encoding == 2 then -- Dictionary
				assert(col.dictIndices, "Dictionary-encoded column missing dictIndices")
				local dictIndices = col.dictIndices
				local nonDefaultIdx = 1
				for k = 1, effectiveCount do
					if col.bitmask[k] then
						values[k] = col.values[dictIndices[nonDefaultIdx] + 1] -- 0-based -> 1-based
						nonDefaultIdx += 1
					else
						values[k] = pm.default
					end
				end
			else
				error("Unsupported encoding: " .. tostring(col.encoding))
			end

			-- Apply values to instances (leader/plain positions only; duplicates copied below)
			for k = 1, effectiveCount do
				local i = if effectiveIndices then effectiveIndices[k] else k
				local inst = classInstances[i]
				local val = values[k]

				if pm.codecId == 26 then -- Referent
					if pm.name == "Parent" then
						table.insert(parentTasks, { child = inst, parentId = val })
					else
						local target = nil
						if val and val > 0 then
							target = instances[val]
						end
						pcall(function()
							inst[pm.name] = target
						end)
					end
				elseif pm.codecId == 25 then -- Enum
					if val ~= nil then
						local defaultItem = nil
						pcall(function()
							defaultItem = inst[pm.name]
						end)
						if defaultItem then
							local enumName = tostring(defaultItem.EnumType)
							local name = enumName:match("[^%.]+$") or enumName
							local enumObj = (roblox.Enum :: any)[name]
							if enumObj then
								local enumItemVal = fromValue(enumObj, val)
								if enumItemVal then
									pcall(function()
										inst[pm.name] = enumItemVal
									end)
								end
							end
						end
					end
				else
					if val ~= nil then
						pcall(function()
							inst[pm.name] = val
						end)
					end
				end
			end
		end

		-- Duplicate instances: copy every property from their template leader
		if cb.templateRefs then
			for i = 1, cb.instanceCount do
				local leaderIdx = cb.templateRefs[i]
				if leaderIdx ~= 0 then
					local leaderInst = classInstances[leaderIdx]
					local inst = classInstances[i]
					for _, pm in classMeta.properties do
						pcall(function()
							inst[pm.name] = leaderInst[pm.name]
						end)
					end
				end
			end
		end
	end

	-- Execute parenting tasks at the end
	for _, task in parentTasks do
		local parent = nil
		if task.parentId and task.parentId > 0 then
			parent = instances[task.parentId]
		end
		task.child.Parent = parent
	end

	-- Collect roots
	local roots = {}
	for _, inst in instances do
		if inst.Parent == nil then
			table.insert(roots, inst)
		end
	end

	return roots
end

local function deserialize(buf: buffer, artifact: ArtifactData): { any }
	local formatData = FormatReader.read(buf, artifact)
	return buildInstancesFromFormatData(formatData, artifact)
end

-- Parses the v4 header + string table only (via FormatReader's magic/version check
-- plus a slice of V4's block-length-prefix logic), slices each class block's raw
-- bytes directly out of `data` (no full parse - that's the point of the v4 length
-- prefix), and hands each slice to its own Stage B decoder via one of three
-- backends, in order of preference:
--
--   a. Roblox Actor parallelism (RobloxBackend.decodeClassBlocksParallel) - used
--      inside the real Roblox engine. Takes an ordered array of per-class-block
--      decode payload buffers (the SAME wire format src/parallel/Payload.luau's
--      Payload.decode consumes) and returns an ordered array of result buffers
--      (instanceCount/columnCount/columns..., same shape a Worker.luau decode-mode
--      child process emits on stdout), in input order. No Lune processes involved.
--   b. Lune worker-process path (the original implementation): one
--      `lune run src/parallel/Worker.luau -- decode` child process per class block,
--      launched via blocking process.exec wrapped in task.spawn coroutines.
--   c. Sequential fallback: if neither Actors nor @lune/process are available,
--      give up on parallelism and call the plain sequential deserialize() -
--      correctness preserved, just not fast.
--
-- Stage C (instance construction) then runs sequentially in the parent via the
-- same buildInstancesFromFormatData used by deserialize().
--
-- Only supports v4 input (parallel encoding always writes v4; this is not a
-- general-purpose replacement for the sequential/versioned deserialize() path).
local function deserializeParallel(data: buffer, artifact: ArtifactData): { any }
	local r = BufferReader.new(data)

	local m0 = r:u8()
	local m1 = r:u8()
	local m2 = r:u8()
	local m3 = r:u8()
	assert(m0 == 0x4C and m1 == 0x41 and m2 == 0x54 and m3 == 0x46, "Invalid format magic bytes")

	local version = r:u16()
	assert(version == 4, "deserializeParallel only supports format v4, got version " .. tostring(version))

	local stringTableCount = r:varint()
	local stringTable = table.create(stringTableCount)
	for i = 1, stringTableCount do
		stringTable[i] = r:string()
	end

	local classBlockCount = r:varint()

	-- Peek each block's classId (first varint of the block body) and byte range
	-- without parsing the rest of the block, so we know which artifact class
	-- metadata to ship to each worker.
	type BlockSlice = { classId: number, bodyStart: number, bodyLength: number }
	local slices: { BlockSlice } = table.create(classBlockCount)

	for _ = 1, classBlockCount do
		local blockLength = r:varint()
		local bodyStart = r:pos()

		-- Peek the block body's leading classId varint via a throwaway reader over
		-- just this block's bytes, so the main reader `r` only ever advances
		-- forward by whole blocks (no rewinding its own position).
		local bodyBuf = buffer.create(blockLength)
		buffer.copy(bodyBuf, 0, data, bodyStart, blockLength)
		local peekReader = BufferReader.new(bodyBuf)
		local classId = peekReader:varint()

		table.insert(slices, { classId = classId, bodyStart = bodyStart, bodyLength = blockLength })

		-- Advance the main reader past this block's body (skip contents; workers
		-- will parse them independently from the sliced bytes).
		r:bytes(blockLength)
	end

	local n = #slices

	-- Build the per-class-block decode payload buffers once. Both Actor(path a)
	-- and Lune-process(path b) backends consume exactly this same wire format
	-- (see src/parallel/Payload.luau's Payload.decode).
	local payloads: { buffer } = table.create(n)
	for idx, slice in slices do
		local classMeta = artifact.classById[slice.classId]
		assert(classMeta, "Class metadata not found in artifact for class ID: " .. tostring(slice.classId))

		local payloadWriter = BufferWriter.new()
		payloadWriter:varint(slice.classId)
		payloadWriter:string(classMeta.name)
		payloadWriter:varint(#classMeta.properties)
		for _, pm in classMeta.properties do
			payloadWriter:string(pm.name)
			payloadWriter:varint(pm.codecId)
		end

		payloadWriter:varint(#stringTable)
		for _, str in stringTable do
			payloadWriter:string(str)
		end

		payloadWriter:varint(slice.bodyLength)
		local bodyBuf = buffer.create(slice.bodyLength)
		buffer.copy(bodyBuf, 0, data, slice.bodyStart, slice.bodyLength)
		payloadWriter:bytes(bodyBuf)

		payloads[idx] = payloadWriter:toBuffer()
	end

	-- decodedColumns[idx] is the result buffer for class block idx - the same
	-- shape both backends produce (instanceCount/columnCount/columns...).
	local decodedColumns: { buffer } = table.create(n)

	if RobloxBackend.isActorParallelAvailable() then
		-- Path a: Roblox Actor parallelism, no Lune processes spawned.
		decodedColumns = RobloxBackend.decodeClassBlocksParallel(payloads)
	else
		-- Path b/c: try the Lune worker-process path; if @lune/process isn't
		-- resolvable (a hypothetical third environment with neither Actors nor
		-- Lune), fall back to the plain sequential deserialize() - correctness
		-- preserved, just no parallelism.
		local processOk, process = pcall(require, "@lune/process")
		if not processOk or process == nil then
			return deserialize(data, artifact)
		end
		local processModule = process :: any

		local decodedStrs: { string? } = table.create(n)
		local errors: { string? } = table.create(n)

		for idx, payload in payloads do
			local classMeta = artifact.classById[slices[idx].classId]
			local payloadStr = buffer.tostring(payload)

			task.spawn(function()
				local result = processModule.exec("lune", { "run", "src/parallel/Worker.luau", "--", "decode" }, {
					stdio = { stdin = payloadStr },
				})
				if result.ok then
					decodedStrs[idx] = result.stdout
				else
					errors[idx] = string.format(
						"parallel decode failed for class %s: %s",
						classMeta.name,
						if result.stderr ~= "" then result.stderr else "exited with code " .. tostring(result.code)
					)
				end
			end)
		end

		local remaining = n
		while remaining > 0 do
			remaining = 0
			for idx = 1, n do
				if decodedStrs[idx] == nil and errors[idx] == nil then
					remaining += 1
				end
			end
			if remaining > 0 then
				task.wait(0.01)
			end
		end

		for idx = 1, n do
			if errors[idx] then
				error(errors[idx])
			end
		end

		for idx = 1, n do
			decodedColumns[idx] = buffer.fromstring(decodedStrs[idx] :: string)
		end
	end

	-- Decode each result buffer back into PropertyColumns.
	local classBlocks: { FormatTypes.ClassBlock } = table.create(n)
	for idx, slice in slices do
		local classMeta = artifact.classById[slice.classId]
		local or_ = BufferReader.new(decodedColumns[idx])

		local instanceCount = or_:varint()
		local columnCount = or_:varint()
		local columns = table.create(columnCount)

		for i = 1, columnCount do
			local propertyNameIndex = or_:varint()
			local encoding = or_:varint()

			local numBytes = math.ceil(instanceCount / 8)
			local maskBytes = if numBytes > 0 then or_:bytes(numBytes) else buffer.create(0)
			local bitmask = table.create(instanceCount)
			local k = 1
			for byteIdx = 0, numBytes - 1 do
				local byteVal = buffer.readu8(maskBytes, byteIdx)
				local limit = math.min(8, instanceCount - k + 1)
				for bitIdx = 0, limit - 1 do
					bitmask[k] = bit32.band(byteVal, bit32.lshift(1, bitIdx)) ~= 0
					k += 1
				end
			end

			local propName = stringTable[propertyNameIndex]
			assert(propName, "Property name index out of bounds in string table")
			local pm = nil
			for _, p in classMeta.properties do
				if p.name == propName then
					pm = p
					break
				end
			end
			assert(pm, "Property metadata not found for property: " .. propName)
			local codec = pm.codec

			local valueCount = or_:varint()
			local values = table.create(valueCount)
			for j = 1, valueCount do
				values[j] = codec.read(or_)
			end

			local hasDictIndices = or_:u8()
			local dictIndices: { number }? = nil
			if hasDictIndices == 1 then
				local dictIndexCount = or_:varint()
				local indices = table.create(dictIndexCount)
				for j = 1, dictIndexCount do
					indices[j] = or_:varint()
				end
				dictIndices = indices
			end

			columns[i] = {
				propertyNameIndex = propertyNameIndex,
				encoding = encoding,
				bitmask = bitmask,
				values = values,
				dictIndices = dictIndices,
			}
		end

		classBlocks[idx] = {
			classId = slice.classId,
			instanceCount = instanceCount,
			columns = columns,
		}
	end

	local formatData: FormatTypes.FormatData = {
		version = 4,
		stringTable = stringTable,
		classBlocks = classBlocks,
	}

	return buildInstancesFromFormatData(formatData, artifact)
end

-- Same thresholds as Serializer.serializeAuto (see that module for the
-- benchmark this was derived from - parallel only won past 6+ classes and
-- 12k+ total instances; smaller scenes lose to per-worker process-spawn
-- overhead in Lune).
local PARALLEL_MIN_CLASSES = 6
local PARALLEL_MIN_INSTANCES = 12000

-- Picks deserialize() or deserializeParallel() based on scene size. Only v4
-- buffers carry enough info (length-prefixed blocks) to peek classId/
-- instanceCount without a full parse; for any other version, deserialize()
-- is the only valid choice anyway; deserializeParallel would raise "only
-- supports format v4" (see comment on deserializeParallel above.
local function deserializeAuto(data: buffer, artifact: ArtifactData): { any }
	local r = BufferReader.new(data)

	local m0 = r:u8()
	local m1 = r:u8()
	local m2 = r:u8()
	local m3 = r:u8()
	if not (m0 == 0x4C and m1 == 0x41 and m2 == 0x54 and m3 == 0x46) then
		return deserialize(data, artifact)
	end

	local version = r:u16()
	if version ~= 4 then
		return deserialize(data, artifact)
	end

	local stringTableCount = r:varint()
	for _ = 1, stringTableCount do
		r:string()
	end

	local classBlockCount = r:varint()
	local totalInstances = 0

	for _ = 1, classBlockCount do
		local blockLength = r:varint()
		local bodyStart = r:pos()

		local bodyBuf = buffer.create(blockLength)
		buffer.copy(bodyBuf, 0, data, bodyStart, blockLength)
		local peekReader = BufferReader.new(bodyBuf)
		peekReader:varint() -- classId, unused here
		totalInstances += peekReader:varint() -- instanceCount

		r:bytes(blockLength)
	end

	if classBlockCount >= PARALLEL_MIN_CLASSES and totalInstances >= PARALLEL_MIN_INSTANCES then
		return deserializeParallel(data, artifact)
	end
	return deserialize(data, artifact)
end

return {
	deserialize = deserialize,
	deserializeParallel = deserializeParallel,
	deserializeAuto = deserializeAuto,
}
