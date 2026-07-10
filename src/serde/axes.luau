--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local types = require("@src/types")

local Axes = roblox.Axes
local Axis = roblox.Enum.Axis

local axes: types.Codec<Axes> = {
	write = function(writer: Writer.Writer, value: Axes)
		local bits = (if value.X then 1 else 0) + (if value.Y then 2 else 0) + (if value.Z then 4 else 0)
		writer:u8(bits)
	end,

	read = function(reader: Reader.Reader): Axes
		local bits = reader:u8()
		local set = {}
		if bit32.band(bits, 1) ~= 0 then
			table.insert(set, Axis.X)
		end
		if bit32.band(bits, 2) ~= 0 then
			table.insert(set, Axis.Y)
		end
		if bit32.band(bits, 4) ~= 0 then
			table.insert(set, Axis.Z)
		end
		return Axes.new(table.unpack(set))
	end,
}

return axes
