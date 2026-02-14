local t = require(script.Parent:FindFirstChild('types'))
local udim = require(script.Parent:FindFirstChild('udim'))

local udim2: t.Converter<UDim2> = {}

function udim2.read()
    local X = udim.read()
    local Y = udim.read()
    return UDim2.new(X.Scale, X.Offset, Y.Scale, Y.Offset)
end

function udim2.write(v: UDim2)
    udim.write(v.X)
    udim.write(v.Y)

    return
end

function udim2.getLengthOf(v: UDim2)
    return udim.getLengthOf(v.X) + udim.getLengthOf(v.Y)
end

return udim2