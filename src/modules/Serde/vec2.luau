local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))

local vec2: t.Converter<Vector2> = {}

function vec2.read()
    local b = buff.get()
    local x = buffer.readf32(b, buff.getCursor())
    buff.push(4)
    local y = buffer.readf32(b, buff.getCursor())
    buff.push(4)

    return Vector2.new(x, y)
end

function vec2.write(v: Vector2)
    buff.alloc(8)

    local b = buff.get()
    buffer.writef32(b, buff.getCursor(), v.X)
    buff.push(4)
    buffer.writef32(b, buff.getCursor(), v.Y)
    buff.push(4)

    return
end

function vec2.getLengthOf(v: Vector2)
    return 8
end

return vec2