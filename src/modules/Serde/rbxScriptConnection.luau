local t = require(script.Parent:FindFirstChild('types'))
local number = require(script.Parent:FindFirstChild('f64'))

local udim: t.Converter<UDim> = {}

function udim.read()
    return UDim.new(number.read(), number.read())
end

function udim.write(v: UDim)
    number.write(v.Scale)
    number.write(v.Offset)

    return
end

function udim.getLengthOf(v: UDim)
    return number.getLengthOf(v.Scale) + number.getLengthOf(v.Offset)
end

return udim