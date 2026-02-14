local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))

local vec3: t.Converter<Vector3> = {}

function vec3.read()
    local b = buff.get()
    local x = buffer.readf32(b, buff.getCursor())
    buff.push(4)
    local y = buffer.readf32(b, buff.getCursor())
    buff.push(4)
    local z = buffer.readf32(b, buff.getCursor())
    buff.push(4)

    return Vector3.new(x, y, z)
end

function vec3.write(v: Vector3)
    buff.alloc(12)

    local b = buff.get()
    buffer.writef32(b, buff.getCursor(), v.X)
    buff.push(4)
    buffer.writef32(b, buff.getCursor(), v.Y)
    buff.push(4)
    buffer.writef32(b, buff.getCursor(), v.Z)
    buff.push(4)

    return
end

function vec3.getLengthOf(v: Vector3)
    return 12
end

return vec3