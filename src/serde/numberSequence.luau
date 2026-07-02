--!strict
--!native
--!optimize 2

local roblox = require("@lune/roblox")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local numberSequenceKeypoint = require("@src/serde/numberSequenceKeypoint")

local numberSequence = {}

function numberSequence.write(writer: Writer.Writer, value: roblox.NumberSequence)
	local keypoints = value.Keypoints
	writer:varint(#keypoints)
	for _, keypoint in keypoints do
		numberSequenceKeypoint.write(writer, keypoint)
	end
end

function numberSequence.read(reader: Reader.Reader): roblox.NumberSequence
	local count = reader:varint()
	local keypoints = table.create(count)
	for i = 1, count do
		keypoints[i] = numberSequenceKeypoint.read(reader)
	end
	return roblox.NumberSequence.new(keypoints)
end

return numberSequence
