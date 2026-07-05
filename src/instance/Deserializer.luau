--!strict
--!native
--!optimize 2

local roblox = require("@lune/roblox")
local Types = require("@src/types")
local ArtifactTypes = require("@src/artifacts/types")
local FormatTypes = require("@src/format/types")
local FormatReader = require("@src/format/Reader")

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

local function deserialize(buf: buffer, artifact: ArtifactData): { any }
	local formatData = FormatReader.read(buf, artifact)

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

			-- Reconstruct values array
			local values = table.create(cb.instanceCount)
			if col.encoding == 3 then -- AllDefault
				for i = 1, cb.instanceCount do
					values[i] = pm.default
				end
			elseif col.encoding == 4 then -- AllNonDefault
				for i = 1, cb.instanceCount do
					values[i] = col.values[i]
				end
			elseif col.encoding == 0 or col.encoding == 1 then
				local nonDefaultIdx = 1
				for i = 1, cb.instanceCount do
					if col.bitmask[i] then
						values[i] = col.values[nonDefaultIdx]
						nonDefaultIdx += 1
					else
						values[i] = pm.default
					end
				end
			else
				error("Unsupported encoding: " .. tostring(col.encoding))
			end

			-- Apply values to instances
			for i = 1, cb.instanceCount do
				local inst = classInstances[i]
				local val = values[i]

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

return {
	deserialize = deserialize,
}
