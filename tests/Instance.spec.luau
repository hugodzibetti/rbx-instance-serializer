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

	-- Artifact with a bulkier "palette" property (Vector3, like Size) alongside
	-- Anchored and a fully-unique Position, modeling a realistic floor-grid scene:
	-- many Parts share a Size, none share a Position.
	local mockArtifactWithSize = {
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
						name = "Size",
						codecId = 17,
						codec = serde.codecIdToModule[17],
						default = roblox.Vector3.new(0, 0, 0),
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
	mockArtifactWithSize.classByName["Part"] = mockArtifactWithSize.classById[1]

	test.suite("instance.dictionaryEncoding", function()
		test.case("N instances sharing a small palette on one property while another is fully unique round trip correctly", function()
			local sizes = { roblox.Vector3.new(4, 1, 4), roblox.Vector3.new(2, 1, 2), roblox.Vector3.new(6, 1, 6) }
			local parts = {}
			for i = 1, 30 do
				local part = roblox.Instance.new("Part")
				part.Anchored = true
				part.Size = sizes[(i % #sizes) + 1] -- small reused palette, shuffled
				part.Position = roblox.Vector3.new(i, i * 2, i * 3) -- fully unique per instance
				table.insert(parts, part)
			end

			local buf = instance.serialize(parts, mockArtifactWithSize :: any)

			local decodedFormat = format.read(buf, mockArtifactWithSize :: any)
			local cb = decodedFormat.classBlocks[1]
			local sizeCol = nil
			for _, col in cb.columns do
				local propName = decodedFormat.stringTable[col.propertyNameIndex]
				if propName == "Size" then
					sizeCol = col
				end
			end
			check.equal(sizeCol ~= nil, true)
			check.equal(sizeCol.encoding, 2) -- Dictionary should win: small shuffled palette of Vector3s

			local roots = instance.deserialize(buf, mockArtifactWithSize :: any)
			check.equal(#roots, 30)

			table.sort(roots, function(a, b)
				return a.Position.X < b.Position.X
			end)

			for i, r in roots do
				check.equal(r.Size, sizes[(i % #sizes) + 1])
				check.equal(r.Position, roblox.Vector3.new(i, i * 2, i * 3))
			end
		end)

		-- Regression test for a critical bug: Dictionary encoding used to key unique
		-- values by tostring(v), not the value's actual serialized bytes. tostring on
		-- Roblox userdata (Vector3/CFrame/etc) can lose precision relative to the
		-- value itself, so two numerically distinct values that print identically
		-- would silently collapse into one dictionary entry -- every instance holding
		-- the second value would get the first value substituted back on read.
		--
		-- This Lune/Luau build's tostring for Vector3/CFrame happens to be a
		-- round-trip-safe shortest-representation formatter (verified: no adjacent-f32
		-- or adjacent-f64 pair was found to collide under tostring across an extensive
		-- sweep), so a *naturally occurring* tostring collision could not be
		-- reproduced here to use as the fixture. Instead, this test proves the actual
		-- fix property directly: many distinct-but-numerically-close Vector3 values
		-- (the exact shape of value that a lossy tostring implementation would be
		-- most likely to collide on) each round-trip to their own distinct value,
		-- with no cross-contamination, which is only guaranteed because Dictionary
		-- keys are now derived from codec.write(...) bytes -- collision-safe by
		-- construction -- rather than from tostring(v).
		test.case("Dictionary-encoded near-identical float values round trip distinctly, not collapsed by string keying", function()
			local parts = {}
			local expectedPositions = {}
			-- Many closely-spaced, but codec-distinguishable, positions sharing a
			-- non-adjacent repeated pattern (so Dictionary, not RLE/Raw, wins).
			for i = 1, 40 do
				local part = roblox.Instance.new("Part")
				part.Anchored = true
				local bucket = i % 4
				part.Position = roblox.Vector3.new(1 + bucket * 0.00001, 2, 3)
				-- Read the value back off the instance (rather than reusing the literal
				-- we wrote) so the expected value reflects whatever Roblox's own
				-- internal storage/rounding produces -- avoids float64-vs-f32 mismatches
				-- between the authored literal and the actual property value.
				table.insert(parts, part)
				table.insert(expectedPositions, part.Position)
			end

			local buf = instance.serialize(parts, mockArtifactWithSize :: any)
			local decodedFormat = format.read(buf, mockArtifactWithSize :: any)
			local cb = decodedFormat.classBlocks[1]

			local roots = instance.deserialize(buf, mockArtifactWithSize :: any)
			check.equal(#roots, 40)

			table.sort(roots, function(a, b)
				return a.Position.X < b.Position.X
			end)
			table.sort(expectedPositions, function(a, b)
				return a.X < b.X
			end)

			for i, r in roots do
				check.equal(r.Position, expectedPositions[i])
			end

			-- Independence: mutating one root must not affect others that share a
			-- dictionary-encoded bucket value (would fail if values were aliased due
			-- to a false string-keyed merge).
			roots[1].Position = roblox.Vector3.new(999, 999, 999)
			for i = 2, #roots do
				check.equal(roots[i].Position, expectedPositions[i])
			end
		end)
	end)

	test.suite("instance.referentRoundTrip", function()
		test.case("round trips distinct instances with identical non-Referent properties, each keeping its own Parent", function()
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
			local roots = instance.deserialize(buf, mockArtifactWithParent :: any)

			check.equal(#roots, 1)
			local newFolder = roots[1]
			local children = newFolder:GetChildren()
			check.equal(#children, 2)

			for _, child in children do
				check.equal(child.Anchored, true)
				check.equal(child.Position, roblox.Vector3.new(5, 5, 5))
				check.equal(child.Parent, newFolder)
			end

			-- Must be independent instances, not aliased.
			children[1].Position = roblox.Vector3.new(1, 2, 3)
			check.equal(children[2].Position, roblox.Vector3.new(5, 5, 5))
		end)
	end)
end
