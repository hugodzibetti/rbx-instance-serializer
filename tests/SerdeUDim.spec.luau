local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local roblox = require("@lune/roblox")

local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local udim = require("@src/serde/udim")
local udim2 = require("@src/serde/udim2")
local rect = require("@src/serde/rect")

return function()
	test.suite("serde.udim", function()
		test.case("round trip with positive, negative, and fractional values", function()
			local cases = {
				roblox.UDim.new(0, 0),
				roblox.UDim.new(0.5, 10),
				roblox.UDim.new(1, -20),
			}
			for _, value in cases do
				local w = Writer.new()
				udim.write(w, value)
				local r = Reader.new(w:toBuffer())
				local result = udim.read(r)
				check.equal(result.Scale, value.Scale)
				check.equal(result.Offset, value.Offset)
			end
		end)
	end)

	test.suite("serde.udim2", function()
		test.case("round trip with distinct X/Y", function()
			local value = roblox.UDim2.new(roblox.UDim.new(0.25, 5), roblox.UDim.new(0.75, -15))
			local w = Writer.new()
			udim2.write(w, value)
			local r = Reader.new(w:toBuffer())
			local result = udim2.read(r)
			check.equal(result.X.Scale, value.X.Scale)
			check.equal(result.X.Offset, value.X.Offset)
			check.equal(result.Y.Scale, value.Y.Scale)
			check.equal(result.Y.Offset, value.Y.Offset)
		end)
	end)

	test.suite("serde.rect", function()
		test.case("round trip with a non-trivial box", function()
			local value = roblox.Rect.new(10, 20, 110, 220)
			local w = Writer.new()
			rect.write(w, value)
			local r = Reader.new(w:toBuffer())
			local result = rect.read(r)
			check.equal(result.Min.X, value.Min.X)
			check.equal(result.Min.Y, value.Min.Y)
			check.equal(result.Max.X, value.Max.X)
			check.equal(result.Max.Y, value.Max.Y)
		end)
	end)
end
