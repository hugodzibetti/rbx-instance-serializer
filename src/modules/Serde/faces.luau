local t = require("./types")
local sides = require("./sides")

local faces: t.Converter<Faces> = {}

function faces.read()
    return Faces.new(table.unpack(sides.read()))
end

faces.write = sides.write
faces.getLengthOf = sides.getLengthOf

return faces