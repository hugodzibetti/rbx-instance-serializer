local t = require("./types")
local buff = require("./buff")
local number = require("./f64")
local enumItem = require("./enumItem")
local cframe = require("./cframe")

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