local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))
local string = require(script.Parent:FindFirstChild('string'))

return function<T>(properties: T): t.CastConverter<Instance, T>
    local instance: t.CastConverter<Instance, T> = {}
    
    function instance.read()
        local b = buff.get()
        local len = buffer.readu32(b, buff.getCursor())
        buff.push(4)
        
        local t: {[string]: t.Converter<t.Primitive>} = {}
        for i = 1, len do
            local key = string.read()
            t[key] = properties[key].read()
        end

        return t
    end

    function instance.write(v: Instance)
        buff.alloc(4)
        
        local len = 0
        for _, _ in properties do
            len += 1
        end
        
        if len == 0 then
            return
        end
        
        for k, j in properties do
            buff.alloc(string.getLengthOf(k))
            buff.alloc(j.getLengthOf(v[k]))
        end
        
        local b = buff.get()
        buffer.writeu32(b, buff.getCursor(), len)
        
        buff.push(4)
        
        for k, j in properties do
            string.write(k)
            j.write(v[k])
        end

        return
    end
    
    function instance.getLengthOf(v: Instance)
        local len = 4
        for k, j in properties do
            len += string.getLengthOf(k)
            len += j.getLengthOf(v[k])
        end
        
        return len
    end
    
    return instance
end