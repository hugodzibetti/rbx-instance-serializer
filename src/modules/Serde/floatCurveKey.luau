local t = require("./types")
local buff = require("./buff")
local number = require("./f64")
local option = require("./option")
local enumItem = require("./enumItem")

local optionNumber = option(number)

local floatCurveKey: t.Converter<FloatCurveKey> = {}

function floatCurveKey.read()
    local key = FloatCurveKey.new(number.read(), number.read(), enumItem.read())
    key.RightTangent = optionNumber.read()
    key.LeftTangent = optionNumber.read()
    
    return key
end

function floatCurveKey.write(v: FloatCurveKey)
    number.write(v.Time)
    number.write(v.Value)
    enumItem.write(v.Interpolation)
    optionNumber.write(v.RightTangent)
    optionNumber.write(v.LeftTangent)

    return
end

function floatCurveKey.getLengthOf(v: FloatCurveKey)
    return number.read(v.Time) +
        number.read(v.Value) +
        enumItem.read(v.Interpolation) +
        optionNumber.read(v.RightTangent) +
        optionNumber.read(v.LeftTangent)
end

return floatCurveKey