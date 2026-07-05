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

		local columns: { PropertyColumn } = {}

		for _, pm in classMeta.properties do
			local codec = pm.codec
			if not codec then
				continue
			end

			local allValues = {}
			local nonDefaultValues = {}
			local bitmask = {}
			local nonDefaultCount = 0

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
				bitmask = table.create(#bucket, false)
			else
				-- Raw cost
				local sizeRaw = math.ceil(#bucket / 8)
				for _, v in nonDefaultValues do
					sizeRaw += getValueSize(codec, v)
				end
				local minSize = sizeRaw

				-- RLE cost
				local runs = runLengthEncode(nonDefaultValues)
				local sizeRle = math.ceil(#bucket / 8) + varintSize(#runs)
				for _, run in runs do
					sizeRle += varintSize(run.count) + getValueSize(codec, run.value)
				end

				if sizeRle < minSize then
					minSize = sizeRle
					encoding = 1
					colValues = nonDefaultValues
				end

				-- AllNonDefault cost
				if nonDefaultCount == #bucket then
					local sizeAllNonDefault = 0
					for _, v in allValues do
						sizeAllNonDefault += getValueSize(codec, v)
					end
					if sizeAllNonDefault < minSize then
						minSize = sizeAllNonDefault
						encoding = 4
						colValues = allValues
						bitmask = table.create(#bucket, true)
					end
				end
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
			instanceCount = #bucket,
			columns = columns,
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
