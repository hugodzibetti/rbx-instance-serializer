--!strict
--!native
--!optimize 2

local roblox = require("@lune/roblox")
local types = require("@src/types")

export type Ray = typeof(roblox.Ray.new(roblox.Vector3.new(0, 0, 0), roblox.Vector3.new(0, 0, 0)))

local ray = {} :: types.Codec<Ray>

function ray.write(writer, value: Ray)
	writer:f32(value.Origin.X)
	writer:f32(value.Origin.Y)
	writer:f32(value.Origin.Z)
	writer:f32(value.Direction.X)
	writer:f32(value.Direction.Y)
	writer:f32(value.Direction.Z)
end

function ray.read(reader): Ray
	local ox, oy, oz = reader:f32(), reader:f32(), reader:f32()
	local dx, dy, dz = reader:f32(), reader:f32(), reader:f32()
	return roblox.Ray.new(roblox.Vector3.new(ox, oy, oz), roblox.Vector3.new(dx, dy, dz))
end

return ray
