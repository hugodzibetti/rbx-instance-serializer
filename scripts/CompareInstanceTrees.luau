--!strict
-- Deep, type-aware structural comparison between an original instance tree and its
-- Lattice round-trip. Meant to be pasted (or required) directly inside a live Studio
-- session via the Roblox_Studio MCP's execute_luau, per .claude/skills/verify/SKILL.md
-- Step 3.
--
-- Earlier ad-hoc versions of this check compared property values with plain `==`,
-- which false-positives/negatives on the exact types Lattice deliberately lossy-encodes
-- (f32 truncation, Color3 8-bit quantization, CFrame axis-snapping) and false-negatives
-- on reference-typed values (two distinct Vector3 userdata with equal components are
-- `==` in Luau, so that part was fine, but comparing floats with `==` after an f32
-- round-trip is not, and walking children with GetChildren() without accounting for
-- Lattice's own NON_CREATABLE_CLASSES skip-set desyncs the two trees on the very first
-- TouchTransmitter it hits). This module fixes both: per-codec tolerance and
-- skip-aware pairing driven by the same artifact metadata the serializer used.

-- Mirrors src/instance/Serializer.luau's skip-set. Kept in sync manually since this
-- script runs standalone in Studio without access to that module's internals.
local NON_CREATABLE_CLASSES = {
	TouchTransmitter = true,
}

local function relevantChildren(inst: any): { any }
	local out = {}
	for _, child in inst:GetChildren() do
		if not NON_CREATABLE_CLASSES[child.ClassName] then
			table.insert(out, child)
		end
	end
	return out
end

-- Type-aware equality tolerance, keyed off the Roblox runtime type of the value
-- (typeof(va)) rather than the property's codecId. Two properties turned up whose
-- codecId didn't resolve to the codec name a naive lookup expects: combinator-wrapped
-- properties (e.g. WeldConstraint's C0/C1, wrapped in an option/array combinator at
-- artifact-build time) get a dynamically-assigned codecId that isn't in the static
-- codecNameToId table, so a codecId->name reverse lookup silently misses and falls
-- through to a raw `==` — which then flags every sub-epsilon CFrame rotation as a
-- "mismatch" even though it's well within Lattice's f32 round-trip tolerance. Driving
-- comparisons off the actual value's type sidesteps that lookup entirely.
local EPSILON = 1e-4

local function numbersClose(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or EPSILON)
end

local typeComparators: { [string]: (a: any, b: any) -> boolean } = {
	Vector2 = function(a, b)
		return numbersClose(a.X, b.X, 1e-3) and numbersClose(a.Y, b.Y, 1e-3)
	end,
	Vector3 = function(a, b)
		return (a - b).Magnitude < 1e-2
	end,
	Color3 = function(a, b)
		return numbersClose(a.R, b.R, 1 / 255) and numbersClose(a.G, b.G, 1 / 255) and numbersClose(a.B, b.B, 1 / 255)
	end,
	-- Compares basis vectors directly rather than ToEulerAnglesXYZ(): Euler decomposition
	-- is discontinuous near axis-aligned rotations (gimbal-lock-style), so a ~1e-6
	-- difference in the input matrix can produce a large difference in decoded angles.
	-- Basis-vector comparison is continuous and doesn't have that failure mode.
	CFrame = function(a, b)
		if (a.Position - b.Position).Magnitude >= 1e-2 then
			return false
		end
		return (a.RightVector - b.RightVector).Magnitude < 1e-2
			and (a.UpVector - b.UpVector).Magnitude < 1e-2
			and (a.LookVector - b.LookVector).Magnitude < 1e-2
	end,
	UDim = function(a, b)
		return numbersClose(a.Scale, b.Scale, 1e-3) and a.Offset == b.Offset
	end,
	UDim2 = function(a, b)
		return typeComparators.UDim(a.X, b.X) and typeComparators.UDim(a.Y, b.Y)
	end,
	Rect = function(a, b)
		return typeComparators.Vector2(a.Min, b.Min) and typeComparators.Vector2(a.Max, b.Max)
	end,
	NumberRange = function(a, b)
		return numbersClose(a.Min, b.Min, 1e-3) and numbersClose(a.Max, b.Max, 1e-3)
	end,
	NumberSequence = function(a, b)
		return #a.Keypoints == #b.Keypoints
	end,
	ColorSequence = function(a, b)
		return #a.Keypoints == #b.Keypoints
	end,
	PhysicalProperties = function(a, b)
		return numbersClose(a.Density, b.Density, 1e-3) and numbersClose(a.Friction, b.Friction, 1e-3)
	end,
	Ray = function(a, b)
		return typeComparators.Vector3(a.Origin, b.Origin) and typeComparators.Vector3(a.Direction, b.Direction)
	end,
	UniqueId = function(a, b)
		return tostring(a) == tostring(b)
	end,
	number = function(a, b)
		return numbersClose(a, b, 1e-3)
	end,
}

local function valuesEqual(_codecName: string?, a: any, b: any): boolean
	if a == nil or b == nil then
		return a == b
	end
	local cmp = typeComparators[typeof(a)]
	if cmp then
		local ok, result = pcall(cmp, a, b)
		if ok then
			return result
		end
		return false
	end
	return a == b
end

export type Mismatch = {
	path: string,
	kind: "class" | "property" | "childCount" | "missing",
	detail: string,
}

-- `Instance`-valued properties (Parent, PrimaryPart, Part0/Part1 on constraints/joints,
-- etc.) are serialized via the "referent" codec as an index into the class block, not
-- by value — so the two trees never share actual Instance identity and a raw `==`
-- always reports a mismatch even on a perfect round-trip. The only meaningful check is
-- "does the referenced instance occupy the same position in its tree", so referent
-- properties are compared by path (Name chain) relative to each tree's own root instead.
local function relativePath(root: any, inst: any): string?
	if inst == nil then
		return "<nil>"
	end
	local parts = {}
	local cur = inst
	while cur do
		table.insert(parts, 1, cur.Name)
		if cur == root then
			return table.concat(parts, "/")
		end
		cur = cur.Parent
	end
	return nil -- not a descendant of root (e.g. points outside the serialized subtree)
end

-- Compares `original` against `roundTrip`, using `artifact` (an ArtifactData, same as
-- passed to Lattice.serialize/deserialize) to know which properties were actually part
-- of the round-trip, and `serde` (Lattice.Serde) to resolve each property's codec name
-- (hence tolerance) from its codecId.
local function compare(artifact: any, serde: any, original: any, roundTrip: any): { Mismatch }
	local mismatches: { Mismatch } = {}
	local codecIdToName: { [number]: string } = {}
	for name, id in serde.codecNameToId do
		codecIdToName[id] = name
	end

	local function walk(a: any, b: any, path: string)
		if a.ClassName ~= b.ClassName then
			table.insert(mismatches, { path = path, kind = "class", detail = `{a.ClassName} vs {b.ClassName}` })
			return
		end

		local classMeta = artifact.classByName[a.ClassName]
		if classMeta then
			for _, prop in classMeta.properties do
				local okA, va = pcall(function()
					return (a :: any)[prop.name]
				end)
				local okB, vb = pcall(function()
					return (b :: any)[prop.name]
				end)
				if okA and okB then
					-- Instance-typed properties (Parent, PrimaryPart, Part0/1, ...) are
					-- checked by typeof rather than codecId lookup, for the same reason
					-- typeComparators is: codecId resolution isn't reliable for every
					-- combinator-wrapped property, but typeof(va) always is.
					local equal: boolean
					if typeof(va) == "Instance" or typeof(vb) == "Instance" then
						equal = relativePath(original, va) == relativePath(roundTrip, vb)
					else
						equal = valuesEqual(codecIdToName[prop.codecId], va, vb)
					end
					if not equal then
						table.insert(mismatches, {
							path = path,
							kind = "property",
							detail = `{prop.name}: {tostring(va)} vs {tostring(vb)}`,
						})
					end
				end
			end
		end

		local ac, bc = relevantChildren(a), relevantChildren(b)
		if #ac ~= #bc then
			table.insert(mismatches, {
				path = path,
				kind = "childCount",
				detail = `{#ac} vs {#bc}`,
			})
			return
		end
		for i = 1, #ac do
			walk(ac[i], bc[i], `{path}/{ac[i].Name}`)
		end
	end

	walk(original, roundTrip, original.Name)
	return mismatches
end

return {
	compare = compare,
	relevantChildren = relevantChildren,
	NON_CREATABLE_CLASSES = NON_CREATABLE_CLASSES,
}
