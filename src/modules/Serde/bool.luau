local t = require("./types")
local buff = require("./buff")

local bool: t.Converter<boolean> = {}

function bool.read()
    local b = buff.get()
    local num = buffer.readu8(b, buff.getCursor())
    buff.push(1)

    return num == 1
end

function bool.write(v: boolean)
    buff.alloc(1)

    local b = buff.get()
    buffer.writeu8(b, buff.getCursor(), v and 1 or 0)

    buff.push(1)
    return
end

function bool.getLengthOf(x: boolean)
    return 1
end

return bool