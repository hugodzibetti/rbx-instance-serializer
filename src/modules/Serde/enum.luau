local t = require("./types")
local string = require("./string")

local enum: t.Converter<Enum> = {}

function enum.read()
    return Enum[string.read()]
end

function enum.write(v: Enum)
    string.write(tostring(v))

    return
end

function enum.getLengthOf(v: Enum)
    return #tostring(v) + 4
end

return enum