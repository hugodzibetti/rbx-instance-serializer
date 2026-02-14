local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))

local col3: t.Converter<Color3> = {}

function col3.read()
    local b = buff.get()
    local x = buffer.readf32(b, buff.getCursor())
    buff.push(4)
    local y = buffer.readf32(b, buff.getCursor())
    buff.push(4)
    local z = buffer.readf32(b, buff.getCursor())
    buff.push(4)

    return Vector3.new(x, y, z)
end

function col3.write(v: Color3)
    buff.alloc(12)

    local b = buff.get()
    buffer.writef32(b, buff.getCursor(), v.R)
    buff.push(4)
    buffer.writef32(b, buff.getCursor(), v.G)
    buff.push(4)
    buffer.writef32(b, buff.getCursor(), v.B)
    buff.push(4)

    return
end

function col3.getLengthOf(v: Color3)
    return 12
end

return col3