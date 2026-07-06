--!strict
--!native
--!optimize 2

-- Computes a patch (LATP buffer) between a baseline .lattice snapshot and a
-- live current instance tree. MVP scope only: baseline + exactly one patch,
-- no chained history, no compaction, no conflict resolution, no
-- sub-property deltas. See
-- docs/superpowers/specs/2026-07-05-incremental-delta-encoding-design.md.

local ArtifactTypes = require("@src/artifacts/types")
local BufferWriter = require("@src/buffer/Writer")
local Deserializer = require("@src/instance/Deserializer")
local PropertyCompare = require("@src/instance/PropertyCompare")
local Identity = require("@src/patch/Identity")

type ArtifactData = ArtifactTypes.ArtifactData
type ClassMetadata = ArtifactTypes.ClassMetadata
type PropertyMetadata = ArtifactTypes.PropertyMetadata
type Identity = Identity.Identity

local MAGIC = { 0x4C, 0x41, 0x54, 0x50 } -- "LATP"
local VERSION = 1

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

local function buildParentChildLookup(list: { any }): ((any) -> any?, (any) -> { any })
	-- Parent lookup uses Roblox's own .Parent; children lookup uses
	-- GetChildren() restricted to instances present in `list` (so identity
	-- paths are computed consistently against the same instance set used
	-- for diffing, not against live-tree children that might include
	-- instances outside the diffed roots).
	--
	-- IMPORTANT: Lune's `roblox` binding hands back a fresh userdata wrapper
	-- from every `GetChildren()`/property-read call. Two wrappers for the
	-- *same* underlying instance compare equal with `==`, but are NOT
	-- interchangeable as table keys (a table keyed by one wrapper won't be
	-- found via `t[otherWrapper]`, even though `otherWrapper == wrapper`).
	-- So membership/lookup here is keyed by `GetDebugId()` (a stable string)
	-- rather than by the instance value itself, and canonical instance
	-- objects (the ones from `list`, which callers already hold onto) are
	-- returned instead of whatever wrapper `GetChildren()`/`.Parent` handed
	-- back.
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

-- Builds an identity -> instance map, and a per-instance "used fallback"
-- flag (true when the instance's identity is a positional path rather than
-- a UniqueId), for a list of instances belonging to a single tree snapshot.
local function buildIdentityMap(
	list: { any }
): ({ [string]: any }, { [any]: boolean }, { [any]: Identity })
	local parentOf, childrenOf = buildParentChildLookup(list)
	local map: { [string]: any } = {}
	local usedFallback: { [any]: boolean } = {}
	local identityOf: { [any]: Identity } = {}
	local siblingCache = Identity.newSiblingCache()

	for _, inst in list do
		local id = Identity.computeIdentity(inst, parentOf, childrenOf, siblingCache)
		identityOf[inst] = id
		usedFallback[inst] = (id.kind == "path")
		map[Identity.identityKey(id)] = inst
	end

	return map, usedFallback, identityOf
end

local function getStringIndexFactory(): ((string) -> number, () -> { string })
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
	local function getTable(): { string }
		return stringTable
	end
	return getStringIndex, getTable
end

-- Writes an Identity to the patch buffer. String-table indices for path
-- segment class names are resolved via `getStringIndex` (patch-local table,
-- separate from the main format's string table).
local function writeIdentity(w: BufferWriter.Writer, id: Identity, getStringIndex: (string) -> number)
	if id.kind == "uniqueId" then
		w:u8(0)
		w:bytes(Identity.tryGetUniqueId and (function()
			-- id.uniqueId is the raw UniqueId userdata; reuse the uniqueId
			-- codec's own hex-to-bytes convention by writing via the codec
			-- module directly would require a Writer.Writer both use the
			-- same. We inline the same approach as src/serde/uniqueId.luau.
			local raw = buffer.create(16)
			local hex = tostring(id.uniqueId)
			for i = 0, 15 do
				local byte = tonumber(hex:sub(i * 2 + 1, i * 2 + 2), 16) :: number
				buffer.writeu8(raw, i, byte)
			end
			return raw
		end)(), 16)
	else
		w:u8(1)
		local path = id.path :: { { className: string, siblingIndex: number } }
		w:varint(#path)
		for _, seg in path do
			w:varint(getStringIndex(seg.className))
			w:varint(seg.siblingIndex)
		end
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

export type DiffResult = {
	patch: buffer,
	usedFallbackCount: number,
}

-- diff(baselineBuf, baselineArtifact, currentRoots) -> DiffResult
--
-- `baselineBuf` is a full .lattice (LATF) buffer previously produced by
-- Serializer.serialize against `artifact`. `currentRoots` is the live
-- instance tree to diff against that baseline.
local function diff(baselineBuf: buffer, artifact: ArtifactData, currentRoots: { any }): DiffResult
	local baselineRoots = Deserializer.deserialize(baselineBuf, artifact)
	local baselineList = collectAll(baselineRoots)
	local currentList = collectAll(currentRoots)

	local baselineMap, _baselineFallback, _baselineIdentity = buildIdentityMap(baselineList)
	local currentMap, currentFallback, currentIdentity = buildIdentityMap(currentList)

	-- globalIdMap for Referent resolution within the *current* tree: assign
	-- ids by the same deterministic order diff walks currentList, so
	-- Referent property comparisons are self-consistent within one diff
	-- call (patch-local ids, not tied to any prior serialize() call).
	local globalIdMap: { [string]: number } = {}
	-- Canonical instance lookups by GetDebugId(): needed because reading a
	-- Referent-typed property (e.g. `.Parent`) via Lune's `roblox` binding
	-- returns a fresh userdata wrapper each time, which is NOT usable
	-- directly as a key into `currentIdentity`/`baselineMap` even though it
	-- `==`-compares equal to the canonical instance (same gotcha as
	-- buildParentChildLookup above).
	local currentByDebugId: { [string]: any } = {}
	local baselineByDebugId: { [string]: any } = {}
	for i, inst in currentList do
		globalIdMap[inst:GetDebugId()] = i
		currentByDebugId[inst:GetDebugId()] = inst
	end
	for _, inst in baselineList do
		baselineByDebugId[inst:GetDebugId()] = inst
	end

	local getStringIndex, getStringTable = getStringIndexFactory()

	local changed = {}
	local added = {}
	local usedFallbackCount = 0

	local matchedBaseline: { [any]: boolean } = {}

	for _, inst in currentList do
		local id = currentIdentity[inst]
		if currentFallback[inst] then
			usedFallbackCount += 1
		end
		local key = Identity.identityKey(id)
		local baseInst = baselineMap[key]

		if baseInst == nil then
			table.insert(added, inst)
		else
			matchedBaseline[baseInst] = true
			local className = inst.ClassName
			local classMeta = artifact.classByName[className]
			if classMeta then
				local changedProps = {}
				for _, pm in classMeta.properties do
					if pm.codec then
						local curVal, curIsDefault = PropertyCompare.computeSerializedValue(inst, pm, globalIdMap)
						local baseVal, baseIsDefault =
							PropertyCompare.computeSerializedValue(baseInst, pm, globalIdMap)
						-- Compare on serialized form: for non-Referent props this is
						-- the direct value; Referent comparisons are inherently
						-- patch-local (both sides resolved against globalIdMap
						-- built from currentList) so identical-shaped references
						-- compare equal even though raw target ids differ from the
						-- baseline file's own numbering.
						local differs
						if pm.codecId == 26 then
							-- Referent: compare by resolved *identity* of the target,
							-- not raw id, since baseline ids and current ids come from
							-- different numbering spaces. Targets are resolved to
							-- canonical instances via GetDebugId() before being used
							-- as table keys (see currentByDebugId/baselineByDebugId
							-- above) since the raw values returned here are fresh,
							-- non-key-comparable wrappers.
							local ok1, curTargetRaw = pcall(function()
								return inst[pm.name]
							end)
							local ok2, baseTargetRaw = pcall(function()
								return baseInst[pm.name]
							end)
							local curTarget = if ok1 and curTargetRaw then currentByDebugId[curTargetRaw:GetDebugId()] else nil
							local baseTarget = if ok2 and baseTargetRaw then baselineByDebugId[baseTargetRaw:GetDebugId()] else nil

							if curTarget == nil and baseTarget == nil then
								differs = false
							elseif curTarget == nil or baseTarget == nil then
								differs = true
							else
								local curId = currentIdentity[curTarget]
								if curId == nil then
									differs = true
								else
									local curKey = Identity.identityKey(curId)
									local baseTargetMatch = baselineMap[curKey]
									differs = baseTargetMatch ~= baseTarget
								end
							end
						else
							differs = curVal ~= baseVal
						end

						if differs then
							table.insert(changedProps, { pm = pm, value = curVal })
						end
					end
				end

				if #changedProps > 0 then
					table.insert(changed, { inst = inst, identity = id, classMeta = classMeta, props = changedProps })
				end
			end
		end
	end

	local removed = {}
	local baselineParentOf, baselineChildrenOf = buildParentChildLookup(baselineList)
	local removedSiblingCache = Identity.newSiblingCache()
	for _, baseInst in baselineList do
		if not matchedBaseline[baseInst] then
			local id = Identity.computeIdentity(baseInst, baselineParentOf, baselineChildrenOf, removedSiblingCache)
			table.insert(removed, id)
		end
	end

	-- Serialize patch buffer.
	local body = BufferWriter.new()

	body:varint(#baselineList)
	body:varint(#changed)

	for _, entry in changed do
		writeIdentity(body, entry.identity, getStringIndex)
		body:varint(entry.classMeta.id)
		body:varint(#entry.props)
		for _, cp in entry.props do
			body:varint(getStringIndex(cp.pm.name))
			cp.pm.codec.write(body, cp.value)
		end
	end

	body:varint(#added)
	for _, inst in added do
		local className = inst.ClassName
		local classMeta = artifact.classByName[className]
		assert(classMeta, "Class metadata not found in artifact for class: " .. className)
		body:varint(classMeta.id)

		local propsWithCodec = {}
		for _, pm in classMeta.properties do
			if pm.codec then
				table.insert(propsWithCodec, pm)
			end
		end

		local nonDefault = {}
		for _, pm in propsWithCodec do
			local val, isDefault = PropertyCompare.computeSerializedValue(inst, pm, globalIdMap)
			if not isDefault then
				table.insert(nonDefault, { pm = pm, value = val })
			end
		end

		body:varint(#nonDefault)
		for _, np in nonDefault do
			body:varint(getStringIndex(np.pm.name))
			np.pm.codec.write(body, np.value)
		end
	end

	body:varint(#removed)
	for _, id in removed do
		writeIdentity(body, id, getStringIndex)
	end

	-- Prepend header now that the patch-local string table is finalized.
	local out = BufferWriter.new()
	out:u8(MAGIC[1])
	out:u8(MAGIC[2])
	out:u8(MAGIC[3])
	out:u8(MAGIC[4])
	out:u16(VERSION)

	local stringTable = getStringTable()
	out:varint(#stringTable)
	for _, s in stringTable do
		out:string(s)
	end

	out:bytes(body:toBuffer())

	return {
		patch = out:toBuffer(),
		usedFallbackCount = usedFallbackCount,
	}
end

return {
	diff = diff,
}
