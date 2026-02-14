local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))
local string = require(script.Parent:FindFirstChild('string'))

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