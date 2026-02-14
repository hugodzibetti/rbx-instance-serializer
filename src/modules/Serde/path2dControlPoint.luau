local t = require(script.Parent:FindFirstChild('types'))
local udim2 = require(script.Parent:FindFirstChild('udim2'))

local path2dControlPoint: t.Converter<Path2DControlPoint> = {}

function path2dControlPoint.read()
    return Path2DControlPoint.new(udim2.read(), udim2.read(), udim2.read())
end

function path2dControlPoint.write(v: Path2DControlPoint)
    udim2.write(v.Position)
    udim2.write(v.LeftTangent)
    udim2.write(v.RightTangent)

    return
end

function path2dControlPoint.getLengthOf(v: Path2DControlPoint)
    return udim2.getLengthOf(v.Position) +
        udim2.getLengthOf(v.LeftTangent) +
        udim2.getLengthOf(v.RightTangent)
end

return path2dControlPoint