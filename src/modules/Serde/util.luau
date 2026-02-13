local util = {}

function util.packTupleIfExists(...)
    local values = {...}
    if #values <= 1 then
        return table.unpack(values)
    end
    
    return values
end

local typeInfo = {
    {name = "u8",  min = 0,          max = 255,              isInt = true,  bytes = 1},
    {name = "i8",  min = -128,        max = 127,              isInt = true,  bytes = 1},
    {name = "u16", min = 0,          max = 65535,            isInt = true,  bytes = 2},
    {name = "i16", min = -32768,     max = 32767,            isInt = true,  bytes = 2},
    {name = "u32", min = 0,          max = 4294967295,        isInt = true,  bytes = 4},
    {name = "i32", min = -2147483648, max = 2147483647,       isInt = true,  bytes = 4},
    {name = "f32", min = -3.4e38,    max = 3.4e38,           isInt = false, bytes = 8},
    {name = "f64", min = -1.7e308,   max = 1.7e308,          isInt = false, bytes = 8}
}

function util.inferType(number: number): (string, number)
    local isInteger = math.floor(number) == number

    for i, info in typeInfo do
        if number >= info.min and number <= info.max then
            if not info.isInt or (info.isInt and isInteger) then
                return info.name, i, info.bytes
            end
        end
    end

    return "f64", #typeInfo, 8
end

function util.typeToInt(t: number)
    local values = typeInfo[t]
    return values.name, values.bytes
end

return util