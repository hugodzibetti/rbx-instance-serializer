--!strict
--!native
--!optimize 2

local roblox = require("@lune/roblox")
local Types = require("@src/types")
local ArtifactTypes = require("@src/artifacts/types")
local FormatTypes = require("@src/format/types")
local FormatWriter = require("@src/format/Writer")
local BufferWriter = require("@src/buffer/Writer")
local PropertyCompare = require("@src/instance/PropertyCompare")
local CostEstimator = require("@src/format/CostEstimator")

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

local function serialize(roots: { any }, artifact: ArtifactData): buffer
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
				local serializedVal, isDefault = PropertyCompare.computeSerializedValue(inst, pm, globalIdMap)
				serializedVals[i] = serializedVal
				isDefaults[i] = isDefault
			end

			serializedByProp[pIdx] = serializedVals
			isDefaultByProp[pIdx] = isDefaults
		end

		local effectiveCount = numBucket

		local columns: { PropertyColumn } = {}

		for pIdx, pm in propsWithCodec do
			local codec = pm.codec

			local serializedVals = serializedByProp[pIdx]
			local isDefaults = isDefaultByProp[pIdx]

			local allValues = table.create(effectiveCount)
			local bitmask = table.create(effectiveCount)
			local nonDefaultValues = {}
			local nonDefaultCount = 0

			for i = 1, effectiveCount do
				local serializedVal = serializedVals[i]
				local isDefault = isDefaults[i]

				allValues[i] = serializedVal
				bitmask[i] = not isDefault

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
				local minSize = CostEstimator.sizeRaw(codec, effectiveCount, nonDefaultValues)

				local rleCost = CostEstimator.sizeRle(codec, effectiveCount, nonDefaultValues)
				if rleCost < minSize then
					minSize = rleCost
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

				local sizeDict = math.ceil(effectiveCount / 8) + CostEstimator.varintSize(#uniqueValues)
				for _, v in uniqueValues do
					sizeDict += CostEstimator.getValueSize(codec, v)
				end
				for _, idx in dictIndices do
					sizeDict += CostEstimator.varintSize(idx)
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
					local allNonDefaultCost = CostEstimator.sizeAllNonDefault(codec, allValues)
					if allNonDefaultCost < minSize then
						minSize = allNonDefaultCost
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
		})
	end

	local formatData: FormatData = {
		version = 3,
		stringTable = stringTable,
		classBlocks = classBlocks,
	}

	return FormatWriter.write(formatData, artifact)
end

return {
	serialize = serialize,
}
