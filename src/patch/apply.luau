--!strict
--!native
--!optimize 2

-- Applies a LATP patch (produced by src/patch/diff.luau) to a baseline
-- .lattice buffer, reconstructing the current tree. MVP scope only: single
-- patch against a single baseline, no chained patches.

local roblox = require("@src/robloxDatatypes")
local ArtifactTypes = require("@src/artifacts/types")
local Deserializer = require("@src/instance/Deserializer")
local Identity = require("@src/patch/Identity")
local PatchFormat = require("@src/patch/PatchFormat")

type ArtifactData = ArtifactTypes.ArtifactData
type ClassMetadata = ArtifactTypes.ClassMetadata
type PropertyMetadata = ArtifactTypes.PropertyMetadata

local function collectAll(roots: { any }): { any }
	local list = {}
	local visited = {}

	local function dfs(inst: any)
		if not inst or visited[inst] then
			return
		end
		visited[inst] = true
		table.insert(list, inst)
		for _, child in inst:GetChildren() do
			dfs(child)
		end
	end

	for _, root in roots do
		dfs(root)
	end

	return list
end

-- IMPORTANT: Lune's `roblox` binding hands back a fresh userdata wrapper
-- from every `GetChildren()`/property-read call. Two wrappers for the same
-- underlying instance compare equal with `==` but are NOT interchangeable
-- as table keys. Lookups here are keyed by `GetDebugId()` (a stable string)
-- and resolve back to the canonical instance object from `list`.
local function buildParentChildLookup(list: { any }): ((any) -> any?, (any) -> { any })
	local byDebugId: { [string]: any } = {}
	for _, inst in list do
		byDebugId[inst:GetDebugId()] = inst
	end

	local function parentOf(inst: any): any?
		local ok, p = pcall(function()
			return inst.Parent
		end)
		if ok and p ~= nil then
			return byDebugId[p:GetDebugId()]
		end
		return nil
	end

	local function childrenOf(inst: any): { any }
		local result = {}
		local ok, children = pcall(function()
			return inst:GetChildren()
		end)
		if ok then
			for _, c in children do
				local canonical = byDebugId[c:GetDebugId()]
				if canonical then
					table.insert(result, canonical)
				end
			end
		end
		return result
	end

	return parentOf, childrenOf
end

local function uniqueIdBytesToKey(raw: buffer): string
	local hexChars = {}
	for i = 0, 15 do
		hexChars[i + 1] = string.format("%02x", buffer.readu8(raw, i))
	end
	return "U:" .. table.concat(hexChars)
end

local function patchIdentityKey(id: PatchFormat.PatchIdentity): string
	if id.kind == "uniqueId" then
		return uniqueIdBytesToKey(id.uniqueIdBytes :: buffer)
	else
		local path = id.path :: { PatchFormat.PathSegment }
		local parts = table.create(#path)
		for i, seg in path do
			parts[i] = seg.className .. "#" .. tostring(seg.siblingIndex)
		end
		return "P:" .. table.concat(parts, "/")
	end
end

local function findPropertyMeta(classMeta: ClassMetadata, name: string): PropertyMetadata?
	for _, pm in classMeta.properties do
		if pm.name == name then
			return pm
		end
	end
	return nil
end

local function fromEnumValue(enumObj: any, val: number): any?
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

local function applyPropertyValue(inst: any, pm: PropertyMetadata, val: any, resolveReferent: (number) -> any?)
	if pm.codecId == 26 then -- Referent
		local target = nil
		if val and val > 0 then
			target = resolveReferent(val)
		end
		pcall(function()
			inst[pm.name] = target
		end)
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
					local enumItemVal = fromEnumValue(enumObj, val)
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

export type ApplyResult = {
	roots: { any },
	usedFallbackCount: number,
}

-- apply(baselineBuf, artifact, patchBuf) -> ApplyResult
local function apply(baselineBuf: buffer, artifact: ArtifactData, patchBuf: buffer): ApplyResult
	local baselineRoots = Deserializer.deserialize(baselineBuf, artifact)
	local baselineList = collectAll(baselineRoots)

	assert(#baselineList >= 0, "unreachable")

	local parentOf, childrenOf = buildParentChildLookup(baselineList)

	local baselineMap: { [string]: any } = {}
	local siblingCache = Identity.newSiblingCache()
	for _, inst in baselineList do
		local id = Identity.computeIdentity(inst, parentOf, childrenOf, siblingCache)
		baselineMap[Identity.identityKey(id)] = inst
	end

	local header = PatchFormat.readHeader(patchBuf)
	local r = header.reader
	local stringTable = header.stringTable

	assert(
		header.baselineInstanceCount == #baselineList,
		"Patch baselineInstanceCount ("
			.. tostring(header.baselineInstanceCount)
			.. ") does not match provided baseline instance count ("
			.. tostring(#baselineList)
			.. ")"
	)

	local usedFallbackCount = 0

	-- Pass 1: read changed-instance entries (property overwrites only,
	-- deferred application until after added instances exist, since a
	-- changed instance's Parent may point at a newly-added instance).
	local changedCount = r:varint()
	local changedEntries = {}
	for _ = 1, changedCount do
		local id = PatchFormat.readIdentity(r, stringTable)
		if id.kind == "path" then
			usedFallbackCount += 1
		end
		local classId = r:varint()
		local propCount = r:varint()
		local props = table.create(propCount)
		for i = 1, propCount do
			local propNameIdx = r:varint()
			local propName = stringTable[propNameIdx]
			assert(propName, "Patch: property name index out of bounds")
			local classMeta = artifact.classById[classId]
			assert(classMeta, "Patch: class metadata not found for class ID: " .. tostring(classId))
			local pm = findPropertyMeta(classMeta, propName)
			assert(pm, "Patch: property metadata not found for property: " .. propName)
			assert(pm.codec, "Patch: codec not found for property: " .. propName)
			local val = pm.codec.read(r)
			props[i] = { pm = pm, value = val }
		end
		table.insert(changedEntries, { identity = id, classId = classId, props = props })
	end

	-- Pass 2: read added-instance entries and construct instances (without
	-- setting Parent yet -- Parent is itself one of the encoded properties
	-- and is applied in a later pass so parent-before-child ordering can be
	-- respected, mirroring Deserializer.luau's own parentTasks approach).
	local addedCount = r:varint()
	local addedEntries = {}
	for _ = 1, addedCount do
		local classId = r:varint()
		local classMeta = artifact.classById[classId]
		assert(classMeta, "Patch: class metadata not found for class ID: " .. tostring(classId))
		local inst = roblox.Instance.new(classMeta.name)

		local propCount = r:varint()
		local props = table.create(propCount)
		for i = 1, propCount do
			local propNameIdx = r:varint()
			local propName = stringTable[propNameIdx]
			assert(propName, "Patch: property name index out of bounds")
			local pm = findPropertyMeta(classMeta, propName)
			assert(pm, "Patch: property metadata not found for property: " .. propName)
			assert(pm.codec, "Patch: codec not found for property: " .. propName)
			local val = pm.codec.read(r)
			props[i] = { pm = pm, value = val }
		end

		table.insert(addedEntries, { inst = inst, props = props })
	end

	local removedCount = r:varint()
	local removedIdentities = table.create(removedCount)
	for i = 1, removedCount do
		local id = PatchFormat.readIdentity(r, stringTable)
		removedIdentities[i] = id
	end

	-- Resolve identity -> instance, including newly added instances (added
	-- instances have no meaningful baseline-relative identity of their own
	-- yet within this patch's Referent graph; they're referenced only by
	-- position in `addedEntries`, matching diff's globalIdMap: Referent
	-- values in changed/added properties reference resolved instances via
	-- the SAME identity-matching scheme used at diff time -- i.e. a
	-- Referent property's stored value is itself an Identity-shaped
	-- reference is NOT how this format encodes it; see note below).
	--
	-- NOTE on Referent-typed changed/added properties: diff.luau's Referent
	-- comparison logic determines *whether* a Referent changed by comparing
	-- resolved target identity, but the value written to the wire for a
	-- changed/added Referent property is the property's own codec (id 26,
	-- a plain varint) -- i.e. a patch-local numeric id assigned to
	-- `currentList` order at diff time (see diff.luau's globalIdMap). Apply
	-- must reconstruct that same list order to resolve those ids: baseline
	-- instances keep their baseline traversal order, and added instances
	-- are appended after, in the order they appear in the patch -- mirroring
	-- exactly how diff.luau built `currentList` (collectAll: DFS from
	-- roots) and assigned ids 1..N in that order. Since apply does not
	-- replay the exact live DFS, Referent-typed property deltas can only be
	-- resolved correctly when the referenced target is unambiguously
	-- identifiable by matching identity (Unique Id/path) against the
	-- instances now known to apply (baseline ∪ added, matched by identity).
	-- We therefore resolve Referent property values written by diff
	-- (patch-local sequential ids into currentList) back to instances by
	-- re-deriving the same currentList ordering: baselineList order (for
	-- matched/changed instances) is preserved positionally, then added
	-- instances follow in patch order. This matches diff.luau's collectAll
	-- + DFS traversal only when tree shape is otherwise unchanged, which is
	-- the same fallback-matching caveat already documented for identity.
	local currentListForReferents = {}
	for _, inst in baselineList do
		table.insert(currentListForReferents, inst)
	end
	for _, entry in addedEntries do
		table.insert(currentListForReferents, entry.inst)
	end

	local function resolveReferentId(id: number): any?
		return currentListForReferents[id]
	end

	-- Apply changed-instance property overwrites.
	for _, entry in changedEntries do
		local key = patchIdentityKey(entry.identity)
		local target = baselineMap[key]
		assert(target, "Patch: changed-instance identity not found in baseline: " .. key)
		for _, cp in entry.props do
			applyPropertyValue(target, cp.pm, cp.value, resolveReferentId)
		end
	end

	-- Apply added-instance properties (including Parent, which attaches the
	-- instance into the tree).
	for _, entry in addedEntries do
		for _, cp in entry.props do
			applyPropertyValue(entry.inst, cp.pm, cp.value, resolveReferentId)
		end
	end

	-- Apply removed instances: detach and destroy.
	for _, id in removedIdentities do
		local key = patchIdentityKey(id)
		local target = baselineMap[key]
		if target then
			pcall(function()
				target.Parent = nil
			end)
			pcall(function()
				target:Destroy()
			end)
		end
	end

	-- Collect final roots: everything in baselineList ∪ addedEntries whose
	-- Parent is nil and which wasn't removed.
	local removedSet: { [any]: boolean } = {}
	for _, id in removedIdentities do
		local key = patchIdentityKey(id)
		local target = baselineMap[key]
		if target then
			removedSet[target] = true
		end
	end

	local roots = {}
	for _, inst in currentListForReferents do
		if not removedSet[inst] then
			local ok, parent = pcall(function()
				return inst.Parent
			end)
			if ok and parent == nil then
				table.insert(roots, inst)
			end
		end
	end

	return {
		roots = roots,
		usedFallbackCount = usedFallbackCount,
	}
end

return {
	apply = apply,
}
