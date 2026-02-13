local t = require("./types")
local util = require("./util")
local number = require("./f64")

return function<K, V>(key: t.Converter<K>, value: t.Converter<V>)
    local dict: t.Converter<{[K]: V}> = {}
    
    function dict.read()
        local len = number.read()
        if len == 0 then
            return {}
        end
        
        local t: {[K]: V} = {}
        for i = 1, len do
            -- Interact with the KEY first
            t[key.read()] = util.packTupleIfExists(value.read())
        end

        return t
    end

    function dict.write(v: {[K]: V})
        local len = 0
        for _, _ in v do
            len += 1
        end

        number.write(len)
        
        for k, j in v do
            key.write(k)
            value.write(j)
        end

        return
    end
    
    function dict.getLengthOf(v: {[K]: V})
        local len = 0
        for _, _ in v do
            len += 1
        end
        
        len = number.getLengthOf(len)
        
        for k, j in v do
            len += key.getLengthOf(k)
            len += value.getLengthOf(j)
        end
        
        return len
    end
    
    return dict
end