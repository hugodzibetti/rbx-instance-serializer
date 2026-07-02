--!strict
--!native
--!optimize 2

local roblox = require("@lune/roblox")
local types = require("@src/types")

export type Rect = typeof(roblox.Rect.new(0, 0, 0, 0))

local rect = {} :: types.Codec<Rect>

function rect.write(writer, value: Rect)
	writer:f32(value.Min.X)
	writer:f32(value.Min.Y)
	writer:f32(value.Max.X)
	writer:f32(value.Max.Y)
end

function rect.read(reader): Rect
	local minX = reader:f32()
	local minY = reader:f32()
	local maxX = reader:f32()
	local maxY = reader:f32()
	return roblox.Rect.new(minX, minY, maxX, maxY)
end

return rect
