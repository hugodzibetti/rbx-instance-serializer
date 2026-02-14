local t = require(script.Parent:FindFirstChild('types'))
local sides = require(script.Parent:FindFirstChild('sides'))

local faces: t.Converter<Faces> = {}

function faces.read()
    return Faces.new(table.unpack(sides.read()))
end

faces.write = sides.write
faces.getLengthOf = sides.getLengthOf

return faces