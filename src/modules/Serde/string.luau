local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))
local number = require(script.Parent:FindFirstChild('f64'))

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