--!strict
-- `lattice diff <before> <after>` — resolves both files to instance trees
-- (via src/instance/Deserializer.luau) and reports which properties changed.
--
-- Lattice has no stable cross-serialize instance identity. UniqueId (codec 24
-- / roblox.UniqueId, exposed as the `.UniqueId` property on instances that
-- have one assigned) is the closest thing Roblox provides, but it isn't
-- guaranteed present. matchInstances below uses UniqueId where available and
-- falls back to matching by traversal order (tree position) for instances
-- without one -- and reports which strategy actually resolved each match so
-- `diff` output doesn't silently guess.

local fs = require("@lune/fs")
local process = require("@lune/process")
local Artifact = require("@src/artifacts/Artifact")
local Deserializer = require("@src/instance/Deserializer")

export type MatchedPair = {
	before: any,
	after: any,
	strategy: "uniqueId" | "position",
}

export type MatchResult = {
	matched: { MatchedPair },
	added: { any }, -- present only in `after`
	removed: { any }, -- present only in `before`
}

-- Pure function: takes two flat instance lists (already resolved, any order)
-- and returns matched/added/removed. No file I/O, no CLI plumbing -- callable
-- directly from tests.
local function matchInstances(beforeList: { any }, afterList: { any }): MatchResult
	local function tryGetUniqueId(inst: any): string?
		local ok, val = pcall(function()
			return inst.UniqueId
		end)
		if ok and val ~= nil then
			local okStr, str = pcall(tostring, val)
			-- Lune's roblox binding never auto-assigns UniqueId, so freshly
			-- constructed instances all share the null id; treat it as absent
			-- rather than a false match.
			if okStr and str ~= "00000000000000000000000000000000" then
				return str
			end
		end
		return nil
	end

	local beforeById: { [string]: any } = {}
	local beforeNoId: { any } = {}
	for _, inst in beforeList do
		local uid = tryGetUniqueId(inst)
		if uid then
			beforeById[uid] = inst
		else
			table.insert(beforeNoId, inst)
		end
	end

	local afterById: { [string]: any } = {}
	local afterNoId: { any } = {}
	for _, inst in afterList do
		local uid = tryGetUniqueId(inst)
		if uid then
			afterById[uid] = inst
		else
			table.insert(afterNoId, inst)
		end
	end

	local matched: { MatchedPair } = {}
	local removed: { any } = {}
	local addedById: { [string]: boolean } = {}

	for uid, beforeInst in beforeById do
		local afterInst = afterById[uid]
		if afterInst then
			table.insert(matched, { before = beforeInst, after = afterInst, strategy = "uniqueId" })
			afterById[uid] = nil
		else
			table.insert(removed, beforeInst)
		end
	end

	local added: { any } = {}
	for _, afterInst in afterById do
		table.insert(added, afterInst)
	end

	-- Positional fallback for instances lacking a UniqueId: pair by traversal
	-- order. Extra entries on either side become added/removed.
	local n = math.min(#beforeNoId, #afterNoId)
	for i = 1, n do
		table.insert(matched, { before = beforeNoId[i], after = afterNoId[i], strategy = "position" })
	end
	for i = n + 1, #beforeNoId do
		table.insert(removed, beforeNoId[i])
	end
	for i = n + 1, #afterNoId do
		table.insert(added, afterNoId[i])
	end

	return {
		matched = matched,
		added = added,
		removed = removed,
	}
end

local function collectAll(roots: { any }): { any }
	local list = {}
	local visited: { [any]: boolean } = {}
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

local function describeInstance(inst: any): string
	local uid: string? = nil
	local ok, val = pcall(function()
		return inst.UniqueId
	end)
	if ok and val ~= nil then
		local okStr, str = pcall(tostring, val)
		if okStr and str ~= "00000000000000000000000000000000" then
			uid = str
		end
	end
	if uid then
		return string.format("%s[uid:%s]", inst.ClassName, uid:sub(1, 8))
	end
	return string.format("%s[%s]", inst.ClassName, inst.Name)
end

local function propList(classMeta: any): { any }
	local props = {}
	for _, pm in classMeta.properties do
		if pm.codec and pm.codecId ~= 26 then -- skip Referent props (Parent etc.)
			table.insert(props, pm)
		end
	end
	return props
end

local function run(args: { string })
	local beforePath = args[1]
	local afterPath = args[2]
	if not beforePath or not afterPath then
		print("Usage: lattice diff <before.lattice> <after.lattice>")
		process.exit(1)
		return
	end

	local artifactBuf = buffer.fromstring(fs.readFile("data/artifact.bin"))
	local artifact = Artifact.load(artifactBuf)

	local beforeBuf = buffer.fromstring(fs.readFile(beforePath))
	local afterBuf = buffer.fromstring(fs.readFile(afterPath))

	local beforeRoots = Deserializer.deserialize(beforeBuf, artifact)
	local afterRoots = Deserializer.deserialize(afterBuf, artifact)

	local beforeList = collectAll(beforeRoots)
	local afterList = collectAll(afterRoots)

	local result = matchInstances(beforeList, afterList)

	print(string.format("%s vs %s", beforePath, afterPath))
	print("")

	local changedCount = 0
	local uidMatches = 0
	local posMatches = 0

	for _, pair in result.matched do
		if pair.strategy == "uniqueId" then
			uidMatches += 1
		else
			posMatches += 1
		end

		if pair.before.ClassName ~= pair.after.ClassName then
			continue
		end

		local classMeta = artifact.classByName[pair.before.ClassName]
		if not classMeta then
			continue
		end

		for _, pm in propList(classMeta) do
			local okB, before = pcall(function()
				return pair.before[pm.name]
			end)
			local okA, after = pcall(function()
				return pair.after[pm.name]
			end)
			if okB and okA and before ~= after then
				changedCount += 1
				print(string.format("~ %s %s: %s -> %s", describeInstance(pair.before), pm.name, tostring(before), tostring(after)))
			end
		end
	end

	for _, inst in result.added do
		print(string.format("+ %s (new instance)", describeInstance(inst)))
	end
	for _, inst in result.removed do
		print(string.format("- %s (removed)", describeInstance(inst)))
	end

	print("")
	print(string.format(
		"%d properties changed, %d instance%s added, %d instance%s removed",
		changedCount,
		#result.added,
		if #result.added == 1 then "" else "s",
		#result.removed,
		if #result.removed == 1 then "" else "s"
	))
	print(string.format(
		"(%d instances matched by UniqueId, %d matched by tree position -- no UniqueId present)",
		uidMatches,
		posMatches
	))
end

return {
	matchInstances = matchInstances,
	run = run,
}
