--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: ColorSequence)
		local keypoints = v.Keypoints
		b:WriteUInt32(#keypoints)
		for _, keypoint in ipairs(keypoints) do
			b:WriteFloat32(keypoint.Time)
			local color = keypoint.Value
			b:WriteUInt8(math.floor(color.R * 255))
			b:WriteUInt8(math.floor(color.G * 255))
			b:WriteUInt8(math.floor(color.B * 255))
		end
	end,
	read = function(b: Types.BufferReader)
		local count = b:ReadUInt32()
		local keypoints = {}
		for i = 1, count do
			table.insert(
				keypoints,
				ColorSequenceKeypoint.new(b:ReadFloat32(), Color3.fromRGB(b:ReadUInt8(), b:ReadUInt8(), b:ReadUInt8()))
			)
		end
		return ColorSequence.new(keypoints)
	end,
}
