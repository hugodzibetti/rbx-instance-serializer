local t = require("./types")
local number = require("./f64")

return function<T>(converter: t.Converter<T>)
    local array: t.Converter<{T}> = {}
    
    function array.read()
        local len = number.read()
        
        if len == 0 then
            return
        end
        
        local t: {T} = {}
        for i = 1, len do
            local items = {converter.read()}
            -- Support for tuples
            for _, j in items do
                table.insert(t, j)
            end
        end

        return t
    end

    function array.write(v: {T})
        local len = #v
        number.write(len)
        
        for _, j in v do
            converter.write(j)
        end

        return
    end
    
    function array.getLengthOf(v: {T})
        local len = number.getLengthOf(#v)
        for _, j in v do
            len += converter.getLengthOf(j)
        end
        
        return len
    end
    
    return array
end