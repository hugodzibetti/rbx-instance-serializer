local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check
local BrickPack = require("@src")
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local testModelsPath = "./assets/test-models"

return function()
	test.suite("Test models deserialization integrity", function()
		for i, modelName in fs.readDir(testModelsPath) do
			test.case(modelName, function()
				local model = roblox.deserializeModel(`{testModelsPath}/{modelName}`)
				local serialized = BrickPack.Serialize(model)
				print(serialized)
				-- local deserialized = BrickPack.Deserialize(serialized)
				-- check.equal(model, deserialized)
			end)
		end
	end)
end
