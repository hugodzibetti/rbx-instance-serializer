local buff = require("./buff")

local sides = {}

local NormalId = Enum.NormalId


function sides.read()
    local b = buff.get()
    local cursor = buff.getCursor()
    local faces = {}
    table.insert(faces, buffer.readu8(b, cursor) == 1 and NormalId.Left or nil); cursor += 1
    table.insert(faces, buffer.readu8(b, cursor) == 1 and NormalId.Top or nil); cursor += 1
    table.insert(faces, buffer.readu8(b, cursor) == 1 and NormalId.Back or nil); cursor += 1
    table.insert(faces, buffer.readu8(b, cursor) == 1 and NormalId.Right or nil); cursor += 1
    table.insert(faces, buffer.readu8(b, cursor) == 1 and NormalId.Bottom or nil); cursor += 1
    table.insert(faces, buffer.readu8(b, cursor) == 1 and NormalId.Front or nil); cursor += 1

    buff.push(6)

    return faces
end

function sides.write(v)
    buff.alloc(6)

    local b = buff.get()
    local cursor = buff.getCursor()

    buffer.writeu8(b, cursor, v.Left and 1 or 0); cursor += 1
    buffer.writeu8(b, cursor, v.Top and 1 or 0); cursor += 1
    buffer.writeu8(b, cursor, v.Back and 1 or 0); cursor += 1
    buffer.writeu8(b, cursor, v.Right and 1 or 0); cursor += 1
    buffer.writeu8(b, cursor, v.Bottom and 1 or 0); cursor += 1
    buffer.writeu8(b, cursor, v.Front and 1 or 0); cursor += 1

    buff.push(6)
    return
end

function sides.getLengthOf(x)
    return 6
end

return sides