--!native

local Types = require("@src/modules/BufferUtil/Types")

type ReadWritePair = {
	read: <T>(reader: Types.BufferReader) -> T,
	write: <T>(writer: Types.BufferWriter, value: T) -> (),
}

local DataTypeBuffer = {}
DataTypeBuffer.ReadWrite = {} :: { [string]: ReadWritePair | ((innerSerializer: any) -> ReadWritePair) }

-- Primitives
DataTypeBuffer.ReadWrite.bool = require("@self/bool")
DataTypeBuffer.ReadWrite.int = require("@self/int")
DataTypeBuffer.ReadWrite.int64 = require("@self/int64")
DataTypeBuffer.ReadWrite.float = require("@self/float")
DataTypeBuffer.ReadWrite.double = require("@self/double")
DataTypeBuffer.ReadWrite.string = require("@self/string")
DataTypeBuffer.ReadWrite.Content = DataTypeBuffer.ReadWrite.string

-- Vectors
DataTypeBuffer.ReadWrite.Vector2 = require("@self/Vector2")
DataTypeBuffer.ReadWrite.Vector3 = require("@self/Vector3")
DataTypeBuffer.ReadWrite.Vector2int16 = require("@self/Vector2int16")
DataTypeBuffer.ReadWrite.Vector3int16 = require("@self/Vector3int16")

-- Roblox types
DataTypeBuffer.ReadWrite.BrickColor = require("@self/BrickColor")
DataTypeBuffer.ReadWrite.CFrame = require("@self/CFrame")
DataTypeBuffer.ReadWrite.Color3 = require("@self/Color3")
DataTypeBuffer.ReadWrite.Color3uint8 = require("@self/Color3uint8")
DataTypeBuffer.ReadWrite.DateTime = require("@self/DateTime")
DataTypeBuffer.ReadWrite.Ray = require("@self/Ray")
DataTypeBuffer.ReadWrite.Rect = require("@self/Rect")
DataTypeBuffer.ReadWrite.Region3 = require("@self/Region3")
DataTypeBuffer.ReadWrite.Region3int16 = require("@self/Region3int16")
DataTypeBuffer.ReadWrite.UDim = require("@self/UDim")
DataTypeBuffer.ReadWrite.UDim2 = require("@self/UDim2")
DataTypeBuffer.ReadWrite.Enum = require("@self/Enum")
DataTypeBuffer.ReadWrite.NumberSequence = require("@self/NumberSequence")
DataTypeBuffer.ReadWrite.ColorSequence = require("@self/ColorSequence")
DataTypeBuffer.ReadWrite.Faces = require("@self/Faces")
DataTypeBuffer.ReadWrite.NumberRange = require("@self/NumberRange")
DataTypeBuffer.ReadWrite.array = require("@self/array")

return DataTypeBuffer
