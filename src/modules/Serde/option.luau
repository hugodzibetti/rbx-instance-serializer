local t = require("./types")
local buff = require("./buff")
local string = require("./string")

return function<T>(converter: t.Converter<T>)
    local option: t.Converter<T?> = {}
    
    function option.read()
        local b = buff.get()
        local exists = buffer.readu8(b, buff.getCursor())
        buff.push(1)
        
        if exists == 0 then
            return nil
        else
            return converter.read()
        end
    end

    function option.write(v: T?)
        buff.alloc(1)
        
        local b = buff.get()
        buffer.writeu8(b, buff.getCursor(), v and 1 or 0)
        
        if not v then
            return
        end
        
        buff.push(1)
        
        converter.write(v)

        return
    end
    
    function option.getLengthOf(v: T?)
        if not v then
            return 1
        else
            return string.getLengthOf(v) + 1
        end
    end
    
    return option
end