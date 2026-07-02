--!strict
--!native
--!optimize 2

local roblox = require("@lune/roblox")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")

local numberSequenceKeypoint = {}

function numberSequenceKeypoint.write(writer: Writer.Writer, value: roblox.NumberSequenceKeypoint)
	writer:f32(value.Time)
	writer:f32(value.Value)
	writer:f32(value.Envelope)
end

function numberSequenceKeypoint.read(reader: Reader.Reader): roblox.NumberSequenceKeypoint
	local time = reader:f32()
	local value = reader:f32()
	local envelope = reader:f32()
	return roblox.NumberSequenceKeypoint.new(time, value, envelope)
end

return numberSequenceKeypoint
