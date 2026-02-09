--!native

local Types = require("@src/modules/BufferUtil/Types")

return {
	write = function(b: Types.BufferWriter, v: Faces)
		b:WriteBool(v.Right)
		b:WriteBool(v.Top)
		b:WriteBool(v.Back)
		b:WriteBool(v.Left)
		b:WriteBool(v.Bottom)
		b:WriteBool(v.Front)
	end,
	read = function(b: Types.BufferReader)
		local normals = {}
		if b:ReadBool() then
			table.insert(normals, Enum.NormalId.Right)
		end
		if b:ReadBool() then
			table.insert(normals, Enum.NormalId.Top)
		end
		if b:ReadBool() then
			table.insert(normals, Enum.NormalId.Back)
		end
		if b:ReadBool() then
			table.insert(normals, Enum.NormalId.Left)
		end
		if b:ReadBool() then
			table.insert(normals, Enum.NormalId.Bottom)
		end
		if b:ReadBool() then
			table.insert(normals, Enum.NormalId.Front)
		end

		return Faces.new(unpack(normals))
	end,
}
