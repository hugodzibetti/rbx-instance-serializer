local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))
local number = require(script.Parent:FindFirstChild('f64'))
local enumItem = require(script.Parent:FindFirstChild('enumItem'))
local cframe = require(script.Parent:FindFirstChild('cframe'))

local rotationCurveKey: t.Converter<RotationCurveKey> = {}

function rotationCurveKey.read()
    local key = RotationCurveKey.new(number.read(), cframe.read(), enumItem.read())
    key.RightTangent = number.read()
    key.LeftTangent = number.read()

    return key
end

function rotationCurveKey.write(v: RotationCurveKey)
    number.write(v.Time)
    cframe.write(v.Value)
    enumItem.write(v.Interpolation)
    number.write(v.RightTangent)
    number.write(v.LeftTangent)

    return
end

function rotationCurveKey.getLengthOf(v: RotationCurveKey)
    return number.read(v.Time) +
        cframe.read(v.Value) +
        enumItem.read(v.Interpolation) +
        number.read(v.RightTangent) +
        number.read(v.LeftTangent)
end

return rotationCurveKey