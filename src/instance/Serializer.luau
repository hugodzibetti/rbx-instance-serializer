--!strict
--!native
--!optimize 2

local roblox = require("@lune/roblox")
local Types = require("@src/types")
local ArtifactTypes = require("@src/artifacts/types")
local FormatTypes = require("@src/format/types")
local FormatWriter = require("@src/format/Writer")
local BufferWriter = require("@src/buffer/Writer")

type ArtifactData = ArtifactTypes.ArtifactData
type ClassBlock = FormatTypes.ClassBlock
type PropertyColumn = FormatTypes.PropertyColumn
type FormatData = FormatTypes.FormatData

local function collectAll(roots: { any }): { any }
	local list = {}
	local visited = {}

	local function dfs(inst: any)
		if not inst or visited[inst] then
			return
		end
		visited[inst] = true
		table.insert(list, inst)

		local children = inst:GetChildren()
		for _, child in children do
			dfs(child)
		end
	end

	for _, root in roots do
		dfs(root)
	end

	return list
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

local function getValueSize(codec: any, val: any): number
	local tempW = BufferWriter.new()
	local ok = pcall(function()
		codec.write(tempW, val)
	end)
	if ok then
		return buffer.len(tempW:toBuffer())
	else
		return 0
	end
end

local function varintSize(val: number): number
	local size = 0
	local temp = val
	repeat
		size += 1
		temp = bit32.rshift(temp, 7)
	until temp == 0
	return size
end

-- disableDedup: for benchmarking only (bench/DedupVsDictionary.luau) — forces
-- whole-instance dedup off so real dedup-on vs dedup-off byte counts can be
-- compared with Dictionary encoding held constant. Not part of the public API.
local function serialize(roots: { any }, artifact: ArtifactData, disableDedup: boolean?): buffer
	local list = collectAll(roots)

	-- Bucket by ClassName
	local buckets: { [string]: { any } } = {}
	for _, inst in list do
		local className = inst.ClassName
		local bucket = buckets[className]
		if not bucket then
			bucket = {}
			buckets[className] = bucket
		end
		table.insert(bucket, inst)
	end

	-- Sort class names alphabetically
	local classNames = {}
	for name in buckets do
		table.insert(classNames, name)
	end
	table.sort(classNames)

	-- Assign implicit sequential 1-based global IDs
	local globalIdMap: { [string]: number } = {}
	local globalId = 0
	for _, className in classNames do
		local bucket = buckets[className]
		for _, inst in bucket do
			globalId += 1
			globalIdMap[inst:GetDebugId()] = globalId
		end
	end

	local stringTable: { string } = {}
	local stringMap: { [string]: number } = {}
	local function getStringIndex(str: string): number
		local idx = stringMap[str]
		if not idx then
			table.insert(stringTable, str)
			idx = #stringTable
			stringMap[str] = idx
		end
		return idx
	end

	local classBlocks: { ClassBlock } = {}

	for _, className in classNames do
		local bucket = buckets[className]
		local classMeta = artifact.classByName[className]
		if not classMeta then
			warn("Class metadata not found in artifact for class: " .. className)
			continue
		end

		local numBucket = #bucket

		local propsWithCodec = {}
		for _, pm in classMeta.properties do
			if pm.codec then
				table.insert(propsWithCodec, pm)
			end
		end

		local hasReferent = false
		for _, pm in propsWithCodec do
			if pm.codecId == 26 then
				hasReferent = true
				break
			end
		end

		-- Pass A: compute serialized value + isDefault for every property/instance
		local serializedByProp = table.create(#propsWithCodec)
		local isDefaultByProp = table.create(#propsWithCodec)

		for pIdx, pm in propsWithCodec do
			local serializedVals = table.create(numBucket)
			local isDefaults = table.create(numBucket)

			for i, inst in bucket do
				local ok, val = pcall(function()
					return inst[pm.name]
				end)
				if not ok then
					val = nil
				end

				local serializedVal = val
				local isDefault = false

				if pm.codecId == 25 then -- Enum
					if typeof(val) == "EnumItem" then
						serializedVal = val.Value
					elseif type(val) == "number" then
						serializedVal = val
					end
					isDefault = (serializedVal == pm.default)
				elseif pm.codecId == 26 then -- Referent
					local targetId = 0
					if val then
						targetId = globalIdMap[val:GetDebugId()] or 0
					end
					serializedVal = targetId
					isDefault = (serializedVal == 0)
				else
					isDefault = (val == pm.default)
				end

				serializedVals[i] = serializedVal
				isDefaults[i] = isDefault
			end

			serializedByProp[pIdx] = serializedVals
			isDefaultByProp[pIdx] = isDefaults
		end

		-- Template detection: whole-instance dedup within this class bucket.
		-- Skipped for buckets with a Referent property, since duplicate instances
		-- can't safely share reference-target semantics.
		--
		-- This coexists with column Dictionary encoding (encoding == 2) rather than
		-- being superseded by it: bench/DedupVsDictionary.luau does a real on/off
		-- byte-count comparison (dedup+Dictionary vs Dictionary-only) on a mixed
		-- fixture; see that benchmark's output / CLAUDE.md "Current Work" for the
		-- measured numbers before assuming either mechanism is safe to drop.
		local templateRefs: { number }? = nil
		if not disableDedup and not hasReferent and numBucket >= 2 and #propsWithCodec > 0 then
			-- ponytail: O(n^2) dedup scan per class bucket, upgrade: hash canonical value tuples if profiling shows buckets are large
			local refs = table.create(numBucket, 0)
			for i = 1, numBucket do
				if refs[i] == 0 then
					for j = i + 1, numBucket do
						if refs[j] == 0 then
							local equal = true
							for pIdx = 1, #propsWithCodec do
								if serializedByProp[pIdx][i] ~= serializedByProp[pIdx][j] then
									equal = false
									break
								end
							end
							if equal then
								refs[j] = i
							end
						end
					end
				end
			end

			local anyDup = false
			for i = 1, numBucket do
				if refs[i] ~= 0 then
					anyDup = true
					break
				end
			end

			if anyDup then
				templateRefs = refs
			end
		end

		local effectiveIndices: { number }? = nil
		local effectiveCount = numBucket
		if templateRefs then
			local indices = {}
			for i = 1, numBucket do
				if templateRefs[i] == 0 then
					table.insert(indices, i)
				end
			end
			effectiveIndices = indices
			effectiveCount = #indices
		end

		local columns: { PropertyColumn } = {}

		for pIdx, pm in propsWithCodec do
			local codec = pm.codec

			local serializedVals = serializedByProp[pIdx]
			local isDefaults = isDefaultByProp[pIdx]

			local allValues = table.create(effectiveCount)
			local bitmask = table.create(effectiveCount)
			local nonDefaultValues = {}
			local nonDefaultCount = 0

			for k = 1, effectiveCount do
				local i = if effectiveIndices then effectiveIndices[k] else k
				local serializedVal = serializedVals[i]
				local isDefault = isDefaults[i]

				allValues[k] = serializedVal
				bitmask[k] = not isDefault

				if not isDefault then
					table.insert(nonDefaultValues, serializedVal)
					nonDefaultCount += 1
				end
			end

			local encoding = 0
			local colValues = nonDefaultValues

			if nonDefaultCount == 0 then
				encoding = 3
				colValues = {}
				bitmask = table.create(effectiveCount, false)
			else
				-- Raw cost
				local sizeRaw = math.ceil(effectiveCount / 8)
				for _, v in nonDefaultValues do
					sizeRaw += getValueSize(codec, v)
				end
				local minSize = sizeRaw

				-- RLE cost
				local runs = runLengthEncode(nonDefaultValues)
				local sizeRle = math.ceil(effectiveCount / 8) + varintSize(#runs)
				for _, run in runs do
					sizeRle += varintSize(run.count) + getValueSize(codec, run.value)
				end

				if sizeRle < minSize then
					minSize = sizeRle
					encoding = 1
					colValues = nonDefaultValues
				end

				-- Dictionary cost: unique values (first-occurrence order) + per-instance index.
				-- Keyed by the value's actual serialized bytes (via the column's own codec),
				-- not tostring(v): tostring truncates float precision for Vector3/CFrame/etc,
				-- so numerically distinct values can print identically and get wrongly
				-- collapsed into one dictionary entry (silent data corruption on read-back).
				-- Serialized bytes are exactly what will be written to the wire, so this
				-- keying is collision-safe by construction.
				local uniqueValues = {}
				local dictIndexOf = {}
				local dictIndices = table.create(nonDefaultCount)
				for _, v in nonDefaultValues do
					local keyW = BufferWriter.new()
					codec.write(keyW, v)
					local key = buffer.tostring(keyW:toBuffer())
					local idx = dictIndexOf[key]
					if not idx then
						table.insert(uniqueValues, v)
						idx = #uniqueValues - 1 -- 0-based
						dictIndexOf[key] = idx
					end
					table.insert(dictIndices, idx)
				end

				local sizeDict = math.ceil(effectiveCount / 8) + varintSize(#uniqueValues)
				for _, v in uniqueValues do
					sizeDict += getValueSize(codec, v)
				end
				for _, idx in dictIndices do
					sizeDict += varintSize(idx)
				end

				local dictIndicesResult: { number }? = nil
				if sizeDict < minSize then
					minSize = sizeDict
					encoding = 2
					colValues = uniqueValues
					dictIndicesResult = dictIndices
				end

				-- AllNonDefault cost
				if nonDefaultCount == effectiveCount then
					local sizeAllNonDefault = 0
					for _, v in allValues do
						sizeAllNonDefault += getValueSize(codec, v)
					end
					if sizeAllNonDefault < minSize then
						minSize = sizeAllNonDefault
						encoding = 4
						colValues = allValues
						bitmask = table.create(effectiveCount, true)
						dictIndicesResult = nil
					end
				end

				table.insert(columns, {
					propertyNameIndex = getStringIndex(pm.name),
					encoding = encoding,
					bitmask = bitmask,
					values = colValues,
					dictIndices = dictIndicesResult,
				})
				continue
			end

			table.insert(columns, {
				propertyNameIndex = getStringIndex(pm.name),
				encoding = encoding,
				bitmask = bitmask,
				values = colValues,
			})
		end

		table.insert(classBlocks, {
			classId = classMeta.id,
			instanceCount = numBucket,
			columns = columns,
			templateRefs = templateRefs,
		})
	end

	local formatData: FormatData = {
		version = 1,
		stringTable = stringTable,
		classBlocks = classBlocks,
	}

	return FormatWriter.write(formatData, artifact)
end

return {
	serialize = serialize,
}
