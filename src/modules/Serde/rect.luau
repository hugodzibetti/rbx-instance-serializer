local t = require(script.Parent:FindFirstChild('types'))
local vec2 = require(script.Parent:FindFirstChild('vec2'))

local rect: t.Converter<Rect> = {}

function rect.read()
    return Rect.new(vec2.read(), vec2.read())
end

function rect.write(v: Rect)
    vec2.write(v.Min)
    vec2.write(v.Max)

    return
end

function rect.getLengthOf(v: Rect)
    return vec2.getLengthOf(v.Min) +
        vec2.getLengthOf(v.Max)
end

return rect