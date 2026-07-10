--!strict
--!native
--!optimize 2

local Types = require("@src/types")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local roblox = require("@src/robloxDatatypes")

local Vector3 = roblox.Vector3

local codec: Types.Codec<Vector3> = {
	write = function(writer, value)
		writer:f32(value.X)
		writer:f32(value.Y)
		writer:f32(value.Z)
	end,
	read = function(reader)
		return Vector3.new(reader:f32(), reader:f32(), reader:f32())
	end,
}

return codec
