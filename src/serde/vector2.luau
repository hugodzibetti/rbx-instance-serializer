--!strict
--!native
--!optimize 2

local Types = require("@src/types")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local roblox = require("@src/robloxDatatypes")

local Vector2 = roblox.Vector2

local codec: Types.Codec<Vector2> = {
	write = function(writer, value)
		writer:f32(value.X)
		writer:f32(value.Y)
	end,
	read = function(reader)
		return Vector2.new(reader:f32(), reader:f32())
	end,
}

return codec
