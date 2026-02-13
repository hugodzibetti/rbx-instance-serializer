local t = require("./types")
local buff = require("./buff")
local string = require("./string")

local enums: t.Converter<Enums> = {}

function enums.read()
    return Enum
end

function enums.write(v: Enums)
    return
end

function enums.getLengthOf(v: Enums)
    return 0
end

return enums