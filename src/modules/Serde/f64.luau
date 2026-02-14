local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))
local util = require(script.Parent:FindFirstChild('util'))

local f64: t.Converter<number> = {}

function f64.read()
    local b = buff.get()
    local typeTag = buffer.readu8(b, buff.getCursor())
    buff.push(1)
    
    local name, bytes = util.typeToInt(typeTag)
    local num = buffer["read"..name](b, buff.getCursor())
    buff.push(bytes) -- 8 bytes
    
    return num
end

function f64.write(v: number)
    local typeName, index, bytes = util.inferType(v)
    buff.alloc(bytes + 1)
    
    local b = buff.get()
    buffer.writeu8(b, buff.getCursor(), index)
    buff.push(1)
    
    buffer["write"..typeName](b, buff.getCursor(), v)
    
    buff.push(bytes)
    return
end

function f64.getLengthOf(v: number)
    local _, bytes = util.inferType(v)
    return bytes + 1
end

return f64