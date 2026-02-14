local t = require(script.Parent:FindFirstChild('types'))
local number = require(script.Parent:FindFirstChild('f64'))

return function<T>(...: t.Converter<T>)
    local tuple: t.Converter<T> = {}

    local converters = {...}
    function tuple.read()
        local len = number.read()
        
        local t: {T} = {}
        for i = 1, len do
            table.insert(
                t, converters[i].read()
            )
        end
        
        return table.unpack(t)
    end

    function tuple.write(...: T)
        local v = {...}
        local len = #v

        -- If a table is passed instead
        if len == 1 and #converters > 1 and typeof(v[1]) == "table" then
            v = v[1]
            len = #v
        end

        number.write(len)
        
        if len > #converters then
            error("too many items in tuple passed")
        end
        
        for i, j in v do
            converters[i].write(j)
        end

        return
    end
    
    function tuple.getLengthOf(...: T)
        local items = {...}
        local len = number.getLengthOf(#items)
        for i, j in items do
            local conv = converters[i]
            if not conv then
                error("too many items in tuple passed")
            end
            
            len += conv.getLengthOf(j)
        end
        
        return len
    end
    
    return tuple
end