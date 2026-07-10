--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local types = require("@src/types")

local Color3 = roblox.Color3
local ColorSequenceKeypoint = roblox.ColorSequenceKeypoint

local round = math.round

-- Color channels are quantized to u8 (matching Roblox's own internal storage
-- for colors), so 12 bytes of f32 fields collapse to 4 bytes time + 3 bytes color.
local colorSequenceKeypoint: types.Codec<ColorSequenceKeypoint> = {
	write = function(writer: Writer.Writer, value: ColorSequenceKeypoint)
		writer:f32(value.Time)
		local color = value.Value
		writer:u8(math.clamp(round(color.R * 255), 0, 255))
		writer:u8(math.clamp(round(color.G * 255), 0, 255))
		writer:u8(math.clamp(round(color.B * 255), 0, 255))
	end,

	read = function(reader: Reader.Reader): ColorSequenceKeypoint
		local time = reader:f32()
		local r = reader:u8()
		local g = reader:u8()
		local b = reader:u8()
		return ColorSequenceKeypoint.new(time, Color3.new(r / 255, g / 255, b / 255))
	end,
}

return colorSequenceKeypoint
