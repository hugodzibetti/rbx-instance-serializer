local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local roblox = require("@lune/roblox")

local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local numberRange = require("@src/serde/numberRange")
local numberSequenceKeypoint = require("@src/serde/numberSequenceKeypoint")
local numberSequence = require("@src/serde/numberSequence")

local function checkKeypoints(result: { roblox.NumberSequenceKeypoint }, expected: { roblox.NumberSequenceKeypoint })
	check.equal(#result, #expected)
	for i, expectedKeypoint in expected do
		check.equal(result[i].Time, expectedKeypoint.Time)
		check.equal(result[i].Value, expectedKeypoint.Value)
		check.equal(result[i].Envelope, expectedKeypoint.Envelope)
	end
end

return function()
	test.suite("serde.numberRange", function()
		test.case("round trip with distinct min/max", function()
			local value = roblox.NumberRange.new(-5, 42.5)
			local w = Writer.new()
			numberRange.write(w, value)
			local r = Reader.new(w:toBuffer())
			local result = numberRange.read(r)
			check.equal(result.Min, value.Min)
			check.equal(result.Max, value.Max)
		end)
	end)

	test.suite("serde.numberSequenceKeypoint", function()
		test.case("round trip with a non-zero envelope", function()
			local value = roblox.NumberSequenceKeypoint.new(0.5, 10, 2)
			local w = Writer.new()
			numberSequenceKeypoint.write(w, value)
			local r = Reader.new(w:toBuffer())
			local result = numberSequenceKeypoint.read(r)
			check.equal(result.Time, value.Time)
			check.equal(result.Value, value.Value)
			check.equal(result.Envelope, value.Envelope)
		end)
	end)

	test.suite("serde.numberSequence", function()
		test.case("round trip with the minimal 2-keypoint case", function()
			local value = roblox.NumberSequence.new(5)
			local w = Writer.new()
			numberSequence.write(w, value)
			local r = Reader.new(w:toBuffer())
			local result = numberSequence.read(r)
			checkKeypoints(result.Keypoints, value.Keypoints)
		end)

		test.case("round trip with a 3-keypoint sequence", function()
			local value = roblox.NumberSequence.new({
				roblox.NumberSequenceKeypoint.new(0, 0),
				roblox.NumberSequenceKeypoint.new(0.5, 1),
				roblox.NumberSequenceKeypoint.new(1, 0),
			})
			local w = Writer.new()
			numberSequence.write(w, value)
			local r = Reader.new(w:toBuffer())
			local result = numberSequence.read(r)
			checkKeypoints(result.Keypoints, value.Keypoints)
		end)
	end)
end
