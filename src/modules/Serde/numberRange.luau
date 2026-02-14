local t = require(script.Parent:FindFirstChild('types'))
local number = require(script.Parent:FindFirstChild('f64'))

local numberRange: t.Converter<NumberRange> = {}

function numberRange.read()
    return NumberRange.new(number.read(), number.read())
end

function numberRange.write(v: NumberRange)
    number.write(v.Min)
    number.write(v.Max)

    return
end

function numberRange.getLengthOf(v: NumberRange)
    return number.getLengthOf(v.Min) + number.getLengthOf(v.Max)
end

return numberRange