local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local roblox = require("@lune/roblox")

local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local physicalProperties = require("@src/serde/physicalProperties")

return function()
	test.suite("serde.physicalProperties", function()
		test.case("round trip with distinct, non-default values", function()
			local value = roblox.PhysicalProperties.new(2.5, 0.4, 0.1, 50, 25)
			local w = Writer.new()
			physicalProperties.write(w, value)
			local r = Reader.new(w:toBuffer())
			local result = physicalProperties.read(r)
			check.equal(result.Density, value.Density)
			check.equal(result.Friction, value.Friction)
			check.equal(result.Elasticity, value.Elasticity)
			check.equal(result.FrictionWeight, value.FrictionWeight)
			check.equal(result.ElasticityWeight, value.ElasticityWeight)
		end)
	end)
end
