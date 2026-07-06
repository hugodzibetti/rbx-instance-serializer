local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local ColumnEncoder = require("@src/instance/ColumnEncoder")
local f32 = require("@src/serde/f32")

return function()
	test.suite("instance.ColumnEncoder", function()
		test.case("chooses AllDefault when every value is default", function()
			local serializedVals = { 0, 0, 0, 0 }
			local isDefaults = { true, true, true, true }

			local result = ColumnEncoder.encodeColumn(f32, serializedVals, isDefaults, 4)

			check.equal(result.encoding, 3)
			check.equal(#result.values, 0)
			check.equal(result.dictIndices, nil)
			for _, b in result.bitmask do
				check.equal(b, false)
			end
		end)

		test.case("chooses AllNonDefault when every value is non-default and uniform", function()
			-- All instances have distinct-but-cheap values with no repetition,
			-- so storing raw with no bitmask (AllNonDefault) beats Raw/RLE/Dictionary.
			local serializedVals = { 1, 2, 3, 4 }
			local isDefaults = { false, false, false, false }

			local result = ColumnEncoder.encodeColumn(f32, serializedVals, isDefaults, 4)

			check.equal(result.encoding, 4)
			check.equal(#result.values, 4)
			check.equal(result.values[1], 1)
			check.equal(result.values[4], 4)
			check.equal(result.dictIndices, nil)
			for _, b in result.bitmask do
				check.equal(b, true)
			end
		end)

		test.case("chooses RLE when non-default values form long runs", function()
			-- Long runs of the same non-default value with a default sprinkled in
			-- makes RLE cheapest (few runs) vs raw (per-value) or dictionary.
			local serializedVals = { 5, 5, 5, 5, 5, 5, 5, 5, 0, 5, 5, 5, 5, 5, 5, 5 }
			local isDefaults = {
				false,
				false,
				false,
				false,
				false,
				false,
				false,
				false,
				true,
				false,
				false,
				false,
				false,
				false,
				false,
				false,
			}

			local result = ColumnEncoder.encodeColumn(f32, serializedVals, isDefaults, 16)

			check.equal(result.encoding, 1)
			check.equal(result.bitmask[9], false)
			check.equal(result.dictIndices, nil)
		end)

		test.case("chooses Dictionary when repeated-but-shuffled values dominate", function()
			-- Few unique values repeated in shuffled (non-run) order: RLE can't
			-- collapse this (constant value-switching), but Dictionary can.
			local serializedVals = {}
			local isDefaults = {}
			local pattern = { 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3 }
			for i, v in pattern do
				serializedVals[i] = v
				isDefaults[i] = false
			end

			local result = ColumnEncoder.encodeColumn(f32, serializedVals, isDefaults, #pattern)

			check.equal(result.encoding, 2)
			check.equal(#result.values, 3) -- unique values: 1, 2, 3
			check.equal(result.values[1], 1)
			check.equal(result.values[2], 2)
			check.equal(result.values[3], 3)

			local dictIndices = result.dictIndices :: { number }
			check.equal(dictIndices ~= nil, true)
			check.equal(#dictIndices, #pattern)
			-- first-occurrence order: 1->0, 2->1, 3->2
			check.equal(dictIndices[1], 0)
			check.equal(dictIndices[2], 1)
			check.equal(dictIndices[3], 2)
			check.equal(dictIndices[4], 0)
		end)

		test.case("chooses Raw when non-default values are sparse and distinct", function()
			-- Mostly default, a couple of scattered distinct non-default values:
			-- too few values for RLE/Dictionary to beat plain raw storage.
			local serializedVals = { 0, 0, 42, 0, 0, 0, 0, 0 }
			local isDefaults = { true, true, false, true, true, true, true, true }

			local result = ColumnEncoder.encodeColumn(f32, serializedVals, isDefaults, 8)

			check.equal(result.encoding, 0)
			check.equal(#result.values, 1)
			check.equal(result.values[1], 42)
			check.equal(result.bitmask[3], true)
			check.equal(result.dictIndices, nil)
		end)
	end)
end
