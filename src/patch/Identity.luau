--!strict
--!native
--!optimize 2

-- Cross-call instance identity matching for src/patch/.
--
-- NOTE: this is independently implemented for src/patch/ only. The design
-- doc (docs/superpowers/specs/2026-07-05-incremental-delta-encoding-design.md)
-- flags that the CLI Tooling spec's `lattice diff` command needs the exact
-- same matching problem solved, and that whichever of the two lands second
-- should reuse the other's matching function rather than re-implementing it.
-- At the time this was written, this worktree had no visibility into any
-- `cli/Diff.luau` matching function, so this is a from-scratch implementation
-- scoped to src/patch/. Reconciling the two (if `cli/Diff.luau` exists or is
-- added later) is follow-up work, not done here.
--
-- Strategy:
--  1. Prefer UniqueId (stable across serialize/deserialize calls, when the
--     class exposes it) as the identity key.
--  2. Fall back to a stable structural path when UniqueId is absent: the
--     sequence of (ClassName, siblingIndex) pairs from a root, where
--     siblingIndex is this instance's position among same-ClassName
--     siblings of the same parent, siblings sorted by a deterministic key
--     (UniqueId if present on ANY sibling, else insertion/GetChildren()
--     order at snapshot time -- see note below). This is intentionally NOT
--     a raw GetChildren() traversal index, since that shifts if any earlier
--     sibling anywhere in the tree is added/removed; scoping the index to
--     "siblings sharing this instance's ClassName under this parent" keeps
--     it far more stable across unrelated edits elsewhere in the tree, per
--     the design doc's explicit warning against a fragile whole-tree index.
--
-- Fallback matching is inherently best-effort: it is correct when tree
-- shape (parent/ClassName/ordering) is unchanged near the instance, and can
-- misfire if siblings of the same class were reordered, added, or removed.
-- Callers must treat `usedFallback` as a transparency signal, not swallow
-- it (see design doc's Testing section).

export type IdentityKind = "uniqueId" | "path"

export type Identity = {
	kind: IdentityKind,
	-- For kind == "uniqueId": the UniqueId value itself (used as a table key
	-- via tostring()).
	uniqueId: any?,
	-- For kind == "path": stable path from a root, each segment
	-- {className, siblingIndex} (1-based, siblingIndex is among same-class
	-- siblings of the same parent).
	path: { { className: string, siblingIndex: number } }?,
}

local function uniqueIdKey(u: any): string
	return "U:" .. tostring(u)
end

local function pathKey(path: { { className: string, siblingIndex: number } }): string
	local parts = table.create(#path)
	for i, seg in path do
		parts[i] = seg.className .. "#" .. tostring(seg.siblingIndex)
	end
	return "P:" .. table.concat(parts, "/")
end

-- Returns a string key uniquely identifying this Identity, suitable for
-- table-keyed lookups.
local function identityKey(id: Identity): string
	if id.kind == "uniqueId" then
		return uniqueIdKey(id.uniqueId)
	else
		return pathKey(id.path :: { { className: string, siblingIndex: number } })
	end
end

-- Lune's `roblox` binding does not auto-generate a real UniqueId the way
-- Roblox Studio does: freshly-created instances report an all-zero
-- UniqueId (`00000000000000000000000000000000`) unless one was explicitly
-- assigned. An all-zero id is not a valid distinguishing identity -- if we
-- treated it as one, every never-touched instance in a tree would collide
-- on the same identity key. Treat all-zero as "absent" and fall through to
-- positional matching.
local ZERO_UNIQUE_ID_STRING = string.rep("0", 32)

local function tryGetUniqueId(inst: any): any?
	local ok, val = pcall(function()
		return (inst :: any).UniqueId
	end)
	if ok and val ~= nil then
		local ok2, str = pcall(tostring, val)
		if ok2 and str == ZERO_UNIQUE_ID_STRING then
			return nil
		end
		return val
	end
	return nil
end

-- Builds a stable child ordering key: prefer UniqueId (stable across
-- snapshots) when present on the child, else fall back to the child's
-- Name (Roblox instances always have one) as the deterministic tiebreaker.
-- This is NOT GetChildren() traversal order.
local function siblingSortKey(inst: any): string
	local uid = tryGetUniqueId(inst)
	if uid then
		return "0:" .. tostring(uid)
	end
	local ok, name = pcall(function()
		return (inst :: any).Name
	end)
	if not ok or type(name) ~= "string" then
		name = ""
	end
	return "1:" .. name
end

-- Cache type: memoizes, per parent instance + className, the sorted list
-- of same-class children (keyed by parent's GetDebugId() .. "#" ..
-- className). Without this, computing paths for every child of a wide
-- parent (e.g. 1000 Parts under one Folder) would redo the full
-- collect+sort of that parent's children once per child -- O(n) work per
-- instance, O(n^2) overall. The cache makes each parent's sibling list
-- built and sorted exactly once regardless of how many of its children
-- need a path computed, dropping this to O(n log n) for a single flat
-- level (the common case for bulk sibling sets) and preserving that
-- benefit through repeated calls across the same instance list.
export type SiblingCache = { [string]: { any } }

local function newSiblingCache(): SiblingCache
	return {}
end

local function getSortedSiblings(
	parent: any,
	className: string,
	childrenOf: (any) -> { any },
	cache: SiblingCache?
): { any }
	local cacheKey = if cache then parent:GetDebugId() .. "#" .. className else nil
	if cache and cacheKey and cache[cacheKey] then
		return cache[cacheKey]
	end

	local siblings = {}
	for _, child in childrenOf(parent) do
		if (child :: any).ClassName == className then
			table.insert(siblings, child)
		end
	end
	table.sort(siblings, function(a, b)
		return siblingSortKey(a) < siblingSortKey(b)
	end)

	if cache and cacheKey then
		cache[cacheKey] = siblings
	end
	return siblings
end

-- Computes the stable path (root -> ... -> inst) for `inst`, given a lookup
-- of each instance's parent (`parentOf`) and full child list for computing
-- sibling index (`childrenOf`, i.e. all children of a given instance,
-- including other classes -- filtering to same-ClassName siblings happens
-- here). `cache`, if provided, memoizes per-parent sibling computation
-- across repeated calls (see SiblingCache above) -- pass the same cache
-- table when computing paths for many instances in the same tree snapshot.
local function computePath(
	inst: any,
	parentOf: (any) -> any?,
	childrenOf: (any) -> { any },
	cache: SiblingCache?
): { { className: string, siblingIndex: number } }
	local segments = {}
	local current = inst
	while current ~= nil do
		local parent = parentOf(current)
		local className = (current :: any).ClassName
		local siblingIndex = 1
		if parent ~= nil then
			local siblings = getSortedSiblings(parent, className, childrenOf, cache)
			for i, sib in siblings do
				if sib == current then
					siblingIndex = i
					break
				end
			end
		end
		table.insert(segments, 1, { className = className, siblingIndex = siblingIndex })
		current = parent
	end
	return segments
end

-- Computes the Identity for `inst`: UniqueId if the class exposes one,
-- else the stable structural path. `cache` is an optional SiblingCache
-- (see above) to avoid O(n^2) blowup when computing identities for many
-- instances that share parents.
local function computeIdentity(
	inst: any,
	parentOf: (any) -> any?,
	childrenOf: (any) -> { any },
	cache: SiblingCache?
): Identity
	local uid = tryGetUniqueId(inst)
	if uid then
		return { kind = "uniqueId", uniqueId = uid }
	end
	return {
		kind = "path",
		path = computePath(inst, parentOf, childrenOf, cache),
	}
end

return {
	computeIdentity = computeIdentity,
	identityKey = identityKey,
	tryGetUniqueId = tryGetUniqueId,
	newSiblingCache = newSiblingCache,
}
