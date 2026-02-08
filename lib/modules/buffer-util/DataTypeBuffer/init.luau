--!native

local Types = require(script.Parent.Types)

type ReadWritePair = {
	read: <T>(reader: Types.BufferReader) -> T,
	write: <T>(writer: Types.BufferWriter, value: T) -> (),
}

local DataTypeBuffer = {}
DataTypeBuffer.ReadWrite = {} :: { [string]: ReadWritePair | ((innerSerializer: any) -> ReadWritePair) }

-- Primitives
DataTypeBuffer.ReadWrite.bool = require(script.bool)
DataTypeBuffer.ReadWrite.int = require(script.int)
DataTypeBuffer.ReadWrite.int64 = require(script.int64)
DataTypeBuffer.ReadWrite.float = require(script.float)
DataTypeBuffer.ReadWrite.double = require(script.double)
DataTypeBuffer.ReadWrite.string = require(script.string)
DataTypeBuffer.ReadWrite.Content = DataTypeBuffer.ReadWrite.string

-- Vectors
DataTypeBuffer.ReadWrite.Vector2 = require(script.Vector2)
DataTypeBuffer.ReadWrite.Vector3 = require(script.Vector3)
DataTypeBuffer.ReadWrite.Vector2int16 = require(script.Vector2int16)
DataTypeBuffer.ReadWrite.Vector3int16 = require(script.Vector3int16)

-- Roblox types
DataTypeBuffer.ReadWrite.BrickColor = require(script.BrickColor)
DataTypeBuffer.ReadWrite.CFrame = require(script.CFrame)
DataTypeBuffer.ReadWrite.Color3 = require(script.Color3)
DataTypeBuffer.ReadWrite.Color3uint8 = require(script.Color3uint8)
DataTypeBuffer.ReadWrite.DateTime = require(script.DateTime)
DataTypeBuffer.ReadWrite.Ray = require(script.Ray)
DataTypeBuffer.ReadWrite.Rect = require(script.Rect)
DataTypeBuffer.ReadWrite.Region3 = require(script.Region3)
DataTypeBuffer.ReadWrite.Region3int16 = require(script.Region3int16)
DataTypeBuffer.ReadWrite.UDim = require(script.UDim)
DataTypeBuffer.ReadWrite.UDim2 = require(script.UDim2)
DataTypeBuffer.ReadWrite.Enum = require(script.Enum)
DataTypeBuffer.ReadWrite.NumberSequence = require(script.NumberSequence)
DataTypeBuffer.ReadWrite.ColorSequence = require(script.ColorSequence)
DataTypeBuffer.ReadWrite.Faces = require(script.Faces)
DataTypeBuffer.ReadWrite.NumberRange = require(script.NumberRange)
DataTypeBuffer.ReadWrite.array = require(script.array)

return DataTypeBuffer
