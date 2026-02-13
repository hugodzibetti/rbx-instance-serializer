local t = require("./types")
local number = require("./f64")
local color3 = require("./col3")

local colorSequenceKeypoint: t.Converter<ColorSequenceKeypoint> = {}

function colorSequenceKeypoint.read()
    local time = number.read()
    local value = color3.read()
    
    return ColorSequenceKeypoint.new(time, value)
end

function colorSequenceKeypoint.write(v: ColorSequenceKeypoint)
    number.write(v.Time)
    color3.write(v.Value)

    return
end

function colorSequenceKeypoint.getLengthOf(v: ColorSequenceKeypoint)
    return number.getLengthOf(v.Time) + color3.getLengthOf(v.Value)
end

return colorSequenceKeypoint