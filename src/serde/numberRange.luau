--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")

local numberRange = {}

function numberRange.write(writer: Writer.Writer, value: roblox.NumberRange)
	writer:f32(value.Min)
	writer:f32(value.Max)
end

function numberRange.read(reader: Reader.Reader): roblox.NumberRange
	local min = reader:f32()
	local max = reader:f32()
	return roblox.NumberRange.new(min, max)
end

return numberRange
