local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local roblox = require("@lune/roblox")
local serde = require("@src/serde")
local format = require("@src/format")
local instance = require("@src/instance")

-- Classes with a Referent ("Parent") property: hierarchy round-trips, but
-- these buckets must never be deduplicated even if properties are identical.
local mockArtifactWithParent = {
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
mockArtifactWithParent.classByName["Folder"] = mockArtifactWithParent.classById[1]
mockArtifactWithParent.classByName["Part"] = mockArtifactWithParent.classById[2]

-- No Referent property modeled on "Part" here, so identical instances are
-- eligible for template dedup.
local mockArtifactNoParent = {
	version = 1,
	classes = {},
	classByName = {},
	classById = {
		[1] = {
			id = 1,
			name = "Part",
			properties = {
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
mockArtifactNoParent.classByName["Part"] = mockArtifactNoParent.classById[1]

return function()
	test.suite("instance.roundtrip", function()
		test.case("round trips a simple instance tree preserving structure and properties", function()
			local folder = roblox.Instance.new("Folder")
			local part1 = roblox.Instance.new("Part")
			part1.Parent = folder
			part1.Anchored = true
			part1.Position = roblox.Vector3.new(1, 2, 3)

			local part2 = roblox.Instance.new("Part")
			part2.Parent = folder
			part2.Anchored = false
			part2.Position = roblox.Vector3.new(4, 5, 6)

			local buf = instance.serialize({ folder }, mockArtifactWithParent :: any)
			local roots = instance.deserialize(buf, mockArtifactWithParent :: any)

			check.equal(#roots, 1)
			local newFolder = roots[1]
			check.equal(newFolder.ClassName, "Folder")

			local children = newFolder:GetChildren()
			check.equal(#children, 2)

			local newPart1, newPart2 = nil, nil
			for _, child in children do
				if child.Anchored == true then
					newPart1 = child
				else
					newPart2 = child
				end
			end

			check.equal(newPart1 ~= nil, true)
			check.equal(newPart2 ~= nil, true)
			check.equal(newPart1.Position, roblox.Vector3.new(1, 2, 3))
			check.equal(newPart2.Position, roblox.Vector3.new(4, 5, 6))
			check.equal(newPart1.Parent, newFolder)
			check.equal(newPart2.Parent, newFolder)
		end)
	end)

	test.suite("instance.no-dedup", function()
		test.case("identical instances serialize without dedup (v3 format)", function()
			local p1 = roblox.Instance.new("Part")
			p1.Anchored = true
			p1.Position = roblox.Vector3.new(1, 1, 1)

			local p2 = roblox.Instance.new("Part")
			p2.Anchored = true
			p2.Position = roblox.Vector3.new(1, 1, 1)

			local p3 = roblox.Instance.new("Part")
			p3.Anchored = true
			p3.Position = roblox.Vector3.new(1, 1, 1)

			local buf = instance.serialize({ p1, p2, p3 }, mockArtifactNoParent :: any)
			local decoded = format.read(buf, mockArtifactNoParent :: any)

			check.equal(#decoded.classBlocks, 1)
			local cb = decoded.classBlocks[1]
			check.equal(cb.instanceCount, 3)
			check.equal(cb.templateRefs, nil)
		end)

		test.case("mixed instances round trip to correct, independent values", function()
			local p1 = roblox.Instance.new("Part")
			p1.Anchored = true
			p1.Position = roblox.Vector3.new(2, 2, 2)

			local p2 = roblox.Instance.new("Part")
			p2.Anchored = true
			p2.Position = roblox.Vector3.new(2, 2, 2)

			local p3 = roblox.Instance.new("Part")
			p3.Anchored = false
			p3.Position = roblox.Vector3.new(9, 9, 9)

			local buf = instance.serialize({ p1, p2, p3 }, mockArtifactNoParent :: any)
			local roots = instance.deserialize(buf, mockArtifactNoParent :: any)

			check.equal(#roots, 3)

			local duplicates = {}
			local uniques = {}
			for _, r in roots do
				if r.Anchored == true then
					table.insert(duplicates, r)
				else
					table.insert(uniques, r)
				end
			end

			check.equal(#duplicates, 2)
			check.equal(#uniques, 1)
			check.equal(duplicates[1].Position, roblox.Vector3.new(2, 2, 2))
			check.equal(duplicates[2].Position, roblox.Vector3.new(2, 2, 2))
			check.equal(uniques[1].Position, roblox.Vector3.new(9, 9, 9))

			-- Duplicates must be separate Instance objects, not aliased.
			duplicates[1].Position = roblox.Vector3.new(100, 100, 100)
			check.equal(duplicates[2].Position, roblox.Vector3.new(2, 2, 2))
			check.equal(uniques[1].Position, roblox.Vector3.new(9, 9, 9))
		end)
	end)

	test.suite("instance.referentSkip", function()
		test.case("never dedups a class bucket containing a Referent property", function()
			local folder = roblox.Instance.new("Folder")

			local p1 = roblox.Instance.new("Part")
			p1.Parent = folder
			p1.Anchored = true
			p1.Position = roblox.Vector3.new(5, 5, 5)

			local p2 = roblox.Instance.new("Part")
			p2.Parent = folder
			p2.Anchored = true
			p2.Position = roblox.Vector3.new(5, 5, 5)

			local buf = instance.serialize({ folder }, mockArtifactWithParent :: any)
			local decoded = format.read(buf, mockArtifactWithParent :: any)

			local partBlock = nil
			for _, cb in decoded.classBlocks do
				if cb.classId == 2 then
					partBlock = cb
				end
			end

			check.equal(partBlock ~= nil, true)
			check.equal(partBlock.templateRefs, nil)
		end)
	end)
end
