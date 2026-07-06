local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@src/serde")
local format = require("@src/format")
local BufferWriter = require("@src/buffer/Writer")

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
	test.suite("schema evolution", function()
		test.case("loads the frozen v1 fixture and reads correct values", function()
			local bytes = fs.readFile("tests/fixtures/format_v1_sample.bin")
			local buf = buffer.fromstring(bytes)

			local decoded = format.read(buf, mockArtifact :: any)

			check.equal(decoded.version, 1)
			check.equal(#decoded.stringTable, 2)
			check.equal(decoded.stringTable[1], "Anchored")
			check.equal(decoded.stringTable[2], "Position")

			check.equal(#decoded.classBlocks, 1)
			local block = decoded.classBlocks[1]
			check.equal(block.classId, 1)
			check.equal(block.instanceCount, 6)

			local refs = block.templateRefs :: { number }
			check.equal(refs[1], 0)
			check.equal(refs[2], 0)
			check.equal(refs[3], 1)
			check.equal(refs[4], 1)
			check.equal(refs[5], 1)
			check.equal(refs[6], 2)

			local col = block.columns[1]
			check.equal(col.encoding, 1)
			check.equal(#col.values, 3)
			check.equal(col.values[1], roblox.Vector3.new(1, 2, 3))
			check.equal(col.values[2], roblox.Vector3.new(1, 2, 3))
			check.equal(col.values[3], roblox.Vector3.new(4, 5, 6))
		end)

		test.case("writes version 4 (length-prefixed class blocks) and round-trips correctly", function()
			local data: format.FormatData = {
				version = 3,
				stringTable = { "Anchored", "Position" },
				classBlocks = {
					{
						classId = 1,
						instanceCount = 3,
						columns = {
							{
								propertyNameIndex = 2,
								encoding = 1,
								bitmask = { true, true, true },
								values = {
									roblox.Vector3.new(1, 2, 3),
									roblox.Vector3.new(1, 2, 3),
									roblox.Vector3.new(4, 5, 6),
								},
							},
						},
					},
				},
			}

			local buf = format.write(data, mockArtifact :: any)

			-- Confirm the header reports version 4 (Writer always writes current version).
			local versionByte = buffer.readu8(buf, 4)
			local versionByte2 = buffer.readu8(buf, 5)
			check.equal(versionByte, 4)
			check.equal(versionByte2, 0)

			local decoded = format.read(buf, mockArtifact :: any)
			check.equal(decoded.version, 4)

			local block = decoded.classBlocks[1]
			check.equal(block.templateRefs, nil)

			local col = block.columns[1]
			check.equal(#col.values, 3)
			check.equal(col.values[1], roblox.Vector3.new(1, 2, 3))
			check.equal(col.values[3], roblox.Vector3.new(4, 5, 6))
		end)

		test.case("errors clearly on unknown format version", function()
			local w = BufferWriter.new()
			w:u8(0x4C)
			w:u8(0x41)
			w:u8(0x54)
			w:u8(0x46)
			w:u16(99)
			local buf = w:toBuffer()

			local success, err = pcall(function()
				format.read(buf, mockArtifact :: any)
			end)

			check.equal(success, false)
			check.is_true(string.find(tostring(err), "Unsupported format version", 1, true) ~= nil)
			check.is_true(string.find(tostring(err), "99", 1, true) ~= nil)
		end)
	end)
end
