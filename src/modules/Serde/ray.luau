local t = require("./types")
local vec3 = require("./vec3")

local ray: t.Converter<Ray> = {}

function ray.read()
    return Ray.new(vec3.read(), vec3.read())
end

function ray.write(v: Ray)
    vec3.write(v.Origin)
    vec3.write(v.Direction)

    return
end

function ray.getLengthOf(v: Ray)
    return vec3.getLengthOf(v.Origin) +
        vec3.getLengthOf(v.Direction)
end

return ray