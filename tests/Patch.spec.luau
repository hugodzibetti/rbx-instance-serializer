local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local roblox = require("@lune/roblox")
local serde = require("@src/serde")
local instance = require("@src/instance")
local diffModule = require("@src/patch/diff")
local applyModule = require("@src/patch/apply")

-- Same shape as tests/Instance.spec.luau's mockArtifactWithParent, with a
-- Name property added (string codec) so instances can be told apart and so
-- positional-fallback path segments (Name as tiebreaker) are exercised.
local mockArtifact = {
	version = 1,
	classes = {},
	classByName = {},
	classById = {
		[1] = {
			id = 1,
			name = "Folder",
			properties = {
				{
					name = "Parent",
					codecId = 26,
					codec = serde.codecIdToModule[26],
					default = 0,
				},
				{
					name = "Name",
					codecId = 3,
					codec = serde.codecIdToModule[3],
					default = "Folder",
				},
			},
		},
		[2] = {
			id = 2,
			name = "Part",
			properties = {
				{
					name = "Parent",
					codecId = 26,
					codec = serde.codecIdToModule[26],
					default = 0,
				},
				{
					name = "Name",
					codecId = 3,
					codec = serde.codecIdToModule[3],
					default = "Part",
				},
				{
					name = "Anchored",
					codecId = 2,
					codec = serde.codecIdToModule[2],
					default = false,
				},
				{
					name = "Position",
					codecId = 17,
					codec = serde.codecIdToModule[17],
					default = roblox.Vector3.new(0, 0, 0),
				},
			},
		},
	},
}
mockArtifact.classByName["Folder"] = mockArtifact.classById[1]
mockArtifact.classByName["Part"] = mockArtifact.classById[2]

local function countRoots(roots)
	local n = 0
	for _ in roots do
		n += 1
	end
	return n
end

local function findByName(roots, name)
	for _, r in roots do
		if r.Name == name then
			return r
		end
		local found = findByName(r:GetChildren(), name)
		if found then
			return found
		end
	end
	return nil
end

local function allInstances(roots)
	local list = {}
	local function dfs(inst)
		table.insert(list, inst)
		for _, c in inst:GetChildren() do
			dfs(c)
		end
	end
	for _, r in roots do
		dfs(r)
	end
	return list
end

return function()
	test.suite("patch.emptyDiff", function()
		test.case("no changes produces an empty patch that applies to an equal tree", function()
			local folder = roblox.Instance.new("Folder")
			folder.Name = "Root"
			local part = roblox.Instance.new("Part")
			part.Name = "P1"
			part.Parent = folder
			part.Anchored = true
			part.Position = roblox.Vector3.new(1, 2, 3)

			local baselineBuf = instance.serialize({ folder }, mockArtifact :: any)

			-- Re-deserialize to build a "current" tree structurally identical
			-- to the baseline (same shape/values), simulating "nothing changed".
			local currentRoots = instance.deserialize(baselineBuf, mockArtifact :: any)

			local result = diffModule.diff(baselineBuf, mockArtifact :: any, currentRoots)

			local applyResult = applyModule.apply(baselineBuf, mockArtifact :: any, result.patch)
			check.equal(countRoots(applyResult.roots), 1)

			local newFolder = applyResult.roots[1]
			check.equal(newFolder.Name, "Root")
			local newPart = findByName(newFolder:GetChildren(), "P1")
			check.equal(newPart ~= nil, true)
			check.equal(newPart.Position, roblox.Vector3.new(1, 2, 3))
			check.equal(newPart.Anchored, true)
		end)
	end)

	test.suite("patch.singlePropertyChange", function()
		test.case("changing one property on one instance patches only that property", function()
			local folder = roblox.Instance.new("Folder")
			folder.Name = "Root"
			local part1 = roblox.Instance.new("Part")
			part1.Name = "P1"
			part1.Parent = folder
			part1.Anchored = true
			part1.Position = roblox.Vector3.new(1, 1, 1)

			local part2 = roblox.Instance.new("Part")
			part2.Name = "P2"
			part2.Parent = folder
			part2.Anchored = false
			part2.Position = roblox.Vector3.new(2, 2, 2)

			local baselineBuf = instance.serialize({ folder }, mockArtifact :: any)
			local currentRoots = instance.deserialize(baselineBuf, mockArtifact :: any)

			local currentP1 = findByName(currentRoots, "P1")
			currentP1.Position = roblox.Vector3.new(99, 99, 99)

			local result = diffModule.diff(baselineBuf, mockArtifact :: any, currentRoots)

			local applyResult = applyModule.apply(baselineBuf, mockArtifact :: any, result.patch)
			local newP1 = findByName(applyResult.roots, "P1")
			local newP2 = findByName(applyResult.roots, "P2")

			check.equal(newP1.Position, roblox.Vector3.new(99, 99, 99))
			check.equal(newP1.Anchored, true)
			check.equal(newP2.Position, roblox.Vector3.new(2, 2, 2))
			check.equal(newP2.Anchored, false)
		end)
	end)

	test.suite("patch.addRemoveChangeCombined", function()
		test.case("add + remove + change together apply in correct order", function()
			local folder = roblox.Instance.new("Folder")
			folder.Name = "Root"
			local part1 = roblox.Instance.new("Part")
			part1.Name = "Keep"
			part1.Parent = folder
			part1.Anchored = true
			part1.Position = roblox.Vector3.new(1, 1, 1)

			local part2 = roblox.Instance.new("Part")
			part2.Name = "Remove"
			part2.Parent = folder
			part2.Anchored = false
			part2.Position = roblox.Vector3.new(2, 2, 2)

			local baselineBuf = instance.serialize({ folder }, mockArtifact :: any)
			local currentRoots = instance.deserialize(baselineBuf, mockArtifact :: any)

			local currentFolder = currentRoots[1]
			local currentKeep = findByName(currentRoots, "Keep")
			local currentRemove = findByName(currentRoots, "Remove")

			-- change
			currentKeep.Anchored = false

			-- remove
			currentRemove.Parent = nil
			currentRemove:Destroy()

			-- add
			local part3 = roblox.Instance.new("Part")
			part3.Name = "Added"
			part3.Parent = currentFolder
			part3.Anchored = true
			part3.Position = roblox.Vector3.new(7, 7, 7)

			local result = diffModule.diff(baselineBuf, mockArtifact :: any, currentRoots)
			local applyResult = applyModule.apply(baselineBuf, mockArtifact :: any, result.patch)

			local finalAll = allInstances(applyResult.roots)
			local names = {}
			for _, inst in finalAll do
				names[inst.Name] = inst
			end

			check.equal(names["Remove"], nil)
			check.equal(names["Keep"] ~= nil, true)
			check.equal(names["Keep"].Anchored, false)
			check.equal(names["Added"] ~= nil, true)
			check.equal(names["Added"].Position, roblox.Vector3.new(7, 7, 7))
			check.equal(names["Added"].Parent, names["Root"])
		end)
	end)

	test.suite("patch.uniqueIdAbsentFallback", function()
		test.case("positional fallback matches instances when UniqueId is unavailable", function()
			-- mockArtifact's Folder/Part classes don't model UniqueId as a
			-- property, and Lune's roblox.Instance.new instances used here
			-- don't surface a settable/comparable UniqueId in this mock
			-- context in a way the artifact tracks -- so Identity always
			-- falls back to positional/path matching for this artifact,
			-- exercising the fallback path deliberately (per the design
			-- doc's requirement to test the no-UniqueId case explicitly).
			local folder = roblox.Instance.new("Folder")
			folder.Name = "Root"
			local partA = roblox.Instance.new("Part")
			partA.Name = "A"
			partA.Parent = folder
			partA.Anchored = true
			partA.Position = roblox.Vector3.new(1, 0, 0)

			local partB = roblox.Instance.new("Part")
			partB.Name = "B"
			partB.Parent = folder
			partB.Anchored = false
			partB.Position = roblox.Vector3.new(0, 1, 0)

			local baselineBuf = instance.serialize({ folder }, mockArtifact :: any)
			local currentRoots = instance.deserialize(baselineBuf, mockArtifact :: any)

			local currentB = findByName(currentRoots, "B")
			currentB.Position = roblox.Vector3.new(0, 42, 0)

			local result = diffModule.diff(baselineBuf, mockArtifact :: any, currentRoots)

			-- Both A and B lack UniqueId under this artifact, so fallback
			-- matching should have been used for at least the changed one.
			check.equal(result.usedFallbackCount > 0, true)

			local applyResult = applyModule.apply(baselineBuf, mockArtifact :: any, result.patch)
			local newB = findByName(applyResult.roots, "B")
			local newA = findByName(applyResult.roots, "A")
			check.equal(newB.Position, roblox.Vector3.new(0, 42, 0))
			check.equal(newA.Position, roblox.Vector3.new(1, 0, 0))
		end)
	end)
end
