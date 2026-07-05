local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local roblox = require("@lune/roblox")
local serde = require("@src/serde")
local format = require("@src/format")

local mockArtifact = {
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

return function()
	test.suite("format.roundtrip", function()
		test.case("handles AllDefault encoding", function()
			local data: format.FormatData = {
				version = 1,
				stringTable = { "Anchored", "Position" },
				classBlocks = {
					{
						classId = 1,
						instanceCount = 5,
						columns = {
							{
								propertyNameIndex = 1, -- "Anchored"
								encoding = 3, -- AllDefault
								bitmask = { false, false, false, false, false },
								values = {},
							},
						},
					},
				},
			}

			local buf = format.write(data, mockArtifact :: any)
			local decoded = format.read(buf, mockArtifact :: any)

			check.equal(decoded.version, data.version)
			check.equal(#decoded.stringTable, #data.stringTable)
			check.equal(decoded.stringTable[1], data.stringTable[1])
			check.equal(#decoded.classBlocks, 1)

			local block = decoded.classBlocks[1]
			check.equal(block.classId, 1)
			check.equal(block.instanceCount, 5)
			check.equal(#block.columns, 1)

			local col = block.columns[1]
			check.equal(col.propertyNameIndex, 1)
			check.equal(col.encoding, 3)
			check.equal(#col.values, 0)
			for i = 1, 5 do
				check.equal(col.bitmask[i], false)
			end
		end)

		test.case("handles AllNonDefault encoding", function()
			local data: format.FormatData = {
				version = 1,
				stringTable = { "Anchored", "Position" },
				classBlocks = {
					{
						classId = 1,
						instanceCount = 3,
						columns = {
							{
								propertyNameIndex = 1, -- "Anchored"
								encoding = 4, -- AllNonDefault
								bitmask = { true, true, true },
								values = { true, true, true },
							},
						},
					},
				},
			}

			local buf = format.write(data, mockArtifact :: any)
			local decoded = format.read(buf, mockArtifact :: any)

			local block = decoded.classBlocks[1]
			local col = block.columns[1]
			check.equal(col.encoding, 4)
			check.equal(#col.values, 3)
			check.equal(col.values[1], true)
			check.equal(col.values[2], true)
			check.equal(col.values[3], true)
			for i = 1, 3 do
				check.equal(col.bitmask[i], true)
			end
		end)

		test.case("handles Raw encoding", function()
			local data: format.FormatData = {
				version = 1,
				stringTable = { "Anchored", "Position" },
				classBlocks = {
					{
						classId = 1,
						instanceCount = 4,
						columns = {
							{
								propertyNameIndex = 1, -- "Anchored"
								encoding = 0, -- Raw
								bitmask = { false, true, false, true },
								values = { true, true },
							},
						},
					},
				},
			}

			local buf = format.write(data, mockArtifact :: any)
			local decoded = format.read(buf, mockArtifact :: any)

			local block = decoded.classBlocks[1]
			local col = block.columns[1]
			check.equal(col.encoding, 0)
			check.equal(#col.values, 2)
			check.equal(col.values[1], true)
			check.equal(col.values[2], true)
			check.equal(col.bitmask[1], false)
			check.equal(col.bitmask[2], true)
			check.equal(col.bitmask[3], false)
			check.equal(col.bitmask[4], true)
		end)

		test.case("handles RLE encoding", function()
			local data: format.FormatData = {
				version = 1,
				stringTable = { "Anchored", "Position" },
				classBlocks = {
					{
						classId = 1,
						instanceCount = 6,
						columns = {
							{
								propertyNameIndex = 2, -- "Position"
								encoding = 1, -- RLE
								bitmask = { true, true, true, false, true, true },
								-- Values: 5 non-defaults: pos1, pos1, pos1, pos2, pos2
								values = {
									roblox.Vector3.new(1, 2, 3),
									roblox.Vector3.new(1, 2, 3),
									roblox.Vector3.new(1, 2, 3),
									roblox.Vector3.new(4, 5, 6),
									roblox.Vector3.new(4, 5, 6),
								},
							},
						},
					},
				},
			}

			local buf = format.write(data, mockArtifact :: any)
			local decoded = format.read(buf, mockArtifact :: any)

			local block = decoded.classBlocks[1]
			local col = block.columns[1]
			check.equal(col.encoding, 1)
			check.equal(#col.values, 5)
			check.equal(col.values[1], roblox.Vector3.new(1, 2, 3))
			check.equal(col.values[2], roblox.Vector3.new(1, 2, 3))
			check.equal(col.values[3], roblox.Vector3.new(1, 2, 3))
			check.equal(col.values[4], roblox.Vector3.new(4, 5, 6))
			check.equal(col.values[5], roblox.Vector3.new(4, 5, 6))

			check.equal(col.bitmask[1], true)
			check.equal(col.bitmask[2], true)
			check.equal(col.bitmask[3], true)
			check.equal(col.bitmask[4], false)
			check.equal(col.bitmask[5], true)
			check.equal(col.bitmask[6], true)
		end)

		test.case("handles Dictionary encoding", function()
			-- Non-adjacent repeated values: pos1, pos2, pos1, pos2, pos1 (5 non-defaults)
			local pos1 = roblox.Vector3.new(1, 2, 3)
			local pos2 = roblox.Vector3.new(4, 5, 6)

			local data: format.FormatData = {
				version = 1,
				stringTable = { "Anchored", "Position" },
				classBlocks = {
					{
						classId = 1,
						instanceCount = 5,
						columns = {
							{
								propertyNameIndex = 2, -- "Position"
								encoding = 2, -- Dictionary
								bitmask = { true, true, true, true, true },
								values = { pos1, pos2 }, -- unique values, first-occurrence order
								dictIndices = { 0, 1, 0, 1, 0 },
							},
						},
					},
				},
			}

			local buf = format.write(data, mockArtifact :: any)
			local decoded = format.read(buf, mockArtifact :: any)

			local block = decoded.classBlocks[1]
			local col = block.columns[1]
			check.equal(col.encoding, 2)
			check.equal(#col.values, 2)
			check.equal(col.values[1], pos1)
			check.equal(col.values[2], pos2)
			check.equal(col.dictIndices ~= nil, true)
			check.equal(col.dictIndices[1], 0)
			check.equal(col.dictIndices[2], 1)
			check.equal(col.dictIndices[3], 0)
			check.equal(col.dictIndices[4], 1)
			check.equal(col.dictIndices[5], 0)
			for i = 1, 5 do
				check.equal(col.bitmask[i], true)
			end
		end)
	end)

	test.suite("format.encodingPicker", function()
		test.case("picks Dictionary for a repeated-but-shuffled non-adjacent value column", function()
			local serde = require("@src/serde")
			local instance = require("@src/instance")

			local pickerArtifact = {
				version = 1,
				classes = {},
				classByName = {},
				classById = {
					[1] = {
						id = 1,
						name = "Part",
						properties = {
							{
								name = "Transparency",
								codecId = 0,
								codec = serde.codecIdToModule[0],
								default = 0,
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
			pickerArtifact.classByName["Part"] = pickerArtifact.classById[1]

			-- Alternating 2 values, non-adjacent repeats: dictionary should beat raw/RLE.
			-- Position is unique per instance so whole-instance dedup can't collapse these.
			local parts = {}
			for i = 1, 100 do
				local part = roblox.Instance.new("Part")
				part.Transparency = if i % 2 == 0 then 0.25 else 0.75
				part.Position = roblox.Vector3.new(i, i * 2, i * 3)
				table.insert(parts, part)
			end

			local buf = instance.serialize(parts, pickerArtifact :: any)
			local decoded = format.read(buf, pickerArtifact :: any)

			local block = decoded.classBlocks[1]
			local transparencyCol = nil
			for _, col in block.columns do
				if decoded.stringTable[col.propertyNameIndex] == "Transparency" then
					transparencyCol = col
				end
			end
			check.equal(transparencyCol ~= nil, true)
			check.equal(transparencyCol.encoding, 2)
		end)

		test.case("does not pick Dictionary for a column of fully unique values", function()
			local serde = require("@src/serde")
			local instance = require("@src/instance")

			local pickerArtifact = {
				version = 1,
				classes = {},
				classByName = {},
				classById = {
					[1] = {
						id = 1,
						name = "Part",
						properties = {
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
			pickerArtifact.classByName["Part"] = pickerArtifact.classById[1]

			local parts = {}
			for i = 1, 50 do
				local part = roblox.Instance.new("Part")
				part.Position = roblox.Vector3.new(i, i * 2, i * 3)
				table.insert(parts, part)
			end

			local buf = instance.serialize(parts, pickerArtifact :: any)
			local decoded = format.read(buf, pickerArtifact :: any)

			local block = decoded.classBlocks[1]
			local col = block.columns[1]
			check.equal(col.encoding ~= 2, true)
		end)
	end)
end
