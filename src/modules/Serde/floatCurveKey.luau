local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))
local number = require(script.Parent:FindFirstChild('f64'))
local option = require(script.Parent:FindFirstChild('option'))
local enumItem = require(script.Parent:FindFirstChild('enumItem'))

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