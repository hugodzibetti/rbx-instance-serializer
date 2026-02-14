local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))

local brickColor: t.Converter<BrickColor> = {}

function brickColor.read()
    local b = buff.get()
    local x = buffer.readf32(b, buff.getCursor())
    buff.push(4)
    local y = buffer.readf32(b, buff.getCursor())
    buff.push(4)
    local z = buffer.readf32(b, buff.getCursor())
    buff.push(4)

    return BrickColor.new(x, y, z)
end

function brickColor.write(v: BrickColor)
    buff.alloc(12)

    local b = buff.get()
    buffer.writef32(b, buff.getCursor(), v.r)
    buff.push(4)
    buffer.writef32(b, buff.getCursor(), v.g)
    buff.push(4)
    buffer.writef32(b, buff.getCursor(), v.b)
    buff.push(4)

    return
end

function brickColor.getLengthOf(v: BrickColor)
    return 12
end

return brickColor