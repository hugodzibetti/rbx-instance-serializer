local buff = {}

local SIZE = 0
local CURSOR = 0
local BUFFER = buffer.create(0)

function buff.release()
    SIZE = 0
    CURSOR = 0
    BUFFER = buffer.create(0)
end

function buff.load(bfr: buffer)
    BUFFER = bfr
    CURSOR = 0
    SIZE = buffer.len(bfr)
end

function buff.alloc(bytes: number)
    SIZE += bytes
    local secondBuffer = buffer.create(SIZE)
    buffer.copy(secondBuffer, 0, BUFFER)
    
    BUFFER = secondBuffer
end

function buff.push(cursor: number)
    CURSOR += cursor
end

function buff.getCursor()
    return CURSOR
end

function buff.get(): buffer
    return BUFFER
end

return buff