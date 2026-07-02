local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local roblox = require("@lune/roblox")

local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local uniqueId = require("@src/serde/uniqueId")

return function()
	test.suite("serde.uniqueId", function()
		test.case("round trips a freshly generated UniqueId", function()
			local value = roblox.UniqueId.new()
			local w = Writer.new()
			uniqueId.write(w, value)
			local r = Reader.new(w:toBuffer())
			local result = uniqueId.read(r)
			check.equal(tostring(result), tostring(value))
		end)

		test.case("round trips UniqueId.null", function()
			local value = roblox.UniqueId.null
			local w = Writer.new()
			uniqueId.write(w, value)
			local r = Reader.new(w:toBuffer())
			local result = uniqueId.read(r)
			check.equal(tostring(result), tostring(value))
		end)

		test.case("distinct UniqueIds stay distinct after round trip", function()
			local a = roblox.UniqueId.new()
			local b = roblox.UniqueId.new()
			local wa = Writer.new()
			uniqueId.write(wa, a)
			local wb = Writer.new()
			uniqueId.write(wb, b)
			local resultA = uniqueId.read(Reader.new(wa:toBuffer()))
			local resultB = uniqueId.read(Reader.new(wb:toBuffer()))
			check.equal(tostring(resultA) == tostring(resultB), false)
		end)
	end)
end
