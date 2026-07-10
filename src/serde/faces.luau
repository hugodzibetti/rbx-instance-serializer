--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local types = require("@src/types")

local Faces = roblox.Faces
local NormalId = roblox.Enum.NormalId

local faces: types.Codec<Faces> = {
	write = function(writer: Writer.Writer, value: Faces)
		local bits = (if value.Top then 1 else 0)
			+ (if value.Bottom then 2 else 0)
			+ (if value.Left then 4 else 0)
			+ (if value.Right then 8 else 0)
			+ (if value.Front then 16 else 0)
			+ (if value.Back then 32 else 0)
		writer:u8(bits)
	end,

	read = function(reader: Reader.Reader): Faces
		local bits = reader:u8()
		local set = {}
		if bit32.band(bits, 1) ~= 0 then
			table.insert(set, NormalId.Top)
		end
		if bit32.band(bits, 2) ~= 0 then
			table.insert(set, NormalId.Bottom)
		end
		if bit32.band(bits, 4) ~= 0 then
			table.insert(set, NormalId.Left)
		end
		if bit32.band(bits, 8) ~= 0 then
			table.insert(set, NormalId.Right)
		end
		if bit32.band(bits, 16) ~= 0 then
			table.insert(set, NormalId.Front)
		end
		if bit32.band(bits, 32) ~= 0 then
			table.insert(set, NormalId.Back)
		end
		return Faces.new(table.unpack(set))
	end,
}

return faces
