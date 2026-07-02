local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local roblox = require("@lune/roblox")

local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local enumItem = require("@src/serde/enumItem")

return function()
	test.suite("serde.enumItem", function()
		test.case("round trips Material items", function()
			local codec = enumItem(roblox.Enum.Material)
			local values = { roblox.Enum.Material.Plastic, roblox.Enum.Material.Wood, roblox.Enum.Material.Neon }
			for _, value in values do
				local w = Writer.new()
				codec.write(w, value)
				local r = Reader.new(w:toBuffer())
				check.equal(codec.read(r), value)
			end
		end)

		test.case("is generic across different enums", function()
			local keyCodeCodec = enumItem(roblox.Enum.KeyCode)
			local values = { roblox.Enum.KeyCode.A, roblox.Enum.KeyCode.Space }
			for _, value in values do
				local w = Writer.new()
				keyCodeCodec.write(w, value)
				local r = Reader.new(w:toBuffer())
				check.equal(keyCodeCodec.read(r), value)
			end
		end)
	end)
end
