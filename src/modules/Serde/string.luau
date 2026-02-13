local t = require("./types")
local buff = require("./buff")
local number = require("./f64")

local string: t.Converter<string> = {}

function string.read()
    local b = buff.get()
    local length = number.read()
    
    local str = buffer.readstring(b, buff.getCursor(), length)
    buff.push(length)

    return str
end

function string.write(v: string)
    local len = #v
    number.write(len)

    buff.alloc(len)
    local b = buff.get()
    buffer.writestring(b, buff.getCursor(), v)

    buff.push(len)
    return
end

function string.getLengthOf(v: string)
    local len = #v
    return len + number.getLengthOf(len)
end

return string