--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, v: NumberSequence)
		local keypoints = v.Keypoints
		b:WriteUInt32(#keypoints)
		for _, keypoint in ipairs(keypoints) do
			b:WriteFloat32(keypoint.Time)
			b:WriteFloat32(keypoint.Value)
			b:WriteFloat32(keypoint.Envelope)
		end
	end,
	read = function(b: Types.BufferReader)
		local count = b:ReadUInt32()
		local keypoints = {}
		for i = 1, count do
			table.insert(keypoints, NumberSequenceKeypoint.new(b:ReadFloat32(), b:ReadFloat32(), b:ReadFloat32()))
		end
		return NumberSequence.new(keypoints)
	end,
}
