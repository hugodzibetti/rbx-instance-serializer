local t = require("./types")
local util = require("./util")
local number = require("./f64")

return function(dictionary: {[string]: t.Converter<t.Primitive>})
    local struct: t.Converter<{[string]: t.Converter<t.Primitive>}> = {}
    
    local keys = {}
    local length = 0
    for k, _ in dictionary do
        length += 1
        table.insert(keys, k)
    end
    
    function struct.read()
        if length == 0 then
            return {}
        end
        
        local t: {[string]: t.Converter<t.Primitive>} = {}
        for i = 1, length do
            t[keys[i]] = util.packTupleIfExists(dictionary[keys[i]].read())
        end

        return t
    end

    function struct.write(v: {[string]: t.Converter<t.Primitive>})
        for k, j in v do
            dictionary[k].write(j)
        end

        return
    end
    
    function struct.getLengthOf(v: {[string]: t.Converter<t.Primitive>})
        local bytes = 0
        for k, j in v do
            bytes += dictionary[k].getLengthOf(j)
        end
        
        return bytes
    end
    
    return struct
end