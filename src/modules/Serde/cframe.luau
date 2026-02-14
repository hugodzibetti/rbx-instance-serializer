local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))

local cframe: t.Converter<CFrame> = {}

function cframe.write(cf: CFrame)
    buff.alloc(48)
    local b = buff.get()

    buffer.writef32(b, buff.getCursor(), cf.X); buff.push(4)
    buffer.writef32(b, buff.getCursor(), cf.Y); buff.push(4)
    buffer.writef32(b, buff.getCursor(), cf.Z); buff.push(4)

    local rx, ry, rz = cf.RightVector, cf.UpVector, cf.LookVector
    buffer.writef32(b, buff.getCursor(), rx.X); buff.push(4)
    buffer.writef32(b, buff.getCursor(), rx.Y); buff.push(4)
    buffer.writef32(b, buff.getCursor(), rx.Z); buff.push(4)

    buffer.writef32(b, buff.getCursor(), ry.X); buff.push(4)
    buffer.writef32(b, buff.getCursor(), ry.Y); buff.push(4)
    buffer.writef32(b, buff.getCursor(), ry.Z); buff.push(4)

    buffer.writef32(b, buff.getCursor(), rz.X); buff.push(4)
    buffer.writef32(b, buff.getCursor(), rz.Y); buff.push(4)
    buffer.writef32(b, buff.getCursor(), rz.Z); buff.push(4)
end

function cframe.read()
    local b = buff.get()
    local cursor = buff.getCursor()

    local x = buffer.readf32(b, cursor); cursor += 4
    local y = buffer.readf32(b, cursor); cursor += 4
    local z = buffer.readf32(b, cursor); cursor += 4

    local rxx = buffer.readf32(b, cursor); cursor += 4
    local rxy = buffer.readf32(b, cursor); cursor += 4
    local rxz = buffer.readf32(b, cursor); cursor += 4

    local ryx = buffer.readf32(b, cursor); cursor += 4
    local ryy = buffer.readf32(b, cursor); cursor += 4
    local ryz = buffer.readf32(b, cursor); cursor += 4

    local rzx = buffer.readf32(b, cursor); cursor += 4
    local rzy = buffer.readf32(b, cursor); cursor += 4
    local rzz = buffer.readf32(b, cursor); cursor += 4

    buff.push(48) 

    local rotation = CFrame.fromMatrix(
        Vector3.new(0, 0, 0),
        Vector3.new(rxx, rxy, rxz),
        Vector3.new(ryx, ryy, ryz),
        Vector3.new(rzx, rzy, rzz)
    )
    return rotation + Vector3.new(x, y, z)
end

function cframe.getLengthOf(v: CFrame)
    return 48
end

return cframe