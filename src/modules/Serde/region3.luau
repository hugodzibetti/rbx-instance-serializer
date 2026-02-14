local t = require(script.Parent:FindFirstChild('types'))
local vec3 = require(script.Parent:FindFirstChild('vec3'))

local region3: t.Converter<Region3> = {}

function region3.read()
    local min = vec3.read()
    local max = vec3.read()
    return Region3.new(min, max)
end

function region3.write(v: Region3)
    vec3.write(v.CFrame.Position - v.Size * 0.5)
    vec3.write(v.CFrame.Position + v.Size * 0.5) 
end

function region3.getLengthOf(v: Region3)
    return vec3.getLengthOf(v.CFrame.Position - v.Size * 0.5) +  -- Min corner
        vec3.getLengthOf(v.CFrame.Position + v.Size * 0.5)    -- Max corner
end

return region3