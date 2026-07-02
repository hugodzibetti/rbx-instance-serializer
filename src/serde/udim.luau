--!strict
--!native
--!optimize 2

local roblox = require("@lune/roblox")
local types = require("@src/types")

export type UDim = typeof(roblox.UDim.new(0, 0))

local udim = {} :: types.Codec<UDim>

function udim.write(writer, value: UDim)
	writer:f32(value.Scale)
	writer:varintSigned(math.round(value.Offset))
end

function udim.read(reader): UDim
	local scale = reader:f32()
	local offset = reader:varintSigned()
	return roblox.UDim.new(scale, offset)
end

return udim
