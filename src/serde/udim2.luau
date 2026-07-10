--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")
local types = require("@src/types")
local udim = require("@src/serde/udim")

export type UDim2 = typeof(roblox.UDim2.new(roblox.UDim.new(0, 0), roblox.UDim.new(0, 0)))

local udim2 = {} :: types.Codec<UDim2>

function udim2.write(writer, value: UDim2)
	udim.write(writer, value.X)
	udim.write(writer, value.Y)
end

function udim2.read(reader): UDim2
	local x = udim.read(reader)
	local y = udim.read(reader)
	return roblox.UDim2.new(x, y)
end

return udim2
