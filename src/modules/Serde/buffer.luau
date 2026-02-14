local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))

local bfr: t.Converter<buffer> = {}

function bfr.read()
    local b = buff.get()
    local length = buffer.readu32(b, buff.getCursor())
    buff.push(4)
    
    local str = buffer.readstring(b, buff.getCursor(), length)
    buff.push(length)

    return buffer.fromstring(str)
end

function bfr.write(v: buffer)
    local len = buffer.len(v)
    buff.alloc(len + 4)

    local b = buff.get()
    buffer.writeu32(b, buff.getCursor(), len)
    buff.push(4)
    
    buffer.writestring(b, buff.getCursor(), buffer.tostring(v))

    buff.push(len)
    return
end

function bfr.getLengthOf(v: buffer)
    return #v + 4
end

return bfr