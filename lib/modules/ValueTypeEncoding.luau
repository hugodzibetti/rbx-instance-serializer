local FastBufferStream = require(script.Parent.FastBufferStream)

local Encoding = {}

export type ValueTypeWrite = (b: FastBufferStream.BufferWriter, v: boolean) -> nil
export type ValueTypeRead = (b: FastBufferStream.BufferReader) -> nil

Encoding.bool = {
    write = function(b: FastBufferStream.BufferWriter, v: boolean)
        b.writeu8(v and 1 or 0)
    end,
    read = function(b: FastBufferStream.BufferReader)
        return b.readu8() == 1
    end,
}

Encoding.int = {
    write = function(b: FastBufferStream.BufferWriter, v: number)
        b.writeu16(v)
    end,
    read = function(b: FastBufferStream.BufferReader)
        return b.readu16()
    end,
}

Encoding.int64 = {
    write = function(b: FastBufferStream.BufferWriter, v: number)
        b.writeu32(v)
    end,
    read = function(b: FastBufferStream.BufferReader)
        return b.readu32()
    end,
}

Encoding.float = {
    write = function(b: FastBufferStream.BufferWriter, v: number)
        b.writef64(v)
    end,
    read = function(b: FastBufferStream.BufferReader)
        return b.readf64()
    end,
}

Encoding.string = {
    write = function(b: FastBufferStream.BufferWriter, v: string)
        b.writeu32(#v)
        b.writestring(v)
    end,
    read = function(b: FastBufferStream.BufferReader)
        local len = b.readu32()
        return b.readstring(len)
    end,
}
Encoding.Content = Encoding.string

Encoding.Vector2 = {
    write = function(b: FastBufferStream.BufferWriter, v: Vector2)
        b.writef32(v.X)
        b.writef32(v.Y)
    end,
    read = function(b: FastBufferStream.BufferReader)
        return Vector2.new(b.readf32(), b.readf32())
    end,
}

Encoding.Vector3 = {
    write = function(b: FastBufferStream.BufferWriter, v: Vector3)
        b.writef32(v.X)
        b.writef32(v.Y)
        b.writef32(v.Z)
    end,
    read = function(b: FastBufferStream.BufferReader)
        return Vector3.new(b.readf32(), b.readf32(), b.readf32())
    end,
}

Encoding.CFrame = {
    write = function(b: FastBufferStream.BufferWriter, v: CFrame)
        local components = {v:GetComponents()}
        for i = 1, 12 do
            b.writef32(components[i])
        end
    end,
    read = function(b: FastBufferStream.BufferReader)
        local components = {}
        for i = 1, 12 do
            table.insert(components, b.readf32())
        end
        return CFrame.fromMatrix(
            Vector3.new(components[1], components[2], components[3]),
            Vector3.new(components[4], components[5], components[6]),
            Vector3.new(components[7], components[8], components[9]),
            Vector3.new(components[10], components[11], components[12])
        )
    end,
}

-- Encoding.Quaternion = {
--     write = function(b: FastBufferStream.BufferWriter, v: Quaternion)
--         b.writef32(v.X)
--         b.writef32(v.Y)
--         b.writef32(v.Z)
--         b.writef32(v.W)
--     end,
--     read = function(b: FastBufferStream.BufferReader)
--         return Quaternion.new(b.readf32(), b.readf32(), b.readf32(), b.readf32())
--     end,
-- }

Encoding.Color3 = {
    write = function(b: FastBufferStream.BufferWriter, v: Color3)
        b.writeu8(math.floor(v.R * 255))
        b.writeu8(math.floor(v.G * 255))
        b.writeu8(math.floor(v.B * 255))
    end,
    read = function(b: FastBufferStream.BufferReader)
        return Color3.fromRGB(b.readu8(), b.readu8(), b.readu8())
    end,
}

Encoding.Color3uint8 = {
    write = function(b: FastBufferStream.BufferWriter, v: Color3)
        b.writeu8(math.floor(v.R * 255))
        b.writeu8(math.floor(v.G * 255))
        b.writeu8(math.floor(v.B * 255))
    end,
    read = function(b: FastBufferStream.BufferReader)
        return Color3.fromRGB(b.readu8(), b.readu8(), b.readu8())
    end,
}

Encoding.Rect = {
    write = function(b: FastBufferStream.BufferWriter, v: Rect)
        b.writef32(v.Min.X)
        b.writef32(v.Min.Y)
        b.writef32(v.Max.X)
        b.writef32(v.Max.Y)
    end,
    read = function(b: FastBufferStream.BufferReader)
        local minX, minY = b.readf32(), b.readf32()
        local maxX, maxY = b.readf32(), b.readf32()
        return Rect.new(minX, minY, maxX, maxY)
    end,
}

-- Encoding.Region3 = {
--     write = function(b: FastBufferStream.BufferWriter, v: Region3)
--         local min = v:ExpandToGrid(4)
--         b.writei32(min.X)
--         b.writei32(min.Y)
--         b.writei32(min.Z)
--         local size = v.Size
--         b.writei32(size.X)
--         b.writei32(size.Y)
--         b.writei32(size.Z)
--     end,
--     read = function(b: FastBufferStream.BufferReader)
--         local minX = b.readi32()
--         local minY = b.readi32()
--         local minZ = b.readi32()
--         local sizeX = b.readi32()
--         local sizeY = b.readi32()
--         local sizeZ = b.readi32()
--         local min = Vector3.new(minX, minY, minZ)
--         return Region3.new(min, min + Vector3.new(sizeX, sizeY, sizeZ))
--     end,
-- }

Encoding.UDim = {
    write = function(b: FastBufferStream.BufferWriter, v: UDim)
        b.writef32(v.Scale)
        b.writei32(v.Offset)
    end,
    read = function(b: FastBufferStream.BufferReader)
        return UDim.new(b.readf32(), b.readi32())
    end,
}

Encoding.UDim2 = {
    write = function(b: FastBufferStream.BufferWriter, v: UDim2)
        b.writef32(v.X.Scale)
        b.writei32(v.X.Offset)
        b.writef32(v.Y.Scale)
        b.writei32(v.Y.Offset)
    end,
    read = function(b: FastBufferStream.BufferReader)
        return UDim2.new(
            b.readf32(), b.readi32(),
            b.readf32(), b.readi32()
        )
    end,
}

Encoding.Enum = {
    write = function(b: FastBufferStream.BufferWriter, v: EnumItem)
        b.writeu32(v.Value)
    end,
    read = function(b: FastBufferStream.BufferReader)
        return b.readu32()
    end,
}

Encoding.Ray = {
    write = function(b: FastBufferStream.BufferWriter, v: Ray)
        local origin = v.Origin
        b.writef32(origin.X)
        b.writef32(origin.Y)
        b.writef32(origin.Z)
        local direction = v.Direction
        b.writef32(direction.X)
        b.writef32(direction.Y)
        b.writef32(direction.Z)
    end,
    read = function(b: FastBufferStream.BufferReader)
        local originX, originY, originZ = b.readf32(), b.readf32(), b.readf32()
        local dirX, dirY, dirZ = b.readf32(), b.readf32(), b.readf32()
        return Ray.new(
            Vector3.new(originX, originY, originZ),
            Vector3.new(dirX, dirY, dirZ)
        )
    end,
}

Encoding.NumberSequence = {
    write = function(b: FastBufferStream.BufferWriter, v: NumberSequence)
        local keypoints = v.Keypoints
        b.writeu32(#keypoints)
        for _, keypoint in ipairs(keypoints) do
            b.writef32(keypoint.Time)
            b.writef32(keypoint.Value)
            b.writef32(keypoint.Envelope)
        end
    end,
    read = function(b: FastBufferStream.BufferReader)
        local count = b.readu32()
        local keypoints = {}
        for i = 1, count do
            table.insert(keypoints, NumberSequenceKeypoint.new(
                b.readf32(),
                b.readf32(),
                b.readf32()
            ))
        end
        return NumberSequence.new(keypoints)
    end,
}

Encoding.ColorSequence = {
    write = function(b: FastBufferStream.BufferWriter, v: ColorSequence)
        local keypoints = v.Keypoints
        b.writeu32(#keypoints)
        for _, keypoint in ipairs(keypoints) do
            b.writef32(keypoint.Time)
            local color = keypoint.Value
            b.writeu8(math.floor(color.R * 255))
            b.writeu8(math.floor(color.G * 255))
            b.writeu8(math.floor(color.B * 255))
        end
    end,
    read = function(b: FastBufferStream.BufferReader)
        local count = b.readu32()
        local keypoints = {}
        for i = 1, count do
            table.insert(keypoints, ColorSequenceKeypoint.new(
                b.readf32(),
                Color3.fromRGB(b.readu8(), b.readu8(), b.readu8())
            ))
        end
        return ColorSequence.new(keypoints)
    end,
}

Encoding.NumberRange = {
    write = function(b: FastBufferStream.BufferWriter, v: NumberRange)
        b.writef32(v.Min)
        b.writef32(v.Max)
    end,
    read = function(b: FastBufferStream.BufferReader)
        return NumberRange.new(b.readf32(), b.readf32())
    end,
}

Encoding.optional = function(innerSerializer)
    return {
        write = function(b: FastBufferStream.BufferWriter, v)
            if v == nil then
                b.writeu8(0)
            else
                b.writeu8(1)
                innerSerializer.write(b, v)
            end
        end,
        read = function(b: FastBufferStream.BufferReader)
            if b.readu8() == 0 then
                return nil
            else
                return innerSerializer.read(b)
            end
        end,
    }
end

Encoding.array = function(innerSerializer)
    return {
        write = function(b: FastBufferStream.BufferWriter, v: {any})
            b.writeu32(#v)
            for _, item in ipairs(v) do
                innerSerializer.write(b, item)
            end
        end,
        read = function(b: FastBufferStream.BufferReader)
            local count = b.readu32()
            local result = {}
            for i = 1, count do
                table.insert(result, innerSerializer.read(b))
            end
            return result
        end,
    }
end

return Encoding