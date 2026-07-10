--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local types = require("@src/types")
local colorSequenceKeypoint = require("@src/serde/colorSequenceKeypoint")

local ColorSequence = roblox.ColorSequence

local colorSequence: types.Codec<ColorSequence> = {
	write = function(writer: Writer.Writer, value: ColorSequence)
		local keypoints = value.Keypoints
		writer:varint(#keypoints)
		for _, keypoint in keypoints do
			colorSequenceKeypoint.write(writer, keypoint)
		end
	end,

	read = function(reader: Reader.Reader): ColorSequence
		local count = reader:varint()
		local keypoints = table.create(count)
		for i = 1, count do
			keypoints[i] = colorSequenceKeypoint.read(reader)
		end
		return ColorSequence.new(keypoints)
	end,
}

return colorSequence
